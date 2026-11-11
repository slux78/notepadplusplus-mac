import SwiftUI
import AppKit

public struct NppFindReplaceDialogView: View {
    @ObservedObject var workspace: NppWorkspace
    @Binding var isPresented: Bool

    @State private var findText: String = ""
    @State private var replaceText: String = ""

    private var filterText: String {
        get { workspace.filterText }
        nonmutating set { workspace.filterText = newValue }
    }
    private var directoryText: String {
        get { workspace.directoryText }
        nonmutating set { workspace.directoryText = newValue }
    }
    private var inSubfolders: Bool {
        get { workspace.inSubfolders }
        nonmutating set { workspace.inSubfolders = newValue }
    }
    private var inHiddenFolders: Bool {
        get { workspace.inHiddenFolders }
        nonmutating set { workspace.inHiddenFolders = newValue }
    }
    private var matchCase: Bool {
        get { workspace.matchCase }
        nonmutating set { workspace.matchCase = newValue }
    }
    private var matchWholeWord: Bool {
        get { workspace.matchWholeWord }
        nonmutating set { workspace.matchWholeWord = newValue }
    }
    private var wrapAround: Bool {
        get { workspace.wrapAround }
        nonmutating set { workspace.wrapAround = newValue }
    }
    private var backwardDirection: Bool {
        get { workspace.searchBackward }
        nonmutating set { workspace.searchBackward = newValue }
    }
    private var inSelection: Bool {
        get { workspace.searchInSelection }
        nonmutating set { workspace.searchInSelection = newValue }
    }
    private var searchMode: Int {
        get { workspace.searchMode }
        nonmutating set { workspace.searchMode = newValue }
    }
    private var dotMatchesNewline: Bool {
        get { workspace.dotMatchesNewline }
        nonmutating set { workspace.dotMatchesNewline = newValue }
    }
    private var bookmarkLine: Bool {
        get { workspace.bookmarkLine }
        nonmutating set { workspace.bookmarkLine = newValue }
    }
    private var purgeEachSearch: Bool {
        get { workspace.purgeEachSearch }
        nonmutating set { workspace.purgeEachSearch = newValue }
    }


    @AppStorage("npp_two_find_buttons_mode") private var twoFindButtonsMode: Bool = false

    @State private var statusMessage: String = ""

