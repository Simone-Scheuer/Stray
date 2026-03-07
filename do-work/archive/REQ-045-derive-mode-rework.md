---
id: REQ-045
title: Derive mode rework — pure session recording
status: pending
created_at: 2026-03-06T13:30:00Z
user_request: UR-014
related: [REQ-036, REQ-039]
---

# Derive Mode Rework — Pure Session Recording

## What
Strip the compass and beacon targeting out of the default Derive (Stray) session experience. Sessions become pure walk recordings: start, walk, see your path, pause/resume, end, get summary. The fog itself is the user's guide — they can see where they haven't been.

## Requirements
### Remove from default session
- Compass arrow no longer appears automatically when a session starts
- No beacon target selection (StrayEngine.pickTarget not called on session start)
- No CompassTargetAnnotation (red dot) placed on map
- No beacon-reached detection or counter in session HUD
- No distance-to-beacon display

### Preserve but deactivate
- Do NOT delete StrayEngine compass/beacon code — keep it for potential future opt-in toggle
- StrayCompassView code stays in the codebase but is not shown by default
- BeaconEvent / targetsReachedInSession logic stays but is dormant

### Session HUD changes
- Remove beacon count from HUD (the mappin.circle.fill counter)
- Keep: time, cells revealed, distance, steps
- Add path trace visualization (REQ-039) as the primary session feedback

### Psychocaching trigger change
- Currently triggers when user reaches a beacon cell
- New trigger: when user enters a cluster of 3+ newly revealed cells in quick succession (they're exploring a new area)
- Or: trigger on first new cell revealed after X minutes of walking (periodic prompt)
- The "You've arrived. What do you notice?" prompt and camera button stay — just triggered differently
- Builder should pick the trigger that feels most natural and least interruptive

### Session summary card
- Remove beacon count from summary
- Keep: duration, cells, distance, steps
- Add: path length or path visualization thumbnail (if feasible)

## Builder Guidance
- Certainty level: Firm — user explicitly agreed to Option A after discussion
- This is philosophically important: the Situationist derive is about surrendering to environmental pull, not following algorithm guidance
- "The fog IS the compass" — the visual map design already tells users where they haven't been
- The compass felt like "random scalloping" in practice — not an adventure
- Don't delete compass code, just don't activate it. Future REQ may add it as opt-in toggle.
- Coordinate with REQ-036 (pause/resume) and REQ-039 (path trace) — these three together define the new session experience

---
*Source: Discussion about Derive mode philosophy. User said "I agree option A." Option A = pure session recording, fog is your compass, no algorithmic guidance.*
