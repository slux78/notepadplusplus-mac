import SwiftUI
import AppKit

final class TabMenuTarget: NSObject {
    static let shared = TabMenuTarget()
    weak var workspace: NppWorkspace?

    @objc func selectDoc(_ sender: NSMenuItem) {
        if let docId = sender.representedObject as? UUID {
            workspace?.activeDocumentId = docId
        }
    }

    @objc func sortTabs() {
        workspace?.sortTabsByName(ascending: true)
    }

    @objc func closeAll() {
        workspace?.closeAll()
    }

    @objc func openWindowsDialog() {
        workspace?.showDocumentList = true
    }
}

public struct NppTabBarView: View {
    @ObservedObject var workspace: NppWorkspace

    public init(workspace: NppWorkspace) {
        self.workspace = workspace
    }

    private func showDocumentListMenu() {
        let menu = NSMenu()
        TabMenuTarget.shared.workspace = workspace

        for (index, doc) in workspace.documents.enumerated() {
            let check = (workspace.activeDocumentId == doc.id) ? "✓ " : "   "
            let dirty = doc.isDirty ? "*" : ""
            let pinned = doc.isPinned ? "📌 " : ""
            let title = "\(check)\(index + 1): \(pinned)\(doc.title)\(dirty)"
            let item = NSMenuItem(title: title, action: #selector(TabMenuTarget.selectDoc(_:)), keyEquivalent: "")
            item.target = TabMenuTarget.shared
            item.representedObject = doc.id
            menu.addItem(item)
        }

        menu.addItem(NSMenuItem.separator())

        let sortItem = NSMenuItem(title: workspace.tr("Sort by Name"), action: #selector(TabMenuTarget.sortTabs), keyEquivalent: "")
        sortItem.target = TabMenuTarget.shared
        menu.addItem(sortItem)

        let closeAllItem = NSMenuItem(title: workspace.tr("Close All"), action: #selector(TabMenuTarget.closeAll), keyEquivalent: "")
        closeAllItem.target = TabMenuTarget.shared
        menu.addItem(closeAllItem)

        let windowsItem = NSMenuItem(title: workspace.tr("Windows..."), action: #selector(TabMenuTarget.openWindowsDialog), keyEquivalent: "")
        windowsItem.target = TabMenuTarget.shared
        menu.addItem(windowsItem)

        if let event = NSApp.currentEvent {
            NSMenu.popUpContextMenu(menu, with: event, for: NSApp.keyWindow?.contentView ?? NSView())
        }
    }

    public var body: some View {
        ScrollViewReader { proxy in
            HStack(spacing: 0) {
                // 1. Scrollable tab items on the left
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 2) {
                        ForEach(workspace.documents) { doc in
                            NppTabItemView(
                                doc: doc,
                                workspace: workspace,
                                isActive: workspace.activeDocumentId == doc.id,
                                onSelect: {
                                    guard workspace.documents.contains(where: { $0.id == doc.id }) else { return }
                                    workspace.activeDocumentId = doc.id
                                },
                                onClose: {
                                    workspace.closeDocument(id: doc.id)
                                }
                            )
                            .id(doc.id)
                        }
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, workspace.tabReduce ? 1 : 3)
                }
                .onChange(of: workspace.activeDocumentId) { newId in
                    if let id = newId {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            proxy.scrollTo(id, anchor: .center)
                        }
                    }
                }

                // 2. Empty space next to tabs (Double-click creates new tab per Notepad++ spec)
                Color.clear
                    .contentShape(Rectangle())
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .onTapGesture(count: 2) {
                        if workspace.doubleClickSpaceToNewTab {
                            workspace.newDocument()
                        }
                    }

                // 3. Right shortcuts cluster firmly anchored to the trailing edge
                HStack(spacing: 2) {
                    // Tab overflow navigation arrows ⏴ ⏵ (per user-interface.md:130)
                    HStack(spacing: 1) {
                        Button(action: {
                            workspace.prevTab()
                        }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: workspace.tabReduce ? 8 : 10, weight: .bold))
                                .foregroundColor(.secondary)
                                .frame(width: workspace.tabReduce ? 16 : 18, height: workspace.tabReduce ? 20 : 24)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help(workspace.tr("Previous Tab (⏴)"))

                        Button(action: {
                            workspace.nextTab()
                        }) {
                            Image(systemName: "chevron.right")
                                .font(.system(size: workspace.tabReduce ? 8 : 10, weight: .bold))
                                .foregroundColor(.secondary)
                                .frame(width: workspace.tabReduce ? 16 : 18, height: workspace.tabReduce ? 20 : 24)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help(workspace.tr("Next Tab (⏵)"))
                    }
                    .padding(.horizontal, 2)

                    // Right shortcuts cluster: ＋ ▼ ✕ (Notepad_plus.rc:1366-1372, respects hideRightShortcuts)
                    if !workspace.hideRightShortcuts {
                        HStack(spacing: 2) {
                            Divider().frame(height: 14)

                            // 1. ＋ New Document (IDM_FILE_NEW)
                            Button(action: {
                                workspace.newDocument()
                            }) {
                                Image(systemName: "plus")
                                    .font(.system(size: workspace.tabReduce ? 9 : 11, weight: .bold))
                                    .foregroundColor(.secondary)
                                    .frame(width: workspace.tabReduce ? 18 : 22, height: workspace.tabReduce ? 20 : 24)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(PlainButtonStyle())
                            .help(workspace.tr("New Document (＋)"))

                            // 2. ▼ Document list popup menu (IDM_DROPLIST_LIST) - Single authentic dropdown
                            Button(action: {
                                showDocumentListMenu()
                            }) {
                                Image(systemName: "arrowtriangle.down.fill")
                                    .font(.system(size: workspace.tabReduce ? 7 : 8, weight: .semibold))
                                    .foregroundColor(.secondary)
                                    .frame(width: workspace.tabReduce ? 18 : 20, height: workspace.tabReduce ? 20 : 24)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(PlainButtonStyle())
                            .help(workspace.tr("Open Documents List (▼)"))

                            // 3. ✕ Close active tab (IDM_FILE_CLOSE)
                            Button(action: {
                                if let activeId = workspace.activeDocumentId {
                                    workspace.closeDocument(id: activeId)
                                }
                            }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: workspace.tabReduce ? 9 : 10, weight: .bold))
                                    .foregroundColor(workspace.activeDocument == nil ? .secondary.opacity(0.3) : .secondary)
                                    .frame(width: workspace.tabReduce ? 18 : 20, height: workspace.tabReduce ? 20 : 24)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(PlainButtonStyle())
                            .disabled(workspace.activeDocument == nil)
                            .help(workspace.tr("Close Current Tab (✕)"))
                        }
                        .padding(.trailing, 4)
                    }
                }
            }
        }
        .frame(height: workspace.tabReduce ? 24 : 30)
        .background(Color(NSColor.windowBackgroundColor))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(NSColor.separatorColor)),
            alignment: .bottom
        )
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            workspace.newDocument()
        }
    }
}

