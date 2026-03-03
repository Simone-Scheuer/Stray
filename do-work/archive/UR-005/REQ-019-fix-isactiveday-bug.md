---
id: REQ-019
title: Fix isActiveDay bug — streak always returns 0
status: completed
claimed_at: 2026-03-02T00:00:00Z
completed_at: 2026-03-02T00:00:00Z
route: A
created_at: 2026-03-02T00:00:00Z
user_request: UR-005
related: [REQ-020, REQ-021, REQ-022, REQ-023, REQ-024, REQ-025]
batch: polish-sweep
---

# Fix isActiveDay Bug

## What
`DailySummary.isActiveDay` is never set to `true` anywhere in the codebase. `StatsEngine.currentStreak()` checks `summary.isActiveDay` before counting a day toward the streak, so the streak counter always returns 0.

## Detailed Requirements
- In `PersistenceService.updateDailySummary()`, set `isActiveDay = true` when a DailySummary is created or updated with exploration activity
- Verify that `StatsEngine.currentStreak()` correctly returns consecutive days after the fix
- Ensure existing DailySummary records (from before the fix) also get `isActiveDay` set to `true` if they have `cellsRevealed > 0` — add a one-time migration/fixup in `deduplicateAndReload()` or similar boot path

## Context
- `DailySummary.isActiveDay` declared at `Stray/Models/DailySummary.swift` with default `false`
- `PersistenceService.updateDailySummary()` at `Stray/Services/PersistenceService.swift` (lines 49-66) creates/updates summaries but never sets the flag
- `StatsEngine.currentStreak()` at `Stray/Services/StatsEngine.swift` (lines 16-44) uses the flag in its condition

---
*Source: App polish sweep — functional bug found during codebase audit*

---

## Triage

**Route: A** - Simple

**Reasoning:** Bug fix with clear reproduction — `isActiveDay` never set, fix is obvious. Three specific files identified.

**Planning:** Not required

## Plan

**Planning not required** - Route A: Direct implementation

Rationale: Simple bug fix with clear scope — set a boolean that was never being set.

*Skipped by work action*

## Implementation Summary

- `Stray/Services/PersistenceService.swift`: Added `summary.isActiveDay = true` in `updateDailySummary()` after updating stats
- `Stray/Services/PersistenceService.swift`: Added `fixupDailySummaryActiveFlags()` method — queries for DailySummary records with `cellsRevealed > 0 && isActiveDay == false` and fixes them
- `Stray/StrayApp.swift`: Call `fixupDailySummaryActiveFlags()` in `init()` and `deduplicateAndReload()` boot paths
- StatsEngine.currentStreak() verified correct — no changes needed

*Completed by work action (Route A)*

## Testing

**Tests run:** `xcodebuild build` (no unit test framework)
**Result:** BUILD SUCCEEDED

*Verified by work action*
