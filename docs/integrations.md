# Stray — Integrations Status

**Last updated:** 2026-05-01

## Project identity

| Field | Value |
|---|---|
| Bundle ID | `com.simonescheuer.stray` |
| Development Team | `RFN4QJX8V3` |
| iOS deployment target | 17.0 |
| Code signing | Automatic via Xcode |
| Apple Developer account | simonscheuer123@gmail.com |

## Apple services

### CloudKit
- Container: `iCloud.com.simonescheuer.stray`
- Environment: **Production** (TestFlight + App Store both use Prod; Xcode-installed Debug builds use Development by default)
- Used for: SwiftData sync of `RevealedCell`, `CellVisit`, `DailySummary`, `StraySession`, `SpecialTile` across the user's devices
- Schema rules:
  - Never use `@Attribute(.unique)` (CloudKit forbids uniqueness constraints)
  - All relationships must be optional
  - All properties must have defaults
  - Lightweight migrations only — once deployed, only add properties (with defaults), never remove/rename
- Deduplication: `PersistenceService.deduplicate*` methods run on launch. Required because multi-device sync creates duplicates.

### MapKit
- `MKMapView` via `UIViewRepresentable` (SwiftUI's `Map` doesn't support custom tile overlays)
- Custom `FogOverlay` extends `MKOverlay`, drawn via `FogOverlayRenderer`
- Map style configurable: standard, hybrid satellite (with optional labels)
- Legal label position: `mapView.layoutMargins.bottom = 45` baseline; animates to `220` when timeline panel is open
- Tile rendering happens on background queue (never main thread)

### CoreLocation
- `LocationService` uses `CLLocationUpdate.liveUpdates(.default)` for passive tracking
- Background tracking enabled via `CLBackgroundActivitySession` + `UIBackgroundModes = ["location"]`
- Filters: `horizontalAccuracy > 100m` (passive), `> 50m` (active), skip when `isStationary`
- Background session is created lazily and reused (1.1.0 change — was previously invalidated/recreated on every `startTracking()`)
- City detection via `CLGeocoder.reverseGeocodeLocation` with rate limiting (`Constants.geocodeRateLimitPerMinute = 40`)
- Identity-header city: foreground-only re-geocode (1.1.0 change)

### Photos (PhotoKit)
- `PhotoService` reads geotagged photos via `PHAsset.location`
- Permission scoping: `NSPhotoLibraryUsageDescription` (read), `NSPhotoLibraryAddUsageDescription` (write — for in-app capture)
- Cells with photos cached in `photoService.cellsWithPhotos`

### CoreMotion (pedometer)
- `PedometerService` queries `CMPedometer` for step counts and distance
- Permission: `NSMotionUsageDescription`
- Used in Stats and Timeline; falls back to GPS-derived estimates when permission denied

### Camera
- In-app camera capture wired through `CameraView`
- Permission: `NSCameraUsageDescription`

## Entitlements

`Stray/Stray.entitlements`:
- `aps-environment = development` (APNs sandbox — see "Known gaps" below)
- `com.apple.developer.icloud-container-identifiers = ["iCloud.com.simonescheuer.stray"]`
- `com.apple.developer.icloud-services = ["CloudKit"]`

## Info.plist privacy strings

- `NSCameraUsageDescription` — capture moments during exploration
- `NSLocationAlwaysAndWhenInUseUsageDescription` — background tracking pitch
- `NSLocationWhenInUseUsageDescription` — foreground tracking pitch
- `NSMotionUsageDescription` — accurate step counts and distance
- `NSPhotoLibraryAddUsageDescription` — save photos taken in-app
- `NSPhotoLibraryUsageDescription` — read locations from existing photos

## Known integration gaps

| Gap | Severity | Notes |
|---|---|---|
| `remote-notification` not in `UIBackgroundModes` | Low | CloudKit falls back to polling instead of push. Cross-device sync is slower than ideal but functional. Pre-existing, predates 1.1.0. |
| `aps-environment = development` in production builds | Low | Means push notifications would hit APNs sandbox; we don't actually send pushes today, so no impact. Worth flipping to `production` if/when we add notification features. |
| `CFBundleShortVersionString` / `CFBundleVersion` hardcoded in Info.plist | Closed-pending-1.2 | Caused 1.1.0 upload rejection initially (file said `1.0`, project settings said `1.1.0`). Currently both hardcoded to `1.1.0` / `13`. Fix: use `$(MARKETING_VERSION)` / `$(CURRENT_PROJECT_VERSION)` variable references. |

## Third-party dependencies

**None.** Project policy is no third-party dependencies without explicit approval.

## App Store / TestFlight workflow

1. Bump `CFBundleShortVersionString` and `CFBundleVersion` in [Info.plist](../Stray/Info.plist) (note: also bump `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` in [project.pbxproj](../Stray.xcodeproj/project.pbxproj) for consistency, even though Info.plist is the source of truth until the variable refactor)
2. Set Xcode destination to **Any iOS Device (arm64)** — not simulator, not connected phone
3. **Product → Archive**
4. **Organizer → Distribute App → App Store Connect → Upload** (automatic signing, default options)
5. Wait for processing (~15-30 min) — email arrives when ready
6. **App Store Connect → TestFlight tab** → assign build to Internal Testing group
7. Install on device via TestFlight app (replaces App Store version, preserves data)
8. Validate manually for ~24-48 hours
9. **App Store Connect → App Store tab → + Version** → attach same build → submit for review
10. Apple review: typically 24-48 hours

### Data preservation guarantees

- Same bundle ID + same Team ID = iOS treats updates as the same app, on-disk data preserved
- TestFlight builds use Production CloudKit environment (same as App Store builds), so iCloud sync data is shared
- Local SwiftData container is in app's sandbox, keyed by bundle ID — never wiped on update unless user manually deletes/offloads the app
- Lightweight migrations are safe; we have not added any `@Model` fields or removed any in 1.1.0

## Build configuration

| Config | Used for |
|---|---|
| Debug | Local Xcode runs (CloudKit Development env) |
| Release | TestFlight + App Store distribution (CloudKit Production env) |

## CI / automation

None currently. All builds, archives, and uploads are manual via Xcode.
