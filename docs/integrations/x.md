# X (Twitter) Integration

Sources: X docs "OAuth 2.0 Authorization Code Flow with PKCE" (docs.x.com), 2026 developer guides.

## OAuth 2.0 — Authorization Code Flow with PKCE
- Dayframe is a **confidential client** (Web App type; the secret lives only in Edge Functions).
- Authorize URL: `https://x.com/i/oauth2/authorize` with `response_type=code`, `client_id`,
  `redirect_uri` (**exact match** required), `scope`, `state`, `code_challenge` (S256),
  `code_challenge_method=S256`.
- Token exchange / refresh: `POST https://api.x.com/2/oauth2/token`
  (`grant_type=authorization_code` / `refresh_token`, Basic auth with client credentials).
- Scopes used: `tweet.read` `tweet.write` `users.read` `offline.access` `media.write`.
  Without `offline.access` there is **no refresh token**; access tokens live **2 hours**.
  We always request `offline.access` and store the refresh token in Vault.
- The `auth_code` expires **30 seconds** after the redirect — the callback function must
  exchange immediately.

## Publishing
- `POST https://api.x.com/2/tweets` with `{"text": "..."}`, `Authorization: Bearer <token>`.
- Max **280 characters** (already enforced client-side; the Composer blocks over-limit posts).
- `external_post_id` = `data.id` of the response.
- Text-only posts are fully supported — media is optional.

## Media
- `media.write` scope; upload via `POST https://api.x.com/2/media/upload` (simple/chunked),
  attach with `media.media_ids`. JPEG/PNG/GIF/WEBP, video MP4/MOV. Total 5 MB image limit
  (15 MB via chunked), 512 MB video.
- Phase 5 scope: images only, chunked upload for >5 MB files.

## Rate limits (v2, per app + per user)
- `POST /2/tweets`: **17 requests / 24 h** per user at the **Free** tier; Basic ($200/mo) lifts
  this to 3 000 posts / 24 h per user (per-app cap 50 000). Dayframe surfaces the tier's
  error (429 + `x-rate-limit-reset`) as a retryable failure with backoff.
- General per-app cap: 900 requests / 15 min for lookups.

## Token lifecycle and reconnect
- Access token 2 h; refresh via `grant_type=refresh_token` (single-use — store the NEW refresh
  token after every refresh).
- Invalid/revoked token → HTTP 401/403 → channel `expired`, reconnect badge, targets pause
  (AppFLOW §3).
- Refresh is cheap enough that `publish-due` refreshes any token older than 90 minutes before
  publishing.

## Errors and retry policy
- 429 → retryable, honor `x-rate-limit-reset`.
- 401/403 (auth/permission) → permanent: mark `failed`, flip channel to `expired` if token
  invalid.
- 5xx → retryable with Dayframe backoff (1/5/15 min, max 3 attempts).

## Env vars (functions)
`X_CLIENT_ID`, `X_CLIENT_SECRET`, optional `X_API_BASE` override for local testing.
