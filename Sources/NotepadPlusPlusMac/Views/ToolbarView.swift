import SwiftUI
import AppKit

public struct NppToolbarView: View {
    @ObservedObject var workspace: NppWorkspace

    public init(workspace: NppWorkspace) {
        self.workspace = workspace
    }

    private var isLarge: Bool {
        workspace.largeToolbarIcons || workspace.toolbarIconStyle.contains("large")
    }

    private var buttonSize: CGFloat {
        isLarge ? 32 : 24
    }

    private var iconSize: CGFloat {
        isLarge ? 17 : 12
    }

    private var isFilled: Bool {
        workspace.toolbarIconStyle.contains("Filled")
    }

    public var resolvedThemeColor: Color? {
        Self.resolvedColor(choice: workspace.toolbarColorChoice)
    }

    public static func resolvedColor(choice: String) -> Color? {
        switch choice {
        case "Red": return .red
        case "Green": return .green
        case "Blue": return .blue
        case "Purple": return .purple
        case "Cyan": return .cyan
        case "Olive": return Color(red: 0.5, green: 0.5, blue: 0.0)
        case "Yellow": return .yellow
        case "System Accent": return .accentColor
        case "Custom": return Color(red: 0.2, green: 0.6, blue: 0.86)
        default: return nil
        }
    }

    private var isCompleteColorization: Bool {
        workspace.toolbarColorization == "Complete"
    }

    public static func resolveIconName(_ base: String, isFilled: Bool) -> String {
        if isFilled {
            switch base {
            case "folder": return "folder.fill"
            case "square.and.arrow.down": return "square.and.arrow.down.fill"
            case "square.and.arrow.down.on.square": return "square.and.arrow.down.on.square.fill"
            case "xmark.circle": return "xmark.circle.fill"
            case "printer": return "printer.fill"
            case "doc.on.doc": return "doc.on.doc.fill"
            case "doc.on.clipboard": return "doc.on.clipboard.fill"
            case "arrow.uturn.backward": return "arrow.uturn.backward.circle.fill"
            case "arrow.uturn.forward": return "arrow.uturn.forward.circle.fill"
            case "magnifyingglass": return "magnifyingglass.circle.fill"
            case "arrow.triangle.2.circlepath": return "arrow.triangle.2.circlepath.circle.fill"
            case "gearshape": return "gearshape.fill"
            case "list.bullet.rectangle": return "list.bullet.rectangle.fill"
            case "folder.badge.gearshape": return "folder.fill.badge.gearshape"
            case "rectangle.split.2x1": return "rectangle.split.2x1.fill"
            case "eye": return "eye.fill"
            default: return base
            }
        }
        return base
    }

    private func icon(_ base: String) -> String {
        Self.resolveIconName(base, isFilled: isFilled)
    }

