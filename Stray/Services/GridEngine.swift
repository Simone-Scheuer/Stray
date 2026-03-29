import Foundation
import CoreLocation
import MapKit
import SwiftData
import os

enum RevealResult: Equatable {
    case newCell(GridCell)
    case revisited
    case cooldownActive
}

@Observable
final class GridEngine {
    private static let logger = Logger(subsystem: "com.stray.app", category: "grid")

    var lastLoadError: String?
    private(set) var revealedCells: [GridCell: Int] = [:]
    private(set) var lastVisitTimes: [GridCell: Date] = [:]
    private(set) var specialTiles: [GridCell: SpecialTile] = [:]
    private(set) var timelineCells: [GridCell: Int]? = nil
    private(set) var photoCells: [GridCell: Int]? = nil
    private(set) var heatCells: Bool = false
    private(set) var photoDotsData: [GridCell: Int]? = nil
    private(set) var dayHighlightCells: Set<GridCell>? = nil
    private(set) var dayNewCells: Set<GridCell>? = nil
    private(set) var compassTarget: GridCell? = nil
    private(set) var inspectedCell: GridCell? = nil
    private(set) var recentlyRevealedCells: [GridCell: Date] = [:]
    private var spatialIndex: [SpatialBucket: [GridCell]] = [:]

    /// Incremented only when tiles actually need re-rendering (throttled).
    private(set) var renderGeneration: Int = 0

    private var isDirty: Bool = false
    private var reloadThrottleTask: Task<Void, Never>?

    struct SpatialBucket: Hashable {
        let latDegree: Int
        let lngDegree: Int
    }

    func isRevealed(_ cell: GridCell) -> Bool {
        revealedCells[cell] != nil
    }

    func visitCount(for cell: GridCell) -> Int {
        revealedCells[cell] ?? 0
    }

