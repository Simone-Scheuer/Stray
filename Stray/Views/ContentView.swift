import SwiftUI
import UIKit

private struct SessionSnapshot {
    let duration: TimeInterval
    let cells: Int
    let distance: Double
    let steps: Int
    let beacons: Int
}

struct ContentView: View {
    @Environment(\.gridEngine) var gridEngine
    @Environment(\.persistenceService) var persistenceService
    @Environment(\.straySessionViewModel) var sessionViewModel
    @Environment(\.photoService) var photoService
    @AppStorage(Constants.showMapLabelsKey) private var showMapLabels = false
    @AppStorage(Constants.mutedMapStyleKey) private var mutedMapStyle = true
    @AppStorage(Constants.showTrafficKey) private var showTraffic = false
    @AppStorage(Constants.showScaleKey) private var showScale = true
    @AppStorage(Constants.allowRotationKey) private var allowRotation = true

    @State private var showStats = false
    @State private var showSettings = false
    @State private var showEndSessionAlert = false
    @State private var inspectedCell: GridCell?
    @State private var showPersistenceError = false
    @State private var errorDismissTask: Task<Void, Never>?

    @State private var showTimeline = false
    @State private var timelineVM = TimelineViewModel()

    @State private var isFollowingUser = true

    @State private var showSessionSummary = false
    @State private var lastSession: SessionSnapshot?
    @State private var summaryDismissTask: Task<Void, Never>?

    @State private var showPsychocachePrompt = false
    @State private var psychocacheDismissTask: Task<Void, Never>?
    @State private var showCamera = false
    @State private var lastBeaconCount = 0

    @State private var showPhotoMode = false
    @State private var showSplash = true

