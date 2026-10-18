import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    let workspace = NppWorkspace()

    func applicationDidFinishLaunching(_ notification: Notification) {
        let contentView = NppMainWindowView(workspace: workspace)

        window = NSWindow(
            contentRect: NSRect(x: 100, y: 100, width: 950, height: 650),
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

        // 2. File Menu
        let fileMenuItem = NSMenuItem()
        let fileMenu = NSMenu(title: "File")
        fileMenu.addItem(withTitle: "New", action: #selector(menuNew), keyEquivalent: "n")
        fileMenu.addItem(withTitle: "Open...", action: #selector(menuOpen), keyEquivalent: "o")
        fileMenu.addItem(NSMenuItem.separator())
        fileMenu.addItem(withTitle: "Save", action: #selector(menuSave), keyEquivalent: "s")
        fileMenu.addItem(withTitle: "Save As...", action: #selector(menuSaveAs), keyEquivalent: "S")
        fileMenu.addItem(withTitle: "Save All", action: #selector(menuSaveAll), keyEquivalent: "")
        fileMenu.addItem(NSMenuItem.separator())
        fileMenu.addItem(withTitle: "Close Tab", action: #selector(menuCloseTab), keyEquivalent: "w")
        fileMenu.addItem(withTitle: "Close All", action: #selector(menuCloseAll), keyEquivalent: "")
        fileMenuItem.submenu = fileMenu
        mainMenu.addItem(fileMenuItem)

        // 3. Edit Menu
        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenu.addItem(NSMenuItem.separator())

        // EOL Submenu
        let eolMenuItem = NSMenuItem(title: "EOL Conversion", action: nil, keyEquivalent: "")
        let eolMenu = NSMenu(title: "EOL Conversion")
        eolMenu.addItem(withTitle: "Windows (CR LF)", action: #selector(menuEolWindows), keyEquivalent: "")
        eolMenu.addItem(withTitle: "Unix (LF)", action: #selector(menuEolUnix), keyEquivalent: "")
        eolMenu.addItem(withTitle: "Macintosh (CR)", action: #selector(menuEolMac), keyEquivalent: "")
        eolMenuItem.submenu = eolMenu
        editMenu.addItem(eolMenuItem)

        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        // 4. Search Menu
        let searchMenuItem = NSMenuItem()
        let searchMenu = NSMenu(title: "Search")
        searchMenu.addItem(withTitle: "Find...", action: #selector(menuFind), keyEquivalent: "f")
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

        // 6. Encoding Menu (The signature Notepad++ menu)
        let encMenuItem = NSMenuItem()
        let encMenu = NSMenu(title: "Encoding")
        encMenu.addItem(withTitle: "Encode in ANSI", action: #selector(menuEncodeAnsi), keyEquivalent: "")
        encMenu.addItem(withTitle: "Encode in UTF-8", action: #selector(menuEncodeUtf8), keyEquivalent: "")
        encMenu.addItem(withTitle: "Encode in UTF-8-BOM", action: #selector(menuEncodeUtf8Bom), keyEquivalent: "")
        encMenu.addItem(withTitle: "Encode in UTF-16 BE", action: #selector(menuEncodeUtf16BE), keyEquivalent: "")
        encMenu.addItem(withTitle: "Encode in UTF-16 LE", action: #selector(menuEncodeUtf16LE), keyEquivalent: "")

        let charSetsItem = NSMenuItem(title: "Character sets", action: nil, keyEquivalent: "")
        let charSetsMenu = NSMenu(title: "Character sets")
        let koreanItem = NSMenuItem(title: "Korean", action: nil, keyEquivalent: "")
        let koreanMenu = NSMenu(title: "Korean")
        koreanMenu.addItem(withTitle: "Windows-949 (CP949)", action: #selector(menuEncodeCP949), keyEquivalent: "")
        koreanMenu.addItem(withTitle: "EUC-KR", action: #selector(menuEncodeEucKr), keyEquivalent: "")
        koreanItem.submenu = koreanMenu
        charSetsMenu.addItem(koreanItem)

        let japaneseItem = NSMenuItem(title: "Japanese", action: nil, keyEquivalent: "")
        let japaneseMenu = NSMenu(title: "Japanese")
        japaneseMenu.addItem(withTitle: "Shift-JIS (CP932)", action: #selector(menuEncodeShiftJis), keyEquivalent: "")
        japaneseItem.submenu = japaneseMenu
        charSetsMenu.addItem(japaneseItem)

        let chineseItem = NSMenuItem(title: "Chinese", action: nil, keyEquivalent: "")
        let chineseMenu = NSMenu(title: "Chinese")
        chineseMenu.addItem(withTitle: "GB18030", action: #selector(menuEncodeGB18030), keyEquivalent: "")
        chineseMenu.addItem(withTitle: "Big5", action: #selector(menuEncodeBig5), keyEquivalent: "")
        chineseItem.submenu = chineseMenu
        charSetsMenu.addItem(chineseItem)

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
    @objc func menuSave() { workspace.saveActive() }
    @objc func menuSaveAs() {
        if let doc = workspace.activeDocument {
            workspace.promptSaveAs(for: doc)
        }
    }
    @objc func menuSaveAll() { workspace.saveAll() }
    @objc func menuCloseTab() {
        if let id = workspace.activeDocumentId {
            workspace.closeDocument(id: id)
        }
    }
    @objc func menuCloseAll() { workspace.closeAll() }
    @objc func menuFind() { workspace.showSearchBar.toggle() }
    @objc func menuToggleWordWrap() { workspace.isWordWrapEnabled.toggle() }
    @objc func menuZoomIn() { workspace.zoomIn() }
    @objc func menuZoomOut() { workspace.zoomOut() }
    @objc func menuResetZoom() { workspace.resetZoom() }

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
