---
id: REQ-050
title: HealthKit integration for accurate steps/distance
route: C
status: pending
priority: high
---

# HealthKit Integration

## Goal
Replace GPS-estimated steps and distance with HealthKit data when the user grants permission. Fall back gracefully to current GPS estimates if denied.

## Requirements
- Add HealthKit capability in Xcode (entitlements + project.yml)
- Create `HealthService` (@Observable) that requests read access to `stepCount` and `distanceWalkingRunning`
- Query HealthKit for session-scoped data (Stray session start -> now) for the HUD
- Query HealthKit for daily totals for Stats/timeline views
- LocationService keeps its GPS distance tracking as fallback — HealthKit is display-only
- Cell revealing still uses GPS position (unchanged)
- Add HealthKit permission page to onboarding flow (after location, before photos)
- Permission prompt: explain it's optional, GPS fallback works fine
- Add `NSHealthShareUsageDescription` to Info.plist
- Display unit preference: show HealthKit values when authorized, GPS estimates when not
- Session summary card uses HealthKit values when available

## Notes
- HealthKit is NOT available on iPad — guard with `HKHealthStore.isHealthDataAvailable()`
- Query with `HKStatisticsQuery` for totals, not sample queries
- HealthKit queries are async but fast for small date ranges
