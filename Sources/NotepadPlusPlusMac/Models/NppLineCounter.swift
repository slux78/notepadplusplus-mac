import Foundation

/// Counts lines the way Scintilla/Notepad++ does: CRLF, LF and CR each end one line,
/// so Windows, Unix and classic-Mac files (and mixed ones) all report the same numbers.
public enum NppLineCounter {
    /// 1-based line number and UTF-16 offset of that line's start for the caret at `location`.
    public static func lineInfo(upTo location: Int, in ns: NSString) -> (line: Int, lineStart: Int) {
        let end = min(max(0, location), ns.length)
        var line = 1
        var lineStart = 0
        var i = 0
        while i < end {
            let c = ns.character(at: i)
            if c == 10 {
                line += 1
                lineStart = i + 1
            } else if c == 13 {
                let nextIsLF = i + 1 < ns.length && ns.character(at: i + 1) == 10
                if !nextIsLF {
                    line += 1
                    lineStart = i + 1
                }
            }
            i += 1
        }
        return (line, lineStart)
    }

    public static func lineNumber(upTo location: Int, in ns: NSString) -> Int {
        lineInfo(upTo: location, in: ns).line
    }

    /// Total number of lines (a trailing line break starts a new, empty line).
    public static func lineCount(in text: String) -> Int {
        let ns = text as NSString
        return lineInfo(upTo: ns.length, in: ns).line
    }

    /// Number of line breaks in `text` (CRLF counts once).
    public static func breakCount(in text: String) -> Int {
        lineCount(in: text) - 1
    }
}
