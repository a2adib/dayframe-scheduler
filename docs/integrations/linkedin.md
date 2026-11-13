# LinkedIn Integration

Sources: LinkedIn Posts API guides and Microsoft Learn "Refresh Tokens with OAuth 2.0" (2026).

## OAuth 2.0
- Authorization: `https://www.linkedin.com/oauth/v2/authorization` with `response_type=code`,
  `client_id`, `redirect_uri` (exact match), `scope`, `state`. PKCE is supported and sent.
- Token exchange / refresh: `POST https://www.linkedin.com/oauth/v2/accessToken`
  (`application/x-www-form-urlencoded`, `client_id`, `client_secret`, code / refresh_token).
- Scopes used: `openid` `profile` `w_member_social` (`w_member_social` is required for posting
  as the member; without it every post returns 403).
- Access tokens: **60 days**. Programmatic **refresh tokens (365 days)** are only granted to
  approved partner apps ("1P/3P refresh tokens" product); most apps must re-prompt the member.
  Dayframe stores `expires_in`, shows the Reconnect badge near expiry (AppFLOW §3), and tries
  the refresh flow when a refresh token is present.

## App setup
- App on developer.linkedin.com with the **"Share on LinkedIn"** product approved
  (Standard/Community Management tier). Redirect URL = `oauth-callback` function URL.
- Posting as a member uses `author = urn:li:person:{member_urn}`; Page posting would need
  `w_organization_social` (later phase).

## Publishing
- `POST https://api.linkedin.com/rest/posts` with headers `Authorization: Bearer <token>`,
  `LinkedIn-Version: 202401` (or newer), `Content-Type: application/json`, and body:
  ```json
  {
    "author": "urn:li:person:{urn}",
    "commentary": "<post text>",
    "visibility": "PUBLIC",
    "distribution": {"feedDistribution": "MAIN_FEED", "targetEntities": [], "thirdPartyDistributionChannels": []},
    "lifecycleState": "PUBLISHED",
    "isReshareDisabledByAuthor": false
  }
  ```
- Response `X-RestLi-Id` header carries the new post URN → stored as `external_post_id`.
- Member URN resolved at connect time via `GET /v2/userinfo` (`sub` claim) and stored as the
  channel's `external_account_id`.

## Media (images)
- Register image: `POST /rest/actions` … current flow is
  `POST https://api.linkedin.com/rest/actions?action=registerUpload` style via
  `POST /rest/posts` with `content.media` after an `images` upload:
  1. `POST /rest/images?action=initializeUpload` → upload URL + image URN.
  2. `PUT` the bytes to the upload URL.
  3. Reference the image URN in the post's `content.media[].id`.
- Phase 5 scope: single image per LinkedIn post (first media asset of the Dayframe post).

## Rate limits
- Posts API: **~100 calls/day per member** (throttled at app level too: 500/day for standard
  apps). 429 responses include `Retry-After` — treated as retryable with backoff.

## Errors and retry policy
- 401 (expired token) → refresh if possible; otherwise channel `expired` + reconnect badge.
- 403 (missing `w_member_social` or product not approved) → permanent `failed` with a
  message pointing at the app's LinkedIn product config.
- 422/400 (validation) → permanent `failed`.
- 429/5xx → retryable (Dayframe backoff 1/5/15 min, max 3 attempts).

## Scheduling
- The Posts API has **no native scheduling** — Dayframe simulates it: `publish-due` fires at
  `scheduled_at` and calls the API immediately (TRD §4).

## Env vars (functions)
`LINKEDIN_CLIENT_ID`, `LINKEDIN_CLIENT_SECRET`, optional `LINKEDIN_API_BASE` override for
local testing.
