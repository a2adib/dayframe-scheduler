// publish-due: invoked by pg_cron every minute (service-role Bearer only).
// Claims due targets with SKIP LOCKED, publishes to each platform, and applies
// the retry/backoff policy (1/5/15 min, max 3 attempts). Permanent failures
// mark the target failed; expired tokens flip the channel to `expired`.
import { providerConfig, type Platform } from "../_shared/providers.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const SERVICE_HEADERS = {
  apikey: SERVICE_KEY,
  Authorization: `Bearer ${SERVICE_KEY}`,
  "Content-Type": "application/json",
};

const BACKOFF_MINUTES = [1, 5, 15];
const MAX_ATTEMPTS = 3;

interface ClaimedTarget {
  target_id: string;
  post_id: string;
  user_id: string;
  channel_id: string;
  platform: Platform;
  body: string;
  body_override: string | null;
  attempts: number;
  media: { path: string; kind: "image" | "video" }[];
}

interface StoredToken {
  access_token: string;
  refresh_token: string | null;
  expires_at: string;
}

interface TokenBundle {
  accessToken: string;
  refreshToken: string | null;
  expiresAt: number;
  secretId: string; // current secret id; changes after a refresh
}

class PublishError extends Error {
  constructor(message: string, readonly status: number) {
    super(message);
  }
}

async function rpc<T>(name: string, args: Record<string, unknown>): Promise<T> {
  const response = await fetch(`${SUPABASE_URL}/rest/v1/rpc/${name}`, {
    method: "POST",
    headers: SERVICE_HEADERS,
    body: JSON.stringify(args),
  });
  if (!response.ok) throw new Error(`rpc ${name} failed: ${response.status}`);
  return response.json() as Promise<T>;
}

function tokenEndpoint(platform: Platform): string {
  const base = providerConfig(platform).apiBase;
  return platform === "x" ? `${base}/2/oauth2/token` : platform === "linkedin" ? `${base}/oauth/v2/accessToken` : `${base}/access_token`;
}

async function refreshToken(platform: Platform, refresh: string): Promise<{ accessToken: string; refreshToken: string | null; expiresIn: number }> {
  const config = providerConfig(platform);
  const body = new URLSearchParams({ grant_type: "refresh_token", refresh_token: refresh });
  const headers: Record<string, string> = { "Content-Type": "application/x-www-form-urlencoded" };
  if (platform === "x") {
    headers["Authorization"] = "Basic " + btoa(`${config.clientId}:${config.clientSecret}`);
    body.set("client_id", config.clientId!);
  } else {
    body.set("client_id", config.clientId!);
    body.set("client_secret", config.clientSecret!);
  }
  const response = await fetch(tokenEndpoint(platform), { method: "POST", headers, body });
  const data = await response.json();
  if (!response.ok) throw new PublishError(`Token refresh failed: ${data.error ?? response.status}`, 401);
  return { accessToken: data.access_token, refreshToken: data.refresh_token ?? refresh, expiresIn: data.expires_in ?? 3600 };
}

async function loadToken(target: ClaimedTarget): Promise<TokenBundle | null> {
  const channels = await fetch(
    `${SUPABASE_URL}/rest/v1/channels?id=eq.${target.channel_id}&select=id,token_secret_id,token_expires_at,status`,
    { headers: SERVICE_HEADERS },
  ).then((r) => r.json());
  const channel = channels[0];
  if (!channel?.token_secret_id) return null;
  const secret = await rpc<string>("read_token_secret", { p_secret_id: channel.token_secret_id });
  const parsed = JSON.parse(secret) as StoredToken;
  return { accessToken: parsed.access_token, refreshToken: parsed.refresh_token, expiresAt: Date.parse(parsed.expires_at), secretId: channel.token_secret_id };
}

/// Persists a refreshed token: new vault secret + channel row update.
async function saveRefreshedToken(channelId: string, bundle: TokenBundle, refreshed: { accessToken: string; refreshToken: string | null; expiresIn: number }): Promise<string> {
  const expiresAt = new Date(Date.now() + refreshed.expiresIn * 1000).toISOString();
  const newSecretId = await rpc<string>("store_token_secret", {
    p_secret: JSON.stringify({ access_token: refreshed.accessToken, refresh_token: refreshed.refreshToken, expires_at: expiresAt }),
  });
  await fetch(`${SUPABASE_URL}/rest/v1/channels?id=eq.${channelId}`, {
    method: "PATCH",
    headers: SERVICE_HEADERS,
    body: JSON.stringify({ token_secret_id: newSecretId, token_expires_at: expiresAt, status: "connected" }),
  });
  return newSecretId;
}

