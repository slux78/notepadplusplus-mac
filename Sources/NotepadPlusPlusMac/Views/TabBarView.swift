import SwiftUI
import AppKit

final class TabMenuTarget: NSObject {
    static let shared = TabMenuTarget()
    weak var workspace: NppWorkspace?
    var targetViewIndex: Int = 0

    @objc func selectDoc(_ sender: NSMenuItem) {
        if let docId = sender.representedObject as? UUID {
            if targetViewIndex == 0 {
                workspace?.activeDocumentId = docId
                workspace?.activeView = 0
            } else {
                workspace?.secondaryActiveDocumentId = docId
                workspace?.activeView = 1
            }
        }
    }

    @objc func sortTabs() {
        workspace?.sortTabsByName(ascending: true)
    }

    @objc func closeAll() {
        _ = workspace?.closeAll(force: false)
    }

    @objc func openWindowsDialog() {
        workspace?.showDocumentList = true
    }
}

// MARK: - Authentic Notepad++ Floppy Disk Tab Icon
public struct FloppyIconView: View {
    public let isDirty: Bool
    public var size: CGFloat = 13

    public init(isDirty: Bool, size: CGFloat = 13) {
        self.isDirty = isDirty
        self.size = size
    }

    public var body: some View {
        let baseColor = isDirty ? Color(red: 0.88, green: 0.20, blue: 0.20) : Color(red: 0.18, green: 0.48, blue: 0.88)

        ZStack {
            // Outer 3.5" floppy disk body with notched upper corner
            RoundedRectangle(cornerRadius: 1.5)
                .fill(baseColor)
                .frame(width: size, height: size)

            VStack(spacing: 1.5) {
                // Top metal shutter slider
                ZStack {
                    RoundedRectangle(cornerRadius: 0.8)
                        .fill(Color(white: 0.88))
                        .frame(width: size * 0.65, height: size * 0.35)

                    // Shutter window rectangular cut
                    Rectangle()
                        .fill(baseColor)
                        .frame(width: size * 0.16, height: size * 0.22)
                        .offset(x: -size * 0.12)
                }

                // Bottom paper label
                RoundedRectangle(cornerRadius: 0.5)
                    .fill(Color(white: 0.95))
                    .frame(width: size * 0.72, height: size * 0.40)
                    .overlay(
                        VStack(spacing: 1) {
                            Rectangle()
                                .fill(Color.gray.opacity(0.4))
                                .frame(height: 0.6)
                            Rectangle()
                                .fill(Color.gray.opacity(0.4))
                                .frame(height: 0.6)
                        }
                        .padding(.horizontal, 1.5)
                    )
            }
        }
        .frame(width: size, height: size)
    }
}

public struct NppTabBarView: View {
    @ObservedObject var workspace: NppWorkspace
    public var viewIndex: Int = 0 // 0: Primary View, 1: Secondary View

    public init(workspace: NppWorkspace, viewIndex: Int = 0) {
        self.workspace = workspace
        self.viewIndex = viewIndex
    }

    private var currentDocs: [NppDocument] {
        if viewIndex == 1 {
            return workspace.secondaryDocuments
        } else {
            return workspace.isDualView ? workspace.primaryDocuments : workspace.documents
        }
    }

    private var currentActiveId: UUID? {
        if viewIndex == 1 {
            return workspace.secondaryActiveDocumentId
        } else {
            return workspace.activeDocumentId
        }
    }

