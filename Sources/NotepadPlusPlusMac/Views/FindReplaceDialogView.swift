import SwiftUI
import AppKit

public struct NppFindReplaceDialogView: View {
    @ObservedObject var workspace: NppWorkspace
    @Binding var isPresented: Bool

    @State private var findText: String = ""
    @State private var replaceText: String = ""
    @State private var filterText: String = "*.*"
    @State private var directoryText: String = ""
    @State private var inSubfolders: Bool = true
    @State private var inHiddenFolders: Bool = false

    @State private var matchCase: Bool = false
    @State private var matchWholeWord: Bool = false
    @State private var wrapAround: Bool = true
    @State private var backwardDirection: Bool = false
    @State private var inSelection: Bool = false

    @State private var searchMode: Int = 0 // 0: Normal, 1: Extended, 2: RegEx
    @State private var dotMatchesNewline: Bool = false

    // Mark tab options
    @State private var bookmarkLine: Bool = true
    @State private var purgeEachSearch: Bool = false

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
                tabButton(workspace.tr("Mark"), tag: 3)
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.top, 4)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // Dialog Main Body
            HStack(alignment: .top, spacing: 12) {
                // Left Area: Inputs & Options (width ~ 460)
                VStack(alignment: .leading, spacing: workspace.findReplaceTab == 2 ? 4 : 8) {
                    // Find What Row
                    HStack(spacing: 8) {
                        Text(workspace.tr("Find what :"))
                            .font(.system(size: 11))
                            .frame(width: 80, alignment: .trailing)
                        TextField("", text: $findText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .font(.system(size: 12, design: .monospaced))
                            .onChange(of: findText) { newVal in
                                workspace.findQueryText = newVal
                                workspace.lastSearchQuery = newVal
                            }
                    }

                    // Replace With Row (shown in Replace & Find in Files)
                    if workspace.findReplaceTab == 1 || workspace.findReplaceTab == 2 {
                        HStack(spacing: 8) {
                            Text(workspace.tr("Replace with :"))
                                .font(.system(size: 11))
                                .frame(width: 80, alignment: .trailing)
                            TextField("", text: $replaceText)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .font(.system(size: 12, design: .monospaced))
                            Button(action: {
                                let tmp = findText
                                findText = replaceText
                                replaceText = tmp
                            }) {
                                Image(systemName: "arrow.up.arrow.down")
                                    .font(.system(size: 10))
                            }
                            .help("Swap Find and Replace strings")
                        }
                    }

                    // Find in Files specific rows: Filters & Directory
                    if workspace.findReplaceTab == 2 {
                        HStack(spacing: 8) {
                            Text(workspace.tr("Filters :"))
                                .font(.system(size: 11))
                                .frame(width: 80, alignment: .trailing)
                            TextField("", text: $filterText)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .font(.system(size: 12, design: .monospaced))
                        }

                        HStack(spacing: 8) {
                            Text(workspace.tr("Directory :"))
                                .font(.system(size: 11))
                                .frame(width: 80, alignment: .trailing)
                            TextField("", text: $directoryText)
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
                            Toggle(workspace.tr("In all sub-folders"), isOn: $inSubfolders)
                                .font(.system(size: 10))
                                .toggleStyle(CheckboxToggleStyle())
                            Toggle(workspace.tr("In hidden folders"), isOn: $inHiddenFolders)
                                .font(.system(size: 10))
                                .toggleStyle(CheckboxToggleStyle())
                        }
                    }

                    // Mark specific options
                    if workspace.findReplaceTab == 3 {
                        HStack(spacing: 16) {
                            Spacer().frame(width: 80)
                            Toggle(workspace.tr("Bookmark line"), isOn: $bookmarkLine)
                                .font(.system(size: 11))
                                .toggleStyle(CheckboxToggleStyle())
                            Toggle(workspace.tr("Purge for each search"), isOn: $purgeEachSearch)
                                .font(.system(size: 11))
                                .toggleStyle(CheckboxToggleStyle())
                        }
                    }

                    // Checkboxes Row: Match case, Whole word, Wrap around
                    HStack(alignment: .top, spacing: 20) {
                        VStack(alignment: .leading, spacing: workspace.findReplaceTab == 2 ? 4 : 6) {
                            Toggle(workspace.tr("Match whole word only"), isOn: $matchWholeWord)
                                .font(.system(size: 11))
                                .toggleStyle(CheckboxToggleStyle())
                            Toggle(workspace.tr("Match case"), isOn: $matchCase)
                                .font(.system(size: 11))
                                .toggleStyle(CheckboxToggleStyle())
                            if workspace.findReplaceTab != 2 {
                                Toggle(workspace.tr("Wrap around"), isOn: $wrapAround)
                                    .font(.system(size: 11))
                                    .toggleStyle(CheckboxToggleStyle())
                            }
                        }

                        VStack(alignment: .leading, spacing: workspace.findReplaceTab == 2 ? 4 : 6) {
                            if workspace.findReplaceTab != 2 {
                                Toggle(workspace.tr("Backward direction"), isOn: $backwardDirection)
                                    .font(.system(size: 11))
                                    .toggleStyle(CheckboxToggleStyle())
                            }
                            if workspace.findReplaceTab == 1 {
                                Toggle(workspace.tr("In selection"), isOn: $inSelection)
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
                        actionBtn(workspace.tr("Find Next"), isDefault: true) { runFindNext() }
                        actionBtn(workspace.tr("Count")) { runCount() }
                        actionBtn(workspace.tr("Find All in All Opened Documents")) {
                            workspace.findAllInAllOpenedDocs(query: processedQuery(), matchCase: matchCase, wholeWord: matchWholeWord, useRegex: searchMode == 2)
                            let total = workspace.searchFileGroups.reduce(0) { $0 + $1.matches.count }
                            statusMessage = "Found \(total) matches across opened files."
                        }
                        actionBtn(workspace.tr("Find All in Current Document")) {
                            workspace.findAllInCurrentDoc(query: processedQuery(), matchCase: matchCase, wholeWord: matchWholeWord, useRegex: searchMode == 2)
                            statusMessage = "Found \(workspace.searchFileGroups.first?.matches.count ?? 0) matches in current file."
                        }
                    } else if workspace.findReplaceTab == 1 {
                        // Replace Tab Buttons
                        actionBtn(workspace.tr("Find Next")) { runFindNext() }
                        actionBtn(workspace.tr("Replace")) { runReplaceOne() }
                        actionBtn(workspace.tr("Replace All"), isDefault: true) { runReplaceAll() }
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
                        // Mark Tab Buttons
                        actionBtn(workspace.tr("Find Next")) { runFindNext() }
                        actionBtn(workspace.tr("Mark All"), isDefault: true) { runMarkAll() }
                        actionBtn(workspace.tr("Clear all marks")) {
                            workspace.clearAllBookmarks()
                            statusMessage = "All marks cleared."
                        }
                        actionBtn(workspace.tr("Copy Marked Text")) {
                            workspace.copyBookmarkedLines()
                            statusMessage = "Copied bookmarked lines to clipboard."
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
                    RadioButton(tag: 0, selection: $searchMode, label: workspace.tr("Normal"))
                    RadioButton(tag: 1, selection: $searchMode, label: "Extended (\\n, \\r...)")
                }
                HStack(spacing: 6) {
                    RadioButton(tag: 2, selection: $searchMode, label: workspace.tr("Regular expression"))
                    if searchMode == 2 {
                        Toggle(workspace.tr(". matches newline"), isOn: $dotMatchesNewline)
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
                    Slider(value: $workspace.findTransparencyValue, in: 0.20...0.95, step: 0.05) { _ in
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
        if searchMode == 1 { // Extended
            q = q.replacingOccurrences(of: "\\n", with: "\n")
                .replacingOccurrences(of: "\\r", with: "\r")
                .replacingOccurrences(of: "\\t", with: "\t")
                .replacingOccurrences(of: "\\0", with: "\0")
        }
        return q
    }

    private func processedReplacement() -> String {
        var r = replaceText
        if searchMode == 1 { // Extended
            r = r.replacingOccurrences(of: "\\n", with: "\n")
                .replacingOccurrences(of: "\\r", with: "\r")
                .replacingOccurrences(of: "\\t", with: "\t")
                .replacingOccurrences(of: "\\0", with: "\0")
        }
        return r
    }

    private func buildSearchRegex(for query: String) -> NSRegularExpression? {
        guard !query.isEmpty else { return nil }
        var pattern = (searchMode == 2) ? query : NSRegularExpression.escapedPattern(for: query)
        if matchWholeWord {
            pattern = "\\b" + pattern + "\\b"
        }
        var options: NSRegularExpression.Options = []
        if !matchCase { options.insert(.caseInsensitive) }
        if searchMode == 2 && dotMatchesNewline { options.insert(.dotMatchesLineSeparators) }
        return try? NSRegularExpression(pattern: pattern, options: options)
    }

    private func runFindNext() {
        guard let tv = workspace.activeTextView, !findText.isEmpty else { return }
        let query = processedQuery()
        let content = tv.string
        let currentRange = tv.selectedRange()
        let startLocation = backwardDirection ? currentRange.location : NSMaxRange(currentRange)

        var foundRange: NSRange?
        if searchMode == 2 || matchWholeWord {
            if let regex = buildSearchRegex(for: query) {
                let matches = regex.matches(in: content, range: NSRange(location: 0, length: (content as NSString).length))
                if backwardDirection {
                    foundRange = matches.last(where: { $0.range.location < startLocation })?.range
                    if foundRange == nil && wrapAround {
                        foundRange = matches.last?.range
                    }
                } else {
                    foundRange = matches.first(where: { $0.range.location >= startLocation })?.range
                    if foundRange == nil && wrapAround {
                        foundRange = matches.first?.range
                    }
                }
            }
        } else { // Normal or Extended without wholeWord
            var options: NSString.CompareOptions = []
            if !matchCase { options.insert(.caseInsensitive) }
            let searchLength = (content as NSString).length
            if backwardDirection {
                let rangeToSearch = NSRange(location: 0, length: min(startLocation, searchLength))
                let r = (content as NSString).range(of: query, options: options.union(.backwards), range: rangeToSearch)
                if r.location != NSNotFound {
                    foundRange = r
                } else if wrapAround {
                    let wrapRange = NSRange(location: 0, length: searchLength)
                    let wr = (content as NSString).range(of: query, options: options.union(.backwards), range: wrapRange)
                    if wr.location != NSNotFound { foundRange = wr }
                }
            } else {
                let rangeToSearch = NSRange(location: min(startLocation, searchLength), length: max(0, searchLength - startLocation))
                let r = (content as NSString).range(of: query, options: options, range: rangeToSearch)
                if r.location != NSNotFound {
                    foundRange = r
                } else if wrapAround {
                    let wrapRange = NSRange(location: 0, length: searchLength)
                    let wr = (content as NSString).range(of: query, options: options, range: wrapRange)
                    if wr.location != NSNotFound { foundRange = wr }
                }
            }
        }

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
        var count = 0

        if searchMode == 2 || matchWholeWord {
            if let regex = buildSearchRegex(for: query) {
                count = regex.numberOfMatches(in: content, range: NSRange(location: 0, length: (content as NSString).length))
            }
        } else {
            var searchRange = NSRange(location: 0, length: (content as NSString).length)
            var options: NSString.CompareOptions = []
            if !matchCase { options.insert(.caseInsensitive) }
            while searchRange.location < (content as NSString).length {
                let r = (content as NSString).range(of: query, options: options, range: searchRange)
                if r.location != NSNotFound {
                    count += 1
                    searchRange.location = NSMaxRange(r)
                    searchRange.length = (content as NSString).length - searchRange.location
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
            tv.insertText(replacement, replacementRange: selected)
            doc.content = tv.string
            doc.isDirty = true
            statusMessage = "Replaced 1 occurrence."
            runFindNext()
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
                let template = (searchMode == 2) ? replacement : NSRegularExpression.escapedTemplate(for: replacement)
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

        tv.string = content
        doc.content = content
        doc.isDirty = true
        statusMessage = "Replace All: \(count) occurrence\(count == 1 ? "" : "s") were replaced."
    }

    private func runReplaceAllInOpenedDocs() {
        guard !workspace.isAllDocumentsReadOnly, !findText.isEmpty else { return }
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
                    let template = (searchMode == 2) ? replacement : NSRegularExpression.escapedTemplate(for: replacement)
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
        let count = workspace.markAll(
            query: processedQuery(),
            matchCase: matchCase,
            wholeWord: matchWholeWord,
            useRegex: searchMode == 2,
            bookmarkLine: bookmarkLine,
            purgeExisting: purgeEachSearch
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

