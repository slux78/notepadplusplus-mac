import SwiftUI
import AppKit

public struct NppEditorView: NSViewRepresentable {
    @ObservedObject var document: NppDocument
    @ObservedObject var workspace: NppWorkspace
    public var viewIndex: Int = 0

    public init(document: NppDocument, workspace: NppWorkspace, viewIndex: Int = 0) {
        self.document = document
        self.workspace = workspace
        self.viewIndex = viewIndex
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    public func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.contentView.postsBoundsChangedNotifications = true
        if viewIndex == 0 {
            workspace.primaryScrollView = scrollView
        } else {
            workspace.secondaryScrollView = scrollView
        }
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

        // Initial syntax highlighting (guarded by performanceLargeFileSizeMB per programing-languages.md:80-95)
        if !workspace.isLargeFile(doc: document), let textStorage = textView.textStorage {
            NppSyntaxHighlighter.highlight(
                textStorage: textStorage,
                language: document.language,
                isDarkMode: theme.isDark,
                baseFont: targetFont,
                theme: theme,
                userDefinedLanguage: workspace.userDefinedLanguage(named: document.language)
            )
        }

        return scrollView
    }

    public func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let textView = context.coordinator.textView else { return }

        if viewIndex == 0 {
            workspace.primaryScrollView = scrollView
        } else {
            workspace.secondaryScrollView = scrollView
        }

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
        if let match = workspace.targetJumpMatch {
            let isTargetDoc = match.documentId == document.id ||
                (match.filePath != nil && document.filePath != nil &&
                 match.filePath?.standardizedFileURL.path == document.filePath?.standardizedFileURL.path)
            if isTargetDoc {
                let targetRange = NSRange(location: match.charPosition, length: match.matchLength)
                if NSMaxRange(targetRange) <= (textView.string as NSString).length {
                    textView.setSelectedRange(targetRange)
                    textView.scrollRangeToVisible(targetRange)
                    textView.window?.makeFirstResponder(textView)
                }
                DispatchQueue.main.async {
                    self.workspace.targetJumpMatch = nil
                }
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
        var activeBraceRanges: [NSRange] = []

        init(_ parent: NppEditorView) {
            self.parent = parent
            self.lastWordWrap = parent.workspace.isWordWrapEnabled
            self.lastLanguage = parent.document.language
        }

        public func textView(_ textView: NSTextView, shouldChangeTextIn affectedCharRange: NSRange, replacementString: String?) -> Bool {
            let replLen = (replacementString as NSString?)?.length ?? 0
            let delta = replLen - affectedCharRange.length
            if delta != 0 || affectedCharRange.length > 0 {
                parent.document.adjustStyledRanges(affectedRange: affectedCharRange, delta: delta)
                parent.document.adjustBookmarks(affectedRange: affectedCharRange, replacementString: replacementString ?? "", currentText: textView.string)
            }
            return true
        }

        public func textView(_ textView: NSTextView, completions words: [String], forPartialWordRange charRange: NSRange, indexOfSelectedItem index: UnsafeMutablePointer<Int>?) -> [String] {
            let ws = parent.workspace
            let manualMode = (textView as? NppTextView)?.completionModeOverride
            if manualMode == 3 {
                return NppCompletionEngine.shared.pathCandidates(
                    text: textView.string,
                    caret: NSMaxRange(charRange),
                    documentURL: parent.document.filePath
                )
            }
            return NppCompletionEngine.shared.candidates(
                text: textView.string,
                caret: NSMaxRange(charRange),
                language: parent.document.language,
                mode: manualMode ?? ws.autoCompletionType,
                minimumLength: ws.autoCompletionThreshold,
                ignoreNumbers: ws.autoCompletionIgnoreNumbers,
                manual: manualMode != nil
            )
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
            updateBraceHighlighting()
        }

        func updateBraceHighlighting() {
            guard let tv = textView, let ts = tv.textStorage else { return }
            let sel = tv.selectedRange()
            let str = tv.string as NSString

            // Clear previous real-time brace highlights
            if !activeBraceRanges.isEmpty {
                ts.beginEditing()
                for r in activeBraceRanges where NSMaxRange(r) <= ts.length {
                    ts.removeAttribute(.backgroundColor, range: r)
                }
                // Restore manual token styles if any overlapped
                for (styleIdx, tokenRanges) in parent.document.styledTokenRanges {
                    let styleColor = NppWorkspace.tokenStyleColor(for: styleIdx)
                    for r in tokenRanges where NSMaxRange(r) <= ts.length {
                        ts.addAttribute(.backgroundColor, value: styleColor, range: r)
                    }
                }
                ts.endEditing()
                activeBraceRanges.removeAll()
            }

            guard str.length >= 2 else { return }
            // Upstream Notepad++ matching brace detection
            if let pair = NppEditOperations.findMatchingBracePair(in: str, at: sel.location, allowEnclosing: false) {
                let openRange = NSRange(location: pair.openPos, length: 1)
                let closeRange = NSRange(location: pair.closePos, length: 1)
                let braceHighlightColor = NSColor.systemTeal.withAlphaComponent(0.35)

                ts.beginEditing()
                if NSMaxRange(openRange) <= ts.length {
                    ts.addAttribute(.backgroundColor, value: braceHighlightColor, range: openRange)
                }
                if NSMaxRange(closeRange) <= ts.length {
                    ts.addAttribute(.backgroundColor, value: braceHighlightColor, range: closeRange)
                }
                ts.endEditing()
                activeBraceRanges = [openRange, closeRange]
            }
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
                let info = NppLineCounter.lineInfo(upTo: sel.location, in: str)
                let line = info.line
                let lineStart = info.lineStart
                let col = sel.location - lineStart + 1
                parent.document.cursorLine = line
                parent.document.cursorCol = col
            }

            parent.document.selectionRanges = tv.selectedRanges.map { NppSelectionRange(range: $0.rangeValue) }
            if parent.document.primarySelectionIndex >= parent.document.selectionRanges.count {
                parent.document.primarySelectionIndex = 0
            }
        }

        func applyHighlighting() {
            guard let tv = textView, let ts = tv.textStorage else { return }
            guard !parent.workspace.isLargeFile(doc: parent.document) else { return }
            let isDark = tv.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            NppSyntaxHighlighter.highlight(textStorage: ts, language: parent.document.language,
                                           isDarkMode: isDark, baseFont: tv.font,
                                           theme: parent.workspace.currentTheme,
                                           userDefinedLanguage: parent.workspace.userDefinedLanguage(named: parent.document.language))
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
    var completionModeOverride: Int?
    private var parameterHintPopover: NSPopover?
    private var completionPopupActive = false
    private var completionOriginalPrefix = ""

    public override var rangeForUserCompletion: NSRange {
        if completionModeOverride == 3 {
            return NppCompletionEngine.pathNameRange(in: string as NSString, before: selectedRange().location)
        }
        return super.rangeForUserCompletion
    }

    public func triggerCompletion(mode: Int) {
        let caret = selectedRange().location
        let engine = NppCompletionEngine.shared
        let suggestions: [String]
        if mode == 3 {
            suggestions = engine.pathCandidates(text: string, caret: caret, documentURL: resolvedDocument?.filePath)
        } else {
            suggestions = engine.candidates(
                text: string, caret: caret, language: resolvedDocument?.language ?? "",
                mode: mode, minimumLength: 1, ignoreNumbers: false, manual: true
            )
        }
        if suggestions.count == 1 {
            let range = mode == 3
                ? NppCompletionEngine.pathNameRange(in: string as NSString, before: caret)
                : NppCompletionEngine.wordRange(in: string as NSString, before: caret)
            insertText(suggestions[0], replacementRange: range)
            return
        }
        guard !suggestions.isEmpty else { return }
        completionModeOverride = mode
        showCompletions()
    }

    private func showCompletions() {
        let range = rangeForUserCompletion
        if NSMaxRange(range) <= (string as NSString).length {
            completionOriginalPrefix = (string as NSString).substring(with: range)
        }
        completionPopupActive = true
        complete(nil)
    }

    public override func insertCompletion(_ word: String, forPartialWordRange charRange: NSRange,
                                          movement: Int, isFinal flag: Bool) {
        let disallowedTab = movement == NSTabTextMovement && resolvedWorkspace?.autoCompletionKeyTab == false
        let disallowedEnter = movement == NSReturnTextMovement && resolvedWorkspace?.autoCompletionKeyEnter == false
        if flag { completionPopupActive = false; completionModeOverride = nil }
        if flag && (disallowedTab || disallowedEnter) {
            super.insertCompletion(completionOriginalPrefix, forPartialWordRange: charRange,
                                   movement: NSCancelTextMovement, isFinal: true)
            if disallowedEnter {
                insertText("\n", replacementRange: selectedRange())
            } else {
                let ws = resolvedWorkspace
                let indent = ws?.replaceTabBySpace == true
                    ? String(repeating: " ", count: ws?.tabSize ?? 4) : "\t"
                insertText(indent, replacementRange: selectedRange())
            }
            return
        }
        super.insertCompletion(word, forPartialWordRange: charRange, movement: movement, isFinal: flag)
    }

    public func showParameterHint(force: Bool = false) {
        guard force || resolvedWorkspace?.funcParamsHint == true,
              let window,
              let hint = NppCompletionEngine.shared.parameterHint(
                in: string, caret: selectedRange().location,
                language: resolvedDocument?.language ?? ""
              ) else { return }
        parameterHintPopover?.close()
        let label = NSTextField(wrappingLabelWithString: hint)
        label.font = NSFont.systemFont(ofSize: 12)
        label.frame = NSRect(x: 10, y: 10, width: 420, height: 60)
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 440, height: 80))
        view.addSubview(label)
        let controller = NSViewController()
        controller.view = view
        let popover = NSPopover()
        popover.behavior = .transient
        popover.contentViewController = controller
        popover.contentSize = view.frame.size
        let screenRect = firstRect(forCharacterRange: selectedRange(), actualRange: nil)
        let localRect = convert(window.convertFromScreen(screenRect), from: nil)
        popover.show(relativeTo: localRect, of: self, preferredEdge: .maxY)
        parameterHintPopover = popover
    }

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

