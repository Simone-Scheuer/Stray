import Foundation
import SwiftData

@Model
final class CellVisit {
    var cellKey: String = ""
    var dateString: String = ""
    var visitedAt: Date = Date()

    init(cellKey: String, dateString: String) {
        self.cellKey = cellKey
        self.dateString = dateString
        self.visitedAt = Date()
    }
}
