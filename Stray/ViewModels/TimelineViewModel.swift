import Foundation

@Observable
final class TimelineViewModel {
    var activeDays: [DailySummary] = []
    var selectedIndex: Int = 0

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
