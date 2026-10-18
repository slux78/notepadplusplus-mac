import Foundation
import NppCore

public final class NppDocument: ObservableObject, Identifiable {
    public let id = UUID()

    @Published public var filePath: URL?
    @Published public var title: String
    @Published public var content: String
    @Published public var encoding: String
    @Published public var hasBOM: Bool
    @Published public var eolFormat: NppEol
    @Published public var isDirty: Bool = false
    @Published public var language: String = "Plain Text"

    @Published public var cursorLine: Int = 1
    @Published public var cursorCol: Int = 1
    @Published public var cursorPos: Int = 0
    @Published public var selectionLength: Int = 0

    // Raw bytes kept for lossless re-interpretation
    public var rawFileBytes: Data?

    public init(title: String = "new 1", content: String = "", encoding: String = "UTF-8", hasBOM: Bool = false, eol: NppEol = .crlf) {
        self.title = title
        self.content = content
        self.encoding = encoding
        self.hasBOM = hasBOM
        self.eolFormat = eol
        self.isDirty = false
    }

    public static func fromFile(url: URL) throws -> NppDocument {
        let data = try Data(contentsOf: url)
        let doc = NppDocument(title: url.lastPathComponent)
        doc.filePath = url
        doc.rawFileBytes = data

        // Detect encoding and EOL via NppCore C++ engine
        data.withUnsafeBytes { rawPtr in
            guard let ptr = rawPtr.baseAddress?.assumingMemoryBound(to: CChar.self) else { return }
            let det = npp_detect_encoding_and_eol(ptr, data.count)
            let charset = det.charsetName != nil ? String(cString: det.charsetName) : "UTF-8"
            doc.encoding = charset
            doc.hasBOM = det.hasBOM != 0
            doc.eolFormat = NppEol(rawValue: Int(det.eolFormat)) ?? .lf

            var decodedLen: Int32 = 0
            if let decodedPtr = npp_decode_to_utf8(ptr, data.count, charset, &decodedLen) {
                if let str = String(bytes: Data(bytes: decodedPtr, count: Int(decodedLen)), encoding: .utf8) {
                    doc.content = str
                } else {
                    doc.content = String(cString: decodedPtr)
                }
                npp_free_string(decodedPtr)
            } else {
                doc.content = String(decoding: data, as: UTF8.self)
            }
        }

        doc.language = detectLanguage(for: url)
        doc.isDirty = false
        return doc
    }

    public func save() -> Bool {
        guard let url = filePath else { return false }
        return save(to: url)
    }

    public func save(to url: URL) -> Bool {
        let utf8Bytes = Array(content.utf8)
        var outLen: Int = 0
        let addBomFlag: Int32 = hasBOM ? 1 : 0

        guard let encodedPtr = npp_encode_from_utf8(
            content,
            utf8Bytes.count,
            encoding,
            addBomFlag,
            &outLen
        ) else {
            return false
        }

        let data = Data(bytes: encodedPtr, count: outLen)
        npp_free_buffer(encodedPtr)

        do {
            try data.write(to: url, options: .atomic)
            self.filePath = url
            self.title = url.lastPathComponent
            self.rawFileBytes = data
            self.isDirty = false
            self.language = NppDocument.detectLanguage(for: url)
            return true
        } catch {
            print("Failed to save file: \(error)")
            return false
        }
    }

    public var encodingDisplayName: String {
        switch encoding {
        case "UTF-8":
            return hasBOM ? "UTF-8-BOM" : "UTF-8"
        case "CP949":
            return "Windows-949"
        case "EUC-KR":
            return "EUC-KR"
        case "WINDOWS-1252":
            return "ANSI"
        case "CP932":
            return "Shift-JIS"
        case "GB18030":
            return "GB2312"
        case "BIG5":
            return "Big5"
        case "UTF-16LE":
            return "UTF-16 LE"
        case "UTF-16BE":
            return "UTF-16 BE"
        default:
            return encoding
        }
    }

    public static func normalizeCharset(_ name: String) -> String {
        let upper = name.uppercased()
        if upper.contains("949") || upper == "EUC-KR" { return "CP949" }
        if upper.contains("932") || upper.contains("SHIFT") { return "CP932" }
        if upper.contains("18030") || upper.contains("2312") { return "GB18030" }
        if upper.contains("BIG5") { return "BIG5" }
        if upper.contains("1252") || upper == "ANSI" { return "WINDOWS-1252" }
        if upper.contains("16LE") { return "UTF-16LE" }
        if upper.contains("16BE") { return "UTF-16BE" }
        if upper.contains("UTF-8") || upper.contains("UTF8") { return "UTF-8" }
        return upper
    }

