---
id: REQ-002
title: Persistence Hook for CellVisit Logging
status: completed
claimed_at: 2026-03-28T12:06:00Z
completed_at: 2026-03-28T12:08:00Z
route: A
created_at: 2026-03-28T12:00:00Z
user_request: UR-001
related: [REQ-001, REQ-003]
batch: daily-journey-replay
---

# Persistence Hook for CellVisit Logging

## What
Add a `logCellVisit(cellKey:date:)` method to `PersistenceService` and call it from the existing cell reveal/revisit flow in `StrayApp.swift`.

## Detailed Requirements
- New method in PersistenceService: `logCellVisit(cellKey: String, date: Date)`
- Check if a CellVisit already exists for this cellKey + today's dateString combo
- If none exists, create one with visitedAt = now
- If one already exists for today, skip (one row per cell per day)
- Hook into the existing orchestration in StrayApp.swift where `saveOrUpdateCell` is called
- Must be called for both new cells AND revisited cells (this is a visit log, not just discovery)

## Constraints
- Must not impact performance of the hot location-update path
- Use the same dateString format ("yyyy-MM-dd") as DailySummary

## Dependencies
- Depends on: REQ-001 (CellVisit model must exist)

## Builder Guidance
- Certainty level: Firm on the method signature and dedup logic
- Follow the existing PersistenceService patterns for fetch + conditional create

## Full Context
See [user-requests/UR-001/input.md](./user-requests/UR-001/input.md) for complete verbatim input.

---
*Source: See UR-001/input.md for full verbatim input*

## Verification

**Source**: UR-001/input.md
**Pre-fix coverage**: 100% (4/4 items)

### Coverage Map

| # | Item | REQ Section | Status |
|---|------|-------------|--------|
| 1 | logCellVisit method in PersistenceService | Detailed Requirements | Full |
| 2 | Check existing CellVisit for cellKey+dateString | Detailed Requirements | Full |
| 3 | Create if not exists, skip if exists | Detailed Requirements | Full |
| 4 | Call from StrayApp.swift reveal/revisit flow | Detailed Requirements | Full |

*Verified by verify-request action*