    public init(workspace: NppWorkspace, isPresented: Binding<Bool>) {
        self.workspace = workspace
        self._isPresented = isPresented
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header / Tabs - Pinned directly flush to the top
            HStack(spacing: 2) {
                tabButton(workspace.tr("Find"), tag: 0)
                tabButton(workspace.tr("Replace"), tag: 1)
                tabButton(workspace.tr("Find in Files"), tag: 2)
                tabButton(workspace.tr("Find in Projects"), tag: 3)
                tabButton(workspace.tr("Mark"), tag: 4)
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.top, 4)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // Dialog Main Body
            HStack(alignment: .top, spacing: 12) {
                // Left Area: Inputs & Options (width ~ 460)
                VStack(alignment: .leading, spacing: (workspace.findReplaceTab == 2 || workspace.findReplaceTab == 3) ? 4 : 8) {
                    // Find What Row
                    HStack(spacing: 8) {
                        Text(workspace.tr("Find what :"))
                            .font(.system(size: 11))
                            .frame(width: 80, alignment: .trailing)
                        TextField("", text: $findText, onCommit: { runFindNext(backward: false) })
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .font(workspace.useMonospacedFontInFindDlg ? .system(size: 12, design: .monospaced) : .system(size: 12))
                            .onChange(of: findText) { newVal in
                                workspace.findQueryText = newVal
                                workspace.lastSearchQuery = newVal
                            }
                    }

                    // Replace With Row (shown in Replace, Find in Files & Find in Projects)
                    if workspace.findReplaceTab == 1 || workspace.findReplaceTab == 2 || workspace.findReplaceTab == 3 {
                        HStack(spacing: 8) {
                            Text(workspace.tr("Replace with :"))
                                .font(.system(size: 11))
                                .frame(width: 80, alignment: .trailing)
                            TextField("", text: $replaceText, onCommit: { runFindNext(backward: false) })
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .font(workspace.useMonospacedFontInFindDlg ? .system(size: 12, design: .monospaced) : .system(size: 12))
                            Menu {
                                Button(action: {
                                    let tmp = findText
                                    findText = replaceText
                                    replaceText = tmp
                                }) {
                                    Label(workspace.tr("Swap Find with Replace"), systemImage: "arrow.up.arrow.down")
                                }
                                Button(action: {
                                    replaceText = findText
                                }) {
                                    Label(workspace.tr("Copy from Find to Replace"), systemImage: "arrow.down.right")
                                }
                                Button(action: {
                                    findText = replaceText
                                }) {
                                    Label(workspace.tr("Copy from Replace to Find"), systemImage: "arrow.up.left")
                                }
                            } label: {
                                Image(systemName: "arrow.up.arrow.down")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.primary)
                                    .frame(width: 24, height: 20)
                            }
                            .menuStyle(BorderlessButtonMenuStyle())
                            .help(workspace.tr("Swap or Copy Find and Replace strings (⇅)"))
                        }
                    }

                    // Find in Files specific rows: Filters & Directory
                    if workspace.findReplaceTab == 2 {
                        HStack(spacing: 8) {
                            Text(workspace.tr("Filters :"))
                                .font(.system(size: 11))
                                .frame(width: 80, alignment: .trailing)
                            TextField("", text: $workspace.filterText)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .font(.system(size: 12, design: .monospaced))
                        }

                        HStack(spacing: 8) {
                            Text(workspace.tr("Directory :"))
                                .font(.system(size: 11))
                                .frame(width: 80, alignment: .trailing)
                            TextField("", text: $workspace.directoryText)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .font(.system(size: 12))
                            Button("...") {
                                let panel = NSOpenPanel()
                                panel.canChooseFiles = false
                                panel.canChooseDirectories = true
                                panel.allowsMultipleSelection = false
                                if panel.runModal() == .OK, let url = panel.url {
                                    directoryText = url.path
                                }
                            }
                            .controlSize(.small)
                            Button("<<") {
                                if let path = workspace.activeDocument?.filePath {
                                    directoryText = path.deletingLastPathComponent().path
                                }
                            }
                            .controlSize(.small)
                            .help("Set Directory from current document")
                        }

                        HStack(spacing: 12) {
                            Spacer().frame(width: 80)
                            Toggle(workspace.tr("In all sub-folders"), isOn: $workspace.inSubfolders)
                                .font(.system(size: 10))
                                .toggleStyle(CheckboxToggleStyle())
                            Toggle(workspace.tr("In hidden folders"), isOn: $workspace.inHiddenFolders)
                                .font(.system(size: 10))
                                .toggleStyle(CheckboxToggleStyle())
                        }
                    }

                    // Find in Projects specific rows: Filters & Project Panel Checkboxes
                    if workspace.findReplaceTab == 3 {
                        HStack(spacing: 8) {
                            Text(workspace.tr("Filters :"))
                                .font(.system(size: 11))
                                .frame(width: 80, alignment: .trailing)
                            TextField("", text: $workspace.filterText)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .font(.system(size: 12, design: .monospaced))
                        }

                        HStack(spacing: 12) {
                            Spacer().frame(width: 80)
                            Toggle(workspace.tr("Project Panel 1"), isOn: $workspace.findInProjectsPanel1)
                                .font(.system(size: 10))
                                .toggleStyle(CheckboxToggleStyle())
                            Toggle(workspace.tr("Project Panel 2"), isOn: $workspace.findInProjectsPanel2)
                                .font(.system(size: 10))
                                .toggleStyle(CheckboxToggleStyle())
                            Toggle(workspace.tr("Project Panel 3"), isOn: $workspace.findInProjectsPanel3)
                                .font(.system(size: 10))
                                .toggleStyle(CheckboxToggleStyle())
                        }
                    }

                    // Mark specific options
                    if workspace.findReplaceTab == 4 {
                        HStack(spacing: 16) {
                            Spacer().frame(width: 80)
                            Toggle(workspace.tr("Bookmark line"), isOn: $workspace.bookmarkLine)
                                .font(.system(size: 11))
                                .toggleStyle(CheckboxToggleStyle())
                            Toggle(workspace.tr("Purge for each search"), isOn: $workspace.purgeEachSearch)
                                .font(.system(size: 11))
                                .toggleStyle(CheckboxToggleStyle())
                        }
                    }

                    // Checkboxes Row: Match case, Whole word, Wrap around
                    HStack(alignment: .top, spacing: 20) {
                        VStack(alignment: .leading, spacing: (workspace.findReplaceTab == 2 || workspace.findReplaceTab == 3) ? 4 : 6) {
                            Toggle(workspace.tr("Match whole word only"), isOn: $workspace.matchWholeWord)
                                .font(.system(size: 11))
                                .toggleStyle(CheckboxToggleStyle())
                            Toggle(workspace.tr("Match case"), isOn: $workspace.matchCase)
                                .font(.system(size: 11))
                                .toggleStyle(CheckboxToggleStyle())
                            if workspace.findReplaceTab != 2 && workspace.findReplaceTab != 3 {
                                Toggle(workspace.tr("Wrap around"), isOn: $workspace.wrapAround)
                                    .font(.system(size: 11))
                                    .toggleStyle(CheckboxToggleStyle())
                            }
                        }

                        VStack(alignment: .leading, spacing: (workspace.findReplaceTab == 2 || workspace.findReplaceTab == 3) ? 4 : 6) {
                            if workspace.findReplaceTab != 2 && workspace.findReplaceTab != 3 {
                                Toggle(workspace.tr("Backward direction"), isOn: $workspace.searchBackward)
                                    .font(.system(size: 11))
                                    .toggleStyle(CheckboxToggleStyle())
                                Toggle(workspace.tr("In selection"), isOn: $workspace.searchInSelection)
                                    .font(.system(size: 11))
                                    .toggleStyle(CheckboxToggleStyle())
                            }
                        }
                    }
                    .padding(.leading, 15)

                    // Search Mode & Transparency side-by-side (matching upstream FindReplaceDlg.rc y=131)
                    HStack(alignment: .top, spacing: 8) {
                        searchModeBox
                        transparencyBox
                    }
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)

                // Right Area: Action Buttons (width: 215, matching Notepad++ authentic layout with NO truncation)
                VStack(spacing: 6) {
                    if workspace.findReplaceTab == 0 {
                        // Find Tab Buttons
                        findNextButtonCluster
                        actionBtn(workspace.tr("Count")) { runCount() }
                        actionBtn(workspace.tr("Find All in All Opened Documents")) {
                            workspace.findAllInAllOpenedDocs(query: processedQuery(), matchCase: matchCase, wholeWord: matchWholeWord, useRegex: searchMode == 2)
                            let total = workspace.searchFileGroups.reduce(0) { $0 + $1.matches.count }
                            statusMessage = "Found \(total) matches across opened files."
                            if !workspace.findDlgAlwaysVisible {
                                closeDialog()
                            }
                        }
                        actionBtn(workspace.tr("Find All in Current Document")) {
                            workspace.findAllInCurrentDoc(query: processedQuery(), matchCase: matchCase, wholeWord: matchWholeWord, useRegex: searchMode == 2)
                            statusMessage = "Found \(workspace.searchFileGroups.first?.matches.count ?? 0) matches in current file."
                            if !workspace.findDlgAlwaysVisible {
                                closeDialog()
                            }
                        }
                    } else if workspace.findReplaceTab == 1 {
                        // Replace Tab Buttons
                        findNextButtonCluster
                        actionBtn(workspace.tr("Replace")) { runReplaceOne() }
                        actionBtn(workspace.tr("Replace All")) { runReplaceAll() }
                        actionBtn(workspace.tr("Replace All in All Opened Docs")) {
                            runReplaceAllInOpenedDocs()
                        }
                    } else if workspace.findReplaceTab == 2 {
                        // Find in Files Tab Buttons
                        actionBtn(workspace.tr("Find All"), isDefault: true) {
                            let dir = directoryText.isEmpty ? (workspace.activeDocument?.filePath?.deletingLastPathComponent().path ?? FileManager.default.currentDirectoryPath) : directoryText
                            workspace.findAllInFiles(query: processedQuery(), filter: filterText, directory: dir, subfolders: inSubfolders, matchCase: matchCase, wholeWord: matchWholeWord, useRegex: searchMode == 2)
                            let total = workspace.searchFileGroups.reduce(0) { $0 + $1.matches.count }
                            statusMessage = "Find in Files: \(total) hits in \(workspace.searchFileGroups.count) files."
                            if !workspace.findDlgAlwaysVisible {
                                closeDialog()
                            }
                        }
                        actionBtn(workspace.tr("Replace in Files")) {
                            let dir = directoryText.isEmpty ? (workspace.activeDocument?.filePath?.deletingLastPathComponent().path ?? FileManager.default.currentDirectoryPath) : directoryText
                            let res = workspace.replaceInFiles(
                                query: processedQuery(),
                                replacement: processedReplacement(),
                                filter: filterText,
                                directory: dir,
                                subfolders: inSubfolders,
                                matchCase: matchCase,
                                wholeWord: matchWholeWord,
                                useRegex: searchMode == 2
                            )
                            statusMessage = "Replace in Files: \(res.replacements) occurrences replaced in \(res.filesModified) files."
                        }
                    } else if workspace.findReplaceTab == 3 {
                        // Find in Projects Tab Buttons
                        let hasAnyPanel = workspace.findInProjectsPanel1 || workspace.findInProjectsPanel2 || workspace.findInProjectsPanel3
                        actionBtn(workspace.tr("Find All in Projects"), isDefault: true) {
                            var panels: [Int] = []
                            if workspace.findInProjectsPanel1 { panels.append(1) }
                            if workspace.findInProjectsPanel2 { panels.append(2) }
                            if workspace.findInProjectsPanel3 { panels.append(3) }
                            workspace.findAllInProjects(
                                query: processedQuery(),
                                filter: workspace.filterText.isEmpty ? "*.*" : workspace.filterText,
                                panels: panels,
                                matchCase: matchCase,
                                wholeWord: matchWholeWord,
                                useRegex: searchMode == 2
                            )
                            let total = workspace.searchFileGroups.reduce(0) { $0 + $1.matches.count }
                            statusMessage = "Find in Projects: \(total) hits in \(workspace.searchFileGroups.count) files."
                            if !workspace.findDlgAlwaysVisible {
                                closeDialog()
                            }
                        }
                        .disabled(!hasAnyPanel)

                        actionBtn(workspace.tr("Replace in Projects")) {
                            let alert = NSAlert()
                            alert.messageText = workspace.tr("Are you sure?")
                            alert.informativeText = workspace.tr("Are you sure you want to replace all occurrences in the selected projects?")
                            alert.addButton(withTitle: workspace.tr("OK"))
                            alert.addButton(withTitle: workspace.tr("Cancel"))
                            if alert.runModal() == .alertFirstButtonReturn {
                                var panels: [Int] = []
                                if workspace.findInProjectsPanel1 { panels.append(1) }
                                if workspace.findInProjectsPanel2 { panels.append(2) }
                                if workspace.findInProjectsPanel3 { panels.append(3) }
                                let res = workspace.replaceInProjects(
                                    query: processedQuery(),
                                    replacement: processedReplacement(),
                                    filter: workspace.filterText.isEmpty ? "*.*" : workspace.filterText,
                                    panels: panels,
                                    matchCase: matchCase,
                                    wholeWord: matchWholeWord,
                                    useRegex: searchMode == 2
                                )
                                statusMessage = "Replace in Projects: \(res.replacements) occurrences replaced in \(res.filesModified) files."
                            }
                        }
                        .disabled(!hasAnyPanel)
                    } else if workspace.findReplaceTab == 4 {
                        // Mark Tab Buttons
                        findNextButtonCluster
                        actionBtn(workspace.tr("Mark All")) { runMarkAll() }
                        actionBtn(workspace.tr("Clear all marks")) {
                            workspace.clearAllMarks()
                            statusMessage = "All marks cleared."
                        }
                        actionBtn(workspace.tr("Copy Marked Text")) {
                            workspace.copyMarkedText()
                            statusMessage = "Copied marked text to clipboard."
                        }
                    }

                    Spacer().frame(height: 4)

                    actionBtn(workspace.tr("Close")) {
                        closeDialog()
                    }
                }
                .frame(width: 215)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            Spacer(minLength: 0)

            Divider()

            // Status bar of dialog
            HStack {
                if !statusMessage.isEmpty {
                    Text(statusMessage)
                        .font(.system(size: 11))
                        .foregroundColor(.accentColor)
                }
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(minWidth: 730, minHeight: 360)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(NSColor.controlBackgroundColor))
        .preferredColorScheme(workspace.currentTheme.isDark ? .dark : .light)
        .onAppear {
            syncFromWorkspaceOnOpen()
        }
        .onChange(of: workspace.findInvocationCounter) { _ in
            syncFromWorkspaceOnOpen()
        }
        .onChange(of: workspace.findQueryText) { newQuery in
            if findText != newQuery {
                findText = newQuery
            }
        }
        .onExitCommand {
            closeDialog()
        }
    }

