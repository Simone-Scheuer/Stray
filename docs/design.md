# Stray — Design Status

**Last updated:** 2026-05-01

## Brand axioms

Currently load-bearing decisions. Treat as defaults; override only with explicit reason.

- **Dark base.** The dark fog is the central metaphor — "unexplored" is encoded as visual darkness. Inverting this (light mode) breaks the metaphor. Declined for 1.1.0; revisit if 3+ users request it.
- **Italic for voice, roman for function.** Italic = wordmark, dates, big numerals, narrative prose. Roman = toggle labels, button text, captions, placeholder prompts. When everything is italic, italic stops meaning anything.
- **Heat gradient is blue → amber → gold, no greens.** Avoids the cyan/green/yellow band that HSB-interpolated blue-to-gold passes through. Verified colorblind-friendly across deuteranopia/protanopia.
- **5-tier heat detail is preserved.** User values gradient resolution; do not propose collapsing tiers under "visual identity" work.
- **The map is the interface.** UI is overlays, never destinations. Sheets sit over the map. The map never leaves the screen.
- **Top-right = "go elsewhere", bottom-right = "lens this view".** Two visual treatments encode the categorical split: chromeless glyphs at top (sheets, separate screens), in-circle toggles at bottom (overlay modes).

## Type system

| Use | Treatment |
|---|---|
| Wordmark `stray` | New York italic, ~24pt |
| City labels (`SAN FRANCISCO`) | New York regular, small caps, tracked 1.6 |
| Dates | New York italic, ordinal long-form (`Tuesday, the 28th of April`) |
| Big numerals (`644`, `307`) | New York italic, 36–44pt |
| Captions (`cells`, `walked`) | New York regular |
| Section headers (`TODAY`, `ALL TIME`) | New York regular, small caps, tracked 1.6 |
| Body / narrative | New York italic |
| Toggle labels, button text | New York regular |

Currently using SwiftUI's `.serif` design (resolves to New York). Fraunces is the designer's preferred face but isn't bundled — backlog item.

## Color palette

- Sheet background: `#0E0E0F` (`StrayPalette.sheetBackground`)
- Fog overlay: `UIColor(white: 0.06, alpha: 0.85)` (`Constants.fogColor`)
- Heat tier 1 (1 visit): RGB(82, 122, 199) cool blue
- Heat tier 2 (2): RGB(115, 140, 178) blue-grey
- Heat tier 3 (3–5): RGB(166, 140, 128) warm clay
- Heat tier 4 (6–20): RGB(217, 166, 89) amber
- Heat tier 5 (21+): RGB(235, 184, 71) gold
- Brand amber accent: RGB(217, 166, 89) — toggle tint, primary action buttons
- Brand violet accent: RGB(178, 140, 217) — photo mode active state
- Photo density gradient: violet → magenta → pink (purple family)

## Per-screen status

| Screen | Status | Notes |
|---|---|---|
| Map (ContentView) | Refactored 1.1.0 ✓ | Identity header, split toolbar, glow on active lens |
| Stats | Refactored 1.1.0 ✓ | Journal page — italic numerals, hairlines, no cards |
| Settings | Refactored 1.1.0 ✓ | Hand-rolled scroll sections, amber toggles, no NavigationStack |
| Cell Inspector | Refactored 1.1.0 ✓ | Literary summary sentence, journal-style notes field |
| Timeline overlay | Refactored 1.1.0 ✓ | Dark solid panel, italic-serif date, centered stats |
| CellPhotosView | Partial | Empty/permission states still iOS gray; "+N more" still system blue |
| Onboarding | Refactored 1.1.0 ✓ | Wordmark-led welcome, italic-serif headings, amber primary CTA, journal voice |
| Splash | Partial | Animated grid uses heat colors, but "Stray" wordmark uses default sans |
| StrayCompassView | Dead code | Leftover from removed Stray Mode; deletion eligible |

## Decisions log

