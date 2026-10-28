import AppKit
import Foundation

public enum CaseType {
    case uppercase
    case lowercase
    case properCase        // PROPERCASE_FORCE
    case properCaseBlend   // PROPERCASE_BLEND
    case sentenceCase      // SENTENCECASE_FORCE
    case sentenceCaseBlend // SENTENCECASE_BLEND
    case invertCase
    case randomCase
}

public enum TrimMode {
    case leading
    case trailing
    case both
}

public enum NppCommentMode {
    case toggle     // cm_toggle (IDM_EDIT_BLOCK_COMMENT)
    case comment    // cm_comment (IDM_EDIT_BLOCK_COMMENT_SET)
    case uncomment  // cm_uncomment (IDM_EDIT_BLOCK_UNCOMMENT)
}

public final class NppEditOperations {

    // MARK: - Case Conversion
    public static func convertCase(in textView: NSTextView, to caseType: CaseType) {
        guard textView.isEditable else { return }
        let sel = textView.selectedRange()
        let str = textView.string as NSString
        guard sel.length > 0 else {
            // If no selection, convert current word under caret and keep caret position
            let wordRange = getWordRange(at: sel.location, in: str)
            if wordRange.length > 0 {
                let word = str.substring(with: wordRange)
                let converted = transformString(word, to: caseType)
                if textView.shouldChangeText(in: wordRange, replacementString: converted) {
                    textView.replaceCharacters(in: wordRange, with: converted)
                    textView.didChangeText()
                    textView.setSelectedRange(sel)
                }
            }
            return
        }

        let selectedText = str.substring(with: sel)
        let converted = transformString(selectedText, to: caseType)
        if textView.shouldChangeText(in: sel, replacementString: converted) {
            textView.replaceCharacters(in: sel, with: converted)
            textView.didChangeText()
            textView.setSelectedRange(NSRange(location: sel.location, length: (converted as NSString).length))
        }
    }

    private static func isSingleQuote(_ c: Character) -> Bool {
        return c == "'" || c == "\u{2019}" || c == "\u{2018}"
    }

    public static func transformProperCase(_ s: String, blend: Bool) -> String {
        let chars = Array(s)
        var result: [Character] = []
        result.reserveCapacity(chars.count)

        for i in 0..<chars.count {
            let ch = chars[i]
            if ch.isLetter {
                let isAfterApostrophe = (i >= 2 && isSingleQuote(chars[i - 1]) && (chars[i - 2].isLetter || chars[i - 2].isNumber))
                let isWordStart = (i == 0 || !(chars[i - 1].isLetter || chars[i - 1].isNumber))

                if isAfterApostrophe {
                    if !blend {
                        result.append(Character(ch.lowercased()))
                    } else {
                        result.append(ch)
                    }
                } else if isWordStart {
                    result.append(Character(ch.uppercased()))
                } else if !blend {
                    result.append(Character(ch.lowercased()))
                } else {
                    result.append(ch)
                }
            } else {
                result.append(ch)
            }
        }
        return String(result)
    }

    public static func transformSentenceCase(_ s: String, blend: Bool) -> String {
        let chars = Array(s)
        var result: [Character] = []
        result.reserveCapacity(chars.count)

        var isNewSentence = true
        var wasEolR = false
        var wasEolN = false

        for i in 0..<chars.count {
            let ch = chars[i]
            if ch.isLetter {
                var transformed = ch
                if isNewSentence {
                    transformed = Character(ch.uppercased())
                    isNewSentence = false
                } else if !blend {
                    transformed = Character(ch.lowercased())
                }
                wasEolR = false
                wasEolN = false

                // Standalone 'i' exception (Notepad++ / Scintilla L3776-3781)
                if (transformed == "i" || ch == "i") {
                    let prevValid = (i < 1) ? true : (chars[i - 1].isWhitespace || chars[i - 1] == "(" || chars[i - 1] == "\"")
                    let nextValid = (i + 1 == chars.count) ? true : (chars[i + 1].isWhitespace || chars[i + 1] == "'" || chars[i + 1] == "." || chars[i + 1] == "," || chars[i + 1] == "!" || chars[i + 1] == "?")
                    if prevValid && nextValid {
                        transformed = "I"
                    }
                }
                result.append(transformed)
            } else if ch == "." || ch == "!" || ch == "?" {
                if i + 1 < chars.count && (chars[i + 1].isLetter || chars[i + 1].isNumber) {
                    isNewSentence = false
                } else {
                    isNewSentence = true
                }
                result.append(ch)
            } else if ch == "\r" {
                if wasEolR { isNewSentence = true } else { wasEolR = true }
                result.append(ch)
            } else if ch == "\n" {
                if wasEolN { isNewSentence = true } else { wasEolN = true }
                result.append(ch)
            } else {
                result.append(ch)
            }
        }
        return String(result)
    }

    public static func transformRandomCase(_ s: String) -> String {
        return String(s.map { ch in
            guard ch.isLetter else { return ch }
            return Bool.random() ? Character(ch.uppercased()) : Character(ch.lowercased())
        })
    }

    public static func transformString(_ s: String, to caseType: CaseType) -> String {
        switch caseType {
        case .uppercase:
            return s.uppercased()
        case .lowercase:
            return s.lowercased()
        case .properCase:
            return transformProperCase(s, blend: false)
        case .properCaseBlend:
            return transformProperCase(s, blend: true)
        case .sentenceCase:
            return transformSentenceCase(s, blend: false)
        case .sentenceCaseBlend:
            return transformSentenceCase(s, blend: true)
        case .invertCase:
            return s.map { char in
                let sChar = String(char)
                return sChar == sChar.uppercased() ? sChar.lowercased() : sChar.uppercased()
            }.joined()
        case .randomCase:
            return transformRandomCase(s)
        }
    }

    // MARK: - Line Operations
    /// 1:1 port of Scintilla `SCI_LINEDUPLICATE` (`IDM_EDIT_DUP_LINE`):
    /// Duplicates the current line (without moving the caret to the next line).
    public static func duplicateLine(in textView: NSTextView) {
        guard textView.isEditable else { return }
        let str = textView.string as NSString
        let sel = textView.selectedRange()
        var lineStart = 0
        var lineEnd = 0
        var contentsEnd = 0
        str.getLineStart(&lineStart, end: &lineEnd, contentsEnd: &contentsEnd, for: NSRange(location: sel.location, length: 0))

        let lineContent = str.substring(with: NSRange(location: lineStart, length: contentsEnd - lineStart))
        let eolLen = lineEnd - contentsEnd
        let eolStr = eolLen > 0 ? str.substring(with: NSRange(location: contentsEnd, length: eolLen)) : "\n"

        let insertPos = contentsEnd
        let insertText = eolStr + lineContent
        let insertRange = NSRange(location: insertPos, length: 0)
        if textView.shouldChangeText(in: insertRange, replacementString: insertText) {
            textView.replaceCharacters(in: insertRange, with: insertText)
            textView.didChangeText()
            // Keep caret/selection at its original position on the line (SCI_LINEDUPLICATE)
            textView.setSelectedRange(sel)
        }
    }

