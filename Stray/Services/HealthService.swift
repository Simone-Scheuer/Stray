import Foundation
import HealthKit

@Observable
final class HealthService {
    private(set) var isAuthorized = false
    private(set) var isAvailable = false

    private var healthStore: HKHealthStore?

    init() {
        isAvailable = HKHealthStore.isHealthDataAvailable()
        if isAvailable {
            healthStore = HKHealthStore()
        }
    }

    // MARK: - Authorization

    func requestAuthorization() async -> Bool {
        guard let store = healthStore else { return false }

        let typesToRead: Set<HKObjectType> = [
            HKQuantityType(.stepCount),
            HKQuantityType(.distanceWalkingRunning),
        ]

        do {
            try await store.requestAuthorization(toShare: [], read: typesToRead)
            // HealthKit doesn't tell you if the user said yes or no for read types.
            // We check by doing a test query — if it returns data or an empty result, we're authorized.
            // If it throws, we're not.
            let authorized = await checkReadAccess()
            await MainActor.run { isAuthorized = authorized }
            return authorized
        } catch {
            return false
        }
    }

    /// Refreshes authorization state (call on app foreground)
    func refreshAuthorizationStatus() {
        guard healthStore != nil else { return }
        Task {
            let authorized = await checkReadAccess()
            await MainActor.run { isAuthorized = authorized }
        }
    }

    // MARK: - Queries

    /// Steps during a time window (e.g. a Stray session)
    func steps(from start: Date, to end: Date) async -> Int {
        guard let store = healthStore else { return 0 }
        let type = HKQuantityType(.stepCount)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
                let count = result?.sumQuantity()?.doubleValue(for: .count()) ?? 0
                continuation.resume(returning: Int(count))
            }
            store.execute(query)
        }
    }

    /// Walking/running distance during a time window (meters)
    func distance(from start: Date, to end: Date) async -> Double {
        guard let store = healthStore else { return 0 }
        let type = HKQuantityType(.distanceWalkingRunning)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
                let meters = result?.sumQuantity()?.doubleValue(for: .meter()) ?? 0
                continuation.resume(returning: meters)
            }
            store.execute(query)
        }
    }

    /// Today's steps (since midnight)
    func todaySteps() async -> Int {
        await steps(from: Calendar.current.startOfDay(for: Date()), to: Date())
    }

    /// Today's walking distance (since midnight, in meters)
    func todayDistance() async -> Double {
        await distance(from: Calendar.current.startOfDay(for: Date()), to: Date())
    }

    // MARK: - Private

    private func checkReadAccess() async -> Bool {
        guard let store = healthStore else { return false }
        let type = HKQuantityType(.stepCount)
        let predicate = HKQuery.predicateForSamples(
            withStart: Calendar.current.startOfDay(for: Date()),
            end: Date(),
            options: .strictStartDate
        )
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, _, error in
                // If we get an authorization error, we're not authorized
                continuation.resume(returning: error == nil)
            }
            store.execute(query)
        }
    }
}
