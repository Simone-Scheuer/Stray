# Stray — Release Status

**Last updated:** 2026-05-01

## Current state

| Field | Value |
|---|---|
| App Store version | 1.0.0 (live since April 2026) |
| In-flight version | 1.1.0 (build 18) |
| Stage | Pending TestFlight upload (build 17 superseded by Settings restructure + condensed-title fix) |
| Branch | `design-pass-toolbar` |
| Bundle ID | `com.simonescheuer.stray` |
| iOS minimum | 17.0 |

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
- Reserved for post-TestFlight regressions

### 1.2 (next minor)
- **Designer-sourced app icon** — currently 1.0 icon ships unchanged
- **Bundle Fraunces font** — replace `.serif` system fallback with brand face
- **Replace hardcoded versions in Info.plist** with `$(MARKETING_VERSION)` / `$(CURRENT_PROJECT_VERSION)` to avoid the rejection we hit during 1.1.0 upload
- **CellPhotosView style alignment** — gray captions → white opacity, blue link → amber
- **Splash screen wordmark** — currently default sans-serif, should be New York italic

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
| 1.1.0 | 18 | Pending | Design pass + battery work + foreground geocoding + 2026-05-01 polish (italic tightening, scroll-condensed titles, literary timeline dates, onboarding restyle, footer copy tightening, AI/cute copy strip, weekday dropped from timeline date, Settings restructure: location+photos merged into permissions, map footer dropped, footer hierarchy fixed, condensed-title default-value bug fixed) |

## Release notes drafting

`What to Test` (TestFlight):
> Visual overhaul: redesigned map header, stats, settings, timeline, and tile inspector. New blue→amber heat gradient. Battery optimization for background tracking. Test by walking around for ~30 min with the app open and confirm tile data is still there.

`What's New` (App Store) — draft for 1.1.0:
> A complete visual refresh. New typography across the app, redesigned stats and timeline pages with a literary feel, and a refined heat-map gradient. Quieter background tracking — Stray now batches data writes so it's even gentler on your battery while you wander.
