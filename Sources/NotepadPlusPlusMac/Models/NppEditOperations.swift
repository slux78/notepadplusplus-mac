import AppKit
import Foundation

public enum CaseType {
    case uppercase
    case lowercase
    case properCase
    case sentenceCase
    case invertCase
    case randomCase
}

public enum TrimMode {
    case leading
    case trailing
    case both
}

public final class NppEditOperations {

    // MARK: - Case Conversion
    public static func convertCase(in textView: NSTextView, to caseType: CaseType) {
        let sel = textView.selectedRange()
        let str = textView.string as NSString
        guard sel.length > 0 else {
            // If no selection, convert current word or line
            let wordRange = getWordRange(at: sel.location, in: str)
            if wordRange.length > 0 {
                let word = str.substring(with: wordRange)
                let converted = transformString(word, to: caseType)
                textView.shouldChangeText(in: wordRange, replacementString: converted)
                textView.replaceCharacters(in: wordRange, with: converted)
                textView.didChangeText()
            }
            return
        }

        let selectedText = str.substring(with: sel)
        let converted = transformString(selectedText, to: caseType)
        textView.shouldChangeText(in: sel, replacementString: converted)
        textView.replaceCharacters(in: sel, with: converted)
        textView.setSelectedRange(NSRange(location: sel.location, length: (converted as NSString).length))
        textView.didChangeText()
    }

    private static func transformString(_ s: String, to caseType: CaseType) -> String {
        switch caseType {
        case .uppercase:
            return s.uppercased()
        case .lowercase:
            return s.lowercased()
        case .properCase:
            return s.capitalized
        case .sentenceCase:
            let sentences = s.components(separatedBy: ". ")
            return sentences.map { sent in
                guard let first = sent.first else { return sent }
                return String(first).uppercased() + sent.dropFirst().lowercased()
            }.joined(separator: ". ")
        case .invertCase:
            return s.map { char in
                let sChar = String(char)
                return sChar == sChar.uppercased() ? sChar.lowercased() : sChar.uppercased()
            }.joined()
        case .randomCase:
            return s.map { char in
                Bool.random() ? char.uppercased() : char.lowercased()
            }.joined()
        }
    }

    // MARK: - Line Operations
    public static func duplicateLine(in textView: NSTextView) {
        let str = textView.string as NSString
        let sel = textView.selectedRange()
        let lineRange = str.lineRange(for: NSRange(location: sel.location, length: 0))
        let lineText = str.substring(with: lineRange)

        var insertText = lineText
        if !insertText.hasSuffix("\n") && !insertText.hasSuffix("\r") {
            insertText = "\n" + lineText
        }

        let insertPos = NSMaxRange(lineRange)
        textView.shouldChangeText(in: NSRange(location: insertPos, length: 0), replacementString: insertText)
        textView.replaceCharacters(in: NSRange(location: insertPos, length: 0), with: insertText)
        textView.setSelectedRange(NSRange(location: insertPos + (insertText as NSString).length, length: 0))
        textView.didChangeText()
    }

    public static func moveLineUp(in textView: NSTextView) {
        let str = textView.string as NSString
        let sel = textView.selectedRange()
        let currentLineRange = str.lineRange(for: sel)
        guard currentLineRange.location > 0 else { return } // already at top

        let prevLineRange = str.lineRange(for: NSRange(location: currentLineRange.location - 1, length: 0))
        let combinedRange = NSRange(location: prevLineRange.location, length: prevLineRange.length + currentLineRange.length)

        let prevLineText = str.substring(with: prevLineRange)
        let currentLineText = str.substring(with: currentLineRange)

        let newText = currentLineText + prevLineText
        textView.shouldChangeText(in: combinedRange, replacementString: newText)
        textView.replaceCharacters(in: combinedRange, with: newText)
        textView.setSelectedRange(NSRange(location: prevLineRange.location, length: sel.length))
        textView.didChangeText()
    }

