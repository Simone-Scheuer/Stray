import SwiftUI
import UIKit

struct ContentView: View {
    @Environment(\.gridEngine) var gridEngine
    @Environment(\.persistenceService) var persistenceService
    @Environment(\.straySessionViewModel) var sessionViewModel
    @AppStorage(Constants.showMapLabelsKey) private var showMapLabels = false

    @State private var showStats = false
    @State private var showSettings = false
    @State private var showEndSessionAlert = false
    @State private var inspectedCell: GridCell?
    @State private var showPersistenceError = false
    @State private var errorDismissTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            MapViewRepresentable(
                gridEngine: gridEngine,
                showMapLabels: showMapLabels,
                onCellTapped: { cell in
                    inspectedCell = cell
                }
            )
            .ignoresSafeArea()

            VStack {
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
                                    vm.startSession()
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

                if let vm = sessionViewModel, vm.isSessionActive {
                    sessionHUD(vm: vm)

                    Spacer()

                    HStack {
                        StrayCompassView(
                            bearing: vm.compassBearing,
                            hasTarget: vm.hasCompassTarget,
                            noTargetMessage: vm.noTargetMessage
                        )
                        .padding(.leading, 16)
                        Spacer()
                    }
                    .padding(.bottom, 16)
                } else {
                    Spacer()
                }
            }
        }
        .sheet(isPresented: $showStats) {
            StatsView()
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(item: $inspectedCell) { cell in
            CellInspectorView(cell: cell)
                .presentationDetents([.height(220), .medium])
                .presentationDragIndicator(.visible)
        }
        .overlay(alignment: .bottom) {
            if showPersistenceError {
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
                sessionViewModel?.endSession()
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
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.black.opacity(0.6), in: Capsule())
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Session: \(formattedTime(vm.elapsedSeconds)) elapsed, \(vm.cellsRevealedInSession) cells revealed, \(formattedDistance(vm.distanceInSession)) walked")
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
