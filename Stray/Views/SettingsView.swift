import SwiftUI
import Photos

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.locationService) var locationService
    @Environment(\.gridEngine) var gridEngine
    @Environment(\.photoService) var photoService
    @Environment(\.dismiss) private var dismiss
    @State private var showDemoConfirm = false
    @AppStorage(Constants.showMapLabelsKey) private var showMapLabels = false
    @AppStorage(Constants.mutedMapStyleKey) private var mutedMapStyle = true
    @AppStorage(Constants.showTrafficKey) private var showTraffic = false
    @AppStorage(Constants.allowRotationKey) private var allowRotation = true
    @AppStorage(Constants.mapStyleKey) private var mapStyle = "standard"

    @State private var showCondensedTitle = false

    private let amberAccent = Color(red: 0.85, green: 0.65, blue: 0.35)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 36) {
                journalHeader
                    .background(headerOffsetReader)
                trackingSection
                permissionsSection
                mapSection
                #if DEBUG
                debugSection
                #endif
                aboutSection
            }
            .padding(.horizontal, 28)
            .padding(.top, 56)
            .padding(.bottom, 48)
        }
        .coordinateSpace(name: "settingsScroll")
        .onPreferenceChange(ScrollOffsetKey.self) { headerMaxY in
            let shouldShow = headerMaxY < 44
            if shouldShow != showCondensedTitle {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showCondensedTitle = shouldShow
                }
            }
        }
        .background(StrayPalette.sheetBackground.ignoresSafeArea())
        .overlay(alignment: .top) {
            ZStack {
                Text("settings")
                    .font(.system(size: 14, weight: .regular, design: .serif))
                    .foregroundStyle(.white.opacity(0.85))
                    .opacity(showCondensedTitle ? 1 : 0)

                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Text("done")
                            .font(.system(size: 14, weight: .regular, design: .serif))
                            .foregroundStyle(.white.opacity(0.75))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.trailing, 16)
            }
            .padding(.top, 12)
            .padding(.bottom, 8)
            .frame(maxWidth: .infinity)
            .background(StrayPalette.sheetBackground)
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Header

    private var journalHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("settings")
                .font(.system(size: 32, weight: .regular, design: .serif))
                .foregroundStyle(.white.opacity(0.92))
            Text("STRAY  ·  \(appVersionString)")
                .font(.system(size: 11, weight: .medium, design: .serif))
                .tracking(1.6)
                .foregroundStyle(.white.opacity(0.5))
        }
        .padding(.top, 8)
    }

    private var headerOffsetReader: some View {
        GeometryReader { geo in
            Color.clear.preference(
                key: ScrollOffsetKey.self,
                value: geo.frame(in: .named("settingsScroll")).maxY
            )
        }
    }

    // MARK: - Tracking

    private var trackingSection: some View {
        section(
            header: "tracking",
            footer: "Reveals cells as you walk, even in the background."
        ) {
            toggleRow("background tracking", isOn: Binding(
                get: { locationService.isTracking },
                set: { newValue in
                    if newValue {
                        locationService.startTracking()
                    } else {
                        locationService.stopTracking()
                    }
                }
            ))
        }
    }

    // MARK: - Map

    private var mapSection: some View {
        section(header: "map") {
            VStack(spacing: 0) {
                pickerRow(
                    label: "map style",
                    selection: $mapStyle,
                    options: [("Standard", "standard"), ("Satellite", "satellite")]
                )
                hairline
                toggleRow("show labels", isOn: $showMapLabels)
                if mapStyle == "standard" {
                    hairline
                    toggleRow("muted style", isOn: $mutedMapStyle)
                }
                hairline
                toggleRow("show traffic", isOn: $showTraffic)
                hairline
                toggleRow("allow rotation", isOn: $allowRotation)
            }
        }
    }

    // MARK: - Permissions

    private var permissionsSection: some View {
        section(header: "permissions") {
            VStack(spacing: 0) {
                // Location
                if locationService.authorizationStatus == .authorizedWhenInUse || locationService.authorizationStatus == .authorizedAlways {
                    navRow("location", value: permissionLabel) {
                        openSystemSettings()
                    }
                } else {
                    valueRow("location", value: permissionLabel)
                }

                if locationService.authorizationStatus == .authorizedWhenInUse {
                    hairline
                    actionRow("upgrade to always allow", accent: amberAccent) {
                        locationService.requestAlwaysPermission()
                    }
                }

                if locationService.authorizationStatus == .denied || locationService.authorizationStatus == .restricted {
                    hairline
                    actionRow("open location settings", accent: amberAccent) {
                        openSystemSettings()
                    }
                }

                hairline

                // Photos
                if photoService.isAuthorized {
                    navRow("photos", value: photoPermissionLabel) {
                        openSystemSettings()
                    }
                    hairline
                    Button {
                        photoService.scanLibrary()
                    } label: {
                        HStack {
                            Text("rescan photo library")
                                .font(.system(size: 16, weight: .regular, design: .serif))
                                .foregroundStyle(.white.opacity(0.88))
                            Spacer()
                            if photoService.isScanning {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .tint(.white.opacity(0.7))
                            }
                        }
                        .padding(.vertical, 12)
                    }
                    .disabled(photoService.isScanning)
                } else {
                    valueRow("photos", value: photoPermissionLabel)
                }

                if photoService.authorizationStatus == .denied || photoService.authorizationStatus == .restricted {
                    hairline
                    actionRow("open photo settings", accent: amberAccent) {
                        openSystemSettings()
                    }
                }

                if photoService.authorizationStatus == .notDetermined {
                    hairline
                    actionRow("allow photo access", accent: amberAccent) {
                        Task { let _ = await photoService.requestAuthorization() }
                    }
                }
            }
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

    // MARK: - Debug

    #if DEBUG
    private var debugSection: some View {
        section(
            header: "debug",
            footer: "Load fake data to preview features."
        ) {
            actionRow("load demo profile (portland)", accent: amberAccent) {
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
                Text("Replaces your real data with a fake Portland profile. Tiles, stats, and notes will all be erased.")
            }
        }
    }
    #endif

    // MARK: - About

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader("about")

            Text("An atlas of where you've been. Inspired by the dérive, the Situationist practice of drifting through a city without a destination.")
                .font(.system(size: 14, weight: .regular, design: .serif))
                .foregroundStyle(.white.opacity(0.7))
                .lineSpacing(4)
                .padding(.vertical, 8)

            Text("STRAY  v\(appVersionString)")
                .font(.system(size: 10, weight: .regular, design: .serif))
                .tracking(1.4)
                .foregroundStyle(.white.opacity(0.35))
                .frame(maxWidth: .infinity)
                .padding(.top, 24)
        }
    }

    private var appVersionString: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
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

    private func openSystemSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    // MARK: - Section Components

    @ViewBuilder
    private func section<Content: View>(
        header: String,
        footer: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(header)
            content()
            if let footer {
                Text(footer)
                    .font(.system(size: 10, weight: .regular, design: .serif))
                    .foregroundStyle(.white.opacity(0.35))
                    .lineSpacing(2)
                    .padding(.top, 4)
            }
        }
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .medium, design: .serif))
            .tracking(1.6)
            .foregroundStyle(.white.opacity(0.65))
    }

    private var hairline: some View {
        Rectangle()
            .fill(Color.white.opacity(0.08))
            .frame(height: 0.5)
    }

    // MARK: - Row Components

    private func toggleRow(_ label: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 16, weight: .regular, design: .serif))
                .foregroundStyle(.white.opacity(0.88))
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(amberAccent)
        }
        .padding(.vertical, 12)
    }

    private func valueRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 16, weight: .regular, design: .serif))
                .foregroundStyle(.white.opacity(0.88))
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .regular, design: .serif))
                .foregroundStyle(.white.opacity(0.5))
        }
        .padding(.vertical, 12)
    }

    private func navRow(_ label: String, value: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(label)
                    .font(.system(size: 16, weight: .regular, design: .serif))
                    .foregroundStyle(.white.opacity(0.88))
                Spacer()
                Text(value)
                    .font(.system(size: 14, weight: .regular, design: .serif))
                    .foregroundStyle(.white.opacity(0.5))
                Image(systemName: "arrow.up.forward")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.4))
            }
            .padding(.vertical, 12)
        }
    }

    private func actionRow(_ label: String, accent: Color = .white, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(label)
                    .font(.system(size: 16, weight: .regular, design: .serif))
                    .foregroundStyle(accent.opacity(0.92))
                Spacer()
            }
            .padding(.vertical, 12)
        }
    }

    private func pickerRow(label: String, selection: Binding<String>, options: [(label: String, value: String)]) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 16, weight: .regular, design: .serif))
                .foregroundStyle(.white.opacity(0.88))
            Spacer()
            Picker("", selection: selection) {
                ForEach(options, id: \.value) { option in
                    Text(option.label).tag(option.value)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .tint(.white.opacity(0.7))
        }
        .padding(.vertical, 12)
    }
}
