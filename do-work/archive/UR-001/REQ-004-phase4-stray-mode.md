---
id: REQ-004
title: "Phase 4: Stray Mode — Frequency-weighted compass and session UI"
status: completed
created_at: 2026-03-02T12:00:00Z
claimed_at: 2026-03-02T13:50:00Z
route: C
completed_at: 2026-03-02T14:20:00Z
user_request: UR-001
related: [REQ-001, REQ-002, REQ-003, REQ-005, REQ-006]
batch: stray-mvp
---

# Phase 4: Stray Mode

## What
Implement the frequency-weighted compass algorithm (BFS clustering over scored cells), session management, compass UI overlay, and wire into the main map view with Start/End buttons.

## Detailed Requirements

1. **StrayEngine.swift** — The compass algorithm.
   - `scoredCellsNearby(center:radius:)` — enumerate all cells within 500m radius, assign frequency weights:
     - Never visited: weight 1.0
     - Visited 1-2 times: weight 0.7
     - Visited 3-5 times: weight 0.3
     - Visited 6+ times: weight 0.0 (no pull)
   - `findHighestWeightCluster(in:)` — BFS flood-fill over weighted cells. Group into contiguous clusters. Rank by total weight. Return the highest-weight cluster.
   - `bearingToCluster(from:cluster:)` — geographic bearing from user position to the cluster's weight-adjusted centroid.
   - Recalculate: on new cell reveal OR every 5 seconds during movement.
   - Performance: <1ms for 500m radius (~300 cells). Fine on every location update.

2. **StraySessionViewModel.swift** — `@Observable` class.
   - Session lifecycle: `startSession()`, `endSession()`
   - Running timer (duration)
   - Track cells revealed during session, distance walked, steps
   - Current compass bearing (from StrayEngine)
   - Save completed `StraySession` via PersistenceService on end

