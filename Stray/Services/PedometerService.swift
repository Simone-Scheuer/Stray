import Foundation
import CoreMotion
import os

@Observable
final class PedometerService {
    private static let logger = Logger(subsystem: "com.stray.app", category: "pedometer")

    private(set) var isAvailable: Bool
    private(set) var isAuthorized: Bool = false

    private let pedometer: CMPedometer?

    init() {
        let available = CMPedometer.isStepCountingAvailable()
        isAvailable = available
        pedometer = available ? CMPedometer() : nil
        if available {
            refreshAuthorizationStatus()
        }
    }

    func refreshAuthorizationStatus() {
        let status = CMPedometer.authorizationStatus()
        isAuthorized = status == .authorized
    }

    /// Queries step count for a time window. Returns 0 if unavailable or denied.
    func steps(from start: Date, to end: Date) async -> Int {
        guard let pedometer, isAvailable else { return 0 }
        return await withCheckedContinuation { continuation in
            pedometer.queryPedometerData(from: start, to: end) { data, error in
                if let error {
                    Self.logger.error("Pedometer query failed: \(error.localizedDescription, privacy: .public)")
                }
                let steps = data?.numberOfSteps.intValue ?? 0
                continuation.resume(returning: steps)
            }
        }
    }

    /// Queries walking/running distance for a time window (meters). Returns 0 if unavailable.
    func distance(from start: Date, to end: Date) async -> Double {
        guard let pedometer, isAvailable else { return 0 }
        return await withCheckedContinuation { continuation in
            pedometer.queryPedometerData(from: start, to: end) { data, error in
                let meters = data?.distance?.doubleValue ?? 0
                continuation.resume(returning: meters)
            }
        }
    }

    func todaySteps() async -> Int {
        await steps(from: Calendar.current.startOfDay(for: Date()), to: Date())
    }

    func todayDistance() async -> Double {
        await distance(from: Calendar.current.startOfDay(for: Date()), to: Date())
    }
}