    public var body: some View {
        HStack(spacing: isLarge ? 4 : 3) {
            // Group 1: File Operations (New, Open, Save, Save All, Close, Close All, Print)
            toolbarBtn(icon: icon("doc.badge.plus"), tooltip: workspace.tr("New")) {
                workspace.newDocument()
            }
            toolbarBtn(icon: icon("folder"), tooltip: workspace.tr("Open...")) {
                workspace.promptOpenFile()
            }
            toolbarBtn(icon: icon("square.and.arrow.down"), tooltip: workspace.tr("Save"), isEnabled: workspace.activeDocument?.isDirty ?? false) {
                workspace.saveActive()
            }
            toolbarBtn(icon: icon("square.and.arrow.down.on.square"), tooltip: workspace.tr("Save All"), isEnabled: workspace.documents.contains(where: { $0.isDirty })) {
                workspace.saveAll()
            }
            toolbarBtn(icon: icon("xmark.circle"), tooltip: workspace.tr("Close")) {
                workspace.closeActive()
            }
            toolbarBtn(icon: "xmark.circle.fill", tooltip: workspace.tr("Close All")) {
                workspace.closeAll()
            }
            toolbarBtn(icon: icon("printer"), tooltip: workspace.tr("Print...")) {
                workspace.printActive()
            }

            Divider().frame(height: isLarge ? 24 : 18).padding(.horizontal, isLarge ? 3 : 2)

            // Group 2: Edit Operations (Cut, Copy, Paste, Undo, Redo)
            toolbarBtn(icon: "scissors", tooltip: workspace.tr("Cut")) {
                workspace.cut()
            }
            toolbarBtn(icon: icon("doc.on.doc"), tooltip: workspace.tr("Copy")) {
                workspace.copy()
            }
            toolbarBtn(icon: icon("doc.on.clipboard"), tooltip: workspace.tr("Paste")) {
                workspace.paste()
            }
            toolbarBtn(icon: icon("arrow.uturn.backward"), tooltip: workspace.tr("Undo")) {
                workspace.undo()
            }
            toolbarBtn(icon: icon("arrow.uturn.forward"), tooltip: workspace.tr("Redo")) {
                workspace.redo()
            }

            Divider().frame(height: isLarge ? 24 : 18).padding(.horizontal, isLarge ? 3 : 2)

            // Group 3: Search & Zoom (Find, Replace, Zoom In, Zoom Out)
            toolbarBtn(icon: icon("magnifyingglass"), tooltip: workspace.tr("Find..."), isActive: workspace.showFindReplaceDialog && workspace.findReplaceTab == 0) {
                if workspace.showFindReplaceDialog && workspace.findReplaceTab == 0 {
                    workspace.showFindReplaceDialog = false
                } else {
                    workspace.openFind()
                }
            }
            toolbarBtn(icon: icon("arrow.triangle.2.circlepath"), tooltip: workspace.tr("Replace..."), isActive: workspace.showFindReplaceDialog && workspace.findReplaceTab == 1) {
                if workspace.showFindReplaceDialog && workspace.findReplaceTab == 1 {
                    workspace.showFindReplaceDialog = false
                } else {
                    workspace.openReplace()
                }
            }
            toolbarBtn(icon: "plus.magnifyingglass", tooltip: workspace.tr("Zoom In")) {
                workspace.zoomIn()
            }
            toolbarBtn(icon: "minus.magnifyingglass", tooltip: workspace.tr("Zoom Out")) {
                workspace.zoomOut()
            }

            Divider().frame(height: isLarge ? 24 : 18).padding(.horizontal, isLarge ? 3 : 2)

            // Group 4: View & Display formatting (Word Wrap, Characters ¶, Indent Guide, Language, Map, Func List, Scroll Sync)
            toolbarBtn(icon: "text.wrap", tooltip: workspace.tr("Word wrap"), isActive: workspace.isWordWrapEnabled) {
                workspace.isWordWrapEnabled.toggle()
            }
            toolbarBtn(icon: "paragraphsign", tooltip: workspace.tr("Show All Characters"), isActive: workspace.showInvisibleCharacters) {
                workspace.showInvisibleCharacters.toggle()
            }
            toolbarBtn(icon: "checklist.unchecked", tooltip: workspace.tr("Show Indent Guide"), isActive: workspace.showIndentGuides) {
                workspace.showIndentGuides.toggle()
            }
            toolbarBtn(icon: "chevron.left.forwardslash.chevron.right", tooltip: workspace.tr("Language")) {
                showDefineLanguageAlert()
            }
            toolbarBtn(icon: icon("list.bullet.rectangle"), tooltip: workspace.tr("Document List"), isActive: workspace.showDocumentList) {
                workspace.showDocumentList.toggle()
            }
            toolbarBtn(icon: icon("folder.badge.gearshape"), tooltip: workspace.tr("Folder as Workspace"), isActive: workspace.showFolderAsWorkspace) {
                workspace.showFolderAsWorkspace.toggle()
            }
            toolbarBtn(icon: icon("rectangle.split.2x1"), tooltip: workspace.tr("Document Map"), isActive: workspace.showDocumentMap) {
                workspace.showDocumentMap.toggle()
            }
            toolbarBtn(icon: "function", tooltip: workspace.tr("Function List"), isActive: workspace.showFunctionList) {
                workspace.showFunctionList.toggle()
            }
            toolbarBtn(icon: "arrow.up.and.down", tooltip: workspace.tr("Synchronize Vertical Scrolling"), isActive: workspace.syncScrollV) {
                workspace.syncScrollV.toggle()
            }
            toolbarBtn(icon: "arrow.left.and.right", tooltip: workspace.tr("Synchronize Horizontal Scrolling"), isActive: workspace.syncScrollH) {
                workspace.syncScrollH.toggle()
            }
            toolbarBtn(icon: icon("eye"), tooltip: workspace.tr("Monitoring (tail -f)"), isActive: workspace.activeDocument?.isMonitoring ?? false) {
                workspace.toggleMonitoringCurrentDoc()
            }

            Divider().frame(height: isLarge ? 24 : 18).padding(.horizontal, isLarge ? 3 : 2)

            // Group 5: Macro Operations (Start, Stop, Play, Run Multiple, Save - Notepad_plus.cpp L127-131 & L2778-2783)
            toolbarBtn(
                icon: "circle.fill",
                tooltip: workspace.tr("Start Recording"),
                color: .red,
                isEnabled: !workspace.isMacroRecording,
                isActive: workspace.isMacroRecording
            ) {
                workspace.startMacroRecording()
            }
            toolbarBtn(
                icon: "square.fill",
                tooltip: workspace.tr("Stop Recording"),
                isEnabled: workspace.isMacroRecording
            ) {
                workspace.stopMacroRecording()
            }
            toolbarBtn(
                icon: "play.fill",
                tooltip: workspace.tr("Playback"),
                color: .green,
                isEnabled: workspace.canPlaybackMacro
            ) {
                workspace.playbackMacro()
            }
            toolbarBtn(
                icon: "forward.fill",
                tooltip: workspace.tr("Run a Macro Multiple Times..."),
                isEnabled: workspace.canRunMultiMacro
            ) {
                workspace.runMacroMultipleTimes()
            }
            toolbarBtn(
                icon: icon("externaldrive.badge.plus"),
                tooltip: workspace.tr("Save Current Recorded Macro..."),
                isEnabled: workspace.canSaveRecordedMacro
            ) {
                workspace.promptSaveCurrentRecordedMacro()
            }

            Divider().frame(height: isLarge ? 24 : 18).padding(.horizontal, isLarge ? 3 : 2)

            // Group 6: Preferences & Settings
            toolbarBtn(
                icon: icon("gearshape"),
                tooltip: workspace.tr("Preferences...")
            ) {
                workspace.openPreferences(tab: 0)
            }

            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, isLarge ? 6 : 4)
        .background(Color(NSColor.windowBackgroundColor))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(NSColor.separatorColor)),
            alignment: .bottom
        )
    }

    @ViewBuilder
    private func toolbarBtn(
        icon: String,
        tooltip: String,
        color: Color? = nil,
        isEnabled: Bool = true,
        isActive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        NppToolbarButton(
            icon: icon,
            tooltip: tooltip,
            color: color,
            isEnabled: isEnabled,
            isActive: isActive,
            buttonSize: buttonSize,
            iconSize: iconSize,
            themeColor: resolvedThemeColor,
            isCompleteColorization: isCompleteColorization,
            action: action
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
    var buttonSize: CGFloat = 24
    var iconSize: CGFloat = 12
    var themeColor: Color? = nil
    var isCompleteColorization: Bool = false
    let action: () -> Void

    @State private var isHovering: Bool = false

    public var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: iconSize, weight: .regular))
                .foregroundColor(buttonColor)
                .frame(width: buttonSize, height: buttonSize)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(backgroundFill)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(borderStroke, lineWidth: 1)
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
            return themeColor ?? .accentColor
        }
        if isCompleteColorization, let tc = themeColor {
            return tc
        }
        if isHovering {
            return themeColor ?? .primary
        }
        return isCompleteColorization && themeColor != nil ? (themeColor?.opacity(0.85) ?? .secondary) : .secondary
    }

    private var backgroundFill: Color {
        let tint = themeColor ?? Color.accentColor
        if isActive {
            return tint.opacity(0.22)
        }
        if isHovering && isEnabled {
            return isCompleteColorization ? tint.opacity(0.14) : Color(NSColor.controlBackgroundColor)
        }
        return Color.clear
    }

    private var borderStroke: Color {
        let tint = themeColor ?? Color.accentColor
        if isActive {
            return tint.opacity(0.5)
        }
        if isHovering && isEnabled && isCompleteColorization {
            return tint.opacity(0.3)
        }
        return Color.clear
    }
}
