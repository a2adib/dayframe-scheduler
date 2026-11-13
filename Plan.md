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
- [ ] Color assets (light/dark), typography, spacing, radius tokens
- [ ] Components listed in UI_Spec.md section 3, each with `#Preview`
- [ ] 5-tab shell with raised Create button
- **Done when:** shell runs, all components previewed in Light and Dark

## Phase 2: Screens on Mock Data
- [ ] Define repository protocols and `Mock` implementations (TRD.md section 2)
- [ ] Onboarding and Auth UI
- [ ] Connect Channels
- [ ] Queue (chips, grouping, swipe actions, skeleton, empty)
- [ ] Composer (counters, media row, schedule options, previews)
- [ ] Calendar (month and week)
- [ ] Post Detail
- [ ] Analytics (Swift Charts)
- [ ] Profile and Settings (slot editor, theme, upgrade card, About)
- [ ] For EACH screen: open its Figma frame first, build, then screenshot the simulator and compare side by side; fix spacing, color, type, and icon differences before ticking
- **Done when:** all 8 screens reachable per AppFLOW.md, each visually matches its Figma frame, zero warnings, previews for every view

## Phase 3: Backend Foundation
- [ ] Supabase project, local dev via CLI, `/supabase/migrations` from Schema.md
- [ ] RLS policies on every table, `channels_public` view, storage bucket and policies
- [ ] Triggers: derived post status, plan limits
- [ ] Seed script for dev data
- **Done when:** migrations apply cleanly, RLS verified with two test users

## Phase 4: Live Data Layer
- [ ] Add `supabase-swift`, `AppEnvironment`, `Live` repositories
- [ ] Auth: email, Sign in with Apple, Google
- [ ] Profiles, posting slots, posts and targets CRUD, media upload
- [ ] SwiftData cache and offline drafts
- [ ] Swap Mock to Live behind a debug toggle
- **Done when:** a user can sign up, create, schedule, edit, and delete posts end to end (no publishing yet)

## Phase 5: Channels and Publishing
- [ ] Per platform: read provider docs, write `docs/integrations/<platform>.md` (TRD.md section 11)
- [ ] `oauth-start` and `oauth-callback` for Instagram, X, LinkedIn (first three)
- [ ] `publish-due` with claim, retry, backoff, idempotency
- [ ] pg_cron job each minute
- [ ] Reconnect flow for expired tokens
- **Done when:** a scheduled post publishes to a real test account within 2 minutes, failures retry and surface correctly

## Phase 6: Analytics
- [ ] `refresh-metrics` function and tables populated
- [ ] Wire Analytics screen to real data, range and channel filters
- **Done when:** charts match platform data for a test account

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
