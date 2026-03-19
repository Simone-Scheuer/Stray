---
id: REQ-053
title: TestFlight submission prep
route: B
status: pending
priority: medium
depends_on: REQ-051, Apple Developer Program enrollment
---

# TestFlight Submission Prep

## Goal
Get the app through TestFlight review and into beta testers' hands.

## Requirements

### App Store Connect setup
- Create app listing in App Store Connect (bundle ID, name "Stray", category: Navigation or Lifestyle)
- Privacy nutrition labels (location always, photos, camera, health if REQ-050 ships)
- Age rating questionnaire

### Privacy policy
- Simple privacy policy page (GitHub Pages or similar)
- Must cover: location data collected, stored on-device + iCloud, no analytics, no third-party sharing

### Build prep
- Version number: 1.0.0 (build 1)
- App icon — verify all required sizes are in asset catalog
- Launch screen
- Update privacy description strings to be clear and non-scary for App Review

### App Review notes
- Explain why "Always" location is needed (background fog reveal while walking)
- Short demo description or video link showing the fog feature
- Note: no account required, no server, all data is on-device/iCloud

### Screenshots (can be simulator)
- 3-5 screenshots showing: fog map, revealed area with heat colors, Stray compass, cell inspector, stats
