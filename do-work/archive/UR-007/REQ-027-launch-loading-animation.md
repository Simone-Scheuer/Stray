---
id: REQ-027
title: Launch loading animation
status: completed
completed_at: 2026-03-05T12:15:00Z
created_at: 2026-03-05T12:00:00Z
claimed_at: 2026-03-05T12:05:00Z
route: B
user_request: UR-007
related: [REQ-028, REQ-029]
batch: launch-experience
---

# Launch Loading Animation

## What
Add a loading/splash animation on app boot-up before the map is ready.

## Context
Currently the app launches straight into the map with no transition. A loading animation would smooth the experience and buy time for fog preloading (REQ-029).

---
*Source: "add a loading animation on boot up"*

---

## Triage

**Route: B** - Medium

**Reasoning:** Clear feature (splash screen) but need to explore current app launch flow and how services initialize.

**Planning:** Not required

## Plan

**Planning not required** - Route B: Exploration-guided implementation

Rationale: Clear feature request — add a splash/loading screen. Just need to understand current boot sequence and service readiness signals.

*Skipped by work action*

## Implementation Summary

- Added `@State private var showSplash = true` to ContentView
- Added `.overlay` with `SplashOverlay()` that renders on top of everything, fades out after 2.5s
- Created `SplashOverlay` private struct: dark background (fog color), 5x5 grid of animated cells cycling through heat gradient colors (cool blue -> bright glow), "Stray" text with letter spacing
- Map loads behind the splash so there's no blank flash on fade-out
- Animation uses repeating linear cycle (2s) with staggered opacity waves

*Completed by work action (Route B)*

## Testing

**Tests run:** xcodebuild build
**Result:** BUILD SUCCEEDED

No testing infrastructure in this project (manual device validation per CLAUDE.md).

*Verified by work action*