    private func showDocumentListMenu() {
        let menu = NSMenu()
        TabMenuTarget.shared.workspace = workspace
        TabMenuTarget.shared.targetViewIndex = viewIndex

        let docs = currentDocs
        let activeId = currentActiveId

        for (index, doc) in docs.enumerated() {
            let check = (activeId == doc.id) ? "✓ " : "   "
            let dirty = doc.isDirty ? "*" : ""
            let pinned = doc.isPinned ? "📌 " : ""
            let title = "\(check)\(index + 1): \(pinned)\(workspace.tabTitle(for: doc))\(dirty)"
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

    @ViewBuilder
    private func tabItem(for doc: NppDocument) -> some View {
        NppTabItemView(
            doc: doc,
            workspace: workspace,
            isActive: currentActiveId == doc.id,
            viewIndex: viewIndex,
            onSelect: {
                if viewIndex == 1 {
                    workspace.secondaryActiveDocumentId = doc.id
                    workspace.activeView = 1
                } else {
                    workspace.activeDocumentId = doc.id
                    workspace.activeView = 0
                }
            },
            onClose: {
                _ = workspace.closeDocument(id: doc.id, force: false)
            }
        )
        .id(doc.id)
        .onDrag {
            if workspace.tabLock {
                return NSItemProvider()
            }
            return NSItemProvider(object: doc.id.uuidString as NSString)
        }
        .onDrop(of: ["public.utf8-plain-text", "public.text"], delegate: TabDropDelegate(item: doc, workspace: workspace, viewIndex: viewIndex))
    }

    public var body: some View {
        ScrollViewReader { proxy in
            HStack(spacing: 0) {
                // 1. Scrollable tab strip containing both tabs and trailing empty space
                GeometryReader { geo in
                    Group {
                        if workspace.tabVertical {
                            ScrollView(.vertical, showsIndicators: false) {
                                VStack(alignment: .leading, spacing: 2) {
                                    ForEach(currentDocs) { doc in
                                        tabItem(for: doc)
                                    }
                                }
                                .padding(4)
                            }
                        } else if workspace.tabMultiLine {
                            ScrollView(.vertical, showsIndicators: false) {
                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 2)], spacing: 2) {
                                    ForEach(currentDocs) { doc in
                                        tabItem(for: doc)
                                    }
                                }
                                .padding(4)
                            }
                        } else {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 0) {
                                    HStack(spacing: 2) {
                                        ForEach(currentDocs) { doc in
                                            tabItem(for: doc)
                                        }
                                    }
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, workspace.tabReduce ? 1 : 3)

                                    // 2. Empty space next to tabs (Double-click creates new tab per Notepad++ spec)
                                    Color.clear
                                        .contentShape(Rectangle())
                                        .frame(minWidth: 40, maxWidth: .infinity, maxHeight: .infinity)
                                        .onTapGesture(count: 2) {
                                            if workspace.doubleClickSpaceToNewTab {
                                                if viewIndex == 1 {
                                                    workspace.newDocumentInSecondaryView()
                                                    workspace.activeView = 1
                                                } else {
                                                    workspace.activeView = 0
                                                    workspace.newDocument()
                                                }
                                            }
                                        }
                                }
                                .frame(minWidth: geo.size.width, minHeight: workspace.tabReduce ? 24 : 30)
                            }
                        }
                    }
                    .onChange(of: currentActiveId) { newId in
                        if let id = newId {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                proxy.scrollTo(id, anchor: .center)
                            }
                        }
                    }
                }

                // 3. Right shortcuts cluster: ＋ ▼ ✕ (Only in Single View per Notepad++ manual view-rotate-4.png)
                if !workspace.hideRightShortcuts && !workspace.isDualView {
                    HStack(spacing: 2) {
                        Divider().frame(height: 14)

                        // 1. ＋ New Document (IDM_FILE_NEW)
                        Button(action: {
                            if viewIndex == 1 {
                                workspace.newDocumentInSecondaryView()
                                workspace.activeView = 1
                            } else {
                                workspace.activeView = 0
                                workspace.newDocument()
                            }
                        }) {
                            Image(systemName: "plus")
                                .font(.system(size: workspace.tabReduce ? 9 : 11, weight: .bold))
                                .foregroundColor(.secondary)
                                .frame(width: workspace.tabReduce ? 18 : 22, height: workspace.tabReduce ? 20 : 24)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help(workspace.tr("New Document (＋)"))

                        // 2. ▼ Document list popup menu (IDM_DROPLIST_LIST)
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
                            if let activeId = currentActiveId {
                                _ = workspace.closeDocument(id: activeId, force: false)
                            }
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: workspace.tabReduce ? 9 : 10, weight: .bold))
                                .foregroundColor(currentActiveId == nil ? .secondary.opacity(0.3) : .secondary)
                                .frame(width: workspace.tabReduce ? 18 : 20, height: workspace.tabReduce ? 20 : 24)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())
                        .disabled(currentActiveId == nil)
                        .help(workspace.tr("Close Current Tab (✕)"))
                    }
                    .padding(.trailing, 4)
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
    }
}

struct TabDropDelegate: DropDelegate {
    let item: NppDocument
    let workspace: NppWorkspace
    let viewIndex: Int

    func performDrop(info: DropInfo) -> Bool {
        if workspace.tabLock { return false }
        guard let itemProvider = info.itemProviders(for: ["public.utf8-plain-text", "public.text"]).first else { return false }
        itemProvider.loadItem(forTypeIdentifier: "public.utf8-plain-text", options: nil) { (data, error) in
            var uuidStr: String?
            if let data = data as? Data {
                uuidStr = String(data: data, encoding: .utf8)
            } else if let str = data as? String {
                uuidStr = str
            }
            if let uuidStr = uuidStr, let draggedId = UUID(uuidString: uuidStr) {
                DispatchQueue.main.async {
                    workspace.reorderTab(draggedId: draggedId, targetId: item.id, viewIndex: viewIndex)
                }
            }
        }
        return true
    }
}

