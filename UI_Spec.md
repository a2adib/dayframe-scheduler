# UI_Spec: Dayframe

Design direction: clean, airy, white-dominant, rounded and friendly, in the spirit of Buffer but with fully original branding. Never copy Buffer's logo or assets.

## 0. Figma Is the Visual Source of Truth
Design file: https://www.figma.com/design/I1xQfWCdFc9GgdvWbMoblS/Dayframe---Social-Media-Scheduler-iOS?node-id=4-3

- Everything below is a default starting point. Where Figma differs (colors, type, spacing, radius, icons, layout, copy), **Figma wins**; update this file to match and log the change in Plan.md "Decisions".
- Build order per screen: open the Figma frame, list components, states, spacing, and colors, build, then compare a simulator screenshot to the frame and fix differences.
- Tokens are extracted from Figma first (Plan.md Phase 0), then used everywhere through the design system.
- If the agent cannot read Figma (no MCP, no exported frames in `docs/design/`), it must stop and ask. It must not guess.

### Figma Frame Map (filled in Phase 0)
Source: https://www.figma.com/design/I1xQfWCdFc9GgdvWbMoblS/Dayframe---Social-Media-Scheduler-iOS (view-only link; read via browser automation, anonymous session). The file has one page with 11 top-level frames. **It contains the full brand kit and exactly one app screen (Queue). There are no Figma frames for Launch/Onboarding, Auth, Connect Channels, Composer, Calendar, Post Detail, Analytics, or Profile.**

| Screen | Figma frame name | Node ID | Exported file |
|--------|------------------|---------|---------------|
| Launch / Onboarding | — (not in Figma) | | |
| Auth | — (not in Figma) | | |
| Connect Channels | — (not in Figma) | | |
| Queue (single screen mock inside "Code" frame) | Code | 4-3 | docs/design/figma-queue-1.png, figma-queue-2.png |
| Composer | — (not in Figma) | | |
| Calendar | — (not in Figma) | | |
| Post Detail | — (not in Figma) | | |
| Analytics | — (not in Figma) | | |
| Profile / Settings | — (not in Figma) | | |
| Brand: mark | dayframe-mark (200×200) | 2-2 | docs/design/figma-mark.png |
| Brand: lockup | dayframe-logo-lockup (460×120) | 1-2 | docs/design/figma-lockup.png |
| Brand: app icon | dayframe-app-icon | 2-5 | (in figma-lockup.png view) |
| Brand: logo on white / dark / gradient | logo-on-white / logo-on-dark / logo-on-gradient | 2-22 / 2-23 / 2-24 | docs/design/figma-logo-on-dark.png |
| Brand: logo small sizes | logo-at-small-size | 2-25 | (in figma-code-frame.png view) |
| Brand: unused logo concepts | concept-1-sun-frame / concept-2-time-notch / concept-3-framing-d | 2-10 / 2-13 / 2-18 | — |

Missing-screen decision: the 8 screens without Figma frames follow UI_Spec.md defaults until the user supplies frames (or approves building from UI_Spec). Do not invent layouts silently.

