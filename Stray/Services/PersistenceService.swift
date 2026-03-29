import Foundation
import CoreLocation
import SwiftData
import os

@Observable
final class PersistenceService {
    private static let logger = Logger(subsystem: "com.stray.app", category: "persistence")

    private let context: ModelContext
    private let geocoder = CLGeocoder()

    /// Non-nil when the most recent save failed. Cleared on next successful save.
    var lastPersistenceError: Error?

    // Rate limiting for reverse geocoding
    private var geocodeRequestCount: Int = 0
    private var geocodeWindowStart: Date = Date()

    // Cache city names by coarse coordinate bucket (~500m)
    private var cityCache: [String: String] = [:]
    private var backfillTask: Task<Void, Never>?

    // Track new cells and distance within current batch for daily summary updates
    private var pendingNewCells: Int = 0
    private var pendingDistance: Double = 0.0
    private var pendingSteps: Int = 0

    private var lastSaveFailureTime: Date?

    init(context: ModelContext) {
        self.context = context
    }

    /// Saves or updates a revealed cell. Returns true if the cell is newly created.
    func saveOrUpdateCell(_ cell: GridCell, at coordinate: CLLocationCoordinate2D) -> Bool {
        let key = cell.key
        let descriptor = FetchDescriptor<RevealedCell>(
            predicate: #Predicate<RevealedCell> { $0.cellKey == key }
        )

        do {
            if let existing = try context.fetch(descriptor).first {
                existing.visitCount += 1
                existing.lastVisitedAt = Date()
                return false
            }
        } catch {
            Self.logger.error("Failed to fetch cell \(key, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }

        let record = RevealedCell(
            latIndex: cell.latIndex,
            lngIndex: cell.lngIndex,
            cellKey: key
        )
        context.insert(record)
        return true
    }

    /// Updates today's daily summary with new exploration data.
    func updateDailySummary(newCells: Int, distance: Double, steps: Int) {
        let today = todayString()
        let descriptor = FetchDescriptor<DailySummary>(
            predicate: #Predicate<DailySummary> { $0.dateString == today }
        )

        let summary: DailySummary
        do {
            if let existing = try context.fetch(descriptor).first {
                summary = existing
            } else {
                summary = DailySummary(dateString: today)
                context.insert(summary)
            }
        } catch {
            Self.logger.error("Failed to fetch daily summary for \(today, privacy: .public): \(error.localizedDescription, privacy: .public)")
            summary = DailySummary(dateString: today)
            context.insert(summary)
        }

        summary.cellsRevealed += newCells
        summary.distanceMeters += distance
        summary.stepCount += steps
        summary.isActiveDay = true
    }

    /// One-time fixup: sets isActiveDay on existing DailySummary records that have exploration activity
    /// but were created before the isActiveDay bug was fixed.
    func fixupDailySummaryActiveFlags() {
        let descriptor = FetchDescriptor<DailySummary>(
            predicate: #Predicate<DailySummary> { $0.cellsRevealed > 0 && $0.isActiveDay == false }
        )
        let summaries: [DailySummary]
        do {
            summaries = try context.fetch(descriptor)
        } catch {
            Self.logger.error("Failed to fetch daily summaries for fixup: \(error.localizedDescription, privacy: .public)")
            return
        }
        for summary in summaries {
            summary.isActiveDay = true
        }
        if !summaries.isEmpty {
            save()
        }
    }

    /// Logs a cell visit for the daily journey replay. Creates one CellVisit per cell per day.
    func logCellVisit(cellKey: String, date: Date = Date()) {
        let day = todayString(for: date)
        let descriptor = FetchDescriptor<CellVisit>(
            predicate: #Predicate<CellVisit> { $0.cellKey == cellKey && $0.dateString == day }
        )
        do {
            if try context.fetch(descriptor).first != nil { return }
        } catch {
            Self.logger.error("Failed to check CellVisit for \(cellKey, privacy: .public) on \(day, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
        let visit = CellVisit(cellKey: cellKey, dateString: day)
        context.insert(visit)
    }

    /// Fetches all CellVisit records for a given date string (e.g. "2026-03-28").
    func fetchCellVisits(for dateString: String) -> [CellVisit] {
        let descriptor = FetchDescriptor<CellVisit>(
            predicate: #Predicate<CellVisit> { $0.dateString == dateString }
        )
        do {
            return try context.fetch(descriptor)
        } catch {
            Self.logger.error("Failed to fetch cell visits for \(dateString, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    /// Deduplicates CellVisit records created by multi-device CloudKit sync.
    /// Keeps the earliest visitedAt per cellKey+dateString pair.
    func deduplicateCellVisits() {
        let descriptor = FetchDescriptor<CellVisit>()
        let all: [CellVisit]
        do {
            all = try context.fetch(descriptor)
        } catch {
            Self.logger.error("Failed to fetch cell visits for dedup: \(error.localizedDescription, privacy: .public)")
            return
        }

        var grouped: [String: [CellVisit]] = [:]
        for visit in all {
            let compositeKey = "\(visit.cellKey)_\(visit.dateString)"
            grouped[compositeKey, default: []].append(visit)
        }

        for (_, visits) in grouped where visits.count > 1 {
            let sorted = visits.sorted { $0.visitedAt < $1.visitedAt }
            for duplicate in sorted.dropFirst() {
                context.delete(duplicate)
            }
        }
        save()
    }

    /// Deduplicates RevealedCell records created by multi-device CloudKit sync.
    /// Keeps the earliest firstVisitedAt, sums visitCount, keeps latest lastVisitedAt, keeps first non-nil city.
    func deduplicateCells() {
        let descriptor = FetchDescriptor<RevealedCell>()
        let allCells: [RevealedCell]
        do {
            allCells = try context.fetch(descriptor)
        } catch {
            Self.logger.error("Failed to fetch cells for deduplication: \(error.localizedDescription, privacy: .public)")
            return
        }

        var grouped: [String: [RevealedCell]] = [:]
        for cell in allCells {
            grouped[cell.cellKey, default: []].append(cell)
        }

        for (_, cells) in grouped where cells.count > 1 {
            // Sort by firstVisitedAt so the first element is the canonical record
            let sorted = cells.sorted { $0.firstVisitedAt < $1.firstVisitedAt }
            guard let keeper = sorted.first else { continue }

            var totalVisits = keeper.visitCount
            var latestVisit = keeper.lastVisitedAt
            var city = keeper.city

            for duplicate in sorted.dropFirst() {
                totalVisits += duplicate.visitCount
                if duplicate.lastVisitedAt > latestVisit {
                    latestVisit = duplicate.lastVisitedAt
                }
                if city == nil { city = duplicate.city }
                context.delete(duplicate)
            }

            keeper.visitCount = totalVisits
            keeper.lastVisitedAt = latestVisit
            keeper.city = city
        }

        save()
    }

    /// Geocodes all cells that still have city == nil, in batches respecting the rate limit.
    func backfillMissingCities() {
        let descriptor = FetchDescriptor<RevealedCell>(
            predicate: #Predicate<RevealedCell> { $0.city == nil }
        )
        let cells: [RevealedCell]
        do {
            cells = try context.fetch(descriptor)
        } catch {
            Self.logger.error("Failed to fetch cells for city backfill: \(error.localizedDescription, privacy: .public)")
            return
        }
        guard !cells.isEmpty else { return }

        backfillTask?.cancel()
        backfillTask = Task {
            for record in cells {
                guard !Task.isCancelled else { break }
                let cell = GridCell(latIndex: record.latIndex, lngIndex: record.lngIndex)
                let coord = cell.centerCoordinate
                let bucketKey = geocodeBucketKey(for: coord)

                if let cached = await MainActor.run(body: { cityCache[bucketKey] }) {
                    await MainActor.run {
                        setCityOnCell(cell, city: cached)
                    }
                    continue
                }

                let location = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
                do {
                    let placemarks = try await geocoder.reverseGeocodeLocation(location)
                    if let city = placemarks.first?.locality {
                        await MainActor.run {
                            self.cityCache[bucketKey] = city
                            self.setCityOnCell(cell, city: city)
                        }
                    }
                } catch {
                    // Rate limited or network error — stop and retry next launch
                    Self.logger.info("City backfill paused: \(error.localizedDescription, privacy: .public)")
                    break
                }
                // ~1.5s between requests to stay well under Apple's rate limit
                try? await Task.sleep(for: .milliseconds(1500))
            }
            await MainActor.run { self.save() }
        }
    }

    /// Detects the city for a grid cell using reverse geocoding with rate limiting and caching.
    func detectCity(for cell: GridCell, at coordinate: CLLocationCoordinate2D) {
        let bucketKey = geocodeBucketKey(for: coordinate)

        // Check cache first
        if let cached = cityCache[bucketKey] {
            setCityOnCell(cell, city: cached)
            return
        }

        if cityCache.count > 500 {
            let keysToRemove = Array(cityCache.keys.prefix(cityCache.count / 2))
            for key in keysToRemove { cityCache.removeValue(forKey: key) }
        }

        // Rate limit check
        let now = Date()
        if now.timeIntervalSince(geocodeWindowStart) > 60.0 {
            geocodeRequestCount = 0
            geocodeWindowStart = now
        }
        guard geocodeRequestCount < Constants.geocodeRateLimitPerMinute else { return }
        geocodeRequestCount += 1

        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        Task {
            do {
                let placemarks = try await geocoder.reverseGeocodeLocation(location)
                if let city = placemarks.first?.locality {
                    await MainActor.run {
                        self.cityCache[bucketKey] = city
                        self.setCityOnCell(cell, city: city)
                        self.save()
                    }
                }
            } catch {
                // Geocoding failed — city stays nil, will be retried on next visit
            }
        }
    }

    /// Persists a completed Stray session
    func saveStraySession(startedAt: Date, endedAt: Date, cellsRevealed: Int, distance: Double, duration: Double, pausedDuration: Double = 0, pathData: Data? = nil, healthSteps: Int? = nil, healthDistance: Double? = nil) {
        let session = StraySession()
        session.startedAt = startedAt
        session.endedAt = endedAt
        session.cellsRevealedCount = cellsRevealed
        session.distanceMeters = distance
        session.durationSeconds = duration
        session.pausedDurationSeconds = pausedDuration
        session.pathData = pathData
        session.healthStepCount = healthSteps
        session.healthDistanceMeters = healthDistance
        context.insert(session)
        save()
    }

    // MARK: - Timeline

    /// Returns all cells first revealed on or before `date`, keyed by GridCell with their visit count.
    func fetchCellsUpTo(date: Date) -> [GridCell: Int] {
        guard let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: date) else {
            return [:]
        }
        let cutoff = Calendar.current.startOfDay(for: nextDay)
        let descriptor = FetchDescriptor<RevealedCell>(
            predicate: #Predicate<RevealedCell> { $0.firstVisitedAt < cutoff }
        )
        var result: [GridCell: Int] = [:]
        do {
            for record in try context.fetch(descriptor) {
                let cell = GridCell(latIndex: record.latIndex, lngIndex: record.lngIndex)
                result[cell] = record.visitCount
            }
        } catch {
            Self.logger.error("Failed to fetch cells for timeline: \(error.localizedDescription, privacy: .public)")
        }
        return result
    }

    /// Returns all days on which the user was active, sorted oldest-first.
    func fetchActiveDays() -> [DailySummary] {
        let descriptor = FetchDescriptor<DailySummary>(
            predicate: #Predicate<DailySummary> { $0.isActiveDay == true },
            sortBy: [SortDescriptor(\.dateString)]
        )
        do {
            return try context.fetch(descriptor)
        } catch {
            Self.logger.error("Failed to fetch active days: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    func fetchCell(key: String) -> RevealedCell? {
        let descriptor = FetchDescriptor<RevealedCell>(
            predicate: #Predicate<RevealedCell> { $0.cellKey == key }
        )
        do {
            return try context.fetch(descriptor).first
        } catch {
            Self.logger.error("Failed to fetch cell \(key, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    func updateCellNotes(_ cell: GridCell, notes: String) {
        let key = cell.key
        let descriptor = FetchDescriptor<RevealedCell>(
            predicate: #Predicate<RevealedCell> { $0.cellKey == key }
        )
        do {
            if let record = try context.fetch(descriptor).first {
                record.notes = notes
                save()
            }
        } catch {
            Self.logger.error("Failed to update notes for cell \(key, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Special Tiles

    func saveSpecialTile(for cell: GridCell, label: String, icon: String, colorHex: String) {
        let key = cell.key
        let descriptor = FetchDescriptor<SpecialTile>(
            predicate: #Predicate<SpecialTile> { $0.cellKey == key }
        )

        do {
            if let existing = try context.fetch(descriptor).first {
                existing.label = label
                existing.icon = icon
                existing.colorHex = colorHex
            } else {
                let tile = SpecialTile(
                    cellKey: key,
                    latIndex: cell.latIndex,
                    lngIndex: cell.lngIndex,
                    label: label,
                    icon: icon,
                    colorHex: colorHex
                )
                context.insert(tile)
            }
        } catch {
            Self.logger.error("Failed to fetch special tile \(key, privacy: .public): \(error.localizedDescription, privacy: .public)")
            let tile = SpecialTile(
                cellKey: key,
                latIndex: cell.latIndex,
                lngIndex: cell.lngIndex,
                label: label,
                icon: icon,
                colorHex: colorHex
            )
            context.insert(tile)
        }
        save()
    }

    func deleteSpecialTile(for cell: GridCell) {
        let key = cell.key
        let descriptor = FetchDescriptor<SpecialTile>(
            predicate: #Predicate<SpecialTile> { $0.cellKey == key }
        )
        do {
            for tile in try context.fetch(descriptor) {
                context.delete(tile)
            }
        } catch {
            Self.logger.error("Failed to delete special tile \(key, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
        save()
    }

    func fetchSpecialTile(for cell: GridCell) -> SpecialTile? {
        let key = cell.key
        let descriptor = FetchDescriptor<SpecialTile>(
            predicate: #Predicate<SpecialTile> { $0.cellKey == key }
        )
        do {
            return try context.fetch(descriptor).first
        } catch {
            Self.logger.error("Failed to fetch special tile \(key, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    func fetchAllSpecialTiles() -> [SpecialTile] {
        let descriptor = FetchDescriptor<SpecialTile>()
        do {
            return try context.fetch(descriptor)
        } catch {
            Self.logger.error("Failed to fetch all special tiles: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    func deduplicateDailySummaries() {
        let descriptor = FetchDescriptor<DailySummary>()
        let all: [DailySummary]
        do {
            all = try context.fetch(descriptor)
        } catch {
            Self.logger.error("Failed to fetch daily summaries for dedup: \(error.localizedDescription, privacy: .public)")
            return
        }

        var grouped: [String: [DailySummary]] = [:]
        for summary in all {
            grouped[summary.dateString, default: []].append(summary)
        }

        for (_, summaries) in grouped where summaries.count > 1 {
            // Keep the one with the most data, merge the rest
            let sorted = summaries.sorted { $0.cellsRevealed > $1.cellsRevealed }
            guard let keeper = sorted.first else { continue }

            for duplicate in sorted.dropFirst() {
                keeper.cellsRevealed = max(keeper.cellsRevealed, duplicate.cellsRevealed)
                keeper.distanceMeters = max(keeper.distanceMeters, duplicate.distanceMeters)
                keeper.stepCount = max(keeper.stepCount, duplicate.stepCount)
                keeper.isActiveDay = keeper.isActiveDay || duplicate.isActiveDay
                context.delete(duplicate)
            }
        }
        save()
    }

    func deduplicateSpecialTiles() {
        let allTiles = fetchAllSpecialTiles()
        var grouped: [String: [SpecialTile]] = [:]
        for tile in allTiles {
            grouped[tile.cellKey, default: []].append(tile)
        }
        for (_, tiles) in grouped where tiles.count > 1 {
            let sorted = tiles.sorted { $0.createdAt < $1.createdAt }
            for duplicate in sorted.dropFirst() {
                context.delete(duplicate)
            }
        }
        save()
    }

    func save() {
        if let failureTime = lastSaveFailureTime,
           Date().timeIntervalSince(failureTime) < 10.0 {
            return
        }
        do {
            try context.save()
            lastPersistenceError = nil
            lastSaveFailureTime = nil
        } catch {
            Self.logger.error("SwiftData save failed: \(error.localizedDescription, privacy: .public)")
            lastPersistenceError = error
            lastSaveFailureTime = Date()
        }
    }

    // MARK: - Private Helpers

    private func setCityOnCell(_ cell: GridCell, city: String) {
        let key = cell.key
        let descriptor = FetchDescriptor<RevealedCell>(
            predicate: #Predicate<RevealedCell> { $0.cellKey == key }
        )
        do {
            if let record = try context.fetch(descriptor).first, record.city == nil {
                record.city = city
            }
        } catch {
            Self.logger.error("Failed to fetch cell \(key, privacy: .public) for city update: \(error.localizedDescription, privacy: .public)")
        }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    private func todayString(for date: Date = Date()) -> String {
        Self.dateFormatter.string(from: date)
    }

    /// ~500m buckets for caching city lookups. Adjacent cells in the same area share a geocode result.
    private func geocodeBucketKey(for coordinate: CLLocationCoordinate2D) -> String {
        let latBucket = Int(floor(coordinate.latitude * 200))
        let lngBucket = Int(floor(coordinate.longitude * 200))
        return "\(latBucket)_\(lngBucket)"
    }
}
