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

            // Folder Tree
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(workspace.workspaceFolders, id: \.self) { rootUrl in
                        FolderItemView(url: rootUrl, depth: 0, expandedPaths: $expandedPaths, onSelectFile: { fileUrl in
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

            if isDirectory && isExpanded {
                let children = (try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])) ?? []
                let sortedChildren = children.sorted { a, b in
                    a.lastPathComponent.localizedCaseInsensitiveCompare(b.lastPathComponent) == .orderedAscending
                }
                ForEach(sortedChildren, id: \.self) { child in
                    FolderItemView(url: child, depth: depth + 1, expandedPaths: $expandedPaths, onSelectFile: onSelectFile)
                }
            }
        }
    }
}
