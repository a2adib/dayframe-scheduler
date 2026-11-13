# Dayframe Brand Assets

Source of truth: Figma file "Dayframe - Social Media Scheduler iOS"
(https://www.figma.com/design/I1xQfWCdFc9GgdvWbMoblS), nodes:

- `dayframe-mark` (2-2): the logo mark, 200×200
- `dayframe-app-icon` (2-5): white mark on full-bleed brand gradient
- `dayframe-logo-lockup` (1-2): mark + wordmark, 460×120
- `logo-on-white` / `logo-on-dark` / `logo-on-gradient` / `logo-at-small-size`: usage frames
- `concept-1-sun-frame` / `concept-2-time-notch` / `concept-3-framing-d`: unused explorations

## Mark geometry (200×200, measured from Figma)
- Rounded-square ring: inset 15.5, stroke 25, outer corner radius 50, no fill
- Stroke gradient: #4F6BFF (top-leading) → #7B61FF (bottom-trailing)
- Sun dot: center (120.5, 80.5), r 21.5, #FFB020

## Wordmark
"Dayframe", bold rounded type; "Day" #111827, "frame" #2C4BFF.

## Files
- `dayframe-mark.svg` — mark only
- `dayframe-app-icon.svg` — 1024 app icon (white mark on gradient)
- `dayframe-logo-lockup.svg` — mark + wordmark

Native SwiftUI versions: `DayframeLogoMark` and `DayframeWordmark` in
`DayframeScheduler/Components/Brand/`. The AppIcon PNG is generated from the
mark geometry (`docs/design/generated-app-icon.png` is a copy for reference).
