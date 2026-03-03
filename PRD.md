# Stray — Product Requirements Document

**Version:** 2.0
**Date:** March 2, 2026
**Status:** Pre-Development

---

## 1. Vision

Stray is a personal exploration app inspired by Guy Debord and the Situationist International's concept of the *dérive* — an unplanned journey through urban landscapes guided by curiosity rather than efficiency.

**Problem:** Every map app optimizes your route. No app helps you *disrupt* your route. People walk the same paths daily, missing 90%+ of their own city. Existing fog-of-war apps (Fog of World, $30) treat exploration as a completionist game — filling in a spreadsheet, not cultivating an experience.

**Thesis:** Stray is anti-optimization. It reveals how little of your world you've actually seen, and gently pulls you toward the unfamiliar. It transforms everyday walking into a practice of intentional discovery.

**Tagline:** Life Cartography.

---

## 2. Target User

Primary: Urban walkers who are curious about their surroundings and want to break habitual routes. People who played Pikmin Bloom, enjoy wandering, and find satisfaction in seeing the invisible patterns of their daily life made visible. Travelers who want to deeply explore new cities, not just hit the tourist spots.

Not primarily for: Athletes tracking performance, tourists following guides, or gamers chasing achievements. Stray is a personal practice, not a game.

---

## 3. Core Experience

A full-screen map where unexplored areas are **heavily darkened**. As you walk, ~50m grid cells **bloom into full color** — a strong visual juxtaposition between the dark unknown and the vivid explored. Cells you revisit frequently glow warmer, creating a living heat map of your habits.

### The Daily Loop

1. **Glance** — Open app or widget. See the dark fog surrounding your usual routes. Notice the warm glow of your habitual paths and the cool blue of places visited once.
2. **Stray** — Tap "Start Stray." A compass arrow pulls you toward areas you've never visited or rarely go. Not turn-by-turn directions. Just a pull.
3. **Walk** — Cells bloom into color in real-time as you cross them. The satisfying reveal IS the reward.
4. **Reflect** — Check stats. See your city slowly filling in over weeks and months. Notice how your exploration patterns change.

### The Single Moment We're Designing For

Walking through your city, seeing the parts you've never been to rendered as dark voids on the map, and feeling the pull to venture into them. Then watching the fog dissolve as you step into the unknown for the first time.

---

## 4. MVP Features (v1.0)

### 4.1 Fog-of-War Map with Heat Gradient

**The primary screen. The entire app centers on this.**

- Full-screen map using MapKit
- Unexplored areas covered with a dark overlay (~85% opacity)
- The underlying map is faintly visible through the fog (road shapes discernible, labels hidden) — preserving navigational context while maintaining mystery
- Revealed cells are colored by visit frequency (heat gradient):
  - 1 visit: faint cool blue tint — "I've been here once"
  - 2-5 visits: full-color map (transparent) — familiar territory
  - 10+ visits: warm amber tint — regular routes
  - 50+ visits: bright glow — home base, daily paths
- This creates a living thermal map of your habits. The heat gradient solves two problems:
  1. The map never becomes "complete" — frequency data is always changing
  2. Stray Mode can direct you toward neglected areas, not just unvisited ones
- Cells reveal in real-time as the user walks — the "bloom" effect
- World divided into ~50-meter grid cells
- User's current location shown with standard blue dot
- Standard map controls (zoom, pan, compass)

### 4.2 Background Location Tracking

**Must be invisible, reliable, and battery-friendly.**

- Passive background tracking records which grid cells the user visits and how often
- Works with "Always" location permission (recommended) or "When In Use" (degraded — only tracks when app is foregrounded)
- Battery-efficient: skips processing when user is stationary, filters out low-accuracy readings, uses OS-optimized update cadence
- No timer-based polling — reactive to OS-delivered location updates only
- Target: negligible battery impact when stationary, modest impact during movement
- Records distance walked (derived from GPS coordinates, no pedometer permission needed)
- Estimates step count from distance (distance / 0.7m average stride) — avoids Motion & Fitness permission

### 4.3 Stray Mode (Session-Based)

**The signature feature. What makes this Stray and not just another fog map.**

