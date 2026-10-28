import AppKit
import SwiftUI

// MARK: - Windows Management Dialog View (Notepad++ IDD_WINDOWS Parity)
public struct NppWindowsDialogView: View {
    @ObservedObject public var workspace: NppWorkspace
    public let onClose: () -> Void

    @State private var selectedDocIds: Set<UUID> = []
    @State private var sortColumn: Int = 0 // 0: Name, 1: Path, 2: Type, 3: Size, 4: Modified Time
    @State private var isAscending: Bool = true

    public init(workspace: NppWorkspace, onClose: @escaping () -> Void) {
        self.workspace = workspace
        self.onClose = onClose
    }

    private static let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return df
    }()

    public var sortedDocuments: [NppDocument] {
        workspace.documents.sorted { a, b in
            switch sortColumn {
            case 0: // Name
                let res = a.title.localizedStandardCompare(b.title)
                if res != .orderedSame {
                    return isAscending ? res == .orderedAscending : res == .orderedDescending
                }
            case 1: // Path
                let p1 = a.filePath?.path ?? ""
                let p2 = b.filePath?.path ?? ""
                let res = p1.localizedStandardCompare(p2)
                if res != .orderedSame {
                    return isAscending ? res == .orderedAscending : res == .orderedDescending
                }
            case 2: // Type
                let res = a.language.localizedStandardCompare(b.language)
                if res != .orderedSame {
                    return isAscending ? res == .orderedAscending : res == .orderedDescending
                }
            case 3: // Size
                if a.content.count != b.content.count {
                    return isAscending ? a.content.count < b.content.count : a.content.count > b.content.count
                }
            case 4: // Modified Time
                let d1 = a.lastKnownModificationDate ?? Date.distantPast
                let d2 = b.lastKnownModificationDate ?? Date.distantPast
                if d1 != d2 {
                    return isAscending ? d1 < d2 : d1 > d2
                }
            default:
                break
            }
            // Secondary tie-breaker fallback to path/title
            let p1 = a.filePath?.path ?? a.title
            let p2 = b.filePath?.path ?? b.title
            return p1.localizedStandardCompare(p2) == .orderedAscending
        }
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 14) {
            // Left: 5-Column Documents List
            VStack(spacing: 0) {
                // Table Header
                HStack(spacing: 0) {
                    headerButton(title: workspace.tr("Name"), col: 0, width: 150)
                    Divider()
                    headerButton(title: workspace.tr("Path"), col: 1, width: 180)
                    Divider()
                    headerButton(title: workspace.tr("Type"), col: 2, width: 90)
                    Divider()
                    headerButton(title: workspace.tr("Size"), col: 3, width: 70)
                    Divider()
                    headerButton(title: workspace.tr("Modified time"), col: 4, width: 140)
                }
                .frame(height: 24)
                .background(Color(NSColor.controlBackgroundColor))
                .border(Color.secondary.opacity(0.3), width: 1)

                // Table Rows
                ScrollView {
                    LazyVStack(spacing: 1) {
                        ForEach(sortedDocuments) { doc in
                            rowView(for: doc)
                        }
                    }
                }
                .border(Color.secondary.opacity(0.3), width: 1)
                .background(Color(NSColor.textBackgroundColor))
            }
            .frame(minWidth: 630)

            // Right: Action Buttons (WindowsDlg.rc vertical layout)
            VStack(spacing: 8) {
                // Activate (Strictly disabled when selected count != 1)
                Button(workspace.tr("Activate")) {
                    activateSelected()
                }
                .frame(width: 120)
                .disabled(selectedDocIds.count != 1)
                .keyboardShortcut(.defaultAction)

                // Save
                Button(workspace.tr("Save")) {
                    saveSelected()
                }
                .frame(width: 120)
                .disabled(selectedDocIds.isEmpty)

                // Close window(s)
                Button(workspace.tr("Close window(s)")) {
                    closeSelected()
                }
                .frame(width: 120)
                .disabled(selectedDocIds.isEmpty)

                // Sort tabs (reorders workspace.documents to match current dialog order)
                Button(workspace.tr("Sort tabs")) {
                    sortTabsToCurrentOrder()
                }
                .frame(width: 120)

                Spacer()

                // OK / Close
                Button(workspace.tr("OK")) {
                    onClose()
                }
                .frame(width: 120)
                .keyboardShortcut(.cancelAction)
            }
            .padding(.top, 4)
        }
        .padding(14)
        .frame(minWidth: 780, minHeight: 420)
    }

    private func headerButton(title: String, col: Int, width: CGFloat) -> some View {
        Button(action: {
            if sortColumn == col {
                isAscending.toggle()
            } else {
                sortColumn = col
                isAscending = true
            }
        }) {
            HStack(spacing: 2) {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
                if sortColumn == col {
                    Text(isAscending ? "▲" : "▼")
                        .font(.system(size: 8))
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 4)
            .frame(width: width, height: 24)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func rowView(for doc: NppDocument) -> some View {
        let isSelected = selectedDocIds.contains(doc.id)
        let isActive = doc.id == workspace.activeDocumentId

        let displayName = "\(doc.title)\(doc.isDirty ? "*" : "")\(doc.isReadOnly ? " [Read Only]" : "")"
        let displayPath = doc.filePath?.deletingLastPathComponent().path ?? ""
        let displayType = doc.language
        let displaySize = "\(doc.content.count)"
        let displayDate = doc.lastKnownModificationDate != nil ? Self.dateFormatter.string(from: doc.lastKnownModificationDate!) : ""

        return HStack(spacing: 0) {
            Text(displayName)
                .font(.system(size: 11, weight: isActive ? .bold : .regular))
                .foregroundColor(doc.isDirty ? .red : .primary)
                .frame(width: 150, alignment: .leading)
                .lineLimit(1)
                .padding(.horizontal, 4)

            Text(displayPath)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .frame(width: 180, alignment: .leading)
                .lineLimit(1)
                .padding(.horizontal, 4)

            Text(displayType)
                .font(.system(size: 11))
                .frame(width: 90, alignment: .leading)
                .lineLimit(1)
                .padding(.horizontal, 4)

            Text(displaySize)
                .font(.system(size: 11, design: .monospaced))
                .frame(width: 70, alignment: .trailing)
                .padding(.horizontal, 4)

            Text(displayDate)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 140, alignment: .leading)
                .padding(.horizontal, 4)
        }
        .frame(height: 22)
        .background(isSelected ? Color.accentColor.opacity(0.25) : (isActive ? Color.accentColor.opacity(0.08) : Color.clear))
        .contentShape(Rectangle())
        .onTapGesture {
            if NSEvent.modifierFlags.contains(.command) {
                if selectedDocIds.contains(doc.id) {
                    selectedDocIds.remove(doc.id)
                } else {
                    selectedDocIds.insert(doc.id)
                }
            } else if NSEvent.modifierFlags.contains(.shift) {
                // Range selection
                selectedDocIds.insert(doc.id)
            } else {
                selectedDocIds = [doc.id]
            }
        }
        .contextMenu {
            Button(workspace.tr("Copy Name(s)")) {
                copySelectedNames()
            }
            Button(workspace.tr("Copy Pathname(s)")) {
                copySelectedPaths()
            }
        }
    }

    private func activateSelected() {
        guard let firstId = selectedDocIds.first else { return }
        workspace.activeDocumentId = firstId
        onClose()
    }

    private func saveSelected() {
        for id in selectedDocIds {
            if let doc = workspace.documents.first(where: { $0.id == id }) {
                _ = doc.save()
            }
        }
    }

    private func closeSelected() {
        let toClose = Array(selectedDocIds)
        for id in toClose {
            workspace.closeDocument(id: id)
        }
        selectedDocIds.removeAll()
        if workspace.documents.isEmpty {
            onClose()
        }
    }

    public func sortTabsToCurrentOrder() {
        let currentOrder = sortedDocuments
        let activeId = workspace.activeDocumentId
        workspace.documents = currentOrder
        workspace.activeDocumentId = activeId
    }

    private func copySelectedNames() {
        let names = workspace.documents.filter { selectedDocIds.contains($0.id) }.map { $0.title }
        let text = names.joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func copySelectedPaths() {
        let paths = workspace.documents.filter { selectedDocIds.contains($0.id) }.map { $0.filePath?.path ?? $0.title }
        let text = paths.joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

// MARK: - Windows Management Window Controller
public final class NppWindowsDialogWindowController: NSObject, NSWindowDelegate {
    public static let shared = NppWindowsDialogWindowController()
    public private(set) var panel: NSPanel?
    private weak var workspace: NppWorkspace?

    private override init() {
        super.init()
    }

    public func show(workspace: NppWorkspace) {
        self.workspace = workspace
        close()

        let newPanel = NSPanel(
            contentRect: NSRect(x: 180, y: 240, width: 800, height: 460),
            styleMask: [.titled, .closable, .resizable, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        newPanel.isFloatingPanel = true
        newPanel.level = .floating
        newPanel.hidesOnDeactivate = true
        newPanel.isReleasedWhenClosed = false
        newPanel.delegate = self
        newPanel.title = "\(workspace.tr("Windows")) - \(workspace.tr("Total documents:")) \(workspace.documents.count)"

        let hostingView = NSHostingView(
            rootView: NppWindowsDialogView(
                workspace: workspace,
                onClose: { [weak self] in
                    self?.close()
                }
            )
        )
        newPanel.contentView = hostingView
        self.panel = newPanel

        newPanel.center()
        newPanel.makeKeyAndOrderFront(nil)
    }

    public func close() {
        panel?.orderOut(nil)
        panel = nil
    }

    public func windowWillClose(_ notification: Notification) {
        panel = nil
    }
}
