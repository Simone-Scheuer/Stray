---
id: UR-001
title: Daily Journey Replay Feature (CellVisit Journal)
created_at: 2026-03-28T12:00:00Z
requests: [REQ-001, REQ-002, REQ-003, REQ-004, REQ-005, REQ-006]
word_count: 312
---

# Daily Journey Replay Feature (CellVisit Journal)

## Summary

User wants a daily journey replay feature that answers "what did I do on Tuesday?" by showing all cells traversed on a specific day. Cells visited that day are highlighted on top of existing exploration (not isolated on darkness). This emerged from a conversation about the app's exploration philosophy — it's a memory feature, not a stats feature.

## Extracted Requests

| ID | Title | Summary |
|----|-------|---------|
| REQ-001 | CellVisit SwiftData model | New @Model to log one row per cell per day |
| REQ-002 | Persistence hook for CellVisit | Log visits in the existing reveal/revisit flow |
| REQ-003 | Register CellVisit in ModelContainer | Add to schema for SwiftData + CloudKit |
| REQ-004 | CellVisit CloudKit deduplication | Merge duplicates on cellKey+dateString |
| REQ-005 | Calendar UI in Stats Sheet | Day picker to select and query a day's cells |
| REQ-006 | Map day highlight mode | Highlight selected day's cells on top of existing exploration |

## Batch Constraints

- Must follow all SwiftData + CloudKit constraints (no @Attribute(.unique), all defaults, optional relationships)
- Day view shows today's cells highlighted ON TOP of previous cells (not isolated on darkness) — user was explicit about this
- Previously revealed cells should be slightly dimmed when day mode is active; that day's cells get bright highlight
- Builder has latitude on specific UI implementation (calendar vs horizontal scroller) — user is exploratory here
- This is a forward-looking feature — no need to reconstruct past days from existing data

## Full Verbatim Input

Build the Daily Journey Replay feature (CellVisit journal):

1. **New Model: CellVisit** — Create `Stray/Models/CellVisit.swift` with `@Model` class:
   - `cellKey: String = ""` (matches RevealedCell's cellKey)
   - `dateString: String = ""` (e.g. "2026-03-28" for fast day queries)
   - `visitedAt: Date = Date()` (first touch that day)
   - Follow all SwiftData+CloudKit constraints: no @Attribute(.unique), all defaults, lightweight migration safe

2. **Persistence Hook** — In `PersistenceService.swift`, add a method `logCellVisit(cellKey:date:)` that:
   - Checks if a CellVisit already exists for this cellKey+dateString combo
   - If not, creates one
   - Call this from the existing cell reveal/revisit flow (in StrayApp.swift orchestration)

3. **Register CellVisit in ModelContainer** — Add CellVisit to the schema in the app's model container setup

4. **CloudKit Dedup** — Add deduplication logic for CellVisit (merge on cellKey+dateString, same pattern as RevealedCell dedup)

5. **Calendar UI in Stats Sheet** — Add a day-picker (calendar or horizontal date scroller) to the stats view that:
   - Lets user tap a day
   - Queries all CellVisit records for that dateString
   - Passes those cells to the map to highlight on top of existing exploration
   - Day's cells get a bright highlight tint, previous cells slightly dimmed

6. **Map Day Highlight Mode** — When a day is selected:
   - FogTileOverlay renders previously revealed cells at reduced opacity
   - That day's cells get a bright highlight (e.g. white-blue glow or accent color outline)
   - Small caption overlay: "X cells visited · Y new" for the selected day

Additional context from conversation: User confirmed day view should show today's cells slightly highlighted on top of previous cells, not isolated. The feature is a "memory" feature — "what did I do on Tuesday" — showing everywhere you went whether routine or brand new.

---
*Captured: 2026-03-28T12:00:00Z*
