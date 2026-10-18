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

        let font = NSFont.monospacedSystemFont(ofSize: workspace.fontSize, weight: .regular)
        textView.font = font
        textView.string = document.content

        // Line wrap setup
        configureWordWrap(textView: textView, scrollView: scrollView, enabled: workspace.isWordWrapEnabled)

        scrollView.documentView = textView

        // Attach Line Number Gutter
        let gutter = NppGutterView(textView: textView)
        scrollView.verticalRulerView = gutter
        scrollView.hasVerticalRuler = true
        scrollView.rulersVisible = true

        context.coordinator.textView = textView
        context.coordinator.gutter = gutter

        // Initial syntax highlighting
        let isDark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        if let textStorage = textView.textStorage {
            NppSyntaxHighlighter.highlight(textStorage: textStorage, language: document.language, isDarkMode: isDark)
        }

        return scrollView
    }

    public func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let textView = context.coordinator.textView else { return }

        // Update content if changed externally (e.g., encoding conversion, reload or edit operations)
        if textView.string != document.content {
            let selectedRange = textView.selectedRange()
            textView.string = document.content
            if selectedRange.location <= (document.content as NSString).length {
                textView.setSelectedRange(selectedRange)
            }
            context.coordinator.applyHighlighting()
            context.coordinator.gutter?.needsDisplay = true
        }

        // Update font size
        let font = NSFont.monospacedSystemFont(ofSize: workspace.fontSize, weight: .regular)
        if textView.font?.pointSize != workspace.fontSize {
            textView.font = font
            context.coordinator.gutter?.needsDisplay = true
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
        var smartHighlightedRanges: [NSRange] = []
        var lastSmartHighlightedWord: String = ""

        init(_ parent: NppEditorView) {
            self.parent = parent
            self.lastWordWrap = parent.workspace.isWordWrapEnabled
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

            // Clear previous smart highlights
            if !smartHighlightedRanges.isEmpty {
                ts.beginEditing()
                for r in smartHighlightedRanges {
                    if NSMaxRange(r) <= ts.length {
                        ts.removeAttribute(.backgroundColor, range: r)
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
                var col = 1
                var lineStart = 0

                str.enumerateSubstrings(in: NSRange(location: 0, length: sel.location), options: [.byLines, .substringNotRequired]) { _, _, range, _ in
                    line += 1
                    lineStart = NSMaxRange(range)
                }

                col = sel.location - lineStart + 1
                parent.document.cursorLine = line
                parent.document.cursorCol = col
            }
        }

        func applyHighlighting() {
            guard let tv = textView, let ts = tv.textStorage else { return }
            let isDark = tv.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            NppSyntaxHighlighter.highlight(textStorage: ts, language: parent.document.language, isDarkMode: isDark)
        }
    }
}

public final class NppTextView: NSTextView {
    weak var editorCoordinator: NppEditorView.Coordinator?

    public override func keyDown(with event: NSEvent) {
        // Tab key: insert 4 spaces
        if event.keyCode == 48 && !event.modifierFlags.contains(.shift) && !event.modifierFlags.contains(.control) {
            self.insertText("    ", replacementRange: self.selectedRange())
            return
        }

        // Duplicate Line: Cmd + D
        if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "d" {
            NppEditOperations.duplicateLine(in: self)
            return
        }

        // Move Line Up: Option + Up
        if event.modifierFlags.contains(.option) && event.keyCode == 126 {
            NppEditOperations.moveLineUp(in: self)
            return
        }

        // Move Line Down: Option + Down
        if event.modifierFlags.contains(.option) && event.keyCode == 125 {
            NppEditOperations.moveLineDown(in: self)
            return
        }

        // Join Lines: Cmd + J
        if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "j" {
            NppEditOperations.joinLines(in: self)
            return
        }

        // Toggle Comment: Cmd + /
        if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "/" {
            if let lang = editorCoordinator?.parent.document.language {
                NppEditOperations.toggleComment(in: self, language: lang)
            }
            return
        }

        super.keyDown(with: event)
    }

    // MARK: - Notepad++ Active Line Highlight Bar (notepad4ever.png line 8 style)
    public override func draw(_ dirtyRect: NSRect) {
        let sel = self.selectedRange()
        if sel.length == 0, let layoutManager = self.layoutManager {
            let str = self.string as NSString
            let charPos = min(sel.location, max(0, str.length))
            let glyphIdx = layoutManager.glyphIndexForCharacter(at: charPos)
            var lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIdx, effectiveRange: nil)
            lineRect.origin.x = 0
            lineRect.size.width = max(self.bounds.width, self.visibleRect.width)

            let isDark = self.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            let lineHighlightColor = isDark
                ? NSColor(calibratedRed: 0.17, green: 0.18, blue: 0.20, alpha: 0.95)
                : NSColor(calibratedRed: 0.93, green: 0.95, blue: 0.98, alpha: 0.95)

            lineHighlightColor.setFill()
            NSBezierPath(rect: lineRect).fill()
        }
        super.draw(dirtyRect)
    }

    // MARK: - Notepad++ Right Click Context Menu (Scintilla Edit Zone)
    public override func menu(for event: NSEvent) -> NSMenu? {
        let menu = NSMenu(title: "Context Menu")

        // 1. Basic Edit
        menu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        menu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        menu.addItem(NSMenuItem.separator())

        menu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        menu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        menu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        menu.addItem(withTitle: "Delete", action: #selector(NSText.delete(_:)), keyEquivalent: "")
        menu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        menu.addItem(NSMenuItem.separator())

        // 2. Notepad++ Style Token Occurrence Submenu
        let styleMenuItem = NSMenuItem(title: "Style all occurrences of token", action: nil, keyEquivalent: "")
        let styleMenu = NSMenu(title: "Style all occurrences of token")
        let style1 = NSMenuItem(title: "Using 1st Style (Mint Green)", action: #selector(contextStyle1), keyEquivalent: "")
        style1.target = self
        styleMenu.addItem(style1)
        let style2 = NSMenuItem(title: "Using 2nd Style (Cyan)", action: #selector(contextStyle2), keyEquivalent: "")
        style2.target = self
        styleMenu.addItem(style2)
        let style3 = NSMenuItem(title: "Using 3rd Style (Yellow)", action: #selector(contextStyle3), keyEquivalent: "")
        style3.target = self
        styleMenu.addItem(style3)
        let style4 = NSMenuItem(title: "Using 4th Style (Orange)", action: #selector(contextStyle4), keyEquivalent: "")
        style4.target = self
        styleMenu.addItem(style4)
        let style5 = NSMenuItem(title: "Using 5th Style (Purple)", action: #selector(contextStyle5), keyEquivalent: "")
        style5.target = self
        styleMenu.addItem(style5)
        styleMenuItem.submenu = styleMenu
        menu.addItem(styleMenuItem)

        let clearStyleItem = NSMenuItem(title: "Clear style", action: #selector(contextClearStyle), keyEquivalent: "")
        clearStyleItem.target = self
        menu.addItem(clearStyleItem)
        menu.addItem(NSMenuItem.separator())

        // 3. Notepad++ Plugin commands (Base64, URL, Hashes)
        let pluginItem = NSMenuItem(title: "Plugin commands", action: nil, keyEquivalent: "")
        let pluginMenu = NSMenu(title: "Plugin commands")
        let b64Enc = NSMenuItem(title: "Base64 Encode", action: #selector(contextBase64Encode), keyEquivalent: "")
        b64Enc.target = self
        pluginMenu.addItem(b64Enc)
        let b64Dec = NSMenuItem(title: "Base64 Decode", action: #selector(contextBase64Decode), keyEquivalent: "")
        b64Dec.target = self
        pluginMenu.addItem(b64Dec)
        pluginMenu.addItem(NSMenuItem.separator())
        let urlEnc = NSMenuItem(title: "URL Encode", action: #selector(contextUrlEncode), keyEquivalent: "")
        urlEnc.target = self
        pluginMenu.addItem(urlEnc)
        let urlDec = NSMenuItem(title: "URL Decode", action: #selector(contextUrlDecode), keyEquivalent: "")
        urlDec.target = self
        pluginMenu.addItem(urlDec)
        pluginMenu.addItem(NSMenuItem.separator())
        let md5Item = NSMenuItem(title: "Generate MD5 into Clipboard", action: #selector(contextMD5), keyEquivalent: "")
        md5Item.target = self
        pluginMenu.addItem(md5Item)
        let sha256Item = NSMenuItem(title: "Generate SHA-256 into Clipboard", action: #selector(contextSHA256), keyEquivalent: "")
        sha256Item.target = self
        pluginMenu.addItem(sha256Item)
        pluginItem.submenu = pluginMenu
        menu.addItem(pluginItem)
        menu.addItem(NSMenuItem.separator())

        // 2. Comment / Uncomment
        let commentItem = NSMenuItem(title: "Toggle Single Line Comment", action: #selector(contextToggleComment), keyEquivalent: "/")
        commentItem.target = self
        menu.addItem(commentItem)
        menu.addItem(NSMenuItem.separator())

        // 3. Convert Case submenu
        let caseMenuItem = NSMenuItem(title: "Convert Case to", action: nil, keyEquivalent: "")
        let caseMenu = NSMenu(title: "Convert Case to")
        let itemUpper = NSMenuItem(title: "UPPERCASE", action: #selector(contextUppercase), keyEquivalent: "U")
        itemUpper.target = self
        caseMenu.addItem(itemUpper)
        let itemLower = NSMenuItem(title: "lowercase", action: #selector(contextLowercase), keyEquivalent: "u")
        itemLower.target = self
        caseMenu.addItem(itemLower)
        let itemProper = NSMenuItem(title: "Proper Case", action: #selector(contextProperCase), keyEquivalent: "")
        itemProper.target = self
        caseMenu.addItem(itemProper)
        let itemSentence = NSMenuItem(title: "Sentence case", action: #selector(contextSentenceCase), keyEquivalent: "")
        itemSentence.target = self
        caseMenu.addItem(itemSentence)
        let itemInvert = NSMenuItem(title: "iNVERT cASE", action: #selector(contextInvertCase), keyEquivalent: "")
        itemInvert.target = self
        caseMenu.addItem(itemInvert)
        caseMenuItem.submenu = caseMenu
        menu.addItem(caseMenuItem)

        // 4. Line Operations submenu
        let lineOpsItem = NSMenuItem(title: "Line Operations", action: nil, keyEquivalent: "")
        let lineOpsMenu = NSMenu(title: "Line Operations")
        let dupItem = NSMenuItem(title: "Duplicate Current Line", action: #selector(contextDuplicateLine), keyEquivalent: "d")
        dupItem.target = self
        lineOpsMenu.addItem(dupItem)
        let joinItem = NSMenuItem(title: "Join Lines", action: #selector(contextJoinLines), keyEquivalent: "j")
        joinItem.target = self
        lineOpsMenu.addItem(joinItem)
        let splitItem = NSMenuItem(title: "Split Lines", action: #selector(contextSplitLines), keyEquivalent: "")
        splitItem.target = self
        lineOpsMenu.addItem(splitItem)
        lineOpsMenu.addItem(NSMenuItem.separator())
        let rmEmpty = NSMenuItem(title: "Remove Empty Lines", action: #selector(contextRemoveEmptyLines), keyEquivalent: "")
        rmEmpty.target = self
        lineOpsMenu.addItem(rmEmpty)
        let rmDups = NSMenuItem(title: "Remove Duplicate Lines", action: #selector(contextRemoveDuplicateLines), keyEquivalent: "")
        rmDups.target = self
        lineOpsMenu.addItem(rmDups)
        let sortAsc = NSMenuItem(title: "Sort Lines Lexicographically Ascending", action: #selector(contextSortAscending), keyEquivalent: "")
        sortAsc.target = self
        lineOpsMenu.addItem(sortAsc)
        let sortDesc = NSMenuItem(title: "Sort Lines Lexicographically Descending", action: #selector(contextSortDescending), keyEquivalent: "")
        sortDesc.target = self
        lineOpsMenu.addItem(sortDesc)
        let revLines = NSMenuItem(title: "Reverse Line Order", action: #selector(contextReverseLines), keyEquivalent: "")
        revLines.target = self
        lineOpsMenu.addItem(revLines)
        lineOpsItem.submenu = lineOpsMenu
        menu.addItem(lineOpsItem)

        // 5. Blank Operations submenu
        let blankOpsItem = NSMenuItem(title: "Blank Operations", action: nil, keyEquivalent: "")
        let blankOpsMenu = NSMenu(title: "Blank Operations")
        let trimTrail = NSMenuItem(title: "Trim Trailing Space", action: #selector(contextTrimTrailing), keyEquivalent: "")
        trimTrail.target = self
        blankOpsMenu.addItem(trimTrail)
        let trimLead = NSMenuItem(title: "Trim Leading Space", action: #selector(contextTrimLeading), keyEquivalent: "")
        trimLead.target = self
        blankOpsMenu.addItem(trimLead)
        let trimBoth = NSMenuItem(title: "Trim Leading and Trailing Space", action: #selector(contextTrimBoth), keyEquivalent: "")
        trimBoth.target = self
        blankOpsMenu.addItem(trimBoth)
        let eol2ws = NSMenuItem(title: "EOL to Space", action: #selector(contextEolToSpace), keyEquivalent: "")
        eol2ws.target = self
        blankOpsMenu.addItem(eol2ws)
        let tab2sp = NSMenuItem(title: "TAB to Space", action: #selector(contextTabToSpace), keyEquivalent: "")
        tab2sp.target = self
        blankOpsMenu.addItem(tab2sp)
        let sp2tab = NSMenuItem(title: "Space to TAB", action: #selector(contextSpaceToTab), keyEquivalent: "")
        sp2tab.target = self
        blankOpsMenu.addItem(sp2tab)
        blankOpsItem.submenu = blankOpsMenu
        menu.addItem(blankOpsItem)
        menu.addItem(NSMenuItem.separator())

        // 6. Insert Date Time
        let insertItem = NSMenuItem(title: "Insert", action: nil, keyEquivalent: "")
        let insertMenu = NSMenu(title: "Insert")
        let dtShort = NSMenuItem(title: "Date Time (short)", action: #selector(contextInsertDateShort), keyEquivalent: "")
        dtShort.target = self
        insertMenu.addItem(dtShort)
        let dtLong = NSMenuItem(title: "Date Time (long)", action: #selector(contextInsertDateLong), keyEquivalent: "")
        dtLong.target = self
        insertMenu.addItem(dtLong)
        insertItem.submenu = insertMenu
        menu.addItem(insertItem)
        menu.addItem(NSMenuItem.separator())

        // 7. On Selection (Search on Google / Open File)
        let sel = self.selectedRange()
        if sel.length > 0 {
            let selectedText = (self.string as NSString).substring(with: sel)
            let searchGoogle = NSMenuItem(title: "Search on Google: \"\(selectedText.prefix(20))\(selectedText.count > 20 ? "..." : "")\"", action: #selector(contextSearchGoogle), keyEquivalent: "")
            searchGoogle.target = self
            menu.addItem(searchGoogle)

            if selectedText.contains("/") || selectedText.contains(".") || selectedText.hasPrefix("http") {
                let openFileOrUrl = NSMenuItem(title: "Open Selected File or URL", action: #selector(contextOpenSelectedFileOrUrl), keyEquivalent: "")
                openFileOrUrl.target = self
                menu.addItem(openFileOrUrl)
            }
            menu.addItem(NSMenuItem.separator())
        }

        // 8. File Path operations
        if let doc = editorCoordinator?.parent.document, doc.filePath != nil {
            let copyPathItem = NSMenuItem(title: "Copy Current Full File Path", action: #selector(contextCopyFullPath), keyEquivalent: "")
            copyPathItem.target = self
            menu.addItem(copyPathItem)

            let revealItem = NSMenuItem(title: "Open Containing Folder in Finder", action: #selector(contextRevealInFinder), keyEquivalent: "")
            revealItem.target = self
            menu.addItem(revealItem)
        }

        return menu
    }

    // Context Menu Handlers
    @objc func contextToggleComment() {
        if let lang = editorCoordinator?.parent.document.language {
            NppEditOperations.toggleComment(in: self, language: lang)
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
    @objc func contextRemoveEmptyLines() {
        if let doc = editorCoordinator?.parent.document {
            NppEditOperations.removeEmptyLines(in: doc, removeBlankChars: true)
        }
    }
    @objc func contextRemoveDuplicateLines() {
        if let doc = editorCoordinator?.parent.document {
            NppEditOperations.removeDuplicateLines(in: doc)
        }
    }
    @objc func contextSortAscending() {
        if let doc = editorCoordinator?.parent.document {
            NppEditOperations.sortLines(in: doc, ascending: true)
        }
    }
    @objc func contextSortDescending() {
        if let doc = editorCoordinator?.parent.document {
            NppEditOperations.sortLines(in: doc, ascending: false)
        }
    }
    @objc func contextReverseLines() {
        if let doc = editorCoordinator?.parent.document {
            NppEditOperations.reverseLineOrder(in: doc)
        }
    }

    @objc func contextTrimTrailing() {
        if let doc = editorCoordinator?.parent.document { NppEditOperations.trimSpaces(in: doc, mode: .trailing) }
    }
    @objc func contextTrimLeading() {
        if let doc = editorCoordinator?.parent.document { NppEditOperations.trimSpaces(in: doc, mode: .leading) }
    }
    @objc func contextTrimBoth() {
        if let doc = editorCoordinator?.parent.document { NppEditOperations.trimSpaces(in: doc, mode: .both) }
    }
    @objc func contextEolToSpace() {
        if let doc = editorCoordinator?.parent.document { NppEditOperations.eolToSpace(in: doc) }
    }
    @objc func contextTabToSpace() {
        if let doc = editorCoordinator?.parent.document { NppEditOperations.tabToSpace(in: doc) }
    }
    @objc func contextSpaceToTab() {
        if let doc = editorCoordinator?.parent.document { NppEditOperations.spaceToTab(in: doc) }
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
                editorCoordinator?.parent.workspace.openFile(url: fileUrl)
            }
        }
    }

    @objc func contextCopyFullPath() {
        if let doc = editorCoordinator?.parent.document, let path = doc.filePath {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(path.path, forType: .string)
        }
    }

    @objc func contextRevealInFinder() {
        if let doc = editorCoordinator?.parent.document, let path = doc.filePath {
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

    @objc func contextStyle1() { styleToken(color: NSColor(calibratedRed: 0.15, green: 0.65, blue: 0.40, alpha: 0.50)) } // Mint Green
    @objc func contextStyle2() { styleToken(color: NSColor(calibratedRed: 0.15, green: 0.55, blue: 0.85, alpha: 0.50)) } // Cyan
    @objc func contextStyle3() { styleToken(color: NSColor(calibratedRed: 0.85, green: 0.75, blue: 0.20, alpha: 0.50)) } // Yellow
    @objc func contextStyle4() { styleToken(color: NSColor(calibratedRed: 0.90, green: 0.50, blue: 0.20, alpha: 0.50)) } // Orange
    @objc func contextStyle5() { styleToken(color: NSColor(calibratedRed: 0.65, green: 0.35, blue: 0.85, alpha: 0.50)) } // Purple

    @objc func contextClearStyle() {
        guard let ts = self.textStorage else { return }
        ts.beginEditing()
        ts.removeAttribute(.backgroundColor, range: NSRange(location: 0, length: ts.length))
        ts.endEditing()
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
