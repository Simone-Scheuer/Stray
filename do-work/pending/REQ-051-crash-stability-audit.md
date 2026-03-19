---
id: REQ-051
title: Pre-beta crash and stability audit
route: C
status: pending
priority: high
---

# Pre-Beta Crash & Stability Audit

## Goal
Ensure no crashes or data loss for beta testers. Audit every code path that touches user data, location, or persistence.

## Audit Areas

### Force unwraps / unhandled optionals
- Grep for `!` force unwraps in production code (test helpers exempt)
- Check all `guard let` / `if let` chains have sensible fallbacks
- Verify no implicit unwrap of SwiftData fetch results

### First-launch flow
- Fresh install: onboarding -> permissions -> boot reveal — does it work end-to-end?
- What happens if user denies location? Denies photos? Denies both?
- Does the app degrade gracefully with no permissions at all?

### Background recovery
- iOS kills app in background -> user reopens -> does tracking resume?
- CLBackgroundActivitySession lifecycle — is it properly recreated?
- SwiftData writes during background -> any corruption risk?

### Location edge cases
- Permission revoked mid-session (Settings -> Stray -> Location -> Never)
- Airplane mode / no GPS signal
- Rapid mode switching (passive <-> active)

### SwiftData integrity
- What happens if a SwiftData write fails? (disk full, etc.)
- Deduplication on launch — does it handle 0 duplicates gracefully?
- Large dataset: simulate 10k+ cells, verify no UI lag

### Memory pressure
- Profile with Instruments: Allocations + Leaks
- FogOverlayRenderer iterating dense regions — any allocation spikes?
- PhotoService with large photo libraries (10k+ photos)

### Error states to add
- User-visible error for SwiftData save failures (not just print())
- Graceful handling of HealthKit unavailable (iPad)