## 1. Brand
- Display name: Dayframe. Tagline: "Frame your day. Schedule your story."
- Logo (as found in Figma, Phase 0): a rounded-square ring stroked with the brand gradient (#4F6BFF top-leading → #7B61FF bottom-trailing), no fill, plus an amber sun dot (#FFB020) floating inside at the upper-right. In the app icon the same mark is white on a full-bleed brand gradient. The wordmark is "Dayframe" in bold rounded type: "Day" #111827, "frame" #2C4BFF. Geometry (200×200 mark frame): outer rounded square inset 11, stroke 28, outer corner radius ~54, dot center (108, 75) r 25.
- Deliverables: `dayframe-mark.svg`, `dayframe-app-icon.svg` (1024), `dayframe-logo-lockup.svg`, AppIcon asset set, SwiftUI `DayframeLogoMark` and `DayframeWordmark` drawn with native Shapes.
- Placement: launch, onboarding p1, auth header, Queue nav bar (small), empty states (muted), loading (pulse), Profile upgrade card (watermark), About.

## 2. Design Tokens (extracted from Figma by pixel-sampling rendered frames, Phase 0)
**Colors (adaptive; Light = measured from the Queue frame, Dark = not present in Figma, defaults kept)**
| Token | Light (measured) | Dark (default) |
|-------|------------------|----------------|
| primary | #2C4BFF (measured: active chip, timeline dots, Scheduled chip text, active tab, "frame" wordmark) | #2C4BFF |
| accent | #7B61FF | #7B61FF |
| success | #22C55E | #22C55E |
| warning | #F59E0B | #F59E0B |
| danger | #EF4444 | #EF4444 |
| background | #FFFFFF | #0B0F17 (measured from logo-on-dark frame; replaces earlier #0B0D12) |
| surface | #F6F7FB (chips, pills, Channels button, avatars) | #151821 |
| border | #E6E8F0 (card border, nav divider, tab hairline, timeline connector) | #232838 |
| textPrimary | #111827 (nav title, section headers, body) | #F2F4F8 |
| textSecondary | #6B7280 (timestamps, inactive chip text) | #9CA3AF |
| textTertiary | #9CA3AF (inactive tab labels; icons ~#B5BAC3) | #6B7280 |
| brandBlue (gradient start) | #4F6BFF (measured #4865FF–#4D6AFF on renders) | same |
| brandPurple (gradient end) | #7B61FF (measured #6D5DFF–#705EFE on renders) | same |
| logoAmber (sun dot) | #FFB020 (measured; #FFBD28 on dark frame) | same |
| statusScheduledBg | #E5E9FF | #232C58 |
| statusScheduledText | #2C4BFF | #8FA0FF |

Brand gradient: #4F6BFF → #7B61FF, top-leading → bottom-trailing (135°). Used by: logo mark ring, app icon, floating Create button, media attachment card.

**Typography**: system font (SF Pro), rounded design for display/wordmark. Measured from the 2× Queue mock: Large Title 30–32 bold rounded (nav "Queue"); Section header 24 bold (Today/Tomorrow); Title 22 semibold rounded (wordmark scales); Headline 17 semibold; Body 17 regular (post text); Caption 13 semibold (tab labels, chips 15 semibold). Use Dynamic Type.

**Spacing**: 4 / 8 / 12 / 16 / 24 / 32 (Queue mock: card padding 16, screen margins 16, chip gaps 8, section gaps 24).
**Radius**: 12 media attachment, 16 cards, 24 sheets, pill for chips/buttons (measured: PostCard ~16, chips + buttons fully rounded).
**Elevation**: no heavy shadows; 1px border #E6E8F0 on cards. Soft shadow/glow only under the floating Create button (gradient circle ~64pt with white +).
**Motion**: spring animations (response 0.35, damping 0.8); haptics on schedule, delete, connect.

## 3. Components
DayframeLogoMark, DayframeWordmark, PrimaryButton, SecondaryButton, ChannelAvatar (platform badge), PostCard, StatusChip (Scheduled / Published / Draft / Failed), StatCard, EmptyStateView, SectionHeader, FloatingCreateButton (gradient), CharacterCounterRing, TimeSlotRow, SkeletonView.

Rules: all colors and fonts come from the design system; minimum tap target 44pt; every interactive element has an accessibility label.

## 4. Screens
1. **Launch / Onboarding / Auth**: centered logo; 3 swipeable pages with SF Symbol illustrations on soft gradient cards; Auth with wordmark, email, Apple, Google.
2. **Connect Channels**: list of Instagram, X, LinkedIn, Facebook, TikTok, YouTube; Connect button; connected state with green check; Reconnect badge when expired.
3. **Queue**: wordmark in nav bar; filter chips; posts grouped by Today / Tomorrow / date with timeline connector and time labels; PostCard (avatar, preview, thumbnail, status); swipe actions; skeleton; empty state.
4. **Composer (sheet)**: channel avatars multi-select; text editor with counter rings; media row; toolbar (emoji, hashtag, sparkle, link); schedule options; preview tab per platform; Save draft + Schedule.
5. **Calendar**: month grid with dots; week toggle; day posts in bottom sheet.
6. **Post Detail**: full preview, status, channels, time, edit / reschedule / delete.
7. **Analytics**: range segmented control; 4 StatCards with trend arrows; reach line chart; posts-per-channel bar chart; top posts.
8. **Profile**: user header, channels, posting schedule editor, notifications, theme, upgrade card, About, logout.

## 5. Navigation Shell
5-tab TabView: Queue, Calendar, Create (raised gradient circular + button), Analytics, Profile. SF Symbols, filled when selected, tint = primary.

## 6. States
Every data screen defines: loading (skeleton), empty (muted logo + message + action), error (inline banner + retry), offline (read-only banner).

## 7. Accessibility
Dynamic Type through AX sizes, VoiceOver labels and traits, contrast at least 4.5:1, reduce motion respected, never rely on color alone for status (chips include icon + text).

## 8. Related Docs
AppFLOW.md for behavior, Schema.md for field names shown in UI.
