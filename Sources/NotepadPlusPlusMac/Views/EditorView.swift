import SwiftUI
import AppKit

public struct NppEditorView: NSViewRepresentable {
    @ObservedObject var document: NppDocument
    @ObservedObject var workspace: NppWorkspace

    public init(document: NppDocument, workspace: NppWorkspace) {
        self.document = document
        self.workspace = workspace
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    public func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = !workspace.isWordWrapEnabled
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder

        let textView = NppTextView(frame: .zero)
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.editorCoordinator = context.coordinator
        textView.workspace = workspace
        textView.isEditable = !document.isReadOnly && !workspace.isAllDocumentsReadOnly

        let targetFont = NppWorkspace.resolveFont(name: workspace.fontFamily, size: workspace.fontSize)
        textView.font = targetFont
        textView.string = document.content

        // Apply Notepad++ Theme Colors
        let theme = workspace.currentTheme
        textView.backgroundColor = theme.backgroundColor
        textView.insertionPointColor = theme.foregroundColor
        textView.textColor = theme.foregroundColor
        textView.typingAttributes = [
            .font: targetFont,
            .foregroundColor: theme.foregroundColor
        ]

        // Line wrap setup
        configureWordWrap(textView: textView, scrollView: scrollView, enabled: workspace.isWordWrapEnabled)

        scrollView.documentView = textView

        // Attach Line Number Gutter
        let gutter = NppGutterView(textView: textView)
        gutter.document = document
        gutter.workspace = workspace
        gutter.gutterBackground = theme.gutterBackground
        gutter.gutterForeground = theme.gutterForeground
        scrollView.verticalRulerView = gutter
        scrollView.hasVerticalRuler = true
        scrollView.rulersVisible = workspace.showLineNumbers
        gutter.setupScrollAndLayoutObservers()

        context.coordinator.textView = textView
        context.coordinator.gutter = gutter
        workspace.activeTextView = textView

        // Initial syntax highlighting
        if let textStorage = textView.textStorage {
            NppSyntaxHighlighter.highlight(
                textStorage: textStorage,
                language: document.language,
                isDarkMode: theme.isDark,
                baseFont: targetFont,
                theme: theme
            )
        }

        return scrollView
    }

    public func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let textView = context.coordinator.textView else { return }

        if workspace.activeDocumentId == document.id {
            workspace.activeTextView = textView
        }

        let effectiveEditable = !document.isReadOnly && !workspace.isAllDocumentsReadOnly
        if textView.isEditable != effectiveEditable {
            textView.isEditable = effectiveEditable
        }

        context.coordinator.gutter?.document = document
        context.coordinator.gutter?.workspace = workspace
        context.coordinator.gutter?.needsDisplay = true

        // Apply Theme Colors
        let theme = workspace.currentTheme
        if textView.backgroundColor != theme.backgroundColor {
            textView.backgroundColor = theme.backgroundColor
            textView.insertionPointColor = theme.foregroundColor
            textView.textColor = theme.foregroundColor
            context.coordinator.applyHighlighting()
        }
        context.coordinator.gutter?.gutterBackground = theme.gutterBackground
        context.coordinator.gutter?.gutterForeground = theme.gutterForeground
        context.coordinator.gutter?.needsDisplay = true

        // Update language highlighting if language changed from menu or status bar
        if context.coordinator.lastLanguage != document.language {
            context.coordinator.lastLanguage = document.language
            context.coordinator.applyHighlighting()
        }

        // Update content if changed externally (e.g., encoding conversion, reload or edit operations)
        if textView.string != document.content {
            let selectedRange = textView.selectedRange()
            let newLen = (document.content as NSString).length
            textView.string = document.content
            let safeLoc = min(selectedRange.location, newLen)
            let safeLen = min(selectedRange.length, max(0, newLen - safeLoc))
            textView.setSelectedRange(NSRange(location: safeLoc, length: safeLen))
            context.coordinator.applyHighlighting()
            context.coordinator.gutter?.needsDisplay = true
        }

        // Update font family and size
        let targetFont = NppWorkspace.resolveFont(name: workspace.fontFamily, size: workspace.fontSize)
        if textView.font != targetFont {
            textView.font = targetFont
            context.coordinator.applyHighlighting()
            context.coordinator.gutter?.needsDisplay = true
            textView.needsDisplay = true
        }

        // Update line numbers gutter visibility
        if scrollView.rulersVisible != workspace.showLineNumbers {
            scrollView.rulersVisible = workspace.showLineNumbers
        }

        // Update padding margins (Notepad++ Margins/Border/Edge preference)
        let targetPadding = NSSize(width: CGFloat(workspace.paddingLeft), height: 0)
        if textView.textContainerInset != targetPadding {
            textView.textContainerInset = targetPadding
        }

        // Update word wrap
        if context.coordinator.lastWordWrap != workspace.isWordWrapEnabled {
            context.coordinator.lastWordWrap = workspace.isWordWrapEnabled
            configureWordWrap(textView: textView, scrollView: scrollView, enabled: workspace.isWordWrapEnabled)
        }

        // Jump to match from Find All Results panel
        if let match = workspace.targetJumpMatch, match.documentId == document.id {
            let targetRange = NSRange(location: match.charPosition, length: match.matchLength)
            if NSMaxRange(targetRange) <= (textView.string as NSString).length {
                textView.setSelectedRange(targetRange)
                textView.scrollRangeToVisible(targetRange)
            }
            DispatchQueue.main.async {
                self.workspace.targetJumpMatch = nil
            }
        }

