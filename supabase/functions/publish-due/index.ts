// publish-due: invoked by pg_cron every minute (service-role Bearer only).
// Claims due targets with SKIP LOCKED, publishes to each platform, and applies
// the retry/backoff policy (1/5/15 min, max 3 attempts). Permanent failures
// mark the target failed; expired tokens flip the channel to `expired`.
import { providerConfig, type Platform } from "../_shared/providers.ts";
import { ensureFreshToken, expireChannel, SERVICE_HEADERS, requireServiceRole, signedMediaUrls, SUPABASE_URL } from "../_shared/backend.ts";

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

export class PublishError extends Error {
  constructor(message: string, readonly status: number) {
    super(message);
  }
}

async function publishInstagram(target: ClaimedTarget, token: string): Promise<string> {
  const base = providerConfig("instagram").apiBase;
  if (target.media.filter((m) => m.kind === "image").length === 0) {
    throw new PublishError("Instagram posts need at least one image.", 422);
  }
  const urls = await signedMediaUrls(target.media.map((m) => m.path));
  const caption = encodeURIComponent(target.body_override ?? target.body);
  const imageAssets = target.media.filter((m) => m.kind === "image");

  const containers: string[] = [];
  for (const asset of imageAssets) {
    const url = urls.get(asset.path);
    if (!url) throw new PublishError("Media URL could not be signed.", 500);
    const response = await fetch(`${base}/v23.0/me/media`, {
      method: "POST",
      headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
      body: JSON.stringify({ image_url: url, caption, is_carousel_item: containers.length > 0 || imageAssets.length > 1 }),
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

async function publishFacebook(target: ClaimedTarget, token: string, pageId: string): Promise<string> {
  const base = providerConfig("facebook").apiBase;
  const text = target.body_override ?? target.body;
  const images = target.media.filter((m) => m.kind === "image");

  if (images.length > 0) {
    const urls = await signedMediaUrls([images[0].path]);
    const url = urls.get(images[0].path);
    if (!url) throw new PublishError("Media URL could not be signed.", 500);

    const response = await fetch(`${base}/v21.0/${pageId}/photos`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        url,
        caption: text,
        access_token: token,
      }),
    });
    const data = await response.json();
    if (!response.ok) {
      throw new PublishError(data.error?.message ?? `Facebook photo publish failed (${response.status})`, response.status);
    }
    return data.post_id ?? data.id;
  }

  const response = await fetch(`${base}/v21.0/${pageId}/feed`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      message: text,
      access_token: token,
    }),
  });
  const data = await response.json();
  if (!response.ok) {
    throw new PublishError(data.error?.message ?? `Facebook post failed (${response.status})`, response.status);
  }
  return data.id;
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

Deno.serve(async (req) => {
  if (!requireServiceRole(req)) {
    return Response.json({ code: "unauthorized", message: "Service role required." }, { status: 401 });
  }

  let claimed: ClaimedTarget[];
  try {
    claimed = await fetch(`${SUPABASE_URL}/rest/v1/rpc/claim_due_targets`, {
      method: "POST",
      headers: SERVICE_HEADERS,
      body: JSON.stringify({ p_limit: 10 }),
    }).then(async (r) => {
      if (!r.ok) throw new Error(`claim_due_targets failed: ${r.status}`);
      return r.json();
    });
  } catch (error) {
    return Response.json({ code: "claim_failed", message: String(error) }, { status: 500 });
  }

  let published = 0;
  let retried = 0;
  let failed = 0;

  for (const target of claimed) {
    try {
      const bundle = await ensureFreshToken(target.platform, target.channel_id);
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
        case "facebook":
          externalId = await publishFacebook(
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
