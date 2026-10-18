import Foundation
import NppCore

public enum NppEol: Int, CaseIterable, Identifiable {
    case crlf = 0
    case lf = 1
    case cr = 2

    public var id: Int { self.rawValue }

    public var displayName: String {
        switch self {
        case .crlf: return "Windows (CR LF)"
        case .lf: return "Unix (LF)"
        case .cr: return "Macintosh (CR)"
        }
    }

    public var shortName: String {
        switch self {
        case .crlf: return "CRLF"
        case .lf: return "LF"
        case .cr: return "CR"
        }
    }

    public var characters: String {
        switch self {
        case .crlf: return "\r\n"
        case .lf: return "\n"
        case .cr: return "\r"
        }
    }
}

public struct NppEncodingInfo: Identifiable, Hashable {
    public let id: String
    public let name: String
    public let hasBOM: Bool
    public let category: String

    public init(id: String, name: String, hasBOM: Bool = false, category: String = "Common") {
        self.id = id
        self.name = name
        self.hasBOM = hasBOM
        self.category = category
    }

    public static let utf8 = NppEncodingInfo(id: "UTF-8", name: "UTF-8", hasBOM: false, category: "Unicode")
    public static let utf8Bom = NppEncodingInfo(id: "UTF-8-BOM", name: "UTF-8 with BOM", hasBOM: true, category: "Unicode")
    public static let utf16LE = NppEncodingInfo(id: "UTF-16LE", name: "UTF-16 LE", hasBOM: true, category: "Unicode")
    public static let utf16BE = NppEncodingInfo(id: "UTF-16BE", name: "UTF-16 BE", hasBOM: true, category: "Unicode")
    public static let cp949 = NppEncodingInfo(id: "CP949", name: "Korean (Windows-949 / CP949)", category: "Korean")
    public static let euckr = NppEncodingInfo(id: "EUC-KR", name: "Korean (EUC-KR)", category: "Korean")
    public static let shiftJis = NppEncodingInfo(id: "CP932", name: "Japanese (Shift-JIS / CP932)", category: "Japanese")
    public static let gb18030 = NppEncodingInfo(id: "GB18030", name: "Chinese Simplified (GB18030)", category: "Chinese")
    public static let big5 = NppEncodingInfo(id: "BIG5", name: "Chinese Traditional (Big5)", category: "Chinese")
    public static let win1252 = NppEncodingInfo(id: "WINDOWS-1252", name: "Western European (Windows-1252)", category: "Western European")
    public static let ansi = NppEncodingInfo(id: "ANSI", name: "ANSI", category: "Common")

    public static let all: [NppEncodingInfo] = [
        .utf8, .utf8Bom, .utf16LE, .utf16BE,
        .cp949, .euckr,
        .shiftJis,
        .gb18030, .big5,
        .win1252, .ansi
    ]
}
