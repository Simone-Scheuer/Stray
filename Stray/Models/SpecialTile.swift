import Foundation
import SwiftData

@Model
final class SpecialTile {
    var cellKey: String = ""
    var latIndex: Int = 0
    var lngIndex: Int = 0
    var label: String = ""
    var icon: String = "star.fill"
    var colorHex: String = "#FFD700"
    var createdAt: Date = Date()

    init(cellKey: String, latIndex: Int, lngIndex: Int, label: String, icon: String, colorHex: String) {
        self.cellKey = cellKey
        self.latIndex = latIndex
        self.lngIndex = lngIndex
        self.label = label
        self.icon = icon
        self.colorHex = colorHex
        self.createdAt = Date()
    }
}
