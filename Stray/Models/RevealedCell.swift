import Foundation
import SwiftData

@Model
final class RevealedCell {
    var latIndex: Int = 0
    var lngIndex: Int = 0
    var cellKey: String = ""
    var firstVisitedAt: Date = Date()
    var lastVisitedAt: Date = Date()
    var visitCount: Int = 1
    var city: String? = nil
    var notes: String = ""

    init(latIndex: Int, lngIndex: Int, cellKey: String, city: String? = nil) {
        self.latIndex = latIndex
        self.lngIndex = lngIndex
        self.cellKey = cellKey
        self.firstVisitedAt = Date()
        self.lastVisitedAt = Date()
        self.visitCount = 1
        self.city = city
    }
}
