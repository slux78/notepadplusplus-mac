import SwiftUI
import AppKit

public struct NppProjectPanelView: View {
    @ObservedObject var workspace: NppWorkspace
    public let panelIndex: Int

    @State private var expandedNodeIds: Set<UUID> = []
    @State private var selectedNodeId: UUID? = nil
    @State private var editingNodeId: UUID? = nil
    @State private var editingText: String = ""

    public init(workspace: NppWorkspace, panelIndex: Int) {
        self.workspace = workspace
        self.panelIndex = panelIndex
    }

    private var projectWorkspace: NppProjectWorkspace {
        workspace.getProjectWorkspace(panelIndex: panelIndex)
    }

    private var selectedNode: NppProjectElement? {
        guard let id = selectedNodeId else { return nil }
        if projectWorkspace.rootNode.id == id { return projectWorkspace.rootNode }
        return projectWorkspace.enumAllNodes().first(where: { $0.id == id })
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Label(workspace.tr("Project Panel \(panelIndex)"), systemImage: "folder.badge.gearshape")
                    .font(.system(size: 11, weight: .semibold))
                if projectWorkspace.isDirty {
                    Text("*")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.red)
                }
                Spacer()

                Button(action: { closePanel() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9))
                }
                .buttonStyle(PlainButtonStyle())
                .help(workspace.tr("Close"))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Toolbar: Workspace Menu & Edit Menu & Fold/Unfold
            HStack(spacing: 6) {
                // Workspace Toolbar Menu
                Menu {
                    Button(workspace.tr("New Workspace")) {
                        handleNewWorkspace()
                    }
                    Button(workspace.tr("Open Workspace...")) {
                        handleOpenWorkspace()
                    }
                    Button(workspace.tr("Reload Workspace")) {
                        handleReloadWorkspace()
                    }
                    .disabled(projectWorkspace.filePath == nil)

                    Divider()

                    Button(workspace.tr("Save")) {
                        handleSaveWorkspace()
                    }
                    Button(workspace.tr("Save As...")) {
                        handleSaveAsWorkspace()
                    }
                    Button(workspace.tr("Save a Copy As...")) {
                        handleSaveCopyAsWorkspace()
                    }

                    Divider()

                    Button(workspace.tr("Add New Project")) {
                        let newProj = projectWorkspace.addProject(name: workspace.tr("Project Name"))
                        selectedNodeId = newProj.id
                        editingNodeId = newProj.id
                        editingText = newProj.name
                    }

                    Button(workspace.tr("Find in Projects...")) {
                        workspace.openFindInProjects()
                    }
                } label: {
                    Text(workspace.tr("Workspace"))
                        .font(.system(size: 10))
                }
                .menuStyle(BorderlessButtonMenuStyle())

                // Edit Toolbar Menu
                Menu {
                    Button(workspace.tr("Rename")) {
                        if let sel = selectedNode, sel.type != .workspace {
                            editingNodeId = sel.id
                            editingText = sel.name
                        }
                    }
                    .disabled(selectedNode == nil || selectedNode?.type == .workspace)

                    Button(workspace.tr("Add Folder")) {
                        if let sel = selectedNode, sel.type == .project || sel.type == .folder {
                            let f = projectWorkspace.addFolder(parent: sel, name: workspace.tr("Folder Name"))
                            expandedNodeIds.insert(sel.id)
                            selectedNodeId = f.id
                            editingNodeId = f.id
                            editingText = f.name
                        }
                    }
                    .disabled(selectedNode == nil || (selectedNode?.type != .project && selectedNode?.type != .folder))

                    Button(workspace.tr("Add Files...")) {
                        if let sel = selectedNode, sel.type == .project || sel.type == .folder {
                            handleAddFiles(to: sel)
                        }
                    }
                    .disabled(selectedNode == nil || (selectedNode?.type != .project && selectedNode?.type != .folder))

                    Button(workspace.tr("Add Files from Directory...")) {
                        if let sel = selectedNode, sel.type == .project || sel.type == .folder {
                            handleAddFilesRecursively(to: sel)
                        }
                    }
                    .disabled(selectedNode == nil || (selectedNode?.type != .project && selectedNode?.type != .folder))

                    Divider()

                    Button(workspace.tr("Move Up")) {
                        if let sel = selectedNode, sel.type != .workspace {
                            _ = projectWorkspace.moveNode(sel, up: true)
                        }
                    }
                    .disabled(selectedNode == nil || selectedNode?.type == .workspace)

                    Button(workspace.tr("Move Down")) {
                        if let sel = selectedNode, sel.type != .workspace {
                            _ = projectWorkspace.moveNode(sel, up: false)
                        }
                    }
                    .disabled(selectedNode == nil || selectedNode?.type == .workspace)

                    Divider()

                    Button(workspace.tr("Remove")) {
                        if let sel = selectedNode, sel.type != .workspace {
                            projectWorkspace.removeNode(sel)
                            selectedNodeId = nil
                        }
                    }
                    .disabled(selectedNode == nil || selectedNode?.type == .workspace)
                } label: {
                    Text(workspace.tr("Edit"))
                        .font(.system(size: 10))
                }
                .menuStyle(BorderlessButtonMenuStyle())

                Spacer()

                Button(action: {
                    for node in projectWorkspace.enumAllNodes() where node.type == .project || node.type == .folder {
                        expandedNodeIds.insert(node.id)
                    }
                }) {
                    Image(systemName: "arrow.down.right.and.arrow.up.left")
                        .font(.system(size: 9))
                }
                .buttonStyle(PlainButtonStyle())
                .help(workspace.tr("Unfold All"))

                Button(action: {
                    expandedNodeIds.removeAll()
                }) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 9))
                }
                .buttonStyle(PlainButtonStyle())
                .help(workspace.tr("Fold All"))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Tree View
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    // Root Node
                    rootNodeRow(projectWorkspace.rootNode)

                    // Project Children
                    ForEach(projectWorkspace.rootNode.children) { proj in
                        NppProjectNodeRowView(
                            node: proj,
                            depth: 1,
                            workspace: workspace,
                            projectWorkspace: projectWorkspace,
                            expandedNodeIds: $expandedNodeIds,
                            selectedNodeId: $selectedNodeId,
                            editingNodeId: $editingNodeId,
                            editingText: $editingText
                        )
                    }
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 4)
            }
            .background(Color(NSColor.textBackgroundColor))
        }
    }

    private func closePanel() {
        switch panelIndex {
        case 1: workspace.showProjectPanel1 = false
        case 2: workspace.showProjectPanel2 = false
        case 3: workspace.showProjectPanel3 = false
        default: break
        }
    }

    // MARK: - Root Node Row

    @ViewBuilder
    private func rootNodeRow(_ node: NppProjectElement) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "folder.badge.gearshape")
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            Text(projectWorkspace.displayName)
                .font(.system(size: 11, weight: .bold))

            Spacer()
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .background(selectedNodeId == node.id ? Color.accentColor.opacity(0.2) : Color.clear)
        .cornerRadius(3)
        .onTapGesture {
            selectedNodeId = node.id
        }
        .contextMenu {
            Button(workspace.tr("New Workspace")) { handleNewWorkspace() }
            Button(workspace.tr("Open Workspace...")) { handleOpenWorkspace() }
            Button(workspace.tr("Reload Workspace")) { handleReloadWorkspace() }
                .disabled(projectWorkspace.filePath == nil)
            Divider()
            Button(workspace.tr("Save")) { handleSaveWorkspace() }
            Button(workspace.tr("Save As...")) { handleSaveAsWorkspace() }
            Button(workspace.tr("Save a Copy As...")) { handleSaveCopyAsWorkspace() }
            Divider()
            Button(workspace.tr("Add New Project")) {
                let p = projectWorkspace.addProject(name: workspace.tr("Project Name"))
                selectedNodeId = p.id
            }
            Button(workspace.tr("Find in Projects...")) {
                workspace.openFindInProjects()
            }
        }
    }

    // MARK: - Action Handlers

    private func handleNewWorkspace() {
        if projectWorkspace.isDirty {
            let alert = NSAlert()
            alert.messageText = workspace.tr("Workspace has been modified. Save changes?")
            alert.addButton(withTitle: workspace.tr("Save"))
            alert.addButton(withTitle: workspace.tr("Don't Save"))
            alert.addButton(withTitle: workspace.tr("Cancel"))
            let resp = alert.runModal()
            if resp == .alertFirstButtonReturn {
                handleSaveWorkspace()
            } else if resp == .alertThirdButtonReturn {
                return
            }
        }
        projectWorkspace.newWorkspace()
        expandedNodeIds.removeAll()
        selectedNodeId = nil
    }

    private func handleOpenWorkspace() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        if #available(macOS 12.0, *) {
            panel.allowedContentTypes = []
        }
        if panel.runModal() == .OK, let url = panel.url {
            do {
                try projectWorkspace.loadWorkspace(from: url)
                expandedNodeIds.removeAll()
                selectedNodeId = nil
            } catch {
                let alert = NSAlert(error: error)
                alert.runModal()
            }
        }
    }

    private func handleReloadWorkspace() {
        guard let url = projectWorkspace.filePath else { return }
        if projectWorkspace.isDirty {
            let alert = NSAlert()
            alert.messageText = workspace.tr("Reload will discard all changes. Continue?")
            alert.addButton(withTitle: workspace.tr("OK"))
            alert.addButton(withTitle: workspace.tr("Cancel"))
            if alert.runModal() != .alertFirstButtonReturn { return }
        }
        do {
            try projectWorkspace.loadWorkspace(from: url)
        } catch {
            let alert = NSAlert(error: error)
            alert.runModal()
        }
    }

    private func handleSaveWorkspace() {
        if let url = projectWorkspace.filePath {
            do {
                try projectWorkspace.saveWorkspace(to: url)
            } catch {
                let alert = NSAlert(error: error)
                alert.runModal()
            }
        } else {
            handleSaveAsWorkspace()
        }
    }

    private func handleSaveAsWorkspace() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "workspace.npp_project"
        if panel.runModal() == .OK, let url = panel.url {
            do {
                try projectWorkspace.saveWorkspace(to: url)
            } catch {
                let alert = NSAlert(error: error)
                alert.runModal()
            }
        }
    }

    private func handleSaveCopyAsWorkspace() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "copy_workspace.npp_project"
        if panel.runModal() == .OK, let url = panel.url {
            do {
                let xml = try projectWorkspace.exportToXml()
                try xml.write(to: url, atomically: true, encoding: .utf8)
            } catch {
                let alert = NSAlert(error: error)
                alert.runModal()
            }
        }
    }

    private func handleAddFiles(to parent: NppProjectElement) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        if panel.runModal() == .OK {
            for url in panel.urls {
                _ = projectWorkspace.addFile(parent: parent, fileUrl: url)
            }
            expandedNodeIds.insert(parent.id)
        }
    }

    private func handleAddFilesRecursively(to parent: NppProjectElement) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            projectWorkspace.addFilesFromDirectory(parent: parent, dirUrl: url)
            expandedNodeIds.insert(parent.id)
        }
    }
}

