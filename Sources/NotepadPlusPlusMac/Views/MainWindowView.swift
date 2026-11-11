import SwiftUI

public struct NppMainWindowView: View {
    @ObservedObject var workspace: NppWorkspace

    public init(workspace: NppWorkspace) {
        self.workspace = workspace
    }

    public var body: some View {
        VStack(spacing: 0) {
            // 1. Toolbar
            if !workspace.hideToolbar {
                NppToolbarView(workspace: workspace)
            }

            // 2. Tab Bar (Single View only; in Dual View each pane has its own tab bar)
            if !workspace.isDualView && !workspace.hideTabBar {
                NppTabBarView(workspace: workspace, viewIndex: 0)
            }

            // 3. Search Bar (if visible and at top)
            if workspace.showSearchBar && workspace.incSearchBarAtTop {
                NppSearchBarView(workspace: workspace)
            }

            // 4. Editor Area with optional sidebars (Document List, Folder as Workspace, Function List, Document Map)
            HStack(spacing: 0) {
                if workspace.showDocumentList {
                    NppDocumentListView(workspace: workspace)
                        .frame(width: 220)
                    Divider()
                }

                if workspace.showFolderAsWorkspace {
                    NppFolderAsWorkspaceView(workspace: workspace)
                        .frame(width: 220)
                    Divider()
                }

                if workspace.showProjectPanel1 {
                    NppProjectPanelView(workspace: workspace, panelIndex: 1)
                        .frame(width: 220)
                    Divider()
                }

                if workspace.showProjectPanel2 {
                    NppProjectPanelView(workspace: workspace, panelIndex: 2)
                        .frame(width: 220)
                    Divider()
                }

                if workspace.showProjectPanel3 {
                    NppProjectPanelView(workspace: workspace, panelIndex: 3)
                        .frame(width: 220)
                    Divider()
                }

                if workspace.showFunctionList {
                    NppFunctionListView(workspace: workspace)
                        .frame(width: 210)
                    Divider()
                }

                // Main Editor or Dual View Area
                if workspace.isDualView {
                    GeometryReader { geo in
                        if workspace.splitDirection == .vertical {
                            HStack(spacing: 0) {
                                if workspace.isViewSwapped {
                                    secondaryEditorPane
                                        .frame(width: max(100, geo.size.width * workspace.splitRatio - 3))
                                    NppSplitterBarView(workspace: workspace, totalSize: geo.size.width, isVertical: true)
                                        .frame(width: 6)
                                    primaryEditorPane
                                        .frame(width: max(100, geo.size.width * (1.0 - workspace.splitRatio) - 3))
                                } else {
                                    primaryEditorPane
                                        .frame(width: max(100, geo.size.width * workspace.splitRatio - 3))
                                    NppSplitterBarView(workspace: workspace, totalSize: geo.size.width, isVertical: true)
                                        .frame(width: 6)
                                    secondaryEditorPane
                                        .frame(width: max(100, geo.size.width * (1.0 - workspace.splitRatio) - 3))
                                }
                            }
                        } else {
                            VStack(spacing: 0) {
                                if workspace.isViewSwapped {
                                    secondaryEditorPane
                                        .frame(height: max(60, geo.size.height * workspace.splitRatio - 3))
                                    NppSplitterBarView(workspace: workspace, totalSize: geo.size.height, isVertical: false)
                                        .frame(height: 6)
                                    primaryEditorPane
                                        .frame(height: max(60, geo.size.height * (1.0 - workspace.splitRatio) - 3))
                                } else {
                                    primaryEditorPane
                                        .frame(height: max(60, geo.size.height * workspace.splitRatio - 3))
                                    NppSplitterBarView(workspace: workspace, totalSize: geo.size.height, isVertical: false)
                                        .frame(height: 6)
                                    secondaryEditorPane
                                        .frame(height: max(60, geo.size.height * (1.0 - workspace.splitRatio) - 3))
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    if let doc = workspace.activeDocument {
                        NppEditorView(document: doc, workspace: workspace, viewIndex: 0)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        noDocPlaceholderView
                    }
                }

                if workspace.showCharacterPanel {
                    Divider()
                    NppCharacterPanelView(workspace: workspace)
                        .frame(width: 280)
                }

                if workspace.showClipboardHistory {
                    Divider()
                    NppClipboardHistoryView(workspace: workspace)
                        .frame(width: 240)
                }

                if workspace.showDocumentMap {
                    Divider()
                    NppDocumentMapView(workspace: workspace)
                        .frame(width: 140)
                }

                if workspace.showUserDefineDialog && workspace.isUserDefineDialogDocked {
                    Divider()
                    NppUserDefineDialogView(workspace: workspace, onClose: {
                        workspace.showUserDefineDialog = false
                    })
                    .frame(width: 520)
                }
            }

            // Search Bar (if visible and at bottom)
            if workspace.showSearchBar && !workspace.incSearchBarAtTop {
                NppSearchBarView(workspace: workspace)
            }

            // 5. Search Results Panel (Notepad++ Find Result dock)
            if workspace.showSearchResultsPanel && !workspace.searchFileGroups.isEmpty {
                NppSearchResultsView(workspace: workspace)
            }

            // 6. Status Bar
            if !workspace.hideStatusBar {
                NppStatusBarView(workspace: workspace)
            }
        }
        .frame(minWidth: 700, minHeight: 450)
        .preferredColorScheme(workspace.currentTheme.isDark ? .dark : .light)
        .sheet(isPresented: $workspace.showPreferencesSheet) {
            NppPreferencesView(workspace: workspace, isPresented: $workspace.showPreferencesSheet)
        }
        .sheet(isPresented: $workspace.showStyleConfigurator) {
            NppStyleConfiguratorView(workspace: workspace, isPresented: $workspace.showStyleConfigurator)
        }
        .sheet(isPresented: $workspace.showShortcutMapper) {
            NppShortcutMapperView(workspace: workspace, isPresented: $workspace.showShortcutMapper)
        }
        .sheet(isPresented: $workspace.showColumnEditor) {
            NppColumnEditorView(workspace: workspace, isPresented: $workspace.showColumnEditor)
        }
        .sheet(isPresented: $workspace.showRunMacroDialog) {
            NppRunMacroDialogView(workspace: workspace, isPresented: $workspace.showRunMacroDialog)
        }
        .onDrop(of: ["public.file-url"], isTargeted: nil) { providers in
            for provider in providers {
                provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, _ in
                    var targetUrl: URL?
                    if let url = item as? URL {
                        targetUrl = url
                    } else if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                        targetUrl = url
                    }
                    if let url = targetUrl {
                        DispatchQueue.main.async {
                            workspace.openFile(url: url)
                        }
                    }
                }
            }
            return true
        }
        .overlay(alignment: .topTrailing) {
            if workspace.isFullScreen || workspace.isPostItMode {
                Button(action: {
                    if workspace.isPostItMode {
                        workspace.togglePostItMode(window: NSApp.keyWindow)
                    } else if workspace.isFullScreen {
                        NSApp.keyWindow?.toggleFullScreen(nil)
                        workspace.isFullScreen = false
                    }
                }) {
                    Text("⊞")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.primary)
                        .frame(width: 28, height: 24)
                        .background(Color(NSColor.windowBackgroundColor).opacity(0.85))
                        .cornerRadius(4)
                        .shadow(radius: 2)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                        )
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.top, 8)
                .padding(.trailing, 12)
                .help(workspace.tr("Restore View (F11/F12)"))
            }
        }
    }

