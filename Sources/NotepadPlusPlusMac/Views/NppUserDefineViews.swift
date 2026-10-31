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
        .onAppear {
            syncFieldsFromSelectedLanguage()
        }
        .onChange(of: selectedLanguageIndex) { _ in
            syncFieldsFromSelectedLanguage()
        }
        .onChange(of: currentExtensions) { val in
            if selectedLanguageIndex > 0 && selectedLanguageIndex - 1 < workspace.userDefinedLanguages.count {
                workspace.userDefinedLanguages[selectedLanguageIndex - 1].extensions = val
                workspace.saveUserDefinedLanguages()
            }
        }
        .onChange(of: ignoreCase) { val in
            if selectedLanguageIndex > 0 && selectedLanguageIndex - 1 < workspace.userDefinedLanguages.count {
                workspace.userDefinedLanguages[selectedLanguageIndex - 1].ignoreCase = val
                workspace.saveUserDefinedLanguages()
            }
        }
        .onChange(of: folderOpenKeyword) { updateKeyword("Folders in code1, open", value: $0) }
        .onChange(of: folderCloseKeyword) { updateKeyword("Folders in code1, close", value: $0) }
        .onChange(of: group1Keywords) { updateKeyword("Keywords1", value: $0) }
        .onChange(of: group2Keywords) { updateKeyword("Keywords2", value: $0) }
        .onChange(of: operatorsString) { updateKeyword("Operators1", value: $0) }
        .onChange(of: lineCommentPrefix) { updateCommentToken(0, value: $0) }
        .onChange(of: blockCommentOpen) { updateCommentToken(3, value: $0) }
        .onChange(of: blockCommentClose) { updateCommentToken(4, value: $0) }
    }

    private func updateKeyword(_ name: String, value: String) {
        guard selectedLanguageIndex > 0, selectedLanguageIndex - 1 < workspace.userDefinedLanguages.count else { return }
        workspace.userDefinedLanguages[selectedLanguageIndex - 1].keywordLists[name] = value
        workspace.saveUserDefinedLanguages()
    }

    private func keywordBinding(_ name: String) -> Binding<String> {
        Binding(
            get: {
                guard selectedLanguageIndex > 0,
                      selectedLanguageIndex - 1 < workspace.userDefinedLanguages.count else { return "" }
                return workspace.userDefinedLanguages[selectedLanguageIndex - 1].keywordLists[name] ?? ""
            },
            set: { updateKeyword(name, value: $0) }
        )
    }

    private func prefixBinding(_ name: String) -> Binding<Bool> {
        Binding(
            get: {
                guard selectedLanguageIndex > 0,
                      selectedLanguageIndex - 1 < workspace.userDefinedLanguages.count else { return false }
                return workspace.userDefinedLanguages[selectedLanguageIndex - 1].prefixModes[name] == true
            },
            set: { value in
                guard selectedLanguageIndex > 0,
                      selectedLanguageIndex - 1 < workspace.userDefinedLanguages.count else { return }
                workspace.userDefinedLanguages[selectedLanguageIndex - 1].prefixModes[name] = value
                workspace.saveUserDefinedLanguages()
            }
        )
    }

    private var decimalSeparatorBinding: Binding<Int> {
        Binding(
            get: {
                guard selectedLanguageIndex > 0,
                      selectedLanguageIndex - 1 < workspace.userDefinedLanguages.count else { return 0 }
                return workspace.userDefinedLanguages[selectedLanguageIndex - 1].decimalSeparator
            },
            set: { value in
                guard selectedLanguageIndex > 0,
                      selectedLanguageIndex - 1 < workspace.userDefinedLanguages.count else { return }
                workspace.userDefinedLanguages[selectedLanguageIndex - 1].decimalSeparator = value
                workspace.saveUserDefinedLanguages()
            }
        )
    }

    private func updateCommentToken(_ number: Int, value: String) {
        guard selectedLanguageIndex > 0, selectedLanguageIndex - 1 < workspace.userDefinedLanguages.count else { return }
        let index = selectedLanguageIndex - 1
        let existing = workspace.userDefinedLanguages[index].keywordLists["Comments"] ?? ""
        workspace.userDefinedLanguages[index].keywordLists["Comments"] =
            NppUDLCodec.replacingCommentToken(number, value: value, in: existing)
        workspace.saveUserDefinedLanguages()
    }

    private func syncFieldsFromSelectedLanguage() {
        if selectedLanguageIndex > 0 && selectedLanguageIndex - 1 < workspace.userDefinedLanguages.count {
            let lang = workspace.userDefinedLanguages[selectedLanguageIndex - 1]
            currentLanguageName = lang.name
            currentExtensions = lang.extensions
            ignoreCase = lang.ignoreCase
            folderOpenKeyword = lang.keywordLists["Folders in code1, open"] ?? ""
            folderCloseKeyword = lang.keywordLists["Folders in code1, close"] ?? ""
            group1Keywords = lang.keywordLists["Keywords1"] ?? ""
            group2Keywords = lang.keywordLists["Keywords2"] ?? ""
            operatorsString = lang.keywordLists["Operators1"] ?? ""
            let comments = lang.keywordLists["Comments"] ?? ""
            lineCommentPrefix = NppUDLCodec.commentToken(0, in: comments)
            blockCommentOpen = NppUDLCodec.commentToken(3, in: comments)
            blockCommentClose = NppUDLCodec.commentToken(4, in: comments)
        } else {
            currentLanguageName = "User-Defined"
            currentExtensions = ""
            ignoreCase = true
            folderOpenKeyword = ""
            folderCloseKeyword = ""
            group1Keywords = ""
            group2Keywords = ""
            operatorsString = ""
            lineCommentPrefix = "//"
            blockCommentOpen = "/*"
            blockCommentClose = "*/"
        }
    }

    private var folderAndDefaultTab: some View {
        ScrollView {
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
            ForEach(["Folders in code1, middle", "Folders in code2, open", "Folders in code2, middle",
                     "Folders in code2, close", "Folders in comment, open", "Folders in comment, middle",
                     "Folders in comment, close"], id: \.self) { name in
                HStack {
                    Text(name).frame(width: 190, alignment: .leading)
                    TextField("", text: keywordBinding(name))
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                .font(.system(size: 10))
            }
          }
        }
    }

    private var keywordsListTab: some View {
        ScrollView {
          VStack(alignment: .leading, spacing: 8) {
            Text(workspace.tr("1st Group Keywords:")).font(.system(size: 11, weight: .semibold))
            TextField("if else for while return func class", text: $group1Keywords)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            Toggle("Prefix Mode", isOn: prefixBinding("Keywords1"))
                .disabled(selectedLanguageIndex == 0)

            Text(workspace.tr("2nd Group Keywords:")).font(.system(size: 11, weight: .semibold))
            TextField("true false nil null undefined", text: $group2Keywords)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            Toggle("Prefix Mode", isOn: prefixBinding("Keywords2"))
                .disabled(selectedLanguageIndex == 0)
            ForEach(3...8, id: \.self) { group in
                Text("\(group)th Group Keywords:").font(.system(size: 11, weight: .semibold))
                TextField("", text: keywordBinding("Keywords\(group)"))
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                Toggle("Prefix Mode", isOn: prefixBinding("Keywords\(group)"))
                    .disabled(selectedLanguageIndex == 0)
            }
          }
        }
    }

    private var commentAndNumberTab: some View {
        ScrollView {
          VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Decimal separator:").font(.system(size: 10))
                Picker("", selection: decimalSeparatorBinding) {
                    Text("Dot").tag(0)
                    Text("Comma").tag(1)
                    Text("Both").tag(2)
                }
                .frame(width: 150)
                .disabled(selectedLanguageIndex == 0)
            }
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
            ForEach(["Numbers, prefix1", "Numbers, prefix2", "Numbers, extras1", "Numbers, extras2",
                     "Numbers, suffix1", "Numbers, suffix2", "Numbers, range"], id: \.self) { name in
                HStack {
                    Text(name).frame(width: 130, alignment: .leading)
                    TextField("", text: keywordBinding(name))
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                .font(.system(size: 10))
            }
          }
        }
    }

    private var operatorsTab: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Operators 1:").font(.system(size: 11, weight: .semibold))
            TextField("+ - * / = < > ! & | % ~ ^", text: $operatorsString)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            Text("Operators 2:").font(.system(size: 11, weight: .semibold))
            TextField("", text: keywordBinding("Operators2"))
                .textFieldStyle(RoundedBorderTextFieldStyle())
            Text("Delimiters (UDL XML rule format):").font(.system(size: 11, weight: .semibold))
            TextField("", text: keywordBinding("Delimiters"))
                .textFieldStyle(RoundedBorderTextFieldStyle())
            Spacer()
        }
    }

    private func createNewLanguage() {
        let count = workspace.userDefinedLanguages.count + 1
        let newLang = NppUserDefineLanguage(name: "User Language \(count)", extensions: "udl\(count)",
                                            ignoreCase: ignoreCase, keywordLists: currentKeywordLists())
        workspace.userDefinedLanguages.append(newLang)
        workspace.includeSeparateUserDefinedLanguage(named: newLang.name)
        selectedLanguageIndex = workspace.userDefinedLanguages.count
        workspace.saveUserDefinedLanguages()
        (NSApp.delegate as? AppDelegate)?.setupMenuBar()
    }

    private func saveAsNewLanguage() {
        let name = "Copy of \(selectedLanguageIndex == 0 ? "User-Defined" : workspace.userDefinedLanguages[selectedLanguageIndex - 1].name)"
        var newLang = selectedLanguageIndex > 0 && selectedLanguageIndex - 1 < workspace.userDefinedLanguages.count
            ? workspace.userDefinedLanguages[selectedLanguageIndex - 1]
            : NppUserDefineLanguage(name: name, extensions: currentExtensions,
                                    ignoreCase: ignoreCase, keywordLists: currentKeywordLists())
        newLang.id = UUID()
        newLang.name = name
        workspace.userDefinedLanguages.append(newLang)
        workspace.includeSeparateUserDefinedLanguage(named: newLang.name)
        selectedLanguageIndex = workspace.userDefinedLanguages.count
        workspace.saveUserDefinedLanguages()
        (NSApp.delegate as? AppDelegate)?.setupMenuBar()
    }

    private func currentKeywordLists() -> [String: String] {
        var comments = ""
        comments = NppUDLCodec.replacingCommentToken(0, value: lineCommentPrefix, in: comments)
        comments = NppUDLCodec.replacingCommentToken(3, value: blockCommentOpen, in: comments)
        comments = NppUDLCodec.replacingCommentToken(4, value: blockCommentClose, in: comments)
        return [
            "Folders in code1, open": folderOpenKeyword,
            "Folders in code1, close": folderCloseKeyword,
            "Keywords1": group1Keywords,
            "Keywords2": group2Keywords,
            "Operators1": operatorsString,
            "Comments": comments
        ]
    }

    private func renameLanguage() {
        guard selectedLanguageIndex > 0, selectedLanguageIndex - 1 < workspace.userDefinedLanguages.count else { return }
        let idx = selectedLanguageIndex - 1
        let alert = NSAlert()
        alert.messageText = workspace.tr("Rename")
        alert.addButton(withTitle: workspace.tr("OK"))
        alert.addButton(withTitle: workspace.tr("Cancel"))
        let field = NSTextField(string: workspace.userDefinedLanguages[idx].name)
        field.frame = NSRect(x: 0, y: 0, width: 260, height: 24)
        alert.accessoryView = field
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let newName = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !newName.isEmpty else { return }
        workspace.excludeSeparateUserDefinedLanguage(named: workspace.userDefinedLanguages[idx].name)
        workspace.includeSeparateUserDefinedLanguage(named: newName)
        workspace.userDefinedLanguages[idx].name = newName
        workspace.saveUserDefinedLanguages()
        (NSApp.delegate as? AppDelegate)?.setupMenuBar()
    }

    private func removeLanguage() {
        guard selectedLanguageIndex > 0, selectedLanguageIndex - 1 < workspace.userDefinedLanguages.count else { return }
        workspace.excludeSeparateUserDefinedLanguage(named: workspace.userDefinedLanguages[selectedLanguageIndex - 1].name)
        workspace.userDefinedLanguages.remove(at: selectedLanguageIndex - 1)
        selectedLanguageIndex = 0
        workspace.saveUserDefinedLanguages()
        (NSApp.delegate as? AppDelegate)?.setupMenuBar()
    }

    private func importLanguage() {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = []
        openPanel.allowsMultipleSelection = false
        if openPanel.runModal() == .OK, let url = openPanel.url {
            do {
                let data = try Data(contentsOf: url)
                let languages = try NppUDLCodec.decode(data)
                for language in languages { workspace.includeSeparateUserDefinedLanguage(named: language.name) }
                workspace.userDefinedLanguages.append(contentsOf: languages)
                selectedLanguageIndex = workspace.userDefinedLanguages.count
                workspace.saveUserDefinedLanguages()
                (NSApp.delegate as? AppDelegate)?.setupMenuBar()
            } catch {
                showFileError(error)
            }
        }
    }

    private func exportLanguage() {
        let savePanel = NSSavePanel()
        savePanel.nameFieldStringValue = "\(selectedLanguageIndex == 0 ? "UserDefined" : workspace.userDefinedLanguages[selectedLanguageIndex - 1].name).xml"
        if savePanel.runModal() == .OK, let url = savePanel.url {
            let language = selectedLanguageIndex > 0 && selectedLanguageIndex - 1 < workspace.userDefinedLanguages.count
                ? workspace.userDefinedLanguages[selectedLanguageIndex - 1]
                : NppUserDefineLanguage(name: "User Defined Language", extensions: currentExtensions,
                                        ignoreCase: ignoreCase, keywordLists: currentKeywordLists())
            do {
                let data = try NppUDLCodec.encode(language)
                try data.write(to: url, options: .atomic)
            } catch {
                showFileError(error)
            }
        }
    }

    private func showFileError(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = workspace.tr("User Defined Language")
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.runModal()
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
