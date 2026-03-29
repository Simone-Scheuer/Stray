import Foundation
import SwiftData

/// Generates fake exploration data centered on Portland, OR for UI testing.
/// Activated via Settings → "Load Demo Profile" or launch argument `--seed-demo`.
enum SeedDataService {

    // MARK: - Public

    static func loadDemoProfile(into context: ModelContext) {
        // Wipe existing data first so the demo is clean
        wipeAll(context: context)

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Generate 45 days of walking data, ending yesterday
        let dayCount = 45
        var allCells: [(GridCell, Date, Int)] = [] // (cell, firstDate, visitCount)
        var dailyVisits: [String: [(GridCell, Date)]] = [:] // dateString -> [(cell, visitedAt)]
        var dailyStats: [String: (cells: Int, distance: Double, steps: Int)] = [:]

        let rng = SeededRNG(seed: 42) // Deterministic for consistent demo

        // Portland neighborhoods as walk anchors
        let anchors: [(lat: Double, lng: Double, name: String)] = [
            (45.5231, -122.6765, "Downtown"),        // Pioneer Square area
            (45.5285, -122.6628, "Lloyd District"),   // Convention center
            (45.5175, -122.6814, "PSU / South Park"), // Portland State
            (45.5345, -122.6553, "Sullivan's Gulch"), // Near I-84
            (45.5122, -122.6587, "SE Industrial"),    // Inner SE
            (45.5268, -122.6890, "Pearl District"),   // NW arts area
            (45.5195, -122.6493, "Buckman"),          // SE Belmont/Hawthorne
            (45.5310, -122.6745, "Old Town"),         // Chinatown
            (45.5150, -122.6720, "Waterfront South"), // Along the river
            (45.5380, -122.6500, "Irvington"),        // NE neighborhood
        ]

        // Track all generated cells to avoid duplicates
        var cellTracker: [String: (firstDate: Date, visitCount: Int)] = [:]

        for dayOffset in (1...dayCount).reversed() {
            let dayDate = calendar.date(byAdding: .day, value: -dayOffset, to: today)!
            let dateString = formatDate(dayDate)

            // Pick 1-3 anchors to walk near today
            let anchorCount = rng.nextInt(min: 1, max: 3)
            var todayCells: [(GridCell, Date)] = []
            var todayNewCells = 0
            var todayDistance: Double = 0

            for a in 0..<anchorCount {
                let anchor = anchors[rng.nextInt(min: 0, max: anchors.count - 1)]

                // Generate a random walk path from this anchor
                let pathLength = rng.nextInt(min: 8, max: 40)
                var currentLat = anchor.lat + rng.nextDouble(min: -0.003, max: 0.003)
                var currentLng = anchor.lng + rng.nextDouble(min: -0.003, max: 0.003)

                for step in 0..<pathLength {
                    let cell = GridCell.from(latitude: currentLat, longitude: currentLng)

                    // Time spread across the day (morning walk, afternoon walk, etc.)
                    let baseHour = a == 0 ? 8 : (a == 1 ? 13 : 18)
                    let minuteOffset = step * 2 + rng.nextInt(min: 0, max: 3)
                    let visitTime = calendar.date(
                        byAdding: .minute,
                        value: baseHour * 60 + minuteOffset,
                        to: dayDate
                    )!

                    todayCells.append((cell, visitTime))

                    // Track cell first-visit and accumulate visits
                    if let existing = cellTracker[cell.key] {
                        cellTracker[cell.key] = (
                            firstDate: min(existing.firstDate, dayDate),
                            visitCount: existing.visitCount + 1
                        )
                    } else {
                        cellTracker[cell.key] = (firstDate: dayDate, visitCount: 1)
                        todayNewCells += 1
                    }

                    // Random walk: mostly forward with some lateral drift
                    let direction = rng.nextDouble(min: 0, max: .pi * 2)
                    let stepSize = rng.nextDouble(min: 0.0003, max: 0.0008) // ~30-90m
                    currentLat += cos(direction) * stepSize
                    currentLng += sin(direction) * stepSize
                    todayDistance += stepSize * 111_320 // rough meters
                }
            }

            dailyVisits[dateString] = todayCells
            let steps = Int(todayDistance / 0.7)
            dailyStats[dateString] = (cells: todayNewCells, distance: todayDistance, steps: steps)
        }

        // --- Insert RevealedCells ---
        var cityForCell: [String: String] = [:]
        for (key, info) in cellTracker {
            let parts = key.split(separator: "_")
            let latIdx = Int(parts[0])!
            let lngIdx = Int(parts[1])!

            let cell = RevealedCell(latIndex: latIdx, lngIndex: lngIdx, cellKey: key, city: "Portland")
            cell.firstVisitedAt = info.firstDate
            cell.lastVisitedAt = calendar.date(byAdding: .day, value: rng.nextInt(min: 0, max: 5), to: info.firstDate) ?? info.firstDate
            cell.visitCount = info.visitCount
            context.insert(cell)
            cityForCell[key] = "Portland"
        }

        // --- Insert CellVisits ---
        var seenVisitKeys: Set<String> = []
        for (dateString, visits) in dailyVisits {
            for (cell, visitTime) in visits {
                let compositeKey = "\(cell.key)_\(dateString)"
                guard !seenVisitKeys.contains(compositeKey) else { continue }
                seenVisitKeys.insert(compositeKey)

                let cv = CellVisit(cellKey: cell.key, dateString: dateString)
                cv.visitedAt = visitTime
                context.insert(cv)
            }
        }

        // --- Insert DailySummaries ---
        for (dateString, stats) in dailyStats.sorted(by: { $0.key < $1.key }) {
            let summary = DailySummary(dateString: dateString)
            summary.cellsRevealed = stats.cells
            summary.distanceMeters = stats.distance
            summary.stepCount = stats.steps
            summary.isActiveDay = true
            context.insert(summary)
        }

        // --- Insert a few StraySession records ---
        let sessionDays = [3, 7, 12, 18, 25, 33, 40]
        for dayOffset in sessionDays {
            guard dayOffset <= dayCount else { continue }
            let sessionDate = calendar.date(byAdding: .day, value: -dayOffset, to: today)!
            let session = StraySession()
            session.startedAt = calendar.date(byAdding: .hour, value: 9, to: sessionDate)!
            let duration = Double(rng.nextInt(min: 1200, max: 3600))
            session.endedAt = session.startedAt.addingTimeInterval(duration)
            session.durationSeconds = duration
            session.cellsRevealedCount = rng.nextInt(min: 10, max: 60)
            session.distanceMeters = Double(rng.nextInt(min: 800, max: 5000))
            context.insert(session)
        }

        // --- Insert SpecialTiles ---
        let homeCell = GridCell.from(latitude: 45.5231, longitude: -122.6765)
        let homeTile = SpecialTile(
            cellKey: homeCell.key, latIndex: homeCell.latIndex, lngIndex: homeCell.lngIndex,
            label: "Home", icon: "house.fill", colorHex: "#4CAF50"
        )
        context.insert(homeTile)

        let workCell = GridCell.from(latitude: 45.5285, longitude: -122.6628)
        let workTile = SpecialTile(
            cellKey: workCell.key, latIndex: workCell.latIndex, lngIndex: workCell.lngIndex,
            label: "Work", icon: "briefcase.fill", colorHex: "#7B68EE"
        )
        context.insert(workTile)

        let favCell = GridCell.from(latitude: 45.5268, longitude: -122.6890)
        let favTile = SpecialTile(
            cellKey: favCell.key, latIndex: favCell.latIndex, lngIndex: favCell.lngIndex,
            label: "Powell's Books", icon: "book.fill", colorHex: "#FFD700"
        )
        context.insert(favTile)

        // Save everything
        do {
            try context.save()
        } catch {
            print("[SeedData] Failed to save: \(error)")
        }
    }

    static func hasDemoData(in context: ModelContext) -> Bool {
        let descriptor = FetchDescriptor<RevealedCell>()
        let count = (try? context.fetchCount(descriptor)) ?? 0
        return count > 100
    }

    // MARK: - Private

    private static func wipeAll(context: ModelContext) {
        try? context.delete(model: RevealedCell.self)
        try? context.delete(model: CellVisit.self)
        try? context.delete(model: DailySummary.self)
        try? context.delete(model: StraySession.self)
        try? context.delete(model: SpecialTile.self)
    }

    private static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

// MARK: - Deterministic RNG (so demo data is reproducible)

private class SeededRNG {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    private func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }

    func nextInt(min: Int, max: Int) -> Int {
        guard max > min else { return min }
        let range = UInt64(max - min + 1)
        return min + Int(next() % range)
    }

    func nextDouble(min: Double, max: Double) -> Double {
        let fraction = Double(next()) / Double(UInt64.max)
        return min + fraction * (max - min)
    }
}
