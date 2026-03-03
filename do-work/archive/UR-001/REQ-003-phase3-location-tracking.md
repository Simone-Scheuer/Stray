---
id: REQ-003
title: "Phase 3: Location Tracking — LocationService, persistence, city detection"
status: completed
created_at: 2026-03-02T12:00:00Z
claimed_at: 2026-03-02T13:05:00Z
route: C
completed_at: 2026-03-02T13:45:00Z
user_request: UR-001
related: [REQ-001, REQ-002, REQ-004, REQ-005, REQ-006]
batch: stray-mvp
---

# Phase 3: Location Tracking

## What
Implement dual-mode location tracking (passive background + active Stray session), persistence service for saving/updating cells, onboarding permission flow, and city detection via reverse geocoding. Wire the full pipeline: location → GridEngine → persistence → fog refresh.

## Detailed Requirements

1. **LocationService.swift** — `@Observable` class wrapping CoreLocation.
   - **Passive mode**: `CLLocationUpdate.liveUpdates(.default)` + `CLBackgroundActivitySession`
     - Skip when `update.isStationary == true` (critical battery saver)
     - Discard `horizontalAccuracy > 100m`
     - Track cumulative distance between consecutive valid updates
   - **Active Stray mode**: `CLLocationUpdate.liveUpdates(.automotiveNavigation)`
     - Tighter accuracy filter: `> 50m`
     - Feed updates to StrayEngine for compass bearing
   - Methods: `startPassiveTracking()`, `startActiveTracking()`, `stopTracking()`
   - Steps estimated: `distanceMeters / 0.7` (no Motion permission needed)

2. **PersistenceService.swift** — SwiftData CRUD helpers.
   - `saveOrUpdateCell(gridCell:, at date:, in context:)` — create new `RevealedCell` or increment `visitCount` on existing (lookup by `cellKey`)
   - `updateDailySummary(cells:, distance:, steps:, in context:)` — increment today's summary or create new
   - `deduplicateCells(in context:)` — merge `RevealedCell` records with same `cellKey` (keep earliest `firstVisitedAt`, sum `visitCount`, keep latest `lastVisitedAt`)

3. **Wire the pipeline**: Location update → `GridEngine.revealCell()` → if new/updated: `PersistenceService.saveOrUpdateCell()` + `FogTileOverlay` renderer `reloadData()`

4. **OnboardingView.swift** — First-launch flow:
   - 1-2 screen explanation of concept
   - Request "When In Use" location permission with clear explanation
   - Later prompt upgrade to "Always" (after first successful walk, not on first launch)

5. **City detection** — On first visit to a new cell, queue `CLGeocoder.reverseGeocodeLocation()` to get city name. Store on `RevealedCell.city`. Rate limit: Apple limits ~50 requests/minute. Cache aggressively (if adjacent cells are in same city, skip API call). Store `nil` on failure, retry later.

## Constraints

- No timer-based polling — purely reactive to OS-delivered location updates
- Battery is sacred: `isStationary` check, accuracy filtering, no processing when still
- Two-step permission flow: When In Use first, Always upgrade later
- App must work (degraded) with only "When In Use" permission

## Dependencies

- Depends on: REQ-001 (models, GridCell), REQ-002 (GridEngine)
- Can partially parallelize with REQ-002 once GridEngine interface is defined
- Blocks: REQ-004 (Stray Mode needs LocationService)

## Builder Guidance

- Certainty level: Firm — CLLocationUpdate API choice is settled
- Battery efficiency is THE critical concern. Profile with Xcode Energy Diagnostics.
- Reference: IMPLEMENTATION_PLAN.md "Location Tracking" section

## Full Context
See [user-requests/UR-001/input.md](./user-requests/UR-001/input.md) for complete verbatim input.

---

## Triage

**Route: C** - Complex

**Reasoning:** Multiple new services (LocationService, PersistenceService), async CLLocationUpdate API, CLBackgroundActivitySession, reverse geocoding with rate limiting, onboarding view, and wiring the full pipeline. Introduces dual-mode tracking pattern and SwiftData CRUD layer. Battery implications require careful design.

**Planning:** Required

## Plan

### Files to Create/Modify

| Action | File | Description |
|--------|------|-------------|
| Create | `Stray/Services/LocationService.swift` | @Observable, dual-mode CLLocationUpdate, CLBackgroundActivitySession, permission, distance/steps |
| Create | `Stray/Services/PersistenceService.swift` | SwiftData CRUD, dedup by cellKey, city detection via rate-limited CLGeocoder |
| Create | `Stray/Views/OnboardingView.swift` | 2-page first-launch: concept intro + When In Use permission request |
| Modify | `Stray/StrayApp.swift` | Create/inject all services, dedup on launch, wire pipeline callback, onboarding gate |
| Modify | `Stray/Views/ContentView.swift` | Receive services from environment instead of local @State |
| Modify | `Stray/Utilities/Extensions.swift` | Add EnvironmentKey conformances for service injection |
| Modify | `Stray/Utilities/Constants.swift` | Add geocoding rate limit, UserDefaults keys, min distance constants |

