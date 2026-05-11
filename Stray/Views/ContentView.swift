import SwiftUI
import UIKit
import CoreLocation

struct ContentView: View {
    @Environment(\.gridEngine) var gridEngine
    @Environment(\.locationService) var locationService
    @Environment(\.persistenceService) var persistenceService
    @Environment(\.photoService) var photoService
    @AppStorage(Constants.showMapLabelsKey) private var showMapLabels = false
    @AppStorage(Constants.mutedMapStyleKey) private var mutedMapStyle = true
    @AppStorage(Constants.showTrafficKey) private var showTraffic = false
    @AppStorage(Constants.allowRotationKey) private var allowRotation = true
    @AppStorage(Constants.mapStyleKey) private var mapStyle = "standard"
    @AppStorage(Constants.experimentalDisableLODKey) private var experimentalDisableLOD = false

    @State private var showStats = false
    @State private var showSettings = false
    @State private var inspectedCell: GridCell?
    @State private var showPersistenceError = false
    @State private var errorDismissTask: Task<Void, Never>?

    @State private var showTimeline = false
    @State private var timelineVM = TimelineViewModel()

    @State private var isFollowingUser = true

    @State private var showEmptyTimeline = false
    @State private var emptyTimelineDismissTask: Task<Void, Never>?

    @State private var showPhotoMode = false
    @State private var showHeatMode = false
    @State private var showSplash = true

    @State private var currentCity: String?