- **2026-04-28** — Removed circle chrome from heat/photo lens icons in favor of chromeless glyphs. Reverted same day after Momo feedback that toggles need to read as buttons. Final: circles back, but darker (`black 0.55`) and tinted brand amber/violet instead of system orange/purple.
- **2026-04-28** — Timeline button moved from top-right (nav cluster) to bottom-right (lens cluster) per Momo feedback. Reframing: timeline is a *temporal lens*, same category as heat (frequency lens) and photo (density lens). Order in cluster left-to-right: timeline, photo, heat — heat closest to thumb as most-used.
- **2026-04-29** — Switched city geocoding from bucket-based (re-fire every 1km of movement) to foreground-only (re-fire on app open / phase becoming `.active`). Simpler model, fewer geocoder calls; mid-walk city updates lost but acceptable for a "glance daily" app.
- **2026-04-29** — Light mode declined. Dark base IS the brand metaphor; one user request didn't justify reauthoring the palette. Revisit threshold: 3+ user requests.
- **2026-04-30** — Italic discipline pass. Roman for functional labels, italic for voice. Refactored Settings, Cell Inspector, and stat captions.
- **2026-04-30** — Apple Maps legal label baseline lifted to `bottomInset = 45` so it Y-aligns with the lens button row. Animates to `220` when timeline opens to clear the panel.
- **2026-05-01** — Heat gradient verified colorblind-friendly via deuteranopia/protanopia simulation matrices. Tiers 2 and 3 are close in luminance (~6% delta) but blue→yellow direction preserves order across all common color vision types.
- **2026-05-01** — Italic discipline tightened. Page titles (`your map`, `settings`) → roman. Settings section footers → roman. About blurb → roman. Empty cities state → roman. Italic now lives only on: wordmark, identity-header date, big numerals, city names in lists, narrative prose (cell inspector summary, user notes), `replay your journey` CTA. Reasoning: when too much is italic, italic stops signaling voice — over-application reads as affect rather than register.
- **2026-05-01** — Scroll-condensed title pattern added to Stats and Settings. As user scrolls past the big page title, a small inline label fades in inside the top bar (where `done` lives). Threshold ≈ -88pt scroll offset. Implemented via `ScrollOffsetKey` PreferenceKey + GeometryReader (no NavigationStack to avoid iOS 26 chrome).
- **2026-05-01** — Timeline date format changed from `Mar 14, 2026` to literary long form `Saturday, the 14th of March, 2026` (matches identity-header date convention). Scrubber pill labels also use full month name (`March 14` instead of `Mar 14`). The `.lowercased()` modifier dropped — proper case for dates per home convention.
- **2026-05-01** — Settings section footers tightened to fit on one line (~50 chars max) and stripped of em-dashes. Reasoning: footer text wrapping to two lines hurt scannability; em-dashes felt over-precious for utility captions.
- **2026-05-01** — About blurb em-dash removed. Restructured from "the dérive — an unplanned journey..." to "inspired by the Situationist concept of the dérive. An unplanned journey..." Two-sentence form preserves the apposition without the dash.
- **2026-05-01** — Onboarding restyled (was scheduled for 1.2, pulled forward). Wordmark-led welcome page (`stray` italic 64pt + `LIFE CARTOGRAPHY` tracked subhead). Roman serif body copy. Italic for the literary subtitles. Primary CTAs use amber-filled rounded buttons with serif label. Skip link is italic serif at low opacity.
- **2026-05-01** — Copy pass to remove AI/cute language. Cuts: vibes-adjectives ("quiet atlas" → "atlas"), anthropomorphism ("your map is already coming alive" → just the count), Instagram verbs ("capture moments" → "take photos"), aphorism mantras ("no goals. no streaks. just you and the map." → "No goals. No streaks. No leaderboards." — concrete, scannable), purple prose ("the pull of the terrain and the encounters you find there" → cut), and performative first-person subtitles ("show me where I've walked" → "Where you walk"). Updated Info.plist privacy strings (camera/location/motion/photos), Settings about blurb, onboarding bodies, scan summaries, error toasts, and confirmation dialogs. Cell Inspector literary summary em-dash → comma.
- **2026-05-01** — Timeline date dropped weekday: `Wednesday, the 18th of March, 2026` → `the 18th of March, 2026`. Was wrapping to two lines on long-weekday days (Wednesday, Thursday, Saturday). Shorter version comfortably fits at 20pt one line; bumped font back from 17 → 20pt now that wrap risk is gone.
- **2026-05-01** — Settings restructured. Merged `location` and `photos` into a single `permissions` section (rows now read `location`/`photos` instead of `permission`). Dropped the `map` section footer (it described only the `muted style` toggle, misleading the other three). Footer copy globally shrunk 12pt → 10pt and dimmed to 0.35 opacity; section headers bumped 0.5 → 0.65 opacity. Reasoning: as a user, the original layout had ~equal-weight footer text under each section header, flattening the hierarchy. Section order now: tracking → permissions → map → about.
- **2026-05-01** — `ScrollOffsetKey.defaultValue` flipped 0 → 9999. Old default kept the condensed title visible at top-of-page until the GeometryReader emitted a real measurement, producing a brief flash (or stuck-on state) on Stats and Settings. Default 9999 ensures `headerMaxY < 44` is false until the real value arrives.

## Open design questions

- Designer-sourced app icon for 1.2 (current is the original 1.0 icon)
- Onboarding restyle for 1.2
- Should `replay your journey` CTA go roman like other buttons, or keep italic as poetic CTA? (Currently italic.)
- City rows in Stats — italic both sides, or roman count? (Currently italic both — "reads as one phrase.")
