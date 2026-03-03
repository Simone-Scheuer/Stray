---
id: REQ-002
title: "Phase 2: Fog + Heat Gradient — GridEngine and FogTileOverlay"
status: completed
created_at: 2026-03-02T12:00:00Z
claimed_at: 2026-03-02T12:32:00Z
route: C
completed_at: 2026-03-02T13:00:00Z
user_request: UR-001
related: [REQ-001, REQ-003, REQ-004, REQ-005, REQ-006]
batch: stray-mvp
---

# Phase 2: Fog + Heat Gradient

## What
Implement the GridEngine (in-memory cell management with visit counts) and FogTileOverlay (MKTileOverlay subclass that renders dark fog with heat-colored holes via Core Graphics). Wire the fog overlay into the map.

## Detailed Requirements

1. **GridEngine.swift** — `@Observable` class managing `Dictionary<GridCell, Int>` (cell → visit count). Methods:
   - `isRevealed(_ cell: GridCell) -> Bool`
   - `revealCell(at coordinate: CLLocationCoordinate2D) -> GridCell?` — returns cell if newly revealed, increments visit count if already known
   - `visitCount(for cell: GridCell) -> Int`
   - `cellsWithCounts(in region: MKCoordinateRegion) -> [(GridCell, Int)]` — for tile rendering
   - `loadCells(from context: ModelContext)` — populate from SwiftData on launch
   - Spatial index: bucket cells by integer lat/lng degree for fast regional queries

2. **FogTileOverlay.swift** — `MKTileOverlay` subclass. Override `loadTile(at:result:)`:
   - Determine geographic bounds of tile from `MKTileOverlayPath`
   - Create 256x256 `CGContext` filled with fog color `UIColor(white: 0.08, alpha: 0.85)`
   - For each revealed cell in tile bounds, render based on visit count:
     - 1 visit: clear fog, fill with cool blue tint `UIColor(red: 0.3, green: 0.4, blue: 0.8, alpha: 0.25)`
     - 2-5 visits: fully clear (transparent) — vivid base map shows through
     - 10+ visits: clear fog, fill with warm amber `UIColor(red: 0.9, green: 0.6, blue: 0.2, alpha: 0.2)`
     - 50+ visits: clear fog, fill with bright glow `UIColor(red: 1.0, green: 0.8, blue: 0.3, alpha: 0.25)`
   - Return PNG data
   - **All tile generation on background queue** — dispatch to `DispatchQueue.global(qos: .userInitiated)`
   - `canReplaceMapContent = false` (overlay on top of base map)
   - `tileSize = CGSize(width: 256, height: 256)`

3. **Wire into MapViewRepresentable** — Add `FogTileOverlay` to `MKMapView` with `.aboveLabels` level. Return `MKTileOverlayRenderer` in coordinator's `rendererFor:` delegate. Expose `reloadData()` trigger.

4. **Test with hardcoded cells** — Add 10-20 cells around Portland with varying visit counts. Verify visual output.

## Constraints

- Tile rendering MUST be off main thread
- Only reload tiles when cells actually change (not on every location update)
- Must handle zoomed-out rendering gracefully (sub-pixel cells at low zoom are ok to skip)
- Reference specific color values from Constants.swift

## Dependencies

- Depends on: REQ-001 (GridCell, models, MapViewRepresentable)
- Can partially parallelize with REQ-003 (after GridEngine is built)
- Blocks: REQ-004 (Stray Mode needs GridEngine)

## Builder Guidance

- Certainty level: Firm — rendering approach is decided (MKTileOverlay + Core Graphics)
- This is the most technically challenging component. Get the tile math right.
- Reference: IMPLEMENTATION_PLAN.md "Fog + Heat Gradient Rendering" section for exact tile generation logic

## Full Context
See [user-requests/UR-001/input.md](./user-requests/UR-001/input.md) for complete verbatim input.

---

## Triage

**Route: C** - Complex

**Reasoning:** Most technically challenging component — tile coordinate math (Web Mercator → geographic), Core Graphics rendering pipeline, spatial indexing for fast queries, and wiring into MKMapView overlay system. Introduces new architectural patterns (GridEngine as @Observable service, FogTileOverlay as MKTileOverlay subclass). Getting tile math wrong = visual bugs.

**Planning:** Required

## Plan

### Files to Create/Modify