        textView.needsDisplay = true
        context.coordinator.gutter?.needsDisplay = true
    }

    private func configureWordWrap(textView: NSTextView, scrollView: NSScrollView, enabled: Bool) {
        if enabled {
            scrollView.hasHorizontalScroller = false
            textView.isHorizontallyResizable = false
            textView.autoresizingMask = [.width]
            textView.textContainer?.containerSize = NSSize(width: scrollView.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
            textView.textContainer?.widthTracksTextView = true
        } else {
            scrollView.hasHorizontalScroller = true
            textView.isHorizontallyResizable = true
            textView.autoresizingMask = [.width, .height]
            textView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
            textView.textContainer?.widthTracksTextView = false
        }
    }

    public class Coordinator: NSObject, NSTextViewDelegate {
        var parent: NppEditorView
        weak var textView: NppTextView?
        weak var gutter: NppGutterView?
        var lastWordWrap: Bool = false
        var lastLanguage: String = ""
        var smartHighlightedRanges: [NSRange] = []
        var lastSmartHighlightedWord: String = ""

        init(_ parent: NppEditorView) {
            self.parent = parent
            self.lastWordWrap = parent.workspace.isWordWrapEnabled
            self.lastLanguage = parent.document.language
        }

        public func textDidChange(_ notification: Notification) {
            guard let tv = textView else { return }
            parent.document.content = tv.string
            parent.document.isDirty = true
            gutter?.needsDisplay = true
            updateCaretPosition()
            applyHighlighting()
        }

        public func textViewDidChangeSelection(_ notification: Notification) {
            updateCaretPosition()
            gutter?.needsDisplay = true
            textView?.needsDisplay = true
            updateSmartHighlighting()
        }

        func updateSmartHighlighting() {
            guard let tv = textView, let ts = tv.textStorage else { return }
            let sel = tv.selectedRange()
            let str = tv.string as NSString

            // Clear previous smart highlights and restore any manual token styles
            if !smartHighlightedRanges.isEmpty {
                ts.beginEditing()
                for r in smartHighlightedRanges {
                    if NSMaxRange(r) <= ts.length {
                        ts.removeAttribute(.backgroundColor, range: r)
                    }
                }
                for (styleIdx, tokenRanges) in parent.document.styledTokenRanges {
                    let styleColor = NppWorkspace.tokenStyleColor(for: styleIdx)
                    for r in tokenRanges where NSMaxRange(r) <= ts.length {
                        ts.addAttribute(.backgroundColor, value: styleColor, range: r)
                    }
                }
                ts.endEditing()
                smartHighlightedRanges.removeAll()
                lastSmartHighlightedWord = ""
            }

            guard sel.length > 0 && NSMaxRange(sel) <= str.length else { return }

            let selectedWord = str.substring(with: sel).trimmingCharacters(in: .whitespacesAndNewlines)
            guard selectedWord.count >= 1, !selectedWord.contains("\n"), !selectedWord.contains("\r") else { return }

            // Notepad++ Smart Highlight: find all occurrences of selectedWord in document
            var ranges: [NSRange] = []
            var searchRange = NSRange(location: 0, length: str.length)

            while searchRange.location < str.length {
                let found = str.range(of: selectedWord, options: [.literal], range: searchRange)
                if found.location == NSNotFound { break }
                ranges.append(found)
                let nextPos = found.location + max(1, found.length)
                searchRange = NSRange(location: nextPos, length: str.length - nextPos)
            }

            if ranges.count > 1 {
                // Notepad++ signature smart highlight: mint green
                let isDark = tv.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                let highlightColor = isDark
                    ? NSColor(calibratedRed: 0.15, green: 0.55, blue: 0.35, alpha: 0.55)
                    : NSColor(calibratedRed: 0.50, green: 0.95, blue: 0.65, alpha: 0.60)

                ts.beginEditing()
                for r in ranges {
                    ts.addAttribute(.backgroundColor, value: highlightColor, range: r)
                }
                ts.endEditing()
                smartHighlightedRanges = ranges
                lastSmartHighlightedWord = selectedWord
            }
        }

        func updateCaretPosition() {
            guard let tv = textView else { return }
            let sel = tv.selectedRange()
            let str = tv.string as NSString

            parent.document.cursorPos = sel.location
            parent.document.selectionLength = sel.length

            if sel.location <= str.length {
                var line = 1
                var lineStart = 0
                for i in 0..<min(sel.location, str.length) {
                    if str.character(at: i) == 10 { // LF '\n'
                        line += 1
                        lineStart = i + 1
                    }
                }
                let col = sel.location - lineStart + 1
                parent.document.cursorLine = line
                parent.document.cursorCol = col
            }
        }

        func applyHighlighting() {
            guard let tv = textView, let ts = tv.textStorage else { return }
            let isDark = tv.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            NppSyntaxHighlighter.highlight(textStorage: ts, language: parent.document.language, isDarkMode: isDark, baseFont: tv.font, theme: parent.workspace.currentTheme)
            if !parent.document.styledTokenRanges.isEmpty {
                ts.beginEditing()
                for (styleIdx, tokenRanges) in parent.document.styledTokenRanges {
                    let styleColor = NppWorkspace.tokenStyleColor(for: styleIdx)
                    for r in tokenRanges where NSMaxRange(r) <= ts.length {
                        ts.addAttribute(.backgroundColor, value: styleColor, range: r)
                    }
                }
                ts.endEditing()
            }
        }
    }
}

public final class NppTextView: NSTextView {
    weak var editorCoordinator: NppEditorView.Coordinator?
    public weak var workspace: NppWorkspace?

    // MARK: - Auto-Completion Matched Pairs Tracking (Notepad++ / Scintilla Parity)
    public struct MatchedCharInserted: Equatable {
        public let openChar: Character
        public let closeChar: Character
        public var openPos: Int

        public init(openChar: Character, closeChar: Character, openPos: Int) {
            self.openChar = openChar
            self.closeChar = closeChar
            self.openPos = openPos
        }
    }
    public var insertedMatchedChars: [MatchedCharInserted] = []

    public override func mouseDown(with event: NSEvent) {
        insertedMatchedChars.removeAll()
        super.mouseDown(with: event)
    }

    public func cleanInvalidMatchedChars(caretPos: Int, typedChar: Character? = nil) {
        if typedChar == "\n" || typedChar == "\r" {
            insertedMatchedChars.removeAll()
            return
        }
        let text = self.string as NSString
        guard text.length > 0 else {
            insertedMatchedChars.removeAll()
            return
        }
        let safeCaret = min(caretPos, text.length)
        let caretLineRange = text.lineRange(for: NSRange(location: safeCaret, length: 0))

        insertedMatchedChars.removeAll { item in
            guard item.openPos < text.length else { return true }
            let itemLineRange = text.lineRange(for: NSRange(location: item.openPos, length: 0))
            if itemLineRange != caretLineRange {
                return true
            }
            if safeCaret <= item.openPos {
                return true
            }
            return false
        }
    }

    private func isCharNextBlankOrCloseSymbol(at pos: Int, text: NSString) -> Bool {
        if pos >= text.length { return true }
        let c = text.character(at: pos)
        return c == 32 /* space */ || c == 9 /* tab */ || c == 10 /* LF */ || c == 13 /* CR */ ||
               c == 41 /* ) */ || c == 93 /* ] */ || c == 125 /* } */ || c == 59 /* ; */ || c == 44 /* , */
    }

    public func searchMatchedCloseChar(startChar: Character, endChar: Character, caretPos: Int) -> Int? {
        guard !insertedMatchedChars.isEmpty else { return nil }
        let text = self.string as NSString
        guard caretPos <= text.length else { return nil }
        let caretLineRange = text.lineRange(for: NSRange(location: caretPos, length: 0))
        let lineEnd = NSMaxRange(caretLineRange)

        for i in (0..<insertedMatchedChars.count).reversed() {
            let item = insertedMatchedChars[i]
            if item.openChar == startChar && item.openPos < caretPos {
                let itemLineRange = text.lineRange(for: NSRange(location: item.openPos, length: 0))
                if itemLineRange == caretLineRange {
                    for j in caretPos..<lineEnd {
                        let ch = Character(UnicodeScalar(text.character(at: j))!)
                        if ch != " " && ch != "\t" {
                            if ch == endChar {
                                insertedMatchedChars.remove(at: i)
                                return j
                            } else {
                                insertedMatchedChars.remove(at: i)
                                return nil
                            }
                        }
                    }
                } else {
                    insertedMatchedChars.remove(at: i)
                }
            }
        }
        return nil
    }

    private func handleSmartPairDeleteBackward() -> Bool {
        let range = self.selectedRange()
        guard range.length == 0, range.location > 0 else { return false }
        let text = self.string as NSString
        guard range.location < text.length else { return false }

        let prevChar = Character(UnicodeScalar(text.character(at: range.location - 1))!)
        let nextChar = Character(UnicodeScalar(text.character(at: range.location))!)

        if let idx = insertedMatchedChars.lastIndex(where: { $0.openPos == range.location - 1 && $0.openChar == prevChar && $0.closeChar == nextChar }) {
            insertedMatchedChars.remove(at: idx)
            let pairRange = NSRange(location: range.location - 1, length: 2)
            if self.shouldChangeText(in: pairRange, replacementString: "") {
                self.replaceCharacters(in: pairRange, with: "")
                self.didChangeText()
                return true
            }
        }
        return false
    }

    private var resolvedWorkspace: NppWorkspace? {
        editorCoordinator?.parent.workspace ?? workspace
    }

    private var resolvedDocument: NppDocument? {
        editorCoordinator?.parent.document ?? resolvedWorkspace?.activeDocument
    }