public struct NppTabItemView: View {
    @ObservedObject var doc: NppDocument
    @ObservedObject var workspace: NppWorkspace
    let isActive: Bool
    var viewIndex: Int = 0
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
        Self.formattedTitle(title: workspace.tabTitle(for: doc), maxLen: workspace.tabMaxLabelLen)
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
                if doc.isPinned && workspace.tabPinFeature {
                    Image(systemName: "pin.fill")
                        .font(.system(size: workspace.tabReduce ? 8 : 9))
                        .foregroundColor(.orange)
                }

                // Authentic Floppy Disk / Monitoring / Lock / Alt Icon
                if doc.isMonitoring {
                    Image(systemName: "eye.fill")
                        .font(.system(size: workspace.tabReduce ? 9 : 10))
                        .foregroundColor(Color(red: 0.12, green: 0.53, blue: 0.90))
                } else if doc.isReadOnly {
                    Image(systemName: "lock.fill")
                        .font(.system(size: workspace.tabReduce ? 9 : 10))
                        .foregroundColor(.secondary)
                } else if workspace.tabAltIcons {
                    Image(systemName: doc.isDirty ? "pencil.circle.fill" : "doc.text.fill")
                        .font(.system(size: workspace.tabReduce ? 9 : 10.5))
                        .foregroundColor(doc.isDirty ? .red : .blue)
                } else {
                    FloppyIconView(isDirty: doc.isDirty, size: workspace.tabReduce ? 11 : 12.5)
                }

                Text(displayedTitle)
                    .font(.system(size: titleFontSize, weight: isActive ? .semibold : .regular))
                    .foregroundColor(isActive ? .primary : .secondary)
                    .lineLimit(1)
            }
            .contentShape(Rectangle())
            .onTapGesture(count: 2) {
                if workspace.doubleClickTabToClose && (!doc.isPinned || !workspace.tabPinFeature) {
                    onClose()
                }
            }
            .onTapGesture(count: 1) {
                onSelect()
            }

            // Close button [x] (respects showTabCloseButton, hidden if pinned, respects tabShowOnlyPinnedButton)
            let showClose = workspace.showTabCloseButton && (!workspace.tabShowOnlyPinnedButton || doc.isPinned)
            if showClose && (!doc.isPinned || !workspace.tabPinFeature) {
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
            // Top highlight bar (Authentic Notepad++ Orange Bar, view-rotate-4.png)
            VStack {
                if doc.tabColorId >= 1 && doc.tabColorId <= 5 {
                    Rectangle()
                        .fill(Self.tabAccentColor(for: doc.tabColorId))
                        .frame(height: 3.0)
                        .cornerRadius(1)
                } else if isActive && workspace.tabColorIndicator {
                    Rectangle()
                        .fill(Color(red: 0.98, green: 0.48, blue: 0.12)) // Authentic Notepad++ Orange highlight
                        .frame(height: 2.5)
                        .cornerRadius(1)
                }
                Spacer()
            }
        )
        .onHover { hovering in
            isHovering = hovering
        }
        .help(workspace.docPeekerOnTab ? "\(displayedTitle)\n\(String(doc.content.prefix(200)))" : "")
        // MARK: - Notepad++ Tab Right Click Context Menu (tabContextMenu.xml)
        .contextMenu {
            if !doc.isPinned {
                Button(workspace.tr("Close")) { onClose() }
            }

            Button(workspace.tr(doc.isPinned ? "Unpin Tab" : "Pin Tab")) {
                workspace.togglePin(id: doc.id)
            }

            Divider()

            // Authentic Dual View Commands
            Button(workspace.tr("Move to Other View")) {
                workspace.moveToOtherView(id: doc.id)
            }
            Button(workspace.tr("Clone to Other View")) {
                workspace.cloneToOtherView(id: doc.id)
            }

            Divider()

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
                workspace.moveTabToStart(id: doc.id, viewIndex: viewIndex)
            }
            Button(workspace.tr("Move to End")) {
                workspace.moveTabToEnd(id: doc.id, viewIndex: viewIndex)
            }

            Divider()

            Menu(workspace.tr("Close Multiple Documents")) {
                Button(workspace.tr("Close All but Active Document")) {
                    _ = workspace.closeAllBut(id: doc.id, force: false)
                }
                Button(workspace.tr("Close All but Pinned Documents")) {
                    _ = workspace.closeAllButPinned(force: false)
                }
                Button(workspace.tr("Close All to the Left")) {
                    _ = workspace.closeAllToLeft(of: doc.id, force: false)
                }
                Button(workspace.tr("Close All to the Right")) {
                    _ = workspace.closeAllToRight(of: doc.id, force: false)
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
