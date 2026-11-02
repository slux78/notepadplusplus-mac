import Foundation
import AppKit
import NppCore

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

public struct NppUserDefineLanguage: Codable, Equatable, Identifiable {
    public var id: UUID
    public var name: String
    public var extensions: String
    public var ignoreCase: Bool
    public var keywordLists: [String: String]
    public var prefixModes: [String: Bool]
    public var decimalSeparator: Int
    public var styleForegrounds: [String: String]
    /// Original UserLang element, retained so unedited styles and advanced rules survive export.
    public var sourceXML: String?

    public init(id: UUID = UUID(), name: String, extensions: String = "", ignoreCase: Bool = true,
                keywordLists: [String: String] = [:], prefixModes: [String: Bool] = [:],
                decimalSeparator: Int = 0,
                styleForegrounds: [String: String] = [:],
                sourceXML: String? = nil) {
        self.id = id
        self.name = name
        self.extensions = extensions
        self.ignoreCase = ignoreCase
        self.keywordLists = keywordLists
        self.prefixModes = prefixModes
        self.decimalSeparator = decimalSeparator
        self.styleForegrounds = styleForegrounds
        self.sourceXML = sourceXML
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, extensions, ignoreCase, keywordLists, prefixModes, decimalSeparator, styleForegrounds, sourceXML
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try values.decode(String.self, forKey: .name)
        extensions = try values.decodeIfPresent(String.self, forKey: .extensions) ?? ""
        ignoreCase = try values.decodeIfPresent(Bool.self, forKey: .ignoreCase) ?? true
        keywordLists = try values.decodeIfPresent([String: String].self, forKey: .keywordLists) ?? [:]
        prefixModes = try values.decodeIfPresent([String: Bool].self, forKey: .prefixModes) ?? [:]
        decimalSeparator = try values.decodeIfPresent(Int.self, forKey: .decimalSeparator) ?? 0
        styleForegrounds = try values.decodeIfPresent([String: String].self, forKey: .styleForegrounds) ?? [:]
        sourceXML = try values.decodeIfPresent(String.self, forKey: .sourceXML)
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
            if oldValue != activeDocumentId {
                beginSelectAnchor = nil
            }
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
                showControlCharsAndUnicodeEol = showInvisibleCharacters
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
                showInvisibleCharacters = (showSpaceAndTab && showEndOfLine && showNonPrintingCharacters && showControlCharsAndUnicodeEol)
                isSyncingShowSymbolFlags = false
            }
            activeTextView?.needsDisplay = true
        }
    }
    @Published public var showEndOfLine: Bool = false {
        didSet {
            if !isSyncingShowSymbolFlags {
                isSyncingShowSymbolFlags = true
                showInvisibleCharacters = (showSpaceAndTab && showEndOfLine && showNonPrintingCharacters && showControlCharsAndUnicodeEol)
                isSyncingShowSymbolFlags = false
            }
            activeTextView?.needsDisplay = true
        }
    }
    @Published public var showNonPrintingCharacters: Bool = false {
        didSet {
            if !isSyncingShowSymbolFlags {
                isSyncingShowSymbolFlags = true
                showInvisibleCharacters = (showSpaceAndTab && showEndOfLine && showNonPrintingCharacters && showControlCharsAndUnicodeEol)
                isSyncingShowSymbolFlags = false
            }
            activeTextView?.needsDisplay = true
        }
    }
    @Published public var showControlCharsAndUnicodeEol: Bool = false {
        didSet {
            if !isSyncingShowSymbolFlags {
                isSyncingShowSymbolFlags = true
                showInvisibleCharacters = (showSpaceAndTab && showEndOfLine && showNonPrintingCharacters && showControlCharsAndUnicodeEol)
                isSyncingShowSymbolFlags = false
            }
            activeTextView?.needsDisplay = true
        }
    }
    @Published public var showWrapSymbol: Bool = false {
        didSet { activeTextView?.needsDisplay = true }
    }
    @Published public var showIndentGuides: Bool = true {
        didSet { activeTextView?.needsDisplay = true }
    }
    @Published public var showDocumentMap: Bool = false
    @Published public var showFunctionList: Bool = false
    @Published public var syncScrollV: Bool = false {
        didSet {
            if syncScrollV {
                recalculateSyncScrollDeltas()
                performInitialScrollSync()
            }
        }
    }
    @Published public var syncScrollH: Bool = false {
        didSet {
            if syncScrollH {
                recalculateSyncScrollDeltas()
                performInitialScrollSync()
            }
        }
    }

    // Dual-View Scroll Synchronization State
    public weak var primaryScrollView: NSScrollView? {
        didSet { setupScrollSynchronization() }
    }
    public weak var secondaryScrollView: NSScrollView? {
        didSet { setupScrollSynchronization() }
    }
    public var syncScrollVDelta: CGFloat = 0
    public var syncScrollHDelta: CGFloat = 0
    public var isSyncingScroll: Bool = false
    private var primaryClipObserver: NSObjectProtocol?
    private var secondaryClipObserver: NSObjectProtocol?
    public var hasActiveScrollObservers: Bool {
        return primaryClipObserver != nil || secondaryClipObserver != nil
    }

    public func recalculateSyncScrollDeltas() {
        let pY = primaryScrollView?.contentView.bounds.origin.y ?? 0
        let sY = secondaryScrollView?.contentView.bounds.origin.y ?? 0
        syncScrollVDelta = pY - sY

        let pX = primaryScrollView?.contentView.bounds.origin.x ?? 0
        let sX = secondaryScrollView?.contentView.bounds.origin.x ?? 0
        syncScrollHDelta = pX - sX
    }

    public func performInitialScrollSync() {
        guard isDualView, let _ = primaryScrollView, let _ = secondaryScrollView else { return }
        syncFromPrimaryToSecondary()
    }

    public func setupScrollSynchronization() {
        if let obs = primaryClipObserver { NotificationCenter.default.removeObserver(obs) }
        if let obs = secondaryClipObserver { NotificationCenter.default.removeObserver(obs) }
        primaryClipObserver = nil
        secondaryClipObserver = nil

        if let primaryClip = primaryScrollView?.contentView {
            primaryClip.postsBoundsChangedNotifications = true
            primaryClipObserver = NotificationCenter.default.addObserver(
                forName: NSView.boundsDidChangeNotification,
                object: primaryClip,
                queue: .main
            ) { [weak self] _ in
                self?.handlePrimaryScroll()
            }
        }

        if let secondaryClip = secondaryScrollView?.contentView {
            secondaryClip.postsBoundsChangedNotifications = true
            secondaryClipObserver = NotificationCenter.default.addObserver(
                forName: NSView.boundsDidChangeNotification,
                object: secondaryClip,
                queue: .main
            ) { [weak self] _ in
                self?.handleSecondaryScroll()
            }
        }
    }

    public func teardownScrollSynchronization() {
        if let obs = primaryClipObserver { NotificationCenter.default.removeObserver(obs) }
        if let obs = secondaryClipObserver { NotificationCenter.default.removeObserver(obs) }
        primaryClipObserver = nil
        secondaryClipObserver = nil
    }

    public func handlePrimaryScroll() {
        guard isDualView, (syncScrollV || syncScrollH), !isSyncingScroll else { return }
        syncFromPrimaryToSecondary()
    }

    public func handleSecondaryScroll() {
        guard isDualView, (syncScrollV || syncScrollH), !isSyncingScroll else { return }
        syncFromSecondaryToPrimary()
    }

    public func syncFromPrimaryToSecondary() {
        guard let primary = primaryScrollView, let secondary = secondaryScrollView else { return }
        guard !isSyncingScroll else { return }
        isSyncingScroll = true
        defer { isSyncingScroll = false }

        let pOrigin = primary.contentView.bounds.origin
        var sOrigin = secondary.contentView.bounds.origin
        if syncScrollV {
            sOrigin.y = pOrigin.y - syncScrollVDelta
        }
        if syncScrollH {
            sOrigin.x = pOrigin.x - syncScrollHDelta
        }
        if let docView = secondary.documentView {
            let maxX = max(0, docView.frame.width - secondary.contentView.bounds.width)
            let maxY = max(0, docView.frame.height - secondary.contentView.bounds.height)
            sOrigin.x = max(0, min(sOrigin.x, maxX))
            sOrigin.y = max(0, min(sOrigin.y, maxY))
        }
        secondary.contentView.scroll(to: sOrigin)
        secondary.reflectScrolledClipView(secondary.contentView)
    }

    public func syncFromSecondaryToPrimary() {
        guard let primary = primaryScrollView, let secondary = secondaryScrollView else { return }
        guard !isSyncingScroll else { return }
        isSyncingScroll = true
        defer { isSyncingScroll = false }

        let sOrigin = secondary.contentView.bounds.origin
        var pOrigin = primary.contentView.bounds.origin
        if syncScrollV {
            pOrigin.y = sOrigin.y + syncScrollVDelta
        }
        if syncScrollH {
            pOrigin.x = sOrigin.x + syncScrollHDelta
        }
        if let docView = primary.documentView {
            let maxX = max(0, docView.frame.width - primary.contentView.bounds.width)
            let maxY = max(0, docView.frame.height - primary.contentView.bounds.height)
            pOrigin.x = max(0, min(pOrigin.x, maxX))
            pOrigin.y = max(0, min(pOrigin.y, maxY))
        }
        primary.contentView.scroll(to: pOrigin)
        primary.reflectScrolledClipView(primary.contentView)
    }

    @Published public var isAlwaysOnTop: Bool = false
    @Published public var isFullScreen: Bool = false
    @Published public var isPostItMode: Bool = false
    @Published public var isDistractionFreeMode: Bool = false
    private var savedPreModeToolbar: Bool = false
    private var savedPreModeTabBar: Bool = false
    private var savedPreModeStatusBar: Bool = false
    private var savedPrePostItAlwaysOnTop: Bool = false
    private var savedPreDistractionFreeAlwaysOnTop: Bool = false

    public var isLangMenuCompact: Bool {
        get { compactLanguageMenu }
        set { compactLanguageMenu = newValue }
    }
    @Published public var showUserDefineDialog: Bool = false
    @Published public var userDefinedLanguages: [NppUserDefineLanguage] = []
    @Published public var currentSearchResultIndex: Int = -1
    // Sprint 2: Incremental Search & Highlighting State (searching.md:380-410)
    @Published public var incrementalSearchMatches: [NSRange] = []
    @Published public var incrementalCurrentMatchIndex: Int = 0
    @Published public var incrementalHighlightAll: Bool = false
    public var incrementalHighlightedRanges: [NSRange] = []
    // Authentic Notepad++ Panels
    @Published public var showDocumentList: Bool = false
    @Published public var showFolderAsWorkspace: Bool = false
    @Published public var workspaceFolders: [URL] = [URL(fileURLWithPath: FileManager.default.currentDirectoryPath)]
    @Published public var showClipboardHistory: Bool = false
    @Published public var showCharacterPanel: Bool = false
    @Published public var clipboardHistory: [ClipboardItem] = []

    // Milestone 1: Project Panels 1~3 & Find in Projects
    @Published public var showProjectPanel1: Bool = false
    @Published public var showProjectPanel2: Bool = false
    @Published public var showProjectPanel3: Bool = false
    @Published public var projectWorkspace1: NppProjectWorkspace = NppProjectWorkspace(panelIndex: 1)
    @Published public var projectWorkspace2: NppProjectWorkspace = NppProjectWorkspace(panelIndex: 2)
    @Published public var projectWorkspace3: NppProjectWorkspace = NppProjectWorkspace(panelIndex: 3)
    @Published public var findInProjectsPanel1: Bool = true
    @Published public var findInProjectsPanel2: Bool = false
    @Published public var findInProjectsPanel3: Bool = false

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
    @Published public var showFindCharsInRangeDialog: Bool = false {
        didSet {
            let shouldShow = showFindCharsInRangeDialog
            if Thread.isMainThread {
                if shouldShow {
                    NppFindCharsInRangeWindowController.shared.show(workspace: self)
                } else {
                    NppFindCharsInRangeWindowController.shared.close()
                }
            } else {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    if shouldShow {
                        NppFindCharsInRangeWindowController.shared.show(workspace: self)
                    } else {
                        NppFindCharsInRangeWindowController.shared.close()
                    }
                }
            }
        }
    }
    @Published public var findReplaceTab: Int = 0 { // 0: Find, 1: Replace, 2: Find in Files, 3: Find in Projects, 4: Mark
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
    @Published public var findDirectoryPath: String = ""
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

    public func openFindInFiles(directory: String? = nil) {
        prepareFindDialogFromEditor()
        findReplaceTab = 2
        if let dir = directory {
            findDirectoryPath = dir
        }
        if showFindReplaceDialog {
            NppFindReplaceWindowController.shared.show(workspace: self)
        } else {
            showFindReplaceDialog = true
        }
    }

    public func openFindInProjects() {
        prepareFindDialogFromEditor()
        findReplaceTab = 3
        if showFindReplaceDialog {
            NppFindReplaceWindowController.shared.show(workspace: self)
        } else {
            showFindReplaceDialog = true
        }
    }

    public func openMark() {
        prepareFindDialogFromEditor()
        findReplaceTab = 4
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
                    theme: theme,
                    userDefinedLanguage: userDefinedLanguage(named: activeDocument?.language ?? "")
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
    public static let allCanonicalLanguages: [String] = [
        "ActionScript", "Ada", "ASN.1", "ASP", "Assembly", "AutoIt", "AviSynth",
        "BaanC", "Batch", "Blitzbasic", "C", "C#", "C++", "Caml", "CMake", "COBOL",
        "CSound", "CoffeeScript", "CSS", "D", "Diff", "Erlang", "ErrorList",
        "Escape Sequence (ANSI)", "ESCRIPT", "Forth", "Fortran (free form)", "Fortran (fixed form)",
        "Freebasic", "GDScript", "Go", "Gui4Cli", "Haskell", "Hollywood", "HTML",
        "INI file", "Inno Setup", "Intel HEX", "Java", "JavaScript", "JSON", "JSON5",
        "JSP", "KIXtart", "LISP", "LaTeX", "Lua", "Makefile", "Markdown", "Matlab",
        "Microsoft Transact-SQL", "MMIXAL", "MS-DOS Style", "Nim", "Nncrontab", "NSIS",
        "Objective-C", "OScript", "Pascal", "Perl", "PHP", "PostScript", "PowerShell",
        "Properties", "Purebasic", "Python", "R", "Raku", "REBOL", "Registry",
        "Resource file", "Ruby", "Rust", "SAS", "Shell", "Scheme", "Smalltalk",
        "Spice", "SQL", "Structured Text", "Swift", "S-Record", "TCL",
        "Tektronix extended HEX", "TeX", "TOML", "txt2tags", "TypeScript",
        "Verilog", "VHDL", "Visual Basic", "Visual Prolog", "XML", "YAML"
    ]
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
    /// Test hook: where the automatic session and backups live instead of Application Support.
    public var supportDirectoryOverride: URL?
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
    @Published public var autoCompletionKeyEnter: Bool = false
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
    private var isLoadingSession = false
    public var sessionPlaceholderDecisionHandler: (([URL]) -> Bool)? = nil
    @Published public var workspaceFileExt: String = "workspace"

    // Run Command State
    @Published public var lastRunCommand: String = "python3 $(CURRENT_FILE)"
    @Published public var runCommandHistory: [String] = []
    public struct NppSavedRunCommand: Codable, Equatable, Identifiable {
        public var id: UUID
        public var name: String
        public var command: String
        public var shortcut: String
        public var inTerminal: Bool

        public init(id: UUID = UUID(), name: String, command: String,
                    shortcut: String = "", inTerminal: Bool = false) {
            self.id = id
            self.name = name
            self.command = command
            self.shortcut = shortcut
            self.inTerminal = inTerminal
        }
    }
    public static let savedRunCommandsKey = "npp.savedRunCommands.v1"
    @Published public var savedRunCommands: [NppSavedRunCommand] = []
    @Published public var requestedShortcutMapperTab: Int = 0
    private let runCommandDefaults: UserDefaults

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
                    theme: currentTheme,
                    userDefinedLanguage: userDefinedLanguage(named: activeDocument?.language ?? "")
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

    // Unified Search State (Single Source of Truth)
    @Published public var searchMode: Int = 0 // 0: Normal, 1: Extended, 2: RegEx
    @Published public var matchCase: Bool = false
    @Published public var matchWholeWord: Bool = false
    @Published public var wrapAround: Bool = true
    @Published public var dotMatchesNewline: Bool = false
    @Published public var searchBackward: Bool = false
    @Published public var searchInSelection: Bool = false
    @Published public var filterText: String = "*.*"
    @Published public var directoryText: String = ""
    @Published public var inSubfolders: Bool = true
    @Published public var inHiddenFolders: Bool = false
    @Published public var bookmarkLine: Bool = true
    @Published public var purgeEachSearch: Bool = false

    // Notepad++ Find All Search Results State
    @Published public var searchFileGroups: [NppSearchFileGroup] = []
    @Published public var lastSearchQuery: String = ""
    @Published public var showSearchResultsPanel: Bool = false
    @Published public var targetJumpMatch: NppSearchMatch?

    public func processedSearchQuery(for rawQuery: String? = nil) -> String {
        let q = rawQuery ?? (!lastSearchQuery.isEmpty ? lastSearchQuery : findQueryText)
        if searchMode == 1 {
            return NppWorkspace.expandExtendedEscapes(q)
        }
        return q
    }

    public func buildSearchRegex(for query: String) -> NSRegularExpression? {
        guard !query.isEmpty else { return nil }
        var pattern = (searchMode == 2) ? query : NSRegularExpression.escapedPattern(for: query)
        if matchWholeWord {
            pattern = NppWorkspace.wholeWordPattern(pattern, query: query)
        }
        var options: NSRegularExpression.Options = []
        if !matchCase { options.insert(.caseInsensitive) }
        if searchMode == 2 && dotMatchesNewline { options.insert(.dotMatchesLineSeparators) }
        if searchMode == 2 { options.insert(.anchorsMatchLines) }
        return try? NSRegularExpression(pattern: pattern, options: options)
    }

    public func findRange(in content: String, query: String, forward: Bool, startLocation: Int) -> NSRange? {
        let nsContent = content as NSString
        let contentLength = nsContent.length
        guard contentLength > 0 && !query.isEmpty else { return nil }

        if searchMode == 2 || matchWholeWord {
            guard let regex = buildSearchRegex(for: query) else { return nil }
            let matches = regex.matches(in: content, range: NSRange(location: 0, length: contentLength))
            if forward {
                if let match = matches.first(where: { $0.range.location >= startLocation }) {
                    return match.range
                } else if wrapAround {
                    return matches.first?.range
                }
            } else {
                if let match = matches.last(where: { $0.range.location < startLocation }) {
                    return match.range
                } else if wrapAround {
                    return matches.last?.range
                }
            }
        } else {
            var options: NSString.CompareOptions = []
            if !matchCase { options.insert(.caseInsensitive) }
            if !forward { options.insert(.backwards) }

            if forward {
                let clampedStart = min(max(0, startLocation), contentLength)
                let searchRange = NSRange(location: clampedStart, length: contentLength - clampedStart)
                var found = nsContent.range(of: query, options: options, range: searchRange)
                if found.location == NSNotFound && wrapAround {
                    found = nsContent.range(of: query, options: options)
                }
                if found.location != NSNotFound { return found }
            } else {
                let clampedEnd = min(max(0, startLocation), contentLength)
                let searchRange = NSRange(location: 0, length: clampedEnd)
                var found = nsContent.range(of: query, options: options, range: searchRange)
                if found.location == NSNotFound && wrapAround {
                    found = nsContent.range(of: query, options: options)
                }
                if found.location != NSNotFound { return found }
            }
        }
        return nil
    }

    // Preferences Persistence Keys
    public static let prefsRememberSessionKey = "npp.prefs.rememberSession"
    public static let prefsPeriodicBackupKey = "npp.prefs.periodicBackupEnabled"
    public static let prefsDoubleClickSpaceToNewTabKey = "npp.prefs.doubleClickSpaceToNewTab"
    public static let prefsDoubleClickTabToCloseKey = "npp.prefs.doubleClickTabToClose"
    public static let prefsFontFamilyKey = "npp.prefs.fontFamily"
    public static let prefsFontSizeKey = "npp.prefs.fontSize"
    public static let prefsDarkModeChoiceKey = "npp.prefs.darkModeChoice"
    public static let prefsSelectedThemeKey = "npp.prefs.selectedTheme"
    public static let prefsWordWrapKey = "npp.prefs.wordWrap"
    public static let prefsShowLineNumbersKey = "npp.prefs.showLineNumbers"
    public static let prefsTabSizeKey = "npp.prefs.tabSize"
    public static let prefsRememberProjectPanelsKey = "npp.prefs.rememberProjectPanels"
    public static let prefsShowProjectPanel1Key = "npp.prefs.showProjectPanel1"
    public static let prefsShowProjectPanel2Key = "npp.prefs.showProjectPanel2"
    public static let prefsShowProjectPanel3Key = "npp.prefs.showProjectPanel3"

    public func getProjectWorkspace(panelIndex: Int) -> NppProjectWorkspace {
        switch panelIndex {
        case 1: return projectWorkspace1
        case 2: return projectWorkspace2
        case 3: return projectWorkspace3
        default: return projectWorkspace1
        }
    }

    public func toggleProjectPanel(_ index: Int) {
        switch index {
        case 1: showProjectPanel1.toggle()
        case 2: showProjectPanel2.toggle()
        case 3: showProjectPanel3.toggle()
        default: break
        }
    }

    public func savePreferences() {
        let ud = UserDefaults.standard
        ud.set(rememberSession, forKey: Self.prefsRememberSessionKey)
        ud.set(periodicBackupEnabled, forKey: Self.prefsPeriodicBackupKey)
        ud.set(doubleClickSpaceToNewTab, forKey: Self.prefsDoubleClickSpaceToNewTabKey)
        ud.set(doubleClickTabToClose, forKey: Self.prefsDoubleClickTabToCloseKey)
        ud.set(fontFamily, forKey: Self.prefsFontFamilyKey)
        ud.set(Double(fontSize), forKey: Self.prefsFontSizeKey)
        ud.set(darkModeChoice, forKey: Self.prefsDarkModeChoiceKey)
        ud.set(themeMode, forKey: Self.prefsSelectedThemeKey)
        ud.set(isWordWrapEnabled, forKey: Self.prefsWordWrapKey)
        ud.set(showLineNumbers, forKey: Self.prefsShowLineNumbersKey)
        ud.set(tabSize, forKey: Self.prefsTabSizeKey)
        if rememberProjectPanels {
            ud.set(true, forKey: Self.prefsRememberProjectPanelsKey)
            ud.set(showProjectPanel1, forKey: Self.prefsShowProjectPanel1Key)
            ud.set(showProjectPanel2, forKey: Self.prefsShowProjectPanel2Key)
            ud.set(showProjectPanel3, forKey: Self.prefsShowProjectPanel3Key)
        } else {
            ud.removeObject(forKey: Self.prefsRememberProjectPanelsKey)
            ud.removeObject(forKey: Self.prefsShowProjectPanel1Key)
            ud.removeObject(forKey: Self.prefsShowProjectPanel2Key)
            ud.removeObject(forKey: Self.prefsShowProjectPanel3Key)
        }
    }

    public func loadPreferences() {
        let ud = UserDefaults.standard
        if ud.object(forKey: Self.prefsRememberSessionKey) != nil {
            rememberSession = ud.bool(forKey: Self.prefsRememberSessionKey)
        }
        if ud.object(forKey: Self.prefsPeriodicBackupKey) != nil {
            periodicBackupEnabled = ud.bool(forKey: Self.prefsPeriodicBackupKey)
        }
        if ud.object(forKey: Self.prefsDoubleClickSpaceToNewTabKey) != nil {
            doubleClickSpaceToNewTab = ud.bool(forKey: Self.prefsDoubleClickSpaceToNewTabKey)
        }
        if ud.object(forKey: Self.prefsDoubleClickTabToCloseKey) != nil {
            doubleClickTabToClose = ud.bool(forKey: Self.prefsDoubleClickTabToCloseKey)
        }
        if let font = ud.string(forKey: Self.prefsFontFamilyKey) {
            fontFamily = font
        }
        if ud.object(forKey: Self.prefsFontSizeKey) != nil {
            fontSize = CGFloat(ud.double(forKey: Self.prefsFontSizeKey))
        }
        if ud.object(forKey: Self.prefsDarkModeChoiceKey) != nil {
            darkModeChoice = ud.integer(forKey: Self.prefsDarkModeChoiceKey)
        }
        if let theme = ud.string(forKey: Self.prefsSelectedThemeKey) {
            themeMode = theme
        }
        if ud.object(forKey: Self.prefsWordWrapKey) != nil {
            isWordWrapEnabled = ud.bool(forKey: Self.prefsWordWrapKey)
        }
        if ud.object(forKey: Self.prefsShowLineNumbersKey) != nil {
            showLineNumbers = ud.bool(forKey: Self.prefsShowLineNumbersKey)
        }
        if ud.object(forKey: Self.prefsTabSizeKey) != nil {
            tabSize = ud.integer(forKey: Self.prefsTabSizeKey)
        }
        if ud.bool(forKey: Self.prefsRememberProjectPanelsKey) {
            rememberProjectPanels = true
            if ud.object(forKey: Self.prefsShowProjectPanel1Key) != nil {
                showProjectPanel1 = ud.bool(forKey: Self.prefsShowProjectPanel1Key)
            }
            if ud.object(forKey: Self.prefsShowProjectPanel2Key) != nil {
                showProjectPanel2 = ud.bool(forKey: Self.prefsShowProjectPanel2Key)
            }
            if ud.object(forKey: Self.prefsShowProjectPanel3Key) != nil {
                showProjectPanel3 = ud.bool(forKey: Self.prefsShowProjectPanel3Key)
            }
        }
    }

    public func resetPreferencesToDefaults() {
        let ud = UserDefaults.standard
        let keys = [
            Self.prefsRememberSessionKey,
            Self.prefsPeriodicBackupKey,
            Self.prefsDoubleClickSpaceToNewTabKey,
            Self.prefsDoubleClickTabToCloseKey,
            Self.prefsFontFamilyKey,
            Self.prefsFontSizeKey,
            Self.prefsDarkModeChoiceKey,
            Self.prefsSelectedThemeKey,
            Self.prefsWordWrapKey,
            Self.prefsShowLineNumbersKey,
            Self.prefsTabSizeKey,
            Self.prefsRememberProjectPanelsKey,
            Self.prefsShowProjectPanel1Key,
            Self.prefsShowProjectPanel2Key,
            Self.prefsShowProjectPanel3Key
        ]
        for k in keys { ud.removeObject(forKey: k) }
    }

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

    public init(runCommandDefaults: UserDefaults = .standard) {
        self.runCommandDefaults = runCommandDefaults
        loadPreferences()
        newDocument()
        loadSavedMacros()
        loadSavedRunCommands()
        loadUserDefinedLanguages()
    }

    public func loadSavedRunCommands() {
        guard let data = runCommandDefaults.data(forKey: Self.savedRunCommandsKey),
              let commands = try? JSONDecoder().decode([NppSavedRunCommand].self, from: data)
        else { return }
        savedRunCommands = commands
    }

    public func persistSavedRunCommands() {
        if let data = try? JSONEncoder().encode(savedRunCommands) {
            runCommandDefaults.set(data, forKey: Self.savedRunCommandsKey)
        }
    }

    @discardableResult
    public func saveRunCommand(name: String, command: String, shortcut: String = "",
                               inTerminal: Bool = false) -> Bool {
        let title = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, !body.isEmpty,
              !savedRunCommands.contains(where: { $0.name == title }) else { return false }
        savedRunCommands.append(NppSavedRunCommand(name: title, command: body,
                                                   shortcut: shortcut, inTerminal: inTerminal))
        persistSavedRunCommands()
        return true
    }

    public func updateRunCommand(id: UUID, name: String, shortcut: String) -> Bool {
        guard let index = savedRunCommands.firstIndex(where: { $0.id == id }) else { return false }
        let title = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty,
              !savedRunCommands.contains(where: { $0.id != id && $0.name == title }) else { return false }
        savedRunCommands[index].name = title
        savedRunCommands[index].shortcut = shortcut
        persistSavedRunCommands()
        return true
    }

    public func deleteRunCommand(id: UUID) {
        savedRunCommands.removeAll { $0.id == id }
        persistSavedRunCommands()
    }

    private static var userDefinedLanguagesDirectory: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return support.appendingPathComponent("NotepadPlusPlusMac", isDirectory: true)
    }

    private static let excludedSeparateUDLKey = "npp.excludedSeparateUDLNames.v1"

    public func excludeSeparateUserDefinedLanguage(named name: String) {
        var excluded = Set(UserDefaults.standard.stringArray(forKey: Self.excludedSeparateUDLKey) ?? [])
        excluded.insert(name)
        UserDefaults.standard.set(excluded.sorted(), forKey: Self.excludedSeparateUDLKey)
    }

    public func includeSeparateUserDefinedLanguage(named name: String) {
        var excluded = Set(UserDefaults.standard.stringArray(forKey: Self.excludedSeparateUDLKey) ?? [])
        excluded.remove(name)
        UserDefaults.standard.set(excluded.sorted(), forKey: Self.excludedSeparateUDLKey)
    }

    public func loadUserDefinedLanguages(from storageDirectory: URL? = nil) {
        let directory = storageDirectory ?? Self.userDefinedLanguagesDirectory
        var loaded: [NppUserDefineLanguage] = []
        let mainFile = directory.appendingPathComponent("userDefineLang.xml")
        if let data = try? Data(contentsOf: mainFile), let languages = try? NppUDLCodec.decode(data) {
            loaded.append(contentsOf: languages)
        }
        let separateDirectory = directory.appendingPathComponent("userDefineLangs", isDirectory: true)
        let excluded = Set(UserDefaults.standard.stringArray(forKey: Self.excludedSeparateUDLKey) ?? [])
        if let files = try? FileManager.default.contentsOfDirectory(at: separateDirectory,
                                                                    includingPropertiesForKeys: nil,
                                                                    options: [.skipsHiddenFiles]) {
            for file in files where file.pathExtension.lowercased() == "xml" {
                if let data = try? Data(contentsOf: file), let languages = try? NppUDLCodec.decode(data) {
                    loaded.append(contentsOf: languages.filter { candidate in
                        !excluded.contains(candidate.name) && !loaded.contains { $0.name == candidate.name }
                    })
                }
            }
        }
        userDefinedLanguages = loaded
    }

    public func saveUserDefinedLanguages(to storageDirectory: URL? = nil) {
        let directory = storageDirectory ?? Self.userDefinedLanguagesDirectory
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let data = try NppUDLCodec.encode(userDefinedLanguages)
            try data.write(to: directory.appendingPathComponent("userDefineLang.xml"), options: .atomic)
        } catch {
            NSLog("Failed to save user defined languages: %@", error.localizedDescription)
        }
        if let document = activeDocument,
           let language = userDefinedLanguage(named: document.language),
           let textView = activeTextView, let storage = textView.textStorage {
            NppSyntaxHighlighter.highlight(textStorage: storage, language: document.language,
                                           isDarkMode: currentTheme.isDark,
                                           baseFont: textView.font, theme: currentTheme,
                                           userDefinedLanguage: language)
        }
    }

    public func userDefinedLanguage(for url: URL) -> NppUserDefineLanguage? {
        let fileExtension = url.pathExtension.lowercased()
        guard !fileExtension.isEmpty else { return nil }
        return userDefinedLanguages.first { language in
            language.extensions.split(whereSeparator: { $0.isWhitespace })
                .contains { $0.trimmingCharacters(in: CharacterSet(charactersIn: ".")).lowercased() == fileExtension }
        }
    }

    public func userDefinedLanguage(named name: String) -> NppUserDefineLanguage? {
        userDefinedLanguages.first { $0.name == name }
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
        activeView = 0
    }

    public func openFile(url: URL) {
        let configuredSessionExtension = sessionFileExt.trimmingCharacters(in: CharacterSet(charactersIn: ".")).lowercased()
        if !isLoadingSession && !configuredSessionExtension.isEmpty &&
            url.pathExtension.lowercased() == configuredSessionExtension {
            _ = loadSession(from: url)
            return
        }
        addRecentFile(url)
        // If already open, just switch to it
        if let existing = documents.first(where: { $0.filePath == url }) {
            if existing.isSessionPlaceholder && FileManager.default.fileExists(atPath: url.path) {
                reloadFromDisk(for: existing)
            }
            activeDocumentId = existing.id
            return
        }

        do {
            let doc = try NppDocument.fromFile(url: url)
            if let udl = userDefinedLanguage(for: url) { doc.language = udl.name }
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

    // MARK: - Save Confirmation & Dual View State
    public protocol NppUserInteractionProvider: AnyObject {
        func confirmSave(for document: NppDocument) -> SavePromptResult
        func promptSaveSynchronously(for document: NppDocument) -> Bool
        func confirmKeepMissingFiles(missingFiles: [URL]) -> Bool
    }

    public class NppDefaultInteractionProvider: NppUserInteractionProvider {
        public init() {}

        public func confirmSave(for document: NppDocument) -> SavePromptResult {
            let alert = NSAlert()
            alert.messageText = "Save"
            alert.informativeText = "Save file \"\(document.title)\" ?"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Save")
            alert.addButton(withTitle: "Don't Save")
            alert.addButton(withTitle: "Cancel")

            let res = alert.runModal()
            switch res {
            case .alertFirstButtonReturn:
                return .save
            case .alertSecondButtonReturn:
                return .dontSave
            default:
                return .cancel
            }
        }

        public func promptSaveSynchronously(for document: NppDocument) -> Bool {
            if document.filePath != nil {
                return document.save()
            } else {
                let panel = NSSavePanel()
                panel.title = "Save"
                panel.canCreateDirectories = true
                panel.nameFieldStringValue = document.title
                let res = panel.runModal()
                if res == .OK, let url = panel.url {
                    return document.save(to: url)
                } else {
                    return false
                }
            }
        }

        public func confirmKeepMissingFiles(missingFiles: [URL]) -> Bool {
            let alert = NSAlert()
            alert.messageText = "Remember inaccessible files from past session"
            alert.informativeText = "Keep inaccessible files as read-only placeholders?"
            alert.addButton(withTitle: "Yes")
            alert.addButton(withTitle: "No")
            return alert.runModal() == .alertFirstButtonReturn
        }
    }

    public enum SavePromptResult: String, Codable {
        case save
        case dontSave
        case cancel
    }

    public var isTestRunning: Bool = false
    public var confirmSaveHandler: ((NppDocument) -> SavePromptResult)? = nil
    public var promptSaveHandler: ((NppDocument) -> Bool)? = nil
    public static var defaultInteractionProvider: NppUserInteractionProvider = NppDefaultInteractionProvider()
    public var interactionProvider: NppUserInteractionProvider = NppWorkspace.defaultInteractionProvider

    public enum SplitDirection: String, Codable {
        case vertical   // Left / Right
        case horizontal // Top / Bottom
    }

    @Published public var viewRotationStage: Int = 0 {
        didSet {
            splitDirection = (viewRotationStage % 2 == 0) ? .vertical : .horizontal
        }
    }
    public var isViewSwapped: Bool {
        return viewRotationStage >= 2
    }

    @Published public var secondaryDocumentIds: [UUID] = []
    @Published public var secondaryActiveDocumentId: UUID? = nil
    @Published public var splitDirection: SplitDirection = .vertical
    @Published public var splitRatio: CGFloat = 0.5
    @Published public var clonedDocumentIds: Set<UUID> = []
    @Published public var activeView: Int = 0 // 0: Primary, 1: Secondary

    public var isDualView: Bool {
        return !secondaryDocumentIds.isEmpty
    }

    public var primaryDocuments: [NppDocument] {
        return documents.filter { doc in
            !secondaryDocumentIds.contains(doc.id) || clonedDocumentIds.contains(doc.id)
        }
    }

    public var secondaryDocuments: [NppDocument] {
        return secondaryDocumentIds.compactMap { id in
            documents.first(where: { $0.id == id })
        }
    }

    public var secondaryActiveDocument: NppDocument? {
        guard !secondaryDocuments.isEmpty else { return nil }
        if let id = secondaryActiveDocumentId, let doc = secondaryDocuments.first(where: { $0.id == id }) {
            return doc
        }
        return secondaryDocuments.first
    }

    public func confirmSaveIfNeeded(for doc: NppDocument) -> SavePromptResult {
        let needsConfirm = doc.isDirty || (doc.filePath == nil && !doc.content.isEmpty)
        guard needsConfirm else { return .dontSave }
        if let handler = confirmSaveHandler {
            return handler(doc)
        }
        return interactionProvider.confirmSave(for: doc)
    }

    public func promptSaveSynchronously(for doc: NppDocument) -> Bool {
        if let handler = promptSaveHandler {
            return handler(doc)
        }
        if doc.filePath != nil {
            return doc.save()
        } else {
            return interactionProvider.promptSaveSynchronously(for: doc)
        }
    }


    @discardableResult
    public func closeDocument(id: UUID, force: Bool = false) -> Bool {
        guard let index = documents.firstIndex(where: { $0.id == id }) else { return true }
        let doc = documents[index]
        // Authentic Notepad++ (Notepad_plus.cpp L5165): Pinned tab cannot be closed
        if doc.isPinned {
            NSSound.beep()
            return false
        }

        // Dual View handling for Cloned Document (closing one clone view unlinks it without discarding document)
        if clonedDocumentIds.contains(id) {
            if activeView == 1 || (secondaryActiveDocumentId == id && activeView == 1) {
                secondaryDocumentIds.removeAll(where: { $0 == id })
                clonedDocumentIds.remove(id)
                if secondaryActiveDocumentId == id {
                    secondaryActiveDocumentId = secondaryDocumentIds.first
                }
                if secondaryDocumentIds.isEmpty {
                    activeView = 0
                }
                objectWillChange.send()
                return true
            } else if secondaryDocumentIds.contains(id) {
                clonedDocumentIds.remove(id)
                if activeDocumentId == id {
                    activeDocumentId = primaryDocuments.first(where: { $0.id != id })?.id
                }
                objectWillChange.send()
                return true
            }
        }

        let needsConfirm = doc.isDirty || (doc.filePath == nil && !doc.content.isEmpty)
        if !force && needsConfirm {
            let choice = confirmSaveIfNeeded(for: doc)
            switch choice {
            case .save:
                if !promptSaveSynchronously(for: doc) {
                    return false
                }
            case .dontSave:
                break
            case .cancel:
                return false
            }
        }

        secondaryDocumentIds.removeAll(where: { $0 == id })
        clonedDocumentIds.remove(id)
        if secondaryActiveDocumentId == id {
            secondaryActiveDocumentId = secondaryDocumentIds.first
        }
        if secondaryDocumentIds.isEmpty {
            activeView = 0
        }

        if let path = doc.filePath {
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

        stopMonitoring(document: doc)
        documents.remove(at: index)

        if documents.isEmpty {
            newDocument()
        } else if wasActive || activeDocumentId == id || !documents.contains(where: { $0.id == activeDocumentId }) {
            let safeIndex = max(0, min(fallbackIndex, documents.count - 1))
            activeDocumentId = documents[safeIndex].id
        }
        objectWillChange.send()
        return true
    }

    @discardableResult
    public func closeAll(force: Bool = false) -> Bool {
        // Authentic Notepad++: Pinned documents remain open
        let unpinned = documents.filter { !$0.isPinned }
        for doc in unpinned {
            if !closeDocument(id: doc.id, force: force) {
                return false
            }
        }
        return true
    }

    @discardableResult
    public func closeAllDocuments(force: Bool = false) -> Bool {
        return closeAll(force: force)
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
    @discardableResult
    public func closeAllBut(id: UUID, force: Bool = false) -> Bool {
        // IDM_FILE_CLOSEALL_BUT_CURRENT: Closes all documents except target and pinned documents
        let targets = documents.filter { $0.id != id && !$0.isPinned }
        for doc in targets {
            if !closeDocument(id: doc.id, force: force) {
                return false
            }
        }
        ensureValidActiveDocument(fallbackId: id)
        return true
    }

    @discardableResult
    public func closeAllButPinned(force: Bool = false) -> Bool {
        // IDM_FILE_CLOSEALL_BUT_PINNED: Closes all unpinned documents
        return closeAll(force: force)
    }

    @discardableResult
    public func closeAllToLeft(of id: UUID, force: Bool = false) -> Bool {
        guard let index = documents.firstIndex(where: { $0.id == id }) else { return false }
        // IDM_FILE_CLOSEALL_TOLEFT: Skips pinned tabs
        let leftDocs = Array(documents[0..<index].filter { !$0.isPinned })
        for doc in leftDocs {
            if !closeDocument(id: doc.id, force: force) {
                return false
            }
        }
        ensureValidActiveDocument(fallbackId: id)
        return true
    }

    @discardableResult
    public func closeAllToRight(of id: UUID, force: Bool = false) -> Bool {
        guard let index = documents.firstIndex(where: { $0.id == id }) else { return false }
        // IDM_FILE_CLOSEALL_TORIGHT: Skips pinned tabs
        if index + 1 < documents.count {
            let rightDocs = Array(documents[(index + 1)..<documents.count].filter { !$0.isPinned })
            for doc in rightDocs {
                if !closeDocument(id: doc.id, force: force) {
                    return false
                }
            }
        }
        ensureValidActiveDocument(fallbackId: id)
        return true
    }

    public func closeAllUnchanged() {
        let unchanged = documents.filter { !$0.isDirty && !$0.isPinned }
        for doc in unchanged { _ = closeDocument(id: doc.id, force: true) }
    }

    // MARK: - Dual View Operations (IDM_VIEW_GOTO_ANOTHER_VIEW, IDM_VIEW_CLONE_TO_ANOTHER_VIEW)
    public func moveToOtherView(id: UUID) {
        if secondaryDocumentIds.contains(id) {
            // Move from Secondary to Primary
            secondaryDocumentIds.removeAll(where: { $0 == id })
            clonedDocumentIds.remove(id)
            if secondaryActiveDocumentId == id {
                secondaryActiveDocumentId = secondaryDocumentIds.first
            }
            activeDocumentId = id
            activeView = 0
        } else {
            // Move from Primary to Secondary
            secondaryDocumentIds.append(id)
            clonedDocumentIds.remove(id)
            secondaryActiveDocumentId = id
            activeView = 1
            if activeDocumentId == id {
                activeDocumentId = primaryDocuments.first?.id
                if activeDocumentId == nil {
                    newDocument()
                    activeView = 1
                }
            }
        }
        objectWillChange.send()
    }

    public func cloneToOtherView(id: UUID) {
        clonedDocumentIds.insert(id)
        if !secondaryDocumentIds.contains(id) {
            secondaryDocumentIds.append(id)
            secondaryActiveDocumentId = id
            activeView = 1
        } else {
            activeDocumentId = id
            activeView = 0
        }
        objectWillChange.send()
    }

    public func rotateSplitter(direction: Int = 1) {
        if direction >= 0 {
            rotateSplitterRight()
        } else {
            rotateSplitterLeft()
        }
    }

    public func rotateSplitterLeft() {
        viewRotationStage = (viewRotationStage + 3) % 4
        objectWillChange.send()
    }

    public func rotateSplitterRight() {
        viewRotationStage = (viewRotationStage + 1) % 4
        objectWillChange.send()
    }

    public func newDocumentInSecondaryView() {
        let title = "new \(newDocCounter)"
        newDocCounter += 1
        let enc = defaultNewDocEncoding.isEmpty ? defaultEncoding : defaultNewDocEncoding
        let eol = defaultNewDocFormat
        let newDoc = NppDocument(
            title: title,
            content: "",
            encoding: enc,
            hasBOM: enc == "UTF-8-BOM",
            eol: eol
        )
        newDoc.language = defaultNewDocLanguage.isEmpty ? defaultLanguage : defaultNewDocLanguage
        documents.append(newDoc)
        secondaryDocumentIds.append(newDoc.id)
        secondaryActiveDocumentId = newDoc.id
        activeView = 1
        objectWillChange.send()
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
            let wasPlaceholder = doc.isSessionPlaceholder
            doc.content = reloaded.content
            doc.encoding = reloaded.encoding
            doc.hasBOM = reloaded.hasBOM
            doc.eolFormat = reloaded.eolFormat
            doc.rawFileBytes = reloaded.rawFileBytes
            doc.lastKnownModificationDate = reloaded.lastKnownModificationDate
            doc.isDirty = false
            doc.isSessionPlaceholder = false
            if wasPlaceholder { doc.isReadOnly = false }
            doc.clearBookmarks()
            doc.styledTokenRanges.removeAll()
            objectWillChange.send()
        } catch {
            print("Failed to reload file: \(error)")
        }
    }

    // MARK: - File Status Auto-Detection
    public func checkFileStatus(for doc: NppDocument, prompt: Bool = true) -> Bool {
        guard fileStatusAutoDetection, let url = doc.filePath else { return false }
        let path = url.path
        let fileManager = FileManager.default

        if !fileManager.fileExists(atPath: path) {
            if prompt {
                let alert = NSAlert()
                alert.messageText = "\(doc.title)"
                alert.informativeText = "The file \"\(url.lastPathComponent)\" doesn't exist anymore.\n\nKeep this file in editor?"
                alert.addButton(withTitle: "Yes")
                alert.addButton(withTitle: "No")
                alert.alertStyle = .warning
                let res = alert.runModal()
                if res == .alertSecondButtonReturn {
                    _ = closeDocument(id: doc.id, force: true)
                    return true
                }
            }
            return false
        }

        if doc.isSessionPlaceholder {
            if !prompt { return false }
            let alert = NSAlert()
            alert.messageText = doc.title
            alert.informativeText = tr("The file is available again. Reload it?")
            alert.addButton(withTitle: tr("Yes"))
            alert.addButton(withTitle: tr("No"))
            if alert.runModal() == .alertFirstButtonReturn {
                reloadFromDisk(for: doc)
                return true
            }
            return false
        }

        guard let attrs = try? fileManager.attributesOfItem(atPath: path),
              let diskDate = attrs[.modificationDate] as? Date else { return false }

        guard let knownDate = doc.lastKnownModificationDate else {
            doc.lastKnownModificationDate = diskDate
            return false
        }

        // If file modification time is newer by more than 1 second
        if diskDate.timeIntervalSince(knownDate) > 1.0 {
            if fileStatusAutoReloadSilently && !doc.isDirty {
                reloadFromDisk(for: doc)
                return true
            } else if prompt {
                let alert = NSAlert()
                alert.messageText = "\(doc.title)"
                if doc.isDirty {
                    alert.informativeText = "\(doc.title) has been modified by another program.\n\nDo you want to reload it and lose the changes made in Notepad++?"
                    alert.addButton(withTitle: "No")
                    alert.addButton(withTitle: "Yes")
                    alert.alertStyle = .warning
                    let res = alert.runModal()
                    if res == .alertSecondButtonReturn {
                        reloadFromDisk(for: doc)
                        return true
                    } else {
                        doc.lastKnownModificationDate = diskDate
                        return false
                    }
                } else {
                    alert.informativeText = "\(doc.title) has been modified by another program.\n\nDo you want to reload it?"
                    alert.addButton(withTitle: "Yes")
                    alert.addButton(withTitle: "No")
                    alert.alertStyle = .informational
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
        }
        return false
    }

    public func checkAllFilesStatus() {
        for doc in documents {
            _ = checkFileStatus(for: doc, prompt: true)
        }
    }

    // MARK: - Notepad++ Run Command Engine (run-menu.md:40-65)
    public func expandRunCommand(_ rawCmd: String) -> String {
        guard let doc = activeDocument else { return rawCmd }
        let filePath = doc.filePath?.path ?? ""
        let fileDir = doc.filePath?.deletingLastPathComponent().path ?? FileManager.default.currentDirectoryPath
        let fileName = doc.filePath?.lastPathComponent ?? doc.title
        let namePart = (fileName as NSString).deletingPathExtension
        let fileExtension = doc.filePath?.pathExtension ?? (fileName as NSString).pathExtension
        let extPart = fileExtension.isEmpty ? "" : ".\(fileExtension)"

        let nppFullFilePath = Bundle.main.executablePath ?? CommandLine.arguments.first ?? ""
        let nppDirectory = (nppFullFilePath as NSString).deletingLastPathComponent

        let currentLine = "\(doc.cursorLine)"
        let currentCol = "\(doc.cursorCol)"

        let nsContent = doc.content as NSString
        let safePos = max(0, min(doc.cursorPos, nsContent.length))
        let lineRange = nsContent.lineRange(for: NSRange(location: safePos, length: 0))
        let currentLineStr = nsContent.substring(with: lineRange).trimmingCharacters(in: .newlines)

        let selectionLength = max(0, min(doc.selectionLength, nsContent.length - safePos))
        let wordRange = NppEditOperations.getWordRange(at: safePos, in: nsContent)
        let currentWord = selectionLength > 0
            ? nsContent.substring(with: NSRange(location: safePos, length: selectionLength))
            : (wordRange.length > 0 ? nsContent.substring(with: wordRange) : "")

        var cmd = rawCmd
        cmd = cmd.replacingOccurrences(of: "$(FULL_CURRENT_PATH)", with: filePath)
        cmd = cmd.replacingOccurrences(of: "$(CURRENT_FILE)", with: filePath)
        cmd = cmd.replacingOccurrences(of: "$(CURRENT_DIRECTORY)", with: fileDir)
        cmd = cmd.replacingOccurrences(of: "$(FILE_NAME)", with: fileName)
        cmd = cmd.replacingOccurrences(of: "$(NAME_PART)", with: namePart)
        cmd = cmd.replacingOccurrences(of: "$(EXT_PART)", with: extPart)
        cmd = cmd.replacingOccurrences(of: "$(CURRENT_WORD)", with: currentWord)
        cmd = cmd.replacingOccurrences(of: "$(CURRENT_LINE)", with: currentLine)
        cmd = cmd.replacingOccurrences(of: "$(CURRENT_COLUMN)", with: currentCol)
        cmd = cmd.replacingOccurrences(of: "$(CURRENT_LINESTR)", with: currentLineStr)
        cmd = cmd.replacingOccurrences(of: "$(NPP_DIRECTORY)", with: nppDirectory)
        cmd = cmd.replacingOccurrences(of: "$(NPP_FULL_FILE_PATH)", with: nppFullFilePath)
        return cmd
    }

    public func executeRunCommand(_ rawCmd: String, inTerminal: Bool = true) {
        lastRunCommand = rawCmd
        runCommandHistory.removeAll { $0 == rawCmd }
        runCommandHistory.insert(rawCmd, at: 0)
        if runCommandHistory.count > 20 { runCommandHistory.removeLast() }
        let expanded = expandRunCommand(rawCmd)
        if let url = URL(string: expanded), ["http", "https"].contains(url.scheme?.lowercased() ?? "") {
            NSWorkspace.shared.open(url)
            return
        }
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
            pattern = NppWorkspace.wholeWordPattern(pattern, query: query)
        }

        var regexOptions: NSRegularExpression.Options = [.anchorsMatchLines]
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
            let lineNum = NppLineCounter.lineNumber(upTo: m.range.location, in: content)

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

    /// Wraps a pattern for "Match whole word". The pattern is grouped so alternation (`a|b`) stays
    /// inside the boundaries, and a boundary is only required next to a word character
    /// (so queries such as `foo()` or `$x` can still match).
    public static func wholeWordPattern(_ pattern: String, query: String) -> String {
        func isWord(_ c: Character?) -> Bool { c.map { $0.isLetter || $0.isNumber || $0 == "_" } ?? false }
        let lead = isWord(query.first) ? "\\b" : ""
        let trail = isWord(query.last) ? "\\b" : ""
        return lead + "(?:" + pattern + ")" + trail
    }

    public static func normalizeRegexReplacementTemplate(_ input: String) -> String {
        var result = ""
        var i = input.startIndex
        while i < input.endIndex {
            let ch = input[i]
            if ch == "\\" {
                let nextIndex = input.index(after: i)
                if nextIndex < input.endIndex {
                    let nextCh = input[nextIndex]
                    if nextCh >= "0" && nextCh <= "9" {
                        result.append("$")
                        result.append(nextCh)
                        i = input.index(after: nextIndex)
                        continue
                    } else if nextCh == "n" || nextCh == "r" || nextCh == "t" {
                        result.append(nextCh == "n" ? "\n" : (nextCh == "r" ? "\r" : "\t"))
                        i = input.index(after: nextIndex)
                        continue
                    } else if nextCh == "\\" {
                        result.append("\\\\")
                        i = input.index(after: nextIndex)
                        continue
                    } else if nextCh == "g" {
                        let rem = input[nextIndex...]
                        if let match = rem.range(of: #"^g[<{](\d+)[>}]"#, options: .regularExpression) {
                            let numStr = rem[match].filter { $0.isNumber }
                            result.append("$\(numStr)")
                            i = match.upperBound
                            continue
                        }
                    }
                    result.append("\\")
                    result.append(nextCh)
                    i = input.index(after: nextIndex)
                    continue
                } else {
                    result.append("\\")
                    i = nextIndex
                    continue
                }
            } else {
                result.append(ch)
                i = input.index(after: i)
            }
        }
        return result
    }

    public func jumpToSearchResult(_ match: NppSearchMatch) {
        jumpToMatch(match)
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

        let allMatches = searchFileGroups.flatMap { $0.matches }
        if let idx = allMatches.firstIndex(where: { $0.id == match.id }) {
            currentSearchResultIndex = idx
        }

        if let doc = activeDocument {
            doc.cursorPos = match.charPosition
            doc.selectionLength = match.matchLength
            doc.cursorLine = match.lineNumber
            doc.cursorCol = match.matchRangeInLine.location + 1
            if let tv = activeTextView {
                let isBoundToDoc = (tv.string == doc.content)
                if isBoundToDoc {
                    let maxLen = (tv.string as NSString).length
                    let safeLoc = min(max(0, match.charPosition), maxLen)
                    let safeLen = min(max(0, match.matchLength), max(0, maxLen - safeLoc))
                    let range = NSRange(location: safeLoc, length: safeLen)
                    tv.setSelectedRange(range)
                    tv.scrollRangeToVisible(range)
                }
            }
        }
    }

    @discardableResult
    public func findNext(forward: Bool = true) -> Bool {
        let rawQuery = !lastSearchQuery.isEmpty ? lastSearchQuery : findQueryText
        guard !rawQuery.isEmpty else { return false }
        let query = processedSearchQuery(for: rawQuery)

        if let tv = activeTextView, let doc = activeDocument {
            if tv.string != doc.content {
                syncDocumentToTextView(doc: doc, tv: tv)
            }
            let content = tv.string
            let sel = tv.selectedRange()
            let startLocation = forward ? NSMaxRange(sel) : sel.location
            if let found = findRange(in: content, query: query, forward: forward, startLocation: startLocation) {
                tv.setSelectedRange(found)
                tv.scrollRangeToVisible(found)
                doc.cursorPos = found.location
                doc.selectionLength = found.length
                lastSearchQuery = rawQuery
                findQueryText = rawQuery
                return true
            }
        } else if let doc = activeDocument {
            let content = doc.content
            let sel = NSRange(
                location: min(doc.cursorPos, (content as NSString).length),
                length: min(doc.selectionLength, max(0, (content as NSString).length - min(doc.cursorPos, (content as NSString).length)))
            )
            let startLocation = forward ? NSMaxRange(sel) : sel.location
            if let found = findRange(in: content, query: query, forward: forward, startLocation: startLocation) {
                doc.cursorPos = found.location
                doc.selectionLength = found.length
                lastSearchQuery = rawQuery
                findQueryText = rawQuery
                return true
            }
        }
        return false
    }

    public func clearSearchResults() {
        searchFileGroups.removeAll()
        currentSearchResultIndex = -1
        showSearchResultsPanel = false
    }

    // MARK: - Search Results Item Management & Context Menu (searching.md:420-450)
    public func deleteSearchResult(matchId: UUID) {
        for i in 0..<searchFileGroups.count {
            if let mIdx = searchFileGroups[i].matches.firstIndex(where: { $0.id == matchId }) {
                searchFileGroups[i].matches.remove(at: mIdx)
                if searchFileGroups[i].matches.isEmpty {
                    searchFileGroups.remove(at: i)
                }
                if searchFileGroups.isEmpty {
                    showSearchResultsPanel = false
                }
                objectWillChange.send()
                return
            }
        }
    }

    public func deleteSearchGroup(groupId: UUID) {
        searchFileGroups.removeAll(where: { $0.id == groupId })
        if searchFileGroups.isEmpty {
            showSearchResultsPanel = false
        }
        objectWillChange.send()
    }

    public func copySelectedSearchLines(matches: [NppSearchMatch]) {
        let text = matches.map { "Line \($0.lineNumber): \($0.lineContent)" }.joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    public func copySelectedSearchPathnames(filePaths: [String]) {
        let text = filePaths.joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    public func openSelectedSearchPathname(filePath: URL?, match: NppSearchMatch? = nil) {
        if let match = match {
            jumpToMatch(match)
        } else if let fp = filePath {
            openFile(url: fp)
        }
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
        let text = (tv.string.isEmpty ? doc.content : tv.string) as NSString
        let lines = doc.content.nppLines()
        let targetLine = max(1, min(line, max(1, lines.count)))
        var curLine = 1
        var charPos = 0
        while curLine < targetLine && charPos < text.length {
            let lRange = text.lineRange(for: NSRange(location: charPos, length: 0))
            charPos = NSMaxRange(lRange)
            curLine += 1
        }
        let targetRange = NSRange(location: min(charPos, text.length), length: 0)
        tv.setSelectedRange(targetRange)
        tv.scrollRangeToVisible(targetRange)
        doc.cursorLine = targetLine
        doc.cursorPos = charPos
    }

    public func markAll(query: String, matchCase: Bool, wholeWord: Bool, useRegex: Bool, bookmarkLine: Bool, purgeExisting: Bool, inRange: NSRange? = nil) -> Int {
        guard let doc = activeDocument, !query.isEmpty else { return 0 }
        if purgeExisting {
            doc.clearBookmarks()
        }
        var matches = searchInDocument(doc: doc, query: query, matchCase: matchCase, wholeWord: wholeWord, useRegex: useRegex)
        if let limitRange = inRange, limitRange.length > 0 {
            matches = matches.filter { NSIntersectionRange(NSRange(location: $0.charPosition, length: $0.matchLength), limitRange).length > 0 }
        }
        if bookmarkLine {
            for match in matches {
                doc.bookmarkedLines.insert(match.lineNumber)
            }
        }
        objectWillChange.send()
        return matches.count
    }

    // MARK: - Notepad++ Find in Files
    public static func matchesFileFilter(filename: String, filePath: String, filterString: String) -> Bool {
        let trimmed = filterString.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return true }

        let filters = trimmed.components(separatedBy: CharacterSet.whitespaces.union(CharacterSet(charactersIn: ";"))).filter { !$0.isEmpty }
        if filters.isEmpty { return true }

        let positiveFilters = filters.filter { !$0.hasPrefix("!") }
        let excludeFilters = filters.filter { $0.hasPrefix("!") }.map { String($0.dropFirst()) }

        for pat in excludeFilters {
            var cleanDir = pat
            if cleanDir.hasPrefix("\\") || cleanDir.hasPrefix("/") {
                cleanDir = String(cleanDir.dropFirst())
            }
            if cleanDir.hasSuffix("\\") || cleanDir.hasSuffix("/") {
                cleanDir = String(cleanDir.dropLast())
            }
            cleanDir = cleanDir.replacingOccurrences(of: "\\", with: "/").trimmingCharacters(in: CharacterSet(charactersIn: "/"))

            if fnmatch(pat, filename, 0) == 0 {
                return false
            }
            if !cleanDir.isEmpty {
                if fnmatch(cleanDir, filename, 0) == 0 {
                    return false
                }
                let pathComponents = filePath.split(separator: "/").map(String.init)
                let dirComponents = pathComponents.dropLast()
                if dirComponents.contains(where: { fnmatch(cleanDir, $0, 0) == 0 || $0 == cleanDir }) ||
                   filePath.contains("/" + cleanDir + "/") ||
                   filePath.hasPrefix(cleanDir + "/") {
                    return false
                }
            }
        }

        if positiveFilters.isEmpty || positiveFilters.contains("*.*") || positiveFilters.contains("*") {
            return true
        }

        return positiveFilters.contains { pat in
            fnmatch(pat, filename, 0) == 0
        }
    }

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

        var targetFiles: [URL] = []
        if let enumerator = fileManager.enumerator(at: dirUrl, includingPropertiesForKeys: [.isRegularFileKey], options: subfolders ? [] : [.skipsSubdirectoryDescendants]) {
            for case let fileUrl as URL in enumerator {
                var isReg: AnyObject?
                try? (fileUrl as NSURL).getResourceValue(&isReg, forKey: .isRegularFileKey)
                if let isReg = isReg as? Bool, isReg {
                    let filename = fileUrl.lastPathComponent
                    if Self.matchesFileFilter(filename: filename, filePath: fileUrl.path, filterString: filter) {
                        targetFiles.append(fileUrl)
                    }
                }
            }
        }

        var groups: [NppSearchFileGroup] = []
        for fileUrl in targetFiles {
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

        var targetFiles: [URL] = []
        if let enumerator = fileManager.enumerator(at: dirUrl, includingPropertiesForKeys: [.isRegularFileKey], options: subfolders ? [] : [.skipsSubdirectoryDescendants]) {
            for case let fileUrl as URL in enumerator {
                var isReg: AnyObject?
                try? (fileUrl as NSURL).getResourceValue(&isReg, forKey: .isRegularFileKey)
                if let isReg = isReg as? Bool, isReg {
                    let filename = fileUrl.lastPathComponent
                    if Self.matchesFileFilter(filename: filename, filePath: fileUrl.path, filterString: filter) {
                        targetFiles.append(fileUrl)
                    }
                }
            }
        }

        var pattern = useRegex ? query : NSRegularExpression.escapedPattern(for: query)
        if wholeWord {
            pattern = NppWorkspace.wholeWordPattern(pattern, query: query)
        }
        var regexOptions: NSRegularExpression.Options = [.anchorsMatchLines]
        if !matchCase {
            regexOptions.insert(.caseInsensitive)
        }
        guard let regex = try? NSRegularExpression(pattern: pattern, options: regexOptions) else {
            return (0, 0)
        }
        let template = useRegex ? NppWorkspace.normalizeRegexReplacementTemplate(replacement) : NSRegularExpression.escapedTemplate(for: replacement)

        var totalReplacements = 0
        var filesModified = 0

        for fileUrl in targetFiles {
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

    // MARK: - Milestone 1: Find & Replace in Projects

    public func enumProjectFiles(panelIndex: Int, filter: String) -> [URL] {
        let ws = getProjectWorkspace(panelIndex: panelIndex)
        let files = ws.enumAllFiles()
        var results: [URL] = []
        for file in files {
            guard let path = file.filePath else { continue }
            let url = URL(fileURLWithPath: path)
            if Self.matchesFileFilter(filename: url.lastPathComponent, filePath: url.path, filterString: filter) {
                results.append(url)
            }
        }
        return results
    }

    public func findAllInProjects(
        query: String,
        filter: String,
        panels: [Int],
        matchCase: Bool,
        wholeWord: Bool,
        useRegex: Bool
    ) {
        guard !query.isEmpty else { return }
        lastSearchQuery = query

        var targetFiles: [URL] = []
        var seenPaths: Set<String> = []

        for p in panels {
            let files = enumProjectFiles(panelIndex: p, filter: filter)
            for fileUrl in files {
                let stdPath = fileUrl.standardizedFileURL.path
                if !seenPaths.contains(stdPath) {
                    seenPaths.insert(stdPath)
                    targetFiles.append(fileUrl)
                }
            }
        }

        var groups: [NppSearchFileGroup] = []
        for fileUrl in targetFiles {
            if let openDoc = documents.first(where: {
                if let p = $0.filePath {
                    return p.standardizedFileURL.path == fileUrl.standardizedFileURL.path
                }
                return false
            }) {
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
    public func replaceInProjects(
        query: String,
        replacement: String,
        filter: String,
        panels: [Int],
        matchCase: Bool,
        wholeWord: Bool,
        useRegex: Bool
    ) -> (replacements: Int, filesModified: Int) {
        guard !query.isEmpty else { return (0, 0) }

        var targetFiles: [URL] = []
        var seenPaths: Set<String> = []

        for p in panels {
            let files = enumProjectFiles(panelIndex: p, filter: filter)
            for fileUrl in files {
                let stdPath = fileUrl.standardizedFileURL.path
                if !seenPaths.contains(stdPath) {
                    seenPaths.insert(stdPath)
                    targetFiles.append(fileUrl)
                }
            }
        }

        var pattern = useRegex ? query : NSRegularExpression.escapedPattern(for: query)
        if wholeWord {
            pattern = NppWorkspace.wholeWordPattern(pattern, query: query)
        }

        var regexOptions: NSRegularExpression.Options = [.anchorsMatchLines]
        if !matchCase {
            regexOptions.insert(.caseInsensitive)
        }
        guard let regex = try? NSRegularExpression(pattern: pattern, options: regexOptions) else {
            return (0, 0)
        }
        let template = useRegex ? NppWorkspace.normalizeRegexReplacementTemplate(replacement) : NSRegularExpression.escapedTemplate(for: replacement)

        var totalReplacements = 0
        var filesModified = 0

        for fileUrl in targetFiles {
            let content: String
            let isOpenDoc = documents.first(where: {
                if let p = $0.filePath {
                    return p.standardizedFileURL.path == fileUrl.standardizedFileURL.path
                }
                return false
            })
            if let openDoc = isOpenDoc {
                content = openDoc.content
            } else if let diskContent = (try? String(contentsOf: fileUrl, encoding: .utf8)) ?? (try? String(contentsOf: fileUrl, encoding: .ascii)) {
                content = diskContent
            } else {
                continue
            }

            let fullRange = NSRange(location: 0, length: (content as NSString).length)
            let count = regex.numberOfMatches(in: content, options: [], range: fullRange)
            if count > 0 {
                let updated = regex.stringByReplacingMatches(in: content, options: [], range: fullRange, withTemplate: template)
                totalReplacements += count
                filesModified += 1

                if let openDoc = isOpenDoc {
                    openDoc.content = updated
                    openDoc.isDirty = true
                    if openDoc.id == activeDocumentId, let tv = activeTextView {
                        syncDocumentToTextView(doc: openDoc, tv: tv)
                    }
                } else {
                    _ = try? updated.write(to: fileUrl, atomically: true, encoding: .utf8)
                }
            }
        }
        objectWillChange.send()
        return (totalReplacements, filesModified)
    }

    // MARK: - Notepad++ Extended Search Mode Escapes (searching.md:120-135)
    public static func expandExtendedEscapes(_ input: String) -> String {
        var result = ""
        var i = input.startIndex
        while i < input.endIndex {
            if input[i] == "\\" {
                let next = input.index(after: i)
                if next < input.endIndex {
                    let c = input[next]
                    switch c {
                    case "\\":
                        result.append("\\")
                        i = input.index(after: next)
                        continue
                    case "n":
                        result.append("\n")
                        i = input.index(after: next)
                        continue
                    case "r":
                        result.append("\r")
                        i = input.index(after: next)
                        continue
                    case "t":
                        result.append("\t")
                        i = input.index(after: next)
                        continue
                    case "0":
                        result.append("\0")
                        i = input.index(after: next)
                        continue
                    case "x", "X":
                        // \xHH: 2 hex characters
                        let hexStart = input.index(after: next)
                        if let hexEnd = input.index(hexStart, offsetBy: 2, limitedBy: input.endIndex) {
                            let hexStr = String(input[hexStart..<hexEnd])
                            if let byteVal = UInt8(hexStr, radix: 16) {
                                result.append(Character(UnicodeScalar(byteVal)))
                                i = hexEnd
                                continue
                            }
                        }
                    case "u", "U":
                        // \uHHHH: 4 hex characters
                        let hexStart = input.index(after: next)
                        if let hexEnd = input.index(hexStart, offsetBy: 4, limitedBy: input.endIndex) {
                            let hexStr = String(input[hexStart..<hexEnd])
                            if let codePoint = UInt32(hexStr, radix: 16), let scalar = UnicodeScalar(codePoint) {
                                result.append(Character(scalar))
                                i = hexEnd
                                continue
                            }
                        }
                    default:
                        break
                    }
                }
            }
            result.append(input[i])
            i = input.index(after: i)
        }
        return result
    }

    // MARK: - Incremental Search Engine (searching.md:380-410)
    public func updateIncrementalSearch(query: String, matchCase: Bool, wholeWord: Bool, useRegex: Bool) {
        guard let doc = activeDocument, !query.isEmpty else {
            incrementalSearchMatches = []
            incrementalCurrentMatchIndex = 0
            clearIncrementalHighlight()
            objectWillChange.send()
            return
        }
        let content = doc.content as NSString
        var options: NSString.CompareOptions = []
        if !matchCase { options.insert(.caseInsensitive) }
        if useRegex { options.insert(.regularExpression) }

        var ranges: [NSRange] = []
        var searchRange = NSRange(location: 0, length: content.length)
        while searchRange.location < content.length {
            let r = content.range(of: query, options: options, range: searchRange)
            if r.location == NSNotFound { break }
            if wholeWord {
                let leftOk = (r.location == 0 || !CharacterSet.alphanumerics.contains(UnicodeScalar(content.character(at: r.location - 1))!))
                let rightPos = NSMaxRange(r)
                let rightOk = (rightPos == content.length || !CharacterSet.alphanumerics.contains(UnicodeScalar(content.character(at: rightPos))!))
                if leftOk && rightOk {
                    ranges.append(r)
                }
            } else {
                ranges.append(r)
            }
            let nextLoc = max(NSMaxRange(r), searchRange.location + 1)
            searchRange = NSRange(location: nextLoc, length: content.length - nextLoc)
        }
        incrementalSearchMatches = ranges

        if let idx = ranges.firstIndex(where: { NSLocationInRange(doc.cursorPos, $0) || $0.location >= doc.cursorPos }) {
            incrementalCurrentMatchIndex = idx + 1
        } else if !ranges.isEmpty {
            incrementalCurrentMatchIndex = 1
        } else {
            incrementalCurrentMatchIndex = 0
        }

        if incrementalHighlightAll {
            applyIncrementalHighlight(ranges: ranges)
        } else {
            clearIncrementalHighlight()
        }
        objectWillChange.send()
    }

    public func applyIncrementalHighlight(ranges: [NSRange]) {
        guard let tv = activeTextView, let ts = tv.textStorage else { return }
        clearIncrementalHighlight()
        let highlightColor = NSColor.systemYellow.withAlphaComponent(0.35)
        ts.beginEditing()
        for r in ranges where NSMaxRange(r) <= ts.length {
            ts.addAttribute(.backgroundColor, value: highlightColor, range: r)
        }
        ts.endEditing()
        incrementalHighlightedRanges = ranges
    }

    public func clearIncrementalHighlight() {
        guard let tv = activeTextView, let ts = tv.textStorage, !incrementalHighlightedRanges.isEmpty else { return }
        ts.beginEditing()
        for r in incrementalHighlightedRanges where NSMaxRange(r) <= ts.length {
            ts.removeAttribute(.backgroundColor, range: r)
        }
        ts.endEditing()
        incrementalHighlightedRanges.removeAll()
    }

    // MARK: - Performance Large File Guard (programing-languages.md:80-95)
    public func isLargeFile(doc: NppDocument) -> Bool {
        guard performanceLargeFileEnabled else { return false }
        let threshold = performanceLargeFileSizeMB * 1024 * 1024
        let size = doc.rawFileBytes?.count ?? doc.content.utf8.count
        return size > threshold
    }

    // MARK: - Notepad++ Column Editor (Alt+C)
    public func executeColumnEditor(isText: Bool, text: String, initialNumber: Int, increaseBy: Int, repeatCount: Int, format: String, leadingZeros: Bool, leadingSpaces: Bool = false) {
        guard let tv = activeTextView, let doc = activeDocument else { return }
        let str = tv.string as NSString
        let sel = tv.selectedRange()

        var lineInfo: [(lineRange: NSRange, colOffset: Int, replaceLength: Int)] = []

        if tv.selectedRanges.count > 1 {
            for val in tv.selectedRanges {
                let r = val.rangeValue
                let lRange = str.lineRange(for: NSRange(location: r.location, length: 0))
                let col = r.location - lRange.location
                lineInfo.append((lRange, col, r.length))
            }
        } else if sel.length == 0 {
            // Caret with 0 length: iterate from cursor line all the way to EOF (columnEditor.cpp:216-268)
            let firstLineRange = str.lineRange(for: NSRange(location: sel.location, length: 0))
            let colOffset = sel.location - firstLineRange.location
            let spanRange = NSRange(location: firstLineRange.location, length: str.length - firstLineRange.location)
            str.enumerateSubstrings(in: spanRange, options: [.byLines, .substringNotRequired]) { _, subRange, _, _ in
                lineInfo.append((subRange, colOffset, 0))
            }
            if lineInfo.isEmpty {
                lineInfo.append((firstLineRange, colOffset, 0))
            }
        } else {
            let firstLineRange = str.lineRange(for: NSRange(location: sel.location, length: 0))
            let colOffset = sel.location - firstLineRange.location
            let selLineRange = str.lineRange(for: sel)
            str.enumerateSubstrings(in: selLineRange, options: [.byLines, .substringNotRequired]) { _, subRange, _, _ in
                lineInfo.append((subRange, colOffset, 0))
            }
            if lineInfo.isEmpty {
                lineInfo.append((selLineRange, colOffset, 0))
            }
        }

        var insertStrings: [String] = []
        if isText {
            insertStrings = Array(repeating: text, count: lineInfo.count)
        } else {
            var rawNumbers: [Int] = []
            var currentNum = initialNumber
            var currentRepeat = 0
            let effectiveRepeat = max(1, repeatCount)
            for _ in 0..<lineInfo.count {
                rawNumbers.append(currentNum)
                currentRepeat += 1
                if currentRepeat >= effectiveRepeat {
                    currentRepeat = 0
                    currentNum += increaseBy
                }
            }

            func rawStr(_ num: Int) -> String {
                switch format.lowercased() {
                case "hex": return String(num, radix: 16).uppercased()
                case "hex_lower": return String(num, radix: 16).lowercased()
                case "oct": return String(num, radix: 8)
                case "bin": return String(num, radix: 2)
                default: return "\(num)"
                }
            }

            let isNonDec = format.lowercased() != "dec" && !format.lowercased().hasPrefix("dec")
            let minDigits = isNonDec ? 4 : 1
            let maxLen = max(minDigits, rawNumbers.map { rawStr($0).count }.max() ?? 1)

            for num in rawNumbers {
                let strVal = rawStr(num)
                let formattedNum: String
                if leadingZeros && strVal.count < maxLen {
                    formattedNum = String(repeating: "0", count: maxLen - strVal.count) + strVal
                } else if leadingSpaces && strVal.count < maxLen {
                    formattedNum = String(repeating: " ", count: maxLen - strVal.count) + strVal
                } else {
                    formattedNum = strVal
                }
                insertStrings.append(formattedNum)
            }
        }

        var modifiedText = tv.string
        for (i, info) in lineInfo.enumerated().reversed() {
            let lineStr = (str as NSString).substring(with: info.lineRange)
            var cleanLineLen = lineStr.count
            if lineStr.hasSuffix("\r\n") { cleanLineLen -= 2 }
            else if lineStr.hasSuffix("\n") || lineStr.hasSuffix("\r") { cleanLineLen -= 1 }

            let col = info.colOffset
            let insertPos: Int
            let replaceLen: Int
            let finalInsert: String

            if cleanLineLen < col {
                // Short line: pad with spaces up to colOffset (columnEditor.cpp:250-254)
                let padding = String(repeating: " ", count: col - cleanLineLen)
                insertPos = info.lineRange.location + cleanLineLen
                replaceLen = 0
                finalInsert = padding + insertStrings[i]
            } else {
                insertPos = info.lineRange.location + col
                replaceLen = min(info.replaceLength, cleanLineLen - col)
                finalInsert = insertStrings[i]
            }

            let nsMod = modifiedText as NSString
            modifiedText = nsMod.replacingCharacters(in: NSRange(location: insertPos, length: replaceLen), with: finalInsert)
        }

        let fullRange = NSRange(location: 0, length: str.length)
        if tv.shouldChangeText(in: fullRange, replacementString: modifiedText) {
            tv.undoManager?.beginUndoGrouping()
            tv.replaceCharacters(in: fullRange, with: modifiedText)
            tv.didChangeText()
            tv.undoManager?.endUndoGrouping()
            doc.content = tv.string
            doc.isDirty = true
            objectWillChange.send()
        } else {
            tv.string = modifiedText
            doc.content = modifiedText
            doc.isDirty = true
            objectWillChange.send()
        }
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
                if doc.save(to: url), let language = self.userDefinedLanguage(for: url) {
                    doc.language = language.name
                }
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
            return renameDocument(id: id, to: newURL)
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

    @discardableResult
    public func renameDocument(id: UUID, to newURL: URL) -> Bool {
        guard let doc = documents.first(where: { $0.id == id }),
              let currentURL = doc.filePath else { return false }
        if newURL.path == currentURL.path { return true }
        guard !FileManager.default.fileExists(atPath: newURL.path) else { return false }
        do {
            try FileManager.default.moveItem(at: currentURL, to: newURL)
            doc.filePath = newURL
            doc.title = newURL.lastPathComponent
            doc.language = userDefinedLanguage(for: newURL)?.name ?? NppDocument.detectLanguage(for: newURL)
            recentFiles.removeAll { $0.path == currentURL.path }
            closedFilePaths.removeAll { $0.path == currentURL.path }
            addRecentFile(newURL)
            objectWillChange.send()
            return true
        } catch {
            NSLog("Failed to rename file on disk: %@", error.localizedDescription)
            return false
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
                if !renameDocument(id: doc.id, to: destURL) {
                    let alert = NSAlert()
                    alert.messageText = tr("Rename...")
                    alert.informativeText = tr("Could not rename the file.")
                    alert.alertStyle = .warning
                    alert.runModal()
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
        guard let data = doc.encodedData() else { return false }
        do {
            try data.write(to: url, options: .atomic)
            return true
        } catch {
            NSLog("Failed to save document copy: %@", error.localizedDescription)
            return false
        }
    }

    @discardableResult
    public func moveActiveFileToTrash() -> Bool {
        guard let doc = activeDocument, let url = doc.filePath, !doc.isPinned else { return false }
        if doc.isDirty {
            switch confirmSaveIfNeeded(for: doc) {
            case .save:
                guard promptSaveSynchronously(for: doc) else { return false }
            case .dontSave:
                break
            case .cancel:
                return false
            }
        }
        do {
            try FileManager.default.trashItem(at: url, resultingItemURL: nil)
            return closeDocument(id: doc.id, force: true)
        } catch {
            NSLog("Failed to move file to Trash: %@", error.localizedDescription)
            return false
        }
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

    /// Writes a Notepad++-style session file.
    /// With `backupDirectory`, unsaved (dirty / untitled) documents are also written there so the
    /// next launch can restore their content ("session snapshot and periodic backup").
    public func saveSession(to url: URL, backupDirectory: URL? = nil) -> Bool {
        func escaped(_ value: String) -> String {
            value.replacingOccurrences(of: "&", with: "&amp;")
                .replacingOccurrences(of: "\"", with: "&quot;")
                .replacingOccurrences(of: "<", with: "&lt;")
                .replacingOccurrences(of: ">", with: "&gt;")
                // XML attribute-value normalization turns raw tab/CR/LF into spaces, so keep them as references
                .replacingOccurrences(of: "\t", with: "&#9;")
                .replacingOccurrences(of: "\n", with: "&#10;")
                .replacingOccurrences(of: "\r", with: "&#13;")
        }
        var referencedBackups = Set<String>()
        var allBackupsSucceeded = true
        if let dir = backupDirectory {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        func includes(_ doc: NppDocument) -> Bool {
            if doc.filePath != nil { return true }
            let isUnsaved = doc.isDirty || !doc.content.isEmpty
            return backupDirectory != nil && isUnsaved && !doc.isSessionPlaceholder
        }
        func fileElement(_ doc: NppDocument) -> String? {
            let name: String
            if let path = doc.filePath?.path { name = path } else { name = doc.title }
            let start = doc.cursorPos
            let end = doc.cursorPos + doc.selectionLength
            var attrs = "firstVisibleLine=\"0\" xOffset=\"0\" scrollWidth=\"100\" startPos=\"\(start)\" endPos=\"\(end)\" selMode=\"0\" lang=\"\(escaped(doc.language))\" encoding=\"\(escaped(doc.encoding))\""
            if doc.isPinned {
                attrs += " tabPinned=\"true\""
            }
            let isUnsaved = doc.isDirty || (doc.filePath == nil && !doc.content.isEmpty)
            if let dir = backupDirectory, isUnsaved, !doc.isSessionPlaceholder {
                let safeTitle = doc.title.replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: ":", with: "_")
                let backupName = "\(safeTitle)@\(doc.id.uuidString)"
                let backupURL = dir.appendingPathComponent(backupName)
                guard (try? Data(doc.content.utf8).write(to: backupURL, options: .atomic)) != nil else {
                    allBackupsSucceeded = false
                    return doc.filePath == nil ? nil : "<File \(attrs) filename=\"\(escaped(name))\">"
                }
                referencedBackups.insert(backupName)
                attrs += " backupFilePath=\"\(escaped(backupURL.path))\" backupHasBOM=\"\(doc.hasBOM ? 1 : 0)\" backupEol=\"\(doc.eolFormat.rawValue)\" backupEncoding=\"\(escaped(doc.encoding))\""
            } else if doc.filePath == nil {
                return nil
            }
            var el = "            <File \(attrs) filename=\"\(escaped(name))\">\n"
            for bLine in doc.bookmarkedLines.sorted() {
                el += "                <Mark line=\"\(bLine)\" />\n"
            }
            el += "            </File>\n"
            return el
        }
        var xml = "<?xml version=\"1.0\" encoding=\"UTF-8\" ?>\n<NotepadPlus>\n"
        xml += "    <Session activeView=\"\(activeView)\">\n"
        let savedPrimary = primaryDocuments.filter(includes)
        let activeIdx = savedPrimary.firstIndex(where: { $0.id == activeDocumentId }) ?? 0
        xml += "        <mainView activeIndex=\"\(activeIdx)\">\n"
        for doc in savedPrimary { if let el = fileElement(doc) { xml += el } }
        xml += "        </mainView>\n"
        let savedSecondary = secondaryDocuments.filter(includes)
        let subIdx = savedSecondary.firstIndex(where: { $0.id == secondaryActiveDocumentId }) ?? 0
        xml += "        <subView activeIndex=\"\(subIdx)\">\n"
        for doc in savedSecondary { if let el = fileElement(doc) { xml += el } }
        xml += "        </subView>\n"
        xml += "    </Session>\n</NotepadPlus>\n"

        guard backupDirectory == nil || allBackupsSucceeded else {
            return false
        }

        do {
            try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try xml.write(to: url, atomically: true, encoding: .utf8)
            if let dir = backupDirectory,
               let existing = try? FileManager.default.contentsOfDirectory(atPath: dir.path) {
                for name in existing where !referencedBackups.contains(name) && name.contains("@") {
                    try? FileManager.default.removeItem(at: dir.appendingPathComponent(name))
                }
            }
            return true
        } catch {
            return false
        }
    }

    // MARK: - Session snapshot & periodic backup (Preferences > Backup)
    public var sessionSupportDirectory: URL {
        if let override = supportDirectoryOverride { return override }
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let primaryDir = base.appendingPathComponent("NotepadPlusPlusMac", isDirectory: true)
        if (try? FileManager.default.createDirectory(at: primaryDir, withIntermediateDirectories: true)) != nil {
            return primaryDir
        }
        let fallbackDir = base.appendingPathComponent("Notepad++", isDirectory: true)
        if (try? FileManager.default.createDirectory(at: fallbackDir, withIntermediateDirectories: true)) != nil {
            return fallbackDir
        }
        return FileManager.default.temporaryDirectory.appendingPathComponent("NotepadPlusPlusMac", isDirectory: true)
    }
    public var autoSessionURL: URL { sessionSupportDirectory.appendingPathComponent("session.xml") }
    public var backupDirectoryURL: URL {
        let custom = periodicBackupPath.trimmingCharacters(in: .whitespaces)
        if !custom.isEmpty { return URL(fileURLWithPath: (custom as NSString).expandingTildeInPath, isDirectory: true) }
        return sessionSupportDirectory.appendingPathComponent("backup", isDirectory: true)
    }

    /// Whether quitting can skip the save prompts because unsaved work is preserved by the backup.
    public var canRestoreUnsavedOnLaunch: Bool { rememberSession && periodicBackupEnabled }

    /// Saves the current session (and backups of unsaved documents) for the next launch.
    @discardableResult
    public func snapshotSession() -> Bool {
        guard rememberSession else { return false }
        try? FileManager.default.createDirectory(at: sessionSupportDirectory, withIntermediateDirectories: true)
        return saveSession(to: autoSessionURL, backupDirectory: periodicBackupEnabled ? backupDirectoryURL : nil)
    }

    /// Prepares the workspace documents and session for application termination or window close.
    /// When session snapshot & periodic backup is active (`canRestoreUnsavedOnLaunch`),
    /// dirty and untitled documents are saved to the backup directory without modal prompts,
    /// matching upstream Notepad++ `WM_CLOSE` behavior.
    @discardableResult
    public func prepareForTermination() -> Bool {
        savePreferences()
        if canRestoreUnsavedOnLaunch {
            if snapshotSession() {
                return true
            }
            // Fallback if snapshot failed (e.g. disk write failure)
            return promptSaveDirtyDocumentsBeforeQuit()
        } else {
            guard promptSaveDirtyDocumentsBeforeQuit() else { return false }
            if rememberSession {
                _ = saveSession(to: autoSessionURL, backupDirectory: nil)
            } else {
                try? FileManager.default.removeItem(at: autoSessionURL)
            }
            return true
        }
    }

    /// Prompts the user to save dirty documents before exiting, matching upstream `fileCloseAll(false, false)`.
    public func promptSaveDirtyDocumentsBeforeQuit() -> Bool {
        let dirtyDocs = documents.filter { $0.isDirty || ($0.filePath == nil && !$0.content.isEmpty) }
        guard !dirtyDocs.isEmpty else { return true }

        for doc in dirtyDocs {
            let choice = confirmSaveIfNeeded(for: doc)
            switch choice {
            case .save:
                if !promptSaveSynchronously(for: doc) {
                    return false
                }
            case .dontSave:
                break
            case .cancel:
                return false
            }
        }
        return true
    }

    /// Reopens the previous session, including unsaved documents, if one was snapshotted.
    @discardableResult
    public func restoreAutoSession() -> Bool {
        guard rememberSession, FileManager.default.fileExists(atPath: autoSessionURL.path) else { return false }
        let blanks = documents.filter { $0.filePath == nil && !$0.isDirty && $0.content.isEmpty }
        let before = documents.count
        guard loadSession(from: autoSessionURL) else { return false }
        if documents.count > before {
            for blank in blanks { _ = closeDocument(id: blank.id, force: true) }
        }
        return true
    }

    public func loadSession(from url: URL) -> Bool {
        guard let data = try? Data(contentsOf: url) else { return false }
        guard !isLoadingSession else { return false }
        isLoadingSession = true
        defer { isLoadingSession = false }
        if let xml = try? XMLDocument(data: data),
           let root = xml.rootElement(),
           let session = (root.name == "Session" ? root : root.elements(forName: "Session").first) {
            func attribute(_ element: XMLElement, _ name: String) -> String? {
                element.attribute(forName: name)?.stringValue
            }
            let missingFiles = ["mainView", "subView"].flatMap { viewName in
                session.elements(forName: viewName).first?.elements(forName: "File") ?? []
            }.compactMap { file -> URL? in
                guard let path = attribute(file, "filename"), path.hasPrefix("/") else { return nil }
                if let b = attribute(file, "backupFilePath"), FileManager.default.fileExists(atPath: b) { return nil }
                let fileURL = URL(fileURLWithPath: path).standardizedFileURL
                return FileManager.default.fileExists(atPath: fileURL.path) ? nil : fileURL
            }
            let keepMissing: Bool
            if !keepAbsentFilesInSession || missingFiles.isEmpty {
                keepMissing = false
            } else if let decision = sessionPlaceholderDecisionHandler {
                keepMissing = decision(missingFiles)
            } else {
                keepMissing = interactionProvider.confirmKeepMissingFiles(missingFiles: missingFiles)
            }
            var loadedPrimary: [UUID] = []
            var loadedSecondary: [UUID] = []
            for (viewName, isSecondary) in [("mainView", false), ("subView", true)] {
                guard let view = session.elements(forName: viewName).first else { continue }
                for file in view.elements(forName: "File") {
                    guard let path = attribute(file, "filename"), !path.isEmpty else { continue }
                    let fileURL = URL(fileURLWithPath: path).standardizedFileURL
                    var restored: NppDocument?
                    if let backupPath = attribute(file, "backupFilePath"),
                       let backupData = FileManager.default.contents(atPath: backupPath) {
                        // Unsaved document: bring back the backed-up text and keep it marked as modified.
                        let isRealPath = path.hasPrefix("/")
                        let doc: NppDocument
                        if isRealPath {
                            if FileManager.default.fileExists(atPath: fileURL.path) { openFile(url: fileURL) }
                            if let open = documents.first(where: { $0.filePath?.standardizedFileURL == fileURL }) {
                                doc = open
                            } else {
                                doc = NppDocument(title: fileURL.lastPathComponent)
                                doc.filePath = fileURL
                                documents.append(doc)
                            }
                        } else {
                            doc = NppDocument(title: path)
                            documents.append(doc)
                        }
                        doc.content = String(decoding: backupData, as: UTF8.self)
                        if let enc = attribute(file, "backupEncoding"), !enc.isEmpty { doc.encoding = enc }
                        doc.hasBOM = attribute(file, "backupHasBOM") == "1"
                        if let raw = Int(attribute(file, "backupEol") ?? ""), let eol = NppEol(rawValue: raw) { doc.eolFormat = eol }
                        doc.isDirty = true
                        restored = doc
                    } else if FileManager.default.fileExists(atPath: fileURL.path) {
                        openFile(url: fileURL)
                    } else if keepMissing {
                        if !documents.contains(where: { $0.filePath?.standardizedFileURL == fileURL }) {
                            let placeholder = NppDocument(title: fileURL.lastPathComponent, content: "")
                            placeholder.filePath = fileURL
                            placeholder.isReadOnly = true
                            placeholder.isSessionPlaceholder = true
                            documents.append(placeholder)
                        }
                    } else {
                        continue
                    }
                    guard let doc = restored ?? documents.first(where: { $0.filePath?.standardizedFileURL == fileURL }) else { continue }
                    if isSecondary {
                        if loadedPrimary.contains(doc.id) {
                            if !secondaryDocumentIds.contains(doc.id) { cloneToOtherView(id: doc.id) }
                        } else if !secondaryDocumentIds.contains(doc.id) {
                            moveToOtherView(id: doc.id)
                        }
                        loadedSecondary.append(doc.id)
                    } else {
                        if secondaryDocumentIds.contains(doc.id) && !clonedDocumentIds.contains(doc.id) {
                            cloneToOtherView(id: doc.id)
                        }
                        loadedPrimary.append(doc.id)
                    }
                    if let language = attribute(file, "lang"), !language.isEmpty {
                        doc.language = language
                    }
                    let length = (doc.content as NSString).length
                    let start = min(max(0, Int(attribute(file, "startPos") ?? "") ?? 0), length)
                    let end = min(max(start, Int(attribute(file, "endPos") ?? "") ?? start), length)
                    doc.cursorPos = start
                    doc.selectionLength = end - start
                    let prefix = (doc.content as NSString).substring(to: start) as NSString
                    let info = NppLineCounter.lineInfo(upTo: prefix.length, in: prefix)
                    doc.cursorLine = info.line
                    doc.cursorCol = start - info.lineStart + 1
                    doc.bookmarkedLines = Set(file.elements(forName: "Mark").compactMap {
                        Int(attribute($0, "line") ?? "")
                    }.filter { $0 > 0 })
                    let pinnedAttr = attribute(file, "tabPinned")?.lowercased()
                    doc.isPinned = (pinnedAttr == "true" || pinnedAttr == "yes" || pinnedAttr == "1")
                }
            }
            let mainIndex = Int(attribute(session.elements(forName: "mainView").first ?? session, "activeIndex") ?? "") ?? 0
            let subIndex = Int(attribute(session.elements(forName: "subView").first ?? session, "activeIndex") ?? "") ?? 0
            if loadedSecondary.indices.contains(subIndex) {
                secondaryActiveDocumentId = loadedSecondary[subIndex]
            }
            if attribute(session, "activeView") == "1", let id = secondaryActiveDocumentId {
                activeView = 1
                activeDocumentId = id
            } else if loadedPrimary.indices.contains(mainIndex) {
                activeView = 0
                activeDocumentId = loadedPrimary[mainIndex]
            }
            return true
        } else if let paths = try? JSONSerialization.jsonObject(with: data) as? [String] {
            for p in paths {
                let fileURL = URL(fileURLWithPath: p)
                if FileManager.default.fileExists(atPath: fileURL.path) {
                    openFile(url: fileURL)
                }
            }
            return true
        }
        return false
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
        guard !documents.isEmpty else { return }
        if index == 8 && documents.count > 9 {
            activeDocumentId = documents.last?.id
        } else if index >= 0 && index < documents.count {
            activeDocumentId = documents[index].id
        } else if index >= documents.count {
            activeDocumentId = documents.last?.id
        }
    }

    public func moveTabToStart(id: UUID? = nil, viewIndex: Int? = nil) {
        let isSecondary = (viewIndex == 1) || (viewIndex == nil && activeView == 1)
        if isSecondary {
            let targetId = id ?? secondaryActiveDocumentId ?? secondaryDocumentIds.first
            guard let targetId = targetId,
                  let index = secondaryDocumentIds.firstIndex(of: targetId),
                  index > 0 else { return }
            let item = secondaryDocumentIds.remove(at: index)
            secondaryDocumentIds.insert(item, at: 0)
            secondaryActiveDocumentId = targetId
        } else {
            let targetId = id ?? activeDocumentId ?? documents.first?.id
            guard let targetId = targetId,
                  let index = documents.firstIndex(where: { $0.id == targetId }),
                  index > 0 else { return }
            let doc = documents.remove(at: index)
            documents.insert(doc, at: 0)
            activeDocumentId = targetId
        }
        objectWillChange.send()
    }

    public func moveTabToEnd(id: UUID? = nil, viewIndex: Int? = nil) {
        let isSecondary = (viewIndex == 1) || (viewIndex == nil && activeView == 1)
        if isSecondary {
            let targetId = id ?? secondaryActiveDocumentId ?? secondaryDocumentIds.last
            guard let targetId = targetId,
                  let index = secondaryDocumentIds.firstIndex(of: targetId),
                  index + 1 < secondaryDocumentIds.count else { return }
            let item = secondaryDocumentIds.remove(at: index)
            secondaryDocumentIds.append(item)
            secondaryActiveDocumentId = targetId
        } else {
            let targetId = id ?? activeDocumentId ?? documents.last?.id
            guard let targetId = targetId,
                  let index = documents.firstIndex(where: { $0.id == targetId }),
                  index + 1 < documents.count else { return }
            let doc = documents.remove(at: index)
            documents.append(doc)
            activeDocumentId = targetId
        }
        objectWillChange.send()
    }

    public func reorderTab(draggedId: UUID, targetId: UUID, viewIndex: Int) {
        guard draggedId != targetId else { return }
        if viewIndex == 1 {
            guard let from = secondaryDocumentIds.firstIndex(of: draggedId),
                  let to = secondaryDocumentIds.firstIndex(of: targetId) else { return }
            let id = secondaryDocumentIds.remove(at: from)
            secondaryDocumentIds.insert(id, at: to)
        } else {
            guard let from = documents.firstIndex(where: { $0.id == draggedId }),
                  let to = documents.firstIndex(where: { $0.id == targetId }) else { return }
            let doc = documents.remove(at: from)
            documents.insert(doc, at: to)
        }
        objectWillChange.send()
    }

    // MARK: - Column Mode Selection (IDM_EDIT_BEGINENDSELECT_COLUMNMODE)
    @Published public var isColumnModeSelecting: Bool = false
    @Published public var columnModeStartAnchor: (line: Int, col: Int)? = nil

    public func toggleColumnModeSelection() {
        guard let tv = activeTextView else { return }
        if isColumnModeSelecting {
            isColumnModeSelecting = false
            if let start = columnModeStartAnchor {
                let text = tv.string as NSString
                let sel = tv.selectedRange()
                let curPos = min(sel.location, text.length)
                let curLineRange = text.lineRange(for: NSRange(location: curPos, length: 0))
                var curLineNum = 1
                var idx = 0
                while idx < curLineRange.location {
                    curLineNum += 1
                    idx = NSMaxRange(text.lineRange(for: NSRange(location: idx, length: 0)))
                }
                let curCol = curPos - curLineRange.location
                if let nppTv = tv as? NppTextView {
                    let colRanges = nppTv.computeColumnRanges(fromLine: start.line, fromCol: start.col, toLine: curLineNum, toCol: curCol)
                    tv.selectedRanges = colRanges
                }
            }
            columnModeStartAnchor = nil
        } else {
            isColumnModeSelecting = true
            let text = tv.string as NSString
            let sel = tv.selectedRange()
            let curPos = min(sel.location, text.length)
            let curLineRange = text.lineRange(for: NSRange(location: curPos, length: 0))
            var curLineNum = 1
            var idx = 0
            while idx < curLineRange.location {
                curLineNum += 1
                idx = NSMaxRange(text.lineRange(for: NSRange(location: idx, length: 0)))
            }
            let curCol = curPos - curLineRange.location
            columnModeStartAnchor = (curLineNum, curCol)
        }
        objectWillChange.send()
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
            let res = $0.title.localizedStandardCompare($1.title)
            if res != .orderedSame {
                return ascending ? res == .orderedAscending : res == .orderedDescending
            }
            let p1 = $0.filePath?.path ?? $0.title
            let p2 = $1.filePath?.path ?? $1.title
            return ascending ? p1.localizedStandardCompare(p2) == .orderedAscending
                             : p1.localizedStandardCompare(p2) == .orderedDescending
        }
    }

    public func sortTabsByPath(ascending: Bool) {
        documents.sort {
            let p1 = $0.filePath?.path ?? $0.title
            let p2 = $1.filePath?.path ?? $1.title
            let res = p1.localizedStandardCompare(p2)
            if res != .orderedSame {
                return ascending ? res == .orderedAscending : res == .orderedDescending
            }
            return ascending ? $0.title.localizedStandardCompare($1.title) == .orderedAscending
                             : $0.title.localizedStandardCompare($1.title) == .orderedDescending
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
            let langA = a.language
            let langB = b.language
            if langA != langB {
                return ascending
                    ? langA.localizedStandardCompare(langB) == .orderedAscending
                    : langA.localizedStandardCompare(langB) == .orderedDescending
            }
            let extA = a.filePath?.pathExtension.lowercased() ?? (a.title as NSString).pathExtension.lowercased()
            let extB = b.filePath?.pathExtension.lowercased() ?? (b.title as NSString).pathExtension.lowercased()
            if extA != extB {
                return ascending
                    ? extA.localizedStandardCompare(extB) == .orderedAscending
                    : extA.localizedStandardCompare(extB) == .orderedDescending
            }
            return ascending
                ? a.title.localizedStandardCompare(b.title) == .orderedAscending
                : a.title.localizedStandardCompare(b.title) == .orderedDescending
        }
    }

    public func sortTabsBySize(ascending: Bool) {
        documents.sort {
            if $0.content.count != $1.content.count {
                return ascending ? $0.content.count < $1.content.count : $0.content.count > $1.content.count
            }
            return ascending ? $0.title.localizedStandardCompare($1.title) == .orderedAscending
                             : $0.title.localizedStandardCompare($1.title) == .orderedDescending
        }
    }

    public func sortTabsByModifiedTime(ascending: Bool) {
        documents.sort {
            let d1 = $0.lastKnownModificationDate ?? Date.distantPast
            let d2 = $1.lastKnownModificationDate ?? Date.distantPast
            if d1 != d2 {
                return ascending ? d1 < d2 : d1 > d2
            }
            return ascending ? $0.title.localizedStandardCompare($1.title) == .orderedAscending
                             : $0.title.localizedStandardCompare($1.title) == .orderedDescending
        }
    }

    @discardableResult
    public func closeActive(force: Bool = false) -> Bool {
        if let doc = activeDocument {
            return closeDocument(id: doc.id, force: force)
        }
        return true
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
            let lineCount = NppLineCounter.lineCount(in: doc.content)
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

    public func applyTextToTextViewPreservingUndo(tv: NSTextView, newText: String) {
        guard tv.string != newText else { return }
        let fullRange = NSRange(location: 0, length: (tv.string as NSString).length)
        if tv.shouldChangeText(in: fullRange, replacementString: newText) {
            tv.undoManager?.beginUndoGrouping()
            tv.replaceCharacters(in: fullRange, with: newText)
            tv.didChangeText()
            tv.undoManager?.endUndoGrouping()
        } else {
            tv.string = newText
        }
    }

    /// Synchronizes changes from NppDocument into NSTextView, safely clamping and preserving selection with Undo preservation.
    public func syncDocumentToTextView(doc: NppDocument, tv: NSTextView) {
        if tv.string != doc.content {
            let sel = tv.selectedRange()
            let newLen = (doc.content as NSString).length
            applyTextToTextViewPreservingUndo(tv: tv, newText: doc.content)
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
        guard !doc.isReadOnly && !isAllDocumentsReadOnly else { return }

        if let tv = tv, doc.content != tv.string {
            syncTextViewToDocument(tv: tv, doc: doc)
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
        guard let doc = activeDocument, !doc.isReadOnly && !isAllDocumentsReadOnly else { return }
        isPlayingBackMacro = true
        defer { isPlayingBackMacro = false }

        let tv = activeTextView ?? (NSApp.keyWindow?.firstResponder as? NSTextView)

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
    public func selectRange(_ range: NSRange, makeFirstResponder: Bool = true) {
        if let tv = activeTextView ?? (NSApp.keyWindow?.firstResponder as? NSTextView) {
            if makeFirstResponder {
                tv.window?.makeFirstResponder(tv)
            }
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
        var targetFound = false
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
                    targetFound = true
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
                    targetFound = true
                }
            }
        }
        // Upstream parity: if (str.empty()) return;
        guard targetFound else { return }
        findNext(forward: forward)
    }

    /// `IDM_SEARCH_VOLATILE_FINDNEXT` (`Cmd+Option+F3`) & `IDM_SEARCH_VOLATILE_FINDPREV` (`Cmd+Option+Shift+F3`)
    /// Upstream NppCommands.cpp:1690-1715:
    /// Expands word under caret if needed, wraps around, case-insensitive, normal search.
    /// MUST NOT modify `lastSearchQuery` or `findQueryText`.
    public func findVolatile(forward: Bool = true) {
        guard let doc = activeDocument else { return }
        let nsStr: NSString
        var sel: NSRange

        if let tv = activeTextView {
            if tv.string != doc.content {
                syncDocumentToTextView(doc: doc, tv: tv)
            }
            nsStr = tv.string as NSString
            sel = tv.selectedRange()
            if sel.length == 0 {
                let expanded = expandWordRange(at: sel.location, in: nsStr)
                if expanded.length > 0 {
                    tv.setSelectedRange(expanded)
                    sel = expanded
                    doc.cursorPos = expanded.location
                    doc.selectionLength = expanded.length
                }
            }
        } else {
            nsStr = doc.content as NSString
            sel = NSRange(
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
        }

        guard sel.length > 0, NSMaxRange(sel) <= nsStr.length else { return }
        let targetText = nsStr.substring(with: sel)
        guard !targetText.isEmpty else { return }

        // Upstream: op._isMatchCase = false, op._isWrapAround = true, op._searchType = FindNormal
        let options: NSString.CompareOptions = forward ? [.caseInsensitive] : [.caseInsensitive, .backwards]
        let searchRange: NSRange
        if forward {
            let start = NSMaxRange(sel)
            searchRange = NSRange(location: min(start, nsStr.length), length: max(0, nsStr.length - min(start, nsStr.length)))
        } else {
            searchRange = NSRange(location: 0, length: min(sel.location, nsStr.length))
        }

        var found = nsStr.range(of: targetText, options: options, range: searchRange)
        if found.location == NSNotFound {
            // Wrap around (always true for volatile find in upstream)
            found = nsStr.range(of: targetText, options: options)
        }

        if found.location != NSNotFound {
            if let tv = activeTextView {
                tv.setSelectedRange(found)
                tv.scrollRangeToVisible(found)
            }
            doc.cursorPos = found.location
            doc.selectionLength = found.length
        }
        // Notice: lastSearchQuery and findQueryText are intentionally NOT modified!
    }

    /// `IDM_SEARCH_FINDINCREMENT` (`Cmd+Option+I`)
    public func toggleIncrementalSearch() {
        searchBarMode = .find
        if !showSearchBar {
            // Opening: pre-fill from selection without expanding (upstream getSelectedTextToWChar(false))
            if let tv = activeTextView {
                let sel = tv.selectedRange()
                if sel.length > 0 && NSMaxRange(sel) <= (tv.string as NSString).length {
                    let selectedStr = (tv.string as NSString).substring(with: sel)
                    if !selectedStr.isEmpty && !selectedStr.contains("\n") && !selectedStr.contains("\r") {
                        findQueryText = selectedStr
                    }
                }
            }
            showSearchBar = true
        } else {
            showSearchBar = false
        }
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
        case 1: return NSColor(calibratedRed: 0.00, green: 1.00, blue: 1.00, alpha: 0.40) // 1st Style: Cyan (#00FFFF)
        case 2: return NSColor(calibratedRed: 1.00, green: 0.50, blue: 0.00, alpha: 0.40) // 2nd Style: Orange (#FF8000)
        case 3: return NSColor(calibratedRed: 1.00, green: 1.00, blue: 0.00, alpha: 0.40) // 3rd Style: Yellow (#FFFF00)
        case 4: return NSColor(calibratedRed: 0.50, green: 0.00, blue: 1.00, alpha: 0.40) // 4th Style: Purple (#8000FF)
        case 5: return NSColor(calibratedRed: 0.00, green: 0.50, blue: 0.00, alpha: 0.40) // 5th Style: Dark Green (#008000)
        default: return NSColor(calibratedRed: 0.00, green: 1.00, blue: 1.00, alpha: 0.40)
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
        for r in matchedRanges {
            if !existing.contains(r) {
                existing.append(r)
            }
        }
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
        if !existing.contains(sel) {
            existing.append(sel)
        }
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
        let content = doc.content as NSString
        let clampedLoc = min(range.location, content.length)
        doc.cursorLine = NppLineCounter.lineNumber(upTo: clampedLoc, in: content)
        if let tv = activeTextView {
            tv.setSelectedRange(range)
            tv.scrollRangeToVisible(range)
        }
    }

    public func openFindCharsInRange() {
        showFindCharsInRangeDialog = true
        NppFindCharsInRangeWindowController.shared.show(workspace: self)
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
        let win = window ?? NSApp.keyWindow ?? NSApp.mainWindow
        if !isPostItMode {
            if !isDistractionFreeMode {
                savedPreModeToolbar = hideToolbar
                savedPreModeTabBar = hideTabBar
                savedPreModeStatusBar = hideStatusBar
                savedPrePostItAlwaysOnTop = isAlwaysOnTop
            }
            isPostItMode = true
            isDistractionFreeMode = false
            hideToolbar = true
            hideTabBar = true
            hideStatusBar = true
            isAlwaysOnTop = true
            win?.level = .floating
        } else {
            isPostItMode = false
            hideToolbar = savedPreModeToolbar
            hideTabBar = savedPreModeTabBar
            hideStatusBar = savedPreModeStatusBar
            isAlwaysOnTop = savedPrePostItAlwaysOnTop
            win?.level = savedPrePostItAlwaysOnTop ? .floating : .normal
        }
    }

    public func toggleDistractionFreeMode(window: NSWindow? = nil) {
        let win = window ?? NSApp.keyWindow ?? NSApp.mainWindow
        if !isDistractionFreeMode {
            if !isPostItMode {
                savedPreModeToolbar = hideToolbar
                savedPreModeTabBar = hideTabBar
                savedPreModeStatusBar = hideStatusBar
                savedPreDistractionFreeAlwaysOnTop = isAlwaysOnTop
            }
            isDistractionFreeMode = true
            isPostItMode = false
            hideToolbar = true
            hideTabBar = true
            hideStatusBar = true
            isAlwaysOnTop = true
            win?.level = .floating
            paddingLeft = max(paddingLeft, 120)
            if let w = win, !isFullScreen {
                w.toggleFullScreen(nil)
            }
        } else {
            isDistractionFreeMode = false
            hideToolbar = savedPreModeToolbar
            hideTabBar = savedPreModeTabBar
            hideStatusBar = savedPreModeStatusBar
            isAlwaysOnTop = savedPreDistractionFreeAlwaysOnTop
            win?.level = savedPreDistractionFreeAlwaysOnTop ? .floating : .normal
            if paddingLeft == 120 {
                paddingLeft = 0
            }
            if let w = win, isFullScreen {
                w.toggleFullScreen(nil)
            }
        }
    }

    private var monitoringSources: [UUID: DispatchSourceFileSystemObject] = [:]
    private var monitoringFileDescriptors: [UUID: Int32] = [:]

    public var lastMonitoringAlert: String? = nil

    public func toggleMonitoringCurrentDoc(window: NSWindow? = nil) {
        guard let doc = activeDocument else { return }
        guard doc.filePath != nil else {
            let msg = tr("The file should exist to be monitored.")
            lastMonitoringAlert = msg
            if !CommandLine.arguments.contains("--run-tests") && NSApp.mainWindow != nil {
                let alert = NSAlert()
                alert.messageText = tr("Monitoring (tail -f)")
                alert.informativeText = msg
                alert.alertStyle = .warning
                alert.runModal()
            }
            return
        }

        if !doc.isMonitoring {
            if doc.isDirty {
                let msg = tr("The document is dirty. Please save the modification before monitoring it.")
                lastMonitoringAlert = msg
                if !CommandLine.arguments.contains("--run-tests") && NSApp.mainWindow != nil {
                    let alert = NSAlert()
                    alert.messageText = tr("Monitoring (tail -f)")
                    alert.informativeText = msg
                    alert.alertStyle = .warning
                    alert.runModal()
                }
                return
            }

            doc.isMonitoring = true
            doc.isReadOnly = true
            startMonitoring(document: doc)
        } else {
            stopMonitoring(document: doc)
            doc.isMonitoring = false
            doc.isReadOnly = false
        }
        objectWillChange.send()
    }

    public func startMonitoring(document doc: NppDocument) {
        guard let fileURL = doc.filePath else { return }
        stopMonitoring(document: doc)

        let fd = open(fileURL.path, O_EVTONLY)
        guard fd >= 0 else { return }
        monitoringFileDescriptors[doc.id] = fd

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .extend, .attrib],
            queue: DispatchQueue.main
        )

        source.setEventHandler { [weak self, weak doc] in
            guard let self = self, let doc = doc, let url = doc.filePath else { return }
            if let data = try? Data(contentsOf: url) {
                doc.rawFileBytes = data
                var decoded: String = ""
                data.withUnsafeBytes { (rawBuffer: UnsafeRawBufferPointer) -> Void in
                    guard let ptr = rawBuffer.baseAddress?.assumingMemoryBound(to: CChar.self) else { return }
                    var decodedLen: Int32 = 0
                    let norm = NppDocument.normalizeCharset(doc.encoding)
                    if norm == "UTF-8" {
                        decoded = String(decoding: data, as: UTF8.self)
                    } else if let decodedPtr = npp_decode_to_utf8(ptr, data.count, norm, &decodedLen) {
                        let decodedData = Data(bytes: decodedPtr, count: Int(decodedLen))
                        decoded = String(bytes: decodedData, encoding: .utf8) ?? String(decoding: decodedData, as: UTF8.self)
                        npp_free_string(decodedPtr)
                    } else {
                        decoded = String(decoding: data, as: UTF8.self)
                    }
                }
                doc.content = decoded
                doc.isDirty = false
                if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
                   let modDate = attrs[.modificationDate] as? Date {
                    doc.lastKnownModificationDate = modDate
                }
                if self.activeDocumentId == doc.id, let tv = self.activeTextView {
                    tv.string = decoded
                    let len = (decoded as NSString).length
                    tv.setSelectedRange(NSRange(location: len, length: 0))
                    tv.scrollRangeToVisible(NSRange(location: len, length: 0))
                }
            }
        }

        source.setCancelHandler {
            close(fd)
        }

        monitoringSources[doc.id] = source
        source.resume()
    }

    public func stopMonitoring(document doc: NppDocument) {
        if let source = monitoringSources.removeValue(forKey: doc.id) {
            source.cancel()
        }
        _ = monitoringFileDescriptors.removeValue(forKey: doc.id)
    }

    public func scrollToBottom() {
        guard let tv = activeTextView else { return }
        let len = (tv.string as NSString).length
        tv.scrollRangeToVisible(NSRange(location: len, length: 0))
    }

    // MARK: - Function List Parser & Sorter (function-list.md:30-55)
    public static func parseFunctions(content: String, filter: String = "", sortedAlphabetically: Bool = false) -> [NppFunctionItem] {
        let lines = content.nppLines()
        var results: [NppFunctionItem] = []
        for (idx, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let isClass = trimmed.hasPrefix("class ") || trimmed.hasPrefix("struct ")
            let isFunc = trimmed.hasPrefix("func ") || trimmed.hasPrefix("def ") || trimmed.hasPrefix("function ") ||
                         (trimmed.contains("(") && trimmed.contains(")") && (trimmed.hasPrefix("void ") || trimmed.hasPrefix("int ") || trimmed.hasPrefix("public ") || trimmed.hasPrefix("private ")))
            if isClass || isFunc {
                var name = trimmed
                if let paren = name.firstIndex(of: "(") {
                    name = String(name[..<paren])
                }
                if let brace = name.firstIndex(of: "{") {
                    name = String(name[..<brace])
                }
                name = name.trimmingCharacters(in: .whitespaces)
                var changed = true
                while changed {
                    changed = false
                    for prefix in ["public ", "private ", "fileprivate ", "internal ", "open ", "static ", "final ", "class ", "struct ", "func ", "def ", "function ", "void ", "int ", "bool ", "double ", "float "] {
                        if name.hasPrefix(prefix) {
                            name = String(name.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
                            changed = true
                            break
                        }
                    }
                }
                results.append(NppFunctionItem(name: name, line: idx + 1, isClass: isClass))
            }
        }

        if !filter.isEmpty {
            results = results.filter { $0.name.localizedCaseInsensitiveContains(filter) }
        }

        if sortedAlphabetically {
            results.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        } else {
            results.sort { $0.line < $1.line }
        }

        return results
    }

    // MARK: - Folder As Workspace Helpers (session.md:110-140)
    public static func unfoldAllDirectories(in roots: [URL]) -> Set<String> {
        var allDirs: Set<String> = []
        let fm = FileManager.default
        for root in roots {
            allDirs.insert(root.path)
            if let enumerator = fm.enumerator(at: root, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) {
                for case let fileUrl as URL in enumerator {
                    var isDir: AnyObject?
                    try? (fileUrl as NSURL).getResourceValue(&isDir, forKey: .isDirectoryKey)
                    if let isDir = isDir as? Bool, isDir {
                        allDirs.insert(fileUrl.path)
                    }
                }
            }
        }
        return allDirs
    }

    public static func locateAncestorDirectories(for fileUrl: URL, in roots: [URL]) -> Set<String> {
        var dirs: Set<String> = []
        var current = fileUrl.deletingLastPathComponent()
        while current.path != "/" && !current.path.isEmpty {
            dirs.insert(current.path)
            if roots.contains(where: { $0.standardizedFileURL.path == current.standardizedFileURL.path }) {
                break
            }
            let parent = current.deletingLastPathComponent()
            if parent.path == current.path { break }
            current = parent
        }
        return dirs
    }
}

public struct NppFunctionItem: Identifiable, Equatable {
    public var id: Int { line }
    public let name: String
    public let line: Int
    public let isClass: Bool

    public init(name: String, line: Int, isClass: Bool) {
        self.name = name
        self.line = line
        self.isClass = isClass
    }
}
