---
id: REQ-043
title: Timeline scrubber
status: pending
created_at: 2026-03-06T13:00:00Z
user_request: UR-013
related: [REQ-042]
batch: post-ideation
---

# Timeline Scrubber

## What
Replace the current pill-tap navigation in the timeline overlay with a continuous horizontal scrubber that snaps to days. More scalable as the number of days grows.

## Requirements
- Replace the day-pill row with a horizontal scrubber/slider
- Scrubber snaps to discrete day positions
- Current day indicator/thumb shows the selected date
- Smooth dragging between days with the map updating as you scrub
- Keep prev/next arrows as alternative navigation (or remove if scrubber makes them redundant)
- Stat chips still update per selected day
- Must work well with photo strip (REQ-042) if both are built

## Builder Guidance
- Certainty level: Firm — "we will have to transition from a tap to proceed through the timeline to a scrubber"
- Self-contained UI change in TimelineOverlayView
- Consider whether the scrubber needs date labels (every Nth day? month markers?) or just the selected date display

---
*Source: User confirmed from ideation sweep discussion.*