    public var caretBlinkTurnedOn: Bool = true
    private var isCmdDragging: Bool = false
    private var cmdDragAnchor: Int = 0
    private var cmdDragRangeIndex: Int = 0
    private var isSyncingToAppKit: Bool = false
    private var customSelectedRanges: [NSValue] = [NSValue(range: NSRange(location: 0, length: 0))]

    public override var selectedRanges: [NSValue] {
        get {
            return customSelectedRanges
        }
        set {
            self.setSelectedRanges(newValue, affinity: .downstream, stillSelecting: false)
        }
    }

    public override func selectedRange() -> NSRange {
        return customSelectedRanges.first?.rangeValue ?? NSRange(location: 0, length: 0)
    }

    public override func setSelectedRanges(_ ranges: [NSValue], affinity: NSSelectionAffinity, stillSelecting stillSelectingFlag: Bool) {
        if isSyncingToAppKit {
            super.setSelectedRanges(ranges, affinity: affinity, stillSelecting: stillSelectingFlag)
            return
        }

        let sanitized = sanitizeRanges(ranges)
        self.customSelectedRanges = sanitized

        isSyncingToAppKit = true
        let appKitRanges = sanitized.filter { $0.rangeValue.length > 0 }
        if !appKitRanges.isEmpty {
            super.setSelectedRanges(appKitRanges, affinity: affinity, stillSelecting: stillSelectingFlag)
        } else if let primary = sanitized.first {
            super.setSelectedRanges([primary], affinity: affinity, stillSelecting: stillSelectingFlag)
        }
        isSyncingToAppKit = false

        syncDocumentSelectionRanges()
        needsDisplay = true
    }

    public override func setSelectedRange(_ charRange: NSRange) {
        self.setSelectedRanges([NSValue(range: charRange)], affinity: .downstream, stillSelecting: false)
    }

    public override func setSelectedRange(_ charRange: NSRange, affinity: NSSelectionAffinity, stillSelecting stillSelectingFlag: Bool) {
        self.setSelectedRanges([NSValue(range: charRange)], affinity: affinity, stillSelecting: stillSelectingFlag)
    }

    public func sanitizeRanges(_ ranges: [NSValue]) -> [NSValue] {
        let docLen = (self.string as NSString).length
        guard !ranges.isEmpty else {
            return [NSValue(range: NSRange(location: 0, length: 0))]
        }

        var validRanges: [NSRange] = []
        for val in ranges {
            let r = val.rangeValue
            let safeLoc = max(0, min(r.location, docLen))
            let safeLen = max(0, min(r.length, docLen - safeLoc))
            validRanges.append(NSRange(location: safeLoc, length: safeLen))
        }

        validRanges.sort {
            if $0.location != $1.location {
                return $0.location < $1.location
            }
            return $0.length < $1.length
        }

        var merged: [NSRange] = []
        for r in validRanges {
            if let last = merged.last {
                if r.location < NSMaxRange(last) {
                    let newMax = max(NSMaxRange(last), NSMaxRange(r))
                    merged[merged.count - 1] = NSRange(location: last.location, length: newMax - last.location)
                } else if r.location == NSMaxRange(last) {
                    if last.length == 0 && r.length == 0 {
                        continue
                    } else if r.length == 0 {
                        continue
                    } else if last.length == 0 {
                        merged[merged.count - 1] = r
                    } else {
                        merged.append(r)
                    }
                } else {
                    merged.append(r)
                }
            } else {
                merged.append(r)
            }
        }

        if merged.isEmpty {
            merged = [NSRange(location: 0, length: 0)]
        }

        return merged.map { NSValue(range: $0) }
    }

    public func syncDocumentSelectionRanges() {
        guard let doc = resolvedDocument else { return }
        let ranges = self.selectedRanges.map { $0.rangeValue }
        doc.selectionRanges = ranges.isEmpty ? [NppSelectionRange(anchor: 0, caret: 0)] : ranges.map { NppSelectionRange(range: $0) }
        if doc.primarySelectionIndex >= doc.selectionRanges.count {
            doc.primarySelectionIndex = 0
        }
    }

    public func characterOffset(for point: NSPoint) -> Int {
        guard let lm = self.layoutManager, let tc = self.textContainer else { return 0 }
        let text = self.string as NSString
        let docLen = text.length
        guard docLen > 0 else { return 0 }

        lm.ensureLayout(forCharacterRange: NSRange(location: 0, length: docLen))

        let origin = self.textContainerOrigin
        let containerPoint = NSPoint(x: point.x - origin.x, y: point.y - origin.y)

        if lm.extraLineFragmentRect.height > 0 && containerPoint.y >= lm.extraLineFragmentRect.minY {
            return docLen
        }

        let lineGlyph = lm.glyphIndex(for: NSPoint(x: 0, y: max(0, containerPoint.y)), in: tc)
        guard lineGlyph < lm.numberOfGlyphs else { return docLen }

        let lineUsedRect = lm.lineFragmentUsedRect(forGlyphAt: lineGlyph, effectiveRange: nil)
        let lineChar = lm.characterIndexForGlyph(at: lineGlyph)
        let lineRange = text.lineRange(for: NSRange(location: min(lineChar, docLen - 1), length: 0))
        let lineSub = text.substring(with: lineRange)
        var lineEndWithoutEol = lineRange.location + lineSub.count
        if lineSub.hasSuffix("\r\n") { lineEndWithoutEol -= 2 }
        else if lineSub.hasSuffix("\n") || lineSub.hasSuffix("\r") { lineEndWithoutEol -= 1 }

        if containerPoint.x >= lineUsedRect.maxX {
            return lineEndWithoutEol
        }
        if containerPoint.x <= lineUsedRect.minX {
            return lineRange.location
        }

        var fraction: CGFloat = 0.0
        let glyphIndex = lm.glyphIndex(for: NSPoint(x: max(0, containerPoint.x), y: max(0, containerPoint.y)), in: tc, fractionOfDistanceThroughGlyph: &fraction)
        guard glyphIndex < lm.numberOfGlyphs else { return lineEndWithoutEol }

        var charIndex = lm.characterIndexForGlyph(at: glyphIndex)
        if fraction > 0.5 && charIndex < docLen {
            charIndex += 1
        }

        return max(lineRange.location, min(charIndex, lineEndWithoutEol))
    }

