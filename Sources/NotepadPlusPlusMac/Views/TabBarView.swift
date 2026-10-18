import SwiftUI
import AppKit

public struct NppTabBarView: View {
    @ObservedObject var workspace: NppWorkspace

    public init(workspace: NppWorkspace) {
        self.workspace = workspace
    }

    public var body: some View {
        HStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 2) {
                    ForEach(workspace.documents) { doc in
                        NppTabItemView(
                            doc: doc,
                            workspace: workspace,
                            isActive: workspace.activeDocumentId == doc.id,
                            onSelect: {
                                workspace.activeDocumentId = doc.id
                            },
                            onClose: {
                                workspace.closeDocument(id: doc.id)
                            }
                        )
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 3)
            }

            // New Tab "+" Button
            Button(action: {
                workspace.newDocument()
            }) {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondary)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.trailing, 6)
        }
        .background(Color(NSColor.windowBackgroundColor))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(NSColor.separatorColor)),
            alignment: .bottom
        )
    }
}

public struct NppTabItemView: View {
    @ObservedObject var doc: NppDocument
    @ObservedObject var workspace: NppWorkspace
    let isActive: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    @State private var isHovering: Bool = false

    public var body: some View {
        HStack(spacing: 6) {
            // Notepad++ Floppy Disk Icon: Blue for saved, Red for dirty
            Image(systemName: doc.isDirty ? "circle.fill" : "doc.text")
                .font(.system(size: 10))
                .foregroundColor(doc.isDirty ? .red : .blue)

            Text(doc.title)
                .font(.system(size: 12, weight: isActive ? .medium : .regular))
                .foregroundColor(isActive ? .primary : .secondary)
                .lineLimit(1)

            // Close button
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(isHovering || isActive ? .secondary : .clear)
                    .frame(width: 14, height: 14)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(isActive ? Color(NSColor.controlBackgroundColor) : (isHovering ? Color(NSColor.controlBackgroundColor).opacity(0.5) : Color.clear))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 5)
                .stroke(isActive ? Color(NSColor.separatorColor) : Color.clear, lineWidth: 1)
        )
        .onHover { hovering in
            isHovering = hovering
        }
        .onTapGesture {
            onSelect()
        }
        // MARK: - Notepad++ Tab Right Click Context Menu (tabContextMenu.xml)
        .contextMenu {
            Button("Close") { onClose() }

            Menu("Close Multiple Tabs") {
                Button("Close All but Active Document") {
                    workspace.closeAllBut(id: doc.id)
                }
                Button("Close All to the Left") {
                    workspace.closeAllToLeft(of: doc.id)
                }
                Button("Close All to the Right") {
                    workspace.closeAllToRight(of: doc.id)
                }
                Button("Close All Unchanged") {
                    workspace.closeAllUnchanged()
                }
            }

            Divider()

            Button("Save") {
                if doc.filePath != nil {
                    _ = doc.save()
                } else {
                    workspace.promptSaveAs(for: doc)
                }
            }
            Button("Save As...") {
                workspace.promptSaveAs(for: doc)
            }
            if doc.filePath != nil {
                Button("Reload from Disk") {
                    workspace.reloadFromDisk(for: doc)
                }
            }

            Divider()

            if let path = doc.filePath {
                Menu("Open into") {
                    Button("Open Containing Folder in Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting([path])
                    }
                    Button("Open in Terminal") {
                        let dir = path.deletingLastPathComponent().path
                        let script = "tell application \"Terminal\" to do script \"cd '\(dir)'\""
                        if let appleScript = NSAppleScript(source: script) {
                            var error: NSDictionary?
                            appleScript.executeAndReturnError(&error)
                        }
                    }
                }

                Divider()

                Menu("Copy to Clipboard") {
                    Button("Copy Current Full File Path") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(path.path, forType: .string)
                    }
                    Button("Copy Current Filename") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(path.lastPathComponent, forType: .string)
                    }
                    Button("Copy Current Dir. Path") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(path.deletingLastPathComponent().path, forType: .string)
                    }
                }
            }
        }
    }
}