public struct NppTabItemView: View {
    @ObservedObject var doc: NppDocument
    @ObservedObject var workspace: NppWorkspace
    let isActive: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    @State private var isHovering: Bool = false

    public static func formattedTitle(title: String, maxLen: Int) -> String {
        let limit = max(4, maxLen)
        if title.count > limit {
            return String(title.prefix(limit)) + "…"
        }
        return title
    }

    private var displayedTitle: String {
        Self.formattedTitle(title: doc.title, maxLen: workspace.tabMaxLabelLen)
    }

    private var tabIconName: String {
        if doc.isMonitoring {
            return "eye.fill"
        }
        if doc.isReadOnly {
            return "lock.fill"
        }
        if doc.isDirty {
            return "circle.fill"
        }
        if workspace.tabAltIcons {
            return isActive ? "doc.fill" : "doc.plaintext"
        }
        return isActive ? "pencil.line" : "doc.text"
    }

    private var tabIconColor: Color {
        if doc.isMonitoring {
            return Color(red: 0.12, green: 0.53, blue: 0.90) // Dodger Blue
        }
        if doc.isReadOnly {
            return .secondary
        }
        if doc.isDirty {
            return .red
        }
        return isActive ? .accentColor : .secondary
    }

    private var verticalPadding: CGFloat {
        workspace.tabReduce ? 2.5 : 5.0
    }

    private var titleFontSize: CGFloat {
        workspace.tabReduce ? 10.5 : 12.0
    }

    public var body: some View {
        HStack(spacing: 4) {
            // Clickable tab label (Icon + Title)
            HStack(spacing: 6) {
                if doc.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: workspace.tabReduce ? 8 : 9))
                        .foregroundColor(.orange)
                }

                Image(systemName: tabIconName)
                    .font(.system(size: workspace.tabReduce ? 9 : 10))
                    .foregroundColor(tabIconColor)

