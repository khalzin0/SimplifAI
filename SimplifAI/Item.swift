import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    var sourceName: String
    var notesText: String
    var summaryText: String

    init(timestamp: Date = .now, sourceName: String, notesText: String, summaryText: String) {
        self.timestamp = timestamp
        self.sourceName = sourceName
        self.notesText = notesText
        self.summaryText = summaryText
    }
}
