// refresh-metrics: invoked by pg_cron hourly (service-role Bearer only).
// For every connected channel: pulls follower counts into `metrics_daily` and
// per-post metrics for published targets into `post_metrics`.
// LinkedIn exposes no member-level analytics without partner approval, so its
// numbers stay zero (docs/integrations/linkedin.md).
import { providerConfig, type Platform } from "../_shared/providers.ts";
import { ensureFreshToken, expireChannel, requireServiceRole, SERVICE_HEADERS, SUPABASE_URL } from "../_shared/backend.ts";

interface ChannelRow {
  id: string;
  user_id: string;
  platform: Platform;
  external_account_id: string;
}

interface MetricsRow {
  channel_id: string;
  day: string;
  followers: number | null;
  reach: number | null;
  engagement: number | null;
  clicks: number | null;
}

function dayKey(iso: string | number | Date): string {
  return new Date(iso).toISOString().slice(0, 10);
}

async function upsertDaily(channelId: string, userId: string, day: string, patch: { followers?: number; reach?: number; engagement?: number; clicks?: number }) {
  const row: MetricsRow & { user_id: string } = {
    channel_id: channelId,
    user_id: userId,
    day,
    followers: patch.followers ?? null,
    reach: patch.reach ?? null,
    engagement: patch.engagement ?? null,
    clicks: patch.clicks ?? null,
  };
  const response = await fetch(
    `${SUPABASE_URL}/rest/v1/metrics_daily?on_conflict=channel_id,day`,
    { method: "POST", headers: { ...SERVICE_HEADERS, Prefer: "resolution=merge-duplicates" }, body: JSON.stringify(row) },
  );
  if (!response.ok) throw new Error(`metrics_daily upsert failed (${response.status})`);
}

async function upsertPostMetric(targetId: string, userId: string, metrics: { reach: number; likes: number; comments: number; shares: number; clicks: number }) {
  await fetch(
    `${SUPABASE_URL}/rest/v1/post_metrics?on_conflict=post_target_id`,
    { method: "POST", headers: { ...SERVICE_HEADERS, Prefer: "resolution=merge-duplicates" }, body: JSON.stringify({
      post_target_id: targetId,
      user_id: userId,
      reach: metrics.reach,
      likes: metrics.likes,
      comments: metrics.comments,
      shares: metrics.shares,
      clicks: metrics.clicks,
      fetched_at: new Date().toISOString(),
    }) },
  );
}

// ── X ────────────────────────────────────────────────────────────────────────
// Followers: /2/users/me?user.fields=public_metrics. Per-post metrics come
// from the author timeline and are matched by tweet id.

interface XTweet {
  id: string;
  created_at: string;
  public_metrics?: { impression_count?: number; like_count?: number; reply_count?: number; retweet_count?: number; bookmark_count?: number };
}

async function refreshX(channel: ChannelRow, token: string): Promise<number> {
  const base = providerConfig("x").apiBase;
  let writes = 0;

  const me = await fetch(`${base}/2/users/me?user.fields=public_metrics`, {
    headers: { Authorization: `Bearer ${token}` },
  }).then(async (r) => {
    if (!r.ok) throw new Error(`X me failed (${r.status})`);
    return r.json();
  });
  const followers = me.data?.public_metrics?.followers_count ?? 0;
  await upsertDaily(channel.id, channel.user_id, dayKey(Date.now()), { followers, reach: 0, engagement: 0, clicks: 0 });
  writes++;

  const timeline = await fetch(`${base}/2/users/${channel.external_account_id}/tweets?max_results=100&tweet.fields=public_metrics,created_at`, {
    headers: { Authorization: `Bearer ${token}` },
  }).then(async (r) => {
    if (!r.ok) throw new Error(`X timeline failed (${r.status})`);
    return r.json();
  });
  const tweets = (timeline.data ?? []) as XTweet[];

  const daily = new Map<string, { reach: number; engagement: number }>();
  for (const tweet of tweets) {
    const m = tweet.public_metrics ?? {};
    const reach = m.impression_count ?? 0;
    const engagement = (m.like_count ?? 0) + (m.reply_count ?? 0) + (m.retweet_count ?? 0);
    const day = dayKey(tweet.created_at);
    const bucket = daily.get(day) ?? { reach: 0, engagement: 0 };
    bucket.reach += reach;
    bucket.engagement += engagement;
    daily.set(day, bucket);
    await upsertPostMetricByExternalId(channel, tweet.id, {
      reach,
      likes: m.like_count ?? 0,
      comments: m.reply_count ?? 0,
      shares: m.retweet_count ?? 0,
      clicks: 0,
    });
    writes++;
  }
  for (const [day, bucket] of daily) {
    await upsertDaily(channel.id, channel.user_id, day, { reach: bucket.reach, engagement: bucket.engagement });
    writes++;
  }
  return writes;
}

