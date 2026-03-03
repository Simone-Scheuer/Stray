---
id: REQ-022
title: Add haptic feedback to key interactions
status: completed
claimed_at: 2026-03-02T00:00:00Z
completed_at: 2026-03-02T00:00:00Z
route: A
created_at: 2026-03-02T00:00:00Z
user_request: UR-005
related: [REQ-019, REQ-020, REQ-021, REQ-023, REQ-024, REQ-025]
batch: polish-sweep
---

# Add Haptic Feedback

## What
No haptic feedback anywhere in the app. Modern iOS apps use subtle haptics to confirm interactions.

## Detailed Requirements
- **Session start** (tap "Start Stray"): `UIImpactFeedbackGenerator(style: .heavy).impactOccurred()`
- **Session end** (tap "End Stray"): `UIImpactFeedbackGenerator(style: .medium).impactOccurred()`
- **Action buttons** (stats, settings, gear): `UIImpactFeedbackGenerator(style: .light).impactOccurred()`
- **Cell reveal** (new cell bloomed — `.newCell` result): `UIImpactFeedbackGenerator(style: .soft).impactOccurred()` — only on new cells, not revisits or cooldown
- **Compass bearing update** (when StrayEngine finds a new target): `UISelectionFeedbackGenerator().selectionChanged()`
- Do NOT add haptics to: map panning, zoom, every location update, anything that fires continuously
- Respect system haptic settings (UIFeedbackGenerator handles this automatically)
- Keep it subtle — this is a contemplative app, not a game

## Context
- Session start/end in `Stray/Views/ContentView.swift` (action bar buttons)
- Cell reveal in `Stray/StrayApp.swift` (location pipeline, checks `RevealResult`)
- Compass update in `Stray/ViewModels/StraySessionViewModel.swift`

---
*Source: App polish sweep — missing haptic feedback*

---

## Triage

**Route: A** - Simple

**Reasoning:** Adding haptic calls at specific, named call sites. No architectural decisions.

**Planning:** Not required

## Plan

**Planning not required** - Route A: Direct implementation

Rationale: Simple additions at known call sites with specified haptic styles.

*Skipped by work action*

## Implementation Summary

- `Stray/Views/ContentView.swift`: Added `.heavy` on session start, `.medium` on session end confirm, `.light` on stats/settings buttons
- `Stray/StrayApp.swift`: Added `.soft` on `.newCell` reveal only (not revisits or cooldown)
- `Stray/ViewModels/StraySessionViewModel.swift`: Added `selectionChanged()` when compass acquires a new target (not on every update)

*Completed by work action (Route A)*

## Testing

**Tests run:** `xcodebuild build`
**Result:** BUILD SUCCEEDED

*Verified by work action*
