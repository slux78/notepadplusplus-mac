import Foundation
import AppKit

public struct ClipboardItem: Identifiable, Equatable {
    public let id = UUID()
    public let text: String
    public let timestamp: Date
    public var preview: String {
        let firstLine = text.components(separatedBy: .newlines).first ?? text
        let trimmed = firstLine.trimmingCharacters(in: .whitespaces)
        return trimmed.count > 48 ? String(trimmed.prefix(45)) + "..." : trimmed
    }

    public init(text: String, timestamp: Date = Date()) {
        self.text = text
        self.timestamp = timestamp
    }
}

public final class NppWorkspace: ObservableObject {
    @Published public var documents: [NppDocument] = [] {
        didSet {
            validateActiveDocument()
        }
    }
    @Published public var activeDocumentId: UUID? {
        didSet {
            validateActiveDocument()
        }
    }

    private var isValidating = false
    private func validateActiveDocument() {
        guard !isValidating else { return }
        isValidating = true
        defer { isValidating = false }

        if documents.isEmpty {
            if activeDocumentId != nil {
                activeDocumentId = nil
            }
        } else {
            if activeDocumentId == nil || !documents.contains(where: { $0.id == activeDocumentId }) {
                activeDocumentId = documents.first?.id
            }
        }
    }

    @Published public var fontSize: CGFloat = 13.0 {
        didSet {
            updateEditorFonts()
        }
    }
    @Published public var fontFamily: String = "Menlo" {
        didSet {
            updateEditorFonts()
        }
    }
    @Published public var tabSize: Int = 4 {
        didSet {
            activeTextView?.needsDisplay = true
        }
    }
    @Published public var isWordWrapEnabled: Bool = false
    @Published public var showInvisibleCharacters: Bool = false {
        didSet {
            if !isSyncingShowSymbolFlags {
                isSyncingShowSymbolFlags = true
                showSpaceAndTab = showInvisibleCharacters
                showEndOfLine = showInvisibleCharacters
                showNonPrintingCharacters = showInvisibleCharacters
                isSyncingShowSymbolFlags = false
            }
            activeTextView?.needsDisplay = true
        }
    }
    private var isSyncingShowSymbolFlags: Bool = false
    @Published public var showSpaceAndTab: Bool = false {
        didSet {
            if !isSyncingShowSymbolFlags {
                isSyncingShowSymbolFlags = true
                showInvisibleCharacters = (showSpaceAndTab && showEndOfLine && showNonPrintingCharacters)
                isSyncingShowSymbolFlags = false
            }
            activeTextView?.needsDisplay = true
        }
    }
    @Published public var showEndOfLine: Bool = false {
        didSet {
            if !isSyncingShowSymbolFlags {
                isSyncingShowSymbolFlags = true
                showInvisibleCharacters = (showSpaceAndTab && showEndOfLine && showNonPrintingCharacters)
                isSyncingShowSymbolFlags = false
            }
            activeTextView?.needsDisplay = true
        }
    }
    @Published public var showNonPrintingCharacters: Bool = false {
        didSet {
            if !isSyncingShowSymbolFlags {
                isSyncingShowSymbolFlags = true
                showInvisibleCharacters = (showSpaceAndTab && showEndOfLine && showNonPrintingCharacters)
                isSyncingShowSymbolFlags = false
            }
            activeTextView?.needsDisplay = true
        }
    }
    @Published public var showControlCharsAndUnicodeEol: Bool = false {
        didSet { activeTextView?.needsDisplay = true }
    }
    @Published public var showWrapSymbol: Bool = false {
        didSet { activeTextView?.needsDisplay = true }
    }
    @Published public var showIndentGuides: Bool = true {
        didSet { activeTextView?.needsDisplay = true }
    }
    @Published public var showDocumentMap: Bool = false
    @Published public var showFunctionList: Bool = false
    @Published public var syncScrollV: Bool = false
    @Published public var syncScrollH: Bool = false
    @Published public var isAlwaysOnTop: Bool = false
    @Published public var isFullScreen: Bool = false
    @Published public var isPostItMode: Bool = false
    @Published public var isDistractionFreeMode: Bool = false
    private var savedPreModeToolbar: Bool = false
    private var savedPreModeTabBar: Bool = false
    private var savedPreModeStatusBar: Bool = false
    @Published public var currentSearchResultIndex: Int = -1
    // Authentic Notepad++ Panels
    @Published public var showDocumentList: Bool = false
    @Published public var showFolderAsWorkspace: Bool = false
    @Published public var workspaceFolders: [URL] = [URL(fileURLWithPath: FileManager.default.currentDirectoryPath)]
    @Published public var showClipboardHistory: Bool = false
    @Published public var showCharacterPanel: Bool = false
    @Published public var clipboardHistory: [ClipboardItem] = []

    // Pass 2: Edit Menu Parity State
    @Published public var beginSelectAnchor: Int? = nil
    @Published public var customDateFormat: String = "yyyy-MM-dd HH:mm:ss"
    @Published public var isAllDocumentsReadOnly: Bool = false

