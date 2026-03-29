---
id: REQ-056
title: Smooth zoom fade + improved clearing animation
route: B
status: pending
priority: medium
user_request: UR-018
related: [REQ-054, REQ-055]
batch: fog-overhaul
---

# Smooth Zoom Fade + Improved Clearing Animation

## Goal
Eliminate the visual pop when zooming out (hard cutoff at latitudeDelta > 1.0) and make cell reveal animation more satisfying with longer duration and ease-out curve.

## Requirements

### Smooth zoom-out transition
- Replace hard `latitudeDelta > 1.0` return with gradual fade zone
- `cellOpacity = 1.0` when delta < 0.5 (fully visible)
- Linear fade from 1.0 to 0.0 between 0.5 and 1.0 delta
- `cellOpacity = 0.0` when delta > 1.0 (early return, fog only — same as current)
- Thread cellOpacity through:
  - Hole-punching: partial clear + fog refill at `(1 - cellOpacity) * fogAlpha`
  - Tint drawing: scale tint alpha by cellOpacity
  - Photo count numbers: skip when cellOpacity < 0.3

### Improved clearing animation
- Duration: 700ms (was 300ms)
- Frame count: 14 frames at 50ms intervals (was 6 frames)
- Ease-out cubic curve: `1 - (1-t)^3` — fast start, slow settle
- Update `pruneRecentlyRevealed()` cutoff to 0.8s (was 0.4s)

### Constants
- Add `cellFadeStartDelta: Double = 0.5` to Constants
- Add `cellFadeEndDelta: Double = 1.0` to Constants
- Add `clearingAnimationDuration: TimeInterval = 0.7` to Constants
- Add `clearingAnimationFrameCount: Int = 14` to Constants

## Files to Modify
- `Stray/Services/FogOverlay.swift` — zoom fade logic + ease-out curve in clearing animation
- `Stray/Services/GridEngine.swift` — update scheduleClearingAnimation() frame count, pruneRecentlyRevealed() cutoff
- `Stray/Utilities/Constants.swift` — add zoom fade and animation constants

## Dependencies
- Depends on REQ-054 (offscreen fog context — cellOpacity integrates into the offscreen pass)

## Constraints
- cellOpacity must affect both the offscreen fog pass and the direct tint pass
- Photo count text should disappear before cells reach full transparency (unreadable at low alpha)
- Animation timing changes in GridEngine must match duration used in FogOverlayRenderer

## Builder Guidance
- Certainty level: Firm
- The zoom fade and animation improvement are small enough to combine into one REQ
- Stretch goal: radial reveal (clear circle expanding from center) — only implement if uniform ease-out feels insufficient with the blur

## Verification

**Source**: UR-018/input.md
**Pre-fix coverage**: 100% (7/7 items)

### Coverage Map

| # | Item | REQ Section | Status |
|---|------|-------------|--------|
| 1 | Replace hard cutoff with gradual fade | Smooth zoom-out | Full |
| 2 | cellOpacity threaded through rendering | Smooth zoom-out | Full |
| 3 | Skip photo text at low opacity | Smooth zoom-out | Full |
| 4 | 700ms duration, 14 frames | Clearing animation | Full |
| 5 | Ease-out cubic curve | Clearing animation | Full |
| 6 | Update pruneRecentlyRevealed cutoff | Clearing animation | Full |
| 7 | New constants | Constants | Full |

*Verified by verify-request action*
