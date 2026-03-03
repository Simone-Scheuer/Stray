---
id: UR-001
title: Stray MVP Implementation — All 6 Phases
created_at: 2026-03-02T12:00:00Z
requests: [REQ-001, REQ-002, REQ-003, REQ-004, REQ-005, REQ-006]
word_count: 512
---

# Stray MVP Implementation — All 6 Phases

## Summary

Full implementation of the Stray iOS app MVP across 6 phases: Foundation, Fog + Heat Gradient, Location Tracking, Stray Mode, Stats & Navigation, and Sync & Polish. Each phase has specific files to create, validation criteria, and dependency relationships. Phases 2 and 3 can be partially parallelized after Phase 1 completes.

## Extracted Requests

| ID | Title | Summary |
|----|-------|---------|
| REQ-001 | Phase 1: Foundation | Xcode project scaffold, data models, GridCell, SwiftData models, basic MKMapView on screen |
| REQ-002 | Phase 2: Fog + Heat Gradient | GridEngine, FogTileOverlay (MKTileOverlay + Core Graphics), heat gradient rendering |
| REQ-003 | Phase 3: Location Tracking | LocationService (dual-mode CLLocationUpdate), PersistenceService, onboarding, city detection |
| REQ-004 | Phase 4: Stray Mode | StrayEngine (frequency-weighted BFS compass), session management, compass UI |
| REQ-005 | Phase 5: Stats & Navigation | StatsEngine, per-city breakdown, StatsView, SettingsView, bottom sheet navigation |
| REQ-006 | Phase 6: Sync & Polish | iCloud sync testing, deduplication, bloom animation, compass animation, battery optimization |

## Batch Constraints

- Phase 1 must complete before any other phase begins
- Phases 2 and 3 can partially parallelize after GridEngine (step 2.1) is complete
- Phase 4 depends on both Phases 2 and 3
- Phases 5 and 6 can partially parallelize
- All code must follow CLAUDE.md conventions (no @Attribute(.unique), all defaults, background queue rendering, etc.)
- Reference files: PRD.md, IMPLEMENTATION_PLAN.md, CLAUDE.md

## Full Verbatim Input

Queue the following implementation tasks for Stray (iOS exploration app). Execute in order, using parallel agents where noted in CLAUDE.md:

Phase 1 - Foundation:
1. Create Xcode project structure (Stray/, Views/, ViewModels/, Models/, Services/, Utilities/)
2. Implement Constants.swift (grid size 50m, search radius 500m, fog color, heat gradient colors, accuracy thresholds)
3. Implement Extensions.swift (CLLocationCoordinate2D distance + bearing helpers)
4. Implement GridCell.swift (struct, Hashable, Codable, Sendable — lat/lng index math, coordinate conversion)
5. Implement RevealedCell.swift (@Model with visitCount, city, CloudKit-safe defaults, indexes)
6. Implement StraySession.swift (@Model for session records)
7. Implement DailySummary.swift (@Model with stepCount)
8. Implement StrayApp.swift (@main, ModelContainer with CloudKit)
9. Implement MapViewRepresentable.swift (UIViewRepresentable wrapping MKMapView)
10. Implement ContentView.swift (full-screen map)

Phase 2 - Fog + Heat Gradient (can partially parallel with Phase 3 after GridEngine):
11. Implement GridEngine.swift (Dictionary<GridCell, Int>, isRevealed, revealCell, visitCount, spatial index)
12. Implement FogTileOverlay.swift (MKTileOverlay subclass, Core Graphics fog + heat gradient tiles)
13. Wire fog overlay into MapViewRepresentable + tile refresh on cell changes

Phase 3 - Location Tracking:
14. Implement LocationService.swift (dual-mode CLLocationUpdate, isStationary filtering, distance accumulation)
15. Implement PersistenceService.swift (saveOrUpdateCell, updateDailySummary, deduplication)
16. Wire location → GridEngine → PersistenceService → fog refresh pipeline
17. Implement OnboardingView.swift (permission flow)
18. Add city detection via CLGeocoder reverse geocoding

Phase 4 - Stray Mode:
19. Implement StrayEngine.swift (frequency-weighted scoring, BFS clustering, bearing calculation)
20. Implement StraySessionViewModel.swift (session lifecycle, timer, distance/step tracking)
21. Implement StrayCompassView.swift (animated compass arrow)
22. Wire Stray Mode into ContentView (Start/End buttons, compass overlay, session info)
23. Save completed StraySession to SwiftData

Phase 5 - Stats & Navigation:
24. Implement StatsEngine.swift (total cells, streak, distance, steps, per-city breakdown)
25. Implement StatsViewModel.swift + StatsView.swift
26. Implement SettingsView.swift
27. Wire bottom sheet navigation in ContentView

Phase 6 - Sync & Polish:
28. CloudKit sync testing + deduplication pass
29. Bloom animation (smooth fade from dark to heat color)
30. Compass arrow smooth rotation animation
31. Battery optimization pass
32. Edge case handling (fresh install, poor GPS, airplane mode, app killed by OS)

Reference files: PRD.md, IMPLEMENTATION_PLAN.md, CLAUDE.md

---
*Captured: 2026-03-02T12:00:00Z*