    // Authentic Notepad++ Modeless Dialogs & Transparency
    @Published public var showFindReplaceDialog: Bool = false {
        didSet {
            let shouldShow = showFindReplaceDialog
            if Thread.isMainThread {
                if shouldShow {
                    NppFindReplaceWindowController.shared.show(workspace: self)
                } else {
                    NppFindReplaceWindowController.shared.close()
                }
            } else {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    if shouldShow {
                        NppFindReplaceWindowController.shared.show(workspace: self)
                    } else {
                        NppFindReplaceWindowController.shared.close()
                    }
                }
            }
        }
    }
    @Published public var findReplaceTab: Int = 0 { // 0: Find, 1: Replace, 2: Find in Files, 3: Mark
        didSet {
            NppFindReplaceWindowController.shared.updateTitle()
        }
    }
    @Published public var findTransparencyEnabled: Bool = true
    @Published public var findTransparencyMode: Int = 0 // 0: On losing focus, 1: Always
    @Published public var findTransparencyValue: Double = 0.65 // 0.2 ... 0.95
    @Published public var showStyleConfigurator: Bool = false
    @Published public var showShortcutMapper: Bool = false
    @Published public var showColumnEditor: Bool = false
    @Published public var showWindowsDialog: Bool = false

    // Typing Mode
    @Published public var insertMode: Bool = true // true = INS, false = OVR

    public enum NppSearchBarMode: String {
        case find = "Find"
        case replace = "Replace"
    }
    @Published public var showSearchBar: Bool = false
    @Published public var searchBarMode: NppSearchBarMode = .find
    @Published public var showPreferencesSheet: Bool = false
    @Published public var selectedPreferencesTab: Int = 0

    // Authentic Notepad++ Find/Replace Initial Query & Word-Under-Caret Expansion State (FindReplaceDlg.cpp L5643)
    @Published public var findQueryText: String = ""
    @Published public var findInvocationCounter: Int = 0
    @Published public var findAutoInSelection: Bool = false

    public func tr(_ key: String) -> String {
        NppLocalization.tr(key, lang: localizationLanguage)
    }

    private func isWordCharacter(_ scalar: UnicodeScalar) -> Bool {
        if CharacterSet.alphanumerics.contains(scalar) || scalar == "_" {
            return true
        }
        if wordCharMode == 1 && !wordCharCustom.isEmpty {
            return wordCharCustom.unicodeScalars.contains(scalar)
        }
        return false
    }

    /// Expands word selection around `caretLocation` in `nsString` matching Scintilla's `expandWordSelection()`
    public func expandWordRange(at caretLocation: Int, in nsString: NSString) -> NSRange {
        let len = nsString.length
        guard len > 0 else { return NSRange(location: 0, length: 0) }
        let clampedCaret = max(0, min(caretLocation, len))

        var anchor = clampedCaret
        // Check character at caret or immediately before caret
        let checkRight: Bool = {
            guard clampedCaret < len,
                  let sc = UnicodeScalar(nsString.character(at: clampedCaret)) else { return false }
            return isWordCharacter(sc)
        }()
        let checkLeft: Bool = {
            guard clampedCaret > 0,
                  let sc = UnicodeScalar(nsString.character(at: clampedCaret - 1)) else { return false }
            return isWordCharacter(sc)
        }()

        if !checkRight && !checkLeft {
            return NSRange(location: clampedCaret, length: 0)
        }
        if !checkRight && checkLeft {
            anchor = clampedCaret - 1
        }

        var start = anchor
        while start > 0 {
            guard let sc = UnicodeScalar(nsString.character(at: start - 1)), isWordCharacter(sc) else { break }
            start -= 1
        }

        var end = anchor
        while end < len {
            guard let sc = UnicodeScalar(nsString.character(at: end)), isWordCharacter(sc) else { break }
            end += 1
        }

        return NSRange(location: start, length: max(0, end - start))
    }

    /// Upstream parity with `FindReplaceDlg::setSearchTextWithSettings()` and `ScintillaEditView::getSelectedTextToWChar(bool expand)`
    public func prepareFindDialogFromEditor() {
        defer {
            findInvocationCounter += 1
        }
        guard fillFindFieldWithSelected else { return }

        if let tv = activeTextView {
            let nsStr = tv.string as NSString
            var sel = tv.selectedRange()
            if sel.length == 0 && selectWordUnderCaretIfEmpty {
                let expanded = expandWordRange(at: sel.location, in: nsStr)
                if expanded.length > 0 {
                    tv.setSelectedRange(expanded)
                    sel = expanded
                    activeDocument?.cursorPos = expanded.location
                    activeDocument?.selectionLength = expanded.length
                }
            }
            findAutoInSelection = (sel.length >= inSelectionThreshold)
            if sel.length > 0 && sel.length <= fillFindFieldThreshold && NSMaxRange(sel) <= nsStr.length {
                let candidate = nsStr.substring(with: sel)
                if !candidate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !candidate.contains("\n") && !candidate.contains("\r") {
                    findQueryText = candidate
                    lastSearchQuery = candidate
                }
            }
        } else if let doc = activeDocument {
            let nsStr = doc.content as NSString
            var sel = NSRange(location: min(doc.cursorPos, nsStr.length), length: min(doc.selectionLength, max(0, nsStr.length - min(doc.cursorPos, nsStr.length))))
            if sel.length == 0 && selectWordUnderCaretIfEmpty {
                let expanded = expandWordRange(at: sel.location, in: nsStr)
                if expanded.length > 0 {
                    sel = expanded
                    doc.cursorPos = expanded.location
                    doc.selectionLength = expanded.length
                }
            }
            findAutoInSelection = (sel.length >= inSelectionThreshold)
            if sel.length > 0 && sel.length <= fillFindFieldThreshold && NSMaxRange(sel) <= nsStr.length {
                let candidate = nsStr.substring(with: sel)
                if !candidate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !candidate.contains("\n") && !candidate.contains("\r") {
                    findQueryText = candidate
                    lastSearchQuery = candidate
                }
            }
        }
    }

    public func openFind() {
        prepareFindDialogFromEditor()
        findReplaceTab = 0
        if showFindReplaceDialog {
            NppFindReplaceWindowController.shared.show(workspace: self)
        } else {
            showFindReplaceDialog = true
        }
        searchBarMode = .find
        showSearchBar = false
    }

    public func openReplace() {
        prepareFindDialogFromEditor()
        findReplaceTab = 1
        if showFindReplaceDialog {
            NppFindReplaceWindowController.shared.show(workspace: self)
        } else {
            showFindReplaceDialog = true
        }
        searchBarMode = .replace
        showSearchBar = false
    }

    public func openFindInFiles() {
        prepareFindDialogFromEditor()
        findReplaceTab = 2
        if showFindReplaceDialog {
            NppFindReplaceWindowController.shared.show(workspace: self)
        } else {
            showFindReplaceDialog = true
        }
    }

    public func openMark() {
        prepareFindDialogFromEditor()
        findReplaceTab = 3
        if showFindReplaceDialog {
            NppFindReplaceWindowController.shared.show(workspace: self)
        } else {
            showFindReplaceDialog = true
        }
    }

    // Authentic Preferences State (matching 24 categories in upstream preferenceDlg.cpp & preference.rc)
    // 0: General
    @Published public var localizationLanguage: String = "English" {
        didSet {
            NppFindReplaceWindowController.shared.updateTitle()
        }
    }
    @Published public var hideMenuBar: Bool = false
    @Published public var hideRightShortcuts: Bool = false
    @Published public var hideStatusBar: Bool = false
    @Published public var dialogFontSize: Int = 9
    @Published public var dialogFontName: String = "MS Shell Dlg"

    // 1: Toolbar
    @Published public var hideToolbar: Bool = false
    @Published public var toolbarIconStyle: String = "Standard icons: small"
    @Published public var toolbarColorization: String = "Complete"
    @Published public var toolbarColorChoice: String = "Default"
    @Published public var largeToolbarIcons: Bool = false

    // 2: Tab Bar
    @Published public var hideTabBar: Bool = false
    @Published public var tabVertical: Bool = false
    @Published public var tabMultiLine: Bool = false
    @Published public var tabLock: Bool = false
    @Published public var doubleClickTabToClose: Bool = true
    @Published public var doubleClickSpaceToNewTab: Bool = true
    @Published public var exitOnCloseLastTab: Bool = false
    @Published public var tabMaxLabelLen: Int = 30
    @Published public var tabReduce: Bool = false
    @Published public var tabAltIcons: Bool = false
    @Published public var tabChangeInactiveColor: Bool = false
    @Published public var tabColorIndicator: Bool = true
    @Published public var showTabCloseButton: Bool = true
    @Published public var tabPinFeature: Bool = true
    @Published public var tabShowOnlyPinnedButton: Bool = false
    @Published public var tabShowButtonsOnInactive: Bool = false

    // 3: Editing 1
    @Published public var currentLineIndicator: Int = 1 { // 0: None, 1: Highlight Background, 2: Frame
        didSet { activeTextView?.needsDisplay = true }
    }
    @Published public var currentLineFrameWidth: Int = 1 {
        didSet { activeTextView?.needsDisplay = true }
    }
    @Published public var caretWidth: Int = 1 {
        didSet { activeTextView?.needsDisplay = true }
    }
    @Published public var caretBlinkRate: Double = 500
    @Published public var lineWrapMode: Int = 0 // 0: Default, 1: Aligned, 2: Indent
    @Published public var smoothFont: Bool = true
    @Published public var virtualSpace: Bool = false
    @Published public var foldingToggle: Bool = true
    @Published public var rightClickKeepsSelection: Bool = true
    @Published public var lineCutCopyWithNoSelection: Bool = true
    @Published public var selectedTextForegroundCustom: Bool = false
    @Published public var scrollBeyondLastLine: Bool = false
    @Published public var disableTouchpadScroll: Bool = false
    @Published public var disableSelectedTextDragDrop: Bool = false
    @Published public var highlightCurrentLine: Bool = true {
        didSet {
            activeTextView?.needsDisplay = true
        }
    }

    // 4: Editing 2
    @Published public var multiSelection: Bool = true
    @Published public var columnToMultiEditing: Bool = true
    @Published public var eolAppearance: Int = 0 // 0: Default, 1: Plain text
    @Published public var eolCustomColor: Bool = false
    @Published public var npcAppearance: Int = 0 // 0: Abbreviation, 1: Codepoint
    @Published public var npcCustomColor: Bool = false
    @Published public var npcIncludeUnicodeEol: Bool = true
    @Published public var npcNoInputC0: Bool = false

    // 5: Dark Mode & Style Configurator (WordStyleDlg.cpp / stylers.model.xml)
    public struct NppStyleOverride: Equatable {
        public var fgColor: NSColor?
        public var bgColor: NSColor?
        public var fontFamily: String?
        public var fontSize: CGFloat?
        public var isBold: Bool?
        public var isItalic: Bool?
        public var isUnderline: Bool?

        public init(
            fgColor: NSColor? = nil,
            bgColor: NSColor? = nil,
            fontFamily: String? = nil,
            fontSize: CGFloat? = nil,
            isBold: Bool? = nil,
            isItalic: Bool? = nil,
            isUnderline: Bool? = nil
        ) {
            self.fgColor = fgColor
            self.bgColor = bgColor
            self.fontFamily = fontFamily
            self.fontSize = fontSize
            self.isBold = isBold
            self.isItalic = isItalic
            self.isUnderline = isUnderline
        }
    }

    @Published public var styleOverrides: [String: NppStyleOverride] = [:]
    @Published public var globalOverrideFg: Bool = false { didSet { updateThemeAppearance() } }
    @Published public var globalOverrideBg: Bool = false { didSet { updateThemeAppearance() } }
    @Published public var globalOverrideFont: Bool = false { didSet { updateThemeAppearance() } }
    @Published public var globalOverrideFontSize: Bool = false { didSet { updateThemeAppearance() } }
    @Published public var globalOverrideBold: Bool = false { didSet { updateThemeAppearance() } }
    @Published public var globalOverrideItalic: Bool = false { didSet { updateThemeAppearance() } }
    @Published public var globalOverrideUnderline: Bool = false { didSet { updateThemeAppearance() } }
    @Published public var styleUserExtensions: [String: String] = [:]
    @Published public var styleUserKeywords: [String: String] = [:]
    @Published public var styleConfigTransparent: Bool = false
    @Published public var styleConfigTransparencyPercent: Double = 30.0

    public func styleOverrideKey(themeId: String, language: String, style: String) -> String {
        "\(themeId)|\(language)|\(style)"
    }

    @Published public var darkModeChoice: Int = 1 { // 0: Light, 1: Dark, 2: Follow System
        didSet {
            applyDarkModeChoice()
        }
    }
    @Published public var darkModeTone: String = "Black"
    @Published public var themeMode: String = "dark" {
        didSet {
            updateThemeAppearance()
        }
    }
    public var currentTheme: NppTheme {
        let base = NppTheme.theme(withId: themeMode)
        let defaultOverride = styleOverrides[styleOverrideKey(themeId: themeMode, language: "Global Styles", style: "Default Style")]
        let globalOverride = styleOverrides[styleOverrideKey(themeId: themeMode, language: "Global Styles", style: "Global override")]
        let gutterOverride = styleOverrides[styleOverrideKey(themeId: themeMode, language: "Global Styles", style: "Line number margin")]
        let currentLineOverride = styleOverrides[styleOverrideKey(themeId: themeMode, language: "Global Styles", style: "Current line background colour")]
        let selectionOverride = styleOverrides[styleOverrideKey(themeId: themeMode, language: "Global Styles", style: "Selected text colour")]

        let effectiveFg = (globalOverrideFg ? globalOverride?.fgColor : nil) ?? defaultOverride?.fgColor ?? base.foregroundColor
        let effectiveBg = (globalOverrideBg ? globalOverride?.bgColor : nil) ?? defaultOverride?.bgColor ?? base.backgroundColor
        let effectiveGutterBg = (globalOverrideBg ? globalOverride?.bgColor : nil) ?? gutterOverride?.bgColor ?? base.gutterBackground
        let effectiveGutterFg = (globalOverrideFg ? globalOverride?.fgColor : nil) ?? gutterOverride?.fgColor ?? base.gutterForeground
        let effectiveActiveLine = currentLineOverride?.bgColor ?? base.activeLineColor
        let effectiveSelection = selectionOverride?.bgColor ?? base.selectionColor

        return NppTheme(
            id: base.id,
            name: base.name,
            isDark: base.isDark,
            backgroundColor: effectiveBg,
            foregroundColor: effectiveFg,
            gutterBackground: effectiveGutterBg,
            gutterForeground: effectiveGutterFg,
            activeLineColor: effectiveActiveLine,
            selectionColor: effectiveSelection,
            keywordColor: (globalOverrideFg ? globalOverride?.fgColor : nil) ?? base.keywordColor,
            stringColor: (globalOverrideFg ? globalOverride?.fgColor : nil) ?? base.stringColor,
            commentColor: (globalOverrideFg ? globalOverride?.fgColor : nil) ?? base.commentColor,
            numberColor: (globalOverrideFg ? globalOverride?.fgColor : nil) ?? base.numberColor
        )
    }

    public func applyDarkModeChoice() {
        let appAppearance: NSAppearance?
        switch darkModeChoice {
        case 0: // Light mode
            themeMode = "light"
            appAppearance = NSAppearance(named: .aqua)
        case 1: // Dark mode
            themeMode = "dark"
            appAppearance = NSAppearance(named: .darkAqua)
        case 2: // Follow System
            appAppearance = nil
            let isSystemDark = NSApp?.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            themeMode = isSystemDark ? "dark" : "light"
        default:
            appAppearance = nil
        }
        NSApp?.appearance = appAppearance
        for window in NSApp?.windows ?? [] {
            window.appearance = appAppearance
        }
        updateThemeAppearance()
    }

    public func updateThemeAppearance() {
        let theme = currentTheme
        let resolvedFont = NppWorkspace.resolveFont(name: fontFamily, size: fontSize)
        if let tv = activeTextView {
            tv.backgroundColor = theme.backgroundColor
            tv.insertionPointColor = theme.foregroundColor
            tv.textColor = theme.foregroundColor
            tv.typingAttributes = [
                .font: resolvedFont,
                .foregroundColor: theme.foregroundColor
            ]
            if let ts = tv.textStorage {
                NppSyntaxHighlighter.highlight(
                    textStorage: ts,
                    language: activeDocument?.language ?? "Plain Text",
                    isDarkMode: theme.isDark,
                    baseFont: resolvedFont,
                    theme: theme
                )
            }
            if let scroll = tv.enclosingScrollView, let gutter = scroll.verticalRulerView as? NppGutterView {
                gutter.gutterBackground = theme.gutterBackground
                gutter.gutterForeground = theme.gutterForeground
                gutter.needsDisplay = true
            }
            tv.needsDisplay = true
        }
        objectWillChange.send()
    }

    // 6: Margins/Border/Edge
    @Published public var foldMarginStyle: String = "Box tree"
    @Published public var borderWidth: Int = 0
    @Published public var noEdge: Bool = true
    @Published public var verticalEdgeColumn: Int = 80
    @Published public var verticalEdgeMode: Int = 1 // 0: None, 1: Line, 2: Background
    @Published public var verticalEdgeBgMode: Bool = false
    @Published public var changeHistoryMargin: Bool = true
    @Published public var changeHistoryText: Bool = false
    @Published public var showLineNumbers: Bool = true
    @Published public var lineNumberDynamicWidth: Bool = true
    @Published public var paddingLeft: Int = 0
    @Published public var paddingRight: Int = 0
    @Published public var distractionFreePadding: Int = 0
    @Published public var displayBookmarkMargin: Bool = true

    // 7: New Document
    @Published public var defaultNewDocFormat: NppEol = .crlf
    @Published public var defaultNewDocEncoding: String = "UTF-8"
    @Published public var openAnsiAsUtf8: Bool = false
    @Published public var defaultNewDocLanguage: String = "Plain Text"
    @Published public var addNewDocOnStartup: Bool = false
    @Published public var useFirstLineAsTabName: Bool = false

    // 8: Default Directory
    @Published public var defaultDirectoryMode: Int = 0 // 0: Follow current doc, 1: Remember last, 2: Always on
    @Published public var customDefaultDirectory: String = ""
    @Published public var dropFolderOpenAllFiles: Bool = false

    // 9: Recent Files History
    @Published public var dontCheckHistoryAtLaunch: Bool = false
    @Published public var recentFilesMax: Int = 15
    @Published public var recentFilesInSubmenu: Bool = true
    @Published public var recentFilesDisplayMode: Int = 1 // 0: Only File Name, 1: Full Path, 2: Custom Length
    @Published public var recentFilesCustomLength: Int = 30

    // 10: File Association
    @Published public var fileAssociations: [String] = [".txt", ".log", ".ini", ".c", ".cpp", ".h", ".swift", ".py", ".java", ".js", ".html", ".xml", ".json", ".md"]
    public func toggleFileAssociation(_ ext: String) {
        if let idx = fileAssociations.firstIndex(of: ext) {
            fileAssociations.remove(at: idx)
        } else {
            fileAssociations.append(ext)
        }
    }

    // 11: Language
    @Published public var compactLanguageMenu: Bool = false
    @Published public var treatBackslashAsEscapeForSql: Bool = false
    @Published public var availableLanguages: [String] = [
        "C / C++", "Swift", "Python", "Java", "JavaScript / TypeScript",
        "HTML / XML", "JSON / YAML", "Rust / Go", "SQL", "Markdown", "Shell / Bash", "PHP", "CSS"
    ]
    @Published public var disabledLanguages: [String] = [
        "ActionScript", "Ada", "Assembly", "Batch", "Cobol", "Fortran", "Pascal"
    ]
    public func disableLanguage(_ lang: String) {
        if let idx = availableLanguages.firstIndex(of: lang) {
            availableLanguages.remove(at: idx)
            if !disabledLanguages.contains(lang) {
                disabledLanguages.append(lang)
            }
        }
    }
    public func enableLanguage(_ lang: String) {
        if let idx = disabledLanguages.firstIndex(of: lang) {
            disabledLanguages.remove(at: idx)
            if !availableLanguages.contains(lang) {
                availableLanguages.append(lang)
            }
        }
    }

    // 12: Indentation
    @Published public var useDefaultTabValue: Bool = true
    @Published public var replaceTabBySpace: Bool = false
    @Published public var backspaceUnindents: Bool = true
    @Published public var autoIndentMode: Int = 1 // 0: None, 1: Basic, 2: Advanced

    // 13: Highlighting
    @Published public var markAllMatchCase: Bool = false
    @Published public var markAllWholeWord: Bool = false
    @Published public var highlightMatchingTags: Bool = true
    @Published public var highlightTagAttributes: Bool = true
    @Published public var highlightNoneHtmlZone: Bool = true
    @Published public var smartHighlighting: Bool = true
    @Published public var smartHighlightAnotherView: Bool = false
    @Published public var smartHighlightMatchCase: Bool = false
    @Published public var smartHighlightWholeWord: Bool = false
    @Published public var smartHighlightUseFindSettings: Bool = false

    // 14: Print
    @Published public var printColorOption: Int = 0 // 0: WYSIWYG, 1: Invert, 2: B&W, 3: No BG
    @Published public var printMarginTop: Int = 10
    @Published public var printMarginLeft: Int = 10
    @Published public var printMarginRight: Int = 10
    @Published public var printMarginBottom: Int = 10
    @Published public var printLineNumbers: Bool = false
    @Published public var printFormFeedPageBreak: Bool = false
    @Published public var printHeaderLeft: String = ""
    @Published public var printHeaderMiddle: String = ""
    @Published public var printHeaderRight: String = ""
    @Published public var printFooterLeft: String = ""
    @Published public var printFooterMiddle: String = ""
    @Published public var printFooterRight: String = ""
    @Published public var printVariableSelection: String = "Full file name path"

    // 15: Searching
    @Published public var inSelectionThreshold: Int = 1024
    @Published public var fillFindInFilesFromActiveDoc: Bool = true
    @Published public var fillFindFieldWithSelected: Bool = true
    @Published public var fillFindFieldThreshold: Int = 2048
    @Published public var selectWordUnderCaretIfEmpty: Bool = true
    @Published public var useMonospacedFontInFindDlg: Bool = false
    @Published public var findDlgAlwaysVisible: Bool = false
    @Published public var confirmReplaceAllInAllOpenedDocs: Bool = true
    @Published public var replaceAndStop: Bool = false
    @Published public var showOncePerFoundLine: Bool = false
    @Published public var fifIgnoreOpenedFiles: Bool = false
    @Published public var incSearchBarAtTop: Bool = false

    // 16: Backup
    @Published public var rememberSession: Bool = true
    @Published public var periodicBackupEnabled: Bool = true
    @Published public var periodicBackupIntervalSeconds: Int = 7
    @Published public var periodicBackupPath: String = ""
    @Published public var keepAbsentFilesInSession: Bool = true
    @Published public var backupOnSaveMode: Int = 0 // 0: None, 1: Simple, 2: Verbose
    @Published public var customBackupDirEnabled: Bool = false
    @Published public var customBackupDir: String = ""

    // 17: Auto-Completion
    @Published public var autoCompletionEnabled: Bool = true
    @Published public var autoCompletionType: Int = 2 // 0: Function, 1: Word, 2: Both
    @Published public var autoCompletionBrief: Bool = false
    @Published public var funcParamsHint: Bool = true
    @Published public var autoCompletionThreshold: Int = 1
    @Published public var autoCompletionKeyTab: Bool = true
    @Published public var autoCompletionKeyEnter: Bool = true
    @Published public var autoCompletionIgnoreNumbers: Bool = true
    @Published public var autoInsertParen: Bool = true
    @Published public var autoInsertBracket: Bool = true
    @Published public var autoInsertBrace: Bool = true
    @Published public var autoInsertDoubleQuote: Bool = true
    @Published public var autoInsertSingleQuote: Bool = true
    @Published public var autoInsertHtmlTag: Bool = true

    // 18: Multi-Instance & Date
    @Published public var multiInstanceMode: Int = 0 // 0: Default, 1: Always multi, 2: Open session in new
    @Published public var dateTimeReverseOrder: Bool = false
    @Published public var dateTimeCustomFormat: String = "yyyy-MM-dd HH:mm:ss"
    @Published public var rememberPanelStateDocList: Bool = true
    @Published public var rememberPanelStateFAW: Bool = true
    @Published public var rememberClipboardHistory: Bool = false
    @Published public var rememberCharacterPanel: Bool = false
    @Published public var rememberProjectPanels: Bool = false
    @Published public var rememberPluginPanels: Bool = false

    // 19: Delimiter
    @Published public var wordCharMode: Int = 0 // 0: Default, 1: Custom
    @Published public var wordCharCustom: String = ""
    @Published public var delimiterOpen: String = "("
    @Published public var delimiterClose: String = ")"
    @Published public var delimiterSeveralLines: Bool = false

    // 20: Performance
    @Published public var performanceLargeFileEnabled: Bool = true
    @Published public var performanceLargeFileSizeMB: Int = 200
    @Published public var performanceDeactivateWordWrap: Bool = true
    @Published public var performanceAllowAutoCompletion: Bool = false
    @Published public var performanceAllowSmartHighlighting: Bool = false
    @Published public var performanceAllowBraceMatch: Bool = false
    @Published public var performanceAllowClickableLink: Bool = false
    @Published public var performanceSuppress2GBWarning: Bool = false

    // 21: Cloud & Link
    @Published public var cloudMode: Int = 0 // 0: No Cloud, 1: Custom Cloud
    @Published public var cloudPath: String = ""
    @Published public var clickableLinkEnable: Bool = true
    @Published public var clickableLinkNoUnderline: Bool = false
    @Published public var clickableLinkFullBoxMode: Bool = false
    @Published public var uriCustomSchemes: String = ""

    // 22: Search Engine
    @Published public var searchEngineChoice: Int = 1 // 0: DuckDuckGo, 1: Google, 2: Yahoo, 3: Stack Overflow, 4: Custom
    @Published public var searchEngineUrl: String = "https://www.google.com/search?q="
    @Published public var customSearchEngineUrl: String = "https://www.google.com/search?q=$(CURRENT_WORD)"

    // 23: MISC.
    @Published public var fileStatusAutoDetection: Bool = true
    @Published public var fileStatusAutoReloadSilently: Bool = false
    @Published public var fileStatusGoToEOF: Bool = false
    @Published public var docSwitcherEnabled: Bool = true
    @Published public var docSwitcherMRU: Bool = true
    @Published public var docPeekerOnTab: Bool = false
    @Published public var docPeekerOnMap: Bool = false
    @Published public var muteAllSounds: Bool = false
    @Published public var autoDetectEncoding: Bool = true
    @Published public var shortTitleInBar: Bool = false
    @Published public var saveAllConfirmDialog: Bool = true
    @Published public var allowSymlinksInFAW: Bool = true
    @Published public var sessionFileExt: String = "session"
    @Published public var workspaceFileExt: String = "workspace"

    // Run Command State
    @Published public var lastRunCommand: String = "python3 $(CURRENT_FILE)"

    // Robust macOS Font Resolution for Family and PostScript names
    public static func resolveFont(name: String, size: CGFloat, bold: Bool = false, italic: Bool = false) -> NSFont {
        let fontManager = NSFontManager.shared
        var traits: NSFontTraitMask = []
        if bold { traits.insert(.boldFontMask) }
        if italic { traits.insert(.italicFontMask) }

        // 1. Try fontWithFamily with requested traits
        if let font = fontManager.font(withFamily: name, traits: traits, weight: bold ? 9 : 5, size: size) {
            return font
        }
        // 2. Try exact name (PostScript name)
        if let font = NSFont(name: name, size: size) {
            return font
        }
        // 3. Try family name without traits
        if let font = fontManager.font(withFamily: name, traits: [], weight: 5, size: size) {
            return font
        }
        // 4. Fallback to system monospaced font
        return NSFont.monospacedSystemFont(ofSize: size, weight: bold ? .bold : .regular)
    }

    // Dynamic Monospaced & Coding Fonts Discovery + All System Fonts
    public static var allSystemFontFamilies: [String] {
        return NSFontManager.shared.availableFontFamilies.sorted()
    }

    public static var availableCodingFonts: [String] {
        let preferred = [
            "SF Mono", "Menlo", "Monaco", "Courier New", "Courier",
            "JetBrains Mono", "Fira Code", "D2Coding", "NanumGothicCoding",
            "Hack", "Inconsolata", "Source Code Pro", "PT Mono", "Andale Mono",
            "Consolas", "Apple SD Gothic Neo"
        ]
        let fontManager = NSFontManager.shared
        let systemFamilies = Set(fontManager.availableFontFamilies)
        var result: [String] = []
        for f in preferred {
            if systemFamilies.contains(f) {
                result.append(f)
            }
        }
        for family in fontManager.availableFontFamilies.sorted() {
            if !result.contains(family) {
                if let font = fontManager.font(withFamily: family, traits: [], weight: 5, size: 12), font.isFixedPitch {
                    result.append(family)
                }
            }
        }
        if result.isEmpty {
            result = ["Menlo", "Monaco", "Courier New"]
        }
        return result
    }

    public func updateEditorFonts() {
        let resolved = NppWorkspace.resolveFont(name: fontFamily, size: fontSize)
        let theme = currentTheme
        if let tv = activeTextView {
            tv.font = resolved
            tv.typingAttributes = [
                .font: resolved,
                .foregroundColor: theme.foregroundColor
            ]
            if let ts = tv.textStorage {
                NppSyntaxHighlighter.highlight(
                    textStorage: ts,
                    language: activeDocument?.language ?? "Plain Text",
                    isDarkMode: currentTheme.isDark,
                    baseFont: resolved,
                    theme: currentTheme
                )
            }
            tv.needsDisplay = true
        }
        objectWillChange.send()
    }

    // New Document Defaults
    @Published public var defaultEol: NppEol = .crlf
    @Published public var defaultEncoding: String = "UTF-8"
    @Published public var defaultLanguage: String = "Plain Text"

    // Reference to active text view for reliable toolbar actions
    public weak var activeTextView: NSTextView? {
        didSet {
            if let nppTv = activeTextView as? NppTextView {
                nppTv.workspace = self
            }
        }
    }

    public func openPreferences(tab: Int = 0) {
        selectedPreferencesTab = tab
        showPreferencesSheet = true
    }

    // Notepad++ Find All Search Results State
    @Published public var searchFileGroups: [NppSearchFileGroup] = []
    @Published public var lastSearchQuery: String = ""
    @Published public var showSearchResultsPanel: Bool = false
    @Published public var targetJumpMatch: NppSearchMatch?

    private var newDocCounter: Int = 1

    public var activeDocument: NppDocument? {
        if let id = activeDocumentId, let doc = documents.first(where: { $0.id == id }) {
            return doc
        }
        return documents.first
    }

    public var totalSearchHits: Int {
        searchFileGroups.reduce(0) { $0 + $1.matches.count }
    }

    public init() {
        newDocument()
        loadSavedMacros()
    }

    public func newDocument() {
        let title = "new \(newDocCounter)"
        newDocCounter += 1
        let enc = defaultNewDocEncoding.isEmpty ? defaultEncoding : defaultNewDocEncoding
        let eol = defaultNewDocFormat
        let doc = NppDocument(
            title: title,
            content: "",
            encoding: enc,
            hasBOM: enc == "UTF-8-BOM",
            eol: eol
        )
        doc.language = defaultNewDocLanguage.isEmpty ? defaultLanguage : defaultNewDocLanguage
        documents.append(doc)
        activeDocumentId = doc.id
    }

    public func openFile(url: URL) {
        addRecentFile(url)
        // If already open, just switch to it
        if let existing = documents.first(where: { $0.filePath == url }) {
            activeDocumentId = existing.id
            return
        }

        do {
            let doc = try NppDocument.fromFile(url: url)
            // If only single untitled document is open and empty, replace it
            if documents.count == 1 && documents[0].filePath == nil && documents[0].content.isEmpty && !documents[0].isDirty {
                documents = [doc]
            } else {
                documents.append(doc)
            }
            activeDocumentId = doc.id
        } catch {
            print("Failed to open file: \(error)")
        }
    }

    @Published public var recentFiles: [URL] = []
    @Published public var closedFilePaths: [URL] = []

    public func addRecentFile(_ url: URL) {
        recentFiles.removeAll(where: { $0.path == url.path })
        recentFiles.insert(url, at: 0)
        let limit = max(1, recentFilesMax)
        if recentFiles.count > limit {
            recentFiles = Array(recentFiles.prefix(limit))
        }
    }

    public func closeDocument(id: UUID) {
        guard let index = documents.firstIndex(where: { $0.id == id }) else { return }
        // Authentic Notepad++ (Notepad_plus.cpp L5165): Pinned tab cannot be closed
        if documents[index].isPinned {
            NSSound.beep()
            return
        }
        if let path = documents[index].filePath {
            closedFilePaths.removeAll(where: { $0.path == path.path })
            closedFilePaths.append(path)
            addRecentFile(path)
        }
        let wasActive = (activeDocumentId == id)

        let fallbackIndex: Int
        if index + 1 < documents.count {
            fallbackIndex = index
        } else if index > 0 {
            fallbackIndex = index - 1
        } else {
            fallbackIndex = -1
        }

        documents.remove(at: index)

        if documents.isEmpty {
            newDocument()
        } else if wasActive || activeDocumentId == id || !documents.contains(where: { $0.id == activeDocumentId }) {
            let safeIndex = max(0, min(fallbackIndex, documents.count - 1))
            activeDocumentId = documents[safeIndex].id
        }
    }

    public func closeAll() {
        // Authentic Notepad++: Pinned documents remain open
        let pinned = documents.filter { $0.isPinned }
        if pinned.isEmpty {
            documents.removeAll()
            newDocCounter = 1
            newDocument()
        } else {
            documents = pinned
            if !documents.contains(where: { $0.id == activeDocumentId }) {
                activeDocumentId = documents.first?.id
            }
        }
    }

    public func closeAllDocuments() {
        closeAll()
    }

    // Notepad++ Tab Pinning (Buffer::isPinned & TabBar.cpp)
    public func togglePin(id: UUID) {
        guard let doc = documents.first(where: { $0.id == id }) else { return }
        doc.isPinned.toggle()
        // Authentic Notepad++: All pinned tabs are grouped to the left
        let pinned = documents.filter { $0.isPinned }
        let unpinned = documents.filter { !$0.isPinned }
        documents = pinned + unpinned
    }

    // Notepad++ Tab Context Menu: Close Multiple Documents (Notepad_plus.rc & NppIO.cpp)
    public func closeAllBut(id: UUID) {
        // IDM_FILE_CLOSEALL_BUT_CURRENT: Closes all documents except target and pinned documents
        documents.removeAll(where: { $0.id != id && !$0.isPinned })
        ensureValidActiveDocument(fallbackId: id)
    }

    public func closeAllButPinned() {
        // IDM_FILE_CLOSEALL_BUT_PINNED: Closes all unpinned documents
        documents.removeAll(where: { !$0.isPinned })
        ensureValidActiveDocument()
    }

    public func closeAllToLeft(of id: UUID) {
        guard let index = documents.firstIndex(where: { $0.id == id }) else { return }
        // IDM_FILE_CLOSEALL_TOLEFT: Skips pinned tabs
        let leftDocs = documents[0..<index]
        let toRemove = Set(leftDocs.filter { !$0.isPinned }.map { $0.id })
        documents.removeAll(where: { toRemove.contains($0.id) })
        ensureValidActiveDocument(fallbackId: id)
    }

    public func closeAllToRight(of id: UUID) {
        guard let index = documents.firstIndex(where: { $0.id == id }) else { return }
        // IDM_FILE_CLOSEALL_TORIGHT: Skips pinned tabs
        if index + 1 < documents.count {
            let rightDocs = documents[(index + 1)..<documents.count]
            let toRemove = Set(rightDocs.filter { !$0.isPinned }.map { $0.id })
            documents.removeAll(where: { toRemove.contains($0.id) })
        }
        ensureValidActiveDocument(fallbackId: id)
    }

    public func closeAllUnchanged() {
        // IDM_FILE_CLOSEALL_UNCHANGED: Closes all clean documents except pinned
        let retained = documents.filter { $0.isDirty || $0.isPinned }
        if retained.isEmpty {
            newDocument()
            documents = [documents.last!]
        } else {
            documents = retained
            ensureValidActiveDocument()
        }
    }

    private func ensureValidActiveDocument(fallbackId: UUID? = nil) {
        if documents.isEmpty {
            newDocument()
        }
        if let fid = fallbackId, documents.contains(where: { $0.id == fid }) {
            activeDocumentId = fid
        } else if activeDocumentId == nil || !documents.contains(where: { $0.id == activeDocumentId }) {
            activeDocumentId = documents.last?.id
        }
    }

    public func reloadFromDisk(for doc: NppDocument) {
        guard let url = doc.filePath else { return }
        do {
            let reloaded = try NppDocument.fromFile(url: url)
            doc.content = reloaded.content
            doc.encoding = reloaded.encoding
            doc.hasBOM = reloaded.hasBOM
            doc.eolFormat = reloaded.eolFormat
            doc.rawFileBytes = reloaded.rawFileBytes
            doc.lastKnownModificationDate = reloaded.lastKnownModificationDate
            doc.isDirty = false
            objectWillChange.send()
        } catch {
            print("Failed to reload file: \(error)")
        }
    }

    // MARK: - File Status Auto-Detection
    public func checkFileStatus(for doc: NppDocument, prompt: Bool = true) -> Bool {
        guard fileStatusAutoDetection, let path = doc.filePath?.path else { return false }
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: path),
              let diskDate = attrs[.modificationDate] as? Date else { return false }

        guard let knownDate = doc.lastKnownModificationDate else {
            doc.lastKnownModificationDate = diskDate
            return false
        }

        // If file modification time is newer by more than 1 second
        if diskDate.timeIntervalSince(knownDate) > 1.0 {
            if fileStatusAutoReloadSilently {
                reloadFromDisk(for: doc)
                return true
            } else if prompt {
                let alert = NSAlert()
                alert.messageText = "\(doc.title)"
                alert.informativeText = "This file has been modified by another program.\n\nDo you want to reload it and lose the changes made in Notepad++?"
                alert.addButton(withTitle: "Yes")
                alert.addButton(withTitle: "No")
                alert.alertStyle = .warning
                let res = alert.runModal()
                if res == .alertFirstButtonReturn {
                    reloadFromDisk(for: doc)
                    return true
                } else {
                    doc.lastKnownModificationDate = diskDate
                    return false
                }
            }
        }
        return false
    }

    public func checkAllFilesStatus() {
        for doc in documents {
            _ = checkFileStatus(for: doc, prompt: true)
        }
    }

    // MARK: - Notepad++ Run Command Engine
    public func expandRunCommand(_ rawCmd: String) -> String {
        guard let doc = activeDocument else { return rawCmd }
        let filePath = doc.filePath?.path ?? ""
        let fileDir = doc.filePath?.deletingLastPathComponent().path ?? FileManager.default.currentDirectoryPath
        let fileName = doc.filePath?.lastPathComponent ?? doc.title
        let namePart = (fileName as NSString).deletingPathExtension

        var cmd = rawCmd
        cmd = cmd.replacingOccurrences(of: "$(CURRENT_FILE)", with: "\"\(filePath)\"")
        cmd = cmd.replacingOccurrences(of: "$(CURRENT_DIRECTORY)", with: "\"\(fileDir)\"")
        cmd = cmd.replacingOccurrences(of: "$(FILE_NAME)", with: "\"\(fileName)\"")
        cmd = cmd.replacingOccurrences(of: "$(NAME_PART)", with: "\"\(namePart)\"")
        return cmd
    }

    public func executeRunCommand(_ rawCmd: String, inTerminal: Bool = true) {
        lastRunCommand = rawCmd
        let expanded = expandRunCommand(rawCmd)
        let workDir = activeDocument?.filePath?.deletingLastPathComponent().path ?? FileManager.default.currentDirectoryPath

        if inTerminal {
            let escapedWorkDir = workDir.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
            let escapedCmd = expanded.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
            let script = "tell application \"Terminal\" to do script \"cd \\\"\(escapedWorkDir)\\\" && \(escapedCmd)\""
            var error: NSDictionary?
            var appleScriptSuccess = false
            if let appleScript = NSAppleScript(source: script) {
                let res = appleScript.executeAndReturnError(&error)
                if error == nil && res.descriptorType != 0 {
                    appleScriptSuccess = true
                }
            }
            if appleScriptSuccess {
                if let termApp = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.Terminal").first {
                    termApp.activate(options: .activateIgnoringOtherApps)
                }
            } else {
                NppTools.openTerminal(at: URL(fileURLWithPath: workDir))
            }
        } else {
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/bin/zsh")
            proc.arguments = ["-c", expanded]
            proc.currentDirectoryURL = URL(fileURLWithPath: workDir)
            try? proc.run()
        }
    }

    // MARK: - Notepad++ Find All Operations
    public func findAllInCurrentDoc(query: String, matchCase: Bool, wholeWord: Bool, useRegex: Bool) {
        guard let doc = activeDocument, !query.isEmpty else { return }
        lastSearchQuery = query
        let matches = searchInDocument(doc: doc, query: query, matchCase: matchCase, wholeWord: wholeWord, useRegex: useRegex)
        if !matches.isEmpty {
            searchFileGroups = [NppSearchFileGroup(documentId: doc.id, documentTitle: doc.title, filePath: doc.filePath, matches: matches)]
        } else {
            searchFileGroups = []
        }
        showSearchResultsPanel = true
    }

    public func findAllInAllOpenedDocs(query: String, matchCase: Bool, wholeWord: Bool, useRegex: Bool) {
        guard !query.isEmpty else { return }
        lastSearchQuery = query
        var groups: [NppSearchFileGroup] = []
        for doc in documents {
            let matches = searchInDocument(doc: doc, query: query, matchCase: matchCase, wholeWord: wholeWord, useRegex: useRegex)
            if !matches.isEmpty {
                groups.append(NppSearchFileGroup(documentId: doc.id, documentTitle: doc.title, filePath: doc.filePath, matches: matches))
            }
        }
        searchFileGroups = groups
        showSearchResultsPanel = true
    }

    private func searchInDocument(doc: NppDocument, query: String, matchCase: Bool, wholeWord: Bool, useRegex: Bool) -> [NppSearchMatch] {
        let content = doc.content as NSString
        guard content.length > 0 else { return [] }

        var pattern = query
        if !useRegex {
            pattern = NSRegularExpression.escapedPattern(for: query)
        }
        if wholeWord {
            pattern = "\\b" + pattern + "\\b"
        }

        var regexOptions: NSRegularExpression.Options = []
        if !matchCase {
            regexOptions.insert(.caseInsensitive)
        }

        guard let regex = try? NSRegularExpression(pattern: pattern, options: regexOptions) else { return [] }
        let rawMatches = regex.matches(in: doc.content, options: [], range: NSRange(location: 0, length: content.length))

        var results: [NppSearchMatch] = []
        for m in rawMatches {
            let lineRange = content.lineRange(for: NSRange(location: m.range.location, length: 0))
            let lineText = content.substring(with: lineRange).trimmingCharacters(in: .newlines)

            // Compute exact 1-indexed line number
            var lineNum = 1
            for i in 0..<m.range.location {
                if content.character(at: i) == 10 {
                    lineNum += 1
                }
            }

            let matchRangeInLine = NSRange(location: m.range.location - lineRange.location, length: m.range.length)

            let match = NppSearchMatch(
                documentId: doc.id,
                documentTitle: doc.title,
                filePath: doc.filePath,
                lineNumber: lineNum,
                lineContent: lineText,
                matchRangeInLine: matchRangeInLine,
                charPosition: m.range.location,
                matchLength: m.range.length
            )
            results.append(match)
        }
        return results
    }

    public func jumpToMatch(_ match: NppSearchMatch) {
        if documents.contains(where: { $0.id == match.documentId }) {
            activeDocumentId = match.documentId
        } else if let fileUrl = match.filePath,
                  let existingDoc = documents.first(where: { $0.filePath?.standardizedFileURL.path == fileUrl.standardizedFileURL.path }) {
            activeDocumentId = existingDoc.id
        } else if let fileUrl = match.filePath, FileManager.default.fileExists(atPath: fileUrl.path) {
            openFile(url: fileUrl)
        } else {
            activeDocumentId = match.documentId
        }
        targetJumpMatch = match

        if let doc = activeDocument {
            doc.cursorPos = match.charPosition
            doc.selectionLength = match.matchLength
            doc.cursorLine = match.lineNumber
            if let tv = activeTextView {
                if tv.string != doc.content {
                    syncDocumentToTextView(doc: doc, tv: tv)
                }
                let maxLen = (tv.string as NSString).length
                let safeLoc = min(max(0, match.charPosition), maxLen)
                let safeLen = min(max(0, match.matchLength), max(0, maxLen - safeLoc))
                let range = NSRange(location: safeLoc, length: safeLen)
                tv.setSelectedRange(range)
                tv.scrollRangeToVisible(range)
            }
        }
    }

    public func findNext(forward: Bool = true) {
        guard !lastSearchQuery.isEmpty else { return }
        if let tv = activeTextView, let doc = activeDocument {
            if tv.string != doc.content {
                syncDocumentToTextView(doc: doc, tv: tv)
            }
            let content = tv.string as NSString
            let sel = tv.selectedRange()
            let options: NSString.CompareOptions = forward ? [] : [.backwards]
            let searchRange: NSRange
            if forward {
                let start = NSMaxRange(sel)
                searchRange = NSRange(location: min(start, content.length), length: max(0, content.length - min(start, content.length)))
            } else {
                searchRange = NSRange(location: 0, length: min(sel.location, content.length))
            }
            var found = content.range(of: lastSearchQuery, options: options, range: searchRange)
            if found.location == NSNotFound {
                found = content.range(of: lastSearchQuery, options: options)
            }
            if found.location != NSNotFound {
                tv.setSelectedRange(found)
                tv.scrollRangeToVisible(found)
                doc.cursorPos = found.location
                doc.selectionLength = found.length
            }
        } else if let doc = activeDocument {
            let content = doc.content as NSString
            let sel = NSRange(
                location: min(doc.cursorPos, content.length),
                length: min(doc.selectionLength, max(0, content.length - min(doc.cursorPos, content.length)))
            )
            let options: NSString.CompareOptions = forward ? [] : [.backwards]
            let searchRange: NSRange
            if forward {
                let start = NSMaxRange(sel)
                searchRange = NSRange(location: min(start, content.length), length: max(0, content.length - min(start, content.length)))
            } else {
                searchRange = NSRange(location: 0, length: min(sel.location, content.length))
            }
            var found = content.range(of: lastSearchQuery, options: options, range: searchRange)
            if found.location == NSNotFound {
                found = content.range(of: lastSearchQuery, options: options)
            }
            if found.location != NSNotFound {
                doc.cursorPos = found.location
                doc.selectionLength = found.length
            }
        }
    }

    public func clearSearchResults() {
        searchFileGroups.removeAll()
        currentSearchResultIndex = -1
        showSearchResultsPanel = false
    }

    // MARK: - Notepad++ Bookmark Operations (Scintilla Parity)
    public func toggleBookmark(line: Int? = nil) {
        guard let doc = activeDocument else { return }
        let targetLine = line ?? doc.cursorLine
        doc.toggleBookmark(line: targetLine)
        objectWillChange.send()
    }

    public func nextBookmark() {
        guard let doc = activeDocument, !doc.bookmarkedLines.isEmpty else { return }
        let sorted = doc.bookmarkedLines.sorted()
        let current = doc.cursorLine
        if let next = sorted.first(where: { $0 > current }) {
            doc.cursorLine = next
            jumpToLine(next)
        } else if let first = sorted.first {
            doc.cursorLine = first
            jumpToLine(first)
        }
    }

    public func prevBookmark() {
        guard let doc = activeDocument, !doc.bookmarkedLines.isEmpty else { return }
        let sorted = doc.bookmarkedLines.sorted()
        let current = doc.cursorLine
        if let prev = sorted.last(where: { $0 < current }) {
            doc.cursorLine = prev
            jumpToLine(prev)
        } else if let last = sorted.last {
            doc.cursorLine = last
            jumpToLine(last)
        }
    }

    public func clearAllBookmarks() {
        guard let doc = activeDocument else { return }
        doc.clearBookmarks()
        objectWillChange.send()
    }

    public func copyBookmarkedLines() {
        guard let doc = activeDocument, !doc.bookmarkedLines.isEmpty else { return }
        let lines = doc.content.nppLines()
        let sep = doc.eolFormat.characters
        var copiedLines: [String] = []
        for (idx, line) in lines.enumerated() {
            let lineNum = idx + 1
            if doc.bookmarkedLines.contains(lineNum) {
                copiedLines.append(line)
            }
        }
        let joined = copiedLines.joined(separator: sep) + (copiedLines.isEmpty ? "" : sep)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(joined, forType: .string)
    }

    public func cutBookmarkedLines() {
        guard let doc = activeDocument,
              !(doc.isReadOnly || isAllDocumentsReadOnly),
              !doc.bookmarkedLines.isEmpty else { return }
        copyBookmarkedLines()
        removeBookmarkedLines()
    }

    public func pasteToBookmarkedLines() {
        guard let doc = activeDocument,
              !(doc.isReadOnly || isAllDocumentsReadOnly),
              !doc.bookmarkedLines.isEmpty,
              let clipString = NSPasteboard.general.string(forType: .string) else { return }
        var lines = doc.content.nppLines()
        let cleanClip = clipString.trimmingCharacters(in: .newlines)
        for lineNum in doc.bookmarkedLines {
            let idx = lineNum - 1
            if idx >= 0 && idx < lines.count {
                lines[idx] = cleanClip
            }
        }
        let sep = doc.eolFormat.characters
        doc.content = lines.joined(separator: sep)
        doc.isDirty = true
        if let tv = activeTextView {
            syncDocumentToTextView(doc: doc, tv: tv)
        }
        objectWillChange.send()
    }

    public func removeBookmarkedLines() {
        guard let doc = activeDocument,
              !(doc.isReadOnly || isAllDocumentsReadOnly),
              !doc.bookmarkedLines.isEmpty else { return }
        let lines = doc.content.nppLines()
        var remaining: [String] = []
        for (idx, line) in lines.enumerated() {
            let lineNum = idx + 1
            if !doc.bookmarkedLines.contains(lineNum) {
                remaining.append(line)
            }
        }
        let sep = doc.eolFormat.characters
        doc.content = remaining.joined(separator: sep)
        doc.clearBookmarks()
        doc.isDirty = true
        if let tv = activeTextView {
            syncDocumentToTextView(doc: doc, tv: tv)
        }
        objectWillChange.send()
    }

    public func removeNonBookmarkedLines() {
        guard let doc = activeDocument,
              !(doc.isReadOnly || isAllDocumentsReadOnly),
              !doc.bookmarkedLines.isEmpty else { return }
        let lines = doc.content.nppLines()
        var kept: [String] = []
        for (idx, line) in lines.enumerated() {
            let lineNum = idx + 1
            if doc.bookmarkedLines.contains(lineNum) {
                kept.append(line)
            }
        }
        let sep = doc.eolFormat.characters
        doc.content = kept.joined(separator: sep)
        doc.bookmarkedLines = Set(1...max(1, kept.count))
        doc.isDirty = true
        if let tv = activeTextView {
            syncDocumentToTextView(doc: doc, tv: tv)
        }
        objectWillChange.send()
    }

    public func inverseBookmarks() {
        guard let doc = activeDocument else { return }
        let lines = doc.content.nppLines()
        let totalLines = max(1, lines.count)
        var newBookmarks = Set<Int>()
        for lineNum in 1...totalLines {
            if !doc.bookmarkedLines.contains(lineNum) {
                newBookmarks.insert(lineNum)
            }
        }
        doc.bookmarkedLines = newBookmarks
        objectWillChange.send()
    }

    public func jumpToLine(_ line: Int) {
        guard let doc = activeDocument, let tv = activeTextView else { return }
        let lines = doc.content.nppLines()
        let targetLine = max(1, min(line, lines.count))
        var charPos = 0
        for i in 0..<(targetLine - 1) {
            charPos += (lines[i] as NSString).length + doc.eolFormat.characters.count
        }
        let targetRange = NSRange(location: min(charPos, (doc.content as NSString).length), length: 0)
        tv.setSelectedRange(targetRange)
        tv.scrollRangeToVisible(targetRange)
        doc.cursorLine = targetLine
        doc.cursorPos = charPos
    }

    public func markAll(query: String, matchCase: Bool, wholeWord: Bool, useRegex: Bool, bookmarkLine: Bool, purgeExisting: Bool) -> Int {
        guard let doc = activeDocument, !query.isEmpty else { return 0 }
        if purgeExisting {
            doc.clearBookmarks()
        }
        let matches = searchInDocument(doc: doc, query: query, matchCase: matchCase, wholeWord: wholeWord, useRegex: useRegex)
        if bookmarkLine {
            for match in matches {
                doc.bookmarkedLines.insert(match.lineNumber)
            }
        }
        objectWillChange.send()
        return matches.count
    }

    // MARK: - Notepad++ Find in Files
    public func findAllInFiles(query: String, filter: String, directory: String, subfolders: Bool, matchCase: Bool, wholeWord: Bool, useRegex: Bool) {
        guard !query.isEmpty else { return }
        lastSearchQuery = query

        let fileManager = FileManager.default
        let expandedDir = (directory as NSString).expandingTildeInPath
        let dirUrl: URL
        if expandedDir.hasPrefix("/") {
            dirUrl = URL(fileURLWithPath: expandedDir)
        } else {
            let currentPath = fileManager.currentDirectoryPath
            dirUrl = URL(fileURLWithPath: currentPath).appendingPathComponent(expandedDir)
        }
        guard fileManager.fileExists(atPath: dirUrl.path) else { return }

        let filters = filter.components(separatedBy: .whitespaces).filter { !$0.isEmpty }

        var targetFiles: [URL] = []
        if let enumerator = fileManager.enumerator(at: dirUrl, includingPropertiesForKeys: [.isRegularFileKey], options: subfolders ? [] : [.skipsSubdirectoryDescendants]) {
            for case let fileUrl as URL in enumerator {
                var isReg: AnyObject?
                try? (fileUrl as NSURL).getResourceValue(&isReg, forKey: .isRegularFileKey)
                if let isReg = isReg as? Bool, isReg {
                    let filename = fileUrl.lastPathComponent
                    let matchesFilter = filters.isEmpty || filters.contains("*.*") || filters.contains("*") || filters.contains { pat in
                        fnmatch(pat, filename, 0) == 0
                    }
                    if matchesFilter {
                        targetFiles.append(fileUrl)
                    }
                }
            }
        }

        var groups: [NppSearchFileGroup] = []
        for fileUrl in targetFiles.prefix(200) {
            if let openDoc = documents.first(where: { $0.filePath?.standardizedFileURL.path == fileUrl.standardizedFileURL.path }) {
                let matches = searchInDocument(doc: openDoc, query: query, matchCase: matchCase, wholeWord: wholeWord, useRegex: useRegex)
                if !matches.isEmpty {
                    groups.append(NppSearchFileGroup(documentId: openDoc.id, documentTitle: openDoc.title, filePath: fileUrl, matches: matches))
                }
            } else if let content = (try? String(contentsOf: fileUrl, encoding: .utf8)) ?? (try? String(contentsOf: fileUrl, encoding: .ascii)) {
                let tempDoc = NppDocument(title: fileUrl.lastPathComponent, content: content)
                tempDoc.filePath = fileUrl
                let matches = searchInDocument(doc: tempDoc, query: query, matchCase: matchCase, wholeWord: wholeWord, useRegex: useRegex)
                if !matches.isEmpty {
                    groups.append(NppSearchFileGroup(documentId: tempDoc.id, documentTitle: tempDoc.title, filePath: fileUrl, matches: matches))
                }
            }
        }
        searchFileGroups = groups
        showSearchResultsPanel = true
    }

    @discardableResult
    public func replaceInFiles(
        query: String,
        replacement: String,
        filter: String,
        directory: String,
        subfolders: Bool,
        matchCase: Bool,
        wholeWord: Bool,
        useRegex: Bool
    ) -> (replacements: Int, filesModified: Int) {
        guard !query.isEmpty else { return (0, 0) }
        let fileManager = FileManager.default
        let expandedDir = (directory as NSString).expandingTildeInPath
        let dirUrl: URL
        if expandedDir.hasPrefix("/") {
            dirUrl = URL(fileURLWithPath: expandedDir)
        } else {
            let currentPath = fileManager.currentDirectoryPath
            dirUrl = URL(fileURLWithPath: currentPath).appendingPathComponent(expandedDir)
        }
        guard fileManager.fileExists(atPath: dirUrl.path) else { return (0, 0) }

        let filters = filter.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        var targetFiles: [URL] = []
        if let enumerator = fileManager.enumerator(at: dirUrl, includingPropertiesForKeys: [.isRegularFileKey], options: subfolders ? [] : [.skipsSubdirectoryDescendants]) {
            for case let fileUrl as URL in enumerator {
                var isReg: AnyObject?
                try? (fileUrl as NSURL).getResourceValue(&isReg, forKey: .isRegularFileKey)
                if let isReg = isReg as? Bool, isReg {
                    let filename = fileUrl.lastPathComponent
                    let matchesFilter = filters.isEmpty || filters.contains("*.*") || filters.contains("*") || filters.contains { pat in
                        fnmatch(pat, filename, 0) == 0
                    }
                    if matchesFilter {
                        targetFiles.append(fileUrl)
                    }
                }
            }
        }

        var pattern = useRegex ? query : NSRegularExpression.escapedPattern(for: query)
        if wholeWord {
            pattern = "\\b" + pattern + "\\b"
        }
        var regexOptions: NSRegularExpression.Options = []
        if !matchCase {
            regexOptions.insert(.caseInsensitive)
        }
        guard let regex = try? NSRegularExpression(pattern: pattern, options: regexOptions) else {
            return (0, 0)
        }
        let template = useRegex ? replacement : NSRegularExpression.escapedTemplate(for: replacement)

        var totalReplacements = 0
        var filesModified = 0

        for fileUrl in targetFiles.prefix(200) {
            guard let content = (try? String(contentsOf: fileUrl, encoding: .utf8)) ?? (try? String(contentsOf: fileUrl, encoding: .ascii)) else {
                continue
            }
            let fullRange = NSRange(location: 0, length: (content as NSString).length)
            let count = regex.numberOfMatches(in: content, options: [], range: fullRange)
            if count > 0 {
                let updated = regex.stringByReplacingMatches(in: content, options: [], range: fullRange, withTemplate: template)
                if (try? updated.write(to: fileUrl, atomically: true, encoding: .utf8)) != nil {
                    totalReplacements += count
                    filesModified += 1
                    if let openDoc = documents.first(where: { $0.filePath?.standardizedFileURL.path == fileUrl.standardizedFileURL.path }) {
                        openDoc.content = updated
                        openDoc.isDirty = false
                        if openDoc.id == activeDocumentId, let tv = activeTextView {
                            syncDocumentToTextView(doc: openDoc, tv: tv)
                        }
                    }
                }
            }
        }
        objectWillChange.send()
        return (totalReplacements, filesModified)
    }

    // MARK: - Notepad++ Column Editor (Alt+C)
    public func executeColumnEditor(isText: Bool, text: String, initialNumber: Int, increaseBy: Int, repeatCount: Int, format: String, leadingZeros: Bool, leadingSpaces: Bool = false) {
        guard let tv = activeTextView, let doc = activeDocument else { return }
        let str = tv.string as NSString
        let sel = tv.selectedRange()

        let selLineRange = str.lineRange(for: sel)
        var lineRanges: [NSRange] = []
        str.enumerateSubstrings(in: selLineRange, options: [.byLines, .substringNotRequired]) { _, subRange, _, _ in
            lineRanges.append(subRange)
        }
        if lineRanges.isEmpty {
            lineRanges.append(selLineRange)
        }

        let firstLineRange = str.lineRange(for: NSRange(location: sel.location, length: 0))
        let colOffset = sel.location - firstLineRange.location

        var insertStrings: [String] = []
        if isText {
            insertStrings = Array(repeating: text, count: lineRanges.count)
        } else {
            var currentNum = initialNumber
            var currentRepeat = 0
            for _ in 0..<lineRanges.count {
                let formattedNum: String
                switch format.lowercased() {
                case "hex":
                    formattedNum = String(format: leadingZeros ? "%04X" : (leadingSpaces ? "%4X" : "%X"), currentNum)
                case "hex_lower":
                    formattedNum = String(format: leadingZeros ? "%04x" : (leadingSpaces ? "%4x" : "%x"), currentNum)
                case "oct":
                    formattedNum = String(format: leadingZeros ? "%04o" : (leadingSpaces ? "%4o" : "%o"), currentNum)
                case "bin":
                    let rawBin = String(currentNum, radix: 2)
                    if leadingZeros && rawBin.count < 4 {
                        formattedNum = String(repeating: "0", count: 4 - rawBin.count) + rawBin
                    } else if leadingSpaces && rawBin.count < 4 {
                        formattedNum = String(repeating: " ", count: 4 - rawBin.count) + rawBin
                    } else {
                        formattedNum = rawBin
                    }
                default:
                    formattedNum = leadingZeros ? String(format: "%04d", currentNum) : (leadingSpaces ? String(format: "%4d", currentNum) : "\(currentNum)")
                }
                insertStrings.append(formattedNum)

                currentRepeat += 1
                if currentRepeat >= max(1, repeatCount) {
                    currentRepeat = 0
                    currentNum += increaseBy
                }
            }
        }

        var modifiedText = tv.string
        for (i, lineRange) in lineRanges.enumerated().reversed() {
            let lineStr = (str as NSString).substring(with: lineRange)
            let insertPos = lineRange.location + min(colOffset, (lineStr as NSString).length)
            let insertString = insertStrings[i]

            let nsMod = modifiedText as NSString
            modifiedText = nsMod.replacingCharacters(in: NSRange(location: insertPos, length: 0), with: insertString)
        }

        tv.string = modifiedText
        doc.content = modifiedText
        doc.isDirty = true
        objectWillChange.send()
    }

    public func saveActive() {
        guard let doc = activeDocument else { return }
        if doc.filePath != nil {
            _ = doc.save()
        } else {
            promptSaveAs(for: doc)
        }
    }

    public func saveAll() {
        for doc in documents where doc.isDirty {
            if doc.filePath != nil {
                _ = doc.save()
            } else {
                promptSaveAs(for: doc)
            }
        }
    }

    public func promptSaveAs(for doc: NppDocument) {
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = doc.filePath?.lastPathComponent ?? doc.title
        panel.begin { response in
            if response == .OK, let url = panel.url {
                _ = doc.save(to: url)
            }
        }
    }

    public func promptOpenFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.begin { [weak self] response in
            if response == .OK {
                for url in panel.urls {
                    self?.openFile(url: url)
                }
            }
        }
    }

    // MARK: - Authentic Notepad++ File Menu Operations (IDM_FILE_RENAME, IDM_FILE_SAVECOPYAS, etc.)
    @discardableResult
    public func renameDocument(id: UUID, newName: String) -> Bool {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let doc = documents.first(where: { $0.id == id }) else { return false }

        if let currentURL = doc.filePath {
            let newURL = currentURL.deletingLastPathComponent().appendingPathComponent(trimmed)
            if newURL.path == currentURL.path {
                return true
            }
            do {
                try FileManager.default.moveItem(at: currentURL, to: newURL)
                doc.filePath = newURL
                doc.title = newURL.lastPathComponent
                doc.language = NppDocument.detectLanguage(for: newURL)
                addRecentFile(newURL)
                objectWillChange.send()
                return true
            } catch {
                print("Failed to rename file on disk: \(error)")
                return false
            }
        } else {
            doc.title = trimmed
            let fakeURL = URL(fileURLWithPath: "/tmp/\(trimmed)")
            if !fakeURL.pathExtension.isEmpty {
                doc.language = NppDocument.detectLanguage(for: fakeURL)
            }
            objectWillChange.send()
            return true
        }
    }

    public func promptRenameDocument(for targetDoc: NppDocument? = nil) {
        guard let doc = targetDoc ?? activeDocument else { return }
        if let currentURL = doc.filePath {
            let panel = NSSavePanel()
            panel.title = tr("Rename...")
            panel.prompt = tr("Rename...")
            panel.directoryURL = currentURL.deletingLastPathComponent()
            panel.nameFieldStringValue = currentURL.lastPathComponent
            if panel.runModal() == .OK, let destURL = panel.url {
                if destURL.path != currentURL.path {
                    try? FileManager.default.moveItem(at: currentURL, to: destURL)
                    doc.filePath = destURL
                    doc.title = destURL.lastPathComponent
                    doc.language = NppDocument.detectLanguage(for: destURL)
                    addRecentFile(destURL)
                    objectWillChange.send()
                }
            }
        } else {
            let alert = NSAlert()
            alert.messageText = tr("Rename...")
            alert.informativeText = "\(doc.title)"
            alert.addButton(withTitle: "OK")
            alert.addButton(withTitle: "Cancel")
            let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
            input.stringValue = doc.title
            alert.accessoryView = input
            if alert.runModal() == .alertFirstButtonReturn {
                _ = renameDocument(id: doc.id, newName: input.stringValue)
            }
        }
    }

    @discardableResult
    public func saveCopyAs(for doc: NppDocument, to url: URL) -> Bool {
        // IDM_FILE_SAVECOPYAS: Writes content to disk without changing the buffer's own filePath or dirty state
        let origPath = doc.filePath
        let origTitle = doc.title
        let origDirty = doc.isDirty
        let ok = doc.save(to: url)
        doc.filePath = origPath
        doc.title = origTitle
        doc.isDirty = origDirty
        objectWillChange.send()
        return ok
    }

    public func promptSaveCopyAs(for targetDoc: NppDocument? = nil) {
        guard let doc = targetDoc ?? activeDocument else { return }
        let panel = NSSavePanel()
        panel.title = tr("Save a Copy As...")
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = doc.filePath?.lastPathComponent ?? doc.title
        if panel.runModal() == .OK, let url = panel.url {
            _ = saveCopyAs(for: doc, to: url)
        }
    }

    public func openInDefaultViewer() {
        guard let url = activeDocument?.filePath else { return }
        NSWorkspace.shared.open(url)
    }

    public func openFolderAsWorkspace(url: URL? = nil) {
        if let folderUrl = url {
            if !workspaceFolders.contains(where: { $0.path == folderUrl.path }) {
                workspaceFolders.append(folderUrl)
            }
            showFolderAsWorkspace = true
            return
        }
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let chosen = panel.url {
            if !workspaceFolders.contains(where: { $0.path == chosen.path }) {
                workspaceFolders.append(chosen)
            }
            showFolderAsWorkspace = true
        }
    }

    public func openContainingFolderAsWorkspace() {
        guard let fileUrl = activeDocument?.filePath else { return }
        let dirUrl = fileUrl.deletingLastPathComponent()
        openFolderAsWorkspace(url: dirUrl)
    }

    public func saveSession(to url: URL) -> Bool {
        let paths = documents.compactMap { $0.filePath?.path }
        guard let data = try? JSONSerialization.data(withJSONObject: paths, options: [.prettyPrinted]) else { return false }
        do {
            try data.write(to: url)
            return true
        } catch {
            return false
        }
    }

    public func loadSession(from url: URL) -> Bool {
        guard let data = try? Data(contentsOf: url),
              let paths = try? JSONSerialization.jsonObject(with: data) as? [String] else { return false }
        for p in paths {
            let fileURL = URL(fileURLWithPath: p)
            if FileManager.default.fileExists(atPath: fileURL.path) {
                openFile(url: fileURL)
            }
        }
        return true
    }

    public func promptSaveSession() {
        let panel = NSSavePanel()
        panel.title = tr("Save Session...")
        panel.nameFieldStringValue = "session.\(sessionFileExt)"
        if panel.runModal() == .OK, let url = panel.url {
            _ = saveSession(to: url)
        }
    }

    public func promptLoadSession() {
        let panel = NSOpenPanel()
        panel.title = tr("Load Session...")
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url {
            _ = loadSession(from: url)
        }
    }

    public func printNow() {
        if let tv = activeTextView ?? (NSApp.keyWindow?.firstResponder as? NSTextView) {
            let op = NSPrintOperation(view: tv)
            op.showsPrintPanel = false
            op.showsProgressPanel = false
            op.run()
        }
    }

    public func restoreRecentClosedFile() {
        while let lastURL = closedFilePaths.popLast() {
            if FileManager.default.fileExists(atPath: lastURL.path) {
                openFile(url: lastURL)
                return
            }
        }
    }

    public func openAllRecentFiles() {
        let urls = recentFiles
        for url in urls where FileManager.default.fileExists(atPath: url.path) {
            openFile(url: url)
        }
    }

    public func emptyRecentFilesList() {
        recentFiles.removeAll()
        closedFilePaths.removeAll()
    }

    @Published public var isOverwriteMode: Bool = false

    // MARK: - Authentic Notepad++ Macro Subsystem (NppCommands.cpp L1441-1506, RunMacroDlg.cpp, NppBigSwitch.cpp L1589-1705)
    public enum NppMacroStep: Codable, Equatable {
        case insertText(String)
        case deleteBackward
        case deleteForward
        case insertNewline
        case insertTab
        case moveLeft
        case moveRight
        case moveUp
        case moveDown
        case moveToBeginningOfLine
        case moveToEndOfLine
        case duplicateLine
        case deleteLine
        case moveLineUp
        case moveLineDown
        case trimTrailingSpace
        case trimLeadingSpace
        case trimBothSpace
        case uppercase
        case lowercase
        case toggleComment
        case saveDocument

        // 20 Edit Commands
        case cut
        case copy
        case paste
        case selectAll
        case joinLines
        case splitLines
        case insertEmptyLineAbove
        case insertEmptyLineBelow
        case removeEmptyLines
        case removeEmptyLinesContainingBlanks
        case removeDuplicateLines
        case sortLines
        case sortLinesDescending
        case sortLinesIntegersAscending
        case sortLinesIntegersDescending
        case sortLinesDecimalsDotAscending
        case sortLinesDecimalsDotDescending
        case sortLinesDecimalsCommaAscending
        case sortLinesDecimalsCommaDescending
        case reverseLineOrder
        case singleLineComment
        case singleLineUncomment
        case streamComment
        case streamUncomment
        case eolToSpace
        case tabToSpace
        case spaceToTab
        case insertDateTime
        case insertDateTimeLong
        case insertDateTimeCustomized

        public var actionName: String {
            switch self {
            case .insertText: return "insertText"
            case .deleteBackward: return "deleteBackward"
            case .deleteForward: return "deleteForward"
            case .insertNewline: return "insertNewline"
            case .insertTab: return "insertTab"
            case .moveLeft: return "moveLeft"
            case .moveRight: return "moveRight"
            case .moveUp: return "moveUp"
            case .moveDown: return "moveDown"
            case .moveToBeginningOfLine: return "moveToBeginningOfLine"
            case .moveToEndOfLine: return "moveToEndOfLine"
            case .duplicateLine: return "duplicateLine"
            case .deleteLine: return "deleteLine"
            case .moveLineUp: return "moveLineUp"
            case .moveLineDown: return "moveLineDown"
            case .trimTrailingSpace: return "trimTrailingSpace"
            case .trimLeadingSpace: return "trimLeadingSpace"
            case .trimBothSpace: return "trimBothSpace"
            case .uppercase: return "uppercase"
            case .lowercase: return "lowercase"
            case .toggleComment: return "toggleComment"
            case .saveDocument: return "saveDocument"
            case .cut: return "cut"
            case .copy: return "copy"
            case .paste: return "paste"
            case .selectAll: return "selectAll"
            case .joinLines: return "joinLines"
            case .splitLines: return "splitLines"
            case .insertEmptyLineAbove: return "insertEmptyLineAbove"
            case .insertEmptyLineBelow: return "insertEmptyLineBelow"
            case .removeEmptyLines: return "removeEmptyLines"
            case .removeEmptyLinesContainingBlanks: return "removeEmptyLinesContainingBlanks"
            case .removeDuplicateLines: return "removeDuplicateLines"
            case .sortLines: return "sortLines"
            case .sortLinesDescending: return "sortLinesDescending"
            case .sortLinesIntegersAscending: return "sortLinesIntegersAscending"
            case .sortLinesIntegersDescending: return "sortLinesIntegersDescending"
            case .sortLinesDecimalsDotAscending: return "sortLinesDecimalsDotAscending"
            case .sortLinesDecimalsDotDescending: return "sortLinesDecimalsDotDescending"
            case .sortLinesDecimalsCommaAscending: return "sortLinesDecimalsCommaAscending"
            case .sortLinesDecimalsCommaDescending: return "sortLinesDecimalsCommaDescending"
            case .reverseLineOrder: return "reverseLineOrder"
            case .singleLineComment: return "singleLineComment"
            case .singleLineUncomment: return "singleLineUncomment"
            case .streamComment: return "streamComment"
            case .streamUncomment: return "streamUncomment"
            case .eolToSpace: return "eolToSpace"
            case .tabToSpace: return "tabToSpace"
            case .spaceToTab: return "spaceToTab"
            case .insertDateTime: return "insertDateTime"
            case .insertDateTimeLong: return "insertDateTimeLong"
            case .insertDateTimeCustomized: return "insertDateTimeCustomized"
            }
        }

        public init?(actionName: String, text: String?) {
            switch actionName {
            case "insertText": self = .insertText(text ?? "")
            case "deleteBackward": self = .deleteBackward
            case "deleteForward": self = .deleteForward
            case "insertNewline": self = .insertNewline
            case "insertTab": self = .insertTab
            case "moveLeft": self = .moveLeft
            case "moveRight": self = .moveRight
            case "moveUp": self = .moveUp
            case "moveDown": self = .moveDown
            case "moveToBeginningOfLine": self = .moveToBeginningOfLine
            case "moveToEndOfLine": self = .moveToEndOfLine
            case "duplicateLine": self = .duplicateLine
            case "deleteLine": self = .deleteLine
            case "moveLineUp": self = .moveLineUp
            case "moveLineDown": self = .moveLineDown
            case "trimTrailingSpace": self = .trimTrailingSpace
            case "trimLeadingSpace": self = .trimLeadingSpace
            case "trimBothSpace": self = .trimBothSpace
            case "uppercase": self = .uppercase
            case "lowercase": self = .lowercase
            case "toggleComment": self = .toggleComment
            case "saveDocument": self = .saveDocument
            case "cut": self = .cut
            case "copy": self = .copy
            case "paste": self = .paste
            case "selectAll": self = .selectAll
            case "joinLines": self = .joinLines
            case "splitLines": self = .splitLines
            case "insertEmptyLineAbove": self = .insertEmptyLineAbove
            case "insertEmptyLineBelow": self = .insertEmptyLineBelow
            case "removeEmptyLines": self = .removeEmptyLines
            case "removeEmptyLinesContainingBlanks": self = .removeEmptyLinesContainingBlanks
            case "removeDuplicateLines": self = .removeDuplicateLines
            case "sortLines": self = .sortLines
            case "sortLinesDescending": self = .sortLinesDescending
            case "sortLinesIntegersAscending": self = .sortLinesIntegersAscending
            case "sortLinesIntegersDescending": self = .sortLinesIntegersDescending
            case "sortLinesDecimalsDotAscending": self = .sortLinesDecimalsDotAscending
            case "sortLinesDecimalsDotDescending": self = .sortLinesDecimalsDotDescending
            case "sortLinesDecimalsCommaAscending": self = .sortLinesDecimalsCommaAscending
            case "sortLinesDecimalsCommaDescending": self = .sortLinesDecimalsCommaDescending
            case "reverseLineOrder": self = .reverseLineOrder
            case "singleLineComment": self = .singleLineComment
            case "singleLineUncomment": self = .singleLineUncomment
            case "streamComment": self = .streamComment
            case "streamUncomment": self = .streamUncomment
            case "eolToSpace": self = .eolToSpace
            case "tabToSpace": self = .tabToSpace
            case "spaceToTab": self = .spaceToTab
            case "insertDateTime": self = .insertDateTime
            case "insertDateTimeLong": self = .insertDateTimeLong
            case "insertDateTimeCustomized": self = .insertDateTimeCustomized
            default: return nil
            }
        }

        private enum CodingKeys: String, CodingKey {
            case action
            case text
            case type
            case value
        }

        public init(from decoder: Decoder) throws {
            if let singleContainer = try? decoder.singleValueContainer(),
               let rawAction = try? singleContainer.decode(String.self) {
                if let step = NppMacroStep(actionName: rawAction, text: nil) {
                    self = step
                    return
                } else {
                    throw DecodingError.dataCorrupted(
                        DecodingError.Context(
                            codingPath: decoder.codingPath,
                            debugDescription: "Unknown macro step action name: \(rawAction)"
                        )
                    )
                }
            }

            let container = try decoder.container(keyedBy: CodingKeys.self)
            let action = (try? container.decode(String.self, forKey: .action))
                ?? (try? container.decode(String.self, forKey: .type))
                ?? ""
            let text = (try? container.decode(String.self, forKey: .text))
                ?? (try? container.decode(String.self, forKey: .value))

            if let step = NppMacroStep(actionName: action, text: text) {
                self = step
            } else {
                throw DecodingError.dataCorruptedError(forKey: .action, in: container, debugDescription: "Unknown action: \(action)")
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .insertText(let str):
                try container.encode("insertText", forKey: .action)
                try container.encode(str, forKey: .text)
            default:
                try container.encode(actionName, forKey: .action)
            }
        }
    }

    public struct NppSavedMacro: Identifiable, Equatable, Codable {
        public var id: UUID
        public var name: String
        public var shortcut: String
        public var steps: [NppMacroStep]

        public init(id: UUID = UUID(), name: String, shortcut: String = "", steps: [NppMacroStep]) {
            self.id = id
            self.name = name
            self.shortcut = shortcut
            self.steps = steps
        }

        private enum CodingKeys: String, CodingKey {
            case id
            case name
            case shortcut
            case steps
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.id = (try? container.decode(UUID.self, forKey: .id)) ?? UUID()
            let rawName = (try? container.decode(String.self, forKey: .name)) ?? ""
            let trimmedName = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedName.isEmpty else {
                throw DecodingError.dataCorruptedError(
                    forKey: .name,
                    in: container,
                    debugDescription: "Macro name cannot be empty"
                )
            }
            self.name = trimmedName
            self.shortcut = (try? container.decode(String.self, forKey: .shortcut)) ?? ""
            let decodedSteps = try container.decode([NppMacroStep].self, forKey: .steps)
            guard !decodedSteps.isEmpty else {
                throw DecodingError.dataCorruptedError(
                    forKey: .steps,
                    in: container,
                    debugDescription: "Saved macro steps cannot be empty"
                )
            }
            self.steps = decodedSteps
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(id, forKey: .id)
            try container.encode(name, forKey: .name)
            try container.encode(shortcut, forKey: .shortcut)
            try container.encode(steps, forKey: .steps)
        }
    }

    public static let savedMacrosUserDefaultsKey = "npp.savedMacros.v1"
    public static let defaultSavedMacros: [NppSavedMacro] = [
        NppSavedMacro(name: "Trim Trailing Space and Save", shortcut: "Alt+Shift+S", steps: [.trimTrailingSpace, .saveDocument])
    ]
    private var isLoadingSavedMacros: Bool = false

    @Published public var isMacroRecording: Bool = false
    @Published public var isRecordingSaved: Bool = false
    @Published public var recordedMacroSteps: [NppMacroStep] = []
    public var recordedMacroActions: [String] = []
    @Published public var savedMacros: [NppSavedMacro] = NppWorkspace.defaultSavedMacros {
        didSet {
            if !isLoadingSavedMacros {
                persistSavedMacros()
            }
        }
    }
    @Published public var selectedMacroToRun: String = "Trim Trailing Space and Save"
    @Published public var customShortcuts: [String: String] = [:]
    @Published public var showRunMacroDialog: Bool = false
    private var isPlayingBackMacro: Bool = false

    public var hasRecordedMacro: Bool {
        !recordedMacroSteps.isEmpty && !isMacroRecording
    }

    public var canSaveRecordedMacro: Bool {
        !recordedMacroSteps.isEmpty && !isMacroRecording && !isRecordingSaved
    }

    public var canRunMultiMacro: Bool {
        !isMacroRecording && (!recordedMacroSteps.isEmpty || !savedMacros.isEmpty)
    }

    public var availableMacros: [String] {
        var list: [String] = []
        if hasRecordedMacro {
            list.append("Current recorded macro")
        }
        for saved in savedMacros {
            list.append(saved.name)
        }
        return list
    }

    public func ensureValidSelectedMacro() {
        let avail = availableMacros
        if !avail.contains(selectedMacroToRun) {
            selectedMacroToRun = avail.first ?? ""
        }
    }

    public var canPlaybackMacro: Bool {
        guard !isMacroRecording else { return false }
        if selectedMacroToRun == "Current recorded macro" {
            return !recordedMacroSteps.isEmpty
        }
        if savedMacros.contains(where: { $0.name == selectedMacroToRun }) {
            return true
        }
        return !recordedMacroSteps.isEmpty || !savedMacros.isEmpty
    }

    public func loadSavedMacros() {
        isLoadingSavedMacros = true
        defer { isLoadingSavedMacros = false }
        if let data = UserDefaults.standard.data(forKey: Self.savedMacrosUserDefaultsKey) {
            var validMacros: [NppSavedMacro] = []

            if let decoded = try? JSONDecoder().decode([NppSavedMacro].self, from: data),
               !decoded.isEmpty,
               decoded.allSatisfy({ !$0.steps.isEmpty }) {
                validMacros = decoded
            } else if let jsonArray = (try? JSONSerialization.jsonObject(with: data)) as? [Any] {
                let decoder = JSONDecoder()
                for item in jsonArray {
                    guard JSONSerialization.isValidJSONObject(item),
                          let itemData = try? JSONSerialization.data(withJSONObject: item),
                          let macro = try? decoder.decode(NppSavedMacro.self, from: itemData),
                          !macro.steps.isEmpty else {
                        continue
                    }
                    validMacros.append(macro)
                }
            }

            if !validMacros.isEmpty {
                self.savedMacros = validMacros
            } else {
                self.savedMacros = Self.defaultSavedMacros
            }
        } else {
            self.savedMacros = Self.defaultSavedMacros
        }
        ensureValidSelectedMacro()
    }

    public func persistSavedMacros() {
        guard !isLoadingSavedMacros else { return }
        do {
            let data = try JSONEncoder().encode(savedMacros)
            UserDefaults.standard.set(data, forKey: Self.savedMacrosUserDefaultsKey)
        } catch {
            print("Failed to persist savedMacros: \(error)")
        }
    }

    public func deleteSavedMacro(named name: String) {
        savedMacros.removeAll { $0.name == name }
        ensureValidSelectedMacro()
        persistSavedMacros()
    }

    public func updateSavedMacro(named originalName: String, newName: String, newShortcut: String) {
        if let idx = savedMacros.firstIndex(where: { $0.name == originalName }) {
            savedMacros[idx].name = newName
            savedMacros[idx].shortcut = (newShortcut == "None") ? "" : newShortcut
            if selectedMacroToRun == originalName {
                selectedMacroToRun = newName
            }
            persistSavedMacros()
        }
    }

    public func recordMacroStep(_ step: NppMacroStep) {
        guard isMacroRecording && !isPlayingBackMacro else { return }
        recordedMacroSteps.append(step)
        recordedMacroActions.append("\(step)")
        isRecordingSaved = false
    }

    public func zoomIn() {
        fontSize = min(fontSize + 1.0, 36.0)
    }

    public func zoomOut() {
        fontSize = max(fontSize - 1.0, 8.0)
    }

    public func resetZoom() {
        fontSize = 13.0
    }

    public static let defaultLanguages: [String] = [
        "C", "C++", "C#", "Swift", "Python", "JavaScript", "TypeScript",
        "HTML", "CSS", "JSON", "XML", "SQL", "Shell", "Markdown",
        "Java", "Rust", "Go", "PHP", "Ruby", "YAML"
    ]

    public func showDocumentSummary() {
        guard let doc = activeDocument else { return }
        let lineCount = max(1, doc.content.nppLines().count)
        let words = doc.content.split { $0.isWhitespace || $0.isNewline }.count
        let nonSpace = doc.content.filter { !$0.isWhitespace && !$0.isNewline }.count
        let utf8Bytes = (doc.content.data(using: .utf8) ?? Data()).count

        let pathStr = doc.filePath?.path ?? tr("[New Document]")
        var createdStr = tr("Unknown")
        var modifiedStr = tr("Unknown")
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

        if let filePath = doc.filePath,
           let attrs = try? FileManager.default.attributesOfItem(atPath: filePath.path) {
            if let crDate = attrs[.creationDate] as? Date {
                createdStr = formatter.string(from: crDate)
            }
            if let modDate = attrs[.modificationDate] as? Date {
                modifiedStr = formatter.string(from: modDate)
            }
        } else {
            createdStr = formatter.string(from: Date())
            modifiedStr = formatter.string(from: Date())
        }

        var info = ""
        info += "\(tr("Full file path")): \(pathStr)\n"
        info += "\(tr("Created")): \(createdStr)\n"
        info += "\(tr("Modified")): \(modifiedStr)\n"
        info += "\(tr("Characters (without line endings)")): \(nonSpace)\n"
        info += "\(tr("Words")): \(words)\n"
        info += "\(tr("Lines")): \(lineCount)\n"
        info += "\(tr("Document length")): \(utf8Bytes) bytes"

        if doc.selectionLength > 0 {
            let nsStr = doc.content as NSString
            let safeLoc = min(doc.cursorPos, nsStr.length)
            let safeLen = min(doc.selectionLength, max(0, nsStr.length - safeLoc))
            let selText = nsStr.substring(with: NSRange(location: safeLoc, length: safeLen))
            let selBytes = (selText.data(using: .utf8) ?? Data()).count
            info += "\n\(doc.selectionLength) \(tr("selected characters")) (\(selBytes) bytes) \(tr("in 1 range"))"
        }

        let alert = NSAlert()
        alert.messageText = tr("Summary")
        alert.informativeText = info
        alert.alertStyle = .informational
        alert.addButton(withTitle: tr("OK"))
        alert.runModal()
    }

    // MARK: - Tab Navigation & Sorting (Window Menu)
    public func nextTab() {
        guard documents.count > 1, let currentId = activeDocumentId,
              let currentIndex = documents.firstIndex(where: { $0.id == currentId }) else { return }
        let nextIndex = (currentIndex + 1) % documents.count
        activeDocumentId = documents[nextIndex].id
    }

    public func prevTab() {
        guard documents.count > 1, let currentId = activeDocumentId,
              let currentIndex = documents.firstIndex(where: { $0.id == currentId }) else { return }
        let prevIndex = (currentIndex - 1 + documents.count) % documents.count
        activeDocumentId = documents[prevIndex].id
    }

    public func selectTab(at index: Int) {
        guard index >= 0 && index < documents.count else { return }
        activeDocumentId = documents[index].id
    }

    public func moveTabForward() {
        guard let currentId = activeDocumentId,
              let index = documents.firstIndex(where: { $0.id == currentId }),
              index + 1 < documents.count else { return }
        documents.swapAt(index, index + 1)
    }

    public func moveTabBackward() {
        guard let currentId = activeDocumentId,
              let index = documents.firstIndex(where: { $0.id == currentId }),
              index > 0 else { return }
        documents.swapAt(index, index - 1)
    }

    public func sortTabsByName(ascending: Bool) {
        documents.sort {
            ascending ? $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
                      : $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedDescending
        }
    }

    public func sortTabsByPath(ascending: Bool) {
        documents.sort {
            let p1 = $0.filePath?.path ?? $0.title
            let p2 = $1.filePath?.path ?? $1.title
            return ascending ? p1.localizedCaseInsensitiveCompare(p2) == .orderedAscending
                             : p1.localizedCaseInsensitiveCompare(p2) == .orderedDescending
        }
    }

    public func selectFirstTab() {
        guard let first = documents.first else { return }
        activeDocumentId = first.id
    }

    public func selectLastTab() {
        guard let last = documents.last else { return }
        activeDocumentId = last.id
    }

    public func applyTabColor(_ colorId: Int) {
        guard let doc = activeDocument else { return }
        doc.tabColorId = max(0, min(5, colorId))
        objectWillChange.send()
    }

    public func sortTabsByType(ascending: Bool) {
        documents.sort { a, b in
            let extA = a.filePath?.pathExtension.lowercased() ?? (a.title as NSString).pathExtension.lowercased()
            let extB = b.filePath?.pathExtension.lowercased() ?? (b.title as NSString).pathExtension.lowercased()
            if extA != extB {
                return ascending
                    ? extA.localizedCaseInsensitiveCompare(extB) == .orderedAscending
                    : extA.localizedCaseInsensitiveCompare(extB) == .orderedDescending
            }
            return ascending
                ? a.title.localizedCaseInsensitiveCompare(b.title) == .orderedAscending
                : a.title.localizedCaseInsensitiveCompare(b.title) == .orderedDescending
        }
    }

    public func sortTabsBySize(ascending: Bool) {
        documents.sort {
            ascending ? $0.content.count < $1.content.count : $0.content.count > $1.content.count
        }
    }

    public func closeActive() {
        if let doc = activeDocument {
            closeDocument(id: doc.id)
        }
    }

    public func printActive() {
        if let tv = activeTextView ?? (NSApp.keyWindow?.firstResponder as? NSTextView) {
            let op = NSPrintOperation(view: tv)
            op.run()
        }
    }

    public func startMacroRecording() {
        isMacroRecording = true
        isRecordingSaved = false
        recordedMacroSteps.removeAll()
        recordedMacroActions.removeAll()
        if selectedMacroToRun == "Current recorded macro" {
            selectedMacroToRun = savedMacros.first?.name ?? ""
        }
    }

    public func stopMacroRecording() {
        isMacroRecording = false
        if !recordedMacroSteps.isEmpty {
            selectedMacroToRun = "Current recorded macro"
        } else {
            ensureValidSelectedMacro()
        }
    }

    public func toggleMacroRecording() {
        if isMacroRecording {
            stopMacroRecording()
        } else {
            startMacroRecording()
        }
    }

    public func playbackMacro() {
        guard !isMacroRecording else { return }
        ensureValidSelectedMacro()
        let name = selectedMacroToRun
        if name == "Current recorded macro" {
            guard !recordedMacroSteps.isEmpty else { return }
            executeMacroSteps(recordedMacroSteps)
        } else if let saved = savedMacros.first(where: { $0.name == name }) {
            executeMacroSteps(saved.steps)
        } else if !recordedMacroSteps.isEmpty {
            executeMacroSteps(recordedMacroSteps)
        } else if let firstSaved = savedMacros.first {
            executeMacroSteps(firstSaved.steps)
        }
    }

    public func runMacroMultipleTimes() {
        guard !isMacroRecording else { return }
        ensureValidSelectedMacro()
        showRunMacroDialog = true
    }

    public func saveCurrentRecordedMacro(name: String, shortcut: String = "") -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty && !recordedMacroSteps.isEmpty && !isMacroRecording else { return false }
        if let idx = savedMacros.firstIndex(where: { $0.name == trimmed }) {
            savedMacros[idx].steps = recordedMacroSteps
            if !shortcut.isEmpty { savedMacros[idx].shortcut = shortcut }
        } else {
            savedMacros.append(NppSavedMacro(name: trimmed, shortcut: shortcut, steps: recordedMacroSteps))
        }
        isRecordingSaved = true
        selectedMacroToRun = trimmed
        persistSavedMacros()
        return true
    }

    public func promptSaveCurrentRecordedMacro() {
        guard canSaveRecordedMacro else { return }
        let alert = NSAlert()
        alert.messageText = tr("Save Current Recorded Macro...")
        alert.informativeText = tr("Name:")
        alert.addButton(withTitle: tr("OK"))
        alert.addButton(withTitle: tr("Cancel"))

        let container = NSView(frame: NSRect(x: 0, y: 0, width: 280, height: 56))
        let nameField = NSTextField(frame: NSRect(x: 0, y: 30, width: 280, height: 24))
        nameField.placeholderString = "My Macro"
        nameField.stringValue = "Macro \(savedMacros.count + 1)"

        let shortcutLabel = NSTextField(labelWithString: "Shortcut (optional):")
        shortcutLabel.font = NSFont.systemFont(ofSize: 11)
        shortcutLabel.frame = NSRect(x: 0, y: 4, width: 120, height: 18)

        let shortcutField = NSTextField(frame: NSRect(x: 125, y: 2, width: 155, height: 22))
        shortcutField.placeholderString = "e.g. Cmd+Option+M"

        container.addSubview(nameField)
        container.addSubview(shortcutLabel)
        container.addSubview(shortcutField)
        alert.accessoryView = container
        alert.window.initialFirstResponder = nameField

        if alert.runModal() == .alertFirstButtonReturn {
            _ = saveCurrentRecordedMacro(name: nameField.stringValue, shortcut: shortcutField.stringValue)
        }
    }

    public func executeSavedMacro(named name: String) {
        guard !isMacroRecording,
              let macro = savedMacros.first(where: { $0.name == name }) else { return }
        executeMacroSteps(macro.steps)
    }

    public func executeMultiMacro(macroName: String = "", runUntilEOF: Bool, times: Int) {
        guard !isMacroRecording else { return }
        let targetName = macroName.isEmpty ? selectedMacroToRun : macroName
        let steps: [NppMacroStep]
        if targetName == "Current recorded macro" {
            guard hasRecordedMacro else { return }
            steps = recordedMacroSteps
        } else if let saved = savedMacros.first(where: { $0.name == targetName }) {
            steps = saved.steps
        } else {
            // Target macro not found: DO NOT fall back to recordedMacroSteps!
            return
        }
        guard !steps.isEmpty else { return }

        selectedMacroToRun = targetName

        if !runUntilEOF {
            let repeatCount = max(1, times)
            for _ in 0..<repeatCount {
                executeMacroSteps(steps)
            }
        } else {
            // Run until the end of file (matching NppBigSwitch.cpp L1675-1705)
            guard let doc = activeDocument else { return }
            let lineCount = doc.content.components(separatedBy: "\n").count
            let maxIterations = max(1000, lineCount * 100)
            var counter = 0
            while counter < maxIterations {
                let prevCursor = activeTextView?.selectedRange().location ?? doc.cursorPos
                let prevLen = (activeTextView?.string as NSString?)?.length ?? (doc.content as NSString).length
                executeMacroSteps(steps)
                counter += 1
                let newCursor = activeTextView?.selectedRange().location ?? doc.cursorPos
                let newLen = (activeTextView?.string as NSString?)?.length ?? (doc.content as NSString).length
                if newCursor >= newLen {
                    break
                }
                if newCursor <= prevCursor && newLen >= prevLen {
                    break
                }
            }
        }
    }

    /// Synchronizes changes from NSTextView into NppDocument (content, dirty state, cursor, selection, and EOL format).
    private func syncTextViewToDocument(tv: NSTextView, doc: NppDocument) {
        if doc.content != tv.string {
            doc.content = tv.string
            doc.isDirty = true
        }
        if doc.content.contains("\r\n") {
            doc.eolFormat = .crlf
        } else if doc.content.contains("\n") {
            doc.eolFormat = .lf
        } else if doc.content.contains("\r") {
            doc.eolFormat = .cr
        }
        let sel = tv.selectedRange()
        doc.cursorPos = sel.location
        doc.selectionLength = sel.length
    }

    /// Synchronizes changes from NppDocument into NSTextView, safely clamping and preserving selection.
    private func syncDocumentToTextView(doc: NppDocument, tv: NSTextView) {
        if tv.string != doc.content {
            let sel = tv.selectedRange()
            let newLen = (doc.content as NSString).length
            tv.string = doc.content
            let safeLoc = min(sel.location, newLen)
            let safeLen = min(sel.length, max(0, newLen - safeLoc))
            tv.setSelectedRange(NSRange(location: safeLoc, length: safeLen))
        }
    }

    private func executeDocumentOperation(tv: NSTextView?, doc: NppDocument, operation: () -> Void) {
        if let tv = tv {
            syncTextViewToDocument(tv: tv, doc: doc)
        } else {
            if doc.content.contains("\r\n") {
                doc.eolFormat = .crlf
            } else if doc.content.contains("\n") {
                doc.eolFormat = .lf
            } else if doc.content.contains("\r") {
                doc.eolFormat = .cr
            }
        }
        operation()
        if let tv = tv {
            syncDocumentToTextView(doc: doc, tv: tv)
        }
    }

    private func withTextView(tv: NSTextView?, doc: NppDocument, action: (NSTextView) -> Void) {
        if let tv = tv {
            syncDocumentToTextView(doc: doc, tv: tv)
            action(tv)
            syncTextViewToDocument(tv: tv, doc: doc)
        } else {
            let fallback = NSTextView()
            fallback.string = doc.content
            let pos = min(doc.cursorPos, (doc.content as NSString).length)
            let len = min(doc.selectionLength, max(0, (doc.content as NSString).length - pos))
            fallback.setSelectedRange(NSRange(location: pos, length: len))
            action(fallback)
            doc.content = fallback.string
            doc.cursorPos = fallback.selectedRange().location
            doc.selectionLength = fallback.selectedRange().length
            doc.isDirty = true
        }
    }

    public func executeMacroStep(_ step: NppMacroStep, in textView: NSTextView? = nil, document: NppDocument? = nil) {
        let tv = textView ?? activeTextView ?? (NSApp.keyWindow?.firstResponder as? NSTextView)
        guard let doc = document ?? activeDocument else { return }

        if let tv = tv, doc.content != tv.string {
            syncTextViewToDocument(tv: tv, doc: doc)
        }

        let isEffectiveReadOnly = doc.isReadOnly || isAllDocumentsReadOnly
        if isEffectiveReadOnly {
            switch step {
            case .moveLeft, .moveRight, .moveUp, .moveDown, .moveToBeginningOfLine, .moveToEndOfLine, .copy, .selectAll, .saveDocument:
                break
            default:
                return
            }
        }

        switch step {
        case .insertText(let text):
            if let tv = tv {
                let sel = tv.selectedRange()
                tv.insertText(text, replacementRange: sel)
                syncTextViewToDocument(tv: tv, doc: doc)
            } else {
                let ns = doc.content as NSString
                let pos = min(doc.cursorPos, ns.length)
                let len = min(doc.selectionLength, max(0, ns.length - pos))
                doc.content = ns.replacingCharacters(in: NSRange(location: pos, length: len), with: text)
                doc.cursorPos = pos + (text as NSString).length
                doc.selectionLength = 0
                doc.isDirty = true
            }
        case .deleteBackward:
            if let tv = tv {
                tv.deleteBackward(nil)
                syncTextViewToDocument(tv: tv, doc: doc)
            } else if doc.cursorPos > 0 {
                let ns = doc.content as NSString
                let pos = min(doc.cursorPos, ns.length)
                if pos > 0 {
                    doc.content = ns.replacingCharacters(in: NSRange(location: pos - 1, length: 1), with: "")
                    doc.cursorPos = pos - 1
                    doc.isDirty = true
                }
            }
        case .deleteForward:
            if let tv = tv {
                tv.deleteForward(nil)
                syncTextViewToDocument(tv: tv, doc: doc)
            } else {
                let ns = doc.content as NSString
                let pos = min(doc.cursorPos, ns.length)
                if pos < ns.length {
                    doc.content = ns.replacingCharacters(in: NSRange(location: pos, length: 1), with: "")
                    doc.isDirty = true
                }
            }
        case .insertNewline:
            if let tv = tv {
                tv.insertNewline(nil)
                syncTextViewToDocument(tv: tv, doc: doc)
            } else {
                let ns = doc.content as NSString
                let pos = min(doc.cursorPos, ns.length)
                doc.content = ns.replacingCharacters(in: NSRange(location: pos, length: 0), with: "\n")
                doc.cursorPos = pos + 1
                doc.isDirty = true
            }
        case .insertTab:
            if let tv = tv {
                tv.insertTab(nil)
                syncTextViewToDocument(tv: tv, doc: doc)
            } else {
                let ns = doc.content as NSString
                let pos = min(doc.cursorPos, ns.length)
                doc.content = ns.replacingCharacters(in: NSRange(location: pos, length: 0), with: "\t")
                doc.cursorPos = pos + 1
                doc.isDirty = true
            }
        case .moveLeft:
            tv?.moveLeft(nil)
            if let tv = tv { syncTextViewToDocument(tv: tv, doc: doc) }
        case .moveRight:
            tv?.moveRight(nil)
            if let tv = tv { syncTextViewToDocument(tv: tv, doc: doc) }
        case .moveUp:
            tv?.moveUp(nil)
            if let tv = tv { syncTextViewToDocument(tv: tv, doc: doc) }
        case .moveDown:
            tv?.moveDown(nil)
            if let tv = tv { syncTextViewToDocument(tv: tv, doc: doc) }
        case .moveToBeginningOfLine:
            tv?.moveToBeginningOfLine(nil)
            if let tv = tv { syncTextViewToDocument(tv: tv, doc: doc) }
        case .moveToEndOfLine:
            tv?.moveToEndOfLine(nil)
            if let tv = tv { syncTextViewToDocument(tv: tv, doc: doc) }
        case .cut:
            withTextView(tv: tv, doc: doc) { $0.cut(nil) }
        case .copy:
            withTextView(tv: tv, doc: doc) { $0.copy(nil) }
        case .paste:
            withTextView(tv: tv, doc: doc) { $0.paste(nil) }
        case .selectAll:
            withTextView(tv: tv, doc: doc) { $0.selectAll(nil) }
        case .duplicateLine:
            withTextView(tv: tv, doc: doc) { NppEditOperations.duplicateLine(in: $0) }
        case .deleteLine:
            withTextView(tv: tv, doc: doc) { targetTv in
                let ns = targetTv.string as NSString
                let lr = ns.lineRange(for: targetTv.selectedRange())
                if targetTv.shouldChangeText(in: lr, replacementString: "") {
                    targetTv.replaceCharacters(in: lr, with: "")
                    targetTv.didChangeText()
                }
            }
        case .moveLineUp:
            withTextView(tv: tv, doc: doc) { NppEditOperations.moveLineUp(in: $0) }
        case .moveLineDown:
            withTextView(tv: tv, doc: doc) { NppEditOperations.moveLineDown(in: $0) }
        case .joinLines:
            withTextView(tv: tv, doc: doc) { NppEditOperations.joinLines(in: $0) }
        case .splitLines:
            withTextView(tv: tv, doc: doc) { NppEditOperations.splitLines(in: $0) }
        case .insertEmptyLineAbove:
            withTextView(tv: tv, doc: doc) { NppEditOperations.insertEmptyLineAbove(in: $0) }
        case .insertEmptyLineBelow:
            withTextView(tv: tv, doc: doc) { NppEditOperations.insertEmptyLineBelow(in: $0) }
        case .removeEmptyLines:
            executeDocumentOperation(tv: tv, doc: doc) {
                NppEditOperations.removeEmptyLines(in: doc, removeBlankChars: false)
            }
        case .removeEmptyLinesContainingBlanks:
            executeDocumentOperation(tv: tv, doc: doc) {
                NppEditOperations.removeEmptyLines(in: doc, removeBlankChars: true)
            }
        case .removeDuplicateLines:
            executeDocumentOperation(tv: tv, doc: doc) {
                NppEditOperations.removeDuplicateLines(in: doc, consecutiveOnly: false)
            }
        case .sortLines:
            executeDocumentOperation(tv: tv, doc: doc) {
                NppEditOperations.sortLines(in: doc, ascending: true, ignoreCase: false)
            }
        case .sortLinesDescending:
            executeDocumentOperation(tv: tv, doc: doc) {
                NppEditOperations.sortLines(in: doc, ascending: false, ignoreCase: false)
            }
        case .sortLinesIntegersAscending:
            executeDocumentOperation(tv: tv, doc: doc) {
                NppEditOperations.sortLinesAsIntegers(in: doc, ascending: true)
            }
        case .sortLinesIntegersDescending:
            executeDocumentOperation(tv: tv, doc: doc) {
                NppEditOperations.sortLinesAsIntegers(in: doc, ascending: false)
            }
        case .sortLinesDecimalsDotAscending:
            executeDocumentOperation(tv: tv, doc: doc) {
                NppEditOperations.sortLinesAsDecimals(in: doc, ascending: true, usesComma: false)
            }
        case .sortLinesDecimalsDotDescending:
            executeDocumentOperation(tv: tv, doc: doc) {
                NppEditOperations.sortLinesAsDecimals(in: doc, ascending: false, usesComma: false)
            }
        case .sortLinesDecimalsCommaAscending:
            executeDocumentOperation(tv: tv, doc: doc) {
                NppEditOperations.sortLinesAsDecimals(in: doc, ascending: true, usesComma: true)
            }
        case .sortLinesDecimalsCommaDescending:
            executeDocumentOperation(tv: tv, doc: doc) {
                NppEditOperations.sortLinesAsDecimals(in: doc, ascending: false, usesComma: true)
            }
        case .reverseLineOrder:
            executeDocumentOperation(tv: tv, doc: doc) {
                NppEditOperations.reverseLineOrder(in: doc)
            }
        case .singleLineComment:
            withTextView(tv: tv, doc: doc) { NppEditOperations.singleLineComment(in: $0, language: doc.language) }
        case .singleLineUncomment:
            withTextView(tv: tv, doc: doc) { NppEditOperations.singleLineUncomment(in: $0, language: doc.language) }
        case .streamComment:
            withTextView(tv: tv, doc: doc) { NppEditOperations.streamComment(in: $0, language: doc.language) }
        case .streamUncomment:
            withTextView(tv: tv, doc: doc) { NppEditOperations.streamUncomment(in: $0, language: doc.language) }
        case .trimTrailingSpace:
            executeDocumentOperation(tv: tv, doc: doc) {
                NppEditOperations.trimSpaces(in: doc, mode: .trailing)
            }
        case .trimLeadingSpace:
            executeDocumentOperation(tv: tv, doc: doc) {
                NppEditOperations.trimSpaces(in: doc, mode: .leading)
            }
        case .trimBothSpace:
            executeDocumentOperation(tv: tv, doc: doc) {
                NppEditOperations.trimSpaces(in: doc, mode: .both)
            }
        case .eolToSpace:
            executeDocumentOperation(tv: tv, doc: doc) {
                NppEditOperations.eolToSpace(in: doc)
            }
        case .tabToSpace:
            executeDocumentOperation(tv: tv, doc: doc) {
                NppEditOperations.tabToSpace(in: doc, spaceCount: tabSize)
            }
        case .spaceToTab:
            executeDocumentOperation(tv: tv, doc: doc) {
                NppEditOperations.spaceToTab(in: doc, spaceCount: tabSize)
            }
        case .uppercase:
            withTextView(tv: tv, doc: doc) { NppEditOperations.convertCase(in: $0, to: .uppercase) }
        case .lowercase:
            withTextView(tv: tv, doc: doc) { NppEditOperations.convertCase(in: $0, to: .lowercase) }
        case .toggleComment:
            withTextView(tv: tv, doc: doc) { NppEditOperations.toggleComment(in: $0, language: doc.language) }
        case .insertDateTime:
            withTextView(tv: tv, doc: doc) { NppEditOperations.insertDateTime(in: $0, isLong: false) }
        case .insertDateTimeLong:
            withTextView(tv: tv, doc: doc) { NppEditOperations.insertDateTime(in: $0, isLong: true) }
        case .insertDateTimeCustomized:
            withTextView(tv: tv, doc: doc) { NppEditOperations.insertCustomDateTime(in: $0, format: self.customDateFormat) }
        case .saveDocument:
            if doc.filePath != nil {
                saveActive()
            }
        }
    }

    public func executeMacroSteps(_ steps: [NppMacroStep]) {
        guard !steps.isEmpty else { return }
        isPlayingBackMacro = true
        defer { isPlayingBackMacro = false }

        let tv = activeTextView ?? (NSApp.keyWindow?.firstResponder as? NSTextView)
        guard let doc = activeDocument else { return }

        if let tv = tv {
            syncTextViewToDocument(tv: tv, doc: doc)
        }

        for step in steps {
            executeMacroStep(step, in: tv, document: doc)
        }
        if let tv = tv {
            syncTextViewToDocument(tv: tv, doc: doc)
        }
    }

    // Direct editor actions working reliably regardless of UI focus
    public func selectRange(_ range: NSRange) {
        if let tv = activeTextView ?? (NSApp.keyWindow?.firstResponder as? NSTextView) {
            tv.window?.makeFirstResponder(tv)
            tv.setSelectedRange(range)
            tv.scrollRangeToVisible(range)
        }
    }

    public func cut() {
        let tv = activeTextView ?? (NSApp.keyWindow?.firstResponder as? NSTextView)
        tv?.cut(nil)
        if let clip = NSPasteboard.general.string(forType: .string) {
            addToClipboardHistory(clip)
        }
    }

    public func copy() {
        let tv = activeTextView ?? (NSApp.keyWindow?.firstResponder as? NSTextView)
        tv?.copy(nil)
        if let clip = NSPasteboard.general.string(forType: .string) {
            addToClipboardHistory(clip)
        }
    }

    public func paste() {
        let tv = activeTextView ?? (NSApp.keyWindow?.firstResponder as? NSTextView)
        tv?.paste(nil)
    }

    public func undo() {
        let tv = activeTextView ?? (NSApp.keyWindow?.firstResponder as? NSTextView)
        tv?.undoManager?.undo()
    }

    public func redo() {
        let tv = activeTextView ?? (NSApp.keyWindow?.firstResponder as? NSTextView)
        tv?.undoManager?.redo()
    }

    // MARK: - Pass 2: Edit Menu Parity Actions

    public func beginOrEndSelect() {
        guard let tv = activeTextView ?? (NSApp.keyWindow?.firstResponder as? NSTextView) else { return }
        let currentCaret = tv.selectedRange().location
        let docLen = (tv.string as NSString).length
        let clampedCaret = min(currentCaret, docLen)

        if let anchor = beginSelectAnchor {
            let clampedAnchor = min(anchor, docLen)
            let start = min(clampedAnchor, clampedCaret)
            let end = max(clampedAnchor, clampedCaret)
            selectRange(NSRange(location: start, length: end - start))
            beginSelectAnchor = nil
        } else {
            beginSelectAnchor = clampedCaret
        }
    }

    public func copyAllFilenames() {
        let names = documents.map { $0.filePath?.lastPathComponent ?? $0.title }
        guard !names.isEmpty else { return }
        let text = names.joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    public func copyAllFilePaths() {
        let paths = documents.map { $0.filePath?.path ?? $0.title }
        guard !paths.isEmpty else { return }
        let text = paths.joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    public func toggleReadOnlyCurrentDoc() {
        guard let doc = activeDocument else { return }
        doc.isReadOnly.toggle()
        if isAllDocumentsReadOnly && !doc.isReadOnly {
            isAllDocumentsReadOnly = false
        }
    }

    public func setReadOnlyAllDocs() {
        isAllDocumentsReadOnly = true
        for doc in documents {
            doc.isReadOnly = true
        }
    }

    public func clearReadOnlyAllDocs() {
        isAllDocumentsReadOnly = false
        for doc in documents {
            doc.isReadOnly = false
        }
    }

    public func resolvedSearchUrl(for query: String) -> URL? {
        let cleanQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanQuery.isEmpty else { return nil }
        let encoded = cleanQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? cleanQuery
        let template: String
        switch searchEngineChoice {
        case 0:
            template = "https://duckduckgo.com/?q=$(CURRENT_WORD)"
        case 1:
            template = "https://www.google.com/search?q=$(CURRENT_WORD)"
        case 2:
            template = "https://search.yahoo.com/search?q=$(CURRENT_WORD)"
        case 3:
            template = "https://stackoverflow.com/search?q=$(CURRENT_WORD)"
        case 4:
            template = customSearchEngineUrl.isEmpty ? "https://www.google.com/search?q=$(CURRENT_WORD)" : customSearchEngineUrl
        default:
            template = searchEngineUrl.contains("$(CURRENT_WORD)") ? searchEngineUrl : "\(searchEngineUrl)$(CURRENT_WORD)"
        }

        var urlString = template
        if urlString.contains("$(CURRENT_WORD)") {
            urlString = urlString.replacingOccurrences(of: "$(CURRENT_WORD)", with: encoded)
        } else if urlString.contains("%s") {
            urlString = urlString.replacingOccurrences(of: "%s", with: encoded)
        } else {
            urlString = urlString + encoded
        }
        return URL(string: urlString)
    }

    public func addToClipboardHistory(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        clipboardHistory.removeAll { $0.text == text }
        clipboardHistory.insert(ClipboardItem(text: text, timestamp: Date()), at: 0)
        if clipboardHistory.count > 50 {
            clipboardHistory.removeLast()
        }
    }

    // MARK: - Pass 3 (M3): Search Menu Parity (Notepad_plus.rc L648-744, NppCommands.cpp)

    /// `IDM_SEARCH_SETANDFINDNEXT` (`Cmd+F3`) & `IDM_SEARCH_SETANDFINDPREV` (`Cmd+Shift+F3`):
    /// Selects word under caret if no selection exists, sets `lastSearchQuery` & `findQueryText`, and finds next/previous occurrence.
    public func selectAndFindNext(forward: Bool = true) {
        if let tv = activeTextView, let doc = activeDocument {
            if tv.string != doc.content {
                syncDocumentToTextView(doc: doc, tv: tv)
            }
            let nsStr = tv.string as NSString
            var sel = tv.selectedRange()
            if sel.length == 0 {
                let expanded = expandWordRange(at: sel.location, in: nsStr)
                if expanded.length > 0 {
                    tv.setSelectedRange(expanded)
                    sel = expanded
                    doc.cursorPos = expanded.location
                    doc.selectionLength = expanded.length
                }
            }
            if sel.length > 0 && NSMaxRange(sel) <= nsStr.length {
                let token = nsStr.substring(with: sel)
                if !token.isEmpty {
                    lastSearchQuery = token
                    findQueryText = token
                }
            }
        } else if let doc = activeDocument {
            let nsStr = doc.content as NSString
            var sel = NSRange(
                location: min(doc.cursorPos, nsStr.length),
                length: min(doc.selectionLength, max(0, nsStr.length - min(doc.cursorPos, nsStr.length)))
            )
            if sel.length == 0 {
                let expanded = expandWordRange(at: sel.location, in: nsStr)
                if expanded.length > 0 {
                    sel = expanded
                    doc.cursorPos = expanded.location
                    doc.selectionLength = expanded.length
                }
            }
            if sel.length > 0 && NSMaxRange(sel) <= nsStr.length {
                let token = nsStr.substring(with: sel)
                if !token.isEmpty {
                    lastSearchQuery = token
                    findQueryText = token
                }
            }
        }
        findNext(forward: forward)
    }

    /// `IDM_SEARCH_FINDINCREMENT` (`Cmd+Option+I`)
    public func toggleIncrementalSearch() {
        searchBarMode = .find
        showSearchBar.toggle()
    }

    /// `IDM_FOCUS_ON_FOUND_RESULTS` (`F7`)
    public func toggleSearchResultsWindow() {
        showSearchResultsPanel.toggle()
    }

    /// `IDM_SEARCH_GOTONEXTFOUND` (`F4`)
    public func nextSearchResult() {
        let allMatches = searchFileGroups.flatMap { $0.matches }
        guard !allMatches.isEmpty else { return }
        showSearchResultsPanel = true
        currentSearchResultIndex = (currentSearchResultIndex + 1) % allMatches.count
        jumpToMatch(allMatches[currentSearchResultIndex])
    }

    /// `IDM_SEARCH_GOTOPREVFOUND` (`Shift+F4`)
    public func prevSearchResult() {
        let allMatches = searchFileGroups.flatMap { $0.matches }
        guard !allMatches.isEmpty else { return }
        showSearchResultsPanel = true
        if currentSearchResultIndex <= 0 {
            currentSearchResultIndex = allMatches.count - 1
        } else {
            currentSearchResultIndex -= 1
        }
        jumpToMatch(allMatches[currentSearchResultIndex])
    }

    /// `IDM_SEARCH_GOTOMATCHINGBRACE` (`Cmd+B`)
    @discardableResult
    public func goToMatchingBrace() -> Bool {
        guard let doc = activeDocument else { return false }
        if let tv = activeTextView {
            syncDocumentToTextView(doc: doc, tv: tv)
            let ok = NppEditOperations.goToMatchingBrace(in: tv)
            let sel = tv.selectedRange()
            doc.cursorPos = sel.location
            doc.selectionLength = sel.length
            return ok
        } else {
            let fallback = NSTextView()
            fallback.string = doc.content
            let pos = min(doc.cursorPos, (doc.content as NSString).length)
            fallback.setSelectedRange(NSRange(location: pos, length: 0))
            let ok = NppEditOperations.goToMatchingBrace(in: fallback)
            doc.cursorPos = fallback.selectedRange().location
            doc.selectionLength = fallback.selectedRange().length
            return ok
        }
    }

    /// `IDM_SEARCH_SELECTMATCHINGBRACES` (`Cmd+Option+B`)
    @discardableResult
    public func selectAllBetweenBraces() -> Bool {
        guard let doc = activeDocument else { return false }
        if let tv = activeTextView {
            syncDocumentToTextView(doc: doc, tv: tv)
            let ok = NppEditOperations.selectAllBetweenBraces(in: tv)
            let sel = tv.selectedRange()
            doc.cursorPos = sel.location
            doc.selectionLength = sel.length
            return ok
        } else {
            let fallback = NSTextView()
            fallback.string = doc.content
            let pos = min(doc.cursorPos, (doc.content as NSString).length)
            let len = min(doc.selectionLength, max(0, (doc.content as NSString).length - pos))
            fallback.setSelectedRange(NSRange(location: pos, length: len))
            let ok = NppEditOperations.selectAllBetweenBraces(in: fallback)
            doc.cursorPos = fallback.selectedRange().location
            doc.selectionLength = fallback.selectedRange().length
            return ok
        }
    }

    public static func tokenStyleColor(for styleIndex: Int) -> NSColor {
        switch styleIndex {
        case 1: return NSColor(calibratedRed: 0.15, green: 0.65, blue: 0.40, alpha: 0.50) // 1st Style: Mint Green
        case 2: return NSColor(calibratedRed: 0.15, green: 0.55, blue: 0.85, alpha: 0.50) // 2nd Style: Cyan
        case 3: return NSColor(calibratedRed: 0.85, green: 0.75, blue: 0.20, alpha: 0.50) // 3rd Style: Yellow
        case 4: return NSColor(calibratedRed: 0.90, green: 0.50, blue: 0.20, alpha: 0.50) // 4th Style: Orange
        case 5: return NSColor(calibratedRed: 0.65, green: 0.35, blue: 0.85, alpha: 0.50) // 5th Style: Purple
        default: return NSColor(calibratedRed: 0.15, green: 0.65, blue: 0.40, alpha: 0.50)
        }
    }

    /// `IDM_SEARCH_MARKALLEXT1..5` (`Style All Occurrences of Token` -> `Using 1st..5th Style`)
    @discardableResult
    public func styleAllOccurrencesOfToken(styleIndex: Int) -> Int {
        guard (1...5).contains(styleIndex), let doc = activeDocument else { return 0 }
        if let tv = activeTextView, tv.string != doc.content {
            syncTextViewToDocument(tv: tv, doc: doc)
        }
        let nsStr = doc.content as NSString
        guard nsStr.length > 0 else { return 0 }

        var sel: NSRange
        if let tv = activeTextView {
            sel = tv.selectedRange()
        } else {
            let pos = min(doc.cursorPos, nsStr.length)
            let len = min(doc.selectionLength, max(0, nsStr.length - pos))
            sel = NSRange(location: pos, length: len)
        }

        if sel.length == 0 {
            sel = expandWordRange(at: sel.location, in: nsStr)
        }
        guard sel.length > 0 && NSMaxRange(sel) <= nsStr.length else { return 0 }
        let token = nsStr.substring(with: sel)
        guard !token.isEmpty else { return 0 }

        var matchedRanges: [NSRange] = []
        var searchRange = NSRange(location: 0, length: nsStr.length)
        while searchRange.location < nsStr.length {
            let found = nsStr.range(of: token, options: [.literal], range: searchRange)
            if found.location == NSNotFound { break }
            matchedRanges.append(found)
            let nextPos = found.location + max(1, found.length)
            searchRange = NSRange(location: nextPos, length: nsStr.length - nextPos)
        }

        var existing = doc.styledTokenRanges[styleIndex] ?? []
        existing.append(contentsOf: matchedRanges)
        doc.styledTokenRanges[styleIndex] = existing

        if let ts = activeTextView?.textStorage {
            let color = Self.tokenStyleColor(for: styleIndex)
            ts.beginEditing()
            for r in matchedRanges where NSMaxRange(r) <= ts.length {
                ts.addAttribute(.backgroundColor, value: color, range: r)
            }
            ts.endEditing()
        }
        objectWillChange.send()
        return matchedRanges.count
    }

    /// `IDM_SEARCH_MARKONEEXT1..5` (`Style One Token` -> `Using 1st..5th Style`)
    @discardableResult
    public func styleOneToken(styleIndex: Int) -> Bool {
        guard (1...5).contains(styleIndex), let doc = activeDocument else { return false }
        if let tv = activeTextView, tv.string != doc.content {
            syncTextViewToDocument(tv: tv, doc: doc)
        }
        let nsStr = doc.content as NSString
        guard nsStr.length > 0 else { return false }

        var sel: NSRange
        if let tv = activeTextView {
            sel = tv.selectedRange()
        } else {
            let pos = min(doc.cursorPos, nsStr.length)
            let len = min(doc.selectionLength, max(0, nsStr.length - pos))
            sel = NSRange(location: pos, length: len)
        }

        if sel.length == 0 {
            sel = expandWordRange(at: sel.location, in: nsStr)
        }
        guard sel.length > 0 && NSMaxRange(sel) <= nsStr.length else { return false }

        var existing = doc.styledTokenRanges[styleIndex] ?? []
        existing.append(sel)
        doc.styledTokenRanges[styleIndex] = existing

        if let ts = activeTextView?.textStorage, NSMaxRange(sel) <= ts.length {
            let color = Self.tokenStyleColor(for: styleIndex)
            ts.beginEditing()
            ts.addAttribute(.backgroundColor, value: color, range: sel)
            ts.endEditing()
        }
        objectWillChange.send()
        return true
    }

    /// `IDM_SEARCH_UNMARKALLEXT1..5` (`Clear Style` -> `Clear 1st..5th Style`)
    public func clearStyle(styleIndex: Int) {
        guard (1...5).contains(styleIndex), let doc = activeDocument else { return }
        let removedRanges = doc.styledTokenRanges.removeValue(forKey: styleIndex) ?? []
        if let ts = activeTextView?.textStorage {
            ts.beginEditing()
            for r in removedRanges where NSMaxRange(r) <= ts.length {
                ts.removeAttribute(.backgroundColor, range: r)
            }
            // Re-apply remaining styles in case ranges overlapped
            for (otherIdx, otherRanges) in doc.styledTokenRanges {
                let c = Self.tokenStyleColor(for: otherIdx)
                for r in otherRanges where NSMaxRange(r) <= ts.length {
                    ts.addAttribute(.backgroundColor, value: c, range: r)
                }
            }
            ts.endEditing()
        }
        objectWillChange.send()
    }

    /// `IDM_SEARCH_CLEARALLMARKS` (`Clear Style` -> `Clear all Styles`)
    public func clearAllStyles() {
        guard let doc = activeDocument else { return }
        doc.styledTokenRanges.removeAll()
        if let ts = activeTextView?.textStorage {
            ts.beginEditing()
            ts.removeAttribute(.backgroundColor, range: NSRange(location: 0, length: ts.length))
            ts.endEditing()
        }
        objectWillChange.send()
    }

    /// `IDM_SEARCH_FINDCHARINRANGE` (`Find characters in range...`):
    /// Finds the next/previous character whose Unicode code point is within `minCode...maxCode`.
    @discardableResult
    public func findCharactersInRange(minCode: Int, maxCode: Int, forward: Bool = true, wrap: Bool = true) -> NSRange? {
        guard let doc = activeDocument else { return nil }
        if let tv = activeTextView, tv.string != doc.content {
            syncTextViewToDocument(tv: tv, doc: doc)
        }
        let nsStr = doc.content as NSString
        let len = nsStr.length
        guard len > 0 else { return nil }

        let low = min(minCode, maxCode)
        let high = max(minCode, maxCode)

        let sel: NSRange
        if let tv = activeTextView {
            sel = tv.selectedRange()
        } else {
            let pos = min(doc.cursorPos, len)
            let sLen = min(doc.selectionLength, max(0, len - pos))
            sel = NSRange(location: pos, length: sLen)
        }

        func checkMatch(at index: Int) -> NSRange? {
            guard index >= 0 && index < len else { return nil }
            let charRange = nsStr.rangeOfComposedCharacterSequence(at: index)
            let sub = nsStr.substring(with: charRange)
            for scalar in sub.unicodeScalars {
                let v = Int(scalar.value)
                if v >= low && v <= high {
                    return charRange
                }
            }
            return nil
        }

        if forward {
            var i = min(NSMaxRange(sel), len)
            while i < len {
                let r = nsStr.rangeOfComposedCharacterSequence(at: i)
                if let matched = checkMatch(at: i) {
                    applyFoundCharRange(matched, doc: doc)
                    return matched
                }
                i = max(i + 1, NSMaxRange(r))
            }
            if wrap {
                i = 0
                let limit = min(sel.location, len)
                while i < limit {
                    let r = nsStr.rangeOfComposedCharacterSequence(at: i)
                    if let matched = checkMatch(at: i) {
                        applyFoundCharRange(matched, doc: doc)
                        return matched
                    }
                    i = max(i + 1, NSMaxRange(r))
                }
            }
        } else {
            var i = sel.location - 1
            while i >= 0 {
                let r = nsStr.rangeOfComposedCharacterSequence(at: i)
                if let matched = checkMatch(at: r.location) {
                    applyFoundCharRange(matched, doc: doc)
                    return matched
                }
                i = r.location - 1
            }
            if wrap {
                i = len - 1
                let limit = NSMaxRange(sel)
                while i >= limit {
                    let r = nsStr.rangeOfComposedCharacterSequence(at: i)
                    if let matched = checkMatch(at: r.location) {
                        applyFoundCharRange(matched, doc: doc)
                        return matched
                    }
                    i = r.location - 1
                }
            }
        }
        return nil
    }

    private func applyFoundCharRange(_ range: NSRange, doc: NppDocument) {
        doc.cursorPos = range.location
        doc.selectionLength = range.length
        if let tv = activeTextView {
            tv.setSelectedRange(range)
            tv.scrollRangeToVisible(range)
        }
    }

    // MARK: - Pass 4 (M4): View Menu Parity (Notepad_plus.rc L746-880)

    public func toggleShowSpaceAndTab() {
        showSpaceAndTab.toggle()
    }

    public func toggleShowEndOfLine() {
        showEndOfLine.toggle()
    }

    public func toggleShowNonPrintingCharacters() {
        showNonPrintingCharacters.toggle()
    }

    public func toggleShowControlCharsAndUnicodeEol() {
        showControlCharsAndUnicodeEol.toggle()
    }

    public func toggleShowAllCharacters() {
        showInvisibleCharacters.toggle()
    }

    public func togglePostItMode(window: NSWindow? = nil) {
        if !isPostItMode {
            if !isDistractionFreeMode {
                savedPreModeToolbar = hideToolbar
                savedPreModeTabBar = hideTabBar
                savedPreModeStatusBar = hideStatusBar
            }
            isPostItMode = true
            isDistractionFreeMode = false
            hideToolbar = true
            hideTabBar = true
            hideStatusBar = true
            isAlwaysOnTop = true
            window?.level = .floating
        } else {
            isPostItMode = false
            hideToolbar = savedPreModeToolbar
            hideTabBar = savedPreModeTabBar
            hideStatusBar = savedPreModeStatusBar
            isAlwaysOnTop = false
            window?.level = .normal
        }
    }

    public func toggleDistractionFreeMode() {
        if !isDistractionFreeMode {
            if !isPostItMode {
                savedPreModeToolbar = hideToolbar
                savedPreModeTabBar = hideTabBar
                savedPreModeStatusBar = hideStatusBar
            }
            isDistractionFreeMode = true
            isPostItMode = false
            hideToolbar = true
            hideTabBar = true
            hideStatusBar = true
            paddingLeft = max(paddingLeft, 120)
        } else {
            isDistractionFreeMode = false
            hideToolbar = savedPreModeToolbar
            hideTabBar = savedPreModeTabBar
            hideStatusBar = savedPreModeStatusBar
            if paddingLeft == 120 {
                paddingLeft = 0
            }
        }
    }

    public func toggleMonitoringCurrentDoc() {
        guard let doc = activeDocument else { return }
        doc.isMonitoring.toggle()
        doc.isReadOnly = doc.isMonitoring
        if doc.isMonitoring, doc.filePath != nil {
            reloadFromDisk(for: doc)
        }
        objectWillChange.send()
    }
}
