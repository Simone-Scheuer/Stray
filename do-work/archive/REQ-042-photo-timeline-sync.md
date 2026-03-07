---
id: REQ-042
title: Photo timeline sync
status: pending
created_at: 2026-03-06T13:00:00Z
user_request: UR-013
related: [REQ-043]
batch: post-ideation
---

# Photo Timeline Sync

## What
When scrubbing the daily timeline, show that day's geotagged photos as a horizontal strip below the map. Tapping a photo centers the map on that cell. Also: retroactively extend the timeline using photo history — days with geotagged photos but no Stray tracking data still appear as explorable timeline entries.

## Requirements
### Photo strip on timeline
- When a timeline day is selected, query PhotoService for photos with creation dates on that day
- Show a horizontal scrollable strip of thumbnails below the timeline stat chips
- Tapping a photo scrolls/centers the map to that photo's cell location
- Strip is empty (hidden) for days with no photos

### Retroactive timeline from photo history
- On first photo scan (or when enabled), identify all unique dates that have geotagged photos
- For dates that have no existing DailySummary or RevealedCell data, create synthetic timeline entries
- These "photo memory" days should be visually distinguishable from actual walk days (different pill color or icon)
- Photo-derived cells could be shown with a distinct visual treatment (dimmer, different tint) to distinguish from cells you actually walked through with Stray
- Decision needed: are photo-derived cells first-class RevealedCells or a separate "memory" layer?

## Builder Guidance
- Certainty level: Firm on photo strip during timeline. Exploratory on retroactive timeline — user said "potentially" and the exact treatment of photo-derived cells needs design work
- The photo strip is moderate scope; the retroactive timeline is larger and could be a follow-up
- Builder should implement photo strip first, then assess retroactive timeline scope

---
*Source: User confirmed. "I like a retroactive timeline that shows if you import into it, it automatically adds all those prior days from your earliest photo to the timeline potentially."*
