import SwiftUI
import AppKit

public struct NppSearchBarView: View {
    @ObservedObject var workspace: NppWorkspace

    @State private var findText: String = ""
    @State private var replaceText: String = ""
    @State private var matchCase: Bool = false
    @State private var matchWholeWord: Bool = false
    @State private var useRegex: Bool = false
    @State private var statusMessage: String = ""

    public init(workspace: NppWorkspace) {
        self.workspace = workspace
    }

    public var body: some View {
        VStack(spacing: 8) {
            // Mode Header / Switcher Bar
            HStack(spacing: 12) {
                // Find & Replace Mode Tabs
                HStack(spacing: 0) {
                    Button(action: {
                        workspace.searchBarMode = .find
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 10))
                            Text(workspace.tr("Find"))
                                .font(.system(size: 11, weight: workspace.searchBarMode == .find ? .bold : .regular))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 3)
                        .background(workspace.searchBarMode == .find ? Color.accentColor.opacity(0.2) : Color.clear)
                        .cornerRadius(4)
                    }
                    .buttonStyle(PlainButtonStyle())

                    Button(action: {
                        workspace.searchBarMode = .replace
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 10))
                            Text(workspace.tr("Replace"))
                                .font(.system(size: 11, weight: workspace.searchBarMode == .replace ? .bold : .regular))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 3)
                        .background(workspace.searchBarMode == .replace ? Color.accentColor.opacity(0.2) : Color.clear)
                        .cornerRadius(4)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .background(Color(NSColor.textBackgroundColor).opacity(0.5))
                .cornerRadius(5)

                Spacer()

                if !statusMessage.isEmpty {
                    Text(statusMessage)
                        .font(.system(size: 11))
                        .foregroundColor(.accentColor)
                }

                Button(action: {
                    workspace.clearIncrementalHighlight()
                    workspace.showSearchBar = false
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
            }

            if workspace.searchBarMode == .find {
                // MARK: - Dedicated Find / Incremental Search Mode
                HStack(spacing: 8) {
                    Text(workspace.tr("Find what:"))
                        .font(.system(size: 11, weight: .medium))
                        .frame(width: 75, alignment: .trailing)

                    HStack(spacing: 4) {
                        TextField(workspace.tr("Find what:"), text: $findText, onCommit: {
                            findNext()
                        })
                        .textFieldStyle(RoundedBorderTextFieldStyle())

                        if !findText.isEmpty {
                            let total = workspace.incrementalSearchMatches.count
                            let current = workspace.incrementalCurrentMatchIndex
                            Text("[\(current)/\(total)]")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(total > 0 ? .accentColor : .red)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(Color(NSColor.controlBackgroundColor))
                                .cornerRadius(4)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .onChange(of: findText) { newValue in
                        if !newValue.isEmpty {
                            findIncremental()
                        } else {
                            workspace.updateIncrementalSearch(query: "", matchCase: matchCase, wholeWord: matchWholeWord, useRegex: useRegex)
                            statusMessage = ""
                        }
                    }

                    Button(workspace.tr("Find Next")) { findNext() }
                        .keyboardShortcut(.defaultAction)
                    Button(workspace.tr("Find Previous")) { findPrev() }
                    Button(workspace.tr("Count")) { countOccurrences() }
                    Button(workspace.tr("Find All in Current Document")) {
                        workspace.findAllInCurrentDoc(query: findText, matchCase: matchCase, wholeWord: matchWholeWord, useRegex: useRegex)
                    }
                    Button(workspace.tr("Find All in All Opened Documents")) {
                        workspace.findAllInAllOpenedDocs(query: findText, matchCase: matchCase, wholeWord: matchWholeWord, useRegex: useRegex)
                    }
                }

                HStack(spacing: 12) {
                    Spacer().frame(width: 75)
                    Toggle(workspace.tr("Match case"), isOn: $matchCase)
                        .toggleStyle(CheckboxToggleStyle())
                        .font(.system(size: 11))
                        .onChange(of: matchCase) { _ in findIncremental() }
                    Toggle(workspace.tr("Match whole word only"), isOn: $matchWholeWord)
                        .toggleStyle(CheckboxToggleStyle())
                        .font(.system(size: 11))
                        .onChange(of: matchWholeWord) { _ in findIncremental() }
                    Toggle(workspace.tr("Regular expression"), isOn: $useRegex)
                        .toggleStyle(CheckboxToggleStyle())
                        .font(.system(size: 11))
                        .onChange(of: useRegex) { _ in findIncremental() }
                    Toggle(workspace.tr("Highlight all"), isOn: $workspace.incrementalHighlightAll)
                        .toggleStyle(CheckboxToggleStyle())
                        .font(.system(size: 11))
                        .onChange(of: workspace.incrementalHighlightAll) { _ in
                            workspace.updateIncrementalSearch(query: findText, matchCase: matchCase, wholeWord: matchWholeWord, useRegex: useRegex)
                        }
                    Spacer()
                }
            } else {
                // MARK: - Dedicated Replace Mode
                HStack(spacing: 8) {
                    Text(workspace.tr("Find what:"))
                        .font(.system(size: 11, weight: .medium))
                        .frame(width: 75, alignment: .trailing)

                    TextField(workspace.tr("Find what:"), text: $findText, onCommit: {
                        findNext()
                    })
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(maxWidth: .infinity)

                    Button(workspace.tr("Find Next")) { findNext() }
                    Button(workspace.tr("Find Previous")) { findPrev() }
                    Button(workspace.tr("Find All in Current Document")) {
                        workspace.findAllInCurrentDoc(query: findText, matchCase: matchCase, wholeWord: matchWholeWord, useRegex: useRegex)
                    }
                }

                HStack(spacing: 8) {
                    Text(workspace.tr("Replace with:"))
                        .font(.system(size: 11, weight: .medium))
                        .frame(width: 75, alignment: .trailing)

                    TextField(workspace.tr("Replace with:"), text: $replaceText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(maxWidth: .infinity)

                    Button(workspace.tr("Replace")) { replaceOne() }
                    Button(workspace.tr("Replace All")) { replaceAll() }
                }

                HStack(spacing: 12) {
                    Spacer().frame(width: 75)
                    Toggle(workspace.tr("Match case"), isOn: $matchCase)
                        .toggleStyle(CheckboxToggleStyle())
                        .font(.system(size: 11))
                    Toggle(workspace.tr("Match whole word only"), isOn: $matchWholeWord)
                        .toggleStyle(CheckboxToggleStyle())
                        .font(.system(size: 11))
                    Toggle(workspace.tr("Regular expression"), isOn: $useRegex)
                        .toggleStyle(CheckboxToggleStyle())
                        .font(.system(size: 11))
                    Spacer()
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(NSColor.separatorColor)),
            alignment: .bottom
        )
        .onAppear {
            if !workspace.findQueryText.isEmpty {
                findText = workspace.findQueryText
            } else if !workspace.lastSearchQuery.isEmpty {
                findText = workspace.lastSearchQuery
            }
        }
        .onExitCommand {
            workspace.clearIncrementalHighlight()
            workspace.showSearchBar = false
            if let tv = workspace.activeTextView {
                tv.window?.makeFirstResponder(tv)
            }
        }
    }

    private func findIncremental() {
        guard !findText.isEmpty, let doc = workspace.activeDocument else {
            workspace.updateIncrementalSearch(query: "", matchCase: matchCase, wholeWord: matchWholeWord, useRegex: useRegex)
            return
        }
        workspace.lastSearchQuery = findText
        workspace.updateIncrementalSearch(query: findText, matchCase: matchCase, wholeWord: matchWholeWord, useRegex: useRegex)

        let matches = workspace.incrementalSearchMatches
        if !matches.isEmpty {
            let startPos = min(max(0, doc.cursorPos), (doc.content as NSString).length)
            let matchRange = matches.first(where: { $0.location >= startPos }) ?? matches.first!
            doc.cursorPos = matchRange.location
            doc.selectionLength = matchRange.length
            workspace.selectRange(matchRange, makeFirstResponder: false)
            if let idx = matches.firstIndex(of: matchRange) {
                workspace.incrementalCurrentMatchIndex = idx + 1
            }
            statusMessage = "Found at line \(doc.cursorLine)"
        } else {
            statusMessage = "Phrase not found"
        }
    }

    private func findNext() {
        guard !findText.isEmpty, let doc = workspace.activeDocument else { return }
        workspace.lastSearchQuery = findText
        workspace.updateIncrementalSearch(query: findText, matchCase: matchCase, wholeWord: matchWholeWord, useRegex: useRegex)

        let matches = workspace.incrementalSearchMatches
        if !matches.isEmpty {
            let currentLoc = doc.cursorPos + max(1, doc.selectionLength)
            let nextMatch = matches.first(where: { $0.location >= currentLoc }) ?? matches.first!
            doc.cursorPos = nextMatch.location
            doc.selectionLength = nextMatch.length
            workspace.selectRange(nextMatch, makeFirstResponder: false)
            if let idx = matches.firstIndex(of: nextMatch) {
                workspace.incrementalCurrentMatchIndex = idx + 1
            }
            statusMessage = "Found at line \(doc.cursorLine)"
        } else {
            statusMessage = "Cannot find '\(findText)'"
        }
    }

    private func findPrev() {
        guard !findText.isEmpty, let doc = workspace.activeDocument else { return }
        workspace.lastSearchQuery = findText
        workspace.updateIncrementalSearch(query: findText, matchCase: matchCase, wholeWord: matchWholeWord, useRegex: useRegex)

        let matches = workspace.incrementalSearchMatches
        if !matches.isEmpty {
            let currentLoc = doc.cursorPos
            let prevMatch = matches.last(where: { $0.location < currentLoc }) ?? matches.last!
            doc.cursorPos = prevMatch.location
            doc.selectionLength = prevMatch.length
            workspace.selectRange(prevMatch, makeFirstResponder: false)
            if let idx = matches.firstIndex(of: prevMatch) {
                workspace.incrementalCurrentMatchIndex = idx + 1
            }
            statusMessage = "Found at line \(doc.cursorLine)"
        } else {
            statusMessage = "Cannot find '\(findText)'"
        }
    }

    private func countOccurrences() {
        guard !findText.isEmpty, let doc = workspace.activeDocument else { return }
        let content = doc.content as NSString
        var count = 0
        var searchRange = NSRange(location: 0, length: content.length)

        var options: NSString.CompareOptions = []
        if !matchCase { options.insert(.caseInsensitive) }
        if useRegex { options.insert(.regularExpression) }

        while searchRange.location < content.length {
            let found = content.range(of: findText, options: options, range: searchRange)
            if found.location == NSNotFound { break }
            count += 1
            let nextLoc = NSMaxRange(found)
            searchRange = NSRange(location: nextLoc, length: content.length - nextLoc)
        }
        statusMessage = "Count: \(count) match(es)"
    }

    private func replaceOne() {
        guard !findText.isEmpty,
              let doc = workspace.activeDocument,
              !(doc.isReadOnly || workspace.isAllDocumentsReadOnly) else { return }
        let content = doc.content as NSString
        let searchRange = NSRange(location: min(doc.cursorPos, content.length), length: max(0, content.length - min(doc.cursorPos, content.length)))

        var options: NSString.CompareOptions = []
        if !matchCase { options.insert(.caseInsensitive) }
        if useRegex { options.insert(.regularExpression) }

        let found = content.range(of: findText, options: options, range: searchRange)
        if found.location != NSNotFound {
            let newStr = content.replacingCharacters(in: found, with: replaceText)
            doc.content = newStr
            doc.isDirty = true
            if let tv = workspace.activeTextView {
                tv.string = newStr
            }
            let replacedRange = NSRange(location: found.location, length: (replaceText as NSString).length)
            workspace.selectRange(replacedRange)
            statusMessage = "1 occurrence replaced"
        } else {
            findNext()
        }
    }

    private func replaceAll() {
        guard !findText.isEmpty,
              let doc = workspace.activeDocument,
              !(doc.isReadOnly || workspace.isAllDocumentsReadOnly) else { return }
        var options: NSString.CompareOptions = []
        if !matchCase { options.insert(.caseInsensitive) }
        if useRegex { options.insert(.regularExpression) }

        let (newStr, count) = replaceAllOccurrences(in: doc.content, target: findText, with: replaceText, options: options)
        doc.content = newStr
        doc.isDirty = true
        if let tv = workspace.activeTextView {
            tv.string = newStr
        }
        statusMessage = "Replaced \(count) occurrence(s)"
    }

    private func replaceAllOccurrences(in text: String, target: String, with replacement: String, options: NSString.CompareOptions) -> (String, Int) {
        var str = text as NSString
        var count = 0
        var searchRange = NSRange(location: 0, length: str.length)

        while searchRange.location < str.length {
            let found = str.range(of: target, options: options, range: searchRange)
            if found.location == NSNotFound { break }
            str = str.replacingCharacters(in: found, with: replacement) as NSString
            count += 1
            let nextLoc = found.location + (replacement as NSString).length
            searchRange = NSRange(location: nextLoc, length: str.length - nextLoc)
        }
        return (str as String, count)
    }
}