    public func caretRect(for charIndex: Int) -> NSRect? {
        guard let lm = self.layoutManager, let tc = self.textContainer else { return nil }
        let text = self.string as NSString
        let docLen = text.length
        let safeIndex = max(0, min(charIndex, docLen))
        let caretW = CGFloat(max(1, resolvedWorkspace?.caretWidth ?? 1))
        let origin = self.textContainerOrigin

        if docLen == 0 {
            let fontHeight = self.font?.pointSize ?? 13.0
            return NSRect(x: origin.x, y: origin.y, width: caretW, height: fontHeight + 3.0)
        }

        if safeIndex == docLen {
            if docLen > 0 && [10, 13].contains(text.character(at: docLen - 1)) {
                if lm.extraLineFragmentRect.height > 0 {
                    var r = lm.extraLineFragmentRect
                    r.origin.x += origin.x
                    r.origin.y += origin.y
                    r.size.width = caretW
                    return r
                }
            }
            let lastGlyph = max(0, lm.numberOfGlyphs - 1)
            let glyphRect = lm.boundingRect(forGlyphRange: NSRange(location: lastGlyph, length: 1), in: tc)
            let lineRect = lm.lineFragmentRect(forGlyphAt: lastGlyph, effectiveRange: nil)
            return NSRect(x: origin.x + glyphRect.maxX, y: origin.y + lineRect.minY, width: caretW, height: lineRect.height)
        }

        let glyphIndex = lm.glyphIndexForCharacter(at: safeIndex)
        let lineRect = lm.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: nil)
        let glyphLocation = lm.location(forGlyphAt: glyphIndex)

