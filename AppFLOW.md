# AppFLOW: Dayframe

## 1. Navigation Map
```
Launch
 ├─ First run  → Onboarding (3 pages) → Auth (Sign in / Sign up)
 └─ Returning  → Auth check → Main TabView

Main TabView
 ├─ Queue      → Post Detail → Edit (Composer)
 ├─ Calendar   → Day list → Post Detail
 ├─ Create     → Composer (full-screen sheet)
 ├─ Analytics  → Top post detail
 └─ Profile    → Connected Channels → Connect Channel
              → Posting Schedule
              → Notifications / Theme / Subscription / About
```

## 2. Core Flows

### 2.1 Onboarding and Auth
1. Launch screen shows logo.
2. First run: 3 onboarding pages (Plan, Schedule, Analyze) with Skip / Next.
3. Auth screen: email + password, Continue with Apple, Continue with Google.
4. On success, if user has 0 channels, route to Connect Channels (skippable). Otherwise go to Queue.
5. Errors: inline message under field; network error shows retry banner.

### 2.2 Connect a Channel
1. Profile or empty Queue → Connect Channels list.
2. Tap Connect on a platform → in-app web auth session (ASWebAuthenticationSession) → platform consent.
3. Backend exchanges the code, stores tokens securely, returns the channel record.
4. Channel appears as Connected with avatar and handle.
5. Failure paths: user cancelled (no change), denied permissions (explain what is missing), plan limit reached (show upgrade sheet).

### 2.3 Create and Schedule a Post
1. Tap center Create button → Composer sheet.
2. Select one or more channels (at least one required).
3. Write text; per-channel character ring updates; over-limit blocks scheduling for that channel.
4. Optionally add media (photo/video), hashtag, emoji, link, AI assist.
5. Choose schedule mode:
   - Add to queue: next free posting slot
   - Custom: date and time picker (must be in the future)
   - Post now
6. Preview tab shows per-platform rendering.
7. Actions: Save draft, or Schedule / Post now.
8. On success: sheet closes, Queue scrolls to the new post, haptic success.
9. Validation errors are shown inline and never lose user input.

### 2.4 Post Lifecycle
```
draft ──schedule──▶ scheduled ──due──▶ publishing ──ok──▶ published
                       ▲                  │
                       │                  └─fail─▶ failed ──retry──▶ scheduled
                       └──reschedule/edit─┘
```
- Each channel target has its own status; the post status is derived (all published = published; any failed = failed; mixed in-progress = publishing).
- Auto retry up to 3 times with backoff before marking failed and notifying.

### 2.5 Queue Management
- Filter chips: All + each connected channel
- Swipe actions: Edit, Duplicate, Delete (confirm)
- Pull to refresh; skeleton on first load
- Empty state: muted logo + "Nothing planned. Frame your day." + Create button

### 2.6 Calendar
- Month view with dots on days that have posts; toggle to week view
- Tap a day → bottom list of that day's posts → tap opens Post Detail
- Tap + on a day pre-fills the Composer's custom date

### 2.7 Analytics
- Range control: 7d / 30d / 90d (90d is Pro)
- Stat cards, reach line chart, posts-per-channel bar chart, top posts list
- Channel filter applies to all widgets
- Empty/low-data state explains data appears after first published posts

### 2.8 Profile and Settings
- Edit posting schedule: choose days and time slots (per channel or all)
- Notification toggles, theme (System / Light / Dark)
- Subscription: upgrade card → paywall → restore purchases
- Logout; Delete account (confirm, removes data and revokes tokens)

## 3. Edge Cases
- Token expired: channel shows "Reconnect" badge; posts for it pause and user is notified
- Offline: show cached Queue read-only; creating a post queues locally and syncs when online
- Time zone change: scheduled times stay at the same absolute instant; UI shows local time
- Plan limit hit: block action, show upgrade sheet, keep draft
- Duplicate submit: idempotency key on schedule requests

## 4. Related Docs
PRD.md, UI_Spec.md, TRD.md, Schema.md, Plan.md
