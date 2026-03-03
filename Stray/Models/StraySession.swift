import Foundation
import SwiftData

@Model
final class StraySession {
    var startedAt: Date = Date()
    var endedAt: Date? = nil
    var cellsRevealedCount: Int = 0
    var distanceMeters: Double = 0.0
    var durationSeconds: Double = 0.0
    var pathData: Data? = nil

    init() {
        self.startedAt = Date()
    }
}
