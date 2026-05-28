# Stray — Release Status

**Last updated:** 2026-05-10

## Current state

| Field | Value |
|---|---|
| App Store version | 1.1.0 (live) |
| In-flight version | 1.2.0 (build 27) |
| Stage | TestFlight prep — LOD restructure + timeline back/forward buttons (tap or hold) + scrubber smoothness optimization (defer engine work to drag-end) |
| Branch | `1.2-lod` |
| Bundle ID | `com.simonescheuer.stray` |
| iOS minimum | 17.0 |

## Next steps

### 1.2.0 build 26 — full LOD restructure on TestFlight
- Heat LOD bug fix (carried over from build 25)
- LOD tower restructured: dropped `block`, added `street` (800m), pushed thresholds way out
- Experimental "show all detail" toggle in Settings (bypasses LOD entirely, opt-in)
- Verify on device: base 50m cells should now persist through "whole-city" zoom; the cliff between aggregation tiers should feel smoother; toggle should switch on/off without restart

### Earlier
- 1.2.0 build 25: first TestFlight build of 1.2 train (heat LOD bug fix only)
- 1.1.0 approved 2026-05-05; live on App Store

### 1.2 lead item: LOD smoothing + experimental "show all detail" toggle

**Observation:** at moderate zoom-out the fine spider-web of personal trails is still visible to the eye, but the LOD aggregator switches to chunky fill-ins too early. The real culprit is structural — the `block`→`district` jump is 16x linear / 256x area, while every other tier transition is 4x. That single cliff is what makes the transition feel ugly regardless of where the threshold sits.

**Three-part plan:**

**(1) Add an intermediate LOD tier between `block` and `district`.**
Insert `street` = 16 (800m cells) into [`GridEngine.LODLevel`](../Stray/Services/GridEngine.swift). Tower becomes 4x-spaced end to end:
```
base 50m → block 200m → street 800m → district 3.2km → city 12.8km → metro ~51km → region ~205km
              4x            4x             4x              4x             4x            4x
```
Threshold-only nudges don't fix the cliff — they just move where it is. The new tier is what kills it.

**(2) Push thresholds outward — significantly — so base persists through "whole-map at city level."**
First-tester observation: car-trip trails are visible to the eye well past current cutoffs but the LOD aggregator kicks in too early; the cute thin trails get aggregated away. Goal is that a comfortable "looking at all my walks across the metro" view still renders base 50m cells. Approximate revised targets — base goes much further than the conservative 0.20° I first proposed:
```
..<0.40  → .base     (was ..<0.06; original revised plan was ..<0.20)
..<1.0   → .block    (was ..<0.20)
..<3.0   → .street   (NEW)
..<8.0   → .district (was ..<0.60)
..<16.0  → .city
..<32.0  → .metro
default  → .region
```
Exact values need on-device tuning. The intent is: keep base alive through what feels like "looking at the whole city/metro on screen at once." Performance sanity-check during tuning — if rendering 50k+ base cells in viewport gets sluggish, dial back. The opt-in toggle (item 3) is the escape hatch for users who want even further.

**(3) Experimental "Show all detail" toggle in Settings.**
Place under a new `Settings → Experimental` (or `Labs`) section with a clear performance warning. When ON, skip LOD aggregation entirely and render base 50m everywhere. Default OFF. Wired via `@AppStorage("experimentalDisableLOD")`. Affects only [`FogOverlay.swift`](../Stray/Services/FogOverlay.swift) — when flag is true, force `level = .base`.

**Optional safety floor:** even with the toggle ON, cap visible cell count at ~100k per render. Prevents pathological "user with 500k cells zooms to continental view" hangs. Skip if heavy-user data scale isn't realistic.

**Order of operations:** (1) and (2) are the actual feel fix and ship together. (3) is opt-in for power users who want even more.

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
| 1.1.0 | 24 | Live | Design pass + battery work + foreground geocoding + 2026-05-01 polish (italic tightening, scroll-condensed titles, literary timeline dates, onboarding restyle, footer copy tightening, AI/cute copy strip, weekday dropped from timeline date, Settings restructure, condensed-title default-value bug fixed) + 2026-05-04 polish (location upgrade banner for `.authorizedWhenInUse`/`.denied`, splash wordmark switched to brand serif italic, cell inspector reverted from literary line to plain "X visits" + "last visited Y", timeline panel always reserves photo-strip height + legal label inset bumped to 305). Submitted 2026-05-02, approved 2026-05-05 — clean run, no rejection round. |
| 1.2.0 | 25 | TestFlight (superseded by 26) | First 1.2 build — heat LOD bug fix only. |
| 1.2.0 | 26 | TestFlight (superseded by 27) | Heat LOD bug fix + LOD restructure (dropped block, added street, pushed thresholds) + experimental toggle. |
| 1.2.0 | 27 | TestFlight prep | Timeline ergonomics: back/forward chevron buttons flanking the date in the header (tap = step one day, hold = auto-advance after 350ms with 220ms repeat). Scrubber stutter fix — `onSelect` now fires only on drag-end, not during. Date label still updates live via local `dragIndex`; heavy day-apply / photo-load / pedometer work runs once on commit. |

## Release notes drafting

`What to Test` (TestFlight):
> Visual overhaul: redesigned map header, stats, settings, timeline, and tile inspector. New blue→amber heat gradient. Battery optimization for background tracking. Test by walking around for ~30 min with the app open and confirm tile data is still there.

`What's New` (App Store) — draft for 1.1.0:
> A complete visual refresh. New typography across the app, redesigned stats and timeline pages with a literary feel, and a refined heat-map gradient. Quieter background tracking — Stray now batches data writes so it's even gentler on your battery while you wander.
