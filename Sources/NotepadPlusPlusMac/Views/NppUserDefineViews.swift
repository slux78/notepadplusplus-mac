import AppKit
import SwiftUI

// MARK: - User Defined Language Dialog View (Notepad++ UserDefineDialog parity)
public struct NppUserDefineDialogView: View {
    @ObservedObject public var workspace: NppWorkspace
    public let onClose: () -> Void

    @State private var selectedLanguageIndex: Int = 0
    @State private var currentLanguageName: String = "User-Defined"
    @State private var currentExtensions: String = ""
    @State private var ignoreCase: Bool = true
    @State private var selectedTab: Int = 0

    // Tab keyword fields
    @State private var folderOpenKeyword: String = ""
    @State private var folderCloseKeyword: String = ""
    @State private var group1Keywords: String = ""
    @State private var group2Keywords: String = ""
    @State private var lineCommentPrefix: String = "//"
    @State private var blockCommentOpen: String = "/*"
    @State private var blockCommentClose: String = "*/"
    @State private var operatorsString: String = "+ - * / = < > ! & |"

    public init(workspace: NppWorkspace, onClose: @escaping () -> Void) {
        self.workspace = workspace
        self.onClose = onClose
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header: User Language Picker & Management Buttons
            HStack(spacing: 8) {
                Text(workspace.tr("User language:"))
                    .font(.system(size: 11, weight: .semibold))

                Picker("", selection: $selectedLanguageIndex) {
                    Text("User-Defined").tag(0)
                    ForEach(workspace.userDefinedLanguages.indices, id: \.self) { idx in
                        Text(workspace.userDefinedLanguages[idx].name).tag(idx + 1)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .frame(width: 140)

                Button(workspace.tr("Create New...")) {
                    createNewLanguage()
                }
                .font(.system(size: 11))

                Button(workspace.tr("Save As...")) {
                    saveAsNewLanguage()
                }
                .font(.system(size: 11))

                Button(workspace.tr("Rename")) {
                    renameLanguage()
                }
                .font(.system(size: 11))
                .disabled(selectedLanguageIndex == 0 || workspace.userDefinedLanguages.isEmpty)

                Button(workspace.tr("Remove")) {
                    removeLanguage()
                }
                .font(.system(size: 11))
                .disabled(selectedLanguageIndex == 0 || workspace.userDefinedLanguages.isEmpty)

                Spacer()

                Button(workspace.tr("Import...")) {
                    importLanguage()
                }
                .font(.system(size: 11))

                Button(workspace.tr("Export...")) {
                    exportLanguage()
                }
                .font(.system(size: 11))
            }

            // Options: Ignore case & Extensions
            HStack(spacing: 16) {
                Toggle(workspace.tr("Ignore case"), isOn: $ignoreCase)
                    .font(.system(size: 11))
                    .toggleStyle(CheckboxToggleStyle())

                HStack(spacing: 4) {
                    Text(workspace.tr("Ext. :"))
                        .font(.system(size: 11))
                    TextField("txt udl", text: $currentExtensions)
                        .font(.system(size: 11, design: .monospaced))
                        .frame(width: 140)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
            }

            Divider()

            // Sub-tabs matching Notepad++ UserDefineDialog
            Picker("", selection: $selectedTab) {
                Text("Folder & Default").tag(0)
                Text("Keywords Lists").tag(1)
                Text("Comment & Number").tag(2)
                Text("Operators & Delimiters").tag(3)
            }
            .pickerStyle(SegmentedPickerStyle())

            Group {
                switch selectedTab {
                case 0:
                    folderAndDefaultTab
                case 1:
                    keywordsListTab
                case 2:
                    commentAndNumberTab
                default:
                    operatorsTab
                }
            }
            .frame(minHeight: 180)

            Divider()

            // Bottom bar
            HStack {
                Spacer()
                Button(workspace.tr("Close")) {
                    onClose()
                }
                .keyboardShortcut(.cancelAction)
            }
        }
        .padding(14)
        .frame(minWidth: 560, minHeight: 380)
    }

    private var folderAndDefaultTab: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(workspace.tr("Folding in code:"))
                .font(.system(size: 11, weight: .semibold))
            HStack(spacing: 12) {
                VStack(alignment: .leading) {
                    Text(workspace.tr("Open :")).font(.system(size: 10))
                    TextField("{ ( begin", text: $folderOpenKeyword)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                VStack(alignment: .leading) {
                    Text(workspace.tr("Close :")).font(.system(size: 10))
                    TextField("} ) end", text: $folderCloseKeyword)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
            }
            Spacer()
        }
    }

    private var keywordsListTab: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(workspace.tr("1st Group Keywords:")).font(.system(size: 11, weight: .semibold))
            TextField("if else for while return func class", text: $group1Keywords)
                .textFieldStyle(RoundedBorderTextFieldStyle())

            Text(workspace.tr("2nd Group Keywords:")).font(.system(size: 11, weight: .semibold))
            TextField("true false nil null undefined", text: $group2Keywords)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            Spacer()
        }
    }

