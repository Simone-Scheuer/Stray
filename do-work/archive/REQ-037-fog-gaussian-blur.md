---
id: REQ-037
title: Fog edge Gaussian blur
status: completed
created_at: 2026-03-06T13:00:00Z
claimed_at: 2026-03-06T13:45:00Z
route: B
completed_at: 2026-03-06T14:00:00Z
user_request: UR-013
related: [REQ-038]
batch: post-ideation
---

# Fog Edge Gaussian Blur

## What
Soften the boundary between revealed cells and fog with a Gaussian blur or alpha gradient, making the fog edge feel more organic and less grid-like.

## Context
Current fog has hard pixel edges at cell boundaries. Previous attempt with rounded rects caused gaps between adjacent cells — this is a different approach: softening the outer boundary of the revealed region, not individual cells.

---
*Source: User confirmed from ideation sweep. "I would love a Gaussian blur for the fog. I'd love to get more fog-like."*

---

## Triage

**Route: B** - Medium

**Reasoning:** Clear visual change, needed to explore FogOverlayRenderer draw cycle to find the right approach.

**Planning:** Not required

## Plan

**Planning not required** - Route B: Exploration-guided implementation

*Skipped by work action*

## Implementation Summary

- **GridCell.swift**: Added `Neighbors` struct and `neighbors` computed property for N/S/E/W adjacency
- **FogOverlay.swift**: Refactored cell rect calculation into `cellScreenRect(for:)` helper. Added `drawFogEdgeGradients()` — for each revealed cell, checks all 4 edges; if the neighbor is NOT revealed (faces fog), draws a linear gradient strip from clear→fog color along that edge. Gradient width is 20% of cell size, scaling with zoom. Uses `CGGradient` with clipping per edge to avoid overdraw. Built `revealedSet` for O(1) adjacency lookups.
- No gaps between adjacent cells: gradients only appear on fog-facing edges

*Completed by work action (Route B)*

## Testing

**Tests run:** xcodebuild build
**Result:** BUILD SUCCEEDED

*Verified by work action*