    private var primaryEditorPane: some View {
        VStack(spacing: 0) {
            if !workspace.hideTabBar {
                NppTabBarView(workspace: workspace, viewIndex: 0)
            }
            if let doc = workspace.activeDocument {
                NppEditorView(document: doc, workspace: workspace, viewIndex: 0)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                noDocPlaceholderView
            }
        }
    }

    private var secondaryEditorPane: some View {
        VStack(spacing: 0) {
            if !workspace.hideTabBar {
                NppTabBarView(workspace: workspace, viewIndex: 1)
            }
            if let doc = workspace.secondaryActiveDocument {
                NppEditorView(document: doc, workspace: workspace, viewIndex: 1)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                noDocPlaceholderView
            }
        }
    }

    private var noDocPlaceholderView: some View {
        VStack {
            Spacer()
            Text(workspace.tr("No Document Open"))
                .font(.title2)
                .foregroundColor(.secondary)
            Button(workspace.tr("Create New")) {
                workspace.newDocument()
            }
            .padding(.top, 8)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.textBackgroundColor))
    }
}

public struct NppFunctionListView: View {
    @ObservedObject var workspace: NppWorkspace
    @State private var isAlphabetical: Bool = false
    @State private var filterQuery: String = ""
    @State private var refreshId: UUID = UUID()