        return NSRect(x: origin.x + lineRect.minX + glyphLocation.x, y: origin.y + lineRect.minY, width: caretW, height: lineRect.height)
    }

    private var isOptionDragging = false
    private var optionDragStartPoint: NSPoint = .zero
    private var optionDragStartLine: Int = 1
    private var optionDragStartCol: Int = 0

    private func lineAndCol(for point: NSPoint) -> (line: Int, col: Int, charIndex: Int) {
        guard let lm = self.layoutManager, let tc = self.textContainer else { return (1, 0, 0) }
        let docY = point.y - self.textContainerOrigin.y
        let text = self.string as NSString
        guard text.length > 0 else { return (1, 0, 0) }
        let glyphIndex = lm.glyphIndex(for: NSPoint(x: max(0, point.x - self.textContainerOrigin.x), y: max(0, docY)), in: tc)
        let charIndex = lm.characterIndexForGlyph(at: glyphIndex)
        let safeIndex = min(charIndex, text.length)
        let lineRange = text.lineRange(for: NSRange(location: safeIndex, length: 0))
        var lineNum = 1
        var cur = 0
        while cur < lineRange.location {
            lineNum += 1
            cur = NSMaxRange(text.lineRange(for: NSRange(location: cur, length: 0)))
        }
        let col = safeIndex - lineRange.location
        return (lineNum, col, safeIndex)
    }

    public func computeColumnRanges(fromLine: Int, fromCol: Int, toLine: Int, toCol: Int) -> [NSValue] {
        let text = self.string as NSString
        guard text.length > 0 else { return [NSValue(range: NSRange(location: 0, length: 0))] }
        let minL = min(fromLine, toLine)
        let maxL = max(fromLine, toLine)
        let minC = min(fromCol, toCol)
        let maxC = max(fromCol, toCol)

        var ranges: [NSValue] = []
        var curLine = 1
        var curPos = 0
        while curPos < text.length && curLine <= maxL {
            let lRange = text.lineRange(for: NSRange(location: curPos, length: 0))
            if curLine >= minL && curLine <= maxL {
                let lineStr = text.substring(with: lRange)
                var lineCleanLen = lineStr.count
                if lineStr.hasSuffix("\r\n") { lineCleanLen -= 2 }
                else if lineStr.hasSuffix("\n") || lineStr.hasSuffix("\r") { lineCleanLen -= 1 }

                let startOffset = min(minC, lineCleanLen)
                let endOffset = min(maxC, lineCleanLen)
                let length = max(0, endOffset - startOffset)
                let r = NSRange(location: lRange.location + startOffset, length: length)
                ranges.append(NSValue(range: r))
            }
            curPos = NSMaxRange(lRange)
            curLine += 1
        }
        return ranges.isEmpty ? [NSValue(range: NSRange(location: 0, length: 0))] : ranges
    }

    public override func mouseDown(with event: NSEvent) {
        insertedMatchedChars.removeAll()
        if event.modifierFlags.contains(.option) {
            isOptionDragging = true
            optionDragStartPoint = self.convert(event.locationInWindow, from: nil)
            let (l, c, charIdx) = lineAndCol(for: optionDragStartPoint)
            optionDragStartLine = l
            optionDragStartCol = c
            let r = NSRange(location: charIdx, length: 0)
            self.selectedRanges = [NSValue(range: r)]
            return
        }
        isOptionDragging = false

        if event.modifierFlags.contains(.command) && (resolvedWorkspace?.multiSelection ?? true) {
            handleMultiCaretMouseDown(event: event)
            return
        }

        if event.modifierFlags.contains(.command) && !(resolvedWorkspace?.multiSelection ?? true) {
            let pt = self.convert(event.locationInWindow, from: nil)
            let clickedChar = characterOffset(for: pt)
            self.selectedRanges = [NSValue(range: NSRange(location: clickedChar, length: 0))]
            isCmdDragging = false
            return
        }

        let isTest = (resolvedWorkspace?.isTestRunning == true) || CommandLine.arguments.contains("--run-tests") || (NSApp.currentEvent !== event)
        if isTest {
            let pt = self.convert(event.locationInWindow, from: nil)
            let clickedChar = characterOffset(for: pt)
            self.selectedRanges = [NSValue(range: NSRange(location: clickedChar, length: 0))]
            isCmdDragging = false
            return
        }

        isCmdDragging = false
        super.mouseDown(with: event)
    }

    public func handleMultiCaretMouseDown(event: NSEvent) {
        let pt = self.convert(event.locationInWindow, from: nil)
        let clickedChar = characterOffset(for: pt)
        var currentRanges = self.selectedRanges.map { $0.rangeValue }

        var hitIndex: Int? = nil
        for (i, r) in currentRanges.enumerated() {
            if r.length == 0 {
                if r.location == clickedChar {
                    hitIndex = i
                    break
                }
            } else {
                if clickedChar >= r.location && clickedChar <= NSMaxRange(r) {
                    hitIndex = i
                    break
                }
            }
        }

        if let hit = hitIndex, currentRanges.count > 1 {
            currentRanges.remove(at: hit)
            self.selectedRanges = currentRanges.map { NSValue(range: $0) }
            isCmdDragging = false
        } else {
            let newRange = NSRange(location: clickedChar, length: 0)
            currentRanges.append(newRange)
            let sanitized = sanitizeRanges(currentRanges.map { NSValue(range: $0) })
            self.selectedRanges = sanitized
            isCmdDragging = true
            cmdDragAnchor = clickedChar
            if let idx = sanitized.firstIndex(where: { $0.rangeValue.location == clickedChar }) {
                cmdDragRangeIndex = idx
            }
        }
    }

    public func handleMultiCaretMouseDragged(event: NSEvent) {
        let pt = self.convert(event.locationInWindow, from: nil)
        let curChar = characterOffset(for: pt)
        var currentRanges = self.selectedRanges.map { $0.rangeValue }
        let dragRange = NSRange(
            location: min(cmdDragAnchor, curChar),
            length: abs(curChar - cmdDragAnchor)
        )
        if cmdDragRangeIndex < currentRanges.count {
            currentRanges[cmdDragRangeIndex] = dragRange
        } else {
            currentRanges.append(dragRange)
        }
        self.selectedRanges = currentRanges.map { NSValue(range: $0) }
    }

    public func handleMultiCaretMouseUp(event: NSEvent) {
        isCmdDragging = false
    }

    public override func mouseDragged(with event: NSEvent) {
        if isOptionDragging {
            let pt = self.convert(event.locationInWindow, from: nil)
            let (curL, curC, _) = lineAndCol(for: pt)
            let colRanges = computeColumnRanges(
                fromLine: optionDragStartLine, fromCol: optionDragStartCol,
                toLine: curL, toCol: curC
            )
            self.selectedRanges = colRanges
            return
        }
        if isCmdDragging {
            handleMultiCaretMouseDragged(event: event)
            return
        }
        let isTest = (resolvedWorkspace?.isTestRunning == true) || CommandLine.arguments.contains("--run-tests") || (NSApp.currentEvent !== event)
        if isTest {
            return
        }
        super.mouseDragged(with: event)
    }

    public override func mouseUp(with event: NSEvent) {
        if isOptionDragging {
            isOptionDragging = false
            return
        }
        if isCmdDragging {
            handleMultiCaretMouseUp(event: event)
            return
        }
        let isTest = (resolvedWorkspace?.isTestRunning == true) || CommandLine.arguments.contains("--run-tests") || (NSApp.currentEvent !== event)
        if isTest {
            return
        }
        super.mouseUp(with: event)
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

    private func isCharPrevAlphanumeric(at pos: Int, text: NSString) -> Bool {
        guard pos > 0 && pos <= text.length else { return false }
        let c = text.character(at: pos - 1)
        guard let scalar = UnicodeScalar(c) else { return false }
        return CharacterSet.alphanumerics.contains(scalar)
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

        if completionPopupActive && event.keyCode == 48 {
            super.keyDown(with: event)
            return
        }

        if event.keyCode == 53 || event.characters == ")" {
            parameterHintPopover?.close()
        }
        if event.keyCode == 53 && self.selectedRanges.count > 1 {
            self.cancelOperation(nil)
            return
        }

        // Tab key: indent operations or spaces/tabs according to workspace.tabSize & replaceTabBySpace
        if event.keyCode == 48 && !event.modifierFlags.contains(.control) {
            let count = resolvedWorkspace?.tabSize ?? 4
            let replaceBySpaces = resolvedWorkspace?.replaceTabBySpace ?? true
            if self.selectedRanges.count > 1 {
                let strToInsert = replaceBySpaces ? String(repeating: " ", count: count) : "\t"
                self.insertText(strToInsert, replacementRange: NSRange(location: 0, length: 0))
                return
            }
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
        if !event.modifierFlags.contains(.command) && !event.modifierFlags.contains(.control) && self.selectedRanges.count <= 1,
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
                        showParameterHint()
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
                    if !isCharPrevAlphanumeric(at: range.location, text: text) && isCharNextBlankOrCloseSymbol(at: range.location, text: text) {
                        self.insertText("\"\"", replacementRange: range)
                        self.setSelectedRange(NSRange(location: range.location + 1, length: 0))
                        insertedMatchedChars.append(MatchedCharInserted(openChar: "\"", closeChar: "\"", openPos: range.location))
                        return
                    }
                }
                if ch == "'" && ws.autoInsertSingleQuote {
                    if !isCharPrevAlphanumeric(at: range.location, text: text) && isCharNextBlankOrCloseSymbol(at: range.location, text: text) {
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
            if first == "(" { showParameterHint() }
            cleanInvalidMatchedChars(caretPos: self.selectedRange().location, typedChar: first)
            if let ws = resolvedWorkspace, ws.autoCompletionEnabled,
               !event.modifierFlags.contains(.command), !event.modifierFlags.contains(.control),
               (first.isLetter || first.isNumber || first == "_"),
               self.window != nil, self.selectedRange().length == 0, self.selectedRanges.count <= 1 {
                let mode = ws.autoCompletionType
                let candidates = NppCompletionEngine.shared.candidates(
                    text: self.string,
                    caret: self.selectedRange().location,
                    language: resolvedDocument?.language ?? "",
                    mode: mode,
                    minimumLength: ws.autoCompletionThreshold,
                    ignoreNumbers: ws.autoCompletionIgnoreNumbers,
                    manual: false
                )
                if !candidates.isEmpty { showCompletions() }
            }
        }
    }

    // MARK: - Synchronized Multi-Caret Editing Engine (Scintilla Parity: Bottom-to-Top)
    public func applySynchronizedMultiCaretEdit(
        insertString: String? = nil,
        insertStrings: [String]? = nil,
        isBackspace: Bool = false,
        isForwardDelete: Bool = false
    ) {
        guard self.isEditable else { return }
        let rawRanges = self.selectedRanges.map { $0.rangeValue }
        guard !rawRanges.isEmpty else { return }

        // Must be sorted ascending
        let sortedRanges = rawRanges.sorted { $0.location < $1.location }
        let text = self.string as NSString
        let docLen = text.length

        struct EditOp {
            var targetRange: NSRange
            var replacement: String
            var delta: Int
            var originalCaretPos: Int
        }

        var editOps: [EditOp] = []

        for (i, r) in sortedRanges.enumerated() {
            let safeLoc = max(0, min(r.location, docLen))
            let safeLen = max(0, min(r.length, docLen - safeLoc))
            let effectiveRange = NSRange(location: safeLoc, length: safeLen)

            if isBackspace {
                if effectiveRange.length > 0 {
                    editOps.append(EditOp(
                        targetRange: effectiveRange,
                        replacement: "",
                        delta: -effectiveRange.length,
                        originalCaretPos: effectiveRange.location
                    ))
                } else if safeLoc > 0 {
                    var delLen = 1
                    if safeLoc >= 2 && safeLoc <= docLen && text.substring(with: NSRange(location: safeLoc - 2, length: 2)) == "\r\n" {
                        delLen = 2
                    }
                    let delRange = NSRange(location: safeLoc - delLen, length: delLen)
                    editOps.append(EditOp(
                        targetRange: delRange,
                        replacement: "",
                        delta: -delLen,
                        originalCaretPos: safeLoc - delLen
                    ))
                } else {
                    editOps.append(EditOp(
                        targetRange: NSRange(location: 0, length: 0),
                        replacement: "",
                        delta: 0,
                        originalCaretPos: 0
                    ))
                }
            } else if isForwardDelete {
                if effectiveRange.length > 0 {
                    editOps.append(EditOp(
                        targetRange: effectiveRange,
                        replacement: "",
                        delta: -effectiveRange.length,
                        originalCaretPos: effectiveRange.location
                    ))
                } else if safeLoc < docLen {
                    var delLen = 1
                    if safeLoc + 2 <= docLen && text.substring(with: NSRange(location: safeLoc, length: 2)) == "\r\n" {
                        delLen = 2
                    }
                    let delRange = NSRange(location: safeLoc, length: delLen)
                    editOps.append(EditOp(
                        targetRange: delRange,
                        replacement: "",
                        delta: -delLen,
                        originalCaretPos: safeLoc
                    ))
                } else {
                    editOps.append(EditOp(
                        targetRange: NSRange(location: docLen, length: 0),
                        replacement: "",
                        delta: 0,
                        originalCaretPos: docLen
                    ))
                }
            } else {
                let repStr: String
                if let insertStrings = insertStrings, i < insertStrings.count {
                    repStr = insertStrings[i]
                } else {
                    repStr = insertString ?? ""
                }
                let repLen = (repStr as NSString).length
                let delta = repLen - effectiveRange.length
                editOps.append(EditOp(
                    targetRange: effectiveRange,
                    replacement: repStr,
                    delta: delta,
                    originalCaretPos: effectiveRange.location + repLen
                ))
            }
        }

        // Calculate post-mutation caret locations using cumulative delta summation
        var runningDelta = 0
        var newCaretLocations: [Int] = []
        for op in editOps {
            let postPos = op.originalCaretPos + runningDelta
            newCaretLocations.append(postPos)
            runningDelta += op.delta
        }

        // Single atomic Undo/Redo grouping
        self.undoManager?.beginUndoGrouping()

        // Execute mutations strictly BOTTOM-TO-TOP (reverse offset order)
        for op in editOps.reversed() {
            if op.targetRange.length > 0 || !op.replacement.isEmpty {
                if self.shouldChangeText(in: op.targetRange, replacementString: op.replacement) {
                    self.replaceCharacters(in: op.targetRange, with: op.replacement)
                    self.didChangeText()
                }
            }
        }

        self.undoManager?.endUndoGrouping()

        // Build new NSRanges and coalesce on collision (RemoveDuplicates)
        let newDocLen = (self.string as NSString).length
        var coalescedRanges: [NSRange] = []
        for loc in newCaretLocations {
            let clamped = max(0, min(loc, newDocLen))
            let r = NSRange(location: clamped, length: 0)
            if !coalescedRanges.contains(where: { $0.location == clamped }) {
                coalescedRanges.append(r)
            }
        }

        if coalescedRanges.isEmpty {
            coalescedRanges = [NSRange(location: 0, length: 0)]
        }

        self.selectedRanges = coalescedRanges.map { NSValue(range: $0) }
        self.needsDisplay = true
    }

    private func moveMultiCaretsLeft() {
        let text = self.string as NSString
        var newRanges: [NSRange] = []
        for val in self.selectedRanges {
            let r = val.rangeValue
            if r.length > 0 {
                newRanges.append(NSRange(location: r.location, length: 0))
            } else if r.location > 0 {
                var step = 1
                if r.location >= 2 && text.substring(with: NSRange(location: r.location - 2, length: 2)) == "\r\n" {
                    step = 2
                }
                newRanges.append(NSRange(location: r.location - step, length: 0))
            } else {
                newRanges.append(NSRange(location: 0, length: 0))
            }
        }
        self.selectedRanges = sanitizeRanges(newRanges.map { NSValue(range: $0) })
        self.needsDisplay = true
    }

    private func moveMultiCaretsRight() {
        let text = self.string as NSString
        let docLen = text.length
        var newRanges: [NSRange] = []
        for val in self.selectedRanges {
            let r = val.rangeValue
            if r.length > 0 {
                newRanges.append(NSRange(location: NSMaxRange(r), length: 0))
            } else if r.location < docLen {
                var step = 1
                if r.location + 2 <= docLen && text.substring(with: NSRange(location: r.location, length: 2)) == "\r\n" {
                    step = 2
                }
                newRanges.append(NSRange(location: r.location + step, length: 0))
            } else {
                newRanges.append(NSRange(location: docLen, length: 0))
            }
        }
        self.selectedRanges = sanitizeRanges(newRanges.map { NSValue(range: $0) })
        self.needsDisplay = true
    }

    private func moveMultiCaretsUp() {
        let text = self.string as NSString
        var newRanges: [NSRange] = []
        for val in self.selectedRanges {
            let r = val.rangeValue
            let curPos = min(r.location, text.length)
            let lineInfo = NppLineCounter.lineInfo(upTo: curPos, in: text)
            if lineInfo.line > 1 {
                let col = curPos - lineInfo.lineStart
                let prevLineInfo = NppLineCounter.lineInfo(upTo: max(0, lineInfo.lineStart - 1), in: text)
                let prevLineRange = text.lineRange(for: NSRange(location: prevLineInfo.lineStart, length: 0))
                let prevLineStr = text.substring(with: prevLineRange)
                var prevCleanLen = prevLineStr.count
                if prevLineStr.hasSuffix("\r\n") { prevCleanLen -= 2 }
                else if prevLineStr.hasSuffix("\n") || prevLineStr.hasSuffix("\r") { prevCleanLen -= 1 }
                let targetCol = min(col, prevCleanLen)
                newRanges.append(NSRange(location: prevLineInfo.lineStart + targetCol, length: 0))
            } else {
                newRanges.append(NSRange(location: 0, length: 0))
            }
        }
        self.selectedRanges = sanitizeRanges(newRanges.map { NSValue(range: $0) })
        self.needsDisplay = true
    }

    private func moveMultiCaretsDown() {
        let text = self.string as NSString
        let docLen = text.length
        var newRanges: [NSRange] = []
        for val in self.selectedRanges {
            let r = val.rangeValue
            let curPos = min(r.location, docLen)
            let curLineRange = text.lineRange(for: NSRange(location: curPos, length: 0))
            let col = curPos - curLineRange.location
            let nextLineStart = NSMaxRange(curLineRange)
            if nextLineStart < docLen {
                let nextLineRange = text.lineRange(for: NSRange(location: nextLineStart, length: 0))
                let nextLineStr = text.substring(with: nextLineRange)
                var nextCleanLen = nextLineStr.count
                if nextLineStr.hasSuffix("\r\n") { nextCleanLen -= 2 }
                else if nextLineStr.hasSuffix("\n") || nextLineStr.hasSuffix("\r") { nextCleanLen -= 1 }
                let targetCol = min(col, nextCleanLen)
                newRanges.append(NSRange(location: nextLineStart + targetCol, length: 0))
            } else {
                newRanges.append(NSRange(location: docLen, length: 0))
            }
        }
        self.selectedRanges = sanitizeRanges(newRanges.map { NSValue(range: $0) })
        self.needsDisplay = true
    }

    public override func cancelOperation(_ sender: Any?) {
        if self.selectedRanges.count > 1 {
            let primary = self.selectedRanges.first ?? NSValue(range: NSRange(location: 0, length: 0))
            self.selectedRanges = [primary]
            self.needsDisplay = true
            return
        }
        super.cancelOperation(sender)
    }

    public override func insertText(_ string: Any, replacementRange: NSRange) {
        let textToInsert: String
        if let str = string as? String {
            textToInsert = str
            resolvedWorkspace?.recordMacroStep(.insertText(str))
        } else if let attr = string as? NSAttributedString {
            textToInsert = attr.string
            resolvedWorkspace?.recordMacroStep(.insertText(attr.string))
        } else {
            textToInsert = "\(string)"
        }

        guard self.selectedRanges.count > 1 else {
            super.insertText(string, replacementRange: replacementRange)
            return
        }

        applySynchronizedMultiCaretEdit(insertString: textToInsert)
    }

    public override func insertNewline(_ sender: Any?) {
        insertedMatchedChars.removeAll()

        if self.selectedRanges.count > 1 {
            applySynchronizedMultiCaretEdit(insertString: "\n")
            if let ws = resolvedWorkspace, ws.isMacroRecording {
                ws.recordMacroStep(.insertNewline)
            }
            return
        }

        guard let ws = resolvedWorkspace, ws.autoIndentMode > 0 else {
            super.insertNewline(sender)
            if let ws = resolvedWorkspace, ws.isMacroRecording {
                ws.recordMacroStep(.insertNewline)
            }
            return
        }

        let text = self.string as NSString
        let sel = self.selectedRange()
        let curPos = min(sel.location, text.length)
        let lineRange = text.lineRange(for: NSRange(location: curPos, length: 0))
        let lineBeforeCaret = text.substring(with: NSRange(location: lineRange.location, length: curPos - lineRange.location))

        var indent = ""
        for ch in lineBeforeCaret {
            if ch == " " || ch == "\t" {
                indent.append(ch)
            } else {
                break
            }
        }

        let trimmed = lineBeforeCaret.trimmingCharacters(in: .whitespaces)
        var extraIndent = ""
        let tabIndent = ws.replaceTabBySpace ? String(repeating: " ", count: max(1, ws.tabSize)) : "\t"

        if ws.autoIndentMode == 2 {
            if trimmed.hasSuffix("{") || trimmed.hasSuffix("(") || trimmed.hasSuffix("[") || trimmed.hasSuffix(":") {
                extraIndent = tabIndent
            }
        }

        let nextChar: String? = (curPos < text.length) ? text.substring(with: NSRange(location: curPos, length: 1)) : nil
        let isBetweenBraces = (trimmed.hasSuffix("{") && nextChar == "}") ||
                              (trimmed.hasSuffix("(") && nextChar == ")") ||
                              (trimmed.hasSuffix("[") && nextChar == "]")

        if ws.autoIndentMode == 2 && isBetweenBraces {
            let insertStr = "\n" + indent + extraIndent + "\n" + indent
            if self.shouldChangeText(in: sel, replacementString: insertStr) {
                self.replaceCharacters(in: sel, with: insertStr)
                self.didChangeText()
                let targetPos = curPos + 1 + indent.count + extraIndent.count
                self.setSelectedRange(NSRange(location: targetPos, length: 0))
            }
        } else {
            let insertStr = "\n" + indent + extraIndent
            if self.shouldChangeText(in: sel, replacementString: insertStr) {
                self.replaceCharacters(in: sel, with: insertStr)
                self.didChangeText()
                self.setSelectedRange(NSRange(location: curPos + insertStr.count, length: 0))
            }
        }

        if ws.isMacroRecording {
            ws.recordMacroStep(.insertNewline)
        }
    }

    public override func doCommand(by selector: Selector) {
        if self.selectedRanges.count > 1 {
            switch selector {
            case #selector(NSStandardKeyBindingResponding.deleteBackward(_:)):
                applySynchronizedMultiCaretEdit(isBackspace: true)
                if let ws = resolvedWorkspace, ws.isMacroRecording {
                    ws.recordMacroStep(.deleteBackward)
                }
                return
            case #selector(NSStandardKeyBindingResponding.deleteForward(_:)):
                applySynchronizedMultiCaretEdit(isForwardDelete: true)
                if let ws = resolvedWorkspace, ws.isMacroRecording {
                    ws.recordMacroStep(.deleteForward)
                }
                return
            case #selector(NSStandardKeyBindingResponding.insertNewline(_:)):
                self.insertNewline(nil)
                return
            case #selector(NSStandardKeyBindingResponding.moveLeft(_:)):
                moveMultiCaretsLeft()
                if let ws = resolvedWorkspace, ws.isMacroRecording {
                    ws.recordMacroStep(.moveLeft)
                }
                return
            case #selector(NSStandardKeyBindingResponding.moveRight(_:)):
                moveMultiCaretsRight()
                if let ws = resolvedWorkspace, ws.isMacroRecording {
                    ws.recordMacroStep(.moveRight)
                }
                return
            case #selector(NSStandardKeyBindingResponding.moveUp(_:)):
                moveMultiCaretsUp()
                if let ws = resolvedWorkspace, ws.isMacroRecording {
                    ws.recordMacroStep(.moveUp)
                }
                return
            case #selector(NSStandardKeyBindingResponding.moveDown(_:)):
                moveMultiCaretsDown()
                if let ws = resolvedWorkspace, ws.isMacroRecording {
                    ws.recordMacroStep(.moveDown)
                }
                return
            case #selector(NSStandardKeyBindingResponding.cancelOperation(_:)):
                self.cancelOperation(nil)
                return
            default:
                break
            }
        }

        if selector == #selector(NSStandardKeyBindingResponding.deleteBackward(_:)) {
            if handleSmartPairDeleteBackward() {
                if let ws = resolvedWorkspace, ws.isMacroRecording {
                    ws.recordMacroStep(.deleteBackward)
                }
                return
            }
        }
        if selector == #selector(NSStandardKeyBindingResponding.insertNewline(_:)) {
            self.insertNewline(nil)
            return
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
        if self.selectedRanges.count > 1 {
            let replaceBySpaces = resolvedWorkspace?.replaceTabBySpace ?? true
            let strToInsert = replaceBySpaces ? String(repeating: " ", count: tabSize) : "\t"
            self.insertText(strToInsert, replacementRange: NSRange(location: 0, length: 0))
            return
        }
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
        if let ws = resolvedWorkspace, ws.isMacroRecording {
            ws.recordMacroStep(.cut)
        }

        guard self.selectedRanges.count > 1 else {
            super.cut(sender)
            if let clip = NSPasteboard.general.string(forType: .string) {
                resolvedWorkspace?.addToClipboardHistory(clip)
            }
            return
        }

        self.copy(sender)
        applySynchronizedMultiCaretEdit(insertString: "")
    }

    public override func copy(_ sender: Any?) {
        if let ws = resolvedWorkspace, ws.isMacroRecording {
            ws.recordMacroStep(.copy)
        }

        guard self.selectedRanges.count > 1 else {
            super.copy(sender)
            if let clip = NSPasteboard.general.string(forType: .string) {
                resolvedWorkspace?.addToClipboardHistory(clip)
            }
            return
        }

        let text = self.string as NSString
        let nonEmpties = self.selectedRanges.map { $0.rangeValue }.filter { $0.length > 0 && NSMaxRange($0) <= text.length }
        if !nonEmpties.isEmpty {
            let joined = nonEmpties.map { text.substring(with: $0) }.joined(separator: "\n")
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(joined, forType: .string)
            resolvedWorkspace?.addToClipboardHistory(joined)
        }
    }

    public override func paste(_ sender: Any?) {
        if let ws = resolvedWorkspace, ws.isMacroRecording {
            ws.recordMacroStep(.paste)
        }

        guard self.selectedRanges.count > 1 else {
            super.paste(sender)
            return
        }

        guard let clipString = NSPasteboard.general.string(forType: .string) else {
            super.paste(sender)
            return
        }

        let normalized = clipString.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        let rawLines = normalized.components(separatedBy: "\n")

        if rawLines.count == self.selectedRanges.count {
            applySynchronizedMultiCaretEdit(insertStrings: rawLines)
        } else {
            applySynchronizedMultiCaretEdit(insertString: clipString)
        }
    }

    public override func selectAll(_ sender: Any?) {
        resolvedWorkspace?.recordMacroStep(.selectAll)
        super.selectAll(sender)
    }

    // MARK: - Notepad++ Caret Width (SCI_SETCARETWIDTH: 1, 2, 3)
    public override func drawInsertionPoint(in rect: NSRect, color: NSColor, turnedOn flag: Bool) {
        self.caretBlinkTurnedOn = flag
        guard flag else {
            if self.selectedRanges.count > 1 {
                self.setNeedsDisplay(self.visibleRect, avoidAdditionalLayout: true)
            }
            return
        }
        let caretW = CGFloat(max(1, resolvedWorkspace?.caretWidth ?? 1))
        var caretRect = rect
        caretRect.size.width = caretW
        color.set()
        caretRect.fill()

        if self.selectedRanges.count > 1 {
            self.setNeedsDisplay(self.visibleRect, avoidAdditionalLayout: true)
        }
    }

    // MARK: - Notepad++ Active Line Highlight Bar (drawn behind text)
    public override func drawBackground(in rect: NSRect) {
        super.drawBackground(in: rect)

        let shouldHighlightLine = editorCoordinator?.parent.workspace.highlightCurrentLine ?? true
        let lineIndicatorMode = editorCoordinator?.parent.workspace.currentLineIndicator ?? 1
        if shouldHighlightLine && lineIndicatorMode != 0, let layoutManager = self.layoutManager {
            let str = self.string as NSString
            let theme = editorCoordinator?.parent.workspace.currentTheme
            let lineHighlightColor = theme?.activeLineColor ?? NSColor(calibratedRed: 0.17, green: 0.18, blue: 0.20, alpha: 0.95)
            let frameWidth = CGFloat(max(1, editorCoordinator?.parent.workspace.currentLineFrameWidth ?? 1))

            var drawnY: Set<CGFloat> = []

            for val in self.selectedRanges {
                let sel = val.rangeValue
                guard sel.length == 0 else { continue }

                var lineRect: NSRect
                if str.length > 0 && layoutManager.numberOfGlyphs > 0 {
                    let charPos = min(sel.location, max(0, str.length - 1))
                    let glyphIdx = min(layoutManager.glyphIndexForCharacter(at: charPos), layoutManager.numberOfGlyphs - 1)
                    if sel.location == str.length && [10, 13].contains(str.character(at: str.length - 1)) && layoutManager.extraLineFragmentRect.height > 0 {
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

                guard !drawnY.contains(lineRect.origin.y) else { continue }
                drawnY.insert(lineRect.origin.y)

                lineRect.origin.x = 0
                lineRect.size.width = max(self.bounds.width, self.visibleRect.width)

                if lineIndicatorMode == 1 {
                    // Background Highlight
                    lineHighlightColor.setFill()
                    NSBezierPath(rect: lineRect).fill()
                } else if lineIndicatorMode == 2 {
                    // Frame Outline
                    let strokeRect = lineRect.insetBy(dx: 0.5, dy: 0.5)
                    lineHighlightColor.setStroke()
                    let path = NSBezierPath(rect: strokeRect)
                    path.lineWidth = frameWidth
                    path.stroke()
                }
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
           ws.showInvisibleCharacters || ws.showSpaceAndTab || ws.showEndOfLine || ws.showNonPrintingCharacters || ws.showControlCharsAndUnicodeEol || ws.showIndentGuides || (ws.isWordWrapEnabled && ws.showWrapSymbol) {
            drawInvisibleCharacters(in: dirtyRect)
        }
    }

    private static let controlMnemonicTable: [UInt16: String] = [
        0: "NUL", 1: "SOH", 2: "STX", 3: "ETX", 4: "EOT", 5: "ENQ", 6: "ACK", 7: "BEL",
        8: "BS", 11: "VT", 12: "FF", 14: "SO", 15: "SI", 16: "DLE", 17: "DC1", 18: "DC2",
        19: "DC3", 20: "DC4", 21: "NAK", 22: "SYN", 23: "ETB", 24: "CAN", 25: "EM", 26: "SUB",
        27: "ESC", 28: "FS", 29: "GS", 30: "RS", 31: "US", 127: "DEL", 160: "NBSP"
    ]

    private func drawInvisibleCharacters(in dirtyRect: NSRect) {
        guard let layoutManager = self.layoutManager, let textContainer = self.textContainer,
              let ws = editorCoordinator?.parent.workspace else { return }
        let drawWS = ws.showInvisibleCharacters || ws.showSpaceAndTab
        let drawEOL = ws.showInvisibleCharacters || ws.showEndOfLine
        let drawNPC = ws.showInvisibleCharacters || ws.showNonPrintingCharacters
        let drawCCUniEOL = ws.showInvisibleCharacters || ws.showControlCharsAndUnicodeEol
        let drawIndent = ws.showIndentGuides
        let drawWrap = ws.isWordWrapEnabled && ws.showWrapSymbol
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
            } else if drawNPC, let mnemonic = Self.controlMnemonicTable[ch] {
                let badgeFont = NSFont.monospacedSystemFont(ofSize: 7.5, weight: .bold)
                let badgeAttrs: [NSAttributedString.Key: Any] = [.font: badgeFont, .foregroundColor: NSColor.white]
                let textSize = (mnemonic as NSString).size(withAttributes: badgeAttrs)
                let badgeRect = NSRect(x: x, y: y + (lineRect.height - textSize.height - 2) / 2.0, width: textSize.width + 4, height: textSize.height + 2)
                color.setFill()
                NSBezierPath(roundedRect: badgeRect, xRadius: 2, yRadius: 2).fill()
                mnemonic.draw(at: NSPoint(x: badgeRect.origin.x + 2, y: badgeRect.origin.y + 1), withAttributes: badgeAttrs)
            } else if drawCCUniEOL && (ch == 0x2028 || ch == 0x2029 || ch == 0x0085) {
                let badge = ch == 0x2028 ? "LS" : (ch == 0x2029 ? "PS" : "NEL")
                let badgeFont = NSFont.systemFont(ofSize: 7.5, weight: .bold)
                let attrs: [NSAttributedString.Key: Any] = [.font: badgeFont, .foregroundColor: color]
                "[\(badge)]".draw(at: NSPoint(x: x + 2.0, y: y + (lineRect.height - 7.5) / 2.0), withAttributes: attrs)
            }
            i += 1
        }

        if drawIndent {
            let tabW = charWidth * CGFloat(max(1, ws.tabSize))
            let guideColor = (theme?.isDark ?? true)
                ? NSColor(calibratedWhite: 0.35, alpha: 0.4)
                : NSColor(calibratedWhite: 0.65, alpha: 0.4)
            guideColor.setStroke()
            layoutManager.enumerateLineFragments(forGlyphRange: glyphRange) { rect, usedRect, container, range, stop in
                let charR = layoutManager.characterRange(forGlyphRange: range, actualGlyphRange: nil)
                guard charR.location < str.length else { return }
                var indentChars = 0
                while charR.location + indentChars < str.length {
                    let c = str.character(at: charR.location + indentChars)
                    if c == 32 || c == 9 {
                        indentChars += (c == 9 ? ws.tabSize : 1)
                    } else {
                        break
                    }
                }
                let maxGuides = indentChars / max(1, ws.tabSize)
                if maxGuides > 0 {
                    for g in 1...maxGuides {
                        let gx = containerOrigin.x + rect.origin.x + (CGFloat(g) * tabW)
                        let path = NSBezierPath()
                        path.move(to: NSPoint(x: gx, y: containerOrigin.y + rect.origin.y))
                        path.line(to: NSPoint(x: gx, y: containerOrigin.y + rect.origin.y + rect.height))
                        path.lineWidth = 1.0
                        let dashes: [CGFloat] = [1.0, 2.0]
                        path.setLineDash(dashes, count: 2, phase: 0)
                        path.stroke()
                    }
                }
            }
        }

        if drawWrap {
            let wrapFont = NSFont.systemFont(ofSize: 9.0, weight: .bold)
            let wrapAttrs: [NSAttributedString.Key: Any] = [.font: wrapFont, .foregroundColor: color.withAlphaComponent(0.6)]
            layoutManager.enumerateLineFragments(forGlyphRange: glyphRange) { rect, usedRect, container, range, stop in
                let charR = layoutManager.characterRange(forGlyphRange: range, actualGlyphRange: nil)
                if NSMaxRange(charR) < str.length {
                    let lastCh = str.character(at: NSMaxRange(charR) - 1)
                    if lastCh != 10 && lastCh != 13 {
                        let wrapX = containerOrigin.x + usedRect.maxX + 2.0
                        let wrapY = containerOrigin.y + rect.origin.y + (rect.height - wrapFont.pointSize) / 2.0
                        "↵".draw(at: NSPoint(x: wrapX, y: wrapY), withAttributes: wrapAttrs)
                    }
                }
            }
        }

        // 4. Multi-Caret Secondary Insertion Points
        if self.selectedRanges.count > 1 && self.caretBlinkTurnedOn {
            let caretColor = resolvedWorkspace?.currentTheme.foregroundColor ?? self.insertionPointColor ?? NSColor.textColor
            caretColor.set()
            for val in self.selectedRanges.dropFirst() {
                let r = val.rangeValue
                let caretPos = (r.length == 0) ? r.location : NSMaxRange(r)
                if let cRect = caretRect(for: caretPos) {
                    cRect.fill()
                }
            }
        }
    }

    // MARK: - NSUserInterfaceValidations
    public override func validateUserInterfaceItem(_ item: NSValidatedUserInterfaceItem) -> Bool {
        let isDocReadOnly = !self.isEditable || (editorCoordinator?.parent.document.isReadOnly ?? false)
        let mutatingSelectors: Set<Selector> = [
            #selector(NSText.cut(_:)),
            #selector(NSText.delete(_:)),
            #selector(NSText.paste(_:)),
            #selector(contextToggleComment),
            #selector(contextBlockComment),
            #selector(contextBlockUncomment),
            #selector(contextUppercase),
            #selector(contextLowercase),
            #selector(contextProperCase),
            #selector(contextSentenceCase),
            #selector(contextInvertCase),
            #selector(contextDuplicateLine),
            #selector(contextJoinLines),
            #selector(contextSplitLines),
            #selector(contextRemoveEmptyLines),
            #selector(contextRemoveDuplicateLines),
            #selector(contextSortAscending),
            #selector(contextSortDescending),
            #selector(contextReverseLines),
            #selector(contextTrimTrailing),
            #selector(contextTrimLeading),
            #selector(contextTrimBoth),
            #selector(contextEolToSpace),
            #selector(contextTabToSpace),
            #selector(contextSpaceToTab),
            #selector(contextInsertDateShort),
            #selector(contextInsertDateLong)
        ]
        if let action = item.action, mutatingSelectors.contains(action) {
            return !isDocReadOnly
        }
        return super.validateUserInterfaceItem(item)
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

        // Style one token Submenu
        let styleOneMenuItem = NSMenuItem(title: tr("Style one token"), action: nil, keyEquivalent: "")
        let styleOneMenu = NSMenu(title: tr("Style one token"))
        let styleOne1 = NSMenuItem(title: tr("Using 1st Style"), action: #selector(contextStyleOne1), keyEquivalent: "")
        styleOne1.target = self
        styleOneMenu.addItem(styleOne1)
        let styleOne2 = NSMenuItem(title: tr("Using 2nd Style"), action: #selector(contextStyleOne2), keyEquivalent: "")
        styleOne2.target = self
        styleOneMenu.addItem(styleOne2)
        let styleOne3 = NSMenuItem(title: tr("Using 3rd Style"), action: #selector(contextStyleOne3), keyEquivalent: "")
        styleOne3.target = self
        styleOneMenu.addItem(styleOne3)
        let styleOne4 = NSMenuItem(title: tr("Using 4th Style"), action: #selector(contextStyleOne4), keyEquivalent: "")
        styleOne4.target = self
        styleOneMenu.addItem(styleOne4)
        let styleOne5 = NSMenuItem(title: tr("Using 5th Style"), action: #selector(contextStyleOne5), keyEquivalent: "")
        styleOne5.target = self
        styleOneMenu.addItem(styleOne5)
        styleOneMenuItem.submenu = styleOneMenu
        menu.addItem(styleOneMenuItem)

        // Clear Style Submenu
        let clearStyleMenuItem = NSMenuItem(title: tr("Clear style"), action: nil, keyEquivalent: "")
        let clearStyleMenu = NSMenu(title: tr("Clear style"))
        let clearStyle1 = NSMenuItem(title: tr("Clear 1st Style"), action: #selector(contextClearStyle1), keyEquivalent: "")
        clearStyle1.target = self
        clearStyleMenu.addItem(clearStyle1)
        let clearStyle2 = NSMenuItem(title: tr("Clear 2nd Style"), action: #selector(contextClearStyle2), keyEquivalent: "")
        clearStyle2.target = self
        clearStyleMenu.addItem(clearStyle2)
        let clearStyle3 = NSMenuItem(title: tr("Clear 3rd Style"), action: #selector(contextClearStyle3), keyEquivalent: "")
        clearStyle3.target = self
        clearStyleMenu.addItem(clearStyle3)
        let clearStyle4 = NSMenuItem(title: tr("Clear 4th Style"), action: #selector(contextClearStyle4), keyEquivalent: "")
        clearStyle4.target = self
        clearStyleMenu.addItem(clearStyle4)
        let clearStyle5 = NSMenuItem(title: tr("Clear 5th Style"), action: #selector(contextClearStyle5), keyEquivalent: "")
        clearStyle5.target = self
        clearStyleMenu.addItem(clearStyle5)
        clearStyleMenu.addItem(NSMenuItem.separator())
        let clearAllStyle = NSMenuItem(title: tr("Clear all Styles"), action: #selector(contextClearStyle), keyEquivalent: "")
        clearAllStyle.target = self
        clearStyleMenu.addItem(clearAllStyle)
        clearStyleMenuItem.submenu = clearStyleMenu
        menu.addItem(clearStyleMenuItem)
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
        guard self.isEditable, let doc = editorCoordinator?.parent.document, !doc.isReadOnly else { return }
        NppEditOperations.toggleComment(in: self, language: doc.language)
    }
    @objc func contextBlockComment() {
        guard self.isEditable, let doc = editorCoordinator?.parent.document, !doc.isReadOnly else { return }
        NppEditOperations.streamComment(in: self, language: doc.language)
    }
    @objc func contextBlockUncomment() {
        guard self.isEditable, let doc = editorCoordinator?.parent.document, !doc.isReadOnly else { return }
        NppEditOperations.streamUncomment(in: self, language: doc.language)
    }
    @objc func contextUppercase() {
        guard self.isEditable, let doc = editorCoordinator?.parent.document, !doc.isReadOnly else { return }
        NppEditOperations.convertCase(in: self, to: .uppercase)
    }
    @objc func contextLowercase() {
        guard self.isEditable, let doc = editorCoordinator?.parent.document, !doc.isReadOnly else { return }
        NppEditOperations.convertCase(in: self, to: .lowercase)
    }
    @objc func contextProperCase() {
        guard self.isEditable, let doc = editorCoordinator?.parent.document, !doc.isReadOnly else { return }
        NppEditOperations.convertCase(in: self, to: .properCase)
    }
    @objc func contextSentenceCase() {
        guard self.isEditable, let doc = editorCoordinator?.parent.document, !doc.isReadOnly else { return }
        NppEditOperations.convertCase(in: self, to: .sentenceCase)
    }
    @objc func contextInvertCase() {
        guard self.isEditable, let doc = editorCoordinator?.parent.document, !doc.isReadOnly else { return }
        NppEditOperations.convertCase(in: self, to: .invertCase)
    }

    @objc func contextDuplicateLine() {
        guard self.isEditable, let doc = editorCoordinator?.parent.document, !doc.isReadOnly else { return }
        NppEditOperations.duplicateLine(in: self)
    }
    @objc func contextJoinLines() {
        guard self.isEditable, let doc = editorCoordinator?.parent.document, !doc.isReadOnly else { return }
        NppEditOperations.joinLines(in: self)
    }
    @objc func contextSplitLines() {
        guard self.isEditable, let doc = editorCoordinator?.parent.document, !doc.isReadOnly else { return }
        NppEditOperations.splitLines(in: self)
    }
    private func performContextDocumentOp(_ op: (NppDocument) -> Void) {
        guard self.isEditable, let doc = editorCoordinator?.parent.document, !doc.isReadOnly else { return }
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
        guard self.isEditable, let doc = editorCoordinator?.parent.document, !doc.isReadOnly else { return }
        resolvedWorkspace?.recordMacroStep(.removeEmptyLinesContainingBlanks)
        performContextDocumentOp { NppEditOperations.removeEmptyLines(in: $0, removeBlankChars: true) }
    }
    @objc func contextRemoveDuplicateLines() {
        guard self.isEditable, let doc = editorCoordinator?.parent.document, !doc.isReadOnly else { return }
        resolvedWorkspace?.recordMacroStep(.removeDuplicateLines)
        performContextDocumentOp { NppEditOperations.removeDuplicateLines(in: $0) }
    }
    @objc func contextSortAscending() {
        guard self.isEditable, let doc = editorCoordinator?.parent.document, !doc.isReadOnly else { return }
        resolvedWorkspace?.recordMacroStep(.sortLines)
        performContextDocumentOp { NppEditOperations.sortLines(in: $0, ascending: true) }
    }
    @objc func contextSortDescending() {
        guard self.isEditable, let doc = editorCoordinator?.parent.document, !doc.isReadOnly else { return }
        resolvedWorkspace?.recordMacroStep(.sortLinesDescending)
        performContextDocumentOp { NppEditOperations.sortLines(in: $0, ascending: false) }
    }
    @objc func contextReverseLines() {
        guard self.isEditable, let doc = editorCoordinator?.parent.document, !doc.isReadOnly else { return }
        resolvedWorkspace?.recordMacroStep(.reverseLineOrder)
        performContextDocumentOp { NppEditOperations.reverseLineOrder(in: $0) }
    }

    @objc func contextTrimTrailing() {
        guard self.isEditable, let doc = editorCoordinator?.parent.document, !doc.isReadOnly else { return }
        resolvedWorkspace?.recordMacroStep(.trimTrailingSpace)
        performContextDocumentOp { NppEditOperations.trimSpaces(in: $0, mode: .trailing) }
    }
    @objc func contextTrimLeading() {
        guard self.isEditable, let doc = editorCoordinator?.parent.document, !doc.isReadOnly else { return }
        resolvedWorkspace?.recordMacroStep(.trimLeadingSpace)
        performContextDocumentOp { NppEditOperations.trimSpaces(in: $0, mode: .leading) }
    }
    @objc func contextTrimBoth() {
        guard self.isEditable, let doc = editorCoordinator?.parent.document, !doc.isReadOnly else { return }
        resolvedWorkspace?.recordMacroStep(.trimBothSpace)
        performContextDocumentOp { NppEditOperations.trimSpaces(in: $0, mode: .both) }
    }
    @objc func contextEolToSpace() {
        guard self.isEditable, let doc = editorCoordinator?.parent.document, !doc.isReadOnly else { return }
        resolvedWorkspace?.recordMacroStep(.eolToSpace)
        performContextDocumentOp { NppEditOperations.eolToSpace(in: $0) }
    }
    @objc func contextTabToSpace() {
        guard self.isEditable, let doc = editorCoordinator?.parent.document, !doc.isReadOnly else { return }
        resolvedWorkspace?.recordMacroStep(.tabToSpace)
        performContextDocumentOp { NppEditOperations.tabToSpace(in: $0, spaceCount: resolvedWorkspace?.tabSize ?? 4) }
    }
    @objc func contextSpaceToTab() {
        guard self.isEditable, let doc = editorCoordinator?.parent.document, !doc.isReadOnly else { return }
        resolvedWorkspace?.recordMacroStep(.spaceToTab)
        performContextDocumentOp { NppEditOperations.spaceToTab(in: $0, spaceCount: resolvedWorkspace?.tabSize ?? 4) }
    }

    @objc func contextInsertDateShort() {
        guard self.isEditable, let doc = editorCoordinator?.parent.document, !doc.isReadOnly else { return }
        NppEditOperations.insertDateTime(in: self, isLong: false)
    }
    @objc func contextInsertDateLong() {
        guard self.isEditable, let doc = editorCoordinator?.parent.document, !doc.isReadOnly else { return }
        NppEditOperations.insertDateTime(in: self, isLong: true)
    }

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

    @objc func contextStyleOne1() { _ = resolvedWorkspace?.styleOneToken(styleIndex: 1) }
    @objc func contextStyleOne2() { _ = resolvedWorkspace?.styleOneToken(styleIndex: 2) }
    @objc func contextStyleOne3() { _ = resolvedWorkspace?.styleOneToken(styleIndex: 3) }
    @objc func contextStyleOne4() { _ = resolvedWorkspace?.styleOneToken(styleIndex: 4) }
    @objc func contextStyleOne5() { _ = resolvedWorkspace?.styleOneToken(styleIndex: 5) }

    @objc func contextClearStyle1() { resolvedWorkspace?.clearStyle(styleIndex: 1) }
    @objc func contextClearStyle2() { resolvedWorkspace?.clearStyle(styleIndex: 2) }
    @objc func contextClearStyle3() { resolvedWorkspace?.clearStyle(styleIndex: 3) }
    @objc func contextClearStyle4() { resolvedWorkspace?.clearStyle(styleIndex: 4) }
    @objc func contextClearStyle5() { resolvedWorkspace?.clearStyle(styleIndex: 5) }

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
