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
    private(set) var dayHighlightCells: Set<GridCell>? = nil
    private(set) var dayNewCells: Set<GridCell>? = nil
    private(set) var todayVisitedCells: Set<GridCell> = []
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
            if recentlyRevealedCells.count > 50 { pruneRecentlyRevealed() }
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

    // MARK: - Today's Visited Cells

    func loadTodayCells(from context: ModelContext) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let todayString = formatter.string(from: Date())

        var descriptor = FetchDescriptor<CellVisit>(
            predicate: #Predicate { $0.dateString == todayString }
        )
        descriptor.propertiesToFetch = [\.cellKey]
        let visits = (try? context.fetch(descriptor)) ?? []

        todayVisitedCells.removeAll(keepingCapacity: true)
        for visit in visits {
            let parts = visit.cellKey.split(separator: "_")
            guard parts.count == 2,
                  let latIdx = Int(parts[0]),
                  let lngIdx = Int(parts[1]) else { continue }
            todayVisitedCells.insert(GridCell(latIndex: latIdx, lngIndex: lngIdx))
        }
    }

    func markCellVisitedToday(_ cell: GridCell) {
        guard !todayVisitedCells.contains(cell) else { return }
        todayVisitedCells.insert(cell)
        markDirty()
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

    // MARK: - LOD Aggregation

    /// LOD levels for multi-scale rendering.
    /// `block` (200m) dropped — visually indistinguishable from `base` per first-tester feedback.
    /// `street` (800m, 16x base) is the new first aggregation tier; visually distinct enough to
    /// signal a real LOD change. Subsequent tiers are 4x steps.
    enum LODLevel: Int, CaseIterable {
        case base = 1            // 50m
        case street = 16         // 800m
        case district = 64       // 3.2km
        case city = 256          // 12.8km
        case metro = 1024        // ~51km
        case region = 4096       // ~205km

        var subcellCount: Int { rawValue * rawValue }
        /// Degree step used for uniform lat/lng bucketing
        var latStep: Double { GridCell.latStep * Double(rawValue) }

        /// Thresholds pushed significantly outward from earlier defaults so the 50m
        /// spider-web persists through "whole-city" zoom. Tuned for first-tester intuition;
        /// further iteration in the simulator may refine these.
        static func level(for latitudeDelta: Double) -> LODLevel {
            switch latitudeDelta {
            case ..<0.30:  return .base
            case ..<1.5:   return .street
            case ..<5.0:   return .district
            case ..<15.0:  return .city
            case ..<30.0:  return .metro
            default:       return .region
            }
        }
    }

    /// An aggregated cell using uniform degree-based bucketing.
    /// Same degree step for lat and lng — avoids latitude-dependent lngStep drift.
    struct LODCell: Hashable {
        let latBucket: Int
        let lngBucket: Int
        let degreeStep: Double

        func hash(into hasher: inout Hasher) {
            hasher.combine(latBucket)
            hasher.combine(lngBucket)
        }

        static func == (lhs: LODCell, rhs: LODCell) -> Bool {
            lhs.latBucket == rhs.latBucket && lhs.lngBucket == rhs.lngBucket
        }

        var coordinate: CLLocationCoordinate2D {
            CLLocationCoordinate2D(
                latitude: Double(latBucket) * degreeStep,
                longitude: Double(lngBucket) * degreeStep
            )
        }

        var latStep: Double { degreeStep }
        func lngStep(atLatitude lat: Double) -> Double { degreeStep }
    }

    /// Returns aggregated cells for the given region at the specified LOD level.
    /// Each tuple is (lodCell, coverage 0.0–1.0, cellCount, valueSum).
    /// - cellCount: number of base cells revealed within this LOD region.
    /// - valueSum: sum of values (visit counts in default/heat mode, photo counts in photo mode).
    /// Coverage is independent of value: a fully-covered region with all 1-visit cells has
    /// coverage 1.0 but valueSum equal to cellCount, so heat coloring should average value/count.
    func aggregatedCells(in region: MKCoordinateRegion, level: LODLevel) -> [(LODCell, Double, Int, Int)] {
        let source = photoCells ?? timelineCells ?? revealedCells
        guard !source.isEmpty else { return [] }

        let degStep = level.latStep // uniform degree step
        let subcellArea = Double(level.subcellCount)

        var cellCounts: [LODCell: Int] = [:]
        var valueSums: [LODCell: Int] = [:]

        let minLat = region.center.latitude - region.span.latitudeDelta / 2.0
        let maxLat = region.center.latitude + region.span.latitudeDelta / 2.0
        let minLng = region.center.longitude - region.span.longitudeDelta / 2.0
        let maxLng = region.center.longitude + region.span.longitudeDelta / 2.0

        let minLatBucket = max(-90, Int(floor(minLat)))
        let maxLatBucket = min(90, Int(floor(maxLat)))
        let minLngBucket = max(-180, Int(floor(minLng)))
        let maxLngBucket = min(180, Int(floor(maxLng)))

        for latB in minLatBucket...maxLatBucket {
            for lngB in minLngBucket...maxLngBucket {
                let bucket = SpatialBucket(latDegree: latB, lngDegree: lngB)
                guard let cells = spatialIndex[bucket] else { continue }
                for cell in cells {
                    guard let value = source[cell] else { continue }
                    let coord = cell.coordinate
                    let lodLatB = Int(floor(coord.latitude / degStep))
                    let lodLngB = Int(floor(coord.longitude / degStep))
                    let lodCell = LODCell(latBucket: lodLatB, lngBucket: lodLngB, degreeStep: degStep)
                    cellCounts[lodCell, default: 0] += 1
                    valueSums[lodCell, default: 0] += value
                }
            }
        }

        let pad = degStep
        return cellCounts.compactMap { (lodCell, cellCount) in
            let coord = lodCell.coordinate
            guard coord.latitude >= minLat - pad && coord.latitude <= maxLat + pad
                && coord.longitude >= minLng - pad && coord.longitude <= maxLng + pad else {
                return nil
            }
            let coverage = min(1.0, Double(cellCount) / subcellArea)
            let valueSum = valueSums[lodCell] ?? 0
            return (lodCell, coverage, cellCount, valueSum)
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