async function upsertPostMetricByExternalId(
  channel: ChannelRow,
  externalId: string,
  metrics: { reach: number; likes: number; comments: number; shares: number; clicks: number },
) {
  const rows = await fetch(
    `${SUPABASE_URL}/rest/v1/post_targets?external_post_id=eq.${externalId}&channel_id=eq.${channel.id}&select=id,user_id`,
    { headers: SERVICE_HEADERS },
  ).then((r) => r.json());
  for (const row of rows) {
    await upsertPostMetric(row.id, row.user_id, metrics);
  }
}

// ── Instagram ────────────────────────────────────────────────────────────────
// Followers: /{ig-id}?fields=followers_count. Per-media insights give reach;
// likes/comments come from media fields. Grouped per media publish day.

async function refreshInstagram(channel: ChannelRow, token: string): Promise<number> {
  const base = providerConfig("instagram").apiBase;
  let writes = 0;

  const profile = await fetch(`${base}/v23.0/me?fields=followers_count`, {
    headers: { Authorization: `Bearer ${token}` },
  }).then(async (r) => {
    if (!r.ok) throw new Error(`IG profile failed (${r.status})`);
    return r.json();
  });
  await upsertDaily(channel.id, channel.user_id, dayKey(Date.now()), { followers: profile.followers_count ?? 0, reach: 0, engagement: 0, clicks: 0 });
  writes++;

  const media = await fetch(`${base}/v23.0/me/media?fields=id,timestamp&limit=50`, {
    headers: { Authorization: `Bearer ${token}` },
  }).then(async (r) => {
    if (!r.ok) throw new Error(`IG media failed (${r.status})`);
    return r.json();
  });

  const daily = new Map<string, { reach: number; engagement: number }>();
  for (const item of (media.data ?? []) as { id: string; timestamp: string }[]) {
    const [insights, fields] = await Promise.all([
      fetch(`${base}/v23.0/${item.id}/insights?metric=impressions`, { headers: { Authorization: `Bearer ${token}` } }).then((r) => (r.ok ? r.json() : { data: [] })),
      fetch(`${base}/v23.0/${item.id}?fields=like_count,comments_count`, { headers: { Authorization: `Bearer ${token}` } }).then((r) => (r.ok ? r.json() : {})),
    ]);
    const reach = (insights.data ?? []).find((m: { name: string }) => m.name === "impressions")?.values?.[0]?.value ?? 0;
    const likes = fields.like_count ?? 0;
    const comments = fields.comments_count ?? 0;
    const day = dayKey(item.timestamp);
    const bucket = daily.get(day) ?? { reach: 0, engagement: 0 };
    bucket.reach += reach;
    bucket.engagement += likes + comments;
    daily.set(day, bucket);
    await upsertPostMetricByExternalId(channel, item.id, { reach, likes, comments, shares: 0, clicks: 0 });
    writes++;
  }
  for (const [day, bucket] of daily) {
    await upsertDaily(channel.id, channel.user_id, day, { reach: bucket.reach, engagement: bucket.engagement });
    writes++;
  }
  return writes;
}

// ── LinkedIn: no member-level analytics without partner approval ─────────────
async function refreshLinkedIn(_channel: ChannelRow, _token: string): Promise<number> {
  return 0;
}

Deno.serve(async (req) => {
  if (!requireServiceRole(req)) {
    return Response.json({ code: "unauthorized", message: "Service role required." }, { status: 401 });
  }

  const channels: ChannelRow[] = await fetch(
    `${SUPABASE_URL}/rest/v1/channels?status=eq.connected&select=id,user_id,platform,external_account_id`,
    { headers: SERVICE_HEADERS },
  ).then((r) => r.json());

  let refreshed = 0;
  let skipped = 0;
  for (const channel of channels) {
    try {
      const bundle = await ensureFreshToken(channel.platform, channel.id);
      if (!bundle) { skipped++; continue; }
      if (channel.platform === "x") await refreshX(channel, bundle.accessToken);
      else if (channel.platform === "instagram") await refreshInstagram(channel, bundle.accessToken);
      else await refreshLinkedIn(channel, bundle.accessToken);
      refreshed++;
    } catch (error) {
      const message = String(error);
      if (message.includes("(401)")) await expireChannel(channel.id);
      skipped++;
    }
  }

  return Response.json({ channels: channels.length, refreshed, skipped });
});
