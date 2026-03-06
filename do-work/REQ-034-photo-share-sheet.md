---
id: REQ-034
title: Add share sheet to fullscreen photo preview
status: pending
created_at: 2026-03-06T00:15:00Z
user_request: UR-011
related: [REQ-033]
---

# Add share sheet to fullscreen photo preview

## What
Add a share button to the fullscreen photo preview (the one that opens when you tap a photo in the cell inspector). Uses the standard iOS share sheet (UIActivityViewController) so users can AirDrop, message, save, etc.

## Context
- No public API to deep-link to a specific PHAsset in Photos.app
- Share sheet is the standard iOS pattern and covers the "access your photos" need
- Add a share icon (square.and.arrow.up) alongside the existing dismiss button in the fullscreen cover
- Philosophy: Stray is a spatial index into memories, not a photo viewer — share sheet lets users take action without building gallery infrastructure

---
*Source: "i want people to be able to access the photos they see on the tiles"*