/// X tokens live 2 h, Instagram/LinkedIn 60 days: refresh well before expiry.
async function ensureFreshToken(target: ClaimedTarget): Promise<TokenBundle | null> {
  const bundle = await loadToken(target);
  if (!bundle) return null;
  const refreshWindowMs = target.platform === "x" ? 30 * 60 * 1000 : 7 * 86_400 * 1000;
  if (bundle.expiresAt - Date.now() > refreshWindowMs) return bundle;
  if (!bundle.refreshToken) return bundle; // nothing to refresh with; try as-is
  try {
    const refreshed = await refreshToken(target.platform, bundle.refreshToken);
    bundle.accessToken = refreshed.accessToken;
    bundle.refreshToken = refreshed.refreshToken;
    bundle.expiresAt = Date.now() + refreshed.expiresIn * 1000;
    bundle.secretId = await saveRefreshedToken(target.channel_id, bundle, refreshed);
  } catch {
    // Fall through: the publish attempt surfaces the auth error properly.
  }
  return bundle;
}

/// Signed URLs for private storage media (Instagram requires a public URL).
async function signedMediaUrls(paths: string[]): Promise<Map<string, string>> {
  const result = new Map<string, string>();
  if (paths.length === 0) return result;
  const response = await fetch(`${SUPABASE_URL}/storage/v1/object/sign/media`, {
    method: "POST",
    headers: SERVICE_HEADERS,
    body: JSON.stringify({ expiresIn: 7 * 86_400, paths }),
  });
  if (!response.ok) throw new Error(`Could not sign media URLs: ${response.status}`);
  const data = await response.json() as { signedURLs?: string[]; signedUrls?: string[] };
  const urls = data.signedURLs ?? data.signedUrls ?? [];
  paths.forEach((path, index) => {
    if (urls[index]) result.set(path, `${SUPABASE_URL}/storage/v1${urls[index]}`);
  });
  return result;
}

// ── Platform publishers ──────────────────────────────────────────────────────

