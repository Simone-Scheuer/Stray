---
id: REQ-046
title: Fix cell inspector city/visits layout
status: completed
claimed_at: 2026-03-06T12:35:00Z
route: A
completed_at: 2026-03-06T12:36:00Z
created_at: 2026-03-06T12:00:00Z
user_request: UR-015
related: [REQ-047]
---

# Fix Cell Inspector City/Visits Layout

## What
City name and visit count are displayed on the same line in CellInspectorView, which feels awkward. Separate them onto their own lines for better readability.

## Context
The cell inspector is shown as a sheet when tapping a revealed cell on the map. The current layout crams city and visits together horizontally.

---
*Source: "city and visits are on the same line in the tile view which i think is a bit awkward"*

---

## Triage

**Route: A** - Simple

**Reasoning:** Visual layout tweak in a known file (CellInspectorView.swift). Clear scope.

**Planning:** Not required

## Plan

**Planning not required** - Route A: Direct implementation

Rationale: Simple layout change — move city and visits from HStack to separate rows.

*Skipped by work action*

## Implementation Summary

- Modified `Stray/Views/CellInspectorView.swift`: replaced `HStack` containing city and visits `LabeledContent` with separate vertical rows, each with its own accessibility label.

*Completed by work action (Route A)*

## Testing

**Tests run:** xcodebuild build
**Result:** BUILD SUCCEEDED

No testing infrastructure in this project (manual device testing per CLAUDE.md).

*Verified by work action*
