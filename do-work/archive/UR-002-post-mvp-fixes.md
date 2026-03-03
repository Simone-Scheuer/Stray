---
id: UR-002
title: "Post-MVP Fixes — Visit cooldown, gradient, UI cleanup"
created_at: 2026-03-02
status: completed
---

# UR-002: Post-MVP Fixes

## Source
User feedback after MVP build. Mix of UX fixes and visual polish.

## Requirements (FIX)

### REQ-007: Visit count cooldown
- Add a cooldown (default 30 minutes) before a cell's visit count increments again
- Compare current time to `RevealedCell.lastVisitedAt` — only increment if cooldown has elapsed
- Already skips stationary updates; this adds temporal deduplication on top
- Configurable via Constants (so it can be tuned later)
- Update `lastVisitedAt` only when the cooldown-gated increment actually fires

### REQ-008: Smoother heat gradient
- Current gradient has a confusing transparent gap (2–9 visits = invisible)
- Replace with a smoother ramp: cool blue (1) → lighter blue (2–4) → neutral/subtle (5–9) → warm amber (10–29) → bright glow (30+)
- Tier thresholds and colors tuned so the progression feels continuous
- Update `heatTierChanged()` in GridEngine to match new tier boundaries
- Update `heatColor(for:)` in FogOverlayRenderer to match

### REQ-009: Disable camera pitch (true flat mode)
- 3D elevation is already off (`.flat`), but camera pitch still allows perspective view
- Set `mapView.isPitchEnabled = false` in MapViewRepresentable
- One-liner fix

### REQ-010: Map labels off by default, toggleable in Settings
- Use `MKPointOfInterestFilter.excludingAll` on the map configuration by default
- Add a toggle in SettingsView: "Show map labels" (default off)
- Store preference via @AppStorage
- When toggled, update the map configuration's pointOfInterestFilter

### REQ-011: UI layout cleanup — compass, buttons, Apple logo
- **Compass overlap:** Ensure StrayCompassView doesn't overlap with top-right gear/stats buttons. Add proper spacing/safe area constraints.
- **Start Stray button:** Demote from prominent bottom-center capsule to a small corner button or integrate into a lightweight action menu alongside stats/settings. Map should feel primary, not the button.
- **Apple Maps logo:** Reposition via layoutMargins to be less intrusive (cannot remove — Apple requirement). Push it to a less prominent corner.

### REQ-012: Tap to inspect tiles
- Tap gesture on map to identify which GridCell was tapped
- Show a popover/sheet with cell stats: visit count, first visited date, last visited date, city
- Uses existing RevealedCell data (firstVisitedAt, lastVisitedAt already stored)
- Foundation for future "mark special tile" feature

## Dependency Order
- REQ-007 and REQ-008 are independent, can be parallelized
- REQ-009 is trivial, independent
- REQ-010 is independent
- REQ-011 is independent but should be designed holistically (all UI changes together)
- REQ-012 depends on nothing but benefits from REQ-011 (cleaner layout = better tap targets)
