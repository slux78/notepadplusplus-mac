import Foundation
import AppKit

public final class NppWorkspace: ObservableObject {
    @Published public var documents: [NppDocument] = []
    @Published public var activeDocumentId: UUID?

    @Published public var fontSize: CGFloat = 13.0
    @Published public var isWordWrapEnabled: Bool = false
    @Published public var showInvisibleCharacters: Bool = false
    @Published public var showSearchBar: Bool = false

    // Notepad++ Find All Search Results State
    @Published public var searchFileGroups: [NppSearchFileGroup] = []
    @Published public var lastSearchQuery: String = ""
    @Published public var showSearchResultsPanel: Bool = false
    @Published public var targetJumpMatch: NppSearchMatch?

    private var newDocCounter: Int = 1

    public var activeDocument: NppDocument? {
        guard let id = activeDocumentId else { return nil }
        return documents.first(where: { $0.id == id })
    }

    public var totalSearchHits: Int {
        searchFileGroups.reduce(0) { $0 + $1.matches.count }
    }

    public init() {
        newDocument()
    }

    public func newDocument() {
        let title = "new \(newDocCounter)"
        newDocCounter += 1
        let doc = NppDocument(title: title, content: "", encoding: "UTF-8", hasBOM: false, eol: .crlf)
        documents.append(doc)
        activeDocumentId = doc.id
    }

    public func openFile(url: URL) {
        // If already open, just switch to it
        if let existing = documents.first(where: { $0.filePath == url }) {
            activeDocumentId = existing.id
            return
        }

        do {
            let doc = try NppDocument.fromFile(url: url)
            // If only single untitled document is open and empty, replace it
            if documents.count == 1 && documents[0].filePath == nil && documents[0].content.isEmpty && !documents[0].isDirty {
                documents = [doc]
            } else {
                documents.append(doc)
            }
            activeDocumentId = doc.id
        } catch {
            print("Failed to open file: \(error)")
        }
    }

    public func closeDocument(id: UUID) {
        guard let index = documents.firstIndex(where: { $0.id == id }) else { return }
        documents.remove(at: index)

        if documents.isEmpty {
            newDocument()
        } else if activeDocumentId == id {
            let nextIndex = min(index, documents.count - 1)
            activeDocumentId = documents[nextIndex].id
        }
    }

    public func closeAll() {
        documents.removeAll()
        newDocCounter = 1
        newDocument()
    }

    // Notepad++ Tab Context Menu: Close Multiple Documents
    public func closeAllBut(id: UUID) {
        documents.removeAll(where: { $0.id != id })
        activeDocumentId = id
    }

    public func closeAllToLeft(of id: UUID) {
        guard let index = documents.firstIndex(where: { $0.id == id }) else { return }
        documents.removeSubrange(0..<index)
        activeDocumentId = id
    }

    public func closeAllToRight(of id: UUID) {
        guard let index = documents.firstIndex(where: { $0.id == id }) else { return }
        if index + 1 < documents.count {
            documents.removeSubrange((index + 1)..<documents.count)
        }
        activeDocumentId = id
    }

    public func closeAllUnchanged() {
        let dirtyDocs = documents.filter { $0.isDirty }
        if dirtyDocs.isEmpty {
            newDocument()
            documents = [documents.last!]
        } else {
            documents = dirtyDocs
            activeDocumentId = documents.first?.id
        }
    }

    public func reloadFromDisk(for doc: NppDocument) {
        guard let url = doc.filePath else { return }
        do {
            let reloaded = try NppDocument.fromFile(url: url)
            doc.content = reloaded.content
            doc.encoding = reloaded.encoding
            doc.hasBOM = reloaded.hasBOM
            doc.eolFormat = reloaded.eolFormat
            doc.rawFileBytes = reloaded.rawFileBytes
            doc.isDirty = false
        } catch {
            print("Failed to reload file: \(error)")
        }
    }

    // MARK: - Notepad++ Find All Operations
    public func findAllInCurrentDoc(query: String, matchCase: Bool, wholeWord: Bool, useRegex: Bool) {
        guard let doc = activeDocument, !query.isEmpty else { return }
        lastSearchQuery = query
        let matches = searchInDocument(doc: doc, query: query, matchCase: matchCase, wholeWord: wholeWord, useRegex: useRegex)
        if !matches.isEmpty {
            searchFileGroups = [NppSearchFileGroup(documentId: doc.id, documentTitle: doc.title, filePath: doc.filePath, matches: matches)]
        } else {
            searchFileGroups = []
        }
        showSearchResultsPanel = true
    }

    public func findAllInAllOpenedDocs(query: String, matchCase: Bool, wholeWord: Bool, useRegex: Bool) {
        guard !query.isEmpty else { return }
        lastSearchQuery = query
        var groups: [NppSearchFileGroup] = []
        for doc in documents {
            let matches = searchInDocument(doc: doc, query: query, matchCase: matchCase, wholeWord: wholeWord, useRegex: useRegex)
            if !matches.isEmpty {
                groups.append(NppSearchFileGroup(documentId: doc.id, documentTitle: doc.title, filePath: doc.filePath, matches: matches))
            }
        }
        searchFileGroups = groups
        showSearchResultsPanel = true
    }