    public var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            HStack {
                Label(workspace.tr("Function List"), systemImage: "function")
                    .font(.system(size: 11, weight: .semibold))
                Spacer()
                Button(action: { workspace.showFunctionList = false }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9))
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Function List 3-Control Toolbar (function-list.md:30-55)
            HStack(spacing: 6) {
                // Real-time Search Filter Field
                HStack(spacing: 4) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                    TextField(workspace.tr("Filter..."), text: $filterQuery)
                        .textFieldStyle(PlainTextFieldStyle())
                        .font(.system(size: 11))
                    if !filterQuery.isEmpty {
                        Button(action: { filterQuery = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 5)
                .padding(.vertical, 3)
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(4)
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color(NSColor.separatorColor), lineWidth: 0.5))

                // Sort Button (Toggle Appearance Order vs Alphabetical A-Z)
                Button(action: { isAlphabetical.toggle() }) {
                    Image(systemName: isAlphabetical ? "arrow.up.and.down.text.horizontal" : "arrow.up.arrow.down")
                        .font(.system(size: 10))
                        .foregroundColor(isAlphabetical ? .accentColor : .primary)
                        .frame(width: 20, height: 20)
                        .background(isAlphabetical ? Color.accentColor.opacity(0.15) : Color.clear)
                        .cornerRadius(3)
                }
                .buttonStyle(PlainButtonStyle())
                .help(workspace.tr("Sort (A-Z vs Order of Appearance)"))

                // Refresh Button (Reparse current buffer)
                Button(action: { refreshId = UUID() }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 10))
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(PlainButtonStyle())
                .help(workspace.tr("Refresh"))
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            let functions = NppWorkspace.parseFunctions(
                content: workspace.activeDocument?.content ?? "",
                filter: filterQuery,
                sortedAlphabetically: isAlphabetical
            )

