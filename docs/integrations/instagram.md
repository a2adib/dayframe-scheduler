# Instagram Integration

Sources: Meta "Content Publishing" guide (developers.facebook.com/documentation/instagram-platform/content-publishing, updated 2026-10-20).

## Account and app requirements
- Target account must be an **Instagram professional account** (Business or Creator).
- Dayframe uses **Instagram API with Instagram Login** (host `graph.instagram.com`) where possible:
  - Permissions: `instagram_business_basic`, `instagram_business_content_publish`.
  - Access level: Advanced Access required for production (Standard works in dev mode with test users).
- Legacy path (Facebook Login for Business) uses `instagram_basic`, `instagram_content_publish`,
  `pages_read_engagement` on `graph.facebook.com`. We build against the unified-login path first.

## OAuth
- Business Login for Instagram, authorization endpoint
  `https://www.instagram.com/oauth/authorize` with `client_id`, `redirect_uri`, `scope`
  (`instagram_business_basic,instagram_business_content_publish`), `response_type=code`.
- Short-lived token exchanged at `https://api.instagram.com/oauth/access_token`
  (`grant_type=authorization_code`), then to long-lived at
  `https://graph.instagram.com/access_token?grant_type=ig_exchange_token`.
- Long-lived tokens are valid **60 days** and are refreshed by calling
  `GET /refresh_access_token?grant_type=ig_refresh_token` — Dayframe refreshes when
  `token_expires_at` is within 7 days.
- Redirect URI must be HTTPS → we point providers at the `oauth-callback` Edge Function,
  which 302s to the `dayframe://` custom scheme for `ASWebAuthenticationSession`.

## Publishing
Instagram **cannot publish text-only posts**. Every post needs media.

1. `POST /v{version}/{ig_user_id}/media` with `image_url` (public URL — Meta fetches it) and
   `caption` → returns a **container id**.
2. Poll `GET /v{version}/{container_id}?fields=status_code` until `FINISHED`
   (recommended once per minute, max 5 minutes). Statuses: EXPIRED, ERROR, FINISHED,
   IN_PROGRESS, PUBLISHED.
3. `POST /v{version}/{ig_user_id}/media_publish` with `creation_id` → returns media id
   (stored as `external_post_id`).

Constraints verified from docs:
- **JPEG only** for images (MPO/JPS unsupported). No filters. Dayframe re-encodes uploads to JPEG.
- Media must be on a **publicly reachable server** at publish time → `publish-due` creates a
  Supabase Storage **signed URL** (7 days) for each attached media asset.
- Carousels: up to 20 children, `media_type=CAROUSEL` + `children=container_id,...`; counts as
  **one post** against the limit.
- Reels/Stories: `media_type=REELS|STORIES` with `video_url` — out of scope for Phase 5.

## Rate limits
- **100 API-published posts per rolling 24 h** per account (enforced at `media_publish`).
- Check usage with `GET /{ig_user_id}/content_publishing_limit`. `publish-due` treats a
  rate-limit error as **retryable** with backoff, unless the daily window is exhausted
  (reschedules to the next day).

## Errors and retry policy
- Permission/eligibility errors (`INSTAGRAM_PLATFORM_API__PERMISSION`, code 9007 etc.) are
  **permanent** → target `failed` immediately with `error_message`.
- Network/5xx/429 are retryable (Dayframe backoff 1/5/15 min, max 3 attempts).
- Expired token (`OAuthException` code 190) → channel set to `expired`, target `failed`,
  reconnect badge shown in app.

## Env vars (functions)
`META_APP_ID`, `META_APP_SECRET`, optional `INSTAGRAM_API_BASE` override for local testing.