    var body: some View {
        ZStack {
            MapViewRepresentable(
                gridEngine: gridEngine,
                showMapLabels: showMapLabels,
                mutedMapStyle: mutedMapStyle,
                showTraffic: showTraffic,
                showScale: showScale,
                allowRotation: allowRotation,
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
                    // Top-right action buttons
                    HStack {
                        Spacer()
                        HStack(spacing: 12) {
                            if let vm = sessionViewModel {
                                if vm.isSessionActive {
                                    iconButton(systemName: "figure.walk.arrival", tint: .red.opacity(0.7), label: "End exploring session") {
                                        showEndSessionAlert = true
                                    }
                                } else {
                                    iconButton(systemName: "figure.walk.departure", label: "Start exploring") {
                                        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                                        summaryDismissTask?.cancel()
                                        showSessionSummary = false
                                        vm.startSession()
                                    }
                                }
                            }
                            iconButton(systemName: "clock.arrow.circlepath", label: "View timeline") {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                enterTimeline()
                            }
                            if photoService.isAuthorized {
                                iconButton(
                                    systemName: showPhotoMode ? "photo.fill" : "photo",
                                    tint: showPhotoMode ? .purple.opacity(0.7) : nil,
                                    label: showPhotoMode ? "Exit photo mode" : "View photo density"
                                ) {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    if showPhotoMode {
                                        exitPhotoMode()
                                    } else {
                                        enterPhotoMode()
                                    }
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

                    if let vm = sessionViewModel, vm.isSessionActive {
                        sessionHUD(vm: vm)

                        Spacer()

                        HStack {
                            Spacer()
                            StrayCompassView(
                                bearing: vm.compassBearing,
                                hasTarget: vm.hasCompassTarget,
                                noTargetMessage: vm.noTargetMessage,
                                distanceToTarget: vm.distanceToTarget
                            )
                            Spacer()
                        }
                        .padding(.bottom, 16)
                    } else {
                        Spacer()
                    }
                } else {
                    Spacer()
                }
            }

            if showTimeline {
                VStack {
                    Spacer()
                    TimelineOverlayView(timelineVM: timelineVM, onExit: exitTimeline)
                        .environment(\.gridEngine, gridEngine)
                        .environment(\.persistenceService, persistenceService)
                }
            }
        }
        .overlay(alignment: .bottomTrailing) {
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
                .padding(.trailing, 16)
                .padding(.bottom, 40)
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: isFollowingUser)
        .overlay(alignment: .bottom) {
            if showSessionSummary, let snap = lastSession {
                sessionSummaryCard(snap: snap)
                    .padding(.bottom, 40)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .onTapGesture {
                        summaryDismissTask?.cancel()
                        showSessionSummary = false
                    }
            }
        }
        .animation(.easeInOut(duration: 0.4), value: showSessionSummary)
        .overlay(alignment: .bottom) {
            if showPsychocachePrompt {
                psychocachePrompt
                    .padding(.bottom, 100)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.4), value: showPsychocachePrompt)
        .onChange(of: sessionViewModel?.targetsReachedInSession) { old, new in
            guard let new, new > (old ?? 0) else { return }
            lastBeaconCount = new
            showPsychocachePrompt = true
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            psychocacheDismissTask?.cancel()
            psychocacheDismissTask = Task {
                try? await Task.sleep(for: .seconds(5))
                if !Task.isCancelled {
                    showPsychocachePrompt = false
                }
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraView()
                .ignoresSafeArea()
        }
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
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .overlay(alignment: .bottom) {
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
        .animation(.easeInOut(duration: 0.3), value: showPersistenceError)
        .onChange(of: persistenceService?.lastPersistenceError != nil) { _, hasError in
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
        .alert("End Stray?", isPresented: $showEndSessionAlert) {
            Button("End", role: .destructive) {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                if let vm = sessionViewModel {
                    let snapshot = SessionSnapshot(
                        duration: vm.elapsedSeconds,
                        cells: vm.cellsRevealedInSession,
                        distance: vm.distanceInSession,
                        steps: vm.estimatedStepsInSession,
                        beacons: vm.targetsReachedInSession
                    )
                    vm.endSession()
                    lastSession = snapshot
                    showSessionSummary = true
                    summaryDismissTask?.cancel()
                    summaryDismissTask = Task {
                        try? await Task.sleep(for: .seconds(5))
                        if !Task.isCancelled {
                            showSessionSummary = false
                        }
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will end your current Stray session.")
        }
        .onAppear {
            #if DEBUG && targetEnvironment(simulator)
            gridEngine.addTestCells()
            #endif
        }
        .overlay {
            if showSplash {
                SplashOverlay()
                    .transition(.opacity)
                    .ignoresSafeArea()
            }
        }
        .animation(.easeOut(duration: 0.8), value: showSplash)
        .task {
            try? await Task.sleep(for: .seconds(2.5))
            showSplash = false
        }
    }

    // MARK: - Photo Mode

    private func enterPhotoMode() {
        guard !showTimeline, !showPhotoMode else { return }
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
        if !timelineVM.activeDays.isEmpty {
            timelineVM.applyDay(gridEngine: gridEngine, persistence: ps)
        }
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

    // MARK: - Session HUD

    private func sessionHUD(vm: StraySessionViewModel) -> some View {
        TimelineView(.periodic(from: .now, by: 1.0)) { _ in
            HStack(spacing: 16) {
                Label(formattedTime(vm.elapsedSeconds), systemImage: "clock")
                Label("\(vm.cellsRevealedInSession)", systemImage: "square.grid.2x2")
                Label(formattedDistance(vm.distanceInSession), systemImage: "figure.walk")
                if vm.targetsReachedInSession > 0 {
                    Label("\(vm.targetsReachedInSession)", systemImage: "mappin.circle.fill")
                        .foregroundStyle(.red.opacity(0.9))
                }
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.black.opacity(0.6), in: Capsule())
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Session: \(formattedTime(vm.elapsedSeconds)) elapsed, \(vm.cellsRevealedInSession) cells revealed, \(formattedDistance(vm.distanceInSession)) walked, \(vm.targetsReachedInSession) beacons reached")
        }
    }

    // MARK: - Session Summary

    private func sessionSummaryCard(snap: SessionSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Session Complete")
                .font(.headline)
                .foregroundStyle(.white)
            HStack(spacing: 20) {
                summaryItem(icon: "clock", value: formattedTime(snap.duration))
                summaryItem(icon: "square.grid.2x2", value: "\(snap.cells)")
                summaryItem(icon: "figure.walk", value: formattedDistance(snap.distance))
            }
            HStack(spacing: 20) {
                summaryItem(icon: "shoeprints.fill", value: "\(snap.steps)")
                if snap.beacons > 0 {
                    summaryItem(icon: "mappin.circle.fill", value: "\(snap.beacons)", tint: .red.opacity(0.9))
                }
            }
        }
        .padding(20)
        .background(.black.opacity(0.8), in: RoundedRectangle(cornerRadius: 18))
    }

    private func summaryItem(icon: String, value: String, tint: Color = .white) -> some View {
        Label(value, systemImage: icon)
            .font(.callout.monospacedDigit())
            .foregroundStyle(tint)
    }

    // MARK: - Psychocache Prompt

    private var psychocachePrompt: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text("You've arrived.")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.white)
                Text("What do you notice?")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }
            if CameraView.isAvailable {
                Button {
                    psychocacheDismissTask?.cancel()
                    showPsychocachePrompt = false
                    showCamera = true
                } label: {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.black)
                        .frame(width: 40, height: 40)
                        .background(.white, in: Circle())
                }
                .accessibilityLabel("Open camera")
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(.black.opacity(0.8), in: Capsule())
        .onTapGesture {
            psychocacheDismissTask?.cancel()
            showPsychocachePrompt = false
        }
    }

    // MARK: - Formatting

    private func formattedTime(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%02d:%02d", mins, secs)
    }

    private func formattedDistance(_ meters: Double) -> String {
        formatDistance(meters)
    }
}

// MARK: - Splash Overlay

private struct SplashOverlay: View {
    @State private var animationPhase: Double = 0

    private let gridSize = 5
    private let colors: [Color] = [
        Color(UIColor(red: 0.3, green: 0.5, blue: 0.9, alpha: 1.0)),
        Color(UIColor(red: 0.35, green: 0.55, blue: 0.8, alpha: 1.0)),
        Color(UIColor(red: 0.55, green: 0.5, blue: 0.45, alpha: 1.0)),
        Color(UIColor(red: 0.9, green: 0.6, blue: 0.2, alpha: 1.0)),
        Color(UIColor(red: 1.0, green: 0.85, blue: 0.3, alpha: 1.0)),
    ]

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
