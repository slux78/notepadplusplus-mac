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
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                // Find Row
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 12))

                TextField("Find what...", text: $findText, onCommit: {
                    findNext()
                })
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(maxWidth: .infinity)

                Button("Find Next") { findNext() }
                    .keyboardShortcut(.defaultAction)
                Button("Find Prev") { findPrev() }
                Button("Count") { countOccurrences() }
                Button("Find All in Current Doc") {
                    workspace.findAllInCurrentDoc(query: findText, matchCase: matchCase, wholeWord: matchWholeWord, useRegex: useRegex)
                }
                Button("Find All in Opened Docs") {
                    workspace.findAllInAllOpenedDocs(query: findText, matchCase: matchCase, wholeWord: matchWholeWord, useRegex: useRegex)
                }

                Button(action: {
                    workspace.showSearchBar = false
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
            }

            HStack(spacing: 8) {
                // Replace Row
                Image(systemName: "arrow.triangle.2.circlepath")
                    .foregroundColor(.secondary)
                    .font(.system(size: 12))

                TextField("Replace with...", text: $replaceText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(maxWidth: .infinity)

                Button("Replace") { replaceOne() }
                Button("Replace All") { replaceAll() }

                // Match Options
                Toggle("Match Case", isOn: $matchCase)
                    .toggleStyle(CheckboxToggleStyle())
                    .font(.system(size: 11))
                Toggle("Whole Word", isOn: $matchWholeWord)
                    .toggleStyle(CheckboxToggleStyle())
                    .font(.system(size: 11))
                Toggle("Regex", isOn: $useRegex)
                    .toggleStyle(CheckboxToggleStyle())
                    .font(.system(size: 11))

                if !statusMessage.isEmpty {
                    Text(statusMessage)
                        .font(.system(size: 11))
                        .foregroundColor(.accentColor)
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
    }

    private func findNext() {
        guard !findText.isEmpty, let doc = workspace.activeDocument else { return }
        let content = doc.content as NSString
        let startPos = min(doc.cursorPos + 1, content.length)
        let searchRange = NSRange(location: startPos, length: content.length - startPos)

        var options: NSString.CompareOptions = []
        if !matchCase { options.insert(.caseInsensitive) }
        if useRegex { options.insert(.regularExpression) }

        var foundRange = content.range(of: findText, options: options, range: searchRange)
        if foundRange.location == NSNotFound {
            // Wrap around
            let wrapRange = NSRange(location: 0, length: startPos)
            foundRange = content.range(of: findText, options: options, range: wrapRange)
        }

        if foundRange.location != NSNotFound {
            doc.cursorPos = foundRange.location
            doc.selectionLength = foundRange.length
            statusMessage = "Found at line \(doc.cursorLine)"
        } else {
            statusMessage = "Cannot find '\(findText)'"
        }
    }

    private func findPrev() {
        guard !findText.isEmpty, let doc = workspace.activeDocument else { return }
        let content = doc.content as NSString
        let endPos = max(doc.cursorPos, 0)
        let searchRange = NSRange(location: 0, length: endPos)

        var options: NSString.CompareOptions = [.backwards]
        if !matchCase { options.insert(.caseInsensitive) }
        if useRegex { options.insert(.regularExpression) }

        let foundRange = content.range(of: findText, options: options, range: searchRange)
        if foundRange.location != NSNotFound {
            doc.cursorPos = foundRange.location
            doc.selectionLength = foundRange.length
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
        guard !findText.isEmpty, let doc = workspace.activeDocument else { return }
        let content = doc.content as NSString
        let searchRange = NSRange(location: doc.cursorPos, length: content.length - doc.cursorPos)

        var options: NSString.CompareOptions = []
        if !matchCase { options.insert(.caseInsensitive) }
        if useRegex { options.insert(.regularExpression) }

        let found = content.range(of: findText, options: options, range: searchRange)
        if found.location != NSNotFound {
            let newStr = content.replacingCharacters(in: found, with: replaceText)
            doc.content = newStr
            doc.isDirty = true
            findNext()
        }
    }

    private func replaceAll() {
        guard !findText.isEmpty, let doc = workspace.activeDocument else { return }
        var options: NSString.CompareOptions = []
        if !matchCase { options.insert(.caseInsensitive) }
        if useRegex { options.insert(.regularExpression) }

        let (newStr, count) = replaceAllOccurrences(in: doc.content, target: findText, with: replaceText, options: options)
        doc.content = newStr
        doc.isDirty = true
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