    /// 1:1 port of `ScintillaEditView::currentLinesUp()` (`IDM_EDIT_LINE_UP`):
    /// Swaps the current line's content with the previous line's content while preserving EOLs and caret column offset.
    public static func moveLineUp(in textView: NSTextView) {
        guard textView.isEditable else { return }
        let str = textView.string as NSString
        let sel = textView.selectedRange()
        var currStart = 0
        var currEnd = 0
        var currContentsEnd = 0
        str.getLineStart(&currStart, end: &currEnd, contentsEnd: &currContentsEnd, for: sel)
        guard currStart > 0 else { return } // already at top line

        var prevStart = 0
        var prevEnd = 0
        var prevContentsEnd = 0
        str.getLineStart(&prevStart, end: &prevEnd, contentsEnd: &prevContentsEnd, for: NSRange(location: currStart - 1, length: 0))

        let prevContent = str.substring(with: NSRange(location: prevStart, length: prevContentsEnd - prevStart))
        let separator = str.substring(with: NSRange(location: prevContentsEnd, length: currStart - prevContentsEnd))
        let currContent = str.substring(with: NSRange(location: currStart, length: currContentsEnd - currStart))

        let combinedRange = NSRange(location: prevStart, length: currContentsEnd - prevStart)
        let replacement = currContent + separator + prevContent
        let colOffset = max(0, sel.location - currStart)

        if textView.shouldChangeText(in: combinedRange, replacementString: replacement) {
            textView.replaceCharacters(in: combinedRange, with: replacement)
            textView.didChangeText()
            let newCaretLoc = prevStart + min(colOffset, (currContent as NSString).length)
            textView.setSelectedRange(NSRange(location: newCaretLoc, length: min(sel.length, (currContent as NSString).length)))
        }
    }

    /// 1:1 port of `ScintillaEditView::currentLinesDown()` (`IDM_EDIT_LINE_DOWN`):
    /// Swaps the current line's content with the next line's content while preserving EOLs and caret column offset.
    public static func moveLineDown(in textView: NSTextView) {
        guard textView.isEditable else { return }
        let str = textView.string as NSString
        let sel = textView.selectedRange()
        var currStart = 0
        var currEnd = 0
        var currContentsEnd = 0
        str.getLineStart(&currStart, end: &currEnd, contentsEnd: &currContentsEnd, for: sel)
        guard currEnd < str.length || (currEnd == str.length && currEnd > currContentsEnd) else { return }
        guard currEnd <= str.length else { return }

        // If currEnd == str.length and currEnd == currContentsEnd, there is no next line
        if currEnd == str.length && currEnd == currContentsEnd { return }

        var nextStart = 0
        var nextEnd = 0
        var nextContentsEnd = 0
        if currEnd < str.length {
            str.getLineStart(&nextStart, end: &nextEnd, contentsEnd: &nextContentsEnd, for: NSRange(location: currEnd, length: 0))
        } else {
            // Trailing empty line after final newline
            nextStart = currEnd
            nextEnd = currEnd
            nextContentsEnd = currEnd
        }

        let currContent = str.substring(with: NSRange(location: currStart, length: currContentsEnd - currStart))
        let separator = str.substring(with: NSRange(location: currContentsEnd, length: nextStart - currContentsEnd))
        let nextContent = str.substring(with: NSRange(location: nextStart, length: nextContentsEnd - nextStart))

        let combinedRange = NSRange(location: currStart, length: nextContentsEnd - currStart)
        let replacement = nextContent + separator + currContent
        let colOffset = max(0, sel.location - currStart)

        if textView.shouldChangeText(in: combinedRange, replacementString: replacement) {
            textView.replaceCharacters(in: combinedRange, with: replacement)
            textView.didChangeText()
            let movedLineStart = currStart + (nextContent as NSString).length + (separator as NSString).length
            let newCaretLoc = movedLineStart + min(colOffset, (currContent as NSString).length)
            textView.setSelectedRange(NSRange(location: newCaretLoc, length: min(sel.length, (currContent as NSString).length)))
        }
    }

