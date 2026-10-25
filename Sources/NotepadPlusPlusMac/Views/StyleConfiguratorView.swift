import SwiftUI
import AppKit

// MARK: - Authentic Notepad++ Style Configurator (matching upstream WordStyleDlg.rc IDD_STYLER_DLG & WordStyleDlg.cpp)
public struct NppStyleConfiguratorView: View {
    public static let themePickerWidth: CGFloat = 280

    @ObservedObject var workspace: NppWorkspace
    @Binding var isPresented: Bool

    @State private var selectedThemeId: String = "dark"
    @State private var selectedLanguage: String = "Global Styles"
    @State private var selectedStyle: String = "Default Style"

    // Font Style attributes
    @State private var selectedFontFamily: String = "Menlo"
    @State private var selectedFontSize: CGFloat = 13.0
    @State private var isBold: Bool = false
    @State private var isItalic: Bool = false
    @State private var isUnderline: Bool = false

    // Colour Style attributes
    @State private var fgColor: Color = .white
    @State private var bgColor: Color = .black

    // Language extensions & user keywords (WordStyleDlg.rc lines 39-43, 71-76)
    @State private var userExtensionText: String = ""
    @State private var userKeywordsText: String = ""
    @State private var showGlobalOverrideInfo: Bool = false
    @State private var isUpdatingFromSelection: Bool = false

    // Snapshot for Cancel revert (WordStyleDlg.cpp::prepare2Cancel / restoreGlobalOverrideValues)
    @State private var snapshotThemeId: String = "dark"
    @State private var snapshotFontFamily: String = "Menlo"
    @State private var snapshotFontSize: CGFloat = 13.0
    @State private var snapshotOverrides: [String: NppWorkspace.NppStyleOverride] = [:]
    @State private var snapshotGlobalFg: Bool = false
    @State private var snapshotGlobalBg: Bool = false
    @State private var snapshotGlobalFont: Bool = false
    @State private var snapshotGlobalFontSize: Bool = false
    @State private var snapshotGlobalBold: Bool = false
    @State private var snapshotGlobalItalic: Bool = false
    @State private var snapshotGlobalUnderline: Bool = false

    public static let fontSizes: [CGFloat] = [5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 16, 18, 20, 22, 24, 26, 28, 36]

    public let languages: [String] = [
        "Global Styles",
        "ActionScript", "Ada", "ASM", "Bash / Shell", "Batch",
        "C", "C#", "C++", "CMake", "COBOL", "CSS",
        "D", "Diff", "Fortran", "Go", "Haskell", "HTML",
        "INI file", "InnoSetup", "Java", "JavaScript", "JSON", "Kotlin",
        "LaTeX", "Lisp", "Lua", "Makefile", "Markdown", "Matlab",
        "Objective-C", "Pascal", "Perl", "PHP", "PowerShell", "Properties",
        "Python", "R", "Ruby", "Rust", "Scheme", "Smalltalk",
        "SQL", "Swift", "Tcl", "TeX", "TypeScript", "VB / VBS",
        "Verilog", "VHDL", "XML", "YAML"
    ]

    // Authentic 36 Global Styles from upstream stylers.model.xml
    public let globalStyles: [String] = [
        "Global override",
        "Default Style",
        "Indent guideline style",
        "Brace highlight style",
        "Bad brace colour",
        "Current line background colour",
        "Selected text colour",
        "Multi-selected text color",
        "Caret colour",
        "Multi-edit carets color",
        "Edge colour",
        "Line number margin",
        "Bookmark margin",
        "Change History margin",
        "Fold",
        "Fold active",
        "Fold margin",
        "White space symbol",
        "Smart Highlighting",
        "Find Mark Style",
        "Mark Style 1",
        "Mark Style 2",
        "Mark Style 3",
        "Mark Style 4",
        "Mark Style 5",
        "Incremental highlight all",
        "Tags match highlighting",
        "Tags attribute",
        "Active tab focused indicator",
        "Active tab unfocused indicator",
        "Active tab text",
        "Inactive tabs",
        "URL hovered",
        "Document map",
        "EOL custom color",
        "Non-printing characters custom color"
    ]

