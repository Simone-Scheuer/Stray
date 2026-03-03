import Foundation
import CoreLocation
import UIKit

@Observable
final class LocationService: NSObject, CLLocationManagerDelegate {
    private(set) var currentLocation: CLLocationCoordinate2D?
    private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined
    private(set) var isTracking = false
    private(set) var cumulativeDistance: Double = 0.0
    private(set) var estimatedSteps: Int = 0
    private(set) var isLowPowerActive = false
    var isActiveMode = false

    var onLocationUpdate: ((CLLocationCoordinate2D, Double) -> Void)?

    private let locationManager = CLLocationManager()
    private var backgroundSession: CLBackgroundActivitySession?
    private var trackingTask: Task<Void, Never>?
    private var lastValidLocation: CLLocation?
    private var hasDeliveredFirstUpdate = false
    private var powerStateObserver: NSObjectProtocol?

    override init() {
        super.init()
        locationManager.delegate = self
        authorizationStatus = locationManager.authorizationStatus

        UIDevice.current.isBatteryMonitoringEnabled = true
        updatePowerState()

        powerStateObserver = NotificationCenter.default.addObserver(
            forName: .NSProcessInfoPowerStateDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handlePowerStateChange()
        }
    }

    deinit {
        if let observer = powerStateObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    /// Returns true if the device is in Low Power Mode or battery is below 20%
    private func updatePowerState() {
        let lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
        let lowBattery = UIDevice.current.batteryLevel >= 0 && UIDevice.current.batteryLevel < 0.20
        isLowPowerActive = lowPower || lowBattery
    }

    private func handlePowerStateChange() {
        let wasLowPower = isLowPowerActive
        updatePowerState()
        // If power state changed while tracking in active mode, force downgrade to passive
        if isLowPowerActive != wasLowPower && isTracking {
            if isLowPowerActive && isActiveMode {
                switchMode(active: false)
            }
            // Restart updates with the appropriate accuracy threshold
            trackingTask?.cancel()
            trackingTask = nil
            startLocationUpdates()
        }
    }

    /// The effective accuracy threshold, widened to 150m when in low-power state
    private var effectiveAccuracyThreshold: CLLocationAccuracy {
        if isLowPowerActive {
            return Constants.lowPowerAccuracyThreshold
        }
        return isActiveMode ? Constants.activeAccuracyThreshold : Constants.passiveAccuracyThreshold
    }

    func requestWhenInUsePermission() {
        locationManager.requestWhenInUseAuthorization()
    }

    func requestAlwaysPermission() {
        locationManager.requestAlwaysAuthorization()
    }

    func startTracking() {
        guard !isTracking else { return }
        isTracking = true
        backgroundSession = CLBackgroundActivitySession()
        startLocationUpdates()
    }

    func stopTracking() {
        isTracking = false
        trackingTask?.cancel()
        trackingTask = nil
        backgroundSession?.invalidate()
        backgroundSession = nil
    }

    func switchMode(active: Bool) {
        // Refuse to enter active mode when battery is constrained
        let effectiveActive = active && !isLowPowerActive
        guard isActiveMode != effectiveActive else { return }
        isActiveMode = effectiveActive
        if isTracking {
            trackingTask?.cancel()
            trackingTask = nil
            startLocationUpdates()
        }
    }

    private func startLocationUpdates() {
        trackingTask?.cancel()
        let useActive = isActiveMode && !isLowPowerActive
        let config: CLLocationUpdate.LiveConfiguration = useActive ? .automotiveNavigation : .default
        trackingTask = Task {
            let updates = CLLocationUpdate.liveUpdates(config)
            do {
                for try await update in updates {
                    guard !Task.isCancelled else { break }
                    await MainActor.run { self.processUpdate(update) }
                }
            } catch {
                // Stream ended or was cancelled
            }
        }
    }

    private func processUpdate(_ update: CLLocationUpdate) {
        // Skip stationary updates — biggest battery saver
        // Always deliver the first update so boot reveal can fire
        if hasDeliveredFirstUpdate {
            if #available(iOS 18.0, *) {
                if update.stationary { return }
            } else {
                if update.isStationary { return }
            }
        }

        guard let location = update.location else { return }

        let threshold = effectiveAccuracyThreshold
        guard location.horizontalAccuracy >= 0, location.horizontalAccuracy <= threshold else { return }

        hasDeliveredFirstUpdate = true

        var incrementalDistance: Double = 0
        if let last = lastValidLocation {
            let dist = last.distance(from: location)
            if dist >= Constants.minimumDistanceBetweenUpdatesMeters {
                incrementalDistance = dist
                cumulativeDistance += dist
                estimatedSteps = Int(cumulativeDistance / Constants.averageStrideLengthMeters)
            }
        }

        lastValidLocation = location
        currentLocation = location.coordinate
        onLocationUpdate?(location.coordinate, incrementalDistance)
    }

    // MARK: - CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
    }
}
