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

    // Track new cells and distance within current batch for daily summary updates
    private var pendingNewCells: Int = 0
    private var pendingDistance: Double = 0.0
    private var pendingSteps: Int = 0

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

    /// Detects the city for a grid cell using reverse geocoding with rate limiting and caching.
    func detectCity(for cell: GridCell, at coordinate: CLLocationCoordinate2D) {
        let bucketKey = geocodeBucketKey(for: coordinate)

        // Check cache first
        if let cached = cityCache[bucketKey] {
            setCityOnCell(cell, city: cached)
            return
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
    func saveStraySession(startedAt: Date, endedAt: Date, cellsRevealed: Int, distance: Double, duration: Double) {
        let session = StraySession()
        session.startedAt = startedAt
        session.endedAt = endedAt
        session.cellsRevealedCount = cellsRevealed
        session.distanceMeters = distance
        session.durationSeconds = duration
        context.insert(session)
        save()
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
        do {
            try context.save()
            lastPersistenceError = nil
        } catch {
            Self.logger.error("SwiftData save failed: \(error.localizedDescription, privacy: .public)")
            lastPersistenceError = error
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

    private func todayString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current
        // Fixed locale prevents user locale from altering the date format (e.g. calendar systems)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: Date())
    }

    /// ~500m buckets for caching city lookups. Adjacent cells in the same area share a geocode result.
    private func geocodeBucketKey(for coordinate: CLLocationCoordinate2D) -> String {
        let latBucket = Int(floor(coordinate.latitude * 200))
        let lngBucket = Int(floor(coordinate.longitude * 200))
        return "\(latBucket)_\(lngBucket)"
    }
}
