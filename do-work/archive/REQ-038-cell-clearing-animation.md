---
id: REQ-038
title: Cell clearing animation
status: completed
created_at: 2026-03-06T13:00:00Z
claimed_at: 2026-03-06T14:00:00Z
route: A
completed_at: 2026-03-06T14:10:00Z
user_request: UR-013
related: [REQ-037]
batch: post-ideation
---

# Cell Clearing Animation

## What
When a new cell is revealed in real-time (walking, not boot/background reveal), briefly animate the fog clearing with a ~200ms fade-out instead of instant appearance.

---
*Source: User confirmed from ideation sweep.*

---

## Triage

**Route: A** - Simple

**Reasoning:** Clear scope, same files as REQ-037. Just adding animation timing to existing rendering.

**Planning:** Not required

## Plan

**Planning not required** - Route A: Direct implementation

*Skipped by work action*

## Implementation Summary

- **GridEngine.swift**: Added `recentlyRevealedCells: [GridCell: Date]` tracking. Only populated by single-cell `revealCell()`, NOT by `revealBlock()`. `scheduleClearingAnimation()` fires 6 render generation bumps at 50ms intervals (~20fps for 300ms). `pruneRecentlyRevealed()` cleans up expired entries.
- **FogOverlay.swift**: After drawing all cells and fog edge gradients, iterates `recentlyRevealedCells`. For cells younger than 300ms, draws a fog overlay with alpha proportional to remaining time (starts at full fog alpha, fades to 0).

*Completed by work action (Route A)*

## Testing

**Tests run:** xcodebuild build
**Result:** BUILD SUCCEEDED

*Verified by work action*
