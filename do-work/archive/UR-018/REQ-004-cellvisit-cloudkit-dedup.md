---
id: REQ-004
title: CellVisit CloudKit Deduplication
status: completed
claimed_at: 2026-03-28T12:06:00Z
completed_at: 2026-03-28T12:08:00Z
route: A
created_at: 2026-03-28T12:00:00Z
user_request: UR-001
related: [REQ-001, REQ-002]
batch: daily-journey-replay
---

# CellVisit CloudKit Deduplication

## What
Add deduplication logic for CellVisit records to handle CloudKit multi-device sync conflicts, following the same pattern as RevealedCell dedup.

## Detailed Requirements
- Merge duplicates on `cellKey + dateString` composite key
- When duplicates found, keep the record with the earliest `visitedAt` (first touch wins)
- Delete the duplicate record after merging
- Run dedup on launch alongside existing RevealedCell and DailySummary dedup
- Follow the exact same dedup pattern already established in PersistenceService

## Constraints
- Must handle the case where two devices create a CellVisit for the same cell on the same day

## Dependencies
- Depends on: REQ-001 (CellVisit model must exist)

## Builder Guidance
- Certainty level: Firm — follows established pattern
- Look at existing `deduplicateRevealedCells()` and mirror the approach

## Full Context
See [user-requests/UR-001/input.md](./user-requests/UR-001/input.md) for complete verbatim input.

---
*Source: See UR-001/input.md for full verbatim input*

## Verification

**Source**: UR-001/input.md
**Pre-fix coverage**: 100% (3/3 items)

### Coverage Map

| # | Item | REQ Section | Status |
|---|------|-------------|--------|
| 1 | Merge on cellKey+dateString | Detailed Requirements | Full |
| 2 | Same pattern as RevealedCell dedup | Detailed Requirements | Full |
| 3 | Run on launch | Detailed Requirements | Full |

*Verified by verify-request action*
