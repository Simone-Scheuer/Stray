import SwiftUI
import Photos

struct SettingsView: View {
    @Environment(\.locationService) var locationService
    @Environment(\.photoService) var photoService
    @Environment(\.dismiss) private var dismiss
    @AppStorage(Constants.showMapLabelsKey) private var showMapLabels = false
    @AppStorage(Constants.mutedMapStyleKey) private var mutedMapStyle = true
    @AppStorage(Constants.showTrafficKey) private var showTraffic = false
    @AppStorage(Constants.showScaleKey) private var showScale = true
    @AppStorage(Constants.allowRotationKey) private var allowRotation = true

    var body: some View {
        NavigationStack {
            List {
                trackingSection
                mapSection
                locationSection
                photoSection
                aboutSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Tracking

    private var trackingSection: some View {
        Section {
            Toggle("Background Tracking", isOn: Binding(
                get: { locationService.isTracking },
                set: { newValue in
                    if newValue {
                        locationService.startTracking()
                    } else {
                        locationService.stopTracking()
                    }
                }
            ))
        } header: {
            Text("Tracking")
        } footer: {
            Text("When enabled, Stray reveals the map as you move — even in the background.")
        }
    }

    // MARK: - Map

    private var mapSection: some View {
        Section {
            Toggle("Muted Style", isOn: $mutedMapStyle)
            Toggle("Show Labels", isOn: $showMapLabels)
            Toggle("Show Traffic", isOn: $showTraffic)
            Toggle("Show Scale", isOn: $showScale)
            Toggle("Allow Rotation", isOn: $allowRotation)
        } header: {
            Text("Map")
        } footer: {
            Text("Muted style dims the base map so your exploration colors stand out more.")
        }
    }

    // MARK: - Location Permission

    private var locationSection: some View {
        Section {
            HStack {
                Text("Permission")
                Spacer()
                Text(permissionLabel)
                    .foregroundStyle(.secondary)
            }

            if locationService.authorizationStatus == .authorizedWhenInUse {
                Button("Upgrade to Always Allow") {
                    locationService.requestAlwaysPermission()
                }
            }

            if locationService.authorizationStatus == .denied || locationService.authorizationStatus == .restricted {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            }
        } header: {
            Text("Location")
        } footer: {
            if locationService.authorizationStatus == .authorizedWhenInUse {
                Text("\"Always\" lets Stray track in the background so you never miss a step.")
            }
        }
    }

    // MARK: - Photos

    private var photoSection: some View {
        Section {
            HStack {
                Text("Permission")
                Spacer()
                Text(photoPermissionLabel)
                    .foregroundStyle(.secondary)
            }

            if photoService.isAuthorized {
                Button("Rescan Photo Library") {
                    photoService.scanLibrary()
                }
            }

            if photoService.authorizationStatus == .denied {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            }

            if photoService.authorizationStatus == .notDetermined {
                Button("Allow Photo Access") {
                    Task { let _ = await photoService.requestAuthorization() }
                }
            }
        } header: {
            Text("Photos")
        } footer: {
            Text("Stray reads photo locations to show them on explored tiles. Photos are never copied.")
        }
    }

    private var photoPermissionLabel: String {
        switch photoService.authorizationStatus {
        case .notDetermined: return "Not Set"
        case .restricted: return "Restricted"
        case .denied: return "Denied"
        case .authorized: return "Full Access"
        case .limited: return "Limited"
        @unknown default: return "Unknown"
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                Text("Stray")
                    .font(.headline)

                Text("Inspired by the Situationist International concept of the d\u{00E9}rive — an unplanned journey through a landscape, guided by the pull of the terrain and the encounters you find there.")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                Text("Stray is anti-optimization. No leaderboards, no streaks to protect, no pressure. Just a quiet record of everywhere you've been.")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                Text("Life Cartography.")
                    .font(.callout.italic())
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        } header: {
            Text("About")
        } footer: {
            Text(appVersionString)
                .frame(maxWidth: .infinity)
                .padding(.top, 16)
        }
    }

    private var appVersionString: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "Stray v\(version) (\(build))"
    }

    // MARK: - Helpers

    private var permissionLabel: String {
        switch locationService.authorizationStatus {
        case .notDetermined: return "Not Set"
        case .restricted: return "Restricted"
        case .denied: return "Denied"
        case .authorizedWhenInUse: return "When In Use"
        case .authorizedAlways: return "Always"
        @unknown default: return "Unknown"
        }
    }
}