    /// 1:1 port of `IDM_EDIT_JOIN_LINES` (`NppCommands.cpp:2132-2144`):
    /// Joins selected lines (or current line with next line if single caret) without eating the final line's trailing newline.
    public static func joinLines(in textView: NSTextView) {
        guard textView.isEditable else { return }
        let str = textView.string as NSString
        let sel = textView.selectedRange()

        var startLineStart = 0
        var startLineEnd = 0
        var startContentsEnd = 0
        str.getLineStart(&startLineStart, end: &startLineEnd, contentsEnd: &startContentsEnd, for: NSRange(location: sel.location, length: 0))

        var targetRange: NSRange
        if sel.length > 0 {
            var endLineStart = 0
            var endLineEnd = 0
            var endContentsEnd = 0
            let endCheckPos = max(sel.location, NSMaxRange(sel) - 1)
            str.getLineStart(&endLineStart, end: &endLineEnd, contentsEnd: &endContentsEnd, for: NSRange(location: endCheckPos, length: 0))
            guard endLineStart > startLineStart else { return }
            targetRange = NSRange(location: startLineStart, length: endContentsEnd - startLineStart)
        } else {
            // Single caret: join current line with next line if a next line exists
            guard startLineEnd < str.length else { return }
            var nextStart = 0
            var nextEnd = 0
            var nextContentsEnd = 0
            str.getLineStart(&nextStart, end: &nextEnd, contentsEnd: &nextContentsEnd, for: NSRange(location: startLineEnd, length: 0))
            targetRange = NSRange(location: startLineStart, length: nextContentsEnd - startLineStart)
        }

        let text = str.substring(with: targetRange)
        let lines = text.components(separatedBy: .newlines)
        var joined = ""
        for (idx, line) in lines.enumerated() {
            if idx == 0 {
                joined += line.replacingOccurrences(of: #"\s+$"#, with: "", options: .regularExpression)
            } else {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty {
                    if !joined.isEmpty && !joined.hasSuffix(" ") {
                        joined += " "
                    }
                    joined += trimmed
                }
            }
        }

        if textView.shouldChangeText(in: targetRange, replacementString: joined) {
            textView.replaceCharacters(in: targetRange, with: joined)
            textView.didChangeText()
            let newCaret = min(sel.location, startLineStart + (joined as NSString).length)
            textView.setSelectedRange(NSRange(location: newCaret, length: 0))
        }
    }

    public static func splitLines(in textView: NSTextView) {
        guard textView.isEditable else { return }
        let sel = textView.selectedRange()
        let str = textView.string as NSString
        guard sel.length > 0 else { return }
        let text = str.substring(with: sel)
        let split = text.replacingOccurrences(of: " ", with: "\n")
        if textView.shouldChangeText(in: sel, replacementString: split) {
            textView.replaceCharacters(in: sel, with: split)
            textView.didChangeText()
            textView.setSelectedRange(NSRange(location: sel.location, length: (split as NSString).length))
        }
    }

    public static func removeEmptyLines(in doc: NppDocument, removeBlankChars: Bool = false) {
        guard !doc.isReadOnly else { return }
        let lines = doc.content.nppLines()
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
        guard !doc.isReadOnly else { return }
        let lines = doc.content.nppLines()
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

    public static func removeConsecutiveDuplicateLines(in doc: NppDocument) {
        guard !doc.isReadOnly else { return }
        removeDuplicateLines(in: doc, consecutiveOnly: true)
    }

    public static func sortLines(in doc: NppDocument, ascending: Bool = true, ignoreCase: Bool = false) {
        guard !doc.isReadOnly else { return }
        var lines = doc.content.nppLines()
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

    public static func randomizeLineOrder(in doc: NppDocument) {
        guard !doc.isReadOnly else { return }
        var lines = doc.content.nppLines()
        lines.shuffle()
        let separator = doc.eolFormat.characters
        doc.content = lines.joined(separator: separator)
        doc.isDirty = true
    }

    public static func sortLinesCaseInsensitive(in doc: NppDocument, ascending: Bool = true) {
        guard !doc.isReadOnly else { return }
        var lines = doc.content.nppLines()
        lines.sort { a, b in
            let comp = a.localizedCaseInsensitiveCompare(b)
            return ascending ? (comp == .orderedAscending) : (comp == .orderedDescending)
        }
        let separator = doc.eolFormat.characters
        doc.content = lines.joined(separator: separator)
        doc.isDirty = true
    }

    public static func sortLinesByLength(in doc: NppDocument, ascending: Bool = true) {
        guard !doc.isReadOnly else { return }
        var lines = doc.content.nppLines()
        lines.sort { a, b in
            if a.count != b.count {
                return ascending ? (a.count < b.count) : (a.count > b.count)
            }
            return ascending ? (a < b) : (a > b)
        }
        let separator = doc.eolFormat.characters
        doc.content = lines.joined(separator: separator)
        doc.isDirty = true
    }

    public static func reverseLineOrder(in doc: NppDocument) {
        guard !doc.isReadOnly else { return }
        let lines = doc.content.nppLines()
        let reversed = lines.reversed()
        let separator = doc.eolFormat.characters
        doc.content = reversed.joined(separator: separator)
        doc.isDirty = true
    }

    public static func sortLinesAsIntegers(in doc: NppDocument, ascending: Bool = true) {
        guard !doc.isReadOnly else { return }
        var lines = doc.content.nppLines()
        lines.sort { a, b in
            let intA = extractLeadingInteger(from: a)
            let intB = extractLeadingInteger(from: b)
            if let ia = intA, let ib = intB {
                return ascending ? (ia < ib) : (ia > ib)
            }
            if intA != nil { return ascending }
            if intB != nil { return !ascending }
            return ascending ? (a < b) : (a > b)
        }
        let separator = doc.eolFormat.characters
        doc.content = lines.joined(separator: separator)
        doc.isDirty = true
    }

    public static func sortLinesAsDecimals(in doc: NppDocument, ascending: Bool = true, usesComma: Bool = false) {
        guard !doc.isReadOnly else { return }
        var lines = doc.content.nppLines()
        lines.sort { a, b in
            let dblA = extractLeadingDouble(from: a, usesComma: usesComma)
            let dblB = extractLeadingDouble(from: b, usesComma: usesComma)
            if let da = dblA, let db = dblB {
                return ascending ? (da < db) : (da > db)
            }
            if dblA != nil { return ascending }
            if dblB != nil { return !ascending }
            return ascending ? (a < b) : (a > b)
        }
        let separator = doc.eolFormat.characters
        doc.content = lines.joined(separator: separator)
        doc.isDirty = true
    }

    public static func insertEmptyLineAbove(in textView: NSTextView) {
        guard textView.isEditable else { return }
        let str = textView.string as NSString
        let sel = textView.selectedRange()
        let lineRange = str.lineRange(for: sel)
        if textView.shouldChangeText(in: NSRange(location: lineRange.location, length: 0), replacementString: "\n") {
            textView.replaceCharacters(in: NSRange(location: lineRange.location, length: 0), with: "\n")
            textView.didChangeText()
            textView.setSelectedRange(NSRange(location: lineRange.location, length: 0))
        }
    }

    public static func insertEmptyLineBelow(in textView: NSTextView) {
        guard textView.isEditable else { return }
        let str = textView.string as NSString
        let sel = textView.selectedRange()
        let lineRange = str.lineRange(for: sel)
        let insertPos = NSMaxRange(lineRange)
        var insertStr = "\n"
        if !str.substring(with: lineRange).hasSuffix("\n") && !str.substring(with: lineRange).hasSuffix("\r") {
            insertStr = "\n\n"
        }
        if textView.shouldChangeText(in: NSRange(location: insertPos, length: 0), replacementString: insertStr) {
            textView.replaceCharacters(in: NSRange(location: insertPos, length: 0), with: insertStr)
            textView.didChangeText()
            textView.setSelectedRange(NSRange(location: insertPos + (insertStr.hasPrefix("\n\n") ? 1 : 0), length: 0))
        }
    }

    private static func extractLeadingInteger(from line: String) -> Int? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let scanner = Scanner(string: trimmed)
        return scanner.scanInt()
    }

    private static func extractLeadingDouble(from line: String, usesComma: Bool) -> Double? {
        var trimmed = line.trimmingCharacters(in: .whitespaces)
        if usesComma {
            trimmed = trimmed.replacingOccurrences(of: ",", with: ".")
        }
        let scanner = Scanner(string: trimmed)
        return scanner.scanDouble()
    }

    // MARK: - Blank Operations
    private static func applyLineTransform(
        in doc: NppDocument,
        selectedRange: NSRange? = nil,
        transform: (String) -> String
    ) {
        guard !doc.isReadOnly else { return }
        let nsContent = doc.content as NSString
        let separator = doc.eolFormat.characters

        if let sel = selectedRange, sel.length > 0 && sel.location + sel.length <= nsContent.length {
            let targetRange = nsContent.lineRange(for: sel)
            let subText = nsContent.substring(with: targetRange)
            let hasEndingNewline = subText.hasSuffix("\r\n") || subText.hasSuffix("\n") || subText.hasSuffix("\r")
            let lines = subText.nppLines()
            let transformed = lines.map(transform).joined(separator: separator) + (hasEndingNewline ? separator : "")
            doc.content = nsContent.replacingCharacters(in: targetRange, with: transformed)
        } else {
            let lines = doc.content.nppLines()
            let hasEndingNewline = doc.content.hasSuffix("\r\n") || doc.content.hasSuffix("\n") || doc.content.hasSuffix("\r")
            doc.content = lines.map(transform).joined(separator: separator) + (hasEndingNewline ? separator : "")
        }
        doc.isDirty = true
    }

    public static func trimSpaces(in doc: NppDocument, mode: TrimMode, selectedRange: NSRange? = nil) {
        applyLineTransform(in: doc, selectedRange: selectedRange) { line in
            switch mode {
            case .leading:
                return line.replacingOccurrences(of: #"^\s+"#, with: "", options: .regularExpression)
            case .trailing:
                return line.replacingOccurrences(of: #"\s+$"#, with: "", options: .regularExpression)
            case .both:
                return line.trimmingCharacters(in: .whitespaces)
            }
        }
    }

    public static func eolToSpace(in doc: NppDocument) {
        guard !doc.isReadOnly else { return }
        doc.content = doc.content.nppLines().joined(separator: " ")
        doc.isDirty = true
    }

    public static func tabToSpace(in doc: NppDocument, spaceCount: Int = 4, selectedRange: NSRange? = nil) {
        let spaces = String(repeating: " ", count: spaceCount)
        if let sel = selectedRange, sel.length > 0 {
            applyLineTransform(in: doc, selectedRange: selectedRange) { line in
                line.replacingOccurrences(of: "\t", with: spaces)
            }
        } else {
            guard !doc.isReadOnly else { return }
            doc.content = doc.content.replacingOccurrences(of: "\t", with: spaces)
            doc.isDirty = true
        }
    }

    public static func spaceToTab(in doc: NppDocument, spaceCount: Int = 4, selectedRange: NSRange? = nil) {
        let spaces = String(repeating: " ", count: spaceCount)
        if let sel = selectedRange, sel.length > 0 {
            applyLineTransform(in: doc, selectedRange: selectedRange) { line in
                line.replacingOccurrences(of: spaces, with: "\t")
            }
        } else {
            guard !doc.isReadOnly else { return }
            doc.content = doc.content.replacingOccurrences(of: spaces, with: "\t")
            doc.isDirty = true
        }
    }

    public static func trimBothAndEolToSpace(in doc: NppDocument) {
        guard !doc.isReadOnly else { return }
        let lines = doc.content.nppLines().map { $0.trimmingCharacters(in: .whitespaces) }
        doc.content = lines.joined(separator: " ")
        doc.isDirty = true
    }

    public static func spaceToTabAll(in doc: NppDocument, spaceCount: Int = 4, selectedRange: NSRange? = nil) {
        spaceToTab(in: doc, spaceCount: spaceCount, selectedRange: selectedRange)
    }

    public static func spaceToTabLeading(in doc: NppDocument, spaceCount: Int = 4, selectedRange: NSRange? = nil) {
        guard spaceCount > 0 else { return }
        applyLineTransform(in: doc, selectedRange: selectedRange) { line in
            var count = 0
            for ch in line {
                if ch == " " {
                    count += 1
                } else {
                    break
                }
            }
            if count == 0 { return line }
            let tabs = count / spaceCount
            let rem = count % spaceCount
            let prefix = String(repeating: "\t", count: tabs) + String(repeating: " ", count: rem)
            return prefix + line.dropFirst(count)
        }
    }

    // MARK: - Indent Operations
    public static func increaseLineIndent(in textView: NSTextView, spaceCount: Int = 4, useTabs: Bool = true) {
        guard textView.isEditable else { return }
        let indentStr = useTabs ? "\t" : String(repeating: " ", count: spaceCount)
        let indentLen = (indentStr as NSString).length
        let str = textView.string as NSString
        let sel = textView.selectedRange()

        var startLineStart = 0, startLineEnd = 0, startContentsEnd = 0
        str.getLineStart(&startLineStart, end: &startLineEnd, contentsEnd: &startContentsEnd, for: NSRange(location: sel.location, length: 0))

        let endCheckPos = sel.length > 0 ? max(sel.location, NSMaxRange(sel) - 1) : sel.location
        var endLineStart = 0, endLineEnd = 0, endContentsEnd = 0
        str.getLineStart(&endLineStart, end: &endLineEnd, contentsEnd: &endContentsEnd, for: NSRange(location: endCheckPos, length: 0))

        var lineStarts: [Int] = []
        var cur = startLineStart
        while cur <= endLineStart && cur <= str.length {
            lineStarts.append(cur)
            var lStart = 0, lEnd = 0, cEnd = 0
            str.getLineStart(&lStart, end: &lEnd, contentsEnd: &cEnd, for: NSRange(location: cur, length: 0))
            if lEnd > cur { cur = lEnd } else { break }
        }

        guard !lineStarts.isEmpty else { return }

        textView.undoManager?.beginUndoGrouping()
        for lineStart in lineStarts.reversed() {
            let insertRange = NSRange(location: lineStart, length: 0)
            if textView.shouldChangeText(in: insertRange, replacementString: indentStr) {
                textView.replaceCharacters(in: insertRange, with: indentStr)
            }
        }
        textView.didChangeText()
        textView.undoManager?.endUndoGrouping()

        if sel.length == 0 {
            let newPos = min(sel.location + indentLen, (textView.string as NSString).length)
            textView.setSelectedRange(NSRange(location: newPos, length: 0))
        } else {
            let newStart = (sel.location == startLineStart) ? startLineStart : (sel.location + indentLen)
            let newEnd = NSMaxRange(sel) + (lineStarts.count * indentLen)
            let newLength = max(0, newEnd - newStart)
            let totalLen = (textView.string as NSString).length
            textView.setSelectedRange(NSRange(location: min(newStart, totalLen), length: min(newLength, totalLen - min(newStart, totalLen))))
        }
    }

    public static func decreaseLineIndent(in textView: NSTextView, spaceCount: Int = 4) {
        guard textView.isEditable else { return }
        let str = textView.string as NSString
        let sel = textView.selectedRange()

        var startLineStart = 0, startLineEnd = 0, startContentsEnd = 0
        str.getLineStart(&startLineStart, end: &startLineEnd, contentsEnd: &startContentsEnd, for: NSRange(location: sel.location, length: 0))

        let endCheckPos = sel.length > 0 ? max(sel.location, NSMaxRange(sel) - 1) : sel.location
        var endLineStart = 0, endLineEnd = 0, endContentsEnd = 0
        str.getLineStart(&endLineStart, end: &endLineEnd, contentsEnd: &endContentsEnd, for: NSRange(location: endCheckPos, length: 0))

        var lineRanges: [(lineStart: Int, removeLen: Int)] = []
        var cur = startLineStart
        while cur <= endLineStart && cur <= str.length {
            var lStart = 0, lEnd = 0, cEnd = 0
            str.getLineStart(&lStart, end: &lEnd, contentsEnd: &cEnd, for: NSRange(location: cur, length: 0))

            var removeLen = 0
            if lStart < cEnd {
                let firstChar = str.character(at: lStart)
                if firstChar == 0x09 { // '\t'
                    removeLen = 1
                } else if firstChar == 0x20 { // ' '
                    var spaceC = 0
                    while lStart + spaceC < cEnd && spaceC < spaceCount && str.character(at: lStart + spaceC) == 0x20 {
                        spaceC += 1
                    }
                    removeLen = spaceC
                }
            }
            lineRanges.append((lineStart: lStart, removeLen: removeLen))
            if lEnd > cur { cur = lEnd } else { break }
        }

        guard !lineRanges.isEmpty else { return }

        var removedFirstLine = 0
        var removedTotal = 0

        textView.undoManager?.beginUndoGrouping()
        for (idx, item) in lineRanges.enumerated().reversed() {
            if item.removeLen > 0 {
                let removeRange = NSRange(location: item.lineStart, length: item.removeLen)
                if textView.shouldChangeText(in: removeRange, replacementString: "") {
                    textView.replaceCharacters(in: removeRange, with: "")
                }
                removedTotal += item.removeLen
                if idx == 0 { removedFirstLine = item.removeLen }
            }
        }
        textView.didChangeText()
        textView.undoManager?.endUndoGrouping()

        let newStart = max(startLineStart, sel.location - removedFirstLine)
        let newEnd = max(newStart, NSMaxRange(sel) - removedTotal)
        let newLength = newEnd - newStart
        let totalLen = (textView.string as NSString).length
        textView.setSelectedRange(NSRange(location: min(newStart, totalLen), length: min(newLength, totalLen - min(newStart, totalLen))))
    }

    // MARK: - Comment Operations (`Notepad_plus::doBlockComment` & `doStreamComment` in `Notepad_plus.cpp` L5450-5849)

    /// `IDM_EDIT_BLOCK_COMMENT` (`Toggle Single Line Comment`)
    public static func toggleComment(in textView: NSTextView, language: String) {
        doBlockComment(in: textView, language: language, mode: .toggle)
    }

    /// `IDM_EDIT_BLOCK_COMMENT_SET` (`Single Line Comment`)
    public static func singleLineComment(in textView: NSTextView, language: String) {
        doBlockComment(in: textView, language: language, mode: .comment)
    }

    /// `IDM_EDIT_BLOCK_UNCOMMENT` (`Single Line Uncomment`)
    public static func singleLineUncomment(in textView: NSTextView, language: String) {
        doBlockComment(in: textView, language: language, mode: .uncomment)
    }

    /// 1:1 port of `Notepad_plus::doBlockComment(comment_mode currCommentMode)` (`Notepad_plus.cpp` L5450-5755).
    /// Toggles, sets, or removes single-line comments at each line's indentation point (`SCI_GETLINEINDENTPOSITION`)
    /// while keeping the caret and selection anchored on the exact same line(s) and characters.
    public static func doBlockComment(in textView: NSTextView, language: String, mode: NppCommentMode) {
        guard textView.isEditable else { return }
        let commentPrefix = getCommentPrefix(for: language)
        let prefixWithSpace = commentPrefix + " "
        let prefixLen = (commentPrefix as NSString).length
        let prefixSpaceLen = (prefixWithSpace as NSString).length

        let origSel = textView.selectedRange()
        var selectionStart = origSel.location
        var selectionEnd = origSel.location + origSel.length

        // Collect line index ranges across the document so we can iterate line by line like Scintilla
        struct LineSpan {
            var start: Int
            var indent: Int
            var end: Int          // excludes \r\n
            var nextLineStart: Int
        }

        func computeLines(in nsStr: NSString) -> [LineSpan] {
            var spans: [LineSpan] = []
            var idx = 0
            let totalLen = nsStr.length
            if totalLen == 0 {
                return [LineSpan(start: 0, indent: 0, end: 0, nextLineStart: 0)]
            }
            while idx <= totalLen {
                var lStart = 0
                var lEnd = 0
                var cEnd = 0
                nsStr.getLineStart(&lStart, end: &lEnd, contentsEnd: &cEnd, for: NSRange(location: min(idx, totalLen), length: 0))
                var indentPos = lStart
                while indentPos < cEnd {
                    let ch = nsStr.character(at: indentPos)
                    if ch == 0x20 || ch == 0x09 { // space or tab
                        indentPos += 1
                    } else {
                        break
                    }
                }
                spans.append(LineSpan(start: lStart, indent: indentPos, end: cEnd, nextLineStart: lEnd))
                if lEnd > idx {
                    idx = lEnd
                    if idx == totalLen {
                        // If the string ends with a newline, there is a trailing empty line at totalLen
                        if cEnd < lEnd {
                            spans.append(LineSpan(start: totalLen, indent: totalLen, end: totalLen, nextLineStart: totalLen))
                        }
                        break
                    }
                } else {
                    break
                }
            }
            return spans
        }

        func lineIndex(for pos: Int, in spans: [LineSpan]) -> Int {
            for (i, s) in spans.enumerated() {
                if pos >= s.start && (pos < s.nextLineStart || i == spans.count - 1) {
                    return i
                }
            }
            return max(0, spans.count - 1)
        }

        let initialStr = textView.string as NSString
        let initialSpans = computeLines(in: initialStr)
        let selStartLine = lineIndex(for: selectionStart, in: initialSpans)
        var selEndLine = lineIndex(for: selectionEnd, in: initialSpans)

        // Notepad_plus.cpp L5572:
        // "caret return" is part of the last selected line: if selectionEnd is at the very start of selEndLine, exclude selEndLine
        if selEndLine > selStartLine && selectionEnd == initialSpans[selEndLine].start {
            selEndLine -= 1
        }

        var nUncomments = 0

        textView.undoManager?.beginUndoGrouping()
        for i in selStartLine...selEndLine {
            let currentStr = textView.string as NSString
            let spans = computeLines(in: currentStr)
            guard i < spans.count else { break }
            let span = spans[i]
            let lineStart = span.start
            let lineIndent = span.indent
            let lineEnd = span.end

            // Notepad_plus.cpp L5590: empty lines are not commented
            if lineIndent == lineEnd {
                continue
            }

            let lineContent = currentStr.substring(with: NSRange(location: lineIndent, length: lineEnd - lineIndent))

            // 1) Uncomment or Toggle when line is already commented (Notepad_plus.cpp L5603-5641)
            if mode != .comment {
                if lineContent.lowercased().hasPrefix(commentPrefix.lowercased()) {
                    let hasTrailingSpace = (lineContent as NSString).length >= prefixSpaceLen &&
                        (lineContent as NSString).substring(with: NSRange(location: prefixLen, length: 1)) == " "
                    let removeLen = hasTrailingSpace ? prefixSpaceLen : prefixLen
                    let removeRange = NSRange(location: lineIndent, length: removeLen)

                    if textView.shouldChangeText(in: removeRange, replacementString: "") {
                        textView.replaceCharacters(in: removeRange, with: "")
                        textView.didChangeText()
                    }

                    // SELECTION RANGE ADJUSTMENT (Notepad_plus.cpp L5617-5637)
                    if i == selStartLine {
                        if selectionStart > lineIndent + removeLen {
                            selectionStart -= removeLen
                        } else if selectionStart > lineIndent {
                            selectionStart = lineIndent
                        }
                    }
                    if i == selEndLine {
                        if selectionEnd > lineIndent + removeLen {
                            selectionEnd -= removeLen
                        } else if selectionEnd > lineIndent {
                            selectionEnd = lineIndent
                            if lineIndent == lineStart && i != selStartLine {
                                selectionEnd += 1
                            }
                        }
                    } else {
                        selectionEnd -= removeLen
                    }

                    nUncomments += 1
                    continue
                }
            }

            // 2) Comment or Toggle when line is not commented (Notepad_plus.cpp L5691-5711)
            if mode != .uncomment {
                let insertRange = NSRange(location: lineIndent, length: 0)
                if textView.shouldChangeText(in: insertRange, replacementString: prefixWithSpace) {
                    textView.replaceCharacters(in: insertRange, with: prefixWithSpace)
                    textView.didChangeText()
                }

                // SELECTION RANGE ADJUSTMENT (Notepad_plus.cpp L5698-5710)
                if i == selStartLine {
                    if selectionStart >= lineIndent {
                        selectionStart += prefixSpaceLen
                    }
                }
                if i == selEndLine {
                    if selectionEnd >= lineIndent {
                        selectionEnd += prefixSpaceLen
                    }
                } else {
                    selectionEnd += prefixSpaceLen
                }
            }
        }
        textView.undoManager?.endUndoGrouping()

        // Restore adjusted selection/caret on the exact same line(s) (Notepad_plus.cpp L5737-5746)
        let finalLen = (textView.string as NSString).length
        let clampedStart = min(max(0, selectionStart), finalLen)
        let clampedEnd = min(max(clampedStart, selectionEnd), finalLen)
        textView.setSelectedRange(NSRange(location: clampedStart, length: clampedEnd - clampedStart))

        // Notepad_plus.cpp L5750: If currCommentMode == cm_uncomment && nUncomments == 0, try undoStreamComment
        if mode == .uncomment && nUncomments == 0 {
            streamUncomment(in: textView, language: language)
        }
    }

    /// 1:1 port of `Notepad_plus::doStreamComment()` (`IDM_EDIT_STREAM_COMMENT`, `Notepad_plus.cpp` L5757-5849).
    public static func streamComment(in textView: NSTextView, language: String) {
        guard textView.isEditable else { return }
        let (commentStart, commentEnd) = getStreamCommentSymbols(for: language)
        guard !commentStart.isEmpty && !commentEnd.isEmpty else {
            doBlockComment(in: textView, language: language, mode: .comment)
            return
        }

        let startToken = commentStart + " "
        let endToken = " " + commentEnd
        let startLen = (startToken as NSString).length

        let str = textView.string as NSString
        let sel = textView.selectedRange()
        var selectionStart = sel.location
        var selectionEnd = sel.location + sel.length

        // Notepad_plus.cpp L5824: if there is no selection, wrap current line from indent to end
        if selectionEnd <= selectionStart {
            var lStart = 0
            var lEnd = 0
            var cEnd = 0
            str.getLineStart(&lStart, end: &lEnd, contentsEnd: &cEnd, for: NSRange(location: selectionStart, length: 0))
            var indentPos = lStart
            while indentPos < cEnd {
                let ch = str.character(at: indentPos)
                if ch == 0x20 || ch == 0x09 { indentPos += 1 } else { break }
            }
            selectionStart = indentPos
            selectionEnd = cEnd
        }

        let targetRange = NSRange(location: selectionStart, length: max(0, selectionEnd - selectionStart))
        let innerText = str.substring(with: targetRange)
        let wrapped = startToken + innerText + endToken

        if textView.shouldChangeText(in: targetRange, replacementString: wrapped) {
            textView.replaceCharacters(in: targetRange, with: wrapped)
            textView.didChangeText()
            // Notepad_plus.cpp L5833-5846: select inner text between start_comment and end_comment
            textView.setSelectedRange(NSRange(location: selectionStart + startLen, length: (innerText as NSString).length))
        }
    }

    /// 1:1 port of `Notepad_plus::undoStreamComment()` (`IDM_EDIT_STREAM_UNCOMMENT`, `Notepad_plus.cpp` L8928-9050).
    public static func streamUncomment(in textView: NSTextView, language: String) {
        guard textView.isEditable else { return }
        let (commentStart, commentEnd) = getStreamCommentSymbols(for: language)
        guard !commentStart.isEmpty && !commentEnd.isEmpty else { return }

        let str = textView.string as NSString
        let sel = textView.selectedRange()

        // Search either within selection or enclosing the selection/caret
        var searchRange: NSRange
        if sel.length > 0 {
            let expandStart = max(0, sel.location - (commentStart as NSString).length - 2)
            let expandEnd = min(str.length, NSMaxRange(sel) + (commentEnd as NSString).length + 2)
            searchRange = NSRange(location: expandStart, length: expandEnd - expandStart)
        } else {
            // Find enclosing /* ... */ around caret or on current line
            let startBefore = str.range(of: commentStart, options: .backwards, range: NSRange(location: 0, length: sel.location))
            let endAfter = str.range(of: commentEnd, options: [], range: NSRange(location: sel.location, length: str.length - sel.location))
            if startBefore.location != NSNotFound && endAfter.location != NSNotFound {
                searchRange = NSRange(location: startBefore.location, length: NSMaxRange(endAfter) - startBefore.location)
            } else {
                var lStart = 0, lEnd = 0, cEnd = 0
                str.getLineStart(&lStart, end: &lEnd, contentsEnd: &cEnd, for: sel)
                searchRange = NSRange(location: lStart, length: cEnd - lStart)
            }
        }

        let sub = str.substring(with: searchRange)
        guard let startRange = sub.range(of: commentStart),
              let endRange = sub.range(of: commentEnd, options: .backwards),
              startRange.upperBound <= endRange.lowerBound else {
            return
        }

        var modified = sub
        // Remove end comment (and optional preceding space)
        var endRemoveLower = endRange.lowerBound
        if endRemoveLower > startRange.upperBound {
            let prevIdx = modified.index(before: endRemoveLower)
            if modified[prevIdx] == " " {
                endRemoveLower = prevIdx
            }
        }
        modified.removeSubrange(endRemoveLower..<endRange.upperBound)

        // Remove start comment (and optional following space)
        var startRemoveUpper = startRange.upperBound
        if startRemoveUpper < modified.endIndex && modified[startRemoveUpper] == " " {
            startRemoveUpper = modified.index(after: startRemoveUpper)
        }
        modified.removeSubrange(startRange.lowerBound..<startRemoveUpper)

        if textView.shouldChangeText(in: searchRange, replacementString: modified) {
            textView.replaceCharacters(in: searchRange, with: modified)
            textView.didChangeText()
            let newCaret = min(sel.location, searchRange.location + (modified as NSString).length)
            textView.setSelectedRange(NSRange(location: newCaret, length: 0))
        }
    }

    private static func getCommentPrefix(for language: String) -> String {
        switch language {
        case "Python", "Shell", "Bash", "Ruby", "YAML", "Makefile", "Perl", "R", "TOML":
            return "#"
        case "SQL", "Lua":
            return "--"
        default:
            return "//"
        }
    }

    private static func getStreamCommentSymbols(for language: String) -> (String, String) {
        switch language {
        case "HTML", "XML", "Markdown":
            return ("<!--", "-->")
        case "Python", "Shell", "Bash", "Ruby", "YAML", "Makefile", "Perl", "R", "TOML":
            return ("", "")
        default:
            return ("/*", "*/")
        }
    }

    // MARK: - Insert Operations
    public static func insertDateTime(in textView: NSTextView, isLong: Bool) {
        guard textView.isEditable else { return }
        let formatter = DateFormatter()
        if isLong {
            formatter.dateStyle = .full
            formatter.timeStyle = .medium
        } else {
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        }
        let str = formatter.string(from: Date())
        let sel = textView.selectedRange()
        if textView.shouldChangeText(in: sel, replacementString: str) {
            textView.replaceCharacters(in: sel, with: str)
            textView.didChangeText()
            textView.setSelectedRange(NSRange(location: sel.location + (str as NSString).length, length: 0))
        }
    }

    public static func insertCustomDateTime(in textView: NSTextView, format: String) {
        guard textView.isEditable else { return }
        let formatter = DateFormatter()
        formatter.dateFormat = format.isEmpty ? "yyyy-MM-dd HH:mm:ss" : format
        let str = formatter.string(from: Date())
        let sel = textView.selectedRange()
        if textView.shouldChangeText(in: sel, replacementString: str) {
            textView.replaceCharacters(in: sel, with: str)
            textView.didChangeText()
            textView.setSelectedRange(NSRange(location: sel.location + (str as NSString).length, length: 0))
        }
    }

    /// Redacts text with `mask` (default `█`), preserving CRLF (`\r\n`), LF (`\n`), and CR (`\r`) line breaks.
    public static func redact(text: String, mask: Character = "█") -> String {
        var redacted = ""
        for ch in text {
            if ch.isNewline || ch == "\r" || ch == "\n" || ch == "\r\n" {
                redacted.append(ch)
            } else {
                redacted.append(mask)
            }
        }
        return redacted
    }

    /// `IDM_EDIT_REDACT_SELECTION`: Replaces selected text with `█` (or `●` when Shift is held), preserving `\r` and `\n`.
    public static func redactSelection(in textView: NSTextView, useBullet: Bool = false) {
        guard textView.isEditable else { return }
        let sel = textView.selectedRange()
        guard sel.length > 0 else { return }
        let str = textView.string as NSString
        guard NSMaxRange(sel) <= str.length else { return }
        let text = str.substring(with: sel)
        let mask: Character = useBullet ? "●" : "█"
        let redacted = redact(text: text, mask: mask)
        if textView.shouldChangeText(in: sel, replacementString: redacted) {
            textView.replaceCharacters(in: sel, with: redacted)
            textView.didChangeText()
            textView.setSelectedRange(NSRange(location: sel.location, length: (redacted as NSString).length))
        }
    }

    // MARK: - Brace Matching (`Notepad_plus::findMatchingBracePos` in `Notepad_plus.cpp` L5938-6015)

    /// Finds the matching brace pair `(braceAtCaret, braceOpposite)` for `{}` `[]` `()` at or adjacent to `caretPos`,
    /// or the nearest enclosing brace pair when `allowEnclosing` is true.
    public static func findMatchingBracePair(in nsString: NSString, at caretPos: Int, allowEnclosing: Bool = false) -> (openPos: Int, closePos: Int, caretWasAtOpen: Bool)? {
        let len = nsString.length
        guard len >= 2 else { return nil }
        let clamped = max(0, min(caretPos, len))

        let openBraces: [unichar: unichar] = [0x7B: 0x7D, 0x5B: 0x5D, 0x28: 0x29] // { -> }, [ -> ], ( -> )
        let closeBraces: [unichar: unichar] = [0x7D: 0x7B, 0x5D: 0x5B, 0x29: 0x28] // } -> {, ] -> [, ) -> (

        // Build mask of characters inside string literals or comments to prevent false matches (Scintilla StyleIndexAt guard)
        var ignored = [Bool](repeating: false, count: len)
        var idx = 0
        while idx < len {
            let ch = nsString.character(at: idx)
            if ch == 0x22 { // '"'
                ignored[idx] = true
                idx += 1
                while idx < len {
                    ignored[idx] = true
                    let c = nsString.character(at: idx)
                    if c == 0x5C { // '\'
                        idx += 1
                        if idx < len { ignored[idx] = true; idx += 1 }
                        continue
                    }
                    if c == 0x22 || c == 0x0A || c == 0x0D {
                        idx += 1
                        break
                    }
                    idx += 1
                }
            } else if ch == 0x27 { // '\''
                ignored[idx] = true
                idx += 1
                while idx < len {
                    ignored[idx] = true
                    let c = nsString.character(at: idx)
                    if c == 0x5C { // '\'
                        idx += 1
                        if idx < len { ignored[idx] = true; idx += 1 }
                        continue
                    }
                    if c == 0x27 || c == 0x0A || c == 0x0D {
                        idx += 1
                        break
                    }
                    idx += 1
                }
            } else if ch == 0x2F && idx + 1 < len { // '/'
                let nextCh = nsString.character(at: idx + 1)
                if nextCh == 0x2F { // '//'
                    ignored[idx] = true
                    ignored[idx + 1] = true
                    idx += 2
                    while idx < len {
                        let c = nsString.character(at: idx)
                        if c == 0x0A || c == 0x0D { break }
                        ignored[idx] = true
                        idx += 1
                    }
                } else if nextCh == 0x2A { // '/*'
                    ignored[idx] = true
                    ignored[idx + 1] = true
                    idx += 2
                    while idx < len {
                        ignored[idx] = true
                        let c = nsString.character(at: idx)
                        if c == 0x2A && idx + 1 < len && nsString.character(at: idx + 1) == 0x2F {
                            ignored[idx + 1] = true
                            idx += 2
                            break
                        }
                        idx += 1
                    }
                } else {
                    idx += 1
                }
            } else {
                idx += 1
            }
        }

        func scanForward(from openIdx: Int, openChar: unichar, closeChar: unichar) -> Int? {
            var depth = 1
            var i = openIdx + 1
            while i < len {
                if !ignored[i] {
                    let c = nsString.character(at: i)
                    if c == openChar {
                        depth += 1
                    } else if c == closeChar {
                        depth -= 1
                        if depth == 0 { return i }
                    }
                }
                i += 1
            }
            return nil
        }

        func scanBackward(from closeIdx: Int, openChar: unichar, closeChar: unichar) -> Int? {
            var depth = 1
            var i = closeIdx - 1
            while i >= 0 {
                if !ignored[i] {
                    let c = nsString.character(at: i)
                    if c == closeChar {
                        depth += 1
                    } else if c == openChar {
                        depth -= 1
                        if depth == 0 { return i }
                    }
                }
                i -= 1
            }
            return nil
        }

        // Upstream Notepad_plus.cpp L3120: "Priority goes to character before caret"
        let candidates = [clamped - 1, clamped].filter { $0 >= 0 && $0 < len }
        for pos in candidates {
            if ignored[pos] { continue }
            let ch = nsString.character(at: pos)
            if let closeCh = openBraces[ch], let matchIdx = scanForward(from: pos, openChar: ch, closeChar: closeCh) {
                return (openPos: pos, closePos: matchIdx, caretWasAtOpen: true)
            }
            if let openCh = closeBraces[ch], let matchIdx = scanBackward(from: pos, openChar: openCh, closeChar: ch) {
                return (openPos: matchIdx, closePos: pos, caretWasAtOpen: false)
            }
        }

        if allowEnclosing {
            // Find nearest enclosing opening brace before clamped that closes at or after clamped
            var i = min(clamped - 1, len - 1)
            while i >= 0 {
                if !ignored[i] {
                    let ch = nsString.character(at: i)
                    if let closeCh = openBraces[ch], let matchIdx = scanForward(from: i, openChar: ch, closeChar: closeCh), matchIdx >= clamped {
                        return (openPos: i, closePos: matchIdx, caretWasAtOpen: true)
                    }
                }
                i -= 1
            }
        }
        return nil
    }

    /// `IDM_SEARCH_GOTOMATCHINGBRACE` (`Cmd+B`): Jumps caret to the matching `{}` `[]` `()` brace.
    @discardableResult
    public static func goToMatchingBrace(in textView: NSTextView) -> Bool {
        let str = textView.string as NSString
        let sel = textView.selectedRange()
        guard let pair = findMatchingBracePair(in: str, at: sel.location, allowEnclosing: false) else {
            return false
        }
        let targetPos = pair.caretWasAtOpen ? pair.closePos : pair.openPos
        let targetRange = NSRange(location: targetPos, length: 0)
        textView.setSelectedRange(targetRange)
        textView.scrollRangeToVisible(targetRange)
        return true
    }

    /// `IDM_SEARCH_SELECTMATCHINGBRACES` (`Cmd+Option+B`): Selects all text between `{}` `[]` `()`.
    @discardableResult
    public static func selectAllBetweenBraces(in textView: NSTextView) -> Bool {
        let str = textView.string as NSString
        let sel = textView.selectedRange()
        guard let pair = findMatchingBracePair(in: str, at: sel.location, allowEnclosing: true) else {
            return false
        }
        let innerRange = NSRange(location: pair.openPos + 1, length: max(0, pair.closePos - pair.openPos - 1))
        let outerRange = NSRange(location: pair.openPos, length: pair.closePos - pair.openPos + 1)
        let targetRange = (sel == innerRange) ? outerRange : innerRange
        textView.setSelectedRange(targetRange)
        textView.scrollRangeToVisible(targetRange)
        return true
    }

    // MARK: - Helpers
    public static func getWordRange(at pos: Int, in string: NSString) -> NSRange {
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

extension String {
    public func nppLines() -> [String] {
        var result: [String] = []
        self.enumerateLines { line, _ in
            result.append(line)
        }
        return result
    }
}
