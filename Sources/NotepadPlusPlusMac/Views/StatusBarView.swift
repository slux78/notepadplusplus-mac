import SwiftUI
import AppKit

public struct NppStatusBarView: View {
    public static let box2Width: CGFloat = 240
    public static let box3WidthUnselected: CGFloat = 270
    public static let box3WidthSelected: CGFloat = 340

    @ObservedObject var workspace: NppWorkspace

    public init(workspace: NppWorkspace) {
        self.workspace = workspace
    }

    public var body: some View {
        Group {
            if let doc = workspace.activeDocument {
                NppActiveStatusBarContent(doc: doc, workspace: workspace)
            } else {
                HStack {
                    Text("No document")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                        .padding(.leading, 8)
                    Spacer()
                }
                .frame(height: 22)
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(NSColor.separatorColor)),
            alignment: .top
        )
    }
}

public struct NppActiveStatusBarContent: View {
    @ObservedObject var doc: NppDocument
    @ObservedObject var workspace: NppWorkspace

    public var body: some View {
        HStack(spacing: 0) {
            // Box 1: File Type / Language (Click to open Language Menu per user-interface.md:295)
            NppStatusBarBox(width: 140) {
                Menu {
                    Button(workspace.tr("None (Normal Text)")) {
                        doc.language = ""
                        workspace.objectWillChange.send()
                    }
                    Divider()
                    ForEach(NppWorkspace.defaultLanguages, id: \.self) { lang in
                        Button(action: {
                            doc.language = lang
                            workspace.objectWillChange.send()
                        }) {
                            let check = (doc.language == lang) ? "✓ " : "   "
                            Text("\(check)\(lang)")
                        }
                    }
                } label: {
                    Text(doc.language.isEmpty ? "Normal text file" : "\(doc.language) file")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                }
                .menuStyle(BorderlessButtonMenuStyle())
                .help(workspace.tr("Language Menu (Click to change language)"))
            }

            // Box 2: length : 108   lines : 10 (Double click opens View > Summary per user-interface.md:301)
            let charCount = (doc.content as NSString).length
            let lineCount = max(1, doc.content.nppLines().count)
            let box2Text = "length : \(charCount)   lines : \(lineCount)"
            let box2TextWidth = (box2Text as NSString).size(withAttributes: [.font: NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)]).width
            let box2ActualWidth = max(NppStatusBarView.box2Width, box2TextWidth + 24)
            NppStatusBarBox(width: box2ActualWidth) {
                Button(action: {
                    workspace.showDocumentSummary()
                }) {
                    Text(box2Text)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
                .help(workspace.tr("Document Summary (Double-click or click to open Summary)"))
            }

            // Box 3: Ln : 8   Col : 21   Pos : 102 (and Sel if selected)
            let box3Text = (doc.selectionLength > 0)
                ? "Ln : \(doc.cursorLine)  Col : \(doc.cursorCol)  Pos : \(doc.cursorPos + 1)  Sel : \(doc.selectionLength)"
                : "Ln : \(doc.cursorLine)   Col : \(doc.cursorCol)   Pos : \(doc.cursorPos + 1)"
            let box3MinWidth = doc.selectionLength > 0 ? NppStatusBarView.box3WidthSelected : NppStatusBarView.box3WidthUnselected
            let box3TextWidth = (box3Text as NSString).size(withAttributes: [.font: NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)]).width
            let box3ActualWidth = max(box3MinWidth, box3TextWidth + 24)
            NppStatusBarBox(width: box3ActualWidth) {
                Button(action: {
                    showGoToLineDialog()
                }) {
                    Text(box3Text)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
            }

            Spacer()

            // Box 4: Windows (CR LF) / Unix (LF) / Macintosh (CR)
            NppStatusBarBox(width: 130) {
                Menu {
                    Button(workspace.tr("Windows (CR LF)")) {
                        doc.convertEOL(to: .crlf)
                        workspace.objectWillChange.send()
                    }
                    Button(workspace.tr("Unix (LF)")) {
                        doc.convertEOL(to: .lf)
                        workspace.objectWillChange.send()
                    }
                    Button(workspace.tr("Macintosh (CR)")) {
                        doc.convertEOL(to: .cr)
                        workspace.objectWillChange.send()
                    }
                } label: {
                    Text(workspace.tr(doc.eolFormat.displayName))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.primary)
                }
                .menuStyle(BorderlessButtonMenuStyle())
            }

            // Box 5: Encoding (UTF-8, Windows-949, ANSI, etc.)
            NppStatusBarBox(width: 130) {
                Menu {
                    Section(workspace.tr("Encoding")) {
                        Button(workspace.tr("Convert to UTF-8")) {
                            doc.convertEncoding(to: "UTF-8", addBOM: false)
                            workspace.objectWillChange.send()
                        }
                        Button(workspace.tr("Convert to UTF-8-BOM")) {
                            doc.convertEncoding(to: "UTF-8", addBOM: true)
                            workspace.objectWillChange.send()
                        }
                        Button(workspace.tr("Convert to Korean (Windows 949 / CP949)")) {
                            doc.convertEncoding(to: "CP949")
                            workspace.objectWillChange.send()
                        }
                        Button(workspace.tr("Convert to Korean (EUC-KR)")) {
                            doc.convertEncoding(to: "EUC-KR")
                            workspace.objectWillChange.send()
                        }
                        Button(workspace.tr("Convert to ANSI")) {
                            doc.convertEncoding(to: "WINDOWS-1252")
                            workspace.objectWillChange.send()
                        }
                        Button("UTF-16 LE BOM") {
                            doc.convertEncoding(to: "UTF-16LE")
                            workspace.objectWillChange.send()
                        }
                        Button("UTF-16 BE BOM") {
                            doc.convertEncoding(to: "UTF-16BE")
                            workspace.objectWillChange.send()
                        }
                    }

                    Divider()

                    Section(workspace.tr("Character sets")) {
                        Button("UTF-8") {
                            doc.reencodeAs(targetCharset: "UTF-8")
                            workspace.objectWillChange.send()
                        }
                        Button("Windows 949 (CP949)") {
                            doc.reencodeAs(targetCharset: "CP949")
                            workspace.objectWillChange.send()
                        }
                        Button("EUC-KR") {
                            doc.reencodeAs(targetCharset: "EUC-KR")
                            workspace.objectWillChange.send()
                        }
                        Button("Shift-JIS") {
                            doc.reencodeAs(targetCharset: "CP932")
                            workspace.objectWillChange.send()
                        }
                        Button("GB2312 (Simplified)") {
                            doc.reencodeAs(targetCharset: "GB18030")
                            workspace.objectWillChange.send()
                        }
                        Button("Big5 (Traditional)") {
                            doc.reencodeAs(targetCharset: "BIG5")
                            workspace.objectWillChange.send()
                        }
                        Button("ANSI") {
                            doc.reencodeAs(targetCharset: "WINDOWS-1252")
                            workspace.objectWillChange.send()
                        }
                    }
                } label: {
                    Text(doc.encodingDisplayName)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.primary)
                }
                .menuStyle(BorderlessButtonMenuStyle())
            }