    public override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        if result, let ws = resolvedWorkspace {
            ws.activeTextView = self
        }
        return result
    }

    // Drag & Drop: Dragging files into Notepad++ editor opens them in tabs
    public override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        let pboard = sender.draggingPasteboard
        if let types = pboard.types, types.contains(.fileURL) {
            return .copy
        }
        return super.draggingEntered(sender)
    }

    public override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let pboard = sender.draggingPasteboard
        if let urls = pboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL], !urls.isEmpty {
            for url in urls {
                resolvedWorkspace?.openFile(url: url)
            }
            return true
        }
        return super.performDragOperation(sender)
    }

    public override func keyDown(with event: NSEvent) {
        guard self.isEditable else {
            super.keyDown(with: event)
            return
        }

        // Tab key: indent operations or spaces/tabs according to workspace.tabSize & replaceTabBySpace
        if event.keyCode == 48 && !event.modifierFlags.contains(.control) {
            let count = resolvedWorkspace?.tabSize ?? 4
            let replaceBySpaces = resolvedWorkspace?.replaceTabBySpace ?? true
            if event.modifierFlags.contains(.shift) {
                NppEditOperations.decreaseLineIndent(in: self, spaceCount: count)
                return
            } else {
                if self.selectedRange().length > 0 {
                    NppEditOperations.increaseLineIndent(in: self, spaceCount: count, useTabs: !replaceBySpaces)
                    return
                } else {
                    let strToInsert = replaceBySpaces ? String(repeating: " ", count: count) : "\t"
                    self.insertText(strToInsert, replacementRange: self.selectedRange())
                    return
                }
            }
        }

        // Duplicate Line: Cmd + D
        if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "d" {
            resolvedWorkspace?.recordMacroStep(.duplicateLine)
            NppEditOperations.duplicateLine(in: self)
            return
        }

        // Move Line Up: Option + Up
        if event.modifierFlags.contains(.option) && event.keyCode == 126 {
            resolvedWorkspace?.recordMacroStep(.moveLineUp)
            NppEditOperations.moveLineUp(in: self)
            return
        }

        // Move Line Down: Option + Down
        if event.modifierFlags.contains(.option) && event.keyCode == 125 {
            resolvedWorkspace?.recordMacroStep(.moveLineDown)
            NppEditOperations.moveLineDown(in: self)
            return
        }

        // Join Lines: Cmd + J
        if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "j" {
            resolvedWorkspace?.recordMacroStep(.joinLines)
            NppEditOperations.joinLines(in: self)
            return
        }

        // Toggle Comment: Cmd + /
        if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "/" {
            resolvedWorkspace?.recordMacroStep(.toggleComment)
            if let lang = resolvedDocument?.language {
                NppEditOperations.toggleComment(in: self, language: lang)
            }
            return
        }

        // Auto-completion of delimiters & Mistake Compensation (Notepad++ Auto-Completion Preference)
        if !event.modifierFlags.contains(.command) && !event.modifierFlags.contains(.control),
           let ws = resolvedWorkspace,
           let chars = event.characters, chars.count == 1 {
            let ch = chars
            let text = self.string as NSString
            let range = self.selectedRange()

            // 1. Closing delimiter handling (mistake compensation):
            // When the user reflexively types a closing character matching an actively auto-inserted pair
            // on the current line, step over the closing character to prevent duplicates like int main()).
            // If there is NO pending auto-inserted pair (or user types a 2nd time), it falls through
            // and types normally so intentional input is NEVER blocked.
            if range.length == 0 {
                if ch == ")" && ws.autoInsertParen {
                    if let targetPos = searchMatchedCloseChar(startChar: "(", endChar: ")", caretPos: range.location) {
                        self.setSelectedRange(NSRange(location: targetPos + 1, length: 0))
                        return
                    }
                }
                if ch == "]" && ws.autoInsertBracket {
                    if let targetPos = searchMatchedCloseChar(startChar: "[", endChar: "]", caretPos: range.location) {
                        self.setSelectedRange(NSRange(location: targetPos + 1, length: 0))
                        return
                    }
                }
                if ch == "}" && ws.autoInsertBrace {
                    if let targetPos = searchMatchedCloseChar(startChar: "{", endChar: "}", caretPos: range.location) {
                        self.setSelectedRange(NSRange(location: targetPos + 1, length: 0))
                        return
                    }
                }
                if ch == "\"" && ws.autoInsertDoubleQuote {
                    if let targetPos = searchMatchedCloseChar(startChar: "\"", endChar: "\"", caretPos: range.location) {
                        self.setSelectedRange(NSRange(location: targetPos + 1, length: 0))
                        return
                    }
                }
                if ch == "'" && ws.autoInsertSingleQuote {
                    if let targetPos = searchMatchedCloseChar(startChar: "'", endChar: "'", caretPos: range.location) {
                        self.setSelectedRange(NSRange(location: targetPos + 1, length: 0))
                        return
                    }
                }
                if ch == ">" && ws.autoInsertHtmlTag {
                    if let targetPos = searchMatchedCloseChar(startChar: "<", endChar: ">", caretPos: range.location) {
                        self.setSelectedRange(NSRange(location: targetPos + 1, length: 0))
                        return
                    }
                }

                // 2. Opening delimiter auto-insertion:
                // Only auto-insert the matching closing character if the next character is blank or close symbol,
                // matching upstream Notepad++ ScintillaComponent/AutoCompletion.cpp:900
                if ch == "(" && ws.autoInsertParen {
                    if isCharNextBlankOrCloseSymbol(at: range.location, text: text) {
                        self.insertText("()", replacementRange: range)
                        self.setSelectedRange(NSRange(location: range.location + 1, length: 0))
                        insertedMatchedChars.append(MatchedCharInserted(openChar: "(", closeChar: ")", openPos: range.location))
                        return
                    }
                }
                if ch == "[" && ws.autoInsertBracket {
                    if isCharNextBlankOrCloseSymbol(at: range.location, text: text) {
                        self.insertText("[]", replacementRange: range)
                        self.setSelectedRange(NSRange(location: range.location + 1, length: 0))
                        insertedMatchedChars.append(MatchedCharInserted(openChar: "[", closeChar: "]", openPos: range.location))
                        return
                    }
                }
                if ch == "{" && ws.autoInsertBrace {
                    if isCharNextBlankOrCloseSymbol(at: range.location, text: text) {
                        self.insertText("{}", replacementRange: range)
                        self.setSelectedRange(NSRange(location: range.location + 1, length: 0))
                        insertedMatchedChars.append(MatchedCharInserted(openChar: "{", closeChar: "}", openPos: range.location))
                        return
                    }
                }
                if ch == "\"" && ws.autoInsertDoubleQuote {
                    if isCharNextBlankOrCloseSymbol(at: range.location, text: text) {
                        self.insertText("\"\"", replacementRange: range)
                        self.setSelectedRange(NSRange(location: range.location + 1, length: 0))
                        insertedMatchedChars.append(MatchedCharInserted(openChar: "\"", closeChar: "\"", openPos: range.location))
                        return
                    }
                }
                if ch == "'" && ws.autoInsertSingleQuote {
                    if isCharNextBlankOrCloseSymbol(at: range.location, text: text) {
                        self.insertText("''", replacementRange: range)
                        self.setSelectedRange(NSRange(location: range.location + 1, length: 0))
                        insertedMatchedChars.append(MatchedCharInserted(openChar: "'", closeChar: "'", openPos: range.location))
                        return
                    }
                }
            }
        }

        if let chars = event.characters, !event.modifierFlags.contains(.command), !event.modifierFlags.contains(.control) {
            // Headless / detached view support: Cocoa requires an active NSWindow to route inputContext.
            // When running headless in automated tests without a window, insert text directly.
            if self.window == nil {
                self.insertText(chars, replacementRange: self.selectedRange())
                cleanInvalidMatchedChars(caretPos: self.selectedRange().location, typedChar: chars.first)
                return
            }
        }

        super.keyDown(with: event)
        if let chars = event.characters, let first = chars.first {
            cleanInvalidMatchedChars(caretPos: self.selectedRange().location, typedChar: first)
        }
    }

    public override func insertText(_ string: Any, replacementRange: NSRange) {
        if let str = string as? String {
            resolvedWorkspace?.recordMacroStep(.insertText(str))
        } else if let attr = string as? NSAttributedString {
            resolvedWorkspace?.recordMacroStep(.insertText(attr.string))
        }
        super.insertText(string, replacementRange: replacementRange)
    }

    public override func doCommand(by selector: Selector) {
        if selector == #selector(NSStandardKeyBindingResponding.deleteBackward(_:)) {
            if handleSmartPairDeleteBackward() {
                if let ws = resolvedWorkspace, ws.isMacroRecording {
                    ws.recordMacroStep(.deleteBackward)
                }
                return
            }
        }
        if selector == #selector(NSStandardKeyBindingResponding.insertNewline(_:)) {
            insertedMatchedChars.removeAll()
        }

        if let ws = resolvedWorkspace, ws.isMacroRecording {
            switch selector {
            case #selector(NSStandardKeyBindingResponding.deleteBackward(_:)):
                ws.recordMacroStep(.deleteBackward)
            case #selector(NSStandardKeyBindingResponding.deleteForward(_:)):
                ws.recordMacroStep(.deleteForward)
            case #selector(NSStandardKeyBindingResponding.insertNewline(_:)):
                ws.recordMacroStep(.insertNewline)
            case #selector(NSStandardKeyBindingResponding.insertTab(_:)):
                ws.recordMacroStep(.insertTab)
            case #selector(NSStandardKeyBindingResponding.moveLeft(_:)):
                ws.recordMacroStep(.moveLeft)
            case #selector(NSStandardKeyBindingResponding.moveRight(_:)):
                ws.recordMacroStep(.moveRight)
            case #selector(NSStandardKeyBindingResponding.moveUp(_:)):
                ws.recordMacroStep(.moveUp)
            case #selector(NSStandardKeyBindingResponding.moveDown(_:)):
                ws.recordMacroStep(.moveDown)
            case #selector(NSStandardKeyBindingResponding.moveToBeginningOfLine(_:)):
                ws.recordMacroStep(.moveToBeginningOfLine)
            case #selector(NSStandardKeyBindingResponding.moveToEndOfLine(_:)):
                ws.recordMacroStep(.moveToEndOfLine)
            default:
                break
            }
        }
        super.doCommand(by: selector)

        switch selector {
        case #selector(NSStandardKeyBindingResponding.moveUp(_:)),
             #selector(NSStandardKeyBindingResponding.moveDown(_:)),
             #selector(NSStandardKeyBindingResponding.moveToBeginningOfLine(_:)),
             #selector(NSStandardKeyBindingResponding.moveToEndOfLine(_:)):
            cleanInvalidMatchedChars(caretPos: self.selectedRange().location)
        default:
            break
        }
    }

    public override func insertTab(_ sender: Any?) {
        guard self.isEditable else { return }
        let tabSize = resolvedWorkspace?.tabSize ?? 4
        if self.selectedRange().length > 0 {
            NppEditOperations.increaseLineIndent(in: self, spaceCount: tabSize, useTabs: true)
        } else {
            super.insertTab(sender)
        }
    }

    public override func insertBacktab(_ sender: Any?) {
        guard self.isEditable else { return }
        let tabSize = resolvedWorkspace?.tabSize ?? 4
        NppEditOperations.decreaseLineIndent(in: self, spaceCount: tabSize)
    }

    public override func cut(_ sender: Any?) {
        resolvedWorkspace?.recordMacroStep(.cut)
        super.cut(sender)
        if let clip = NSPasteboard.general.string(forType: .string) {
            resolvedWorkspace?.addToClipboardHistory(clip)
        }
    }

    public override func copy(_ sender: Any?) {
        resolvedWorkspace?.recordMacroStep(.copy)
        super.copy(sender)
        if let clip = NSPasteboard.general.string(forType: .string) {
            resolvedWorkspace?.addToClipboardHistory(clip)
        }
    }

    public override func paste(_ sender: Any?) {
        resolvedWorkspace?.recordMacroStep(.paste)
        super.paste(sender)
    }

    public override func selectAll(_ sender: Any?) {
        resolvedWorkspace?.recordMacroStep(.selectAll)
        super.selectAll(sender)
    }

    // MARK: - Notepad++ Caret Width (SCI_SETCARETWIDTH: 1, 2, 3)
    public override func drawInsertionPoint(in rect: NSRect, color: NSColor, turnedOn flag: Bool) {
        guard flag else { return }
        let caretW = CGFloat(max(1, resolvedWorkspace?.caretWidth ?? 1))
        var caretRect = rect
        caretRect.size.width = caretW
        color.set()
        caretRect.fill()
    }

    // MARK: - Notepad++ Active Line Highlight Bar (drawn behind text)
    public override func drawBackground(in rect: NSRect) {
        super.drawBackground(in: rect)

        let sel = self.selectedRange()
        let shouldHighlightLine = editorCoordinator?.parent.workspace.highlightCurrentLine ?? true
        let lineIndicatorMode = editorCoordinator?.parent.workspace.currentLineIndicator ?? 1
        if shouldHighlightLine && lineIndicatorMode != 0 && sel.length == 0, let layoutManager = self.layoutManager {
            let str = self.string as NSString
            var lineRect: NSRect
            if str.length > 0 && layoutManager.numberOfGlyphs > 0 {
                let charPos = min(sel.location, max(0, str.length - 1))
                let glyphIdx = min(layoutManager.glyphIndexForCharacter(at: charPos), layoutManager.numberOfGlyphs - 1)
                if sel.location == str.length && str.character(at: str.length - 1) == 10 && layoutManager.extraLineFragmentRect.height > 0 {
                    lineRect = layoutManager.extraLineFragmentRect
                } else {
                    lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIdx, effectiveRange: nil)
                }
            } else if layoutManager.extraLineFragmentRect.height > 0 {
                lineRect = layoutManager.extraLineFragmentRect
            } else {
                let h = (self.font?.pointSize ?? 13.0) + 5.0
                lineRect = NSRect(x: 0, y: self.textContainerOrigin.y, width: self.bounds.width, height: h)
            }
            lineRect.origin.x = 0
            lineRect.size.width = max(self.bounds.width, self.visibleRect.width)

            let theme = editorCoordinator?.parent.workspace.currentTheme
            let lineHighlightColor = theme?.activeLineColor ?? NSColor(calibratedRed: 0.17, green: 0.18, blue: 0.20, alpha: 0.95)

            if lineIndicatorMode == 1 {
                // Background Highlight
                lineHighlightColor.setFill()
                NSBezierPath(rect: lineRect).fill()
            } else if lineIndicatorMode == 2 {
                // Frame Outline
                let frameWidth = CGFloat(max(1, editorCoordinator?.parent.workspace.currentLineFrameWidth ?? 1))
                let strokeRect = lineRect.insetBy(dx: 0.5, dy: 0.5)
                lineHighlightColor.setStroke()
                let path = NSBezierPath(rect: strokeRect)
                path.lineWidth = frameWidth
                path.stroke()
            }
        }
    }

    public override func draw(_ dirtyRect: NSRect) {
        // 1. Draw base text view contents (background and text glyphs)
        super.draw(dirtyRect)

        // 2. Vertical Edge Guideline (Notepad++ Scintilla Edge Column)
        if let ws = editorCoordinator?.parent.workspace, !ws.noEdge && ws.verticalEdgeMode > 0 {
            let col = ws.verticalEdgeColumn
            let font = self.font ?? NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
            let charWidth = font.maximumAdvancement.width
            let edgeX = self.textContainerOrigin.x + (charWidth * CGFloat(col))
            if ws.verticalEdgeMode == 1 {
                let edgeColor = (ws.currentTheme.isDark)
                    ? NSColor(calibratedWhite: 0.32, alpha: 0.8)
                    : NSColor(calibratedWhite: 0.78, alpha: 0.8)
                edgeColor.setStroke()
                let path = NSBezierPath()
                path.move(to: NSPoint(x: edgeX, y: dirtyRect.minY))
                path.line(to: NSPoint(x: edgeX, y: dirtyRect.maxY))
                path.lineWidth = 1.0
                path.stroke()
            } else if ws.verticalEdgeMode == 2 {
                let edgeBg = (ws.currentTheme.isDark)
                    ? NSColor(calibratedWhite: 0.18, alpha: 0.35)
                    : NSColor(calibratedWhite: 0.90, alpha: 0.35)
                edgeBg.setFill()
                let bgRect = NSRect(x: edgeX, y: dirtyRect.minY, width: max(0, dirtyRect.maxX - edgeX), height: dirtyRect.height)
                NSBezierPath(rect: bgRect).fill()
            }
        }

        // 3. Draw Notepad++ Invisible / Whitespace Characters on top so they are never erased
        if let ws = editorCoordinator?.parent.workspace,
           ws.showInvisibleCharacters || ws.showSpaceAndTab || ws.showEndOfLine || ws.showNonPrintingCharacters {
            drawInvisibleCharacters(in: dirtyRect)
        }
    }

    private func drawInvisibleCharacters(in dirtyRect: NSRect) {
        guard let layoutManager = self.layoutManager, let textContainer = self.textContainer,
              let ws = editorCoordinator?.parent.workspace else { return }
        let drawWS = ws.showInvisibleCharacters || ws.showSpaceAndTab
        let drawEOL = ws.showInvisibleCharacters || ws.showEndOfLine
        let str = self.string as NSString
        guard str.length > 0 else { return }

        let containerOrigin = self.textContainerOrigin
        let containerRect = dirtyRect.offsetBy(dx: -containerOrigin.x, dy: -containerOrigin.y)
        let glyphRange = layoutManager.glyphRange(forBoundingRect: containerRect, in: textContainer)
        let charRange = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)

        let theme = editorCoordinator?.parent.workspace.currentTheme
        let color: NSColor = (theme?.isDark ?? true)
            ? NSColor(calibratedRed: 0.95, green: 0.62, blue: 0.32, alpha: 0.85) // Notepad++ Scintilla Amber
            : NSColor(calibratedRed: 0.85, green: 0.45, blue: 0.15, alpha: 0.85) // Notepad++ Scintilla Dark Amber

        let currentFont = self.font ?? NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        let charWidth = currentFont.maximumAdvancement.width
        let pilcrowFont = NSFont.systemFont(ofSize: max(9.0, currentFont.pointSize - 3.0), weight: .bold)

        let end = min(NSMaxRange(charRange), str.length)
        var i = charRange.location
        while i < end {
            let ch = str.character(at: i)
            let gIdx = layoutManager.glyphIndexForCharacter(at: i)
            let loc = layoutManager.location(forGlyphAt: gIdx)
            let lineRect = layoutManager.lineFragmentRect(forGlyphAt: gIdx, effectiveRange: nil)

            let x = containerOrigin.x + lineRect.origin.x + loc.x
            let y = containerOrigin.y + lineRect.origin.y
            let midY = y + (lineRect.height / 2.0)

            if ch == 32 && drawWS { // Space -> Middle dot '·'
                let dotRadius: CGFloat = 1.4
                let dotCenter = NSPoint(x: x + (charWidth / 2.0), y: midY)
                let dotRect = NSRect(x: dotCenter.x - dotRadius, y: dotCenter.y - dotRadius, width: dotRadius * 2, height: dotRadius * 2)
                color.setFill()
                NSBezierPath(ovalIn: dotRect).fill()
            } else if ch == 9 && drawWS { // Tab -> Arrow '→'
                let nextGIdx = gIdx + 1
                var tabEnd = x + (charWidth * 3.0)
                if nextGIdx < layoutManager.numberOfGlyphs {
                    let nextLoc = layoutManager.location(forGlyphAt: nextGIdx)
                    let nextLine = layoutManager.lineFragmentRect(forGlyphAt: nextGIdx, effectiveRange: nil)
                    if abs(nextLine.origin.y - lineRect.origin.y) < 2.0 && nextLoc.x > loc.x {
                        tabEnd = containerOrigin.x + lineRect.origin.x + nextLoc.x - 3.0
                    }
                }
                let arrowPath = NSBezierPath()
                arrowPath.move(to: NSPoint(x: x + 2.0, y: midY))
                arrowPath.line(to: NSPoint(x: tabEnd, y: midY))
                arrowPath.line(to: NSPoint(x: tabEnd - 3.5, y: midY - 2.5))
                arrowPath.move(to: NSPoint(x: tabEnd, y: midY))
                arrowPath.line(to: NSPoint(x: tabEnd - 3.5, y: midY + 2.5))
                arrowPath.lineWidth = 1.1
                color.setStroke()
                arrowPath.stroke()
            } else if ch == 10 && drawEOL { // LF -> '¶'
                let isCRLF = (i > 0 && str.character(at: i - 1) == 13)
                let eolText = isCRLF ? "CRLF" : "¶"
                let eolFont = isCRLF ? NSFont.systemFont(ofSize: 8.5, weight: .bold) : pilcrowFont
                let attrs: [NSAttributedString.Key: Any] = [.font: eolFont, .foregroundColor: color]
                let eolY = y + (lineRect.height - eolFont.pointSize) / 2.0 - 0.5
                eolText.draw(at: NSPoint(x: x + 2.0, y: eolY), withAttributes: attrs)
            } else if ch == 13 && drawEOL { // CR alone
                if i + 1 >= str.length || str.character(at: i + 1) != 10 {
                    let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 8.5, weight: .bold), .foregroundColor: color]
                    let eolY = y + (lineRect.height - 8.5) / 2.0 - 0.5
                    "CR".draw(at: NSPoint(x: x + 2.0, y: eolY), withAttributes: attrs)
                }
            }
            i += 1
        }
    }

    // MARK: - Notepad++ Right Click Context Menu (Scintilla Edit Zone)
    public override func menu(for event: NSEvent) -> NSMenu? {
        let tr = { (key: String) -> String in
            self.resolvedWorkspace?.tr(key) ?? key
        }
        let menu = NSMenu(title: "Context Menu")

        // 1. Basic Edit
        menu.addItem(withTitle: tr("Undo"), action: Selector(("undo:")), keyEquivalent: "z")
        menu.addItem(withTitle: tr("Redo"), action: Selector(("redo:")), keyEquivalent: "Z")
        menu.addItem(NSMenuItem.separator())

        menu.addItem(withTitle: tr("Cut"), action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        menu.addItem(withTitle: tr("Copy"), action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        menu.addItem(withTitle: tr("Paste"), action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        menu.addItem(withTitle: tr("Delete"), action: #selector(NSText.delete(_:)), keyEquivalent: "")
        menu.addItem(withTitle: tr("Select All"), action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        menu.addItem(NSMenuItem.separator())

        // 2. Notepad++ Style Token Occurrence Submenu
        let styleMenuItem = NSMenuItem(title: tr("Style all occurrences of token"), action: nil, keyEquivalent: "")
        let styleMenu = NSMenu(title: tr("Style all occurrences of token"))
        let style1 = NSMenuItem(title: tr("Using 1st Style"), action: #selector(contextStyle1), keyEquivalent: "")
        style1.target = self
        styleMenu.addItem(style1)
        let style2 = NSMenuItem(title: tr("Using 2nd Style"), action: #selector(contextStyle2), keyEquivalent: "")
        style2.target = self
        styleMenu.addItem(style2)
        let style3 = NSMenuItem(title: tr("Using 3rd Style"), action: #selector(contextStyle3), keyEquivalent: "")
        style3.target = self
        styleMenu.addItem(style3)
        let style4 = NSMenuItem(title: tr("Using 4th Style"), action: #selector(contextStyle4), keyEquivalent: "")
        style4.target = self
        styleMenu.addItem(style4)
        let style5 = NSMenuItem(title: tr("Using 5th Style"), action: #selector(contextStyle5), keyEquivalent: "")
        style5.target = self
        styleMenu.addItem(style5)
        styleMenuItem.submenu = styleMenu
        menu.addItem(styleMenuItem)

        let clearStyleItem = NSMenuItem(title: tr("Clear all Styles"), action: #selector(contextClearStyle), keyEquivalent: "")
        clearStyleItem.target = self
        menu.addItem(clearStyleItem)
        menu.addItem(NSMenuItem.separator())

        // 3. Notepad++ Plugin commands (Base64, URL, Hashes)
        let pluginItem = NSMenuItem(title: tr("Plugin commands"), action: nil, keyEquivalent: "")
        let pluginMenu = NSMenu(title: tr("Plugin commands"))
        let b64Enc = NSMenuItem(title: tr("Base64 Encode"), action: #selector(contextBase64Encode), keyEquivalent: "")
        b64Enc.target = self
        pluginMenu.addItem(b64Enc)
        let b64Dec = NSMenuItem(title: tr("Base64 Decode"), action: #selector(contextBase64Decode), keyEquivalent: "")
        b64Dec.target = self
        pluginMenu.addItem(b64Dec)
        pluginMenu.addItem(NSMenuItem.separator())
        let urlEnc = NSMenuItem(title: tr("URL Encode"), action: #selector(contextUrlEncode), keyEquivalent: "")
        urlEnc.target = self
        pluginMenu.addItem(urlEnc)
        let urlDec = NSMenuItem(title: tr("URL Decode"), action: #selector(contextUrlDecode), keyEquivalent: "")
        urlDec.target = self
        pluginMenu.addItem(urlDec)
        pluginMenu.addItem(NSMenuItem.separator())
        let md5Item = NSMenuItem(title: "MD5: " + tr("Generate from Selection into Clipboard"), action: #selector(contextMD5), keyEquivalent: "")
        md5Item.target = self
        pluginMenu.addItem(md5Item)
        let sha256Item = NSMenuItem(title: "SHA-256: " + tr("Generate from Selection into Clipboard"), action: #selector(contextSHA256), keyEquivalent: "")
        sha256Item.target = self
        pluginMenu.addItem(sha256Item)
        pluginItem.submenu = pluginMenu
        menu.addItem(pluginItem)
        menu.addItem(NSMenuItem.separator())

        // 2. Comment / Uncomment (contextMenu.xml)
        let commentItem = NSMenuItem(title: tr("Toggle Single Line Comment"), action: #selector(contextToggleComment), keyEquivalent: "/")
        commentItem.target = self
        menu.addItem(commentItem)
        let blockCommentItem = NSMenuItem(title: tr("Block Comment"), action: #selector(contextBlockComment), keyEquivalent: "")
        blockCommentItem.target = self
        menu.addItem(blockCommentItem)
        let blockUncommentItem = NSMenuItem(title: tr("Block Uncomment"), action: #selector(contextBlockUncomment), keyEquivalent: "")
        blockUncommentItem.target = self
        menu.addItem(blockUncommentItem)
        menu.addItem(NSMenuItem.separator())

        // 3. Convert Case submenu
        let caseMenuItem = NSMenuItem(title: tr("Convert Case to"), action: nil, keyEquivalent: "")
        let caseMenu = NSMenu(title: tr("Convert Case to"))
        let itemUpper = NSMenuItem(title: tr("UPPERCASE"), action: #selector(contextUppercase), keyEquivalent: "U")
        itemUpper.target = self
        caseMenu.addItem(itemUpper)
        let itemLower = NSMenuItem(title: tr("lowercase"), action: #selector(contextLowercase), keyEquivalent: "u")
        itemLower.target = self
        caseMenu.addItem(itemLower)
        let itemProper = NSMenuItem(title: tr("Proper Case"), action: #selector(contextProperCase), keyEquivalent: "")
        itemProper.target = self
        caseMenu.addItem(itemProper)
        let itemSentence = NSMenuItem(title: tr("Sentence case"), action: #selector(contextSentenceCase), keyEquivalent: "")
        itemSentence.target = self
        caseMenu.addItem(itemSentence)
        let itemInvert = NSMenuItem(title: tr("iNVERT cASE"), action: #selector(contextInvertCase), keyEquivalent: "")
        itemInvert.target = self
        caseMenu.addItem(itemInvert)
        caseMenuItem.submenu = caseMenu
        menu.addItem(caseMenuItem)

        // 4. Line Operations submenu
        let lineOpsItem = NSMenuItem(title: tr("Line Operations"), action: nil, keyEquivalent: "")
        let lineOpsMenu = NSMenu(title: tr("Line Operations"))
        let dupItem = NSMenuItem(title: tr("Duplicate Current Line"), action: #selector(contextDuplicateLine), keyEquivalent: "d")
        dupItem.target = self
        lineOpsMenu.addItem(dupItem)
        let joinItem = NSMenuItem(title: tr("Join Lines"), action: #selector(contextJoinLines), keyEquivalent: "j")
        joinItem.target = self
        lineOpsMenu.addItem(joinItem)
        let splitItem = NSMenuItem(title: tr("Split Lines"), action: #selector(contextSplitLines), keyEquivalent: "")
        splitItem.target = self
        lineOpsMenu.addItem(splitItem)
        lineOpsMenu.addItem(NSMenuItem.separator())
        let rmEmpty = NSMenuItem(title: tr("Remove Empty Lines"), action: #selector(contextRemoveEmptyLines), keyEquivalent: "")
        rmEmpty.target = self
        lineOpsMenu.addItem(rmEmpty)
        let rmDups = NSMenuItem(title: tr("Remove Duplicate Lines"), action: #selector(contextRemoveDuplicateLines), keyEquivalent: "")
        rmDups.target = self
        lineOpsMenu.addItem(rmDups)
        let sortAsc = NSMenuItem(title: tr("Sort Lines Lexicographically Ascending"), action: #selector(contextSortAscending), keyEquivalent: "")
        sortAsc.target = self
        lineOpsMenu.addItem(sortAsc)
        let sortDesc = NSMenuItem(title: tr("Sort Lines Lexicographically Descending"), action: #selector(contextSortDescending), keyEquivalent: "")
        sortDesc.target = self
        lineOpsMenu.addItem(sortDesc)
        let revLines = NSMenuItem(title: tr("Reverse Line Order"), action: #selector(contextReverseLines), keyEquivalent: "")
        revLines.target = self
        lineOpsMenu.addItem(revLines)
        lineOpsItem.submenu = lineOpsMenu
        menu.addItem(lineOpsItem)

        // 5. Blank Operations submenu
        let blankOpsItem = NSMenuItem(title: tr("Blank Operations"), action: nil, keyEquivalent: "")
        let blankOpsMenu = NSMenu(title: tr("Blank Operations"))
        let trimTrail = NSMenuItem(title: tr("Trim Trailing Space"), action: #selector(contextTrimTrailing), keyEquivalent: "")
        trimTrail.target = self
        blankOpsMenu.addItem(trimTrail)
        let trimLead = NSMenuItem(title: tr("Trim Leading Space"), action: #selector(contextTrimLeading), keyEquivalent: "")
        trimLead.target = self
        blankOpsMenu.addItem(trimLead)
        let trimBoth = NSMenuItem(title: tr("Trim Leading and Trailing Space"), action: #selector(contextTrimBoth), keyEquivalent: "")
        trimBoth.target = self
        blankOpsMenu.addItem(trimBoth)
        let eol2ws = NSMenuItem(title: tr("EOL to Space"), action: #selector(contextEolToSpace), keyEquivalent: "")
        eol2ws.target = self
        blankOpsMenu.addItem(eol2ws)
        let tab2sp = NSMenuItem(title: tr("TAB to Space"), action: #selector(contextTabToSpace), keyEquivalent: "")
        tab2sp.target = self
        blankOpsMenu.addItem(tab2sp)
        let sp2tab = NSMenuItem(title: tr("Space to TAB (All)"), action: #selector(contextSpaceToTab), keyEquivalent: "")
        sp2tab.target = self
        blankOpsMenu.addItem(sp2tab)
        blankOpsItem.submenu = blankOpsMenu
        menu.addItem(blankOpsItem)
        menu.addItem(NSMenuItem.separator())

        // 6. Insert Date Time
        let insertItem = NSMenuItem(title: tr("Insert"), action: nil, keyEquivalent: "")
        let insertMenu = NSMenu(title: tr("Insert"))
        let dtShort = NSMenuItem(title: tr("Date Time (short)"), action: #selector(contextInsertDateShort), keyEquivalent: "")
        dtShort.target = self
        insertMenu.addItem(dtShort)
        let dtLong = NSMenuItem(title: tr("Date Time (long)"), action: #selector(contextInsertDateLong), keyEquivalent: "")
        dtLong.target = self
        insertMenu.addItem(dtLong)
        insertItem.submenu = insertMenu
        menu.addItem(insertItem)
        menu.addItem(NSMenuItem.separator())

        // 7. On Selection (Search on Google / Open File)
        let sel = self.selectedRange()
        if sel.length > 0 {
            let selectedText = (self.string as NSString).substring(with: sel)
            let searchGoogle = NSMenuItem(title: tr("Search on Internet") + ": \"\(selectedText.prefix(20))\(selectedText.count > 20 ? "..." : "")\"", action: #selector(contextSearchGoogle), keyEquivalent: "")
            searchGoogle.target = self
            menu.addItem(searchGoogle)

            if selectedText.contains("/") || selectedText.contains(".") || selectedText.hasPrefix("http") {
                let openFileOrUrl = NSMenuItem(title: tr("Open File"), action: #selector(contextOpenSelectedFileOrUrl), keyEquivalent: "")
                openFileOrUrl.target = self
                menu.addItem(openFileOrUrl)
            }
            menu.addItem(NSMenuItem.separator())
        }

        // 8. File Path operations
        if let doc = resolvedDocument, doc.filePath != nil {
            let copyPathItem = NSMenuItem(title: tr("Copy Full File Path"), action: #selector(contextCopyFullPath), keyEquivalent: "")
            copyPathItem.target = self
            menu.addItem(copyPathItem)

            let revealItem = NSMenuItem(title: tr("Open Containing Folder in Finder"), action: #selector(contextRevealInFinder), keyEquivalent: "")
            revealItem.target = self
            menu.addItem(revealItem)
        }

        // 9. Notepad++ User Custom XML Context Menu Items (from contextMenu.xml)
        let xmlItems = NppContextMenuConfig.shared.loadItems()
        var customCount = 0
        for item in xmlItems {
            if let menuName = item.menuItemName {
                if customCount == 0 { menu.addItem(NSMenuItem.separator()) }
                let customItem = NSMenuItem(title: menuName, action: #selector(contextCustomXMLAction(_:)), keyEquivalent: "")
                customItem.target = self
                customItem.representedObject = item
                menu.addItem(customItem)
                customCount += 1
            }
        }

        return menu
    }

    @objc func contextCustomXMLAction(_ sender: NSMenuItem) {
        guard let item = sender.representedObject as? NppContextMenuItem,
              let name = item.menuItemName else { return }

        switch name {
        case "Convert to UPPERCASE", "UPPERCASE":
            NppEditOperations.convertCase(in: self, to: .uppercase)
        case "Convert to lowercase", "lowercase":
            NppEditOperations.convertCase(in: self, to: .lowercase)
        case "Trim Trailing Space":
            contextTrimTrailing()
        case "Find...":
            resolvedWorkspace?.openFind()
        case "Replace...":
            resolvedWorkspace?.openReplace()
        case "Find All in Current Document":
            let sel = self.selectedRange()
            if sel.length > 0 {
                let str = (self.string as NSString).substring(with: sel)
                resolvedWorkspace?.findAllInCurrentDoc(query: str, matchCase: false, wholeWord: false, useRegex: false)
            } else {
                resolvedWorkspace?.openFind()
            }
        case "Run in Terminal":
            if let path = resolvedDocument?.filePath {
                let dir = path.deletingLastPathComponent()
                NppTools.openTerminal(at: dir)
            } else {
                let alert = NSAlert()
                alert.messageText = "File Not Saved"
                alert.informativeText = "Please save the file first to run in Terminal."
                alert.alertStyle = .informational
                alert.runModal()
            }
        default:
            print("Custom XML action: \(name)")
        }
    }

    // Context Menu Handlers
    @objc func contextToggleComment() {
        if let lang = resolvedDocument?.language {
            NppEditOperations.toggleComment(in: self, language: lang)
        }
    }
    @objc func contextBlockComment() {
        if let lang = resolvedDocument?.language {
            NppEditOperations.streamComment(in: self, language: lang)
        }
    }
    @objc func contextBlockUncomment() {
        if let lang = resolvedDocument?.language {
            NppEditOperations.streamUncomment(in: self, language: lang)
        }
    }
    @objc func contextUppercase() { NppEditOperations.convertCase(in: self, to: .uppercase) }
    @objc func contextLowercase() { NppEditOperations.convertCase(in: self, to: .lowercase) }
    @objc func contextProperCase() { NppEditOperations.convertCase(in: self, to: .properCase) }
    @objc func contextSentenceCase() { NppEditOperations.convertCase(in: self, to: .sentenceCase) }
    @objc func contextInvertCase() { NppEditOperations.convertCase(in: self, to: .invertCase) }

    @objc func contextDuplicateLine() { NppEditOperations.duplicateLine(in: self) }
    @objc func contextJoinLines() { NppEditOperations.joinLines(in: self) }
    @objc func contextSplitLines() { NppEditOperations.splitLines(in: self) }
    private func performContextDocumentOp(_ op: (NppDocument) -> Void) {
        guard self.isEditable, let doc = resolvedDocument else { return }
        if doc.content != self.string {
            doc.content = self.string
        }
        op(doc)
        if self.string != doc.content {
            let sel = self.selectedRange()
            let newLen = (doc.content as NSString).length
            self.string = doc.content
            let safeLoc = min(sel.location, newLen)
            let safeLen = min(sel.length, max(0, newLen - safeLoc))
            self.setSelectedRange(NSRange(location: safeLoc, length: safeLen))
            editorCoordinator?.applyHighlighting()
            editorCoordinator?.gutter?.needsDisplay = true
        }
    }

    @objc func contextRemoveEmptyLines() {
        resolvedWorkspace?.recordMacroStep(.removeEmptyLinesContainingBlanks)
        performContextDocumentOp { NppEditOperations.removeEmptyLines(in: $0, removeBlankChars: true) }
    }
    @objc func contextRemoveDuplicateLines() {
        resolvedWorkspace?.recordMacroStep(.removeDuplicateLines)
        performContextDocumentOp { NppEditOperations.removeDuplicateLines(in: $0) }
    }
    @objc func contextSortAscending() {
        resolvedWorkspace?.recordMacroStep(.sortLines)
        performContextDocumentOp { NppEditOperations.sortLines(in: $0, ascending: true) }
    }
    @objc func contextSortDescending() {
        resolvedWorkspace?.recordMacroStep(.sortLinesDescending)
        performContextDocumentOp { NppEditOperations.sortLines(in: $0, ascending: false) }
    }
    @objc func contextReverseLines() {
        resolvedWorkspace?.recordMacroStep(.reverseLineOrder)
        performContextDocumentOp { NppEditOperations.reverseLineOrder(in: $0) }
    }

    @objc func contextTrimTrailing() {
        resolvedWorkspace?.recordMacroStep(.trimTrailingSpace)
        performContextDocumentOp { NppEditOperations.trimSpaces(in: $0, mode: .trailing) }
    }
    @objc func contextTrimLeading() {
        resolvedWorkspace?.recordMacroStep(.trimLeadingSpace)
        performContextDocumentOp { NppEditOperations.trimSpaces(in: $0, mode: .leading) }
    }
    @objc func contextTrimBoth() {
        resolvedWorkspace?.recordMacroStep(.trimBothSpace)
        performContextDocumentOp { NppEditOperations.trimSpaces(in: $0, mode: .both) }
    }
    @objc func contextEolToSpace() {
        resolvedWorkspace?.recordMacroStep(.eolToSpace)
        performContextDocumentOp { NppEditOperations.eolToSpace(in: $0) }
    }
    @objc func contextTabToSpace() {
        resolvedWorkspace?.recordMacroStep(.tabToSpace)
        performContextDocumentOp { NppEditOperations.tabToSpace(in: $0, spaceCount: resolvedWorkspace?.tabSize ?? 4) }
    }
    @objc func contextSpaceToTab() {
        resolvedWorkspace?.recordMacroStep(.spaceToTab)
        performContextDocumentOp { NppEditOperations.spaceToTab(in: $0, spaceCount: resolvedWorkspace?.tabSize ?? 4) }
    }

    @objc func contextInsertDateShort() { NppEditOperations.insertDateTime(in: self, isLong: false) }
    @objc func contextInsertDateLong() { NppEditOperations.insertDateTime(in: self, isLong: true) }

    @objc func contextSearchGoogle() {
        let sel = self.selectedRange()
        guard sel.length > 0 else { return }
        let text = (self.string as NSString).substring(with: sel)
        if let encoded = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let url = URL(string: "https://www.google.com/search?q=\(encoded)") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc func contextOpenSelectedFileOrUrl() {
        let sel = self.selectedRange()
        guard sel.length > 0 else { return }
        let text = (self.string as NSString).substring(with: sel).trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("http://") || text.hasPrefix("https://"), let url = URL(string: text) {
            NSWorkspace.shared.open(url)
        } else {
            let fileUrl = URL(fileURLWithPath: text)
            if FileManager.default.fileExists(atPath: fileUrl.path) {
                resolvedWorkspace?.openFile(url: fileUrl)
            }
        }
    }

    @objc func contextCopyFullPath() {
        if let doc = resolvedDocument, let path = doc.filePath {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(path.path, forType: .string)
        }
    }

    @objc func contextRevealInFinder() {
        if let doc = resolvedDocument, let path = doc.filePath {
            NSWorkspace.shared.activateFileViewerSelecting([path])
        }
    }

    // MARK: - Notepad++ Style Token Occurrence Handlers
    private func styleToken(color: NSColor) {
        guard let ts = self.textStorage else { return }
        let sel = self.selectedRange()
        let str = self.string as NSString
        guard sel.length > 0 && NSMaxRange(sel) <= str.length else { return }
        let selectedWord = str.substring(with: sel)

        var searchRange = NSRange(location: 0, length: str.length)
        ts.beginEditing()
        while searchRange.location < str.length {
            let found = str.range(of: selectedWord, options: [.literal], range: searchRange)
            if found.location == NSNotFound { break }
            ts.addAttribute(.backgroundColor, value: color, range: found)
            let nextPos = found.location + max(1, found.length)
            searchRange = NSRange(location: nextPos, length: str.length - nextPos)
        }
        ts.endEditing()
    }

    @objc func contextStyle1() { _ = resolvedWorkspace?.styleAllOccurrencesOfToken(styleIndex: 1) }
    @objc func contextStyle2() { _ = resolvedWorkspace?.styleAllOccurrencesOfToken(styleIndex: 2) }
    @objc func contextStyle3() { _ = resolvedWorkspace?.styleAllOccurrencesOfToken(styleIndex: 3) }
    @objc func contextStyle4() { _ = resolvedWorkspace?.styleAllOccurrencesOfToken(styleIndex: 4) }
    @objc func contextStyle5() { _ = resolvedWorkspace?.styleAllOccurrencesOfToken(styleIndex: 5) }

    @objc func contextClearStyle() {
        resolvedWorkspace?.clearAllStyles()
        editorCoordinator?.smartHighlightedRanges.removeAll()
        editorCoordinator?.lastSmartHighlightedWord = ""
    }

    // MARK: - Plugin Commands (Base64, URL, Hashes)
    @objc func contextBase64Encode() {
        let sel = self.selectedRange()
        guard sel.length > 0 else { return }
        let text = (self.string as NSString).substring(with: sel)
        let encoded = NppTools.base64Encode(string: text)
        self.insertText(encoded, replacementRange: sel)
    }

    @objc func contextBase64Decode() {
        let sel = self.selectedRange()
        guard sel.length > 0 else { return }
        let text = (self.string as NSString).substring(with: sel)
        let decoded = NppTools.base64Decode(string: text)
        self.insertText(decoded, replacementRange: sel)
    }

    @objc func contextUrlEncode() {
        let sel = self.selectedRange()
        guard sel.length > 0 else { return }
        let text = (self.string as NSString).substring(with: sel)
        let encoded = NppTools.urlEncode(string: text)
        self.insertText(encoded, replacementRange: sel)
    }

    @objc func contextUrlDecode() {
        let sel = self.selectedRange()
        guard sel.length > 0 else { return }
        let text = (self.string as NSString).substring(with: sel)
        let decoded = NppTools.urlDecode(string: text)
        self.insertText(decoded, replacementRange: sel)
    }

    @objc func contextMD5() {
        let sel = self.selectedRange()
        let targetText: String
        if sel.length > 0 {
            targetText = (self.string as NSString).substring(with: sel)
        } else {
            targetText = self.string
        }
        guard let data = targetText.data(using: .utf8) else { return }
        let hash = NppTools.md5(data: data)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(hash, forType: .string)
        NppTools.showHashDialog(title: "MD5 Digest Copied to Clipboard", hash: hash)
    }

    @objc func contextSHA256() {
        let sel = self.selectedRange()
        let targetText: String
        if sel.length > 0 {
            targetText = (self.string as NSString).substring(with: sel)
        } else {
            targetText = self.string
        }
        guard let data = targetText.data(using: .utf8) else { return }
        let hash = NppTools.sha256(data: data)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(hash, forType: .string)
        NppTools.showHashDialog(title: "SHA-256 Digest Copied to Clipboard", hash: hash)
    }
}
