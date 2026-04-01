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
    private(set) var totalArea: String = "0 km²"

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
        totalArea = formatArea(engine.totalAreaSquareMeters())

        cities = engine.cityBreakdown()
    }

    private func formatArea(_ squareMeters: Double) -> String {
        let useMetric = Locale.current.measurementSystem == .metric
        if useMetric {
            let km2 = squareMeters / 1_000_000.0
            if km2 < 0.01 { return "<0.01 km²" }
            return String(format: "%.2f km²", km2)
        } else {
            let mi2 = squareMeters / 2_589_988.0
            if mi2 < 0.01 { return "<0.01 mi²" }
            return String(format: "%.2f mi²", mi2)
        }
    }

    private func formatNumber(_ value: Int) -> String {
        numberFormatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}
