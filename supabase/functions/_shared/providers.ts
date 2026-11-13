// Shared provider configuration for the Dayframe Edge Functions.
// Secrets come from function env vars; *_API_BASE overrides exist only for
// local end-to-end testing with a mock provider server (see docs/integrations/).

export type Platform = "instagram" | "x" | "linkedin" | "facebook";

export interface ProviderConfig {
  authorizeUrl: string;
  tokenUrl: string;
  scopes: string;
  apiBase: string;
  clientId?: string;
  clientSecret?: string;
  usesPkce: boolean;
}

export function providerConfig(platform: Platform): ProviderConfig {
  // X and LinkedIn keep their token endpoints on the API host, so overriding
  // the base redirects both; Instagram's token host differs and has its own
  // override. These overrides exist for local end-to-end testing only.
  switch (platform) {
    case "facebook": {
      const apiBase = Deno.env.get("FACEBOOK_API_BASE") ?? "https://graph.facebook.com";
      return {
        authorizeUrl: "https://www.facebook.com/v21.0/dialog/oauth",
        tokenUrl: `${apiBase}/v21.0/oauth/access_token`,
        scopes: "pages_show_list,pages_read_engagement,pages_manage_posts",
        apiBase,
        clientId: Deno.env.get("META_APP_ID"),
        clientSecret: Deno.env.get("META_APP_SECRET"),
        usesPkce: false,
      };
    }
    case "instagram": {
      const apiBase = Deno.env.get("INSTAGRAM_API_BASE") ?? "https://graph.instagram.com";
      return {
        authorizeUrl: "https://www.instagram.com/oauth/authorize",
        tokenUrl: Deno.env.get("INSTAGRAM_TOKEN_URL") ?? "https://api.instagram.com/oauth/access_token",
        scopes: "instagram_business_basic,instagram_business_content_publish",
        apiBase,
        clientId: Deno.env.get("META_APP_ID"),
        clientSecret: Deno.env.get("META_APP_SECRET"),
        usesPkce: false,
      };
    }
    case "x": {
      const apiBase = Deno.env.get("X_API_BASE") ?? "https://api.x.com";
      return {
        authorizeUrl: `${Deno.env.get("X_AUTHORIZE_URL") ?? "https://x.com"}/i/oauth2/authorize`,
        tokenUrl: `${apiBase}/2/oauth2/token`,
        scopes: "tweet.read tweet.write users.read offline.access media.write",
        apiBase,
        clientId: Deno.env.get("X_CLIENT_ID"),
        clientSecret: Deno.env.get("X_CLIENT_SECRET"),
        usesPkce: true,
      };
    }
    case "linkedin": {
      const apiBase = Deno.env.get("LINKEDIN_API_BASE") ?? "https://api.linkedin.com";
      return {
        authorizeUrl: `${Deno.env.get("LINKEDIN_AUTHORIZE_URL") ?? "https://www.linkedin.com"}/oauth/v2/authorization`,
        tokenUrl: `${apiBase}/oauth/v2/accessToken`,
        scopes: "openid profile w_member_social",
        apiBase,
        clientId: Deno.env.get("LINKEDIN_CLIENT_ID"),
        clientSecret: Deno.env.get("LINKEDIN_CLIENT_SECRET"),
        usesPkce: true,
      };
    }
  }
}

export const APP_REDIRECT_SCHEME = "dayframe";

/// The https URL the provider redirects back to (the oauth-callback function).
export function callbackUrl(req: Request, platform: Platform): string {
  const base = Deno.env.get("FUNCTIONS_BASE_URL") ??
    `${new URL(req.url).protocol}//${new URL(req.url).host}`;
  return `${base}/functions/v1/oauth-callback?platform=${platform}`;
}

// ── Signed state (HMAC-SHA256) ────────────────────────────────────────────────

const STATE_TTL_MS = 10 * 60 * 1000;

function b64urlEncode(data: Uint8Array | string): string {
  const bytes = typeof data === "string" ? new TextEncoder().encode(data) : data;
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function b64urlDecode(text: string): Uint8Array {
  const padded = text.replace(/-/g, "+").replace(/_/g, "/");
  const binary = atob(padded + "=".repeat((4 - padded.length % 4) % 4));
  return Uint8Array.from(binary, (c) => c.charCodeAt(0));
}

async function hmacKey(): Promise<CryptoKey> {
  const secret = Deno.env.get("OAUTH_STATE_SECRET") ??
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  return crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign", "verify"],
  );
}

export interface StatePayload {
  userId: string;
  platform: Platform;
  codeVerifier?: string;
  exp: number;
}

export async function signState(payload: StatePayload): Promise<string> {
  const body = b64urlEncode(JSON.stringify(payload));
  const signature = await crypto.subtle.sign("HMAC", await hmacKey(), new TextEncoder().encode(body));
  return `${body}.${b64urlEncode(new Uint8Array(signature))}`;
}

export async function verifyState(state: string): Promise<StatePayload | null> {
  const dot = state.lastIndexOf(".");
  if (dot <= 0) return null;
  const [body, signature] = [state.slice(0, dot), state.slice(dot + 1)];
  try {
    const valid = await crypto.subtle.verify(
      "HMAC",
      await hmacKey(),
      b64urlDecode(signature),
      new TextEncoder().encode(body),
    );
    if (!valid) return null;
    const payload = JSON.parse(new TextDecoder().decode(b64urlDecode(body))) as StatePayload;
    if (payload.exp < Date.now()) return null;
    return payload;
  } catch {
    return null;
  }
}

// ── PKCE ─────────────────────────────────────────────────────────────────────

export function codeVerifier(): string {
  const bytes = crypto.getRandomValues(new Uint8Array(32));
  return b64urlEncode(bytes);
}

export async function codeChallenge(verifier: string): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(verifier));
  return b64urlEncode(new Uint8Array(digest));
}