    @ViewBuilder
    private var findNextButtonCluster: some View {
        HStack(spacing: 4) {
            Toggle("", isOn: $twoFindButtonsMode)
                .labelsHidden()
                .toggleStyle(CheckboxToggleStyle())
                .help(workspace.tr("2 find buttons mode"))

            if twoFindButtonsMode {
                Button(action: { runFindNext(backward: true) }) {
                    Text("▲ \(workspace.tr("Find Next"))")
                        .font(.system(size: 11, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 3)
                }
                .buttonStyle(DefaultButtonStyle())
                .help(workspace.tr("Find Previous"))

                Button(action: { runFindNext(backward: false) }) {
                    Text("▼ \(workspace.tr("Find Next"))")
                        .font(.system(size: 11, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 3)
                }
                .buttonStyle(DefaultButtonStyle())
                .keyboardShortcut(.defaultAction)
                .help(workspace.tr("Find Next"))
            } else {
                actionBtn(workspace.tr("Find Next"), isDefault: true) { runFindNext() }
            }

            Button("") {
                runFindNext(backward: true)
            }
            .keyboardShortcut(.return, modifiers: [.shift])
            .frame(width: 0, height: 0)
            .opacity(0)
        }
    }

    private func syncFromWorkspaceOnOpen() {
        if (directoryText.isEmpty || workspace.fillFindInFilesFromActiveDoc),
           let path = workspace.activeDocument?.filePath {
            directoryText = path.deletingLastPathComponent().path
        }
        if !workspace.findQueryText.isEmpty {
            findText = workspace.findQueryText
        }
        if workspace.findReplaceTab == 1 {
            inSelection = workspace.findAutoInSelection
        }
    }

    private func closeDialog() {
        if let tv = workspace.activeTextView {
            tv.window?.makeFirstResponder(tv)
        }
        isPresented = false
        workspace.showFindReplaceDialog = false
        NppFindReplaceWindowController.shared.close()
    }

    @ViewBuilder
    private func actionBtn(_ title: String, isDefault: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity)
        }
        .frame(width: 215, height: 24)
        .keyboardShortcut(isDefault ? .defaultAction : .none)
    }

