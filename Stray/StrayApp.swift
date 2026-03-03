import SwiftUI
import SwiftData
import UIKit
import Combine

@main
struct StrayApp: App {
    let modelContainer: ModelContainer
    private let gridEngine: GridEngine
    private let locationService: LocationService
    private let persistenceService: PersistenceService
    private let straySessionViewModel: StraySessionViewModel
    private let statsViewModel: StatsViewModel

    /// Tracks whether a dedup-on-foreground pass has already run this activation cycle
    @State private var showOnboarding: Bool

    init() {
        let config = ModelConfiguration(cloudKitDatabase: .automatic)
        let container: ModelContainer
        do {
            container = try ModelContainer(
                for: RevealedCell.self, StraySession.self, DailySummary.self, SpecialTile.self,
                configurations: config
            )
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
        self.modelContainer = container

        let context = ModelContext(container)
        let persistence = PersistenceService(context: context)
        let grid = GridEngine()
        let location = LocationService()

        persistence.deduplicateCells()
        persistence.deduplicateSpecialTiles()
        persistence.fixupDailySummaryActiveFlags()
        grid.loadCells(from: context)
        grid.loadSpecialTiles(from: context)

        let sessionVM = StraySessionViewModel(
            gridEngine: grid,
            locationService: location,
            persistenceService: persistence
        )

        // Boot reveal: first valid location fix clears a 3x3 area around the user
        var hasBootRevealed = !grid.revealedCells.isEmpty

        // Wire the location -> grid -> persistence -> fog refresh + session pipeline
        location.onLocationUpdate = { coordinate, distance in
            if !hasBootRevealed {
                hasBootRevealed = true
                grid.revealBlock(around: coordinate)

                // Persist boot-revealed cells so they survive restarts
                let center = GridCell.from(latitude: coordinate.latitude, longitude: coordinate.longitude)
                let r = Constants.bootRevealRadius
                for dLat in -r...r {
                    for dLng in -r...r {
                        let c = GridCell(latIndex: center.latIndex + dLat, lngIndex: center.lngIndex + dLng)
                        let _ = persistence.saveOrUpdateCell(c, at: c.centerCoordinate)
                    }
                }
                persistence.save()

                // Force a second render after MapKit has had time to set up
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(500))
                    grid.forceRender()
                }
            }

            let cell = GridCell.from(latitude: coordinate.latitude, longitude: coordinate.longitude)
            let result = grid.revealCell(at: coordinate)

            // Only persist cell changes when cooldown allows
            if case .cooldownActive = result {} else {
                let _ = persistence.saveOrUpdateCell(cell, at: coordinate)
            }

            let isNew: Bool
            if case .newCell = result { isNew = true } else { isNew = false }

            let steps = distance > 0 ? Int(distance / Constants.averageStrideLengthMeters) : 0
            if isNew || distance > 0 {
                persistence.updateDailySummary(
                    newCells: isNew ? 1 : 0,
                    distance: distance,
                    steps: steps
                )
            }

            if isNew {
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                persistence.detectCity(for: cell, at: coordinate)
            }

            persistence.save()

            // Feed session pipeline
            sessionVM.onSessionLocationUpdate(coordinate: coordinate, distance: distance)
            if isNew {
                sessionVM.onCellRevealed()
            }
        }

        self.gridEngine = grid
        self.locationService = location
        self.persistenceService = persistence
        self.straySessionViewModel = sessionVM
        self.statsViewModel = StatsViewModel()

        let onboardingCompleted = UserDefaults.standard.bool(forKey: Constants.hasCompletedOnboardingKey)
        self._showOnboarding = State(initialValue: !onboardingCompleted)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.gridEngine, gridEngine)
                .environment(\.locationService, locationService)
                .environment(\.persistenceService, persistenceService)
                .environment(\.straySessionViewModel, straySessionViewModel)
                .environment(\.statsViewModel, statsViewModel)
                .fullScreenCover(isPresented: $showOnboarding) {
                    OnboardingView(locationService: locationService) {
                        showOnboarding = false
                    }
                }
                .onAppear {
                    startTrackingIfPermitted()
                }
                .onChange(of: locationService.authorizationStatus) { _, newStatus in
                    if newStatus == .authorizedWhenInUse || newStatus == .authorizedAlways {
                        locationService.startTracking()
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    deduplicateAndReload()
                }
        }
        .modelContainer(modelContainer)
    }

    private func startTrackingIfPermitted() {
        let status = locationService.authorizationStatus
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            locationService.startTracking()
        }
    }

    /// Runs dedup on CloudKit-synced data and reloads GridEngine to pick up merged/new records
    private func deduplicateAndReload() {
        let context = ModelContext(modelContainer)
        let dedupService = PersistenceService(context: context)
        dedupService.deduplicateCells()
        dedupService.deduplicateSpecialTiles()
        dedupService.fixupDailySummaryActiveFlags()
        gridEngine.loadCells(from: context)
        gridEngine.loadSpecialTiles(from: context)
    }
}