3. **StrayCompassView.swift** — SwiftUI overlay.
   - Animated compass arrow showing direction to explore
   - Smooth rotation interpolation (don't snap between bearings)
   - Minimal, confident visual design
   - Disappears when no Stray session is active

4. **Wire into ContentView.swift**:
   - Floating "Start Stray" button (bottom center) when no session active
   - During session: compass overlay + session info (elapsed time, cells revealed, distance) + "End Stray" button
   - Switch LocationService to active mode during session

5. **Edge cases**:
   - No high-weight cells within 500m → show message: "You've explored everything nearby — venture further"
   - GPS unavailable → graceful message
   - User ends session immediately → save with 0 stats (don't crash)

## Constraints

- Compass points, it doesn't navigate. No turn-by-turn directions, ever.
- No obstacle avoidance in MVP — compass updates organically as user walks around barriers
- The algorithm must never "run out" — frequency weighting ensures there's always somewhere to point (until literally every cell is visited 6+ times)

## Dependencies

- Depends on: REQ-001 (models), REQ-002 (GridEngine), REQ-003 (LocationService)
- Blocks: nothing directly (but REQ-005 stats depend on session data)

## Builder Guidance

- Certainty level: Firm — BFS clustering + bearing approach is decided
- The compass feel is critical. Smooth animation, confident arrow. This is the feature people remember.
- Reference: IMPLEMENTATION_PLAN.md "Frequency-Weighted Stray Algorithm" section

## Full Context
See [user-requests/UR-001/input.md](./user-requests/UR-001/input.md) for complete verbatim input.

---

## Triage

**Route: C** - Complex

**Reasoning:** New BFS clustering algorithm, new ViewModel with session lifecycle, animated compass UI, wiring across GridEngine + LocationService + PersistenceService. The compass feel/animation is critical UX. Multiple new components introducing new patterns (ViewModel, timed recalculation).

**Planning:** Required

## Plan

### Files to Create/Modify

| Action | File | Description |
|--------|------|-------------|
| Create | `Stray/Services/StrayEngine.swift` | BFS clustering, frequency scoring, bearing to centroid |
| Create | `Stray/ViewModels/StraySessionViewModel.swift` | @Observable, session lifecycle, timer, coordinates services |
| Create | `Stray/Views/StrayCompassView.swift` | Animated compass arrow, smooth rotation |
| Modify | `Stray/Views/ContentView.swift` | Start/End buttons, compass overlay, session stats HUD |
| Modify | `Stray/Models/GridCell.swift` | Add centerCoordinate computed property |
| Modify | `Stray/Utilities/Extensions.swift` | Add StraySessionViewModel EnvironmentKey |

### Key Technical Decisions
- **Cell enumeration:** Compute lat/lng index ranges for 500m radius, iterate all possible cells, score by visit count from GridEngine
- **BFS adjacency:** 4-connected (N/S/E/W neighbors) using latIndex±1, lngIndex±1
- **Cluster ranking:** sum of weights per cluster, pick highest
- **Bearing:** weight-adjusted centroid (sum of lat*weight, lng*weight / total weight), then bearing from Extensions
- **Smooth rotation:** `.rotationEffect` with `.animation(.easeInOut(duration: 0.5))`
- **Session timer:** `TimelineView(.periodic(every: 1))` — no Timer polling
- **Active mode toggle:** StraySessionViewModel sets `locationService.isActiveMode = true` on start, false on end

*Generated by Plan agent*

## Exploration

- **GridEngine.swift**: `revealedCells: [GridCell: Int]`, `isRevealed(_:)`, `visitCount(for:)`, `cellsWithCounts(in:)` — StrayEngine reads from revealedCells directly
- **LocationService.swift**: `isActiveMode`, `currentLocation`, `onLocationUpdate` callback, `startTracking()/stopTracking()`
- **PersistenceService.swift**: `saveOrUpdateCell`, `updateDailySummary`, `save()` — used to persist StraySession on end
- **StraySession.swift**: @Model with startedAt, endedAt, cellsRevealedCount, distanceMeters, durationSeconds, pathData
- **GridCell.swift**: has `coordinate` (SW corner), needs centerCoordinate for bearing math
- **Constants.swift**: `searchRadiusMeters = 500.0`
- **ContentView.swift**: environment-injected gridEngine, full-screen MapViewRepresentable
- **Extensions.swift**: `CLLocationCoordinate2D.bearing(to:)`, EnvironmentKeys for services
- **ViewModels/ directory**: exists but empty — ready for StraySessionViewModel

*Generated by Plan agent (inline exploration)*

## Implementation Summary

- Created `Stray/Services/StrayEngine.swift` — frequency-weighted compass: scoredCellsNearby (enumerate 500m radius, weight by visits), BFS flood-fill clustering (4-connected), bearingToCluster (weight-adjusted centroid)
- Created `Stray/ViewModels/StraySessionViewModel.swift` — @Observable session lifecycle (start/end), distance/cells/steps tracking, compass bearing updates, saves StraySession via PersistenceService
- Created `Stray/Views/StrayCompassView.swift` — animated compass arrow with easeInOut rotation, "venture further" fallback message
- Modified `Stray/Models/GridCell.swift` — added centerCoordinate computed property
- Modified `Stray/Services/PersistenceService.swift` — added saveStraySession method
- Modified `Stray/Utilities/Extensions.swift` — added StraySessionViewModel EnvironmentKey
- Modified `Stray/Views/ContentView.swift` — Start/End Stray buttons, compass overlay, session stats HUD with TimelineView timer
- Modified `Stray/StrayApp.swift` — creates StraySessionViewModel, wires into location pipeline, injects via environment

*Completed by work action (Route C)*

## Testing

**Tests run:** `xcodegen generate && xcodebuild ... build`
**Result:** BUILD SUCCEEDED

**Notes:** No unit tests in MVP. Manual validation: start session → compass arrow appears pointing toward unexplored area → walk → cells reveal → compass updates smoothly → end session → stats saved.

*Verified by work action*

---
*Source: See UR-001/input.md for full verbatim input*
