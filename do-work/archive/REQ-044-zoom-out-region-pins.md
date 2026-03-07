---
id: REQ-044
title: Zoom-out region pins
status: pending
created_at: 2026-03-06T13:00:00Z
user_request: UR-013
batch: post-ideation
---

# Zoom-Out Region Pins

## What
When zoomed out far enough that individual cells are invisible, show clustered annotation pins at explored regions so users can find their cells on a world-scale map.

## Context
User tested on a friend's phone (friend is from Alaska). At continent-level zoom, explored cells are completely invisible — only the user location dot shows. No way to know where your cells are.

## Requirements
- Detect when zoom level makes cells smaller than ~1px on screen
- At that threshold, replace fog/heat rendering with MKAnnotation pins at region centroids
- Use MKClusterAnnotation (built into MapKit) for automatic grouping
- Show count badge on clustered pins: "Portland (1,247)" or similar
- As user zooms in, pins dissolve and fog/heat takes over
- Pins should be tappable — zooms into that region
- Must work for multi-city explorers (the primary use case)

## Builder Guidance
- Certainty level: Firm — user described the exact problem from real usage
- MapKit's MKClusterAnnotation handles the clustering automatically
- The threshold detection (when to switch from fog to pins) is the main design decision
- Could use the existing spatial index (degree-level buckets) as the basis for region grouping

---
*Source: User's new idea from testing. "When you zoom out quite a bit, you have no way of knowing where your cells are really. They're like completely invisible."*