    // Notepad++: "Convert to UTF-8", "Convert to CP949", etc.
    public func convertEncoding(to targetCharset: String, addBOM: Bool = false) {
        objectWillChange.send()
        let norm = NppDocument.normalizeCharset(targetCharset)

        // In Notepad++, Convert to UTF-8 converts the document format to UTF-8 without altering visible characters.
        // If the document currently has mojibake (e.g. CP949 decoded as Latin1/Windows-1252),
        // we automatically repair the text so it displays clean Korean!
        if (norm == "UTF-8") && (self.encoding == "CP949" || self.encoding == "EUC-KR" || self.encoding == "WINDOWS-1252") {
            if let latinData = content.data(using: .windowsCP1252) ?? content.data(using: .isoLatin1) {
                latinData.withUnsafeBytes { rawPtr in
                    guard let ptr = rawPtr.baseAddress?.assumingMemoryBound(to: CChar.self) else { return }
                    var decodedLen: Int32 = 0
                    if let decodedPtr = npp_decode_to_utf8(ptr, latinData.count, "CP949", &decodedLen) {
                        if let repaired = String(bytes: Data(bytes: decodedPtr, count: Int(decodedLen)), encoding: .utf8), !repaired.isEmpty {
                            self.content = repaired
                        }
                        npp_free_string(decodedPtr)
                    }
                }
            }
        }

        self.encoding = norm
        self.hasBOM = addBOM
        self.isDirty = true
    }

    // Notepad++: "Encode in ANSI / CP949" (re-interpret raw bytes without changing byte payload)
    public func reencodeAs(targetCharset: String) {
        objectWillChange.send()
        let norm = NppDocument.normalizeCharset(targetCharset)

        var data: Data? = nil
        if let url = filePath, let diskData = try? Data(contentsOf: url) {
            data = diskData
            self.rawFileBytes = diskData
        } else if let cached = rawFileBytes {
            data = cached
        } else {
            // For in-memory documents, re-encode current content to raw bytes using old encoding
            let oldEnc = self.encoding
            let utf8Bytes = Array(content.utf8)
            var outLen: Int = 0
            if let ptr = npp_encode_from_utf8(content, utf8Bytes.count, oldEnc, 0, &outLen) {
                data = Data(bytes: ptr, count: outLen)
                npp_free_buffer(ptr)
            }
        }

        if let raw = data {
            raw.withUnsafeBytes { rawPtr in
                guard let ptr = rawPtr.baseAddress?.assumingMemoryBound(to: CChar.self) else { return }
                var decodedLen: Int32 = 0
                if norm == "UTF-8" {
                    // Safe UTF-8 decoding with replacement characters for invalid bytes (Notepad++ / Scintilla behavior)
                    self.content = String(decoding: raw, as: UTF8.self)
                } else if let decodedPtr = npp_decode_to_utf8(ptr, raw.count, norm, &decodedLen) {
                    let decodedData = Data(bytes: decodedPtr, count: Int(decodedLen))
                    if let str = String(bytes: decodedData, encoding: .utf8) {
                        self.content = str
                    } else {
                        self.content = String(decoding: decodedData, as: UTF8.self)
                    }
                    npp_free_string(decodedPtr)
                } else {
                    self.content = String(decoding: raw, as: UTF8.self)
                }
            }
        }

        self.encoding = norm
        self.hasBOM = (norm == "UTF-8" && self.hasBOM)
        self.isDirty = true
    }

    // Notepad++: EOL Conversion (Windows CRLF <-> Unix LF <-> Mac CR)
    public func convertEOL(to targetEol: NppEol) {
        guard targetEol != self.eolFormat else { return }
        objectWillChange.send()
        let utf8Bytes = Array(content.utf8)
        var outLen: Int = 0
        if let convertedPtr = npp_convert_eol(content, utf8Bytes.count, Int32(targetEol.rawValue), &outLen) {
            if let str = String(bytes: Data(bytes: convertedPtr, count: outLen), encoding: .utf8) {
                self.content = str
            } else {
                self.content = String(decoding: Data(bytes: convertedPtr, count: outLen), as: UTF8.self)
            }
            npp_free_string(convertedPtr)
        }
        self.eolFormat = targetEol
        self.isDirty = true
    }

    public static func detectLanguage(for url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "c", "h": return "C"
        case "cpp", "cxx", "cc", "hpp", "hxx": return "C++"
        case "swift": return "Swift"
        case "py", "pyw": return "Python"
        case "js", "mjs", "cjs": return "JavaScript"
        case "ts", "tsx": return "TypeScript"
        case "html", "htm": return "HTML"
        case "css", "scss", "sass": return "CSS"
        case "json": return "JSON"
        case "xml", "plist": return "XML"
        case "sql": return "SQL"
        case "sh", "bash", "zsh": return "Shell"
        case "md", "markdown": return "Markdown"
        case "java": return "Java"
        case "rs": return "Rust"
        case "go": return "Go"
        case "cs": return "C#"
        case "rb": return "Ruby"
        case "php": return "PHP"
        default: return "Plain Text"
        }
    }
}
