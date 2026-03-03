---
id: REQ-025
title: Fix silent error swallowing in PersistenceService
status: completed
claimed_at: 2026-03-02T00:00:00Z
completed_at: 2026-03-02T00:00:00Z
route: B
created_at: 2026-03-02T00:00:00Z
user_request: UR-005
related: [REQ-019, REQ-020, REQ-021, REQ-022, REQ-023, REQ-024]
batch: polish-sweep
---

# Fix Silent Error Swallowing in PersistenceService

## What
`PersistenceService.save()` silently catches and discards all SwiftData errors. If storage is full or the database is corrupted, the user has no indication their data isn't persisting. Walking around "revealing" cells that never save is the worst user experience.

## Detailed Requirements
- In `PersistenceService.save()`: log the error with `os.Logger` (not just print) so it appears in Console.app and device logs
- Add a `@Published` or `@Observable` error state that views can observe: `var lastPersistenceError: Error?`
- In `ContentView`, show a subtle non-blocking banner/toast if `lastPersistenceError` is non-nil — something like "Unable to save exploration data" with a small icon
- Clear the error after display (auto-dismiss after 5 seconds or on next successful save)
- Apply the same pattern to the `try?` fetch calls — at minimum log failures:
  - `fetchCell(key:)` (line ~33)
  - `deduplicateCells()` (line ~71)
  - `fetchAllCells()` (implicit in various places)
- Do NOT add error handling that blocks the user or stops location tracking — just inform
- Consider: if saves fail 3+ times consecutively, should we pause location processing to save battery? (Optional — note as a follow-up if too complex)

## Context
- `PersistenceService.save()` at `Stray/Services/PersistenceService.swift` (lines ~160-166)
- Multiple `try?` calls throughout PersistenceService that silently discard errors
- Battery concern: if saves fail, continued location tracking wastes battery for nothing

---
*Source: App polish sweep — data integrity and error visibility*

---

## Triage

**Route: B** - Medium

**Reasoning:** Clear fix but needed to see all `try?` sites in PersistenceService to convert them.

**Planning:** Not required

## Plan

**Planning not required** - Route B: Exploration-guided implementation

Rationale: Clear outcome, just needed to find all silent error sites.

*Skipped by work action*

## Implementation Summary

- `PersistenceService.swift`: Added `os.Logger`, `lastPersistenceError` observable property. `save()` now logs and sets error on failure, clears on success. Converted all 6 `try?` calls to `do/catch` with logging (same fallback behavior preserved).
- `ContentView.swift`: Red capsule banner at bottom ("Unable to save exploration data"), auto-dismisses after 5 seconds or on next successful save. Non-blocking.

*Completed by work action (Route B)*

## Testing

**Tests run:** `xcodebuild build`
**Result:** BUILD SUCCEEDED

*Verified by work action*
