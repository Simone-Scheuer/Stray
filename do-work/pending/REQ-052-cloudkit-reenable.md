---
id: REQ-052
title: Re-enable CloudKit sync
route: B
status: pending
priority: medium
depends_on: Apple Developer Program enrollment
---

# Re-enable CloudKit Sync

## Goal
With the paid developer account, re-enable iCloud sync so beta testers get multi-device support.

## Steps
- Add CloudKit entitlement back to project
- Update `ModelContainer` config: `cloudKitDatabase: .automatic`
- Verify deduplication logic still works (merge on `cellKey` at launch)
- Test: reveal cells on device A, wait, check device B
- Test: conflict resolution when both devices reveal different cells offline

## Constraints
- All existing SwiftData CloudKit rules still apply (no @Attribute(.unique), all defaults, optional relationships)
- Dedup must run on every launch, not just first