- User taps "Start Stray" to begin a session
- App analyzes a 500m radius around the user using frequency-weighted scoring:
  - Never visited: weight 1.0 (highest pull)
  - Visited 1-2 times: weight 0.7
  - Visited 3-5 times: weight 0.3
  - Visited 6+ times: weight 0.0 (no pull)
- Clusters adjacent high-weight cells and finds the largest cluster
- Displays a compass arrow pointing toward the centroid of that cluster
- Arrow updates in real-time as user moves and reveals new cells
- Higher-accuracy GPS during active sessions (user expects battery usage during intentional exploration)
- User taps "End Stray" to close the session
- Session is saved with: start time, end time, cells revealed, distance walked, steps, duration
- **This never runs out.** Even after years of use, there are always low-frequency zones to pull toward. The compass always has somewhere to point.

### 4.4 Basic Stats

- **Total cells revealed** — lifetime count
- **Current streak** — consecutive days with at least 1 new cell revealed
- **Distance walked** — cumulative miles tracked (derived from GPS)
- **Steps** — estimated from distance (distance / 0.7m stride)
- **Stray sessions** — count of completed sessions
- **Today** — cells revealed today, distance, steps
- **Per-city breakdown** — cells revealed grouped by city/region (auto-detected from coordinates). When traveling, each city becomes its own entry: "Portland — 4,231 cells" / "Tokyo — 342 cells, 3 days"

### 4.5 iCloud Sync

- All exploration data syncs automatically via user's iCloud account
- No custom server, no account creation, no sign-up
- Data survives phone loss/replacement
- Handles multi-device conflicts gracefully (deduplication on launch)

---

## 5. Scope & Roadmap

### What's NOT in MVP

| Feature | Target Version | Rationale |
|---|---|---|
| Novel routing to destinations | v1.1 | "Show me an unexplored route to Powell's Books." Strong feature but requires MKDirections + waypoint generation. Different interaction model from compass. |
| End-of-day replay animation | v1.1 | Strong hook but not required to prove the core works |
| iOS home screen widget | v1.1 | Important for "glance daily" loop, but not day-one critical |
| Situationist text prompts in Stray Mode | v1.1 | MVP compass is purely directional. Poetic prompts like "walk toward the oldest building you can see" come later. |
| Day trace recording (GPS path per day) | v1.2 | The "memory layer" — see your exact path on any given day |
| In-app photo capture + map placement | v1.2 | Take a photo during a walk, it appears as a pin on your map at that location |
| Photo auto-placement from camera roll | v1.2 | Complex (permissions, GPS metadata parsing, backfill performance) |
| "This day last year" notifications | v1.2 | Requires a year of data to be meaningful |
| Social / shared fog / group strays | v1.3+ | Solo-first. Prove the personal practice first. |
| Apple Watch | Future | Aspirational, not essential |
| Monetization | Post-PMF | Ship free to friends, figure out money if it grows |

### Post-MVP Roadmap

**v1.1 — Routes & Replay**
- Novel routing: set a destination, get a route through unexplored/low-frequency areas (waypoint-based via MKDirections)
- End-of-day replay animation (tiles bloom in chronological sequence, 30-second playback)
- iOS home screen widget showing fog map centered on current location
- Situationist text prompts as an alternative Stray mode ("follow the sound," "turn toward something old")

**v1.2 — Memory Layer**
- Day trace recording (GPS path per day, not just cells)
- Animated day trace playback ("this is what my Tuesday in Tokyo looked like")
- In-app photo capture with automatic map placement
- Photo auto-placement from camera roll (GPS metadata backfill)
- Spot stories: view all photos ever taken at a specific location

**v1.3+ — Community**
- Shared city fog (collective map of community exploration)
- Anonymous path sharing ("walk a stranger's path from last week")
- Group Stray sessions (friends scatter, compare paths afterward)
- City-specific exploration statistics

---

## 6. Design Principles

### 6.1 Anti-Optimization

