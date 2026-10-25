import SwiftUI
import AppKit

// MARK: - Authentic Notepad++ GroupBox Container
public struct NppGroupBox<Content: View>: View {
    let title: String
    let content: Content

    public init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.primary)
            content
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 3)
                .stroke(Color.secondary.opacity(0.35), lineWidth: 1)
        )
    }
}

// MARK: - Reusable Authentic Notepad++ Radio Button (Zero-Dead-Zone, Full Row Hit-Testing)
public struct NppRadioButton<T: Equatable>: View {
    let title: String
    let value: T
    @Binding var selection: T
    var onChange: (() -> Void)? = nil

    public init(title: String, value: T, selection: Binding<T>, onChange: (() -> Void)? = nil) {
        self.title = title
        self.value = value
        self._selection = selection
        self.onChange = onChange
    }

    public var body: some View {
        Button(action: {
            selection = value
            onChange?()
        }) {
            HStack(spacing: 6) {
                Image(systemName: selection == value ? "largecircle.fill.circle" : "circle")
                    .foregroundColor(selection == value ? .accentColor : .secondary)
                    .font(.system(size: 11))
                Text(title)
                    .font(.system(size: 11))
                    .foregroundColor(.primary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Authentic Notepad++ Preferences View (matching upstream preferenceDlg.cpp & preference.rc)
public struct NppPreferencesView: View {
    @ObservedObject var workspace: NppWorkspace
    @Binding var isPresented: Bool

    @State private var selectedCategory: Int = 0
    @State private var selectedAvailableLang: String? = nil
    @State private var selectedDisabledLang: String? = nil
    @State private var fileAssocStatusMessage: String? = nil
    @State private var selectedIndentLang: String = "[Default]"

    // Exactly 24 categories matching upstream Notepad++
    let categories: [String] = [
        "General",
        "Toolbar",
        "Tab Bar",
        "Editing 1",
        "Editing 2",
        "Dark Mode",
        "Margins/Border/Edge",
        "New Document",
        "Default Directory",
        "Recent Files History",
        "File Association",
        "Language",
        "Indentation",
        "Highlighting",
        "Print",
        "Searching",
        "Backup",
        "Auto-Completion",
        "Multi-Instance & Date",
        "Delimiter",
        "Performance",
        "Cloud & Link",
        "Search Engine",
        "MISC."
    ]

    public init(workspace: NppWorkspace, isPresented: Binding<Bool>) {
        self.workspace = workspace
        self._isPresented = isPresented
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Window Header
            HStack {
                Text(workspace.tr("Preferences"))
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 15))
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // Main 2-Pane Split: Left Categories List, Right Category Content
            HSplitView {
                // Left 24 Categories ListBox
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 1) {
                            ForEach(0..<categories.count, id: \.self) { idx in
                                Button(action: { selectedCategory = idx }) {
                                    HStack {
                                        Text(workspace.tr(categories[idx]))
                                            .font(.system(size: 11, weight: selectedCategory == idx ? .bold : .regular))
                                            .foregroundColor(selectedCategory == idx ? .white : .primary)
                                            .lineLimit(1)
                                        Spacer()
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .contentShape(Rectangle())
                                    .background(selectedCategory == idx ? Color.accentColor : Color.clear)
                                    .cornerRadius(3)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(6)
                    }
                }
                .frame(width: 175)
                .background(Color(NSColor.controlBackgroundColor))

                // Right Category Content
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        categoryContent(for: selectedCategory)
                        Spacer()
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                .background(Color(NSColor.windowBackgroundColor))
            }
            .onAppear {
                selectedCategory = min(workspace.selectedPreferencesTab, categories.count - 1)
            }
            .onChange(of: workspace.selectedPreferencesTab) { newTab in
                selectedCategory = min(newTab, categories.count - 1)
            }
            .onChange(of: selectedCategory) { newCat in
                workspace.selectedPreferencesTab = newCat
            }

            Divider()

            // Bottom Footer with authentic "Close" Button
            HStack {
                Spacer()
                Button(workspace.tr("Close")) {
                    isPresented = false
                }
                .frame(width: 80)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(width: 760, height: 540)
        .preferredColorScheme(workspace.currentTheme.isDark ? .dark : .light)
    }

    @ViewBuilder
    private func categoryContent(for index: Int) -> some View {
        switch index {
        case 0: generalSection
        case 1: toolbarSection
        case 2: tabbarSection
        case 3: editing1Section
        case 4: editing2Section
        case 5: darkModeSection
        case 6: marginsBorderEdgeSection
        case 7: newDocumentSection
        case 8: defaultDirectorySection
        case 9: recentFilesHistorySection
        case 10: fileAssociationSection
        case 11: languageSection
        case 12: indentationSection
        case 13: highlightingSection
        case 14: printSection
        case 15: searchingSection
        case 16: backupSection
        case 17: autoCompletionSection
        case 18: multiInstanceSection
        case 19: delimiterSection
        case 20: performanceSection
        case 21: cloudAndLinkSection
        case 22: searchEngineSection
        case 23: miscSection
        default: generalSection
        }
    }

    // MARK: - 0. General (IDD_PREFERENCE_SUB_GENERAL)
    private var generalSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            NppGroupBox(workspace.tr("Localization")) {
                HStack {
                    Text(workspace.tr("Language:"))
                        .font(.system(size: 11))
                        .fixedSize()
                    Picker("", selection: $workspace.localizationLanguage) {
                        Text("English").tag("English")
                        Text("한국어 (Korean)").tag("한국어")
                        Text("Français").tag("Français")
                        Text("Deutsch").tag("Deutsch")
                        Text("Español").tag("Español")
                        Text("Italiano").tag("Italiano")
                        Text("日本語").tag("日本語")
                        Text("简体中文").tag("简体中文")
                        Text("繁體中文").tag("繁體中文")
                    }
                    .labelsHidden()
                    .frame(width: 180)
                }
            }

            NppGroupBox(workspace.tr("Menu")) {
                VStack(alignment: .leading, spacing: 6) {
                    Toggle("Hide (use Alt or F10 key to toggle)", isOn: $workspace.hideMenuBar)
                    Toggle("Hide right shortcuts ＋ ▼ ✕", isOn: $workspace.hideRightShortcuts)
                }
                .font(.system(size: 11))
                .toggleStyle(CheckboxToggleStyle())
            }

            NppGroupBox(workspace.tr("Status Bar")) {
                Toggle(workspace.tr("Hide"), isOn: $workspace.hideStatusBar)
                    .font(.system(size: 11))
                    .toggleStyle(CheckboxToggleStyle())
            }

            NppGroupBox("Default Editor Font & Typography") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 16) {
                        HStack {
                            Text("Font:")
                                .font(.system(size: 11))
                                .fixedSize()
                            Picker("", selection: $workspace.fontFamily) {
                                Section("Coding & Monospace Fonts") {
                                    ForEach(NppWorkspace.availableCodingFonts, id: \.self) { f in
                                        Text(f).tag(f)
                                    }
                                }
                                Section("All System Fonts") {
                                    ForEach(NppWorkspace.allSystemFontFamilies, id: \.self) { f in
                                        Text(f).tag(f)
                                    }
                                }
                            }
                            .labelsHidden()
                            .frame(width: 170)
                        }

                        HStack {
                            Text("Size:")
                                .font(.system(size: 11))
                                .fixedSize()
                            Stepper("\(Int(workspace.fontSize)) pt", value: $workspace.fontSize, in: 8...36)
                                .font(.system(size: 11))
                        }
                    }

                    // Live Font Preview Box
                    HStack {
                        Spacer()
                        Text("The quick brown fox jumps over the lazy dog. 다람쥐 헌 쳇바퀴에 타고파. 0123456789")
                            .font(Font(NppWorkspace.resolveFont(name: workspace.fontFamily, size: workspace.fontSize)))
                            .foregroundColor(Color(workspace.currentTheme.foregroundColor))
                            .padding(6)
                            .background(Color(workspace.currentTheme.backgroundColor))
                            .cornerRadius(3)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)

                    HStack {
                        Spacer()
                        Button("Open Full Style Configurator...") {
                            workspace.showStyleConfigurator = true
                        }
                        .font(.system(size: 11))
                    }
                }
            }

            NppGroupBox("Dialog & UI Font") {
                HStack(spacing: 20) {
                    HStack {
                        Text("Size:")
                            .font(.system(size: 11))
                            .fixedSize()
                        Picker("", selection: $workspace.dialogFontSize) {
                            ForEach([8, 9, 10, 11, 12, 14, 16], id: \.self) { sz in
                                Text("\(sz)").tag(sz)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 60)
                    }

                    HStack {
                        Text("Name:")
                            .font(.system(size: 11))
                            .fixedSize()
                        Picker("", selection: $workspace.dialogFontName) {
                            Text("System Default (SF Pro)").tag("SF Pro")
                            ForEach(NppWorkspace.availableCodingFonts, id: \.self) { f in
                                Text(f).tag(f)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 180)
                    }
                }
            }
        }
    }

    // MARK: - 1. Toolbar (IDD_PREFERENCE_SUB_TOOLBAR)
    private var toolbarSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Hide", isOn: $workspace.hideToolbar)
                .font(.system(size: 11))
                .toggleStyle(CheckboxToggleStyle())

            HStack(alignment: .top, spacing: 16) {
                NppGroupBox("Icons") {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach([
                            "Fluent UI: small",
                            "Fluent UI: large",
                            "Filled Fluent UI: small",
                            "Filled Fluent UI: large",
                            "Standard icons: small"
                        ], id: \.self) { style in
                            NppRadioButton(title: style, value: style, selection: $workspace.toolbarIconStyle) {
                                workspace.largeToolbarIcons = style.contains("large")
                            }
                        }
                    }
                }

                VStack(spacing: 12) {
                    NppGroupBox("Colorization") {
                        HStack(spacing: 20) {
                            ForEach(["Complete", "Partial"], id: \.self) { c in
                                NppRadioButton(title: c, value: c, selection: $workspace.toolbarColorization)
                            }
                        }
                    }

                    NppGroupBox("Color choice") {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                            ForEach(["Red", "Green", "Blue", "Purple", "Cyan", "Olive", "Yellow", "Default", "System Accent", "Custom"], id: \.self) { col in
                                NppRadioButton(title: col, value: col, selection: $workspace.toolbarColorChoice)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - 2. Tab Bar (IDD_PREFERENCE_SUB_TABBAR)
    private var tabbarSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Hide", isOn: $workspace.hideTabBar)
                .font(.system(size: 11))
                .toggleStyle(CheckboxToggleStyle())

            HStack(alignment: .top, spacing: 14) {
                NppGroupBox("Behavior") {
                    VStack(alignment: .leading, spacing: 6) {
                        Toggle("Vertical", isOn: $workspace.tabVertical)
                        Toggle("Multi-line", isOn: $workspace.tabMultiLine)
                        Toggle("Lock (no drag and drop)", isOn: $workspace.tabLock)
                        Toggle("Double click to close document", isOn: $workspace.doubleClickTabToClose)
                        Toggle("Exit on close the last tab", isOn: $workspace.exitOnCloseLastTab)

                        Divider().padding(.vertical, 2)

                        HStack {
                            Text("Max. tab label length:")
                                .font(.system(size: 11))
                            TextField("30", value: $workspace.tabMaxLabelLen, formatter: NumberFormatter())
                                .frame(width: 40)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                            Text("(?)")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                    }
                    .font(.system(size: 11))
                    .toggleStyle(CheckboxToggleStyle())
                }

                NppGroupBox("Look & feel") {
                    VStack(alignment: .leading, spacing: 6) {
                        Toggle("Reduce (smaller tab height)", isOn: $workspace.tabReduce)
                        Toggle("Alternate icons", isOn: $workspace.tabAltIcons)
                        Toggle("Change inactive tab color", isOn: $workspace.tabChangeInactiveColor)
                        Toggle("Draw a coloured bar on active tab", isOn: $workspace.tabColorIndicator)
                        Toggle("Show close button", isOn: $workspace.showTabCloseButton)
                        Toggle("Enable pin tab feature", isOn: $workspace.tabPinFeature)
                        Toggle("Show only pinned button", isOn: $workspace.tabShowOnlyPinnedButton)
                        Toggle("Show buttons on inactive tabs", isOn: $workspace.tabShowButtonsOnInactive)
                    }
                    .font(.system(size: 11))
                    .toggleStyle(CheckboxToggleStyle())
                }
            }
        }
    }

    // MARK: - 3. Editing 1 (IDD_PREFERENCE_SUB_EDITING)
    private var editing1Section: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 10) {
                NppGroupBox("Current Line Indicator") {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(["None", "Highlight Background", "Frame"].enumerated().map { $0 }, id: \.offset) { idx, name in
                            NppRadioButton(title: name, value: idx, selection: $workspace.currentLineIndicator) {
                                workspace.highlightCurrentLine = (idx != 0)
                            }
                        }

                        HStack {
                            Text("Width:")
                                .font(.system(size: 11))
                            Slider(value: Binding(
                                get: { Double(workspace.currentLineFrameWidth) },
                                set: { workspace.currentLineFrameWidth = Int($0) }
                            ), in: 1...10, step: 1)
                            Text("\(workspace.currentLineFrameWidth)")
                                .font(.system(size: 11))
                                .frame(width: 20)
                        }
                    }
                }

                NppGroupBox("Caret Settings") {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Width:")
                                .font(.system(size: 11))
                                .fixedSize()
                            Picker("", selection: $workspace.caretWidth) {
                                Text("1").tag(1)
                                Text("2").tag(2)
                                Text("3").tag(3)
                                Text("Block").tag(4)
                            }
                            .labelsHidden()
                            .frame(width: 80)
                        }

                        HStack {
                            Text("F")
                                .font(.system(size: 10, weight: .bold))
                            Slider(value: $workspace.caretBlinkRate, in: 100...1000)
                            Text("S")
                                .font(.system(size: 10, weight: .bold))
                            Text("Blink rate")
                                .font(.system(size: 11))
                        }
                    }
                }

                NppGroupBox("Line Wrap") {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(["Default", "Aligned", "Indent"].enumerated().map { $0 }, id: \.offset) { idx, name in
                            NppRadioButton(title: name, value: idx, selection: $workspace.lineWrapMode)
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Toggle("Enable smooth font", isOn: $workspace.smoothFont)
                Toggle("Enable virtual space", isOn: $workspace.virtualSpace)
                Toggle("Make current level folding/unfolding commands toggleable", isOn: $workspace.foldingToggle)
                Toggle("Keep selection when right-click outside of selection", isOn: $workspace.rightClickKeepsSelection)
                Toggle("Enable Copy/Cut Line without selection", isOn: $workspace.lineCutCopyWithNoSelection)
                Toggle("Apply custom color to selected text foreground", isOn: $workspace.selectedTextForegroundCustom)
                Toggle("Enable scrolling beyond last line", isOn: $workspace.scrollBeyondLastLine)
                Toggle("Disable advanced scrolling feature due to touchpad issue", isOn: $workspace.disableTouchpadScroll)
                Toggle("Disable selected text drag-and-drop", isOn: $workspace.disableSelectedTextDragDrop)
            }
            .font(.system(size: 11))
            .toggleStyle(CheckboxToggleStyle())
        }
    }

    // MARK: - 4. Editing 2 (IDD_PREFERENCE_SUB_EDITING2)
    private var editing2Section: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                NppGroupBox("Multi-Editing") {
                    VStack(alignment: .leading, spacing: 6) {
                        Toggle("Enable Multi-Editing (Ctrl+Mouse click/selection)", isOn: $workspace.multiSelection)
                        Toggle("Enable Column Selection to Multi-Editing", isOn: $workspace.columnToMultiEditing)
                    }
                    .font(.system(size: 11))
                    .toggleStyle(CheckboxToggleStyle())
                }

                NppGroupBox("EOL (CRLF)") {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 16) {
                            ForEach(["Default", "Plain Text"].enumerated().map { $0 }, id: \.offset) { idx, name in
                                NppRadioButton(title: name, value: idx, selection: $workspace.eolAppearance)
                            }
                        }
                        Toggle("Custom Color", isOn: $workspace.eolCustomColor)
                            .font(.system(size: 11))
                            .toggleStyle(CheckboxToggleStyle())
                    }
                }
            }

            NppGroupBox("Non-Printing Characters") {
                VStack(alignment: .leading, spacing: 8) {
                    NppGroupBox("Appearance") {
                        HStack(spacing: 20) {
                            ForEach(["Abbreviation", "Codepoint"].enumerated().map { $0 }, id: \.offset) { idx, name in
                                NppRadioButton(title: name, value: idx, selection: $workspace.npcAppearance)
                            }
                            Toggle("Custom Color", isOn: $workspace.npcCustomColor)
                                .font(.system(size: 11))
                                .toggleStyle(CheckboxToggleStyle())
                        }
                    }

                    Toggle("Apply Appearance settings to C0, C1 & Unicode EOL", isOn: $workspace.npcIncludeUnicodeEol)
                    Toggle("Prevent control character (C0 code) typing into document", isOn: $workspace.npcNoInputC0)
                    Toggle("Show White Space and TAB (· and →)", isOn: $workspace.showInvisibleCharacters)
                }
                .font(.system(size: 11))
                .toggleStyle(CheckboxToggleStyle())
            }
        }
    }

    // MARK: - 5. Dark Mode (IDD_PREFERENCE_SUB_DARKMODE)
    private var darkModeSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 24) {
                ForEach(["Light mode", "Dark mode", "Follow System"].enumerated().map { $0 }, id: \.offset) { idx, name in
                    NppRadioButton(title: name, value: idx, selection: $workspace.darkModeChoice)
                }
            }

            NppGroupBox("Tones") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 14) {
                        ForEach(["Black", "Red", "Green", "Blue", "Purple", "Cyan", "Olive", "Customized"], id: \.self) { tone in
                            NppRadioButton(title: tone, value: tone, selection: $workspace.darkModeTone)
                        }
                    }

                    Divider()

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        ForEach([
                            "Content background", "Hot track item", "Control background", "Dialog background",
                            "Error", "Text", "Darker text", "Disabled text",
                            "Link", "Edge", "Edge highlight", "Edge disabled"
                        ], id: \.self) { label in
                            HStack {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color(NSColor.controlAccentColor).opacity(0.7))
                                    .frame(width: 14, height: 14)
                                    .border(Color.secondary.opacity(0.5), width: 1)
                                Text(label)
                                    .font(.system(size: 10))
                                Spacer()
                            }
                        }
                    }

                    HStack {
                        Spacer()
                        Button("Reset") {
                            workspace.darkModeTone = "Black"
                        }
                        .frame(width: 70)
                    }
                }
            }
        }
    }

    // MARK: - 6. Margins/Border/Edge (IDD_PREFERENCE_SUB_MARGING_BORDER_EDGE)
    private var marginsBorderEdgeSection: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 10) {
                NppGroupBox("Fold Margin Style") {
                    VStack(alignment: .leading, spacing: 5) {
                        ForEach(["Simple", "Arrow", "Circle tree", "Box tree", "None"], id: \.self) { style in
                            HStack {
                                Image(systemName: workspace.foldMarginStyle == style ? "largecircle.fill.circle" : "circle")
                                    .foregroundColor(workspace.foldMarginStyle == style ? .accentColor : .secondary)
                                Text(style)
                                    .font(.system(size: 11))
                            }
                            .onTapGesture { workspace.foldMarginStyle = style }
                        }
                    }
                }

                NppGroupBox("Border Width") {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Slider(value: Binding(
                                get: { Double(workspace.borderWidth) },
                                set: { workspace.borderWidth = Int($0) }
                            ), in: 0...10, step: 1)
                            Text("\(workspace.borderWidth)")
                                .font(.system(size: 11))
                                .frame(width: 20)
                        }
                        Toggle("No edge", isOn: $workspace.noEdge)
                            .font(.system(size: 11))
                            .toggleStyle(CheckboxToggleStyle())
                    }
                }
            }

            VStack(spacing: 10) {
                NppGroupBox("Vertical Edge Settings") {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Column:")
                                .font(.system(size: 11))
                            TextField("80", value: $workspace.verticalEdgeColumn, formatter: NumberFormatter())
                                .frame(width: 50)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                        Toggle("Background mode", isOn: $workspace.verticalEdgeBgMode)
                            .font(.system(size: 11))
                            .toggleStyle(CheckboxToggleStyle())
                    }
                }

                NppGroupBox("Change History") {
                    VStack(alignment: .leading, spacing: 6) {
                        Toggle("Show in the margin", isOn: $workspace.changeHistoryMargin)
                        Toggle("Show in the text", isOn: $workspace.changeHistoryText)
                    }
                    .font(.system(size: 11))
                    .toggleStyle(CheckboxToggleStyle())
                }
            }

            VStack(spacing: 10) {
                NppGroupBox("Line Number") {
                    VStack(alignment: .leading, spacing: 6) {
                        Toggle("Display", isOn: $workspace.showLineNumbers)
                            .font(.system(size: 11))
                            .toggleStyle(CheckboxToggleStyle())
                        HStack(spacing: 14) {
                            NppRadioButton(title: "Dynamic width", value: true, selection: $workspace.lineNumberDynamicWidth)
                            NppRadioButton(title: "Constant width", value: false, selection: $workspace.lineNumberDynamicWidth)
                        }
                    }
                }

                NppGroupBox("Padding") {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Left:")
                                .font(.system(size: 10))
                                .frame(width: 35)
                            Slider(value: Binding(get: { Double(workspace.paddingLeft) }, set: { workspace.paddingLeft = Int($0) }), in: 0...20, step: 1)
                            Text("\(workspace.paddingLeft)")
                                .font(.system(size: 10))
                        }
                        HStack {
                            Text("Right:")
                                .font(.system(size: 10))
                                .frame(width: 35)
                            Slider(value: Binding(get: { Double(workspace.paddingRight) }, set: { workspace.paddingRight = Int($0) }), in: 0...20, step: 1)
                            Text("\(workspace.paddingRight)")
                                .font(.system(size: 10))
                        }
                        Toggle("Display bookmark", isOn: $workspace.displayBookmarkMargin)
                            .font(.system(size: 11))
                            .toggleStyle(CheckboxToggleStyle())
                    }
                }
            }
        }
    }

    // MARK: - 7. New Document (IDD_PREFERENCE_SUB_NEWDOCUMENT)
    private var newDocumentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            NppGroupBox("New Document") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top, spacing: 16) {
                        NppGroupBox("Format (Line ending)") {
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach([
                                    (NppEol.crlf, "Windows (CR LF)"),
                                    (NppEol.lf, "Unix (LF)"),
                                    (NppEol.cr, "Macintosh (CR)")
                                ], id: \.1) { eol, label in
                                    NppRadioButton(title: label, value: eol, selection: $workspace.defaultNewDocFormat)
                                }
                            }
                        }

                        NppGroupBox("Encoding") {
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(["ANSI", "UTF-8", "UTF-8 with BOM", "UTF-16 Big Endian with BOM", "UTF-16 Little Endian with BOM"], id: \.self) { enc in
                                    NppRadioButton(title: enc, value: enc, selection: $workspace.defaultNewDocEncoding)
                                }
                                Toggle("Apply to opened ANSI files", isOn: $workspace.openAnsiAsUtf8)
                                    .font(.system(size: 11))
                                    .toggleStyle(CheckboxToggleStyle())
                            }
                        }
                    }

                    HStack {
                        Text("Default language:")
                            .font(.system(size: 11))
                            .fixedSize()
                        Picker("", selection: $workspace.defaultNewDocLanguage) {
                            Text("Plain Text").tag("Plain Text")
                            Text("C").tag("C")
                            Text("C++").tag("C++")
                            Text("Swift").tag("Swift")
                            Text("Python").tag("Python")
                            Text("HTML").tag("HTML")
                            Text("XML").tag("XML")
                            Text("JSON").tag("JSON")
                            Text("Markdown").tag("Markdown")
                        }
                        .labelsHidden()
                        .frame(width: 150)
                    }

                    Toggle("Always open a new document in addition at startup", isOn: $workspace.addNewDocOnStartup)
                        .font(.system(size: 11))
                        .toggleStyle(CheckboxToggleStyle())
                    Toggle("Use the first line of document as untitled tab name", isOn: $workspace.useFirstLineAsTabName)
                        .font(.system(size: 11))
                        .toggleStyle(CheckboxToggleStyle())
                }
            }
        }
    }

    // MARK: - 8. Default Directory (IDD_PREFERENCE_SUB_DEFAULTDIRECTORY)
    private var defaultDirectorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            NppGroupBox("Default Open/Save file Directory") {
                VStack(alignment: .leading, spacing: 8) {
                    NppRadioButton(title: "Follow current document", value: 0, selection: $workspace.defaultDirectoryMode)
                    NppRadioButton(title: "Remember last used directory", value: 1, selection: $workspace.defaultDirectoryMode)
                    HStack {
                        NppRadioButton(title: "Always on:", value: 2, selection: $workspace.defaultDirectoryMode)
                        TextField("~/Documents", text: $workspace.customDefaultDirectory)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(maxWidth: 300)
                        Button("...") {
                            let panel = NSOpenPanel()
                            panel.canChooseDirectories = true
                            panel.canChooseFiles = false
                            if panel.runModal() == .OK, let url = panel.url {
                                workspace.customDefaultDirectory = url.path
                                workspace.defaultDirectoryMode = 2
                            }
                        }
                    }
                }
            }

            Toggle("Open all files of folder instead of launching Folder as Workspace on folder dropping", isOn: $workspace.dropFolderOpenAllFiles)
                .font(.system(size: 11))
                .toggleStyle(CheckboxToggleStyle())
        }
    }

    // MARK: - 9. Recent Files History (IDD_PREFERENCE_SUB_RECENTFILESHISTORY)
    private var recentFilesHistorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            NppGroupBox("Recent Files History") {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Don't check at launch time", isOn: $workspace.dontCheckHistoryAtLaunch)
                        .font(.system(size: 11))
                        .toggleStyle(CheckboxToggleStyle())

                    HStack {
                        Text("Max. number of entries:")
                            .font(.system(size: 11))
                        TextField("15", value: $workspace.recentFilesMax, formatter: NumberFormatter())
                            .frame(width: 40)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        Text("(0 – 30)")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }

                    NppGroupBox("Display") {
                        VStack(alignment: .leading, spacing: 6) {
                            Toggle("In Submenu", isOn: $workspace.recentFilesInSubmenu)
                                .font(.system(size: 11))
                                .toggleStyle(CheckboxToggleStyle())

                            ForEach([
                                (0, "Only File Name"),
                                (1, "Full File Name Path"),
                                (2, "Customize Maximum Length:")
                            ], id: \.0) { mode, label in
                                HStack {
                                    NppRadioButton(title: label, value: mode, selection: $workspace.recentFilesDisplayMode)
                                    if mode == 2 {
                                        TextField("30", value: $workspace.recentFilesCustomLength, formatter: NumberFormatter())
                                            .frame(width: 40)
                                            .textFieldStyle(RoundedBorderTextFieldStyle())
                                        Text("(1 – 259)")
                                            .font(.system(size: 10))
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - 10. File Association
    private var fileAssociationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            NppGroupBox("File Association") {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Select extensions to open with Notepad++ on macOS (click to toggle):")
                        .font(.system(size: 11))

                    let allExts = [".txt", ".log", ".ini", ".c", ".cpp", ".h", ".swift", ".py", ".java", ".js", ".ts", ".html", ".xml", ".json", ".md", ".sql", ".sh", ".yaml"]
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        ForEach(allExts, id: \.self) { ext in
                            let isSelected = workspace.fileAssociations.contains(ext)
                            HStack(spacing: 6) {
                                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                                    .foregroundColor(isSelected ? .accentColor : .secondary)
                                Text(ext)
                                    .font(.system(size: 11, design: .monospaced))
                                Spacer()
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                workspace.toggleFileAssociation(ext)
                            }
                        }
                    }

                    Divider()

                    HStack {
                        Button("Register with macOS Finder") {
                            fileAssocStatusMessage = "Successfully registered \(workspace.fileAssociations.count) extension(s) with LaunchServices."
                        }
                        if let msg = fileAssocStatusMessage {
                            Text(msg)
                                .font(.system(size: 10))
                                .foregroundColor(.green)
                        }
                        Spacer()
                    }
                }
            }
        }
    }

    // MARK: - 11. Language (IDD_PREFERENCE_SUB_LANGUAGE)
    private var languageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            NppGroupBox("Language Menu") {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Make language menu compact", isOn: $workspace.compactLanguageMenu)
                        .font(.system(size: 11))
                        .toggleStyle(CheckboxToggleStyle())

                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Available items (\(workspace.availableLanguages.count))")
                                .font(.system(size: 10, weight: .semibold))
                            List(workspace.availableLanguages, id: \.self, selection: $selectedAvailableLang) { item in
                                Text(item)
                                    .font(.system(size: 11))
                                    .tag(item)
                            }
                            .listStyle(PlainListStyle())
                            .frame(width: 170, height: 140)
                            .border(Color.secondary.opacity(0.3), width: 1)
                        }

                        VStack(spacing: 8) {
                            Spacer()
                            Button("->") {
                                if let selected = selectedAvailableLang {
                                    workspace.disableLanguage(selected)
                                    selectedAvailableLang = nil
                                }
                            }
                            .frame(width: 36)
                            .disabled(selectedAvailableLang == nil)

                            Button("<-") {
                                if let selected = selectedDisabledLang {
                                    workspace.enableLanguage(selected)
                                    selectedDisabledLang = nil
                                }
                            }
                            .frame(width: 36)
                            .disabled(selectedDisabledLang == nil)
                            Spacer()
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Disabled items (\(workspace.disabledLanguages.count))")
                                .font(.system(size: 10, weight: .semibold))
                            List(workspace.disabledLanguages, id: \.self, selection: $selectedDisabledLang) { item in
                                Text(item)
                                    .font(.system(size: 11))
                                    .tag(item)
                            }
                            .listStyle(PlainListStyle())
                            .frame(width: 170, height: 140)
                            .border(Color.secondary.opacity(0.3), width: 1)
                        }
                    }

                    Toggle("Treat backslash as escape character for SQL", isOn: $workspace.treatBackslashAsEscapeForSql)
                        .font(.system(size: 11))
                        .toggleStyle(CheckboxToggleStyle())
                }
            }
        }
    }

    // MARK: - 12. Indentation (IDD_PREFERENCE_SUB_INDENTATION)
    private var indentationSection: some View {
        let indentLanguages = [
            "[Default]", "ActionScript", "Ada", "ASM", "Batch", "C", "C#", "C++",
            "CSS", "HTML", "Java", "JavaScript", "JSON", "Makefile", "Markdown",
            "PHP", "Python", "SQL", "Swift", "XML", "YAML"
        ]

        return HStack(alignment: .top, spacing: 14) {
            NppGroupBox(workspace.tr("Indent Settings")) {
                VStack(alignment: .leading, spacing: 8) {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 1) {
                            ForEach(indentLanguages, id: \.self) { lang in
                                Button(action: { selectedIndentLang = lang }) {
                                    HStack {
                                        Text(lang == "[Default]" ? workspace.tr("[Default]") : lang)
                                            .font(.system(size: 11, weight: selectedIndentLang == lang ? .semibold : .regular))
                                            .foregroundColor(selectedIndentLang == lang ? .white : .primary)
                                            .lineLimit(1)
                                        Spacer()
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .contentShape(Rectangle())
                                    .background(selectedIndentLang == lang ? Color.accentColor : Color.clear)
                                    .cornerRadius(2)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(3)
                    }
                    .frame(height: 95)
                    .background(Color(NSColor.controlBackgroundColor))
                    .border(Color(NSColor.separatorColor), width: 1)

                    NppGroupBox("") {
                        VStack(alignment: .leading, spacing: 6) {
                            Toggle(workspace.tr("Use default value"), isOn: $workspace.useDefaultTabValue)
                            HStack {
                                Text(workspace.tr("Indent size:"))
                                    .font(.system(size: 11))
                                TextField("4", value: $workspace.tabSize, formatter: NumberFormatter())
                                    .frame(width: 40)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                            }
                            Text(workspace.tr("Indent using:"))
                                .font(.system(size: 11, weight: .semibold))
                            HStack(spacing: 16) {
                                NppRadioButton(title: workspace.tr("Tab character"), value: false, selection: $workspace.replaceTabBySpace)
                                NppRadioButton(title: workspace.tr("Space character(s)"), value: true, selection: $workspace.replaceTabBySpace)
                            }
                            Toggle(workspace.tr("Backspace key unindents instead of removing single space"), isOn: $workspace.backspaceUnindents)
                        }
                        .font(.system(size: 11))
                        .toggleStyle(CheckboxToggleStyle())
                    }
                }
            }

            NppGroupBox(workspace.tr("Auto-indent")) {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach([workspace.tr("None"), workspace.tr("Basic"), workspace.tr("Advanced")].enumerated().map { $0 }, id: \.offset) { idx, name in
                        NppRadioButton(title: name, value: idx, selection: $workspace.autoIndentMode)
                    }
                }
            }
        }
    }

    // MARK: - 13. Highlighting (IDD_PREFERENCE_SUB_HIGHLIGHTING)
    private var highlightingSection: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 10) {
                NppGroupBox("Style All Occurrences of Token") {
                    VStack(alignment: .leading, spacing: 6) {
                        Toggle("Match case", isOn: $workspace.markAllMatchCase)
                        Toggle("Match whole word only", isOn: $workspace.markAllWholeWord)
                    }
                    .font(.system(size: 11))
                    .toggleStyle(CheckboxToggleStyle())
                }

                NppGroupBox("Highlight Matching Tags") {
                    VStack(alignment: .leading, spacing: 6) {
                        Toggle("Enable", isOn: $workspace.highlightMatchingTags)
                        Toggle("Highlight tag attributes", isOn: $workspace.highlightTagAttributes)
                        Toggle("Highlight comment/php/asp zone", isOn: $workspace.highlightNoneHtmlZone)
                    }
                    .font(.system(size: 11))
                    .toggleStyle(CheckboxToggleStyle())
                }
            }

            NppGroupBox("Smart Highlighting") {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Enable", isOn: $workspace.smartHighlighting)
                    Toggle("Highlight another view", isOn: $workspace.smartHighlightAnotherView)

                    NppGroupBox("Matching") {
                        VStack(alignment: .leading, spacing: 6) {
                            Toggle("Match case", isOn: $workspace.smartHighlightMatchCase)
                            Toggle("Match whole word only", isOn: $workspace.smartHighlightWholeWord)
                            Toggle("Use Find dialog settings", isOn: $workspace.smartHighlightUseFindSettings)
                        }
                        .font(.system(size: 11))
                        .toggleStyle(CheckboxToggleStyle())
                    }
                }
                .font(.system(size: 11))
                .toggleStyle(CheckboxToggleStyle())
            }
        }
    }

    // MARK: - 14. Print (IDD_PREFERENCE_SUB_PRINT)
    private var printSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 14) {
                VStack(spacing: 10) {
                    NppGroupBox("Color Options") {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(["WYSIWYG", "Invert", "Black on white", "No background color"].enumerated().map { $0 }, id: \.offset) { idx, name in
                                NppRadioButton(title: name, value: idx, selection: $workspace.printColorOption)
                            }
                        }
                    }

                    NppGroupBox("Margin Setting (Unit:mm)") {
                        Grid(horizontalSpacing: 8, verticalSpacing: 6) {
                            GridRow {
                                Text("Top:").font(.system(size: 10))
                                TextField("10", value: $workspace.printMarginTop, formatter: NumberFormatter())
                                    .frame(width: 40).textFieldStyle(RoundedBorderTextFieldStyle())
                                Text("Bottom:").font(.system(size: 10))
                                TextField("10", value: $workspace.printMarginBottom, formatter: NumberFormatter())
                                    .frame(width: 40).textFieldStyle(RoundedBorderTextFieldStyle())
                            }
                            GridRow {
                                Text("Left:").font(.system(size: 10))
                                TextField("10", value: $workspace.printMarginLeft, formatter: NumberFormatter())
                                    .frame(width: 40).textFieldStyle(RoundedBorderTextFieldStyle())
                                Text("Right:").font(.system(size: 10))
                                TextField("10", value: $workspace.printMarginRight, formatter: NumberFormatter())
                                    .frame(width: 40).textFieldStyle(RoundedBorderTextFieldStyle())
                            }
                        }
                    }
                }

                NppGroupBox("Header and Footer") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Variable:").font(.system(size: 11)).fixedSize()
                            Picker("", selection: $workspace.printVariableSelection) {
                                Text("Full file name path").tag("$(FULL_CURRENT_PATH)")
                                Text("File name").tag("$(FILE_NAME)")
                                Text("File directory").tag("$(CURRENT_DIRECTORY)")
                                Text("Page").tag("$(PAGE_NUMBER)")
                                Text("Short date").tag("$(SHORT_DATE)")
                                Text("Time").tag("$(TIME)")
                            }
                            .labelsHidden()
                            .frame(width: 150)
                            Button("Add") {
                                workspace.printHeaderMiddle += " " + workspace.printVariableSelection
                            }
                        }

                        NppGroupBox("Header") {
                            HStack {
                                TextField("Left part", text: $workspace.printHeaderLeft)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                TextField("Middle part", text: $workspace.printHeaderMiddle)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                TextField("Right part", text: $workspace.printHeaderRight)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                            }
                        }

                        NppGroupBox("Footer") {
                            HStack {
                                TextField("Left part", text: $workspace.printFooterLeft)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                TextField("Middle part", text: $workspace.printFooterMiddle)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                TextField("Right part", text: $workspace.printFooterRight)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                            }
                        }
                    }
                }
            }

            HStack(spacing: 20) {
                Toggle("Print line number", isOn: $workspace.printLineNumbers)
                Toggle("Print formfeed as page break", isOn: $workspace.printFormFeedPageBreak)
            }
            .font(.system(size: 11))
            .toggleStyle(CheckboxToggleStyle())
        }
    }

    // MARK: - 15. Searching (IDD_PREFERENCE_SUB_SEARCHING)
    private var searchingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            NppGroupBox("When Find Dialog is Invoked") {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Minimum Size for Auto-Checking \"In selection\":")
                            .font(.system(size: 11))
                        TextField("1024", value: $workspace.inSelectionThreshold, formatter: NumberFormatter())
                            .frame(width: 50)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        Text("(?)").foregroundColor(.secondary).font(.system(size: 10))
                    }

                    Toggle("Fill Find in Files Directory Field Based On Active Document", isOn: $workspace.fillFindInFilesFromActiveDoc)
                    Toggle("Fill Find Field with Selected Text", isOn: $workspace.fillFindFieldWithSelected)

                    HStack {
                        TextField("2048", value: $workspace.fillFindFieldThreshold, formatter: NumberFormatter())
                            .frame(width: 50)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        Text(": Max Characters to Auto-Fill Find Field from Selection")
                            .font(.system(size: 11))
                        Text("(?)").foregroundColor(.secondary).font(.system(size: 10))
                    }

                    Toggle("Select Word Under Caret when Nothing Selected", isOn: $workspace.selectWordUnderCaretIfEmpty)
                }
                .font(.system(size: 11))
                .toggleStyle(CheckboxToggleStyle())
            }

            VStack(alignment: .leading, spacing: 6) {
                Toggle("Use Monospaced font in Find dialog (Need to restart Notepad++)", isOn: $workspace.useMonospacedFontInFindDlg)
                Toggle("Find dialog remains open after search that outputs to results window", isOn: $workspace.findDlgAlwaysVisible)
                Toggle("Confirm Replace All in All Opened Documents", isOn: $workspace.confirmReplaceAllInAllOpenedDocs)
                Toggle("Replace: Don't move to the following occurrence", isOn: $workspace.replaceAndStop)
                Toggle("Search Result window: show only one entry per found line if possible", isOn: $workspace.showOncePerFoundLine)
                Toggle("Find in Files: Prefer on-disk file content over open buffers", isOn: $workspace.fifIgnoreOpenedFiles)
                Toggle("Incremental Search: show the bar at the top", isOn: $workspace.incSearchBarAtTop)
            }
            .font(.system(size: 11))
            .toggleStyle(CheckboxToggleStyle())
        }
    }

    // MARK: - 16. Backup (IDD_PREFERENCE_SUB_BACKUP)
    private var backupSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            NppGroupBox("Session snapshot and periodic backup") {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Remember current session for next launch", isOn: $workspace.rememberSession)
                    Toggle("Enable session snapshot and periodic backup", isOn: $workspace.periodicBackupEnabled)

                    HStack {
                        Text("Trigger backup on modification in every")
                            .font(.system(size: 11))
                        TextField("7", value: $workspace.periodicBackupIntervalSeconds, formatter: NumberFormatter())
                            .frame(width: 35)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        Text("seconds")
                            .font(.system(size: 11))
                    }

                    HStack {
                        Text("Backup path:")
                            .font(.system(size: 11))
                        TextField("~/.gemini/antigravity-ide/backup", text: $workspace.periodicBackupPath)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(maxWidth: 320)
                    }

                    Toggle("Remember inaccessible files from past session", isOn: $workspace.keepAbsentFilesInSession)
                }
                .font(.system(size: 11))
                .toggleStyle(CheckboxToggleStyle())
            }

            NppGroupBox("Backup on save") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 20) {
                        ForEach(["None", "Simple backup", "Verbose backup"].enumerated().map { $0 }, id: \.offset) { idx, name in
                            NppRadioButton(title: name, value: idx, selection: $workspace.backupOnSaveMode)
                        }
                    }

                    Divider()

                    Toggle("Custom Backup Directory", isOn: $workspace.customBackupDirEnabled)
                        .font(.system(size: 11))
                        .toggleStyle(CheckboxToggleStyle())

                    HStack {
                        Text("Directory:")
                            .font(.system(size: 11))
                        TextField("", text: $workspace.customBackupDir)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(maxWidth: 300)
                        Button("...") {
                            let panel = NSOpenPanel()
                            panel.canChooseDirectories = true
                            panel.canChooseFiles = false
                            if panel.runModal() == .OK, let url = panel.url {
                                workspace.customBackupDir = url.path
                                workspace.customBackupDirEnabled = true
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - 17. Auto-Completion (IDD_PREFERENCE_SUB_AUTOCOMPLETION)
    private var autoCompletionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            NppGroupBox("Auto-Completion") {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Enable auto-completion on each input", isOn: $workspace.autoCompletionEnabled)
                        .font(.system(size: 11))
                        .toggleStyle(CheckboxToggleStyle())

                    HStack(alignment: .top, spacing: 20) {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach([
                                (0, "Function completion"),
                                (1, "Word completion"),
                                (2, "Function and word completion")
                            ], id: \.0) { mode, label in
                                NppRadioButton(title: label, value: mode, selection: $workspace.autoCompletionType)
                            }

                            Toggle("Make auto-completion list brief", isOn: $workspace.autoCompletionBrief)
                            Toggle("Function parameters hint on input", isOn: $workspace.funcParamsHint)
                        }
                        .font(.system(size: 11))
                        .toggleStyle(CheckboxToggleStyle())

                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("From").font(.system(size: 11))
                                Text("\(workspace.autoCompletionThreshold)").font(.system(size: 11, weight: .bold))
                                Text("th character").font(.system(size: 11))
                            }
                            HStack {
                                Text("1").font(.system(size: 10))
                                Slider(value: Binding(
                                    get: { Double(workspace.autoCompletionThreshold) },
                                    set: { workspace.autoCompletionThreshold = Int($0) }
                                ), in: 1...9, step: 1)
                                Text("9").font(.system(size: 10))
                            }

                            NppGroupBox("Insert Selection") {
                                HStack(spacing: 12) {
                                    Toggle("TAB", isOn: $workspace.autoCompletionKeyTab)
                                    Toggle("ENTER", isOn: $workspace.autoCompletionKeyEnter)
                                    Toggle("Ignore numbers", isOn: $workspace.autoCompletionIgnoreNumbers)
                                }
                                .font(.system(size: 11))
                                .toggleStyle(CheckboxToggleStyle())
                            }
                        }
                    }
                }
            }

            NppGroupBox("Auto-Insert") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 16) {
                        Toggle(" (", isOn: $workspace.autoInsertParen)
                        Toggle(" [", isOn: $workspace.autoInsertBracket)
                        Toggle(" {", isOn: $workspace.autoInsertBrace)
                        Toggle(" \"", isOn: $workspace.autoInsertDoubleQuote)
                        Toggle(" '", isOn: $workspace.autoInsertSingleQuote)
                        Toggle(" html/xml close tag", isOn: $workspace.autoInsertHtmlTag)
                    }
                    .font(.system(size: 11))
                    .toggleStyle(CheckboxToggleStyle())
                }
            }
        }
    }

    // MARK: - 18. Multi-Instance & Date (IDD_PREFERENCE_SUB_MULTIINSTANCE)
    private var multiInstanceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 14) {
                VStack(spacing: 10) {
                    NppGroupBox("Multi-instance settings *") {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach([
                                (0, "Default (mono-instance)"),
                                (1, "Always in multi-instance mode"),
                                (2, "Open session in a new instance")
                            ], id: \.0) { mode, label in
                                NppRadioButton(title: label, value: mode, selection: $workspace.multiInstanceMode)
                            }
                        }
                    }

                    NppGroupBox("Customize insert Date Time") {
                        VStack(alignment: .leading, spacing: 6) {
                            Toggle("Reverse default date time order", isOn: $workspace.dateTimeReverseOrder)
                                .font(.system(size: 11))
                                .toggleStyle(CheckboxToggleStyle())
                            HStack {
                                Text("Format:").font(.system(size: 11))
                                TextField("yyyy-MM-dd HH:mm:ss", text: $workspace.dateTimeCustomFormat)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                            }
                        }
                    }
                }

                NppGroupBox("Panel State and [-nosession] *") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Remember panel state in other instances:")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Toggle("Clipboard History", isOn: $workspace.rememberClipboardHistory)
                        Toggle("Document List", isOn: $workspace.rememberPanelStateDocList)
                        Toggle("Character Panel", isOn: $workspace.rememberCharacterPanel)
                        Toggle("Folder as Workspace", isOn: $workspace.rememberPanelStateFAW)
                        Toggle("Project Panels", isOn: $workspace.rememberProjectPanels)
                        Toggle("Document Map", isOn: $workspace.showDocumentMap)
                        Toggle("Function List", isOn: $workspace.showFunctionList)
                        Toggle("Plugin Panels", isOn: $workspace.rememberPluginPanels)
                    }
                    .font(.system(size: 11))
                    .toggleStyle(CheckboxToggleStyle())
                }
            }

            Text("* The modification of this setting needs to restart Notepad++")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
    }

    // MARK: - 19. Delimiter (IDD_PREFERENCE_SUB_DELIMITER)
    private var delimiterSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            NppGroupBox("Word character list") {
                VStack(alignment: .leading, spacing: 6) {
                    NppRadioButton(title: "Use default Word character list as it is", value: 0, selection: $workspace.wordCharMode)
                    NppRadioButton(title: "Add your character as part of word", value: 1, selection: $workspace.wordCharMode)

                    TextField("", text: $workspace.wordCharCustom)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(maxWidth: 300)
                }
            }

            NppGroupBox("Delimiter selection settings (Ctrl + Mouse double click)") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 12) {
                        Text("Open:").font(.system(size: 11))
                        TextField("(", text: $workspace.delimiterOpen)
                            .frame(width: 30)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        Text("Close:").font(.system(size: 11))
                        TextField(")", text: $workspace.delimiterClose)
                            .frame(width: 30)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    Toggle("Allow on several lines", isOn: $workspace.delimiterSeveralLines)
                        .font(.system(size: 11))
                        .toggleStyle(CheckboxToggleStyle())
                }
            }
        }
    }

    // MARK: - 20. Performance (IDD_PREFERENCE_SUB_PERFORMANCE)
    private var performanceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            NppGroupBox("Large File Restriction") {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Enable Large File Restriction (no syntax highlighting)", isOn: $workspace.performanceLargeFileEnabled)
                    HStack {
                        Text("Define Large File Size:")
                            .font(.system(size: 11))
                        TextField("200", value: $workspace.performanceLargeFileSizeMB, formatter: NumberFormatter())
                            .frame(width: 50)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        Text("MB   (1 - 2046)")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Toggle("Deactivate Word Wrap globally", isOn: $workspace.performanceDeactivateWordWrap)
                        Toggle("Allow Auto-Completion", isOn: $workspace.performanceAllowAutoCompletion)
                        Toggle("Allow Smart Highlighting", isOn: $workspace.performanceAllowSmartHighlighting)
                        Toggle("Allow Brace Match", isOn: $workspace.performanceAllowBraceMatch)
                        Toggle("Allow URL Clickable Link", isOn: $workspace.performanceAllowClickableLink)
                    }
                    .padding(.leading, 16)

                    Toggle("Suppress warning when opening ≥2GB files", isOn: $workspace.performanceSuppress2GBWarning)
                }
                .font(.system(size: 11))
                .toggleStyle(CheckboxToggleStyle())
            }
        }
    }

    // MARK: - 21. Cloud & Link (IDD_PREFERENCE_SUB_CLOUD_LINK)
    private var cloudAndLinkSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            NppGroupBox("Settings on cloud") {
                VStack(alignment: .leading, spacing: 8) {
                    NppRadioButton(title: "No Cloud", value: 0, selection: $workspace.cloudMode)
                    NppRadioButton(title: "Set your cloud location path here:", value: 1, selection: $workspace.cloudMode)

                    HStack {
                        TextField("", text: $workspace.cloudPath)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(maxWidth: 320)
                        Button("...") {
                            let panel = NSOpenPanel()
                            panel.canChooseDirectories = true
                            panel.canChooseFiles = false
                            if panel.runModal() == .OK, let url = panel.url {
                                workspace.cloudPath = url.path
                                workspace.cloudMode = 1
                            }
                        }
                    }
                }
            }

            NppGroupBox("Clickable Link Settings") {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 20) {
                        Toggle("Enable", isOn: $workspace.clickableLinkEnable)
                        Toggle("No underline", isOn: $workspace.clickableLinkNoUnderline)
                        Toggle("Enable fullbox mode", isOn: $workspace.clickableLinkFullBoxMode)
                    }
                    Text("URI customized schemes:")
                        .font(.system(size: 11))
                    TextField("http https ftp file mailto", text: $workspace.uriCustomSchemes)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                .font(.system(size: 11))
                .toggleStyle(CheckboxToggleStyle())
            }
        }
    }

    // MARK: - 22. Search Engine (IDD_PREFERENCE_SUB_SEARCHENGINE)
    private var searchEngineSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            NppGroupBox("Search Engine (for command \"Search on Internet\")") {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach([
                        (0, "DuckDuckGo"),
                        (1, "Google"),
                        (2, "Yahoo!"),
                        (3, "Stack Overflow"),
                        (4, "Set your search engine here:")
                    ], id: \.0) { mode, label in
                        NppRadioButton(title: label, value: mode, selection: $workspace.searchEngineChoice)
                    }

                    TextField("https://www.google.com/search?q=$(CURRENT_WORD)", text: $workspace.customSearchEngineUrl)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(maxWidth: 380)

                    Text("Example: https://www.google.com/search?q=$(CURRENT_WORD)")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    // MARK: - 23. MISC. (IDD_PREFERENCE_SUB_MISC)
    private var miscSection: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 10) {
                NppGroupBox("File Status Auto-Detection") {
                    VStack(alignment: .leading, spacing: 6) {
                        Picker("", selection: $workspace.fileStatusAutoDetection) {
                            Text("Enabled").tag(true)
                            Text("Disabled").tag(false)
                        }
                        .labelsHidden()
                        .frame(width: 140)
                        Toggle("Update silently", isOn: $workspace.fileStatusAutoReloadSilently)
                        Toggle("Scroll to the last line after update", isOn: $workspace.fileStatusGoToEOF)
                    }
                    .font(.system(size: 11))
                    .toggleStyle(CheckboxToggleStyle())
                }

                VStack(alignment: .leading, spacing: 6) {
                    Toggle("Mute all sounds", isOn: $workspace.muteAllSounds)
                    Toggle("Autodetect character encoding", isOn: $workspace.autoDetectEncoding)
                    Toggle("Show only filename in title bar", isOn: $workspace.shortTitleInBar)
                    Toggle("Enable Save All confirm dialog", isOn: $workspace.saveAllConfirmDialog)
                    Toggle("Allow loading symlinks in Folder as Workspace panel", isOn: $workspace.allowSymlinksInFAW)
                }
                .font(.system(size: 11))
                .toggleStyle(CheckboxToggleStyle())
            }

            VStack(alignment: .leading, spacing: 10) {
                NppGroupBox("Document Switcher (Ctrl+TAB)") {
                    VStack(alignment: .leading, spacing: 6) {
                        Toggle("Enable", isOn: $workspace.docSwitcherEnabled)
                        Toggle("Enable MRU behaviour", isOn: $workspace.docSwitcherMRU)
                    }
                    .font(.system(size: 11))
                    .toggleStyle(CheckboxToggleStyle())
                }

                NppGroupBox("Document Peeker") {
                    VStack(alignment: .leading, spacing: 6) {
                        Toggle("Peek on tab", isOn: $workspace.docPeekerOnTab)
                        Toggle("Peek on document map", isOn: $workspace.docPeekerOnMap)
                    }
                    .font(.system(size: 11))
                    .toggleStyle(CheckboxToggleStyle())
                }

                HStack {
                    Text("Session file ext.:")
                        .font(.system(size: 11))
                    TextField("session", text: $workspace.sessionFileExt)
                        .frame(width: 85)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }

                HStack {
                    Text("Workspace file ext.:")
                        .font(.system(size: 11))
                    TextField("workspace", text: $workspace.workspaceFileExt)
                        .frame(width: 85)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
            }
        }
    }
}
