import SwiftUI
import AppKit

// MARK: - Authentic Notepad++ Shortcut Mapper (matching upstream ShortcutMapper.rc IDD_SHORTCUTMAPPER_DLG & shortcut.rc IDD_SHORTCUT_DLG)
public struct NppShortcutMapperView: View {
    @ObservedObject var workspace: NppWorkspace
    @Binding var isPresented: Bool

    @State private var selectedTab: Int = 0 // 0: Main menu, 1: Macros, 2: Run commands, 3: Plugin commands, 4: Scintilla commands
    @State private var filterText: String = ""
    @State private var selectedEntryKey: String? = nil

    // Modify Sub-Dialog State (IDD_SHORTCUT_DLG in shortcut.rc)
    @State private var showModifySheet: Bool = false
    @State private var editingName: String = ""
    @State private var editingCmd: Bool = true
    @State private var editingAlt: Bool = false
    @State private var editingShift: Bool = false
    @State private var editingKey: String = "None"

    public struct ShortcutEntry: Identifiable, Equatable {
        public var id: String { "\(category)|\(name)" }
        public let category: String
        public let name: String
        public let shortcut: String
    }

    public static let availableKeys: [String] = [
        "None",
        "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M",
        "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z",
        "0", "1", "2", "3", "4", "5", "6", "7", "8", "9",
        "F1", "F2", "F3", "F4", "F5", "F6", "F7", "F8", "F9", "F10", "F11", "F12",
        "Up", "Down", "Left", "Right", "Space", "Tab", "Enter", "Backspace", "Delete", "/", "+", "-"
    ]

    let mainMenuDefaults: [(String, String, String)] = [
        ("File", "New", "Cmd+N"),
        ("File", "Open...", "Cmd+O"),
        ("File", "Save", "Cmd+S"),
        ("File", "Save As...", "Cmd+Shift+S"),
        ("File", "Save All", "Cmd+Alt+S"),
        ("File", "Close", "Cmd+W"),
        ("File", "Close All", "Cmd+Shift+W"),
        ("File", "Restore Recent Closed File", "Cmd+Shift+T"),
        ("File", "Print...", "Cmd+P"),
        ("Edit", "Undo", "Cmd+Z"),
        ("Edit", "Redo", "Cmd+Shift+Z"),
        ("Edit", "Cut", "Cmd+X"),
        ("Edit", "Copy", "Cmd+C"),
        ("Edit", "Paste", "Cmd+V"),
        ("Edit", "Select All", "Cmd+A"),
        ("Edit", "Duplicate Current Line", "Cmd+D"),
        ("Edit", "Move Line Up", "Alt+Up"),
        ("Edit", "Move Line Down", "Alt+Down"),
        ("Edit", "Join Lines", "Cmd+J"),
        ("Edit", "Toggle Single Line Comment", "Cmd+/"),
        ("Edit", "Column Editor...", "Alt+C"),
        ("Search", "Find...", "Cmd+F"),
        ("Search", "Replace...", "Cmd+H"),
        ("Search", "Find in Files...", "Cmd+Shift+F"),
        ("Search", "Mark...", "Cmd+M"),
        ("Search", "Find Next", "F3"),
        ("Search", "Find Previous", "Shift+F3"),
        ("Search", "Go to Line...", "Cmd+G"),
        ("View", "Always on Top", "Cmd+Alt+T"),
        ("View", "Word Wrap", "Cmd+Alt+W"),
        ("View", "Zoom In", "Cmd++"),
        ("View", "Zoom Out", "Cmd+-"),
        ("View", "Reset Zoom", "Cmd+0")
    ]

    let runDefaults: [(String, String, String)] = [
        ("Run", "Run...", "F5"),
        ("Run", "Open in Terminal", "Cmd+T"),
        ("Run", "Launch in Safari", "Cmd+Alt+1"),
        ("Run", "Launch in Chrome", "Cmd+Alt+2")
    ]

