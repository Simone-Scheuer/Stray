---
id: UR-005
title: "App Polish Sweep — UI/UX, bugs, accessibility, code quality"
created_at: 2026-03-02
status: pending
requests: [REQ-019, REQ-020, REQ-021, REQ-022, REQ-023, REQ-024, REQ-025]
word_count: 28
---

# UR-005: App Polish Sweep

## Summary

Full codebase sweep for polish issues. User specifically flagged the compass overlap as still unresolved. Sweep found a functional bug (streak always 0), safe area issues, unit inconsistency, missing haptics, missing accessibility, missing empty states, and silent data loss risk.

## Extracted Requests

| ID | Title | Summary |
|----|-------|---------|
| REQ-019 | Fix isActiveDay bug | Streak counter always returns 0 — property never set to true |
| REQ-020 | Fix safe area handling for overlay UI | Compass overlap, Dynamic Island, action button positioning |
| REQ-021 | Standardize distance units | Session HUD shows km, Stats shows mi — pick one system |
| REQ-022 | Add haptic feedback | Key interactions (buttons, session start/end, cell reveal) lack haptics |
| REQ-023 | Add VoiceOver accessibility labels | Icon buttons, compass, stats cards have no accessibility labels |
| REQ-024 | UX polish bundle | Empty states, geocoding loading indicator, app version in Settings |
| REQ-025 | Fix silent error swallowing in persistence | SwiftData save errors silently discarded — data loss risk |

## Full Verbatim Input

run cleanup. and then do a whole app sweep for polish please. the compass issue is still is not resolved so add that to any ui ux polish.

---
*Captured: 2026-03-02*
