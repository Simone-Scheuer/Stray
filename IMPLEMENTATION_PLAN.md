# Stray — Phased Implementation Plan

**Version:** 2.0
**Date:** March 2, 2026

---

## Technical Stack

| Component | Choice | Rationale |
|---|---|---|
| Platform | iOS 17.0+ | Required for `CLLocationUpdate` async API and mature SwiftData |
| Language | Swift | Native iOS development |
| UI Framework | SwiftUI | Modern, declarative, Apple's recommended approach |
| Architecture | MVVM with `@Observable` | Native SwiftUI pattern, maximum simplicity |
| Map | MapKit (`MKMapView` via `UIViewRepresentable`) | SwiftUI's native `Map` lacks tile overlay support |
| Location | CoreLocation (`CLLocationUpdate`, `CLBackgroundActivitySession`) | Modern async/await API with built-in `isStationary` |
| Persistence | SwiftData | Native Apple framework with automatic CloudKit integration |
| Sync | SwiftData + CloudKit (automatic) | Zero sync code, iCloud-based, no custom server |
| Dependencies | None (third-party) | Maximum simplicity, no dependency management |

---

## Project Structure

```
Stray/
├── StrayApp.swift                   # @main entry point, ModelContainer + service initialization
├── Views/
│   ├── ContentView.swift            # Root view — map with bottom sheet access to stats/settings
│   ├── MapViewRepresentable.swift   # UIViewRepresentable wrapping MKMapView
│   ├── StrayCompassView.swift       # Compass arrow overlay during active Stray sessions
│   ├── StatsView.swift              # Exploration statistics screen
│   ├── SettingsView.swift           # App settings and tracking controls
│   └── OnboardingView.swift         # First-launch flow with permission requests
├── ViewModels/
│   ├── MapViewModel.swift           # Map state management, fog refresh triggers
│   ├── StraySessionViewModel.swift  # Active Stray session state + compass bearing
│   └── StatsViewModel.swift         # Stats queries and formatting
├── Models/
│   ├── GridCell.swift               # Value type (struct) — cell coordinate math, NOT persisted
│   ├── RevealedCell.swift           # SwiftData @Model — persisted cell record with visit count
│   ├── StraySession.swift           # SwiftData @Model — completed session record
│   └── DailySummary.swift           # SwiftData @Model — per-day stats aggregation
├── Services/
│   ├── LocationService.swift        # CLLocationUpdate wrapper, dual-mode tracking
│   ├── GridEngine.swift             # In-memory cell set, spatial index, cell reveal + frequency logic
│   ├── FogTileOverlay.swift         # MKTileOverlay subclass — fog + heat gradient tile generation
│   ├── StrayEngine.swift            # Frequency-weighted compass algorithm
│   ├── PersistenceService.swift     # SwiftData CRUD helpers, CloudKit deduplication
│   └── StatsEngine.swift            # Aggregation queries, per-city breakdown
└── Utilities/
    ├── Constants.swift              # Grid size (50m), search radius (500m), fog color, heat colors
    └── Extensions.swift             # CLLocationCoordinate2D distance/bearing, city detection helpers
```

---

## Key Technical Decisions

### Grid System — Custom lat/lng grid (global)

Every point on Earth maps to a grid cell via integer indices:

- **Latitude step:** `50.0 / 111_320.0` degrees (~0.000449°). 1° latitude = 111,320m everywhere on Earth.
- **Longitude step:** `50.0 / (111_320.0 * cos(latitude))` degrees. Varies by latitude but negligible within a city. Computed per-cell using actual latitude so cells are ~50m on the ground everywhere.
- **Cell ID:** `(latIndex: Int, lngIndex: Int)` — `latIndex = floor(lat / latStep)`, `lngIndex = floor(lng / lngStep)`
- **In-memory storage:** `Set<GridCell>` where `GridCell` is `Hashable`. O(1) lookup. 20,000 cells ≈ 320KB RAM.
- **Global scope:** The grid works everywhere on Earth. Portland, Tokyo, rural Portugal — same math, same cell size.

### Fog + Heat Gradient Rendering — MKTileOverlay + Core Graphics

Custom `FogTileOverlay` extends `MKTileOverlay`, overrides `loadTile(at:result:)`:

1. For each 256×256 tile requested by MapKit:
   - Determine which grid cells fall within this tile's geographic bounds
   - Create a `CGContext` filled with dark fog color (`UIColor(white: 0.08, alpha: 0.85)`)
   - For each revealed cell in bounds, render based on visit frequency:
     - **1 visit:** Clear the fog and fill with a faint cool blue tint (`UIColor(red: 0.3, green: 0.4, blue: 0.8, alpha: 0.25)`)
     - **2-5 visits:** Fully clear (transparent) — the vivid base map shows through
     - **10+ visits:** Clear the fog and fill with a warm amber tint (`UIColor(red: 0.9, green: 0.6, blue: 0.2, alpha: 0.2)`)
     - **50+ visits:** Clear the fog and fill with a bright warm glow (`UIColor(red: 1.0, green: 0.8, blue: 0.3, alpha: 0.25)`)
   - Return the resulting image as PNG data
2. Only visible tiles are ever generated (MapKit handles this). Tile caching is automatic.
3. On new cell reveal or visit count change: call `MKTileOverlayRenderer.reloadData()`.

The heat gradient requires `GridEngine` to store visit counts in the in-memory structure (not just a `Set<GridCell>` — instead a `Dictionary<GridCell, Int>` mapping cells to visit counts).

### Location Tracking — CLLocationUpdate (iOS 17+)

**Passive (background, always-on):**
- `CLLocationUpdate.liveUpdates(.default)` — OS-optimized cadence
- `CLBackgroundActivitySession` — maintains background execution
- Skip processing when `update.isStationary == true` (biggest battery saver)
- Discard updates with `horizontalAccuracy > 100m` (prevents false reveals)
- Track cumulative distance between consecutive valid updates (for distance/step stats)

**Active (Stray session):**
- `CLLocationUpdate.liveUpdates(.automotiveNavigation)` — highest accuracy/frequency
- `horizontalAccuracy` threshold tightened to 50m
- Feeds compass direction updates to `StrayEngine`

**Steps from GPS:** Estimated as `distanceMeters / 0.7` (average stride length). Avoids requiring Motion & Fitness permission. Accurate enough for a non-fitness app.

**Permission flow:**
1. First launch → request "When In Use"
2. After first successful walk → prompt upgrade to "Always" with clear explanation
3. App functions in "When In Use" mode (tracks only when foregrounded)

### Data Persistence — SwiftData with CloudKit

All `@Model` classes are CloudKit-compatible (all properties have defaults, no `@Attribute(.unique)`).

**RevealedCell:**
- `latIndex: Int`, `lngIndex: Int` — cell identification
- `cellKey: String` — `"latIdx_lngIdx"` for dedup lookups
- `firstVisitedAt: Date`, `lastVisitedAt: Date`, `visitCount: Int`
- `city: String?` — auto-detected city name (reverse geocoded on first visit)
- Indexed on `cellKey`, `latIndex`, `lastVisitedAt`, `city`

**StraySession:**
- `startedAt: Date`, `endedAt: Date?`
- `cellsRevealedCount: Int`, `distanceMeters: Double`, `durationSeconds: Double`
- `pathData: Data?` — compressed GPS trace for future replay feature

**DailySummary:**
- `dateString: String` — "2026-03-02" format
- `cellsRevealed: Int`, `distanceMeters: Double`, `stepCount: Int`, `isActiveDay: Bool`

**iCloud sync:** `ModelConfiguration(cloudKitDatabase: .automatic)`. Deduplication on launch merges duplicates (keep earliest `firstVisitedAt`, sum `visitCount`, keep latest `lastVisitedAt`).

### Frequency-Weighted Stray Algorithm

The compass doesn't just point toward unvisited cells. It weighs by visit frequency so it always has somewhere to point, even after years of use:

1. **Search:** Enumerate all cells within 500m radius of user.
2. **Score:** Assign each cell a weight based on visit frequency:
   - Never visited: 1.0
   - Visited 1-2 times: 0.7
   - Visited 3-5 times: 0.3
   - Visited 6+ times: 0.0
3. **Filter:** Remove cells with weight 0.
4. **Cluster:** BFS flood-fill over remaining cells, tracking total weight per cluster.
5. **Select:** Choose the cluster with the highest total weight.
6. **Bearing:** Compute geographic bearing from user to cluster's weight-adjusted centroid.
7. **Update:** Recalculate on new cell reveal or every 5 seconds during movement.

This means:
- Fresh users → compass points toward unvisited areas (same as a binary system)
- Long-time users → compass points toward neglected areas
- The compass always has somewhere to point. It never runs out.

### Per-City Detection

To show per-city stats, we need to know which city a cell belongs to:

- **On first visit to a new cell:** Call `CLGeocoder.reverseGeocodeLocation()` to get the city name. Store on the `RevealedCell` record.
- **Rate limiting:** Apple limits reverse geocoding to ~50 requests/minute. Queue requests, batch when possible, and cache aggressively (if adjacent cells are in the same city, skip the API call).
- **Fallback:** If geocoding fails, store `nil`. Retry later.