    let pluginDefaults: [(String, String, String)] = [
        ("MIME Tools", "Base64 Encode", "None"),
        ("MIME Tools", "Base64 Decode", "None"),
        ("MIME Tools", "URL Encode", "None"),
        ("MIME Tools", "URL Decode", "None"),
        ("Converter", "ASCII -> HEX", "None"),
        ("Converter", "HEX -> ASCII", "None")
    ]

    let scintillaDefaults: [(String, String, String)] = [
        ("Scintilla", "SCI_LINECUT", "Cmd+L"),
        ("Scintilla", "SCI_LINEDELETE", "Cmd+Shift+K"),
        ("Scintilla", "SCI_WORDLEFT", "Alt+Left"),
        ("Scintilla", "SCI_WORDRIGHT", "Alt+Right"),
        ("Scintilla", "SCI_DOCUMENTSTART", "Cmd+Up"),
        ("Scintilla", "SCI_DOCUMENTEND", "Cmd+Down")
    ]

    public init(workspace: NppWorkspace, isPresented: Binding<Bool>) {
        self.workspace = workspace
        self._isPresented = isPresented
    }

    public var body: some View {
        let currentItems = getActiveShortcuts()
        let filtered = filterText.isEmpty ? currentItems : currentItems.filter {
            $0.name.localizedCaseInsensitiveContains(filterText) ||
            $0.category.localizedCaseInsensitiveContains(filterText) ||
            $0.shortcut.localizedCaseInsensitiveContains(filterText)
        }
        let selectedEntry = filtered.first(where: { $0.id == selectedEntryKey }) ?? filtered.first

        VStack(spacing: 0) {
            // Header
            HStack {
                Text(workspace.tr("Shortcut mapper"))
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 14))
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // 5 Tabs Matching ShortcutMapper.rc (IDC_BABYGRID_TABBAR)
            HStack(spacing: 0) {
                tabButton(workspace.tr("Main menu"), tag: 0)
                tabButton(workspace.tr("Macros"), tag: 1)
                tabButton(workspace.tr("Run commands"), tag: 2)
                tabButton(workspace.tr("Plugin commands"), tag: 3)
                tabButton(workspace.tr("Scintilla commands"), tag: 4)
                Spacer()
            }
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // Shortcuts Table Header
            HStack {
                Text(workspace.tr("Name")).bold().frame(width: 280, alignment: .leading)
                Text(workspace.tr("Shortcut")).bold().frame(width: 170, alignment: .leading)
                Text(workspace.tr("Category")).bold().frame(maxWidth: .infinity, alignment: .leading)
            }
            .font(.system(size: 11))
            .foregroundColor(.secondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Shortcuts Rows
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 1) {
                    ForEach(filtered) { item in
                        let isSelected = (selectedEntry?.id == item.id)
                        HStack {
                            Text(item.name)
                                .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                                .foregroundColor(isSelected ? .white : .primary)
                                .frame(width: 280, alignment: .leading)
                                .lineLimit(1)

                            Text(item.shortcut)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(isSelected ? .white : (item.shortcut == "None" ? .secondary : .accentColor))
                                .frame(width: 170, alignment: .leading)
                                .lineLimit(1)

                            Text(item.category)
                                .font(.system(size: 11))
                                .foregroundColor(isSelected ? .white.opacity(0.9) : .secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(isSelected ? Color.accentColor : Color.clear)
                        .cornerRadius(3)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedEntryKey = item.id
                        }
                    }
                }
                .padding(6)
            }
            .background(Color(NSColor.textBackgroundColor))

            Divider()

            // Conflict Info Box (IDC_BABYGRID_INFO, ShortcutMapper.rc line 33)
            VStack(alignment: .leading, spacing: 8) {
                let conflictMsg = conflictMessage(for: selectedEntry, in: currentItems)
                HStack {
                    Text(conflictMsg)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(conflictMsg.contains("CONFLICT") || conflictMsg.contains("겹칩니다") ? .red : .secondary)
                    Spacer()
                }
                .padding(8)
                .frame(maxWidth: .infinity, minHeight: 34, alignment: .leading)
                .background(Color(NSColor.controlBackgroundColor))
                .border(Color(NSColor.separatorColor), width: 1)

                // Filter Row (IDC_BABYGRID_STATIC, IDC_BABYGRID_FILTER, IDC_BABYGRID_FILTER_CLEAR, lines 34-36)
                HStack(spacing: 8) {
                    Text(workspace.tr("Filter:"))
                        .font(.system(size: 11))
                        .fixedSize()
                    TextField("", text: $filterText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(.system(size: 11))
                    Button("✕") {
                        filterText = ""
                    }
                    .disabled(filterText.isEmpty)
                }

                // Bottom Action Buttons (IDM_BABYGRID_MODIFY, IDM_BABYGRID_CLEAR, IDM_BABYGRID_DELETE, IDOK, lines 37-40)
                HStack(spacing: 10) {
                    Spacer()

                    Button(workspace.tr("Modify")) {
                        if let entry = selectedEntry {
                            openModifySheet(for: entry)
                        }
                    }
                    .frame(minWidth: 72)
                    .disabled(selectedEntry == nil)

                    Button(workspace.tr("Clear")) {
                        if let entry = selectedEntry {
                            applyShortcut("None", to: entry)
                        }
                    }
                    .frame(minWidth: 72)
                    .disabled(selectedEntry == nil)

                    Button(workspace.tr("Delete")) {
                        if let entry = selectedEntry, selectedTab == 1 {
                            workspace.savedMacros.removeAll { $0.name == entry.name }
                            selectedEntryKey = nil
                        }
                    }
                    .frame(minWidth: 72)
                    .disabled(selectedTab != 1 || selectedEntry == nil)

                    Button(workspace.tr("Close")) {
                        isPresented = false
                    }
                    .frame(minWidth: 72)
                    .keyboardShortcut(.defaultAction)

                    Spacer()
                }
                .padding(.top, 2)
            }
            .padding(12)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(width: 680, height: 490)
        .background(Color(NSColor.windowBackgroundColor))
        .preferredColorScheme(workspace.currentTheme.isDark ? .dark : .light)
        .sheet(isPresented: $showModifySheet) {
            modifyShortcutSubDialog(entry: selectedEntry)
        }
    }

    // MARK: - Sub-Dialog IDD_SHORTCUT_DLG (shortcut.rc lines 25-43)
    @ViewBuilder
    private func modifyShortcutSubDialog(entry: ShortcutEntry?) -> some View {
        VStack(spacing: 14) {
            Text(workspace.tr("Shortcut"))
                .font(.system(size: 13, weight: .semibold))

            HStack {
                Text(workspace.tr("Name:"))
                    .font(.system(size: 11))
                    .fixedSize()
                TextField("", text: $editingName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .font(.system(size: 11))
                    .disabled(selectedTab != 1)
            }

            HStack(spacing: 10) {
                Toggle("CMD/CTRL", isOn: $editingCmd)
                    .toggleStyle(CheckboxToggleStyle())
                    .fixedSize()
                Text("+")
                Toggle("ALT", isOn: $editingAlt)
                    .toggleStyle(CheckboxToggleStyle())
                    .fixedSize()
                Text("+")
                Toggle("SHIFT", isOn: $editingShift)
                    .toggleStyle(CheckboxToggleStyle())
                    .fixedSize()
                Text("+")
                Picker("", selection: $editingKey) {
                    ForEach(NppShortcutMapperView.availableKeys, id: \.self) { k in
                        Text(k).tag(k)
                    }
                }
                .labelsHidden()
                .frame(width: 95)
            }
            .font(.system(size: 11))

            HStack(spacing: 12) {
                Spacer()
                Button(workspace.tr("OK")) {
                    if let entry = entry {
                        let newShortcut = composedShortcut()
                        applyShortcut(newShortcut, to: entry, newName: editingName)
                    }
                    showModifySheet = false
                }
                .frame(width: 75)
                .keyboardShortcut(.defaultAction)

                Button(workspace.tr("Cancel")) {
                    showModifySheet = false
                }
                .frame(width: 75)
                .keyboardShortcut(.cancelAction)
                Spacer()
            }
        }
        .padding(16)
        .frame(width: 380, height: 165)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private func openModifySheet(for entry: ShortcutEntry) {
        editingName = entry.name
        let parts = entry.shortcut.components(separatedBy: "+")
        editingCmd = parts.contains("Cmd") || parts.contains("Ctrl")
        editingAlt = parts.contains("Alt") || parts.contains("Opt")
        editingShift = parts.contains("Shift")
        if let last = parts.last, NppShortcutMapperView.availableKeys.contains(last) {
            editingKey = last
        } else {
            editingKey = "None"
        }
        showModifySheet = true
    }

    private func composedShortcut() -> String {
        guard editingKey != "None" else { return "None" }
        var parts: [String] = []
        if editingCmd { parts.append("Cmd") }
        if editingAlt { parts.append("Alt") }
        if editingShift { parts.append("Shift") }
        parts.append(editingKey)
        return parts.joined(separator: "+")
    }

    private func applyShortcut(_ newShortcut: String, to entry: ShortcutEntry, newName: String? = nil) {
        if selectedTab == 1 {
            if let idx = workspace.savedMacros.firstIndex(where: { $0.name == entry.name }) {
                workspace.savedMacros[idx].shortcut = (newShortcut == "None") ? "" : newShortcut
                if let nn = newName?.trimmingCharacters(in: .whitespacesAndNewlines), !nn.isEmpty {
                    workspace.savedMacros[idx].name = nn
                }
            }
        } else {
            workspace.customShortcuts[entry.id] = newShortcut
        }
    }

    private func conflictMessage(for entry: ShortcutEntry?, in items: [ShortcutEntry]) -> String {
        guard let entry = entry else {
            return workspace.tr("No shortcut conflicts for this item.")
        }
        guard entry.shortcut != "None" && !entry.shortcut.isEmpty else {
            return workspace.tr("No shortcut conflicts for this item.")
        }
        let conflicts = items.filter { $0.id != entry.id && $0.shortcut.caseInsensitiveCompare(entry.shortcut) == .orderedSame }
        if let firstConflict = conflicts.first {
            return "\(workspace.tr("CONFLICT FOUND!")) [\(firstConflict.category)] \(firstConflict.name) (\(firstConflict.shortcut))"
        }
        return workspace.tr("No shortcut conflicts for this item.")
    }

    private func tabButton(_ title: String, tag: Int) -> some View {
        Button(action: {
            selectedTab = tag
            selectedEntryKey = nil
        }) {
            Text(title)
                .font(.system(size: 11, weight: selectedTab == tag ? .bold : .regular))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(selectedTab == tag ? Color(NSColor.controlBackgroundColor) : Color.clear)
                .foregroundColor(selectedTab == tag ? .primary : .secondary)
        }
        .buttonStyle(PlainButtonStyle())
    }

    public func getActiveShortcuts() -> [ShortcutEntry] {
        let baseTuples: [(String, String, String)]
        switch selectedTab {
        case 0: baseTuples = mainMenuDefaults
        case 1:
            return workspace.savedMacros.map {
                ShortcutEntry(category: "Macro", name: $0.name, shortcut: $0.shortcut.isEmpty ? "None" : $0.shortcut)
            }
        case 2: baseTuples = runDefaults
        case 3: baseTuples = pluginDefaults
        case 4: baseTuples = scintillaDefaults
        default: baseTuples = mainMenuDefaults
        }
        return baseTuples.map { cat, name, defSc in
            let key = "\(cat)|\(name)"
            let sc = workspace.customShortcuts[key] ?? defSc
            return ShortcutEntry(category: cat, name: name, shortcut: sc)
        }
    }
}
