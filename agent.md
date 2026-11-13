# agent.md: Dayframe (dayframe-scheduler)

You are the coding agent for **Dayframe**, an iPhone app for scheduling social media posts, with a clean Buffer-like experience and original branding.

## Agent Configuration
- Model: `glm-5.3-flash`
- Reasoning effort: `high`
- Tool: Command Code (terminal coding agent)

## Source of Truth: Read These First
Read in this order before writing any code. They are the single source of truth; if code and docs disagree, follow the docs or update them and note it in Plan.md "Decisions".

1. [PRD.md](docs/PRD.md): what we are building and why
2. [AppFLOW.md](docs/AppFLOW.md): user flows, navigation, post lifecycle, edge cases
3. [UI_Spec.md](docs/UI_Spec.md): brand, tokens, components, screens
4. [TRD.md](docs/TRD.md): architecture, stack, scheduling engine, security, testing
5. [Schema.md](docs/Schema.md): database tables, RLS, enums, Swift model mapping
6. [Plan.md](docs/Plan.md): phased build order and checklists (your task list)

## Design Source of Truth: Figma
The approved visual design is in Figma. **Every screen, component, color, font, spacing, and icon you build must match it.**

- File: https://www.figma.com/design/I1xQfWCdFc9GgdvWbMoblS/Dayframe---Social-Media-Scheduler-iOS?node-id=4-3
- Priority: Figma wins over UI_Spec.md on anything visual (layout, colors, type, spacing, radius, icons, copy). UI_Spec.md values are defaults only until verified against Figma. If they differ, update UI_Spec.md to match Figma and log it in Plan.md "Decisions".
- Logo: if Figma already contains the Dayframe logo/icon, use that design (recreate as SVG + native SwiftUI shapes). Do not invent a new logo.
- How to read the design (use the first that works):
  1. Figma MCP server, if your tool has it connected: fetch the file and each frame by node, read layout, tokens, and assets.
  2. Exported frames: look for PNGs in `docs/design/` (named after the Figma frame, e.g. `Queue.png`) and view them.
  3. If neither is available, STOP and ask the user to connect Figma MCP or export the frames. Never guess the design.
- Before building a screen: open its Figma frame, list the components, spacing, colors, and states it shows, then build. After building: run the simulator, screenshot, and compare side by side with the frame. Fix differences before ticking the task.
- Extract design tokens (colors, type scale, spacing, radius, shadows) from Figma into the design system first; views must only use those tokens.
- Export icons/illustrations from Figma as SVG or PDF into the asset catalog; use SF Symbols only where Figma uses system-style icons.

## How to Work
1. Open Plan.md and find the first phase with unchecked items.
2. Before starting, write a short plan (files to create or change) and proceed.
3. Implement the phase's tasks in order. After each task: build, fix errors, run tests.
4. Tick the checklist items in Plan.md as you finish them.
5. At the end of the phase, summarize what was done, list anything skipped, and **stop for the user's review**. Do not begin the next phase until told.

## Hard Rules
- Stack: Swift 5.9+, SwiftUI, iOS 17+, MVVM with `@Observable`, NavigationStack, Swift Charts. Backend: Supabase (see TRD.md). No other dependencies without justification recorded in Plan.md.
- App name is **Dayframe**; project `DayframeScheduler`; bundle ID `com.dayframe.scheduler`; Swift types use the `Dayframe` prefix.
- Never copy Buffer's logo, icons, or assets. Use the Dayframe logo from Figma; only if Figma has none, create an original one in Phase 0 and get the user's approval.
- Match the Figma design exactly (see "Design Source of Truth: Figma"). Never invent layouts, colors, or copy that are not in Figma without asking.
- No hardcoded colors, fonts, spacing, or radius values in views; use the design system tokens.
- Platform tokens and service-role keys never ship in the app or the repo. Use `.env` locally and commit only `.env.example`.
- Every table has RLS; never edit an applied migration, add a new one.
- Every view has a `#Preview`; every interactive element has an accessibility label.
- Zero build warnings. Do not commit failing builds or tests.
- Before building a platform integration, read that provider's current docs and write `docs/integrations/<platform>.md`. Do not rely on memory for API limits, scopes, or token lifetimes.
- If a requirement is ambiguous or a doc conflicts with another, ask the user one short question rather than guessing.

## Repository Layout
```
dayframe-scheduler/
  agent.md
  docs/            PRD.md AppFLOW.md UI_Spec.md TRD.md Schema.md Plan.md
  docs/design/     exported Figma frames (PNG) if Figma MCP is not available
  DayframeScheduler/
    App/ DesignSystem/ Models/ Repositories/ Services/ MockData/
    Features/ (Onboarding, Channels, Queue, Composer, Calendar, Analytics, Profile)
    Components/ Assets/Brand/
  supabase/
    migrations/ functions/ seed.sql
  .env.example
```

## Conventions
- Naming: `FooView`, `FooViewModel`, `FooRepository` (protocol) with `MockFooRepository` and `LiveFooRepository`.
- One type per file; files under about 300 lines.
- Async/await everywhere; no completion-handler APIs.
- Dates stored UTC; displayed in the user's time zone.
- Commit messages: `phase-N: short description`.

## Definition of Done (per task)
Builds with zero warnings, tests pass, previews render in Light and Dark, screen visually matches its Figma frame (simulator screenshot compared), behavior matches AppFLOW.md, Plan.md updated.

## Current Status
Start at **Phase 0** in [Plan.md](docs/Plan.md).
