# Stray — Release Status

**Last updated:** 2026-05-04

## Current state

| Field | Value |
|---|---|
| App Store version | 1.0.0 (live since April 2026) |
| In-flight version | 1.1.0 (build 24) |
| Stage | Submitted to App Review 2026-05-04 — awaiting approval |
| Branch | `design-pass-toolbar` |
| Bundle ID | `com.simonescheuer.stray` |
| iOS minimum | 17.0 |

## Next steps

### Once 1.1 is approved
- Watch for review feedback in the contact email; respond promptly
- Decide release: auto-release after May 3 is currently scheduled, manual override possible if anything unexpected lands
- After live: monitor crash reports + early reviews for ~48h before opening 1.2 work

### 1.2 lead item: LOD threshold nudge
First-person observation: at moderate zoom-out the fine "spider-web" of personal trails is still visible to the eye, but the LOD aggregator immediately switches to chunky fill-ins. Want trails to persist longer.

**Decision:** nudge thresholds up one notch (more detail at zoom-out) rather than expose a user toggle. Toggle was considered but rejected — full-detail rendering at state-level zoom on heavy data sets (200k+ cells) risks stutter/freeze, and the LOD exists precisely for that case. Tuning the default is lower-risk and zero-maintenance.

**Where:** [`GridEngine.LODLevel.level(for:)`](../Stray/Services/GridEngine.swift) — shift each `latitudeDelta` boundary up one tier so `base` (50m) persists to ~0.20°, `block` to ~0.60°, etc. Approximately:
```
..<0.20  → .base    (was ..<0.06)
..<0.60  → .block   (was ..<0.20)
..<3.0   → .district
..<6.0   → .city
..<???   → .metro
default  → .region
```
Self-test on own data first; if performance feels right, ship. If a heavy-data user later complains, fall back to the toggle as escape hatch.

## 1.1.0 — design pass + battery optimization

### Visual / UX (this session)

- Identity header (italic wordmark + small-caps city + ordinal-form date)
- Toolbar split (chromeless top-right nav, in-circle bottom-right lenses)
- Heat palette swap (5 hand-picked RGB stops, no greens, colorblind-friendly)
- Stats / Settings / Cell Inspector / Timeline rewritten in journal style
- Italic-for-voice / roman-for-function discipline applied (tightened 2026-05-01 — page titles, footers, About blurb now roman; italic reserved for voice + signature)
- Apple Maps legal label Y-aligned with bottom buttons; lifts above timeline panel
- Custom `done` overlay in Stats / Settings (bypasses iOS 26 glass capsule chrome)
- Scroll-condensed title pattern: small `your map` / `settings` fades in top bar after big title scrolls past
- Timeline slides up with spring animation; identity header stays anchored
- Timeline date in literary long form (`Saturday, the 14th of March, 2026`) with full month names
- Onboarding restyled to match journal voice (pulled forward from 1.2 backlog)
- Settings section footers tightened to one line, em-dashes removed
- About blurb restructured, em-dash removed

### Behind the scenes (pre-session, also shipping)

- Throttled saves: `PersistenceService.scheduleSave()` coalesces disk + CloudKit flushes to ≤1 per 5s on the location hot-path. New cells still save immediately. `flushPendingSave()` runs on `resignActive`.
- Background session reuse: `CLBackgroundActivitySession` no longer invalidated/recreated on every `startTracking()` call.
- City geocoding: foreground-only (cold launch + `scenePhase == .active`), down from bucket-based (every 1km of movement).

### Test plan (TestFlight)

- [ ] TestFlight build installed on real iPhone
- [ ] 30-min walk with app foregrounded — battery feel comparable to 1.0
- [ ] Lock phone, walk 10 min, reopen — new cells revealed (background tracking works)
- [ ] Existing tile data intact post-update
- [ ] Heat toggle on/off — no greens visible in palette
- [ ] Tap a tile — literary summary shows correct visit count + relative time
- [ ] Stats / Settings sheets — done button sticks, no glass capsule, masks scrolling content
- [ ] Timeline slides up, header stays anchored, legal label lifts above panel
- [ ] Active lens icons (heat/photo) glow with brand tint when on

## Backlog

### 1.1.x bugfixes (if needed post-ship)
- **Cell Inspector density** — sparse tiles (1 visit, no photos, no notes) feel tall and blank per first-tester feedback. Consider adding coordinates / cell key / neighborhood line below "last visited" to give the page more substance on virgin tiles.
- **Bottom-row button gap** — possible perceived gap between Apple Maps legal label and the lens button row on certain devices. Confirm with second tester before adjusting.

### 1.2 (next minor)
- **LOD threshold nudge** *(lead item — see Next steps above)*
- **Designer-sourced app icon** — currently 1.0 icon ships unchanged
- **Bundle Fraunces font** — replace `.serif` system fallback with brand face
- **Replace hardcoded versions in Info.plist** with `$(MARKETING_VERSION)` / `$(CURRENT_PROJECT_VERSION)` to avoid the rejection we hit during 1.1.0 upload
- **CellPhotosView style alignment** — gray captions → white opacity, blue link → amber

### 1.x (deferred)
- **`remote-notification` background mode** — Info.plist gap. CloudKit currently polls instead of pushes. Lower priority.
- **`aps-environment` flip** — currently `development` in shipped builds. Flip to `production` if/when notification features added.
- **Light mode** — declined for 1.1.0. Revisit if 3+ users request.
- **Delete `StrayCompassView.swift`** — dead code from removed Stray Mode

### Permanently declined
- **Stray Mode (compass feature)** — removed permanently. The dark fog already shows users where they haven't been; a guided compass is redundant and arguably contradicts the anti-optimization thesis.

## Version history

| Version | Build | Status | Notes |
|---|---|---|---|
| 1.0.0 | 12 | Live | Initial App Store ship, April 2026 |
| 1.1.0 | 24 | Submitted, in review | Design pass + battery work + foreground geocoding + 2026-05-01 polish (italic tightening, scroll-condensed titles, literary timeline dates, onboarding restyle, footer copy tightening, AI/cute copy strip, weekday dropped from timeline date, Settings restructure, condensed-title default-value bug fixed) + 2026-05-04 polish (location upgrade banner for `.authorizedWhenInUse`/`.denied`, splash wordmark switched to brand serif italic, cell inspector reverted from literary line to plain "X visits" + "last visited Y", timeline panel always reserves photo-strip height + legal label inset bumped to 305) |

## Release notes drafting

`What to Test` (TestFlight):
> Visual overhaul: redesigned map header, stats, settings, timeline, and tile inspector. New blue→amber heat gradient. Battery optimization for background tracking. Test by walking around for ~30 min with the app open and confirm tile data is still there.

`What's New` (App Store) — draft for 1.1.0:
> A complete visual refresh. New typography across the app, redesigned stats and timeline pages with a literary feel, and a refined heat-map gradient. Quieter background tracking — Stray now batches data writes so it's even gentler on your battery while you wander.