    public static func moveLineDown(in textView: NSTextView) {
        let str = textView.string as NSString
        let sel = textView.selectedRange()
        let currentLineRange = str.lineRange(for: sel)
        let nextPos = NSMaxRange(currentLineRange)
        guard nextPos < str.length else { return } // already at bottom

        let nextLineRange = str.lineRange(for: NSRange(location: nextPos, length: 0))
        let combinedRange = NSRange(location: currentLineRange.location, length: currentLineRange.length + nextLineRange.length)

        let currentLineText = str.substring(with: currentLineRange)
        let nextLineText = str.substring(with: nextLineRange)

        let newText = nextLineText + currentLineText
        textView.shouldChangeText(in: combinedRange, replacementString: newText)
        textView.replaceCharacters(in: combinedRange, with: newText)
        let newLocation = currentLineRange.location + (nextLineText as NSString).length
        textView.setSelectedRange(NSRange(location: newLocation, length: sel.length))
        textView.didChangeText()
    }

    public static func joinLines(in textView: NSTextView) {
        let str = textView.string as NSString
        let sel = textView.selectedRange()
        let range = sel.length > 0 ? str.lineRange(for: sel) : str.lineRange(for: NSRange(location: sel.location, length: 0))
        let text = str.substring(with: range)

        let joined = text
            .components(separatedBy: .newlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ") + "\n"

        textView.shouldChangeText(in: range, replacementString: joined)
        textView.replaceCharacters(in: range, with: joined)
        textView.didChangeText()
    }

    public static func splitLines(in textView: NSTextView) {
        let sel = textView.selectedRange()
        let str = textView.string as NSString
        guard sel.length > 0 else { return }
        let text = str.substring(with: sel)
        let split = text.replacingOccurrences(of: " ", with: "\n")
        textView.shouldChangeText(in: sel, replacementString: split)
        textView.replaceCharacters(in: sel, with: split)
        textView.didChangeText()
    }

    public static func removeEmptyLines(in doc: NppDocument, removeBlankChars: Bool = false) {
        let lines = doc.content.components(separatedBy: .newlines)
        let filtered = lines.filter { line in
            if removeBlankChars {
                return !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            } else {
                return !line.isEmpty
            }
        }
        let separator = doc.eolFormat.characters
        doc.content = filtered.joined(separator: separator)
        doc.isDirty = true
    }

    public static func removeDuplicateLines(in doc: NppDocument, consecutiveOnly: Bool = false) {
        let lines = doc.content.components(separatedBy: .newlines)
        var result: [String] = []

        if consecutiveOnly {
            var last: String?
            for line in lines {
                if line != last {
                    result.append(line)
                    last = line
                }
            }
        } else {
            var seen = Set<String>()
            for line in lines {
                if !seen.contains(line) {
                    seen.insert(line)
                    result.append(line)
                }
            }
        }

        let separator = doc.eolFormat.characters
        doc.content = result.joined(separator: separator)
        doc.isDirty = true
    }

    public static func sortLines(in doc: NppDocument, ascending: Bool = true, ignoreCase: Bool = false) {
        var lines = doc.content.components(separatedBy: .newlines)
        lines.sort { a, b in
            let comp: ComparisonResult
            if ignoreCase {
                comp = a.caseInsensitiveCompare(b)
            } else {
                comp = a.compare(b)
            }
            return ascending ? (comp == .orderedAscending) : (comp == .orderedDescending)
        }
        let separator = doc.eolFormat.characters
        doc.content = lines.joined(separator: separator)
        doc.isDirty = true
    }

    public static func reverseLineOrder(in doc: NppDocument) {
        let lines = doc.content.components(separatedBy: .newlines)
        let reversed = lines.reversed()
        let separator = doc.eolFormat.characters
        doc.content = reversed.joined(separator: separator)
        doc.isDirty = true
    }

    // MARK: - Blank Operations
    public static func trimSpaces(in doc: NppDocument, mode: TrimMode) {
        let lines = doc.content.components(separatedBy: .newlines)
        let trimmed = lines.map { line -> String in
            switch mode {
            case .leading:
                return line.replacingOccurrences(of: #"^\s+"#, with: "", options: .regularExpression)
            case .trailing:
                return line.replacingOccurrences(of: #"\s+$"#, with: "", options: .regularExpression)
            case .both:
                return line.trimmingCharacters(in: .whitespaces)
            }
        }
        let separator = doc.eolFormat.characters
        doc.content = trimmed.joined(separator: separator)
        doc.isDirty = true
    }

    public static func eolToSpace(in doc: NppDocument) {
        doc.content = doc.content.components(separatedBy: .newlines).joined(separator: " ")
        doc.isDirty = true
    }

    public static func tabToSpace(in doc: NppDocument, spaceCount: Int = 4) {
        let spaces = String(repeating: " ", count: spaceCount)
        doc.content = doc.content.replacingOccurrences(of: "\t", with: spaces)
        doc.isDirty = true
    }

    public static func spaceToTab(in doc: NppDocument, spaceCount: Int = 4) {
        let spaces = String(repeating: " ", count: spaceCount)
        doc.content = doc.content.replacingOccurrences(of: spaces, with: "\t")
        doc.isDirty = true
    }

    // MARK: - Comment Operations
    public static func toggleComment(in textView: NSTextView, language: String) {
        let commentPrefix = getCommentPrefix(for: language)
        let str = textView.string as NSString
        let sel = textView.selectedRange()
        let lineRange = str.lineRange(for: sel)
        let selectedText = str.substring(with: lineRange)

        let lines = selectedText.components(separatedBy: .newlines)
        let allCommented = lines.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .allSatisfy { $0.trimmingCharacters(in: .whitespaces).hasPrefix(commentPrefix) }

        let transformed = lines.map { line -> String in
            if allCommented {
                if let range = line.range(of: commentPrefix) {
                    var modified = line
                    modified.removeSubrange(range)
                    if modified.hasPrefix(" ") { modified.removeFirst() }
                    return modified
                }
                return line
            } else {
                if line.trimmingCharacters(in: .whitespaces).isEmpty { return line }
                return commentPrefix + " " + line
            }
        }.joined(separator: "\n")

        textView.shouldChangeText(in: lineRange, replacementString: transformed)
        textView.replaceCharacters(in: lineRange, with: transformed)
        textView.didChangeText()
    }

    private static func getCommentPrefix(for language: String) -> String {
        switch language {
        case "Python", "Shell": return "#"
        case "SQL": return "--"
        case "HTML", "XML": return "//"
        default: return "//"
        }
    }

    // MARK: - Insert Operations
    public static func insertDateTime(in textView: NSTextView, isLong: Bool) {
        let formatter = DateFormatter()
        if isLong {
            formatter.dateStyle = .full
            formatter.timeStyle = .medium
        } else {
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        }
        let str = formatter.string(from: Date())
        textView.insertText(str, replacementRange: textView.selectedRange())
    }

    // MARK: - Helpers
    private static func getWordRange(at pos: Int, in string: NSString) -> NSRange {
        guard string.length > 0 else { return NSRange(location: 0, length: 0) }
        let clamped = min(max(pos, 0), string.length - 1)
        var start = clamped
        var end = clamped

        let charSet = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))
        while start > 0 {
            let u16 = string.character(at: start - 1)
            if let scalar = UnicodeScalar(u16), charSet.contains(scalar) {
                start -= 1
            } else {
                break
            }
        }
        while end < string.length {
            let u16 = string.character(at: end)
            if let scalar = UnicodeScalar(u16), charSet.contains(scalar) {
                end += 1
            } else {
                break
            }
        }
        return NSRange(location: start, length: max(0, end - start))
    }
}