Every other map app makes you more efficient. Stray makes you less efficient on purpose. This philosophy informs every design decision:
- No turn-by-turn directions (the compass points, it doesn't navigate)
- No "optimal route to reveal the most cells"
- No leaderboard
- The value is in the practice, not the score

### 6.2 Minimal Chrome

The map IS the interface. UI elements are overlays, not destinations. The less UI between the user and the map, the better.

### 6.3 The Bloom

The moment of revealing a cell should feel satisfying. The transition from dark to vivid color should be the app's signature micro-interaction. This is the Pikmin Bloom equivalent — the small delight that makes you want to walk one more block.

### 6.4 Quiet Confidence

Stray doesn't beg for attention. No aggressive notifications, no streaks-are-ending warnings, no gamification dark patterns. It's a journal, not a game. The data compounds silently. After six months, you have something irreplaceable.

### 6.5 Global by Default

Stray is for your whole life, not one city. Your map is a record of everywhere you've ever walked — Portland, Tokyo, a random town in Portugal. Each place is a chapter. Travel is when the app is at its most exciting.

---

## 7. Brand

- **Name:** Stray
- **Tagline:** Life Cartography
- **Meaning:** To wander from the expected path. Slightly rebellious. Implies breaking routine on purpose. One syllable, memorable, searchable, easy to type.
- **Aesthetic:** Dark fog contrasting with vivid revealed map. Warm amber for familiar territory, cool blue for the newly discovered. Minimal UI. Feels like a beautiful personal atlas, not a tech product.
- **Philosophical root:** Situationist International, psychogeography, the practice of urban drifting

---

## 8. Screens

### 8.1 The Map (Primary)
- Full-screen MKMapView with fog tile overlay + heat gradient
- User location blue dot
- Floating "Start Stray" button (bottom center)
- During Stray: compass arrow overlay, session timer, cells revealed count, "End" button
- Minimal other chrome — map dominates

### 8.2 Stats
- Cells revealed (lifetime + today)
- Distance + steps (today + lifetime)
- Current streak
- Stray session count
- Per-city breakdown (auto-detected from coordinates)
- Accessed via bottom sheet from map

### 8.3 Settings
- Tracking on/off toggle
- Location permission status + upgrade prompt
- About / philosophy blurb
- Data export (future)

### 8.4 Onboarding (First Launch Only)
- Brief explanation of the concept (1-2 screens)
- Location permission request with clear explanation of why "Always" matters
- Drop into the map immediately — let the fog speak for itself

### Navigation Model
- Single map screen with bottom sheet access to stats and settings. The map should never leave the screen.

---

## 9. Success Metrics

For a personal/friends project, metrics are informal but still worth tracking:

### Does it work?
- Background tracking reliability (does the map fill in while phone is locked?)
- Battery impact (can you leave it running all day without noticing?)
- iCloud sync (does data appear on a second device?)

### Is it compelling?
- Do you open the app daily?
- Do you find yourself taking different routes because of it?
- When traveling, does it enhance the experience?
- After a month, does the map feel personally meaningful?

### North Star
- **Are you straying more?** If the app makes you explore more of your city than you would have otherwise, it's working.

---

## 10. Risks

| Risk | Severity | Mitigation |
|---|---|---|
| Users reject "Always" location permission | High | App works with "When In Use" (degraded). Clear onboarding explains value. Two-step permission flow (When In Use first, Always upgrade after first positive session). |
| Battery drain complaints | High | Aggressive `isStationary` filtering. Accuracy thresholds. No processing when phone is still. Monitor via Xcode energy diagnostics. |
| Cold start problem (empty map on day 1) | Medium | The fog itself is the hook — seeing your city entirely dark is the "whoa" moment. First walk reveals cells immediately. Consider photo backfill in v1.2 for retroactive reveals. |
| Diminishing returns as fog clears | Medium | **Solved by heat gradient.** The compass directs toward low-frequency areas, not just unvisited ones. The loop never decays. |
| MKTileOverlay rendering glitches | Medium | Fallback to solid fog tile on error. Tiles self-correct on pan/zoom. |
| SwiftData + CloudKit sync conflicts | Medium | Deduplication pass on launch. Merge strategy (keep earliest visit, sum counts). |
| Fog of World comparison | Low | Different product. Stray is a practice tool with a frequency-weighted compass, not a completionist game. Free vs $30. Anti-optimization philosophy vs completion percentage. |
