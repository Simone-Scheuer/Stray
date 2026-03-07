import Foundation
import CoreLocation
import MapKit
import UIKit

@Observable
final class StraySessionViewModel {
    private(set) var isSessionActive = false
    private(set) var isSessionPaused = false
    private(set) var sessionStartTime: Date?
    private(set) var cellsRevealedInSession: Int = 0
    private(set) var distanceInSession: Double = 0.0
    private(set) var compassBearing: Double = 0
    private(set) var hasCompassTarget: Bool = false
    private(set) var noTargetMessage: String?
    private(set) var targetsReachedInSession: Int = 0
    private(set) var distanceToTarget: Double? = nil
    private(set) var pathPolyline: MKPolyline?
    private var pathCoordinates: [CLLocationCoordinate2D] = []
    private var pauseStartTime: Date?
    private var accumulatedPausedTime: TimeInterval = 0

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
        let total = Date().timeIntervalSince(start)
        let currentPause = pauseStartTime.map { Date().timeIntervalSince($0) } ?? 0
        return total - accumulatedPausedTime - currentPause
    }

    var estimatedStepsInSession: Int {
        Int(distanceInSession / Constants.averageStrideLengthMeters)
    }

    func startSession() {
        isSessionActive = true
        isSessionPaused = false
        sessionStartTime = Date()
        cellsRevealedInSession = 0
        distanceInSession = 0
        targetsReachedInSession = 0
        accumulatedPausedTime = 0
        pauseStartTime = nil
        pathCoordinates = []
        pathPolyline = nil
        noTargetMessage = nil

        locationService.switchMode(active: true)
    }

    func pauseSession() {
        guard isSessionActive, !isSessionPaused else { return }
        isSessionPaused = true
        pauseStartTime = Date()
        locationService.switchMode(active: false)
    }

    func resumeSession() {
        guard isSessionActive, isSessionPaused else { return }
        if let pauseStart = pauseStartTime {
            accumulatedPausedTime += Date().timeIntervalSince(pauseStart)
        }
        pauseStartTime = nil
        isSessionPaused = false
        locationService.switchMode(active: true)
    }

    func endSession() {
        guard isSessionActive else { return }
        // Finalize any active pause
        if isSessionPaused, let pauseStart = pauseStartTime {
            accumulatedPausedTime += Date().timeIntervalSince(pauseStart)
        }
        isSessionActive = false
        isSessionPaused = false
        pauseStartTime = nil
        locationService.switchMode(active: false)

        // Encode path data for persistence
        var encodedPath: Data? = nil
        if !pathCoordinates.isEmpty {
            let coords = pathCoordinates.flatMap { [Float($0.latitude), Float($0.longitude)] }
            encodedPath = coords.withUnsafeBytes { Data($0) }
        }

        if let start = sessionStartTime {
            let totalDuration = Date().timeIntervalSince(start)
            let activeDuration = totalDuration - accumulatedPausedTime
            persistenceService?.saveStraySession(
                startedAt: start,
                endedAt: Date(),
                cellsRevealed: cellsRevealedInSession,
                distance: distanceInSession,
                duration: activeDuration,
                pausedDuration: accumulatedPausedTime,
                pathData: encodedPath
            )
        }

        sessionStartTime = nil
        accumulatedPausedTime = 0
        pathCoordinates = []
        pathPolyline = nil
    }

    /// Called from the location pipeline when a new location arrives during a session
    func onSessionLocationUpdate(coordinate: CLLocationCoordinate2D, distance: Double) {
        guard isSessionActive, !isSessionPaused else { return }
        distanceInSession += distance
        pathCoordinates.append(coordinate)
        pathPolyline = MKPolyline(coordinates: pathCoordinates, count: pathCoordinates.count)
    }

    /// Called when a new cell is revealed during a session
    func onCellRevealed() {
        guard isSessionActive, !isSessionPaused else { return }
        cellsRevealedInSession += 1
    }

    private func updateCompass(from location: CLLocationCoordinate2D) {
        let result = strayEngine.calculateBearing(from: location)
        let hadTarget = hasCompassTarget
        hasCompassTarget = result.hasTarget
        noTargetMessage = result.hasTarget ? nil : (Self.noTargetMessages.randomElement() ?? "Keep exploring")

        gridEngine.setCompassTarget(result.hasTarget ? result.targetCell : nil)

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

        if let target = result.targetCell, result.hasTarget {
            distanceToTarget = location.distance(to: target.centerCoordinate)
        } else {
            distanceToTarget = nil
        }
    }
}
