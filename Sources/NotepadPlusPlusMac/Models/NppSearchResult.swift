import Foundation

public struct NppSearchMatch: Identifiable, Hashable {
    public let id = UUID()
    public let documentId: UUID
    public let documentTitle: String
    public let filePath: URL?
    public let lineNumber: Int
    public let lineContent: String
    public let matchRangeInLine: NSRange
    public let charPosition: Int
    public let matchLength: Int

    public init(documentId: UUID, documentTitle: String, filePath: URL?, lineNumber: Int, lineContent: String, matchRangeInLine: NSRange, charPosition: Int, matchLength: Int) {
        self.documentId = documentId
        self.documentTitle = documentTitle
        self.filePath = filePath
        self.lineNumber = lineNumber
        self.lineContent = lineContent
        self.matchRangeInLine = matchRangeInLine
        self.charPosition = charPosition
        self.matchLength = matchLength
    }
}

public struct NppSearchFileGroup: Identifiable {
    public let id = UUID()
    public let documentId: UUID
    public let documentTitle: String
    public let filePath: URL?
    public var matches: [NppSearchMatch]

    public init(documentId: UUID, documentTitle: String, filePath: URL?, matches: [NppSearchMatch]) {
        self.documentId = documentId
        self.documentTitle = documentTitle
        self.filePath = filePath
        self.matches = matches
    }
}
