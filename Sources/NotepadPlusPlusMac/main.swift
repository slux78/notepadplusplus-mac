import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    let workspace = NppWorkspace()

    func applicationDidFinishLaunching(_ notification: Notification) {
        let contentView = NppMainWindowView(workspace: workspace)

        window = NSWindow(
            contentRect: NSRect(x: 100, y: 100, width: 1000, height: 700),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "Notepad++ for Mac"
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
    }

    private func setupMenuBar() {
        let mainMenu = NSMenu()

        // 1. App Menu
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "About Notepad++ for Mac", action: #selector(showAbout), keyEquivalent: "")
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

        // 4. Search Menu
        let searchMenuItem = NSMenuItem()
        let searchMenu = NSMenu(title: "Search")
        searchMenu.addItem(withTitle: "Find...", action: #selector(menuFind), keyEquivalent: "f")
        searchMenu.addItem(withTitle: "Replace...", action: #selector(menuFind), keyEquivalent: "h")
        searchMenuItem.submenu = searchMenu
        mainMenu.addItem(searchMenuItem)

        // 5. View Menu
        let viewMenuItem = NSMenuItem()
        let viewMenu = NSMenu(title: "View")
        viewMenu.addItem(withTitle: "Toggle Word Wrap", action: #selector(menuToggleWordWrap), keyEquivalent: "")
        viewMenu.addItem(NSMenuItem.separator())
        viewMenu.addItem(withTitle: "Zoom In", action: #selector(menuZoomIn), keyEquivalent: "=")
        viewMenu.addItem(withTitle: "Zoom Out", action: #selector(menuZoomOut), keyEquivalent: "-")
        viewMenu.addItem(withTitle: "Restore Default Zoom", action: #selector(menuResetZoom), keyEquivalent: "0")
        viewMenuItem.submenu = viewMenu
        mainMenu.addItem(viewMenuItem)

        // 6. Encoding Menu (Notepad++ Windows parity)
        let encMenuItem = NSMenuItem()
        let encMenu = NSMenu(title: "Encoding")
        encMenu.addItem(withTitle: "Encode in ANSI", action: #selector(menuEncodeAnsi), keyEquivalent: "")
        encMenu.addItem(withTitle: "Encode in UTF-8", action: #selector(menuEncodeUtf8), keyEquivalent: "")
        encMenu.addItem(withTitle: "Encode in UTF-8-BOM", action: #selector(menuEncodeUtf8Bom), keyEquivalent: "")
        encMenu.addItem(withTitle: "Encode in UTF-16 BE", action: #selector(menuEncodeUtf16BE), keyEquivalent: "")
        encMenu.addItem(withTitle: "Encode in UTF-16 LE", action: #selector(menuEncodeUtf16LE), keyEquivalent: "")

        let charSetsMenu = NSMenu(title: "Character sets")
        let koreanMenu = NSMenu(title: "Korean")
        koreanMenu.addItem(withTitle: "Windows-949 (CP949)", action: #selector(menuEncodeCP949), keyEquivalent: "")
        koreanMenu.addItem(withTitle: "EUC-KR", action: #selector(menuEncodeEucKr), keyEquivalent: "")
        let koreanItem = NSMenuItem(title: "Korean", action: nil, keyEquivalent: "")
        koreanItem.submenu = koreanMenu
        charSetsMenu.addItem(koreanItem)

        let japaneseMenu = NSMenu(title: "Japanese")
        japaneseMenu.addItem(withTitle: "Shift-JIS (CP932)", action: #selector(menuEncodeShiftJis), keyEquivalent: "")
        let japaneseItem = NSMenuItem(title: "Japanese", action: nil, keyEquivalent: "")
        japaneseItem.submenu = japaneseMenu
        charSetsMenu.addItem(japaneseItem)

        let chineseMenu = NSMenu(title: "Chinese")
        chineseMenu.addItem(withTitle: "GB18030", action: #selector(menuEncodeGB18030), keyEquivalent: "")
        chineseMenu.addItem(withTitle: "Big5", action: #selector(menuEncodeBig5), keyEquivalent: "")
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
        encMenu.addItem(withTitle: "Convert to Korean (CP949)", action: #selector(menuConvertCP949), keyEquivalent: "")
        encMenu.addItem(withTitle: "Convert to Korean (EUC-KR)", action: #selector(menuConvertEucKr), keyEquivalent: "")

        encMenuItem.submenu = encMenu
        mainMenu.addItem(encMenuItem)

        NSApp.mainMenu = mainMenu
    }

    // Action Handlers
    @objc func menuNew() { workspace.newDocument() }
    @objc func menuOpen() { workspace.promptOpenFile() }
    @objc func menuReload() {
        if let doc = workspace.activeDocument { workspace.reloadFromDisk(for: doc) }
    }
    @objc func menuSave() { workspace.saveActive() }
    @objc func menuSaveAs() {
        if let doc = workspace.activeDocument { workspace.promptSaveAs(for: doc) }
    }
    @objc func menuSaveAll() { workspace.saveAll() }
    @objc func menuCloseTab() {
        if let id = workspace.activeDocumentId { workspace.closeDocument(id: id) }
    }
    @objc func menuCloseAll() { workspace.closeAll() }
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
        }
    }

    @objc func menuFind() { workspace.showSearchBar.toggle() }
    @objc func menuToggleWordWrap() { workspace.isWordWrapEnabled.toggle() }
    @objc func menuZoomIn() { workspace.zoomIn() }
    @objc func menuZoomOut() { workspace.zoomOut() }
    @objc func menuResetZoom() { workspace.resetZoom() }

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
    @objc func menuEolWindows() { workspace.activeDocument?.convertEOL(to: .crlf) }
    @objc func menuEolUnix() { workspace.activeDocument?.convertEOL(to: .lf) }
    @objc func menuEolMac() { workspace.activeDocument?.convertEOL(to: .cr) }

    // Encode in actions
    @objc func menuEncodeAnsi() { workspace.activeDocument?.reencodeAs(targetCharset: "WINDOWS-1252") }
    @objc func menuEncodeUtf8() { workspace.activeDocument?.reencodeAs(targetCharset: "UTF-8") }
    @objc func menuEncodeUtf8Bom() {
        workspace.activeDocument?.reencodeAs(targetCharset: "UTF-8")
        workspace.activeDocument?.hasBOM = true
    }
    @objc func menuEncodeUtf16BE() { workspace.activeDocument?.reencodeAs(targetCharset: "UTF-16BE") }
    @objc func menuEncodeUtf16LE() { workspace.activeDocument?.reencodeAs(targetCharset: "UTF-16LE") }
    @objc func menuEncodeCP949() { workspace.activeDocument?.reencodeAs(targetCharset: "CP949") }
    @objc func menuEncodeEucKr() { workspace.activeDocument?.reencodeAs(targetCharset: "EUC-KR") }
    @objc func menuEncodeShiftJis() { workspace.activeDocument?.reencodeAs(targetCharset: "CP932") }
    @objc func menuEncodeGB18030() { workspace.activeDocument?.reencodeAs(targetCharset: "GB18030") }
    @objc func menuEncodeBig5() { workspace.activeDocument?.reencodeAs(targetCharset: "BIG5") }

    // Convert to actions
    @objc func menuConvertAnsi() { workspace.activeDocument?.convertEncoding(to: "WINDOWS-1252") }
    @objc func menuConvertUtf8() { workspace.activeDocument?.convertEncoding(to: "UTF-8", addBOM: false) }
    @objc func menuConvertUtf8Bom() { workspace.activeDocument?.convertEncoding(to: "UTF-8", addBOM: true) }
    @objc func menuConvertCP949() { workspace.activeDocument?.convertEncoding(to: "CP949") }
    @objc func menuConvertEucKr() { workspace.activeDocument?.convertEncoding(to: "EUC-KR") }

    @objc func showAbout() {
        let alert = NSAlert()
        alert.messageText = "Notepad++ for Mac"
        alert.informativeText = "High-Performance Native Port for macOS\nPowered by Notepad++ C++ Core (uchardet & iconv) and Apple TextKit 2.\n\nAuthor: Pair programmed with Antigravity"
        alert.alertStyle = .informational
        alert.runModal()
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
