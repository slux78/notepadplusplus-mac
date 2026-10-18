import SwiftUI
import AppKit

public struct NppStatusBarView: View {
    @ObservedObject var workspace: NppWorkspace

    public init(workspace: NppWorkspace) {
        self.workspace = workspace
    }

    public var body: some View {
        HStack(spacing: 0) {
            if let doc = workspace.activeDocument {
                // 1. Line & Column & Position
                StatusBarSection(
                    text: "Ln : \(doc.cursorLine)   Col : \(doc.cursorCol)   Pos : \(doc.cursorPos + 1)",
                    width: 170
                )

                // 2. Selection info
                StatusBarSection(
                    text: "Sel : \(doc.selectionLength) | 0",
                    width: 90
                )

                // 3. Document Length & Lines
                let charCount = doc.content.count
                let lineCount = doc.content.components(separatedBy: .newlines).count
                StatusBarSection(
                    text: "Length : \(charCount)   Lines : \(lineCount)",
                    width: 160
                )

                Spacer()

                // 4. EOL Format (Clickable menu to convert EOL)
                Menu {
                    Button("Windows (CR LF)") { doc.convertEOL(to: .crlf) }
                    Button("Unix (LF)") { doc.convertEOL(to: .lf) }
                    Button("Macintosh (CR)") { doc.convertEOL(to: .cr) }
                } label: {
                    Text(doc.eolFormat.displayName)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.primary)
                }
                .menuStyle(BorderlessButtonMenuStyle())
                .frame(width: 130)
                .padding(.horizontal, 4)

                Divider().frame(height: 14)

                // 5. Encoding (Clickable menu to convert or change encoding)
                Menu {
                    Section("Convert to...") {
                        Button("Convert to UTF-8") { doc.convertEncoding(to: "UTF-8", addBOM: false) }
                        Button("Convert to UTF-8 with BOM") { doc.convertEncoding(to: "UTF-8", addBOM: true) }
                        Button("Convert to Korean (CP949)") { doc.convertEncoding(to: "CP949") }
                        Button("Convert to Korean (EUC-KR)") { doc.convertEncoding(to: "EUC-KR") }
                        Button("Convert to Western (Windows-1252)") { doc.convertEncoding(to: "WINDOWS-1252") }
                    }
                    Divider()
                    Section("Character Sets") {
                        Button("Korean -> Windows-949 (CP949)") { doc.reencodeAs(targetCharset: "CP949") }
                        Button("Korean -> EUC-KR") { doc.reencodeAs(targetCharset: "EUC-KR") }
                        Button("Japanese -> Shift-JIS") { doc.reencodeAs(targetCharset: "CP932") }
                        Button("Chinese -> GB18030") { doc.reencodeAs(targetCharset: "GB18030") }
                        Button("Unicode -> UTF-8") { doc.reencodeAs(targetCharset: "UTF-8") }
                    }
                } label: {
                    Text(doc.hasBOM ? "\(doc.encoding) w/ BOM" : doc.encoding)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.primary)
                }
                .menuStyle(BorderlessButtonMenuStyle())
                .frame(width: 140)
                .padding(.horizontal, 4)

                Divider().frame(height: 14)

                // 6. Language & INS mode
                Menu {
                    ForEach(["Plain Text", "C", "C++", "Swift", "Python", "JavaScript", "HTML", "JSON", "XML", "SQL", "Shell", "Markdown"], id: \.self) { lang in
                        Button(lang) {
                            doc.language = lang
                        }
                    }
                } label: {
                    Text(doc.language)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .menuStyle(BorderlessButtonMenuStyle())
                .frame(width: 90)

                Divider().frame(height: 14)

                Text("INS")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(.secondary)
                    .frame(width: 40)
            } else {
                Spacer()
            }
        }
        .frame(height: 22)
        .background(Color(NSColor.windowBackgroundColor))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(NSColor.separatorColor)),
            alignment: .top
        )
    }
}

public struct StatusBarSection: View {
    let text: String
    let width: CGFloat

    public var body: some View {
        HStack {
            Text(text)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.secondary)
                .lineLimit(1)
            Spacer()
            Divider().frame(height: 14)
        }
        .frame(width: width)
        .padding(.leading, 8)
    }
}