    private func searchInDocument(doc: NppDocument, query: String, matchCase: Bool, wholeWord: Bool, useRegex: Bool) -> [NppSearchMatch] {
        let content = doc.content as NSString
        guard content.length > 0 else { return [] }

        var pattern = query
        if !useRegex {
            pattern = NSRegularExpression.escapedPattern(for: query)
        }
        if wholeWord {
            pattern = "\\b" + pattern + "\\b"
        }

        var regexOptions: NSRegularExpression.Options = []
        if !matchCase {
            regexOptions.insert(.caseInsensitive)
        }

        guard let regex = try? NSRegularExpression(pattern: pattern, options: regexOptions) else { return [] }
        let rawMatches = regex.matches(in: doc.content, options: [], range: NSRange(location: 0, length: content.length))

        var results: [NppSearchMatch] = []
        for m in rawMatches {
            let lineRange = content.lineRange(for: NSRange(location: m.range.location, length: 0))
            let lineText = content.substring(with: lineRange).trimmingCharacters(in: .newlines)

            // Compute line number
            var lineNum = 1
            content.enumerateSubstrings(in: NSRange(location: 0, length: m.range.location), options: [.byLines, .substringNotRequired]) { _, _, _, _ in
                lineNum += 1
            }

            let matchRangeInLine = NSRange(location: m.range.location - lineRange.location, length: m.range.length)

            let match = NppSearchMatch(
                documentId: doc.id,
                documentTitle: doc.title,
                filePath: doc.filePath,
                lineNumber: lineNum,
                lineContent: lineText,
                matchRangeInLine: matchRangeInLine,
                charPosition: m.range.location,
                matchLength: m.range.length
            )
            results.append(match)
        }
        return results
    }

    public func jumpToMatch(_ match: NppSearchMatch) {
        activeDocumentId = match.documentId
        targetJumpMatch = match

        if let doc = activeDocument {
            doc.cursorPos = match.charPosition
            doc.selectionLength = match.matchLength
            doc.cursorLine = match.lineNumber
        }
    }

    public func clearSearchResults() {
        searchFileGroups.removeAll()
        showSearchResultsPanel = false
    }

    public func saveActive() {
        guard let doc = activeDocument else { return }
        if doc.filePath != nil {
            _ = doc.save()
        } else {
            promptSaveAs(for: doc)
        }
    }

    public func saveAll() {
        for doc in documents where doc.isDirty {
            if doc.filePath != nil {
                _ = doc.save()
            } else {
                promptSaveAs(for: doc)
            }
        }
    }

    public func promptSaveAs(for doc: NppDocument) {
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = doc.filePath?.lastPathComponent ?? doc.title
        panel.begin { response in
            if response == .OK, let url = panel.url {
                _ = doc.save(to: url)
            }
        }
    }

    public func promptOpenFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.begin { [weak self] response in
            if response == .OK {
                for url in panel.urls {
                    self?.openFile(url: url)
                }
            }
        }
    }

    @Published public var isOverwriteMode: Bool = false
    @Published public var isMacroRecording: Bool = false
    public var recordedMacroActions: [String] = []

    public func zoomIn() {
        fontSize = min(fontSize + 1.0, 36.0)
    }

    public func zoomOut() {
        fontSize = max(fontSize - 1.0, 8.0)
    }

    public func resetZoom() {
        fontSize = 13.0
    }

    // MARK: - Tab Navigation & Sorting (Window Menu)
    public func nextTab() {
        guard documents.count > 1, let currentId = activeDocumentId,
              let currentIndex = documents.firstIndex(where: { $0.id == currentId }) else { return }
        let nextIndex = (currentIndex + 1) % documents.count
        activeDocumentId = documents[nextIndex].id
    }

    public func prevTab() {
        guard documents.count > 1, let currentId = activeDocumentId,
              let currentIndex = documents.firstIndex(where: { $0.id == currentId }) else { return }
        let prevIndex = (currentIndex - 1 + documents.count) % documents.count
        activeDocumentId = documents[prevIndex].id
    }

    public func selectTab(at index: Int) {
        guard index >= 0 && index < documents.count else { return }
        activeDocumentId = documents[index].id
    }

    public func moveTabForward() {
        guard let currentId = activeDocumentId,
              let index = documents.firstIndex(where: { $0.id == currentId }),
              index + 1 < documents.count else { return }
        documents.swapAt(index, index + 1)
    }

    public func moveTabBackward() {
        guard let currentId = activeDocumentId,
              let index = documents.firstIndex(where: { $0.id == currentId }),
              index > 0 else { return }
        documents.swapAt(index, index - 1)
    }

    public func sortTabsByName(ascending: Bool) {
        documents.sort {
            ascending ? $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
                      : $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedDescending
        }
    }

    public func sortTabsByPath(ascending: Bool) {
        documents.sort {
            let p1 = $0.filePath?.path ?? $0.title
            let p2 = $1.filePath?.path ?? $1.title
            return ascending ? p1.localizedCaseInsensitiveCompare(p2) == .orderedAscending
                             : p1.localizedCaseInsensitiveCompare(p2) == .orderedDescending
        }
    }

    public func sortTabsBySize(ascending: Bool) {
        documents.sort {
            ascending ? $0.content.count < $1.content.count : $0.content.count > $1.content.count
        }
    }
}
