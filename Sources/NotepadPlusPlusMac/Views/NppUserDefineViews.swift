import AppKit
import SwiftUI

// MARK: - Color Hex Conversion Extensions
public extension Color {
    init(hexRGB: String, defaultColor: Color = .primary) {
        let clean = hexRGB.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard clean.count == 6, let intVal = Int(clean, radix: 16) else {
            self = defaultColor
            return
        }
        let r = Double((intVal >> 16) & 0xFF) / 255.0
        let g = Double((intVal >> 8) & 0xFF) / 255.0
        let b = Double(intVal & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }

    func toHexRGB() -> String {
        let nsColor = NSColor(self).usingColorSpace(.deviceRGB) ?? NSColor.black
        let r = Int(round(nsColor.redComponent * 255.0))
        let g = Int(round(nsColor.greenComponent * 255.0))
        let b = Int(round(nsColor.blueComponent * 255.0))
        return String(format: "%02X%02X%02X", max(0, min(255, r)), max(0, min(255, g)), max(0, min(255, b)))
    }
}

public extension NSColor {
    convenience init?(hexRGB: String) {
        let clean = hexRGB.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard clean.count == 6, let intVal = Int(clean, radix: 16) else { return nil }
        self.init(calibratedRed: CGFloat((intVal >> 16) & 0xFF) / 255.0,
                  green: CGFloat((intVal >> 8) & 0xFF) / 255.0,
                  blue: CGFloat(intVal & 0xFF) / 255.0, alpha: 1.0)
    }

    func toHexRGB() -> String {
        let rgb = self.usingColorSpace(.deviceRGB) ?? self
        let r = Int(round(rgb.redComponent * 255.0))
        let g = Int(round(rgb.greenComponent * 255.0))
        let b = Int(round(rgb.blueComponent * 255.0))
        return String(format: "%02X%02X%02X", max(0, min(255, r)), max(0, min(255, g)), max(0, min(255, b)))
    }
}

// MARK: - UDL Styler Target & Color Swatch
public struct UDLStylerTarget: Identifiable {
    public var id: String { styleName }
    public let styleName: String
    public let displayName: String
    public let supportsNesting: Bool

    public init(styleName: String, displayName: String, supportsNesting: Bool = false) {
        self.styleName = styleName
        self.displayName = displayName
        self.supportsNesting = supportsNesting
    }
}

public struct UDLColorSwatch: View {
    public let fgHex: String?
    public let bgHex: String?
    public let fontStyle: Int
    public let action: () -> Void

