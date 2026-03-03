import Foundation
import SwiftData

@Model
final class DailySummary {
    var dateString: String = ""
    var cellsRevealed: Int = 0
    var distanceMeters: Double = 0.0
    var stepCount: Int = 0
    var isActiveDay: Bool = false

    init(dateString: String) {
        self.dateString = dateString
    }
}