| Action | File | Description |
|--------|------|-------------|
| Create | `Stray/Services/GridEngine.swift` | @Observable, Dictionary<GridCell,Int>, spatial index by integer lat/lng degree |
| Create | `Stray/Services/FogTileOverlay.swift` | MKTileOverlay subclass, Web Mercator tile math, Core Graphics rendering |
| Modify | `Stray/Views/MapViewRepresentable.swift` | Wire overlay, rendererFor delegate, reloadData trigger |
| Modify | `Stray/Views/ContentView.swift` | Create GridEngine, add test cells in DEBUG |

### Implementation Order
1. GridEngine.swift — cell dictionary + spatial index + regional query
2. FogTileOverlay.swift — tile bounds math + Core Graphics fog/heat rendering
3. MapViewRepresentable.swift — add overlay, renderer delegate, change-driven reload
4. ContentView.swift — wire GridEngine, add hardcoded Portland test cells

### Key Technical Decisions
- **Spatial index:** bucket cells by `(Int(floor(lat)), Int(floor(lng)))` — each bucket covers ~111km, narrows tile queries from O(n) to O(bucket_size)
- **Tile math:** Standard Web Mercator — `lng = x/2^z * 360 - 180`, `lat = atan(sinh(π * (1 - 2y/2^z))) * 180/π`
- **Mercator pixel projection:** horizontal linear in longitude, vertical via `log(tan(π/4 + lat*π/360))`
- **Rendering:** Use `UIGraphicsImageRenderer` (modern API), fill fog, `.clear` blend mode to punch holes, `.normal` for heat tint
- **Heat color 6-9 visits:** transparent (same as 2-5), bridging gap in spec
- **Change detection:** `changeCounter` Int on GridEngine, read in `updateUIView` to trigger `reloadData()`
- **Query region padding:** expand tile bounds by 2× cell width to catch cells straddling tile edge

*Generated by Plan agent*

## Exploration

- **GridCell.swift** (existing): `struct GridCell: Hashable, Codable, Sendable` with `latIndex`, `lngIndex`, `latStep`, `lngStep(atLatitude:)`, `from(latitude:longitude:)`, `coordinate` (SW corner), `key`
- **Constants.swift** (existing): `fogColor = UIColor(white: 0.08, alpha: 0.85)`, `heatCoolBlue`, `heatTransparent`, `heatWarmAmber`, `heatBrightGlow` — all ready to consume
- **MapViewRepresentable.swift** (existing, 31 lines): minimal UIViewRepresentable with Coordinator as MKMapViewDelegate, `mapView(_:didUpdate:)` stub, no overlay support yet
- **ContentView.swift** (existing, 9 lines): just `MapViewRepresentable().ignoresSafeArea()`
- **RevealedCell.swift** (existing): @Model with `latIndex`, `lngIndex`, `cellKey`, `visitCount`, `city`, timestamps — GridEngine.loadCells will fetch these
- **Services/ directory**: exists but empty — ready for GridEngine.swift and FogTileOverlay.swift
- **No existing overlay or renderer patterns** — this is the first overlay in the project

*Generated by Explore agent (inline — plan agent already explored files)*

## Implementation Summary

- Created `Stray/Services/GridEngine.swift` — @Observable class with Dictionary<GridCell,Int>, SpatialBucket index, changeCounter for reactive tile reloads, regional query, SwiftData loading, DEBUG test cells for Portland
- Created `Stray/Services/FogTileOverlay.swift` — MKTileOverlay subclass with Web Mercator tile math, UIGraphicsImageRenderer fog/heat rendering on background queue, padded region queries, heat color mapping from Constants
- Modified `Stray/Views/MapViewRepresentable.swift` — added GridEngine param, FogTileOverlay creation, .aboveLabels overlay, rendererFor delegate, change-counter-driven reloadData()
- Modified `Stray/Views/ContentView.swift` — @State GridEngine, passes to MapViewRepresentable, DEBUG test cells on appear
- Regenerated `Stray.xcodeproj` via xcodegen (auto-includes new files)

*Completed by work action (Route C)*

## Testing

**Tests run:** `xcodebuild -project Stray.xcodeproj -scheme Stray -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2' build`
**Result:** BUILD SUCCEEDED, zero errors

**Notes:** No unit test infrastructure in MVP. Visual verification needed on device — 20 hardcoded Portland cells with visit counts 1-100 should show all four heat gradient bands (cool blue, transparent, warm amber, bright glow) over dark fog.

*Verified by work action*

---
*Source: See UR-001/input.md for full verbatim input*
