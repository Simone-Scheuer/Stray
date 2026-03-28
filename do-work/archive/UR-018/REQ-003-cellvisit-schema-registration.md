---
id: REQ-003
title: Register CellVisit in ModelContainer
status: completed
claimed_at: 2026-03-28T12:06:00Z
completed_at: 2026-03-28T12:08:00Z
route: A
created_at: 2026-03-28T12:00:00Z
user_request: UR-001
related: [REQ-001]
batch: daily-journey-replay
---

# Register CellVisit in ModelContainer

## What
Add `CellVisit` to the SwiftData model container schema so it is persisted and synced via CloudKit.

## Detailed Requirements
- Add CellVisit.self to the Schema array in the app's ModelContainer configuration
- Ensure it's included alongside existing models (RevealedCell, DailySummary, etc.)

## Dependencies
- Depends on: REQ-001 (CellVisit model must exist)

## Builder Guidance
- Certainty level: Firm — straightforward schema addition
- This is a one-line change in the model container setup

## Full Context
See [user-requests/UR-001/input.md](./user-requests/UR-001/input.md) for complete verbatim input.

---
*Source: See UR-001/input.md for full verbatim input*

## Verification

**Source**: UR-001/input.md
**Pre-fix coverage**: 100% (1/1 items)

### Coverage Map

| # | Item | REQ Section | Status |
|---|------|-------------|--------|
| 1 | Add CellVisit to ModelContainer schema | Detailed Requirements | Full |

*Verified by verify-request action*
