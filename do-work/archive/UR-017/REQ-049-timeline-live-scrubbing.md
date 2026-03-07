---
id: REQ-049
title: Timeline live scrubbing — render fog as user slides
status: completed
claimed_at: 2026-03-06T13:05:00Z
route: B
completed_at: 2026-03-06T13:10:00Z
created_at: 2026-03-06T13:00:00Z
user_request: UR-017
---

# Timeline Live Scrubbing

## What
Make the timeline scrubber render fog state for each intermediary day as the user drags through, not just the day they land on. Currently the fog only updates when the user lifts their finger / stops dragging.

## Context
The timeline has a continuous scrubber (REQ-043). Currently the fog snapshot only loads for the final selected day. The user should see the fog state update in real-time as they slide through days, creating a smooth "time-lapse" effect of their exploration history.

---
*Source: "can you make it so sliding through intermediary stages on the time line renders them, rather than only rendering the one the user lands on"*

---

## Triage

**Route: B** - Medium

**Reasoning:** Clear feature — need to find how scrubber triggers fog updates and modify the drag handler.

**Planning:** Not required

## Plan

**Planning not required** - Route B: Exploration-guided implementation

Rationale: The scrubber and timeline rendering flow are in known files. Just need to wire up onSelect during drag with throttling.

*Skipped by work action*

## Implementation Summary

- Modified `TimelineScrubber` in `Stray/Views/TimelineOverlayView.swift`:
  - Added throttled `onSelect` call during `.onChanged` (fires at most every 100ms)
  - Tracks `lastFiredIndex` to avoid redundant calls for the same day
  - `.onEnded` now only fires if the final index wasn't already applied
  - Result: fog updates in real-time as user scrubs through the timeline, creating a time-lapse effect

*Completed by work action (Route B)*

## Testing

**Tests run:** xcodebuild build
**Result:** BUILD SUCCEEDED

No testing infrastructure in this project (manual device testing per CLAUDE.md).

*Verified by work action*
