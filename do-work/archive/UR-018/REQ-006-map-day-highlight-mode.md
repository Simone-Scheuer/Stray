---
id: REQ-006
title: Map Day Highlight Mode
status: completed
claimed_at: 2026-03-28T12:10:00Z
completed_at: 2026-03-28T12:20:00Z
route: B
created_at: 2026-03-28T12:00:00Z
user_request: UR-001
related: [REQ-005]
batch: daily-journey-replay
---

# Map Day Highlight Mode

## What
When a day is selected from the calendar UI, the map highlights that day's cells on top of existing exploration — previously revealed cells are slightly dimmed, and the selected day's cells get a bright highlight.

## Detailed Requirements
- FogTileOverlay renders previously revealed cells at reduced opacity when day mode is active
- That day's cells get a bright highlight tint (e.g. white-blue glow or accent color)
- The highlight is ON TOP of existing exploration — not isolated on darkness (user was explicit)
- Previously explored cells remain visible but slightly dimmed to provide context
- New cells discovered that day should be visually distinguishable from revisited cells if possible
- Small caption overlay on the map: "X cells visited · Y new" for the selected day

## Constraints
- Tile rendering must still happen on background queue (never main thread)
- Must integrate with existing FogTileOverlay without breaking normal rendering mode
- When day mode is deactivated, rendering returns to normal immediately

## Dependencies
- Depends on: REQ-005 (calendar UI provides the selected day and cell set)
- Depends on: REQ-001 (CellVisit data to know which cells belong to the day)

## Builder Guidance
- Certainty level: Mixed — the "highlighted on top" behavior is firm, specific visual treatment (glow, tint, outline) is exploratory
- User explicitly rejected "isolated on darkness" in favor of contextual overlay
- This is the most visually impactful piece — where the magic happens

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
| 1 | Previously revealed cells at reduced opacity | Detailed Requirements | Full |
| 2 | Day's cells get bright highlight | Detailed Requirements | Full |
| 3 | Highlighted ON TOP of existing exploration | Detailed Requirements | Full |
| 4 | Caption "X cells visited · Y new" | Detailed Requirements | Full |
| 5 | Return to normal when day mode deactivated | Constraints | Full |

*Verified by verify-request action*
