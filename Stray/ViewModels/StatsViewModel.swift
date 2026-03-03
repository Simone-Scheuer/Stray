import Foundation
import SwiftData

@Observable
final class StatsViewModel {
    // Today
    private(set) var todayCells: Int = 0
    private(set) var todayDistance: String = formatDistance(0)
    private(set) var todaySteps: String = "0"

    // Lifetime
    private(set) var totalCells: String = "0"
    private(set) var totalDistance: String = formatDistance(0)
    private(set) var totalSteps: String = "0"
    private(set) var currentStreak: Int = 0
    private(set) var sessionCount: Int = 0

    // Cities
    private(set) var cities: [(city: String, count: Int)] = []

    private let numberFormatter: NumberFormatter = {
        let fmt = NumberFormatter()
        fmt.numberStyle = .decimal
        fmt.groupingSeparator = ","
        return fmt
    }()

    func refresh(context: ModelContext) {
        let engine = StatsEngine(context: context)

        let today = engine.todayStats()
        todayCells = today.cells
        todayDistance = formatDistance(today.distance)
        todaySteps = formatNumber(today.steps)

        totalCells = formatNumber(engine.totalCellsRevealed())
        totalDistance = formatDistance(engine.totalDistance())
        totalSteps = formatNumber(engine.totalSteps())
        currentStreak = engine.currentStreak()
        sessionCount = engine.straySessionCount()

        cities = engine.cityBreakdown()
    }

    private func formatNumber(_ value: Int) -> String {
        numberFormatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}
