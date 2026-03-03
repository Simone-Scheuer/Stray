---
id: REQ-024
title: UX polish bundle — empty states, loading, app version
status: completed
claimed_at: 2026-03-02T00:00:00Z
completed_at: 2026-03-02T00:00:00Z
route: B
created_at: 2026-03-02T00:00:00Z
user_request: UR-005
related: [REQ-019, REQ-020, REQ-021, REQ-022, REQ-023, REQ-025]
batch: polish-sweep
---

# UX Polish Bundle

## What
Several small UX gaps that don't warrant individual REQs.

## Detailed Requirements

### Empty states in StatsView
- **No Stray sessions yet**: Show a gentle prompt — "Start a Stray session to see your exploration stats here"
- **No cities detected**: Show "Cities will appear as you explore" instead of blank space
- Keep the tone contemplative, not pushy

### Geocoding loading state
- When `CellInspectorView` shows a cell whose city hasn't been geocoded yet, show a subtle loading indicator or "Locating..." text instead of empty city field
- `PersistenceService.detectCity(for:at:)` runs async — the inspector should reflect this

### App version in Settings
- Display app version and build number at the bottom of `SettingsView`
- Use `Bundle.main.infoDictionary?["CFBundleShortVersionString"]` and `CFBundleVersion`
- Style: small, grey text at the bottom — "Stray v1.0 (42)"
- Useful for debugging when user reports issues

### Compass "all explored" message
- Current message: "You've explored everything nearby — venture further" (generic)
- Rotate through 3-4 poetic alternatives that fit the Situationist theme:
  - "The familiar stretches in every direction"
  - "No uncharted ground nearby — wander further"
  - "You know this place well — seek the unknown"
  - "Every path here is well-worn — find new ones"
- Pick randomly on each compass update cycle

## Context
- StatsView empty states: `Stray/Views/StatsView.swift` (lines ~97-128, cities section)
- Geocoding: `Stray/Services/PersistenceService.swift` (lines ~105-139)
- Cell inspector: `Stray/Views/CellInspectorView.swift`
- Settings: `Stray/Views/SettingsView.swift`
- Compass message: `Stray/ViewModels/StraySessionViewModel.swift` (line ~86)

---
*Source: App polish sweep — miscellaneous UX gaps*

---

## Triage

**Route: B** - Medium

**Reasoning:** Multiple small changes across 4 files. Clear outcomes but needed to see current view structures.

**Planning:** Not required

## Plan

**Planning not required** - Route B: Exploration-guided implementation

Rationale: Bundle of small, well-defined polish items. Just needed to see current code before adding.

*Skipped by work action*

## Implementation Summary

- `StatsView.swift`: Empty states for sessions ("Start a Stray session...") and cities ("Cities will appear as you explore")
- `CellInspectorView.swift`: "Locating..." in grey when city not yet geocoded
- `SettingsView.swift`: App version footer "Stray v1.0 (42)" from Bundle info
- `StraySessionViewModel.swift`: 4 poetic no-target messages, randomly selected

*Completed by work action (Route B)*

## Testing

**Tests run:** `xcodebuild build`
**Result:** BUILD SUCCEEDED

*Verified by work action*
