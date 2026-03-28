---
id: REQ-005
title: Calendar UI in Stats Sheet
status: completed
claimed_at: 2026-03-28T12:10:00Z
completed_at: 2026-03-28T12:20:00Z
route: B
created_at: 2026-03-28T12:00:00Z
user_request: UR-001
related: [REQ-006]
batch: daily-journey-replay
---

# Calendar UI in Stats Sheet

## What
Add a day-picker UI to the stats sheet that lets users select a day and see which cells they visited.

## Detailed Requirements
- Day picker in the stats sheet (calendar grid or horizontal date scroller — builder has latitude)
- Tap a day to select it; queries all CellVisit records for that dateString
- Passes the set of cell keys to the map for highlight rendering
- Shows a caption: "X cells visited, Y new" for the selected day
- "New" = cells where the CellVisit dateString matches RevealedCell.firstVisitedAt's date (first discovery)
- Tap again or dismiss to exit day-view mode

## Constraints
- Must not add a new screen — this lives within the existing Stats sheet
- Only shows days going forward from when the feature ships (no retroactive data)
- Days with no CellVisit records should appear inactive/dimmed in the picker

## Dependencies
- Depends on: REQ-001 (model), REQ-002 (data must be flowing)

## Builder Guidance
- Certainty level: Exploratory on UI specifics — user said "calendar or horizontal date scroller"
- Scope cue: keep it simple, don't over-build the calendar component
- The caption "X cells visited, Y new" was specified in the plan

## Full Context
See [user-requests/UR-001/input.md](./user-requests/UR-001/input.md) for complete verbatim input.

---
*Source: See UR-001/input.md for full verbatim input*

## Verification

**Source**: UR-001/input.md
**Pre-fix coverage**: 100% (5/5 items)

### Coverage Map

| # | Item | REQ Section | Status |
|---|------|-------------|--------|
| 1 | Day picker in stats sheet | Detailed Requirements | Full |
| 2 | Query CellVisit by dateString | Detailed Requirements | Full |
| 3 | Pass cells to map for highlighting | Detailed Requirements | Full |
| 4 | Day's cells bright, previous dimmed | Detailed Requirements (via REQ-006) | Full |
| 5 | Caption "X cells visited, Y new" | Detailed Requirements | Full |

*Verified by verify-request action*
