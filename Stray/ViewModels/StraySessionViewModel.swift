import Foundation
import CoreLocation
import UIKit

@Observable
final class StraySessionViewModel {
    private(set) var isSessionActive = false
    private(set) var sessionStartTime: Date?
    private(set) var cellsRevealedInSession: Int = 0
    private(set) var distanceInSession: Double = 0.0
    private(set) var compassBearing: Double = 0
    private(set) var hasCompassTarget: Bool = false
    private(set) var noTargetMessage: String?

    private static let noTargetMessages = [
        "The familiar stretches in every direction",
        "No uncharted ground nearby — wander further",
        "You know this place well — seek the unknown",
        "Every path here is well-worn — find new ones",
    ]

    private let gridEngine: GridEngine
    private let locationService: LocationService
    private let persistenceService: PersistenceService?
    private let strayEngine: StrayEngine

    init(gridEngine: GridEngine, locationService: LocationService, persistenceService: PersistenceService?) {
        self.gridEngine = gridEngine
        self.locationService = locationService
        self.persistenceService = persistenceService
        self.strayEngine = StrayEngine(gridEngine: gridEngine)
    }

    var elapsedSeconds: TimeInterval {
        guard let start = sessionStartTime else { return 0 }
        return Date().timeIntervalSince(start)
    }

    var estimatedStepsInSession: Int {
        Int(distanceInSession / Constants.averageStrideLengthMeters)
    }

    func startSession() {
        isSessionActive = true
        sessionStartTime = Date()
        cellsRevealedInSession = 0
        distanceInSession = 0
        noTargetMessage = nil

        locationService.switchMode(active: true)

        if let location = locationService.currentLocation {
            updateCompass(from: location)
        }
    }

    func endSession() {
        guard isSessionActive else { return }
        isSessionActive = false
        locationService.switchMode(active: false)

        if let start = sessionStartTime {
            persistenceService?.saveStraySession(
                startedAt: start,
                endedAt: Date(),
                cellsRevealed: cellsRevealedInSession,
                distance: distanceInSession,
                duration: Date().timeIntervalSince(start)
            )
        }

        sessionStartTime = nil
    }

    /// Called from the location pipeline when a new location arrives during a session
    func onSessionLocationUpdate(coordinate: CLLocationCoordinate2D, distance: Double) {
        guard isSessionActive else { return }
        distanceInSession += distance
        updateCompass(from: coordinate)
    }

    /// Called when a new cell is revealed during a session
    func onCellRevealed() {
        guard isSessionActive else { return }
        cellsRevealedInSession += 1
        if let location = locationService.currentLocation {
            updateCompass(from: location)
        }
    }

    private func updateCompass(from location: CLLocationCoordinate2D) {
        let result = strayEngine.calculateBearing(from: location)
        let hadTarget = hasCompassTarget
        hasCompassTarget = result.hasTarget
        noTargetMessage = result.hasTarget ? nil : Self.noTargetMessages.randomElement()!

        if result.hasTarget && !hadTarget {
            UISelectionFeedbackGenerator().selectionChanged()
        }

        if result.hasTarget {
            // Use shortest angular distance to avoid 359->1 spinning the wrong way.
            // Instead of setting the absolute bearing, we accumulate the delta so SwiftUI
            // animates through the shortest arc.
            let newBearing = result.bearing
            var delta = newBearing - (compassBearing.truncatingRemainder(dividingBy: 360.0) + 360.0).truncatingRemainder(dividingBy: 360.0)
            // Normalize delta to [-180, 180]
            if delta > 180.0 { delta -= 360.0 }
            if delta < -180.0 { delta += 360.0 }
            compassBearing += delta
        }
    }
}
