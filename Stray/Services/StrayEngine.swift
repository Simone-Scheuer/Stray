import Foundation
import CoreLocation

final class StrayEngine {
    private let gridEngine: GridEngine

    init(gridEngine: GridEngine) {
        self.gridEngine = gridEngine
    }

    struct ScoredCell {
        let cell: GridCell
        let weight: Double
    }

    /// Enumerate all cells within radius meters of center, scored by visit frequency
    func scoredCellsNearby(center: CLLocationCoordinate2D, radius: Double) -> [ScoredCell] {
        let latRange = radius / 111_320.0
        let lngRange = radius / (111_320.0 * cos(center.latitude * .pi / 180.0))

        let minLatIdx = Int(floor((center.latitude - latRange) / GridCell.latStep))
        let maxLatIdx = Int(floor((center.latitude + latRange) / GridCell.latStep))
        let minLngIdx = Int(floor((center.longitude - lngRange) / GridCell.lngStep(atLatitude: center.latitude)))
        let maxLngIdx = Int(floor((center.longitude + lngRange) / GridCell.lngStep(atLatitude: center.latitude)))

        var scored: [ScoredCell] = []
        for latIdx in minLatIdx...maxLatIdx {
            for lngIdx in minLngIdx...maxLngIdx {
                let cell = GridCell(latIndex: latIdx, lngIndex: lngIdx)
                let visits = gridEngine.visitCount(for: cell)
                let weight = Self.frequencyWeight(visits: visits)
                if weight > 0 {
                    scored.append(ScoredCell(cell: cell, weight: weight))
                }
            }
        }
        return scored
    }

    /// BFS flood-fill to find contiguous clusters of scored cells, sorted by total weight descending
    func findClusters(in scoredCells: [ScoredCell]) -> [[ScoredCell]] {
        var cellMap: [GridCell: ScoredCell] = [:]
        for sc in scoredCells { cellMap[sc.cell] = sc }

        var visited: Set<GridCell> = []
        var clusters: [[ScoredCell]] = []

        for sc in scoredCells {
            guard !visited.contains(sc.cell) else { continue }

            var cluster: [ScoredCell] = []
            var queue: [GridCell] = [sc.cell]
            visited.insert(sc.cell)

            while !queue.isEmpty {
                let current = queue.removeFirst()
                if let scored = cellMap[current] {
                    cluster.append(scored)
                }
                // 4-connected neighbors
                let neighbors = [
                    GridCell(latIndex: current.latIndex + 1, lngIndex: current.lngIndex),
                    GridCell(latIndex: current.latIndex - 1, lngIndex: current.lngIndex),
                    GridCell(latIndex: current.latIndex, lngIndex: current.lngIndex + 1),
                    GridCell(latIndex: current.latIndex, lngIndex: current.lngIndex - 1),
                ]
                for neighbor in neighbors {
                    if !visited.contains(neighbor), cellMap[neighbor] != nil {
                        visited.insert(neighbor)
                        queue.append(neighbor)
                    }
                }
            }
            if !cluster.isEmpty { clusters.append(cluster) }
        }

        return clusters.sorted { c1, c2 in
            c1.reduce(0) { $0 + $1.weight } > c2.reduce(0) { $0 + $1.weight }
        }
    }

    /// Bearing from user to the weight-adjusted centroid of a cluster
    func bearingToCluster(from center: CLLocationCoordinate2D, cluster: [ScoredCell]) -> Double {
        let totalWeight = cluster.reduce(0.0) { $0 + $1.weight }
        guard totalWeight > 0 else { return 0 }

        var weightedLat = 0.0
        var weightedLng = 0.0
        for sc in cluster {
            let coord = sc.cell.centerCoordinate
            weightedLat += coord.latitude * sc.weight
            weightedLng += coord.longitude * sc.weight
        }
        let centroid = CLLocationCoordinate2D(
            latitude: weightedLat / totalWeight,
            longitude: weightedLng / totalWeight
        )
        return center.bearing(to: centroid)
    }

    /// Full calculation: returns bearing toward a specific target cell and whether a target was found
    func calculateBearing(from center: CLLocationCoordinate2D)
        -> (bearing: Double, hasTarget: Bool, targetCell: GridCell?) {
        let scored = scoredCellsNearby(center: center, radius: Constants.searchRadiusMeters)
        guard !scored.isEmpty else { return (0, false, nil) }

        let clusters = findClusters(in: scored)
        guard let bestCluster = clusters.first else { return (0, false, nil) }

        // Pick the nearest truly undiscovered (0-visit) cell in the cluster.
        // Fall back to the nearest low-visit cell only if no unvisited cells exist.
        let userLoc = CLLocation(latitude: center.latitude, longitude: center.longitude)
        func nearest(in pool: [ScoredCell]) -> GridCell? {
            pool.min(by: { a, b in
                let ac = a.cell.centerCoordinate
                let bc = b.cell.centerCoordinate
                return CLLocation(latitude: ac.latitude, longitude: ac.longitude).distance(from: userLoc)
                     < CLLocation(latitude: bc.latitude, longitude: bc.longitude).distance(from: userLoc)
            })?.cell
        }
        let unvisited = bestCluster.filter { gridEngine.visitCount(for: $0.cell) == 0 }
        let targetCell = nearest(in: unvisited.isEmpty ? bestCluster : unvisited)

        let bearing: Double
        if let target = targetCell {
            bearing = center.bearing(to: target.centerCoordinate)
        } else {
            bearing = bearingToCluster(from: center, cluster: bestCluster)
        }
        return (bearing, true, targetCell)
    }

    /// Unvisited cells get full weight, rarely visited get partial, frequently visited get none
    static func frequencyWeight(visits: Int) -> Double {
        switch visits {
        case 0: return 1.0
        case 1...2: return 0.7
        case 3...5: return 0.3
        default: return 0.0
        }
    }
}