    @AppStorage("hasRequestedAlwaysPrompt") private var hasRequestedAlwaysPrompt = false

    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        mainContent
            .overlay(alignment: .bottomTrailing) { lensButtonBar }
            .overlay(alignment: .bottom) { recenterButton }
            .animation(.easeInOut(duration: 0.25), value: isFollowingUser)
            .animation(.easeInOut(duration: 0.25), value: showHeatMode)
            .animation(.easeInOut(duration: 0.25), value: showPhotoMode)
            .onChange(of: locationService.currentLocation == nil) { wasNil, isNil in
                if wasNil && !isNil {
                    Task { await updateCurrentCity() }
                }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    Task { await updateCurrentCity() }
                }
            }
            .overlay(alignment: .bottom) { emptyTimelineOverlay }
            .animation(.easeInOut(duration: 0.3), value: showEmptyTimeline)
            .sheet(isPresented: $showStats) {
                StatsView(onOpenTimeline: {
                    showStats = false
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(350))
                        enterTimeline()
                    }
                })
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .sheet(item: $inspectedCell, onDismiss: {
                gridEngine.setInspectedCell(nil)
            }) { cell in
                CellInspectorView(cell: cell)
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            }
            .overlay(alignment: .bottom) { persistenceErrorOverlay }
            .animation(.easeInOut(duration: 0.3), value: showPersistenceError)
            .overlay(alignment: .center) { locationDeniedOverlay }
            .onChange(of: persistenceService?.lastPersistenceError != nil) { _, hasError in
                handlePersistenceError(hasError)
            }
            .onAppear {
                #if DEBUG && targetEnvironment(simulator)
                gridEngine.addTestCells()
                #endif
                // Safety net: if location is already populated when the view appears
                // (cached fix from prior launch), the .onChange(of: locationService.currentLocation == nil)
                // won't fire because the bool never transitions. Run once on appear too.
                Task { await updateCurrentCity() }
            }
            .overlay { splashOverlay }
            .animation(.easeOut(duration: 0.8), value: showSplash)
            .task {
                try? await Task.sleep(for: .seconds(2.5))
                showSplash = false
            }
    }

    // MARK: - Body Subviews

    private var mainContent: some View {
        ZStack {
            MapViewRepresentable(
                gridEngine: gridEngine,
                showMapLabels: showMapLabels,
                mutedMapStyle: mutedMapStyle,
                showTraffic: showTraffic,
                allowRotation: allowRotation,
                mapStyle: mapStyle,
                isTimelineActive: showTimeline,
                experimentalDisableLOD: experimentalDisableLOD,
                isFollowingUser: $isFollowingUser,
                onCellTapped: { cell in
                    guard !showTimeline else { return }
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    gridEngine.setInspectedCell(cell)
                    inspectedCell = cell
                }
            )
            .ignoresSafeArea()

            VStack(spacing: 12) {
                HStack(alignment: .top) {
                    identityHeader
                    Spacer()
                    if !showTimeline {
                        navButtonBar
                            .transition(.opacity)
                    }
                }
                locationUpgradeBanner
                Spacer()
            }

            if showTimeline {
                VStack {
                    Spacer()
                    TimelineOverlayView(timelineVM: timelineVM, onExit: exitTimeline, onCenterCell: { cell in
                        inspectedCell = cell
                        gridEngine.setInspectedCell(cell)
                    })
                        .environment(\.gridEngine, gridEngine)
                        .environment(\.persistenceService, persistenceService)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    private var identityHeader: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .lastTextBaseline, spacing: 8) {
                Text("stray")
                    .font(.system(size: 24, weight: .regular, design: .serif).italic())
                    .foregroundStyle(.white.opacity(0.85))
                if let city = currentCity {
                    Text(city.uppercased())
                        .font(.system(size: 11, weight: .medium, design: .serif))
                        .tracking(1.2)
                        .foregroundStyle(.white.opacity(0.55))
                }
            }
            Text(formattedDate)
                .font(.system(size: 11, weight: .regular, design: .serif).italic())
                .foregroundStyle(.white.opacity(0.55))
        }
        .padding(.leading, 16)
        .padding(.top, 14)
        .accessibilityElement(children: .combine)
    }

    private var navButtonBar: some View {
        HStack(spacing: 14) {
            navIconButton(systemName: "chart.bar", label: "View statistics") {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                showStats = true
            }
            navIconButton(systemName: "gearshape", label: "Settings") {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                showSettings = true
            }
        }
        .padding(.trailing, 16)
        .padding(.top, 14)
    }

    @ViewBuilder
    private var lensButtonBar: some View {
        if !showTimeline {
            HStack(spacing: 12) {
                lensIconButton(
                    systemName: "clock.arrow.circlepath",
                    isActive: false,
                    activeTint: Color(red: 0.85, green: 0.65, blue: 0.35),
                    label: "View timeline"
                ) {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    enterTimeline()
                }
                if photoService.isAuthorized {
                    lensIconButton(
                        systemName: showPhotoMode ? "photo.fill" : "photo",
                        isActive: showPhotoMode,
                        activeTint: Color(red: 0.7, green: 0.55, blue: 0.85),
                        label: showPhotoMode ? "Exit photo mode" : "View photo density"
                    ) {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        if showPhotoMode { exitPhotoMode() } else { enterPhotoMode() }
                    }
                }
                lensIconButton(
                    systemName: showHeatMode ? "flame.fill" : "flame",
                    isActive: showHeatMode,
                    activeTint: Color(red: 0.85, green: 0.65, blue: 0.35),
                    label: showHeatMode ? "Exit heat map" : "View heat map"
                ) {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    if showHeatMode { exitHeatMode() } else { enterHeatMode() }
                }
            }
            .padding(.trailing, 16)
            .padding(.bottom, 40)
        }
    }

    @ViewBuilder
    private var recenterButton: some View {
        if !isFollowingUser && !showTimeline {
            Button {
                isFollowingUser = true
            } label: {
                Image(systemName: "location.fill")
                    .font(.system(size: 16, weight: .light))
                    .foregroundStyle(.white.opacity(0.78))
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
                    .shadow(color: .black.opacity(0.55), radius: 3, y: 1)
            }
            .accessibilityLabel("Recenter map on your location")
            .padding(.bottom, 40)
            .transition(.opacity)
        }
    }

    @ViewBuilder
    private var emptyTimelineOverlay: some View {
        if showEmptyTimeline {
            Text("Walk to build your timeline.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.9))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.black.opacity(0.7), in: Capsule())
                .padding(.bottom, 40)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    @ViewBuilder
    private var persistenceErrorOverlay: some View {
        if showPersistenceError && !showTimeline {
            Text("Couldn't save your data.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.9))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.red.opacity(0.7), in: Capsule())
                .padding(.bottom, 40)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    @ViewBuilder
    private var locationDeniedOverlay: some View {
        if locationService.authorizationStatus == .denied && gridEngine.revealedCells.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "location.slash")
                    .font(.system(size: 32))
                    .foregroundStyle(.white.opacity(0.7))
                Text("Stray needs location to reveal the map.")
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .font(.callout.weight(.medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(.white.opacity(0.2), in: Capsule())
            }
            .padding(32)
        }
    }

    @ViewBuilder
    private var locationUpgradeBanner: some View {
        let status = locationService.authorizationStatus
        let bigOverlayActive = (status == .denied && gridEngine.revealedCells.isEmpty)
        let shouldShow = (status == .authorizedWhenInUse || status == .denied)
            && !bigOverlayActive
            && !showTimeline
            && !showSplash
        if shouldShow {
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                handleLocationUpgradeTap()
            } label: {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(status == .denied
                             ? "Location is turned off."
                             : "Stray only records while the app is open.")
                            .font(.system(size: 12, weight: .regular, design: .serif).italic())
                            .foregroundStyle(.white.opacity(0.85))
                            .multilineTextAlignment(.leading)
                        Text(status == .denied
                             ? "Turn it on in Settings to keep revealing the map"
                             : "Allow background tracking to record even when closed")
                            .font(.system(size: 12, weight: .regular, design: .serif))
                            .foregroundStyle(Color(red: 0.85, green: 0.65, blue: 0.35))
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(Color(red: 0.85, green: 0.65, blue: 0.35))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(.white.opacity(0.06), lineWidth: 0.5)
                )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .accessibilityLabel(status == .denied
                                ? "Turn on location in Settings"
                                : "Allow background location tracking")
            .accessibilityHint(status == .denied
                               ? "Location is off. Tap to open Settings."
                               : "Stray only records while the app is open. Tap to allow background tracking.")
        }
    }

    private func handleLocationUpgradeTap() {
        let status = locationService.authorizationStatus
        // iOS won't re-prompt once denied or once Always was already requested,
        // so the only action that does anything is sending the user to Settings.
        if status == .denied || hasRequestedAlwaysPrompt {
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        } else {
            hasRequestedAlwaysPrompt = true
            locationService.requestAlwaysPermission()
        }
    }

    @ViewBuilder
    private var splashOverlay: some View {
        if showSplash {
            SplashOverlay()
                .transition(.opacity)
                .ignoresSafeArea()
        }
    }

    // MARK: - Body Helpers

    private func handlePersistenceError(_ hasError: Bool) {
        if hasError {
            showPersistenceError = true
            errorDismissTask?.cancel()
            errorDismissTask = Task {
                try? await Task.sleep(for: .seconds(5))
                if !Task.isCancelled {
                    showPersistenceError = false
                }
            }
        } else {
            showPersistenceError = false
            errorDismissTask?.cancel()
        }
    }

    // MARK: - Heat Mode

    private func enterHeatMode() {
        guard !showTimeline, !showHeatMode else { return }
        if showPhotoMode { exitPhotoMode() }
        gridEngine.enterHeatMode()
        showHeatMode = true
    }

    private func exitHeatMode() {
        gridEngine.exitHeatMode()
        showHeatMode = false
    }

    // MARK: - Photo Mode

    private func enterPhotoMode() {
        guard !showTimeline, !showPhotoMode else { return }
        if showHeatMode { exitHeatMode() }
        var photoCellDict: [GridCell: Int] = [:]
        for cell in photoService.cellsWithPhotos {
            guard gridEngine.isRevealed(cell) else { continue }
            photoCellDict[cell] = photoService.photoCount(for: cell)
        }
        gridEngine.enterPhotoMode(cells: photoCellDict)
        showPhotoMode = true
    }

    private func exitPhotoMode() {
        gridEngine.exitPhotoMode()
        showPhotoMode = false
    }

    // MARK: - Timeline

    private func enterTimeline() {
        guard let ps = persistenceService else { return }
        if showPhotoMode { exitPhotoMode() }
        timelineVM.load(persistence: ps)
        if timelineVM.activeDays.isEmpty {
            showEmptyTimeline = true
            emptyTimelineDismissTask?.cancel()
            emptyTimelineDismissTask = Task {
                try? await Task.sleep(for: .seconds(3))
                if !Task.isCancelled { showEmptyTimeline = false }
            }
            return
        }
        timelineVM.applyDay(gridEngine: gridEngine, persistence: ps)
        withAnimation(.spring(response: 0.42, dampingFraction: 0.85)) {
            showTimeline = true
        }
    }

    private func exitTimeline() {
        timelineVM.exit(gridEngine: gridEngine)
        withAnimation(.spring(response: 0.36, dampingFraction: 0.88)) {
            showTimeline = false
        }
    }

    // MARK: - Navigation Buttons

    /// Top-right nav icons — chromeless glyphs floating on the map.
    /// Drop shadow for legibility against bright cells.
    private func navIconButton(systemName: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .light))
                .foregroundStyle(.white.opacity(0.78))
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
                .shadow(color: .black.opacity(0.55), radius: 3, y: 1)
        }
        .accessibilityLabel(label)
    }

    /// Bottom-right lens toggles — circles restored so they read as buttons, not icons.
    /// Darker, more restrained than the original chrome.
    /// Active: muted brand-tinted symbol on the same dark circle + glow halo.
    private func lensIconButton(systemName: String, isActive: Bool, activeTint: Color, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: isActive ? .regular : .light))
                .foregroundStyle(isActive ? activeTint : .white.opacity(0.7))
                .frame(width: 38, height: 38)
                .background(Circle().fill(Color.black.opacity(0.55)))
                .overlay(Circle().stroke(Color.white.opacity(isActive ? 0 : 0.05), lineWidth: 0.5))
                .shadow(color: isActive ? activeTint.opacity(0.5) : .clear, radius: 14)
        }
        .accessibilityLabel(label)
    }

    // MARK: - Identity Header Helpers

    private var formattedDate: String {
        let now = Date()
        let weekday = now.formatted(.dateTime.weekday(.wide))
        let month = now.formatted(.dateTime.month(.wide))
        let day = Calendar.current.component(.day, from: now)
        let ordinalFormatter = NumberFormatter()
        ordinalFormatter.numberStyle = .ordinal
        let ordinalDay = ordinalFormatter.string(from: NSNumber(value: day)) ?? "\(day)"
        return "\(weekday), the \(ordinalDay) of \(month)"
    }

    private func updateCurrentCity() async {
        guard let coord = locationService.currentLocation else { return }
        let geocoder = CLGeocoder()
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(
                CLLocation(latitude: coord.latitude, longitude: coord.longitude)
            )
            if let city = placemarks.first?.locality {
                await MainActor.run { self.currentCity = city }
            }
        } catch {
            // Silent — city stays nil; will retry on next bucket change
        }
    }
}