### Key Technical Decisions
- **CLLocationUpdate API:** `.liveUpdates(.default)` passive, `.liveUpdates(.automotiveNavigation)` active
- **CLBackgroundActivitySession:** held while tracking, invalidated on stop
- **Location processing on MainActor:** @Observable mutations + onLocationUpdate callback
- **Pipeline callback:** `onLocationUpdate: (CLLocationCoordinate2D, Double) -> Void` — decoupled from GridEngine
- **Service injection:** EnvironmentKey pattern (iOS 17 compatible, not @Entry which needs 17.4+)
- **City cache:** bucket by `Int(floor(lat*200))_Int(floor(lng*200))` (~500m squares) — one geocode per ~100 cells
- **Geocoding rate limit:** counter + minute window, cap at 40/min (under Apple's ~50)
- **Dedup strategy:** fetch all, group by cellKey, keep earliest firstVisitedAt, sum visitCount, latest lastVisitedAt
- **Permission flow:** When In Use only on first launch; Always upgrade deferred to later sessions

### Pipeline Architecture
```
CLLocationUpdate.liveUpdates → LocationService.processUpdate
  → skip isStationary / bad accuracy
  → onLocationUpdate callback (wired in StrayApp)
    → GridEngine.revealCell() → changeCounter → fog reloadData
    → PersistenceService.saveOrUpdateCell() → SwiftData
    → PersistenceService.detectCity() [new cells only]
    → PersistenceService.updateDailySummary()
```

*Generated by Plan agent*

## Exploration

- **GridEngine.swift** (existing): revealCell(at:) returns GridCell? if new, increments changeCounter; loadCells(from:) loads from ModelContext; cellsWithCounts(in:) for tile rendering; addTestCells() for DEBUG
- **ContentView.swift** (existing): @State GridEngine, passes to MapViewRepresentable, DEBUG addTestCells on appear — needs to switch to environment injection
- **StrayApp.swift** (existing): creates ModelContainer with CloudKit, passes to ContentView via .modelContainer() — needs service creation + pipeline wiring
- **RevealedCell.swift** (existing): @Model with cellKey, visitCount, city (optional), firstVisitedAt, lastVisitedAt — PersistenceService will CRUD these
- **DailySummary.swift** (existing): @Model with dateString, cellsRevealed, distanceMeters, stepCount, isActiveDay
- **Constants.swift** (existing): has passiveAccuracyThreshold (100), activeAccuracyThreshold (50), averageStrideLengthMeters (0.7) — need to add geocoding + onboarding constants
- **Extensions.swift** (existing): CLLocationCoordinate2D distance/bearing — need to add EnvironmentKey conformances
- **project.yml**: already has location usage descriptions and UIBackgroundModes [location, remote-notification]
- **Stray.entitlements**: has CloudKit — no background modes key yet but project.yml handles via Info.plist generation

*Generated by Plan agent (inline exploration)*

## Implementation Summary

- Created `Stray/Services/LocationService.swift` — dual-mode CLLocationUpdate (.default/.automotiveNavigation), CLBackgroundActivitySession, isStationary skip, accuracy filtering, distance/steps accumulation, onLocationUpdate callback, CLLocationManagerDelegate
- Created `Stray/Services/PersistenceService.swift` — SwiftData CRUD (saveOrUpdateCell, updateDailySummary, deduplicateCells), rate-limited CLGeocoder city detection with ~500m bucket cache
- Created `Stray/Views/OnboardingView.swift` — 2-page TabView: welcome + location permission request, saves to UserDefaults on completion
- Modified `Stray/StrayApp.swift` — creates all services, runs dedup on launch, loads cells, wires full pipeline (GridEngine → PersistenceService → city detection → daily summary), onboarding gate, environment injection, auto-start tracking
- Modified `Stray/Views/ContentView.swift` — @Environment injection for GridEngine, simulator-only test cells
- Modified `Stray/Utilities/Extensions.swift` — EnvironmentKey conformances for GridEngine, LocationService, PersistenceService
- Modified `Stray/Utilities/Constants.swift` — added minimumDistanceBetweenUpdatesMeters, geocodeRateLimitPerMinute, UserDefaults keys

*Completed by work action (Route C)*

## Testing

**Tests run:** `xcodegen generate && xcodebuild -project Stray.xcodeproj -scheme Stray -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2' build`
**Result:** BUILD SUCCEEDED

**Notes:** No unit test infrastructure in MVP. Manual device testing needed per project guidelines. One expected deprecation warning for `isStationary` (renamed to `stationary` in iOS 18).

*Verified by work action*

---
*Source: See UR-001/input.md for full verbatim input*
