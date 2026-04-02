import SwiftUI
import Photos

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.locationService) var locationService
    @Environment(\.gridEngine) var gridEngine
    @Environment(\.photoService) var photoService
    @Environment(\.healthService) var healthService
    @Environment(\.dismiss) private var dismiss
    @State private var showDemoConfirm = false
    @AppStorage(Constants.showMapLabelsKey) private var showMapLabels = false
    @AppStorage(Constants.mutedMapStyleKey) private var mutedMapStyle = true
    @AppStorage(Constants.showTrafficKey) private var showTraffic = false
    @AppStorage(Constants.allowRotationKey) private var allowRotation = true
    @AppStorage(Constants.showPhotoDotsKey) private var showPhotoDots = false
    @AppStorage(Constants.mapStyleKey) private var mapStyle = "satellite"

    var body: some View {
        NavigationStack {
            List {
                trackingSection
                mapSection
                locationSection
                photoSection
                if healthService.isAvailable {
                    healthSection
                }
                #if DEBUG
                debugSection
                #endif
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
            Picker("Map Style", selection: $mapStyle) {
                Text("Satellite").tag("satellite")
                Text("Standard").tag("standard")
            }
            Toggle("Show Labels", isOn: $showMapLabels)
            if mapStyle == "standard" {
                Toggle("Muted Style", isOn: $mutedMapStyle)
            }
            Toggle("Show Traffic", isOn: $showTraffic)
            Toggle("Allow Rotation", isOn: $allowRotation)
            if photoService.isAuthorized {
                Toggle("Show Photo Markers", isOn: $showPhotoDots)
            }
        } header: {
            Text("Map")
        } footer: {
            Text(mapStyle == "satellite"
                 ? "Satellite view shows the real world beneath your fog — revealed areas show aerial imagery."
                 : "Muted style dims the base map so your exploration colors stand out more.")
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

    // MARK: - Health

    private var healthSection: some View {
        Section {
            HStack {
                Text("Permission")
                Spacer()
                Text(healthService.isAuthorized ? "Authorized" : "Not Set")
                    .foregroundStyle(.secondary)
            }

            if !healthService.isAuthorized {
                Button("Allow Health Access") {
                    Task { let _ = await healthService.requestAuthorization() }
                }
            }
        } header: {
            Text("Health")
        } footer: {
            Text("Stray reads steps and distance from Apple Health to show accurate session stats.")
        }
    }

    // MARK: - Debug

    #if DEBUG
    private var debugSection: some View {
        Section {
            Button("Load Demo Profile (Portland)") {
                showDemoConfirm = true
            }
            .confirmationDialog(
                "Load Demo Profile?",
                isPresented: $showDemoConfirm,
                titleVisibility: .visible
            ) {
                Button("Load Demo Data", role: .destructive) {
                    SeedDataService.loadDemoProfile(into: modelContext)
                    gridEngine.loadCells(from: modelContext)
                    gridEngine.loadSpecialTiles(from: modelContext)
                    gridEngine.forceRender()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This replaces all exploration data with a fake Portland profile. Your real data will be erased.")
            }
        } header: {
            Text("Debug")
        } footer: {
            Text("Load fake exploration data to preview all features.")
        }
    }
    #endif

    // MARK: - About

    private var aboutSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                Text("Stray")
                    .font(.headline)

                Text("Inspired by the Situationist International concept of the d\u{00E9}rive — an unplanned journey through a landscape, guided by the pull of the terrain and the encounters you find there.")
                    .font(.callout)
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