    private var searchModeBox: some View {
        GroupBox(label: Text(workspace.tr("Search Mode")).font(.system(size: 11, weight: .semibold))) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    RadioButton(tag: 0, selection: $workspace.searchMode, label: workspace.tr("Normal"))
                    RadioButton(tag: 1, selection: $workspace.searchMode, label: "Extended (\\n, \\r...)")
                }
                HStack(spacing: 6) {
                    RadioButton(tag: 2, selection: $workspace.searchMode, label: workspace.tr("Regular expression"))
                    if workspace.searchMode == 2 {
                        Toggle(workspace.tr(". matches newline"), isOn: $workspace.dotMatchesNewline)
                            .font(.system(size: 10))
                            .toggleStyle(CheckboxToggleStyle())
                    }
                }
            }
            .padding(2)
        }
    }

    private var transparencyBox: some View {
        GroupBox(label: Text(workspace.tr("Transparency")).font(.system(size: 11, weight: .semibold))) {
            VStack(alignment: .leading, spacing: 3) {
                Toggle(workspace.tr("Transparency"), isOn: $workspace.findTransparencyEnabled)
                    .font(.system(size: 11))
                    .toggleStyle(CheckboxToggleStyle())
                    .onChange(of: workspace.findTransparencyEnabled) { _ in
                        NppFindReplaceWindowController.shared.updateTransparency()
                    }

                HStack(spacing: 10) {
                    HStack(spacing: 3) {
                        Image(systemName: workspace.findTransparencyMode == 0 ? "largecircle.fill.circle" : "circle")
                            .foregroundColor(workspace.findTransparencyMode == 0 ? .accentColor : .secondary)
                        Text(workspace.tr("On losing focus"))
                            .font(.system(size: 10))
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        workspace.findTransparencyMode = 0
                        NppFindReplaceWindowController.shared.updateTransparency()
                    }

                    HStack(spacing: 3) {
                        Image(systemName: workspace.findTransparencyMode == 1 ? "largecircle.fill.circle" : "circle")
                            .foregroundColor(workspace.findTransparencyMode == 1 ? .accentColor : .secondary)
                        Text(workspace.tr("Always"))
                            .font(.system(size: 10))
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        workspace.findTransparencyMode = 1
                        NppFindReplaceWindowController.shared.updateTransparency()
                    }
                }
                .disabled(!workspace.findTransparencyEnabled)
                .opacity(workspace.findTransparencyEnabled ? 1.0 : 0.45)

                HStack(spacing: 4) {
                    Slider(
                        value: Binding<Double>(
                            get: { workspace.findTransparencyValue * 200.0 },
                            set: { workspace.findTransparencyValue = $0 / 200.0 }
                        ),
                        in: 20...200,
                        step: 5
                    ) { _ in
                        NppFindReplaceWindowController.shared.updateTransparency()
                    }
                    .frame(width: 80)
                    Text("\(Int(workspace.findTransparencyValue * 100))%")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                .disabled(!workspace.findTransparencyEnabled)
                .opacity(workspace.findTransparencyEnabled ? 1.0 : 0.45)
            }
            .padding(2)
        }
    }

    private func tabButton(_ title: String, tag: Int) -> some View {
        let isSelected = workspace.findReplaceTab == tag
        return Button(action: {
            workspace.findReplaceTab = tag
            NppFindReplaceWindowController.shared.updateTitle()
        }) {
            Text(title)
                .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? .primary : .secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isSelected ? Color(NSColor.controlBackgroundColor) : Color.clear)
                )
                .overlay(
                    Rectangle()
                        .fill(isSelected ? Color.accentColor : Color.clear)
                        .frame(height: 2),
                    alignment: .bottom
                )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func processedQuery() -> String {
        var q = findText
        if searchMode == 1 { // Extended (searching.md:120-135)
            q = NppWorkspace.expandExtendedEscapes(q)
        }
        return q
    }

    private func processedReplacement() -> String {
        var r = replaceText
        if searchMode == 1 { // Extended (searching.md:120-135)
            r = NppWorkspace.expandExtendedEscapes(r)
        }
        return r
    }

    private func buildSearchRegex(for query: String) -> NSRegularExpression? {
        return workspace.buildSearchRegex(for: query)
    }

    private func runFindNext(backward: Bool? = nil) {
        guard let tv = workspace.activeTextView, !findText.isEmpty else { return }
        let effectiveBackward = backward ?? backwardDirection
        let query = processedQuery()
        let content = tv.string
        let currentRange = tv.selectedRange()
        let startLocation = effectiveBackward ? currentRange.location : NSMaxRange(currentRange)

        let foundRange = workspace.findRange(in: content, query: query, forward: !effectiveBackward, startLocation: startLocation)

        if let range = foundRange {
            tv.setSelectedRange(range)
            tv.scrollRangeToVisible(range)
            workspace.activeDocument?.cursorPos = range.location
            workspace.activeDocument?.selectionLength = range.length
            workspace.lastSearchQuery = query
            statusMessage = "Found match at position \(range.location)."
        } else {
            statusMessage = "Find: Can't find the text \"\(findText)\""
            NSSound.beep()
        }
    }

    private func runCount() {
        guard let tv = workspace.activeTextView, !findText.isEmpty else { return }
        let query = processedQuery()
        let content = tv.string
        let fullLength = (content as NSString).length
        let currentSel = tv.selectedRange()
        let targetRange = (inSelection && currentSel.length > 0 && NSMaxRange(currentSel) <= fullLength)
            ? currentSel
            : NSRange(location: 0, length: fullLength)
        var count = 0

        if searchMode == 2 || matchWholeWord {
            if let regex = buildSearchRegex(for: query) {
                count = regex.numberOfMatches(in: content, range: targetRange)
            }
        } else {
            var searchRange = targetRange
            let endLocation = NSMaxRange(targetRange)
            var options: NSString.CompareOptions = []
            if !matchCase { options.insert(.caseInsensitive) }
            while searchRange.location < endLocation {
                let r = (content as NSString).range(of: query, options: options, range: searchRange)
                if r.location != NSNotFound {
                    count += 1
                    searchRange.location = NSMaxRange(r)
                    searchRange.length = max(0, endLocation - searchRange.location)
                } else {
                    break
                }
            }
        }
        statusMessage = "Count: \(count) match\(count == 1 ? "" : "es")."
    }

    private func runReplaceOne() {
        guard let tv = workspace.activeTextView,
              let doc = workspace.activeDocument,
              !(doc.isReadOnly || workspace.isAllDocumentsReadOnly),
              tv.isEditable,
              !findText.isEmpty else { return }
        let selected = tv.selectedRange()
        let selectedText = (tv.string as NSString).substring(with: selected)
        let query = processedQuery()
        let replacement = processedReplacement()

        let matches: Bool
        if searchMode == 2 || matchWholeWord {
            if let regex = buildSearchRegex(for: query) {
                let fullMatch = regex.firstMatch(in: tv.string, options: [], range: selected)
                matches = (fullMatch?.range == selected && selected.length > 0)
            } else {
                matches = false
            }
        } else {
            matches = matchCase ? (selectedText == query) : (selectedText.caseInsensitiveCompare(query) == .orderedSame)
        }

        if matches {
            var finalReplacement = replacement
            if searchMode == 2 {
                if let regex = buildSearchRegex(for: query),
                   let fullMatch = regex.firstMatch(in: tv.string, options: [], range: selected) {
                    let normalizedTemplate = NppWorkspace.normalizeRegexReplacementTemplate(replacement)
                    finalReplacement = regex.replacementString(for: fullMatch, in: tv.string, offset: 0, template: normalizedTemplate)
                }
            }
            tv.insertText(finalReplacement, replacementRange: selected)
            doc.content = tv.string
            doc.isDirty = true
            statusMessage = "Replaced 1 occurrence."
            if !workspace.replaceAndStop {
                runFindNext()
            }
        } else {
            runFindNext()
        }
    }

    private func runReplaceAll() {
        guard let tv = workspace.activeTextView,
              let doc = workspace.activeDocument,
              !(doc.isReadOnly || workspace.isAllDocumentsReadOnly),
              tv.isEditable,
              !findText.isEmpty else { return }
        let query = processedQuery()
        let replacement = processedReplacement()
        var content = tv.string
        let fullLength = (content as NSString).length
        let currentSel = tv.selectedRange()
        let targetRange: NSRange = (inSelection && currentSel.length > 0 && NSMaxRange(currentSel) <= fullLength)
            ? currentSel
            : NSRange(location: 0, length: fullLength)
        var count = 0

        if searchMode == 2 || matchWholeWord {
            if let regex = buildSearchRegex(for: query) {
                count = regex.numberOfMatches(in: content, range: targetRange)
                let template = (searchMode == 2) ? NppWorkspace.normalizeRegexReplacementTemplate(replacement) : NSRegularExpression.escapedTemplate(for: replacement)
                content = regex.stringByReplacingMatches(in: content, range: targetRange, withTemplate: template)
            }
        } else {
            var searchRange = targetRange
            let endLocation = NSMaxRange(targetRange)
            var options: NSString.CompareOptions = []
            if !matchCase { options.insert(.caseInsensitive) }
            var occurrences: [NSRange] = []
            while searchRange.location < endLocation {
                let r = (content as NSString).range(of: query, options: options, range: searchRange)
                if r.location != NSNotFound {
                    occurrences.append(r)
                    searchRange.location = NSMaxRange(r)
                    searchRange.length = max(0, endLocation - searchRange.location)
                } else {
                    break
                }
            }
            count = occurrences.count
            for r in occurrences.reversed() {
                content = (content as NSString).replacingCharacters(in: r, with: replacement)
            }
        }

        let fullRange = NSRange(location: 0, length: (tv.string as NSString).length)
        if tv.shouldChangeText(in: fullRange, replacementString: content) {
            tv.undoManager?.beginUndoGrouping()
            tv.replaceCharacters(in: fullRange, with: content)
            tv.didChangeText()
            tv.undoManager?.endUndoGrouping()
            doc.content = tv.string
            doc.isDirty = true
        } else {
            tv.string = content
            doc.content = content
            doc.isDirty = true
        }
        statusMessage = "Replace All: \(count) occurrence\(count == 1 ? "" : "s") were replaced."
    }

    private func runReplaceAllInOpenedDocs() {
        guard !workspace.isAllDocumentsReadOnly, !findText.isEmpty else { return }
        if workspace.confirmReplaceAllInAllOpenedDocs && !workspace.isTestRunning && !CommandLine.arguments.contains("--run-tests") {
            let alert = NSAlert()
            alert.messageText = workspace.tr("Replace All in All Opened Documents")
            alert.informativeText = workspace.tr("Are you sure you want to replace all occurrences in all opened documents?")
            alert.addButton(withTitle: workspace.tr("Yes"))
            alert.addButton(withTitle: workspace.tr("No"))
            if alert.runModal() != .alertFirstButtonReturn {
                return
            }
        }
        let query = processedQuery()
        let replacement = processedReplacement()
        var totalCount = 0
        for doc in workspace.documents where !doc.isReadOnly {
            var content = doc.content
            let fullRange = NSRange(location: 0, length: (content as NSString).length)
            if let regex = buildSearchRegex(for: query) {
                let count = regex.numberOfMatches(in: content, range: fullRange)
                if count > 0 {
                    totalCount += count
                    let template = (searchMode == 2) ? NppWorkspace.normalizeRegexReplacementTemplate(replacement) : NSRegularExpression.escapedTemplate(for: replacement)
                    content = regex.stringByReplacingMatches(in: content, range: fullRange, withTemplate: template)
                    doc.content = content
                    doc.isDirty = true
                }
            }
        }
        if let active = workspace.activeDocument, let tv = workspace.activeTextView {
            tv.string = active.content
        }
        statusMessage = "Replace All in All Opened Docs: \(totalCount) occurrence\(totalCount == 1 ? "" : "s") replaced."
    }

    private func runMarkAll() {
        guard !findText.isEmpty else { return }
        let currentSel = workspace.activeTextView?.selectedRange()
        let contentLen = (workspace.activeDocument?.content as NSString?)?.length ?? 0
        let targetRange = (inSelection && (currentSel?.length ?? 0) > 0 && NSMaxRange(currentSel!) <= contentLen) ? currentSel : nil
        let count = workspace.markAll(
            query: processedQuery(),
            matchCase: matchCase,
            wholeWord: matchWholeWord,
            useRegex: searchMode == 2,
            bookmarkLine: bookmarkLine,
            purgeExisting: purgeEachSearch,
            inRange: targetRange
        )
        statusMessage = "Mark: \(count) match\(count == 1 ? "" : "es") marked."
    }
}

fileprivate struct RadioButton: View {
    let tag: Int
    @Binding var selection: Int
    let label: String

    var body: some View {
        Button(action: {
            selection = tag
        }) {
            HStack(spacing: 4) {
                Image(systemName: selection == tag ? "largecircle.fill.circle" : "circle")
                    .foregroundColor(selection == tag ? .accentColor : .secondary)
                Text(label)
                    .font(.system(size: 11))
                    .foregroundColor(.primary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

