import SwiftUI
import UIKit

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

    var body: some View {
        mainContent
            .overlay(alignment: .bottom) { recenterButton }
            .animation(.easeInOut(duration: 0.25), value: isFollowingUser)
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
                isFollowingUser: $isFollowingUser,
                onCellTapped: { cell in
                    guard !showTimeline else { return }
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    gridEngine.setInspectedCell(cell)
                    inspectedCell = cell
                }
            )
            .ignoresSafeArea()

            VStack {
                if !showTimeline {
                    actionButtonBar
                    modeBadges
                    Spacer()
                } else {
                    Spacer()
                }
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
            }
        }
    }

    private var actionButtonBar: some View {
        HStack {
            Spacer()
            HStack(spacing: 12) {
                iconButton(systemName: "clock.arrow.circlepath", label: "View timeline") {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    enterTimeline()
                }
                iconButton(
                    systemName: showHeatMode ? "flame.fill" : "flame",
                    tint: showHeatMode ? .orange.opacity(0.7) : nil,
                    label: showHeatMode ? "Exit heat map" : "View heat map"
                ) {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    if showHeatMode { exitHeatMode() } else { enterHeatMode() }
                }
                if photoService.isAuthorized {
                    iconButton(
                        systemName: showPhotoMode ? "photo.fill" : "photo",
                        tint: showPhotoMode ? .purple.opacity(0.7) : nil,
                        label: showPhotoMode ? "Exit photo mode" : "View photo density"
                    ) {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        if showPhotoMode { exitPhotoMode() } else { enterPhotoMode() }
                    }
                }
                iconButton(systemName: "chart.bar", label: "View statistics") {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    showStats = true
                }
                iconButton(systemName: "gearshape", label: "Settings") {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    showSettings = true
                }
            }
            .padding(.trailing, 16)
            .padding(.top, 12)
        }
    }

    @ViewBuilder
    private var modeBadges: some View {
        if showHeatMode {
            HStack {
                Image(systemName: "flame.fill")
                Text("Heat Map")
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.orange.opacity(0.7), in: Capsule())
        }
        if showPhotoMode {
            HStack {
                Image(systemName: "photo.fill")
                Text("Photos")
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.purple.opacity(0.7), in: Capsule())
        }
    }

    @ViewBuilder
    private var recenterButton: some View {
        if !isFollowingUser && !showTimeline {
            Button {
                isFollowingUser = true
            } label: {
                Image(systemName: "location.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(.black.opacity(0.6), in: Circle())
            }
            .accessibilityLabel("Recenter map on your location")
            .padding(.bottom, 40)
            .transition(.opacity)
        }
    }

    @ViewBuilder
    private var emptyTimelineOverlay: some View {
        if showEmptyTimeline {
            Text("Start exploring to build your timeline")
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
            Text("Unable to save exploration data")
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
                Text("Location access is needed to reveal the map")
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
        showTimeline = true
    }

    private func exitTimeline() {
        timelineVM.exit(gridEngine: gridEngine)
        showTimeline = false
    }

    // MARK: - Navigation Buttons

    private func iconButton(systemName: String, tint: Color? = nil, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(tint ?? .black.opacity(0.6), in: Circle())
        }
        .accessibilityLabel(label)
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

                Text("Stray")
                    .font(.system(size: 32, weight: .light, design: .default))
                    .foregroundStyle(.white.opacity(0.9))
                    .tracking(8)
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
