# Stray - Privacy Policy

**Last updated: March 19, 2026**

## What Stray Collects

Stray records your location to reveal a fog-of-war map as you walk. This is the core function of the app. Specifically:

- **Location data** — GPS coordinates are used to determine which map cells you've visited. Location is processed on your device and stored locally.
- **Photo locations** — If you grant photo access, Stray reads the GPS coordinates embedded in your existing photos to reveal places you've already been. Stray never copies, uploads, or modifies your photos.
- **Health data** — If you grant Health access, Stray reads your step count and walking distance to display accurate stats. This data is read-only and never stored outside the Health app.

## Where Your Data Lives

- **On your device.** All exploration data (visited cells, sessions, stats) is stored locally using Apple's SwiftData framework.
- **In your iCloud.** If you have iCloud enabled, your exploration data syncs privately across your devices via Apple's CloudKit. This sync is encrypted and managed entirely by Apple. Stray has no server and cannot access your iCloud data.

## What Stray Does NOT Do

- We do not collect analytics or usage data.
- We do not use third-party SDKs, trackers, or ad networks.
- We do not sell, share, or transmit your data to anyone.
- We do not have a server. There is no backend. Your data never leaves Apple's ecosystem.
- We do not store your photos. We only read their metadata (location and date).

## Permissions

| Permission | Why | Required? |
|-----------|-----|-----------|
| Location (Always) | Reveals the map as you walk, even in the background | Yes, for core functionality |
| Location (When In Use) | Reveals the map while the app is open | Minimum for the app to work |
| Photos | Reads photo locations to pre-reveal visited places | Optional |
| Camera | Take photos during exploration sessions | Optional |
| Health | Accurate step count and walking distance | Optional |

You can revoke any permission at any time in iOS Settings. The app continues to work with reduced functionality.

## Data Deletion

All your data is stored on your device (and optionally in your iCloud). To delete it:
- Delete the Stray app from your device. This removes all local data.
- If you use iCloud sync, the data will also be removed from iCloud when the app is deleted.

## Contact

If you have questions about this privacy policy, contact: strayapp@proton.me

## Changes

We may update this policy as the app evolves. The "last updated" date at the top will reflect any changes.