---

## Implementation Phases

### Phase 1: Foundation
**Goal:** Xcode project scaffold, data models, basic map on screen.

| Step | File(s) | Description |
|---|---|---|
| 1.1 | Project | Create Xcode project: iOS App, SwiftUI, iOS 17.0 minimum. Bundle ID: `com.<team>.Stray`. Add capabilities: Background Modes (Location updates, Remote notifications), iCloud (CloudKit). |
| 1.2 | Folders | Create `Views/`, `ViewModels/`, `Models/`, `Services/`, `Utilities/` directories |
| 1.3 | `Constants.swift` | Grid cell size (50m), search radius (500m), fog color, heat gradient colors, accuracy thresholds |
| 1.4 | `Extensions.swift` | `CLLocationCoordinate2D` extensions: distance between coordinates, bearing calculation |
| 1.5 | `GridCell.swift` | `struct GridCell: Hashable, Codable, Sendable` — lat/lng index math, coordinate conversion, global support |
| 1.6 | `RevealedCell.swift` | SwiftData `@Model` with visitCount, city, all properties defaulted, indexes |
| 1.7 | `StraySession.swift` | SwiftData `@Model` for session records |
| 1.8 | `DailySummary.swift` | SwiftData `@Model` for daily aggregations with stepCount |
| 1.9 | `StrayApp.swift` | `@main` entry point: `ModelContainer` with CloudKit config, service initialization |
| 1.10 | `MapViewRepresentable.swift` | `UIViewRepresentable` wrapping `MKMapView` with user location, delegate/coordinator |
| 1.11 | `ContentView.swift` | Full-screen map |
| 1.12 | `Info.plist` | Location usage descriptions |

**Validation:** App launches, shows a full-screen Apple Maps view with user location blue dot. No fog yet.

---

### Phase 2: The Fog + Heat Gradient
**Goal:** Dark fog overlay with heat-colored revealed cells. The visual identity comes to life.

| Step | File(s) | Description |
|---|---|---|
| 2.1 | `GridEngine.swift` | `Dictionary<GridCell, Int>` for cell → visit count mapping. `isRevealed()`, `revealCell()`, `visitCount(for:)`, `cellsWithCounts(in: MKCoordinateRegion)` |
| 2.2 | `FogTileOverlay.swift` | `MKTileOverlay` subclass: fog tiles with heat gradient coloring. Dark fill → clear/tint based on visit frequency. Background queue dispatch. |
| 2.3 | `MapViewRepresentable.swift` | Add fog overlay to map. Wire `MKTileOverlayRenderer` in coordinator delegate. |
| 2.4 | Test | Hardcode cells with varying visit counts. Verify: fog is dark, 1-visit cells are cool blue, high-frequency cells are warm amber. |
| 2.5 | `MapViewRepresentable.swift` | Tile refresh: `reloadData()` trigger on cell changes. |
| 2.6 | `GridEngine.swift` | Spatial index (bucket by integer lat/lng degree) for fast tile queries at scale. |

**Validation:** Dark-fogged map with heat-colored holes. Cool blue for single visits, transparent for moderate, warm amber for frequent. Panning/zooming smooth at all levels.

---

### Phase 3: Location Tracking
**Goal:** Walk around and see cells reveal in real-time with correct heat coloring.

| Step | File(s) | Description |
|---|---|---|
| 3.1 | `LocationService.swift` | Passive tracking: `CLLocationUpdate.liveUpdates(.default)`, `CLBackgroundActivitySession`, `isStationary` filtering, accuracy threshold, distance accumulation between updates. |
| 3.2 | `PersistenceService.swift` | `saveOrUpdateCell()` — create new `RevealedCell` or increment `visitCount` on existing. `updateDailySummary()` — increment cells, distance, steps. |
| 3.3 | Wire pipeline | Location → `GridEngine.revealCell()` → `PersistenceService` → fog `reloadData()`. Distance accumulation → step estimation. |
| 3.4 | `OnboardingView.swift` | Permission request flow: explain why location is needed, request "When In Use", later prompt "Always". |
| 3.5 | `GridEngine.swift` | `loadCells(from: ModelContext)` — populate in-memory dictionary from SwiftData on launch. |
| 3.6 | City detection | On new cell reveal, queue `CLGeocoder.reverseGeocodeLocation()` to tag with city name. Rate limit and cache. |
| 3.7 | Test on device | Walk with app. Verify real-time reveal. Lock phone, walk, reopen — verify background tracking. Revisit a path — verify visit count increments and heat color changes. |

**Validation:** Cells reveal in real-time. Revisited cells shift in heat color over time. Background tracking works. Distance and steps accumulate. City name is detected and stored.