private struct NppProjectNodeRowView: View {
    @ObservedObject var node: NppProjectElement
    let depth: Int
    let workspace: NppWorkspace
    let projectWorkspace: NppProjectWorkspace
    @Binding var expandedNodeIds: Set<UUID>
    @Binding var selectedNodeId: UUID?
    @Binding var editingNodeId: UUID?
    @Binding var editingText: String

    var isExpanded: Bool {
        expandedNodeIds.contains(node.id)
    }

    var isSelected: Bool {
        selectedNodeId == node.id
    }

    var isEditing: Bool {
        editingNodeId == node.id
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                Spacer().frame(width: CGFloat(depth * 14))

                if node.type == .project || node.type == .folder {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                        .frame(width: 10)
                        .onTapGesture {
                            toggleExpand(node.id)
                        }
                } else {
                    Spacer().frame(width: 10)
                }

                nodeIcon(node)
                    .frame(width: 14)

                if isEditing {
                    TextField("", text: $editingText, onCommit: {
                        if !editingText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            projectWorkspace.renameNode(node, to: editingText)
                        }
                        editingNodeId = nil
                    })
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .font(.system(size: 11))
                    .frame(maxWidth: .infinity)
                } else {
                    Text(node.name)
                        .font(.system(size: 11))
                        .foregroundColor(node.isMissing ? .red : .primary)
                        .lineLimit(1)

                    if node.isMissing {
                        Text("(missing)")
                            .font(.system(size: 9))
                            .foregroundColor(.red)
                    }

                    Spacer()
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
            .cornerRadius(3)
            .contentShape(Rectangle())
            .onTapGesture(count: 2) {
                if node.type == .file {
                    openFileNode(node)
                } else {
                    toggleExpand(node.id)
                }
            }
            .onTapGesture(count: 1) {
                selectedNodeId = node.id
            }
            .contextMenu {
                nodeContextMenu(node)
            }

            // Children if expanded
            if isExpanded && (node.type == .project || node.type == .folder) {
                ForEach(node.children) { child in
                    NppProjectNodeRowView(
                        node: child,
                        depth: depth + 1,
                        workspace: workspace,
                        projectWorkspace: projectWorkspace,
                        expandedNodeIds: $expandedNodeIds,
                        selectedNodeId: $selectedNodeId,
                        editingNodeId: $editingNodeId,
                        editingText: $editingText
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func nodeIcon(_ node: NppProjectElement) -> some View {
        switch node.type {
        case .workspace:
            Image(systemName: "folder.badge.gearshape")
                .foregroundColor(.secondary)
        case .project:
            Image(systemName: "shippingbox.fill")
                .foregroundColor(.accentColor)
        case .folder:
            Image(systemName: "folder.fill")
                .foregroundColor(.yellow)
        case .file:
            if node.isMissing {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
            } else {
                Image(systemName: "doc.text")
                    .foregroundColor(.secondary)
            }
        }
    }

    @ViewBuilder
    private func nodeContextMenu(_ node: NppProjectElement) -> some View {
        if node.type == .project || node.type == .folder {
            Button(workspace.tr("Add Folder")) {
                let f = projectWorkspace.addFolder(parent: node, name: workspace.tr("Folder Name"))
                expandedNodeIds.insert(node.id)
                selectedNodeId = f.id
                editingNodeId = f.id
                editingText = f.name
            }
            Button(workspace.tr("Add Files...")) {
                handleAddFiles(to: node)
            }
            Button(workspace.tr("Add Files from Directory...")) {
                handleAddFilesRecursively(to: node)
            }
            Divider()
            Button(workspace.tr("Rename")) {
                editingNodeId = node.id
                editingText = node.name
            }
            Button(workspace.tr("Move Up")) {
                _ = projectWorkspace.moveNode(node, up: true)
            }
            Button(workspace.tr("Move Down")) {
                _ = projectWorkspace.moveNode(node, up: false)
            }
            Divider()
            Button(workspace.tr("Remove")) {
                projectWorkspace.removeNode(node)
                if selectedNodeId == node.id { selectedNodeId = nil }
            }
        } else if node.type == .file {
            Button(workspace.tr("Open in Editor")) {
                openFileNode(node)
            }
            Divider()
            Button(workspace.tr("Rename")) {
                editingNodeId = node.id
                editingText = node.name
            }
            Button(workspace.tr("Modify File Path")) {
                handleModifyFilePath(node)
            }
            Button(workspace.tr("Move Up")) {
                _ = projectWorkspace.moveNode(node, up: true)
            }
            Button(workspace.tr("Move Down")) {
                _ = projectWorkspace.moveNode(node, up: false)
            }
            Divider()
            Button(workspace.tr("Remove")) {
                projectWorkspace.removeNode(node)
                if selectedNodeId == node.id { selectedNodeId = nil }
            }
        }
    }

    private func toggleExpand(_ id: UUID) {
        if expandedNodeIds.contains(id) {
            expandedNodeIds.remove(id)
        } else {
            expandedNodeIds.insert(id)
        }
    }

    private func openFileNode(_ node: NppProjectElement) {
        guard let path = node.filePath else { return }
        let url = URL(fileURLWithPath: path)
        if FileManager.default.fileExists(atPath: path) {
            workspace.openFile(url: url)
            node.isMissing = false
        } else {
            node.isMissing = true
        }
    }

    private func handleAddFiles(to parent: NppProjectElement) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        if panel.runModal() == .OK {
            for url in panel.urls {
                _ = projectWorkspace.addFile(parent: parent, fileUrl: url)
            }
            expandedNodeIds.insert(parent.id)
        }
    }

    private func handleAddFilesRecursively(to parent: NppProjectElement) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            projectWorkspace.addFilesFromDirectory(parent: parent, dirUrl: url)
            expandedNodeIds.insert(parent.id)
        }
    }

    private func handleModifyFilePath(_ node: NppProjectElement) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        if let cur = node.filePath {
            panel.directoryURL = URL(fileURLWithPath: cur).deletingLastPathComponent()
        }
        if panel.runModal() == .OK, let url = panel.url {
            projectWorkspace.modifyFilePath(node: node, newUrl: url)
        }
    }
}
