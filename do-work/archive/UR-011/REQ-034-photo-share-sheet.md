---
id: REQ-034
title: Add share sheet to fullscreen photo preview
status: completed
claimed_at: 2026-03-06T00:26:00Z
created_at: 2026-03-06T00:15:00Z
completed_at: 2026-03-06T00:30:00Z
route: A
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

---

## Triage

**Route: A** - Simple

**Reasoning:** Adding a single UI button + standard iOS share sheet to existing fullscreen cover.

**Planning:** Not required

## Plan

**Planning not required** - Route A: Direct implementation

Rationale: Simple UI addition — share button + UIActivityViewController wrapper.

*Skipped by work action*

## Implementation Summary

- Added share button (square.and.arrow.up.circle.fill) next to dismiss button in fullscreen cover
- Share button only visible when image is loaded (hidden during loading/error states)
- Created private `ShareSheet` UIViewControllerRepresentable wrapping UIActivityViewController
- Presented as .sheet over the fullscreen cover
- Added showShareSheet state, reset on dismiss

*Completed by work action (Route A)*

## Testing

**Tests run:** `xcodebuild build` (generic iOS)
**Result:** BUILD SUCCEEDED

No testing infrastructure — manual device testing required.

*Verified by work action*
