---
id: UR-018
title: Fog rendering overhaul — atmospheric fog with soft edges
created_at: 2026-03-28T12:00:00Z
requests: [REQ-054, REQ-055, REQ-056]
word_count: 850
---

# Fog Rendering Overhaul

## Full Verbatim Input

Phase 1 — Offscreen fog rendering with vImage blur. Restructure FogOverlayRenderer.draw() into two-pass rendering:

PASS 1 (offscreen): Create offscreen CGContext matching tile dimensions. Fill with fog color (respecting zoom-based fogAlpha). Punch holes for revealed cells with .clear blend mode. Draw clearing animation residuals. Extract CGImage, apply vImage gaussian blur (3x box convolve via Accelerate framework), draw blurred result to map context.

PASS 2 (direct to map context): Draw cell tints (heat/photo/special/default), inspection highlights, and photo count numbers directly — these stay crisp.

Implementation details:
1. Add `import Accelerate` to FogOverlay.swift
2. Add `applyBlur(to:radius:)` helper method using vImageBoxConvolve_ARGB8888 x3 (three box convolves approximate gaussian)
3. Restructure draw() to create offscreen CGContext, render fog mask there, blur it, then composite to map
4. Offscreen context needs `translateBy(x: -drawRect.origin.x, y: -drawRect.origin.y)` so cellScreenRect coordinates map correctly
5. Extract helper methods: drawCellTints(cells:context:), drawInspectionHighlight(cells:context:), drawPhotoCounts(region:context:) from the current monolithic draw()
6. Add blur cache: store cachedFogImage/cachedGeneration/cachedMapRect properties, skip re-blur when renderGeneration and mapRect haven't changed and no clearing animation is running
7. Add fallback: if offscreen context creation fails, call renderFogDirect() which does current behavior without blur
8. Blur radius = ~35% of one cell's pixel width (computed from cellScreenRect of first visible cell)
9. Add Constants: fogBlurRadiusFraction = 0.35

Phase 2 — Noise texture generation and compositing. Generate a 256x256 tileable noise texture once (static let):
- Dark pixels (fog-colored RGB, varying alpha 0-12%) — NOT white pixels
- Value noise with 2-pass box blur smoothing for cloudy look
- Wrapping blur for seamless tiling
- Composite into offscreen context AFTER fog fill, BEFORE punching holes

Phase 3 — Smooth zoom fade + Improved clearing animation:
- Replace hard latitudeDelta > 1.0 cutoff with gradual fade (0.5 to 1.0 degrees)
- Thread cellOpacity through hole-punching and tint drawing
- Duration: 700ms (was 300ms), 14 frames at 50ms
- Ease-out cubic curve: 1 - (1-t)^3

Files to modify:
- Stray/Services/FogOverlay.swift (major restructure)
- Stray/Services/GridEngine.swift (animation timing)
- Stray/Utilities/Constants.swift (new constants)

Preserve ALL existing rendering modes and visual behavior.

[Context: User reported two issues — stuttering on zoom out and flat/lifeless fog appearance. After discussion, agreed on post-process blur for soft edges (handles all border topologies naturally), noise texture for atmosphere, smooth zoom transitions, and improved clearing animation. Plan approved at /Users/simonescheuer/.claude/plans/reflective-crafting-goblet.md]

---
*Captured: 2026-03-28T12:00:00Z*