// MARK: - Splash Overlay

private struct SplashOverlay: View {
    @State private var animationPhase: Double = 0

    private let gridSize = 5
    private let colors: [Color] = HeatGradient.colors().map {
        Color($0.withAlphaComponent(1.0))
    }

    var body: some View {
        ZStack {
            Color(UIColor(white: 0.06, alpha: 1.0))

            VStack(spacing: 24) {
                gridAnimation

                Text("stray")
                    .font(.system(size: 32, weight: .regular, design: .serif).italic())
                    .foregroundStyle(.white.opacity(0.9))
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                animationPhase = 1.0
            }
        }
    }

    private var gridAnimation: some View {
        VStack(spacing: 4) {
            ForEach(0..<gridSize, id: \.self) { row in
                HStack(spacing: 4) {
                    ForEach(0..<gridSize, id: \.self) { col in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(cellColor(row: row, col: col))
                            .frame(width: 20, height: 20)
                            .opacity(cellOpacity(row: row, col: col))
                    }
                }
            }
        }
    }

    private func cellColor(row: Int, col: Int) -> Color {
        let index = (row + col) % colors.count
        let shift = Int(animationPhase * Double(colors.count))
        return colors[(index + shift) % colors.count]
    }

    private func cellOpacity(row: Int, col: Int) -> Double {
        let normalizedPos = Double(row + col) / Double((gridSize - 1) * 2)
        let phase = (animationPhase + normalizedPos).truncatingRemainder(dividingBy: 1.0)
        return 0.3 + 0.7 * phase
    }
}
