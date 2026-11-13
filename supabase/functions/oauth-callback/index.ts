// oauth-callback: the provider redirects here with ?code&state. We validate
// the signed state, exchange the code, resolve the account identity, store the
// token in Vault, upsert the channel, then bounce to the dayframe:// scheme so
// ASWebAuthenticationSession finishes.
import { APP_REDIRECT_SCHEME, callbackUrl, providerConfig, verifyState, type Platform } from "../_shared/providers.ts";

const SERVICE_HEADERS = {
  apikey: Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  Authorization: `Bearer ${Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")}`,
  "Content-Type": "application/json",
};

function redirect(platform: Platform, status: "success" | "error", message?: string) {
  const params = new URLSearchParams({ platform, status });
  if (message) params.set("message", message);
  const url = `${APP_REDIRECT_SCHEME}://oauth?${params}`;
  const body = `<!doctype html><meta charset="utf-8"><title>Dayframe</title>
<p>Return to the Dayframe app. <a href="${url}">Open Dayframe</a></p>
<script>location.replace(${JSON.stringify(url)})</script>`;
  return new Response(body, {
    status: 302,
    headers: { Location: url, "Content-Type": "text/html; charset=utf-8" },
  });
}

interface TokenResult {
  accessToken: string;
  refreshToken?: string;
  expiresIn: number;
  raw: Record<string, unknown>;
}

async function exchangeCode(platform: Platform, code: string, redirectUri: string, verifier?: string): Promise<TokenResult> {
  const config = providerConfig(platform);
  const body = new URLSearchParams({
    grant_type: "authorization_code",
    code,
    redirect_uri: redirectUri,
    client_id: config.clientId!,
  });
  const headers: Record<string, string> = { "Content-Type": "application/x-www-form-urlencoded" };
  if (platform === "x") {
    headers["Authorization"] = "Basic " + btoa(`${config.clientId}:${config.clientSecret}`);
    if (verifier) body.set("code_verifier", verifier);
  } else {
    body.set("client_secret", config.clientSecret!);
  }
  const response = await fetch(config.tokenUrl, { method: "POST", headers, body });
  const data = await response.json();
  if (!response.ok) {
    throw new Error(data.error_description ?? data.error_message ?? data.error ?? "Token exchange failed");
  }
  return {
    accessToken: data.access_token,
    refreshToken: data.refresh_token,
    expiresIn: data.expires_in ?? 0,
    raw: data,
  };
}

interface Identity {
  externalAccountId: string;
  handle?: string;
  displayName?: string;
  pageAccessToken?: string;
}