                Text(displayedTitle)
                    .font(.system(size: titleFontSize, weight: isActive ? .semibold : .regular))
                    .foregroundColor(isActive ? .primary : .secondary)
                    .lineLimit(1)
            }
            .contentShape(Rectangle())
            .onTapGesture(count: 2) {
                if workspace.doubleClickTabToClose && !doc.isPinned {
                    onClose()
                }
            }
            .onTapGesture(count: 1) {
                onSelect()
            }

            // Close button [x] (respects showTabCloseButton, hidden if pinned)
            if workspace.showTabCloseButton && !doc.isPinned {
                Button(action: {
                    onClose()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: workspace.tabReduce ? 8 : 9, weight: .semibold))
                        .foregroundColor(isHovering || isActive ? .secondary : (workspace.tabShowButtonsOnInactive ? .secondary.opacity(0.5) : .clear))
                        .frame(width: workspace.tabReduce ? 12 : 14, height: workspace.tabReduce ? 12 : 14)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
                .help("Close (or double click tab)")
            }
        }
        .padding(.leading, 10)
        .padding(.trailing, 6)
        .padding(.vertical, verticalPadding)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(tabBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 5)
                .stroke(isActive ? Color(NSColor.separatorColor) : (workspace.tabChangeInactiveColor ? Color(NSColor.separatorColor).opacity(0.3) : Color.clear), lineWidth: 1)
        )
        .overlay(
            VStack {
                if doc.tabColorId >= 1 && doc.tabColorId <= 5 {
                    Rectangle()
                        .fill(Self.tabAccentColor(for: doc.tabColorId))
                        .frame(height: 3.0)
                        .cornerRadius(1)
                } else if isActive && workspace.tabColorIndicator {
                    Rectangle()
                        .fill(Color.orange)
                        .frame(height: 2.5)
                        .cornerRadius(1)
                }
                Spacer()
            }
        )
        .onHover { hovering in
            isHovering = hovering
        }
        // MARK: - Notepad++ Tab Right Click Context Menu (tabContextMenu.xml)
        .contextMenu {
            if !doc.isPinned {
                Button(workspace.tr("Close")) { onClose() }
            }

            Button(workspace.tr(doc.isPinned ? "Unpin Tab" : "Pin Tab")) {
                workspace.togglePin(id: doc.id)
            }

            Menu(workspace.tr("Apply Color to Tab")) {
                ForEach(1...5, id: \.self) { colorIdx in
                    Button(workspace.tr("Apply Color \(colorIdx)")) {
                        doc.tabColorId = colorIdx
                        workspace.objectWillChange.send()
                    }
                }
                Divider()
                Button(workspace.tr("Remove Color")) {
                    doc.tabColorId = 0
                    workspace.objectWillChange.send()
                }
            }

            Divider()

            Button(workspace.tr("Move to Start")) {
                workspace.moveTabToStart()
            }
            Button(workspace.tr("Move to End")) {
                workspace.moveTabToEnd()
            }

            Divider()

            Menu(workspace.tr("Close Multiple Documents")) {
                Button(workspace.tr("Close All but Active Document")) {
                    workspace.closeAllBut(id: doc.id)
                }
                Button(workspace.tr("Close All but Pinned Documents")) {
                    workspace.closeAllButPinned()
                }
                Button(workspace.tr("Close All to the Left")) {
                    workspace.closeAllToLeft(of: doc.id)
                }
                Button(workspace.tr("Close All to the Right")) {
                    workspace.closeAllToRight(of: doc.id)
                }
                Button(workspace.tr("Close All Unchanged")) {
                    workspace.closeAllUnchanged()
                }
            }

            Divider()

            Button(workspace.tr("Save")) {
                if doc.filePath != nil {
                    _ = doc.save()
                } else {
                    workspace.promptSaveAs(for: doc)
                }
            }
            Button(workspace.tr("Save As...")) {
                workspace.promptSaveAs(for: doc)
            }
            Button(workspace.tr("Save a Copy As...")) {
                workspace.promptSaveCopyAs(for: doc)
            }
            Button(workspace.tr("Rename...")) {
                workspace.promptRenameDocument(for: doc)
            }
            if doc.filePath != nil {
                Button(workspace.tr("Reload from Disk")) {
                    workspace.reloadFromDisk(for: doc)
                }
            }

            Divider()

            if let path = doc.filePath {
                Menu(workspace.tr("Open Containing Folder")) {
                    Button(workspace.tr("Open Containing Folder in Finder")) {
                        NSWorkspace.shared.activateFileViewerSelecting([path])
                    }
                    Button(workspace.tr("Open in Terminal")) {
                        let dir = path.deletingLastPathComponent()
                        NppTools.openTerminal(at: dir)
                    }
                    Button(workspace.tr("Folder as Workspace")) {
                        workspace.openFolderAsWorkspace(url: path.deletingLastPathComponent())
                    }
                }

                Divider()

                Menu(workspace.tr("Copy to Clipboard")) {
                    Button(workspace.tr("Copy Current Full File path")) {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(path.path, forType: .string)
                    }
                    Button(workspace.tr("Copy Current Filename")) {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(path.lastPathComponent, forType: .string)
                    }
                    Button(workspace.tr("Copy Current Dir. Path")) {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(path.deletingLastPathComponent().path, forType: .string)
                    }
                }
            }
        }
    }

    public static func tabAccentColor(for colorId: Int) -> Color {
        switch colorId {
        case 1: return Color(red: 0.95, green: 0.78, blue: 0.15) // Yellow (Color 1)
        case 2: return Color(red: 0.25, green: 0.80, blue: 0.45) // Green (Color 2)
        case 3: return Color(red: 0.25, green: 0.65, blue: 0.95) // Blue (Color 3)
        case 4: return Color(red: 0.95, green: 0.50, blue: 0.20) // Orange (Color 4)
        case 5: return Color(red: 0.85, green: 0.40, blue: 0.85) // Pink/Magenta (Color 5)
        default: return Color.orange
        }
    }

    private var tabBackground: Color {
        if isActive {
            return Color(NSColor.controlBackgroundColor)
        }
        if isHovering {
            return Color(NSColor.controlBackgroundColor).opacity(0.5)
        }
        if workspace.tabChangeInactiveColor {
            return Color(NSColor.controlBackgroundColor).opacity(0.35)
        }
        return Color.clear
    }
}
