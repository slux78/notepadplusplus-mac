import SwiftUI
import AppKit

public struct NppFolderAsWorkspaceView: View {
    @ObservedObject var workspace: NppWorkspace
    @State private var expandedPaths: Set<String> = []

    public init(workspace: NppWorkspace) {
        self.workspace = workspace
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Label(workspace.tr("Folder as Workspace"), systemImage: "folder.badge.gearshape")
                    .font(.system(size: 11, weight: .semibold))
                Spacer()

                Button(action: {
                    let panel = NSOpenPanel()
                    panel.canChooseFiles = false
                    panel.canChooseDirectories = true
                    panel.allowsMultipleSelection = false
                    if panel.runModal() == .OK, let url = panel.url {
                        workspace.workspaceFolders = [url]
                    }
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 10))
                }
                .buttonStyle(PlainButtonStyle())
                .help("Add folder to workspace")

                Button(action: { workspace.showFolderAsWorkspace = false }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9))
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // 3-Button Toolbar (session.md:110-140): Unfold All, Fold All, Locate Current File
            HStack(spacing: 8) {
                Button(action: {
                    expandedPaths = NppWorkspace.unfoldAllDirectories(in: workspace.workspaceFolders)
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.down.right.and.arrow.up.left")
                            .font(.system(size: 9))
                        Text(workspace.tr("Unfold All"))
                            .font(.system(size: 10))
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .help(workspace.tr("Unfold All"))

                Button(action: {
                    expandedPaths.removeAll()
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 9))
                        Text(workspace.tr("Fold All"))
                            .font(.system(size: 10))
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .help(workspace.tr("Fold All"))

                Spacer()

                Button(action: {
                    if let activeUrl = workspace.activeDocument?.filePath {
                        let dirs = NppWorkspace.locateAncestorDirectories(for: activeUrl, in: workspace.workspaceFolders)
                        expandedPaths.formUnion(dirs)
                    }
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: "scope")
                            .font(.system(size: 10))
                        Text(workspace.tr("Locate Current File"))
                            .font(.system(size: 10))
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .help(workspace.tr("Locate Current File in Tree"))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Folder Tree
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(workspace.workspaceFolders, id: \.self) { rootUrl in
                        FolderItemView(url: rootUrl, depth: 0, expandedPaths: $expandedPaths, workspace: workspace, onSelectFile: { fileUrl in
                            workspace.openFile(url: fileUrl)
                        })
                    }
                }
                .padding(6)
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
    }
}

private struct FolderItemView: View {
    let url: URL
    let depth: Int
    @Binding var expandedPaths: Set<String>
    let workspace: NppWorkspace
    let onSelectFile: (URL) -> Void

    var isDirectory: Bool {
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue
    }

    var isExpanded: Bool {
        expandedPaths.contains(url.path)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 4) {
                Spacer().frame(width: CGFloat(depth * 12))

                if isDirectory {
                    Button(action: {
                        if isExpanded {
                            expandedPaths.remove(url.path)
                        } else {
                            expandedPaths.insert(url.path)
                        }
                    }) {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                            .frame(width: 10)
                    }
                    .buttonStyle(PlainButtonStyle())

                    Image(systemName: isExpanded ? "folder.fill" : "folder")
                        .font(.system(size: 11))
                        .foregroundColor(.accentColor)

                    Text(url.lastPathComponent)
                        .font(.system(size: 11, weight: .medium))
                        .lineLimit(1)
                } else {
                    Spacer().frame(width: 10)
                    Image(systemName: "doc")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)

                    Text(url.lastPathComponent)
                        .font(.system(size: 11))
                        .lineLimit(1)
                }

                Spacer()
            }
            .padding(.vertical, 2)
            .contentShape(Rectangle())
            .onTapGesture {
                if isDirectory {
                    if isExpanded {
                        expandedPaths.remove(url.path)
                    } else {
                        expandedPaths.insert(url.path)
                    }
                } else {
                    onSelectFile(url)
                }
            }
            .contextMenu {
                Button(workspace.tr("Reveal in Finder")) {
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                }
                Button(workspace.tr("Copy Full Path")) {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(url.path, forType: .string)
                }
                Button(workspace.tr("Copy Filename")) {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(url.lastPathComponent, forType: .string)
                }
                Divider()
                Button(workspace.tr("Find in Files...")) {
                    workspace.openFindInFiles(directory: isDirectory ? url.path : url.deletingLastPathComponent().path)
                }
            }

            if isDirectory && isExpanded {
                let children = (try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])) ?? []
                let sortedChildren = children.sorted { a, b in
                    a.lastPathComponent.localizedCaseInsensitiveCompare(b.lastPathComponent) == .orderedAscending
                }
                ForEach(sortedChildren, id: \.self) { child in
                    FolderItemView(url: child, depth: depth + 1, expandedPaths: $expandedPaths, workspace: workspace, onSelectFile: onSelectFile)
                }
            }
        }
    }
}
