import SwiftUI
import AppKit

public struct NppToolbarView: View {
    @ObservedObject var workspace: NppWorkspace

    public init(workspace: NppWorkspace) {
        self.workspace = workspace
    }

    public var body: some View {
        HStack(spacing: 3) {
            // Group 1: File Operations (New, Open, Save, Save All, Close, Close All, Print)
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
            NppToolbarButton(icon: "xmark.circle", tooltip: "Close (Cmd+W)") {
                workspace.closeActive()
            }
            NppToolbarButton(icon: "xmark.circle.fill", tooltip: "Close All Tabs") {
                workspace.closeAll()
            }
            NppToolbarButton(icon: "printer", tooltip: "Print... (Cmd+P)") {
                workspace.printActive()
            }

            Divider().frame(height: 18).padding(.horizontal, 2)

            // Group 2: Edit Operations (Cut, Copy, Paste, Undo, Redo)
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

            // Group 3: Search & Zoom (Find, Replace, Zoom In, Zoom Out)
            NppToolbarButton(icon: "magnifyingglass", tooltip: "Find (Cmd+F)", isActive: workspace.showSearchBar) {
                workspace.showSearchBar = true
            }
            NppToolbarButton(icon: "arrow.triangle.2.circlepath", tooltip: "Replace (Cmd+H)", isActive: workspace.showSearchBar) {
                workspace.showSearchBar = true
            }
            NppToolbarButton(icon: "plus.magnifyingglass", tooltip: "Zoom In (Cmd++)") {
                workspace.zoomIn()
            }
            NppToolbarButton(icon: "minus.magnifyingglass", tooltip: "Zoom Out (Cmd+-)") {
                workspace.zoomOut()
            }

            Divider().frame(height: 18).padding(.horizontal, 2)

            // Group 4: View & Display formatting (Word Wrap, Characters ¶, Indent Guide, Language, Map, Func List, Scroll Sync)
            NppToolbarButton(icon: "text.wrap", tooltip: "Toggle Word Wrap", isActive: workspace.isWordWrapEnabled) {
                workspace.isWordWrapEnabled.toggle()
            }
            NppToolbarButton(icon: "paragraphsign", tooltip: "Show All Characters (¶)", isActive: workspace.showInvisibleCharacters) {
                workspace.showInvisibleCharacters.toggle()
            }
            NppToolbarButton(icon: "checklist.unchecked", tooltip: "Show Indent Guide", isActive: workspace.showIndentGuides) {
                workspace.showIndentGuides.toggle()
            }
            NppToolbarButton(icon: "chevron.left.forwardslash.chevron.right", tooltip: "Define your language...") {
                showDefineLanguageAlert()
            }
            NppToolbarButton(icon: "rectangle.split.2x1", tooltip: "Document Map", isActive: workspace.showDocumentMap) {
                workspace.showDocumentMap.toggle()
            }
            NppToolbarButton(icon: "function", tooltip: "Function List", isActive: workspace.showFunctionList) {
                workspace.showFunctionList.toggle()
            }
            NppToolbarButton(icon: "arrow.up.and.down", tooltip: "Synchronize Vertical Scrolling", isActive: workspace.syncScrollV) {
                workspace.syncScrollV.toggle()
            }
            NppToolbarButton(icon: "arrow.left.and.right", tooltip: "Synchronize Horizontal Scrolling", isActive: workspace.syncScrollH) {
                workspace.syncScrollH.toggle()
            }

            Divider().frame(height: 18).padding(.horizontal, 2)

            // Group 5: Macro Operations (Start, Stop, Play, Run Multiple)
            NppToolbarButton(
                icon: "circle.fill",
                tooltip: "Start Recording Macro",
                color: .red,
                isActive: workspace.isMacroRecording
            ) {
                workspace.startMacroRecording()
            }
            NppToolbarButton(
                icon: "square.fill",
                tooltip: "Stop Recording Macro",
                isEnabled: workspace.isMacroRecording
            ) {
                workspace.stopMacroRecording()
            }
            NppToolbarButton(
                icon: "play.fill",
                tooltip: "Playback Recorded Macro",
                color: .green
            ) {
                workspace.playbackMacro()
            }
            NppToolbarButton(
                icon: "forward.fill",
                tooltip: "Run a Macro Multiple Times..."
            ) {
                workspace.runMacroMultipleTimes()
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

    private func showDefineLanguageAlert() {
        let alert = NSAlert()
        alert.messageText = "User-Defined Language"
        alert.informativeText = "Current language: \(workspace.activeDocument?.language ?? "Plain Text")\n\nYou can select syntax highlighting for C, C++, Swift, Python, JS, TS, HTML, CSS, JSON, XML, SQL, Shell, Markdown, Java, Rust, Go from the 'Language' menu."
        alert.alertStyle = .informational
        alert.runModal()
    }
}

public struct NppToolbarButton: View {
    let icon: String
    let tooltip: String
    var color: Color? = nil
    var isEnabled: Bool = true
    var isActive: Bool = false
    let action: () -> Void

    @State private var isHovering: Bool = false

    public var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(buttonColor)
                .frame(width: 24, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isActive ? Color.accentColor.opacity(0.18) : (isHovering && isEnabled ? Color(NSColor.controlBackgroundColor) : Color.clear))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isActive ? Color.accentColor.opacity(0.4) : Color.clear, lineWidth: 1)
                )
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!isEnabled)
        .help(tooltip)
        .onHover { h in
            isHovering = h
        }
    }

    private var buttonColor: Color {
        if !isEnabled {
            return .gray.opacity(0.35)
        }
        if let customColor = color {
            return customColor
        }
        if isActive {
            return .accentColor
        }
        return isHovering ? .primary : .secondary
    }
}
