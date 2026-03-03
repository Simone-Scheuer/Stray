import SwiftUI

struct SettingsView: View {
    @Environment(\.locationService) var locationService
    @Environment(\.dismiss) private var dismiss
    @AppStorage(Constants.showMapLabelsKey) private var showMapLabels = false

    var body: some View {
        NavigationStack {
            List {
                trackingSection
                mapSection
                locationSection
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
            Toggle("Show Map Labels", isOn: $showMapLabels)
        } header: {
            Text("Map")
        } footer: {
            Text("Show points of interest and place labels on the map.")
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