    func revealCell(at coordinate: CLLocationCoordinate2D) -> RevealResult {
        let cell = GridCell.from(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let now = Date()

        if revealedCells[cell] == nil {
            revealedCells[cell] = 1
            lastVisitTimes[cell] = now
            addToSpatialIndex(cell)
            recentlyRevealedCells[cell] = now
            markDirty()
            scheduleClearingAnimation()
            return .newCell(cell)
        }

        if let lastVisit = lastVisitTimes[cell],
           now.timeIntervalSince(lastVisit) < Constants.visitCooldownSeconds {
            return .cooldownActive
        }

        let oldCount = revealedCells[cell] ?? 0
        revealedCells[cell, default: 0] += 1
        lastVisitTimes[cell] = now

        if heatTierChanged(from: oldCount, to: oldCount + 1) {
            markDirty()
        }

        return .revisited
    }

    func forceRender() {
        renderGeneration += 1
    }

    func pruneRecentlyRevealed() {
        let cutoff = Date().addingTimeInterval(-0.4)
        recentlyRevealedCells = recentlyRevealedCells.filter { $0.value > cutoff }
    }

    private var clearingAnimationTask: Task<Void, Never>?

    private func scheduleClearingAnimation() {
        guard clearingAnimationTask == nil else { return }
        clearingAnimationTask = Task { @MainActor [weak self] in
            // Trigger redraws at ~20fps for 300ms
            for _ in 0..<6 {
                try? await Task.sleep(for: .milliseconds(50))
                guard let self, !Task.isCancelled else { break }
                self.renderGeneration += 1
            }
            self?.pruneRecentlyRevealed()
            self?.clearingAnimationTask = nil
        }
    }

    /// Reveals a block of cells around a coordinate. Used on boot to establish the user's starting area.
    func revealBlock(around coordinate: CLLocationCoordinate2D, radius: Int = Constants.bootRevealRadius) {
        let centerCell = GridCell.from(latitude: coordinate.latitude, longitude: coordinate.longitude)
        var anyNew = false
        let now = Date()

        for dLat in -radius...radius {
            for dLng in -radius...radius {
                let cell = GridCell(latIndex: centerCell.latIndex + dLat, lngIndex: centerCell.lngIndex + dLng)
                if revealedCells[cell] == nil {
                    revealedCells[cell] = 1
                    lastVisitTimes[cell] = now
                    addToSpatialIndex(cell)
                    anyNew = true
                }
            }
        }

        if anyNew {
            renderGeneration += 1
        }
    }

    /// Returns cells with visit counts within the given region.
    /// In timeline mode uses a linear scan (spatial index is built from live cells, not the snapshot).
    /// In normal mode uses the spatial index for fast queries.
    func cellsWithCounts(in region: MKCoordinateRegion) -> [(GridCell, Int)] {
        let minLat = region.center.latitude - region.span.latitudeDelta / 2.0
        let maxLat = region.center.latitude + region.span.latitudeDelta / 2.0
        let minLng = region.center.longitude - region.span.longitudeDelta / 2.0
        let maxLng = region.center.longitude + region.span.longitudeDelta / 2.0

        if let photo = photoCells {
            return photo.compactMap { (cell, count) in
                let coord = cell.coordinate
                guard coord.latitude >= minLat && coord.latitude <= maxLat
                    && coord.longitude >= minLng && coord.longitude <= maxLng else { return nil }
                return (cell, count)
            }
        }

        if let timeline = timelineCells {
            return timeline.compactMap { (cell, count) in
                let coord = cell.coordinate
                guard coord.latitude >= minLat && coord.latitude <= maxLat
                    && coord.longitude >= minLng && coord.longitude <= maxLng else { return nil }
                return (cell, count)
            }
        }

        let minLatBucket = max(-90, Int(floor(minLat)))
        let maxLatBucket = min(90, Int(floor(maxLat)))
        let minLngBucket = max(-180, Int(floor(minLng)))
        let maxLngBucket = min(180, Int(floor(maxLng)))

        var result: [(GridCell, Int)] = []
        for latB in minLatBucket...maxLatBucket {
            for lngB in minLngBucket...maxLngBucket {
                guard let cells = spatialIndex[SpatialBucket(latDegree: latB, lngDegree: lngB)] else { continue }
                for cell in cells {
                    let coord = cell.coordinate
                    if coord.latitude >= minLat && coord.latitude <= maxLat
                        && coord.longitude >= minLng && coord.longitude <= maxLng {
                        if let count = revealedCells[cell] {
                            result.append((cell, count))
                        }
                    }
                }
            }
        }
        return result
    }

    func loadCells(from context: ModelContext) {
        let descriptor = FetchDescriptor<RevealedCell>()
        let cells: [RevealedCell]
        do {
            cells = try context.fetch(descriptor)
        } catch {
            Self.logger.error("Failed to load cells: \(error.localizedDescription, privacy: .public)")
            lastLoadError = "Failed to load cells: \(error.localizedDescription)"
            return
        }
        revealedCells.removeAll(keepingCapacity: true)
        lastVisitTimes.removeAll(keepingCapacity: true)
        spatialIndex.removeAll(keepingCapacity: true)
        for record in cells {
            let cell = GridCell(latIndex: record.latIndex, lngIndex: record.lngIndex)
            revealedCells[cell] = record.visitCount
            lastVisitTimes[cell] = record.lastVisitedAt
            addToSpatialIndex(cell)
        }
        renderGeneration += 1
    }

    // MARK: - Heat Mode

    func enterHeatMode() {
        heatCells = true
        renderGeneration += 1
    }

    func exitHeatMode() {
        heatCells = false
        renderGeneration += 1
    }

    // MARK: - Photo Mode

    func enterPhotoMode(cells: [GridCell: Int]) {
        photoCells = cells
        renderGeneration += 1
    }

    func exitPhotoMode() {
        photoCells = nil
        renderGeneration += 1
    }

    // MARK: - Photo Dots

    func updatePhotoDots(_ data: [GridCell: Int]) {
        photoDotsData = data
        renderGeneration += 1
    }

    func clearPhotoDots() {
        guard photoDotsData != nil else { return }
        photoDotsData = nil
        renderGeneration += 1
    }

    // MARK: - Timeline Mode

    func enterTimeline(cells: [GridCell: Int]) {
        timelineCells = cells
        renderGeneration += 1
    }

    func setDayHighlight(cells: Set<GridCell>, newCells: Set<GridCell>) {
        dayHighlightCells = cells
        dayNewCells = newCells
        renderGeneration += 1
    }

    func clearDayHighlight() {
        guard dayHighlightCells != nil else { return }
        dayHighlightCells = nil
        dayNewCells = nil
        renderGeneration += 1
    }

    func exitTimeline() {
        timelineCells = nil
        dayHighlightCells = nil
        dayNewCells = nil
        compassTarget = nil
        renderGeneration += 1
    }

    func setCompassTarget(_ cell: GridCell?) {
        compassTarget = cell
        renderGeneration += 1
    }

    func setInspectedCell(_ cell: GridCell?) {
        guard inspectedCell != cell else { return }
        inspectedCell = cell
        renderGeneration += 1
    }

    // MARK: - Special Tiles

    func loadSpecialTiles(from context: ModelContext) {
        let descriptor = FetchDescriptor<SpecialTile>()
        let tiles: [SpecialTile]
        do {
            tiles = try context.fetch(descriptor)
        } catch {
            Self.logger.error("Failed to load special tiles: \(error.localizedDescription, privacy: .public)")
            lastLoadError = "Failed to load special tiles: \(error.localizedDescription)"
            return
        }
        specialTiles.removeAll(keepingCapacity: true)
        for tile in tiles {
            let cell = GridCell(latIndex: tile.latIndex, lngIndex: tile.lngIndex)
            specialTiles[cell] = tile
        }
        renderGeneration += 1
    }

    func specialTile(for cell: GridCell) -> SpecialTile? {
        specialTiles[cell]
    }

    func setSpecialTile(_ tile: SpecialTile?, for cell: GridCell) {
        specialTiles[cell] = tile
        renderGeneration += 1
    }

    // MARK: - Throttled Reload

    private func markDirty() {
        guard !isDirty else { return }
        isDirty = true

        reloadThrottleTask?.cancel()
        reloadThrottleTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(Constants.tileReloadThrottleSeconds))
            guard !Task.isCancelled, let self else { return }
            self.isDirty = false
            self.renderGeneration += 1
        }
    }

    private func heatTierChanged(from oldCount: Int, to newCount: Int) -> Bool {
        func tier(_ count: Int) -> Int {
            switch count {
            case 0: return 0
            case 1: return 1
            case 2: return 2
            case 3...5: return 3
            case 6...20: return 4
            default: return 5
            }
        }
        return tier(oldCount) != tier(newCount)
    }

    // MARK: - Region Summaries (zoom-out pins)

    /// Returns region centroids with cell counts for zoom-out pins.
    /// Each entry represents a SpatialBucket (1° lat/lng) with at least 1 cell.
    func regionSummaries() -> [(coordinate: CLLocationCoordinate2D, cellCount: Int)] {
        let source = photoCells ?? timelineCells ?? revealedCells

        var bucketCounts: [SpatialBucket: Int] = [:]
        var bucketLatSum: [SpatialBucket: Double] = [:]
        var bucketLngSum: [SpatialBucket: Double] = [:]

        for (cell, _) in source {
            let bucket = bucketFor(cell)
            bucketCounts[bucket, default: 0] += 1
            let coord = cell.coordinate
            bucketLatSum[bucket, default: 0] += coord.latitude
            bucketLngSum[bucket, default: 0] += coord.longitude
        }

        return bucketCounts.compactMap { (bucket, count) in
            guard let latSum = bucketLatSum[bucket], let lngSum = bucketLngSum[bucket] else { return nil }
            let centroid = CLLocationCoordinate2D(
                latitude: latSum / Double(count),
                longitude: lngSum / Double(count)
            )
            return (coordinate: centroid, cellCount: count)
        }
    }

    // MARK: - Spatial Index

    private func bucketFor(_ cell: GridCell) -> SpatialBucket {
        let lat = Double(cell.latIndex) * GridCell.latStep
        let lng = Double(cell.lngIndex) * GridCell.lngStep(atLatitude: lat)
        return SpatialBucket(latDegree: Int(floor(lat)), lngDegree: Int(floor(lng)))
    }

    private func addToSpatialIndex(_ cell: GridCell) {
        let bucket = bucketFor(cell)
        spatialIndex[bucket, default: []].append(cell)
    }

    #if DEBUG
    func addTestCells() {
        let testLocations: [(Double, Double, Int)] = [
            (45.5205, -122.6785, 1), (45.5210, -122.6780, 1), (45.5200, -122.6790, 1),
            (45.5215, -122.6775, 3), (45.5220, -122.6770, 5), (45.5225, -122.6765, 2), (45.5230, -122.6760, 4),
            (45.5235, -122.6755, 15), (45.5240, -122.6750, 25), (45.5245, -122.6745, 12),
            (45.5250, -122.6740, 55), (45.5255, -122.6735, 100),
            (45.5190, -122.6800, 1), (45.5195, -122.6795, 8), (45.5260, -122.6730, 35),
            (45.5265, -122.6725, 2), (45.5180, -122.6810, 1), (45.5270, -122.6720, 50),
            (45.5275, -122.6715, 1), (45.5280, -122.6710, 7),
        ]
        for (lat, lng, count) in testLocations {
            let cell = GridCell.from(latitude: lat, longitude: lng)
            revealedCells[cell] = count
            addToSpatialIndex(cell)
        }
        renderGeneration += 1
    }
    #endif
}
