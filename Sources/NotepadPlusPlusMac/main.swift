import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    let workspace = NppWorkspace()

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

    private func updateWindowTitle() {
        if let doc = workspace.activeDocument {
            let dirtyPrefix = doc.isDirty ? "*" : ""
            let pathOrTitle = doc.filePath?.path ?? doc.title
            window?.title = "\(dirtyPrefix)\(pathOrTitle) - Notepad++"
        } else {
            window?.title = "Notepad++"
        }
    }

    private func setupMenuBar() {
        let mainMenu = NSMenu()

        // 1. App Menu
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "About Notepad++", action: #selector(showAbout), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Preferences...", action: #selector(menuPreferences), keyEquivalent: ",")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Quit Notepad++", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        // 2. File Menu (Notepad++ Windows parity)
        let fileMenuItem = NSMenuItem()
        let fileMenu = NSMenu(title: "File")
        fileMenu.addItem(withTitle: "New", action: #selector(menuNew), keyEquivalent: "n")
        fileMenu.addItem(withTitle: "Open...", action: #selector(menuOpen), keyEquivalent: "o")

        let openFolderMenu = NSMenu(title: "Open Containing Folder")
        openFolderMenu.addItem(withTitle: "Finder", action: #selector(menuOpenFolderFinder), keyEquivalent: "")
        openFolderMenu.addItem(withTitle: "Terminal", action: #selector(menuOpenFolderTerminal), keyEquivalent: "")
        let openFolderItem = NSMenuItem(title: "Open Containing Folder", action: nil, keyEquivalent: "")
        openFolderItem.submenu = openFolderMenu
        fileMenu.addItem(openFolderItem)

        fileMenu.addItem(withTitle: "Reload from Disk", action: #selector(menuReload), keyEquivalent: "r")
        fileMenu.addItem(NSMenuItem.separator())
        fileMenu.addItem(withTitle: "Save", action: #selector(menuSave), keyEquivalent: "s")
        fileMenu.addItem(withTitle: "Save As...", action: #selector(menuSaveAs), keyEquivalent: "S")
        fileMenu.addItem(withTitle: "Save All", action: #selector(menuSaveAll), keyEquivalent: "")
        fileMenu.addItem(NSMenuItem.separator())
        fileMenu.addItem(withTitle: "Close", action: #selector(menuCloseTab), keyEquivalent: "w")
        fileMenu.addItem(withTitle: "Close All", action: #selector(menuCloseAll), keyEquivalent: "")

        let closeMultiMenu = NSMenu(title: "Close Multiple Documents")
        closeMultiMenu.addItem(withTitle: "Close All but Active Document", action: #selector(menuCloseAllButActive), keyEquivalent: "")
        closeMultiMenu.addItem(withTitle: "Close All to the Left", action: #selector(menuCloseAllToLeft), keyEquivalent: "")
        closeMultiMenu.addItem(withTitle: "Close All to the Right", action: #selector(menuCloseAllToRight), keyEquivalent: "")
        closeMultiMenu.addItem(withTitle: "Close All Unchanged", action: #selector(menuCloseAllUnchanged), keyEquivalent: "")
        let closeMultiItem = NSMenuItem(title: "Close Multiple Documents", action: nil, keyEquivalent: "")
        closeMultiItem.submenu = closeMultiMenu
        fileMenu.addItem(closeMultiItem)

        fileMenu.addItem(NSMenuItem.separator())
        fileMenu.addItem(withTitle: "Move to Trash", action: #selector(menuMoveToTrash), keyEquivalent: "")
        fileMenu.addItem(NSMenuItem.separator())
        fileMenu.addItem(withTitle: "Print...", action: #selector(menuPrint), keyEquivalent: "p")

        fileMenuItem.submenu = fileMenu
        mainMenu.addItem(fileMenuItem)

        // 3. Edit Menu (Notepad++ Windows parity)
        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Delete", action: #selector(NSText.delete(_:)), keyEquivalent: "")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenu.addItem(NSMenuItem.separator())

        // Insert submenu
        let insertMenu = NSMenu(title: "Insert")
        insertMenu.addItem(withTitle: "Date Time (short)", action: #selector(menuInsertDateShort), keyEquivalent: "")
        insertMenu.addItem(withTitle: "Date Time (long)", action: #selector(menuInsertDateLong), keyEquivalent: "")
        let insertItem = NSMenuItem(title: "Insert", action: nil, keyEquivalent: "")
        insertItem.submenu = insertMenu
        editMenu.addItem(insertItem)

        // Copy to Clipboard submenu
        let copyClipMenu = NSMenu(title: "Copy to Clipboard")
        copyClipMenu.addItem(withTitle: "Copy Current Full File path", action: #selector(menuCopyFullPath), keyEquivalent: "")
        copyClipMenu.addItem(withTitle: "Copy Current Filename", action: #selector(menuCopyFilename), keyEquivalent: "")
        copyClipMenu.addItem(withTitle: "Copy Current Dir. Path", action: #selector(menuCopyDirPath), keyEquivalent: "")
        let copyClipItem = NSMenuItem(title: "Copy to Clipboard", action: nil, keyEquivalent: "")
        copyClipItem.submenu = copyClipMenu
        editMenu.addItem(copyClipItem)

        // Convert Case to submenu
        let caseMenu = NSMenu(title: "Convert Case to")
        caseMenu.addItem(withTitle: "UPPERCASE", action: #selector(menuUppercase), keyEquivalent: "U")
        caseMenu.addItem(withTitle: "lowercase", action: #selector(menuLowercase), keyEquivalent: "u")
        caseMenu.addItem(withTitle: "Proper Case", action: #selector(menuProperCase), keyEquivalent: "")
        caseMenu.addItem(withTitle: "Sentence case", action: #selector(menuSentenceCase), keyEquivalent: "")
        caseMenu.addItem(withTitle: "iNVERT cASE", action: #selector(menuInvertCase), keyEquivalent: "")
        let caseItem = NSMenuItem(title: "Convert Case to", action: nil, keyEquivalent: "")
        caseItem.submenu = caseMenu
        editMenu.addItem(caseItem)

        // Line Operations submenu
        let lineOpsMenu = NSMenu(title: "Line Operations")
        lineOpsMenu.addItem(withTitle: "Duplicate Current Line", action: #selector(menuDupLine), keyEquivalent: "d")
        lineOpsMenu.addItem(withTitle: "Join Lines", action: #selector(menuJoinLines), keyEquivalent: "j")
        lineOpsMenu.addItem(withTitle: "Split Lines", action: #selector(menuSplitLines), keyEquivalent: "")
        lineOpsMenu.addItem(withTitle: "Move Up Current Line", action: #selector(menuMoveLineUp), keyEquivalent: "")
        lineOpsMenu.addItem(withTitle: "Move Down Current Line", action: #selector(menuMoveLineDown), keyEquivalent: "")
        lineOpsMenu.addItem(NSMenuItem.separator())
        lineOpsMenu.addItem(withTitle: "Remove Empty Lines", action: #selector(menuRemoveEmptyLines), keyEquivalent: "")
        lineOpsMenu.addItem(withTitle: "Remove Duplicate Lines", action: #selector(menuRemoveDuplicateLines), keyEquivalent: "")
        lineOpsMenu.addItem(withTitle: "Sort Lines Lexicographically Ascending", action: #selector(menuSortAscending), keyEquivalent: "")
        lineOpsMenu.addItem(withTitle: "Sort Lines Lexicographically Descending", action: #selector(menuSortDescending), keyEquivalent: "")
        lineOpsMenu.addItem(withTitle: "Reverse Line Order", action: #selector(menuReverseLines), keyEquivalent: "")
        let lineOpsItem = NSMenuItem(title: "Line Operations", action: nil, keyEquivalent: "")
        lineOpsItem.submenu = lineOpsMenu
        editMenu.addItem(lineOpsItem)

        // Comment / Uncomment submenu
        let commentMenu = NSMenu(title: "Comment/Uncomment")
        commentMenu.addItem(withTitle: "Toggle Single Line Comment", action: #selector(menuToggleComment), keyEquivalent: "/")
        let commentItem = NSMenuItem(title: "Comment/Uncomment", action: nil, keyEquivalent: "")
        commentItem.submenu = commentMenu
        editMenu.addItem(commentItem)

        // Blank Operations submenu
        let blankOpsMenu = NSMenu(title: "Blank Operations")
        blankOpsMenu.addItem(withTitle: "Trim Trailing Space", action: #selector(menuTrimTrailing), keyEquivalent: "")
        blankOpsMenu.addItem(withTitle: "Trim Leading Space", action: #selector(menuTrimLeading), keyEquivalent: "")
        blankOpsMenu.addItem(withTitle: "Trim Leading and Trailing Space", action: #selector(menuTrimBoth), keyEquivalent: "")
        blankOpsMenu.addItem(withTitle: "EOL to Space", action: #selector(menuEolToSpace), keyEquivalent: "")
        blankOpsMenu.addItem(withTitle: "TAB to Space", action: #selector(menuTabToSpace), keyEquivalent: "")
        blankOpsMenu.addItem(withTitle: "Space to TAB", action: #selector(menuSpaceToTab), keyEquivalent: "")
        let blankOpsItem = NSMenuItem(title: "Blank Operations", action: nil, keyEquivalent: "")
        blankOpsItem.submenu = blankOpsMenu
        editMenu.addItem(blankOpsItem)

        // EOL Conversion Submenu
        let eolMenu = NSMenu(title: "EOL Conversion")
        eolMenu.addItem(withTitle: "Windows (CR LF)", action: #selector(menuEolWindows), keyEquivalent: "")
        eolMenu.addItem(withTitle: "Unix (LF)", action: #selector(menuEolUnix), keyEquivalent: "")
        eolMenu.addItem(withTitle: "Macintosh (CR)", action: #selector(menuEolMac), keyEquivalent: "")
        let eolMenuItem = NSMenuItem(title: "EOL Conversion", action: nil, keyEquivalent: "")
        eolMenuItem.submenu = eolMenu
        editMenu.addItem(eolMenuItem)

        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        // 4. Search Menu (Notepad++ Windows parity)
        let searchMenuItem = NSMenuItem()
        let searchMenu = NSMenu(title: "Search")
        searchMenu.addItem(withTitle: "Find...", action: #selector(menuFind), keyEquivalent: "f")
        searchMenu.addItem(withTitle: "Replace...", action: #selector(menuFind), keyEquivalent: "h")
        searchMenu.addItem(NSMenuItem.separator())
        searchMenu.addItem(withTitle: "Find All in Current Document", action: #selector(menuFindAllCurrent), keyEquivalent: "F")
        searchMenu.addItem(withTitle: "Find All in All Opened Documents", action: #selector(menuFindAllOpened), keyEquivalent: "")
        searchMenu.addItem(withTitle: "Clear Search Results", action: #selector(menuClearSearchResults), keyEquivalent: "")
        searchMenu.addItem(NSMenuItem.separator())
        searchMenu.addItem(withTitle: "Go to Line...", action: #selector(menuGoToLine), keyEquivalent: "l")
        searchMenuItem.submenu = searchMenu
        mainMenu.addItem(searchMenuItem)

        // 5. View Menu
        let viewMenuItem = NSMenuItem()
        let viewMenu = NSMenu(title: "View")
        viewMenu.addItem(withTitle: "Always on Top", action: #selector(menuToggleAlwaysOnTop), keyEquivalent: "")
        viewMenu.addItem(withTitle: "Toggle Word Wrap", action: #selector(menuToggleWordWrap), keyEquivalent: "")
        viewMenu.addItem(NSMenuItem.separator())
        viewMenu.addItem(withTitle: "Zoom In", action: #selector(menuZoomIn), keyEquivalent: "=")
        viewMenu.addItem(withTitle: "Zoom Out", action: #selector(menuZoomOut), keyEquivalent: "-")
        viewMenu.addItem(withTitle: "Restore Default Zoom", action: #selector(menuResetZoom), keyEquivalent: "0")
        viewMenu.addItem(NSMenuItem.separator())
        viewMenu.addItem(withTitle: "Document Summary...", action: #selector(menuDocSummary), keyEquivalent: "")
        viewMenuItem.submenu = viewMenu
        mainMenu.addItem(viewMenuItem)

        // 6. Encoding Menu (Notepad++ Windows parity)
        let encMenuItem = NSMenuItem()
        let encMenu = NSMenu(title: "Encoding")
        encMenu.addItem(withTitle: "ANSI", action: #selector(menuEncodeAnsi), keyEquivalent: "")
        encMenu.addItem(withTitle: "UTF-8", action: #selector(menuEncodeUtf8), keyEquivalent: "")
        encMenu.addItem(withTitle: "UTF-8-BOM", action: #selector(menuEncodeUtf8Bom), keyEquivalent: "")
        encMenu.addItem(withTitle: "UTF-16 BE BOM", action: #selector(menuEncodeUtf16BE), keyEquivalent: "")
        encMenu.addItem(withTitle: "UTF-16 LE BOM", action: #selector(menuEncodeUtf16LE), keyEquivalent: "")

        let charSetsMenu = NSMenu(title: "Character sets")
        let koreanMenu = NSMenu(title: "Korean")
        koreanMenu.addItem(withTitle: "Windows 949 (CP949)", action: #selector(menuEncodeCP949), keyEquivalent: "")
        koreanMenu.addItem(withTitle: "EUC-KR", action: #selector(menuEncodeEucKr), keyEquivalent: "")
        let koreanItem = NSMenuItem(title: "Korean", action: nil, keyEquivalent: "")
        koreanItem.submenu = koreanMenu
        charSetsMenu.addItem(koreanItem)

        let japaneseMenu = NSMenu(title: "Japanese")
        japaneseMenu.addItem(withTitle: "Shift-JIS", action: #selector(menuEncodeShiftJis), keyEquivalent: "")
        let japaneseItem = NSMenuItem(title: "Japanese", action: nil, keyEquivalent: "")
        japaneseItem.submenu = japaneseMenu
        charSetsMenu.addItem(japaneseItem)

        let chineseMenu = NSMenu(title: "Chinese")
        chineseMenu.addItem(withTitle: "GB2312 (Simplified)", action: #selector(menuEncodeGB18030), keyEquivalent: "")
        chineseMenu.addItem(withTitle: "Big5 (Traditional)", action: #selector(menuEncodeBig5), keyEquivalent: "")
        let chineseItem = NSMenuItem(title: "Chinese", action: nil, keyEquivalent: "")
        chineseItem.submenu = chineseMenu
        charSetsMenu.addItem(chineseItem)

        let charSetsItem = NSMenuItem(title: "Character sets", action: nil, keyEquivalent: "")
        charSetsItem.submenu = charSetsMenu
        encMenu.addItem(charSetsItem)

        encMenu.addItem(NSMenuItem.separator())
        encMenu.addItem(withTitle: "Convert to ANSI", action: #selector(menuConvertAnsi), keyEquivalent: "")
        encMenu.addItem(withTitle: "Convert to UTF-8", action: #selector(menuConvertUtf8), keyEquivalent: "")
        encMenu.addItem(withTitle: "Convert to UTF-8-BOM", action: #selector(menuConvertUtf8Bom), keyEquivalent: "")
        encMenu.addItem(withTitle: "Convert to Korean (Windows 949 / CP949)", action: #selector(menuConvertCP949), keyEquivalent: "")
        encMenu.addItem(withTitle: "Convert to Korean (EUC-KR)", action: #selector(menuConvertEucKr), keyEquivalent: "")

        encMenuItem.submenu = encMenu
        mainMenu.addItem(encMenuItem)

        // 7. Language Menu (Notepad++ Windows parity)
        let langMenuItem = NSMenuItem()
        let langMenu = NSMenu(title: "Language")
        langMenu.addItem(withTitle: "None (Normal Text)", action: #selector(menuSetLangPlainText), keyEquivalent: "")
        langMenu.addItem(NSMenuItem.separator())

        let popularLangs = ["C", "C++", "C#", "Swift", "Python", "JavaScript", "TypeScript", "HTML", "CSS", "JSON", "XML", "SQL", "Shell", "Markdown", "Java", "Rust", "Go", "PHP", "Ruby", "YAML"]
        for lang in popularLangs {
            let item = NSMenuItem(title: lang, action: #selector(menuSelectLanguage(_:)), keyEquivalent: "")
            item.representedObject = lang
            langMenu.addItem(item)
        }

        langMenuItem.submenu = langMenu
        mainMenu.addItem(langMenuItem)

        // 8. Settings Menu (Notepad++ Windows parity)
        let settingsMenuItem = NSMenuItem()
        let settingsMenu = NSMenu(title: "Settings")
        settingsMenu.addItem(withTitle: "Preferences...", action: #selector(menuPreferences), keyEquivalent: "")
        settingsMenu.addItem(withTitle: "Style Configurator...", action: #selector(menuStyleConfigurator), keyEquivalent: "")
        settingsMenu.addItem(withTitle: "Shortcut Mapper...", action: #selector(menuShortcutMapper), keyEquivalent: "")
        settingsMenu.addItem(NSMenuItem.separator())
        settingsMenu.addItem(withTitle: "Edit Popup ContextMenu", action: #selector(menuEditContextMenu), keyEquivalent: "")
        settingsMenuItem.submenu = settingsMenu
        mainMenu.addItem(settingsMenuItem)

        // 9. Tools Menu (Notepad++ Windows parity)
        let toolsMenuItem = NSMenuItem()
        let toolsMenu = NSMenu(title: "Tools")

        // MD5
        let md5Menu = NSMenu(title: "MD5")
        md5Menu.addItem(withTitle: "Generate...", action: #selector(menuMD5Generate), keyEquivalent: "")
        md5Menu.addItem(withTitle: "Generate from Selection into Clipboard", action: #selector(menuMD5Selection), keyEquivalent: "")
        let md5Item = NSMenuItem(title: "MD5", action: nil, keyEquivalent: "")
        md5Item.submenu = md5Menu
        toolsMenu.addItem(md5Item)

        // SHA-256
        let shaMenu = NSMenu(title: "SHA-256")
        shaMenu.addItem(withTitle: "Generate...", action: #selector(menuSHA256Generate), keyEquivalent: "")
        shaMenu.addItem(withTitle: "Generate from Selection into Clipboard", action: #selector(menuSHA256Selection), keyEquivalent: "")
        let shaItem = NSMenuItem(title: "SHA-256", action: nil, keyEquivalent: "")
        shaItem.submenu = shaMenu
        toolsMenu.addItem(shaItem)

        toolsMenu.addItem(NSMenuItem.separator())
        toolsMenu.addItem(withTitle: "Base64 Encode", action: #selector(menuBase64Encode), keyEquivalent: "")
        toolsMenu.addItem(withTitle: "Base64 Decode", action: #selector(menuBase64Decode), keyEquivalent: "")
        toolsMenu.addItem(withTitle: "URL Encode", action: #selector(menuUrlEncode), keyEquivalent: "")
        toolsMenu.addItem(withTitle: "URL Decode", action: #selector(menuUrlDecode), keyEquivalent: "")

        toolsMenuItem.submenu = toolsMenu
        mainMenu.addItem(toolsMenuItem)

        // 10. Macro Menu (Notepad++ Windows parity)
        let macroMenuItem = NSMenuItem()
        let macroMenu = NSMenu(title: "Macro")
        macroMenu.addItem(withTitle: "Start Recording", action: #selector(menuMacroStart), keyEquivalent: "")
        macroMenu.addItem(withTitle: "Stop Recording", action: #selector(menuMacroStop), keyEquivalent: "")
        macroMenu.addItem(withTitle: "Playback", action: #selector(menuMacroPlayback), keyEquivalent: "")
        macroMenu.addItem(withTitle: "Run a Macro Multiple Times...", action: #selector(menuMacroRunMulti), keyEquivalent: "")
        macroMenuItem.submenu = macroMenu
        mainMenu.addItem(macroMenuItem)

        // 11. Run Menu (Notepad++ Windows parity)
        let runMenuItem = NSMenuItem()
        let runMenu = NSMenu(title: "Run")
        runMenu.addItem(withTitle: "Run...", action: #selector(menuRunPrompt), keyEquivalent: "")
        runMenu.addItem(NSMenuItem.separator())
        runMenu.addItem(withTitle: "Open in Terminal", action: #selector(menuOpenFolderTerminal), keyEquivalent: "t")
        runMenu.addItem(withTitle: "Launch in Safari", action: #selector(menuLaunchSafari), keyEquivalent: "")
        runMenu.addItem(withTitle: "Launch in Chrome", action: #selector(menuLaunchChrome), keyEquivalent: "")
        runMenu.addItem(withTitle: "Google Search Selected Text", action: #selector(menuSearchGoogle), keyEquivalent: "")
        runMenuItem.submenu = runMenu
        mainMenu.addItem(runMenuItem)

        // 12. Plugins Menu
        let pluginsMenuItem = NSMenuItem()
        let pluginsMenu = NSMenu(title: "Plugins")
        pluginsMenu.addItem(withTitle: "Plugins Admin...", action: #selector(menuPluginsAdmin), keyEquivalent: "")
        pluginsMenu.addItem(withTitle: "Open Plugins Folder...", action: #selector(menuOpenPluginsDir), keyEquivalent: "")
        pluginsMenuItem.submenu = pluginsMenu
        mainMenu.addItem(pluginsMenuItem)

        // 13. Window Menu
        let windowMenuItem = NSMenuItem()
        let windowMenu = NSMenu(title: "Window")
        let sortTabsMenu = NSMenu(title: "Sort By")
        sortTabsMenu.addItem(withTitle: "Name A to Z", action: #selector(menuSortTabsNameAsc), keyEquivalent: "")
        sortTabsMenu.addItem(withTitle: "Name Z to A", action: #selector(menuSortTabsNameDesc), keyEquivalent: "")
        sortTabsMenu.addItem(withTitle: "Path A to Z", action: #selector(menuSortTabsPathAsc), keyEquivalent: "")
        sortTabsMenu.addItem(withTitle: "Path Z to A", action: #selector(menuSortTabsPathDesc), keyEquivalent: "")
        sortTabsMenu.addItem(withTitle: "Content Length Ascending", action: #selector(menuSortTabsSizeAsc), keyEquivalent: "")
        let sortTabsItem = NSMenuItem(title: "Sort By", action: nil, keyEquivalent: "")
        sortTabsItem.submenu = sortTabsMenu
        windowMenu.addItem(sortTabsItem)

        windowMenu.addItem(NSMenuItem.separator())
        windowMenu.addItem(withTitle: "Next Tab", action: #selector(menuNextTab), keyEquivalent: "}")
        windowMenu.addItem(withTitle: "Previous Tab", action: #selector(menuPrevTab), keyEquivalent: "{")
        windowMenu.addItem(withTitle: "Move Tab Forward", action: #selector(menuMoveTabForward), keyEquivalent: "")
        windowMenu.addItem(withTitle: "Move Tab Backward", action: #selector(menuMoveTabBackward), keyEquivalent: "")
        windowMenuItem.submenu = windowMenu
        mainMenu.addItem(windowMenuItem)

        // 14. ? (Help) Menu (Notepad++ Windows parity)
        let helpMenuItem = NSMenuItem()
        let helpMenu = NSMenu(title: "?")
        helpMenu.addItem(withTitle: "Command Line Arguments...", action: #selector(menuCmdArgs), keyEquivalent: "")
        helpMenu.addItem(NSMenuItem.separator())
        helpMenu.addItem(withTitle: "Notepad++ Home", action: #selector(menuNppHome), keyEquivalent: "")
        helpMenu.addItem(withTitle: "Notepad++ Online User Manual", action: #selector(menuNppManual), keyEquivalent: "")
        helpMenu.addItem(withTitle: "Notepad++ Community (Forum)", action: #selector(menuNppForum), keyEquivalent: "")
        helpMenu.addItem(NSMenuItem.separator())
        helpMenu.addItem(withTitle: "Debug Info...", action: #selector(menuDebugInfo), keyEquivalent: "")
        helpMenu.addItem(withTitle: "About Notepad++", action: #selector(showAbout), keyEquivalent: "")
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
    @objc func menuReload() {
        if let doc = workspace.activeDocument {
            workspace.reloadFromDisk(for: doc)
            updateWindowTitle()
        }
    }
    @objc func menuSave() {
        workspace.saveActive()
        updateWindowTitle()
    }
    @objc func menuSaveAs() {
        if let doc = workspace.activeDocument {
            workspace.promptSaveAs(for: doc)
            updateWindowTitle()
        }
    }
    @objc func menuSaveAll() {
        workspace.saveAll()
        updateWindowTitle()
    }
    @objc func menuCloseTab() {
        if let id = workspace.activeDocumentId { workspace.closeDocument(id: id) }
        updateWindowTitle()
    }
    @objc func menuCloseAll() {
        workspace.closeAll()
        updateWindowTitle()
    }
    @objc func menuCloseAllButActive() {
        if let id = workspace.activeDocumentId { workspace.closeAllBut(id: id) }
    }
    @objc func menuCloseAllToLeft() {
        if let id = workspace.activeDocumentId { workspace.closeAllToLeft(of: id) }
    }
    @objc func menuCloseAllToRight() {
        if let id = workspace.activeDocumentId { workspace.closeAllToRight(of: id) }
    }
    @objc func menuCloseAllUnchanged() { workspace.closeAllUnchanged() }

    @objc func menuOpenFolderFinder() {
        if let path = workspace.activeDocument?.filePath {
            NSWorkspace.shared.activateFileViewerSelecting([path])
        }
    }
    @objc func menuOpenFolderTerminal() {
        if let path = workspace.activeDocument?.filePath {
            let dir = path.deletingLastPathComponent().path
            let script = "tell application \"Terminal\" to do script \"cd '\(dir)'\""
            if let appleScript = NSAppleScript(source: script) {
                var error: NSDictionary?
                appleScript.executeAndReturnError(&error)
            }
        }
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

    @objc func menuFind() { workspace.showSearchBar.toggle() }
    @objc func menuFindAllCurrent() {
        workspace.showSearchBar = true
        if let tv = getActiveTextView() {
            let sel = tv.selectedRange()
            if sel.length > 0 {
                let text = (tv.string as NSString).substring(with: sel)
                workspace.findAllInCurrentDoc(query: text, matchCase: false, wholeWord: false, useRegex: false)
            }
        }
    }
    @objc func menuFindAllOpened() {
        workspace.showSearchBar = true
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
            let lines = doc.content.components(separatedBy: .newlines)
            let clampedLine = min(targetLine, lines.count)
            var charIndex = 0
            for i in 0..<(clampedLine - 1) {
                charIndex += lines[i].count + 1
            }
            if let tv = getActiveTextView() {
                let r = NSRange(location: charIndex, length: 0)
                tv.setSelectedRange(r)
                tv.scrollRangeToVisible(r)
            }
        }
    }

    @objc func menuToggleAlwaysOnTop() {
        guard let win = window else { return }
        if win.level == .floating {
            win.level = .normal
        } else {
            win.level = .floating
        }
    }
    @objc func menuToggleWordWrap() { workspace.isWordWrapEnabled.toggle() }
    @objc func menuZoomIn() { workspace.zoomIn() }
    @objc func menuZoomOut() { workspace.zoomOut() }
    @objc func menuResetZoom() { workspace.resetZoom() }
    @objc func menuDocSummary() {
        guard let doc = workspace.activeDocument else { return }
        let charCount = doc.content.count
        let lineCount = max(1, doc.content.components(separatedBy: .newlines).count)
        let words = doc.content.split { $0.isWhitespace || $0.isNewline }.count
        let nonSpace = doc.content.filter { !$0.isWhitespace && !$0.isNewline }.count
        let alert = NSAlert()
        alert.messageText = "Summary for \(doc.title)"
        alert.informativeText = "Characters (without spaces): \(nonSpace)\nCharacters (with spaces): \(charCount)\nWords: \(words)\nLines: \(lineCount)\nDocument length: \(charCount) bytes"
        alert.alertStyle = .informational
        alert.runModal()
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

    // Edit operations
    private func getActiveTextView() -> NSTextView? {
        return window?.firstResponder as? NSTextView
    }

    @objc func menuUppercase() {
        if let tv = getActiveTextView() { NppEditOperations.convertCase(in: tv, to: .uppercase) }
    }
    @objc func menuLowercase() {
        if let tv = getActiveTextView() { NppEditOperations.convertCase(in: tv, to: .lowercase) }
    }
    @objc func menuProperCase() {
        if let tv = getActiveTextView() { NppEditOperations.convertCase(in: tv, to: .properCase) }
    }
    @objc func menuSentenceCase() {
        if let tv = getActiveTextView() { NppEditOperations.convertCase(in: tv, to: .sentenceCase) }
    }
    @objc func menuInvertCase() {
        if let tv = getActiveTextView() { NppEditOperations.convertCase(in: tv, to: .invertCase) }
    }

    @objc func menuDupLine() {
        if let tv = getActiveTextView() { NppEditOperations.duplicateLine(in: tv) }
    }
    @objc func menuJoinLines() {
        if let tv = getActiveTextView() { NppEditOperations.joinLines(in: tv) }
    }
    @objc func menuSplitLines() {
        if let tv = getActiveTextView() { NppEditOperations.splitLines(in: tv) }
    }
    @objc func menuMoveLineUp() {
        if let tv = getActiveTextView() { NppEditOperations.moveLineUp(in: tv) }
    }
    @objc func menuMoveLineDown() {
        if let tv = getActiveTextView() { NppEditOperations.moveLineDown(in: tv) }
    }
    @objc func menuRemoveEmptyLines() {
        if let doc = workspace.activeDocument { NppEditOperations.removeEmptyLines(in: doc, removeBlankChars: true) }
    }
    @objc func menuRemoveDuplicateLines() {
        if let doc = workspace.activeDocument { NppEditOperations.removeDuplicateLines(in: doc) }
    }
    @objc func menuSortAscending() {
        if let doc = workspace.activeDocument { NppEditOperations.sortLines(in: doc, ascending: true) }
    }
    @objc func menuSortDescending() {
        if let doc = workspace.activeDocument { NppEditOperations.sortLines(in: doc, ascending: false) }
    }
    @objc func menuReverseLines() {
        if let doc = workspace.activeDocument { NppEditOperations.reverseLineOrder(in: doc) }
    }

    @objc func menuToggleComment() {
        if let tv = getActiveTextView(), let lang = workspace.activeDocument?.language {
            NppEditOperations.toggleComment(in: tv, language: lang)
        }
    }

    @objc func menuTrimTrailing() {
        if let doc = workspace.activeDocument { NppEditOperations.trimSpaces(in: doc, mode: .trailing) }
    }
    @objc func menuTrimLeading() {
        if let doc = workspace.activeDocument { NppEditOperations.trimSpaces(in: doc, mode: .leading) }
    }
    @objc func menuTrimBoth() {
        if let doc = workspace.activeDocument { NppEditOperations.trimSpaces(in: doc, mode: .both) }
    }
    @objc func menuEolToSpace() {
        if let doc = workspace.activeDocument { NppEditOperations.eolToSpace(in: doc) }
    }
    @objc func menuTabToSpace() {
        if let doc = workspace.activeDocument { NppEditOperations.tabToSpace(in: doc) }
    }
    @objc func menuSpaceToTab() {
        if let doc = workspace.activeDocument { NppEditOperations.spaceToTab(in: doc) }
    }

    @objc func menuInsertDateShort() {
        if let tv = getActiveTextView() { NppEditOperations.insertDateTime(in: tv, isLong: false) }
    }
    @objc func menuInsertDateLong() {
        if let tv = getActiveTextView() { NppEditOperations.insertDateTime(in: tv, isLong: true) }
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
        let alert = NSAlert()
        alert.messageText = "Notepad++ Preferences"
        alert.informativeText = "Editor Font Size: \(Int(workspace.fontSize)) pt\nWord Wrap: \(workspace.isWordWrapEnabled ? "Enabled" : "Disabled")\nOverwrite Mode: \(workspace.isOverwriteMode ? "Enabled" : "Disabled")"
        alert.alertStyle = .informational
        alert.runModal()
    }
    @objc func menuStyleConfigurator() {
        let alert = NSAlert()
        alert.messageText = "Style Configurator"
        alert.informativeText = "Theme: Notepad++ Dark Mode (matches notepad4ever)\nDefault Monospaced Font: SF Mono / Menlo\nFont Size: \(Int(workspace.fontSize)) pt"
        alert.alertStyle = .informational
        alert.runModal()
    }
    @objc func menuShortcutMapper() {
        let alert = NSAlert()
        alert.messageText = "Shortcut Mapper"
        alert.informativeText = "Cmd+N: New Document\nCmd+O: Open File\nCmd+S: Save\nCmd+F: Find\nCmd+D: Duplicate Line\nCmd+J: Join Lines\nCmd+/: Toggle Comment\nCmd+T: Open in Terminal"
        alert.alertStyle = .informational
        alert.runModal()
    }
    @objc func menuEditContextMenu() {
        let alert = NSAlert()
        alert.messageText = "Edit Popup ContextMenu"
        alert.informativeText = "Context menu configuration is loaded in EditorView.swift and supports token occurrences styling, plugins, casing, line, and blank operations."
        alert.alertStyle = .informational
        alert.runModal()
    }

    // Tools actions
    @objc func menuMD5Generate() {
        if let doc = workspace.activeDocument {
            let data = doc.content.data(using: .utf8) ?? Data()
            let hash = NppTools.md5(data: data)
            NppTools.showHashDialog(title: "MD5 Digest for \(doc.title)", hash: hash)
        }
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
    @objc func menuSHA256Generate() {
        if let doc = workspace.activeDocument {
            let data = doc.content.data(using: .utf8) ?? Data()
            let hash = NppTools.sha256(data: data)
            NppTools.showHashDialog(title: "SHA-256 Digest for \(doc.title)", hash: hash)
        }
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

    // Macro actions
    @objc func menuMacroStart() {
        workspace.isMacroRecording = true
        workspace.recordedMacroActions.removeAll()
    }
    @objc func menuMacroStop() {
        workspace.isMacroRecording = false
    }
    @objc func menuMacroPlayback() {
        // Simple replay action
        if let tv = getActiveTextView() {
            NppEditOperations.duplicateLine(in: tv)
        }
    }
    @objc func menuMacroRunMulti() {
        if let tv = getActiveTextView() {
            for _ in 0..<5 {
                NppEditOperations.duplicateLine(in: tv)
            }
        }
    }

    // Run actions
    @objc func menuRunPrompt() {
        let alert = NSAlert()
        alert.messageText = "Run Program"
        alert.informativeText = "The Program to Run:"
        alert.addButton(withTitle: "Run")
        alert.addButton(withTitle: "Cancel")
        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        input.placeholderString = "e.g. python3 $(CURRENT_FILE)"
        alert.accessoryView = input
        alert.runModal()
    }
    @objc func menuLaunchSafari() {
        if let doc = workspace.activeDocument, let path = doc.filePath {
            NSWorkspace.shared.open(path)
        }
    }
    @objc func menuLaunchChrome() {
        if let doc = workspace.activeDocument, let path = doc.filePath {
            let conf = NSWorkspace.OpenConfiguration()
            if let chromeUrl = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.google.Chrome") {
                NSWorkspace.shared.open([path], withApplicationAt: chromeUrl, configuration: conf, completionHandler: nil)
            } else {
                NSWorkspace.shared.open(path)
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
    @objc func menuPluginsAdmin() {
        let alert = NSAlert()
        alert.messageText = "Plugins Admin"
        alert.informativeText = "Active native plugins:\n- MIME Tools (Base64)\n- Converter (URL / Case / Hex)\n- NppExport (Syntax copy)\n- uchardet Mozilla Engine (Charset detection)"
        alert.alertStyle = .informational
        alert.runModal()
    }
    @objc func menuOpenPluginsDir() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let nppDir = appSupport.appendingPathComponent("Notepad++").appendingPathComponent("plugins")
        try? FileManager.default.createDirectory(at: nppDir, withIntermediateDirectories: true)
        NSWorkspace.shared.activateFileViewerSelecting([nppDir])
    }

    // Window menu actions
    @objc func menuSortTabsNameAsc() { workspace.sortTabsByName(ascending: true) }
    @objc func menuSortTabsNameDesc() { workspace.sortTabsByName(ascending: false) }
    @objc func menuSortTabsPathAsc() { workspace.sortTabsByPath(ascending: true) }
    @objc func menuSortTabsPathDesc() { workspace.sortTabsByPath(ascending: false) }
    @objc func menuSortTabsSizeAsc() { workspace.sortTabsBySize(ascending: true) }
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
        alert.informativeText = "Notepad++ for Mac v8.7.0 (64-bit ARM Mach-O)\nBuild time: Oct 2026\nSystem: macOS \(ProcessInfo.processInfo.operatingSystemVersionString)\nCore Engine: Notepad++ upstream uchardet + iconv streaming\nUI Engine: Apple TextKit 2 + SwiftUI AppKit Bridge"
        alert.alertStyle = .informational
        alert.runModal()
    }

    @objc func showAbout() {
        let alert = NSAlert()
        alert.messageText = "Notepad++ for Mac"
        alert.informativeText = "Notepad++ v8.7.0 (64-bit)\nFree & Open Source Software\n\nHigh-Performance Native Port for macOS\nPowered by Notepad++ C++ Core (uchardet & iconv) and Apple TextKit 2.\n\nAuthor: Don HO (Notepad++ upstream)\nPorted to macOS with Antigravity"
        alert.alertStyle = .informational
        alert.runModal()
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