            if functions.isEmpty {
                VStack {
                    Spacer()
                    Text(workspace.tr("No functions found"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                List(functions, id: \.line) { fn in
                    Button(action: {
                        jumpToLine(fn.line)
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: fn.isClass ? "cube.fill" : "fx")
                                .font(.system(size: 9))
                                .foregroundColor(fn.isClass ? .orange : .blue)
                            Text(fn.name)
                                .font(.system(size: 11))
                                .lineLimit(1)
                            Spacer()
                            Text("\(fn.line)")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .listStyle(PlainListStyle())
                .id(refreshId)
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
    }

    private func jumpToLine(_ lineNum: Int) {
        workspace.jumpToLine(lineNum)
    }
}

public struct NppDocumentMapView: View {
    @ObservedObject var workspace: NppWorkspace

    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label(workspace.tr("Document Map"), systemImage: "rectangle.split.2x1")
                    .font(.system(size: 11, weight: .semibold))
                Spacer()
                Button(action: { workspace.showDocumentMap = false }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9))
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            ScrollView([.vertical, .horizontal], showsIndicators: false) {
                let lines = (workspace.activeDocument?.content ?? "").nppLines()
                LazyVStack(alignment: .leading, spacing: 1) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { idx, lineText in
                        Text(lineText.isEmpty ? " " : lineText)
                            .font(.system(size: 4, weight: .regular, design: .monospaced))
                            .foregroundColor(workspace.activeDocument?.cursorLine == (idx + 1) ? .accentColor : .secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                workspace.jumpToLine(idx + 1)
                            }
                    }
                }
                .padding(4)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .help(workspace.docPeekerOnMap ? (workspace.activeDocument.map { "\($0.title)\n\(String($0.content.prefix(200)))" } ?? "") : "")
            .background(Color(NSColor.textBackgroundColor).opacity(0.8))
        }
        .background(Color(NSColor.windowBackgroundColor))
    }
}

public struct NppClipboardHistoryView: View {
    @ObservedObject var workspace: NppWorkspace

    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label(workspace.tr("Clipboard History"), systemImage: "doc.on.clipboard")
                    .font(.system(size: 11, weight: .semibold))
                Spacer()
                Button(action: { workspace.clipboardHistory.removeAll() }) {
                    Image(systemName: "trash")
                        .font(.system(size: 10))
                }
                .buttonStyle(PlainButtonStyle())
                .help("Clear History")
                .padding(.trailing, 4)

                Button(action: { workspace.showClipboardHistory = false }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9))
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            if workspace.clipboardHistory.isEmpty {
                VStack {
                    Spacer()
                    Text(workspace.tr("Clipboard history is empty"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                List(workspace.clipboardHistory) { item in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.preview)
                                .font(.system(size: 11, design: .monospaced))
                                .lineLimit(1)
                            Text("\(item.text.count) chars")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) {
                        insertIntoEditor(item.text)
                    }
                }
                .listStyle(PlainListStyle())
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
    }

    private func insertIntoEditor(_ text: String) {
        guard let tv = workspace.activeTextView, tv.isEditable else { return }
        tv.insertText(text, replacementRange: tv.selectedRange())
    }
}

public struct NppCharacterPanelView: View {
    @ObservedObject var workspace: NppWorkspace
    @State private var filterQuery: String = ""

    struct CharEntry: Identifiable {
        let id: Int // 0..255
        let dec: Int
        let hex: String
        let charDisplay: String
        let htmlName: String
        let htmlDec: String
        let htmlHex: String
    }

    private var entries: [CharEntry] {
        (0...255).compactMap { code -> CharEntry? in
            let hex = String(format: "%02X", code)
            let charDisplay: String
            switch code {
            case 0: charDisplay = "NUL"
            case 9: charDisplay = "TAB"
            case 10: charDisplay = "LF"
            case 13: charDisplay = "CR"
            case 32: charDisplay = "SPACE"
            case 1...31: charDisplay = "CTL"
            case 128...255:
                let byte = UInt8(code)
                let data = Data([byte])
                if let s = String(data: data, encoding: .windowsCP1252) {
                    charDisplay = s
                } else if let scalar = UnicodeScalar(code) {
                    charDisplay = String(scalar)
                } else {
                    charDisplay = "?"
                }
            default:
                if let scalar = UnicodeScalar(code) {
                    charDisplay = String(scalar)
                } else {
                    charDisplay = "?"
                }
            }
            let htmlDec = "&#\(code);"
            let htmlHex = "&#x\(hex);"
            var htmlName = ""
            switch code {
            case 34: htmlName = "&quot;"
            case 38: htmlName = "&amp;"
            case 60: htmlName = "&lt;"
            case 62: htmlName = "&gt;"
            case 160: htmlName = "&nbsp;"
            case 169: htmlName = "&copy;"
            case 174: htmlName = "&reg;"
            default: htmlName = ""
            }

            let entry = CharEntry(id: code, dec: code, hex: hex, charDisplay: charDisplay, htmlName: htmlName, htmlDec: htmlDec, htmlHex: htmlHex)
            if !filterQuery.isEmpty {
                let q = filterQuery.lowercased()
                let match = "\(code)".contains(q) || hex.lowercased().contains(q) || charDisplay.lowercased().contains(q) || htmlName.lowercased().contains(q)
                return match ? entry : nil
            }
            return entry
        }
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label(workspace.tr("Character Panel"), systemImage: "textformat.123")
                    .font(.system(size: 11, weight: .semibold))
                Spacer()
                Button(action: { workspace.showCharacterPanel = false }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9))
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            TextField(workspace.tr("Filter (Dec, Hex, Char)"), text: $filterQuery)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .font(.system(size: 10))
                .padding(6)

            // Column Headers (asciiInsertionPanel.cpp L55-82)
            HStack(spacing: 8) {
                Text(workspace.tr("Value"))
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.secondary)
                    .frame(width: 32, alignment: .trailing)
                Text(workspace.tr("Hex"))
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.secondary)
                    .frame(width: 24, alignment: .leading)
                Text(workspace.tr("Character"))
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.secondary)
                    .frame(width: 40, alignment: .center)
                Text(workspace.tr("HTML Number"))
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 3)

            Divider()

            List(entries) { item in
                HStack(spacing: 8) {
                    Text("\(item.dec)")
                        .font(.system(size: 10, design: .monospaced))
                        .frame(width: 32, alignment: .trailing)
                    Text(item.hex)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.blue)
                        .frame(width: 24, alignment: .leading)
                    Text(item.charDisplay)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .frame(width: 40, alignment: .center)
                    Text(item.htmlName.isEmpty ? item.htmlDec : item.htmlName)
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .contentShape(Rectangle())
                .onTapGesture(count: 2) {
                    guard item.dec > 0 else { return } // Disallow inserting raw NUL (code 0)
                    guard let tv = workspace.activeTextView, tv.isEditable else { return }
                    let stringToInsert: String
                    if item.dec >= 128 && item.dec <= 255 {
                        let data = Data([UInt8(item.dec)])
                        stringToInsert = String(data: data, encoding: .windowsCP1252) ?? (UnicodeScalar(item.dec).map(String.init) ?? "")
                    } else if let scalar = UnicodeScalar(item.dec) {
                        stringToInsert = String(scalar)
                    } else {
                        stringToInsert = ""
                    }
                    guard !stringToInsert.isEmpty else { return }
                    tv.insertText(stringToInsert, replacementRange: tv.selectedRange())
                    workspace.activeDocument?.content = tv.string
                    workspace.activeDocument?.isDirty = true
                    tv.window?.makeFirstResponder(tv)
                }
            }
            .listStyle(PlainListStyle())
        }
        .background(Color(NSColor.windowBackgroundColor))
    }
}