    public init(fgHex: String?, bgHex: String?, fontStyle: Int, action: @escaping () -> Void) {
        self.fgHex = fgHex
        self.bgHex = bgHex
        self.fontStyle = fontStyle
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            let fg = fgHex.flatMap { NSColor(hexRGB: $0) }.map { Color($0) } ?? Color.primary
            let bg = bgHex.flatMap { NSColor(hexRGB: $0) }.map { Color($0) } ?? Color(NSColor.controlBackgroundColor)
            let isBold = (fontStyle & 1) != 0
            let isItalic = (fontStyle & 2) != 0
            let isUnderline = (fontStyle & 4) != 0

            ZStack {
                RoundedRectangle(cornerRadius: 3)
                    .fill(bg)
                RoundedRectangle(cornerRadius: 3)
                    .stroke(Color.secondary.opacity(0.5), lineWidth: 1)
                Text("Aa")
                    .font(.system(size: 10, weight: isBold ? .bold : .regular))
                    .italic(isItalic)
                    .underline(isUnderline)
                    .foregroundColor(fg)
            }
            .frame(width: 32, height: 18)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - User Defined Language Dialog View (Notepad++ UserDefineDialog parity)
public struct NppUserDefineDialogView: View {
    @ObservedObject public var workspace: NppWorkspace
    public let onClose: () -> Void

    @State private var selectedLanguageIndex: Int = 0
    @State private var currentLanguageName: String = "User-Defined"
    @State private var currentExtensions: String = ""
    @State private var ignoreCase: Bool = true
    @State private var selectedTab: Int = 0

    // Styler Sheet presentation
    @State private var activeStylerTarget: UDLStylerTarget? = nil

    // Floating window transparency
    @State private var isTransparentChecked: Bool = false
    @State private var windowOpacity: Double = 1.0

    public init(workspace: NppWorkspace, onClose: @escaping () -> Void) {
        self.workspace = workspace
        self.onClose = onClose
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header: User Language Picker & Management Buttons
            headerView

            // Options: Ignore case & Extensions & Transparency
            optionsView

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
            .frame(minHeight: 220)

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
        .padding(12)
        .frame(minWidth: 580, minHeight: 440)
        .sheet(item: $activeStylerTarget) { target in
            NppUDLStylerSheet(
                target: target,
                workspace: workspace,
                languageIndex: selectedLanguageIndex > 0 ? selectedLanguageIndex - 1 : -1,
                onDismiss: {
                    activeStylerTarget = nil
                }
            )
        }
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
    }

    // MARK: - Header & Sub-views
    private var headerView: some View {
        HStack(spacing: 6) {
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

            Button(workspace.isUserDefineDialogDocked ? workspace.tr("Undock") : workspace.tr("Dock")) {
                workspace.isUserDefineDialogDocked.toggle()
                if workspace.isUserDefineDialogDocked {
                    NppUserDefineWindowController.shared.hideFloatingPanelOnly()
                } else {
                    NppUserDefineWindowController.shared.show(workspace: workspace)
                }
            }
            .font(.system(size: 11))

            Button(workspace.tr("Create New...")) {
                createNewLanguage()
            }
            .font(.system(size: 11))

            Button(workspace.tr("Save As...")) {
                saveAsNewLanguage()
            }
            .font(.system(size: 11))

            if selectedLanguageIndex > 0 {
                Button(workspace.tr("Rename")) {
                    renameLanguage()
                }
                .font(.system(size: 11))

                Button(workspace.tr("Remove")) {
                    removeLanguage()
                }
                .font(.system(size: 11))
            }

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
    }

    private var optionsView: some View {
        HStack(spacing: 16) {
            Toggle(workspace.tr("Ignore case"), isOn: $ignoreCase)
                .font(.system(size: 11))
                .toggleStyle(CheckboxToggleStyle())

            if selectedLanguageIndex > 0 {
                HStack(spacing: 4) {
                    Text(workspace.tr("Ext. :"))
                        .font(.system(size: 11))
                    TextField("txt udl", text: $currentExtensions)
                        .font(.system(size: 11, design: .monospaced))
                        .frame(width: 120)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
            }

            if !workspace.isUserDefineDialogDocked {
                HStack(spacing: 6) {
                    Toggle("Transparency", isOn: $isTransparentChecked)
                        .font(.system(size: 11))
                        .toggleStyle(CheckboxToggleStyle())
                        .onChange(of: isTransparentChecked) { checked in
                            if let panel = NppUserDefineWindowController.shared.panel {
                                panel.alphaValue = checked ? CGFloat(windowOpacity) : 1.0
                            }
                        }

                    if isTransparentChecked {
                        Slider(value: $windowOpacity, in: 0.3...1.0)
                            .frame(width: 80)
                            .onChange(of: windowOpacity) { val in
                                NppUserDefineWindowController.shared.panel?.alphaValue = CGFloat(val)
                            }
                    }
                }
            }
        }
    }

    // MARK: - Tab 1: Folder & Default
    private var folderAndDefaultTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                // Online Help Link
                HStack {
                    Link(workspace.tr("User Defined Languages online help"),
                         destination: URL(string: "https://npp-user-manual.org/docs/user-defined-language-system/")!)
                        .font(.system(size: 11))
                    Spacer()
                }
                .padding(.bottom, 2)

                // Default Style Group
                GroupBox(label: Text("Default style").font(.system(size: 11, weight: .semibold))) {
                    HStack(spacing: 16) {
                        stylerRow(name: "DEFAULT", displayName: "Default Style")
                        Toggle("Fold compact (fold empty lines too)", isOn: foldCompactBinding)
                            .font(.system(size: 11))
                            .toggleStyle(CheckboxToggleStyle())
                            .disabled(selectedLanguageIndex == 0)
                        Spacer()
                    }
                    .padding(6)
                }

                // Folding in code 1
                GroupBox(label: Text("Folding in code 1 style").font(.system(size: 11, weight: .semibold))) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            stylerRow(name: "FOLDER IN CODE1", displayName: "Folder in code 1")
                            Spacer()
                        }
                        HStack(spacing: 12) {
                            fieldWithLabel("Open :", text: keywordBinding("Folders in code1, open"), placeholder: "{ ( begin [")
                            fieldWithLabel("Middle :", text: keywordBinding("Folders in code1, middle"), placeholder: "else elsif case")
                            fieldWithLabel("Close :", text: keywordBinding("Folders in code1, close"), placeholder: "} ) end ]")
                        }
                    }
                    .padding(6)
                }

                // Folding in code 2
                GroupBox(label: Text("Folding in code 2 style (separators needed)").font(.system(size: 11, weight: .semibold))) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            stylerRow(name: "FOLDER IN CODE2", displayName: "Folder in code 2")
                            Spacer()
                        }
                        HStack(spacing: 12) {
                            fieldWithLabel("Open :", text: keywordBinding("Folders in code2, open"), placeholder: "region start")
                            fieldWithLabel("Middle :", text: keywordBinding("Folders in code2, middle"), placeholder: "")
                            fieldWithLabel("Close :", text: keywordBinding("Folders in code2, close"), placeholder: "endregion finish")
                        }
                    }
                    .padding(6)
                }

                // Folding in comment
                GroupBox(label: Text("Folding in comment style").font(.system(size: 11, weight: .semibold))) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            stylerRow(name: "FOLDER IN COMMENT", displayName: "Folder in comment")
                            Spacer()
                        }
                        HStack(spacing: 12) {
                            fieldWithLabel("Open :", text: keywordBinding("Folders in comment, open"), placeholder: "#region")
                            fieldWithLabel("Middle :", text: keywordBinding("Folders in comment, middle"), placeholder: "")
                            fieldWithLabel("Close :", text: keywordBinding("Folders in comment, close"), placeholder: "#endregion")
                        }
                    }
                    .padding(6)
                }
            }
            .padding(4)
        }
    }

    // MARK: - Tab 2: Keywords Lists
    private var keywordsListTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(1...8, id: \.self) { group in
                    let ordinal = groupOrdinal(group)
                    GroupBox(label: Text("\(ordinal) group").font(.system(size: 11, weight: .semibold))) {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 12) {
                                stylerRow(name: "KEYWORDS\(group)", displayName: "\(ordinal) Group Keywords")
                                Toggle("Prefix Mode", isOn: prefixBinding("Keywords\(group)"))
                                    .font(.system(size: 11))
                                    .toggleStyle(CheckboxToggleStyle())
                                    .disabled(selectedLanguageIndex == 0)
                                Spacer()
                            }
                            TextField("space separated keywords or \"quoted strings\"", text: keywordBinding("Keywords\(group)"))
                                .font(.system(size: 11, design: .monospaced))
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .disabled(selectedLanguageIndex == 0)
                        }
                        .padding(6)
                    }
                }
            }
            .padding(4)
        }
    }

    // MARK: - Tab 3: Comment & Number
    private var commentAndNumberTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                // Line comment position & folding
                GroupBox(label: Text("Line comment position & folding").font(.system(size: 11, weight: .semibold))) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 16) {
                            Picker("Position:", selection: forcePureLCBinding) {
                                Text("Allow anywhere").tag(0)
                                Text("Force at beginning of line").tag(1)
                                Text("Allow preceding whitespace").tag(2)
                            }
                            .pickerStyle(RadioGroupPickerStyle())
                            .disabled(selectedLanguageIndex == 0)

                            Toggle("Allow folding of comments", isOn: allowFoldOfCommentsBinding)
                                .font(.system(size: 11))
                                .toggleStyle(CheckboxToggleStyle())
                                .disabled(selectedLanguageIndex == 0)
                        }
                    }
                    .padding(6)
                }

                // Line comment style
                GroupBox(label: Text("Comment line style").font(.system(size: 11, weight: .semibold))) {
                    VStack(alignment: .leading, spacing: 6) {
                        stylerRow(name: "LINE COMMENTS", displayName: "Line Comment Style", supportsNesting: true)
                        HStack(spacing: 12) {
                            fieldWithLabel("Open :", text: commentTokenBinding(0), placeholder: "//")
                            fieldWithLabel("Continue char :", text: commentTokenBinding(1), placeholder: "\\")
                            fieldWithLabel("Close :", text: commentTokenBinding(2), placeholder: "((EOL))")
                        }
                    }
                    .padding(6)
                }

                // Block comment style
                GroupBox(label: Text("Comment style").font(.system(size: 11, weight: .semibold))) {
                    VStack(alignment: .leading, spacing: 6) {
                        stylerRow(name: "COMMENTS", displayName: "Block Comment Style", supportsNesting: true)
                        HStack(spacing: 12) {
                            fieldWithLabel("Open :", text: commentTokenBinding(3), placeholder: "/*")
                            fieldWithLabel("Close :", text: commentTokenBinding(4), placeholder: "*/")
                        }
                    }
                    .padding(6)
                }

                // Number style
                GroupBox(label: Text("Number style").font(.system(size: 11, weight: .semibold))) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 16) {
                            stylerRow(name: "NUMBERS", displayName: "Number Style")
                            Picker("Decimal separator:", selection: decimalSeparatorBinding) {
                                Text("Dot").tag(0)
                                Text("Comma").tag(1)
                                Text("Both").tag(2)
                            }
                            .frame(width: 180)
                            .disabled(selectedLanguageIndex == 0)
                        }
                        HStack(spacing: 12) {
                            fieldWithLabel("Prefix 1 :", text: keywordBinding("Numbers, prefix1"), placeholder: "0b")
                            fieldWithLabel("Prefix 2 :", text: keywordBinding("Numbers, prefix2"), placeholder: "0x")
                            fieldWithLabel("Extras 1 :", text: keywordBinding("Numbers, extras1"), placeholder: "A B C D E F")
                        }
                        HStack(spacing: 12) {
                            fieldWithLabel("Extras 2 :", text: keywordBinding("Numbers, extras2"), placeholder: "")
                            fieldWithLabel("Suffix 1 :", text: keywordBinding("Numbers, suffix1"), placeholder: "ULL ull")
                            fieldWithLabel("Suffix 2 :", text: keywordBinding("Numbers, suffix2"), placeholder: "")
                            fieldWithLabel("Range :", text: keywordBinding("Numbers, range"), placeholder: "..")
                        }
                    }
                    .padding(6)
                }
            }
            .padding(4)
        }
    }

    // MARK: - Tab 4: Operators & Delimiters
    private var operatorsTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                // Operators
                GroupBox(label: Text("Operators style").font(.system(size: 11, weight: .semibold))) {
                    VStack(alignment: .leading, spacing: 6) {
                        stylerRow(name: "OPERATORS", displayName: "Operators Style")
                        fieldWithLabel("Operators 1 (no separators needed) :",
                                       text: keywordBinding("Operators1"),
                                       placeholder: "+ - * / = < > ! & |")
                        fieldWithLabel("Operators 2 (separators needed) :",
                                       text: keywordBinding("Operators2"),
                                       placeholder: "and or not eq ne")
                    }
                    .padding(6)
                }

                // Delimiters 1..8
                ForEach(1...8, id: \.self) { delim in
                    let first = (delim - 1) * 3
                    GroupBox(label: Text("Delimiter \(delim)").font(.system(size: 11, weight: .semibold))) {
                        VStack(alignment: .leading, spacing: 6) {
                            stylerRow(name: "DELIMITERS\(delim)", displayName: "Delimiter \(delim) Style", supportsNesting: true)
                            HStack(spacing: 12) {
                                fieldWithLabel("Open :", text: delimiterTokenBinding(first), placeholder: "\"")
                                fieldWithLabel("Escape :", text: delimiterTokenBinding(first + 1), placeholder: "\\")
                                fieldWithLabel("Close :", text: delimiterTokenBinding(first + 2), placeholder: "\" or ((EOL))")
                            }
                        }
                        .padding(6)
                    }
                }
            }
            .padding(4)
        }
    }

    // MARK: - Helpers & Bindings
    private func stylerRow(name: String, displayName: String, supportsNesting: Bool = false) -> some View {
        HStack(spacing: 6) {
            Button(workspace.tr("Styler")) {
                activeStylerTarget = UDLStylerTarget(styleName: name, displayName: displayName, supportsNesting: supportsNesting)
            }
            .font(.system(size: 11))
            .disabled(selectedLanguageIndex == 0)

            UDLColorSwatch(
                fgHex: styleForeground(named: name),
                bgHex: styleBackground(named: name),
                fontStyle: styleFontStyle(named: name)
            ) {
                if selectedLanguageIndex > 0 {
                    activeStylerTarget = UDLStylerTarget(styleName: name, displayName: displayName, supportsNesting: supportsNesting)
                }
            }
        }
    }

    private func fieldWithLabel(_ label: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.system(size: 10))
            TextField(placeholder, text: text)
                .font(.system(size: 11, design: .monospaced))
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .disabled(selectedLanguageIndex == 0)
        }
    }

    private func groupOrdinal(_ group: Int) -> String {
        switch group {
        case 1: return "1st"
        case 2: return "2nd"
        case 3: return "3rd"
        default: return "\(group)th"
        }
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

    private var foldCompactBinding: Binding<Bool> {
        Binding(
            get: {
                guard selectedLanguageIndex > 0,
                      selectedLanguageIndex - 1 < workspace.userDefinedLanguages.count else { return false }
                return workspace.userDefinedLanguages[selectedLanguageIndex - 1].foldCompact
            },
            set: { value in
                guard selectedLanguageIndex > 0,
                      selectedLanguageIndex - 1 < workspace.userDefinedLanguages.count else { return }
                workspace.userDefinedLanguages[selectedLanguageIndex - 1].foldCompact = value
                workspace.saveUserDefinedLanguages()
            }
        )
    }

    private var allowFoldOfCommentsBinding: Binding<Bool> {
        Binding(
            get: {
                guard selectedLanguageIndex > 0,
                      selectedLanguageIndex - 1 < workspace.userDefinedLanguages.count else { return false }
                return workspace.userDefinedLanguages[selectedLanguageIndex - 1].allowFoldOfComments
            },
            set: { value in
                guard selectedLanguageIndex > 0,
                      selectedLanguageIndex - 1 < workspace.userDefinedLanguages.count else { return }
                workspace.userDefinedLanguages[selectedLanguageIndex - 1].allowFoldOfComments = value
                workspace.saveUserDefinedLanguages()
            }
        )
    }

    private var forcePureLCBinding: Binding<Int> {
        Binding(
            get: {
                guard selectedLanguageIndex > 0,
                      selectedLanguageIndex - 1 < workspace.userDefinedLanguages.count else { return 0 }
                return workspace.userDefinedLanguages[selectedLanguageIndex - 1].forcePureLC
            },
            set: { value in
                guard selectedLanguageIndex > 0,
                      selectedLanguageIndex - 1 < workspace.userDefinedLanguages.count else { return }
                workspace.userDefinedLanguages[selectedLanguageIndex - 1].forcePureLC = value
                workspace.saveUserDefinedLanguages()
            }
        )
    }

    private func commentTokenBinding(_ number: Int) -> Binding<String> {
        Binding(
            get: {
                guard selectedLanguageIndex > 0, selectedLanguageIndex - 1 < workspace.userDefinedLanguages.count else { return "" }
                let comments = workspace.userDefinedLanguages[selectedLanguageIndex - 1].keywordLists["Comments"] ?? ""
                return NppUDLCodec.commentToken(number, in: comments)
            },
            set: { val in
                guard selectedLanguageIndex > 0, selectedLanguageIndex - 1 < workspace.userDefinedLanguages.count else { return }
                let idx = selectedLanguageIndex - 1
                let existing = workspace.userDefinedLanguages[idx].keywordLists["Comments"] ?? ""
                workspace.userDefinedLanguages[idx].keywordLists["Comments"] =
                    NppUDLCodec.replacingCommentToken(number, value: val, in: existing)
                workspace.saveUserDefinedLanguages()
            }
        )
    }

    private func delimiterTokenBinding(_ number: Int) -> Binding<String> {
        Binding(
            get: {
                guard selectedLanguageIndex > 0, selectedLanguageIndex - 1 < workspace.userDefinedLanguages.count else { return "" }
                let delims = workspace.userDefinedLanguages[selectedLanguageIndex - 1].keywordLists["Delimiters"] ?? ""
                return NppUDLCodec.commentToken(number, in: delims)
            },
            set: { val in
                guard selectedLanguageIndex > 0, selectedLanguageIndex - 1 < workspace.userDefinedLanguages.count else { return }
                let idx = selectedLanguageIndex - 1
                let existing = workspace.userDefinedLanguages[idx].keywordLists["Delimiters"] ?? ""
                workspace.userDefinedLanguages[idx].keywordLists["Delimiters"] =
                    NppUDLCodec.replacingCommentToken(number, value: val, in: existing)
                workspace.saveUserDefinedLanguages()
            }
        )
    }

    private func styleForeground(named name: String) -> String? {
        guard selectedLanguageIndex > 0, selectedLanguageIndex - 1 < workspace.userDefinedLanguages.count else { return nil }
        return workspace.userDefinedLanguages[selectedLanguageIndex - 1].styleForegrounds[name]
    }

    private func styleBackground(named name: String) -> String? {
        guard selectedLanguageIndex > 0, selectedLanguageIndex - 1 < workspace.userDefinedLanguages.count else { return nil }
        return workspace.userDefinedLanguages[selectedLanguageIndex - 1].styleBackgrounds[name]
    }

    private func styleFontStyle(named name: String) -> Int {
        guard selectedLanguageIndex > 0, selectedLanguageIndex - 1 < workspace.userDefinedLanguages.count else { return 0 }
        return workspace.userDefinedLanguages[selectedLanguageIndex - 1].styleFontStyles[name] ?? 0
    }

    private func syncFieldsFromSelectedLanguage() {
        if selectedLanguageIndex > 0 && selectedLanguageIndex - 1 < workspace.userDefinedLanguages.count {
            let lang = workspace.userDefinedLanguages[selectedLanguageIndex - 1]
            currentLanguageName = lang.name
            currentExtensions = lang.extensions
            ignoreCase = lang.ignoreCase
        } else {
            currentLanguageName = "User-Defined"
            currentExtensions = ""
            ignoreCase = true
        }
    }

    // MARK: - Actions
    private func createNewLanguage() {
        let count = workspace.userDefinedLanguages.count + 1
        let newLang = NppUserDefineLanguage(
            name: "User Language \(count)",
            extensions: "udl\(count)",
            ignoreCase: ignoreCase
        )
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
            : NppUserDefineLanguage(name: name, extensions: currentExtensions, ignoreCase: ignoreCase)
        newLang.id = UUID()
        newLang.name = name
        workspace.userDefinedLanguages.append(newLang)
        workspace.includeSeparateUserDefinedLanguage(named: newLang.name)
        selectedLanguageIndex = workspace.userDefinedLanguages.count
        workspace.saveUserDefinedLanguages()
        (NSApp.delegate as? AppDelegate)?.setupMenuBar()
    }

    private func renameLanguage() {
        guard selectedLanguageIndex > 0, selectedLanguageIndex - 1 < workspace.userDefinedLanguages.count else { return }
        let idx = selectedLanguageIndex - 1
        let oldName = workspace.userDefinedLanguages[idx].name
        let alert = NSAlert()
        alert.messageText = workspace.tr("Rename")
        alert.addButton(withTitle: workspace.tr("OK"))
        alert.addButton(withTitle: workspace.tr("Cancel"))
        let field = NSTextField(string: oldName)
        field.frame = NSRect(x: 0, y: 0, width: 260, height: 24)
        alert.accessoryView = field
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let newName = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !newName.isEmpty else { return }
        workspace.excludeSeparateUserDefinedLanguage(named: oldName)
        workspace.includeSeparateUserDefinedLanguage(named: newName)
        workspace.userDefinedLanguages[idx].name = newName

        // Upstream buffer sync parity: update open document buffers referencing oldName
        for doc in workspace.documents where doc.language == oldName {
            doc.language = newName
        }

        workspace.saveUserDefinedLanguages()
        (NSApp.delegate as? AppDelegate)?.setupMenuBar()
    }

    private func removeLanguage() {
        guard selectedLanguageIndex > 0, selectedLanguageIndex - 1 < workspace.userDefinedLanguages.count else { return }
        let name = workspace.userDefinedLanguages[selectedLanguageIndex - 1].name
        workspace.excludeSeparateUserDefinedLanguage(named: name)
        workspace.userDefinedLanguages.remove(at: selectedLanguageIndex - 1)
        selectedLanguageIndex = 0

        // Upstream buffer sync parity: reset open document buffers referencing removed language
        for doc in workspace.documents where doc.language == name {
            doc.language = "User-Defined"
        }

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
        if selectedLanguageIndex == 0 {
            let alert = NSAlert()
            alert.messageText = workspace.tr("User Defined Language")
            alert.informativeText = "Before exporting, save your language definition by clicking \"Save As...\" button"
            alert.alertStyle = .informational
            alert.runModal()
            return
        }
        let savePanel = NSSavePanel()
        savePanel.nameFieldStringValue = "\(workspace.userDefinedLanguages[selectedLanguageIndex - 1].name).xml"
        if savePanel.runModal() == .OK, let url = savePanel.url {
            let language = workspace.userDefinedLanguages[selectedLanguageIndex - 1]
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

// MARK: - Styler Popup Sheet (Notepad++ StylerDlg IDD_STYLER_POPUP_DLG parity)
public struct NppUDLStylerSheet: View {
    public let target: UDLStylerTarget
    @ObservedObject public var workspace: NppWorkspace
    public let languageIndex: Int
    public let onDismiss: () -> Void

    @State private var fontName: String = ""
    @State private var fontSize: Int = -1
    @State private var isBold: Bool = false
    @State private var isItalic: Bool = false
    @State private var isUnderline: Bool = false

    @State private var fgColor: Color = .primary
    @State private var isFgTransparent: Bool = false
    @State private var bgColor: Color = Color(NSColor.textBackgroundColor)
    @State private var isBgTransparent: Bool = true

    // Nesting checkboxes bitmask
    @State private var nestingMask: Int = 0

    private let availableFonts = [
        "", "Menlo", "Monaco", "SF Mono", "Courier New", "Consolas", "Courier",
        "Andale Mono", "PT Mono", "Fira Code", "JetBrains Mono"
    ]
    private let availableSizes = [-1, 8, 9, 10, 11, 12, 14, 16, 18, 20, 22, 24, 26, 28]

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Styler - \(target.displayName)")
                .font(.system(size: 13, weight: .bold))

            Divider()

            HStack(alignment: .top, spacing: 16) {
                // Left Column: Font & Color Options
                VStack(alignment: .leading, spacing: 12) {
                    // Font Options
                    GroupBox(label: Text("Font style").font(.system(size: 11, weight: .semibold))) {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Font name:").font(.system(size: 10)).frame(width: 70, alignment: .leading)
                                Picker("", selection: $fontName) {
                                    Text("(Default)").tag("")
                                    ForEach(availableFonts.filter { !$0.isEmpty }, id: \.self) { fn in
                                        Text(fn).tag(fn)
                                    }
                                }
                                .frame(width: 150)
                            }

                            HStack {
                                Text("Font size:").font(.system(size: 10)).frame(width: 70, alignment: .leading)
                                Picker("", selection: $fontSize) {
                                    Text("(Default)").tag(-1)
                                    ForEach(availableSizes.filter { $0 > 0 }, id: \.self) { sz in
                                        Text("\(sz)").tag(sz)
                                    }
                                }
                                .frame(width: 90)
                            }

                            HStack(spacing: 12) {
                                Toggle("Bold", isOn: $isBold)
                                    .font(.system(size: 11))
                                    .toggleStyle(CheckboxToggleStyle())
                                Toggle("Italic", isOn: $isItalic)
                                    .font(.system(size: 11))
                                    .toggleStyle(CheckboxToggleStyle())
                                Toggle("Underline", isOn: $isUnderline)
                                    .font(.system(size: 11))
                                    .toggleStyle(CheckboxToggleStyle())
                            }
                            .padding(.top, 2)
                        }
                        .padding(6)
                    }

                    // Color Options
                    GroupBox(label: Text("Color style").font(.system(size: 11, weight: .semibold))) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 12) {
                                ColorPicker("Foreground color", selection: $fgColor)
                                    .font(.system(size: 11))
                                    .disabled(isFgTransparent)
                                Toggle("Transparent", isOn: $isFgTransparent)
                                    .font(.system(size: 11))
                                    .toggleStyle(CheckboxToggleStyle())
                            }

                            HStack(spacing: 12) {
                                ColorPicker("Background color", selection: $bgColor)
                                    .font(.system(size: 11))
                                    .disabled(isBgTransparent)
                                Toggle("Transparent", isOn: $isBgTransparent)
                                    .font(.system(size: 11))
                                    .toggleStyle(CheckboxToggleStyle())
                            }
                        }
                        .padding(6)
                    }
                }
                .frame(width: 280)

                // Right Column: Nesting Options (if supported) & Live Preview
                VStack(alignment: .leading, spacing: 12) {
                    if target.supportsNesting {
                        GroupBox(label: Text("Nesting").font(.system(size: 11, weight: .semibold))) {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(1...4, id: \.self) { d in
                                    let bit1 = 1 << (d - 1)
                                    let bit2 = 1 << (d + 3)
                                    HStack {
                                        Toggle("Delimiter \(d)", isOn: nestingBinding(bit: bit1))
                                            .font(.system(size: 10))
                                            .toggleStyle(CheckboxToggleStyle())
                                        Spacer()
                                        Toggle("Delimiter \(d + 4)", isOn: nestingBinding(bit: bit2))
                                            .font(.system(size: 10))
                                            .toggleStyle(CheckboxToggleStyle())
                                    }
                                }
                                HStack {
                                    Toggle("Comment", isOn: nestingBinding(bit: 1 << 8))
                                        .font(.system(size: 10))
                                        .toggleStyle(CheckboxToggleStyle())
                                    Spacer()
                                    Toggle("Comment line", isOn: nestingBinding(bit: 1 << 9))
                                        .font(.system(size: 10))
                                        .toggleStyle(CheckboxToggleStyle())
                                }
                                HStack {
                                    Toggle("Numbers", isOn: nestingBinding(bit: 1 << 26))
                                        .font(.system(size: 10))
                                        .toggleStyle(CheckboxToggleStyle())
                                    Spacer()
                                    Toggle("Operators", isOn: nestingBinding(bit: 1 << 24))
                                        .font(.system(size: 10))
                                        .toggleStyle(CheckboxToggleStyle())
                                }
                            }
                            .padding(6)
                        }
                    }

                    // Live preview box
                    GroupBox(label: Text("Preview").font(.system(size: 11, weight: .semibold))) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(isBgTransparent ? Color(NSColor.textBackgroundColor) : bgColor)
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)

                            let effectiveSize: CGFloat = fontSize > 0 ? CGFloat(fontSize) : 12.0
                            let baseFontDesc: Font = fontName.isEmpty
                                ? .system(size: effectiveSize, design: .monospaced)
                                : .custom(fontName, size: effectiveSize)
                            Text("The quick brown fox jumps over the lazy dog 12345")
                                .font(baseFontDesc)
                                .fontWeight(isBold ? .bold : .regular)
                                .italic(isItalic)
                                .underline(isUnderline)
                                .foregroundColor(isFgTransparent ? Color.primary : fgColor)
                                .padding(8)
                        }
                        .frame(height: 70)
                        .padding(4)
                    }
                }
                .frame(width: 260)
            }

            Divider()

            // Actions: OK & Cancel
            HStack {
                Spacer()
                Button(workspace.tr("Cancel")) {
                    onDismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button(workspace.tr("OK")) {
                    saveAndCommit()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(14)
        .frame(width: 580)
        .onAppear {
            loadInitialValues()
        }
    }

    private func loadInitialValues() {
        guard languageIndex >= 0, languageIndex < workspace.userDefinedLanguages.count else { return }
        let lang = workspace.userDefinedLanguages[languageIndex]

        if let fgHex = lang.styleForegrounds[target.styleName], let nsColor = NSColor(hexRGB: fgHex) {
            fgColor = Color(nsColor)
            isFgTransparent = false
        } else {
            isFgTransparent = true
        }

        if let bgHex = lang.styleBackgrounds[target.styleName], let nsColor = NSColor(hexRGB: bgHex) {
            bgColor = Color(nsColor)
            isBgTransparent = false
        } else {
            isBgTransparent = true
        }

        let bits = lang.styleFontStyles[target.styleName] ?? 0
        isBold = (bits & 1) != 0
        isItalic = (bits & 2) != 0
        isUnderline = (bits & 4) != 0

        fontName = lang.styleFontNames[target.styleName] ?? ""
        fontSize = lang.styleFontSizes[target.styleName] ?? -1
    }

    private func saveAndCommit() {
        guard languageIndex >= 0, languageIndex < workspace.userDefinedLanguages.count else {
            onDismiss()
            return
        }
        var lang = workspace.userDefinedLanguages[languageIndex]

        if isFgTransparent {
            lang.styleForegrounds.removeValue(forKey: target.styleName)
        } else {
            lang.styleForegrounds[target.styleName] = fgColor.toHexRGB()
        }

        if isBgTransparent {
            lang.styleBackgrounds.removeValue(forKey: target.styleName)
        } else {
            lang.styleBackgrounds[target.styleName] = bgColor.toHexRGB()
        }

        var styleBits = 0
        if isBold { styleBits |= 1 }
        if isItalic { styleBits |= 2 }
        if isUnderline { styleBits |= 4 }
        lang.styleFontStyles[target.styleName] = styleBits

        if fontName.isEmpty {
            lang.styleFontNames.removeValue(forKey: target.styleName)
        } else {
            lang.styleFontNames[target.styleName] = fontName
        }

        if fontSize <= 0 {
            lang.styleFontSizes.removeValue(forKey: target.styleName)
        } else {
            lang.styleFontSizes[target.styleName] = fontSize
        }

        workspace.userDefinedLanguages[languageIndex] = lang
        workspace.saveUserDefinedLanguages()
        workspace.rehighlightActiveDocument()
        onDismiss()
    }

    private func nestingBinding(bit: Int) -> Binding<Bool> {
        Binding(
            get: { (nestingMask & bit) != 0 },
            set: { on in
                if on {
                    nestingMask |= bit
                } else {
                    nestingMask &= ~bit
                }
            }
        )
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

        if workspace.isUserDefineDialogDocked {
            panel?.orderOut(nil)
            panel = nil
            return
        }

        if let existing = panel {
            existing.makeKeyAndOrderFront(nil)
            return
        }

        let newPanel = NSPanel(
            contentRect: NSRect(x: 200, y: 260, width: 620, height: 480),
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

    public func hideFloatingPanelOnly() {
        panel?.orderOut(nil)
        panel = nil
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
