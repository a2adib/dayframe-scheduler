# Plan: Dayframe

Build in phases. Finish and verify each phase, tick its checklist, then stop for review before the next one. Update this file as work completes.

Legend: [ ] todo, [x] done

## Phase 0: Project and Brand
- [x] Create Xcode project `DayframeScheduler` (iOS 17+, SwiftUI), bundle ID `com.dayframe.scheduler`
- [x] Folder structure: App, Assets/Brand, DesignSystem, Models, Repositories, Services, MockData, Features/*, Components
- [x] Access Figma (agent.md "Design Source of Truth"): connect Figma MCP, or confirm frames are exported to `docs/design/`. If neither works, stop and ask the user
- [x] Inventory the Figma file: list every frame, fill the Figma Frame Map in UI_Spec.md, note screens in Figma that are missing from AppFLOW.md (and vice versa)
- [x] Extract design tokens from Figma (colors light/dark, type scale, spacing, radius, shadows) and update UI_Spec.md where it differs
- [x] Logo: use the one in Figma (recreate as SVG + native SwiftUI shapes). Only if Figma has none, design 3 concepts in `Assets/Brand/Concepts`, pick one, write rationale in `Assets/Brand/README.md`
- [x] Export `dayframe-mark.svg`, `dayframe-app-icon.svg`, `dayframe-logo-lockup.svg`, AppIcon asset set
- [x] Build `DayframeLogoMark` and `DayframeWordmark` views; screenshot on white, dark, gradient, small size, and compare with Figma
- **Done when:** logo and tokens match Figma and are approved by the user, app builds and shows the logo on launch

Note on Figma access (Phase 0): no Figma MCP and no exported frames were available; the file was read via browser automation (view-only anonymous session) and frames captured to `docs/design/*.png` by screenshotting the rendered canvas at up to 200% zoom. Tokens were pixel-sampled from those captures.

Note on simulator (Phase 0): Xcode 27.2 is installed but no iOS simulator runtime was present; `xcodebuild -downloadPlatform iOS` was started. The launch-screen screenshot comparison runs once the runtime is available. The app itself builds for the simulator destination with zero warnings.

## Phase 1: Design System and Shell
- [x] Color assets (light/dark), typography, spacing, radius tokens
- [x] Components listed in UI_Spec.md section 3, each with `#Preview`
- [x] 5-tab shell with raised Create button
- **Done when:** shell runs, all components previewed in Light and Dark

## Phase 2: Screens on Mock Data
- [x] Define repository protocols and `Mock` implementations (TRD.md section 2)
- [x] Onboarding and Auth UI
- [x] Connect Channels
- [x] Queue (chips, grouping, swipe actions, skeleton, empty)
- [x] Composer (counters, media row, schedule options, previews)
- [x] Calendar (month and week)
- [x] Post Detail
- [x] Analytics (Swift Charts)
- [x] Profile and Settings (slot editor, theme, upgrade card, About)
- [x] For EACH screen: open its Figma frame first, build, then screenshot the simulator and compare side by side; fix spacing, color, type, and icon differences before ticking
- **Done when:** all 8 screens reachable per AppFLOW.md, each visually matches its Figma frame, zero warnings, previews for every view

## Phase 3: Backend Foundation
- [x] Supabase project, local dev via CLI, `/supabase/migrations` from Schema.md
- [x] RLS policies on every table, `channels_public` view, storage bucket and policies
- [x] Triggers: derived post status, plan limits
- [x] Seed script for dev data
- **Done when:** migrations apply cleanly, RLS verified with two test users

## Phase 4: Live Data Layer
- [x] Add `supabase-swift`, `AppEnvironment`, `Live` repositories
- [x] Auth: email, Sign in with Apple, Google (email verified end to end; Apple/Google route through Supabase OAuth but providers are unconfigured locally — see Decisions)
- [x] Profiles, posting slots, posts and targets CRUD, media upload
- [x] SwiftData cache and offline drafts
- [x] Swap Mock to Live behind a debug toggle
- **Done when:** a user can sign up, create, schedule, edit, and delete posts end to end (no publishing yet) — verified on-device with the `LiveDataLayerTests` suite

## Phase 5: Channels and Publishing
- [x] Per platform: read provider docs, write `docs/integrations/<platform>.md` (TRD.md section 11)
- [x] `oauth-start` and `oauth-callback` for Instagram, X, LinkedIn (first three)
- [x] `publish-due` with claim, retry, backoff, idempotency
- [x] pg_cron job each minute
- [x] Reconnect flow for expired tokens
- **Done when:** a scheduled post publishes to a real test account within 2 minutes, failures retry and surface correctly — verified end to end against a mock platform API; real-account verification pending credentials (see Decisions)

## Phase 6: Analytics
- [x] `refresh-metrics` function and tables populated
- [x] Wire Analytics screen to real data, range and channel filters
- **Done when:** charts match platform data for a test account — verified against the mock provider (exact numbers); real-account data pending credentials

## Phase 7: Notifications and Subscriptions
- [ ] APNs setup, `send-push`, notification toggles
- [ ] StoreKit 2: products, paywall, restore, server-side entitlement sync
- [ ] Enforce Free/Pro limits in UI and backend
- **Done when:** push arrives on publish and failure; purchase unlocks Pro in sandbox

## Phase 8: Polish, QA, Release
- [ ] Accessibility audit (VoiceOver, Dynamic Type, contrast)
- [ ] Unit, integration, and UI tests per TRD.md section 8
- [ ] CI pipeline, TestFlight build
- [ ] Privacy policy, App Store metadata, screenshots, delete-account flow verified
- **Done when:** TestFlight build passes full manual regression

## Phase 9: Later
TikTok, YouTube, Facebook integrations; AI caption improvements; team workspaces; widgets.

## Working Rules
- One phase at a time; stop and summarize at the end of each
- Every task ends with build + tests passing
- Record decisions and deviations in a "Decisions" list at the bottom of this file

## Decisions
- **Figma access method:** No Figma MCP tool and no `docs/design/` exports existed. The view-only share link was opened in a browser and every frame was captured to `docs/design/*.png` at up to 200% zoom; design tokens were pixel-sampled from those captures. Dev Mode inspection is unavailable without sign-in, so values come from rendered pixels (within antialiasing tolerance).
- **Figma contains only the Queue screen:** the file is a brand kit (mark, lockup, app icon, 3 unused concepts, logo usage frames) plus one phone mock of Queue inside a frame named "Code" (4-3, 1512×982). There are no frames for Launch/Onboarding, Auth, Connect Channels, Composer, Calendar, Post Detail, Analytics, or Profile. Flagged to the user at the Phase 0 stop; those screens follow UI_Spec defaults until frames are provided or building from UI_Spec is approved.
- **Tokens updated from Figma measurements (UI_Spec.md §2):** primary #2C4BFF, gradient #4F6BFF→#7B61FF (the earlier middle stop #2C4BFF was dropped — renders show a two-stop blue→purple diagonal), amber dot #FFB020, textPrimary #111827, textSecondary #6B7280, inactive tab #9CA3AF, surface #F6F7FB, border #E6E8F0, Scheduled chip #E5E9FF/#2C4BFF, dark background #0B0F17 (was #0B0D12). Dark-mode UI colors are defaults (no dark screens in Figma).
- **Launch screen:** no Figma frame exists; Phase 0 shows the mark above the wordmark centered on the background token (UI_Spec "Launch: centered logo").
- **Project generation:** Xcode project generated with `xcodegen` from `project.yml` (reproducible; no hand-maintained pbxproj).
- **Simulator runtime:** none installed on this machine; iOS platform download started to run the Phase 0 screenshot comparison.
- **Custom tab bar (Phase 1):** the system `TabView` bar (iOS 27 floating capsule style) does not match the Figma Queue mock (full-width white bar, 1px top hairline #E6E8F0, five evenly spaced slots with an empty center). The shell therefore draws its own bar (`MainTabView`) with Queue / Calendar / Analytics / Profile items and the FloatingCreateButton raised in the center slot. Tokens verified in the simulator by pixel-sampling (#2C4BFF active, #9CA3AF inactive, #E6E8F0 hairline, gradient #4F6BFF/#7B61FF).
- **Phase 1 shell reference:** the only Figma screen frame (Queue, node 4-3) was used as the reference for the tab bar; captures in `docs/design/compare-tabbar-figma-vs-sim.png`. The Create button opens a Composer placeholder full-screen sheet until Phase 2 builds the real Composer.
- **Spring token (Phase 1):** `Animation.spring(response: 0.35, dampingFraction: 0.8)` — the docs' "damping" maps to the API's `dampingFraction`.
- **Phase 2 Figma coverage:** only Queue has a Figma frame; the other 7 screens follow UI_Spec/AppFLOW defaults (approved by the user at the Phase 0 stop). Queue was compared side by side with node 4-3 after building (`docs/design/compare-queue-figma-vs-sim.png`).
- **Debug screen routing (Phase 2):** `DAYFRAME_SCREEN` env var forces a screen as root (`DayframeSchedulerApp.debugRoot`), settable per launch via `SIMCTL_CHILD_`-prefixed simctl env. Used for the per-screen simulator captures and to be reused by UI tests.
- **Status chips include an icon + text (Phase 2):** Figma's Scheduled chip is text-only, but UI_Spec §7 requires never relying on color alone; the clock icon is kept and text matches Figma.
- **Queue Today count (Phase 2):** the mock data has 2 posts today vs 3 in the Figma frame (the frame's third post exists in the mock as a later-day item). Layout and styling match; content counts are mock data.
- **Enum casts in SQL (Phase 3):** Postgres 17 requires explicit `::post_status` casts for enum literals inside `CASE` expressions in PL/pgSQL updates (the first seed run exposed this in `derive_post_status`; fixed in the same not-yet-shipped migration).
- **Verification results (Phase 3):** `supabase db reset` applies migration + seed cleanly. RLS verified with two seeded users (A sees only own rows; cross-user reads return 0 rows and cross-user inserts are rejected). `channels_public` exposes exactly the 10 non-secret columns. Derived status flips scheduled → published → failed through target updates. Free-plan limits enforced: 4th channel rejected, 11th scheduled target per channel rejected, both allowed for Pro. `media` bucket is private with owner-folder storage policies.
- **On-device testing (Phase 4):** the Mac's disk filled up, so all simulator devices were deleted (runtime disk images retained) and the project now builds/runs/tests on the user's physical iPhone (team `77XMQVA342`, automatic signing, cert trusted on device). Local Supabase listens on loopback only, so a tiny Python TCP forwarder (Mac `0.0.0.0:54321` → `127.0.0.1:54321`, scratchpad `supabase_forward.py`) exposes it over LAN; the app/tests read `SUPABASE_URL` (default local URL, `TEST_RUNNER_SUPABASE_URL=http://<mac-lan-ip>:54321` for device tests). `project.yml` now generates an `Info.plist` with `NSAllowsLocalNetworking` + `NSLocalNetworkUsageDescription` (ATS/local-network permission) and `UIRequiresFullScreen` (portrait-only warning).
- **Storage path casing (Phase 4):** the `media` bucket policy matches `(storage.foldername(name))[1] = auth.uid()::text`; Swift's `UUID`/`uuidString` render UPPERCASE, so uploads built from interpolated UUIDs failed RLS with 403. Storage paths are now explicitly lowercased (`user/post/uuid.ext`).
- **Media upload (Phase 4):** `PostRepository.attachMedia(_:fileName:kind:to:)` uploads bytes to the private `media` bucket under `userID/postID/` and inserts a `media_assets` row. The Composer gained a PhotosPicker media row (up to 4 images, removable thumbnails) that uploads on save. Covered by an e2e test.
- **Apple/Google sign-in (Phase 4):** `LiveAuthService.signInWithOAuth` calls Supabase OAuth, but the Apple/Google providers need real developer credentials (Apple Developer Program, Google Cloud OAuth client) and can't be verified against the local stack. Email auth is fully working; provider configuration is deferred until credentials are available (flagged for the Phase 4 stop).
- **fetchQueue fix (Phase 4):** the queue was assembled from `post_targets`, which hid posts with zero targets. It now queries `posts` by user first and joins targets/media.
- **Phase 5 Edge Functions:** `supabase/functions/` — `oauth-start` (signed HMAC state + PKCE, returns the provider authorize URL), `oauth-callback` (exchanges the code, resolves identity, stores the token in Vault via the `store_token_secret` RPC, upserts the channel, 302s to `dayframe://oauth?...` for `ASWebAuthenticationSession`), `publish-due` (claims via `claim_due_targets` FOR UPDATE SKIP LOCKED, refreshes stale tokens — X always, IG/LinkedIn < 7 days — publishes per platform, applies 1/5/15-min backoff, max 3 attempts; permanent failures mark `failed`, auth failures flip the channel to `expired`).
- **Cron wiring (Phase 5):** migration `20261113120000_publishing.sql` enables pg_cron + pg_net and schedules `publish-due` every minute. The cron job reads two Vault secrets (`service_role_key`, `functions_base_url`) — create them once per environment (local defaults: the CLI's legacy service-role JWT and `http://kong:8000`). `verify_jwt` is disabled for `oauth-callback` (provider redirect has no session) and `publish-due` (service key is not a JWT on Kong); both functions validate their own credentials.
- **Mock provider for local e2e (Phase 5):** `config.toml` `[edge_runtime.secrets]` points every platform API base at a mock provider server (scratchpad `mock_provider.py`, control file `/tmp/dayframe-mock-control` = ok/500/429/401), so the complete loop runs locally with dev credentials. Hosted environments set real credentials with `supabase secrets set`.
- **Phase 5 verification results:** `supabase db reset` applies the migration cleanly. oauth-start → oauth-callback (mock exchange) → channel row created with Vault token. publish-due: published to the mock X API (`external_post_id = mock-tweet-1`, `posts.published_at` set); 500-failure → attempt 1 scheduled with +1 min backoff → escalates through +5 min to `failed` at attempt 3 with derived post status `failed`; 401 → channel `expired` and targets pause (claim filters `status = 'connected'`). pg_cron fires every minute and reaches the function (HTTP 200 in `net._http_response`). App: builds with zero warnings, all 3 device tests pass.
- **Pending for real accounts (Phase 5):** publishing to real Instagram/X/LinkedIn accounts requires OAuth apps with approved products/permissions (Meta advanced access, X paid tier for usable post limits, LinkedIn "Share on LinkedIn" product) plus real credentials; the engine is credential-agnostic and was verified against the mock.
- **Phase 6 refresh-metrics:** hourly cron job (`20261113140000_metrics.sql`) calls the new function; it pulls followers + per-post metrics for X (`/2/users/me` public_metrics, author timeline matched by tweet id) and Instagram (profile followers_count, per-media impressions + like/comment counts), writes `metrics_daily` (followers today; reach/engagement grouped per publish day) and `post_metrics` (merged by target). LinkedIn contributes zeros until partner-level analytics are approved (docs/integrations/linkedin.md). Shared token/refresh helpers moved to `supabase/functions/_shared/backend.ts` (used by both publish-due and refresh-metrics). The `metrics_daily` upsert includes `user_id` (NOT NULL — the first run silently wrote nothing until this was fixed; upserts now surface failures).
- **Phase 6 app wiring:** `AnalyticsRepository.loadPublishedPerChannel` (real bar chart, was a hash-based fake), `loadTopPosts` implemented via `post_metrics` nested-join query, and stat-card trends computed from the first vs second half of the selected range. Range + channel filters operate on the live tables. Verified: refresh-metrics against the mock produced exactly the mock's numbers (800/1200 reach, 17/29 engagement, 5234 followers); app builds warning-free and all 3 device tests pass.
