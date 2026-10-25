import AppKit

public final class NppGutterView: NSRulerView {
    public weak var textView: NSTextView? {
        didSet {
            setupScrollAndLayoutObservers()
        }
    }
    public weak var document: NppDocument?
    public weak var workspace: NppWorkspace?
    public var gutterBackground: NSColor?
    public var gutterForeground: NSColor?

    public override var isFlipped: Bool {
        return true
    }

    public init(textView: NSTextView) {
        self.textView = textView
        super.init(scrollView: textView.enclosingScrollView, orientation: .verticalRuler)
        self.clientView = textView
        self.ruleThickness = 54.0
        setupScrollAndLayoutObservers()
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    public func setupScrollAndLayoutObservers() {
        NotificationCenter.default.removeObserver(self)
        guard let tv = self.textView else { return }

        tv.postsFrameChangedNotifications = true
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleTextViewOrScrollChanged(_:)),
            name: NSView.frameDidChangeNotification,
            object: tv
        )

        if let clipView = tv.enclosingScrollView?.contentView {
            clipView.postsBoundsChangedNotifications = true
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleTextViewOrScrollChanged(_:)),
                name: NSView.boundsDidChangeNotification,
                object: clipView
            )
            clipView.postsFrameChangedNotifications = true
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleTextViewOrScrollChanged(_:)),
                name: NSView.frameDidChangeNotification,
                object: clipView
            )
        }

        if let ts = tv.textStorage {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleTextViewOrScrollChanged(_:)),
                name: NSTextStorage.didProcessEditingNotification,
                object: ts
            )
        }
    }

    @objc private func handleTextViewOrScrollChanged(_ notification: Notification) {
        self.needsDisplay = true
    }

    public override func draw(_ dirtyRect: NSRect) {
        // Always redraw full bounds of the gutter to prevent partial-rect clipping artifacts during scroll
        drawHashMarksAndLabels(in: self.bounds)
    }

    private func convertPointFromTextView(_ point: NSPoint, textView: NSTextView) -> NSPoint {
        if self.window != nil && textView.window != nil && self.window == textView.window {
            return self.convert(point, from: textView)
        }
        return point
    }

    public func calculateTargetThickness() -> CGFloat {
        guard let textView = self.textView else { return self.ruleThickness }
        let font = textView.font ?? NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        let numFontSize = max(9.0, min(24.0, font.pointSize - 1.0))
        let numFont = NSFont.monospacedDigitSystemFont(ofSize: numFontSize, weight: .regular)
        let singleDigitWidth = ("8" as NSString).size(withAttributes: [.font: numFont]).width

        let text = textView.string as NSString
        let totalLines = max(1, getLineNumber(for: text.length, in: text))
        let isDynamic = workspace?.lineNumberDynamicWidth ?? true
        let minDigits = isDynamic ? 3 : 4
        let digits = max(minDigits, String(totalLines).count)

        let digitsWidth = ceil(CGFloat(digits) * singleDigitWidth)
        let showBookmarkMargin = workspace?.displayBookmarkMargin ?? true
        let bookmarkMarginWidth: CGFloat = showBookmarkMargin ? 18.0 : 0.0
        let padding: CGFloat = 14.0
        return bookmarkMarginWidth + digitsWidth + padding
    }

    public override func drawHashMarksAndLabels(in rect: NSRect) {
        guard let textView = self.textView,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else { return }

        // Ensure layout is up-to-date for visible rect before querying glyph positions
        let visibleRect = textView.visibleRect
        let containerOrigin = textView.textContainerOrigin
        let visibleContainerRect = visibleRect.offsetBy(dx: -containerOrigin.x, dy: -containerOrigin.y)
        layoutManager.ensureLayout(forBoundingRect: visibleContainerRect, in: textContainer)

        let isDark = (workspace?.currentTheme.isDark) ?? (self.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua)
        let theme = workspace?.currentTheme
        let bgColor = theme?.gutterBackground ?? (isDark ? NSColor(calibratedWhite: 0.14, alpha: 1.0) : NSColor(calibratedRed: 0.94, green: 0.94, blue: 0.94, alpha: 1.0))
        let fgColor = theme?.gutterForeground ?? (isDark ? NSColor(calibratedWhite: 0.55, alpha: 1.0) : NSColor(calibratedWhite: 0.45, alpha: 1.0))
        let activeFgColor = isDark ? NSColor(calibratedRed: 0.95, green: 0.85, blue: 0.35, alpha: 1.0) : NSColor(calibratedWhite: 0.10, alpha: 1.0)
        let borderColor = isDark ? NSColor(calibratedWhite: 0.22, alpha: 1.0) : NSColor(calibratedWhite: 0.80, alpha: 1.0)
        let showBookmarkMargin = workspace?.displayBookmarkMargin ?? true

        let text = textView.string as NSString
        let font = textView.font ?? NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)

        // Line number font: Dedicated monospaced digit font matching editor point size
        let numFontSize = max(9.0, min(24.0, font.pointSize - 1.0))
        let numFont = NSFont.monospacedDigitSystemFont(ofSize: numFontSize, weight: .regular)
        let activeNumFont = NSFont.monospacedDigitSystemFont(ofSize: numFontSize, weight: .bold)
        let singleDigitWidth = ("8" as NSString).size(withAttributes: [.font: numFont]).width

        // Upstream Notepad++ parity (ScintillaEditView.cpp L3572-3592):
        // Dynamic mode: minimum 3 digits ("999"); Constant mode: minimum 4 digits ("9999")
        let totalLines = max(1, getLineNumber(for: text.length, in: text))
        let isDynamic = workspace?.lineNumberDynamicWidth ?? true
        let minDigits = isDynamic ? 3 : 4
        let digits = max(minDigits, String(totalLines).count)

        let digitsWidth = ceil(CGFloat(digits) * singleDigitWidth)
        let bookmarkMarginWidth: CGFloat = showBookmarkMargin ? 18.0 : 0.0
        let padding: CGFloat = 14.0 // 8px left margin + 6px right spacing
        let targetThickness = bookmarkMarginWidth + digitsWidth + padding

        if abs(self.ruleThickness - targetThickness) > 0.5 {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                if abs(self.ruleThickness - targetThickness) > 0.5 {
                    self.ruleThickness = targetThickness
                }
            }
        }

        // Fill entire gutter background to prevent scroll artifacts
        let fullBounds = self.bounds
        bgColor.setFill()
        fullBounds.fill()

        // Border line on right
        borderColor.setStroke()
        let path = NSBezierPath()
        path.move(to: NSPoint(x: fullBounds.maxX - 0.5, y: fullBounds.minY))
        path.line(to: NSPoint(x: fullBounds.maxX - 0.5, y: fullBounds.maxY))
        path.lineWidth = 1.0
        path.stroke()

        // Bookmark Margin separator on left if enabled
        if showBookmarkMargin {
            let marginSeparatorColor = isDark ? NSColor(calibratedWhite: 0.22, alpha: 1.0) : NSColor(calibratedWhite: 0.84, alpha: 1.0)
            marginSeparatorColor.setStroke()
            let mPath = NSBezierPath()
            mPath.move(to: NSPoint(x: bookmarkMarginWidth - 0.5, y: fullBounds.minY))
            mPath.line(to: NSPoint(x: bookmarkMarginWidth - 0.5, y: fullBounds.maxY))
            mPath.lineWidth = 1.0
            mPath.stroke()
        }

        guard text.length > 0 && layoutManager.numberOfGlyphs > 0 else {
            // Draw line 1 for empty document
            let attrs: [NSAttributedString.Key: Any] = [
                .font: activeNumFont,
                .foregroundColor: activeFgColor
            ]
            let str = NSAttributedString(string: "1", attributes: attrs)
            let strRect = str.boundingRect(with: NSSize(width: fullBounds.width - 8, height: 24), options: [])
            let docPt = NSPoint(x: 0, y: containerOrigin.y)
            let gutterPt = convertPointFromTextView(docPt, textView: textView)
            let yPos = gutterPt.y
            str.draw(at: NSPoint(x: fullBounds.maxX - strRect.width - 6, y: yPos))

            if showBookmarkMargin && (document?.bookmarkedLines.contains(1) == true) {
                drawBookmarkGlyph(at: NSPoint(x: 3.5, y: yPos + (strRect.height - 9.0) / 2.0))
            }
            return
        }

        let visibleGlyphRange = layoutManager.glyphRange(forBoundingRect: visibleContainerRect, in: textContainer)
        let selectedRange = textView.selectedRange()
        let cursorLineNum = getLineNumber(for: selectedRange.location, in: text)

        let firstVisibleCharIndex = visibleGlyphRange.length > 0
            ? layoutManager.characterIndexForGlyph(at: visibleGlyphRange.location)
            : 0
        var lineIndex = getLineNumber(for: firstVisibleCharIndex, in: text)
        var charIndex = text.lineRange(for: NSRange(location: firstVisibleCharIndex, length: 0)).location

        let maxVisibleGlyph = NSMaxRange(visibleGlyphRange)

        while charIndex < text.length {
            let lineCharRange = text.lineRange(for: NSRange(location: charIndex, length: 0))
            let lineGlyphRange = layoutManager.glyphRange(forCharacterRange: lineCharRange, actualCharacterRange: nil)
            if lineGlyphRange.location >= maxVisibleGlyph && charIndex > firstVisibleCharIndex {
                break
            }

            if lineGlyphRange.location < layoutManager.numberOfGlyphs {
                let lineRect = layoutManager.lineFragmentRect(forGlyphAt: lineGlyphRange.location, effectiveRange: nil)
                let docPt = NSPoint(x: 0, y: containerOrigin.y + lineRect.origin.y)
                let gutterPt = convertPointFromTextView(docPt, textView: textView)

                if gutterPt.y > fullBounds.maxY {
                    break
                }

                if gutterPt.y + lineRect.height >= fullBounds.minY {
                    let isCurrentLine = (lineIndex == cursorLineNum)
                    let textColor = isCurrentLine ? activeFgColor : fgColor
                    let textFont = isCurrentLine ? activeNumFont : numFont

                    let attrs: [NSAttributedString.Key: Any] = [
                        .font: textFont,
                        .foregroundColor: textColor
                    ]

                    let numStr = "\(lineIndex)"
                    let str = NSAttributedString(string: numStr, attributes: attrs)
                    let strRect = str.boundingRect(with: NSSize(width: fullBounds.width - 8, height: lineRect.height), options: [])

                    let yPos = gutterPt.y + (lineRect.height - strRect.height) / 2.0
                    str.draw(at: NSPoint(x: fullBounds.maxX - strRect.width - 6, y: yPos))

                    if showBookmarkMargin && (document?.bookmarkedLines.contains(lineIndex) == true) {
                        drawBookmarkGlyph(at: NSPoint(x: 3.5, y: yPos + (strRect.height - 9.0) / 2.0))
                    }
                }
            }

            lineIndex += 1
            let nextCharIndex = NSMaxRange(lineCharRange)
            if nextCharIndex <= charIndex {
                break
            }
            charIndex = nextCharIndex
        }

        // Handle trailing empty line after a final '\n' (extraLineFragmentRect)
        if text.length > 0 && text.character(at: text.length - 1) == 10 {
            let extraRect = layoutManager.extraLineFragmentRect
            if extraRect.height > 0 {
                let docPt = NSPoint(x: 0, y: containerOrigin.y + extraRect.origin.y)
                let gutterPt = convertPointFromTextView(docPt, textView: textView)
                if gutterPt.y + extraRect.height >= fullBounds.minY && gutterPt.y <= fullBounds.maxY {
                    let isCurrentLine = (lineIndex == cursorLineNum)
                    let textColor = isCurrentLine ? activeFgColor : fgColor
                    let textFont = isCurrentLine ? activeNumFont : numFont
                    let attrs: [NSAttributedString.Key: Any] = [
                        .font: textFont,
                        .foregroundColor: textColor
                    ]
                    let numStr = "\(lineIndex)"
                    let str = NSAttributedString(string: numStr, attributes: attrs)
                    let strRect = str.boundingRect(with: NSSize(width: fullBounds.width - 8, height: extraRect.height), options: [])
                    let yPos = gutterPt.y + (extraRect.height - strRect.height) / 2.0
                    str.draw(at: NSPoint(x: fullBounds.maxX - strRect.width - 6, y: yPos))

                    if showBookmarkMargin && (document?.bookmarkedLines.contains(lineIndex) == true) {
                        drawBookmarkGlyph(at: NSPoint(x: 3.5, y: yPos + (strRect.height - 9.0) / 2.0))
                    }
                }
            }
        }
    }

    private func drawBookmarkGlyph(at origin: NSPoint) {
        let bookmarkRect = NSRect(x: origin.x, y: origin.y, width: 9.0, height: 9.0)
        let circlePath = NSBezierPath(ovalIn: bookmarkRect)
        // Scintilla Dodger Blue Fill
        NSColor(calibratedRed: 0.18, green: 0.52, blue: 0.94, alpha: 1.0).setFill()
        circlePath.fill()
        // Darker border
        NSColor(calibratedRed: 0.08, green: 0.35, blue: 0.75, alpha: 1.0).setStroke()
        circlePath.lineWidth = 1.0
        circlePath.stroke()
    }

    public override func mouseDown(with event: NSEvent) {
        guard let textView = self.textView,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else {
            super.mouseDown(with: event)
            return
        }

        let pointInTextView = textView.convert(event.locationInWindow, from: nil)
        let docY = pointInTextView.y - textView.textContainerOrigin.y
        let text = textView.string as NSString
        guard text.length > 0 else {
            workspace?.toggleBookmark(line: 1)
            needsDisplay = true
            return
        }

        let glyphIndex = layoutManager.glyphIndex(for: NSPoint(x: 0, y: max(0, docY)), in: textContainer)
        let charIndex = layoutManager.characterIndexForGlyph(at: glyphIndex)
        let clickedLine = getLineNumber(for: charIndex, in: text)

        workspace?.toggleBookmark(line: clickedLine)
        needsDisplay = true
    }

    private func getLineNumber(for charIndex: Int, in string: NSString) -> Int {
        guard charIndex > 0 && string.length > 0 else { return 1 }
        let safeIndex = min(charIndex, string.length)
        var lineNum = 1
        for i in 0..<safeIndex {
            if string.character(at: i) == 10 { // LF '\n'
                lineNum += 1
            }
        }
        return lineNum
    }
}
