---
id: REQ-021
title: Standardize distance units across app
status: completed
claimed_at: 2026-03-02T00:00:00Z
completed_at: 2026-03-02T00:00:00Z
route: A
created_at: 2026-03-02T00:00:00Z
user_request: UR-005
related: [REQ-019, REQ-020, REQ-022, REQ-023, REQ-024, REQ-025]
batch: polish-sweep
---

# Standardize Distance Units

## What
Session HUD (ContentView) displays distance in **kilometers**, while Stats sheet (StatsViewModel) displays distance in **miles**. Same data, different units — confusing.

## Detailed Requirements
- Use `Locale.current.measurementSystem` to detect user's preferred system
- If `.metric`: show km everywhere
- If `.us` or `.uk`: show mi everywhere
- Apply consistently to:
  - Session HUD distance (ContentView, line ~140)
  - Stats sheet lifetime/session distance (StatsViewModel, lines ~45-51)
  - Any future distance displays
- Consider extracting a shared `formatDistance(_ meters: Double) -> String` utility in Extensions.swift

## Context
- ContentView session HUD: `String(format: "%.1f km", meters / 1000.0)` at line ~140
- StatsViewModel: `let miles = meters / 1609.34` at lines ~46-50
- User is Portland-based (US) but travels internationally — locale-aware is the right call

---
*Source: App polish sweep — unit inconsistency found during audit*

---

## Triage

**Route: A** - Simple

**Reasoning:** Two specific formatting call sites, clear fix — extract shared function and replace both.

**Planning:** Not required

## Plan

**Planning not required** - Route A: Direct implementation

Rationale: Simple value/formatting change with explicit files identified.

*Skipped by work action*

## Implementation Summary

- `Stray/Utilities/Extensions.swift`: Added `formatDistance(_ meters: Double) -> String` — locale-aware (metric → km, imperial → mi)
- `Stray/Views/ContentView.swift`: Replaced hardcoded km formatting with shared `formatDistance()`
- `Stray/ViewModels/StatsViewModel.swift`: Removed private hardcoded miles formatter, uses shared `formatDistance()`; default values also locale-aware

*Completed by work action (Route A)*

## Testing

**Tests run:** `xcodebuild build`
**Result:** BUILD SUCCEEDED

*Verified by work action*