---

### Phase 4: Stray Mode
**Goal:** The frequency-weighted compass pulls you toward the neglected and unknown.

| Step | File(s) | Description |
|---|---|---|
| 4.1 | `StrayEngine.swift` | `scoredCellsNearby(center:radius:)` — enumerate cells in 500m radius, assign frequency weights. |
| 4.2 | `StrayEngine.swift` | `findHighestWeightCluster(in:)` — BFS flood-fill, rank clusters by total weight. |
| 4.3 | `StrayEngine.swift` | `bearingToCluster(from:cluster:)` — bearing to weight-adjusted centroid. |
| 4.4 | `StraySessionViewModel.swift` | Session lifecycle: start/stop, timer, distance + step tracking, cells-revealed counter. |
| 4.5 | `LocationService.swift` | Active tracking mode: switch to `.automotiveNavigation` during Stray sessions. |
| 4.6 | `StrayCompassView.swift` | Compass arrow: animated rotation, smooth bearing interpolation. Minimal, confident design. |
| 4.7 | `ContentView.swift` | "Start Stray" floating button. During session: compass overlay + session info (time, cells, distance) + "End Stray" button. |
| 4.8 | `PersistenceService.swift` | Save completed `StraySession` to SwiftData on end. |
| 4.9 | Edge cases | No high-weight cells nearby → "You've explored everything nearby — venture further." GPS unavailable → graceful message. |

**Validation:** Compass points toward unexplored/low-frequency areas. Arrow updates as you move. Revisited neighborhoods get lower pull. Sessions save correctly.

---

### Phase 5: Stats & Navigation
**Goal:** Complete the daily loop with stats, settings, and onboarding.

| Step | File(s) | Description |
|---|---|---|
| 5.1 | `StatsEngine.swift` | Queries: total cells, streak, distance, steps, session count, per-city breakdown (group `RevealedCell` by `city`). |
| 5.2 | `StatsViewModel.swift` | Format stats, auto-refresh on data changes. Per-city list sorted by cell count. |
| 5.3 | `StatsView.swift` | Clean layout: big numbers for today (cells, distance, steps), lifetime totals, streak, per-city breakdown list ("Portland — 4,231 cells" / "Tokyo — 342 cells"). |
| 5.4 | `SettingsView.swift` | Tracking toggle, permission status, about section. |
| 5.5 | `ContentView.swift` | Navigation: map as primary, bottom sheet for stats/settings. Map never leaves the screen. |
| 5.6 | `OnboardingView.swift` | 1-2 screen intro, permission request with context, straight to map. |

**Validation:** Stats show correct data including per-city breakdown. Distance and steps match expectations. Bottom sheet navigation feels natural without hiding the map.

---

### Phase 6: Sync & Polish
**Goal:** iCloud sync works, app feels polished and intentional.

| Step | File(s) | Description |
|---|---|---|
| 6.1 | `StrayApp.swift` | Verify CloudKit config. Test on real device with iCloud account. |
| 6.2 | `PersistenceService.swift` | Deduplication: on launch + sync events, merge `RevealedCell` records with same `cellKey`. |
| 6.3 | Polish | Cell reveal bloom animation (smooth fade from dark to heat color, not instant pop). |
| 6.4 | Polish | Compass arrow smooth rotation (interpolate bearing changes). |
| 6.5 | Battery | Profile with Xcode Energy Diagnostics. Verify `isStationary` works. Battery-level monitoring. |
| 6.6 | Edge cases | Fresh install, poor GPS indoors, airplane mode, app killed by OS, zoomed-out rendering, international travel (timezone/city boundaries). |
| 6.7 | `Info.plist` | Finalize location descriptions, background modes, CloudKit container. |

**Validation:** iCloud sync works across devices. Battery is minimal when idle. Bloom animations feel satisfying. App handles all edge cases gracefully. Ready for daily use.

---

## Appendix: Required Xcode Configuration

### Capabilities
- **Background Modes:** Location updates, Remote notifications (for CloudKit push sync)
- **iCloud:** CloudKit (create container `iCloud.com.<team-id>.Stray`)

### Info.plist Keys
- `NSLocationWhenInUseUsageDescription`: "Stray uses your location to reveal the parts of your world you've explored."
- `NSLocationAlwaysAndWhenInUseUsageDescription`: "Always-on location lets Stray track your exploration even when the app is in the background, so you never miss a step."
- `UIBackgroundModes`: `location`, `remote-notification`

### Signing
- Requires Apple Developer account for CloudKit and background location
- Development and distribution provisioning profiles with iCloud + Push Notifications entitlements
