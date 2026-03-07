---
id: REQ-040
title: Photo dots on map
status: done
created_at: 2026-03-06T13:00:00Z
completed_at: 2026-03-06T14:30:00Z
user_request: UR-013
batch: post-ideation
---

# Photo Dots on Map

## What
Show small colored dots on the regular map view at cell locations that contain geotagged photos. Dot size scales with photo count. Toggled via Settings (on by default), NOT an action bar button.

## Implementation Summary
- **Constants.swift**: Added `showPhotoDotsKey` AppStorage key, `photoDotColor` (muted purple)
- **GridEngine.swift**: Added `photoDotsData: [GridCell: Int]?`, `updatePhotoDots(_:)`, `clearPhotoDots()` methods; bumps `renderGeneration` on update
- **FogOverlay.swift**: Draws filled ellipses at cell centers in `draw(_:zoomScale:in:)` when `photoDotsData` is set and `photoCells` is nil (regular mode only); dot radius scales with photo count (8%/12%/16% of cell width)
- **SettingsView.swift**: "Show Photo Markers" toggle in Map section
- **ContentView.swift**: `@AppStorage(Constants.showPhotoDotsKey)` drives `refreshPhotoDots()` helper; onChange handlers sync dots with toggle and PhotoService scan completion

## Builder Guidance
- Certainty level: Firm on the feature, exploratory on exact sizing/color
- User specifically said: "make photo dots a toggleable feature in settings so we don't crowd the menu bar - that is on by default"
- User said: "what if it showed roughly how many photos were there?" — dot size scaling was recommended over number badges

---
*Source: User refined from ideation sweep. Wants to "see visually where your photos are without entering photo mode."*
