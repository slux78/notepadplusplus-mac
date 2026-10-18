import AppKit

public final class NppGutterView: NSRulerView {
    public weak var textView: NSTextView?

    public init(textView: NSTextView) {
        self.textView = textView
        super.init(scrollView: textView.enclosingScrollView, orientation: .verticalRuler)
        self.clientView = textView
        self.ruleThickness = 45.0
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func drawHashMarksAndLabels(in rect: NSRect) {
        guard let textView = self.textView,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else { return }

        let isDark = self.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let bgColor = isDark ? NSColor(calibratedWhite: 0.14, alpha: 1.0) : NSColor(calibratedWhite: 0.94, alpha: 1.0)
        let fgColor = isDark ? NSColor(calibratedWhite: 0.55, alpha: 1.0) : NSColor(calibratedWhite: 0.50, alpha: 1.0)
        let activeFgColor = isDark ? NSColor(calibratedRed: 0.9, green: 0.8, blue: 0.3, alpha: 1.0) : NSColor(calibratedRed: 0.1, green: 0.1, blue: 0.1, alpha: 1.0)
        let borderColor = isDark ? NSColor(calibratedWhite: 0.22, alpha: 1.0) : NSColor(calibratedWhite: 0.82, alpha: 1.0)

        // Background
        bgColor.setFill()
        rect.fill()

        // Border line on right
        borderColor.setStroke()
        let path = NSBezierPath()
        path.move(to: NSPoint(x: bounds.maxX - 0.5, y: rect.minY))
        path.line(to: NSPoint(x: bounds.maxX - 0.5, y: rect.maxY))
        path.lineWidth = 1.0
        path.stroke()

        let visibleGlyphRange = layoutManager.glyphRange(forBoundingRect: textView.visibleRect, in: textContainer)
        let text = textView.string as NSString
        guard text.length > 0 else {
            // Draw line 1
            let font = textView.font ?? NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: activeFgColor
            ]
            let str = NSAttributedString(string: "1", attributes: attrs)
            let strRect = str.boundingRect(with: NSSize(width: bounds.width - 8, height: 20), options: [])
            str.draw(at: NSPoint(x: bounds.maxX - strRect.width - 6, y: textView.textContainerOrigin.y))
            return
        }

        var lineIndex = 1
        // Calculate line number up to start of visible range
        let startCharIndex = layoutManager.characterIndexForGlyph(at: visibleGlyphRange.location)
        text.enumerateSubstrings(in: NSRange(location: 0, length: startCharIndex), options: [.byLines, .substringNotRequired]) { _, _, _, _ in
            lineIndex += 1
        }

        let font = textView.font ?? NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        let selectedRange = textView.selectedRange()
        let cursorLineNum = getLineNumber(for: selectedRange.location, in: text)

        var glyphIndex = visibleGlyphRange.location
        while glyphIndex < NSMaxRange(visibleGlyphRange) {
            let charIndex = layoutManager.characterIndexForGlyph(at: glyphIndex)
            let lineRange = text.lineRange(for: NSRange(location: charIndex, length: 0))
            let lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: nil)

            let isCurrentLine = (lineIndex == cursorLineNum)
            let textColor = isCurrentLine ? activeFgColor : fgColor
            let textFont = isCurrentLine ? NSFont.monospacedSystemFont(ofSize: font.pointSize, weight: .bold) : font

            let attrs: [NSAttributedString.Key: Any] = [
                .font: textFont,
                .foregroundColor: textColor
            ]

            let numStr = "\(lineIndex)"
            let str = NSAttributedString(string: numStr, attributes: attrs)
            let strRect = str.boundingRect(with: NSSize(width: bounds.width - 8, height: lineRect.height), options: [])

            let yPos = textView.textContainerOrigin.y + lineRect.origin.y + (lineRect.height - strRect.height) / 2.0
            str.draw(at: NSPoint(x: bounds.maxX - strRect.width - 6, y: yPos))

            lineIndex += 1
            glyphIndex = NSMaxRange(layoutManager.glyphRange(forCharacterRange: lineRange, actualCharacterRange: nil))
        }
    }

    private func getLineNumber(for charIndex: Int, in string: NSString) -> Int {
        guard charIndex <= string.length else { return 1 }
        var lineNum = 1
        string.enumerateSubstrings(in: NSRange(location: 0, length: charIndex), options: [.byLines, .substringNotRequired]) { _, _, _, _ in
            lineNum += 1
        }
        return lineNum
    }
}
