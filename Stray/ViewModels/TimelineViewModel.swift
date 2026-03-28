import Foundation

@Observable
final class TimelineViewModel {
    var activeDays: [DailySummary] = []
    var selectedIndex: Int = 0
    var dayCellCount: Int = 0
    var dayNewCellCount: Int = 0

    var selectedDay: DailySummary? {
        guard selectedIndex >= 0 && selectedIndex < activeDays.count else { return nil }
        return activeDays[selectedIndex]
    }

    var canGoBack: Bool { selectedIndex > 0 }
    var canGoForward: Bool { selectedIndex < activeDays.count - 1 }

    var progressLabel: String {
        guard !activeDays.isEmpty else { return "" }
        return "Day \(selectedIndex + 1) of \(activeDays.count)"
    }

    var formattedDate: String {
        guard let day = selectedDay else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        guard let date = formatter.date(from: day.dateString) else { return day.dateString }
        let display = DateFormatter()
        display.dateStyle = .medium
        display.timeStyle = .none
        return display.string(from: date)
    }

    func load(persistence: PersistenceService) {
        activeDays = persistence.fetchActiveDays()
        selectedIndex = 0
    }

    func applyDay(gridEngine: GridEngine, persistence: PersistenceService) {
        guard let day = selectedDay else { return }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        guard let date = formatter.date(from: day.dateString) else { return }
        let cells = persistence.fetchCellsUpTo(date: date)
        gridEngine.enterTimeline(cells: cells)

        // Apply day highlight from CellVisit journal
        let visits = persistence.fetchCellVisits(for: day.dateString)
        if !visits.isEmpty {
            var dayCells = Set<GridCell>()
            var newCells = Set<GridCell>()

            let dayStart = Calendar.current.startOfDay(for: date)
            let dayEnd = Calendar.current.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart

            for visit in visits {
                // Parse cellKey back to GridCell
                let parts = visit.cellKey.split(separator: "_")
                guard parts.count == 2,
                      let latIdx = Int(parts[0]),
                      let lngIdx = Int(parts[1]) else { continue }
                let cell = GridCell(latIndex: latIdx, lngIndex: lngIdx)
                dayCells.insert(cell)

                // Check if this cell was first discovered on this day
                if let record = persistence.fetchCell(key: visit.cellKey),
                   record.firstVisitedAt >= dayStart && record.firstVisitedAt < dayEnd {
                    newCells.insert(cell)
                }
            }
            dayCellCount = dayCells.count
            dayNewCellCount = newCells.count
            gridEngine.setDayHighlight(cells: dayCells, newCells: newCells)
        } else {
            dayCellCount = 0
            dayNewCellCount = 0
            gridEngine.clearDayHighlight()
        }
    }

    func selectIndex(_ index: Int, gridEngine: GridEngine, persistence: PersistenceService) {
        guard index >= 0 && index < activeDays.count else { return }
        selectedIndex = index
        applyDay(gridEngine: gridEngine, persistence: persistence)
    }

    func goBack(gridEngine: GridEngine, persistence: PersistenceService) {
        guard canGoBack else { return }
        selectedIndex -= 1
        applyDay(gridEngine: gridEngine, persistence: persistence)
    }

    func goForward(gridEngine: GridEngine, persistence: PersistenceService) {
        guard canGoForward else { return }
        selectedIndex += 1
        applyDay(gridEngine: gridEngine, persistence: persistence)
    }

    func exit(gridEngine: GridEngine) {
        gridEngine.exitTimeline()
    }

    /// Abbreviated label for a day pill in the scrubber (e.g. "Mar 1")
    func pillLabel(for day: DailySummary) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        guard let date = formatter.date(from: day.dateString) else { return day.dateString }
        let display = DateFormatter()
        display.dateFormat = "MMM d"
        return display.string(from: date)
    }
}
