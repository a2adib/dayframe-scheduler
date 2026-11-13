# TRD: Dayframe

## 1. Architecture
```
iPhone app (SwiftUI)
   │  supabase-swift (Auth, PostgREST, Storage, Realtime)
   ▼
Supabase
 ├─ Auth (Apple, Google, email)
 ├─ Postgres + RLS (see Schema.md)
 ├─ Storage (media bucket)
 ├─ Edge Functions (Deno/TypeScript)
 │    oauth-start, oauth-callback, publish-due,
 │    refresh-metrics, ai-assist, send-push
 └─ pg_cron (every minute → publish-due)
        │
        ▼
Social platform APIs (Instagram/Facebook Graph, X, LinkedIn, TikTok, YouTube)
```
The app never holds platform tokens. All publishing and token handling runs server-side.

## 2. Client Stack
- Swift 5.9+, SwiftUI, iOS 17+, MVVM with `@Observable`
- NavigationStack, TabView, Swift Charts
- Packages: `supabase-swift` only (plus none other unless justified in Plan.md)
- StoreKit 2 for subscriptions
- Local cache: SwiftData for Queue/Calendar read cache and offline drafts

### Layers
```
Views → ViewModels → Repositories (protocols) → Services (Supabase, Storage, Auth)
```
- Repositories have protocol + `Mock` and `Live` implementations so the UI runs on mock data first (Plan Phase 2) and swaps to Live in Phase 4.
- Dependency injection via an `AppEnvironment` container.

## 3. Backend Functions
| Function | Trigger | Purpose |
|----------|---------|---------|
| oauth-start | App | Build provider auth URL with signed `state` |
| oauth-callback | Provider redirect | Exchange code, store tokens in Vault, upsert channel |
| publish-due | pg_cron each minute | Claim due targets, publish, update status, schedule retries |
| refresh-metrics | Cron (hourly/daily) | Pull followers, reach, engagement into metrics tables |
| ai-assist | App | Optional caption suggestions (rate limited) |
| send-push | Internal | APNs notifications for published / failed |

## 4. Scheduling Engine
1. `claim_due_targets(limit)` selects `post_targets` where status = `scheduled` and `scheduled_at <= now()` using `FOR UPDATE SKIP LOCKED`, sets status = `publishing`.
2. For each target: load channel token from Vault, upload media if needed, call platform publish API.
3. Success: status = `published`, store `external_post_id`, `published_at`.
4. Failure: increment `attempts`; if attempts < 3, status back to `scheduled` with `next_attempt_at` using exponential backoff (1, 5, 15 min); else `failed` and push notification.
5. Idempotency: client sends an `idempotency_key` when scheduling; unique index prevents duplicates.
6. "Add to queue" resolves the next free slot server-side from `posting_slots` in the user's time zone.

## 5. Security
- Row Level Security on every table: `user_id = auth.uid()`
- Platform tokens encrypted (Supabase Vault), never returned to the client
- OAuth `state` signed and short-lived; PKCE where supported
- Service-role key only inside Edge Functions; never in the app
- Secrets in environment variables, not in the repo; `.env.example` committed
- Account deletion: revoke tokens, delete storage objects and rows
- Privacy: App Store privacy labels and a privacy policy URL

## 6. Error Handling and Observability
- Typed `AppError` in the app with user-friendly messages
- Edge Functions return structured errors `{code, message}`
- Log publish attempts (no secrets) in `post_targets.error_message` and a `publish_logs` view
- Basic crash/analytics via Apple's tools in v1

## 7. Performance Targets
- Queue first paint under 1s from cache; network refresh under 2s on 4G
- Composer input latency under 16ms (no heavy work on main thread)
- Media upload with progress and resumable retry
- Pagination: 30 posts per page, cursor by `scheduled_at`

## 8. Testing
- Unit tests: ViewModels, scheduling/slot logic, character-limit rules, date handling across time zones
- Integration: repository against a local Supabase instance
- Edge Function tests with mocked platform APIs
- UI tests: onboarding, auth, create and schedule post, reschedule, delete
- Snapshot previews for Light/Dark and Dynamic Type

## 9. CI/CD
- GitHub Actions: build, test, SwiftLint on each PR
- Fastlane (or Xcode Cloud) to TestFlight on main
- Supabase migrations in `/supabase/migrations`, applied via CLI

## 10. Environment Variables
`SUPABASE_URL`, `SUPABASE_ANON_KEY` (app); `SUPABASE_SERVICE_ROLE_KEY`, `META_APP_ID/SECRET`, `X_CLIENT_ID/SECRET`, `LINKEDIN_CLIENT_ID/SECRET`, `TIKTOK_CLIENT_KEY/SECRET`, `GOOGLE_CLIENT_ID/SECRET`, `APNS_KEY_ID`, `APNS_TEAM_ID`, `APNS_PRIVATE_KEY` (functions).

## 11. Platform Constraints to Verify Before Building Each Integration
Check each provider's current docs for: publishing permissions and app review, media formats and size limits, rate limits, token lifetimes, and whether scheduled posting is native or must be simulated by Dayframe. Record findings in `docs/integrations/<platform>.md`.

## 12. Related Docs
Schema.md for tables, AppFLOW.md for lifecycle, Plan.md for build order.
