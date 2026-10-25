import SwiftUI
import AppKit

public struct NppDocumentListView: View {
    @ObservedObject var workspace: NppWorkspace

    public init(workspace: NppWorkspace) {
        self.workspace = workspace
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Panel Header
            HStack {
                Label(workspace.tr("Document List"), systemImage: "list.bullet.rectangle")
                    .font(.system(size: 11, weight: .semibold))
                Spacer()
                Text("\(workspace.documents.count)")
                    .font(.system(size: 10, weight: .bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(Color.secondary.opacity(0.2))
                    .cornerRadius(8)

                Button(action: { workspace.showDocumentList = false }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9))
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Documents List
            List(selection: $workspace.activeDocumentId) {
                ForEach(workspace.documents) { doc in
                    HStack(spacing: 6) {
                        // Floppy disk icon: Blue for saved, Red for dirty
                        Image(systemName: doc.isDirty ? "circle.fill" : "doc.text")
                            .font(.system(size: 10))
                            .foregroundColor(doc.isDirty ? .red : .accentColor)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(doc.title)
                                .font(.system(size: 11, weight: doc.id == workspace.activeDocumentId ? .bold : .regular))
                                .foregroundColor(doc.id == workspace.activeDocumentId ? .primary : .secondary)

                            if let path = doc.filePath {
                                Text(path.deletingLastPathComponent().path)
                                    .font(.system(size: 9))
                                    .foregroundColor(.secondary.opacity(0.8))
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                        }

                        Spacer()

                        // Close button on hover
                        Button(action: {
                            workspace.closeDocument(id: doc.id)
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 8))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.vertical, 2)
                    .tag(doc.id)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        workspace.activeDocumentId = doc.id
                    }
                    .contextMenu {
                        Button(workspace.tr("Close")) {
                            workspace.closeDocument(id: doc.id)
                        }
                        Button(workspace.tr("Close All BUT This")) {
                            workspace.closeAllBut(id: doc.id)
                        }
                        Divider()
                        if let path = doc.filePath {
                            Button(workspace.tr("Open Containing Folder in Finder")) {
                                NSWorkspace.shared.activateFileViewerSelecting([path])
                            }
                            Button(workspace.tr("Open in Terminal")) {
                                NppTools.openTerminal(at: path.deletingLastPathComponent())
                            }
                            Divider()
                            Button(workspace.tr("Copy Full File Path")) {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(path.path, forType: .string)
                            }
                        }
                    }
                }
            }
            .listStyle(PlainListStyle())
        }
        .background(Color(NSColor.controlBackgroundColor))
    }
}