    // Authentic Lexer Styles from upstream stylers.model.xml
    public let languageStyles: [String] = [
        "DEFAULT",
        "INSTRUCTION WORD",
        "TYPE WORD",
        "NUMBER",
        "STRING",
        "CHARACTER",
        "OPERATOR",
        "PREPROCESSOR",
        "COMMENT",
        "COMMENT LINE",
        "COMMENT DOC",
        "FUNCTION",
        "USER KEYWORDS 1",
        "USER KEYWORDS 2",
        "USER KEYWORDS 3",
        "USER KEYWORDS 4"
    ]

    public init(workspace: NppWorkspace, isPresented: Binding<Bool>) {
        self.workspace = workspace
        self._isPresented = isPresented
    }

    private var currentStyles: [String] {
        selectedLanguage == "Global Styles" ? globalStyles : languageStyles
    }

    private var isKeywordStyle: Bool {
        guard selectedLanguage != "Global Styles" else { return false }
        return [
            "INSTRUCTION WORD", "TYPE WORD", "FUNCTION",
            "USER KEYWORDS 1", "USER KEYWORDS 2", "USER KEYWORDS 3", "USER KEYWORDS 4"
        ].contains(selectedStyle)
    }

    // Maps Global Styles to linked Preferences tab index (WordStyleDlg.cpp::updateGlobalOverrideCtrls / Go to settings)
    private var linkedPreferencesCategory: (tabIndex: Int, sectionName: String)? {
        guard selectedLanguage == "Global Styles" else { return nil }
        switch selectedStyle {
        case "Current line background colour", "Selected text colour", "Caret colour":
            return (3, "Editing 1")
        case "Multi-selected text color", "Multi-edit carets color", "White space symbol", "EOL custom color", "Non-printing characters custom color":
            return (4, "Editing 2")
        case "Edge colour", "Line number margin", "Bookmark margin", "Change History margin", "Fold", "Fold active", "Fold margin":
            return (6, "Margins/Border/Edge")
        case "Smart Highlighting", "Tags match highlighting", "Tags attribute":
            return (13, "Highlighting")
        case "Find Mark Style", "Incremental highlight all":
            return (15, "Searching")
        case "Active tab focused indicator", "Active tab unfocused indicator", "Active tab text", "Inactive tabs":
            return (2, "Tab Bar")
        case "URL hovered":
            return (21, "Cloud & Link")
        default:
            return nil
        }
    }

