import Foundation

/// Completion words from the active buffer and the upstream per-language API files.
public final class NppCompletionEngine {
    public static let shared = NppCompletionEngine()

    private struct LanguageAPI {
        var words: [String]
        var ignoreCase: Bool
        var hints: [String: String]
    }

    private var cache: [String: LanguageAPI] = [:]
    private let wordRegex = try! NSRegularExpression(pattern: #"[\p{L}\p{N}_]{2,}"#)

    private init() {}

    public static func wordRange(in text: NSString, before caret: Int) -> NSRange {
        var start = min(max(0, caret), text.length)
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))
        while start > 0, let scalar = UnicodeScalar(text.character(at: start - 1)),
              allowed.contains(scalar) {
            start -= 1
        }
        return NSRange(location: start, length: min(max(0, caret), text.length) - start)
    }

    public func candidates(
        text: String,
        caret: Int,
        language: String,
        mode: Int,
        minimumLength: Int,
        ignoreNumbers: Bool,
        manual: Bool
    ) -> [String] {
        let source = text as NSString
        let range = Self.wordRange(in: source, before: caret)
        guard range.length > 0, manual || range.length >= max(1, minimumLength) else { return [] }
        let prefix = source.substring(with: range)
        if !manual && ignoreNumbers && prefix.first?.isNumber == true { return [] }

        var found = Set<String>()
        if mode == 0 || mode == 2 {
            let api = languageAPI(for: language)
            for word in api.words {
                let matches = api.ignoreCase
                    ? word.lowercased().hasPrefix(prefix.lowercased())
                    : word.hasPrefix(prefix)
                if matches && word != prefix { found.insert(word) }
            }
        }
        if mode == 1 || mode == 2 {
            let fullRange = NSRange(location: 0, length: source.length)
            for match in wordRegex.matches(in: text, range: fullRange) {
                let word = source.substring(with: match.range)
                if word.hasPrefix(prefix) && word != prefix { found.insert(word) }
            }
        }
        return found.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    public func parameterHint(for functionName: String, language: String) -> String? {
        languageAPI(for: language).hints[functionName]
    }

    public func parameterHint(in text: String, caret: Int, language: String) -> String? {
        let source = text as NSString
        var position = min(max(0, caret), source.length)
        var nested = 0
        while position > 0 {
            position -= 1
            let character = source.character(at: position)
            if character == 41 { nested += 1; continue } // )
            guard character == 40 else { continue } // (
            if nested > 0 { nested -= 1; continue }
            let nameRange = Self.wordRange(in: source, before: position)
            guard nameRange.length > 0 else { return nil }
            return parameterHint(for: source.substring(with: nameRange), language: language)
        }
        return nil
    }

    /// Path completion is manual and uses the document directory for relative paths.
    public func pathCandidates(text: String, caret: Int, documentURL: URL?) -> [String] {
        let source = text as NSString
        let position = min(max(0, caret), source.length)
        let before = source.substring(to: position)
        guard let slash = before.lastIndex(of: "/") else { return [] }
        let prefixStart = before[..<slash].lastIndex(where: { $0.isWhitespace || $0 == "\"" || $0 == "'" })
        let pathStart = prefixStart.map { before.index(after: $0) } ?? before.startIndex
        let directoryPart = String(before[pathStart...slash])
        let namePrefix = String(before[before.index(after: slash)...])
        let directoryURL: URL
        if directoryPart.hasPrefix("/") {
            directoryURL = URL(fileURLWithPath: directoryPart, isDirectory: true)
        } else if directoryPart.hasPrefix("~/") {
            directoryURL = URL(fileURLWithPath: (directoryPart as NSString).expandingTildeInPath, isDirectory: true)
        } else {
            let base = documentURL?.deletingLastPathComponent()
                ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
            directoryURL = base.appendingPathComponent(directoryPart, isDirectory: true)
        }
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: directoryURL, includingPropertiesForKeys: [.isDirectoryKey], options: []
        ) else { return [] }
        return entries.compactMap { entry in
            let name = entry.lastPathComponent
            guard name.hasPrefix(namePrefix), name != namePrefix else { return nil }
            let isDirectory = (try? entry.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            return name + (isDirectory ? "/" : "")
        }.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    public static func pathNameRange(in text: NSString, before caret: Int) -> NSRange {
        let position = min(max(0, caret), text.length)
        var start = position
        while start > 0 {
            let character = text.character(at: start - 1)
            if character == 47 || character == 10 || character == 13 { break }
            start -= 1
        }
        return NSRange(location: start, length: position - start)
    }

    private func languageAPI(for language: String) -> LanguageAPI {
        let key = language.lowercased()
        if let cached = cache[key] { return cached }
        let fileName: String
        switch key {
        case "c", "c / c++": fileName = "c"
        case "c++", "cpp": fileName = "cpp"
        case "c#": fileName = "cs"
        case "javascript", "javascript / typescript", "typescript": fileName = "javascript"
        case "html", "html / xml": fileName = "html"
        case "xml": fileName = "xml"
        case "shell", "shell / bash", "bash": fileName = "bash"
        default: fileName = key.replacingOccurrences(of: " ", with: "")
        }
        guard let url = Bundle.module.resourceURL?
            .appendingPathComponent("autoCompletion")
            .appendingPathComponent(fileName + ".xml"),
            let data = try? Data(contentsOf: url),
            let xml = try? XMLDocument(data: data),
            let autoComplete = xml.rootElement()?.elements(forName: "AutoComplete").first else {
            let empty = LanguageAPI(words: [], ignoreCase: false, hints: [:])
            cache[key] = empty
            return empty
        }
        let environment = autoComplete.elements(forName: "Environment").first
        let ignoreCase = environment?.attribute(forName: "ignoreCase")?.stringValue == "yes"
        var words: [String] = []
        var hints: [String: String] = [:]
        for keyword in autoComplete.elements(forName: "KeyWord") {
            guard let name = keyword.attribute(forName: "name")?.stringValue, !name.isEmpty else { continue }
            words.append(name)
            if let overload = keyword.elements(forName: "Overload").first {
                let parameters = overload.elements(forName: "Param").compactMap {
                    $0.attribute(forName: "name")?.stringValue
                }
                let description = overload.attribute(forName: "descr")?.stringValue ?? ""
                let signature = name + "(" + parameters.joined(separator: ", ") + ")"
                hints[name] = description.isEmpty ? signature : signature + " — " + description
            }
        }
        let result = LanguageAPI(words: words, ignoreCase: ignoreCase, hints: hints)
        cache[key] = result
        return result
    }
}
