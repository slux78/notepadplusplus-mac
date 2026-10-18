import SwiftUI
import AppKit

public struct NppStatusBarView: View {
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
            // Box 1: length : 108   lines : 10 (Notepad++ exact format)
            let charCount = doc.content.count
            let lineCount = max(1, doc.content.components(separatedBy: .newlines).count)
            NppStatusBarBox(width: 175) {
                Text("length : \(charCount)   lines : \(lineCount)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
            }

            // Box 2: Ln : 8   Col : 21   Pos : 102 (and Sel if selected)
            NppStatusBarBox(width: doc.selectionLength > 0 ? 210 : 170) {
                Button(action: {
                    showGoToLineDialog()
                }) {
                    if doc.selectionLength > 0 {
                        Text("Ln : \(doc.cursorLine)  Col : \(doc.cursorCol)  Pos : \(doc.cursorPos + 1)  Sel : \(doc.selectionLength)")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.secondary)
                    } else {
                        Text("Ln : \(doc.cursorLine)   Col : \(doc.cursorCol)   Pos : \(doc.cursorPos + 1)")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }

            Spacer()

            // Box 3: Windows (CR LF) / Unix (LF) / Macintosh (CR)
            NppStatusBarBox(width: 130) {
                Menu {
                    Button("Windows (CR LF)") {
                        doc.convertEOL(to: .crlf)
                        workspace.objectWillChange.send()
                    }
                    Button("Unix (LF)") {
                        doc.convertEOL(to: .lf)
                        workspace.objectWillChange.send()
                    }
                    Button("Macintosh (CR)") {
                        doc.convertEOL(to: .cr)
                        workspace.objectWillChange.send()
                    }
                } label: {
                    Text(doc.eolFormat.displayName)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.primary)
                }
                .menuStyle(BorderlessButtonMenuStyle())
            }

            // Box 4: Encoding (UTF-8, Windows-949, ANSI, etc.)
            NppStatusBarBox(width: 130) {
                Menu {
                    Section("Convert to...") {
                        Button("Convert to UTF-8") {
                            doc.convertEncoding(to: "UTF-8", addBOM: false)
                            workspace.objectWillChange.send()
                        }
                        Button("Convert to UTF-8 with BOM") {
                            doc.convertEncoding(to: "UTF-8", addBOM: true)
                            workspace.objectWillChange.send()
                        }
                        Button("Convert to Korean (Windows 949 / CP949)") {
                            doc.convertEncoding(to: "CP949")
                            workspace.objectWillChange.send()
                        }
                        Button("Convert to Korean (EUC-KR)") {
                            doc.convertEncoding(to: "EUC-KR")
                            workspace.objectWillChange.send()
                        }
                        Button("Convert to ANSI (Windows-1252)") {
                            doc.convertEncoding(to: "WINDOWS-1252")
                            workspace.objectWillChange.send()
                        }
                        Button("Convert to UTF-16 LE") {
                            doc.convertEncoding(to: "UTF-16LE")
                            workspace.objectWillChange.send()
                        }
                        Button("Convert to UTF-16 BE") {
                            doc.convertEncoding(to: "UTF-16BE")
                            workspace.objectWillChange.send()
                        }
                    }

                    Divider()

                    Section("Character Sets (Re-interpret)") {
                        Button("Unicode -> UTF-8") {
                            doc.reencodeAs(targetCharset: "UTF-8")
                            workspace.objectWillChange.send()
                        }
                        Button("Korean -> Windows 949 (CP949)") {
                            doc.reencodeAs(targetCharset: "CP949")
                            workspace.objectWillChange.send()
                        }
                        Button("Korean -> EUC-KR") {
                            doc.reencodeAs(targetCharset: "EUC-KR")
                            workspace.objectWillChange.send()
                        }
                        Button("Japanese -> Shift-JIS") {
                            doc.reencodeAs(targetCharset: "CP932")
                            workspace.objectWillChange.send()
                        }
                        Button("Chinese -> Simplified (GB18030)") {
                            doc.reencodeAs(targetCharset: "GB18030")
                            workspace.objectWillChange.send()
                        }
                        Button("Chinese -> Traditional (Big5)") {
                            doc.reencodeAs(targetCharset: "BIG5")
                            workspace.objectWillChange.send()
                        }
                        Button("Western -> ANSI (Windows-1252)") {
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

            // Box 5: INS / OVR
            NppStatusBarBox(width: 45) {
                Button(action: {
                    workspace.isOverwriteMode.toggle()
                }) {
                    Text(workspace.isOverwriteMode ? "OVR" : "INS")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(workspace.isOverwriteMode ? .red : .secondary)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .frame(height: 22)
    }

    private func showGoToLineDialog() {
        let alert = NSAlert()
        alert.messageText = "Go to Line"
        alert.informativeText = "Enter line number (1 - \(max(1, doc.content.components(separatedBy: .newlines).count))):"
        alert.addButton(withTitle: "Go")
        alert.addButton(withTitle: "Cancel")

        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        input.stringValue = "\(doc.cursorLine)"
        alert.accessoryView = input

        if alert.runModal() == .alertFirstButtonReturn {
            if let targetLine = Int(input.stringValue), targetLine >= 1 {
                let lines = doc.content.components(separatedBy: .newlines)
                let clampedLine = min(targetLine, lines.count)
                var charIndex = 0
                for i in 0..<(clampedLine - 1) {
                    charIndex += lines[i].count + 1
                }
                doc.cursorPos = charIndex
                doc.cursorLine = clampedLine
                doc.cursorCol = 1
                doc.selectionLength = 0
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
        HStack {
            content
                .lineLimit(1)
            Spacer()
            Divider().frame(height: 14)
        }
        .frame(width: width)
        .padding(.horizontal, 6)
    }
}