async function fetchIdentity(platform: Platform, token: string): Promise<Identity> {
  const config = providerConfig(platform);
  if (platform === "facebook") {
    const response = await fetch(`${config.apiBase}/v21.0/me/accounts?fields=id,name,access_token`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    if (!response.ok) throw new Error(`Could not load Facebook pages (${response.status}).`);
    const data = await response.json();
    if (!data.data || data.data.length === 0) {
      throw new Error("No Facebook Page found. Please ensure your Facebook account manages a Page.");
    }
    const page = data.data[0];
    return {
      externalAccountId: page.id,
      displayName: page.name,
      handle: page.name,
      pageAccessToken: page.access_token,
    };
  }
  if (platform === "x") {
    const response = await fetch(`${config.apiBase}/2/users/me`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    if (!response.ok) throw new Error(`Could not load the X account (${response.status}).`);
    const { data } = await response.json();
    return { externalAccountId: data.id, handle: data.username, displayName: data.name };
  }
  if (platform === "linkedin") {
    const response = await fetch(`${config.apiBase}/v2/userinfo`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    if (!response.ok) throw new Error(`Could not load the LinkedIn account (${response.status}).`);
    const data = await response.json();
    return { externalAccountId: data.sub, displayName: data.name };
  }
  // Instagram (Business Login): /me returns the professional account.
  const response = await fetch(`${config.apiBase}/v23.0/me?fields=user_id,username,name`, {
    headers: { Authorization: `Bearer ${token}` },
  });
  if (!response.ok) throw new Error(`Could not load the Instagram account (${response.status}).`);
  const data = await response.json();
  return { externalAccountId: data.user_id ?? data.id, handle: data.username, displayName: data.name };
}

async function longLivedInstagramToken(shortLived: string): Promise<{ token: string; expiresIn: number }> {
  const config = providerConfig("instagram");
  const response = await fetch(
    `${config.apiBase}/access_token?grant_type=ig_exchange_token&client_secret=${config.clientSecret}` +
      `&access_token=${encodeURIComponent(shortLived)}`,
  );
  const data = await response.json();
  if (!response.ok) return { token: shortLived, expiresIn: 3600 };
  return { token: data.access_token, expiresIn: data.expires_in ?? 60 * 86_400 };
}

async function storeChannel(
  userId: string,
  platform: Platform,
  identity: Identity,
  token: TokenResult,
): Promise<void> {
  // 1. Vault secret. Use page access token for Facebook if available.
  const accessToken = identity.pageAccessToken ?? token.accessToken;
  const expiresAt = new Date(Date.now() + (identity.pageAccessToken ? 365 * 86_400 * 1000 : token.expiresIn * 1000)).toISOString();
  const secret = JSON.stringify({
    access_token: accessToken,
    refresh_token: token.refreshToken ?? null,
    expires_at: expiresAt,
  });
  const secretResponse = await fetch(`${Deno.env.get("SUPABASE_URL")}/rest/v1/rpc/store_token_secret`, {
    method: "POST",
    headers: SERVICE_HEADERS,
    body: JSON.stringify({ p_secret: secret }),
  });
  if (!secretResponse.ok) throw new Error("Could not store the access token.");
  const secretId = (await secretResponse.json()) as string;

  // 2. Upsert the channel on (user_id, platform, external_account_id).
  const row = {
    user_id: userId,
    platform,
    external_account_id: identity.externalAccountId,
    handle: identity.handle ?? null,
    display_name: identity.displayName ?? null,
    status: "connected",
    token_secret_id: secretId,
    token_expires_at: expiresAt,
  };
  const channelResponse = await fetch(
    `${Deno.env.get("SUPABASE_URL")}/rest/v1/channels?on_conflict=user_id,platform,external_account_id`,
    {
      method: "POST",
      headers: { ...SERVICE_HEADERS, Prefer: "resolution=merge-duplicates,return=minimal" },
      body: JSON.stringify(row),
    },
  );
  if (!channelResponse.ok) {
    throw new Error(`Could not save the channel (${channelResponse.status}).`);
  }
}

Deno.serve(async (req) => {
  const url = new URL(req.url);
  const state = url.searchParams.get("state");
  const code = url.searchParams.get("code");
  const payload = state ? await verifyState(state) : null;
  if (!payload) return redirect("instagram", "error", "The sign-in link expired. Try connecting again.");
  const platform = payload.platform;

  if (url.searchParams.get("error") || !code) {
    const reason = url.searchParams.get("error_description") ?? url.searchParams.get("error") ?? "cancelled";
    if (reason === "cancelled" || reason === "user_cancelled_login") {
      return redirect(platform, "error", "cancelled");
    }
    return redirect(platform, "error", `The provider denied access: ${reason}`);
  }

  try {
    const redirectUri = callbackUrl(req, platform);
    let token = await exchangeCode(platform, code, redirectUri, payload.codeVerifier);
    if (platform === "instagram") {
      const longLived = await longLivedInstagramToken(token.accessToken);
      token = { ...token, accessToken: longLived.token, expiresIn: longLived.expiresIn };
    }
    const identity = await fetchIdentity(platform, token.accessToken);
    await storeChannel(payload.userId, platform, identity, token);
    return redirect(platform, "success");
  } catch (error) {
    return redirect(platform, "error", error instanceof Error ? error.message : "Connection failed.");
  }
});