    public var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()
            HStack(alignment: .top, spacing: 12) {
                leftGroupBox
                rightGroupBox
            }
            .padding(12)
            Divider()
            footerBar
        }
        .frame(width: 800, height: 530)
        .background(Color(NSColor.windowBackgroundColor))
        .preferredColorScheme(workspace.currentTheme.isDark ? .dark : .light)
        .opacity(workspace.styleConfigTransparent ? (1.0 - workspace.styleConfigTransparencyPercent / 150.0) : 1.0)
        .onAppear {
            captureSnapshot()
            selectedThemeId = workspace.themeMode
            selectedFontFamily = workspace.fontFamily
            selectedFontSize = workspace.fontSize
            loadSelectedStyleAttributes()
        }
    }

    // MARK: - 1. Header & Select Theme Bar (WordStyleDlg.rc lines 27, 31-32)
    private var headerBar: some View {
        HStack(spacing: 14) {
            Text(workspace.tr("Style Configurator"))
                .font(.system(size: 13, weight: .semibold))
                .fixedSize()

            Spacer()

            HStack(spacing: 8) {
                Text(workspace.tr("Select theme :"))
                    .font(.system(size: 11, weight: .medium))
                    .fixedSize()

                Picker("", selection: $selectedThemeId) {
                    ForEach(NppTheme.allThemes, id: \.id) { t in
                        Text(t.name).tag(t.id)
                    }
                }
                .labelsHidden()
                .frame(width: NppStyleConfiguratorView.themePickerWidth)
                .onChange(of: selectedThemeId) { newId in
                    guard !isUpdatingFromSelection else { return }
                    workspace.themeMode = newId
                    loadSelectedStyleAttributes()
                }
            }

            Button(action: { cancelAndRevert() }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
                    .font(.system(size: 15))
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - 2. Left GroupBox: Language, Style & Extensions (WordStyleDlg.rc lines 33-43)
    private var leftGroupBox: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                languageListColumn
                styleListColumn
            }

            if selectedLanguage != "Global Styles" {
                extensionFieldsRow
            }
        }
        .padding(10)
        .frame(width: 345)
        .frame(maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.secondary.opacity(0.35), lineWidth: 1)
        )
    }

    private var languageListColumn: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(workspace.tr("Language :"))
                .font(.system(size: 11, weight: .semibold))
                .fixedSize()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 1) {
                    ForEach(languages, id: \.self) { lang in
                        Button(action: { selectLanguage(lang) }) {
                            HStack {
                                Text(lang)
                                    .font(.system(size: 11, weight: selectedLanguage == lang ? .semibold : .regular))
                                    .foregroundColor(selectedLanguage == lang ? .white : .primary)
                                    .lineLimit(1)
                                Spacer(minLength: 2)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(selectedLanguage == lang ? Color.accentColor : Color.clear)
                            .cornerRadius(3)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(3)
            }
            .frame(width: 130)
            .background(Color(NSColor.controlBackgroundColor))
            .border(Color(NSColor.separatorColor), width: 1)
        }
    }

    private var styleListColumn: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(workspace.tr("Style :"))
                .font(.system(size: 11, weight: .semibold))
                .fixedSize()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 1) {
                    ForEach(currentStyles, id: \.self) { st in
                        Button(action: { selectStyle(st) }) {
                            HStack {
                                Text(st)
                                    .font(.system(size: 11, weight: selectedStyle == st ? .semibold : .regular))
                                    .foregroundColor(selectedStyle == st ? .white : .primary)
                                    .lineLimit(1)
                                Spacer(minLength: 2)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(selectedStyle == st ? Color.accentColor : Color.clear)
                            .cornerRadius(3)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(3)
            }
            .frame(width: 185)
            .background(Color(NSColor.controlBackgroundColor))
            .border(Color(NSColor.separatorColor), width: 1)
        }
    }

    private var extensionFieldsRow: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                Text(workspace.tr("Default ext. :"))
                    .font(.system(size: 10, weight: .medium))
                    .fixedSize()
                TextField("", text: .constant(defaultExtensions(for: selectedLanguage)))
                    .font(.system(size: 11, design: .monospaced))
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .disabled(true)
            }
            .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 3) {
                Text(workspace.tr("User ext. :"))
                    .font(.system(size: 10, weight: .medium))
                    .fixedSize()
                TextField("", text: $userExtensionText)
                    .font(.system(size: 11, design: .monospaced))
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onChange(of: userExtensionText) { newVal in
                        workspace.styleUserExtensions[selectedLanguage] = newVal
                    }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.top, 2)
    }

    // MARK: - 3. Right GroupBox: Colour Style, Font Style & Dynamic Context Area (WordStyleDlg.rc lines 44-76)
    private var rightGroupBox: some View {
        VStack(alignment: .leading, spacing: 10) {
            styleDescriptionHeader

            HStack(alignment: .top, spacing: 10) {
                colourStyleGroupBox
                fontStyleGroupBox
            }

            dynamicContextArea
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.secondary.opacity(0.35), lineWidth: 1)
        )
    }

    private var styleDescriptionHeader: some View {
        HStack {
            Text("\(selectedLanguage) : \(selectedStyle)")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.primary)
                .lineLimit(1)
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(3)
        .overlay(
            RoundedRectangle(cornerRadius: 3)
                .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
        )
    }

    private var colourStyleGroupBox: some View {
        NppGroupBox(workspace.tr("Colour Style")) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(workspace.tr("Foreground colour"))
                        .font(.system(size: 11))
                        .fixedSize()
                    Spacer()
                    ColorPicker("", selection: $fgColor)
                        .labelsHidden()
                        .onChange(of: fgColor) { _ in
                            guard !isUpdatingFromSelection else { return }
                            commitCurrentStyleOverride()
                        }
                }

                HStack {
                    Text(workspace.tr("Background colour"))
                        .font(.system(size: 11))
                        .fixedSize()
                    Spacer()
                    ColorPicker("", selection: $bgColor)
                        .labelsHidden()
                        .onChange(of: bgColor) { _ in
                            guard !isUpdatingFromSelection else { return }
                            commitCurrentStyleOverride()
                        }
                }

                if let linked = linkedPreferencesCategory {
                    Divider()
                    HStack {
                        Spacer()
                        Button(action: {
                            isPresented = false
                            workspace.openPreferences(tab: linked.tabIndex)
                        }) {
                            Text(workspace.tr("Go to settings") + " ↗")
                                .font(.system(size: 10, weight: .medium))
                                .underline()
                                .foregroundColor(.accentColor)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help("Open Preferences > \(linked.sectionName)")
                    }
                }
            }
            .frame(minHeight: 74, alignment: .top)
        }
        .frame(width: 175)
    }

    private var fontStyleGroupBox: some View {
        NppGroupBox(workspace.tr("Font Style")) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Text(workspace.tr("Font name:"))
                        .font(.system(size: 11))
                        .fixedSize()
                        .frame(width: 65, alignment: .trailing)

                    Picker("", selection: $selectedFontFamily) {
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
                    .frame(maxWidth: .infinity)
                    .onChange(of: selectedFontFamily) { _ in
                        guard !isUpdatingFromSelection else { return }
                        commitCurrentStyleOverride()
                    }
                }

                HStack(spacing: 6) {
                    Text(workspace.tr("Font size:"))
                        .font(.system(size: 11))
                        .fixedSize()
                        .frame(width: 65, alignment: .trailing)

                    Picker("", selection: $selectedFontSize) {
                        ForEach(NppStyleConfiguratorView.fontSizes, id: \.self) { sz in
                            Text("\(Int(sz))").tag(sz)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 80)
                    .onChange(of: selectedFontSize) { _ in
                        guard !isUpdatingFromSelection else { return }
                        commitCurrentStyleOverride()
                    }

                    Spacer()
                }

                HStack(spacing: 12) {
                    Toggle(workspace.tr("Bold"), isOn: $isBold)
                        .font(.system(size: 11))
                        .toggleStyle(CheckboxToggleStyle())
                        .fixedSize()
                        .onChange(of: isBold) { _ in
                            guard !isUpdatingFromSelection else { return }
                            commitCurrentStyleOverride()
                        }

                    Toggle(workspace.tr("Italic"), isOn: $isItalic)
                        .font(.system(size: 11))
                        .toggleStyle(CheckboxToggleStyle())
                        .fixedSize()
                        .onChange(of: isItalic) { _ in
                            guard !isUpdatingFromSelection else { return }
                            commitCurrentStyleOverride()
                        }

                    Toggle(workspace.tr("Underline"), isOn: $isUnderline)
                        .font(.system(size: 11))
                        .toggleStyle(CheckboxToggleStyle())
                        .fixedSize()
                        .onChange(of: isUnderline) { _ in
                            guard !isUpdatingFromSelection else { return }
                            commitCurrentStyleOverride()
                        }
                }
                .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var dynamicContextArea: some View {
        if selectedLanguage == "Global Styles" && selectedStyle == "Global override" {
            globalOverrideSection
        } else if isKeywordStyle {
            keywordsSection
        } else {
            stylePreviewSection
        }
    }

    private var globalOverrideSection: some View {
        NppGroupBox("Global Override Options") {
            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Toggle(workspace.tr("Enable global foreground colour"), isOn: $workspace.globalOverrideFg)
                        Toggle(workspace.tr("Enable global background colour"), isOn: $workspace.globalOverrideBg)
                        Toggle(workspace.tr("Enable global font"), isOn: $workspace.globalOverrideFont)
                        Toggle(workspace.tr("Enable global font size"), isOn: $workspace.globalOverrideFontSize)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Toggle(workspace.tr("Enable global bold font style"), isOn: $workspace.globalOverrideBold)
                        Toggle(workspace.tr("Enable global italic font style"), isOn: $workspace.globalOverrideItalic)
                        Toggle(workspace.tr("Enable global underline font style"), isOn: $workspace.globalOverrideUnderline)

                        Button(action: { showGlobalOverrideInfo.toggle() }) {
                            Text(workspace.tr("What is Global override?"))
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.accentColor)
                                .underline()
                        }
                        .buttonStyle(PlainButtonStyle())
                        .popover(isPresented: $showGlobalOverrideInfo) {
                            Text("Enabling any of the options here will override that style attribute on ALL styles in all languages.\n\nTo change the default editor colors while keeping syntax highlighting intact, modify 'Global Styles > Default Style' instead.")
                                .font(.system(size: 11))
                                .padding(10)
                                .frame(width: 280)
                        }
                    }
                }
                .font(.system(size: 11))
                .toggleStyle(CheckboxToggleStyle())
            }
        }
    }

    private var keywordsSection: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(workspace.tr("Default keywords"))
                    .font(.system(size: 11, weight: .semibold))
                    .fixedSize()
                ScrollView {
                    Text(defaultKeywords(for: selectedLanguage, style: selectedStyle))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(6)
                }
                .frame(height: 115)
                .background(Color(NSColor.controlBackgroundColor))
                .border(Color(NSColor.separatorColor), width: 1)
            }
            .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 4) {
                Text(workspace.tr("User-defined keywords"))
                    .font(.system(size: 11, weight: .semibold))
                    .fixedSize()
                TextEditor(text: $userKeywordsText)
                    .font(.system(size: 11, design: .monospaced))
                    .frame(height: 115)
                    .border(Color(NSColor.separatorColor), width: 1)
                    .onChange(of: userKeywordsText) { newVal in
                        workspace.styleUserKeywords["\(selectedLanguage)|\(selectedStyle)"] = newVal
                    }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var stylePreviewSection: some View {
        NppGroupBox(workspace.tr("Style Preview")) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Spacer()
                    Text("The quick brown fox jumps over the lazy dog. 다람쥐 헌 쳇바퀴에 타고파. 0123456789")
                        .font(Font(NppWorkspace.resolveFont(name: selectedFontFamily, size: selectedFontSize, bold: isBold, italic: isItalic)))
                        .underline(isUnderline)
                        .foregroundColor(fgColor)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .background(bgColor)
                        .cornerRadius(4)
                    Spacer()
                }
                Text("Live preview is automatically applied to the active editor. Click 'Save & Close' to keep changes or 'Cancel' to revert.")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - 4. Footer Bar: Transparency + Save & Close + Cancel (WordStyleDlg.rc lines 78-82)
    private var footerBar: some View {
        HStack(spacing: 12) {
            Toggle(workspace.tr("Transparency"), isOn: $workspace.styleConfigTransparent)
                .font(.system(size: 11))
                .toggleStyle(CheckboxToggleStyle())
                .fixedSize()

            Slider(value: $workspace.styleConfigTransparencyPercent, in: 10...80)
                .frame(width: 110)
                .disabled(!workspace.styleConfigTransparent)

            Spacer()

            Button(workspace.tr("Save & Close")) {
                commitCurrentStyleOverride()
                isPresented = false
            }
            .keyboardShortcut(.defaultAction)

            Button(workspace.tr("Cancel")) {
                cancelAndRevert()
            }
            .keyboardShortcut(.cancelAction)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Selection & Live Preview Helpers
    private func selectLanguage(_ lang: String) {
        selectedLanguage = lang
        userExtensionText = workspace.styleUserExtensions[lang] ?? ""
        if lang == "Global Styles" {
            selectedStyle = "Default Style"
        } else {
            selectedStyle = "INSTRUCTION WORD"
        }
        loadSelectedStyleAttributes()
    }

    private func selectStyle(_ style: String) {
        selectedStyle = style
        userKeywordsText = workspace.styleUserKeywords["\(selectedLanguage)|\(style)"] ?? ""
        loadSelectedStyleAttributes()
    }

    private func captureSnapshot() {
        snapshotThemeId = workspace.themeMode
        snapshotFontFamily = workspace.fontFamily
        snapshotFontSize = workspace.fontSize
        snapshotOverrides = workspace.styleOverrides
        snapshotGlobalFg = workspace.globalOverrideFg
        snapshotGlobalBg = workspace.globalOverrideBg
        snapshotGlobalFont = workspace.globalOverrideFont
        snapshotGlobalFontSize = workspace.globalOverrideFontSize
        snapshotGlobalBold = workspace.globalOverrideBold
        snapshotGlobalItalic = workspace.globalOverrideItalic
        snapshotGlobalUnderline = workspace.globalOverrideUnderline
    }

    private func cancelAndRevert() {
        isUpdatingFromSelection = true
        workspace.styleOverrides = snapshotOverrides
        workspace.globalOverrideFg = snapshotGlobalFg
        workspace.globalOverrideBg = snapshotGlobalBg
        workspace.globalOverrideFont = snapshotGlobalFont
        workspace.globalOverrideFontSize = snapshotGlobalFontSize
        workspace.globalOverrideBold = snapshotGlobalBold
        workspace.globalOverrideItalic = snapshotGlobalItalic
        workspace.globalOverrideUnderline = snapshotGlobalUnderline
        workspace.fontFamily = snapshotFontFamily
        workspace.fontSize = snapshotFontSize
        workspace.themeMode = snapshotThemeId
        workspace.updateEditorFonts()
        workspace.updateThemeAppearance()
        isUpdatingFromSelection = false
        isPresented = false
    }

    private func loadSelectedStyleAttributes() {
        isUpdatingFromSelection = true
        defer { isUpdatingFromSelection = false }

        let baseTheme = NppTheme.theme(withId: selectedThemeId)
        let key = workspace.styleOverrideKey(themeId: selectedThemeId, language: selectedLanguage, style: selectedStyle)
        let override = workspace.styleOverrides[key]

        let (defaultFg, defaultBg) = defaultColorsForStyle(theme: baseTheme, language: selectedLanguage, style: selectedStyle)
        fgColor = Color(override?.fgColor ?? defaultFg)
        bgColor = Color(override?.bgColor ?? defaultBg)

        selectedFontFamily = override?.fontFamily ?? workspace.fontFamily
        selectedFontSize = override?.fontSize ?? workspace.fontSize
        isBold = override?.isBold ?? (selectedStyle == "INSTRUCTION WORD" || selectedStyle == "Brace highlight style")
        isItalic = override?.isItalic ?? (selectedStyle.contains("COMMENT"))
        isUnderline = override?.isUnderline ?? false

        userExtensionText = workspace.styleUserExtensions[selectedLanguage] ?? ""
        userKeywordsText = workspace.styleUserKeywords["\(selectedLanguage)|\(selectedStyle)"] ?? ""
    }

    private func commitCurrentStyleOverride() {
        let key = workspace.styleOverrideKey(themeId: selectedThemeId, language: selectedLanguage, style: selectedStyle)
        workspace.styleOverrides[key] = NppWorkspace.NppStyleOverride(
            fgColor: NSColor(fgColor),
            bgColor: NSColor(bgColor),
            fontFamily: selectedFontFamily,
            fontSize: selectedFontSize,
            isBold: isBold,
            isItalic: isItalic,
            isUnderline: isUnderline
        )
        if selectedLanguage == "Global Styles" && (selectedStyle == "Default Style" || selectedStyle == "Global override") {
            workspace.fontFamily = selectedFontFamily
            workspace.fontSize = selectedFontSize
            workspace.updateEditorFonts()
        }
        workspace.updateThemeAppearance()
    }

    private func defaultColorsForStyle(theme: NppTheme, language: String, style: String) -> (NSColor, NSColor) {
        if language == "Global Styles" {
            switch style {
            case "Line number margin", "Bookmark margin", "Fold margin":
                return (theme.gutterForeground, theme.gutterBackground)
            case "Current line background colour":
                return (theme.foregroundColor, theme.activeLineColor)
            case "Selected text colour":
                return (theme.foregroundColor, theme.selectionColor)
            case "Brace highlight style":
                return (theme.keywordColor, theme.backgroundColor)
            default:
                return (theme.foregroundColor, theme.backgroundColor)
            }
        } else {
            switch style {
            case "INSTRUCTION WORD", "TYPE WORD", "PREPROCESSOR":
                return (theme.keywordColor, theme.backgroundColor)
            case "STRING", "CHARACTER":
                return (theme.stringColor, theme.backgroundColor)
            case "COMMENT", "COMMENT LINE", "COMMENT DOC":
                return (theme.commentColor, theme.backgroundColor)
            case "NUMBER":
                return (theme.numberColor, theme.backgroundColor)
            default:
                return (theme.foregroundColor, theme.backgroundColor)
            }
        }
    }

    private func defaultExtensions(for language: String) -> String {
        switch language {
        case "C": return "c h"
        case "C++": return "cpp cxx cc hpp hxx hh inl"
        case "C#": return "cs"
        case "Swift": return "swift"
        case "Objective-C": return "m mm h"
        case "Python": return "py pyw pyi"
        case "Java": return "java"
        case "JavaScript": return "js mjs cjs jsx"
        case "TypeScript": return "ts tsx"
        case "HTML": return "html htm shtml xhtml"
        case "XML": return "xml xaml xsl xslt xsd svg plist"
        case "JSON": return "json jsonc"
        case "CSS": return "css scss less"
        case "PHP": return "php php3 phtml inc"
        case "Rust": return "rs"
        case "Go": return "go"
        case "SQL": return "sql"
        case "Bash / Shell": return "sh bash zsh ksh csh"
        case "Markdown": return "md markdown"
        case "YAML": return "yml yaml"
        case "INI file": return "ini inf cfg conf"
        case "Makefile": return "mak mk"
        case "CMake": return "cmake"
        case "Lua": return "lua"
        case "Perl": return "pl pm plx"
        case "Ruby": return "rb rbw"
        case "Kotlin": return "kt kts"
        default: return language.lowercased()
        }
    }

    private func defaultKeywords(for language: String, style: String) -> String {
        switch (language, style) {
        case ("Swift", "INSTRUCTION WORD"):
            return "actor any as associatedtype async await break case catch class continue convenience default defer deinit do else enum extension fallthrough false fileprivate final for func get guard if import in indirect infix init inout internal is isolated lazy let macro mutating nil nonisolated nonmutating open operator optional override package prefix private protocol public repeat required rethrows return self Self set some static struct subscript super switch throw throws true try typealias unowned var weak where while"
        case ("Swift", "TYPE WORD"):
            return "Any AnyObject Array Bool Character ClosedRange Codable Collection Comparable Data Date Decimal Decoder Dictionary Double Encodable Encoder Error Float Hashable Identifiable Index Int Int8 Int16 Int32 Int64 Never Optional Range Result Set Slice StaticString CodingKey String Substring Tuple UInt UInt8 UInt16 UInt32 UInt64 URL UUID Void"
        case ("C", "INSTRUCTION WORD"), ("C++", "INSTRUCTION WORD"):
            return "alignas alignof and and_eq asm auto bitand bitor break case catch class compl concept const consteval constexpr constinit const_cast continue co_await co_return co_yield decltype default delete do dynamic_cast else enum explicit export extern false final for friend goto if inline mutable namespace new noexcept not not_eq nullptr operator or or_eq override private protected public register reinterpret_cast requires return sizeof static static_assert static_cast struct switch template this thread_local throw true try typedef typeid typename union unsigned using virtual void volatile wchar_t while xor xor_eq"
        case ("C", "TYPE WORD"), ("C++", "TYPE WORD"):
            return "bool char char8_t char16_t char32_t double float int int8_t int16_t int32_t int64_t long ptrdiff_t short signed size_t std string uint8_t uint16_t uint32_t uint64_t uintptr_t vector void wchar_t"
        case ("Python", "INSTRUCTION WORD"):
            return "False None True and as assert async await break class continue def del elif else except finally for from global if import in is lambda nonlocal not or pass raise return try while with yield"
        case ("JavaScript", "INSTRUCTION WORD"), ("TypeScript", "INSTRUCTION WORD"):
            return "async await break case catch class const continue debugger default delete do else export extends false finally for from function get if import in instanceof interface let new null of package private protected public return set static super switch this throw true try typeof undefined var void while with yield"
        default:
            if style.hasPrefix("USER KEYWORDS") {
                return ""
            }
            return "abstract assert boolean break byte case catch char class const continue default do double else enum export extends false final finally float for function goto if implements import in instanceof int interface let long native new null package private protected public return short static strictfp super switch synchronized this throw throws transient true try typeof var void volatile while with yield"
        }
    }
}