async function publishInstagram(target: ClaimedTarget, token: string): Promise<string> {
  const base = providerConfig("instagram").apiBase;
  if (target.media.filter((m) => m.kind === "image").length === 0) {
    throw new PublishError("Instagram posts need at least one image.", 422);
  }
  const urls = await signedMediaUrls(target.media.map((m) => m.path));
  const caption = encodeURIComponent(target.body_override ?? target.body);

  const containers: string[] = [];
  for (const asset of target.media.filter((m) => m.kind === "image")) {
    const url = urls.get(asset.path);
    if (!url) throw new PublishError("Media URL could not be signed.", 500);
    const response = await fetch(`${base}/v23.0/me/media`, {
      method: "POST",
      headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
      body: JSON.stringify({ image_url: url, caption, is_carousel_item: containers.length > 0 || target.media.filter((m) => m.kind === "image").length > 1 }),
    });
    const data = await response.json();
    if (!response.ok) throw new PublishError(data.error?.message ?? `Container failed (${response.status})`, response.status);
    containers.push(data.id);
  }

  let creationId = containers[0];
  if (containers.length > 1) {
    const response = await fetch(`${base}/v23.0/me/media`, {
      method: "POST",
      headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
      body: JSON.stringify({ media_type: "CAROUSEL", children: containers.join(","), caption }),
    });
    const data = await response.json();
    if (!response.ok) throw new PublishError(data.error?.message ?? `Carousel failed (${response.status})`, response.status);
    creationId = data.id;
  }

  // Wait for the container to finish processing (max 5 polls, 1 s apart).
  for (let poll = 0; poll < 5; poll++) {
    const statusResponse = await fetch(`${base}/v23.0/${creationId}?fields=status_code`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    const status = await statusResponse.json();
    if (status.status_code === "FINISHED" || status.status_code === "PUBLISHED") break;
    if (status.status_code === "ERROR" || status.status_code === "EXPIRED") {
      throw new PublishError("Instagram container processing failed.", 422);
    }
    await new Promise((resolve) => setTimeout(resolve, 1000));
  }

  const publishResponse = await fetch(`${base}/v23.0/me/media_publish`, {
    method: "POST",
    headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
    body: JSON.stringify({ creation_id: creationId }),
  });
  const data = await publishResponse.json();
  if (!publishResponse.ok) throw new PublishError(data.error?.message ?? `Publish failed (${publishResponse.status})`, publishResponse.status);
  return data.id;
}

async function publishX(target: ClaimedTarget, token: string): Promise<string> {
  const base = providerConfig("x").apiBase;
  const payload: Record<string, unknown> = { text: (target.body_override ?? target.body).slice(0, 280) };

  const images = target.media.filter((m) => m.kind === "image");
  if (images.length > 0) {
    const urls = await signedMediaUrls(images.map((m) => m.path));
    const mediaIds: string[] = [];
    for (const asset of images) {
      const url = urls.get(asset.path);
      if (!url) throw new PublishError("Media URL could not be signed.", 500);
      const bytes = await (await fetch(url)).arrayBuffer();
      const form = new FormData();
      form.append("media", new Blob([bytes], { type: "image/jpeg" }), "image.jpg");
      const uploadResponse = await fetch(`${base}/2/media/upload`, {
        method: "POST",
        headers: { Authorization: `Bearer ${token}` },
        body: form,
      });
      const upload = await uploadResponse.json();
      if (!uploadResponse.ok) throw new PublishError(upload.detail ?? `Media upload failed (${uploadResponse.status})`, uploadResponse.status);
      mediaIds.push(upload.data.id);
    }
    payload.media = { media_ids: mediaIds };
  }

  const response = await fetch(`${base}/2/tweets`, {
    method: "POST",
    headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
    body: JSON.stringify(payload),
  });
  const data = await response.json();
  if (!response.ok) {
    throw new PublishError(data.detail ?? data.title ?? `Tweet failed (${response.status})`, response.status);
  }
  return data.data.id;
}

async function publishLinkedIn(target: ClaimedTarget, token: string, memberUrn: string): Promise<string> {
  const base = providerConfig("linkedin").apiBase;
  const headers = {
    Authorization: `Bearer ${token}`,
    "LinkedIn-Version": "202401",
    "Content-Type": "application/json",
    "X-Restli-Protocol-Version": "2.0.0",
  };
  const text = target.body_override ?? target.body;

  const images = target.media.filter((m) => m.kind === "image");
  let content: Record<string, unknown> | undefined;
  if (images.length > 0) {
    const urls = await signedMediaUrls([images[0].path]);
    const url = urls.get(images[0].path);
    if (!url) throw new PublishError("Media URL could not be signed.", 500);
    const initResponse = await fetch(`${base}/rest/images?action=initializeUpload`, {
      method: "POST",
      headers,
      body: JSON.stringify({ initializeUploadRequest: { owner: `urn:li:person:${memberUrn}` } }),
    });
    const init = await initResponse.json();
    if (!initResponse.ok) throw new PublishError(`Image registration failed (${initResponse.status})`, initResponse.status);
    const uploadUrl = init.value.uploadUrl;
    const imageUrn = init.value.image;
    const bytes = await (await fetch(url)).arrayBuffer();
    const putResponse = await fetch(uploadUrl, {
      method: "PUT",
      headers: { "Content-Type": "application/octet-stream" },
      body: bytes,
    });
    if (!putResponse.ok) throw new PublishError(`Image upload failed (${putResponse.status})`, putResponse.status);
    content = { media: { id: imageUrn } };
  }

  const post = {
    author: `urn:li:person:${memberUrn}`,
    commentary: text.slice(0, 3000),
    visibility: "PUBLIC",
    distribution: { feedDistribution: "MAIN_FEED", targetEntities: [], thirdPartyDistributionChannels: [] },
    lifecycleState: "PUBLISHED",
    isReshareDisabledByAuthor: false,
    ...(content ? { content } : {}),
  };
  const response = await fetch(`${base}/rest/posts`, { method: "POST", headers, body: JSON.stringify(post) });
  if (!response.ok) {
    const detail = await response.text();
    throw new PublishError(detail.slice(0, 200) || `LinkedIn post failed (${response.status})`, response.status);
  }
  return response.headers.get("x-restli-id") ?? response.headers.get("X-RestLi-Id") ?? "unknown";
}

/// LinkedIn stores the member URN (from /v2/userinfo sub) as external_account_id.
async function externalAccountId(channelId: string): Promise<string> {
  const rows = await fetch(`${SUPABASE_URL}/rest/v1/channels?id=eq.${channelId}&select=external_account_id`, {
    headers: SERVICE_HEADERS,
  }).then((r) => r.json());
  return rows[0]?.external_account_id ?? "";
}

// ── Result handling ──────────────────────────────────────────────────────────

function isPermanent(status: number): boolean {
  return status === 400 || status === 403 || status === 404 || status === 422;
}

async function markPublished(target: ClaimedTarget, externalId: string): Promise<void> {
  const now = new Date().toISOString();
  await fetch(`${SUPABASE_URL}/rest/v1/post_targets?id=eq.${target.target_id}`, {
    method: "PATCH",
    headers: SERVICE_HEADERS,
    body: JSON.stringify({ status: "published", published_at: now, external_post_id: externalId, error_message: null }),
  });
  await fetch(`${SUPABASE_URL}/rest/v1/posts?id=eq.${target.post_id}&published_at=is.null`, {
    method: "PATCH",
    headers: SERVICE_HEADERS,
    body: JSON.stringify({ published_at: now }),
  });
}

async function markFailed(target: ClaimedTarget, attempts: number, message: string): Promise<void> {
  if (attempts < MAX_ATTEMPTS) {
    const delay = BACKOFF_MINUTES[Math.min(attempts, BACKOFF_MINUTES.length) - 1] ?? 15;
    await fetch(`${SUPABASE_URL}/rest/v1/post_targets?id=eq.${target.target_id}`, {
      method: "PATCH",
      headers: SERVICE_HEADERS,
      body: JSON.stringify({
        status: "scheduled",
        attempts,
        error_message: message.slice(0, 500),
        next_attempt_at: new Date(Date.now() + delay * 60_000).toISOString(),
      }),
    });
  } else {
    await fetch(`${SUPABASE_URL}/rest/v1/post_targets?id=eq.${target.target_id}`, {
      method: "PATCH",
      headers: SERVICE_HEADERS,
      body: JSON.stringify({ status: "failed", attempts, error_message: message.slice(0, 500) }),
    });
  }
}

async function expireChannel(channelId: string): Promise<void> {
  await fetch(`${SUPABASE_URL}/rest/v1/channels?id=eq.${channelId}`, {
    method: "PATCH",
    headers: SERVICE_HEADERS,
    body: JSON.stringify({ status: "expired" }),
  });
}

Deno.serve(async (req) => {
  const auth = req.headers.get("Authorization") ?? "";
  if (auth !== `Bearer ${SERVICE_KEY}`) {
    return Response.json({ code: "unauthorized", message: "Service role required." }, { status: 401 });
  }

  let claimed: ClaimedTarget[];
  try {
    claimed = await rpc<ClaimedTarget[]>("claim_due_targets", { p_limit: 10 });
  } catch (error) {
    return Response.json({ code: "claim_failed", message: String(error) }, { status: 500 });
  }

  let published = 0;
  let retried = 0;
  let failed = 0;

  for (const target of claimed) {
    try {
      const bundle = await ensureFreshToken(target);
      if (!bundle) throw new PublishError("Channel has no stored token.", 401);

      let externalId: string;
      switch (target.platform) {
        case "instagram":
          externalId = await publishInstagram(target, bundle.accessToken);
          break;
        case "x":
          externalId = await publishX(target, bundle.accessToken);
          break;
        case "linkedin":
          externalId = await publishLinkedIn(
            target,
            bundle.accessToken,
            await externalAccountId(target.channel_id),
          );
          break;
      }
      await markPublished(target, externalId);
      published++;
    } catch (error) {
      const status = error instanceof PublishError ? error.status : 500;
      const message = error instanceof Error ? error.message : String(error);
      if (status === 401) await expireChannel(target.channel_id);
      const attempts = target.attempts + 1;
      if (!isPermanent(status) && status !== 401 && attempts < MAX_ATTEMPTS) retried++;
      else failed++;
      await markFailed(target, attempts, message);
    }
  }

  return Response.json({ claimed: claimed.length, published, retried, failed });
});
