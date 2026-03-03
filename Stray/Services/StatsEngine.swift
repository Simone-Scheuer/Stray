import Foundation
import SwiftData

struct StatsEngine {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func totalCellsRevealed() -> Int {
        let descriptor = FetchDescriptor<RevealedCell>()
        return (try? context.fetchCount(descriptor)) ?? 0
    }

    func currentStreak() -> Int {
        let descriptor = FetchDescriptor<DailySummary>(
            sortBy: [SortDescriptor(\.dateString, order: .reverse)]
        )
        guard let summaries = try? context.fetch(descriptor) else { return 0 }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current

        var streak = 0
        var checkDate = Calendar.current.startOfDay(for: Date())

        for summary in summaries {
            let dateStr = formatter.string(from: checkDate)
            if summary.dateString == dateStr && summary.isActiveDay {
                streak += 1
                guard let previousDay = Calendar.current.date(byAdding: .day, value: -1, to: checkDate) else { break }
                checkDate = previousDay
            } else if summary.dateString == dateStr {
                break
            } else if summary.dateString < dateStr {
                // We passed the date we were looking for without a match — streak broken
                break
            }
        }

        return streak
    }

    func totalDistance() -> Double {
        let descriptor = FetchDescriptor<DailySummary>()
        guard let summaries = try? context.fetch(descriptor) else { return 0 }
        return summaries.reduce(0.0) { $0 + $1.distanceMeters }
    }

    func totalSteps() -> Int {
        let descriptor = FetchDescriptor<DailySummary>()
        guard let summaries = try? context.fetch(descriptor) else { return 0 }
        return summaries.reduce(0) { $0 + $1.stepCount }
    }

    func straySessionCount() -> Int {
        let descriptor = FetchDescriptor<StraySession>()
        return (try? context.fetchCount(descriptor)) ?? 0
    }

    func todayStats() -> (cells: Int, distance: Double, steps: Int) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current
        let today = formatter.string(from: Date())

        let descriptor = FetchDescriptor<DailySummary>(
            predicate: #Predicate<DailySummary> { $0.dateString == today }
        )
        guard let summary = (try? context.fetch(descriptor))?.first else {
            return (cells: 0, distance: 0, steps: 0)
        }
        return (cells: summary.cellsRevealed, distance: summary.distanceMeters, steps: summary.stepCount)
    }

    func cityBreakdown() -> [(city: String, count: Int)] {
        let descriptor = FetchDescriptor<RevealedCell>()
        guard let cells = try? context.fetch(descriptor) else { return [] }

        var grouped: [String: Int] = [:]
        for cell in cells {
            let cityName = cell.city ?? "Unknown"
            grouped[cityName, default: 0] += 1
        }

        return grouped
            .map { (city: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
    }
}
