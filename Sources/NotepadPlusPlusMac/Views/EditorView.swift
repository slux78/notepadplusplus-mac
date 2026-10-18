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
        guard let textView = context.coordinator.textView else { return }

        // Update content if changed externally (e.g., encoding conversion or open)
        if textView.string != document.content {
            let selectedRange = textView.selectedRange()
            textView.string = document.content
            if selectedRange.location <= (document.content as NSString).length {
                textView.setSelectedRange(selectedRange)
            }
            context.coordinator.applyHighlighting()
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
    public override func keyDown(with event: NSEvent) {
        // Handle Tab key: insert 4 spaces (or Tab)
        if event.keyCode == 48 && !event.modifierFlags.contains(.shift) && !event.modifierFlags.contains(.control) {
            self.insertText("    ", replacementRange: self.selectedRange())
            return
        }

        // Duplicate Line: Cmd + D
        if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "d" {
            duplicateCurrentLine()
            return
        }

        super.keyDown(with: event)
    }

    private func duplicateCurrentLine() {
        let str = self.string as NSString
        let sel = self.selectedRange()
        let lineRange = str.lineRange(for: NSRange(location: sel.location, length: 0))
        let lineText = str.substring(with: lineRange)
        
        let insertPos = NSMaxRange(lineRange)
        var textToInsert = lineText
        if !lineText.hasSuffix("\n") && !lineText.hasSuffix("\r") {
            textToInsert = "\n" + lineText
        }

        self.shouldChangeText(in: NSRange(location: insertPos, length: 0), replacementString: textToInsert)
        self.insertText(textToInsert, replacementRange: NSRange(location: insertPos, length: 0))
        self.didChangeText()
    }
}