    private var commentAndNumberTab: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                VStack(alignment: .leading) {
                    Text(workspace.tr("Line comment:")).font(.system(size: 10))
                    TextField("// #", text: $lineCommentPrefix)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                VStack(alignment: .leading) {
                    Text(workspace.tr("Comment open:")).font(.system(size: 10))
                    TextField("/* <!--", text: $blockCommentOpen)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                VStack(alignment: .leading) {
                    Text(workspace.tr("Comment close:")).font(.system(size: 10))
                    TextField("*/ -->", text: $blockCommentClose)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
            }
            Spacer()
        }
    }

    private var operatorsTab: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(workspace.tr("Operators:")).font(.system(size: 11, weight: .semibold))
            TextField("+ - * / = < > ! & | % ~ ^", text: $operatorsString)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            Spacer()
        }
    }

    private func createNewLanguage() {
        let count = workspace.userDefinedLanguages.count + 1
        let newLang = NppUserDefineLanguage(name: "User Language \(count)", extensions: "udl\(count)", ignoreCase: true)
        workspace.userDefinedLanguages.append(newLang)
        selectedLanguageIndex = workspace.userDefinedLanguages.count
    }

    private func saveAsNewLanguage() {
        let name = "Copy of \(selectedLanguageIndex == 0 ? "User-Defined" : workspace.userDefinedLanguages[selectedLanguageIndex - 1].name)"
        let newLang = NppUserDefineLanguage(name: name, extensions: currentExtensions, ignoreCase: ignoreCase)
        workspace.userDefinedLanguages.append(newLang)
        selectedLanguageIndex = workspace.userDefinedLanguages.count
    }

    private func renameLanguage() {
        guard selectedLanguageIndex > 0, selectedLanguageIndex - 1 < workspace.userDefinedLanguages.count else { return }
        let idx = selectedLanguageIndex - 1
        workspace.userDefinedLanguages[idx].name += " (renamed)"
    }

    private func removeLanguage() {
        guard selectedLanguageIndex > 0, selectedLanguageIndex - 1 < workspace.userDefinedLanguages.count else { return }
        workspace.userDefinedLanguages.remove(at: selectedLanguageIndex - 1)
        selectedLanguageIndex = 0
    }

    private func importLanguage() {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = []
        openPanel.allowsMultipleSelection = false
        if openPanel.runModal() == .OK, let url = openPanel.url {
            let name = url.deletingPathExtension().lastPathComponent
            let lang = NppUserDefineLanguage(name: name, extensions: url.pathExtension, ignoreCase: true)
            workspace.userDefinedLanguages.append(lang)
            selectedLanguageIndex = workspace.userDefinedLanguages.count
        }
    }

    private func exportLanguage() {
        let savePanel = NSSavePanel()
        savePanel.nameFieldStringValue = "\(selectedLanguageIndex == 0 ? "UserDefined" : workspace.userDefinedLanguages[selectedLanguageIndex - 1].name).xml"
        if savePanel.runModal() == .OK, let url = savePanel.url {
            let dummyXML = "<NotepadPlus><UserLang name=\"\(savePanel.nameFieldStringValue)\" ext=\"\(currentExtensions)\"/></NotepadPlus>"
            try? dummyXML.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}

// MARK: - User Defined Language Window Controller
public final class NppUserDefineWindowController: NSObject, NSWindowDelegate {
    public static let shared = NppUserDefineWindowController()
    public private(set) var panel: NSPanel?
    private weak var workspace: NppWorkspace?

    private override init() {
        super.init()
    }

    public func show(workspace: NppWorkspace) {
        self.workspace = workspace
        workspace.showUserDefineDialog = true

        if let existing = panel {
            existing.makeKeyAndOrderFront(nil)
            return
        }

        let newPanel = NSPanel(
            contentRect: NSRect(x: 200, y: 260, width: 580, height: 420),
            styleMask: [.titled, .closable, .resizable, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        newPanel.isFloatingPanel = true
        newPanel.level = .floating
        newPanel.hidesOnDeactivate = true
        newPanel.isReleasedWhenClosed = false
        newPanel.delegate = self
        newPanel.title = "User Defined Language v2.1"

        let hostingView = NSHostingView(
            rootView: NppUserDefineDialogView(
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
        workspace?.showUserDefineDialog = false
    }

    public func windowWillClose(_ notification: Notification) {
        workspace?.showUserDefineDialog = false
        panel = nil
    }
}
