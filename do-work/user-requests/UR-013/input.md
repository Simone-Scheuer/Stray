---
id: UR-013
title: Post-ideation feature batch — confirmed items from sweep discussion
created_at: 2026-03-06T13:00:00Z
requests: [REQ-036, REQ-037, REQ-038, REQ-039, REQ-040, REQ-041, REQ-042, REQ-043, REQ-044]
word_count: 850
---

# Post-Ideation Feature Batch

## Summary
User reviewed the REQ-035 ideation sweep and confirmed 9 features to build. Photo dots refined (settings toggle, scaled dot size). Derive mode discussion ongoing (may produce separate REQ). Items ordered by recommended build priority.

## Extracted Requests

| ID | Title | Summary |
|----|-------|---------|
| REQ-036 | Session pause/resume | Pause Stray session without ending it |
| REQ-037 | Fog Gaussian blur | Soft edges on fog boundary |
| REQ-038 | Cell clearing animation | 200ms fade when new cell revealed in real-time |
| REQ-039 | Session path trace | Polyline showing walking path during active session |
| REQ-040 | Photo dots on map | Scaled dots showing photo locations, settings toggle |
| REQ-041 | Cell notes | Short text notes in cell inspector |
| REQ-042 | Photo timeline sync | Show day's photos when scrubbing timeline |
| REQ-043 | Timeline scrubber | Replace pill tap-navigation with continuous scrubber |
| REQ-044 | Zoom-out region pins | Clustered annotations when zoomed out far |

## Batch Constraints
- No feature creep — keep each implementation minimal
- Philosophy: anti-optimization, no gamification
- Cell inspector must remain comfortable at half-screen height with internal scrolling
- Photo dots: settings toggle (on by default), NOT action bar button
- Don't crowd the existing UI; each feature should feel native

## Full Verbatim Input

yes but maybe make photo dots a toggleable feature in settings so we dont crowd the menu bar - that is on by default - and what if it showed roughly how many photos were there? up to an obvious max? thoughts? also i want to have a real discussion about derive mode, like users can ideniy empty reigions in thier map so what are we relaly doinng for them by selecting the cells- their path will be influenced by their enviroment anyway - derive mode could drop the guiding you and just be a walk you record and that tracks your path etc? thoughts? capture 1234678 and 10 and lets discuss the others

[Prior context: User reviewed REQ-035 ideation sweep. Confirmed items 1 (Session Pause/Resume), 2 (Fog Gaussian Blur), 3 (Cell Clearing Animation), 4 (Session Path Trace), 6 (Cell Notes), 7 (Photo Timeline Sync), 8 (Timeline Scrubber), 10 (Zoom-Out Region Pins) from recommended build order. Photo Dots (#5) refined with settings toggle and count indicator. Random Direction Compass (#9) and Derive mode philosophy under separate discussion.]

---
*Captured: 2026-03-06T13:00:00Z*
