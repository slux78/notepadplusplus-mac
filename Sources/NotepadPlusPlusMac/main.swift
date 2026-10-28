import AppKit
import SwiftUI
import Combine

final class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    let workspace = NppWorkspace()
    private var cancellables = Set<AnyCancellable>()
    private var activeDocCancellable: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let contentView = NppMainWindowView(workspace: workspace)

        window = NSWindow(
            contentRect: NSRect(x: 100, y: 100, width: 1050, height: 720),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        updateWindowTitle()
        window.contentView = NSHostingView(rootView: contentView)
        window.makeKeyAndOrderFront(nil)
        setupMenuBar()

        // Synchronize window title with active document and workspace changes (AUDIT-011)
        workspace.$activeDocumentId
            .receive(on: RunLoop.main)
            .sink { [weak self] newId in
                self?.bindActiveDocument(for: newId)
                self?.updateWindowTitle(for: newId)
            }
            .store(in: &cancellables)

        // Real-time menu bar localization without restart (preferenceDlg.cpp L919 NPPM_INTERNAL_RELOADNATIVELANG)
        workspace.$localizationLanguage
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.setupMenuBar()
            }
            .store(in: &cancellables)

        workspace.$recentFiles
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.setupMenuBar()
            }
            .store(in: &cancellables)

        workspace.$savedMacros
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.setupMenuBar()
            }
            .store(in: &cancellables)

        workspace.$documents
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.setupMenuBar()
            }
            .store(in: &cancellables)

        workspace.$disabledLanguages
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.setupMenuBar()
            }
            .store(in: &cancellables)

        workspace.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateWindowTitle()
            }
            .store(in: &cancellables)

        bindActiveDocument()

        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.workspace.checkAllFilesStatus()
        }

        if CommandLine.arguments.contains("--run-tests") {
            NppAutomatedTestSuite.run(appDelegate: self)
        } else if let tabIdxStr = CommandLine.arguments.first(where: { $0.hasPrefix("--screenshot-pref-tab=") }) {
            let tabIdx = Int(tabIdxStr.replacingOccurrences(of: "--screenshot-pref-tab=", with: "")) ?? 0
            NppAutomatedTestSuite.captureCustomScreenshot(appDelegate: self, setup: { ws in
                ws.openPreferences(tab: tabIdx)
            }, filename: "screenshot_pref_tab_\(tabIdx).png")
        } else if CommandLine.arguments.contains("--screenshot-prefs") {
            NppAutomatedTestSuite.captureCustomScreenshot(appDelegate: self, setup: { ws in
                ws.openPreferences(tab: 0)
            }, filename: "screenshot_preferences.png")
        } else if CommandLine.arguments.contains("--screenshot-find-dialog") {
            NppAutomatedTestSuite.captureCustomScreenshot(appDelegate: self, setup: { ws in
                ws.openFind()
            }, filename: "screenshot_find_dialog.png")
        } else if CommandLine.arguments.contains("--screenshot-find-in-files") {
            NppAutomatedTestSuite.captureCustomScreenshot(appDelegate: self, setup: { ws in
                ws.openFindInFiles()
            }, filename: "screenshot_find_in_files.png")
        } else if CommandLine.arguments.contains("--screenshot-editor-dialog") {
            NppAutomatedTestSuite.captureCustomScreenshot(appDelegate: self, setup: { ws in
                ws.openFind()
            }, filename: "screenshot_editor_dialog.png")
        } else if CommandLine.arguments.contains("--screenshot-pinned-tab") {
            NppAutomatedTestSuite.captureCustomScreenshot(appDelegate: self, setup: { ws in
                ws.newDocument()
                ws.documents.first?.title = "Pinned Notes"
                ws.documents.first?.isPinned = true
                ws.documents.last?.title = "Document 2"
            }, filename: "screenshot_pinned_tab.png")
        } else if CommandLine.arguments.contains("--screenshot-style-config") {
            NppAutomatedTestSuite.captureCustomScreenshot(appDelegate: self, setup: { ws in
                ws.showStyleConfigurator = true
            }, filename: "screenshot_style_config.png")
        } else if CommandLine.arguments.contains("--screenshot-shortcuts") {
            NppAutomatedTestSuite.captureCustomScreenshot(appDelegate: self, setup: { ws in
                ws.showShortcutMapper = true
            }, filename: "screenshot_shortcuts.png")
        } else if CommandLine.arguments.contains("--screenshot-column-editor") {
            NppAutomatedTestSuite.captureCustomScreenshot(appDelegate: self, setup: { ws in
                ws.showColumnEditor = true
            }, filename: "screenshot_column_editor.png")
        } else if CommandLine.arguments.contains("--screenshot-run-macro") {
            NppAutomatedTestSuite.captureCustomScreenshot(appDelegate: self, setup: { ws in
                ws.startMacroRecording()
                ws.recordMacroStep(.insertText("// header"))
                ws.stopMacroRecording()
                ws.runMacroMultipleTimes()
            }, filename: "screenshot_run_macro.png")
        } else if CommandLine.arguments.contains("--screenshot-panels") {
            NppAutomatedTestSuite.captureCustomScreenshot(appDelegate: self, setup: { ws in
                ws.showDocumentList = true
                ws.showFolderAsWorkspace = true
            }, filename: "screenshot_panels.png")
        } else if CommandLine.arguments.contains("--screenshot-fonts") {
            NppAutomatedTestSuite.captureScreenshot(appDelegate: self, openPrefs: true, prefTab: 1, filename: "screenshot_fonts.png")
        } else if CommandLine.arguments.contains("--screenshot-themes") {
            NppAutomatedTestSuite.captureScreenshot(appDelegate: self, openPrefs: true, prefTab: 2, filename: "screenshot_themes.png")
        } else if CommandLine.arguments.contains("--screenshot-invisibles") {
            NppAutomatedTestSuite.captureScreenshot(appDelegate: self, openPrefs: false, showInvisibles: true, filename: "screenshot_invisibles.png")
        } else if CommandLine.arguments.contains("--screenshot-find") {
            NppAutomatedTestSuite.captureScreenshot(appDelegate: self, openPrefs: false, searchMode: .find, filename: "screenshot_find.png")
        } else if CommandLine.arguments.contains("--screenshot-replace") {
            NppAutomatedTestSuite.captureScreenshot(appDelegate: self, openPrefs: false, searchMode: .replace, filename: "screenshot_replace.png")
        } else if CommandLine.arguments.contains("--screenshot-tabbar-hidden") {
            NppAutomatedTestSuite.captureCustomScreenshot(appDelegate: self, setup: { ws in
                ws.hideTabBar = true
            }, filename: "screenshot_tabbar_hidden.png")
        } else if CommandLine.arguments.contains("--screenshot-toolbar-custom") {
            NppAutomatedTestSuite.captureCustomScreenshot(appDelegate: self, setup: { ws in
                ws.toolbarIconStyle = "Filled Fluent UI: large"
                ws.largeToolbarIcons = true
                ws.toolbarColorChoice = "Red"
                ws.toolbarColorization = "Complete"
            }, filename: "screenshot_toolbar_custom.png")
        } else if CommandLine.arguments.contains("--screenshot-tabbar-reduced") {
            NppAutomatedTestSuite.captureCustomScreenshot(appDelegate: self, setup: { ws in
                ws.tabReduce = true
                ws.tabMaxLabelLen = 8
            }, filename: "screenshot_tabbar_reduced.png")
        } else if CommandLine.arguments.contains("--screenshot-find-transparent") {
            NppAutomatedTestSuite.captureCustomScreenshot(appDelegate: self, setup: { ws in
                ws.openFind()
                ws.findTransparencyEnabled = true
                ws.findTransparencyMode = 1 // Always semi-transparent
                ws.findTransparencyValue = 0.65
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    NppFindReplaceWindowController.shared.updateTransparency()
                }
            }, filename: "screenshot_find_transparent.png")
        } else if CommandLine.arguments.contains("--screenshot-light") {
            NppAutomatedTestSuite.captureCustomScreenshot(appDelegate: self, setup: { ws in
                ws.themeMode = "light"
                ws.darkModeChoice = 0
                ws.applyDarkModeChoice()
            }, filename: "screenshot_light.png")
        } else if CommandLine.arguments.contains("--screenshot-main") {
            NppAutomatedTestSuite.captureScreenshot(appDelegate: self, openPrefs: false, filename: "screenshot_main.png")
        } else {
            NppCommandLineParser.parse(CommandLine.arguments, workspace: workspace)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        for fn in filenames {
            workspace.openFile(url: URL(fileURLWithPath: fn))
        }
        updateWindowTitle()
    }

    func updateWindowTitle(for documentId: UUID? = nil) {
        let activeDoc: NppDocument?
        if let docId = documentId {
            activeDoc = workspace.documents.first(where: { $0.id == docId })
        } else {
            activeDoc = workspace.activeDocument
        }

        if let doc = activeDoc {
            let dirtyPrefix = doc.isDirty ? "*" : ""
            let pathOrTitle = doc.filePath?.path ?? doc.title
            window?.title = "\(dirtyPrefix)\(pathOrTitle) - Notepad++"
        } else {
            window?.title = "Notepad++"
        }
    }

    func bindActiveDocument(for documentId: UUID? = nil) {
        activeDocCancellable?.cancel()
        let activeDoc: NppDocument?
        if let docId = documentId {
            activeDoc = workspace.documents.first(where: { $0.id == docId })
        } else {
            activeDoc = workspace.activeDocument
        }
        if let doc = activeDoc {
            activeDocCancellable = doc.objectWillChange
                .receive(on: RunLoop.main)
                .sink { [weak self] _ in
                    self?.updateWindowTitle()
                }
        }
    }

    public func setupMenuBar() {
        let tr = { [weak self] (key: String) -> String in
            self?.workspace.tr(key) ?? key
        }
        let mainMenu = NSMenu()

        // 1. App Menu
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: tr("About Notepad++"), action: #selector(showAbout), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: tr("Preferences..."), action: #selector(menuPreferences), keyEquivalent: ",")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: tr("Quit Notepad++"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        // 2. File Menu (100% Notepad++ Notepad_plus.rc L444-488 parity)
        let fileMenuItem = NSMenuItem()
        let fileMenu = NSMenu(title: tr("File"))
        fileMenu.addItem(withTitle: tr("New"), action: #selector(menuNew), keyEquivalent: "n")
        fileMenu.addItem(withTitle: tr("Open..."), action: #selector(menuOpen), keyEquivalent: "o")

        let openFolderMenu = NSMenu(title: tr("Open Containing Folder"))
        openFolderMenu.addItem(withTitle: tr("Finder"), action: #selector(menuOpenFolderFinder), keyEquivalent: "")
        openFolderMenu.addItem(withTitle: tr("Terminal"), action: #selector(menuOpenFolderTerminal), keyEquivalent: "")
        openFolderMenu.addItem(NSMenuItem.separator())
        openFolderMenu.addItem(withTitle: tr("Folder as Workspace"), action: #selector(menuOpenContainingFolderAsWorkspace), keyEquivalent: "")
        let openFolderItem = NSMenuItem(title: tr("Open Containing Folder"), action: nil, keyEquivalent: "")
        openFolderItem.submenu = openFolderMenu
        fileMenu.addItem(openFolderItem)

        fileMenu.addItem(withTitle: tr("Open in Default Viewer"), action: #selector(menuOpenInDefaultViewer), keyEquivalent: "")
        fileMenu.addItem(withTitle: tr("Open Folder as Workspace..."), action: #selector(menuOpenFolderAsWorkspace), keyEquivalent: "")
        fileMenu.addItem(withTitle: tr("Reload from Disk"), action: #selector(menuReload), keyEquivalent: "r")
        fileMenu.addItem(NSMenuItem.separator())
        fileMenu.addItem(withTitle: tr("Save"), action: #selector(menuSave), keyEquivalent: "s")
        fileMenu.addItem(withTitle: tr("Save As..."), action: #selector(menuSaveAs), keyEquivalent: "S")
        fileMenu.addItem(withTitle: tr("Save a Copy As..."), action: #selector(menuSaveCopyAs), keyEquivalent: "")
        fileMenu.addItem(withTitle: tr("Save All"), action: #selector(menuSaveAll), keyEquivalent: "")
        fileMenu.addItem(withTitle: tr("Rename..."), action: #selector(menuRename), keyEquivalent: "")
        fileMenu.addItem(NSMenuItem.separator())
        fileMenu.addItem(withTitle: tr("Close"), action: #selector(menuCloseTab), keyEquivalent: "w")
        fileMenu.addItem(withTitle: tr("Close All"), action: #selector(menuCloseAll), keyEquivalent: "")

        let closeMultiMenu = NSMenu(title: tr("Close Multiple Documents"))
        closeMultiMenu.addItem(withTitle: tr("Close All but Active Document"), action: #selector(menuCloseAllButActive), keyEquivalent: "")
        closeMultiMenu.addItem(withTitle: tr("Close All but Pinned Documents"), action: #selector(menuCloseAllButPinned), keyEquivalent: "")
        closeMultiMenu.addItem(withTitle: tr("Close All to the Left"), action: #selector(menuCloseAllToLeft), keyEquivalent: "")
        closeMultiMenu.addItem(withTitle: tr("Close All to the Right"), action: #selector(menuCloseAllToRight), keyEquivalent: "")
        closeMultiMenu.addItem(withTitle: tr("Close All Unchanged"), action: #selector(menuCloseAllUnchanged), keyEquivalent: "")
        let closeMultiItem = NSMenuItem(title: tr("Close Multiple Documents"), action: nil, keyEquivalent: "")
        closeMultiItem.submenu = closeMultiMenu
        fileMenu.addItem(closeMultiItem)

        fileMenu.addItem(withTitle: tr("Move to Trash"), action: #selector(menuMoveToTrash), keyEquivalent: "")
        fileMenu.addItem(NSMenuItem.separator())
        fileMenu.addItem(withTitle: tr("Load Session..."), action: #selector(menuLoadSession), keyEquivalent: "")
        fileMenu.addItem(withTitle: tr("Save Session..."), action: #selector(menuSaveSession), keyEquivalent: "")
        fileMenu.addItem(NSMenuItem.separator())
        fileMenu.addItem(withTitle: tr("Print..."), action: #selector(menuPrint), keyEquivalent: "p")
        fileMenu.addItem(withTitle: tr("Print Now"), action: #selector(menuPrintNow), keyEquivalent: "")
        fileMenu.addItem(NSMenuItem.separator())

        let recentMenu = NSMenu(title: tr("Recent Files"))
        for (idx, url) in workspace.recentFiles.enumerated() {
            let label: String
            if workspace.recentFilesDisplayMode == 0 {
                label = "\(idx + 1): \(url.lastPathComponent)"
            } else {
                label = "\(idx + 1): \(url.path)"
            }
            let rItem = NSMenuItem(title: label, action: #selector(menuOpenRecentFile(_:)), keyEquivalent: "")
            rItem.representedObject = url
            recentMenu.addItem(rItem)
        }
        if !workspace.recentFiles.isEmpty {
            recentMenu.addItem(NSMenuItem.separator())
        }
        let restoreClosedItem = NSMenuItem(title: tr("Restore Recent Closed File"), action: #selector(menuRestoreRecentClosedFile), keyEquivalent: "T")
        restoreClosedItem.keyEquivalentModifierMask = [.command, .shift]
        recentMenu.addItem(restoreClosedItem)
        recentMenu.addItem(withTitle: tr("Open All Recent Files"), action: #selector(menuOpenAllRecentFiles), keyEquivalent: "")
        recentMenu.addItem(withTitle: tr("Empty Recent Files List"), action: #selector(menuEmptyRecentFilesList), keyEquivalent: "")
        let recentMenuItem = NSMenuItem(title: tr("Recent Files"), action: nil, keyEquivalent: "")
        recentMenuItem.submenu = recentMenu
        fileMenu.addItem(recentMenuItem)

        fileMenu.addItem(NSMenuItem.separator())
        fileMenu.addItem(withTitle: tr("Exit"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "")

        fileMenuItem.submenu = fileMenu
        mainMenu.addItem(fileMenuItem)

        // 3. Edit Menu (Notepad++ Windows parity)
        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: tr("Edit"))
        editMenu.addItem(withTitle: tr("Undo"), action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: tr("Redo"), action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: tr("Cut"), action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: tr("Copy"), action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: tr("Paste"), action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: tr("Delete"), action: #selector(NSText.delete(_:)), keyEquivalent: "")
        editMenu.addItem(withTitle: tr("Select All"), action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        let beginEndSelectItem = NSMenuItem(title: tr("Begin/End Select"), action: #selector(menuBeginEndSelect), keyEquivalent: "B")
        beginEndSelectItem.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(beginEndSelectItem)
        editMenu.addItem(NSMenuItem.separator())

        // Insert submenu
        let insertMenu = NSMenu(title: tr("Insert"))
        insertMenu.addItem(withTitle: tr("Date Time (short)"), action: #selector(menuInsertDateShort), keyEquivalent: "")
        insertMenu.addItem(withTitle: tr("Date Time (long)"), action: #selector(menuInsertDateLong), keyEquivalent: "")
        insertMenu.addItem(withTitle: tr("Date Time (customized)"), action: #selector(menuInsertDateCustomized), keyEquivalent: "")
        let insertItem = NSMenuItem(title: tr("Insert"), action: nil, keyEquivalent: "")
        insertItem.submenu = insertMenu
        editMenu.addItem(insertItem)

        // Copy to Clipboard submenu
        let copyClipMenu = NSMenu(title: tr("Copy to Clipboard"))
        copyClipMenu.addItem(withTitle: tr("Copy Current Full File path"), action: #selector(menuCopyFullPath), keyEquivalent: "")
        copyClipMenu.addItem(withTitle: tr("Copy Current Filename"), action: #selector(menuCopyFilename), keyEquivalent: "")
        copyClipMenu.addItem(withTitle: tr("Copy Current Dir. Path"), action: #selector(menuCopyDirPath), keyEquivalent: "")
        copyClipMenu.addItem(withTitle: tr("Copy All Filenames"), action: #selector(menuCopyAllFilenames), keyEquivalent: "")
        copyClipMenu.addItem(withTitle: tr("Copy All File Paths"), action: #selector(menuCopyAllFilePaths), keyEquivalent: "")
        let copyClipItem = NSMenuItem(title: tr("Copy to Clipboard"), action: nil, keyEquivalent: "")
        copyClipItem.submenu = copyClipMenu
        editMenu.addItem(copyClipItem)

        // Indent submenu (Notepad_plus.rc L515-518)
        let indentMenu = NSMenu(title: tr("Indent"))
        indentMenu.addItem(withTitle: tr("Increase Line Indent"), action: #selector(menuIncreaseLineIndent), keyEquivalent: "]")
        indentMenu.addItem(withTitle: tr("Decrease Line Indent"), action: #selector(menuDecreaseLineIndent), keyEquivalent: "[")
        let indentItem = NSMenuItem(title: tr("Indent"), action: nil, keyEquivalent: "")
        indentItem.submenu = indentMenu
        editMenu.addItem(indentItem)

        // Convert Case to submenu
        let caseMenu = NSMenu(title: tr("Convert Case to"))
        caseMenu.addItem(withTitle: tr("UPPERCASE"), action: #selector(menuUppercase), keyEquivalent: "U")
        caseMenu.addItem(withTitle: tr("lowercase"), action: #selector(menuLowercase), keyEquivalent: "u")
        caseMenu.addItem(withTitle: tr("Proper Case"), action: #selector(menuProperCase), keyEquivalent: "")
        caseMenu.addItem(withTitle: tr("Proper Case (blend)"), action: #selector(menuProperCaseBlend), keyEquivalent: "")
        caseMenu.addItem(withTitle: tr("Sentence case"), action: #selector(menuSentenceCase), keyEquivalent: "")
        caseMenu.addItem(withTitle: tr("Sentence case (blend)"), action: #selector(menuSentenceCaseBlend), keyEquivalent: "")
        caseMenu.addItem(withTitle: tr("iNVERT cASE"), action: #selector(menuInvertCase), keyEquivalent: "")
        caseMenu.addItem(withTitle: tr("ranDOm CasE"), action: #selector(menuRandomCase), keyEquivalent: "")
        let caseItem = NSMenuItem(title: tr("Convert Case to"), action: nil, keyEquivalent: "")
        caseItem.submenu = caseMenu
        editMenu.addItem(caseItem)

        // Line Operations submenu
        let lineOpsMenu = NSMenu(title: tr("Line Operations"))
        lineOpsMenu.addItem(withTitle: tr("Duplicate Current Line"), action: #selector(menuDupLine), keyEquivalent: "d")
        lineOpsMenu.addItem(withTitle: tr("Remove Duplicate Lines"), action: #selector(menuRemoveDuplicateLines), keyEquivalent: "")
        lineOpsMenu.addItem(withTitle: tr("Remove Consecutive Duplicate Lines"), action: #selector(menuRemoveConsecutiveDuplicateLines), keyEquivalent: "")
        lineOpsMenu.addItem(withTitle: tr("Split Lines"), action: #selector(menuSplitLines), keyEquivalent: "")
        lineOpsMenu.addItem(withTitle: tr("Join Lines"), action: #selector(menuJoinLines), keyEquivalent: "j")
        lineOpsMenu.addItem(withTitle: tr("Move Up Current Line"), action: #selector(menuMoveLineUp), keyEquivalent: "")
        lineOpsMenu.addItem(withTitle: tr("Move Down Current Line"), action: #selector(menuMoveLineDown), keyEquivalent: "")
        lineOpsMenu.addItem(NSMenuItem.separator())
        lineOpsMenu.addItem(withTitle: tr("Insert Empty Line Above Current"), action: #selector(menuInsertEmptyLineAbove), keyEquivalent: "")
        lineOpsMenu.addItem(withTitle: tr("Insert Empty Line Below Current"), action: #selector(menuInsertEmptyLineBelow), keyEquivalent: "")
        lineOpsMenu.addItem(NSMenuItem.separator())
        lineOpsMenu.addItem(withTitle: tr("Remove Empty Lines"), action: #selector(menuRemoveEmptyLines), keyEquivalent: "")
        lineOpsMenu.addItem(withTitle: tr("Remove Empty Lines (Containing Blank characters)"), action: #selector(menuRemoveEmptyLinesContainingBlanks), keyEquivalent: "")
        lineOpsMenu.addItem(NSMenuItem.separator())
        lineOpsMenu.addItem(withTitle: tr("Reverse Line Order"), action: #selector(menuReverseLines), keyEquivalent: "")
        lineOpsMenu.addItem(withTitle: tr("Randomize Line Order"), action: #selector(menuRandomizeLineOrder), keyEquivalent: "")
        lineOpsMenu.addItem(withTitle: tr("Sort Lines Lexicographically Ascending"), action: #selector(menuSortAscending), keyEquivalent: "")
        lineOpsMenu.addItem(withTitle: tr("Sort Lines Lexicographically Descending"), action: #selector(menuSortDescending), keyEquivalent: "")
        lineOpsMenu.addItem(withTitle: tr("Sort Lines Lex. Ascending Ignoring Case"), action: #selector(menuSortCaseInsensitiveAscending), keyEquivalent: "")
        lineOpsMenu.addItem(withTitle: tr("Sort Lines Lex. Descending Ignoring Case"), action: #selector(menuSortCaseInsensitiveDescending), keyEquivalent: "")
        lineOpsMenu.addItem(withTitle: tr("Sort Lines as Integers Ascending"), action: #selector(menuSortIntegersAscending), keyEquivalent: "")
        lineOpsMenu.addItem(withTitle: tr("Sort Lines as Integers Descending"), action: #selector(menuSortIntegersDescending), keyEquivalent: "")
        lineOpsMenu.addItem(withTitle: tr("Sort Lines as Decimals (Dot) Ascending"), action: #selector(menuSortDecimalsDotAscending), keyEquivalent: "")
        lineOpsMenu.addItem(withTitle: tr("Sort Lines as Decimals (Dot) Descending"), action: #selector(menuSortDecimalsDotDescending), keyEquivalent: "")
        lineOpsMenu.addItem(withTitle: tr("Sort Lines as Decimals (Comma) Ascending"), action: #selector(menuSortDecimalsCommaAscending), keyEquivalent: "")
        lineOpsMenu.addItem(withTitle: tr("Sort Lines as Decimals (Comma) Descending"), action: #selector(menuSortDecimalsCommaDescending), keyEquivalent: "")
        lineOpsMenu.addItem(withTitle: tr("Sort Lines By Length Ascending"), action: #selector(menuSortByLengthAscending), keyEquivalent: "")
        lineOpsMenu.addItem(withTitle: tr("Sort Lines By Length Descending"), action: #selector(menuSortByLengthDescending), keyEquivalent: "")
        let lineOpsItem = NSMenuItem(title: tr("Line Operations"), action: nil, keyEquivalent: "")
        lineOpsItem.submenu = lineOpsMenu
        editMenu.addItem(lineOpsItem)

        // Comment / Uncomment submenu (Notepad_plus.rc L562-569)
        let commentMenu = NSMenu(title: tr("Comment/Uncomment"))
        commentMenu.addItem(withTitle: tr("Toggle Single Line Comment"), action: #selector(menuToggleComment), keyEquivalent: "/")
        commentMenu.addItem(withTitle: tr("Single Line Comment"), action: #selector(menuSingleLineComment), keyEquivalent: "k")
        let itemUncomment = NSMenuItem(title: tr("Single Line Uncomment"), action: #selector(menuSingleLineUncomment), keyEquivalent: "K")
        itemUncomment.keyEquivalentModifierMask = [.command, .shift]
        commentMenu.addItem(itemUncomment)
        let itemBlockComment = NSMenuItem(title: tr("Block Comment"), action: #selector(menuBlockComment), keyEquivalent: "Q")
        itemBlockComment.keyEquivalentModifierMask = [.command, .shift]
        commentMenu.addItem(itemBlockComment)
        commentMenu.addItem(withTitle: tr("Block Uncomment"), action: #selector(menuBlockUncomment), keyEquivalent: "")
        let commentItem = NSMenuItem(title: tr("Comment/Uncomment"), action: nil, keyEquivalent: "")
        commentItem.submenu = commentMenu
        editMenu.addItem(commentItem)

        // Blank Operations submenu
        let blankOpsMenu = NSMenu(title: tr("Blank Operations"))
        blankOpsMenu.addItem(withTitle: tr("Trim Trailing Space"), action: #selector(menuTrimTrailing), keyEquivalent: "")
        blankOpsMenu.addItem(withTitle: tr("Trim Leading Space"), action: #selector(menuTrimLeading), keyEquivalent: "")
        blankOpsMenu.addItem(withTitle: tr("Trim Leading and Trailing Space"), action: #selector(menuTrimBoth), keyEquivalent: "")
        blankOpsMenu.addItem(withTitle: tr("EOL to Space"), action: #selector(menuEolToSpace), keyEquivalent: "")
        blankOpsMenu.addItem(withTitle: tr("Trim both and EOL to Space"), action: #selector(menuTrimBothAndEolToSpace), keyEquivalent: "")
        blankOpsMenu.addItem(withTitle: tr("TAB to Space"), action: #selector(menuTabToSpace), keyEquivalent: "")
        blankOpsMenu.addItem(withTitle: tr("Space to TAB (All)"), action: #selector(menuSpaceToTabAll), keyEquivalent: "")
        blankOpsMenu.addItem(withTitle: tr("Space to TAB (Leading)"), action: #selector(menuSpaceToTabLeading), keyEquivalent: "")
        let blankOpsItem = NSMenuItem(title: tr("Blank Operations"), action: nil, keyEquivalent: "")
        blankOpsItem.submenu = blankOpsMenu
        editMenu.addItem(blankOpsItem)

        // EOL Conversion Submenu
        let eolMenu = NSMenu(title: tr("EOL Conversion"))
        eolMenu.addItem(withTitle: tr("Windows (CR LF)"), action: #selector(menuEolWindows), keyEquivalent: "")
        eolMenu.addItem(withTitle: tr("Unix (LF)"), action: #selector(menuEolUnix), keyEquivalent: "")
        eolMenu.addItem(withTitle: tr("Macintosh (CR)"), action: #selector(menuEolMac), keyEquivalent: "")
        let eolMenuItem = NSMenuItem(title: tr("EOL Conversion"), action: nil, keyEquivalent: "")
        eolMenuItem.submenu = eolMenu
        editMenu.addItem(eolMenuItem)

        editMenu.addItem(NSMenuItem.separator())

        // On Selection Submenu (Notepad_plus.rc L606-615)
        let onSelectionMenu = NSMenu(title: tr("On Selection"))
        onSelectionMenu.addItem(withTitle: tr("Open File"), action: #selector(menuOpenSelectedFile), keyEquivalent: "")
        onSelectionMenu.addItem(withTitle: tr("Open Containing Folder in Finder"), action: #selector(menuOpenSelectedFolderInFinder), keyEquivalent: "")
        onSelectionMenu.addItem(NSMenuItem.separator())
        onSelectionMenu.addItem(withTitle: tr("Redact Selection █ (Shift: ●)"), action: #selector(menuRedactSelection), keyEquivalent: "")
        onSelectionMenu.addItem(NSMenuItem.separator())
        onSelectionMenu.addItem(withTitle: tr("Search on Internet"), action: #selector(menuSearchOnInternet), keyEquivalent: "")
        onSelectionMenu.addItem(withTitle: tr("Change Search Engine..."), action: #selector(menuChangeSearchEngine), keyEquivalent: "")
        let onSelectionItem = NSMenuItem(title: tr("On Selection"), action: nil, keyEquivalent: "")
        onSelectionItem.submenu = onSelectionMenu
        editMenu.addItem(onSelectionItem)

        editMenu.addItem(NSMenuItem.separator())
        let colEditItem = NSMenuItem(title: tr("Column Editor..."), action: #selector(menuColumnEditor), keyEquivalent: "c")
        colEditItem.keyEquivalentModifierMask = [.option]
        editMenu.addItem(colEditItem)

        // Side Panels in Edit Menu (Notepad_plus.rc L636-637)
        editMenu.addItem(withTitle: tr("Character Panel"), action: #selector(menuToggleCharacterPanel), keyEquivalent: "")
        editMenu.addItem(withTitle: tr("Clipboard History"), action: #selector(menuToggleClipboardHistory), keyEquivalent: "")

        editMenu.addItem(NSMenuItem.separator())

        // Read-Only in Notepad++ Submenu (Notepad_plus.rc L639-644)
        let readOnlyMenu = NSMenu(title: tr("Read-Only in Notepad++"))
        readOnlyMenu.addItem(withTitle: tr("Read-Only on Current Document"), action: #selector(menuToggleReadOnlyCurrentDoc), keyEquivalent: "")
        readOnlyMenu.addItem(withTitle: tr("Read-Only for All Documents"), action: #selector(menuSetReadOnlyAllDocs), keyEquivalent: "")
        readOnlyMenu.addItem(withTitle: tr("Clear Read-Only for All Documents"), action: #selector(menuClearReadOnlyAllDocs), keyEquivalent: "")
        let readOnlyItem = NSMenuItem(title: tr("Read-Only in Notepad++"), action: nil, keyEquivalent: "")
        readOnlyItem.submenu = readOnlyMenu
        editMenu.addItem(readOnlyItem)

        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        // 4. Search Menu (Notepad++ Windows parity per Notepad_plus.rc L648-744)
        let f2Key = String(UnicodeScalar(NSF2FunctionKey)!)
        let f3Key = String(UnicodeScalar(NSF3FunctionKey)!)
        let f4Key = String(UnicodeScalar(NSF4FunctionKey)!)
        let f7Key = String(UnicodeScalar(NSF7FunctionKey)!)

        let searchMenuItem = NSMenuItem()
        let searchMenu = NSMenu(title: tr("Search"))
        searchMenu.addItem(withTitle: tr("Find..."), action: #selector(menuFind), keyEquivalent: "f")
        let fifItem = NSMenuItem(title: tr("Find in Files..."), action: #selector(menuFindInFiles), keyEquivalent: "F")
        fifItem.keyEquivalentModifierMask = [.command, .shift]
        searchMenu.addItem(fifItem)

        let findNextItem = NSMenuItem(title: tr("Find Next"), action: #selector(menuFindNext), keyEquivalent: f3Key)
        findNextItem.keyEquivalentModifierMask = []
        searchMenu.addItem(findNextItem)

        let findPrevItem = NSMenuItem(title: tr("Find Previous"), action: #selector(menuFindPrev), keyEquivalent: f3Key)
        findPrevItem.keyEquivalentModifierMask = [.shift]
        searchMenu.addItem(findPrevItem)

        let selFindNextItem = NSMenuItem(title: tr("Select and Find Next"), action: #selector(menuSelectAndFindNext), keyEquivalent: f3Key)
        selFindNextItem.keyEquivalentModifierMask = [.command]
        searchMenu.addItem(selFindNextItem)

        let selFindPrevItem = NSMenuItem(title: tr("Select and Find Previous"), action: #selector(menuSelectAndFindPrev), keyEquivalent: f3Key)
        selFindPrevItem.keyEquivalentModifierMask = [.command, .shift]
        searchMenu.addItem(selFindPrevItem)

        let volFindNextItem = NSMenuItem(title: tr("Find (Volatile) Next"), action: #selector(menuSelectAndFindNext), keyEquivalent: f3Key)
        volFindNextItem.keyEquivalentModifierMask = [.command, .option]
        searchMenu.addItem(volFindNextItem)

        let volFindPrevItem = NSMenuItem(title: tr("Find (Volatile) Previous"), action: #selector(menuSelectAndFindPrev), keyEquivalent: f3Key)
        volFindPrevItem.keyEquivalentModifierMask = [.command, .option, .shift]
        searchMenu.addItem(volFindPrevItem)

        searchMenu.addItem(withTitle: tr("Replace..."), action: #selector(menuReplace), keyEquivalent: "h")

        let incSearchItem = NSMenuItem(title: tr("Incremental Search"), action: #selector(menuIncrementalSearch), keyEquivalent: "i")
        incSearchItem.keyEquivalentModifierMask = [.command, .option]
        searchMenu.addItem(incSearchItem)

        let searchResultsWinItem = NSMenuItem(title: tr("Search Results Window"), action: #selector(menuSearchResultsWindow), keyEquivalent: f7Key)
        searchResultsWinItem.keyEquivalentModifierMask = []
        searchMenu.addItem(searchResultsWinItem)

        let nextSearchResItem = NSMenuItem(title: tr("Next Search Result"), action: #selector(menuNextSearchResult), keyEquivalent: f4Key)
        nextSearchResItem.keyEquivalentModifierMask = []
        searchMenu.addItem(nextSearchResItem)

        let prevSearchResItem = NSMenuItem(title: tr("Previous Search Result"), action: #selector(menuPrevSearchResult), keyEquivalent: f4Key)
        prevSearchResItem.keyEquivalentModifierMask = [.shift]
        searchMenu.addItem(prevSearchResItem)

        searchMenu.addItem(NSMenuItem.separator())
        searchMenu.addItem(withTitle: tr("Go to Line..."), action: #selector(menuGoToLine), keyEquivalent: "l")
        searchMenu.addItem(withTitle: tr("Go to Matching Brace"), action: #selector(menuGoToMatchingBrace), keyEquivalent: "b")
        let selBracesItem = NSMenuItem(title: tr("Select All In-between {} [] or ()"), action: #selector(menuSelectAllBetweenBraces), keyEquivalent: "b")
        selBracesItem.keyEquivalentModifierMask = [.command, .option]
        searchMenu.addItem(selBracesItem)

        searchMenu.addItem(NSMenuItem.separator())
        searchMenu.addItem(withTitle: tr("Mark..."), action: #selector(menuMark), keyEquivalent: "m")

        // Style All Occurrences of Token submenu (IDM_SEARCH_MARKALLEXT1..5)
        let styleNames = ["Using 1st Style", "Using 2nd Style", "Using 3rd Style", "Using 4th Style", "Using 5th Style"]
        let styleAllMenu = NSMenu(title: tr("Style All Occurrences of Token"))
        for (idx, titleKey) in styleNames.enumerated() {
            let item = NSMenuItem(title: tr(titleKey), action: #selector(menuStyleAllToken(_:)), keyEquivalent: "")
            item.tag = idx + 1
            styleAllMenu.addItem(item)
        }
        let styleAllItem = NSMenuItem(title: tr("Style All Occurrences of Token"), action: nil, keyEquivalent: "")
        styleAllItem.submenu = styleAllMenu
        searchMenu.addItem(styleAllItem)

        // Style One Token submenu (IDM_SEARCH_MARKONEEXT1..5)
        let styleOneMenu = NSMenu(title: tr("Style One Token"))
        for (idx, titleKey) in styleNames.enumerated() {
            let item = NSMenuItem(title: tr(titleKey), action: #selector(menuStyleOneToken(_:)), keyEquivalent: "")
            item.tag = idx + 1
            styleOneMenu.addItem(item)
        }
        let styleOneItem = NSMenuItem(title: tr("Style One Token"), action: nil, keyEquivalent: "")
        styleOneItem.submenu = styleOneMenu
        searchMenu.addItem(styleOneItem)

        // Clear Style submenu (IDM_SEARCH_UNMARKALLEXT1..5, IDM_SEARCH_CLEARALLMARKS)
        let clearNames = ["Clear 1st Style", "Clear 2nd Style", "Clear 3rd Style", "Clear 4th Style", "Clear 5th Style"]
        let clearStyleMenu = NSMenu(title: tr("Clear Style"))
        for (idx, titleKey) in clearNames.enumerated() {
            let item = NSMenuItem(title: tr(titleKey), action: #selector(menuClearTokenStyle(_:)), keyEquivalent: "")
            item.tag = idx + 1
            clearStyleMenu.addItem(item)
        }
        clearStyleMenu.addItem(NSMenuItem.separator())
        clearStyleMenu.addItem(withTitle: tr("Clear all Styles"), action: #selector(menuClearAllTokenStyles), keyEquivalent: "")
        let clearStyleItem = NSMenuItem(title: tr("Clear Style"), action: nil, keyEquivalent: "")
        clearStyleItem.submenu = clearStyleMenu
        searchMenu.addItem(clearStyleItem)

        searchMenu.addItem(NSMenuItem.separator())
        searchMenu.addItem(withTitle: tr("Find All in Current Document"), action: #selector(menuFindAllCurrent), keyEquivalent: "")
        searchMenu.addItem(withTitle: tr("Find All in All Opened Documents"), action: #selector(menuFindAllOpened), keyEquivalent: "")
        searchMenu.addItem(withTitle: tr("Clear Search Results"), action: #selector(menuClearSearchResults), keyEquivalent: "")

        searchMenu.addItem(NSMenuItem.separator())

        // Bookmark submenu (Official Notepad++ Parity)
        let bookmarkMenu = NSMenu(title: tr("Bookmark"))
        let toggleBmItem = NSMenuItem(title: tr("Toggle Bookmark"), action: #selector(menuToggleBookmark), keyEquivalent: f2Key)
        toggleBmItem.keyEquivalentModifierMask = [.command]
        bookmarkMenu.addItem(toggleBmItem)

        let nextBmItem = NSMenuItem(title: tr("Next Bookmark"), action: #selector(menuNextBookmark), keyEquivalent: f2Key)
        nextBmItem.keyEquivalentModifierMask = []
        bookmarkMenu.addItem(nextBmItem)

        let prevBmItem = NSMenuItem(title: tr("Previous Bookmark"), action: #selector(menuPrevBookmark), keyEquivalent: f2Key)
        prevBmItem.keyEquivalentModifierMask = [.shift]
        bookmarkMenu.addItem(prevBmItem)

        bookmarkMenu.addItem(withTitle: tr("Clear All Bookmarks"), action: #selector(menuClearAllBookmarks), keyEquivalent: "")
        bookmarkMenu.addItem(NSMenuItem.separator())
        bookmarkMenu.addItem(withTitle: tr("Cut Bookmarked Lines"), action: #selector(menuCutBookmarkedLines), keyEquivalent: "")
        bookmarkMenu.addItem(withTitle: tr("Copy Bookmarked Lines"), action: #selector(menuCopyBookmarkedLines), keyEquivalent: "")
        bookmarkMenu.addItem(withTitle: tr("Paste to (Replace) Bookmarked Lines"), action: #selector(menuPasteBookmarkedLines), keyEquivalent: "")
        bookmarkMenu.addItem(withTitle: tr("Remove Bookmarked Lines"), action: #selector(menuRemoveBookmarkedLines), keyEquivalent: "")
        bookmarkMenu.addItem(withTitle: tr("Remove Non-Bookmarked Lines"), action: #selector(menuRemoveNonBookmarkedLines), keyEquivalent: "")
        bookmarkMenu.addItem(withTitle: tr("Inverse Bookmarks"), action: #selector(menuInverseBookmarks), keyEquivalent: "")

        let bookmarkMenuItem = NSMenuItem(title: tr("Bookmark"), action: nil, keyEquivalent: "")
        bookmarkMenuItem.submenu = bookmarkMenu
        searchMenu.addItem(bookmarkMenuItem)

        searchMenu.addItem(NSMenuItem.separator())
        searchMenu.addItem(withTitle: tr("Find characters in range..."), action: #selector(menuFindCharsInRange), keyEquivalent: "")

        searchMenuItem.submenu = searchMenu
        mainMenu.addItem(searchMenuItem)

        // 5. View Menu (Notepad++ Windows parity per Notepad_plus.rc L746-880)
        let viewMenuItem = NSMenuItem()
        let viewMenu = NSMenu(title: tr("View"))
        viewMenu.addItem(withTitle: tr("Always on Top"), action: #selector(menuToggleAlwaysOnTop(_:)), keyEquivalent: "")
        let fsItem = viewMenu.addItem(withTitle: tr("Toggle Full Screen Mode"), action: #selector(menuToggleFullScreen), keyEquivalent: String(UnicodeScalar(NSF11FunctionKey)!))
        fsItem.keyEquivalentModifierMask = []
        let piItem = viewMenu.addItem(withTitle: tr("Post-It"), action: #selector(menuTogglePostIt), keyEquivalent: String(UnicodeScalar(NSF12FunctionKey)!))
        piItem.keyEquivalentModifierMask = []
        viewMenu.addItem(withTitle: tr("Distraction Free Mode"), action: #selector(menuToggleDistractionFree), keyEquivalent: "")
        viewMenu.addItem(NSMenuItem.separator())

        // Show Symbol submenu (Notepad_plus.rc L768-776)
        let showSymbolMenu = NSMenu(title: tr("Show Symbol"))
        showSymbolMenu.addItem(withTitle: tr("Show Space and Tab"), action: #selector(menuToggleShowSpaceAndTab), keyEquivalent: "")
        showSymbolMenu.addItem(withTitle: tr("Show End of Line"), action: #selector(menuToggleShowEndOfLine), keyEquivalent: "")
        showSymbolMenu.addItem(withTitle: tr("Show Non-Printing Characters"), action: #selector(menuToggleShowNonPrintingCharacters), keyEquivalent: "")
        showSymbolMenu.addItem(withTitle: tr("Show Control Characters & Unicode EOL"), action: #selector(menuToggleShowControlCharsAndUnicodeEol), keyEquivalent: "")
        showSymbolMenu.addItem(withTitle: tr("Show All Characters"), action: #selector(menuToggleShowAllCharacters), keyEquivalent: "")
        showSymbolMenu.addItem(NSMenuItem.separator())
        showSymbolMenu.addItem(withTitle: tr("Show Indent Guide"), action: #selector(menuToggleShowIndentGuide), keyEquivalent: "")
        showSymbolMenu.addItem(withTitle: tr("Show Wrap Symbol"), action: #selector(menuToggleShowWrapSymbol), keyEquivalent: "")
        let showSymbolItem = NSMenuItem(title: tr("Show Symbol"), action: nil, keyEquivalent: "")
        showSymbolItem.submenu = showSymbolMenu
        viewMenu.addItem(showSymbolItem)

        // Zoom submenu + direct items
        let zoomMenu = NSMenu(title: tr("Zoom"))
        zoomMenu.addItem(withTitle: tr("Zoom In"), action: #selector(menuZoomIn), keyEquivalent: "=")
        zoomMenu.addItem(withTitle: tr("Zoom Out"), action: #selector(menuZoomOut), keyEquivalent: "-")
        zoomMenu.addItem(withTitle: tr("Restore Default Zoom"), action: #selector(menuResetZoom), keyEquivalent: "0")
        let zoomItem = NSMenuItem(title: tr("Zoom"), action: nil, keyEquivalent: "")
        zoomItem.submenu = zoomMenu
        viewMenu.addItem(zoomItem)

        // Tab submenu (Notepad_plus.rc L794-821)
        let tabSubMenu = NSMenu(title: tr("Tab"))
        let tabOrdinals = ["1st Tab", "2nd Tab", "3rd Tab", "4th Tab", "5th Tab", "6th Tab", "7th Tab", "8th Tab", "9th Tab"]
        for (idx, ordTitle) in tabOrdinals.enumerated() {
            let tItem = NSMenuItem(title: tr(ordTitle), action: #selector(menuSelectTabByIndex(_:)), keyEquivalent: "\(idx + 1)")
            tItem.keyEquivalentModifierMask = [.command]
            tItem.tag = idx
            tabSubMenu.addItem(tItem)
        }
        tabSubMenu.addItem(NSMenuItem.separator())
        tabSubMenu.addItem(withTitle: tr("First Tab"), action: #selector(menuFirstTab), keyEquivalent: "")
        tabSubMenu.addItem(withTitle: tr("Last Tab"), action: #selector(menuLastTab), keyEquivalent: "")
        tabSubMenu.addItem(withTitle: tr("Next Tab"), action: #selector(menuNextTab), keyEquivalent: "")
        tabSubMenu.addItem(withTitle: tr("Previous Tab"), action: #selector(menuPrevTab), keyEquivalent: "")
        tabSubMenu.addItem(NSMenuItem.separator())
        tabSubMenu.addItem(withTitle: tr("Move Tab Forward"), action: #selector(menuMoveTabForward), keyEquivalent: "")
        tabSubMenu.addItem(withTitle: tr("Move Tab Backward"), action: #selector(menuMoveTabBackward), keyEquivalent: "")
        tabSubMenu.addItem(NSMenuItem.separator())
        for colorId in 1...5 {
            let cItem = NSMenuItem(title: tr("Apply Color \(colorId)"), action: #selector(menuApplyTabColor(_:)), keyEquivalent: "")
            cItem.tag = colorId
            tabSubMenu.addItem(cItem)
        }
        let rmColorItem = NSMenuItem(title: tr("Remove Color"), action: #selector(menuApplyTabColor(_:)), keyEquivalent: "")
        rmColorItem.tag = 0
        tabSubMenu.addItem(rmColorItem)
        let tabSubItem = NSMenuItem(title: tr("Tab"), action: nil, keyEquivalent: "")
        tabSubItem.submenu = tabSubMenu
        viewMenu.addItem(tabSubItem)

        viewMenu.addItem(withTitle: tr("Toggle Word Wrap"), action: #selector(menuToggleWordWrap), keyEquivalent: "")
        viewMenu.addItem(NSMenuItem.separator())
        viewMenu.addItem(withTitle: tr("Document List"), action: #selector(menuToggleDocumentList), keyEquivalent: "")
        viewMenu.addItem(withTitle: tr("Folder as Workspace"), action: #selector(menuToggleFolderAsWorkspace), keyEquivalent: "")
        viewMenu.addItem(withTitle: tr("Function List"), action: #selector(menuToggleFunctionList), keyEquivalent: "")
        viewMenu.addItem(withTitle: tr("Document Map"), action: #selector(menuToggleDocumentMap), keyEquivalent: "")
        viewMenu.addItem(NSMenuItem.separator())
        viewMenu.addItem(withTitle: tr("Summary..."), action: #selector(menuDocSummary), keyEquivalent: "")
        viewMenu.addItem(withTitle: tr("Monitoring (tail -f)"), action: #selector(menuToggleMonitoring), keyEquivalent: "")
        viewMenuItem.submenu = viewMenu
        mainMenu.addItem(viewMenuItem)

        // 6. Encoding Menu (Notepad++ Windows parity)
        let encMenuItem = NSMenuItem()
        let encMenu = NSMenu(title: tr("Encoding"))
        encMenu.addItem(withTitle: "ANSI", action: #selector(menuEncodeAnsi), keyEquivalent: "")
        encMenu.addItem(withTitle: "UTF-8", action: #selector(menuEncodeUtf8), keyEquivalent: "")
        encMenu.addItem(withTitle: "UTF-8-BOM", action: #selector(menuEncodeUtf8Bom), keyEquivalent: "")
        encMenu.addItem(withTitle: "UTF-16 BE BOM", action: #selector(menuEncodeUtf16BE), keyEquivalent: "")
        encMenu.addItem(withTitle: "UTF-16 LE BOM", action: #selector(menuEncodeUtf16LE), keyEquivalent: "")

        let charSetsMenu = NSMenu(title: tr("Character sets"))
        let koreanMenu = NSMenu(title: tr("Korean"))
        koreanMenu.addItem(withTitle: "Windows 949 (CP949)", action: #selector(menuEncodeCP949), keyEquivalent: "")
        koreanMenu.addItem(withTitle: "EUC-KR", action: #selector(menuEncodeEucKr), keyEquivalent: "")
        let koreanItem = NSMenuItem(title: tr("Korean"), action: nil, keyEquivalent: "")
        koreanItem.submenu = koreanMenu
        charSetsMenu.addItem(koreanItem)

        let japaneseMenu = NSMenu(title: tr("Japanese"))
        japaneseMenu.addItem(withTitle: "Shift-JIS", action: #selector(menuEncodeShiftJis), keyEquivalent: "")
        let japaneseItem = NSMenuItem(title: tr("Japanese"), action: nil, keyEquivalent: "")
        japaneseItem.submenu = japaneseMenu
        charSetsMenu.addItem(japaneseItem)

        let chineseMenu = NSMenu(title: tr("Chinese"))
        chineseMenu.addItem(withTitle: "GB2312 (Simplified)", action: #selector(menuEncodeGB18030), keyEquivalent: "")
        chineseMenu.addItem(withTitle: "Big5 (Traditional)", action: #selector(menuEncodeBig5), keyEquivalent: "")
        let chineseItem = NSMenuItem(title: tr("Chinese"), action: nil, keyEquivalent: "")
        chineseItem.submenu = chineseMenu
        charSetsMenu.addItem(chineseItem)

        let charSetsItem = NSMenuItem(title: tr("Character sets"), action: nil, keyEquivalent: "")
        charSetsItem.submenu = charSetsMenu
        encMenu.addItem(charSetsItem)

        encMenu.addItem(NSMenuItem.separator())
        encMenu.addItem(withTitle: tr("Convert to ANSI"), action: #selector(menuConvertAnsi), keyEquivalent: "")
        encMenu.addItem(withTitle: tr("Convert to UTF-8"), action: #selector(menuConvertUtf8), keyEquivalent: "")
        encMenu.addItem(withTitle: tr("Convert to UTF-8-BOM"), action: #selector(menuConvertUtf8Bom), keyEquivalent: "")
        encMenu.addItem(withTitle: tr("Convert to Korean (Windows 949 / CP949)"), action: #selector(menuConvertCP949), keyEquivalent: "")
        encMenu.addItem(withTitle: tr("Convert to Korean (EUC-KR)"), action: #selector(menuConvertEucKr), keyEquivalent: "")

        encMenuItem.submenu = encMenu
        mainMenu.addItem(encMenuItem)

        // 7. Language Menu (Notepad++ Windows parity, filtered by workspace.disabledLanguages)
        let langMenuItem = NSMenuItem()
        let langMenu = NSMenu(title: tr("Language"))
        langMenu.addItem(withTitle: tr("None (Normal Text)"), action: #selector(menuSetLangPlainText), keyEquivalent: "")
        langMenu.addItem(NSMenuItem.separator())

        let popularLangs = ["C", "C++", "C#", "Swift", "Python", "JavaScript", "TypeScript", "HTML", "CSS", "JSON", "XML", "SQL", "Shell", "Markdown", "Java", "Rust", "Go", "PHP", "Ruby", "YAML"]
        let disabledSet = Set(workspace.disabledLanguages.map { $0.lowercased() })
        for lang in popularLangs {
            if disabledSet.contains(lang.lowercased()) { continue }
            let item = NSMenuItem(title: lang, action: #selector(menuSelectLanguage(_:)), keyEquivalent: "")
            item.representedObject = lang
            langMenu.addItem(item)
        }

        langMenuItem.submenu = langMenu
        mainMenu.addItem(langMenuItem)

        // 8. Settings Menu (Notepad++ Windows parity)
        let settingsMenuItem = NSMenuItem()
        let settingsMenu = NSMenu(title: tr("Settings"))
        settingsMenu.addItem(withTitle: tr("Preferences..."), action: #selector(menuPreferences), keyEquivalent: "")
        settingsMenu.addItem(withTitle: tr("Style Configurator..."), action: #selector(menuStyleConfigurator), keyEquivalent: "")
        settingsMenu.addItem(withTitle: tr("Shortcut Mapper..."), action: #selector(menuShortcutMapper), keyEquivalent: "")
        settingsMenu.addItem(NSMenuItem.separator())
        settingsMenu.addItem(withTitle: tr("Edit Popup ContextMenu"), action: #selector(menuEditContextMenu), keyEquivalent: "")
        settingsMenuItem.submenu = settingsMenu
        mainMenu.addItem(settingsMenuItem)

        // 9. Tools Menu (Notepad++ Windows parity per Notepad_plus.rc L1281-1307)
        let toolsMenuItem = NSMenuItem()
        let toolsMenu = NSMenu(title: tr("Tools"))

        // MD5
        let md5Menu = NSMenu(title: "MD5")
        md5Menu.addItem(withTitle: tr("Generate..."), action: #selector(menuMD5Generate), keyEquivalent: "")
        md5Menu.addItem(withTitle: tr("Generate from files..."), action: #selector(menuMD5FromFiles), keyEquivalent: "")
        md5Menu.addItem(withTitle: tr("Generate from Selection into Clipboard"), action: #selector(menuMD5Selection), keyEquivalent: "")
        let md5Item = NSMenuItem(title: "MD5", action: nil, keyEquivalent: "")
        md5Item.submenu = md5Menu
        toolsMenu.addItem(md5Item)

        // SHA-1
        let sha1Menu = NSMenu(title: "SHA-1")
        sha1Menu.addItem(withTitle: tr("Generate..."), action: #selector(menuSHA1Generate), keyEquivalent: "")
        sha1Menu.addItem(withTitle: tr("Generate from files..."), action: #selector(menuSHA1FromFiles), keyEquivalent: "")
        sha1Menu.addItem(withTitle: tr("Generate from Selection into Clipboard"), action: #selector(menuSHA1Selection), keyEquivalent: "")
        let sha1Item = NSMenuItem(title: "SHA-1", action: nil, keyEquivalent: "")
        sha1Item.submenu = sha1Menu
        toolsMenu.addItem(sha1Item)

        // SHA-256
        let shaMenu = NSMenu(title: "SHA-256")
        shaMenu.addItem(withTitle: tr("Generate..."), action: #selector(menuSHA256Generate), keyEquivalent: "")
        shaMenu.addItem(withTitle: tr("Generate from files..."), action: #selector(menuSHA256FromFiles), keyEquivalent: "")
        shaMenu.addItem(withTitle: tr("Generate from Selection into Clipboard"), action: #selector(menuSHA256Selection), keyEquivalent: "")
        let shaItem = NSMenuItem(title: "SHA-256", action: nil, keyEquivalent: "")
        shaItem.submenu = shaMenu
        toolsMenu.addItem(shaItem)

        // SHA-512
        let sha512Menu = NSMenu(title: "SHA-512")
        sha512Menu.addItem(withTitle: tr("Generate..."), action: #selector(menuSHA512Generate), keyEquivalent: "")
        sha512Menu.addItem(withTitle: tr("Generate from files..."), action: #selector(menuSHA512FromFiles), keyEquivalent: "")
        sha512Menu.addItem(withTitle: tr("Generate from Selection into Clipboard"), action: #selector(menuSHA512Selection), keyEquivalent: "")
        let sha512Item = NSMenuItem(title: "SHA-512", action: nil, keyEquivalent: "")
        sha512Item.submenu = sha512Menu
        toolsMenu.addItem(sha512Item)

        toolsMenu.addItem(NSMenuItem.separator())
        toolsMenu.addItem(withTitle: tr("Base64 Encode"), action: #selector(menuBase64Encode), keyEquivalent: "")
        toolsMenu.addItem(withTitle: tr("Base64 Decode"), action: #selector(menuBase64Decode), keyEquivalent: "")
        toolsMenu.addItem(withTitle: tr("URL Encode"), action: #selector(menuUrlEncode), keyEquivalent: "")
        toolsMenu.addItem(withTitle: tr("URL Decode"), action: #selector(menuUrlDecode), keyEquivalent: "")

        toolsMenuItem.submenu = toolsMenu
        mainMenu.addItem(toolsMenuItem)

        // 10. Macro Menu (Notepad_plus.rc L1309-1316 parity)
        let macroMenuItem = NSMenuItem()
        let macroMenu = NSMenu(title: tr("Macro"))
        macroMenu.addItem(withTitle: tr("Start Recording"), action: #selector(menuMacroStart), keyEquivalent: "")
        macroMenu.addItem(withTitle: tr("Stop Recording"), action: #selector(menuMacroStop), keyEquivalent: "")
        let playbackItem = NSMenuItem(title: tr("Playback"), action: #selector(menuMacroPlayback), keyEquivalent: "P")
        playbackItem.keyEquivalentModifierMask = [.command, .shift]
        macroMenu.addItem(playbackItem)
        macroMenu.addItem(withTitle: tr("Save Current Recorded Macro..."), action: #selector(menuMacroSave), keyEquivalent: "")
        macroMenu.addItem(withTitle: tr("Run a Macro Multiple Times..."), action: #selector(menuMacroRunMulti), keyEquivalent: "")
        if !workspace.savedMacros.isEmpty {
            macroMenu.addItem(NSMenuItem.separator())
            for saved in workspace.savedMacros {
                let savedItem = NSMenuItem(title: tr(saved.name), action: #selector(menuRunSavedMacro(_:)), keyEquivalent: "")
                savedItem.representedObject = saved.name
                macroMenu.addItem(savedItem)
            }
            macroMenu.addItem(NSMenuItem.separator())
            macroMenu.addItem(withTitle: tr("Modify Shortcut/Delete Macro..."), action: #selector(menuMacroModifyShortcuts), keyEquivalent: "")
        }
        macroMenuItem.submenu = macroMenu
        mainMenu.addItem(macroMenuItem)

        // 11. Run Menu (Notepad++ Windows parity)
        let runMenuItem = NSMenuItem()
        let runMenu = NSMenu(title: tr("Run"))
        runMenu.addItem(withTitle: tr("Run..."), action: #selector(menuRunPrompt), keyEquivalent: "")
        runMenu.addItem(NSMenuItem.separator())
        runMenu.addItem(withTitle: tr("Open in Terminal"), action: #selector(menuOpenFolderTerminal), keyEquivalent: "t")
        runMenu.addItem(withTitle: tr("Launch in Safari"), action: #selector(menuLaunchSafari), keyEquivalent: "")
        runMenu.addItem(withTitle: tr("Launch in Chrome"), action: #selector(menuLaunchChrome), keyEquivalent: "")
        runMenu.addItem(withTitle: tr("Google Search Selected Text"), action: #selector(menuSearchGoogle), keyEquivalent: "")
        runMenuItem.submenu = runMenu
        mainMenu.addItem(runMenuItem)

        // 12. Plugins Menu
        let pluginsMenuItem = NSMenuItem()
        let pluginsMenu = NSMenu(title: tr("Plugins"))

        // MIME Tools
        let mimeMenu = NSMenu(title: tr("MIME Tools"))
        mimeMenu.addItem(withTitle: tr("Base64 Encode"), action: #selector(menuBase64Encode), keyEquivalent: "")
        mimeMenu.addItem(withTitle: tr("Base64 Decode"), action: #selector(menuBase64Decode), keyEquivalent: "")
        mimeMenu.addItem(withTitle: tr("URL Encode"), action: #selector(menuUrlEncode), keyEquivalent: "")
        mimeMenu.addItem(withTitle: tr("URL Decode"), action: #selector(menuUrlDecode), keyEquivalent: "")
        let mimeItem = NSMenuItem(title: tr("MIME Tools"), action: nil, keyEquivalent: "")
        mimeItem.submenu = mimeMenu
        pluginsMenu.addItem(mimeItem)

        // Converter
        let converterMenu = NSMenu(title: tr("Converter"))
        converterMenu.addItem(withTitle: "ASCII -> HEX", action: #selector(menuAsciiToHex), keyEquivalent: "")
        converterMenu.addItem(withTitle: "HEX -> ASCII", action: #selector(menuHexToAscii), keyEquivalent: "")
        converterMenu.addItem(NSMenuItem.separator())
        converterMenu.addItem(withTitle: tr("UPPERCASE"), action: #selector(menuUppercase), keyEquivalent: "")
        converterMenu.addItem(withTitle: tr("lowercase"), action: #selector(menuLowercase), keyEquivalent: "")
        let converterItem = NSMenuItem(title: tr("Converter"), action: nil, keyEquivalent: "")
        converterItem.submenu = converterMenu
        pluginsMenu.addItem(converterItem)

        // NppExport
        let exportMenu = NSMenu(title: "NppExport")
        exportMenu.addItem(withTitle: tr("Copy RTF to clipboard"), action: #selector(menuExportCopyRTF), keyEquivalent: "")
        exportMenu.addItem(withTitle: tr("Copy HTML to clipboard"), action: #selector(menuExportCopyHTML), keyEquivalent: "")
        let exportItem = NSMenuItem(title: "NppExport", action: nil, keyEquivalent: "")
        exportItem.submenu = exportMenu
        pluginsMenu.addItem(exportItem)

        pluginsMenuItem.submenu = pluginsMenu
        mainMenu.addItem(pluginsMenuItem)

        // 13. Window Menu (Notepad_plus.rc L1331-1346 parity)
        let windowMenuItem = NSMenuItem()
        let windowMenu = NSMenu(title: tr("Window"))
        windowMenu.addItem(withTitle: tr("Windows..."), action: #selector(menuShowWindowsDialog), keyEquivalent: "")
        let sortTabsMenu = NSMenu(title: tr("Sort By"))
        sortTabsMenu.addItem(withTitle: tr("Name A to Z"), action: #selector(menuSortTabsNameAsc), keyEquivalent: "")
        sortTabsMenu.addItem(withTitle: tr("Name Z to A"), action: #selector(menuSortTabsNameDesc), keyEquivalent: "")
        sortTabsMenu.addItem(withTitle: tr("Path A to Z"), action: #selector(menuSortTabsPathAsc), keyEquivalent: "")
        sortTabsMenu.addItem(withTitle: tr("Path Z to A"), action: #selector(menuSortTabsPathDesc), keyEquivalent: "")
        sortTabsMenu.addItem(withTitle: tr("Type A to Z"), action: #selector(menuSortTabsTypeAsc), keyEquivalent: "")
        sortTabsMenu.addItem(withTitle: tr("Type Z to A"), action: #selector(menuSortTabsTypeDesc), keyEquivalent: "")
        sortTabsMenu.addItem(withTitle: tr("Content Length Ascending"), action: #selector(menuSortTabsSizeAsc), keyEquivalent: "")
        sortTabsMenu.addItem(withTitle: tr("Content Length Descending"), action: #selector(menuSortTabsSizeDesc), keyEquivalent: "")
        let sortTabsItem = NSMenuItem(title: tr("Sort By"), action: nil, keyEquivalent: "")
        sortTabsItem.submenu = sortTabsMenu
        windowMenu.addItem(sortTabsItem)

        windowMenu.addItem(NSMenuItem.separator())
        windowMenu.addItem(withTitle: tr("Next Tab"), action: #selector(menuNextTab), keyEquivalent: "}")
        windowMenu.addItem(withTitle: tr("Previous Tab"), action: #selector(menuPrevTab), keyEquivalent: "{")
        windowMenu.addItem(withTitle: tr("Move Tab Forward"), action: #selector(menuMoveTabForward), keyEquivalent: "")
        windowMenu.addItem(withTitle: tr("Move Tab Backward"), action: #selector(menuMoveTabBackward), keyEquivalent: "")
        if !workspace.documents.isEmpty {
            windowMenu.addItem(NSMenuItem.separator())
            for (idx, doc) in workspace.documents.enumerated() {
                let dirtyMark = doc.isDirty ? "*" : ""
                let docItem = NSMenuItem(title: "\(idx + 1): \(dirtyMark)\(doc.title)", action: #selector(menuSelectTabByIndex(_:)), keyEquivalent: "")
                docItem.tag = idx
                windowMenu.addItem(docItem)
            }
        }
        windowMenuItem.submenu = windowMenu
        mainMenu.addItem(windowMenuItem)

        // 14. ? (Help) Menu (Notepad++ Windows parity)
        let helpMenuItem = NSMenuItem()
        let helpMenu = NSMenu(title: tr("?"))
        helpMenu.addItem(withTitle: tr("Command Line Arguments..."), action: #selector(menuCmdArgs), keyEquivalent: "")
        helpMenu.addItem(NSMenuItem.separator())
        helpMenu.addItem(withTitle: tr("Notepad++ Home"), action: #selector(menuNppHome), keyEquivalent: "")
        helpMenu.addItem(withTitle: tr("Notepad++ Online User Manual"), action: #selector(menuNppManual), keyEquivalent: "")
        helpMenu.addItem(withTitle: tr("Notepad++ Community (Forum)"), action: #selector(menuNppForum), keyEquivalent: "")
        helpMenu.addItem(NSMenuItem.separator())
        helpMenu.addItem(withTitle: tr("Debug Info..."), action: #selector(menuDebugInfo), keyEquivalent: "")
        helpMenu.addItem(withTitle: tr("About Notepad++"), action: #selector(showAbout), keyEquivalent: "")
        helpMenuItem.submenu = helpMenu
        mainMenu.addItem(helpMenuItem)

        NSApp.mainMenu = mainMenu
    }

    // MARK: - Action Handlers
    @objc func menuNew() {
        workspace.newDocument()
        updateWindowTitle()
    }
    @objc func menuOpen() {
        workspace.promptOpenFile()
        updateWindowTitle()
    }
    @objc func menuOpenInDefaultViewer() {
        workspace.openInDefaultViewer()
    }
    @objc func menuOpenFolderAsWorkspace() {
        workspace.openFolderAsWorkspace()
    }
    @objc func menuOpenContainingFolderAsWorkspace() {
        workspace.openContainingFolderAsWorkspace()
    }
    @objc func menuReload() {
        if let doc = workspace.activeDocument {
            workspace.reloadFromDisk(for: doc)
            updateWindowTitle()
        }
    }
    @objc func menuSave() {
        workspace.recordMacroStep(.saveDocument)
        workspace.saveActive()
        updateWindowTitle()
    }
    @objc func menuSaveAs() {
        if let doc = workspace.activeDocument {
            workspace.promptSaveAs(for: doc)
            updateWindowTitle()
        }
    }
    @objc func menuSaveCopyAs() {
        if let doc = workspace.activeDocument {
            workspace.promptSaveCopyAs(for: doc)
        }
    }
    @objc func menuSaveAll() {
        workspace.saveAll()
        updateWindowTitle()
    }
    @objc func menuRename() {
        workspace.promptRenameDocument()
        updateWindowTitle()
    }
    @objc func menuCloseTab() {
        if let doc = workspace.activeDocument { workspace.closeDocument(id: doc.id) }
        updateWindowTitle()
    }
    @objc func menuCloseAll() {
        workspace.closeAll()
        updateWindowTitle()
    }
    @objc func menuCloseAllButActive() {
        if let doc = workspace.activeDocument { workspace.closeAllBut(id: doc.id) }
    }
    @objc func menuCloseAllButPinned() {
        workspace.closeAllButPinned()
    }
    @objc func menuCloseAllToLeft() {
        if let doc = workspace.activeDocument { workspace.closeAllToLeft(of: doc.id) }
    }
    @objc func menuCloseAllToRight() {
        if let doc = workspace.activeDocument { workspace.closeAllToRight(of: doc.id) }
    }
    @objc func menuCloseAllUnchanged() { workspace.closeAllUnchanged() }
    @objc func menuLoadSession() { workspace.promptLoadSession() }
    @objc func menuSaveSession() { workspace.promptSaveSession() }
    @objc func menuPrintNow() { workspace.printNow() }
    @objc func menuOpenRecentFile(_ sender: NSMenuItem) {
        if let url = sender.representedObject as? URL {
            workspace.openFile(url: url)
            updateWindowTitle()
        }
    }
    @objc func menuRestoreRecentClosedFile() {
        workspace.restoreRecentClosedFile()
        updateWindowTitle()
    }
    @objc func menuOpenAllRecentFiles() {
        workspace.openAllRecentFiles()
        updateWindowTitle()
    }
    @objc func menuEmptyRecentFilesList() {
        workspace.emptyRecentFilesList()
    }

    @objc func menuOpenFolderFinder() {
        guard let path = workspace.activeDocument?.filePath else { return }
        if FileManager.default.fileExists(atPath: path.path) {
            NSWorkspace.shared.activateFileViewerSelecting([path])
        } else {
            let dir = path.deletingLastPathComponent()
            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: dir.path)
        }
    }
    @objc func menuOpenFolderTerminal() {
        guard let path = workspace.activeDocument?.filePath else { return }
        let dir = path.deletingLastPathComponent()
        NppTools.openTerminal(at: dir)
    }
    @objc func menuMoveToTrash() {
        if let doc = workspace.activeDocument, let path = doc.filePath {
            try? FileManager.default.trashItem(at: path, resultingItemURL: nil)
            workspace.closeDocument(id: doc.id)
            updateWindowTitle()
        }
    }
    @objc func menuPrint() {
        if let tv = getActiveTextView() {
            let printOp = NSPrintOperation(view: tv)
            printOp.run()
        }
    }

    @objc func menuFind() { workspace.openFind() }
    @objc func menuReplace() { workspace.openReplace() }
    @objc func menuFindInFiles() { workspace.openFindInFiles() }
    @objc func menuMark() { workspace.openMark() }
    @objc func menuColumnEditor() { workspace.showColumnEditor = true }
    @objc func menuToggleDocumentList() { workspace.showDocumentList.toggle() }
    @objc func menuToggleFolderAsWorkspace() { workspace.showFolderAsWorkspace.toggle() }
    @objc func menuToggleFunctionList() { workspace.showFunctionList.toggle() }
    @objc func menuToggleDocumentMap() { workspace.showDocumentMap.toggle() }
    @objc func menuFindAllCurrent() {
        if let tv = getActiveTextView() {
            let sel = tv.selectedRange()
            if sel.length > 0 {
                let text = (tv.string as NSString).substring(with: sel)
                workspace.findAllInCurrentDoc(query: text, matchCase: false, wholeWord: false, useRegex: false)
            }
        }
    }
    @objc func menuFindAllOpened() {
        if let tv = getActiveTextView() {
            let sel = tv.selectedRange()
            if sel.length > 0 {
                let text = (tv.string as NSString).substring(with: sel)
                workspace.findAllInAllOpenedDocs(query: text, matchCase: false, wholeWord: false, useRegex: false)
            }
        }
    }
    @objc func menuClearSearchResults() { workspace.clearSearchResults() }
    @objc func menuGoToLine() {
        guard let doc = workspace.activeDocument else { return }
        let alert = NSAlert()
        alert.messageText = "Go to Line"
        alert.informativeText = "Enter line number (1 - \(max(1, doc.content.components(separatedBy: .newlines).count))):"
        alert.addButton(withTitle: "Go")
        alert.addButton(withTitle: "Cancel")
        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        input.stringValue = "\(doc.cursorLine)"
        alert.accessoryView = input
        if alert.runModal() == .alertFirstButtonReturn, let targetLine = Int(input.stringValue), targetLine >= 1 {
            if let tv = getActiveTextView() {
                let nsStr = tv.string as NSString
                var currentLine = 1
                var idx = 0
                var targetLocation = 0
                while idx < nsStr.length && currentLine < targetLine {
                    var lStart = 0, lEnd = 0, cEnd = 0
                    nsStr.getLineStart(&lStart, end: &lEnd, contentsEnd: &cEnd, for: NSRange(location: idx, length: 0))
                    if lEnd > idx {
                        idx = lEnd
                        targetLocation = idx
                        currentLine += 1
                    } else {
                        break
                    }
                }
                let r = NSRange(location: min(targetLocation, nsStr.length), length: 0)
                tv.setSelectedRange(r)
                tv.scrollRangeToVisible(r)
            }
        }
    }

    @objc func menuFindNext() { workspace.findNext(forward: true) }
    @objc func menuFindPrev() { workspace.findNext(forward: false) }
    @objc func menuSelectAndFindNext() { workspace.selectAndFindNext(forward: true) }
    @objc func menuSelectAndFindPrev() { workspace.selectAndFindNext(forward: false) }
    @objc func menuIncrementalSearch() { workspace.toggleIncrementalSearch() }
    @objc func menuSearchResultsWindow() { workspace.toggleSearchResultsWindow() }
    @objc func menuNextSearchResult() { workspace.nextSearchResult() }
    @objc func menuPrevSearchResult() { workspace.prevSearchResult() }
    @objc func menuGoToMatchingBrace() { _ = workspace.goToMatchingBrace() }
    @objc func menuSelectAllBetweenBraces() { _ = workspace.selectAllBetweenBraces() }
    @objc func menuStyleAllToken(_ sender: NSMenuItem) {
        _ = workspace.styleAllOccurrencesOfToken(styleIndex: sender.tag)
    }
    @objc func menuStyleOneToken(_ sender: NSMenuItem) {
        _ = workspace.styleOneToken(styleIndex: sender.tag)
    }
    @objc func menuClearTokenStyle(_ sender: NSMenuItem) {
        workspace.clearStyle(styleIndex: sender.tag)
    }
    @objc func menuClearAllTokenStyles() {
        workspace.clearAllStyles()
    }
    @objc func menuFindCharsInRange() {
        let alert = NSAlert()
        alert.messageText = workspace.tr("Find characters in range...")
        alert.informativeText = "Select character code range to search:"
        alert.addButton(withTitle: workspace.tr("Find"))
        alert.addButton(withTitle: workspace.tr("Cancel"))

        let container = NSView(frame: NSRect(x: 0, y: 0, width: 280, height: 84))
        let modePopup = NSPopUpButton(frame: NSRect(x: 0, y: 54, width: 280, height: 26))
        modePopup.addItems(withTitles: [
            "Non-ASCII Characters (128 - 255)",
            "ASCII Characters (0 - 127)",
            "My Range:"
        ])
        let minLabel = NSTextField(labelWithString: "Min:")
        minLabel.frame = NSRect(x: 0, y: 20, width: 36, height: 20)
        let minField = NSTextField(frame: NSRect(x: 40, y: 18, width: 70, height: 24))
        minField.stringValue = "128"
        let maxLabel = NSTextField(labelWithString: "Max:")
        maxLabel.frame = NSRect(x: 130, y: 20, width: 38, height: 20)
        let maxField = NSTextField(frame: NSRect(x: 172, y: 18, width: 70, height: 24))
        maxField.stringValue = "255"

        container.addSubview(modePopup)
        container.addSubview(minLabel)
        container.addSubview(minField)
        container.addSubview(maxLabel)
        container.addSubview(maxField)
        alert.accessoryView = container

        if alert.runModal() == .alertFirstButtonReturn {
            let idx = modePopup.indexOfSelectedItem
            let minCode: Int
            let maxCode: Int
            if idx == 0 {
                minCode = 128
                maxCode = Int(UInt32.max)
            } else if idx == 1 {
                minCode = 0
                maxCode = 127
            } else {
                minCode = Int(minField.stringValue) ?? 128
                maxCode = Int(maxField.stringValue) ?? 255
            }
            _ = workspace.findCharactersInRange(minCode: minCode, maxCode: maxCode, forward: true, wrap: true)
        }
    }

    @objc func menuToggleBookmark() { workspace.toggleBookmark() }
    @objc func menuNextBookmark() { workspace.nextBookmark() }
    @objc func menuPrevBookmark() { workspace.prevBookmark() }
    @objc func menuClearAllBookmarks() { workspace.clearAllBookmarks() }
    @objc func menuCutBookmarkedLines() { workspace.cutBookmarkedLines() }
    @objc func menuCopyBookmarkedLines() { workspace.copyBookmarkedLines() }
    @objc func menuPasteBookmarkedLines() { workspace.pasteToBookmarkedLines() }
    @objc func menuRemoveBookmarkedLines() { workspace.removeBookmarkedLines() }
    @objc func menuRemoveNonBookmarkedLines() { workspace.removeNonBookmarkedLines() }
    @objc func menuInverseBookmarks() { workspace.inverseBookmarks() }

    @objc func menuToggleAlwaysOnTop(_ sender: Any?) {
        guard let win = window else { return }
        if win.level == .floating {
            win.level = .normal
            workspace.isAlwaysOnTop = false
        } else {
            win.level = .floating
            workspace.isAlwaysOnTop = true
        }
        if let item = sender as? NSMenuItem {
            item.state = (win.level == .floating) ? .on : .off
        }
    }
    @objc func menuToggleWordWrap() { workspace.isWordWrapEnabled.toggle() }
    @objc func menuToggleFullScreen() {
        window?.toggleFullScreen(nil)
        workspace.isFullScreen.toggle()
    }
    @objc func menuTogglePostIt() {
        workspace.togglePostItMode(window: window)
    }
    @objc func menuToggleDistractionFree() {
        workspace.toggleDistractionFreeMode()
    }
    @objc func menuToggleShowSpaceAndTab() { workspace.toggleShowSpaceAndTab() }
    @objc func menuToggleShowEndOfLine() { workspace.toggleShowEndOfLine() }
    @objc func menuToggleShowNonPrintingCharacters() { workspace.toggleShowNonPrintingCharacters() }
    @objc func menuToggleShowControlCharsAndUnicodeEol() { workspace.toggleShowControlCharsAndUnicodeEol() }
    @objc func menuToggleShowAllCharacters() { workspace.toggleShowAllCharacters() }
    @objc func menuToggleShowIndentGuide() { workspace.showIndentGuides.toggle() }
    @objc func menuToggleShowWrapSymbol() { workspace.showWrapSymbol.toggle() }
    @objc func menuSelectTabByIndex(_ sender: NSMenuItem) {
        workspace.selectTab(at: sender.tag)
        updateWindowTitle()
    }
    @objc func menuFirstTab() {
        workspace.selectFirstTab()
        updateWindowTitle()
    }
    @objc func menuLastTab() {
        workspace.selectLastTab()
        updateWindowTitle()
    }
    @objc func menuApplyTabColor(_ sender: NSMenuItem) {
        workspace.applyTabColor(sender.tag)
    }
    @objc func menuToggleMonitoring() {
        workspace.toggleMonitoringCurrentDoc()
    }
    @objc func menuZoomIn() { workspace.zoomIn() }
    @objc func menuZoomOut() { workspace.zoomOut() }
    @objc func menuResetZoom() { workspace.resetZoom() }
    @objc func menuDocSummary() {
        workspace.showDocumentSummary()
    }

    // Clipboard & Path
    @objc func menuCopyFullPath() {
        if let path = workspace.activeDocument?.filePath {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(path.path, forType: .string)
        }
    }
    @objc func menuCopyFilename() {
        if let path = workspace.activeDocument?.filePath {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(path.lastPathComponent, forType: .string)
        }
    }
    @objc func menuCopyDirPath() {
        if let path = workspace.activeDocument?.filePath {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(path.deletingLastPathComponent().path, forType: .string)
        }
    }
    @objc func menuCopyAllFilenames() {
        workspace.copyAllFilenames()
    }
    @objc func menuCopyAllFilePaths() {
        workspace.copyAllFilePaths()
    }

    // Edit operations
    private func getActiveTextView() -> NSTextView? {
        return workspace.activeTextView ?? (window?.firstResponder as? NSTextView)
    }

    @objc func menuBeginEndSelect() {
        workspace.beginOrEndSelect()
    }

    @objc func menuIncreaseLineIndent() {
        if let tv = getActiveTextView() {
            NppEditOperations.increaseLineIndent(in: tv, spaceCount: workspace.tabSize, useTabs: true)
        }
    }
    @objc func menuDecreaseLineIndent() {
        if let tv = getActiveTextView() {
            NppEditOperations.decreaseLineIndent(in: tv, spaceCount: workspace.tabSize)
        }
    }

    @objc func menuUppercase() {
        workspace.recordMacroStep(.uppercase)
        if let tv = getActiveTextView() { NppEditOperations.convertCase(in: tv, to: .uppercase) }
    }
    @objc func menuLowercase() {
        workspace.recordMacroStep(.lowercase)
        if let tv = getActiveTextView() { NppEditOperations.convertCase(in: tv, to: .lowercase) }
    }
    @objc func menuProperCase() {
        if let tv = getActiveTextView() { NppEditOperations.convertCase(in: tv, to: .properCase) }
    }
    @objc func menuProperCaseBlend() {
        if let tv = getActiveTextView() { NppEditOperations.convertCase(in: tv, to: .properCaseBlend) }
    }
    @objc func menuSentenceCase() {
        if let tv = getActiveTextView() { NppEditOperations.convertCase(in: tv, to: .sentenceCase) }
    }
    @objc func menuSentenceCaseBlend() {
        if let tv = getActiveTextView() { NppEditOperations.convertCase(in: tv, to: .sentenceCaseBlend) }
    }
    @objc func menuInvertCase() {
        if let tv = getActiveTextView() { NppEditOperations.convertCase(in: tv, to: .invertCase) }
    }
    @objc func menuRandomCase() {
        if let tv = getActiveTextView() { NppEditOperations.convertCase(in: tv, to: .randomCase) }
    }

    @objc func menuDupLine() {
        workspace.recordMacroStep(.duplicateLine)
        if let tv = getActiveTextView() { NppEditOperations.duplicateLine(in: tv) }
    }
    @objc func menuJoinLines() {
        workspace.recordMacroStep(.joinLines)
        if let tv = getActiveTextView() { NppEditOperations.joinLines(in: tv) }
    }
    @objc func menuSplitLines() {
        workspace.recordMacroStep(.splitLines)
        if let tv = getActiveTextView() { NppEditOperations.splitLines(in: tv) }
    }
    @objc func menuMoveLineUp() {
        workspace.recordMacroStep(.moveLineUp)
        if let tv = getActiveTextView() { NppEditOperations.moveLineUp(in: tv) }
    }
    @objc func menuMoveLineDown() {
        workspace.recordMacroStep(.moveLineDown)
        if let tv = getActiveTextView() { NppEditOperations.moveLineDown(in: tv) }
    }
    @objc func menuInsertEmptyLineAbove() {
        workspace.recordMacroStep(.insertEmptyLineAbove)
        if let tv = getActiveTextView() { NppEditOperations.insertEmptyLineAbove(in: tv) }
    }
    @objc func menuInsertEmptyLineBelow() {
        workspace.recordMacroStep(.insertEmptyLineBelow)
        if let tv = getActiveTextView() { NppEditOperations.insertEmptyLineBelow(in: tv) }
    }
    @objc func menuRemoveEmptyLines() {
        workspace.recordMacroStep(.removeEmptyLines)
        if let doc = workspace.activeDocument { NppEditOperations.removeEmptyLines(in: doc, removeBlankChars: false) }
    }
    @objc func menuRemoveEmptyLinesContainingBlanks() {
        workspace.recordMacroStep(.removeEmptyLinesContainingBlanks)
        if let doc = workspace.activeDocument { NppEditOperations.removeEmptyLines(in: doc, removeBlankChars: true) }
    }
    @objc func menuRemoveDuplicateLines() {
        workspace.recordMacroStep(.removeDuplicateLines)
        if let doc = workspace.activeDocument { NppEditOperations.removeDuplicateLines(in: doc) }
    }
    @objc func menuRemoveConsecutiveDuplicateLines() {
        if let doc = workspace.activeDocument { NppEditOperations.removeConsecutiveDuplicateLines(in: doc) }
    }
    @objc func menuSortAscending() {
        workspace.recordMacroStep(.sortLines)
        if let doc = workspace.activeDocument { NppEditOperations.sortLines(in: doc, ascending: true) }
    }
    @objc func menuSortDescending() {
        workspace.recordMacroStep(.sortLinesDescending)
        if let doc = workspace.activeDocument { NppEditOperations.sortLines(in: doc, ascending: false) }
    }
    @objc func menuSortCaseInsensitiveAscending() {
        if let doc = workspace.activeDocument { NppEditOperations.sortLinesCaseInsensitive(in: doc, ascending: true) }
    }
    @objc func menuSortCaseInsensitiveDescending() {
        if let doc = workspace.activeDocument { NppEditOperations.sortLinesCaseInsensitive(in: doc, ascending: false) }
    }
    @objc func menuSortIntegersAscending() {
        workspace.recordMacroStep(.sortLinesIntegersAscending)
        if let doc = workspace.activeDocument { NppEditOperations.sortLinesAsIntegers(in: doc, ascending: true) }
    }
    @objc func menuSortIntegersDescending() {
        workspace.recordMacroStep(.sortLinesIntegersDescending)
        if let doc = workspace.activeDocument { NppEditOperations.sortLinesAsIntegers(in: doc, ascending: false) }
    }
    @objc func menuSortDecimalsDotAscending() {
        workspace.recordMacroStep(.sortLinesDecimalsDotAscending)
        if let doc = workspace.activeDocument { NppEditOperations.sortLinesAsDecimals(in: doc, ascending: true, usesComma: false) }
    }
    @objc func menuSortDecimalsDotDescending() {
        workspace.recordMacroStep(.sortLinesDecimalsDotDescending)
        if let doc = workspace.activeDocument { NppEditOperations.sortLinesAsDecimals(in: doc, ascending: false, usesComma: false) }
    }
    @objc func menuSortDecimalsCommaAscending() {
        workspace.recordMacroStep(.sortLinesDecimalsCommaAscending)
        if let doc = workspace.activeDocument { NppEditOperations.sortLinesAsDecimals(in: doc, ascending: true, usesComma: true) }
    }
    @objc func menuSortDecimalsCommaDescending() {
        workspace.recordMacroStep(.sortLinesDecimalsCommaDescending)
        if let doc = workspace.activeDocument { NppEditOperations.sortLinesAsDecimals(in: doc, ascending: false, usesComma: true) }
    }
    @objc func menuSortByLengthAscending() {
        if let doc = workspace.activeDocument { NppEditOperations.sortLinesByLength(in: doc, ascending: true) }
    }
    @objc func menuSortByLengthDescending() {
        if let doc = workspace.activeDocument { NppEditOperations.sortLinesByLength(in: doc, ascending: false) }
    }
    @objc func menuReverseLines() {
        workspace.recordMacroStep(.reverseLineOrder)
        if let doc = workspace.activeDocument { NppEditOperations.reverseLineOrder(in: doc) }
    }
    @objc func menuRandomizeLineOrder() {
        if let doc = workspace.activeDocument { NppEditOperations.randomizeLineOrder(in: doc) }
    }

    @objc func menuToggleComment() {
        workspace.recordMacroStep(.toggleComment)
        if let tv = getActiveTextView(), let lang = workspace.activeDocument?.language {
            NppEditOperations.toggleComment(in: tv, language: lang)
        }
    }

    @objc func menuSingleLineComment() {
        workspace.recordMacroStep(.singleLineComment)
        if let tv = getActiveTextView(), let lang = workspace.activeDocument?.language {
            NppEditOperations.singleLineComment(in: tv, language: lang)
        }
    }

    @objc func menuSingleLineUncomment() {
        workspace.recordMacroStep(.singleLineUncomment)
        if let tv = getActiveTextView(), let lang = workspace.activeDocument?.language {
            NppEditOperations.singleLineUncomment(in: tv, language: lang)
        }
    }

    @objc func menuBlockComment() {
        workspace.recordMacroStep(.streamComment)
        if let tv = getActiveTextView(), let lang = workspace.activeDocument?.language {
            NppEditOperations.streamComment(in: tv, language: lang)
        }
    }

    @objc func menuBlockUncomment() {
        workspace.recordMacroStep(.streamUncomment)
        if let tv = getActiveTextView(), let lang = workspace.activeDocument?.language {
            NppEditOperations.streamUncomment(in: tv, language: lang)
        }
    }

    @objc func menuTrimTrailing() {
        workspace.recordMacroStep(.trimTrailingSpace)
        let sel = getActiveTextView()?.selectedRange()
        if let doc = workspace.activeDocument { NppEditOperations.trimSpaces(in: doc, mode: .trailing, selectedRange: sel) }
    }
    @objc func menuTrimLeading() {
        workspace.recordMacroStep(.trimLeadingSpace)
        let sel = getActiveTextView()?.selectedRange()
        if let doc = workspace.activeDocument { NppEditOperations.trimSpaces(in: doc, mode: .leading, selectedRange: sel) }
    }
    @objc func menuTrimBoth() {
        workspace.recordMacroStep(.trimBothSpace)
        let sel = getActiveTextView()?.selectedRange()
        if let doc = workspace.activeDocument { NppEditOperations.trimSpaces(in: doc, mode: .both, selectedRange: sel) }
    }
    @objc func menuEolToSpace() {
        workspace.recordMacroStep(.eolToSpace)
        if let doc = workspace.activeDocument { NppEditOperations.eolToSpace(in: doc) }
    }
    @objc func menuTrimBothAndEolToSpace() {
        if let doc = workspace.activeDocument { NppEditOperations.trimBothAndEolToSpace(in: doc) }
    }
    @objc func menuTabToSpace() {
        workspace.recordMacroStep(.tabToSpace)
        let sel = getActiveTextView()?.selectedRange()
        if let doc = workspace.activeDocument { NppEditOperations.tabToSpace(in: doc, selectedRange: sel) }
    }
    @objc func menuSpaceToTab() {
        workspace.recordMacroStep(.spaceToTab)
        let sel = getActiveTextView()?.selectedRange()
        if let doc = workspace.activeDocument { NppEditOperations.spaceToTab(in: doc, selectedRange: sel) }
    }
    @objc func menuSpaceToTabAll() {
        workspace.recordMacroStep(.spaceToTab)
        let sel = getActiveTextView()?.selectedRange()
        if let doc = workspace.activeDocument { NppEditOperations.spaceToTabAll(in: doc, spaceCount: workspace.tabSize, selectedRange: sel) }
    }
    @objc func menuSpaceToTabLeading() {
        let sel = getActiveTextView()?.selectedRange()
        if let doc = workspace.activeDocument { NppEditOperations.spaceToTabLeading(in: doc, spaceCount: workspace.tabSize, selectedRange: sel) }
    }

    @objc func menuInsertDateShort() {
        workspace.recordMacroStep(.insertDateTime)
        if let tv = getActiveTextView() { NppEditOperations.insertDateTime(in: tv, isLong: false) }
    }
    @objc func menuInsertDateLong() {
        workspace.recordMacroStep(.insertDateTimeLong)
        if let tv = getActiveTextView() { NppEditOperations.insertDateTime(in: tv, isLong: true) }
    }
    @objc func menuInsertDateCustomized() {
        workspace.recordMacroStep(.insertDateTimeCustomized)
        if let tv = getActiveTextView() { NppEditOperations.insertCustomDateTime(in: tv, format: workspace.customDateFormat) }
    }

    // On Selection Actions
    @objc func menuOpenSelectedFile() {
        guard let tv = getActiveTextView() else { return }
        let sel = tv.selectedRange()
        var rawText = ""
        if sel.length > 0 {
            rawText = (tv.string as NSString).substring(with: sel)
        } else {
            let str = tv.string as NSString
            let wordRange = (str.length > 0) ? str.lineRange(for: NSRange(location: sel.location, length: 0)) : NSRange(location: 0, length: 0)
            rawText = str.substring(with: wordRange)
        }
        let target = rawText.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "\"\'"))
        guard !target.isEmpty else { return }

        if target.hasPrefix("http://") || target.hasPrefix("https://"), let url = URL(string: target) {
            NSWorkspace.shared.open(url)
            return
        }

        let expandedPath = (target as NSString).expandingTildeInPath
        if FileManager.default.fileExists(atPath: expandedPath) {
            workspace.openFile(url: URL(fileURLWithPath: expandedPath))
            return
        }

        if let baseDir = workspace.activeDocument?.filePath?.deletingLastPathComponent() {
            let relUrl = baseDir.appendingPathComponent(target)
            if FileManager.default.fileExists(atPath: relUrl.path) {
                workspace.openFile(url: relUrl)
                return
            }
        }

        let alert = NSAlert()
        alert.messageText = workspace.tr("Open Path")
        alert.informativeText = workspace.tr("The path you're trying to open doesn't exist.")
        alert.alertStyle = .warning
        alert.runModal()
    }

    @objc func menuOpenSelectedFolderInFinder() {
        guard let tv = getActiveTextView() else { return }
        let sel = tv.selectedRange()
        var rawText = ""
        if sel.length > 0 {
            rawText = (tv.string as NSString).substring(with: sel)
        } else {
            let str = tv.string as NSString
            let wordRange = (str.length > 0) ? str.lineRange(for: NSRange(location: sel.location, length: 0)) : NSRange(location: 0, length: 0)
            rawText = str.substring(with: wordRange)
        }
        let target = rawText.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "\"\'"))
        guard !target.isEmpty else { return }

        let expandedPath = (target as NSString).expandingTildeInPath
        var urlToReveal: URL?
        if FileManager.default.fileExists(atPath: expandedPath) {
            urlToReveal = URL(fileURLWithPath: expandedPath)
        } else if let baseDir = workspace.activeDocument?.filePath?.deletingLastPathComponent() {
            let relUrl = baseDir.appendingPathComponent(target)
            if FileManager.default.fileExists(atPath: relUrl.path) {
                urlToReveal = relUrl
            }
        }

        if let url = urlToReveal {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } else {
            let alert = NSAlert()
            alert.messageText = workspace.tr("Open Path")
            alert.informativeText = workspace.tr("The path you're trying to open doesn't exist.")
            alert.alertStyle = .warning
            alert.runModal()
        }
    }

    @objc func menuRedactSelection() {
        guard let tv = getActiveTextView(), tv.isEditable else { return }
        if let doc = workspace.activeDocument, doc.isReadOnly { return }
        if workspace.isAllDocumentsReadOnly { return }
        let sel = tv.selectedRange()
        guard sel.length > 0 else { return }
        let text = (tv.string as NSString).substring(with: sel)
        let useBullet = NSEvent.modifierFlags.contains(.shift)
        let mask: Character = useBullet ? "●" : "█"
        let redacted = NppEditOperations.redact(text: text, mask: mask)
        if tv.shouldChangeText(in: sel, replacementString: redacted) {
            tv.replaceCharacters(in: sel, with: redacted)
            tv.didChangeText()
            tv.setSelectedRange(NSRange(location: sel.location, length: (redacted as NSString).length))
        }
    }

    @objc func menuSearchOnInternet() {
        guard let tv = getActiveTextView() else { return }
        let sel = tv.selectedRange()
        guard sel.length > 0 else { return }
        let query = (tv.string as NSString).substring(with: sel)
        if let url = workspace.resolvedSearchUrl(for: query) {
            NSWorkspace.shared.open(url)
        }
    }

    @objc func menuChangeSearchEngine() {
        workspace.openPreferences(tab: 22)
    }

    // Panels & Read-Only Actions
    @objc func menuToggleReadOnlyCurrentDoc() {
        workspace.toggleReadOnlyCurrentDoc()
    }
    @objc func menuSetReadOnlyAllDocs() {
        workspace.setReadOnlyAllDocs()
    }
    @objc func menuClearReadOnlyAllDocs() {
        workspace.clearReadOnlyAllDocs()
    }
    @objc func menuToggleCharacterPanel() {
        workspace.showCharacterPanel.toggle()
    }
    @objc func menuToggleClipboardHistory() {
        workspace.showClipboardHistory.toggle()
    }

    // EOL actions
    @objc func menuEolWindows() {
        workspace.activeDocument?.convertEOL(to: .crlf)
        workspace.objectWillChange.send()
    }
    @objc func menuEolUnix() {
        workspace.activeDocument?.convertEOL(to: .lf)
        workspace.objectWillChange.send()
    }
    @objc func menuEolMac() {
        workspace.activeDocument?.convertEOL(to: .cr)
        workspace.objectWillChange.send()
    }

    // Encode in actions
    @objc func menuEncodeAnsi() {
        workspace.activeDocument?.reencodeAs(targetCharset: "WINDOWS-1252")
        workspace.objectWillChange.send()
    }
    @objc func menuEncodeUtf8() {
        workspace.activeDocument?.reencodeAs(targetCharset: "UTF-8")
        workspace.objectWillChange.send()
    }
    @objc func menuEncodeUtf8Bom() {
        workspace.activeDocument?.reencodeAs(targetCharset: "UTF-8")
        workspace.activeDocument?.hasBOM = true
        workspace.objectWillChange.send()
    }
    @objc func menuEncodeUtf16BE() {
        workspace.activeDocument?.reencodeAs(targetCharset: "UTF-16BE")
        workspace.objectWillChange.send()
    }
    @objc func menuEncodeUtf16LE() {
        workspace.activeDocument?.reencodeAs(targetCharset: "UTF-16LE")
        workspace.objectWillChange.send()
    }
    @objc func menuEncodeCP949() {
        workspace.activeDocument?.reencodeAs(targetCharset: "CP949")
        workspace.objectWillChange.send()
    }
    @objc func menuEncodeEucKr() {
        workspace.activeDocument?.reencodeAs(targetCharset: "EUC-KR")
        workspace.objectWillChange.send()
    }
    @objc func menuEncodeShiftJis() {
        workspace.activeDocument?.reencodeAs(targetCharset: "CP932")
        workspace.objectWillChange.send()
    }
    @objc func menuEncodeGB18030() {
        workspace.activeDocument?.reencodeAs(targetCharset: "GB18030")
        workspace.objectWillChange.send()
    }
    @objc func menuEncodeBig5() {
        workspace.activeDocument?.reencodeAs(targetCharset: "BIG5")
        workspace.objectWillChange.send()
    }

    // Convert to actions
    @objc func menuConvertAnsi() {
        workspace.activeDocument?.convertEncoding(to: "WINDOWS-1252")
        workspace.objectWillChange.send()
    }
    @objc func menuConvertUtf8() {
        workspace.activeDocument?.convertEncoding(to: "UTF-8", addBOM: false)
        workspace.objectWillChange.send()
    }
    @objc func menuConvertUtf8Bom() {
        workspace.activeDocument?.convertEncoding(to: "UTF-8", addBOM: true)
        workspace.objectWillChange.send()
    }
    @objc func menuConvertCP949() {
        workspace.activeDocument?.convertEncoding(to: "CP949")
        workspace.objectWillChange.send()
    }
    @objc func menuConvertEucKr() {
        workspace.activeDocument?.convertEncoding(to: "EUC-KR")
        workspace.objectWillChange.send()
    }

    // Language actions
    @objc func menuSetLangPlainText() {
        workspace.activeDocument?.language = "Plain Text"
        workspace.objectWillChange.send()
    }
    @objc func menuSelectLanguage(_ sender: NSMenuItem) {
        if let lang = sender.representedObject as? String {
            workspace.activeDocument?.language = lang
            workspace.objectWillChange.send()
        }
    }

    // Settings actions
    @objc func menuPreferences() {
        workspace.showPreferencesSheet = true
    }
    @objc func menuStyleConfigurator() {
        workspace.showStyleConfigurator = true
    }
    @objc func menuShortcutMapper() {
        workspace.showShortcutMapper = true
    }
    @objc func menuEditContextMenu() {
        let url = NppContextMenuConfig.ensureConfigFileExists()
        workspace.openFile(url: url)
        updateWindowTitle()
    }

    // Tools actions
    private func promptHashFromFiles(algorithmName: String, compute: (Data) -> String) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        if panel.runModal() == .OK {
            var lines: [String] = []
            for url in panel.urls {
                if let data = try? Data(contentsOf: url) {
                    lines.append("\(compute(data))  \(url.lastPathComponent)")
                }
            }
            if !lines.isEmpty {
                let result = lines.joined(separator: "\n")
                NppTools.showHashDialog(title: "\(algorithmName) Digest from Files", hash: result)
            }
        }
    }

    @objc func menuMD5Generate() {
        if let doc = workspace.activeDocument {
            let data = doc.content.data(using: .utf8) ?? Data()
            let hash = NppTools.md5(data: data)
            NppTools.showHashDialog(title: "MD5 Digest for \(doc.title)", hash: hash)
        }
    }
    @objc func menuMD5FromFiles() {
        promptHashFromFiles(algorithmName: "MD5", compute: NppTools.md5)
    }
    @objc func menuMD5Selection() {
        if let tv = getActiveTextView() {
            let sel = tv.selectedRange()
            let text = sel.length > 0 ? (tv.string as NSString).substring(with: sel) : tv.string
            let hash = NppTools.md5(data: text.data(using: .utf8) ?? Data())
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(hash, forType: .string)
            NppTools.showHashDialog(title: "MD5 Digest Copied to Clipboard", hash: hash)
        }
    }
    @objc func menuSHA1Generate() {
        if let doc = workspace.activeDocument {
            let data = doc.content.data(using: .utf8) ?? Data()
            let hash = NppTools.sha1(data: data)
            NppTools.showHashDialog(title: "SHA-1 Digest for \(doc.title)", hash: hash)
        }
    }
    @objc func menuSHA1FromFiles() {
        promptHashFromFiles(algorithmName: "SHA-1", compute: NppTools.sha1)
    }
    @objc func menuSHA1Selection() {
        if let tv = getActiveTextView() {
            let sel = tv.selectedRange()
            let text = sel.length > 0 ? (tv.string as NSString).substring(with: sel) : tv.string
            let hash = NppTools.sha1(data: text.data(using: .utf8) ?? Data())
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(hash, forType: .string)
            NppTools.showHashDialog(title: "SHA-1 Digest Copied to Clipboard", hash: hash)
        }
    }
    @objc func menuSHA256Generate() {
        if let doc = workspace.activeDocument {
            let data = doc.content.data(using: .utf8) ?? Data()
            let hash = NppTools.sha256(data: data)
            NppTools.showHashDialog(title: "SHA-256 Digest for \(doc.title)", hash: hash)
        }
    }
    @objc func menuSHA256FromFiles() {
        promptHashFromFiles(algorithmName: "SHA-256", compute: NppTools.sha256)
    }
    @objc func menuSHA256Selection() {
        if let tv = getActiveTextView() {
            let sel = tv.selectedRange()
            let text = sel.length > 0 ? (tv.string as NSString).substring(with: sel) : tv.string
            let hash = NppTools.sha256(data: text.data(using: .utf8) ?? Data())
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(hash, forType: .string)
            NppTools.showHashDialog(title: "SHA-256 Digest Copied to Clipboard", hash: hash)
        }
    }
    @objc func menuSHA512Generate() {
        if let doc = workspace.activeDocument {
            let data = doc.content.data(using: .utf8) ?? Data()
            let hash = NppTools.sha512(data: data)
            NppTools.showHashDialog(title: "SHA-512 Digest for \(doc.title)", hash: hash)
        }
    }
    @objc func menuSHA512FromFiles() {
        promptHashFromFiles(algorithmName: "SHA-512", compute: NppTools.sha512)
    }
    @objc func menuSHA512Selection() {
        if let tv = getActiveTextView() {
            let sel = tv.selectedRange()
            let text = sel.length > 0 ? (tv.string as NSString).substring(with: sel) : tv.string
            let hash = NppTools.sha512(data: text.data(using: .utf8) ?? Data())
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(hash, forType: .string)
            NppTools.showHashDialog(title: "SHA-512 Digest Copied to Clipboard", hash: hash)
        }
    }
    @objc func menuBase64Encode() {
        if let tv = getActiveTextView() {
            let sel = tv.selectedRange()
            guard sel.length > 0 else { return }
            let text = (tv.string as NSString).substring(with: sel)
            let enc = NppTools.base64Encode(string: text)
            tv.insertText(enc, replacementRange: sel)
        }
    }
    @objc func menuBase64Decode() {
        if let tv = getActiveTextView() {
            let sel = tv.selectedRange()
            guard sel.length > 0 else { return }
            let text = (tv.string as NSString).substring(with: sel)
            let dec = NppTools.base64Decode(string: text)
            tv.insertText(dec, replacementRange: sel)
        }
    }
    @objc func menuUrlEncode() {
        if let tv = getActiveTextView() {
            let sel = tv.selectedRange()
            guard sel.length > 0 else { return }
            let text = (tv.string as NSString).substring(with: sel)
            let enc = NppTools.urlEncode(string: text)
            tv.insertText(enc, replacementRange: sel)
        }
    }
    @objc func menuUrlDecode() {
        if let tv = getActiveTextView() {
            let sel = tv.selectedRange()
            guard sel.length > 0 else { return }
            let text = (tv.string as NSString).substring(with: sel)
            let dec = NppTools.urlDecode(string: text)
            tv.insertText(dec, replacementRange: sel)
        }
    }

    // Macro actions (NppCommands.cpp L1441-1506)
    @objc func menuMacroStart() {
        workspace.startMacroRecording()
    }
    @objc func menuMacroStop() {
        workspace.stopMacroRecording()
    }
    @objc func menuMacroPlayback() {
        workspace.playbackMacro()
    }
    @objc func menuMacroSave() {
        workspace.promptSaveCurrentRecordedMacro()
    }
    @objc func menuMacroRunMulti() {
        workspace.runMacroMultipleTimes()
    }
    @objc func menuRunSavedMacro(_ sender: NSMenuItem) {
        if let name = sender.representedObject as? String {
            workspace.selectedMacroToRun = name
            workspace.executeSavedMacro(named: name)
        }
    }
    @objc func menuMacroModifyShortcuts() {
        workspace.showShortcutMapper = true
    }

    // Run actions
    @objc func menuRunPrompt() {
        let alert = NSAlert()
        alert.messageText = "Run..."
        alert.informativeText = "The Program to Run:\n\nSpecial variables:\n  $(CURRENT_FILE) - Full path to active file\n  $(CURRENT_DIRECTORY) - Directory of active file\n  $(FILE_NAME) - File name with extension\n  $(NAME_PART) - File name without extension"
        alert.addButton(withTitle: "Run in Terminal")
        alert.addButton(withTitle: "Run in Background")
        alert.addButton(withTitle: "Cancel")

        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 340, height: 24))
        input.placeholderString = "e.g. python3 $(CURRENT_FILE)"
        input.stringValue = workspace.lastRunCommand.isEmpty ? "python3 $(CURRENT_FILE)" : workspace.lastRunCommand
        alert.accessoryView = input

        let response = alert.runModal()
        let command = input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !command.isEmpty else { return }

        if response == .alertFirstButtonReturn {
            workspace.executeRunCommand(command, inTerminal: true)
        } else if response == .alertSecondButtonReturn {
            workspace.executeRunCommand(command, inTerminal: false)
        }
    }
    @objc func menuLaunchSafari() {
        if let doc = workspace.activeDocument, let path = doc.filePath {
            if doc.isDirty { _ = doc.save(to: path) }
            NSWorkspace.shared.open(path)
        } else if let doc = workspace.activeDocument {
            let tempUrl = FileManager.default.temporaryDirectory.appendingPathComponent("\(doc.title).html")
            try? doc.content.write(to: tempUrl, atomically: true, encoding: .utf8)
            NSWorkspace.shared.open(tempUrl)
        }
    }
    @objc func menuLaunchChrome() {
        var targetUrl: URL?
        if let doc = workspace.activeDocument, let path = doc.filePath {
            if doc.isDirty { _ = doc.save(to: path) }
            targetUrl = path
        } else if let doc = workspace.activeDocument {
            let tempUrl = FileManager.default.temporaryDirectory.appendingPathComponent("\(doc.title).html")
            try? doc.content.write(to: tempUrl, atomically: true, encoding: .utf8)
            targetUrl = tempUrl
        }
        if let url = targetUrl {
            let conf = NSWorkspace.OpenConfiguration()
            if let chromeUrl = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.google.Chrome") {
                NSWorkspace.shared.open([url], withApplicationAt: chromeUrl, configuration: conf, completionHandler: nil)
            } else {
                NSWorkspace.shared.open(url)
            }
        }
    }
    @objc func menuSearchGoogle() {
        if let tv = getActiveTextView() {
            let sel = tv.selectedRange()
            guard sel.length > 0 else { return }
            let text = (tv.string as NSString).substring(with: sel)
            if let encoded = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
               let url = URL(string: "https://www.google.com/search?q=\(encoded)") {
                NSWorkspace.shared.open(url)
            }
        }
    }

    // Plugins actions
    @objc func menuAsciiToHex() {
        if let tv = getActiveTextView() {
            let sel = tv.selectedRange()
            let text = sel.length > 0 ? (tv.string as NSString).substring(with: sel) : tv.string
            let hex = NppTools.asciiToHex(string: text)
            if sel.length > 0 {
                tv.insertText(hex, replacementRange: sel)
            } else {
                tv.string = hex
                workspace.activeDocument?.content = hex
                workspace.activeDocument?.isDirty = true
            }
        }
    }

    @objc func menuHexToAscii() {
        if let tv = getActiveTextView() {
            let sel = tv.selectedRange()
            let text = sel.length > 0 ? (tv.string as NSString).substring(with: sel) : tv.string
            let ascii = NppTools.hexToAscii(string: text)
            if sel.length > 0 {
                tv.insertText(ascii, replacementRange: sel)
            } else {
                tv.string = ascii
                workspace.activeDocument?.content = ascii
                workspace.activeDocument?.isDirty = true
            }
        }
    }

    @objc func menuExportCopyRTF() {
        if let doc = workspace.activeDocument {
            NppTools.copyRTFToClipboard(text: doc.content, fontName: workspace.fontFamily, fontSize: workspace.fontSize)
        }
    }

    @objc func menuExportCopyHTML() {
        if let doc = workspace.activeDocument {
            NppTools.copyHTMLToClipboard(text: doc.content)
        }
    }

    // Window menu actions
    @objc func menuShowWindowsDialog() {
        workspace.showDocumentList = true
    }
    @objc func menuSortTabsNameAsc() { workspace.sortTabsByName(ascending: true) }
    @objc func menuSortTabsNameDesc() { workspace.sortTabsByName(ascending: false) }
    @objc func menuSortTabsPathAsc() { workspace.sortTabsByPath(ascending: true) }
    @objc func menuSortTabsPathDesc() { workspace.sortTabsByPath(ascending: false) }
    @objc func menuSortTabsTypeAsc() { workspace.sortTabsByType(ascending: true) }
    @objc func menuSortTabsTypeDesc() { workspace.sortTabsByType(ascending: false) }
    @objc func menuSortTabsSizeAsc() { workspace.sortTabsBySize(ascending: true) }
    @objc func menuSortTabsSizeDesc() { workspace.sortTabsBySize(ascending: false) }
    @objc func menuNextTab() {
        workspace.nextTab()
        updateWindowTitle()
    }
    @objc func menuPrevTab() {
        workspace.prevTab()
        updateWindowTitle()
    }
    @objc func menuMoveTabForward() { workspace.moveTabForward() }
    @objc func menuMoveTabBackward() { workspace.moveTabBackward() }

    // Help menu actions
    @objc func menuCmdArgs() {
        let alert = NSAlert()
        alert.messageText = "Notepad++ Command Line Arguments"
        alert.informativeText = "Usage: open -a Notepad++.app --args [options] [file1 file2 ...]\n\nOptions:\n  -n<line_number> : Go to specified line\n  -c<col_number>  : Go to specified column\n  -loadingTime    : Show launch time"
        alert.alertStyle = .informational
        alert.runModal()
    }
    @objc func menuNppHome() {
        if let url = URL(string: "https://notepad-plus-plus.org/") {
            NSWorkspace.shared.open(url)
        }
    }
    @objc func menuNppManual() {
        if let url = URL(string: "https://npp-user-manual.org/") {
            NSWorkspace.shared.open(url)
        }
    }
    @objc func menuNppForum() {
        if let url = URL(string: "https://community.notepad-plus-plus.org/") {
            NSWorkspace.shared.open(url)
        }
    }
    @objc func menuDebugInfo() {
        let alert = NSAlert()
        alert.messageText = "Debug Info"
        alert.informativeText = "Notepad++ for Mac v8.9.8.1 (64-bit ARM Mach-O)\nBuild time: Oct 2026\nSystem: macOS \(ProcessInfo.processInfo.operatingSystemVersionString)\nCore Engine: Notepad++ upstream v8.9.8.1 uchardet + iconv streaming\nUI Engine: Apple TextKit 2 + SwiftUI AppKit Bridge"
        alert.alertStyle = .informational
        alert.runModal()
    }

    @objc func showAbout() {
        let alert = NSAlert()
        alert.messageText = "Notepad++"
        alert.informativeText = "Notepad++ v8.9.8.1 (64-bit)\n\nOriginal Author: Don HO\nLicense: GNU General Public License (GPLv3)\nHome: https://notepad-plus-plus.org/"
        alert.alertStyle = .informational
        alert.runModal()
    }

    // MARK: - NSMenuItemValidation
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(menuToggleAlwaysOnTop(_:)) {
            menuItem.state = (window?.level == .floating) ? .on : .off
            return true
        }
        if menuItem.action == #selector(menuToggleWordWrap) {
            menuItem.state = workspace.isWordWrapEnabled ? .on : .off
            return true
        }
        if menuItem.action == #selector(menuOpenFolderFinder) || menuItem.action == #selector(menuOpenFolderTerminal) {
            return workspace.activeDocument?.filePath != nil
        }
        if menuItem.action == #selector(menuReload) || menuItem.action == #selector(menuMoveToTrash) {
            return workspace.activeDocument?.filePath != nil
        }
        let isDocReadOnly = (workspace.activeDocument == nil) || (workspace.activeDocument?.isReadOnly == true) || workspace.isAllDocumentsReadOnly
        let isEditable = !isDocReadOnly && (getActiveTextView()?.isEditable ?? true)

        // Macro menu validation matching Notepad_plus.cpp L2778-2783
        if menuItem.action == #selector(menuMacroStart) {
            return !workspace.isMacroRecording
        }
        if menuItem.action == #selector(menuMacroStop) {
            return workspace.isMacroRecording
        }
        if menuItem.action == #selector(menuMacroPlayback) {
            if !isEditable { return false }
            return workspace.canPlaybackMacro
        }
        if menuItem.action == #selector(menuMacroSave) {
            return workspace.canSaveRecordedMacro
        }
        if menuItem.action == #selector(menuMacroRunMulti) {
            if !isEditable { return false }
            return workspace.canRunMultiMacro
        }
        // Pass 2: Edit Menu Validation
        if menuItem.action == #selector(menuBeginEndSelect) {
            menuItem.state = (workspace.beginSelectAnchor != nil) ? .on : .off
            return workspace.activeDocument != nil
        }
        if menuItem.action == #selector(menuToggleReadOnlyCurrentDoc) {
            menuItem.state = (workspace.activeDocument?.isReadOnly == true) ? .on : .off
            return workspace.activeDocument != nil
        }
        if menuItem.action == #selector(menuSetReadOnlyAllDocs) {
            menuItem.state = workspace.isAllDocumentsReadOnly ? .on : .off
            return !workspace.documents.isEmpty
        }
        if menuItem.action == #selector(menuClearReadOnlyAllDocs) {
            return !workspace.documents.isEmpty
        }
        if menuItem.action == #selector(menuToggleCharacterPanel) {
            menuItem.state = workspace.showCharacterPanel ? .on : .off
            return true
        }
        if menuItem.action == #selector(menuToggleClipboardHistory) {
            menuItem.state = workspace.showClipboardHistory ? .on : .off
            return true
        }
        if menuItem.action == #selector(menuRedactSelection) {
            if !isEditable { return false }
            return (getActiveTextView()?.selectedRange().length ?? 0) > 0
        }
        if menuItem.action == #selector(menuSearchOnInternet) {
            return (getActiveTextView()?.selectedRange().length ?? 0) > 0
        }
        if menuItem.action == #selector(menuOpenSelectedFile) || menuItem.action == #selector(menuOpenSelectedFolderInFinder) {
            return workspace.activeDocument != nil
        }

        // EOL Conversion active checkmarks
        if menuItem.action == #selector(menuEolWindows) {
            menuItem.state = (workspace.activeDocument?.eolFormat == .crlf) ? .on : .off
            return !isDocReadOnly
        }
        if menuItem.action == #selector(menuEolUnix) {
            menuItem.state = (workspace.activeDocument?.eolFormat == .lf) ? .on : .off
            return !isDocReadOnly
        }
        if menuItem.action == #selector(menuEolMac) {
            menuItem.state = (workspace.activeDocument?.eolFormat == .cr) ? .on : .off
            return !isDocReadOnly
        }

        // Mutating Edit Operations: Strictly disabled when document is read-only or non-editable
        let mutatingEditActions: Set<Selector> = [
            #selector(NSText.cut(_:)),
            #selector(NSText.delete(_:)),
            #selector(NSText.paste(_:)),
            #selector(menuIncreaseLineIndent),
            #selector(menuDecreaseLineIndent),
            #selector(menuUppercase),
            #selector(menuLowercase),
            #selector(menuProperCase),
            #selector(menuProperCaseBlend),
            #selector(menuSentenceCase),
            #selector(menuSentenceCaseBlend),
            #selector(menuInvertCase),
            #selector(menuRandomCase),
            #selector(menuDupLine),
            #selector(menuRemoveDuplicateLines),
            #selector(menuRemoveConsecutiveDuplicateLines),
            #selector(menuSplitLines),
            #selector(menuJoinLines),
            #selector(menuMoveLineUp),
            #selector(menuMoveLineDown),
            #selector(menuInsertEmptyLineAbove),
            #selector(menuInsertEmptyLineBelow),
            #selector(menuRemoveEmptyLines),
            #selector(menuRemoveEmptyLinesContainingBlanks),
            #selector(menuReverseLines),
            #selector(menuRandomizeLineOrder),
            #selector(menuSortAscending),
            #selector(menuSortDescending),
            #selector(menuSortCaseInsensitiveAscending),
            #selector(menuSortCaseInsensitiveDescending),
            #selector(menuSortIntegersAscending),
            #selector(menuSortIntegersDescending),
            #selector(menuSortDecimalsDotAscending),
            #selector(menuSortDecimalsDotDescending),
            #selector(menuSortDecimalsCommaAscending),
            #selector(menuSortDecimalsCommaDescending),
            #selector(menuSortByLengthAscending),
            #selector(menuSortByLengthDescending),
            #selector(menuToggleComment),
            #selector(menuSingleLineComment),
            #selector(menuSingleLineUncomment),
            #selector(menuBlockComment),
            #selector(menuBlockUncomment),
            #selector(menuTrimTrailing),
            #selector(menuTrimLeading),
            #selector(menuTrimBoth),
            #selector(menuEolToSpace),
            #selector(menuTrimBothAndEolToSpace),
            #selector(menuTabToSpace),
            #selector(menuSpaceToTab),
            #selector(menuSpaceToTabAll),
            #selector(menuSpaceToTabLeading),
            #selector(menuInsertDateShort),
            #selector(menuInsertDateLong),
            #selector(menuInsertDateCustomized),
            #selector(menuCutBookmarkedLines),
            #selector(menuPasteBookmarkedLines),
            #selector(menuRemoveBookmarkedLines),
            #selector(menuRemoveNonBookmarkedLines)
        ]

        if let act = menuItem.action, mutatingEditActions.contains(act) {
            return isEditable
        }

        // Search menu checkmarks
        if menuItem.action == #selector(menuIncrementalSearch) {
            menuItem.state = workspace.showSearchBar ? .on : .off
            return true
        }
        if menuItem.action == #selector(menuSearchResultsWindow) {
            menuItem.state = workspace.showSearchResultsPanel ? .on : .off
            return true
        }

        // View menu checkmarks
        if menuItem.action == #selector(menuToggleFullScreen) {
            menuItem.state = workspace.isFullScreen ? .on : .off
            return true
        }
        if menuItem.action == #selector(menuTogglePostIt) {
            menuItem.state = workspace.isPostItMode ? .on : .off
            return true
        }
        if menuItem.action == #selector(menuToggleDistractionFree) {
            menuItem.state = workspace.isDistractionFreeMode ? .on : .off
            return true
        }
        if menuItem.action == #selector(menuToggleShowSpaceAndTab) {
            menuItem.state = (workspace.showSpaceAndTab || workspace.showInvisibleCharacters) ? .on : .off
            return true
        }
        if menuItem.action == #selector(menuToggleShowEndOfLine) {
            menuItem.state = (workspace.showEndOfLine || workspace.showInvisibleCharacters) ? .on : .off
            return true
        }
        if menuItem.action == #selector(menuToggleShowNonPrintingCharacters) {
            menuItem.state = (workspace.showNonPrintingCharacters || workspace.showInvisibleCharacters) ? .on : .off
            return true
        }
        if menuItem.action == #selector(menuToggleShowControlCharsAndUnicodeEol) {
            menuItem.state = workspace.showControlCharsAndUnicodeEol ? .on : .off
            return true
        }
        if menuItem.action == #selector(menuToggleShowAllCharacters) {
            menuItem.state = workspace.showInvisibleCharacters ? .on : .off
            return true
        }
        if menuItem.action == #selector(menuToggleShowIndentGuide) {
            menuItem.state = workspace.showIndentGuides ? .on : .off
            return true
        }
        if menuItem.action == #selector(menuToggleShowWrapSymbol) {
            menuItem.state = workspace.showWrapSymbol ? .on : .off
            return true
        }
        if menuItem.action == #selector(menuToggleDocumentList) {
            menuItem.state = workspace.showDocumentList ? .on : .off
            return true
        }
        if menuItem.action == #selector(menuToggleFolderAsWorkspace) {
            menuItem.state = workspace.showFolderAsWorkspace ? .on : .off
            return true
        }
        if menuItem.action == #selector(menuToggleFunctionList) {
            menuItem.state = workspace.showFunctionList ? .on : .off
            return true
        }
        if menuItem.action == #selector(menuToggleDocumentMap) {
            menuItem.state = workspace.showDocumentMap ? .on : .off
            return true
        }
        if menuItem.action == #selector(menuToggleMonitoring) {
            menuItem.state = (workspace.activeDocument?.isMonitoring == true) ? .on : .off
            return workspace.activeDocument != nil
        }
        if menuItem.action == #selector(menuApplyTabColor(_:)) {
            let currentColor = workspace.activeDocument?.tabColorId ?? 0
            menuItem.state = (menuItem.tag == currentColor && menuItem.tag > 0) ? .on : .off
            return workspace.activeDocument != nil
        }
        if menuItem.action == #selector(menuSelectTabByIndex(_:)) {
            let idx = menuItem.tag
            if idx >= 0 && idx < workspace.documents.count {
                menuItem.state = (workspace.documents[idx].id == workspace.activeDocumentId) ? .on : .off
                return true
            } else {
                menuItem.state = .off
                return false
            }
        }

        // Encoding menu active checkmarks
        if let doc = workspace.activeDocument {
            let enc = doc.encoding.uppercased()
            let bom = doc.hasBOM
            if menuItem.action == #selector(menuEncodeAnsi) {
                menuItem.state = (enc == "WINDOWS-1252" || enc == "ANSI") ? .on : .off
                return true
            }
            if menuItem.action == #selector(menuEncodeUtf8) {
                menuItem.state = (enc == "UTF-8" && !bom) ? .on : .off
                return true
            }
            if menuItem.action == #selector(menuEncodeUtf8Bom) {
                menuItem.state = ((enc == "UTF-8" && bom) || enc == "UTF-8-BOM") ? .on : .off
                return true
            }
            if menuItem.action == #selector(menuEncodeUtf16BE) {
                menuItem.state = (enc == "UTF-16BE") ? .on : .off
                return true
            }
            if menuItem.action == #selector(menuEncodeUtf16LE) {
                menuItem.state = (enc == "UTF-16LE") ? .on : .off
                return true
            }
            if menuItem.action == #selector(menuEncodeCP949) {
                menuItem.state = (enc == "CP949") ? .on : .off
                return true
            }
            if menuItem.action == #selector(menuEncodeEucKr) {
                menuItem.state = (enc == "EUC-KR") ? .on : .off
                return true
            }
            if menuItem.action == #selector(menuEncodeShiftJis) {
                menuItem.state = (enc == "CP932" || enc == "SHIFT-JIS") ? .on : .off
                return true
            }
            if menuItem.action == #selector(menuEncodeGB18030) {
                menuItem.state = (enc == "GB18030" || enc == "GB2312") ? .on : .off
                return true
            }
            if menuItem.action == #selector(menuEncodeBig5) {
                menuItem.state = (enc == "BIG5") ? .on : .off
                return true
            }

            // Language menu active checkmarks
            if menuItem.action == #selector(menuSetLangPlainText) {
                menuItem.state = (doc.language == "Plain Text" || doc.language == "Normal Text") ? .on : .off
                return true
            }
            if menuItem.action == #selector(menuSelectLanguage(_:)) {
                let itemLang = (menuItem.representedObject as? String) ?? menuItem.title
                menuItem.state = (doc.language == itemLang) ? .on : .off
                return true
            }
        }
        return true
    }
}

// MARK: - Command Line Argument Parser (command-prompt.md)
public struct NppCommandLineParser {
    public struct ParsedArgs {
        public var line: Int?
        public var column: Int?
        public var language: String?
        public var isReadOnly: Bool = false
        public var localization: String?
        public var runTests: Bool = false
        public var files: [String] = []
    }

    public static func parseArgs(_ args: [String]) -> ParsedArgs {
        var parsed = ParsedArgs()
        var i = 0
        // If args has executable at 0, handle both full CommandLine.arguments and isolated arguments
        if args.count > 0 && !args[0].hasPrefix("-") && (args[0].hasSuffix("NotepadPlusPlusMac") || args[0].hasSuffix("Notepad++") || args[0].contains("/")) {
            i = 1
        }

        while i < args.count {
            let arg = args[i]
            if arg == "--run-tests" {
                parsed.runTests = true
            } else if arg.hasPrefix("-n") {
                let rest = String(arg.dropFirst(2))
                if !rest.isEmpty {
                    parsed.line = Int(rest)
                } else if i + 1 < args.count {
                    i += 1
                    parsed.line = Int(args[i])
                }
            } else if arg.hasPrefix("-c") {
                let rest = String(arg.dropFirst(2))
                if !rest.isEmpty {
                    parsed.column = Int(rest)
                } else if i + 1 < args.count {
                    i += 1
                    parsed.column = Int(args[i])
                }
            } else if arg.hasPrefix("-l") {
                let rest = String(arg.dropFirst(2))
                if !rest.isEmpty {
                    parsed.language = rest
                } else if i + 1 < args.count {
                    i += 1
                    parsed.language = args[i]
                }
            } else if arg == "-ro" {
                parsed.isReadOnly = true
            } else if arg.hasPrefix("-L") {
                let langCode = String(arg.dropFirst(2)).lowercased()
                parsed.localization = langCode
            } else if !arg.hasPrefix("-") {
                parsed.files.append(arg)
            }
            i += 1
        }
        return parsed
    }

    public static func parse(_ args: [String], workspace: NppWorkspace) {
        let parsed = parseArgs(args)

        if let loc = parsed.localization {
            if loc == "ko" || loc == "kr" {
                workspace.localizationLanguage = "한국어"
            } else if loc == "en" {
                workspace.localizationLanguage = "English"
            }
        }

        for path in parsed.files {
            let url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
            workspace.openFile(url: url)
        }

        if let doc = workspace.activeDocument {
            if parsed.isReadOnly {
                doc.isReadOnly = true
            }
            if let lang = parsed.language {
                doc.language = lang
            }
            if let line = parsed.line {
                workspace.jumpToLine(line)
                if let col = parsed.column {
                    doc.cursorCol = max(1, col)
                }
            }
        }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