// MARK: - Authentic Notepad++ Dual View Splitter Bar (view-rotate-4.png)
public struct NppSplitterBarView: View {
    @ObservedObject var workspace: NppWorkspace
    let totalSize: CGFloat
    let isVertical: Bool
    @State private var isHovering: Bool = false

    public init(workspace: NppWorkspace, totalSize: CGFloat, isVertical: Bool) {
        self.workspace = workspace
        self.totalSize = totalSize
        self.isVertical = isVertical
    }

    public var body: some View {
        ZStack {
            // 1. Splitter Background Bar
            Rectangle()
                .fill(isHovering ? Color(NSColor.selectedControlColor).opacity(0.3) : Color(NSColor.separatorColor).opacity(0.6))

            // 2. Stipple / Dotted Grip Pattern (Canvas)
            Canvas { ctx, size in
                let dotRadius: CGFloat = 0.8
                let dotColor = Color.secondary.opacity(0.4)
                if isVertical {
                    let x = size.width / 2
                    var y: CGFloat = 24
                    while y < size.height - 24 {
                        ctx.fill(Path(ellipseIn: CGRect(x: x - dotRadius, y: y, width: dotRadius * 2, height: dotRadius * 2)), with: .color(dotColor))
                        y += 4
                    }
                } else {
                    let y = size.height / 2
                    var x: CGFloat = 16
                    while x < size.width - 40 {
                        ctx.fill(Path(ellipseIn: CGRect(x: x, y: y - dotRadius, width: dotRadius * 2, height: dotRadius * 2)), with: .color(dotColor))
                        x += 4
                    }
                }
            }

            // 3. Authentic Notepad++ Rotation Arrows Handle
            if isVertical {
                // Vertical split (Left / Right): Top (◀) and Bottom (▶)
                VStack {
                    Button(action: {
                        workspace.rotateSplitterLeft()
                    }) {
                        Image(systemName: "arrowtriangle.left.fill")
                            .font(.system(size: 6, weight: .bold))
                            .foregroundColor(.secondary)
                            .frame(width: 8, height: 12)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help(workspace.tr("Rotate to left"))
                    .padding(.top, 4)

                    Spacer()

                    Button(action: {
                        workspace.rotateSplitterRight()
                    }) {
                        Image(systemName: "arrowtriangle.right.fill")
                            .font(.system(size: 6, weight: .bold))
                            .foregroundColor(.secondary)
                            .frame(width: 8, height: 12)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help(workspace.tr("Rotate to right"))
                    .padding(.bottom, 4)
                }
            } else {
                // Horizontal split (Top / Bottom): Far Right (▲ / ▼) per view-rotate-4.png
                HStack(spacing: 0) {
                    Spacer()
                    HStack(spacing: 2) {
                        Button(action: {
                            workspace.rotateSplitterLeft()
                        }) {
                            Image(systemName: "arrowtriangle.up.fill")
                                .font(.system(size: 6, weight: .bold))
                                .foregroundColor(.secondary)
                                .frame(width: 10, height: 6)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help(workspace.tr("Rotate to left"))

                        Button(action: {
                            workspace.rotateSplitterRight()
                        }) {
                            Image(systemName: "arrowtriangle.down.fill")
                                .font(.system(size: 6, weight: .bold))
                                .foregroundColor(.secondary)
                                .frame(width: 10, height: 6)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help(workspace.tr("Rotate to right"))
                    }
                    .padding(.horizontal, 3)
                    .padding(.vertical, 1)
                    .background(
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color(NSColor.windowBackgroundColor))
                            .shadow(color: Color.black.opacity(0.12), radius: 1, x: 0, y: 1)
                    )
                    .padding(.trailing, 8)
                }
            }
        }
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovering = hovering
            if hovering {
                if isVertical {
                    NSCursor.resizeLeftRight.push()
                } else {
                    NSCursor.resizeUpDown.push()
                }
            } else {
                NSCursor.pop()
            }
        }
        .gesture(
            DragGesture()
                .onChanged { value in
                    let delta = isVertical ? value.translation.width : value.translation.height
                    let newRatio = workspace.splitRatio + (delta / max(100, totalSize))
                    workspace.splitRatio = max(0.15, min(0.85, newRatio))
                }
        )
        // MARK: - Authentic Notepad++ Splitter Context Menu (SplitterContainer.cpp:255-270, views.md:112)
        .contextMenu {
            Button(workspace.tr("Rotate to right")) {
                workspace.rotateSplitterRight()
            }
            Button(workspace.tr("Rotate to left")) {
                workspace.rotateSplitterLeft()
            }
        }
    }
}