            // Box 6: Typing Mode (INS / OVR, width 48, toggles on click per user-interface.md:315)
            NppStatusBarBox(width: 48) {
                Button(action: {
                    workspace.isOverwriteMode.toggle()
                }) {
                    Text(workspace.isOverwriteMode ? "OVR" : "INS")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(workspace.isOverwriteMode ? .red : .primary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .buttonStyle(PlainButtonStyle())
                .help(workspace.tr("Typing Mode: Insert (INS) / Overwrite (OVR). Click to toggle."))
            }
        }
        .frame(height: 22)
    }

    private func showGoToLineDialog() {
        let totalLines = max(1, doc.content.nppLines().count)
        let alert = NSAlert()
        alert.messageText = workspace.tr("Go to...")
        alert.informativeText = "1 - \(totalLines):"
        alert.addButton(withTitle: workspace.tr("OK"))
        alert.addButton(withTitle: workspace.tr("Cancel"))

        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        input.stringValue = "\(doc.cursorLine)"
        alert.accessoryView = input

        if alert.runModal() == .alertFirstButtonReturn {
            if let targetLine = Int(input.stringValue), targetLine >= 1 {
                workspace.jumpToLine(min(targetLine, totalLines))
                workspace.objectWillChange.send()
            }
        }
    }
}

public struct NppStatusBarBox<Content: View>: View {
    let width: CGFloat
    let content: Content

    public init(width: CGFloat, @ViewBuilder content: () -> Content) {
        self.width = width
        self.content = content()
    }

    public var body: some View {
        HStack(spacing: 4) {
            content
                .lineLimit(1)
            Spacer(minLength: 2)
            Divider().frame(height: 14)
        }
        .padding(.leading, 3)
        .padding(.trailing, 1)
        .frame(width: width)
    }
}
