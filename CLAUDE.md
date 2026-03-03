# Stray — Project Guidelines

## What Is This

Stray is an iOS exploration app. Dark fog covers unexplored areas of a map; cells bloom into color as you walk. A frequency-weighted compass pulls you toward places you've never been or rarely visit. Inspired by Situationist psychogeography. Anti-optimization by design.

**Read before working:** [PRD.md](PRD.md) and [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md) are the source of truth for product and technical decisions.

## Tech Stack

- **iOS 17.0+**, Swift, SwiftUI
- **MapKit** (`MKMapView` via `UIViewRepresentable` — SwiftUI's `Map` lacks tile overlay support)
- **CoreLocation** (`CLLocationUpdate` async API, `CLBackgroundActivitySession`)
- **SwiftData** with automatic CloudKit sync
- **Zero third-party dependencies**

## Architecture

**MVVM with `@Observable`** — the native SwiftUI pattern. No TCA, no VIPER, no coordinators.

```
Views → ViewModels (@Observable) → Services → Models (@Model)
```

- **Views/** — SwiftUI views + one `UIViewRepresentable` for MKMapView
- **ViewModels/** — one per screen, `@Observable` classes
- **Models/** — SwiftData `@Model` classes + `GridCell` value type
- **Services/** — stateless-ish managers (LocationService, GridEngine, FogTileOverlay, StrayEngine, PersistenceService, StatsEngine)
- **Utilities/** — constants, extensions

Services are injected via SwiftUI `.environment()`. No singletons except `ModelContainer`.

## Critical Conventions

### SwiftData + CloudKit Constraints (Non-Negotiable)
- **No `@Attribute(.unique)`** — CloudKit forbids uniqueness constraints
- **All properties must have defaults** — every `@Model` property needs a default value
- **All relationships must be optional** — CloudKit requirement
- **Lightweight migrations only** — once deployed, only add properties (with defaults), never remove/rename
- **Deduplication is required** — multi-device sync creates duplicates; merge on launch by `cellKey`

### Grid System
- ~50m cells via custom lat/lng math (NOT geohash, NOT H3)
- `GridCell` is a plain `struct`, NOT a SwiftData model
- In-memory `Dictionary<GridCell, Int>` (cell → visit count) for rendering queries
- `RevealedCell` is the SwiftData `@Model` that persists to disk/iCloud

### Fog Rendering
- `FogTileOverlay` extends `MKTileOverlay` — generates 256x256 tiles via Core Graphics
- Dark fog: `UIColor(white: 0.08, alpha: 0.85)`
- Heat gradient on revealed cells: cool blue (1 visit) → transparent (2-5) → warm amber (10+) → bright glow (50+)
- Tile generation runs on background queue, never main thread
- Refresh via `MKTileOverlayRenderer.reloadData()` — only call when cells actually change

### Location Tracking
- Passive mode: `.liveUpdates(.default)` — battery efficient
- Active Stray mode: `.liveUpdates(.automotiveNavigation)` — high accuracy
- ALWAYS check `isStationary` — skip processing when true (biggest battery saver)
- ALWAYS filter `horizontalAccuracy > 100m` (passive) or `> 50m` (active)
- Steps estimated from GPS distance (`distance / 0.7`), no Motion permission needed

### Battery is Sacred
- No timer-based polling, ever
- No processing when stationary
- No unnecessary location updates
- Profile with Xcode Energy Diagnostics before shipping

## Code Style

- Keep it simple. This is built by a student with Claude's help. Prefer obvious code over clever code.
- Use Swift concurrency (async/await, Task) — no Combine unless MapKit forces it
- No force unwraps in production code (test helpers are fine)
- Every `@Model` property gets a default value — this is a CloudKit hard requirement, not style preference
- Prefer `struct` over `class` except for `@Observable` view models and `@Model` data classes
- No comments explaining what code does — only why (when non-obvious)

## What NOT to Do

- Don't add third-party dependencies without explicit approval
- Don't use `@Attribute(.unique)` on any SwiftData model (CloudKit will break)
- Don't put tile rendering on the main thread
- Don't poll for location on a timer
- Don't add gamification dark patterns (streak-loss warnings, aggressive notifications, leaderboards)
- Don't add turn-by-turn navigation — the compass points, it doesn't navigate
- Don't create new screens beyond: Map (primary), Stats (sheet), Settings (sheet), Onboarding (first launch)
- Don't duplicate data the camera roll already has — reference photos, don't copy them (v1.2+)

## Multi-Agent Workflow

When implementing, phases can be parallelized where dependencies allow:

- **Phase 1 (Foundation)** must complete first — everything depends on it
- **Phase 2 (Fog) and Phase 3 (Location)** share GridEngine but can be partially parallelized: build GridEngine in Phase 2, then fog rendering and location tracking can proceed in parallel
- **Phase 4 (Stray Mode)** depends on both Phase 2 and 3
- **Phase 5 (Stats) and Phase 6 (Polish)** can be partially parallelized

For agent-based implementation:
- Agent 1: Models + GridEngine + utilities (foundation layer)
- Agent 2: FogTileOverlay + MapViewRepresentable (rendering layer, depends on Agent 1)
- Agent 3: LocationService + PersistenceService (tracking layer, depends on Agent 1)
- After Agents 2+3: StrayEngine, views, polish

## Testing Strategy

No unit test framework in MVP — validate manually on device:
- Walk with app open → cells bloom in real-time
- Lock phone, walk 10 min, reopen → background cells revealed
- Revisit a path → heat colors shift warmer
- Start Stray → compass points toward dark/cool areas
- Kill app, relaunch → all data persists
- Second device with same iCloud → data syncs
