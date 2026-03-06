---
id: REQ-029
title: Preload fog at city scale to prevent zoom-out flash
status: completed
completed_at: 2026-03-05T12:35:00Z
claimed_at: 2026-03-05T12:26:00Z
route: B
created_at: 2026-03-05T12:00:00Z
user_request: UR-007
related: [REQ-027, REQ-028]
batch: launch-experience
---

# Preload Fog at City Scale to Prevent Zoom-Out Flash

## What
On boot, preload/pre-render the fog overlay at a city-wide zoom level so that when the user zooms out for the first time, the darkness renders instantly without visible flashing/loading.

## Context
Currently, zooming out causes the fog overlay to visibly load in, breaking immersion. The user suggests doing a brief zoom-out on boot (city-sized scale) to force MapKit to cache the fog tiles at that zoom level. This could be combined with the loading animation (REQ-027) to hide the preload.

## Open Questions
- Best approach: programmatic zoom-out during splash, pre-rendering overlay tiles at multiple zoom levels, or warming up the renderer's cache?
- How far out to preload — just city scale or wider?

---
*Source: "is it possible to execute like a big zoom out-like just small city sized on boot so it loads the full map because when zooming out for the first time we get some flashing during the load in on the darkness map which is immersion breaking"*

---

## Triage

**Route: B** - Medium

**Reasoning:** Clear approach (zoom out during splash to warm cache) but need to explore MapViewRepresentable's zoom control mechanism.

**Planning:** Not required

## Plan

**Planning not required** - Route B: Exploration-guided implementation

Rationale: The strategy is straightforward — programmatically zoom out to city scale during the splash screen, then zoom back. Need to find how to control map region from outside the Coordinator.

*Skipped by work action*

## Implementation Summary

- Removed immediate `userTrackingMode = .follow` from `makeUIView`
- Added fog preload sequence in `makeUIView` using `DispatchQueue.main.asyncAfter`:
  - At 0.3s: zoom out to city scale (0.08° lat/lng span) — forces `FogOverlayRenderer.draw()` at that zoom level
  - At 1.8s: set `userTrackingMode = .follow` to zoom back to user location
- All happens behind the 2.5s splash screen (REQ-027), invisible to user
- When splash fades at 2.5s, map is centered on user and city-scale fog tiles are already cached

*Completed by work action (Route B)*

## Testing

**Tests run:** xcodebuild build
**Result:** BUILD SUCCEEDED

No testing infrastructure — manual device validation per CLAUDE.md.

*Verified by work action*
