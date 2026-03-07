---
id: REQ-041
title: Cell notes
status: done
created_at: 2026-03-06T13:00:00Z
completed_at: 2026-03-06T15:00:00Z
user_request: UR-013
batch: post-ideation
---

# Cell Notes

## What
Allow users to add short text notes to cells via the cell inspector. Notes appear below photos in the inspector view.

## Implementation Summary
- **RevealedCell.swift**: Added `var notes: String = ""` property (lightweight migration, CloudKit-safe)
- **PersistenceService.swift**: Added `updateCellNotes(_:notes:)` method to persist note changes
- **CellInspectorView.swift**: Added `@State cellNotes` + `@FocusState isNotesFieldFocused`; multi-line TextField with "Add a note..." placeholder between visit details and mark controls; loads notes on appear, saves on focus loss and dismiss
- **ContentView.swift**: Changed `.presentationDetents([.medium, .large])` to `.presentationDetents([.medium])` — locks sheet to half-screen, content scrolls internally

---
*Source: User confirmed from ideation sweep.*
