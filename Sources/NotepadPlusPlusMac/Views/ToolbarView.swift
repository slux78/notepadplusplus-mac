import SwiftUI
import AppKit

public struct NppToolbarView: View {
    @ObservedObject var workspace: NppWorkspace

    public init(workspace: NppWorkspace) {
        self.workspace = workspace
    }

    public var body: some View {
        HStack(spacing: 4) {
            // File operations
            NppToolbarButton(icon: "doc.badge.plus", tooltip: "New (Cmd+N)") {
                workspace.newDocument()
            }
            NppToolbarButton(icon: "folder", tooltip: "Open... (Cmd+O)") {
                workspace.promptOpenFile()
            }
            NppToolbarButton(icon: "square.and.arrow.down", tooltip: "Save (Cmd+S)", isEnabled: workspace.activeDocument?.isDirty ?? false) {
                workspace.saveActive()
            }
            NppToolbarButton(icon: "square.and.arrow.down.on.square", tooltip: "Save All", isEnabled: workspace.documents.contains(where: { $0.isDirty })) {
                workspace.saveAll()
            }
            NppToolbarButton(icon: "xmark.circle", tooltip: "Close Active Tab (Cmd+W)") {
                if let id = workspace.activeDocumentId {
                    workspace.closeDocument(id: id)
                }
            }
            NppToolbarButton(icon: "xmark.circle.fill", tooltip: "Close All Tabs") {
                workspace.closeAll()
            }

            Divider().frame(height: 18).padding(.horizontal, 2)

            // Edit operations
            NppToolbarButton(icon: "scissors", tooltip: "Cut (Cmd+X)") {
                NSApp.sendAction(#selector(NSText.cut(_:)), to: nil, from: nil)
            }
            NppToolbarButton(icon: "doc.on.doc", tooltip: "Copy (Cmd+C)") {
                NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: nil)
            }
            NppToolbarButton(icon: "doc.on.clipboard", tooltip: "Paste (Cmd+V)") {
                NSApp.sendAction(#selector(NSText.paste(_:)), to: nil, from: nil)
            }
            NppToolbarButton(icon: "arrow.uturn.backward", tooltip: "Undo (Cmd+Z)") {
                NSApp.sendAction(Selector(("undo:")), to: nil, from: nil)
            }
            NppToolbarButton(icon: "arrow.uturn.forward", tooltip: "Redo (Cmd+Shift+Z)") {
                NSApp.sendAction(Selector(("redo:")), to: nil, from: nil)
            }

            Divider().frame(height: 18).padding(.horizontal, 2)

            // Search & View operations
            NppToolbarButton(icon: "magnifyingglass", tooltip: "Find & Replace (Cmd+F)", isActive: workspace.showSearchBar) {
                workspace.showSearchBar.toggle()
            }
            NppToolbarButton(icon: "plus.magnifyingglass", tooltip: "Zoom In (Cmd++)") {
                workspace.zoomIn()
            }
            NppToolbarButton(icon: "minus.magnifyingglass", tooltip: "Zoom Out (Cmd+-)") {
                workspace.zoomOut()
            }
            NppToolbarButton(icon: "text.wrap", tooltip: "Toggle Word Wrap", isActive: workspace.isWordWrapEnabled) {
                workspace.isWordWrapEnabled.toggle()
            }

            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(NSColor.windowBackgroundColor))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(NSColor.separatorColor)),
            alignment: .bottom
        )
    }
}

public struct NppToolbarButton: View {
    let icon: String
    let tooltip: String
    var isEnabled: Bool = true
    var isActive: Bool = false
    let action: () -> Void

    @State private var isHovering: Bool = false

    public var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundColor(
                    !isEnabled ? .gray.opacity(0.4) :
                    (isActive ? .accentColor : (isHovering ? .primary : .secondary))
                )
                .frame(width: 26, height: 26)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isActive ? Color.accentColor.opacity(0.15) : (isHovering && isEnabled ? Color(NSColor.controlBackgroundColor) : Color.clear))
                )
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!isEnabled)
        .help(tooltip)
        .onHover { h in
            isHovering = h
        }
    }
}
