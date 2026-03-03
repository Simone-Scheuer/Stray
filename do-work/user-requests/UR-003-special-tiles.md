---
id: UR-003
title: "Special Tiles — User-marked cells (home, work, custom)"
created_at: 2026-03-02
status: pending
---

# UR-003: Special Tiles

## Overview
Let users mark specific grid cells as "special" — home, work, or custom labels. These tiles render with a distinct visual treatment on the map and show their label in the cell inspector. This is a lightweight personal-landmark system, not a full POI database.

## Requirements

### REQ-013: SpecialTile SwiftData model
- New `@Model` class `SpecialTile` with properties:
  - `cellKey: String = ""` — matches `RevealedCell.cellKey` format (`"latIndex_lngIndex"`)
  - `latIndex: Int = 0`
  - `lngIndex: Int = 0`
  - `label: String = ""` — user-chosen name (e.g. "Home", "Work", "Coffee spot")
  - `icon: String = "star.fill"` — SF Symbol name, default star
  - `colorHex: String = "#FFD700"` — hex color string, default gold
  - `createdAt: Date = Date()`
- Remember: no `@Attribute(.unique)`, all properties have defaults (CloudKit rules)
- Register `SpecialTile.self` in `ModelContainer` in `StrayApp.init()`
- **Files:** Create `Stray/Models/SpecialTile.swift`, edit `Stray/StrayApp.swift`

### REQ-014: PersistenceService CRUD for special tiles
- Add to `PersistenceService`:
  - `saveSpecialTile(cell: GridCell, label: String, icon: String, colorHex: String)` — creates or updates a SpecialTile for the given cell
  - `deleteSpecialTile(for cell: GridCell)` — removes the special tile marker
  - `fetchSpecialTile(for cell: GridCell) -> SpecialTile?` — lookup by cellKey
  - `fetchAllSpecialTiles() -> [SpecialTile]` — for rendering on map
- **Files:** Edit `Stray/Services/PersistenceService.swift`

### REQ-015: GridEngine awareness of special tiles
- Add `private(set) var specialTiles: [GridCell: SpecialTile] = [:]` dictionary to GridEngine
- Add `loadSpecialTiles(from context: ModelContext)` — populates the dict, call from `loadCells` or separately
- Add `specialTile(for cell: GridCell) -> SpecialTile?` — quick lookup
- On save/delete of a special tile, update the dict and bump `renderGeneration`
- **Files:** Edit `Stray/Services/GridEngine.swift`

### REQ-016: Render special tiles on the fog overlay
- In `FogOverlayRenderer.draw(_:zoomScale:in:)`, after punching the heat-colored hole, check if the cell has a special tile
- If yes, draw a small filled circle (or the SF Symbol glyph) centered in the cell rect, using the tile's color
- Keep it simple: a colored dot/ring is sufficient for v1. SF Symbol rendering in Core Graphics is complex — use a filled circle with the tile's `colorHex` parsed to UIColor
- At very low zoom levels, skip special tile rendering (they'd be invisible anyway — already handled by the `latitudeDelta > 1.0` early return)
- **Files:** Edit `Stray/Services/FogOverlay.swift`, add a `UIColor` hex initializer in `Stray/Utilities/Extensions.swift`

### REQ-017: Mark/unmark tiles via CellInspectorView
- Expand `CellInspectorView` to show special tile status:
  - If the cell has a special tile: show its label, icon, color, and a "Remove Marker" button
  - If the cell is explored but not special: show a "Mark This Tile" button
  - If the cell is unexplored: no special tile option (can't mark fog)
- "Mark This Tile" presents a small inline form:
  - Preset buttons: "Home" (house.fill, #4A90D9), "Work" (briefcase.fill, #7B68EE), "Favorite" (star.fill, #FFD700)
  - Or a text field for custom label with the star.fill icon and gold color as defaults
- On save, call `persistenceService.saveSpecialTile(...)` and update GridEngine
- On remove, call `persistenceService.deleteSpecialTile(...)` and update GridEngine
- Increase `.presentationDetents` to accommodate the form (maybe `.medium` when editing)
- **Files:** Edit `Stray/Views/CellInspectorView.swift`

### REQ-018: Wire special tiles into app lifecycle
- In `StrayApp.init()`, after `grid.loadCells(from: context)`, also load special tiles: `grid.loadSpecialTiles(from: context)`
- In `deduplicateAndReload()`, also reload special tiles
- Pass `gridEngine` (which already holds special tiles) — no new environment values needed
- **Files:** Edit `Stray/StrayApp.swift`

## Preset Tiles
Three built-in presets (user can always type custom):
| Preset   | SF Symbol       | Color   |
|----------|-----------------|---------|
| Home     | house.fill      | #4A90D9 |
| Work     | briefcase.fill  | #7B68EE |
| Favorite | star.fill       | #FFD700 |

## Dependency Order
1. REQ-013 (model) — foundation, do first
2. REQ-014 (persistence) — depends on model
3. REQ-015 (GridEngine) — depends on model
4. REQ-016 (rendering) — depends on GridEngine integration
5. REQ-017 (UI) — depends on persistence + GridEngine
6. REQ-018 (wiring) — depends on all above

REQ-014 and REQ-015 can be parallelized after REQ-013.

## Non-Goals
- No special tile search/list view (v1.2+)
- No sharing special tiles between users
- No limit on number of special tiles (revisit if performance issue arises)
- No custom icon picker beyond presets (v1.2+)
- No custom color picker beyond presets (v1.2+)
