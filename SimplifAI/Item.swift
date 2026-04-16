import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    var title: String
    var sourceName: String
    var notesText: String
    var summaryText: String
    var studyPackData: String
    var importedFileData: Data?
    var importedFileExtension: String?

    init(
        timestamp: Date = .now,
        title: String,
        sourceName: String,
        notesText: String,
        summaryText: String,
        studyPackData: String = "",
        importedFileData: Data? = nil,
        importedFileExtension: String? = nil
    ) {
        self.timestamp = timestamp
        self.title = title
        self.sourceName = sourceName
        self.notesText = notesText
        self.summaryText = summaryText
        self.studyPackData = studyPackData
        self.importedFileData = importedFileData
        self.importedFileExtension = importedFileExtension
    }
}
