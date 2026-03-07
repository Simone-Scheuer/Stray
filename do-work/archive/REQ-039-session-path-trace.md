---
id: REQ-039
title: Session path trace
status: completed
created_at: 2026-03-06T13:00:00Z
claimed_at: 2026-03-06T14:10:00Z
route: B
completed_at: 2026-03-06T14:25:00Z
user_request: UR-013
related: [REQ-036]
batch: post-ideation
---

# Session Path Trace

---
*Source: User confirmed from ideation sweep.*

---

## Triage

**Route: B** - Medium

**Reasoning:** Clear feature but needed to explore overlay/renderer patterns in MapViewRepresentable.

**Planning:** Not required

## Implementation Summary

- **StraySessionViewModel.swift**: Added `pathCoordinates` array and `pathPolyline: MKPolyline?`. Each location update appends coordinate and rebuilds polyline. On session end, encodes path as Float lat/lng pairs to `pathData`. Path resets on start/end.
- **MapViewRepresentable.swift**: Added `sessionPathPolyline` parameter. `updateUIView` swaps old/new polyline overlays. `rendererFor` returns `MKPolylineRenderer` with white 70% opacity, 3pt line width, round caps/joins.
- **ContentView.swift**: Passes `sessionViewModel?.pathPolyline` to MapViewRepresentable.
- **PersistenceService.swift**: `saveStraySession` now accepts optional `pathData` parameter.

*Completed by work action (Route B)*

## Testing

**Tests run:** xcodebuild build
**Result:** BUILD SUCCEEDED

*Verified by work action*
