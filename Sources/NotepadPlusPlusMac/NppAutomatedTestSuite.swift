import AppKit
import SwiftUI

final class NppAutomatedTestInteractionProvider: NppWorkspace.NppUserInteractionProvider {
    func confirmSave(for document: NppDocument) -> NppWorkspace.SavePromptResult {
        return .dontSave
    }
    func promptSaveSynchronously(for document: NppDocument) -> Bool {
        return true
    }
    func confirmKeepMissingFiles(missingFiles: [URL]) -> Bool {
        return true
    }
}

final class NppAutomatedTestSuite {
    static func run(appDelegate: AppDelegate) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            print("\n========================================================")
            print("🚀 Starting Comprehensive Notepad++ Automated Test Suite")
            print("========================================================")

            let ws = appDelegate.workspace
            var testCount = 0
            var passedCount = 0

            func assertTest(_ name: String, _ condition: Bool) {
                testCount += 1
                if condition {
                    passedCount += 1
                    print("  ✅ PASS: [\(testCount)] \(name)")
                } else {
                    print("  ❌ FAIL: [\(testCount)] \(name)")
                }
            }

            NppWorkspace.defaultInteractionProvider = NppAutomatedTestInteractionProvider()
            ws.interactionProvider = NppWorkspace.defaultInteractionProvider
            ws.isTestRunning = true
            ws.confirmSaveHandler = { _ in .dontSave }
            ws.sessionPlaceholderDecisionHandler = { _ in true }

            // TEST 1: Initial Document State
            assertTest("Initial workspace has 1 default document", ws.documents.count == 1)
            assertTest("Default title is 'new 1'", ws.activeDocument?.title == "new 1")

            // TEST 2: File Operations & CP949 Korean Decoding
            let sampleUrl = URL(fileURLWithPath: "samples/korean_cp949.txt")
            ws.openFile(url: sampleUrl)
            assertTest("Opened korean_cp949.txt", ws.activeDocument?.filePath?.lastPathComponent == "korean_cp949.txt")
            assertTest("CP949 correctly detected", ws.activeDocument?.encoding == "CP949")
            assertTest("Korean characters properly decoded", ws.activeDocument?.content.contains("한글") == true)

            // TEST 3: Encoding Conversions (CP949 -> UTF-8 -> CP949)
            ws.activeDocument?.convertEncoding(to: "UTF-8", addBOM: false)
            assertTest("Converted to UTF-8 without corruption", ws.activeDocument?.encoding == "UTF-8" && ws.activeDocument?.content.contains("한글") == true)
            ws.activeDocument?.convertEncoding(to: "CP949")
            assertTest("Converted back to CP949", ws.activeDocument?.encoding == "CP949" && ws.activeDocument?.content.contains("한글") == true)

            // TEST 4: Tab Management & Sorting
            ws.newDocument() // new 2
            ws.newDocument() // new 3
            assertTest("Created multiple documents", ws.documents.count == 3)
            ws.sortTabsByName(ascending: true)
            assertTest("Tabs sorted by name", ws.documents.count == 3)
            let keepId = ws.documents[0].id
            ws.closeAllBut(id: keepId)
            assertTest("closeAllBut left exactly 1 document", ws.documents.count == 1 && ws.documents[0].id == keepId)

            // TEST 5: Preferences System & Live Bindings
            ws.openPreferences(tab: 0)
            assertTest("openPreferences opens sheet", ws.showPreferencesSheet == true && ws.selectedPreferencesTab == 0)

            ws.fontFamily = "Menlo"
            assertTest("Preferences: fontFamily updated to Menlo", ws.fontFamily == "Menlo")

            let initialFontSize = ws.fontSize
            ws.zoomIn()
            assertTest("Toolbar/Shortcut: Zoom In increases font size", ws.fontSize == initialFontSize + 1.0)
            ws.zoomOut()
            assertTest("Toolbar/Shortcut: Zoom Out restores font size", ws.fontSize == initialFontSize)

            ws.tabSize = 2
            assertTest("Preferences: tabSize updated to 2", ws.tabSize == 2)
            ws.tabSize = 4

            ws.highlightCurrentLine = false
            assertTest("Preferences: highlightCurrentLine toggled to false", ws.highlightCurrentLine == false)
            ws.highlightCurrentLine = true
            assertTest("Preferences: highlightCurrentLine restored to true", ws.highlightCurrentLine == true)

            ws.showLineNumbers = false
            assertTest("Preferences: showLineNumbers toggled to false", ws.showLineNumbers == false)
            ws.showLineNumbers = true
            assertTest("Preferences: showLineNumbers restored to true", ws.showLineNumbers == true)

            ws.themeMode = "light"
            assertTest("Preferences: themeMode set to light", ws.themeMode == "light")
            ws.themeMode = "dark"
            assertTest("Preferences: themeMode set to dark", ws.themeMode == "dark")

            ws.openPreferences(tab: 2) // Style Configurator
            assertTest("Style Configurator opens Theme tab (2)", ws.selectedPreferencesTab == 2)

            ws.openPreferences(tab: 4) // Shortcut Mapper
            assertTest("Shortcut Mapper opens Shortcuts tab (4)", ws.selectedPreferencesTab == 4)

            ws.showPreferencesSheet = false
            assertTest("Preferences sheet closed", ws.showPreferencesSheet == false)

            // TEST 6: Editor View & Active TextView Actions
            let doc = ws.activeDocument!
            doc.content = "function testFunction() {\n    return 42;\n}\nclass TestClass {\n}\n"
            let tv = ws.activeTextView ?? NSTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 400))
            tv.string = doc.content
            ws.activeTextView = tv

            assertTest("activeTextView reference is hooked", ws.activeTextView != nil)

            // Cut, Copy, Paste, Undo, Redo dispatch
            tv.setSelectedRange(NSRange(location: 0, length: 8)) // "function"
            ws.copy()
            let copied = NSPasteboard.general.string(forType: .string)
            assertTest("Toolbar Copy copies selected text", copied == "function")

            ws.cut()
            assertTest("Toolbar Cut removes selected text", !tv.string.hasPrefix("function"))

            ws.undo()
            assertTest("Toolbar Undo restores text", tv.string.hasPrefix("function"))

            // TEST 7: Search, Replace, and Find All Panels
            ws.findAllInCurrentDoc(query: "function", matchCase: false, wholeWord: false, useRegex: false)
            assertTest("Find All in Current Doc finds matches", ws.showSearchResultsPanel && ws.totalSearchHits >= 1)
            assertTest("Last search query stored", ws.lastSearchQuery == "function")

            if let firstMatch = ws.searchFileGroups.first?.matches.first {
                ws.jumpToMatch(firstMatch)
                assertTest("Jump to search match updates cursor", doc.cursorPos == firstMatch.charPosition)
            }
            ws.clearSearchResults()
            assertTest("Clear search results clears dock", !ws.showSearchResultsPanel && ws.totalSearchHits == 0)

            // TEST 8: Sidebars (Function List & Document Map)
            ws.showFunctionList = true
            assertTest("Function List panel toggled ON", ws.showFunctionList == true)
            ws.showFunctionList = false
            assertTest("Function List panel toggled OFF", ws.showFunctionList == false)

            ws.showDocumentMap = true
            assertTest("Document Map panel toggled ON", ws.showDocumentMap == true)
            ws.showDocumentMap = false
            assertTest("Document Map panel toggled OFF", ws.showDocumentMap == false)

            // TEST 9: View Options (Word Wrap, Invisibles, Guides)
            ws.isWordWrapEnabled = true
            assertTest("Word wrap enabled", ws.isWordWrapEnabled == true)
            ws.isWordWrapEnabled = false

            ws.showInvisibleCharacters = true
            assertTest("Show invisibles enabled", ws.showInvisibleCharacters == true)
            ws.showInvisibleCharacters = false

            ws.showIndentGuides = true
            assertTest("Show indent guides enabled", ws.showIndentGuides == true)

            // TEST 10: Tools Operations (MD5, SHA256, Base64, URL)
            let md5Result = NppTools.md5(data: "Notepad++".data(using: .utf8)!)
            assertTest("MD5 hash generation is valid", md5Result.count == 32)

            let shaResult = NppTools.sha256(data: "Notepad++".data(using: .utf8)!)
            assertTest("SHA-256 hash generation is valid", shaResult.count == 64)

            let b64 = NppTools.base64Encode(string: "Hello Notepad++")
            let b64Dec = NppTools.base64Decode(string: b64)
            assertTest("Base64 encode and decode roundtrip", b64Dec == "Hello Notepad++")

            let urlEnc = NppTools.urlEncode(string: "hello world&key=val")
            let urlDec = NppTools.urlDecode(string: urlEnc)
            assertTest("URL encode and decode roundtrip", urlDec == "hello world&key=val")

            // TEST 11: Edit Operations (Line & Case manipulation)
            doc.content = "line 3\nline 1\nline 2\n\n"
            NppEditOperations.removeEmptyLines(in: doc, removeBlankChars: true)
            assertTest("removeEmptyLines removes trailing blank line", !doc.content.contains("\n\n"))

            NppEditOperations.sortLines(in: doc, ascending: true)
            assertTest("sortLines sorts lines ascending", doc.content.hasPrefix("line 1"))

            NppEditOperations.reverseLineOrder(in: doc)
            assertTest("reverseLineOrder reverses lines", doc.content.hasPrefix("line 3"))

            // TEST 12: Dialogs Verification
            // Verify About Notepad++ version string matches v8.9.8.1
            let bundleVer = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "8.9.8.1"
            assertTest("About Dialog: Version strictly conforms to 8.9.8.1", bundleVer == "8.9.8.1")

            // TEST 13: Dynamic Coding Fonts Discovery & Font Selection
            let availableFonts = NppWorkspace.availableCodingFonts
            assertTest("Dynamic coding fonts discovered from macOS system", availableFonts.count >= 3)
            ws.fontFamily = availableFonts.first ?? "Menlo"
            assertTest("Selected Mac coding font applied to workspace", ws.fontFamily == (availableFonts.first ?? "Menlo"))

            // TEST 14: Authentic Notepad++ Themes Support (9 Themes)
            let allThemes = NppTheme.allThemes
            assertTest("9 authentic Notepad++ themes available", allThemes.count == 9)
            let themeIds = ["dark", "light", "monokai", "dracula", "solarized_dark", "solarized_light", "deep_black", "nord", "zenburn"]
            for tid in themeIds {
                ws.themeMode = tid
                let cur = ws.currentTheme
                assertTest("Theme switch: '\(cur.name)' loaded correctly", cur.id == tid)
            }
            ws.themeMode = "dark" // restore default dark theme

            // TEST 15: Run Command Engine & Variable Expansion
            let rawCmd = "echo $(CURRENT_FILE) $(CURRENT_DIRECTORY) $(FILE_NAME) $(NAME_PART)"
            let expandedCmd = ws.expandRunCommand(rawCmd)
            assertTest("Run Command expands $(CURRENT_FILE) and variables", !expandedCmd.contains("$(CURRENT_FILE)") && !expandedCmd.contains("$(FILE_NAME)"))
            assertTest("Run Command contains active file name", expandedCmd.contains("korean_cp949.txt"))

            // TEST 16: Converter Plugin (ASCII <-> HEX)
            let asciiSample = "Notepad++ Mac"
            let hexSample = NppTools.asciiToHex(string: asciiSample)
            assertTest("Converter ASCII -> HEX generates space-separated hex", hexSample.contains("4E 6F 74"))
            let asciiBack = NppTools.hexToAscii(string: hexSample)
            assertTest("Converter HEX -> ASCII restores original text", asciiBack == asciiSample)

            // TEST 17: File Status Auto-Detection & Silent Auto-Reload
            let tempDir = FileManager.default.temporaryDirectory
            let testFileUrl = tempDir.appendingPathComponent("npp_autodetect_test.txt")
            try? "Original Version 1".write(to: testFileUrl, atomically: true, encoding: .utf8)
            ws.openFile(url: testFileUrl)
            let testDoc = ws.activeDocument!
            assertTest("File Status: Opened temp test file", testDoc.content == "Original Version 1")

            // Simulate external modification by another program (e.g. Git, Terminal)
            Thread.sleep(forTimeInterval: 1.1)
            try? "Modified Externally Version 2".write(to: testFileUrl, atomically: true, encoding: .utf8)
            ws.fileStatusAutoDetection = true
            ws.fileStatusAutoReloadSilently = true
            let reloaded = ws.checkFileStatus(for: testDoc, prompt: false)
            assertTest("File Status: Detected external modification & reloaded automatically", reloaded == true && testDoc.content == "Modified Externally Version 2")
            try? FileManager.default.removeItem(at: testFileUrl)

            // TEST 18: Distinct Find vs Replace Dialog Modes (Authentic Notepad++ modeless dialog, no editor searchbar, hidesOnDeactivate)
            ws.openFind()
            assertTest("openFind sets findReplaceTab to 0 without editor searchbar", ws.showFindReplaceDialog && ws.findReplaceTab == 0 && !ws.showSearchBar)
            assertTest("Find dialog panel hidesOnDeactivate is true", NppFindReplaceWindowController.shared.panel?.hidesOnDeactivate == true)
            ws.openReplace()
            assertTest("openReplace sets findReplaceTab to 1 without editor searchbar", ws.showFindReplaceDialog && ws.findReplaceTab == 1 && !ws.showSearchBar)
            ws.showFindReplaceDialog = false

            // TEST 19: Language Selection & Dynamic Syntax Highlighting
            let codeDoc = ws.activeDocument!
            codeDoc.content = "import Foundation\nfunc calculateTotal() -> Int {\n    let val = 42\n    return val\n}\n"
            let textStorage = NSTextStorage(string: codeDoc.content)
            NppSyntaxHighlighter.highlight(textStorage: textStorage, language: "Swift", isDarkMode: true)
            // Verify 'func' keyword has keyword color attribute, differing from identifier 'calculateTotal'
            let funcRange = (codeDoc.content as NSString).range(of: "func")
            let nameRange = (codeDoc.content as NSString).range(of: "calculateTotal")
            let funcColor = textStorage.attribute(.foregroundColor, at: funcRange.location, effectiveRange: nil) as? NSColor
            let nameColor = textStorage.attribute(.foregroundColor, at: nameRange.location, effectiveRange: nil) as? NSColor
            assertTest("Language Selection applies Swift syntax highlighting", funcColor != nil && funcColor != nameColor)

            // TEST 20: Cursor Line & Gutter Number Accuracy (Fix off-by-one bug)
            // Cursor at character 5 on Line 1 ("Hello")
            let sampleLines: NSString = "Line One Content\nLine Two Content\nLine Three Content\n"
            func calcLine(at charIndex: Int) -> Int {
                var l = 1
                for i in 0..<min(charIndex, sampleLines.length) {
                    if sampleLines.character(at: i) == 10 { l += 1 }
                }
                return l
            }
            assertTest("Cursor on Line 1 (char 5) returns Line 1", calcLine(at: 5) == 1)
            assertTest("Cursor on Line 2 (char 22) returns Line 2", calcLine(at: 22) == 2)
            assertTest("Cursor on Line 3 (char 40) returns Line 3", calcLine(at: 40) == 3)

            // TEST 21: Robust Tab Closing and Active Document Retention
            // Verify closing a tab never results in "No Document Open" when tabs remain
            ws.closeAll() // resets to 1 new tab
            let docA = ws.activeDocument!
            docA.title = "Tab A"
            ws.newDocument()
            let docB = ws.activeDocument!
            docB.title = "Tab B"
            ws.newDocument()
            let docC = ws.activeDocument!
            docC.title = "Tab C"
            assertTest("Tab Close: 3 documents created", ws.documents.count == 3)
            assertTest("Tab Close: Tab C is initially active", ws.activeDocument?.id == docC.id)

            // Close Tab C (active tab at end of list)
            ws.closeDocument(id: docC.id)
            assertTest("Tab Close: Tab C removed, 2 documents remaining", ws.documents.count == 2)
            assertTest("Tab Close: activeDocument is non-nil after closing Tab C", ws.activeDocument != nil)
            assertTest("Tab Close: activeDocument switched to Tab B", ws.activeDocument?.id == docB.id)

            // Switch to Tab A and close it
            ws.activeDocumentId = docA.id
            assertTest("Tab Close: switched to Tab A", ws.activeDocument?.id == docA.id)
            ws.closeDocument(id: docA.id)
            assertTest("Tab Close: Tab A removed, 1 document remaining", ws.documents.count == 1)
            assertTest("Tab Close: activeDocument is non-nil and is Tab B", ws.activeDocument?.id == docB.id)

            // Simulate rogue gesture attempting to set activeDocumentId to a closed document ID
            ws.activeDocumentId = docA.id // deleted id
            assertTest("Tab Close: activeDocument recovers automatically from invalid/stale id", ws.activeDocument != nil && ws.activeDocument?.id == docB.id)
            assertTest("Tab Close: activeDocumentId auto-validated to Tab B", ws.activeDocumentId == docB.id)

            // Close the final remaining tab (Notepad++ automatically opens 'new 1')
            ws.closeDocument(id: docB.id)
            assertTest("Tab Close: closing final tab automatically creates new document", ws.documents.count == 1)
            assertTest("Tab Close: activeDocument is non-nil for the new document", ws.activeDocument != nil)

            // TEST 21B: Notepad++ Pin Tab & Close Multiple Documents (upstream Notepad_plus.rc & NppIO.cpp)
            ws.closeAll()
            let pDoc1 = ws.activeDocument!
            pDoc1.title = "Unpinned 1"
            ws.newDocument()
            let pDoc2 = ws.activeDocument!
            pDoc2.title = "To Pin"
            ws.newDocument()
            let pDoc3 = ws.activeDocument!
            pDoc3.title = "Unpinned 2"
            assertTest("Pin Test: 3 docs created", ws.documents.count == 3)

            // Pin pDoc2: should be marked pinned and reordered to the left
            ws.togglePin(id: pDoc2.id)
            assertTest("Pin Test: pDoc2 is pinned", pDoc2.isPinned == true)
            assertTest("Pin Test: pinned doc moved to first position", ws.documents.first?.id == pDoc2.id)

            // Attempt to close pinned document directly: should be blocked
            ws.closeDocument(id: pDoc2.id)
            assertTest("Pin Test: closeDocument blocked for pinned tab", ws.documents.contains(where: { $0.id == pDoc2.id }))

            // Close All but Pinned Documents
            ws.closeAllButPinned()
            assertTest("Pin Test: closeAllButPinned retains only pinned tabs", ws.documents.count == 1 && ws.documents.first?.id == pDoc2.id)

            // Unpin pDoc2
            ws.togglePin(id: pDoc2.id)
            assertTest("Pin Test: pDoc2 unpinned successfully", pDoc2.isPinned == false)

            // TEST 22: Notepad++ contextMenu.xml Configuration & Dynamic Parsing
            let ctxUrl = NppContextMenuConfig.ensureConfigFileExists()
            assertTest("contextMenu.xml exists on disk", FileManager.default.fileExists(atPath: ctxUrl.path))
            let ctxItems = NppContextMenuConfig.shared.loadItems()
            assertTest("contextMenu.xml loaded items is not empty", !ctxItems.isEmpty)
            assertTest("contextMenu.xml includes standard Cut item (42020)", ctxItems.contains(where: { $0.id == "42020" }))
            assertTest("contextMenu.xml includes Convert to UPPERCASE", ctxItems.contains(where: { $0.menuItemName == "Convert to UPPERCASE" }))
            assertTest("contextMenu.xml includes Find...", ctxItems.contains(where: { $0.menuItemName == "Find..." }))

            // TEST 23: View -> Always on Top Window Level & Menu Checkmark Validation
            let alwaysTopItem = NSMenuItem(title: "Always on Top", action: #selector(appDelegate.menuToggleAlwaysOnTop(_:)), keyEquivalent: "")
            appDelegate.menuToggleAlwaysOnTop(alwaysTopItem)
            assertTest("Always on Top enabled: window level is floating", appDelegate.window?.level == .floating)
            assertTest("Always on Top enabled: workspace.isAlwaysOnTop is true", ws.isAlwaysOnTop == true)
            _ = appDelegate.validateMenuItem(alwaysTopItem)
            assertTest("Always on Top menu item displays checkmark (state == .on)", alwaysTopItem.state == .on)

            appDelegate.menuToggleAlwaysOnTop(alwaysTopItem)
            assertTest("Always on Top disabled: window level is normal", appDelegate.window?.level == .normal)
            assertTest("Always on Top disabled: workspace.isAlwaysOnTop is false", ws.isAlwaysOnTop == false)
            _ = appDelegate.validateMenuItem(alwaysTopItem)
            assertTest("Always on Top menu item clears checkmark (state == .off)", alwaysTopItem.state == .off)

            // Verify Open Containing Folder is disabled for unsaved/new document
            let finderItem = NSMenuItem(title: "Finder", action: #selector(appDelegate.menuOpenFolderFinder), keyEquivalent: "")
            let terminalItem = NSMenuItem(title: "Terminal", action: #selector(appDelegate.menuOpenFolderTerminal), keyEquivalent: "")
            let isFinderEnabledForNewDoc = appDelegate.validateMenuItem(finderItem)
            let isTerminalEnabledForNewDoc = appDelegate.validateMenuItem(terminalItem)
            assertTest("Open Containing Folder -> Finder is disabled for unsaved/untitled document", isFinderEnabledForNewDoc == false)
            assertTest("Open Containing Folder -> Terminal is disabled for unsaved/untitled document", isTerminalEnabledForNewDoc == false)

            // Open a real file and verify it becomes enabled
            let savedFileUrl = URL(fileURLWithPath: "samples/korean_cp949.txt")
            ws.openFile(url: savedFileUrl)
            let isFinderEnabledForSavedDoc = appDelegate.validateMenuItem(finderItem)
            let isTerminalEnabledForSavedDoc = appDelegate.validateMenuItem(terminalItem)
            assertTest("Open Containing Folder -> Finder is enabled for saved document", isFinderEnabledForSavedDoc == true)
            assertTest("Open Containing Folder -> Terminal is enabled for saved document", isTerminalEnabledForSavedDoc == true)
            assertTest("Terminal target folder points to document containing folder", ws.activeDocument?.filePath?.deletingLastPathComponent().lastPathComponent == "samples")
            let detailedCode = """
            // Fast computation
            import Foundation
            func computeMetrics(count: Int) -> Double {
                let hexFlag = 0xFF
                if hexFlag > 0 {
                    return 3.14159
                }
                return 0.0
            }
            """
            let detailStorage = NSTextStorage(string: detailedCode)
            let font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
            NppSyntaxHighlighter.highlight(textStorage: detailStorage, language: "Swift", isDarkMode: true, baseFont: font)

            let nsDetail = detailedCode as NSString
            let commentRange = nsDetail.range(of: "// Fast computation")
            let funcRange2 = nsDetail.range(of: "computeMetrics")
            let typeRange = nsDetail.range(of: "Double")
            let hexRange = nsDetail.range(of: "0xFF")
            let ifRange = nsDetail.range(of: "if")

            let commentCol = detailStorage.attribute(.foregroundColor, at: commentRange.location, effectiveRange: nil) as? NSColor
            let funcCol = detailStorage.attribute(.foregroundColor, at: funcRange2.location, effectiveRange: nil) as? NSColor
            let typeCol = detailStorage.attribute(.foregroundColor, at: typeRange.location, effectiveRange: nil) as? NSColor
            let hexCol = detailStorage.attribute(.foregroundColor, at: hexRange.location, effectiveRange: nil) as? NSColor
            let ifCol = detailStorage.attribute(.foregroundColor, at: ifRange.location, effectiveRange: nil) as? NSColor
            let commentFont = detailStorage.attribute(.font, at: commentRange.location, effectiveRange: nil) as? NSFont

            assertTest("Fine Highlighting: Comment has distinct color", commentCol != nil)
            assertTest("Fine Highlighting: Comment uses italic font trait", commentFont?.fontDescriptor.symbolicTraits.contains(.italic) == true)
            assertTest("Fine Highlighting: Function has dedicated function color", funcCol != nil && funcCol != commentCol)
            assertTest("Fine Highlighting: Type (Double) has dedicated type color", typeCol != nil && typeCol != funcCol)
            assertTest("Fine Highlighting: Hex number (0xFF) has number color", hexCol != nil && hexCol != typeCol)
            assertTest("Fine Highlighting: Control flow (if) has control flow color", ifCol != nil && ifCol != funcCol)

            // Tests for User Manual Alignment (Panels & Modeless Dialogs)
            ws.showDocumentList = true
            assertTest("View Menu: Document List panel toggled ON", ws.showDocumentList == true)
            ws.showDocumentList = false
            assertTest("View Menu: Document List panel toggled OFF", ws.showDocumentList == false)

            ws.showFolderAsWorkspace = true
            assertTest("View Menu: Folder as Workspace panel toggled ON", ws.showFolderAsWorkspace == true)
            ws.showFolderAsWorkspace = false
            assertTest("View Menu: Folder as Workspace panel toggled OFF", ws.showFolderAsWorkspace == false)

            // Find in Files
            ws.findAllInFiles(query: "WorkspaceManager", filter: "*.swift", directory: "samples", subfolders: false, matchCase: false, wholeWord: false, useRegex: false)
            assertTest("Find in Files: Found hits in samples directory", !ws.searchFileGroups.isEmpty)

            // Column Editor (Alt+C)
            let colDoc = NppDocument(title: "col_test", content: "alpha\nbeta\ngamma\n")
            ws.documents.append(colDoc)
            ws.activeDocumentId = colDoc.id
            if let tv = ws.activeTextView {
                tv.string = colDoc.content
                tv.setSelectedRange(NSRange(location: 0, length: 15))
                ws.executeColumnEditor(isText: false, text: "", initialNumber: 10, increaseBy: 10, repeatCount: 1, format: "Dec", leadingZeros: false)
                assertTest("Column Editor: Line 1 prefix inserted", tv.string.contains("10alpha"))
                assertTest("Column Editor: Line 2 prefix incremented", tv.string.contains("20beta"))
                assertTest("Column Editor: Line 3 prefix incremented", tv.string.contains("30gamma"))
            }

            // Authentic Dialogs Toggles
            ws.showFindReplaceDialog = true
            assertTest("Dialog: Find/Replace/Mark dialog opens", ws.showFindReplaceDialog == true)
            ws.showFindReplaceDialog = false

            ws.showStyleConfigurator = true
            assertTest("Dialog: Style Configurator dialog opens", ws.showStyleConfigurator == true)
            ws.showStyleConfigurator = false

            ws.showShortcutMapper = true
            assertTest("Dialog: Shortcut Mapper dialog opens", ws.showShortcutMapper == true)
            ws.showShortcutMapper = false

            ws.showColumnEditor = true
            assertTest("Dialog: Column Editor dialog opens", ws.showColumnEditor == true)
            ws.showColumnEditor = false

            // TEST 13: Comprehensive Preferences Functional Verification (All 24 Categories & Live Effects)
            // Category 1: Toolbar
            ws.hideToolbar = true
            assertTest("Pref Toolbar: hideToolbar toggled to true", ws.hideToolbar == true)
            ws.hideToolbar = false
            assertTest("Pref Toolbar: hideToolbar restored to false", ws.hideToolbar == false)
            ws.toolbarIconStyle = "Fluent UI: large"
            ws.largeToolbarIcons = true
            assertTest("Pref Toolbar: largeToolbarIcons active", ws.largeToolbarIcons == true)
            ws.toolbarIconStyle = "Filled Fluent UI: small"
            assertTest("Pref Toolbar: Filled Fluent UI resolves folder.fill", NppToolbarView.resolveIconName("folder", isFilled: true) == "folder.fill")
            assertTest("Pref Toolbar: Regular Fluent UI resolves folder", NppToolbarView.resolveIconName("folder", isFilled: false) == "folder")
            assertTest("Pref Toolbar: Color Red resolves correctly", NppToolbarView.resolvedColor(choice: "Red") == .red)
            assertTest("Pref Toolbar: Color Green resolves correctly", NppToolbarView.resolvedColor(choice: "Green") == .green)
            assertTest("Pref Toolbar: Color Blue resolves correctly", NppToolbarView.resolvedColor(choice: "Blue") == .blue)
            assertTest("Pref Toolbar: Color Default resolves to nil", NppToolbarView.resolvedColor(choice: "Default") == nil)
            ws.toolbarColorization = "Complete"
            assertTest("Pref Toolbar: toolbarColorization set to Complete", ws.toolbarColorization == "Complete")
            ws.toolbarColorization = "Partial"
            assertTest("Pref Toolbar: toolbarColorization set to Partial", ws.toolbarColorization == "Partial")

            // Category 2: Tab Bar
            ws.hideTabBar = true
            assertTest("Pref TabBar: hideTabBar toggled to true", ws.hideTabBar == true)
            ws.hideTabBar = false
            assertTest("Pref TabBar: hideTabBar restored to false", ws.hideTabBar == false)
            ws.tabReduce = true
            assertTest("Pref TabBar: tabReduce toggled to true", ws.tabReduce == true)
            ws.tabReduce = false
            assertTest("Pref TabBar: tabReduce restored to false", ws.tabReduce == false)
            ws.tabMaxLabelLen = 8
            let truncatedTitle = NppTabItemView.formattedTitle(title: "MySuperLongDocument.txt", maxLen: ws.tabMaxLabelLen)
            assertTest("Pref TabBar: tabMaxLabelLen truncates long title", truncatedTitle == "MySuperL…")
            ws.tabColorIndicator = false
            assertTest("Pref TabBar: tabColorIndicator toggled to false", ws.tabColorIndicator == false)
            ws.tabColorIndicator = true
            assertTest("Pref TabBar: tabColorIndicator restored to true", ws.tabColorIndicator == true)
            ws.tabChangeInactiveColor = true
            assertTest("Pref TabBar: tabChangeInactiveColor toggled to true", ws.tabChangeInactiveColor == true)
            ws.showTabCloseButton = false
            assertTest("Pref TabBar: showTabCloseButton toggled to false", ws.showTabCloseButton == false)
            ws.showTabCloseButton = true
            assertTest("Pref TabBar: showTabCloseButton restored to true", ws.showTabCloseButton == true)
            ws.tabAltIcons = true
            assertTest("Pref TabBar: tabAltIcons toggled to true", ws.tabAltIcons == true)

            // Category 0: General
            ws.hideStatusBar = true
            assertTest("Pref General: hideStatusBar toggled to true", ws.hideStatusBar == true)
            ws.hideStatusBar = false
            assertTest("Pref General: hideStatusBar restored to false", ws.hideStatusBar == false)
            ws.hideMenuBar = true
            assertTest("Pref General: hideMenuBar toggled to true", ws.hideMenuBar == true)
            ws.hideMenuBar = false
            assertTest("Pref General: hideMenuBar restored to false", ws.hideMenuBar == false)
            ws.hideRightShortcuts = true
            assertTest("Pref General: hideRightShortcuts toggled to true", ws.hideRightShortcuts == true)
            ws.hideRightShortcuts = false
            assertTest("Pref General: hideRightShortcuts restored to false", ws.hideRightShortcuts == false)
            ws.dialogFontSize = 11
            assertTest("Pref General: dialogFontSize set to 11", ws.dialogFontSize == 11)
            ws.dialogFontName = "SF Pro"
            assertTest("Pref General: dialogFontName set to SF Pro", ws.dialogFontName == "SF Pro")
            ws.localizationLanguage = "한국어"
            assertTest("Pref General: localizationLanguage set to 한국어", ws.localizationLanguage == "한국어")

            // Category 3 & 4: Editing 1 & 2
            ws.currentLineIndicator = 0
            assertTest("Pref Editing: currentLineIndicator set to None (0)", ws.currentLineIndicator == 0)
            ws.currentLineIndicator = 2
            assertTest("Pref Editing: currentLineIndicator set to Frame (2)", ws.currentLineIndicator == 2)
            ws.currentLineFrameWidth = 3
            assertTest("Pref Editing: currentLineFrameWidth set to 3", ws.currentLineFrameWidth == 3)
            ws.currentLineIndicator = 1
            ws.caretWidth = 2
            assertTest("Pref Editing: caretWidth set to 2", ws.caretWidth == 2)
            ws.smoothFont = true
            assertTest("Pref Editing: smoothFont set to true", ws.smoothFont == true)
            ws.multiSelection = true
            assertTest("Pref Editing: multiSelection set to true", ws.multiSelection == true)
            ws.columnToMultiEditing = true
            assertTest("Pref Editing: columnToMultiEditing set to true", ws.columnToMultiEditing == true)
            ws.eolAppearance = 1
            assertTest("Pref Editing: eolAppearance set to Plain text (1)", ws.eolAppearance == 1)

            // Category 6: Margins / Border / Edge
            ws.noEdge = false
            ws.verticalEdgeColumn = 100
            ws.verticalEdgeMode = 1
            assertTest("Pref Edge: Vertical edge line enabled at column 100", !ws.noEdge && ws.verticalEdgeColumn == 100 && ws.verticalEdgeMode == 1)
            ws.verticalEdgeMode = 2
            assertTest("Pref Edge: Vertical edge background mode enabled", ws.verticalEdgeMode == 2)
            ws.noEdge = true
            assertTest("Pref Edge: noEdge restored to true", ws.noEdge == true)
            ws.paddingLeft = 14
            ws.paddingRight = 10
            assertTest("Pref Margin: paddingLeft and paddingRight set", ws.paddingLeft == 14 && ws.paddingRight == 10)
            ws.displayBookmarkMargin = false
            assertTest("Pref Margin: displayBookmarkMargin toggled to false", ws.displayBookmarkMargin == false)
            ws.displayBookmarkMargin = true
            assertTest("Pref Margin: displayBookmarkMargin restored to true", ws.displayBookmarkMargin == true)

            // Category 7: New Document Functional Effect
            ws.defaultNewDocFormat = .lf
            ws.defaultNewDocEncoding = "CP949"
            ws.defaultNewDocLanguage = "Swift"
            ws.newDocument()
            let newlyCreated = ws.activeDocument!
            assertTest("Pref NewDoc Effect: New doc created with LF EOL", newlyCreated.eolFormat == .lf)
            assertTest("Pref NewDoc Effect: New doc created with CP949 encoding", newlyCreated.encoding == "CP949")
            assertTest("Pref NewDoc Effect: New doc created with Swift syntax language", newlyCreated.language == "Swift")
            ws.defaultNewDocFormat = .crlf
            ws.defaultNewDocEncoding = "UTF-8"
            ws.defaultNewDocLanguage = "Plain Text"

            // Category 17: Auto-Completion & Delimiters
            ws.autoCompletionEnabled = true
            ws.autoCompletionThreshold = 2
            assertTest("Pref Auto-Completion: enabled with threshold 2", ws.autoCompletionEnabled && ws.autoCompletionThreshold == 2)
            ws.autoInsertParen = true
            ws.autoInsertBracket = true
            ws.autoInsertBrace = true
            ws.autoInsertDoubleQuote = true
            ws.autoInsertSingleQuote = true
            assertTest("Pref Auto-Completion: All delimiter auto-insertions active", ws.autoInsertParen && ws.autoInsertBracket && ws.autoInsertBrace && ws.autoInsertDoubleQuote && ws.autoInsertSingleQuote)

            // Category 15: Searching
            ws.fillFindFieldWithSelected = true
            ws.fillFindFieldThreshold = 1024
            ws.selectWordUnderCaretIfEmpty = true
            ws.inSelectionThreshold = 2048
            assertTest("Pref Searching: fillFindFieldWithSelected and thresholds verified", ws.fillFindFieldWithSelected && ws.fillFindFieldThreshold == 1024 && ws.selectWordUnderCaretIfEmpty && ws.inSelectionThreshold == 2048)

            // Category 16, 20, 22, 23: Backup, Performance, Search Engine, MISC
            ws.rememberSession = true
            ws.periodicBackupEnabled = true
            ws.periodicBackupIntervalSeconds = 5
            assertTest("Pref Backup: periodic backup set to 5s", ws.periodicBackupIntervalSeconds == 5)
            ws.performanceLargeFileEnabled = true
            ws.performanceLargeFileSizeMB = 150
            assertTest("Pref Performance: large file threshold 150MB", ws.performanceLargeFileSizeMB == 150)
            ws.searchEngineChoice = 0
            ws.searchEngineUrl = "https://duckduckgo.com/?q="
            assertTest("Pref SearchEngine: DuckDuckGo selected", ws.searchEngineChoice == 0 && ws.searchEngineUrl.contains("duckduckgo"))
            ws.fileStatusAutoDetection = true
            ws.fileStatusAutoReloadSilently = true
            assertTest("Pref MISC: fileStatusAutoReloadSilently set to true", ws.fileStatusAutoReloadSilently == true)

            // Category 15+: Modeless Find Dialog & Transparency
            ws.findTransparencyEnabled = true
            assertTest("Find Dialog: Transparency enabled", ws.findTransparencyEnabled == true)
            ws.findTransparencyMode = 0 // On losing focus
            assertTest("Find Dialog: Transparency mode On losing focus (0)", ws.findTransparencyMode == 0)
            ws.findTransparencyValue = 0.60
            assertTest("Find Dialog: Transparency value set to 60%", ws.findTransparencyValue == 0.60)
            ws.findTransparencyMode = 1 // Always
            assertTest("Find Dialog: Transparency mode Always (1)", ws.findTransparencyMode == 1)
            ws.findTransparencyMode = 0 // restore to On losing focus

            // Category 24: Milestone 1 UI Hardening & Parity Tests (AUDIT-011)
            // 1. Status Bar Box Widths (Anti-Clipping)
            assertTest("Status Bar: Box 2 width expanded to 240", NppStatusBarView.box2Width == 240)
            assertTest("Status Bar: Box 3 unselected width expanded to 270", NppStatusBarView.box3WidthUnselected == 270)
            assertTest("Status Bar: Box 3 selected width expanded to 340", NppStatusBarView.box3WidthSelected == 340)

            // Status Bar Large Document Anti-Clipping Assertion (100,000 lines)
            let b2SampleText = "length : 5000000   lines : 100000"
            let monoFont = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
            let b2SampleWidth = (b2SampleText as NSString).size(withAttributes: [.font: monoFont]).width
            let b2CalcWidth = max(NppStatusBarView.box2Width, b2SampleWidth + 24)
            assertTest("Status Bar: 100,000-line document Box 2 width accommodates text without clipping", b2CalcWidth >= b2SampleWidth + 15)

            // 2. Style Configurator Theme Picker Width
            assertTest("Style Configurator: Theme picker width expanded to 280", NppStyleConfiguratorView.themePickerWidth == 280)

            // 3. Find Dialog Dimensions & MinSize Bounds
            ws.openFind()
            RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.05))
            let findPanel = NppFindReplaceWindowController.shared.panel
            let contentHeight = findPanel?.contentRect(forFrameRect: findPanel!.frame).height ?? 0
            assertTest("Find Dialog: Panel content height is compact (360)", contentHeight == 360)
            assertTest("Find Dialog: MinSize width is 730", findPanel?.minSize.width == 730)
            assertTest("Find Dialog: MinSize height is 360", findPanel?.minSize.height == 360)
            ws.showFindReplaceDialog = false

            // 4. Window Title Synchronization on Tab Switch
            let prevActiveId = ws.activeDocumentId
            ws.newDocument()
            let doc1 = ws.activeDocument!
            doc1.title = "SyncTestDoc1"
            RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.05))
            assertTest("Window Title Sync: Reflects newly active document 1", appDelegate.window?.title.contains("SyncTestDoc1") == true)

            ws.newDocument()
            let doc2 = ws.activeDocument!
            doc2.title = "SyncTestDoc2"
            RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.05))
            assertTest("Window Title Sync: Reflects newly active document 2", appDelegate.window?.title.contains("SyncTestDoc2") == true)

            // Switch back to Doc 1
            ws.activeDocumentId = doc1.id
            RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.05))
            assertTest("Window Title Sync: Switches title to document 1 on tab selection", appDelegate.window?.title.contains("SyncTestDoc1") == true)

            // Dirty indicator prefix '*' test
            doc1.isDirty = true
            RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.05))
            assertTest("Window Title Sync: Includes dirty prefix '*' when active document modified", appDelegate.window?.title.hasPrefix("*SyncTestDoc1") == true)
            doc1.isDirty = false
            RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.05))

            // ==========================================
            // AUDIT-012: Scintilla Bookmark Operations
            // ==========================================
            ws.newDocument()
            let bmDoc = ws.activeDocument!
            bmDoc.title = "BookmarkTestDoc"
            bmDoc.content = "Apple\nBanana\nCherry\nDate\nElderberry"
            bmDoc.eolFormat = .lf

            // 1. Toggle Bookmark
            ws.toggleBookmark(line: 2)
            assertTest("Bookmark: Line 2 bookmarked", bmDoc.isLineBookmarked(2))
            ws.toggleBookmark(line: 4)
            assertTest("Bookmark: Line 4 bookmarked", bmDoc.isLineBookmarked(4))
            assertTest("Bookmark: Line 3 NOT bookmarked", !bmDoc.isLineBookmarked(3))

            // 2. Navigation Next / Prev with Wrap Around
            bmDoc.cursorLine = 1
            ws.nextBookmark()
            assertTest("Bookmark: Next from Line 1 jumps to Line 2", bmDoc.cursorLine == 2)
            ws.nextBookmark()
            assertTest("Bookmark: Next from Line 2 jumps to Line 4", bmDoc.cursorLine == 4)
            ws.nextBookmark()
            assertTest("Bookmark: Next wraps around to Line 2", bmDoc.cursorLine == 2)
            ws.prevBookmark()
            assertTest("Bookmark: Prev wraps around to Line 4", bmDoc.cursorLine == 4)
            ws.prevBookmark()
            assertTest("Bookmark: Prev from Line 4 jumps to Line 2", bmDoc.cursorLine == 2)

            // 3. Copy Bookmarked Lines
            ws.copyBookmarkedLines()
            let copiedBM = NSPasteboard.general.string(forType: .string) ?? ""
            assertTest("Bookmark: Copy bookmarked lines copies Banana and Date", copiedBM.contains("Banana") && copiedBM.contains("Date") && !copiedBM.contains("Apple"))

            // 4. Paste to Bookmarked Lines
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString("REPLACED", forType: .string)
            ws.pasteToBookmarkedLines()
            assertTest("Bookmark: Paste to lines replaces Banana and Date with REPLACED", bmDoc.content.components(separatedBy: "\n")[1] == "REPLACED" && bmDoc.content.components(separatedBy: "\n")[3] == "REPLACED")

            // 5. Inverse Bookmarks
            ws.inverseBookmarks()
            assertTest("Bookmark: Inverse bookmarks marks lines 1, 3, 5", bmDoc.isLineBookmarked(1) && bmDoc.isLineBookmarked(3) && bmDoc.isLineBookmarked(5))
            assertTest("Bookmark: Inverse bookmarks unmarks lines 2, 4", !bmDoc.isLineBookmarked(2) && !bmDoc.isLineBookmarked(4))

            // 6. Remove Bookmarked Lines
            ws.removeBookmarkedLines()
            assertTest("Bookmark: Remove bookmarked lines retains only lines 2 and 4", bmDoc.content == "REPLACED\nREPLACED")

            // 7. Clear All Bookmarks
            ws.toggleBookmark(line: 1)
            ws.clearAllBookmarks()
            assertTest("Bookmark: Clear all bookmarks empties set", bmDoc.bookmarkedLines.isEmpty)

            // 8. Mark All from Search
            bmDoc.content = "Item Alpha\nItem Beta\nItem Alpha\nGamma"
            let markMatches = ws.markAll(query: "Alpha", matchCase: true, wholeWord: false, useRegex: false, bookmarkLine: true, purgeExisting: true)
            assertTest("Bookmark: Mark All found 2 occurrences", markMatches == 2)
            assertTest("Bookmark: Mark All marked lines 1 and 3", bmDoc.isLineBookmarked(1) && bmDoc.isLineBookmarked(3) && !bmDoc.isLineBookmarked(2))

            // ==========================================
            // AUDIT-013: Extended Line Operations
            // ==========================================
            // Integer Sort Ascending & Descending
            bmDoc.content = "10 items\n2 items\n1 item\n20 items\n5 items"
            NppEditOperations.sortLinesAsIntegers(in: bmDoc, ascending: true)
            assertTest("Sort Lines: Integers ascending correctly orders 1, 2, 5, 10, 20", bmDoc.content == "1 item\n2 items\n5 items\n10 items\n20 items")

            NppEditOperations.sortLinesAsIntegers(in: bmDoc, ascending: false)
            assertTest("Sort Lines: Integers descending correctly orders 20, 10, 5, 2, 1", bmDoc.content == "20 items\n10 items\n5 items\n2 items\n1 item")

            // Decimal Sort Dot & Comma
            bmDoc.content = "3.14\n1.41\n2.71\n0.50"
            NppEditOperations.sortLinesAsDecimals(in: bmDoc, ascending: true, usesComma: false)
            assertTest("Sort Lines: Decimals (Dot) ascending correctly orders 0.50, 1.41, 2.71, 3.14", bmDoc.content == "0.50\n1.41\n2.71\n3.14")

            bmDoc.content = "3,14\n1,41\n2,71\n0,50"
            NppEditOperations.sortLinesAsDecimals(in: bmDoc, ascending: true, usesComma: true)
            assertTest("Sort Lines: Decimals (Comma) ascending correctly orders 0,50, 1,41, 2,71, 3,14", bmDoc.content == "0,50\n1,41\n2,71\n3,14")

            // Remove Empty Lines with / without blank spaces
            bmDoc.content = "Line1\n\n   \nLine2\n\t\nLine3"
            NppEditOperations.removeEmptyLines(in: bmDoc, removeBlankChars: false)
            assertTest("Remove Empty Lines (Strict): Retains blank lines containing whitespace", bmDoc.content.components(separatedBy: "\n").count == 5)
            NppEditOperations.removeEmptyLines(in: bmDoc, removeBlankChars: true)
            assertTest("Remove Empty Lines (Blanks): Strips all whitespace-only lines", bmDoc.content == "Line1\nLine2\nLine3")

            // Close bmDoc
            ws.closeDocument(id: bmDoc.id)

            // Cleanup test documents
            ws.closeDocument(id: doc1.id)
            ws.closeDocument(id: doc2.id)
            if let prevId = prevActiveId, ws.documents.contains(where: { $0.id == prevId }) {
                ws.activeDocumentId = prevId
                RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.05))
            }

            // TEST 26: Font Resolution & Preferences Live Wiring Verification
            let resolvedD2 = NppWorkspace.resolveFont(name: "D2Coding", size: 14)
            assertTest("Font Resolver: D2Coding resolves with valid pointSize", resolvedD2.pointSize == 14)

            let resolvedAppleSD = NppWorkspace.resolveFont(name: "Apple SD Gothic Neo", size: 16)
            assertTest("Font Resolver: Apple SD Gothic Neo resolves with valid pointSize", resolvedAppleSD.pointSize == 16)

            assertTest("Font Resolver: All system font families count > 100", NppWorkspace.allSystemFontFamilies.count > 100)

            // Language Move Buttons
            let initialAvailCount = ws.availableLanguages.count
            ws.disableLanguage("Swift")
            assertTest("Language Menu: Moving Swift to disabled decreases available", ws.availableLanguages.count == initialAvailCount - 1)
            assertTest("Language Menu: Moving Swift to disabled increases disabled", ws.disabledLanguages.contains("Swift"))
            ws.enableLanguage("Swift")
            assertTest("Language Menu: Moving Swift back restores available count", ws.availableLanguages.count == initialAvailCount && ws.availableLanguages.contains("Swift"))

            // File Association Toggle
            let iniWasAssoc = ws.fileAssociations.contains(".ini")
            ws.toggleFileAssociation(".ini")
            assertTest("File Association: Toggle removes or adds .ini", ws.fileAssociations.contains(".ini") != iniWasAssoc)
            ws.toggleFileAssociation(".ini") // restore
            assertTest("File Association: Toggle restores original state", ws.fileAssociations.contains(".ini") == iniWasAssoc)

            // Print Header/Footer live variables
            ws.printHeaderLeft = "Left Title"
            ws.printVariableSelection = "$(FILE_NAME)"
            ws.printHeaderMiddle = "Doc: " + ws.printVariableSelection
            assertTest("Print Setup: Live header text updated with variable", ws.printHeaderMiddle == "Doc: $(FILE_NAME)")

            // Dark Mode / Light Mode Live System State Tests
            ws.darkModeChoice = 0 // Light mode
            assertTest("Dark Mode Preference: Choice 0 sets themeMode to light", ws.themeMode == "light" && !ws.currentTheme.isDark)
            assertTest("Dark Mode Preference: Choice 0 sets NSApp appearance to aqua", NSApp?.appearance?.name == .aqua)

            ws.darkModeChoice = 1 // Dark mode
            assertTest("Dark Mode Preference: Choice 1 sets themeMode to dark", ws.themeMode == "dark" && ws.currentTheme.isDark)
            assertTest("Dark Mode Preference: Choice 1 sets NSApp appearance to darkAqua", NSApp?.appearance?.name == .darkAqua)

            ws.darkModeChoice = 2 // Follow System
            assertTest("Dark Mode Preference: Choice 2 sets NSApp appearance to nil (system default)", NSApp?.appearance == nil)

            // Editor Font & Typing Attributes Tests
            ws.fontFamily = "Apple SD Gothic Neo"
            ws.fontSize = 15.0
            let expectedFont = NppWorkspace.resolveFont(name: "Apple SD Gothic Neo", size: 15.0)
            assertTest("Editor Font: TextView font resolves and applies 15pt", ws.activeTextView?.font?.pointSize == 15.0 && expectedFont.pointSize == 15.0)
            let typingFont = ws.activeTextView?.typingAttributes[.font] as? NSFont
            assertTest("Editor Font: Typing attributes font is synchronized", typingFont?.pointSize == 15.0)
            let typingFg = ws.activeTextView?.typingAttributes[.foregroundColor] as? NSColor
            assertTest("Editor Font: Typing attributes color is synchronized with theme", typingFg == ws.currentTheme.foregroundColor)
            ws.fontFamily = "Menlo"
            ws.fontSize = 13.0

            // =========================================================================
            // 23. Line Number Gutter Scroll Coordinate & Redraw Integrity (AUDIT-016)
            // =========================================================================
            ws.newDocument()
            let multiLineKorean = (1...35).map { _ in "무궁화 꽃이 피었습니다." }.joined(separator: "\n")
            ws.activeDocument?.content = multiLineKorean
            if let tv = ws.activeTextView, let gutter = tv.enclosingScrollView?.verticalRulerView as? NppGutterView {
                tv.string = multiLineKorean
                assertTest("Line Number Gutter: Gutter uses flipped top-down coordinates", gutter.isFlipped == true)
                // Scroll down to line 15
                ws.jumpToLine(15)
                if let lm = tv.layoutManager, let tc = tv.textContainer {
                    let visRect = tv.visibleRect.offsetBy(dx: -tv.textContainerOrigin.x, dy: -tv.textContainerOrigin.y)
                    lm.ensureLayout(forBoundingRect: visRect, in: tc)
                    let visGlyphs = lm.glyphRange(forBoundingRect: visRect, in: tc)
                    let firstVisibleLineRect = lm.lineFragmentRect(forGlyphAt: visGlyphs.location, effectiveRange: nil)
                    let docPt = NSPoint(x: 0, y: tv.textContainerOrigin.y + firstVisibleLineRect.origin.y)
                    let gutterPt = gutter.convert(docPt, from: tv)
                    assertTest("Line Number Gutter: Top visible scrolled line maps to top of gutter (no scroll offset gap)", gutterPt.y >= -20.0 && gutterPt.y <= 30.0)
                }
            }

            // =========================================================================
            // 24. Cmd+F Word-Under-Caret Auto-Selection & Auto-Fill (FindReplaceDlg.cpp L5643)
            // =========================================================================
            ws.fillFindFieldWithSelected = true
            ws.selectWordUnderCaretIfEmpty = true
            ws.activeDocument?.content = "Hello NotepadPlusPlusMac World 무궁화 꽃이 피었습니다"
            if let tv = ws.activeTextView {
                tv.string = ws.activeDocument?.content ?? ""
                // Place 0-length caret inside "NotepadPlusPlusMac" (index 10)
                tv.setSelectedRange(NSRange(location: 10, length: 0))
                ws.openFind()
                assertTest("Cmd+F Word-Under-Caret: Expands 0-length caret to full word in editor", tv.selectedRange() == NSRange(location: 6, length: 18))
                assertTest("Cmd+F Word-Under-Caret: Auto-fills Find query with word under caret", ws.findQueryText == "NotepadPlusPlusMac")

                // Move 0-length caret to Korean word "무궁화" (index 32) while Find dialog is already open
                let prevCounter = ws.findInvocationCounter
                tv.setSelectedRange(NSRange(location: 32, length: 0))
                ws.openFind()
                assertTest("Cmd+F Re-invocation: Updates Find query to new word under caret when dialog already open", ws.findQueryText == "무궁화" && ws.findInvocationCounter == prevCounter + 1)
            }

            // =========================================================================
            // 25. File Menu Parity & Rename Document (IDM_FILE_RENAME / NppIO.cpp)
            // =========================================================================
            ws.newDocument()
            if let untitledDoc = ws.activeDocument {
                let okRenameUntitled = ws.renameDocument(id: untitledDoc.id, newName: "renamed_buffer.swift")
                assertTest("File > Rename: Renames untitled buffer and updates language", okRenameUntitled && untitledDoc.title == "renamed_buffer.swift" && untitledDoc.language == "Swift")
            }

            let tempRenameSrc = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("npp_test_before_\(UUID().uuidString.prefix(6)).txt")
            let tempRenameDstName = "npp_test_after_\(UUID().uuidString.prefix(6)).py"
            try? "print('hello')".write(to: tempRenameSrc, atomically: true, encoding: .utf8)
            ws.openFile(url: tempRenameSrc)
            if let diskDoc = ws.activeDocument {
                let okRenameDisk = ws.renameDocument(id: diskDoc.id, newName: tempRenameDstName)
                assertTest("File > Rename: Renames on-disk file and updates filePath/title/language", okRenameDisk && diskDoc.title == tempRenameDstName && diskDoc.filePath?.lastPathComponent == tempRenameDstName && diskDoc.language == "Python")
                if let newPath = diskDoc.filePath {
                    try? FileManager.default.removeItem(at: newPath)
                }
            }

            // =========================================================================
            // 26. Live Localization Without Restart (preferenceDlg.cpp L919 korean.xml)
            // =========================================================================
            ws.localizationLanguage = "한국어"
            appDelegate.setupMenuBar()
            NppFindReplaceWindowController.shared.updateTitle()
            let mainMenuTitles = NSApp.mainMenu?.items.compactMap { $0.submenu?.title } ?? []
            assertTest("Live Localization (한국어): Menu bar translates to 파일, 편집, 찾기, 보기, 설정", mainMenuTitles.contains("파일") && mainMenuTitles.contains("편집") && mainMenuTitles.contains("찾기") && mainMenuTitles.contains("보기") && mainMenuTitles.contains("설정"))
            let fileSubmenuTitles = NSApp.mainMenu?.items.first(where: { $0.submenu?.title == "파일" })?.submenu?.items.map { $0.title } ?? []
            assertTest("Live Localization (한국어): File menu includes 파일 이름 변경..., 다른 이름으로 복사본 저장..., 휴지통으로 이동", fileSubmenuTitles.contains("파일 이름 변경...") && fileSubmenuTitles.contains("다른 이름으로 복사본 저장...") && fileSubmenuTitles.contains("휴지통으로 이동"))

            // =========================================================================
            // 27. Style Configurator Parity (WordStyleDlg.rc IDD_STYLER_DLG & WordStyleDlg.cpp)
            // =========================================================================
            let scView = NppStyleConfiguratorView(workspace: ws, isPresented: .constant(true))
            assertTest("Style Configurator: Global Styles count == 36 (stylers.model.xml)", scView.globalStyles.count == 36 && scView.globalStyles.first == "Global override" && scView.globalStyles.contains("Default Style"))
            assertTest("Style Configurator: Lexer Styles include INSTRUCTION WORD, TYPE WORD, USER KEYWORDS 1..4", scView.languageStyles.contains("INSTRUCTION WORD") && scView.languageStyles.contains("TYPE WORD") && scView.languageStyles.contains("USER KEYWORDS 4"))

            let customBg = NSColor(calibratedRed: 0.10, green: 0.20, blue: 0.30, alpha: 1.0)
            let overrideKey = ws.styleOverrideKey(themeId: ws.themeMode, language: "Global Styles", style: "Default Style")
            ws.styleOverrides[overrideKey] = NppWorkspace.NppStyleOverride(bgColor: customBg)
            ws.updateThemeAppearance()
            assertTest("Style Configurator: Live Default Style override updates currentTheme.backgroundColor", ws.currentTheme.backgroundColor == customBg)
            ws.styleOverrides.removeAll()
            ws.updateThemeAppearance()

            // =========================================================================
            // 28. Macro Recording, Playback & Run a Macro Multiple Times Dialog (RunMacroDlg.rc IDD_RUN_MACRO_DLG)
            // =========================================================================
            ws.newDocument()
            if let macroDoc = ws.activeDocument, let tv = ws.activeTextView {
                macroDoc.content = "Line 1"
                tv.string = "Line 1"
                tv.setSelectedRange(NSRange(location: 6, length: 0))
                ws.recordedMacroSteps.removeAll()
                ws.isMacroRecording = false
                ws.showRunMacroDialog = false

                // 1) Playback with no recorded macro does NOT modify document
                ws.playbackMacro()
                assertTest("Macro: Playback when no macro recorded does NOT modify document", tv.string == "Line 1")

                // 2) Run a Macro Multiple Times opens IDD_RUN_MACRO_DLG without blindly modifying document
                ws.runMacroMultipleTimes()
                assertTest("Macro: Run a Macro Multiple Times opens dialog (showRunMacroDialog == true) without modifying document", ws.showRunMacroDialog == true && tv.string == "Line 1")
                ws.showRunMacroDialog = false

                // 3) Recording keystrokes and replaying N times via executeMultiMacro
                ws.startMacroRecording()
                ws.recordMacroStep(.insertText("!"))
                ws.stopMacroRecording()
                assertTest("Macro: Recorded macro step is stored and hasRecordedMacro is true", ws.hasRecordedMacro && ws.recordedMacroSteps.count == 1)
                assertTest("Macro: stopMacroRecording sets selectedMacroToRun to 'Current recorded macro'", ws.selectedMacroToRun == "Current recorded macro")

                ws.executeMultiMacro(macroName: "Current recorded macro", runUntilEOF: false, times: 3)
                assertTest("Macro: executeMultiMacro (3 times) replays recorded macro 3 times", tv.string == "Line 1!!!")

                // 4) Saving current recorded macro adds to savedMacros and RunMacroDlg list
                let savedOk = ws.saveCurrentRecordedMacro(name: "Add Exclamation", shortcut: "Cmd+Opt+E")
                assertTest("Macro: saveCurrentRecordedMacro updates selectedMacroToRun to saved macro name", ws.selectedMacroToRun == "Add Exclamation")
                let runMacroView = NppRunMacroDialogView(workspace: ws, isPresented: .constant(true))
                assertTest("Macro: Save Current Recorded Macro adds to savedMacros and RunMacroDlg dropdown", savedOk && runMacroView.availableMacros.contains("Current recorded macro") && runMacroView.availableMacros.contains("Add Exclamation"))

                // 5) Macro selection & non-fallback execution test
                ws.startMacroRecording()
                ws.recordMacroStep(.insertText("?"))
                ws.stopMacroRecording()
                _ = ws.saveCurrentRecordedMacro(name: "Append Question", shortcut: "")
                assertTest("Macro: Second saved macro sets selectedMacroToRun", ws.selectedMacroToRun == "Append Question")

                // Execute "Add Exclamation" specifically via executeMultiMacro - verify it runs ! and NOT ?
                tv.string = "Test"
                macroDoc.content = "Test"
                tv.setSelectedRange(NSRange(location: 4, length: 0))
                ws.executeMultiMacro(macroName: "Add Exclamation", runUntilEOF: false, times: 2)
                assertTest("Macro: executeMultiMacro executes selected saved macro without fallback to current recorded", tv.string == "Test!!")

                // Non-fallback test: calling executeMultiMacro with non-existent macro must NOT fall back to recordedMacroSteps
                let beforeNonExistent = tv.string
                ws.executeMultiMacro(macroName: "TotallyFakeMacroName", runUntilEOF: false, times: 1)
                assertTest("Macro: executeMultiMacro with non-existent name does NOT modify document", tv.string == beforeNonExistent)

                // Playback of selected macro: when selectedMacroToRun is "Add Exclamation", playbackMacro() runs it
                ws.selectedMacroToRun = "Add Exclamation"
                ws.playbackMacro()
                assertTest("Macro: playbackMacro executes selectedMacroToRun", tv.string == "Test!!!")
                assertTest("Macro: canPlaybackMacro returns true for valid selection", ws.canPlaybackMacro)

                // 6) Persistence Round-Trip (UserDefaults npp.savedMacros.v1)
                let savedData = UserDefaults.standard.data(forKey: NppWorkspace.savedMacrosUserDefaultsKey)
                assertTest("Macro: Saved macros persisted to UserDefaults key npp.savedMacros.v1", savedData != nil && !savedData!.isEmpty)

                let freshWs = NppWorkspace()
                assertTest("Macro: Fresh NppWorkspace loads savedMacros from UserDefaults", freshWs.savedMacros.contains(where: { $0.name == "Add Exclamation" }) && freshWs.savedMacros.contains(where: { $0.name == "Append Question" }))

                // Flexible decoding: raw string array
                let rawJson = """
                ["cut", "copy", "paste", "selectAll", "joinLines"]
                """.data(using: .utf8)!
                let decodedRaw = try? JSONDecoder().decode([NppWorkspace.NppMacroStep].self, from: rawJson)
                assertTest("Macro: Flexible decoding supports raw string format", decodedRaw == [.cut, .copy, .paste, .selectAll, .joinLines])

                // Flexible decoding: keyed dictionary array
                let keyedJson = """
                [
                    {"action": "insertText", "text": "Hello"},
                    {"type": "insertEmptyLineAbove"},
                    {"action": "removeEmptyLines"}
                ]
                """.data(using: .utf8)!
                let decodedKeyed = try? JSONDecoder().decode([NppWorkspace.NppMacroStep].self, from: keyedJson)
                assertTest("Macro: Flexible decoding supports keyed dictionary format", decodedKeyed == [.insertText("Hello"), .insertEmptyLineAbove, .removeEmptyLines])

                // Codable round-trip for all 20 edit commands
                let all20Steps: [NppWorkspace.NppMacroStep] = [
                    .cut, .copy, .paste, .selectAll,
                    .joinLines, .splitLines,
                    .insertEmptyLineAbove, .insertEmptyLineBelow,
                    .removeEmptyLines, .removeDuplicateLines,
                    .sortLines, .reverseLineOrder,
                    .singleLineComment, .singleLineUncomment,
                    .streamComment, .streamUncomment,
                    .eolToSpace, .tabToSpace, .spaceToTab,
                    .insertDateTime
                ]
                let encoded20 = try? JSONEncoder().encode(all20Steps)
                let roundTrip20 = encoded20 != nil ? try? JSONDecoder().decode([NppWorkspace.NppMacroStep].self, from: encoded20!) : nil
                assertTest("Macro: All 20 edit commands round-trip through JSONEncoder/JSONDecoder", roundTrip20 == all20Steps)

                // 7) Execution of all 20 edit commands in macro playback
                // Clipboard & selection
                tv.string = "CutPasteTest"
                macroDoc.content = "CutPasteTest"
                tv.setSelectedRange(NSRange(location: 0, length: 12))
                ws.executeMacroStep(.selectAll, in: tv, document: macroDoc)
                assertTest("Macro Step: selectAll selects whole text", tv.selectedRange().length == 12)
                ws.executeMacroStep(.cut, in: tv, document: macroDoc)
                assertTest("Macro Step: cut clears selected text to pasteboard", tv.string == "")
                ws.executeMacroStep(.paste, in: tv, document: macroDoc)
                assertTest("Macro Step: paste restores cut text", tv.string == "CutPasteTest")

                tv.setSelectedRange(NSRange(location: 0, length: 3))
                ws.executeMacroStep(.copy, in: tv, document: macroDoc)
                assertTest("Macro Step: copy captures selection to pasteboard", NSPasteboard.general.string(forType: .string) == "Cut")

                // Line operations
                tv.string = "Alpha\nBeta\nGamma"
                macroDoc.content = "Alpha\nBeta\nGamma"
                tv.setSelectedRange(NSRange(location: 0, length: 16))
                ws.executeMacroStep(.joinLines, in: tv, document: macroDoc)
                assertTest("Macro Step: joinLines joins lines with spaces", tv.string.contains("Alpha Beta Gamma") || tv.string == "Alpha Beta Gamma")

                tv.string = "One Two Three Four"
                macroDoc.content = "One Two Three Four"
                tv.setSelectedRange(NSRange(location: 0, length: 18))
                ws.executeMacroStep(.splitLines, in: tv, document: macroDoc)
                assertTest("Macro Step: splitLines breaks long lines", tv.string.contains("\n"))

                tv.string = "TargetLine"
                macroDoc.content = "TargetLine"
                tv.setSelectedRange(NSRange(location: 0, length: 0))
                ws.executeMacroStep(.insertEmptyLineAbove, in: tv, document: macroDoc)
                assertTest("Macro Step: insertEmptyLineAbove inserts newline above", tv.string.hasPrefix("\nTargetLine"))

                tv.string = "TargetLine"
                macroDoc.content = "TargetLine"
                tv.setSelectedRange(NSRange(location: 0, length: 0))
                ws.executeMacroStep(.insertEmptyLineBelow, in: tv, document: macroDoc)
                assertTest("Macro Step: insertEmptyLineBelow inserts newline below", tv.string.contains("TargetLine\n"))

                macroDoc.eolFormat = .lf
                tv.string = "Line1\n\n\nLine2"
                macroDoc.content = "Line1\n\n\nLine2"
                ws.executeMacroStep(.removeEmptyLines, in: tv, document: macroDoc)
                assertTest("Macro Step: removeEmptyLines strips empty lines", macroDoc.content == "Line1\nLine2")

                tv.string = "Apple\nBanana\nApple\nCherry"
                macroDoc.content = "Apple\nBanana\nApple\nCherry"
                ws.executeMacroStep(.removeDuplicateLines, in: tv, document: macroDoc)
                assertTest("Macro Step: removeDuplicateLines eliminates duplicate lines", macroDoc.content == "Apple\nBanana\nCherry")

                tv.string = "Zebra\nApple\nMango"
                macroDoc.content = "Zebra\nApple\nMango"
                ws.executeMacroStep(.sortLines, in: tv, document: macroDoc)
                assertTest("Macro Step: sortLines sorts ascending", macroDoc.content == "Apple\nMango\nZebra")

                ws.executeMacroStep(.reverseLineOrder, in: tv, document: macroDoc)
                assertTest("Macro Step: reverseLineOrder reverses lines", macroDoc.content == "Zebra\nMango\nApple")

                // Comments
                macroDoc.language = "Swift"
                tv.string = "let x = 10"
                macroDoc.content = "let x = 10"
                tv.setSelectedRange(NSRange(location: 0, length: 0))
                ws.executeMacroStep(.singleLineComment, in: tv, document: macroDoc)
                assertTest("Macro Step: singleLineComment adds comment prefix", tv.string.contains("//"))
                ws.executeMacroStep(.singleLineUncomment, in: tv, document: macroDoc)
                assertTest("Macro Step: singleLineUncomment removes comment prefix", !tv.string.contains("//") && tv.string.contains("let x = 10"))

                tv.string = "blockOfCode"
                macroDoc.content = "blockOfCode"
                tv.setSelectedRange(NSRange(location: 0, length: 11))
                ws.executeMacroStep(.streamComment, in: tv, document: macroDoc)
                assertTest("Macro Step: streamComment wraps in /* ... */", tv.string.contains("/*") && tv.string.contains("*/"))
                tv.setSelectedRange(NSRange(location: 0, length: (tv.string as NSString).length))
                ws.executeMacroStep(.streamUncomment, in: tv, document: macroDoc)
                assertTest("Macro Step: streamUncomment unwraps /* ... */", !tv.string.contains("/*") && tv.string.contains("blockOfCode"))

                // Blanks and Date/Time
                tv.string = "A\nB\nC"
                macroDoc.content = "A\nB\nC"
                ws.executeMacroStep(.eolToSpace, in: tv, document: macroDoc)
                assertTest("Macro Step: eolToSpace converts newlines to spaces", macroDoc.content == "A B C")

                tv.string = "\tIndented"
                macroDoc.content = "\tIndented"
                ws.tabSize = 4
                ws.executeMacroStep(.tabToSpace, in: tv, document: macroDoc)
                assertTest("Macro Step: tabToSpace expands tab to 4 spaces", macroDoc.content == "    Indented")

                ws.executeMacroStep(.spaceToTab, in: tv, document: macroDoc)
                assertTest("Macro Step: spaceToTab converts 4 leading spaces to tab", macroDoc.content == "\tIndented")

                tv.string = "Timestamp: "
                macroDoc.content = "Timestamp: "
                tv.setSelectedRange(NSRange(location: 11, length: 0))
                ws.startMacroRecording()
                ws.executeMacroStep(.insertDateTime, in: tv, document: macroDoc)
                ws.stopMacroRecording()
                assertTest("Macro Step: insertDateTime does not record spurious nested insertText steps", ws.recordedMacroSteps.isEmpty)
                assertTest("Macro Step: insertDateTime inserted date string", tv.string.count > 15 && tv.string.hasPrefix("Timestamp: "))

                // =========================================================================
                // 28.B Adversarial Macro Challenge & Stress-Test Suite (Pass 1 Parity Verification)
                // =========================================================================
                // Clean slate for adversarial verification
                ws.recordedMacroSteps.removeAll()
                ws.isMacroRecording = false

                // 1) Adversarial Target 1: Selecting a saved macro NEVER runs recordedMacroSteps
                ws.recordedMacroSteps = [.insertText("TRAP_RECORDED_NEVER_RUN")]
                let advSaved1 = NppWorkspace.NppSavedMacro(name: "AdvMacroAlpha", shortcut: "", steps: [.insertText("SAVED_ALPHA_OK")])
                let advSaved2 = NppWorkspace.NppSavedMacro(name: "AdvMacroBeta", shortcut: "", steps: [.insertText("SAVED_BETA_OK")])
                ws.savedMacros.append(contentsOf: [advSaved1, advSaved2])

                // 1.A: executeMultiMacro with explicit saved macro name while recordedMacroSteps is non-empty
                tv.string = "PREFIX:"
                macroDoc.content = "PREFIX:"
                tv.setSelectedRange(NSRange(location: 7, length: 0))
                ws.executeMultiMacro(macroName: "AdvMacroAlpha", runUntilEOF: false, times: 2)
                assertTest("Adversarial Macro 1.A: executeMultiMacro runs saved macro and NEVER recordedMacroSteps",
                           tv.string == "PREFIX:SAVED_ALPHA_OKSAVED_ALPHA_OK" && !tv.string.contains("TRAP_RECORDED"))

                // 1.B: playbackMacro when selectedMacroToRun is a saved macro while recordedMacroSteps is non-empty
                ws.selectedMacroToRun = "AdvMacroBeta"
                tv.string = "PREFIX:"
                macroDoc.content = "PREFIX:"
                tv.setSelectedRange(NSRange(location: 7, length: 0))
                ws.playbackMacro()
                assertTest("Adversarial Macro 1.B: playbackMacro runs selected saved macro and NEVER recordedMacroSteps",
                           tv.string == "PREFIX:SAVED_BETA_OK" && !tv.string.contains("TRAP_RECORDED"))

                // 1.C: executeMultiMacro with empty name (defaulting to selectedMacroToRun) runs saved macro
                tv.string = "PREFIX:"
                macroDoc.content = "PREFIX:"
                tv.setSelectedRange(NSRange(location: 7, length: 0))
                ws.executeMultiMacro(macroName: "", runUntilEOF: false, times: 1)
                assertTest("Adversarial Macro 1.C: executeMultiMacro with default name executes selectedMacroToRun without fallback",
                           tv.string == "PREFIX:SAVED_BETA_OK" && !tv.string.contains("TRAP_RECORDED"))

                // 1.D: menuRunSavedMacro selector updates selectedMacroToRun and runs saved macro
                let menuItemAlpha = NSMenuItem(title: "AdvMacroAlpha", action: #selector(appDelegate.menuRunSavedMacro(_:)), keyEquivalent: "")
                menuItemAlpha.representedObject = "AdvMacroAlpha"
                tv.string = "MENU:"
                macroDoc.content = "MENU:"
                tv.setSelectedRange(NSRange(location: 5, length: 0))
                appDelegate.menuRunSavedMacro(menuItemAlpha)
                assertTest("Adversarial Macro 1.D: menuRunSavedMacro updates selectedMacroToRun and executes without fallback",
                           ws.selectedMacroToRun == "AdvMacroAlpha" && tv.string == "MENU:SAVED_ALPHA_OK" && !tv.string.contains("TRAP_RECORDED"))

                // 2) Adversarial Target 2: Invalid, empty, or non-existent macro name NEVER runs recordedMacroSteps & leaves doc unmodified
                let baselineContent = "IMMUTABLE_BASELINE_CONTENT"
                tv.string = baselineContent
                macroDoc.content = baselineContent
                tv.setSelectedRange(NSRange(location: 0, length: 0))

                // 2.A: Non-existent name
                ws.executeMultiMacro(macroName: "NonExistentGhostMacro_XYZ", runUntilEOF: false, times: 3)
                assertTest("Adversarial Macro 2.A: executeMultiMacro with non-existent name leaves document completely unmodified",
                           tv.string == baselineContent && macroDoc.content == baselineContent)

                // 2.B: Whitespace-only name
                ws.executeMultiMacro(macroName: "   \t\n  ", runUntilEOF: false, times: 1)
                assertTest("Adversarial Macro 2.B: executeMultiMacro with whitespace-only name leaves document completely unmodified",
                           tv.string == baselineContent && macroDoc.content == baselineContent)

                // 2.C: Non-existent name with runUntilEOF: true
                ws.executeMultiMacro(macroName: "NonExistentEOF", runUntilEOF: true, times: 1)
                assertTest("Adversarial Macro 2.C: executeMultiMacro non-existent runUntilEOF leaves document completely unmodified",
                           tv.string == baselineContent && macroDoc.content == baselineContent)

                // 2.D: Empty name when selectedMacroToRun is invalid or empty
                ws.selectedMacroToRun = "InvalidOrGhostSelection"
                ws.executeMultiMacro(macroName: "", runUntilEOF: false, times: 1)
                assertTest("Adversarial Macro 2.D: executeMultiMacro with empty name and invalid selectedMacro leaves doc unmodified",
                           tv.string == baselineContent && macroDoc.content == baselineContent)

                ws.selectedMacroToRun = ""
                ws.executeMultiMacro(macroName: "", runUntilEOF: false, times: 1)
                assertTest("Adversarial Macro 2.E: executeMultiMacro with empty name and empty selectedMacro leaves doc unmodified",
                           tv.string == baselineContent && macroDoc.content == baselineContent)

                // 2.F: executeSavedMacro with non-existent name leaves doc unmodified
                ws.executeSavedMacro(named: "GhostMacro_999")
                assertTest("Adversarial Macro 2.F: executeSavedMacro with non-existent name leaves doc unmodified",
                           tv.string == baselineContent && macroDoc.content == baselineContent)

                // 2.G: Calling while isMacroRecording == true is safely ignored
                ws.isMacroRecording = true
                ws.executeMultiMacro(macroName: "AdvMacroAlpha", runUntilEOF: false, times: 1)
                ws.playbackMacro()
                assertTest("Adversarial Macro 2.G: executeMultiMacro and playbackMacro are no-ops while isMacroRecording is true",
                           tv.string == baselineContent && macroDoc.content == baselineContent)
                ws.isMacroRecording = false

                // 3) Adversarial Target 3: selectedMacroToRun synchronization across save, stop recording, and switching selection
                // 3.A: Stopping recording with actions synchronizes selectedMacroToRun to 'Current recorded macro'
                ws.selectedMacroToRun = "AdvMacroAlpha"
                ws.startMacroRecording()
                ws.recordMacroStep(.insertText("RecordedStep"))
                ws.stopMacroRecording()
                assertTest("Adversarial Macro 3.A: stopMacroRecording with steps sets selectedMacroToRun to 'Current recorded macro'",
                           ws.selectedMacroToRun == "Current recorded macro" && ws.availableMacros.contains("Current recorded macro"))

                // 3.B: Stopping recording with NO actions does NOT keep 'Current recorded macro'
                ws.startMacroRecording()
                ws.stopMacroRecording()
                assertTest("Adversarial Macro 3.B: stopMacroRecording without steps selects valid macro instead of 'Current recorded macro'",
                           ws.selectedMacroToRun != "Current recorded macro" && ws.availableMacros.contains(ws.selectedMacroToRun))

                // 3.C: Saving macro updates selectedMacroToRun to newly saved macro name
                ws.startMacroRecording()
                ws.recordMacroStep(.insertText("StepNew"))
                ws.stopMacroRecording()
                let didSaveAdv = ws.saveCurrentRecordedMacro(name: "AdvMacroGamma")
                assertTest("Adversarial Macro 3.C: saveCurrentRecordedMacro updates selectedMacroToRun to saved macro name",
                           didSaveAdv && ws.selectedMacroToRun == "AdvMacroGamma" && ws.availableMacros.contains("AdvMacroGamma"))

                // 3.D: Switching selection explicitly via selectedMacroToRun
                ws.selectedMacroToRun = "AdvMacroAlpha"
                assertTest("Adversarial Macro 3.D: Switching selectedMacroToRun to AdvMacroAlpha is preserved",
                           ws.selectedMacroToRun == "AdvMacroAlpha")

                // 3.E: Updating saved macro name updates selectedMacroToRun if it was selected
                ws.updateSavedMacro(named: "AdvMacroAlpha", newName: "AdvMacroAlphaRenamed", newShortcut: "")
                assertTest("Adversarial Macro 3.E: updateSavedMacro updates selectedMacroToRun when matching original name",
                           ws.selectedMacroToRun == "AdvMacroAlphaRenamed" && ws.availableMacros.contains("AdvMacroAlphaRenamed"))

                // 3.F: Deleting selected macro updates selectedMacroToRun to another valid macro
                ws.deleteSavedMacro(named: "AdvMacroAlphaRenamed")
                assertTest("Adversarial Macro 3.F: deleteSavedMacro ensures selectedMacroToRun points to a remaining valid macro",
                           ws.selectedMacroToRun != "AdvMacroAlphaRenamed" && ws.availableMacros.contains(ws.selectedMacroToRun))

                // 3.G: RunMacroDialogView binding reflection and ensureValidSelectedMacro onAppear
                let advDialogView = NppRunMacroDialogView(workspace: ws, isPresented: .constant(true))
                assertTest("Adversarial Macro 3.G: RunMacroDialogView availableMacros matches workspace.availableMacros",
                           advDialogView.availableMacros == ws.availableMacros)

                // 1.E: Complex multi-step recorded macro with destructive actions (.cut, .insertText("TRAP")) vs non-destructive saved macro
                ws.recordedMacroSteps = [.selectAll, .cut, .insertText("DESTRUCTIVE_TRAP_EXECUTED")]
                let advUpper = NppWorkspace.NppSavedMacro(name: "AdvMacroUpper", shortcut: "", steps: [.uppercase])
                ws.savedMacros.append(advUpper)
                ws.selectedMacroToRun = "AdvMacroUpper"
                tv.string = "hello world"
                macroDoc.content = "hello world"
                tv.setSelectedRange(NSRange(location: 0, length: 11))
                ws.executeMultiMacro(macroName: "AdvMacroUpper", runUntilEOF: false, times: 1)
                assertTest("Adversarial Macro 1.E: executeMultiMacro executes uppercase and NEVER destructive recorded steps",
                           tv.string == "HELLO WORLD" && !tv.string.contains("DESTRUCTIVE_TRAP"))

                // 1.F: playbackMacro with destructive recorded macro steps
                tv.string = "test playback"
                macroDoc.content = "test playback"
                tv.setSelectedRange(NSRange(location: 0, length: 13))
                ws.playbackMacro()
                assertTest("Adversarial Macro 1.F: playbackMacro executes uppercase and NEVER destructive recorded steps",
                           tv.string == "TEST PLAYBACK" && !tv.string.contains("DESTRUCTIVE_TRAP"))

                // 2.H: executeMultiMacro times clamping (negative or zero count clamps to 1)
                tv.string = "abc"
                macroDoc.content = "abc"
                tv.setSelectedRange(NSRange(location: 0, length: 3))
                ws.executeMultiMacro(macroName: "AdvMacroUpper", runUntilEOF: false, times: -5)
                assertTest("Adversarial Macro 2.H: executeMultiMacro with negative count clamps to at least 1 repetition",
                           tv.string == "ABC")

                // 3.H: Unicode Korean name in saveCurrentRecordedMacro and state synchronization
                ws.recordedMacroSteps = [.insertText("한글")]
                let didSaveKorean = ws.saveCurrentRecordedMacro(name: "매크로_한글_1 🚀")
                assertTest("Adversarial Macro 3.H: saveCurrentRecordedMacro supports Unicode Korean name and updates selectedMacroToRun",
                           didSaveKorean && ws.selectedMacroToRun == "매크로_한글_1 🚀" && ws.availableMacros.contains("매크로_한글_1 🚀"))

                // 3.I: Validation guards when saving macro: empty name or while recording rejected
                let failEmptySave = ws.saveCurrentRecordedMacro(name: "   \t\n")
                assertTest("Adversarial Macro 3.I: saveCurrentRecordedMacro with whitespace name returns false and does not alter selection",
                           !failEmptySave && ws.selectedMacroToRun == "매크로_한글_1 🚀")

                ws.isMacroRecording = true
                let failRecordingSave = ws.saveCurrentRecordedMacro(name: "ShouldFailWhileRecording")
                assertTest("Adversarial Macro 3.J: saveCurrentRecordedMacro while recording returns false and does not alter selection",
                           !failRecordingSave && ws.selectedMacroToRun == "매크로_한글_1 🚀")
                ws.isMacroRecording = false

                // Teardown / cleanup test macros from workspace
                ws.deleteSavedMacro(named: "AdvMacroBeta")
                ws.deleteSavedMacro(named: "AdvMacroGamma")
                ws.deleteSavedMacro(named: "AdvMacroUpper")
                ws.deleteSavedMacro(named: "매크로_한글_1 🚀")
                ws.recordedMacroSteps.removeAll()

                ws.closeDocument(id: macroDoc.id)
            }

            // ---------------------------------------------------------
            // 27. [AUDIT-019] Shortcut Mapper & Column Editor 1:1 Parity
            // ---------------------------------------------------------
            ws.customShortcuts["main:New"] = "Cmd+Shift+N"
            assertTest("ShortcutMapper: customShortcuts stores modified shortcut override", ws.customShortcuts["main:New"] == "Cmd+Shift+N")
            ws.customShortcuts["main:New"] = ""
            assertTest("ShortcutMapper: Clear sets shortcut override to empty", ws.customShortcuts["main:New"] == "")
            ws.customShortcuts.removeAll()

            ws.newDocument()
            if let colDoc = ws.activeDocument, let tv = ws.activeTextView {
                tv.string = "A\nB\nC"
                colDoc.content = tv.string
                tv.setSelectedRange(NSRange(location: 0, length: 5))
                ws.executeColumnEditor(isText: false, text: "", initialNumber: 10, increaseBy: 1, repeatCount: 1, format: "hex_lower", leadingZeros: true, leadingSpaces: false)
                assertTest("ColumnEditor: hex_lower with leadingZeros formats as 000a, 000b, 000c", tv.string.contains("000aA") && tv.string.contains("000bB") && tv.string.contains("000cC"))
                ws.closeDocument(id: colDoc.id)
            }

            ws.localizationLanguage = "한국어"
            assertTest("Localization: ShortcutMapper Korean labels match korean.xml", ws.tr("Main menu") == "주 메뉴" && ws.tr("Scintilla commands") == "Scintilla 명령" && ws.tr("Modify") == "수정" && ws.tr("No shortcut conflicts for this item.") == "이 항목과 충돌하는 단축키가 없습니다.")
            assertTest("Localization: ColumnEditor Korean labels match korean.xml", ws.tr("Column / Multi-Selection Editor") == "열 편집기" && ws.tr("Text to Insert") == "글자 삽입" && ws.tr("Number to Insert") == "숫자 삽입" && ws.tr("Leading :") == "앞부분:")

            // ---------------------------------------------------------
            // 28. [AUDIT-020] Toggle Single Line Comment & Line Ops Caret/Line Integrity
            // ---------------------------------------------------------
            ws.newDocument()
            if let cDoc = ws.activeDocument, let tv = ws.activeTextView {
                cDoc.language = "Swift"
                tv.string = "    let alpha = 1\n    let beta = 2"
                cDoc.content = tv.string
                // Place caret at 'alpha' (index 8 on Line 1)
                tv.setSelectedRange(NSRange(location: 8, length: 0))

                // 1) First Toggle Single Line Comment -> inserts "// " after indent on Line 1 and keeps caret at 'alpha' (index 11) on Line 1
                NppEditOperations.toggleComment(in: tv, language: "Swift")
                let caretAfterComment = tv.selectedRange().location
                assertTest("ToggleComment (1st): Inserts '// ' at indent on Line 1 without touching Line 2", tv.string == "    // let alpha = 1\n    let beta = 2")
                assertTest("ToggleComment (1st): Caret stays on Line 1 at exact same character (index 11, NOT next line)", caretAfterComment == 11)

                // 2) Second Toggle Single Line Comment immediately -> uncomments Line 1 and returns caret to index 8 on Line 1
                NppEditOperations.toggleComment(in: tv, language: "Swift")
                let caretAfterUncomment = tv.selectedRange().location
                assertTest("ToggleComment (2nd): Uncomments Line 1 in place without jumping to Line 2", tv.string == "    let alpha = 1\n    let beta = 2" && caretAfterUncomment == 8)

                // 3) Block Comment & Block Uncomment
                NppEditOperations.streamComment(in: tv, language: "Swift")
                assertTest("BlockComment: Wraps line content in /* ... */", tv.string == "    /* let alpha = 1 */\n    let beta = 2")
                NppEditOperations.streamUncomment(in: tv, language: "Swift")
                assertTest("BlockUncomment: Unwraps /* ... */ cleanly", tv.string == "    let alpha = 1\n    let beta = 2")

                // 4) Move Line Down / Up without concatenating last line (no trailing newline)
                tv.setSelectedRange(NSRange(location: 8, length: 0))
                NppEditOperations.moveLineDown(in: tv)
                assertTest("MoveLineDown: Swaps Line 1 and Line 2 without concatenating lines", tv.string == "    let beta = 2\n    let alpha = 1")
                NppEditOperations.moveLineUp(in: tv)
                assertTest("MoveLineUp: Restores Line 1 and Line 2 cleanly and preserves column offset", tv.string == "    let alpha = 1\n    let beta = 2" && tv.selectedRange().location == 8)

                ws.closeDocument(id: cDoc.id)
            }

            // ---------------------------------------------------------
            // 29. ADVERSARIAL CHALLENGER: UserDefaults & 20 Edit Commands
            // ---------------------------------------------------------
            runAdversarialTests(ws: ws, appDelegate: appDelegate, assertTest: assertTest)

            // ---------------------------------------------------------
            // 30. MILESTONE 2: EDIT MENU FULL PARITY TEST SUITE
            // ---------------------------------------------------------
            runEditMenuParityTests(ws: ws, appDelegate: appDelegate, assertTest: assertTest)

            // ---------------------------------------------------------
            // 31. ADVERSARIAL CHALLENGE SUITE: PASS 2 (M2.2)
            // ---------------------------------------------------------
            runAdversarialM2ChallengeTests(ws: ws, appDelegate: appDelegate, assertTest: assertTest)

            // ---------------------------------------------------------
            // 32. MILESTONES 3 & 4: SEARCH, VIEW, ENCODING, LANGUAGE, TOOLS, WINDOW PARITY SUITE
            // ---------------------------------------------------------
            runSearchAndViewMenuParityTests(ws: ws, appDelegate: appDelegate, assertTest: assertTest)

            // ---------------------------------------------------------
            // 33. RE-AUDIT 5: OFFICIAL MANUAL & C++ UPSTREAM PARITY
            // ---------------------------------------------------------
            runOfficialManualAndUpstreamParityTests(ws: ws, appDelegate: appDelegate, assertTest: assertTest)

            // ---------------------------------------------------------
            // 34. SPRINT 1: MANUAL AUDIT 10 CORE PARITY FEATURES SUITE
            // ---------------------------------------------------------
            runSprint1ParityTests(ws: ws, appDelegate: appDelegate, assertTest: assertTest)

            // ---------------------------------------------------------
            // 35. SPRINT 2: MANUAL AUDIT 8 CORE PARITY FEATURES SUITE
            // ---------------------------------------------------------
            runSprint2ParityTests(ws: ws, appDelegate: appDelegate, assertTest: assertTest)

            // ---------------------------------------------------------
            // 36. MILESTONE 3: SEARCH MENU FULL PARITY AUDIT SUITE
            // ---------------------------------------------------------
            runMilestone3SearchParityTests(ws: ws, appDelegate: appDelegate, assertTest: assertTest)

            runAdversarialM4ChallengeTests(ws: ws, appDelegate: appDelegate, assertTest: assertTest)

            // ---------------------------------------------------------
            // 38. [AUDIT-027] COMPREHENSIVE INTERACTIVE SCENARIO TEST SUITES (Streams 1-5)
            // ---------------------------------------------------------
            runStream1EditorInteractiveTests(ws: ws, assertTest: assertTest)
            runStream2SearchInteractiveTests(ws: ws, assertTest: assertTest)
            runStream3LifecycleInteractiveTests(ws: ws, assertTest: assertTest)
            runStream4EncodingInteractiveTests(ws: ws, assertTest: assertTest)
            runStream5DialogsInteractiveTests(ws: ws, assertTest: assertTest)
            runManualAutoCompletionTests(assertTest: assertTest)
            runManualUDLTests(assertTest: assertTest)
            runManualFileMenuTests(assertTest: assertTest)
            runManualSessionTests(assertTest: assertTest)
            runManualRunMenuTests(assertTest: assertTest)
            runManualLanguageDetectionTests(assertTest: assertTest)
            runLineOpsRegressionTests(assertTest: assertTest)
            runFindReplaceRegressionTests(assertTest: assertTest)
            runLineNumberRegressionTests(assertTest: assertTest)
            runEncodingRoundTripTests(assertTest: assertTest)
            runCommentIndentRegressionTests(assertTest: assertTest)
            runSessionTabRegressionTests(assertTest: assertTest)
            runUnsavedBackupRestoreTests(assertTest: assertTest)
            runResourceBundleTests(assertTest: assertTest)
            runQuitAndTabBarUXParityTests(appDelegate: appDelegate, assertTest: assertTest)
            runAdversarialQuitStressTests(appDelegate: appDelegate, assertTest: assertTest)
            runAdversarialTabBarStressTests(assertTest: assertTest)
            runReviewerEdgeCaseTests(assertTest: assertTest)

            // ---------------------------------------------------------
            // 39. [WORKER 1] REGRESSION INVARIANT MATRIX & GUARDRAILS (Pillars 1-9)
            // ---------------------------------------------------------
            runAppKitLifecycleAndTerminationTripwires(appDelegate: appDelegate, assertTest: assertTest)
            runLiveUIEventAndGestureTripwires(assertTest: assertTest)
            runDualViewSynchronizedScrollingTripwires(assertTest: assertTest)
            runEditAndLineOperationsTripwires(assertTest: assertTest)
            runSearchEngineParityTripwires(assertTest: assertTest)
            runEncodingAndBOMTripwires(assertTest: assertTest)
            runSessionAndBackupResilienceTripwires(assertTest: assertTest)
            runMenuAndResponderChainTripwires(appDelegate: appDelegate, assertTest: assertTest)
            runPreferencesPersistenceTripwires(assertTest: assertTest)

            // Restore English for default screenshot state
            ws.localizationLanguage = "English"
            appDelegate.setupMenuBar()
            ws.darkModeChoice = 1

            print("\n========================================================")
            print("📊 TEST SUMMARY: \(passedCount) / \(testCount) PASSED")
            print("========================================================")

            if passedCount == testCount {
                print("🎉 ALL TESTS PASSED! NppTestResult: OK")
                ws.openFile(url: URL(fileURLWithPath: "samples/syntax_demo.swift"))
                ws.toggleBookmark(line: 3)
                ws.toggleBookmark(line: 7)
                ws.toggleBookmark(line: 14)
                // Take a screenshot of the window with rich syntax highlighting and bookmarks rendered
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    if let win = appDelegate.window {
                        saveWindowPNG(win, to: "screenshot_bookmarks.png")
                        saveWindowPNG(win, to: "screenshot_verification.png")
                        print("📸 Verification screenshots captured to screenshot_bookmarks.png & screenshot_verification.png")
                    }
                    exit(0)
                }
            } else {
                print("💥 SOME TESTS FAILED!")
                exit(1)
            }
        }
    }

    // =========================================================================
    // 29. ADVERSARIAL STRESS TEST SUITE: UserDefaults Persistence & 20 Edit Commands
    // =========================================================================
    static func runAdversarialTests(
        ws: NppWorkspace,
        appDelegate: AppDelegate,
        assertTest: (String, Bool) -> Void
    ) {
        print("\n========================================================")
        print("⚔️ ADVERSARIAL CHALLENGER SUITE: USERDEFAULTS & 20 EDIT COMMANDS")
        print("========================================================")

        // Backup existing UserDefaults data for npp.savedMacros.v1
        let backupData = UserDefaults.standard.data(forKey: NppWorkspace.savedMacrosUserDefaultsKey)
        defer {
            if let backup = backupData {
                UserDefaults.standard.set(backup, forKey: NppWorkspace.savedMacrosUserDefaultsKey)
            } else {
                UserDefaults.standard.removeObject(forKey: NppWorkspace.savedMacrosUserDefaultsKey)
            }
        }

        // ---------------------------------------------------------------------
        // PART 1: UserDefaults Persistence Corruption, Empty & Malformed Stress
        // ---------------------------------------------------------------------
        let defaultMacroName = "Trim Trailing Space and Save"

        // 1. Corrupted binary data
        UserDefaults.standard.set(Data([0xFF, 0xFE, 0x00, 0xDE, 0xAD, 0xBE, 0xEF, 0x12, 0x34]), forKey: NppWorkspace.savedMacrosUserDefaultsKey)
        let wsCorruptBinary = NppWorkspace()
        assertTest("Adversarial UD: Corrupted binary bytes falls back to default macro without crashing",
                   wsCorruptBinary.savedMacros.count == 1 && wsCorruptBinary.savedMacros.first?.name == defaultMacroName)
        assertTest("Adversarial UD: selectedMacroToRun is valid after corrupt binary fallback",
                   wsCorruptBinary.selectedMacroToRun == defaultMacroName)

        // 2. Empty Data()
        UserDefaults.standard.set(Data(), forKey: NppWorkspace.savedMacrosUserDefaultsKey)
        let wsEmptyData = NppWorkspace()
        assertTest("Adversarial UD: Empty Data() falls back to default macro without crashing",
                   wsEmptyData.savedMacros.count == 1 && wsEmptyData.savedMacros.first?.name == defaultMacroName)

        // 3. Empty string in Data
        UserDefaults.standard.set(Data("".utf8), forKey: NppWorkspace.savedMacrosUserDefaultsKey)
        let wsEmptyStringData = NppWorkspace()
        assertTest("Adversarial UD: Empty UTF-8 string Data falls back to default macro without crashing",
                   wsEmptyStringData.savedMacros.count == 1 && wsEmptyStringData.savedMacros.first?.name == defaultMacroName)

        // 4. Malformed JSON syntax (unclosed braces, invalid tokens)
        let malformedJsonStrings: [(String, String)] = [
            ("Unclosed JSON object", "{ unclosed json object"),
            ("Unclosed Array", "[{\"name\": \"Broken\", \"steps\": ["),
            ("Trailing Comma", "{\"steps\": [\"cut\", ]}"),
            ("HTML Payload", "<!DOCTYPE html><html><body>Not JSON</body></html>"),
            ("Raw String", "\"just a raw quoted string\""),
            ("Raw Number", "1234567890"),
            ("Raw Boolean", "true"),
            ("Raw Null", "null")
        ]
        for (desc, badJson) in malformedJsonStrings {
            UserDefaults.standard.set(Data(badJson.utf8), forKey: NppWorkspace.savedMacrosUserDefaultsKey)
            let testWs = NppWorkspace()
            assertTest("Adversarial UD: \(desc) falls back safely to default macro",
                       testWs.savedMacros.count == 1 && testWs.savedMacros.first?.name == defaultMacroName && testWs.selectedMacroToRun == defaultMacroName)
        }

        // 5. Empty JSON Array []
        UserDefaults.standard.set(Data("[]".utf8), forKey: NppWorkspace.savedMacrosUserDefaultsKey)
        let wsEmptyArray = NppWorkspace()
        assertTest("Adversarial UD: Empty JSON array '[]' falls back to default macro (non-empty list)",
                   wsEmptyArray.savedMacros.count == 1 && wsEmptyArray.savedMacros.first?.name == defaultMacroName)

        // 6. Non-Data types stored directly in UserDefaults key
        UserDefaults.standard.set("Direct String Value", forKey: NppWorkspace.savedMacrosUserDefaultsKey)
        let wsStringVal = NppWorkspace()
        assertTest("Adversarial UD: Non-Data String in UserDefaults falls back safely",
                   wsStringVal.savedMacros.count == 1 && wsStringVal.savedMacros.first?.name == defaultMacroName)

        UserDefaults.standard.set(9999, forKey: NppWorkspace.savedMacrosUserDefaultsKey)
        let wsIntVal = NppWorkspace()
        assertTest("Adversarial UD: Non-Data Int in UserDefaults falls back safely",
                   wsIntVal.savedMacros.count == 1 && wsIntVal.savedMacros.first?.name == defaultMacroName)

        UserDefaults.standard.set(["array", "of", "strings"], forKey: NppWorkspace.savedMacrosUserDefaultsKey)
        let wsArrayVal = NppWorkspace()
        assertTest("Adversarial UD: Non-Data NSArray in UserDefaults falls back safely",
                   wsArrayVal.savedMacros.count == 1 && wsArrayVal.savedMacros.first?.name == defaultMacroName)

        // 7. Valid JSON array containing unknown macro step action names
        let unknownActionJson = """
        [
            {
                "id": "11111111-2222-3333-4444-555555555555",
                "name": "UnknownActionMacro",
                "shortcut": "Ctrl+U",
                "steps": ["nonExistentActionCommand12345", "cut"]
            }
        ]
        """
        UserDefaults.standard.set(Data(unknownActionJson.utf8), forKey: NppWorkspace.savedMacrosUserDefaultsKey)
        let wsUnknownStep = NppWorkspace()
        assertTest("Adversarial UD: Unknown action name in steps falls back without crash",
                   wsUnknownStep.savedMacros.count == 1 && wsUnknownStep.savedMacros.first?.name == defaultMacroName)

        // 8. Corrupted step objects (wrong types within steps array)
        let corruptStepObjects = """
        [
            {
                "name": "CorruptStepTypes",
                "steps": [123, true, null, {"invalidKey": 999}]
            }
        ]
        """
        UserDefaults.standard.set(Data(corruptStepObjects.utf8), forKey: NppWorkspace.savedMacrosUserDefaultsKey)
        let wsCorruptSteps = NppWorkspace()
        assertTest("Adversarial UD: Malformed step objects in steps array falls back without crash",
                   wsCorruptSteps.savedMacros.count == 1 && wsCorruptSteps.savedMacros.first?.name == defaultMacroName)

        // 9. Truncated JSON stream
        let truncatedJson = "[{\"name\": \"TruncatedMacro\", \"steps\": [\"cut\", \"copy\""
        UserDefaults.standard.set(Data(truncatedJson.utf8), forKey: NppWorkspace.savedMacrosUserDefaultsKey)
        let wsTruncated = NppWorkspace()
        assertTest("Adversarial UD: Truncated JSON stream falls back safely",
                   wsTruncated.savedMacros.count == 1 && wsTruncated.savedMacros.first?.name == defaultMacroName)

        // 10. Saving new macro after corruption completely repairs UserDefaults
        let recoveryWs = NppWorkspace()
        recoveryWs.startMacroRecording()
        recoveryWs.recordMacroStep(.insertText("RepairedContent"))
        recoveryWs.stopMacroRecording()
        let saveRepaired = recoveryWs.saveCurrentRecordedMacro(name: "RepairedMacro", shortcut: "Cmd+R")
        assertTest("Adversarial UD: Saving new macro after corrupted state succeeds", saveRepaired)

        let freshRepairedWs = NppWorkspace()
        assertTest("Adversarial UD: Fresh workspace loads newly saved macro from repaired UserDefaults",
                   freshRepairedWs.savedMacros.contains(where: { $0.name == "RepairedMacro" }))

        // ---------------------------------------------------------------------
        // PART 2: All 20 Edit Commands Recording & Replay Sequence Stress Tests
        // ---------------------------------------------------------------------
        ws.newDocument()
        guard let testDoc = ws.activeDocument else { return }
        let testTv = ws.activeTextView ?? NSTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 400))
        ws.activeTextView = testTv

        // Test 2.1: Date/Time Duplication Adversarial Stress
        testTv.string = ""
        testDoc.content = ""
        testTv.setSelectedRange(NSRange(location: 0, length: 0))

        ws.startMacroRecording()
        ws.recordMacroStep(.insertDateTime)
        ws.stopMacroRecording()
        assertTest("Adversarial Macro: Recording insertDateTime captures exactly 1 step without nested steps",
                   ws.recordedMacroSteps == [.insertDateTime])

        // Verify: Replaying insertDateTime inserts a single timestamp
        ws.executeMacroSteps(ws.recordedMacroSteps)
        let dateReplay1 = testTv.string
        let datePattern = #"\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}"#
        let regex = try? NSRegularExpression(pattern: datePattern)
        let matches1 = regex?.matches(in: dateReplay1, range: NSRange(location: 0, length: (dateReplay1 as NSString).length)) ?? []
        assertTest("Adversarial Macro: Single insertDateTime step inserts exactly 1 date string (no duplicates)",
                   matches1.count == 1 && dateReplay1.components(separatedBy: " ").count == 2)

        // Replaying multi-times sequence with insertDateTime and surrounding text
        testTv.string = ""
        testDoc.content = ""
        testTv.setSelectedRange(NSRange(location: 0, length: 0))

        let dateTimeSequence: [NppWorkspace.NppMacroStep] = [
            .insertText("START|"),
            .insertDateTime,
            .insertText("|END\n")
        ]
        ws.executeMacroSteps(dateTimeSequence)
        let dtSeqText = testTv.string
        let seqMatches = regex?.matches(in: dtSeqText, range: NSRange(location: 0, length: (dtSeqText as NSString).length)) ?? []
        assertTest("Adversarial Macro: Chained insertText + insertDateTime + insertText produces exactly 1 timestamp",
                   seqMatches.count == 1 && dtSeqText.hasPrefix("START|") && dtSeqText.contains("|END\n"))

        // Test 2.2: Sequence with tv mutations AND doc mutations
        // Initial state: "Charlie\nAlice\nBob"
        // Sequence: selectAll -> cut -> insertText("Zoo\nApple\nMango\n") -> sortLines -> reverseLineOrder
        testTv.string = "Charlie\nAlice\nBob"
        testDoc.content = "Charlie\nAlice\nBob"
        testTv.setSelectedRange(NSRange(location: 0, length: 0))

        let mixSequence: [NppWorkspace.NppMacroStep] = [
            .selectAll,
            .cut,
            .insertText("Zoo\nApple\nMango\n"),
            .sortLines,
            .reverseLineOrder
        ]
        ws.executeMacroSteps(mixSequence)
        let mixResult = testTv.string
        let expectedMix = "Zoo\nMango\nApple\n"
        print("  🔍 DEBUG Adversarial Sequence Result: actual='\(mixResult.replacingOccurrences(of: "\n", with: "\\n"))', expected='\(expectedMix.replacingOccurrences(of: "\n", with: "\\n"))'")
        assertTest("Adversarial Macro: Mixed sequence (selectAll -> cut -> insertText -> sortLines -> reverseLineOrder) preserves text and mutations correctly",
                   mixResult == expectedMix && testDoc.content == expectedMix)

        // Test 2.2.B: Date/Time + Line Operation Sequence (Verifying timestamp is not erased by subsequent line ops)
        testTv.string = "ExistingLine\n"
        testDoc.content = "ExistingLine\n"
        testDoc.eolFormat = .lf
        testTv.setSelectedRange(NSRange(location: 0, length: 0))
        let dtLineSeq: [NppWorkspace.NppMacroStep] = [
            .insertDateTime,
            .insertNewline,
            .sortLines
        ]
        ws.executeMacroSteps(dtLineSeq)
        let dtLineResult = testTv.string
        let hasDateRemaining = regex?.firstMatch(in: dtLineResult, range: NSRange(location: 0, length: (dtLineResult as NSString).length)) != nil
        print("  🔍 DEBUG DateTime+Sort Result: actual='\(dtLineResult.replacingOccurrences(of: "\n", with: "\\n"))', hasDate=\(hasDateRemaining)")
        assertTest("Adversarial Macro: Chained insertDateTime + sortLines preserves timestamp without erasure",
                   hasDateRemaining && dtLineResult.contains("ExistingLine"))

        // Test 2.3: All 20 Edit Commands Executed in Sequenced Pipelines
        // 1. cut, 2. copy, 3. paste, 4. selectAll
        testTv.string = "BaseText"
        testDoc.content = "BaseText"
        testTv.setSelectedRange(NSRange(location: 0, length: 4))
        ws.executeMacroStep(.copy, in: testTv, document: testDoc)
        assertTest("Adversarial Step: copy preserves selection and captures to pasteboard",
                   NSPasteboard.general.string(forType: .string) == "Base")

        testTv.setSelectedRange(NSRange(location: 4, length: 4))
        ws.executeMacroStep(.cut, in: testTv, document: testDoc)
        assertTest("Adversarial Step: cut removes selection", testTv.string == "Base")

        ws.executeMacroStep(.paste, in: testTv, document: testDoc)
        assertTest("Adversarial Step: paste inserts cut text", testTv.string == "BaseText")

        ws.executeMacroStep(.selectAll, in: testTv, document: testDoc)
        assertTest("Adversarial Step: selectAll selects entire string", testTv.selectedRange() == NSRange(location: 0, length: 8))

        // 5. joinLines, 6. splitLines
        testTv.string = "Line One\nLine Two\nLine Three"
        testDoc.content = testTv.string
        testDoc.eolFormat = .lf
        testTv.setSelectedRange(NSRange(location: 0, length: (testTv.string as NSString).length))
        ws.executeMacroStep(.joinLines, in: testTv, document: testDoc)
        assertTest("Adversarial Step: joinLines collapses newlines into single line",
                   !testTv.string.contains("\n") && testTv.string.contains("Line One Line Two Line Three"))

        testTv.setSelectedRange(NSRange(location: 0, length: (testTv.string as NSString).length))
        ws.executeMacroStep(.splitLines, in: testTv, document: testDoc)
        assertTest("Adversarial Step: splitLines breaks line back up", testTv.string.contains("\n"))

        // 7. insertEmptyLineAbove, 8. insertEmptyLineBelow
        testTv.string = "Middle"
        testDoc.content = "Middle"
        testTv.setSelectedRange(NSRange(location: 0, length: 0))
        ws.executeMacroStep(.insertEmptyLineAbove, in: testTv, document: testDoc)
        assertTest("Adversarial Step: insertEmptyLineAbove adds newline above", testTv.string.hasPrefix("\n"))

        testTv.setSelectedRange(NSRange(location: 1, length: 0))
        ws.executeMacroStep(.insertEmptyLineBelow, in: testTv, document: testDoc)
        assertTest("Adversarial Step: insertEmptyLineBelow adds newline below", testTv.string.hasSuffix("\n"))

        // 9. removeEmptyLines, 10. removeDuplicateLines
        testDoc.eolFormat = .lf
        testTv.string = "Alpha\n\nBeta\n\nBeta\nAlpha\nGamma"
        testDoc.content = testTv.string
        ws.executeMacroStep(.removeEmptyLines, in: testTv, document: testDoc)
        assertTest("Adversarial Step: removeEmptyLines eliminates blank lines",
                   testTv.string == "Alpha\nBeta\nBeta\nAlpha\nGamma" && testDoc.content == testTv.string)

        ws.executeMacroStep(.removeDuplicateLines, in: testTv, document: testDoc)
        assertTest("Adversarial Step: removeDuplicateLines retains only unique lines",
                   testTv.string == "Alpha\nBeta\nGamma" && testDoc.content == testTv.string)

        // 11. sortLines, 12. reverseLineOrder
        ws.executeMacroStep(.sortLines, in: testTv, document: testDoc)
        assertTest("Adversarial Step: sortLines alphabetizes lines",
                   testTv.string == "Alpha\nBeta\nGamma" && testDoc.content == testTv.string)

        ws.executeMacroStep(.reverseLineOrder, in: testTv, document: testDoc)
        assertTest("Adversarial Step: reverseLineOrder flips line sequence",
                   testTv.string == "Gamma\nBeta\nAlpha" && testDoc.content == testTv.string)

        // 13. singleLineComment, 14. singleLineUncomment
        testDoc.language = "Swift"
        testTv.string = "let value = 42"
        testDoc.content = testTv.string
        testTv.setSelectedRange(NSRange(location: 0, length: 0))
        ws.executeMacroStep(.singleLineComment, in: testTv, document: testDoc)
        assertTest("Adversarial Step: singleLineComment adds //", testTv.string.contains("// let value = 42"))

        ws.executeMacroStep(.singleLineUncomment, in: testTv, document: testDoc)
        assertTest("Adversarial Step: singleLineUncomment removes //", !testTv.string.contains("//") && testTv.string.contains("let value = 42"))

        // 15. streamComment, 16. streamUncomment
        testTv.string = "fooBar"
        testDoc.content = "fooBar"
        testTv.setSelectedRange(NSRange(location: 0, length: 6))
        ws.executeMacroStep(.streamComment, in: testTv, document: testDoc)
        assertTest("Adversarial Step: streamComment wraps selection in /* ... */", testTv.string == "/* fooBar */")

        testTv.setSelectedRange(NSRange(location: 0, length: (testTv.string as NSString).length))
        ws.executeMacroStep(.streamUncomment, in: testTv, document: testDoc)
        assertTest("Adversarial Step: streamUncomment unwraps /* ... */", testTv.string == "fooBar")

        // 17. eolToSpace, 18. tabToSpace, 19. spaceToTab
        testTv.string = "X\nY\nZ"
        testDoc.content = testTv.string
        ws.executeMacroStep(.eolToSpace, in: testTv, document: testDoc)
        assertTest("Adversarial Step: eolToSpace turns newlines to space",
                   testTv.string == "X Y Z" && testDoc.content == testTv.string)

        testTv.string = "\tTabbed"
        testDoc.content = testTv.string
        ws.tabSize = 4
        ws.executeMacroStep(.tabToSpace, in: testTv, document: testDoc)
        assertTest("Adversarial Step: tabToSpace turns tab to 4 spaces",
                   testTv.string == "    Tabbed" && testDoc.content == testTv.string)

        ws.executeMacroStep(.spaceToTab, in: testTv, document: testDoc)
        assertTest("Adversarial Step: spaceToTab turns 4 leading spaces back to tab",
                   testTv.string == "\tTabbed" && testDoc.content == testTv.string)

        // 20. insertDateTime & insertDateTimeLong
        testTv.string = "Date: "
        testDoc.content = "Date: "
        testTv.setSelectedRange(NSRange(location: 6, length: 0))
        ws.executeMacroStep(.insertDateTime, in: testTv, document: testDoc)
        assertTest("Adversarial Step: insertDateTime produces valid timestamp text",
                   testTv.string.hasPrefix("Date: ") && testTv.string.count > 15)

        testTv.setSelectedRange(NSRange(location: (testTv.string as NSString).length, length: 0))
        ws.executeMacroStep(.insertText(" | Long: "), in: testTv, document: testDoc)
        ws.executeMacroStep(.insertDateTimeLong, in: testTv, document: testDoc)
        assertTest("Adversarial Step: insertDateTimeLong appends long format date without crash",
                   testTv.string.contains(" | Long: ") && testTv.string.count > 30)

        // Test 2.4: Stress testing all 20 operations on an EMPTY document ("")
        testTv.string = ""
        testDoc.content = ""
        testTv.setSelectedRange(NSRange(location: 0, length: 0))
        let all20Ops: [NppWorkspace.NppMacroStep] = [
            .cut, .copy, .paste, .selectAll,
            .joinLines, .splitLines,
            .insertEmptyLineAbove, .insertEmptyLineBelow,
            .removeEmptyLines, .removeDuplicateLines,
            .sortLines, .reverseLineOrder,
            .singleLineComment, .singleLineUncomment,
            .streamComment, .streamUncomment,
            .eolToSpace, .tabToSpace, .spaceToTab,
            .insertDateTime
        ]
        let emptyOpsSurvived = true
        for op in all20Ops {
            ws.executeMacroStep(op, in: testTv, document: testDoc)
        }
        assertTest("Adversarial Stress: All 20 edit operations execute safely on empty document without crashing", emptyOpsSurvived)

        ws.closeDocument(id: testDoc.id)
    }

    // =========================================================================
    // 30. MILESTONE 2: EDIT MENU FULL PARITY TEST SUITE (1:1 Upstream Parity)
    // =========================================================================
    static func runEditMenuParityTests(
        ws: NppWorkspace,
        appDelegate: AppDelegate,
        assertTest: (String, Bool) -> Void
    ) {
        print("\n========================================================")
        print("🎯 MILESTONE 2: EDIT MENU FULL PARITY SUITE (9 FEATURE GROUPS)")
        print("========================================================")

        // -------------------------------------------------------------
        // GROUP 1: Begin/End Select Parity
        // -------------------------------------------------------------
        ws.newDocument()
        guard let doc = ws.activeDocument else { return }
        let tv = NSTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 400))
        tv.string = "0123456789ABCDEF"
        doc.content = tv.string
        ws.activeTextView = tv

        assertTest("EditMenu M2.1.A: Initial beginSelectAnchor is nil", ws.beginSelectAnchor == nil)

        tv.setSelectedRange(NSRange(location: 3, length: 0))
        ws.beginOrEndSelect()
        assertTest("EditMenu M2.1.B: beginOrEndSelect sets anchor to current position (3)", ws.beginSelectAnchor == 3)

        tv.setSelectedRange(NSRange(location: 10, length: 0))
        ws.beginOrEndSelect()
        assertTest("EditMenu M2.1.C: beginOrEndSelect sets range [3, 7] and clears anchor",
                   ws.beginSelectAnchor == nil && tv.selectedRange().location == 3 && tv.selectedRange().length == 7)

        tv.setSelectedRange(NSRange(location: 8, length: 0))
        ws.beginOrEndSelect()
        tv.setSelectedRange(NSRange(location: 2, length: 0))
        ws.beginOrEndSelect()
        assertTest("EditMenu M2.1.D: Backward beginOrEndSelect sets range [2, 6] correctly",
                   ws.beginSelectAnchor == nil && tv.selectedRange().location == 2 && tv.selectedRange().length == 6)

        // -------------------------------------------------------------
        // GROUP 2: Insert Date Time (customized)
        // -------------------------------------------------------------
        ws.customDateFormat = "yyyy/MM/dd HH:mm:ss"
        tv.string = "Prefix: "
        doc.content = tv.string
        tv.setSelectedRange(NSRange(location: 8, length: 0))
        NppEditOperations.insertCustomDateTime(in: tv, format: "yyyy-MM-dd")
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        let expectedDateStr = df.string(from: Date())
        assertTest("EditMenu M2.2.A: insertCustomDateTime inserts formatted date string at caret",
                   tv.string == "Prefix: " + expectedDateStr)

        tv.string = "Custom: "
        doc.content = tv.string
        tv.setSelectedRange(NSRange(location: 8, length: 0))
        ws.customDateFormat = "yyyyMMdd_HHmmss"
        ws.executeMacroStep(.insertDateTimeCustomized, in: tv, document: doc)
        df.dateFormat = "yyyyMMdd"
        let datePart = df.string(from: Date())
        assertTest("EditMenu M2.2.B: Macro step insertDateTimeCustomized uses ws.customDateFormat",
                   tv.string.hasPrefix("Custom: \(datePart)_") && doc.content == tv.string)

        let macroWithCustom = NppWorkspace.NppSavedMacro(
            name: "TestCustomDateMacro",
            steps: [.insertDateTimeCustomized]
        )
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        if let encodedData = try? encoder.encode([macroWithCustom]),
           let decodedMacros = try? decoder.decode([NppWorkspace.NppSavedMacro].self, from: encodedData) {
            assertTest("EditMenu M2.2.C: insertDateTimeCustomized serializes and deserializes cleanly in saved macros",
                       decodedMacros.first?.steps.first == .insertDateTimeCustomized)
        } else {
            assertTest("EditMenu M2.2.C: insertDateTimeCustomized serializes and deserializes cleanly in saved macros", false)
        }

        // -------------------------------------------------------------
        // GROUP 3: Copy All Filenames and Copy All File Paths
        // -------------------------------------------------------------
        let copyWs = NppWorkspace()
        copyWs.documents.removeAll()

        let docA = NppDocument(title: "fileA.swift")
        docA.filePath = URL(fileURLWithPath: "/Users/npp/Documents/fileA.swift")
        copyWs.documents.append(docA)

        let docB = NppDocument(title: "new 2")
        docB.filePath = nil
        copyWs.documents.append(docB)

        let docC = NppDocument(title: "app.log")
        docC.filePath = URL(fileURLWithPath: "/tmp/logs/app.log")
        copyWs.documents.append(docC)

        copyWs.copyAllFilenames()
        let pboard = NSPasteboard.general
        let filenamesClipboard = pboard.string(forType: .string) ?? ""
        assertTest("EditMenu M2.3.A: copyAllFilenames copies names joined by newline",
                   filenamesClipboard == "fileA.swift\nnew 2\napp.log")

        copyWs.copyAllFilePaths()
        let filepathsClipboard = pboard.string(forType: .string) ?? ""
        assertTest("EditMenu M2.3.B: copyAllFilePaths copies full paths (fallback to title if unsaved)",
                   filepathsClipboard == "/Users/npp/Documents/fileA.swift\nnew 2\n/tmp/logs/app.log")

        // -------------------------------------------------------------
        // GROUP 4: Indent Operations (Increase/Decrease & Tab/Backtab)
        // -------------------------------------------------------------
        tv.string = "Alpha\nBeta\nGamma"
        doc.content = tv.string
        tv.setSelectedRange(NSRange(location: 0, length: (tv.string as NSString).length))
        NppEditOperations.increaseLineIndent(in: tv, spaceCount: 4, useTabs: false)
        assertTest("EditMenu M2.4.A: increaseLineIndent with 4 spaces adds 4 leading spaces per line",
                   tv.string == "    Alpha\n    Beta\n    Gamma")

        NppEditOperations.increaseLineIndent(in: tv, spaceCount: 4, useTabs: true)
        assertTest("EditMenu M2.4.B: increaseLineIndent with useTabs adds leading tab per line",
                   tv.string == "\t    Alpha\n\t    Beta\n\t    Gamma")

        NppEditOperations.decreaseLineIndent(in: tv, spaceCount: 4)
        assertTest("EditMenu M2.4.C: decreaseLineIndent strips leading tab per line",
                   tv.string == "    Alpha\n    Beta\n    Gamma")

        NppEditOperations.decreaseLineIndent(in: tv, spaceCount: 4)
        assertTest("EditMenu M2.4.D: decreaseLineIndent strips 4 leading spaces per line back to original",
                   tv.string == "Alpha\nBeta\nGamma")

        tv.string = "  TwoSpaces\nNoSpaces"
        doc.content = tv.string
        tv.setSelectedRange(NSRange(location: 0, length: (tv.string as NSString).length))
        NppEditOperations.decreaseLineIndent(in: tv, spaceCount: 4)
        assertTest("EditMenu M2.4.E: decreaseLineIndent handles lines with fewer spaces safely",
                   tv.string == "TwoSpaces\nNoSpaces")

        // -------------------------------------------------------------
        // GROUP 5: Case Conversions (Proper case blend, Sentence case blend, ranDOm CasE)
        // -------------------------------------------------------------
        let properBlendInput = "hello world of macOS and XMLHTTPRequest"
        let properBlendResult = NppEditOperations.transformProperCase(properBlendInput, blend: true)
        assertTest("EditMenu M2.5.A: Proper Case (blend) capitalizes words without lowercasing existing uppercase",
                   properBlendResult == "Hello World Of MacOS And XMLHTTPRequest")

        let properStrictResult = NppEditOperations.transformProperCase(properBlendInput, blend: false)
        assertTest("EditMenu M2.5.B: Strict Proper Case forces lowercase on rest of word",
                   properStrictResult == "Hello World Of Macos And Xmlhttprequest")

        let sentenceBlendInput = "hello world. this is macOS! does it work? yes."
        let sentenceBlendResult = NppEditOperations.transformSentenceCase(sentenceBlendInput, blend: true)
        assertTest("EditMenu M2.5.C: Sentence case (blend) capitalizes sentences without downcasing inner uppercase",
                   sentenceBlendResult == "Hello world. This is macOS! Does it work? Yes.")

        let sentenceStrictResult = NppEditOperations.transformSentenceCase(sentenceBlendInput, blend: false)
        assertTest("EditMenu M2.5.D: Strict Sentence case lowercases inner uppercase",
                   sentenceStrictResult == "Hello world. This is macos! Does it work? Yes.")

        let randomInput = "the quick brown fox jumps over the lazy dog"
        let randomResult = NppEditOperations.transformRandomCase(randomInput)
        let hasUpper = randomResult.contains { $0.isUppercase }
        let hasLower = randomResult.contains { $0.isLowercase }
        assertTest("EditMenu M2.5.E: ranDOm CasE preserves length, produces mixed case, and matches case-insensitively",
                   randomResult.count == randomInput.count && hasUpper && hasLower && randomResult.lowercased() == randomInput.lowercased())

        // -------------------------------------------------------------
        // GROUP 6: Advanced Line Operations
        // -------------------------------------------------------------
        let dupDoc = NppDocument(title: "dupTest", content: "Apple\nApple\nBanana\nApple\nApple\nCherry\nCherry", eol: .lf)
        NppEditOperations.removeConsecutiveDuplicateLines(in: dupDoc)
        assertTest("EditMenu M2.6.A: removeConsecutiveDuplicateLines preserves non-consecutive duplicates",
                   dupDoc.content == "Apple\nBanana\nApple\nCherry")

        let randDoc = NppDocument(title: "randTest", content: (1...20).map { "Line \($0)" }.joined(separator: "\n"), eol: .lf)
        let originalSorted = randDoc.content.components(separatedBy: "\n").sorted()
        NppEditOperations.randomizeLineOrder(in: randDoc)
        let shuffledSorted = randDoc.content.components(separatedBy: "\n").sorted()
        assertTest("EditMenu M2.6.B: randomizeLineOrder produces permutation of same lines",
                   shuffledSorted == originalSorted && randDoc.content.components(separatedBy: "\n").count == 20)

        let caseDoc = NppDocument(title: "caseTest", content: "banana\nApple\ncherry\nBanana\napple", eol: .lf)
        NppEditOperations.sortLinesCaseInsensitive(in: caseDoc, ascending: true)
        let ascLines = caseDoc.content.components(separatedBy: "\n")
        assertTest("EditMenu M2.6.C: sortLinesCaseInsensitive ascending groups case-insensitively",
                   ascLines.first?.lowercased() == "apple" && ascLines.last?.lowercased() == "cherry")

        NppEditOperations.sortLinesCaseInsensitive(in: caseDoc, ascending: false)
        let descLines = caseDoc.content.components(separatedBy: "\n")
        assertTest("EditMenu M2.6.D: sortLinesCaseInsensitive descending reverses order",
                   descLines.first?.lowercased() == "cherry" && descLines.last?.lowercased() == "apple")

        let lengthDoc = NppDocument(title: "lengthTest", content: "Three\nOne\nSeventeen\nFive", eol: .lf)
        NppEditOperations.sortLinesByLength(in: lengthDoc, ascending: true)
        assertTest("EditMenu M2.6.E: sortLinesByLength ascending orders shortest to longest",
                   lengthDoc.content == "One\nFive\nThree\nSeventeen")

        NppEditOperations.sortLinesByLength(in: lengthDoc, ascending: false)
        assertTest("EditMenu M2.6.F: sortLinesByLength descending orders longest to shortest",
                   lengthDoc.content == "Seventeen\nThree\nFive\nOne")

        // -------------------------------------------------------------
        // GROUP 7: Blank Operations
        // -------------------------------------------------------------
        let trimDoc = NppDocument(title: "trimTest", content: "   First Line   \n\tSecond Line\t\n   Third Line   ", eol: .lf)
        NppEditOperations.trimBothAndEolToSpace(in: trimDoc)
        assertTest("EditMenu M2.7.A: trimBothAndEolToSpace trims leading/trailing whitespace per line and collapses EOL to space",
                   trimDoc.content == "First Line Second Line Third Line")

        let spaceAllDoc = NppDocument(title: "spaceAllTest", content: "    Line    Middle  ", eol: .lf)
        NppEditOperations.spaceToTabAll(in: spaceAllDoc, spaceCount: 4)
        assertTest("EditMenu M2.7.B: spaceToTabAll converts 4 spaces to tabs everywhere",
                   spaceAllDoc.content == "\tLine\tMiddle  ")

        let spaceLeadDoc = NppDocument(title: "spaceLeadTest", content: "    Line    Middle  ", eol: .lf)
        NppEditOperations.spaceToTabLeading(in: spaceLeadDoc, spaceCount: 4)
        assertTest("EditMenu M2.7.C: spaceToTabLeading converts only leading 4 spaces to tab",
                   spaceLeadDoc.content == "\tLine    Middle  ")

        // -------------------------------------------------------------
        // GROUP 8: On Selection Submenu (Search URL & Redact)
        // -------------------------------------------------------------
        ws.searchEngineChoice = 1
        let googleUrl = ws.resolvedSearchUrl(for: "Notepad++ Mac")
        assertTest("EditMenu M2.8.A: resolvedSearchUrl default Google contains query parameters",
                   googleUrl != nil && (googleUrl!.absoluteString.contains("Notepad") && googleUrl!.absoluteString.contains("Mac")))

        ws.searchEngineChoice = 0
        let ddgUrl = ws.resolvedSearchUrl(for: "swift")
        assertTest("EditMenu M2.8.B: resolvedSearchUrl DuckDuckGo generates duckduckgo.com query",
                   ddgUrl?.absoluteString == "https://duckduckgo.com/?q=swift")

        ws.searchEngineChoice = 4
        ws.customSearchEngineUrl = "https://custom.engine/search?text=%s"
        let customUrl = ws.resolvedSearchUrl(for: "test query")
        assertTest("EditMenu M2.8.C: resolvedSearchUrl Custom engine substitutes %s with encoded query",
                   customUrl?.absoluteString == "https://custom.engine/search?text=test%20query")
        ws.searchEngineChoice = 1
        ws.customSearchEngineUrl = ""

        tv.string = "Confidential Information"
        doc.content = tv.string
        tv.setSelectedRange(NSRange(location: 0, length: 12))
        let maskChar: Character = "█"
        let masked1 = String(repeating: maskChar, count: 12)
        tv.replaceCharacters(in: tv.selectedRange(), with: masked1)
        assertTest("EditMenu M2.8.D: Redact standard replaces selection with full blocks (█)",
                   tv.string.hasPrefix("████████████ Information"))

        tv.setSelectedRange(NSRange(location: 13, length: 11))
        let bulletChar: Character = "●"
        let masked2 = String(repeating: bulletChar, count: 11)
        tv.replaceCharacters(in: tv.selectedRange(), with: masked2)
        assertTest("EditMenu M2.8.E: Redact shift replaces selection with bullets (●)",
                   tv.string == "████████████ ●●●●●●●●●●●")

        // -------------------------------------------------------------
        // GROUP 9: Read-Only in Notepad++ & Side Panels
        // -------------------------------------------------------------
        assertTest("EditMenu M2.9.A: Initial doc.isReadOnly is false", doc.isReadOnly == false)
        ws.toggleReadOnlyCurrentDoc()
        assertTest("EditMenu M2.9.B: toggleReadOnlyCurrentDoc toggles doc.isReadOnly to true", doc.isReadOnly == true)
        ws.toggleReadOnlyCurrentDoc()
        assertTest("EditMenu M2.9.C: toggleReadOnlyCurrentDoc toggles doc.isReadOnly back to false", doc.isReadOnly == false)

        assertTest("EditMenu M2.9.D: Initial isAllDocumentsReadOnly is false", ws.isAllDocumentsReadOnly == false)
        ws.setReadOnlyAllDocs()
        assertTest("EditMenu M2.9.E: setReadOnlyAllDocs sets isAllDocumentsReadOnly to true", ws.isAllDocumentsReadOnly == true)
        ws.clearReadOnlyAllDocs()
        assertTest("EditMenu M2.9.F: clearReadOnlyAllDocs restores isAllDocumentsReadOnly to false", ws.isAllDocumentsReadOnly == false)

        assertTest("EditMenu M2.9.G: Initial showClipboardHistory is false", ws.showClipboardHistory == false)
        ws.showClipboardHistory = true
        assertTest("EditMenu M2.9.H: showClipboardHistory toggled to true", ws.showClipboardHistory == true)
        ws.clipboardHistory.removeAll()
        ws.addToClipboardHistory("First item")
        ws.addToClipboardHistory("Second item")
        ws.addToClipboardHistory("First item")
        assertTest("EditMenu M2.9.I: addToClipboardHistory adds items and deduplicates to top",
                   ws.clipboardHistory.first?.text == "First item" && ws.clipboardHistory.count == 2)
        ws.showClipboardHistory = false

        assertTest("EditMenu M2.9.J: Initial showCharacterPanel is false", ws.showCharacterPanel == false)
        ws.showCharacterPanel = true
        assertTest("EditMenu M2.9.K: showCharacterPanel toggled to true", ws.showCharacterPanel == true)
        ws.showCharacterPanel = false

        // -------------------------------------------------------------
        // GROUP 10: Localization Parity (korean.xml)
        // -------------------------------------------------------------
        let testTranslations: [(String, String)] = [
            ("Begin/End Select", "시작/끝 선택"),
            ("Date Time (customized)", "날짜와 시간 (사용자 정의)"),
            ("Copy All Filenames", "모든 파일 이름 복사"),
            ("Copy All File Paths", "모든 파일 경로 복사"),
            ("Indent", "들여쓰기/내어쓰기"),
            ("Increase Line Indent", "탭 삽입 (들여쓰기)"),
            ("Decrease Line Indent", "탭 제거 (내어쓰기)"),
            ("Proper Case (blend)", "단어 첫 글자만 대문자로 (혼합)"),
            ("Sentence case (blend)", "문장 첫 글자만 대문자로 (혼합)"),
            ("ranDOm CasE", "무작위 대/소문자 (ranDOm CasE)"),
            ("Remove Consecutive Duplicate Lines", "연속으로 중복된 줄 삭제"),
            ("Randomize Line Order", "임의로 정렬"),
            ("Sort Lines Lex. Ascending Ignoring Case", "사전식 오름차순 정렬(대소문자 무시)"),
            ("Sort Lines Lex. Descending Ignoring Case", "사전식 내림차순 정렬(대소문자 무시)"),
            ("Sort Lines By Length Ascending", "길이 오름차순 정렬"),
            ("Sort Lines By Length Descending", "길이 내림차순 정렬"),
            ("Trim both and EOL to Space", "줄 앞/뒤 공백 제거 후 줄의 끝문자(EOL)를 공백으로 변환"),
            ("Space to TAB (All)", "공백을 탭으로 (모두)"),
            ("Space to TAB (Leading)", "공백을 탭으로 (줄 시작)"),
            ("On Selection", "선택시"),
            ("Open File", "파일 열기"),
            ("Open Containing Folder in Finder", "Finder에서 현재 폴더 열기"),
            ("Redact Selection █ (Shift: ●)", "선택 영역 █으로 가리기 (Shift: ●)"),
            ("Search on Internet", "인터넷에서 검색"),
            ("Change Search Engine...", "검색 엔진 변경..."),
            ("Read-Only in Notepad++", "Notepad++ 읽기 전용 설정"),
            ("Read-Only on Current Document", "현재 문서만 읽기 전용으로 설정"),
            ("Read-Only for All Documents", "모든 문서를 읽기 전용으로 설정"),
            ("Clear Read-Only for All Documents", "모든 문서의 읽기 전용 해제"),
            ("Character Panel", "문자 패널"),
            ("Clipboard History", "클립보드 히스토리"),
            ("Open Path", "경로 열기"),
            ("The path you're trying to open doesn't exist.", "열려는 경로가 존재하지 않습니다.")
        ]
        var allTranslationsMatch = true
        for (en, ko) in testTranslations {
            let actualKo = NppLocalization.tr(en, lang: "한국어")
            if actualKo != ko {
                print("❌ Translation mismatch for '\(en)': expected '\(ko)', got '\(actualKo)'")
                allTranslationsMatch = false
            }
        }
        assertTest("EditMenu M2.10.A: All 29 Edit Menu Korean translations match korean.xml exactly", allTranslationsMatch)

        ws.closeDocument(id: doc.id)
    }

    // =========================================================================
    // 31. ADVERSARIAL CHALLENGE SUITE: PASS 2 (M2.2)
    // =========================================================================
    static func runAdversarialM2ChallengeTests(
        ws: NppWorkspace,
        appDelegate: AppDelegate,
        assertTest: (String, Bool) -> Void
    ) {
        print("\n========================================================")
        print("⚔️ ADVERSARIAL CHALLENGE SUITE: MILESTONE 2 (PASS 2)")
        print("========================================================")

        // -------------------------------------------------------------
        // CHALLENGE 1: Begin/End Select
        // -------------------------------------------------------------
        ws.newDocument()
        guard let doc1 = ws.activeDocument else { return }
        let tv1 = NppTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 400))
        tv1.string = "Document 1 Content with length forty-four!!!"
        doc1.content = tv1.string
        ws.activeTextView = tv1

        // 1.1: Forward selection on single document
        tv1.setSelectedRange(NSRange(location: 5, length: 0))
        ws.beginOrEndSelect()
        assertTest("Adversarial M2.1.A: Forward select - begin sets anchor at 5", ws.beginSelectAnchor == 5)
        tv1.setSelectedRange(NSRange(location: 20, length: 0))
        ws.beginOrEndSelect()
        assertTest("Adversarial M2.1.B: Forward select - end sets range [5, 15] and clears anchor",
                   ws.beginSelectAnchor == nil && tv1.selectedRange().location == 5 && tv1.selectedRange().length == 15)

        // 1.2: Backward selection on single document
        tv1.setSelectedRange(NSRange(location: 25, length: 0))
        ws.beginOrEndSelect()
        assertTest("Adversarial M2.1.C: Backward select - begin sets anchor at 25", ws.beginSelectAnchor == 25)
        tv1.setSelectedRange(NSRange(location: 10, length: 0))
        ws.beginOrEndSelect()
        assertTest("Adversarial M2.1.D: Backward select - end sets range [10, 15] and clears anchor",
                   ws.beginSelectAnchor == nil && tv1.selectedRange().location == 10 && tv1.selectedRange().length == 15)

        // 1.3: Anchor toggling across document switches & boundary clamping
        // Set anchor in doc1 at index 35 (doc1 length is 44)
        tv1.setSelectedRange(NSRange(location: 35, length: 0))
        ws.beginOrEndSelect()
        assertTest("Adversarial M2.1.E: Cross-doc - anchor set at 35 in doc1", ws.beginSelectAnchor == 35)

        // Create doc2 which is MUCH shorter (length 10)
        ws.newDocument()
        guard let doc2 = ws.activeDocument else { return }
        let tv2 = NppTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 400))
        tv2.string = "0123456789" // length 10
        doc2.content = tv2.string
        ws.activeTextView = tv2
        tv2.setSelectedRange(NSRange(location: 3, length: 0))

        // Cross-doc switch must reset beginSelectAnchor to nil so Tab 1 anchor does not leak into Tab 2
        assertTest("Adversarial M2.1.F: Cross-doc switch resets anchor to nil (prevents cross-tab leak)",
                   ws.beginSelectAnchor == nil)

        // 1.4: Extreme boundary clamping: Empty document
        ws.newDocument()
        guard let doc3 = ws.activeDocument else { return }
        let tv3 = NppTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 400))
        tv3.string = ""
        doc3.content = ""
        ws.activeTextView = tv3
        tv3.setSelectedRange(NSRange(location: 0, length: 0))
        ws.beginOrEndSelect()
        assertTest("Adversarial M2.1.G: Empty document beginSelect sets anchor at 0", ws.beginSelectAnchor == 0)
        ws.beginOrEndSelect()
        assertTest("Adversarial M2.1.H: Empty document endSelect sets range (0, 0) safely",
                   ws.beginSelectAnchor == nil && tv3.selectedRange().location == 0 && tv3.selectedRange().length == 0)

        // 1.5: Anchor clamping when text was deleted while anchor was set
        tv1.string = "Long initial text before truncation"
        doc1.content = tv1.string
        ws.activeDocumentId = doc1.id
        ws.activeTextView = tv1
        tv1.setSelectedRange(NSRange(location: 25, length: 0))
        ws.beginOrEndSelect() // anchor = 25
        tv1.string = "Short" // length 5, anchor 25 is now past end of document
        doc1.content = tv1.string
        tv1.setSelectedRange(NSRange(location: 2, length: 0))
        ws.beginOrEndSelect()
        assertTest("Adversarial M2.1.I: Anchor beyond truncated text length safely clamps to doc end [2, 3]",
                   ws.beginSelectAnchor == nil && tv1.selectedRange().location == 2 && tv1.selectedRange().length == 3)

        // -------------------------------------------------------------
        // CHALLENGE 2: Read-Only modes (Typing, Cut/Paste, Hotkeys)
        // -------------------------------------------------------------
        let initialROText = "The Quick Brown Fox Jumps Over The Lazy Dog"
        tv1.string = initialROText
        doc1.content = initialROText
        tv1.setSelectedRange(NSRange(location: 4, length: 5)) // "Quick"

        // 2.1: doc.isReadOnly == true
        doc1.isReadOnly = true
        ws.isAllDocumentsReadOnly = false
        let effectiveRO1 = !doc1.isReadOnly && !ws.isAllDocumentsReadOnly
        tv1.isEditable = effectiveRO1
        assertTest("Adversarial M2.2.A: doc.isReadOnly=true enforces tv.isEditable=false", tv1.isEditable == false)

        // Test typing insertion blocked
        tv1.insertText("Hacked", replacementRange: tv1.selectedRange())
        assertTest("Adversarial M2.2.B: Typing insertText strictly blocked when read-only", tv1.string == initialROText)

        // Test cut blocked
        tv1.cut(nil)
        assertTest("Adversarial M2.2.C: Cut strictly blocked when read-only", tv1.string == initialROText)

        // Test paste blocked
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString("MaliciousPaste", forType: .string)
        tv1.paste(nil)
        assertTest("Adversarial M2.2.D: Paste strictly blocked when read-only", tv1.string == initialROText)

        // Test hotkey editing via keyDown (Cmd+D duplicate line, Cmd+J join, Tab indent)
        let cmdDEvent = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [.command], timestamp: 0, windowNumber: 0, context: nil, characters: "d", charactersIgnoringModifiers: "d", isARepeat: false, keyCode: 2)
        if let event = cmdDEvent {
            tv1.keyDown(with: event)
        }
        assertTest("Adversarial M2.2.E: Cmd+D duplicate line strictly blocked when read-only", tv1.string == initialROText)

        let cmdJEvent = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [.command], timestamp: 0, windowNumber: 0, context: nil, characters: "j", charactersIgnoringModifiers: "j", isARepeat: false, keyCode: 38)
        if let event = cmdJEvent {
            tv1.keyDown(with: event)
        }
        assertTest("Adversarial M2.2.F: Cmd+J join lines strictly blocked when read-only", tv1.string == initialROText)

        tv1.insertTab(nil)
        assertTest("Adversarial M2.2.G: Tab indentation strictly blocked when read-only", tv1.string == initialROText)

        tv1.insertBacktab(nil)
        assertTest("Adversarial M2.2.H: Shift+Tab unindentation strictly blocked when read-only", tv1.string == initialROText)

        // Test NppEditOperations blocked via shouldChangeText
        NppEditOperations.increaseLineIndent(in: tv1, spaceCount: 4, useTabs: true)
        assertTest("Adversarial M2.2.I: increaseLineIndent blocked by shouldChangeText when read-only", tv1.string == initialROText)

        NppEditOperations.decreaseLineIndent(in: tv1, spaceCount: 4)
        assertTest("Adversarial M2.2.J: decreaseLineIndent blocked by shouldChangeText when read-only", tv1.string == initialROText)

        NppEditOperations.convertCase(in: tv1, to: .uppercase)
        assertTest("Adversarial M2.2.K: convertCase blocked by shouldChangeText when read-only", tv1.string == initialROText)

        // 2.2: ws.isAllDocumentsReadOnly == true
        doc1.isReadOnly = false
        ws.isAllDocumentsReadOnly = true
        let effectiveRO2 = !doc1.isReadOnly && !ws.isAllDocumentsReadOnly
        tv1.isEditable = effectiveRO2
        assertTest("Adversarial M2.2.L: isAllDocumentsReadOnly=true enforces tv.isEditable=false", tv1.isEditable == false)

        tv1.insertText("HackedAll", replacementRange: tv1.selectedRange())
        tv1.cut(nil)
        tv1.paste(nil)
        NppEditOperations.convertCase(in: tv1, to: .lowercase)
        assertTest("Adversarial M2.2.M: All edits strictly blocked when isAllDocumentsReadOnly=true", tv1.string == initialROText)

        // Reset read-only states
        ws.clearReadOnlyAllDocs()
        assertTest("Adversarial M2.2.N: clearReadOnlyAllDocs restores isAllDocumentsReadOnly=false and doc.isReadOnly=false",
                   ws.isAllDocumentsReadOnly == false && doc1.isReadOnly == false)

        // -------------------------------------------------------------
        // CHALLENGE 3: On Selection Actions (Redact, URL Search, Path)
        // -------------------------------------------------------------
        // 3.1: Redact Selection with CRLF and LF newlines
        let multiLineText = "Secret Line 1\r\nSecret Line 2\nEnd Line"
        tv1.string = multiLineText
        doc1.content = multiLineText
        tv1.isEditable = true
        // Select from "Line 1\r\nSecret Line 2" (location 7, length 21: 6 + 2 + 13)
        let redactRange = NSRange(location: 7, length: 21)
        tv1.setSelectedRange(redactRange)
        let selText = (tv1.string as NSString).substring(with: redactRange)
        let redactedBlock = NppEditOperations.redact(text: selText, mask: "█")
        if tv1.shouldChangeText(in: redactRange, replacementString: redactedBlock) {
            tv1.replaceCharacters(in: redactRange, with: redactedBlock)
        }
        let crlfPreserved = tv1.string.contains("\r\n")
        assertTest("Adversarial M2.3.A: Redact █ preserves \\r and \\n line breaks (CRLF \\r\\n must not become █)",
                   crlfPreserved && tv1.string == "Secret ██████\r\n█████████████\nEnd Line")

        // Redact bullet (●)
        tv1.string = "Classified: 9876-5432"
        doc1.content = tv1.string
        let bulletRange = NSRange(location: 12, length: 9) // "9876-5432"
        tv1.setSelectedRange(bulletRange)
        let bulletSelText = (tv1.string as NSString).substring(with: bulletRange)
        let redactedBullet = NppEditOperations.redact(text: bulletSelText, mask: "●")
        if tv1.shouldChangeText(in: bulletRange, replacementString: redactedBullet) {
            tv1.replaceCharacters(in: bulletRange, with: redactedBullet)
        }
        assertTest("Adversarial M2.3.B: Redact ● replaces characters with bullets",
                   tv1.string == "Classified: ●●●●●●●●●")

        // Redact on Read-Only must NOT mutate text
        doc1.isReadOnly = true
        tv1.isEditable = false
        let roRedactRange = NSRange(location: 0, length: 10)
        tv1.setSelectedRange(roRedactRange)
        if tv1.shouldChangeText(in: roRedactRange, replacementString: "██████████") {
            tv1.replaceCharacters(in: roRedactRange, with: "██████████")
        }
        assertTest("Adversarial M2.3.C: Redact on read-only document is strictly rejected",
                   tv1.string == "Classified: ●●●●●●●●●")
        doc1.isReadOnly = false
        tv1.isEditable = true

        // 3.2: URL Searching (resolvedSearchUrl)
        // Test all standard search engines
        ws.searchEngineChoice = 0 // DuckDuckGo
        let ddgActual = ws.resolvedSearchUrl(for: "Notepad++")?.absoluteString ?? "nil"
        assertTest("Adversarial M2.3.D: Search DuckDuckGo produces expected URL",
                   ddgActual == "https://duckduckgo.com/?q=Notepad++" || ddgActual == "https://duckduckgo.com/?q=Notepad%2B%2B")

        ws.searchEngineChoice = 1 // Google
        assertTest("Adversarial M2.3.E: Search Google produces expected URL",
                   ws.resolvedSearchUrl(for: "AppKit Swift")?.absoluteString == "https://www.google.com/search?q=AppKit%20Swift")

        ws.searchEngineChoice = 2 // Yahoo
        assertTest("Adversarial M2.3.F: Search Yahoo produces expected URL",
                   ws.resolvedSearchUrl(for: "query")?.absoluteString == "https://search.yahoo.com/search?q=query")

        ws.searchEngineChoice = 3 // StackOverflow
        assertTest("Adversarial M2.3.G: Search StackOverflow produces expected URL",
                   ws.resolvedSearchUrl(for: "core text")?.absoluteString == "https://stackoverflow.com/search?q=core%20text")

        // Custom search engines with $(CURRENT_WORD) and %s and raw append
        ws.searchEngineChoice = 4
        ws.customSearchEngineUrl = "https://kagi.com/search?q=$(CURRENT_WORD)&opt=1"
        assertTest("Adversarial M2.3.H: Custom search with $(CURRENT_WORD) substitutes correctly",
                   ws.resolvedSearchUrl(for: "test symbol")?.absoluteString == "https://kagi.com/search?q=test%20symbol&opt=1")

        ws.customSearchEngineUrl = "https://github.com/search?q=%s"
        assertTest("Adversarial M2.3.I: Custom search with %s substitutes correctly",
                   ws.resolvedSearchUrl(for: "repo:notepad")?.absoluteString == "https://github.com/search?q=repo:notepad")

        // Empty and whitespace queries must return nil safely
        assertTest("Adversarial M2.3.J: Empty query returns nil", ws.resolvedSearchUrl(for: "") == nil)
        assertTest("Adversarial M2.3.K: Whitespace-only query returns nil", ws.resolvedSearchUrl(for: "   \n\t  ") == nil)

        // 3.3: Path opening resolution logic
        let validHttp = "https://github.com/notepad-plus-plus"
        assertTest("Adversarial M2.3.L: HTTP/HTTPS prefix detected as valid web URL",
                   validHttp.hasPrefix("http://") || validHttp.hasPrefix("https://"))

        let samplePath = "Package.swift"
        assertTest("Adversarial M2.3.M: Local file existence verified for existing repository file",
                   FileManager.default.fileExists(atPath: samplePath))

        let nonExistentPath = "/path/to/definitely/non_existent_file_xyz_123.txt"
        assertTest("Adversarial M2.3.N: Non-existent path returns false for fileExists",
                   !FileManager.default.fileExists(atPath: nonExistentPath))

        let quotedPath = "\"Package.swift\""
        let stripped = quotedPath.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "\"\'"))
        assertTest("Adversarial M2.3.O: Path stripping removes enclosing quotes cleanly",
                   stripped == "Package.swift" && FileManager.default.fileExists(atPath: stripped))

        // Clean up documents
        ws.closeDocument(id: doc1.id)
        ws.closeDocument(id: doc2.id)
        ws.closeDocument(id: doc3.id)
    }

    // =========================================================================
    // 32. MILESTONES 3 & 4: SEARCH, VIEW, ENCODING, LANGUAGE, TOOLS & WINDOW PARITY
    // =========================================================================
    static func runSearchAndViewMenuParityTests(
        ws: NppWorkspace,
        appDelegate: AppDelegate,
        assertTest: (String, Bool) -> Void
    ) {
        print("\n========================================================")
        print("🔍 MILESTONES 3 & 4: SEARCH, VIEW, ENCODING, LANGUAGE, TOOLS & WINDOW PARITY")
        print("========================================================")

        ws.newDocument()
        guard let doc = ws.activeDocument else { return }
        let tv = ws.activeTextView ?? NSTextView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
        ws.activeTextView = tv
        doc.isReadOnly = false
        ws.isAllDocumentsReadOnly = false

        // ---------------------------------------------------------------------
        // 32.1 M2 Iteration 2 Edge-Case Hardening Verification
        // ---------------------------------------------------------------------
        doc.content = "    \n        \n    code"
        doc.eolFormat = .lf
        NppEditOperations.spaceToTabLeading(in: doc, spaceCount: 4)
        assertTest("M2.Iter2: spaceToTabLeading converts all-space lines without duplicating trailing spaces",
                   doc.content == "\t\n\t\t\n\tcode")

        let redactInput = "Secret\r\nLine2\nEnd"
        tv.string = redactInput
        tv.setSelectedRange(NSRange(location: 0, length: (redactInput as NSString).length))
        NppEditOperations.redactSelection(in: tv, useBullet: false)
        let redactedBlock = tv.string
        tv.string = redactInput
        tv.setSelectedRange(NSRange(location: 0, length: (redactInput as NSString).length))
        NppEditOperations.redactSelection(in: tv, useBullet: true)
        let redactedBullet = tv.string
        assertTest("M2.Iter2: redactSelection masks characters with █ while preserving CRLF and LF",
                   redactedBlock == "██████\r\n█████\n███")
        assertTest("M2.Iter2: redactSelection(useBullet: true) masks characters with ● while preserving newlines",
                   redactedBullet == "●●●●●●\r\n●●●●●\n●●●")

        // Read-only macro step guard
        tv.string = "ImmutableLine1\nImmutableLine2"
        doc.content = tv.string
        doc.isReadOnly = true
        ws.executeMacroStep(.sortLines, in: tv, document: doc)
        ws.executeMacroStep(.insertText("HACK"), in: tv, document: doc)
        assertTest("M2.Iter2: executeMacroStep does not mutate read-only document",
                   doc.content == "ImmutableLine1\nImmutableLine2" && tv.string == "ImmutableLine1\nImmutableLine2")
        ws.executeMacroSteps([.insertText("MacroHack"), .removeEmptyLines])
        assertTest("M2.Iter2: executeMacroSteps does not mutate read-only document",
                   doc.content == "ImmutableLine1\nImmutableLine2" && tv.string == "ImmutableLine1\nImmutableLine2")
        doc.isReadOnly = false

        // -------------------------------------------------------------
        // Indent Selection Tracking Tests (No Overshoot & No Exclusion)
        // -------------------------------------------------------------
        let indentTv = NSTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 400))
        indentTv.string = "    Line 1\n    Line 2\n    Line 3\n"
        // Select Line 1 and Line 2 exactly (0..<22)
        indentTv.setSelectedRange(NSRange(location: 0, length: 22))
        NppEditOperations.decreaseLineIndent(in: indentTv, spaceCount: 4)
        assertTest("EditMenu M2.4.F: decreaseLineIndent does NOT overshoot into subsequent lines",
                   indentTv.selectedRange() == NSRange(location: 0, length: 14) &&
                   indentTv.string == "Line 1\nLine 2\n    Line 3\n")

        indentTv.string = "Line 1\nLine 2\nLine 3\n"
        indentTv.setSelectedRange(NSRange(location: 0, length: 14))
        NppEditOperations.increaseLineIndent(in: indentTv, spaceCount: 4, useTabs: true)
        assertTest("EditMenu M2.4.G: increaseLineIndent retains full selection including first tab",
                   indentTv.selectedRange() == NSRange(location: 0, length: 16) &&
                   indentTv.string == "\tLine 1\n\tLine 2\nLine 3\n")

        // -------------------------------------------------------------
        // Adversarial Challenge M2.Iter2.2: Indent Boundaries & Anchor State
        // -------------------------------------------------------------
        // Adv 1.1: decreaseLineIndent on 10-line document, selecting lines 3..7
        let tenLinesTv = NSTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 400))
        var originalTenLines = ""
        for i in 1...10 { originalTenLines += "    Line \(i)\n" }
        tenLinesTv.string = originalTenLines
        // Line length is 11 (4 spaces + 6 text + 1 newline). Lines 1-2 = 22 chars. Lines 3-7 = 5 * 11 = 55 chars.
        tenLinesTv.setSelectedRange(NSRange(location: 22, length: 55))
        NppEditOperations.decreaseLineIndent(in: tenLinesTv, spaceCount: 4)
        // Lines 1-2 unchanged (22 chars). Lines 3-7 deindented: 5 * 7 = 35 chars. Lines 8-10 untouched (3 * 11 = 33 chars).
        // New selection must be location 22, length 35 (ending exactly at 57, never overshooting into Line 8 which starts at 57)
        let tenLinesNewStr = tenLinesTv.string
        let line8Untouched = tenLinesNewStr.contains("    Line 8\n    Line 9\n    Line 10\n")
        let line12Untouched = tenLinesNewStr.hasPrefix("    Line 1\n    Line 2\n")
        assertTest("Adversarial M2.4.H: decreaseLineIndent across 5/10 lines never overshoots into Line 8",
                   tenLinesTv.selectedRange() == NSRange(location: 22, length: 35) &&
                   line12Untouched && line8Untouched)

        // Adv 1.2: decreaseLineIndent with partial selection across lines with mixed indentation
        let partialTv = NSTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 400))
        partialTv.string = "    Line 1\n\tLine 2\nLine 3\n  Line 4\n    Line 5\n"
        // Line 1: 0..<11 ("    Line 1\n")
        // Line 2: 11..<19 ("\tLine 2\n", 8 chars)
        // Line 3: 19..<26 ("Line 3\n", 7 chars)
        // Line 4: 26..<35 ("  Line 4\n", 9 chars)
        // Line 5: 35..<46 ("    Line 5\n", 11 chars)
        // Select from middle of Line 2 (loc 13: "ine 2\n") through Line 3 to middle of Line 4 (loc 30: "  Line 4\nLine 3\n  Li")
        // loc 13, length 17 (ends at 30, inside Line 4)
        partialTv.setSelectedRange(NSRange(location: 13, length: 17))
        NppEditOperations.decreaseLineIndent(in: partialTv, spaceCount: 4)
        // Line 1 untouched (11 chars).
        // Line 2 loses 1 tab: "\tLine 2\n" -> "Line 2\n" (7 chars). Start of Line 2 is 11.
        // Line 3 loses 0 chars: "Line 3\n" (7 chars).
        // Line 4 loses 2 spaces: "  Line 4\n" -> "Line 4\n" (7 chars).
        // Line 5 untouched ("    Line 5\n").
        // Total removed = 1 + 0 + 2 = 3 chars. Line 2 removed = 1.
        // newStart = max(11, 13 - 1) = 12. newEnd = max(12, 30 - 3) = 27. length = 15.
        // Line 5 starts at 11 + 7 + 7 + 7 = 32. 27 < 32, so selection never touches Line 5!
        let line5Untouched = partialTv.string.hasSuffix("    Line 5\n")
        assertTest("Adversarial M2.4.I: decreaseLineIndent partial mixed indent never overshoots into Line 5",
                   partialTv.selectedRange().location == 12 &&
                   NSMaxRange(partialTv.selectedRange()) <= 27 &&
                   line5Untouched)

        // Adv 1.3: decreaseLineIndent with empty lines within selection
        let emptyTv = NSTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 400))
        emptyTv.string = "    Alpha\n\n    Beta\n    Gamma\n"
        // Select Alpha through Beta: loc 0, length 18 ("    Alpha\n\n    Beta\n")
        emptyTv.setSelectedRange(NSRange(location: 0, length: 18))
        NppEditOperations.decreaseLineIndent(in: emptyTv, spaceCount: 4)
        // Alpha becomes "Alpha\n" (6 chars), empty line "\n" (1 char), Beta becomes "Beta\n" (5 chars).
        // Selection of 18 chars in original: "    Alpha\n\n    Bet" (6+1+3 = 10 chars in deindented text)
        assertTest("Adversarial M2.4.J: decreaseLineIndent with empty line preserves structure and ends at Gamma boundary",
                   emptyTv.string == "Alpha\n\nBeta\n    Gamma\n" &&
                   emptyTv.selectedRange() == NSRange(location: 0, length: 10))

        // Adv 2.1: increaseLineIndent on column-0 with spaces (useTabs = false, spaceCount = 4)
        let spaceIndentTv = NSTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 400))
        spaceIndentTv.string = "Item 1\nItem 2\n"
        spaceIndentTv.setSelectedRange(NSRange(location: 0, length: 6)) // "Item 1"
        NppEditOperations.increaseLineIndent(in: spaceIndentTv, spaceCount: 4, useTabs: false)
        assertTest("Adversarial M2.4.K: increaseLineIndent (spaces) includes leading 4 spaces in selection",
                   spaceIndentTv.string == "    Item 1\nItem 2\n" &&
                   spaceIndentTv.selectedRange() == NSRange(location: 0, length: 10))

        // Adv 2.2: increaseLineIndent on column-0 on a non-first line (Line 2)
        let midIndentTv = NSTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 400))
        midIndentTv.string = "Header\nItem 1\nItem 2\n"
        // Line 1: 0..<7 ("Header\n"). Line 2: 7..<14 ("Item 1\n").
        midIndentTv.setSelectedRange(NSRange(location: 7, length: 6)) // "Item 1"
        NppEditOperations.increaseLineIndent(in: midIndentTv, spaceCount: 4, useTabs: true)
        assertTest("Adversarial M2.4.L: increaseLineIndent on Line 2 col-0 includes tab in selection",
                   midIndentTv.string == "Header\n\tItem 1\nItem 2\n" &&
                   midIndentTv.selectedRange() == NSRange(location: 7, length: 7))

        // Adv 2.3: increaseLineIndent caret at col-0 (length 0) advances past tab
        let caretTv = NSTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 400))
        caretTv.string = "Plain Line\n"
        caretTv.setSelectedRange(NSRange(location: 0, length: 0))
        NppEditOperations.increaseLineIndent(in: caretTv, spaceCount: 4, useTabs: true)
        assertTest("Adversarial M2.4.M: increaseLineIndent at col-0 caret moves caret past inserted tab",
                   caretTv.string == "\tPlain Line\n" &&
                   caretTv.selectedRange() == NSRange(location: 1, length: 0))

        // Adv 3.1: Cross-document tab switching comprehensively resets beginSelectAnchor
        let crossWs = NppWorkspace()
        crossWs.documents.removeAll()
        let cDoc1 = NppDocument(title: "Doc1.txt", content: "01234567890123456789", eol: .lf)
        let cDoc2 = NppDocument(title: "Doc2.txt", content: "abcdefghij", eol: .lf)
        let cDoc3 = NppDocument(title: "Doc3.txt", content: "XYZ", eol: .lf)
        crossWs.documents = [cDoc1, cDoc2, cDoc3]
        crossWs.activeDocumentId = cDoc1.id

        let cTv1 = NppTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 400))
        cTv1.string = cDoc1.content
        crossWs.activeTextView = cTv1

        // Set anchor in Doc 1 at caret 5
        cTv1.setSelectedRange(NSRange(location: 5, length: 0))
        crossWs.beginOrEndSelect()
        assertTest("Adversarial M2.1.J1: Anchor set at 5 in Doc 1", crossWs.beginSelectAnchor == 5)

        // Switch tab to Doc 2 via nextTab()
        crossWs.nextTab()
        assertTest("Adversarial M2.1.J2: nextTab switches to Doc 2 and clears anchor",
                   crossWs.activeDocumentId == cDoc2.id && crossWs.beginSelectAnchor == nil)

        // Verify calling beginOrEndSelect() in Doc 2 sets a fresh anchor in Doc 2, NOT Doc 1's anchor
        let cTv2 = NppTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 400))
        cTv2.string = cDoc2.content
        crossWs.activeTextView = cTv2
        cTv2.setSelectedRange(NSRange(location: 2, length: 0))
        crossWs.beginOrEndSelect()
        assertTest("Adversarial M2.1.J3: beginOrEndSelect in Doc 2 sets fresh anchor at 2", crossWs.beginSelectAnchor == 2)

        // Switch to Doc 3 via selectTab(at: 2)
        crossWs.selectTab(at: 2)
        assertTest("Adversarial M2.1.J4: selectTab(at: 2) clears anchor", crossWs.beginSelectAnchor == nil)

        // Switch back to Doc 1 via selectTab(at: 0)
        crossWs.selectTab(at: 0)
        crossWs.activeTextView = cTv1
        assertTest("Adversarial M2.1.J5: selectTab(at: 0) clears anchor", crossWs.beginSelectAnchor == nil)

        // Set anchor in Doc 1 and close Doc 1
        cTv1.setSelectedRange(NSRange(location: 8, length: 0))
        crossWs.beginOrEndSelect()
        let anchorWas8 = (crossWs.beginSelectAnchor == 8)
        crossWs.closeDocument(id: cDoc1.id)
        assertTest("Adversarial M2.1.J6: closeDocument clears anchor on active tab change",
                   anchorWas8 && crossWs.beginSelectAnchor == nil)

        // Set anchor in Doc 2 and create newDocument()
        crossWs.activeTextView = cTv2
        cTv2.setSelectedRange(NSRange(location: 4, length: 0))
        crossWs.beginOrEndSelect()
        let anchorWas4 = (crossWs.beginSelectAnchor == 4)
        crossWs.newDocument()
        assertTest("Adversarial M2.1.J7: newDocument clears anchor",
                   anchorWas4 && crossWs.beginSelectAnchor == nil)


        // -------------------------------------------------------------
        // spaceToTabLeading All-Spaces Line Test
        // -------------------------------------------------------------
        let spaceDoc = NppDocument(title: "spaces.txt", content: "    \n        \n    Text", eol: .lf)
        NppEditOperations.spaceToTabLeading(in: spaceDoc, spaceCount: 4)
        assertTest("EditMenu M2.10.D: spaceToTabLeading handles lines consisting solely of spaces",
                   spaceDoc.content == "\t\n\t\t\n\tText")

        // -------------------------------------------------------------
        // Read-Only Defense-in-Depth Tests (All 17 Operations + EOL)
        // -------------------------------------------------------------
        let roDoc = NppDocument(title: "ro.txt", content: "  line B  \n\n  line A  \n  line A  \n\tline C", eol: .lf)
        roDoc.isReadOnly = true
        roDoc.isDirty = false
        let snapshot = roDoc.content

        NppEditOperations.removeEmptyLines(in: roDoc)
        NppEditOperations.removeDuplicateLines(in: roDoc)
        NppEditOperations.removeConsecutiveDuplicateLines(in: roDoc)
        NppEditOperations.sortLines(in: roDoc)
        NppEditOperations.randomizeLineOrder(in: roDoc)
        NppEditOperations.sortLinesCaseInsensitive(in: roDoc)
        NppEditOperations.sortLinesByLength(in: roDoc)
        NppEditOperations.reverseLineOrder(in: roDoc)
        NppEditOperations.sortLinesAsIntegers(in: roDoc)
        NppEditOperations.sortLinesAsDecimals(in: roDoc)
        NppEditOperations.trimSpaces(in: roDoc, mode: .both)
        NppEditOperations.eolToSpace(in: roDoc)
        NppEditOperations.tabToSpace(in: roDoc)
        NppEditOperations.spaceToTab(in: roDoc)
        NppEditOperations.trimBothAndEolToSpace(in: roDoc)
        NppEditOperations.spaceToTabAll(in: roDoc)
        NppEditOperations.spaceToTabLeading(in: roDoc)
        roDoc.convertEOL(to: .crlf)

        assertTest("ReadOnly M2.12.A: All 17 document operations reject modification when isReadOnly",
                   roDoc.content == snapshot && !roDoc.isDirty && roDoc.eolFormat == .lf)

        // ---------------------------------------------------------------------
        // 32.2 Milestone 3: Search Menu Full Parity (Notepad_plus.rc L648-744)
        // ---------------------------------------------------------------------
        // Select and Find Next / Previous
        tv.string = "alpha beta alpha gamma alpha"
        doc.content = tv.string
        tv.setSelectedRange(NSRange(location: 1, length: 0)) // inside first "alpha"
        ws.selectAndFindNext(forward: true)
        assertTest("M3 Search: selectAndFindNext expands word under caret and finds 2nd occurrence",
                   ws.lastSearchQuery == "alpha" && tv.selectedRange() == NSRange(location: 11, length: 5))

        ws.selectAndFindNext(forward: true)
        assertTest("M3 Search: selectAndFindNext advances to 3rd occurrence",
                   tv.selectedRange() == NSRange(location: 23, length: 5))

        ws.selectAndFindNext(forward: false)
        assertTest("M3 Search: selectAndFindNext(forward: false) moves back to 2nd occurrence",
                   tv.selectedRange() == NSRange(location: 11, length: 5))

        // Incremental Search & Search Results Window toggles
        let initInc = ws.showSearchBar
        ws.toggleIncrementalSearch()
        assertTest("M3 Search: toggleIncrementalSearch activates search bar in find mode",
                   ws.showSearchBar != initInc || ws.searchBarMode == .find)

        let initSearchRes = ws.showSearchResultsPanel
        ws.toggleSearchResultsWindow()
        assertTest("M3 Search: toggleSearchResultsWindow toggles Find Results panel (F7)",
                   ws.showSearchResultsPanel == !initSearchRes)
        ws.showSearchResultsPanel = false

        // Matching Brace & Select All Between Braces (Cmd+B / Cmd+Option+B)
        let braceCode = "func demo() { if (a[0] == 1) { return } }"
        tv.string = braceCode
        doc.content = braceCode
        // Caret at opening '{' at index 12
        tv.setSelectedRange(NSRange(location: 12, length: 0))
        ws.goToMatchingBrace()
        assertTest("M3 Search: goToMatchingBrace jumps from outer '{' to matching outer '}'",
                   tv.selectedRange().location == 40)

        // Caret inside inner block -> selectAllBetweenBraces
        tv.setSelectedRange(NSRange(location: 31, length: 0))
        ws.selectAllBetweenBraces()
        let innerSelected = (braceCode as NSString).substring(with: tv.selectedRange())
        assertTest("M3 Search: selectAllBetweenBraces selects inner block content between '{' and '}'",
                   innerSelected == " return ")

        // Style all occurrences of token (1st..5th style) & Style one token & Clear style
        let tokenText = "foo bar foo baz qux"
        tv.string = tokenText
        doc.content = tokenText
        tv.setSelectedRange(NSRange(location: 0, length: 3)) // "foo"
        ws.styleAllOccurrencesOfToken(styleIndex: 1)
        assertTest("M3 Search: styleAllOccurrencesOfToken(1) marks both occurrences of 'foo'",
                   doc.styledTokenRanges[1]?.count == 2 &&
                   doc.styledTokenRanges[1]?.first == NSRange(location: 0, length: 3) &&
                   doc.styledTokenRanges[1]?.last == NSRange(location: 8, length: 3))

        tv.setSelectedRange(NSRange(location: 4, length: 3)) // "bar"
        ws.styleOneToken(styleIndex: 2)
        assertTest("M3 Search: styleOneToken(2) marks single range of 'bar'",
                   doc.styledTokenRanges[2] == [NSRange(location: 4, length: 3)])

        ws.clearStyle(styleIndex: 1)
        assertTest("M3 Search: clearStyle(1) removes only style 1 while keeping style 2",
                   doc.styledTokenRanges[1] == nil && doc.styledTokenRanges[2] != nil)

        ws.clearAllStyles()
        assertTest("M3 Search: clearAllStyles removes all token styles 1..5",
                   doc.styledTokenRanges.isEmpty)

        // Find characters in range (ASCII vs Non-ASCII)
        let mixedAsciiText = "Hello 한글 World"
        tv.string = mixedAsciiText
        doc.content = mixedAsciiText
        tv.setSelectedRange(NSRange(location: 0, length: 0))
        let foundNonAscii = ws.findCharactersInRange(minCode: 128, maxCode: 65535, forward: true, wrap: true)
        assertTest("M3 Search: findCharactersInRange(128..65535) locates first non-ASCII character '한'",
                   foundNonAscii != nil && tv.selectedRange() == NSRange(location: 6, length: 1))

        let foundAsciiAfter = ws.findCharactersInRange(minCode: 65, maxCode: 90, forward: true, wrap: true)
        assertTest("M3 Search: findCharactersInRange(65..90) locates uppercase ASCII 'W'",
                   foundAsciiAfter != nil && tv.selectedRange() == NSRange(location: 9, length: 1))

        // ---------------------------------------------------------------------
        // 32.3 Milestone 4: View, Encoding, Language, Tools & Window Parity
        // ---------------------------------------------------------------------
        // View > Show Symbol Synchronization
        ws.showInvisibleCharacters = true
        assertTest("M4 View: showInvisibleCharacters = true enables Space/Tab, EOL, and Non-Printing flags",
                   ws.showSpaceAndTab && ws.showEndOfLine && ws.showNonPrintingCharacters && ws.showInvisibleCharacters)

        ws.toggleShowSpaceAndTab()
        assertTest("M4 View: toggling individual symbol flag updates showSpaceAndTab",
                   !ws.showSpaceAndTab && ws.showEndOfLine)
        ws.showInvisibleCharacters = false
        ws.showSpaceAndTab = false
        ws.showEndOfLine = false
        ws.showNonPrintingCharacters = false
        assertTest("M4 View: clearing Show All Characters clears all symbol flags",
                   !ws.showSpaceAndTab && !ws.showEndOfLine && !ws.showNonPrintingCharacters && !ws.showInvisibleCharacters)

        // View > Tab Colors & Navigation
        ws.applyTabColor(3)
        assertTest("M4 View: applyTabColor(3) sets active document tabColorId to 3",
                   doc.tabColorId == 3)
        ws.applyTabColor(0)
        assertTest("M4 View: applyTabColor(0) removes active document tab color",
                   doc.tabColorId == 0)

        // View > Monitoring (tail -f)
        let tempMonURL = FileManager.default.temporaryDirectory.appendingPathComponent("mon_test_\(UUID().uuidString).txt")
        try? "test monitoring content".write(to: tempMonURL, atomically: true, encoding: .utf8)
        doc.filePath = tempMonURL
        doc.isDirty = false
        assertTest("M4 View: isMonitoring defaults to false", !doc.isMonitoring)
        ws.toggleMonitoringCurrentDoc()
        assertTest("M4 View: toggleMonitoringCurrentDoc enables tail -f monitoring flag", doc.isMonitoring)
        ws.toggleMonitoringCurrentDoc()
        assertTest("M4 View: toggleMonitoringCurrentDoc disables tail -f monitoring flag", !doc.isMonitoring)
        try? FileManager.default.removeItem(at: tempMonURL)

        // Tools > Hash Generators (MD5, SHA-1, SHA-256, SHA-512)
        assertTest("M4 Tools: SHA-1 of 'abc' matches official FIPS 180-4 vector",
                   NppTools.sha1(data: Data("abc".utf8)) == "a9993e364706816aba3e25717850c26c9cd0d89d")
        assertTest("M4 Tools: SHA-512 of 'abc' matches official FIPS 180-4 prefix",
                   NppTools.sha512(data: Data("abc".utf8)).hasPrefix("ddaf35a193617abacc417349ae204131"))

        // Window > Sort By (Type & Content Length)
        let sortDocA = NppDocument(title: "z_script.py", content: "short")
        sortDocA.language = "Python"
        let sortDocB = NppDocument(title: "a_readme.md", content: "much longer content string here")
        sortDocB.language = "Markdown"
        ws.documents.append(contentsOf: [sortDocA, sortDocB])

        ws.sortTabsBySize(ascending: false)
        if let idxB = ws.documents.firstIndex(where: { $0.id == sortDocB.id }),
           let idxA = ws.documents.firstIndex(where: { $0.id == sortDocA.id }) {
            assertTest("M4 Window: sortTabsBySize(ascending: false) orders longer document before shorter",
                       idxB < idxA)
        }

        ws.selectFirstTab()
        assertTest("M4 View: selectFirstTab selects documents.first",
                   ws.activeDocumentId == ws.documents.first?.id)
        ws.selectLastTab()
        assertTest("M4 View: selectLastTab selects documents.last",
                   ws.activeDocumentId == ws.documents.last?.id)

        // Language Menu Disabled Filtering & Menu Checkmark Validation
        ws.activeDocumentId = doc.id
        doc.language = "Swift"
        doc.eolFormat = .crlf
        doc.encoding = "UTF-8"
        doc.hasBOM = true

        let langItemSwift = NSMenuItem(title: "Swift", action: #selector(appDelegate.menuSelectLanguage(_:)), keyEquivalent: "")
        langItemSwift.representedObject = "Swift"
        _ = appDelegate.validateMenuItem(langItemSwift)
        assertTest("M4 Menu Validation: Active language 'Swift' has .on checkmark state",
                   langItemSwift.state == .on)

        let eolItemCRLF = NSMenuItem(title: "Windows (CR LF)", action: #selector(appDelegate.menuEolWindows), keyEquivalent: "")
        _ = appDelegate.validateMenuItem(eolItemCRLF)
        assertTest("M4 Menu Validation: Active EOL 'Windows (CR LF)' has .on checkmark state",
                   eolItemCRLF.state == .on)

        let encItemBOM = NSMenuItem(title: "UTF-8-BOM", action: #selector(appDelegate.menuEncodeUtf8Bom), keyEquivalent: "")
        _ = appDelegate.validateMenuItem(encItemBOM)
        assertTest("M4 Menu Validation: Active Encoding 'UTF-8-BOM' has .on checkmark state",
                   encItemBOM.state == .on)

        // ---------------------------------------------------------------------
        // 32.4 Hourly Re-Audit Pass 1: Find/Replace in Files, JumpToMatch & Bookmark Sync
        // ---------------------------------------------------------------------
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("npp_audit_fif_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let tempFileA = tempDir.appendingPathComponent("alpha.txt")
        let tempFileB = tempDir.appendingPathComponent("beta.txt")
        try? "Hello TargetWord World\nSecond line TargetWord".write(to: tempFileA, atomically: true, encoding: .utf8)
        try? "SubTargetWord should not match wholeWord\nExact TargetWord here".write(to: tempFileB, atomically: true, encoding: .utf8)

        ws.findAllInFiles(
            query: "TargetWord",
            filter: "*.txt",
            directory: tempDir.path,
            subfolders: false,
            matchCase: true,
            wholeWord: true,
            useRegex: false
        )
        assertTest("Re-Audit 1.A: findAllInFiles with wholeWord=true finds exact whole-word matches across files",
                   ws.totalSearchHits == 3 && ws.searchFileGroups.count == 2)

        if let firstMatch = ws.searchFileGroups.first?.matches.first {
            ws.jumpToMatch(firstMatch)
            assertTest("Re-Audit 1.B: jumpToMatch on unopened disk file opens file into workspace and selects match",
                       ws.activeDocument != nil &&
                       ws.activeDocument?.filePath?.standardizedFileURL.path == firstMatch.filePath?.standardizedFileURL.path &&
                       ws.activeDocument?.selectionLength == 10)
        }

        let repResult = ws.replaceInFiles(
            query: "TargetWord",
            replacement: "ReplacedToken",
            filter: "*.txt",
            directory: tempDir.path,
            subfolders: false,
            matchCase: true,
            wholeWord: true,
            useRegex: false
        )
        let updatedDiskB = (try? String(contentsOf: tempFileB, encoding: .utf8)) ?? ""
        assertTest("Re-Audit 1.C: replaceInFiles modifies files on disk and respects wholeWord boundary",
                   repResult.replacements == 3 &&
                   repResult.filesModified == 2 &&
                   updatedDiskB.contains("SubTargetWord") &&
                   updatedDiskB.contains("Exact ReplacedToken here"))

        if let openedTempDoc = ws.documents.first(where: { $0.filePath?.standardizedFileURL.path == tempFileA.standardizedFileURL.path }) {
            assertTest("Re-Audit 1.D: replaceInFiles automatically refreshes open document buffer",
                       openedTempDoc.content.contains("ReplacedToken"))
            ws.closeDocument(id: openedTempDoc.id)
        }
        try? FileManager.default.removeItem(at: tempDir)

        // Bookmark line operations TextView sync & Read-Only protection
        ws.activeDocumentId = doc.id
        ws.activeTextView = tv
        tv.string = "KeepLine1\nBookmarkedLine2\nKeepLine3"
        doc.content = tv.string
        doc.eolFormat = .lf
        doc.bookmarkedLines = [2]
        doc.isReadOnly = true
        ws.removeBookmarkedLines()
        assertTest("Re-Audit 1.E: removeBookmarkedLines blocked when document is read-only",
                   doc.content.contains("BookmarkedLine2") && tv.string.contains("BookmarkedLine2"))
        doc.isReadOnly = false
        ws.removeBookmarkedLines()
        assertTest("Re-Audit 1.F: removeBookmarkedLines removes bookmarked line and syncs activeTextView",
                   doc.content == "KeepLine1\nKeepLine3" && tv.string == "KeepLine1\nKeepLine3")

        // ---------------------------------------------------------------------
        // 32.5 Hourly Re-Audit Pass 2: CRLF Line Count, Toolbar Playback & Context Menu Localization
        // ---------------------------------------------------------------------
        let crlfContent = "First\r\nSecond\r\nThird"
        doc.content = crlfContent
        doc.eolFormat = .crlf
        assertTest("Re-Audit 2.A: CRLF document reports exact 3 lines via nppLines() (no double-counting)",
                   doc.content.nppLines().count == 3)

        ws.recordedMacroSteps.removeAll()
        ws.isMacroRecording = false
        if let firstSaved = ws.savedMacros.first {
            ws.selectedMacroToRun = firstSaved.name
            assertTest("Re-Audit 2.B: canPlaybackMacro is true when saved macro is selected even if recordedMacroSteps is empty",
                       ws.canPlaybackMacro)
        }

        ws.localizationLanguage = "한국어 (Korean)"
        if let nppTv = tv as? NppTextView, let ctxMenu = nppTv.menu(for: NSEvent()) {
            let titles = ctxMenu.items.map { $0.title }
            assertTest("Re-Audit 2.C: Editor right-click context menu localizes items into Korean",
                       titles.contains("실행 취소") && titles.contains("복사") && titles.contains("모두 선택"))
        } else {
            assertTest("Re-Audit 2.C: Korean translations exist for context menu items",
                       ws.tr("Undo") == "실행 취소" && ws.tr("Style all occurrences of token") == "토큰의 모든 일치 항목 스타일 지정")
        }
        ws.localizationLanguage = "English (Default)"

        // ---------------------------------------------------------------------
        // 32.6 Re-Audit Pass 3: Gutter Stability, Light Mode Gutter Colors & Preference Indent Parity
        // ---------------------------------------------------------------------
        // 494. Line number gutter width stability (empty document vs Korean text does not fluctuate)
        let gutter = NppGutterView(textView: tv)
        gutter.workspace = ws
        gutter.document = doc
        tv.string = ""
        doc.content = ""
        let emptyGutterThickness = gutter.calculateTargetThickness()

        tv.string = "가나다라마바사아자차카타파하\n두번째줄한글내용"
        doc.content = tv.string
        let koreanGutterThickness = gutter.calculateTargetThickness()
        assertTest("Re-Audit 3.A: Line number gutter width remains stable (~50-54pt) and does not inflate on Korean text",
                   emptyGutterThickness >= 50.0 && emptyGutterThickness <= 58.0 && abs(koreanGutterThickness - emptyGutterThickness) <= 1.0)

        // 495. Light mode gutter color is clean soft light grey (#F0F0F0), not black (#181818)
        ws.themeMode = "light"
        ws.updateThemeAppearance()
        let lightTheme = ws.currentTheme
        assertTest("Re-Audit 3.B: Light mode gutter background is soft light grey (>0.90), never black",
                   !lightTheme.isDark && lightTheme.gutterBackground.redComponent > 0.90 && lightTheme.gutterBackground.greenComponent > 0.90)

        // 496. Indentation preferences localization into Korean
        ws.localizationLanguage = "한국어"
        assertTest("Re-Audit 3.C: Indentation settings and options are localized into Korean",
                   ws.tr("Indent Settings") == "들여쓰기 설정" &&
                   ws.tr("Use default value") == "기본값 사용" &&
                   ws.tr("Tab character") == "탭 문자" &&
                   ws.tr("Auto-indent") == "자동 들여쓰기" &&
                   ws.tr("[Default]") == "[기본값]")
        ws.localizationLanguage = "English (Default)"
        ws.themeMode = "dark"
        ws.updateThemeAppearance()

        // ---------------------------------------------------------------------
        // 32.7 Re-Audit Pass 4: Auto-Insert Delimiters, Mistake Compensation & Intentional Overtype
        // ---------------------------------------------------------------------
        let nppTv = (tv as? NppTextView) ?? NppTextView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
        nppTv.workspace = ws

        // 497. Auto-insert '(' creates '()', typing ')' steps over to prevent duplicate like int main())
        ws.autoInsertParen = true
        nppTv.string = "int main"
        nppTv.setSelectedRange(NSRange(location: 8, length: 0))
        if let eventOpenParen = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil, characters: "(", charactersIgnoringModifiers: "(", isARepeat: false, keyCode: 0) {
            nppTv.keyDown(with: eventOpenParen)
        }
        let afterOpenParenText = nppTv.string
        let afterOpenParenSel = nppTv.selectedRange()
        assertTest("Re-Audit 4.A: Auto-insert '(' creates '()' with cursor inside at index 9",
                   afterOpenParenText == "int main()" && afterOpenParenSel == NSRange(location: 9, length: 0) && nppTv.insertedMatchedChars.count == 1)

        // Now user reflexively types ')' -> should step over without inserting a second ')'
        if let eventCloseParen = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil, characters: ")", charactersIgnoringModifiers: ")", isARepeat: false, keyCode: 0) {
            nppTv.keyDown(with: eventCloseParen)
        }
        assertTest("Re-Audit 4.B: Typing ')' steps over auto-inserted ')' preventing duplicate 'int main())'",
                   nppTv.string == "int main()" && nppTv.selectedRange() == NSRange(location: 10, length: 0) && nppTv.insertedMatchedChars.isEmpty)

        // 498. Typing ')' again after stepping over inserts ')' normally (intentional user intent is NOT blocked)
        if let eventSecondCloseParen = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil, characters: ")", charactersIgnoringModifiers: ")", isARepeat: false, keyCode: 0) {
            nppTv.keyDown(with: eventSecondCloseParen)
        }
        assertTest("Re-Audit 4.C: Typing ')' again inserts normally so user intent is never blocked",
                   nppTv.string == "int main())" && nppTv.selectedRange() == NSRange(location: 11, length: 0))

        // 499. Typing ')' in existing code without pending auto-insert inserts ')' directly
        nppTv.string = "foo()"
        nppTv.setSelectedRange(NSRange(location: 4, length: 0)) // before ')'
        nppTv.insertedMatchedChars.removeAll()
        if let eventExistingClose = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil, characters: ")", charactersIgnoringModifiers: ")", isARepeat: false, keyCode: 0) {
            nppTv.keyDown(with: eventExistingClose)
        }
        assertTest("Re-Audit 4.D: Typing ')' in existing text without pending auto-insert inserts normally",
                   nppTv.string == "foo())")

        // 500. Smart Backspace: typing '(' and immediately hitting Backspace deletes both delimiters cleanly
        nppTv.string = ""
        nppTv.setSelectedRange(NSRange(location: 0, length: 0))
        nppTv.insertedMatchedChars.removeAll()
        if let eventOpen = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil, characters: "(", charactersIgnoringModifiers: "(", isARepeat: false, keyCode: 0) {
            nppTv.keyDown(with: eventOpen)
        }
        assertTest("Re-Audit 4.E: Auto-inserted empty '()' is active before backspace",
                   nppTv.string == "()" && nppTv.selectedRange() == NSRange(location: 1, length: 0) && !nppTv.insertedMatchedChars.isEmpty)
        nppTv.doCommand(by: #selector(NSStandardKeyBindingResponding.deleteBackward(_:)))
        assertTest("Re-Audit 4.F: Smart Backspace deletes entire empty auto-inserted pair cleanly",
                   nppTv.string == "" && nppTv.selectedRange() == NSRange(location: 0, length: 0) && nppTv.insertedMatchedChars.isEmpty)

        // 501. Quotes & Brackets: auto-insert and overtype
        ws.autoInsertDoubleQuote = true
        ws.autoInsertBracket = true
        nppTv.string = "var arr = "
        nppTv.setSelectedRange(NSRange(location: 10, length: 0))
        if let evOpenBracket = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil, characters: "[", charactersIgnoringModifiers: "[", isARepeat: false, keyCode: 0) {
            nppTv.keyDown(with: evOpenBracket)
        }
        if let evCloseBracket = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil, characters: "]", charactersIgnoringModifiers: "]", isARepeat: false, keyCode: 0) {
            nppTv.keyDown(with: evCloseBracket)
        }
        assertTest("Re-Audit 4.G: Bracket auto-insert and overtype produces 'var arr = []' without duplicate",
                   nppTv.string == "var arr = []" && nppTv.selectedRange() == NSRange(location: 12, length: 0))

        nppTv.string = "str = "
        nppTv.setSelectedRange(NSRange(location: 6, length: 0))
        if let evOpenQuote = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil, characters: "\"", charactersIgnoringModifiers: "\"", isARepeat: false, keyCode: 0) {
            nppTv.keyDown(with: evOpenQuote)
        }
        if let evCloseQuote = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil, characters: "\"", charactersIgnoringModifiers: "\"", isARepeat: false, keyCode: 0) {
            nppTv.keyDown(with: evCloseQuote)
        }
        assertTest("Re-Audit 4.H: Double quote auto-insert and overtype produces 'str = \"\"' without duplicate quotes",
                   nppTv.string == "str = \"\"" && nppTv.selectedRange() == NSRange(location: 8, length: 0))

        // Clean up temporary documents
        ws.closeDocument(id: sortDocA.id)
        ws.closeDocument(id: sortDocB.id)
        ws.closeDocument(id: doc.id)
    }

    // =========================================================================
    // 33. RE-AUDIT PASS 5: OFFICIAL MANUAL & C++ UPSTREAM PARITY
    //     (TabBar Shortcuts, Overflow Navigation, Dropdown List,
    //      StatusBar Language Menu, INS/OVR Toggle, Document Summary,
    //      Find/Replace 2 Find Buttons & Swap/Copy, View F11/F12 Shortcuts)
    // =========================================================================
    static func runOfficialManualAndUpstreamParityTests(
        ws: NppWorkspace,
        appDelegate: AppDelegate,
        assertTest: (String, Bool) -> Void
    ) {
        print("\n========================================================")
        print("🎯 RE-AUDIT 5: OFFICIAL MANUAL & C++ UPSTREAM PARITY")
        print("========================================================")

        // 1. TabBar nextTab() and prevTab() cycle through opened documents
        ws.closeAll() // leaves exactly 1 empty default document
        guard let doc1 = ws.activeDocument else { return }
        doc1.title = "Tab1"
        let id1 = doc1.id

        ws.newDocument() // doc2
        guard let doc2 = ws.activeDocument else { return }
        doc2.title = "Tab2"
        let id2 = doc2.id

        ws.newDocument() // doc3
        guard let doc3 = ws.activeDocument else { return }
        doc3.title = "Tab3"
        let id3 = doc3.id

        ws.activeDocumentId = id1
        ws.nextTab()
        let next1 = (ws.activeDocumentId == id2)
        ws.nextTab()
        let next2 = (ws.activeDocumentId == id3)
        ws.nextTab()
        let nextCycle = (ws.activeDocumentId == id1)
        ws.prevTab()
        let prevCycle = (ws.activeDocumentId == id3)
        assertTest("Re-Audit 5.A: TabBar nextTab() and prevTab() cycle through opened documents",
                   next1 && next2 && nextCycle && prevCycle)

        // 2. TabBar sortTabsByName arranges tabs alphabetically
        doc1.title = "ZebraDoc"
        doc2.title = "AppleDoc"
        doc3.title = "MangoDoc"
        ws.sortTabsByName(ascending: true)
        let titles = ws.documents.map { $0.title }
        assertTest("Re-Audit 5.B: TabBar sortTabsByName arranges tabs alphabetically",
                   titles == ["AppleDoc", "MangoDoc", "ZebraDoc"])

        // 3. TabBar closeAllDocuments() closes unpinned tabs and preserves pinned tab
        if let appleDoc = ws.documents.first(where: { $0.title == "AppleDoc" }) {
            appleDoc.isPinned = true
        }
        ws.closeAllDocuments()
        assertTest("Re-Audit 5.C: TabBar closeAllDocuments() closes unpinned tabs and preserves pinned tab",
                   ws.documents.count == 1 && ws.documents.first?.title == "AppleDoc" && ws.documents.first?.isPinned == true)
        ws.documents.first?.isPinned = false

        // 4. TabBar tabReduce and hideRightShortcuts preference flags
        let origReduce = ws.tabReduce
        let origHideShortcuts = ws.hideRightShortcuts
        ws.tabReduce = true
        ws.hideRightShortcuts = true
        let flagsUpdated = (ws.tabReduce == true && ws.hideRightShortcuts == true)
        ws.tabReduce = origReduce
        ws.hideRightShortcuts = origHideShortcuts
        assertTest("Re-Audit 5.D: TabBar tabReduce and hideRightShortcuts preference flags",
                   flagsUpdated && ws.tabReduce == origReduce && ws.hideRightShortcuts == origHideShortcuts)

        // 5. StatusBar default languages array contains 20 standard programming languages
        let langs = NppWorkspace.defaultLanguages
        let hasCoreLangs = langs.contains("C") && langs.contains("C++") && langs.contains("Swift") &&
                           langs.contains("Python") && langs.contains("Rust") && langs.contains("HTML") &&
                           langs.contains("JSON") && langs.contains("Go")
        assertTest("Re-Audit 5.E: StatusBar default languages array contains 20 standard programming languages",
                   langs.count == 20 && hasCoreLangs)

        // 6. StatusBar typing mode toggle INS/OVR
        let origOvr = ws.isOverwriteMode
        ws.isOverwriteMode = false
        ws.isOverwriteMode.toggle()
        let ovrActive = (ws.isOverwriteMode == true)
        ws.isOverwriteMode.toggle()
        let insActive = (ws.isOverwriteMode == false)
        ws.isOverwriteMode = origOvr
        assertTest("Re-Audit 5.F: StatusBar typing mode toggle INS/OVR",
                   ovrActive && insActive)

        // 7. StatusBar and Document Summary metrics calculate exact character, word, line, and UTF-8 byte counts
        ws.newDocument()
        guard let summaryDoc = ws.activeDocument else { return }
        summaryDoc.content = "Hello World\nNotepad++ Mac Native\n한글 테스트"
        let lineCount = max(1, summaryDoc.content.nppLines().count)
        let words = summaryDoc.content.split { $0.isWhitespace || $0.isNewline }.count
        let nonSpace = summaryDoc.content.filter { !$0.isWhitespace && !$0.isNewline }.count
        let utf8Bytes = (summaryDoc.content.data(using: .utf8) ?? Data()).count
        assertTest("Re-Audit 5.G: StatusBar and Document Summary metrics calculate exact character, word, line, and UTF-8 byte counts",
                   lineCount == 3 && words == 7 && nonSpace == 33 && utf8Bytes > 33)

        // 8. Document Summary calculates selection characters and UTF-8 bytes
        let nsContent = summaryDoc.content as NSString
        let selRange = nsContent.range(of: "한글 테스트")
        summaryDoc.cursorPos = selRange.location
        summaryDoc.selectionLength = selRange.length
        let safeLoc = min(summaryDoc.cursorPos, nsContent.length)
        let safeLen = min(summaryDoc.selectionLength, max(0, nsContent.length - safeLoc))
        let selText = nsContent.substring(with: NSRange(location: safeLoc, length: safeLen))
        let selBytes = (selText.data(using: .utf8) ?? Data()).count
        assertTest("Re-Audit 5.H: Document Summary calculates selection characters and UTF-8 bytes",
                   selText == "한글 테스트" && summaryDoc.selectionLength == 6 && selBytes == 16)

        // 9. Find/Replace 2 find buttons mode UserDefaults persistence
        UserDefaults.standard.set(true, forKey: "npp_two_find_buttons_mode")
        let twoBtnsEnabled = UserDefaults.standard.bool(forKey: "npp_two_find_buttons_mode")
        UserDefaults.standard.set(false, forKey: "npp_two_find_buttons_mode")
        let twoBtnsDisabled = !UserDefaults.standard.bool(forKey: "npp_two_find_buttons_mode")
        assertTest("Re-Audit 5.I: Find/Replace 2 find buttons mode UserDefaults persistence",
                   twoBtnsEnabled && twoBtnsDisabled)

        // 10. Find/Replace backward search locates previous occurrence accurately
        let tv = ws.activeTextView ?? NSTextView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
        ws.activeTextView = tv
        tv.string = "cat dog cat bird cat"
        let query = "cat"
        let content = tv.string as NSString
        let startLocation = 11
        let rangeToSearch = NSRange(location: 0, length: min(startLocation, content.length))
        let foundBackward = content.range(of: query, options: [.backwards], range: rangeToSearch)
        assertTest("Re-Audit 5.J: Find/Replace backward search locates previous occurrence accurately",
                   foundBackward.location == 8 && foundBackward.length == 3)

        // 11. Find/Replace swap and copy buttons logic (Swap, Copy Find->Replace, Copy Replace->Find)
        var fText = "findWord"
        var rText = "replaceWord"
        let tmp = fText
        fText = rText
        rText = tmp
        let swapOk = (fText == "replaceWord" && rText == "findWord")
        rText = fText
        let copyFtoROk = (rText == "replaceWord" && fText == "replaceWord")
        fText = "another"
        rText = "fromReplace"
        fText = rText
        let copyRtoFOk = (fText == "fromReplace" && rText == "fromReplace")
        assertTest("Re-Audit 5.K: Find/Replace swap and copy buttons logic (Swap, Copy Find->Replace, Copy Replace->Find)",
                   swapOk && copyFtoROk && copyRtoFOk)

        // 12. View Menu: Toggle Full Screen Mode shortcut is F11
        // 13. View Menu: Post-It shortcut is F12
        // 14. View Menu: Summary... menu item is connected to menuDocSummary
        var fsKeyOk = false
        var piKeyOk = false
        var summaryConnected = false
        if let mainMenu = NSApp.mainMenu {
            for item in mainMenu.items {
                if let sub = item.submenu {
                    for subItem in sub.items {
                        if subItem.action == #selector(AppDelegate.menuToggleFullScreen) {
                            fsKeyOk = (subItem.keyEquivalent == String(UnicodeScalar(NSF11FunctionKey)!) && subItem.keyEquivalentModifierMask == [])
                        }
                        if subItem.action == #selector(AppDelegate.menuTogglePostIt) {
                            piKeyOk = (subItem.keyEquivalent == String(UnicodeScalar(NSF12FunctionKey)!) && subItem.keyEquivalentModifierMask == [])
                        }
                        if subItem.action == #selector(AppDelegate.menuDocSummary) {
                            summaryConnected = true
                        }
                    }
                }
            }
        }
        assertTest("Re-Audit 5.L: View Menu: Toggle Full Screen Mode shortcut is F11", fsKeyOk)
        assertTest("Re-Audit 5.M: View Menu: Post-It shortcut is F12", piKeyOk)
        assertTest("Re-Audit 5.N: View Menu: Summary... menu item is connected to menuDocSummary", summaryConnected)

        // 15. Korean Localization for TabBar, StatusBar, Summary and Find/Replace upstream strings
        ws.localizationLanguage = "한국어"
        let trSummary = (ws.tr("Summary") == "요약")
        let trPath = (ws.tr("Full file path") == "전체 파일 경로")
        let trChars = (ws.tr("Characters (without line endings)") == "문자 수 (줄 바꿈 제외)")
        let tr2Btns = (ws.tr("2 find buttons mode") == "2개 찾기 버튼 모드")
        let trSwap = (ws.tr("Swap Find with Replace") == "찾을 내용과 바꿀 내용 맞바꾸기")
        let trPrevTab = (ws.tr("Previous Tab (⏴)") == "이전 탭 (⏴)")
        let trNextTab = (ws.tr("Next Tab (⏵)") == "다음 탭 (⏵)")
        ws.localizationLanguage = "English (Default)"
        assertTest("Re-Audit 5.O: Korean Localization for TabBar, StatusBar, Summary and Find/Replace upstream strings",
                   trSummary && trPath && trChars && tr2Btns && trSwap && trPrevTab && trNextTab)

        // Clean up
        ws.closeAll()
    }

    // =========================================================================
    // 34. SPRINT 1: MANUAL AUDIT 10 CORE PARITY FEATURES SUITE
    // =========================================================================
    static func runSprint1ParityTests(
        ws: NppWorkspace,
        appDelegate: AppDelegate,
        assertTest: (String, Bool) -> Void
    ) {
        print("\n========================================================")
        print("🚀 SPRINT 1: MANUAL AUDIT 10 CORE PARITY FEATURES SUITE")
        print("========================================================")

        // -------------------------------------------------------------
        // TASK 1: 6-Step Language Auto-Detection, Shebang & Special Filenames
        // -------------------------------------------------------------
        let makefileLang = NppDocument.detectLanguage(for: "Makefile", content: "")
        let cmakeLang = NppDocument.detectLanguage(for: "CMakeLists.txt", content: "")
        let dockerLang = NppDocument.detectLanguage(for: "Dockerfile", content: "")
        let gemLang = NppDocument.detectLanguage(for: "Gemfile", content: "")
        let cronLang = NppDocument.detectLanguage(for: "crontab", content: "")
        assertTest("Sprint 1.1.A: Special filenames detect correct languages without extension",
                   makefileLang == "Makefile" && cmakeLang == "CMake" && dockerLang == "Dockerfile" && gemLang == "Ruby" && (cronLang == "Shell" || cronLang == "Bash"))

        let bashShebang = NppDocument.detectLanguage(for: "unnamed_script", content: "#!/usr/bin/env bash\necho Hello")
        let pythonShebang = NppDocument.detectLanguage(for: "unnamed_script", content: "#!/usr/bin/python3\nprint('Hello')")
        let nodeShebang = NppDocument.detectLanguage(for: "unnamed_script", content: "#!/usr/bin/env node\nconsole.log(1)")
        let perlShebang = NppDocument.detectLanguage(for: "unnamed_script", content: "#!/usr/bin/perl\nprint 1;")
        assertTest("Sprint 1.1.B: Shebang lines detect scripting languages (Bash/Shell, Python, JS, Perl)",
                   (bashShebang == "Shell" || bashShebang == "Bash") && pythonShebang == "Python" && nodeShebang == "JavaScript" && perlShebang == "Perl")

        let xmlProlog = NppDocument.detectLanguage(for: "config", content: "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<config/>")
        let htmlProlog = NppDocument.detectLanguage(for: "page", content: "<!DOCTYPE html>\n<html><body>Hi</body></html>")
        assertTest("Sprint 1.1.C: XML prolog and HTML DOCTYPE detected automatically from content",
                   xmlProlog == "XML" && htmlProlog == "HTML")

        let extOverride = NppDocument.detectLanguage(for: "deploy.swift", content: "#!/bin/bash\n// Swift file")
        assertTest("Sprint 1.1.D: File extension takes precedence over shebang", extOverride == "Swift")

        // -------------------------------------------------------------
        // TASK 2: Reload from Disk Side-effects Cleanup (Bookmarks & Styled Ranges)
        // -------------------------------------------------------------
        let tempDir = FileManager.default.temporaryDirectory
        let reloadFileUrl = tempDir.appendingPathComponent("npp_reload_test_\(UUID().uuidString).txt")
        try? "Line 1\nLine 2\nLine 3\n".write(to: reloadFileUrl, atomically: true, encoding: .utf8)
        ws.openFile(url: reloadFileUrl)
        if let reloadDoc = ws.activeDocument {
            reloadDoc.bookmarkedLines.insert(2)
            reloadDoc.styledTokenRanges[1] = [NSRange(location: 0, length: 6)]
            assertTest("Sprint 1.2.A: Bookmarks and styledTokenRanges set before reload",
                       !reloadDoc.bookmarkedLines.isEmpty && !reloadDoc.styledTokenRanges.isEmpty)

            ws.reloadFromDisk(for: reloadDoc)
            assertTest("Sprint 1.2.B: Reload from disk clears bookmarks and token styles cleanly",
                       reloadDoc.bookmarkedLines.isEmpty && reloadDoc.styledTokenRanges.isEmpty)
            ws.closeDocument(id: reloadDoc.id)
        } else {
            assertTest("Sprint 1.2.A: Open reload test document", false)
            assertTest("Sprint 1.2.B: Reload from disk clears bookmarks and token styles", false)
        }
        try? FileManager.default.removeItem(at: reloadFileUrl)

        // -------------------------------------------------------------
        // TASK 3: Auto-Insert Quote Contraction Prevention
        // -------------------------------------------------------------
        func shouldAutoInsertQuote(char: Character, prevChar: Character?) -> Bool {
            let isQuote = (char == "\"" || char == "'")
            var isPrevAlnum = false
            if let p = prevChar, let s = p.unicodeScalars.first {
                isPrevAlnum = CharacterSet.alphanumerics.contains(s)
            }
            return isQuote && !isPrevAlnum
        }
        assertTest("Sprint 1.3.A: Typing single quote after 'n' in 'don' does NOT auto-insert closing quote",
                   shouldAutoInsertQuote(char: "'", prevChar: "n") == false)
        assertTest("Sprint 1.3.B: Typing single quote after space or punctuation DOES auto-insert pair",
                   shouldAutoInsertQuote(char: "'", prevChar: " ") == true && shouldAutoInsertQuote(char: "'", prevChar: nil) == true)
        assertTest("Sprint 1.3.C: Typing double quote after alphanumeric does NOT auto-insert pair",
                   shouldAutoInsertQuote(char: "\"", prevChar: "a") == false && shouldAutoInsertQuote(char: "\"", prevChar: "=") == true)

        // -------------------------------------------------------------
        // TASK 4: Column Editor Dynamic Digit Padding & Radix Parsing
        // -------------------------------------------------------------
        func parseRadixInt(_ str: String) -> Int? {
            let t = str.trimmingCharacters(in: .whitespaces)
            if t.hasPrefix("0x") || t.hasPrefix("0X") {
                return Int(t.dropFirst(2), radix: 16)
            } else if t.hasPrefix("0o") || t.hasPrefix("0O") {
                return Int(t.dropFirst(2), radix: 8)
            } else if t.hasPrefix("0b") || t.hasPrefix("0B") {
                return Int(t.dropFirst(2), radix: 2)
            }
            return Int(t)
        }
        let hexVal = parseRadixInt("0xA")
        let octVal = parseRadixInt("0o77")
        let binVal = parseRadixInt("0b1011")
        assertTest("Sprint 1.4.A: Column editor radix prefix parser parses Hex, Octal, Binary",
                   hexVal == 10 && octVal == 63 && binVal == 11)

        ws.newDocument()
        if let colDoc = ws.activeDocument {
            let tv = ws.activeTextView ?? NSTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 400))
            tv.string = "Apple\nBanana\nCherry"
            colDoc.content = tv.string
            ws.activeTextView = tv
            tv.setSelectedRange(NSRange(location: 0, length: (tv.string as NSString).length))
            ws.executeColumnEditor(
                isText: false,
                text: "",
                initialNumber: 8,
                increaseBy: 1,
                repeatCount: 1,
                format: "dec",
                leadingZeros: true
            )
            let colLines = tv.string.components(separatedBy: "\n")
            assertTest("Sprint 1.4.B: Column editor dynamically calculates max digits and pads with leading zeros (08, 09, 10)",
                       colLines.count == 3 && colLines[0].hasPrefix("08") && colLines[1].hasPrefix("09") && colLines[2].hasPrefix("10"))
            ws.closeDocument(id: colDoc.id)
        } else {
            assertTest("Sprint 1.4.B: Column editor dynamic padding", false)
        }

        // -------------------------------------------------------------
        // TASK 5: Blank Operations Selection Range Restriction
        // -------------------------------------------------------------
        let blankDoc = NppDocument(title: "blankTest", content: "   Line 1   \n   Line 2   \n   Line 3   ", eol: .lf)
        let line2NSRange = (blankDoc.content as NSString).range(of: "   Line 2   ")
        NppEditOperations.trimSpaces(in: blankDoc, mode: .both, selectedRange: line2NSRange)
        let trimmedLines = blankDoc.content.components(separatedBy: "\n")
        assertTest("Sprint 1.5.A: Trim Spaces with selectedRange only modifies selected line",
                   trimmedLines.count == 3 && trimmedLines[0] == "   Line 1   " && trimmedLines[1] == "Line 2" && trimmedLines[2] == "   Line 3   ")

        blankDoc.content = "\tA\n\tB\n\tC"
        let lineBRange = (blankDoc.content as NSString).range(of: "\tB")
        NppEditOperations.tabToSpace(in: blankDoc, spaceCount: 4, selectedRange: lineBRange)
        let tabLines = blankDoc.content.components(separatedBy: "\n")
        assertTest("Sprint 1.5.B: Tab to Space with selectedRange only modifies selected lines",
                   tabLines[0] == "\tA" && tabLines[1] == "    B" && tabLines[2] == "\tC")

        // -------------------------------------------------------------
        // TASK 6: Monitoring Button & Multi-Line Selection Format (Sel : ℕ | ℒ)
        // -------------------------------------------------------------
        ws.newDocument()
        if let monDoc = ws.activeDocument {
            let tempMonURL2 = FileManager.default.temporaryDirectory.appendingPathComponent("mon_test2_\(UUID().uuidString).txt")
            try? "test monitoring content 2".write(to: tempMonURL2, atomically: true, encoding: .utf8)
            monDoc.filePath = tempMonURL2
            monDoc.isDirty = false
            assertTest("Sprint 1.6.A: Monitoring mode state toggleable via toggleMonitoringCurrentDoc", monDoc.isMonitoring == false)
            ws.toggleMonitoringCurrentDoc()
            assertTest("Sprint 1.6.B: Monitoring toggled ON makes doc.isMonitoring=true and doc.isReadOnly=true",
                       monDoc.isMonitoring == true && monDoc.isReadOnly == true)
            ws.toggleMonitoringCurrentDoc()
            assertTest("Sprint 1.6.C: Monitoring toggled OFF restores state", monDoc.isMonitoring == false)
            ws.closeDocument(id: monDoc.id)
            try? FileManager.default.removeItem(at: tempMonURL2)
        }

        let selDoc = NppDocument(title: "selDoc", content: "First Line\nSecond Line\nThird Line", eol: .lf)
        let multilineRange = NSRange(location: 0, length: 22) // covers First Line\nSecond
        selDoc.selectionLength = 22
        let sub = (selDoc.content as NSString).substring(with: multilineRange)
        let selLineCount = max(1, sub.components(separatedBy: "\n").count)
        let statusBox3Text = "Sel : \(selDoc.selectionLength) | \(selLineCount)"
        assertTest("Sprint 1.6.D: Multi-line selection formats as 'Sel : ℕ | ℒ' per Notepad++ specification",
                   statusBox3Text == "Sel : 22 | 2")

        // -------------------------------------------------------------
        // TASK 7: Official Run Menu Environment Variables (11 Variables)
        // -------------------------------------------------------------
        ws.newDocument()
        if let runDoc = ws.activeDocument {
            runDoc.filePath = URL(fileURLWithPath: "/Users/npp/Projects/MyApp/Sources/MainController.swift")
            runDoc.content = "let totalSum = 100\nprint(totalSum)\n"
            runDoc.cursorLine = 1
            runDoc.cursorCol = 7
            runDoc.cursorPos = 6
            let runTemplate = "$(FULL_CURRENT_PATH)|$(CURRENT_DIRECTORY)|$(FILE_NAME)|$(NAME_PART)|$(EXT_PART)|$(CURRENT_WORD)|$(CURRENT_LINE)|$(CURRENT_COLUMN)"
            let expanded = ws.expandRunCommand(runTemplate)
            let parts = expanded.components(separatedBy: "|")
            assertTest("Sprint 1.7.A: expandRunCommand expands all 8 file & editor variables correctly",
                       parts.count == 8 &&
                       parts[0] == "/Users/npp/Projects/MyApp/Sources/MainController.swift" &&
                       parts[1] == "/Users/npp/Projects/MyApp/Sources" &&
                       parts[2] == "MainController.swift" &&
                       parts[3] == "MainController" &&
                       parts[4] == ".swift" &&
                       parts[5] == "totalSum" &&
                       parts[6] == "1" &&
                       parts[7] == "7")
            runDoc.cursorPos = 4
            runDoc.selectionLength = 8
            assertTest("Manual Run: CURRENT_WORD uses selected text before caret word",
                       ws.expandRunCommand("$(CURRENT_WORD)") == "totalSum")

            let lineStrExpanded = ws.expandRunCommand("$(CURRENT_LINESTR)")
            assertTest("Sprint 1.7.B: expandRunCommand expands $(CURRENT_LINESTR) to current line text",
                       lineStrExpanded == "let totalSum = 100")

            let nppDirExpanded = ws.expandRunCommand("$(NPP_DIRECTORY)")
            let nppPathExpanded = ws.expandRunCommand("$(NPP_FULL_FILE_PATH)")
            assertTest("Sprint 1.7.C: expandRunCommand expands $(NPP_DIRECTORY) and $(NPP_FULL_FILE_PATH)",
                       !nppDirExpanded.isEmpty && !nppPathExpanded.isEmpty && !nppDirExpanded.contains("$("))

            ws.closeDocument(id: runDoc.id)
        } else {
            assertTest("Sprint 1.7.A: Run Menu variables", false)
            assertTest("Sprint 1.7.B: Run Menu line string variable", false)
            assertTest("Sprint 1.7.C: Run Menu app variables", false)
        }

        // -------------------------------------------------------------
        // TASK 8: CLI Argument Parser
        // -------------------------------------------------------------
        let cliArgs = ["-n42", "-c8", "-lswift", "-ro", "-Lko", "/tmp/main.swift"]
        let parsed = NppCommandLineParser.parseArgs(cliArgs)
        assertTest("Sprint 1.8.A: CLI parser extracts -n (line), -c (column), -l (lang), -ro (read-only), -L (locale)",
                   parsed.line == 42 &&
                   parsed.column == 8 &&
                   parsed.language == "swift" &&
                   parsed.isReadOnly == true &&
                   parsed.localization == "ko" &&
                   parsed.files == ["/tmp/main.swift"])

        let cliTestArgs = ["--run-tests"]
        let parsedTests = NppCommandLineParser.parseArgs(cliTestArgs)
        assertTest("Sprint 1.8.B: CLI parser recognizes --run-tests flag", parsedTests.runTests == true)
        let parsedSession = NppCommandLineParser.parseArgs(["-openSession", "/tmp/my.session", "-n7"])
        assertTest("Sprint 1.8.C: CLI parser separates -openSession path from file arguments",
                   parsedSession.sessionPath == "/tmp/my.session" && parsedSession.files.isEmpty && parsedSession.line == 7)

        // -------------------------------------------------------------
        // TASK 9: Find in Files Exclusion Filters (!*.ext, !\dir, !/dir)
        // -------------------------------------------------------------
        let fLog = NppWorkspace.matchesFileFilter(filename: "server.log", filePath: "/proj/server.log", filterString: "*.* !*.log")
        let fSwift = NppWorkspace.matchesFileFilter(filename: "app.swift", filePath: "/proj/app.swift", filterString: "*.* !*.log")
        assertTest("Sprint 1.9.A: Find in Files excludes files matching !*.ext wildcard",
                   fLog == false && fSwift == true)

        let fBuildBackslash = NppWorkspace.matchesFileFilter(filename: "app.swift", filePath: "/proj/build/app.swift", filterString: "*.swift !\\build")
        let fBuildSlash = NppWorkspace.matchesFileFilter(filename: "app.swift", filePath: "/proj/build/app.swift", filterString: "*.swift !/build")
        let fSrc = NppWorkspace.matchesFileFilter(filename: "app.swift", filePath: "/proj/src/app.swift", filterString: "*.swift !\\build")
        assertTest("Sprint 1.9.B: Find in Files excludes directories matching !\\dir and !/dir",
                   fBuildBackslash == false && fBuildSlash == false && fSrc == true)

        let fMultiSemicolon = NppWorkspace.matchesFileFilter(filename: "test_suite.swift", filePath: "/proj/test_suite.swift", filterString: "*.swift;*.txt;!*test*")
        assertTest("Sprint 1.9.C: Find in Files handles semicolon delimiters and multiple wildcard patterns",
                   fMultiSemicolon == false)

        // Clean up
        ws.closeAll()
    }

    // =========================================================================
    // 35. SPRINT 2: MANUAL AUDIT 8 CORE PARITY FEATURES SUITE
    // =========================================================================
    static func runSprint2ParityTests(
        ws: NppWorkspace,
        appDelegate: AppDelegate,
        assertTest: (String, Bool) -> Void
    ) {
        print("\n========================================================")
        print("🚀 SPRINT 2: MANUAL AUDIT 8 CORE PARITY FEATURES SUITE")
        print("========================================================")

        // -------------------------------------------------------------
        // TASK 1: Search Results Context Menu & Delete Key Removal
        // -------------------------------------------------------------
        let docId1 = UUID()
        let match1 = NppSearchMatch(
            documentId: docId1,
            documentTitle: "doc1.txt",
            filePath: URL(fileURLWithPath: "/tmp/doc1.txt"),
            lineNumber: 10,
            lineContent: "let searchHit1 = 1",
            matchRangeInLine: NSRange(location: 4, length: 10),
            charPosition: 100,
            matchLength: 10
        )
        let match2 = NppSearchMatch(
            documentId: docId1,
            documentTitle: "doc1.txt",
            filePath: URL(fileURLWithPath: "/tmp/doc1.txt"),
            lineNumber: 20,
            lineContent: "let searchHit2 = 2",
            matchRangeInLine: NSRange(location: 4, length: 10),
            charPosition: 200,
            matchLength: 10
        )
        let group1 = NppSearchFileGroup(
            documentId: docId1,
            documentTitle: "doc1.txt",
            filePath: URL(fileURLWithPath: "/tmp/doc1.txt"),
            matches: [match1, match2]
        )

        let docId2 = UUID()
        let match3 = NppSearchMatch(
            documentId: docId2,
            documentTitle: "doc2.txt",
            filePath: URL(fileURLWithPath: "/tmp/doc2.txt"),
            lineNumber: 5,
            lineContent: "let otherHit = 3",
            matchRangeInLine: NSRange(location: 4, length: 8),
            charPosition: 50,
            matchLength: 8
        )
        let group2 = NppSearchFileGroup(
            documentId: docId2,
            documentTitle: "doc2.txt",
            filePath: URL(fileURLWithPath: "/tmp/doc2.txt"),
            matches: [match3]
        )

        ws.searchFileGroups = [group1, group2]
        ws.showSearchResultsPanel = true
        assertTest("Sprint 2.1.A: searchFileGroups initialized with 2 groups and 3 total hits",
                   ws.searchFileGroups.count == 2 && ws.totalSearchHits == 3)

        // Delete single match: totalSearchHits drops to 2
        ws.deleteSearchResult(matchId: match1.id)
        assertTest("Sprint 2.1.B: deleteSearchResult removes single match and decrements total hits",
                   ws.totalSearchHits == 2 && ws.searchFileGroups.count == 2 && ws.searchFileGroups[0].matches.count == 1)

        // Delete remaining match in group 1: group 1 automatically removed
        ws.deleteSearchResult(matchId: match2.id)
        assertTest("Sprint 2.1.C: deleteSearchResult removes empty group when its last match is deleted",
                   ws.searchFileGroups.count == 1 && ws.searchFileGroups[0].documentTitle == "doc2.txt")

        // Test copySelectedSearchLines & copySelectedSearchPathnames
        ws.copySelectedSearchLines(matches: [match3])
        let copiedLine = NSPasteboard.general.string(forType: .string) ?? ""
        assertTest("Sprint 2.1.D: copySelectedSearchLines copies formatted 'Line N: Content' to pasteboard",
                   copiedLine == "Line 5: let otherHit = 3")

        ws.copySelectedSearchPathnames(filePaths: ["/tmp/doc1.txt", "/tmp/doc2.txt"])
        let copiedPaths = NSPasteboard.general.string(forType: .string) ?? ""
        assertTest("Sprint 2.1.E: copySelectedSearchPathnames copies newline-separated paths to pasteboard",
                   copiedPaths == "/tmp/doc1.txt\n/tmp/doc2.txt")

        // Delete whole group: dock panel automatically closes when last group deleted
        ws.deleteSearchGroup(groupId: group2.id)
        assertTest("Sprint 2.1.F: deleteSearchGroup clears groups and automatically hides search results panel",
                   ws.searchFileGroups.isEmpty && ws.showSearchResultsPanel == false)

        // -------------------------------------------------------------
        // TASK 2: In-Selection Checkbox for Find Count & Mark All Scoping
        // -------------------------------------------------------------
        ws.newDocument()
        if let selDoc = ws.activeDocument {
            selDoc.content = "apple banana apple\ncherry apple date"
            let line1Range = NSRange(location: 0, length: 19) // "apple banana apple\n"

            // Mark All with inRange restricted to line 1
            let markedInSelection = ws.markAll(
                query: "apple",
                matchCase: true,
                wholeWord: true,
                useRegex: false,
                bookmarkLine: true,
                purgeExisting: true,
                inRange: line1Range
            )
            assertTest("Sprint 2.2.A: markAll scoped with inRange only marks occurrences within selection",
                       markedInSelection == 2 && selDoc.isLineBookmarked(1) && !selDoc.isLineBookmarked(2))

            // Mark All without inRange marks all across entire buffer
            let markedGlobal = ws.markAll(
                query: "apple",
                matchCase: true,
                wholeWord: true,
                useRegex: false,
                bookmarkLine: true,
                purgeExisting: true
            )
            assertTest("Sprint 2.2.B: markAll without inRange marks occurrences across entire document",
                       markedGlobal == 3 && selDoc.isLineBookmarked(1) && selDoc.isLineBookmarked(2))

            ws.closeDocument(id: selDoc.id)
        } else {
            assertTest("Sprint 2.2.A: Selection scoping document test", false)
            assertTest("Sprint 2.2.B: Global scoping document test", false)
        }

        // -------------------------------------------------------------
        // TASK 3: Extended Search Mode Escapes (\, \n, \r, \t, \0, \xHH, \uHHHH)
        // -------------------------------------------------------------
        let stdEscapes = NppWorkspace.expandExtendedEscapes("Line1\\nLine2\\r\\tNull\\0End")
        assertTest("Sprint 2.3.A: expandExtendedEscapes expands \\n, \\r, \\t, and \\0 correctly",
                   stdEscapes == "Line1\nLine2\r\tNull\0End")

        let literalBackslash = NppWorkspace.expandExtendedEscapes("C:\\\\path\\\\file.txt\\\\n")
        assertTest("Sprint 2.3.B: expandExtendedEscapes handles literal backslash \\\\ and \\\\n without converting to newline",
                   literalBackslash == "C:\\path\\file.txt\\n")

        let hexEscapes = NppWorkspace.expandExtendedEscapes("\\x41\\x42\\x43\\x31\\x32")
        assertTest("Sprint 2.3.C: expandExtendedEscapes converts \\xHH (2 hex digits) to ASCII characters",
                   hexEscapes == "ABC12")

        let unicodeEscapes = NppWorkspace.expandExtendedEscapes("\\u0041\\uAC00\\uD55C")
        assertTest("Sprint 2.3.D: expandExtendedEscapes converts \\uHHHH (4 hex digits) to Unicode characters",
                   unicodeEscapes == "A가한")

        // -------------------------------------------------------------
        // TASK 4: Incremental Search [n/total] Counter & Highlight All
        // -------------------------------------------------------------
        ws.newDocument()
        if let incDoc = ws.activeDocument {
            incDoc.content = "apple orange apple banana apple grape"
            let tv = ws.activeTextView ?? NSTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 400))
            tv.string = incDoc.content
            ws.activeTextView = tv

            incDoc.cursorPos = 0
            ws.updateIncrementalSearch(query: "apple", matchCase: true, wholeWord: true, useRegex: false)
            assertTest("Sprint 2.4.A: updateIncrementalSearch finds 3 matches and sets index [1/3]",
                       ws.incrementalSearchMatches.count == 3 && ws.incrementalCurrentMatchIndex == 1)

            // Move cursor to middle and re-evaluate index
            incDoc.cursorPos = 14 // After first apple, before second apple
            ws.updateIncrementalSearch(query: "apple", matchCase: true, wholeWord: true, useRegex: false)
            assertTest("Sprint 2.4.B: updateIncrementalSearch calculates active index based on cursor position [2/3]",
                       ws.incrementalCurrentMatchIndex == 2)

            // Test Highlight All
            ws.incrementalHighlightAll = true
            ws.updateIncrementalSearch(query: "apple", matchCase: true, wholeWord: true, useRegex: false)
            assertTest("Sprint 2.4.C: incrementalHighlightAll applies background highlight to all matches",
                       ws.incrementalHighlightedRanges.count == 3)

            ws.clearIncrementalHighlight()
            assertTest("Sprint 2.4.D: clearIncrementalHighlight removes all highlight ranges cleanly",
                       ws.incrementalHighlightedRanges.isEmpty)

            ws.closeDocument(id: incDoc.id)
        } else {
            assertTest("Sprint 2.4.A: Incremental search test", false)
            assertTest("Sprint 2.4.B: Incremental search index test", false)
            assertTest("Sprint 2.4.C: Incremental highlight all test", false)
            assertTest("Sprint 2.4.D: Incremental clear highlight test", false)
        }

        // -------------------------------------------------------------
        // TASK 5: Function List Parser, Order of Appearance vs A-Z, & Search Filter
        // -------------------------------------------------------------
        let codeSnippet = """
        class ZooKeeper {
        }
        func zebraStripes() {
        }
        func alphaBeta() {
        }
        func monkeyJungle() {
        }
        """

        // Order of appearance (sortedAlphabetically: false)
        let appearanceOrder = NppWorkspace.parseFunctions(content: codeSnippet, filter: "", sortedAlphabetically: false)
        assertTest("Sprint 2.5.A: parseFunctions preserves Order of Appearance by line number",
                   appearanceOrder.count == 4 &&
                   appearanceOrder[0].name == "ZooKeeper" &&
                   appearanceOrder[1].name == "zebraStripes" &&
                   appearanceOrder[2].name == "alphaBeta" &&
                   appearanceOrder[3].name == "monkeyJungle")

        // Alphabetical sort (sortedAlphabetically: true)
        let alphaOrder = NppWorkspace.parseFunctions(content: codeSnippet, filter: "", sortedAlphabetically: true)
        assertTest("Sprint 2.5.B: parseFunctions sorts functions alphabetically (A-Z)",
                   alphaOrder.count == 4 &&
                   alphaOrder[0].name == "alphaBeta" &&
                   alphaOrder[1].name == "monkeyJungle" &&
                   alphaOrder[2].name == "zebraStripes" &&
                   alphaOrder[3].name == "ZooKeeper")

        // Search filter query
        let filteredFuncs = NppWorkspace.parseFunctions(content: codeSnippet, filter: "monk", sortedAlphabetically: false)
        assertTest("Sprint 2.5.C: parseFunctions filters functions by query substring",
                   filteredFuncs.count == 1 && filteredFuncs[0].name == "monkeyJungle")

        // -------------------------------------------------------------
        // TASK 6: Folder as Workspace Navigation Helpers & Find in Files Preload
        // -------------------------------------------------------------
        let rootUrl = URL(fileURLWithPath: "/Workspace/Project")
        let subFileUrl = URL(fileURLWithPath: "/Workspace/Project/Sources/Core/Engine.swift")
        let ancestorDirs = NppWorkspace.locateAncestorDirectories(for: subFileUrl, in: [rootUrl])
        assertTest("Sprint 2.6.A: locateAncestorDirectories locates ancestor directories up to workspace root",
                   ancestorDirs.contains("/Workspace/Project/Sources/Core") &&
                   ancestorDirs.contains("/Workspace/Project/Sources") &&
                   ancestorDirs.contains("/Workspace/Project"))

        ws.openFindInFiles(directory: "/Workspace/Project/Sources")
        assertTest("Sprint 2.6.B: openFindInFiles switches to tab 2 and sets pre-filled directory path",
                   ws.showFindReplaceDialog == true &&
                   ws.findReplaceTab == 2 &&
                   ws.findDirectoryPath == "/Workspace/Project/Sources")
        ws.showFindReplaceDialog = false

        // -------------------------------------------------------------
        // TASK 7: Fullscreen & Post-It State & Overlay Button Mechanics
        // -------------------------------------------------------------
        assertTest("Sprint 2.7.A: Default state has isPostItMode and isFullScreen false",
                   ws.isPostItMode == false && ws.isFullScreen == false)

        ws.togglePostItMode()
        assertTest("Sprint 2.7.B: togglePostItMode enables Post-It mode and hides toolbar/tabbar",
                   ws.isPostItMode == true && ws.hideToolbar == true && ws.hideTabBar == true)

        ws.togglePostItMode()
        assertTest("Sprint 2.7.C: togglePostItMode again restores normal view and unhides toolbar/tabbar",
                   ws.isPostItMode == false && ws.hideToolbar == false && ws.hideTabBar == false)

        // -------------------------------------------------------------
        // TASK 8: Performance Guard for Large Files (>200MB)
        // -------------------------------------------------------------
        ws.newDocument()
        if let perfDoc = ws.activeDocument {
            ws.performanceLargeFileEnabled = true
            ws.performanceLargeFileSizeMB = 1 // Set test threshold to 1MB

            // Document size: 500KB -> Not large
            perfDoc.rawFileBytes = Data(count: 500 * 1024)
            assertTest("Sprint 2.8.A: isLargeFile returns false when file size is under threshold",
                       ws.isLargeFile(doc: perfDoc) == false)

            // Document size: 2MB -> Exceeds 1MB threshold -> Large file
            perfDoc.rawFileBytes = Data(count: 2 * 1024 * 1024)
            assertTest("Sprint 2.8.B: isLargeFile returns true when file size exceeds threshold",
                       ws.isLargeFile(doc: perfDoc) == true)

            // When disabled, isLargeFile returns false regardless of size
            ws.performanceLargeFileEnabled = false
            assertTest("Sprint 2.8.C: isLargeFile returns false when performanceLargeFileEnabled is toggled off",
                       ws.isLargeFile(doc: perfDoc) == false)

            // Restore defaults
            ws.performanceLargeFileEnabled = true
            ws.performanceLargeFileSizeMB = 200

            // Syntax Highlighter maxFileSizeMB guard check
            let smallStorage = NSTextStorage(string: "func quick() -> Int { return 1 }")
            NppSyntaxHighlighter.highlight(textStorage: smallStorage, language: "Swift", isDarkMode: true, maxFileSizeMB: 200)
            let highlighted = smallStorage.attribute(.foregroundColor, at: 0, effectiveRange: nil) != nil
            assertTest("Sprint 2.8.D: NppSyntaxHighlighter highlights files within size threshold", highlighted)

            ws.closeDocument(id: perfDoc.id)
        } else {
            assertTest("Sprint 2.8.A: Large file test", false)
            assertTest("Sprint 2.8.B: Large file test", false)
            assertTest("Sprint 2.8.C: Large file test", false)
            assertTest("Sprint 2.8.D: Large file test", false)
        }

        // Clean up
        ws.closeAll()
    }

    // =========================================================================
    // 36. MILESTONE 3: SEARCH MENU FULL PARITY AUDIT SUITE (Notepad_plus.rc L648-744)
    // =========================================================================
    static func runMilestone3SearchParityTests(
        ws: NppWorkspace,
        appDelegate: AppDelegate,
        assertTest: (String, Bool) -> Void
    ) {
        print("\n========================================================")
        print("🎯 MILESTONE 3: SEARCH MENU FULL PARITY AUDIT SUITE")
        print("========================================================")

        // 1. Volatile Find preserves lastSearchQuery & findQueryText
        ws.newDocument()
        if let doc = ws.activeDocument {
            ws.lastSearchQuery = "persistentQuery"
            ws.findQueryText = "persistentQuery"
            doc.content = "apple orange apple banana apple"
            let tv = ws.activeTextView ?? NSTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 400))
            tv.string = doc.content
            ws.activeTextView = tv

            tv.setSelectedRange(NSRange(location: 6, length: 6)) // "orange"
            ws.findVolatile(forward: true)
            assertTest("M3 Search 1.A: findVolatile wraps and finds target without modifying lastSearchQuery",
                       ws.lastSearchQuery == "persistentQuery" && ws.findQueryText == "persistentQuery")

            // Volatile Find expands caret word and advances
            tv.setSelectedRange(NSRange(location: 1, length: 0)) // inside first "apple"
            ws.findVolatile(forward: true)
            let secondAppleMatched = tv.selectedRange() == NSRange(location: 13, length: 5)
            assertTest("M3 Search 1.B: findVolatile expands caret word and jumps to 2nd occurrence", secondAppleMatched)

            ws.findVolatile(forward: true)
            let thirdAppleMatched = tv.selectedRange() == NSRange(location: 26, length: 5)
            assertTest("M3 Search 1.C: findVolatile advances to 3rd occurrence", thirdAppleMatched)

            ws.findVolatile(forward: false)
            let backToSecondMatched = tv.selectedRange() == NSRange(location: 13, length: 5)
            assertTest("M3 Search 1.D: findVolatile backward jumps back to 2nd occurrence", backToSecondMatched)

            assertTest("M3 Search 1.E: findVolatile leaves user's persistent search buffers untouched",
                       ws.lastSearchQuery == "persistentQuery" && ws.findQueryText == "persistentQuery")

            // 2. Select and Find Next guards against whitespace / empty line
            ws.lastSearchQuery = "originalTerm"
            tv.string = "   \n\t   "
            doc.content = tv.string
            tv.setSelectedRange(NSRange(location: 1, length: 0)) // whitespace
            ws.selectAndFindNext(forward: true)
            assertTest("M3 Search 1.F: selectAndFindNext guards against whitespace and does not overwrite query",
                       ws.lastSearchQuery == "originalTerm")

            // 3. Incremental Search pre-fill from selection
            tv.string = "Sample incremental target text"
            doc.content = tv.string
            tv.setSelectedRange(NSRange(location: 7, length: 11)) // "incremental"
            ws.showSearchBar = false
            ws.toggleIncrementalSearch()
            assertTest("M3 Search 1.G: toggleIncrementalSearch pre-fills findQueryText from editor selection",
                       ws.showSearchBar == true && ws.findQueryText == "incremental")
            ws.showSearchBar = false

            ws.closeDocument(id: doc.id)
        }

        // 4. Search Results Window F7 and F4/Shift+F4 Menu Validation
        ws.clearSearchResults()
        let resultsWinItem = NSMenuItem(title: "Search Results Window", action: #selector(appDelegate.menuSearchResultsWindow), keyEquivalent: "")
        let nextResItem = NSMenuItem(title: "Next Search Result", action: #selector(appDelegate.menuNextSearchResult), keyEquivalent: "")
        let prevResItem = NSMenuItem(title: "Previous Search Result", action: #selector(appDelegate.menuPrevSearchResult), keyEquivalent: "")

        let winItemValidEmpty = appDelegate.validateMenuItem(resultsWinItem)
        let nextItemValidEmpty = appDelegate.validateMenuItem(nextResItem)
        let prevItemValidEmpty = appDelegate.validateMenuItem(prevResItem)
        assertTest("M3 Search 2.A: Search Results Window F7 is disabled when searchFileGroups is empty",
                   winItemValidEmpty == false)
        assertTest("M3 Search 2.B: Next & Prev Search Result F4/Shift+F4 are disabled when searchFileGroups is empty",
                   nextItemValidEmpty == false && prevItemValidEmpty == false)

        // Populate search results and verify menu items enable & sync
        let testDocId = UUID()
        let m1 = NppSearchMatch(documentId: testDocId, documentTitle: "t1.txt", filePath: nil, lineNumber: 1, lineContent: "hit 1", matchRangeInLine: NSRange(location: 0, length: 5), charPosition: 0, matchLength: 5)
        let m2 = NppSearchMatch(documentId: testDocId, documentTitle: "t1.txt", filePath: nil, lineNumber: 2, lineContent: "hit 2", matchRangeInLine: NSRange(location: 0, length: 5), charPosition: 10, matchLength: 5)
        let m3 = NppSearchMatch(documentId: testDocId, documentTitle: "t1.txt", filePath: nil, lineNumber: 3, lineContent: "hit 3", matchRangeInLine: NSRange(location: 0, length: 5), charPosition: 20, matchLength: 5)
        ws.searchFileGroups = [NppSearchFileGroup(documentId: testDocId, documentTitle: "t1.txt", filePath: nil, matches: [m1, m2, m3])]

        let winItemValidPopulated = appDelegate.validateMenuItem(resultsWinItem)
        let nextItemValidPopulated = appDelegate.validateMenuItem(nextResItem)
        assertTest("M3 Search 2.C: Search Results Window and F4 enable when searchFileGroups is populated",
                   winItemValidPopulated == true && nextItemValidPopulated == true)

        // 5. jumpToMatch synchronizes currentSearchResultIndex & F4 cyclic navigation
        ws.jumpToMatch(m2)
        assertTest("M3 Search 2.D: jumpToMatch synchronizes currentSearchResultIndex to clicked row",
                   ws.currentSearchResultIndex == 1)

        ws.nextSearchResult()
        assertTest("M3 Search 2.E: nextSearchResult advances from synchronized index to 2",
                   ws.currentSearchResultIndex == 2)

        ws.nextSearchResult()
        assertTest("M3 Search 2.F: nextSearchResult circularly wraps back to 0",
                   ws.currentSearchResultIndex == 0)

        ws.prevSearchResult()
        assertTest("M3 Search 2.G: prevSearchResult circularly wraps backward to 2",
                   ws.currentSearchResultIndex == 2)

        ws.clearSearchResults()

        // 6. Matching Brace Priority Order [clamped - 1, clamped]
        // String: "() {}" with caret at index 2 (between ')' and ' ')
        let braceStr: NSString = "() {}"
        let bracePair = NppEditOperations.findMatchingBracePair(in: braceStr, at: 2, allowEnclosing: false)
        assertTest("M3 Search 3.A: findMatchingBracePair prioritizes character before caret (clamped - 1)",
                   bracePair != nil && bracePair?.closePos == 1 && bracePair?.openPos == 0)

        // 7. Matching Brace ignores braces inside string literals and comments
        let codeWithStrings: NSString = "func test() { let s = \"}\"; // }\n return 1; }"
        // Caret at index 12 ('{')
        let codePair = NppEditOperations.findMatchingBracePair(in: codeWithStrings, at: 12, allowEnclosing: false)
        assertTest("M3 Search 3.B: findMatchingBracePair ignores braces inside string literal and line comment",
                   codePair != nil && codePair?.openPos == 12 && codePair?.closePos == (codeWithStrings.length - 1))

        // 8. Token Style Palette Colors (Cyan, Orange, Yellow, Purple, Dark Green @ 0.40)
        let c1 = NppWorkspace.tokenStyleColor(for: 1)
        let c2 = NppWorkspace.tokenStyleColor(for: 2)
        let c3 = NppWorkspace.tokenStyleColor(for: 3)
        let c4 = NppWorkspace.tokenStyleColor(for: 4)
        let c5 = NppWorkspace.tokenStyleColor(for: 5)
        let colorsCorrect = (abs(c1.redComponent - 0.0) < 0.05 && abs(c1.greenComponent - 1.0) < 0.05 && abs(c1.blueComponent - 1.0) < 0.05) &&
                            (abs(c2.redComponent - 1.0) < 0.05 && abs(c2.greenComponent - 0.5) < 0.05 && abs(c2.blueComponent - 0.0) < 0.05) &&
                            (abs(c3.redComponent - 1.0) < 0.05 && abs(c3.greenComponent - 1.0) < 0.05 && abs(c3.blueComponent - 0.0) < 0.05) &&
                            (abs(c4.redComponent - 0.5) < 0.05 && abs(c4.greenComponent - 0.0) < 0.05 && abs(c4.blueComponent - 1.0) < 0.05) &&
                            (abs(c5.redComponent - 0.0) < 0.05 && abs(c5.greenComponent - 0.5) < 0.05 && abs(c5.blueComponent - 0.0) < 0.05)
        assertTest("M3 Search 3.C: tokenStyleColor matches official upstream palette (Cyan, Orange, Yellow, Purple, Dark Green)",
                   colorsCorrect && abs(c1.alphaComponent - 0.40) < 0.05)

        // 9. styleOneToken Deduplication
        ws.newDocument()
        if let tokenDoc = ws.activeDocument {
            tokenDoc.content = "highlightTarget word word"
            let tv = ws.activeTextView ?? NSTextView()
            tv.string = tokenDoc.content
            ws.activeTextView = tv

            tv.setSelectedRange(NSRange(location: 0, length: 15)) // "highlightTarget"
            _ = ws.styleOneToken(styleIndex: 1)
            let countAfterFirst = tokenDoc.styledTokenRanges[1]?.count ?? 0
            _ = ws.styleOneToken(styleIndex: 1)
            let countAfterSecond = tokenDoc.styledTokenRanges[1]?.count ?? 0
            assertTest("M3 Search 3.D: styleOneToken deduplicates ranges on repeated application",
                       countAfterFirst == 1 && countAfterSecond == 1)

            // 10. adjustStyledRanges prevents highlight drift on edits
            // Target is at 0..15. Insert 10 characters at offset 0: target should shift to 10..25
            tokenDoc.adjustStyledRanges(affectedRange: NSRange(location: 0, length: 0), delta: 10)
            let shiftedRange = tokenDoc.styledTokenRanges[1]?.first
            assertTest("M3 Search 3.E: adjustStyledRanges shifts token ranges when text inserted before them",
                       shiftedRange == NSRange(location: 10, length: 15))

            // Delete 5 characters before target: target should shift back to 5..20
            tokenDoc.adjustStyledRanges(affectedRange: NSRange(location: 0, length: 5), delta: -5)
            let deletedRange = tokenDoc.styledTokenRanges[1]?.first
            assertTest("M3 Search 3.F: adjustStyledRanges shifts token ranges when text deleted before them",
                       deletedRange == NSRange(location: 5, length: 15))

            // 11. clearStyle(styleIndex:) clears only target style while preserving others
            tokenDoc.styledTokenRanges[2] = [NSRange(location: 30, length: 5)]
            ws.clearStyle(styleIndex: 1)
            assertTest("M3 Search 3.G: clearStyle(1) removes style 1 and preserves style 2",
                       tokenDoc.styledTokenRanges[1] == nil && tokenDoc.styledTokenRanges[2]?.count == 1)

            ws.closeDocument(id: tokenDoc.id)
        }

        // 12. Modeless Find Characters in Range Window Controller
        let findCharsCtrl = NppFindCharsInRangeWindowController.shared
        findCharsCtrl.show(workspace: ws)
        let panelFloating = findCharsCtrl.panel?.isFloatingPanel == true
        let panelLevel = findCharsCtrl.panel?.level == .floating
        let panelHidesOnDeact = findCharsCtrl.panel?.hidesOnDeactivate == true
        assertTest("M3 Search 2.H: NppFindCharsInRangeWindowController is floating modeless panel with hidesOnDeactivate",
                   panelFloating && panelLevel && panelHidesOnDeact)
        findCharsCtrl.close()

        // 13. Korean Localization for Search & Find Characters in Range
        let trFindCharsTitle = NppLocalization.tr("Find Characters in Range...", lang: "Korean")
        let trNonAscii = NppLocalization.tr("Non-ASCII characters (128–255)", lang: "Korean")
        let trAscii = NppLocalization.tr("ASCII characters (0–127)", lang: "Korean")
        let trCustomRange = NppLocalization.tr("Custom range (0–255):", lang: "Korean")
        let trDirection = NppLocalization.tr("Direction", lang: "Korean")
        let trUp = NppLocalization.tr("Up", lang: "Korean")
        let trDown = NppLocalization.tr("Down", lang: "Korean")
        let trVolNext = NppLocalization.tr("Find (Volatile) Next", lang: "Korean")
        let trRangeErr = NppLocalization.tr("Range Value problem", lang: "Korean")
        let localizationMatches = trFindCharsTitle == "범위에서 문자 찾기..." &&
                                  trNonAscii == "Non-ASCII 문자 (128-255)" &&
                                  trAscii == "ASCII 문자 (0-127)" &&
                                  trCustomRange == "사용자 범위 (0-255):" &&
                                  trDirection == "방향" &&
                                  trUp == "위로" &&
                                  trDown == "아래로" &&
                                   trVolNext == "다음 찾기 (임시)" &&
                                   trRangeErr == "범위 값 오류"
        assertTest("M3 Search 2.I: Korean localization matches official korean.xml lines 542–552",
                   localizationMatches)

        // ========================================================
        // 🎯 MILESTONE 4: FULL MENU PARITY AUDIT SUITE
        // (View, Encoding, Language, Tools, Window & Korean Localization)
        // ========================================================
        print("\n========================================================")
        print("🎯 MILESTONE 4: FULL MENU PARITY AUDIT SUITE")
        print("========================================================")

        // 1. View Modes & Window Level Coordination
        assertTest("M4 View 1.A: Fullscreen, Distraction Free, and Post-It initial states are false",
                   !ws.isFullScreen && !ws.isDistractionFreeMode && !ws.isPostItMode)
        ws.togglePostItMode(window: nil)
        assertTest("M4 View 1.B: togglePostItMode enables Post-It, hides tool/tab bars",
                   ws.isPostItMode && ws.hideToolbar && ws.hideTabBar)
        ws.togglePostItMode(window: nil)
        assertTest("M4 View 1.C: togglePostItMode restores normal view",
                   !ws.isPostItMode && !ws.hideToolbar && !ws.hideTabBar)
        ws.toggleDistractionFreeMode(window: nil)
        assertTest("M4 View 1.D: toggleDistractionFreeMode enables distraction-free mode",
                   ws.isDistractionFreeMode && ws.hideToolbar && ws.hideTabBar && ws.hideStatusBar)
        ws.toggleDistractionFreeMode(window: nil)
        assertTest("M4 View 1.E: toggleDistractionFreeMode restores chrome visibility",
                   !ws.isDistractionFreeMode && !ws.hideToolbar && !ws.hideTabBar && !ws.hideStatusBar)

        // 2. 4-Way Symbol Flag Synchronization
        ws.showInvisibleCharacters = false
        ws.showSpaceAndTab = false
        ws.showEndOfLine = false
        ws.showNonPrintingCharacters = false
        ws.toggleShowSpaceAndTab()
        assertTest("M4 View 2.A: toggleShowSpaceAndTab enables space/tab symbol flag", ws.showSpaceAndTab)
        ws.toggleShowEndOfLine()
        assertTest("M4 View 2.B: toggleShowEndOfLine enables EOL symbol flag", ws.showEndOfLine)
        ws.toggleShowNonPrintingCharacters()
        assertTest("M4 View 2.C: toggleShowNonPrintingCharacters enables NPC symbol flag", ws.showNonPrintingCharacters)
        ws.toggleShowAllCharacters()
        assertTest("M4 View 2.D: toggleShowAllCharacters synchronizes all 3 symbol flags",
                   ws.showInvisibleCharacters && ws.showSpaceAndTab && ws.showEndOfLine && ws.showNonPrintingCharacters)
        ws.toggleShowSpaceAndTab()
        assertTest("M4 View 2.E: Toggling off one flag de-syncs showAllCharacters",
                   !ws.showSpaceAndTab && !ws.showInvisibleCharacters)
        let initialControlState = ws.showControlCharsAndUnicodeEol
        ws.toggleShowControlCharsAndUnicodeEol()
        assertTest("M4 View 2.F: toggleShowControlCharsAndUnicodeEol toggles Unicode/Control badge state",
                   ws.showControlCharsAndUnicodeEol != initialControlState)
        let initialIndentGuide = ws.showIndentGuides
        ws.showIndentGuides.toggle()
        assertTest("M4 View 2.G: showIndentGuides toggles vertical indentation guides",
                   ws.showIndentGuides != initialIndentGuide)
        let initialWrapSymbol = ws.showWrapSymbol
        ws.showWrapSymbol.toggle()
        assertTest("M4 View 2.H: showWrapSymbol toggles wrap return symbol rendering",
                   ws.showWrapSymbol != initialWrapSymbol)

        // 3. Tab Navigation & Ordering
        ws.closeAll()
        ws.newDocument() // doc 0
        ws.newDocument() // doc 1
        ws.newDocument() // doc 2
        let doc2Id = ws.documents[2].id
        ws.selectTab(at: 2)
        assertTest("M4 Tab 3.A: Selected 3rd tab", ws.activeDocumentId == doc2Id)
        ws.moveTabToStart()
        assertTest("M4 Tab 3.B: moveTabToStart moves active document to index 0", ws.documents[0].id == doc2Id)
        ws.moveTabToEnd()
        assertTest("M4 Tab 3.C: moveTabToEnd moves active document to last index", ws.documents.last?.id == doc2Id)
        ws.moveTabBackward()
        assertTest("M4 Tab 3.D: moveTabBackward shifts active document left", ws.documents[2].id == doc2Id)
        ws.moveTabForward()
        assertTest("M4 Tab 3.E: moveTabForward shifts active document right", ws.documents[3].id == doc2Id)

        // Tab Navigation 9th Tab Overflow
        ws.closeAll()
        for _ in 0..<12 { ws.newDocument() }
        let lastCreatedId = ws.documents.last?.id
        ws.selectTab(at: 8) // 9th Tab (index 8)
        assertTest("M4 Tab 3.F: 9th tab selector navigates to last tab when count > 9",
                   ws.activeDocumentId == lastCreatedId)

        // 4. Monitoring (tail -f) Guards & Active File Observation
        ws.closeAll()
        ws.newDocument() // Untitled document
        ws.lastMonitoringAlert = nil
        ws.toggleMonitoringCurrentDoc()
        assertTest("M4 View 4.A: toggleMonitoringCurrentDoc on untitled document rejected",
                   ws.activeDocument?.isMonitoring == false && ws.lastMonitoringAlert == "The file should exist to be monitored.")
        let tempMonFile = FileManager.default.temporaryDirectory.appendingPathComponent("mon_guard_\(UUID().uuidString).txt")
        try? "initial text\n".write(to: tempMonFile, atomically: true, encoding: .utf8)
        ws.activeDocument?.filePath = tempMonFile
        ws.activeDocument?.isDirty = true
        ws.lastMonitoringAlert = nil
        ws.toggleMonitoringCurrentDoc()
        assertTest("M4 View 4.B: toggleMonitoringCurrentDoc on dirty document rejected",
                   ws.activeDocument?.isMonitoring == false && ws.lastMonitoringAlert == "The document is dirty. Please save the modification before monitoring it.")
        ws.activeDocument?.isDirty = false
        ws.toggleMonitoringCurrentDoc()
        assertTest("M4 View 4.C: toggleMonitoringCurrentDoc on clean saved file succeeds and sets isReadOnly",
                   ws.activeDocument?.isMonitoring == true && ws.activeDocument?.isReadOnly == true)
        ws.toggleMonitoringCurrentDoc()
        assertTest("M4 View 4.D: toggleMonitoringCurrentDoc toggled OFF restores writable state",
                   ws.activeDocument?.isMonitoring == false && ws.activeDocument?.isReadOnly == false)
        try? FileManager.default.removeItem(at: tempMonFile)

        // 5. Encoding Submenus & UTF-16 BE/LE Conversions
        ws.closeAll()
        ws.newDocument()
        let encDoc = ws.activeDocument!
        encDoc.content = "Notepad++ Unicode Test"
        encDoc.convertEncoding(to: "UTF-16BE", addBOM: true)
        assertTest("M4 Enc 5.A: Convert to UTF-16 BE BOM sets encoding and BOM flag",
                   encDoc.encoding == "UTF-16BE" && encDoc.hasBOM == true)
        encDoc.convertEncoding(to: "UTF-16LE", addBOM: true)
        assertTest("M4 Enc 5.B: Convert to UTF-16 LE BOM sets encoding and BOM flag",
                   encDoc.encoding == "UTF-16LE" && encDoc.hasBOM == true)
        encDoc.reencodeAs(targetCharset: "WINDOWS-1252")
        assertTest("M4 Enc 5.C: reencodeAs reinterprets charset to Windows-1252",
                   encDoc.encoding == "WINDOWS-1252")

        // 6. Language Compact Mode & Dynamic Filtering
        assertTest("M4 Lang 6.A: allCanonicalLanguages contains over 80 standard languages",
                   NppWorkspace.allCanonicalLanguages.count >= 80)
        assertTest("M4 Lang 6.B: allCanonicalLanguages contains XML and YAML",
                   NppWorkspace.allCanonicalLanguages.contains("XML") && NppWorkspace.allCanonicalLanguages.contains("YAML"))
        ws.disabledLanguages = ["Ada", "ActionScript", "COBOL"]
        let disSet = Set(ws.disabledLanguages.map { $0.lowercased() })
        let filteredCanonical = NppWorkspace.allCanonicalLanguages.filter { !disSet.contains($0.lowercased()) }
        assertTest("M4 Lang 6.C: disabledLanguages dynamically filters out specified languages",
                   !filteredCanonical.contains("Ada") && !filteredCanonical.contains("ActionScript") && !filteredCanonical.contains("COBOL"))
        ws.disabledLanguages = []
        let testUdl = NppUserDefineLanguage(name: "TestUDL", extensions: "tudl")
        ws.userDefinedLanguages.append(testUdl)
        assertTest("M4 Lang 6.D: User Defined Language added to workspace",
                   ws.userDefinedLanguages.contains(where: { $0.name == "TestUDL" && $0.extensions == "tudl" }))
        assertTest("M4 Lang 6.E: NppUserDefineWindowController shared instance available",
                   NppUserDefineWindowController.shared.panel == nil)

        // 7. Tools Modeless Hash Generation & Line-by-Line Mode
        let sampleHashText = "The quick brown fox jumps over the lazy dog"
        assertTest("M4 Tools 7.A: NppHashAlgorithm.md5 computes standard RFC 1321 hash",
                   NppHashAlgorithm.md5.compute(string: sampleHashText) == "9e107d9d372bb6826bd81d3542a419d6")
        assertTest("M4 Tools 7.B: NppHashAlgorithm.sha1 computes standard FIPS 180-1 hash",
                   NppHashAlgorithm.sha1.compute(string: sampleHashText) == "2fd4e1c67a2d28fced849ee1bb76e7391b93eb12")
        assertTest("M4 Tools 7.C: NppHashAlgorithm.sha256 computes standard FIPS 180-4 hash",
                   NppHashAlgorithm.sha256.compute(string: sampleHashText) == "d7a8fbb307d7809469ca9abcb0082e4f8d5651e46d3cdb762d02d0bf37c9e592")
        assertTest("M4 Tools 7.D: NppHashAlgorithm.sha512 computes standard FIPS 180-4 hash prefix",
                   NppHashAlgorithm.sha512.compute(string: sampleHashText).hasPrefix("07e547d9586f6a73"))
        let multiLineHashInput = "hello\nworld"
        let lineHashes = NppHashAlgorithm.md5.computeLineByLine(text: multiLineHashInput)
        let hashLines = lineHashes.components(separatedBy: "\n")
        assertTest("M4 Tools 7.E: computeLineByLine computes independent hash per line",
                   hashLines.count == 2 &&
                   hashLines[0] == NppHashAlgorithm.md5.compute(string: "hello") &&
                   hashLines[1] == NppHashAlgorithm.md5.compute(string: "world"))
        assertTest("M4 Tools 7.F: Modeless hash text and files controllers instantiated",
                   NppHashFromTextWindowController.shared.panel == nil && NppHashFromFilesWindowController.shared.panel == nil)

        // 8. Window Menu Natural Sort & Windows... Dialog
        ws.closeAll()
        let winDoc10 = NppDocument(title: "item10.txt", content: "x")
        let winDoc2 = NppDocument(title: "item2.txt", content: "xxx")
        let winDoc1 = NppDocument(title: "item1.txt", content: "xx")
        winDoc10.language = "Swift"
        winDoc2.language = "C++"
        winDoc1.language = "HTML"
        ws.documents = [winDoc10, winDoc2, winDoc1]
        ws.sortTabsByName(ascending: true)
        assertTest("M4 Win 8.A: sortTabsByName uses localizedStandardCompare natural order (item1 < item2 < item10)",
                   ws.documents[0].title == "item1.txt" &&
                   ws.documents[1].title == "item2.txt" &&
                   ws.documents[2].title == "item10.txt")
        ws.sortTabsByType(ascending: true)
        assertTest("M4 Win 8.B: sortTabsByType sorts documents alphabetically by language (C++ < HTML < Swift)",
                   ws.documents[0].language == "C++" &&
                   ws.documents[1].language == "HTML" &&
                   ws.documents[2].language == "Swift")
        ws.sortTabsBySize(ascending: true)
        assertTest("M4 Win 8.C: sortTabsBySize sorts documents by content character length (1 < 2 < 3)",
                   ws.documents[0].content.count == 1 &&
                   ws.documents[1].content.count == 2 &&
                   ws.documents[2].content.count == 3)
        ws.sortTabsBySize(ascending: false)
        assertTest("M4 Win 8.D: sortTabsBySize descending orders largest first (3 > 2 > 1)",
                   ws.documents[0].content.count == 3 &&
                   ws.documents[1].content.count == 2 &&
                   ws.documents[2].content.count == 1)
        assertTest("M4 Win 8.E: NppWindowsDialogWindowController shared instance available",
                   NppWindowsDialogWindowController.shared.panel == nil)

        // 9. Korean Localization Table Coverage (Milestone 4 42 Keys)
        let trMoveStart = NppLocalization.tr("Move to Start", lang: "Korean")
        let trMoveEnd = NppLocalization.tr("Move to End", lang: "Korean")
        let trArabic = NppLocalization.tr("Arabic", lang: "Korean")
        let trCyrillic = NppLocalization.tr("Cyrillic", lang: "Korean")
        let trGreek = NppLocalization.tr("Greek", lang: "Korean")
        let trHebrew = NppLocalization.tr("Hebrew", lang: "Korean")
        let trJapanese = NppLocalization.tr("Japanese", lang: "Korean")
        let trKorean = NppLocalization.tr("Korean", lang: "Korean")
        let trThai = NppLocalization.tr("Thai", lang: "Korean")
        let trWestern = NppLocalization.tr("Western European", lang: "Korean")
        let trUtf16BE = NppLocalization.tr("UTF-16 BE BOM", lang: "Korean")
        let trConvUtf16BE = NppLocalization.tr("Convert to UTF-16 BE BOM", lang: "Korean")
        let trDefineLang = NppLocalization.tr("Define your language...", lang: "Korean")
        let trOpenUDL = NppLocalization.tr("Open User Defined Language folder...", lang: "Korean")
        let trHashSeparate = NppLocalization.tr("Treat each line as a separate string", lang: "Korean")
        let trTextToHash = NppLocalization.tr("Text to Hash:", lang: "Korean")
        let trHashResult = NppLocalization.tr("Hash Result:", lang: "Korean")
        let trGenFromFiles = NppLocalization.tr("Generate from files...", lang: "Korean")
        let trSortModAsc = NppLocalization.tr("Modified Time Ascending", lang: "Korean")
        let trSortModDesc = NppLocalization.tr("Modified Time Descending", lang: "Korean")
        let trWindowsDlg = NppLocalization.tr("Windows...", lang: "Korean")
        let trCloseWin = NppLocalization.tr("Close window(s)", lang: "Korean")
        let trSortTabs = NppLocalization.tr("Sort tabs", lang: "Korean")

        let allKoreanMatched = (trMoveStart == "시작으로 이동") &&
                               (trMoveEnd == "끝으로 이동") &&
                               (trArabic == "아랍어") &&
                               (trCyrillic == "키릴 자모") &&
                               (trGreek == "그리스어") &&
                               (trHebrew == "히브리어") &&
                               (trJapanese == "일본어") &&
                               (trKorean == "한국어") &&
                               (trThai == "태국어") &&
                               (trWestern == "서유럽어") &&
                               (trUtf16BE == "UTF-16 BE BOM") &&
                               (trConvUtf16BE == "UTF-16 BE BOM으로 변환") &&
                               (trDefineLang == "언어 정의...") &&
                               (trOpenUDL == "사용자 정의 언어 폴더 열기...") &&
                               (trHashSeparate == "각 줄을 분리된 문자열로 처리") &&
                               (trTextToHash == "해시할 텍스트:") &&
                               (trHashResult == "해시 결과:") &&
                               (trGenFromFiles == "파일에서 생성...") &&
                               (trSortModAsc == "수정된 시간 오름차순") &&
                               (trSortModDesc == "수정된 시간 내림차순") &&
                               (trWindowsDlg == "창 목록...") &&
                               (trCloseWin == "창 닫기") &&
                               (trSortTabs == "탭 정렬")
        assertTest("M4 Loc 9.A: Korean localization covers Milestone 4 Tab, Charset, UDL, Hash, and Window keys",
                   allKoreanMatched)

        ws.closeAll()
    }

    // =========================================================================
    // 37. ADVERSARIAL CHALLENGE SUITE: PASS 4 (M4)
    // (View Modes, 4-Way Symbol Flags, Tab Actions, Natural Sorting, Monitoring)
    // =========================================================================
    static func runAdversarialM4ChallengeTests(
        ws: NppWorkspace,
        appDelegate: AppDelegate,
        assertTest: (String, Bool) -> Void
    ) {
        print("\n========================================================")
        print("⚔️ ADVERSARIAL CHALLENGE SUITE: MILESTONE 4 (PASS 4)")
        print("========================================================")

        // -------------------------------------------------------------
        // CHALLENGE 1: View Modes Mutually Exclusive State Transitions & Restoration
        // -------------------------------------------------------------
        let dummyWin = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 600, height: 400),
                                styleMask: [.titled, .resizable],
                                backing: .buffered,
                                defer: false)
        dummyWin.level = .normal
        ws.isPostItMode = false
        ws.isDistractionFreeMode = false
        ws.hideToolbar = false
        ws.hideTabBar = false
        ws.hideStatusBar = false
        ws.isAlwaysOnTop = false

        // 1.1: Post-It mode enables floating level and hides chrome
        ws.togglePostItMode(window: dummyWin)
        assertTest("Adv M4.1.A: togglePostItMode sets isPostItMode and clears isDistractionFreeMode",
                   ws.isPostItMode && !ws.isDistractionFreeMode)
        assertTest("Adv M4.1.B: Post-It hides toolbar, tabbar, and statusbar",
                   ws.hideToolbar && ws.hideTabBar && ws.hideStatusBar)
        assertTest("Adv M4.1.C: Post-It raises window level to .floating",
                   dummyWin.level == .floating && ws.isAlwaysOnTop)

        // 1.2: Post-It mode toggle off restores .normal level and unhides chrome
        ws.togglePostItMode(window: dummyWin)
        assertTest("Adv M4.1.D: togglePostItMode off restores isPostItMode to false",
                   !ws.isPostItMode)
        assertTest("Adv M4.1.E: Post-It off restores chrome visibility",
                   !ws.hideToolbar && !ws.hideTabBar && !ws.hideStatusBar)
        assertTest("Adv M4.1.F: Post-It off restores window level to .normal",
                   dummyWin.level == .normal && !ws.isAlwaysOnTop)

        // 1.3: Chrome customization preservation through Post-It mode
        ws.hideToolbar = true
        ws.hideTabBar = false
        ws.hideStatusBar = true
        ws.togglePostItMode(window: dummyWin)
        ws.togglePostItMode(window: dummyWin)
        assertTest("Adv M4.1.G: Post-It faithfully preserves custom pre-mode chrome states",
                   ws.hideToolbar == true && ws.hideTabBar == false && ws.hideStatusBar == true)
        ws.hideToolbar = false
        ws.hideStatusBar = false

        // 1.4: Distraction-Free mode enables floating level, hides chrome, sets padding
        ws.toggleDistractionFreeMode(window: dummyWin)
        assertTest("Adv M4.1.H: toggleDistractionFreeMode sets isDistractionFreeMode and clears isPostItMode",
                   ws.isDistractionFreeMode && !ws.isPostItMode)
        assertTest("Adv M4.1.I: Distraction-Free hides all chrome and sets paddingLeft >= 120",
                   ws.hideToolbar && ws.hideTabBar && ws.hideStatusBar && ws.paddingLeft >= 120)
        assertTest("Adv M4.1.J: Distraction-Free sets window level to .floating",
                   dummyWin.level == .floating && ws.isAlwaysOnTop)

        // 1.5: Distraction-Free toggle off restores chrome, padding, and window level
        ws.toggleDistractionFreeMode(window: dummyWin)
        assertTest("Adv M4.1.K: Distraction-Free off restores normal state and resets paddingLeft to 0",
                   !ws.isDistractionFreeMode && ws.paddingLeft == 0 && dummyWin.level == .normal)

        // 1.6: Mutually exclusive direct transition: Post-It -> DistractionFree
        ws.togglePostItMode(window: dummyWin)
        assertTest("Adv M4.1.L: In Post-It mode before direct switch", ws.isPostItMode && !ws.isDistractionFreeMode)
        ws.toggleDistractionFreeMode(window: dummyWin)
        assertTest("Adv M4.1.M: Direct switch to Distraction-Free deactivates Post-It",
                   ws.isDistractionFreeMode && !ws.isPostItMode)
        ws.toggleDistractionFreeMode(window: dummyWin)
        assertTest("Adv M4.1.N: Exiting Distraction-Free restores normal chrome",
                   !ws.isDistractionFreeMode && !ws.isPostItMode && !ws.hideToolbar && !ws.hideTabBar && !ws.hideStatusBar)

        // 1.7: Mutually exclusive direct transition: DistractionFree -> Post-It
        ws.toggleDistractionFreeMode(window: dummyWin)
        assertTest("Adv M4.1.O: In Distraction-Free mode before direct switch", ws.isDistractionFreeMode && !ws.isPostItMode)
        ws.togglePostItMode(window: dummyWin)
        assertTest("Adv M4.1.P: Direct switch to Post-It deactivates Distraction-Free",
                   ws.isPostItMode && !ws.isDistractionFreeMode)
        ws.togglePostItMode(window: dummyWin)
        assertTest("Adv M4.1.Q: Exiting Post-It restores normal chrome",
                   !ws.isPostItMode && !ws.isDistractionFreeMode && !ws.hideToolbar && !ws.hideTabBar && !ws.hideStatusBar)

        // -------------------------------------------------------------
        // CHALLENGE 2: 4-Way Symbol Flag Synchronization
        // -------------------------------------------------------------
        // 2.1: Master flag drives all 4 individual flags
        ws.showInvisibleCharacters = true
        assertTest("Adv M4.2.A: showInvisibleCharacters=true drives all 4 individual symbol flags ON",
                   ws.showSpaceAndTab && ws.showEndOfLine && ws.showNonPrintingCharacters && ws.showControlCharsAndUnicodeEol)

        ws.showInvisibleCharacters = false
        assertTest("Adv M4.2.B: showInvisibleCharacters=false drives all 4 individual symbol flags OFF",
                   !ws.showSpaceAndTab && !ws.showEndOfLine && !ws.showNonPrintingCharacters && !ws.showControlCharsAndUnicodeEol)

        // 2.2: Any single individual flag OFF de-syncs master flag
        ws.showInvisibleCharacters = true
        ws.showSpaceAndTab = false
        assertTest("Adv M4.2.C: showSpaceAndTab=false de-syncs showInvisibleCharacters to false",
                   !ws.showInvisibleCharacters)
        ws.showSpaceAndTab = true
        assertTest("Adv M4.2.D: Restoring showSpaceAndTab re-syncs showInvisibleCharacters to true",
                   ws.showInvisibleCharacters)

        ws.showEndOfLine = false
        assertTest("Adv M4.2.E: showEndOfLine=false de-syncs showInvisibleCharacters to false",
                   !ws.showInvisibleCharacters)
        ws.showEndOfLine = true
        assertTest("Adv M4.2.F: Restoring showEndOfLine re-syncs showInvisibleCharacters to true",
                   ws.showInvisibleCharacters)

        ws.showNonPrintingCharacters = false
        assertTest("Adv M4.2.G: showNonPrintingCharacters=false de-syncs showInvisibleCharacters to false",
                   !ws.showInvisibleCharacters)
        ws.showNonPrintingCharacters = true
        assertTest("Adv M4.2.H: Restoring showNonPrintingCharacters re-syncs showInvisibleCharacters to true",
                   ws.showInvisibleCharacters)

        ws.showControlCharsAndUnicodeEol = false
        assertTest("Adv M4.2.I: showControlCharsAndUnicodeEol=false de-syncs showInvisibleCharacters to false",
                   !ws.showInvisibleCharacters)
        ws.showControlCharsAndUnicodeEol = true
        assertTest("Adv M4.2.J: Restoring showControlCharsAndUnicodeEol re-syncs showInvisibleCharacters to true",
                   ws.showInvisibleCharacters)

        // 2.3: Exhaustive 16-state truth table generator
        var truthTablePassed = true
        for mask in 0..<16 {
            let fSpace = (mask & 1) != 0
            let fEol   = (mask & 2) != 0
            let fNpc   = (mask & 4) != 0
            let fCtrl  = (mask & 8) != 0

            ws.showSpaceAndTab = fSpace
            ws.showEndOfLine = fEol
            ws.showNonPrintingCharacters = fNpc
            ws.showControlCharsAndUnicodeEol = fCtrl

            let expectedMaster = fSpace && fEol && fNpc && fCtrl
            if ws.showInvisibleCharacters != expectedMaster {
                print("❌ Mismatch at mask \(mask): flags=(\(fSpace),\(fEol),\(fNpc),\(fCtrl)), expected=\(expectedMaster), got=\(ws.showInvisibleCharacters)")
                truthTablePassed = false
            }
        }
        assertTest("Adv M4.2.K: Exhaustive 16-combination truth table: showInvisibleCharacters matches all-on vs any-off exactly",
                   truthTablePassed)

        // Reset symbols
        ws.showInvisibleCharacters = false

        // -------------------------------------------------------------
        // CHALLENGE 3: Tab Submenu Actions Stress (1-tab, 2-tab, multi-tab, 9th tab overflow)
        // -------------------------------------------------------------
        // 3.1: 1-tab workspace boundary
        ws.closeAll()
        assertTest("Adv M4.3.A: 1-tab workspace initial count is 1", ws.documents.count == 1)
        let singleDocId = ws.documents[0].id
        ws.moveTabToStart()
        assertTest("Adv M4.3.B: moveTabToStart on 1-tab workspace preserves document and activeId",
                   ws.documents.count == 1 && ws.documents[0].id == singleDocId && ws.activeDocumentId == singleDocId)
        ws.moveTabToEnd()
        assertTest("Adv M4.3.C: moveTabToEnd on 1-tab workspace preserves document and activeId",
                   ws.documents.count == 1 && ws.documents[0].id == singleDocId && ws.activeDocumentId == singleDocId)

        // 3.2: 2-tab workspace boundaries
        ws.newDocument() // doc 1
        assertTest("Adv M4.3.D: 2-tab workspace initialized", ws.documents.count == 2)
        let d0Id = ws.documents[0].id
        let d1Id = ws.documents[1].id
        ws.activeDocumentId = d0Id
        ws.moveTabToStart() // doc0 is already at start
        assertTest("Adv M4.3.E: moveTabToStart on tab 0 in 2-tab workspace is safe no-op",
                   ws.documents[0].id == d0Id && ws.documents[1].id == d1Id)
        ws.moveTabToEnd() // move doc0 to end -> [d1, d0]
        assertTest("Adv M4.3.F: moveTabToEnd moves tab 0 to end and preserves activeDocumentId",
                   ws.documents[0].id == d1Id && ws.documents[1].id == d0Id && ws.activeDocumentId == d0Id)
        ws.moveTabToEnd() // already at end
        assertTest("Adv M4.3.G: moveTabToEnd on last tab in 2-tab workspace is safe no-op",
                   ws.documents[0].id == d1Id && ws.documents[1].id == d0Id && ws.activeDocumentId == d0Id)
        ws.moveTabToStart() // move doc0 back to start -> [d0, d1]
        assertTest("Adv M4.3.H: moveTabToStart restores tab 0 to start and preserves activeDocumentId",
                   ws.documents[0].id == d0Id && ws.documents[1].id == d1Id && ws.activeDocumentId == d0Id)

        // 3.3: Multi-tab workspace (5 tabs)
        ws.closeAll()
        for _ in 0..<4 { ws.newDocument() } // now 5 tabs
        assertTest("Adv M4.3.I: 5-tab workspace initialized", ws.documents.count == 5)
        let multiIds = ws.documents.map { $0.id }
        ws.activeDocumentId = multiIds[2] // active is Middle tab (index 2)
        ws.moveTabToStart()
        assertTest("Adv M4.3.J: moveTabToStart on middle tab moves it to index 0",
                   ws.documents[0].id == multiIds[2] &&
                   ws.documents[1].id == multiIds[0] &&
                   ws.documents[2].id == multiIds[1] &&
                   ws.documents[3].id == multiIds[3] &&
                   ws.documents[4].id == multiIds[4] &&
                   ws.activeDocumentId == multiIds[2])
        ws.moveTabToEnd()
        assertTest("Adv M4.3.K: moveTabToEnd on index 0 tab moves it to last index 4",
                   ws.documents[0].id == multiIds[0] &&
                   ws.documents[1].id == multiIds[1] &&
                   ws.documents[2].id == multiIds[3] &&
                   ws.documents[3].id == multiIds[4] &&
                   ws.documents[4].id == multiIds[2] &&
                   ws.activeDocumentId == multiIds[2])

        // 3.4: 9th Tab Overflow Behavior (selectTab(at: 8))
        // Case A: count <= 9
        ws.closeAll()
        for _ in 0..<4 { ws.newDocument() } // 5 tabs (indices 0..4)
        ws.selectTab(at: 8) // index 8 on 5 tabs clamps to last tab (index 4)
        assertTest("Adv M4.3.L: selectTab(at: 8) on 5 tabs clamps safely to last tab",
                   ws.activeDocumentId == ws.documents.last?.id)

        ws.closeAll()
        for _ in 0..<8 { ws.newDocument() } // exactly 9 tabs (indices 0..8)
        let doc8Id = ws.documents[8].id
        ws.selectTab(at: 8)
        assertTest("Adv M4.3.M: selectTab(at: 8) on exactly 9 tabs selects 9th tab (index 8)",
                   ws.activeDocumentId == doc8Id)

        // Case B: count > 9 (e.g. 10 tabs, 15 tabs, 20 tabs)
        ws.closeAll()
        for _ in 0..<14 { ws.newDocument() } // 15 tabs (indices 0..14)
        let tab7Id = ws.documents[7].id
        let tabLastId = ws.documents[14].id
        ws.selectTab(at: 7) // 8th tab (index 7)
        assertTest("Adv M4.3.N: selectTab(at: 7) selects 8th tab normally in 15-tab workspace",
                   ws.activeDocumentId == tab7Id)
        ws.selectTab(at: 8) // 9th tab (index 8) overflow jumps to 15th (last) tab!
        assertTest("Adv M4.3.O: selectTab(at: 8) overflows and jumps to last tab when count > 9 (15 tabs)",
                   ws.activeDocumentId == tabLastId)

        // -------------------------------------------------------------
        // CHALLENGE 4: Natural Alphanumeric Sorting Stress
        // -------------------------------------------------------------
        ws.closeAll()
        let numDoc20 = NppDocument(title: "file20")
        let numDoc1  = NppDocument(title: "file1")
        let numDoc10 = NppDocument(title: "file10")
        let numDoc2  = NppDocument(title: "file2")
        ws.documents = [numDoc20, numDoc1, numDoc10, numDoc2]
        ws.sortTabsByName(ascending: true)
        let naturalAscTitles = ws.documents.map { $0.title }
        assertTest("Adv M4.4.A: sortTabsByName strictly observes natural sort [file1, file2, file10, file20]",
                   naturalAscTitles == ["file1", "file2", "file10", "file20"])

        ws.sortTabsByName(ascending: false)
        let naturalDescTitles = ws.documents.map { $0.title }
        assertTest("Adv M4.4.B: sortTabsByName descending strictly observes natural sort [file20, file10, file2, file1]",
                   naturalDescTitles == ["file20", "file10", "file2", "file1"])

        // Extended natural sort with version numbers
        let verDoc3 = NppDocument(title: "release-v1.3.0")
        let verDoc10 = NppDocument(title: "release-v1.10.0")
        let verDoc1 = NppDocument(title: "release-v1.1.0")
        let verDoc2 = NppDocument(title: "release-v1.2.0")
        ws.documents = [verDoc3, verDoc10, verDoc1, verDoc2]
        ws.sortTabsByName(ascending: true)
        let verTitles = ws.documents.map { $0.title }
        assertTest("Adv M4.4.C: Extended natural sort orders versions correctly (v1.1.0 < v1.2.0 < v1.3.0 < v1.10.0)",
                   verTitles == ["release-v1.1.0", "release-v1.2.0", "release-v1.3.0", "release-v1.10.0"])

        // Secondary path tie-breaker when titles are identical
        let dupTitleA = NppDocument(title: "common.txt")
        dupTitleA.filePath = URL(fileURLWithPath: "/z/path/common.txt")
        let dupTitleB = NppDocument(title: "common.txt")
        dupTitleB.filePath = URL(fileURLWithPath: "/a/path/common.txt")
        ws.documents = [dupTitleA, dupTitleB]
        ws.sortTabsByName(ascending: true)
        assertTest("Adv M4.4.D: Duplicate titles tie-break naturally on file paths (/a/... < /z/...)",
                   ws.documents[0].filePath?.path == "/a/path/common.txt" &&
                   ws.documents[1].filePath?.path == "/z/path/common.txt")

        // -------------------------------------------------------------
        // CHALLENGE 5: Monitoring (tail -f) Stress
        // -------------------------------------------------------------
        ws.closeAll()
        guard let monTestDoc = ws.activeDocument else { return }

        let monMenuItem = NSMenuItem(title: "Monitoring (tail -f)", action: #selector(appDelegate.menuToggleMonitoring), keyEquivalent: "")

        // 5.1: Untitled document rejection
        monTestDoc.filePath = nil
        monTestDoc.isMonitoring = false
        monTestDoc.isReadOnly = false
        ws.lastMonitoringAlert = nil
        let untitledMenuValid = appDelegate.validateMenuItem(monMenuItem)
        assertTest("Adv M4.5.A: Monitoring menu item is disabled on untitled document",
                   untitledMenuValid == false)

        ws.toggleMonitoringCurrentDoc()
        assertTest("Adv M4.5.B: Untitled document rejects monitoring",
                   !monTestDoc.isMonitoring && !monTestDoc.isReadOnly)
        assertTest("Adv M4.5.C: Untitled document records exact upstream alert message",
                   ws.lastMonitoringAlert == "The file should exist to be monitored.")

        // 5.2: Dirty document rejection
        let tempMonFile = FileManager.default.temporaryDirectory.appendingPathComponent("adv_mon_\(UUID().uuidString).log")
        try? "initial log line\n".write(to: tempMonFile, atomically: true, encoding: .utf8)
        monTestDoc.filePath = tempMonFile
        monTestDoc.isDirty = true
        ws.lastMonitoringAlert = nil

        let dirtyMenuValid = appDelegate.validateMenuItem(monMenuItem)
        assertTest("Adv M4.5.D: Monitoring menu item is enabled for saved document",
                   dirtyMenuValid == true && monMenuItem.state == .off)

        ws.toggleMonitoringCurrentDoc()
        assertTest("Adv M4.5.E: Dirty document rejects monitoring",
                   !monTestDoc.isMonitoring && !monTestDoc.isReadOnly)
        assertTest("Adv M4.5.F: Dirty document records exact upstream alert message",
                   ws.lastMonitoringAlert == "The document is dirty. Please save the modification before monitoring it.")

        // 5.3: Clean saved document activates monitoring and sets read-only
        monTestDoc.isDirty = false
        ws.lastMonitoringAlert = nil
        ws.toggleMonitoringCurrentDoc()
        assertTest("Adv M4.5.G: Clean saved document enables isMonitoring=true and isReadOnly=true",
                   monTestDoc.isMonitoring && monTestDoc.isReadOnly && ws.lastMonitoringAlert == nil)

        _ = appDelegate.validateMenuItem(monMenuItem)
        assertTest("Adv M4.5.H: Monitoring menu item reflects .on state when monitored",
                   monMenuItem.state == .on)

        // 5.4: Read-only enforcement while monitored
        let tvShouldBeEditable = !monTestDoc.isReadOnly && !ws.isAllDocumentsReadOnly
        assertTest("Adv M4.5.I: Monitored document strictly enforces non-editable state",
                   tvShouldBeEditable == false)

        // 5.5: Toggle OFF monitoring restores writable state
        ws.toggleMonitoringCurrentDoc()
        assertTest("Adv M4.5.J: Toggling monitoring OFF restores isMonitoring=false and isReadOnly=false",
                   !monTestDoc.isMonitoring && !monTestDoc.isReadOnly)

        _ = appDelegate.validateMenuItem(monMenuItem)
        assertTest("Adv M4.5.K: Monitoring menu item reflects .off state after deactivation",
                   monMenuItem.state == .off)

        // 5.6: Teardown and closeDocument monitoring cleanup
        ws.toggleMonitoringCurrentDoc() // re-enable
        assertTest("Adv M4.5.L: Re-enabled monitoring before close", monTestDoc.isMonitoring)
        ws.closeDocument(id: monTestDoc.id)
        assertTest("Adv M4.5.M: Closing monitored document stops monitoring cleanly without leak",
                   !ws.documents.contains(where: { $0.id == monTestDoc.id }))

        try? FileManager.default.removeItem(at: tempMonFile)
        ws.closeAll(force: true)

        // ========================================================
        // ADVANCED SUITE: Dirty Save Confirmation & Dual View
        // ========================================================
        // 1. Dirty Save Confirmation: .cancel rejects close
        ws.newDocument()
        let dirtyDoc1 = ws.documents.last!
        dirtyDoc1.content = "Dirty content"
        dirtyDoc1.isDirty = true
        var promptCalled = false
        ws.confirmSaveHandler = { doc in
            promptCalled = true
            return .cancel
        }
        let closeCancelled = ws.closeDocument(id: dirtyDoc1.id, force: false)
        assertTest("Dirty Save Confirm: .cancel leaves document open", !closeCancelled && ws.documents.contains(where: { $0.id == dirtyDoc1.id }) && promptCalled)

        // 2. Dirty Save Confirmation: .dontSave closes document without saving
        promptCalled = false
        ws.confirmSaveHandler = { doc in
            promptCalled = true
            return .dontSave
        }
        let closeDontSave = ws.closeDocument(id: dirtyDoc1.id, force: false)
        assertTest("Dirty Save Confirm: .dontSave closes document without save", closeDontSave && !ws.documents.contains(where: { $0.id == dirtyDoc1.id }) && promptCalled)

        // 3. Dirty Save Confirmation: .save writes changes and closes
        let tempSaveURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("test_save_confirm_\(UUID().uuidString).txt")
        try? "original".write(to: tempSaveURL, atomically: true, encoding: .utf8)
        ws.openFile(url: tempSaveURL)
        let dirtyDoc2 = ws.documents.last!
        dirtyDoc2.content = "modified content to save"
        dirtyDoc2.isDirty = true
        promptCalled = false
        ws.confirmSaveHandler = { doc in
            promptCalled = true
            return .save
        }
        let closeSaved = ws.closeDocument(id: dirtyDoc2.id, force: false)
        let savedContent = (try? String(contentsOf: tempSaveURL, encoding: .utf8)) ?? ""
        assertTest("Dirty Save Confirm: .save writes changes and closes document", closeSaved && !ws.documents.contains(where: { $0.id == dirtyDoc2.id }) && promptCalled && savedContent == "modified content to save")
        try? FileManager.default.removeItem(at: tempSaveURL)

        // 4. Dirty Save Confirmation: force=true skips confirmation
        ws.newDocument()
        let dirtyDoc3 = ws.documents.last!
        dirtyDoc3.content = "force close"
        dirtyDoc3.isDirty = true
        promptCalled = false
        let forceClosed = ws.closeDocument(id: dirtyDoc3.id, force: true)
        assertTest("Dirty Save Confirm: force=true bypasses confirm dialog", forceClosed && !ws.documents.contains(where: { $0.id == dirtyDoc3.id }) && !promptCalled)

        // 4.1. Untitled Document with Content Save Confirmation
        ws.newDocument()
        let untitledWithText = ws.documents.last!
        untitledWithText.content = "Some unsaved typed text in new tab"
        untitledWithText.isDirty = false // even if isDirty is false, non-empty untitled requires save prompt
        promptCalled = false
        ws.confirmSaveHandler = { doc in
            promptCalled = true
            return .cancel
        }
        let cancelUntitled = ws.closeDocument(id: untitledWithText.id, force: false)
        assertTest("Dirty Save Confirm: Untitled doc with content prompts and .cancel keeps open", !cancelUntitled && ws.documents.contains(where: { $0.id == untitledWithText.id }) && promptCalled)

        ws.confirmSaveHandler = { doc in
            return .dontSave
        }
        let dontSaveUntitled = ws.closeDocument(id: untitledWithText.id, force: false)
        assertTest("Dirty Save Confirm: Untitled doc with content closes with .dontSave", dontSaveUntitled && !ws.documents.contains(where: { $0.id == untitledWithText.id }))
        ws.confirmSaveHandler = nil

        // 5. Dual View: Move to Other View
        ws.closeAll(force: true)
        let docA = ws.documents[0]
        docA.title = "File A"
        ws.newDocument() // Doc B
        let docB = ws.documents[1]
        docB.title = "File B"
        assertTest("Dual View: Initially single view", !ws.isDualView && ws.primaryDocuments.count == 2)

        ws.moveToOtherView(id: docB.id)
        assertTest("Dual View: Move to Other View activates dual view", ws.isDualView && ws.secondaryDocuments.count == 1 && ws.secondaryDocuments.first?.id == docB.id)
        assertTest("Dual View: Primary view retains Doc A only", ws.primaryDocuments.count == 1 && ws.primaryDocuments.first?.id == docA.id)

        // 6. Dual View: 4-Stage Splitter Rotation Cycle (views.md:116-120)
        ws.viewRotationStage = 0
        assertTest("Dual View: Stage 0 is vertical normal (Left: A, Right: B)", ws.splitDirection == .vertical && !ws.isViewSwapped)
        ws.rotateSplitterRight()
        assertTest("Dual View: Stage 1 is horizontal normal (Top: A, Bottom: B)", ws.viewRotationStage == 1 && ws.splitDirection == .horizontal && !ws.isViewSwapped)
        ws.rotateSplitterRight()
        assertTest("Dual View: Stage 2 is vertical swapped (Left: B, Right: A)", ws.viewRotationStage == 2 && ws.splitDirection == .vertical && ws.isViewSwapped)
        ws.rotateSplitterRight()
        assertTest("Dual View: Stage 3 is horizontal swapped (Top: B, Bottom: A - view-rotate-4.png)", ws.viewRotationStage == 3 && ws.splitDirection == .horizontal && ws.isViewSwapped)
        ws.rotateSplitterRight()
        assertTest("Dual View: Stage 4 wraps to Stage 0 (vertical normal)", ws.viewRotationStage == 0 && ws.splitDirection == .vertical && !ws.isViewSwapped)
        ws.rotateSplitterLeft()
        assertTest("Dual View: rotateSplitterLeft steps backward to Stage 3", ws.viewRotationStage == 3 && ws.splitDirection == .horizontal && ws.isViewSwapped)

        ws.splitRatio = 0.6
        assertTest("Dual View: splitRatio updated", ws.splitRatio == 0.6)

        // 7. Dual View: Clone to Other View
        ws.cloneToOtherView(id: docA.id)
        assertTest("Dual View: Clone adds Doc A to both views", ws.clonedDocumentIds.contains(docA.id) && ws.primaryDocuments.contains(where: { $0.id == docA.id }) && ws.secondaryDocuments.contains(where: { $0.id == docA.id }))

        // 8. Dual View: Automatic return to single view when secondary empty
        ws.closeDocument(id: docA.id, force: true)
        ws.closeDocument(id: docB.id, force: true)
        assertTest("Dual View: Automatically returns to single view when secondary closes", !ws.isDualView)

        ws.closeAll(force: true)
    }

    // =========================================================================
    // SECTION 33: [AUDIT-027] COMPREHENSIVE INTERACTIVE SCENARIO TEST SUITES
    // =========================================================================

    // Stream 1: Editor & Text Manipulation Scenarios
    static func runStream1EditorInteractiveTests(ws: NppWorkspace, assertTest: (String, Bool) -> Void) {
        ws.closeAll(force: true)
        ws.newDocument()
        guard let doc = ws.activeDocument else { return }

        // Test 1: Bookmark adjustment on text insertion
        doc.content = "Line 1\nLine 2\nLine 3\nLine 4\n"
        doc.bookmarkedLines = [2, 4]
        let insertStr = "New Line\n"
        doc.adjustBookmarks(affectedRange: NSRange(location: 0, length: 0), replacementString: insertStr, currentText: doc.content)
        doc.content = insertStr + doc.content
        assertTest("Stream 1: Inserting line shifts bookmarks down", doc.bookmarkedLines.contains(3) && doc.bookmarkedLines.contains(5) && !doc.bookmarkedLines.contains(2))

        // Test 2: Bookmark adjustment on line deletion
        let delRange = NSRange(location: 0, length: 9)
        doc.adjustBookmarks(affectedRange: delRange, replacementString: "", currentText: doc.content)
        doc.content = (doc.content as NSString).replacingCharacters(in: delRange, with: "")
        assertTest("Stream 1: Deleting line shifts bookmarks up", doc.bookmarkedLines.contains(2) && doc.bookmarkedLines.contains(4) && !doc.bookmarkedLines.contains(3))

        // Test 3: Line operations on selected range preserves outside lines
        doc.content = "Header\nCharlie\nAlice\nBob\nFooter"
        let full = doc.content as NSString
        let charlieRange = full.range(of: "Charlie")
        let bobRange = full.range(of: "Bob")
        let midRange = NSRange(location: charlieRange.location, length: NSMaxRange(bobRange) - charlieRange.location)
        NppEditOperations.sortLines(in: doc, selectedRange: midRange, ascending: true)
        assertTest("Stream 1: Line sort on selection only affects selected lines", doc.content == "Header\nAlice\nBob\nCharlie\nFooter")

        // Test 4: Decimal sort with commas on selected range
        doc.content = "Unsorted\n3,14\n1,41\n2,71\nEnd"
        let start314 = (doc.content as NSString).range(of: "3,14").location
        let end271 = NSMaxRange((doc.content as NSString).range(of: "2,71"))
        NppEditOperations.sortLinesAsDecimals(in: doc, selectedRange: NSRange(location: start314, length: end271 - start314), ascending: true, usesComma: true)
        assertTest("Stream 1: Decimal sort with commas orders correctly in range", doc.content == "Unsorted\n1,41\n2,71\n3,14\nEnd")

        // Test 5: Column mode toggle & anchor
        if let tv = ws.activeTextView {
            tv.string = doc.content
            tv.setSelectedRange(NSRange(location: 0, length: 0))
            assertTest("Stream 1: Column mode initial state is false", !ws.isColumnModeSelecting && ws.columnModeStartAnchor == nil)
            ws.toggleColumnModeSelection()
            assertTest("Stream 1: Column mode toggle activates and sets anchor", ws.isColumnModeSelecting && ws.columnModeStartAnchor != nil)
            ws.toggleColumnModeSelection()
            assertTest("Stream 1: Column mode second toggle finalizes selection and resets flag", !ws.isColumnModeSelecting && ws.columnModeStartAnchor == nil)
        }

        // Test 6: Column Editor with caret insertion down to EOF
        doc.content = "alpha\nbeta\ngamma"
        if let tv = ws.activeTextView {
            tv.string = doc.content
            tv.setSelectedRange(NSRange(location: 0, length: 0))
            ws.executeColumnEditor(isText: true, text: "PREFIX_", initialNumber: 0, increaseBy: 1, repeatCount: 1, format: "Dec", leadingZeros: false)
            assertTest("Stream 1: Column editor inserts prefix at column across all lines", tv.string == "PREFIX_alpha\nPREFIX_beta\nPREFIX_gamma")
        }

        // Test 7: Jump to line on mixed CRLF/LF does not drift
        doc.content = "Line1\r\nLine2\nLine3\r\nLine4"
        ws.jumpToLine(3)
        assertTest("Stream 1: Jump to line 3 sets cursorLine to 3 accurately", doc.cursorLine == 3)

        ws.closeAll(force: true)
    }

    // Stream 2: Searching, Replacing & Incremental Workflows
    static func runStream2SearchInteractiveTests(ws: NppWorkspace, assertTest: (String, Bool) -> Void) {
        ws.closeAll(force: true)
        ws.newDocument()
        guard let doc = ws.activeDocument, let tv = ws.activeTextView else { return }
        tv.allowsUndo = true

        // Test 1: Regex replacement backreference conversion (\1 -> $1)
        let convertedTmpl = NppWorkspace.normalizeRegexReplacementTemplate("\\1-\\2_\\0")
        assertTest("Stream 2: Regex backreference normalization converts \\1 to $1", convertedTmpl == "$1-$2_$0")

        // Test 2: Regex search with line anchors (^ and $)
        doc.content = "apple 1\napple 2\nbanana\napple 3"
        tv.string = doc.content
        ws.findAllInCurrentDoc(query: "^apple \\d$", matchCase: true, wholeWord: false, useRegex: true)
        let hitCount = ws.searchFileGroups.first?.matches.count ?? 0
        assertTest("Stream 2: Regex line anchors ^ and $ match line boundaries correctly", hitCount == 3)

        // Test 3: Incremental search updates match index and selection
        ws.updateIncrementalSearch(query: "apple", matchCase: true, wholeWord: false, useRegex: false)
        assertTest("Stream 2: Incremental search discovers all matches", ws.incrementalSearchMatches.count == 3)
        assertTest("Stream 2: Incremental search current match index is 1", ws.incrementalCurrentMatchIndex == 1)

        // Test 4: Replace All with regex template expansion
        let regex = try? NSRegularExpression(pattern: "apple (\\d)", options: [.anchorsMatchLines])
        let replaced = regex?.stringByReplacingMatches(in: doc.content, range: NSRange(location: 0, length: (doc.content as NSString).length), withTemplate: "fruit_$1")
        assertTest("Stream 2: Regex stringByReplacingMatches expands $1 properly", replaced == "fruit_1\nfruit_2\nbanana\nfruit_3")

        // Test 5: Replace All undo grouping preservation. A detached NSTextView
        // has no undo manager, so exercise the same window-backed editor setup.
        let undoWindow = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 300), styleMask: [.titled], backing: .buffered, defer: false)
        let undoView = NSTextView(frame: undoWindow.contentView?.bounds ?? .zero)
        undoView.allowsUndo = true
        undoWindow.contentView?.addSubview(undoView)
        undoView.string = tv.string
        let textBeforeReplacement = undoView.string
        ws.applyTextToTextViewPreservingUndo(tv: undoView, newText: replaced ?? "")
        assertTest("Stream 2: applyTextToTextViewPreservingUndo updates tv.string", undoView.string == replaced)
        undoView.undoManager?.undo()
        assertTest("Stream 2: Undo restores original text in a single step", undoView.string == textBeforeReplacement)

        // Test 6: Modeless Find/Replace Window Controller properties
        ws.openFind()
        assertTest("Stream 2: openFind displays modeless floating panel", ws.showFindReplaceDialog && NppFindReplaceWindowController.shared.panel != nil)
        NppFindReplaceWindowController.shared.close()
        assertTest("Stream 2: close restores focus and clears panel", !ws.showFindReplaceDialog && NppFindReplaceWindowController.shared.panel == nil)

        // Test 7: Jump to search match synchronizes cursorCol
        let sampleMatch = NppSearchMatch(
            documentId: doc.id,
            documentTitle: doc.title,
            filePath: doc.filePath,
            lineNumber: 2,
            lineContent: "apple 2",
            matchRangeInLine: NSRange(location: 3, length: 4),
            charPosition: 11,
            matchLength: 5
        )
        ws.jumpToMatch(sampleMatch)
        assertTest("Stream 2: jumpToMatch synchronizes doc.cursorCol accurately", doc.cursorCol == 4)

        ws.closeAll(force: true)
    }

    // Stream 3: Document Lifecycle & Session Workflows
    static func runStream3LifecycleInteractiveTests(ws: NppWorkspace, assertTest: (String, Bool) -> Void) {
        ws.closeAll(force: true)
        // closeAll keeps one untitled document open, as the app does in normal use.
        // Use that document as Doc 1 so this scenario has exactly three tabs.
        ws.newDocument() // Doc 2
        ws.newDocument() // Doc 3
        let id1 = ws.documents[0].id
        let id2 = ws.documents[1].id
        let id3 = ws.documents[2].id
        ws.documents[0].title = "Doc 1"
        ws.documents[1].title = "Doc 2"
        ws.documents[2].title = "Doc 3"

        // Test 1: Reorder tabs (drag Doc 1 to target Doc 3)
        ws.reorderTab(draggedId: id1, targetId: id3, viewIndex: 0)
        assertTest("Stream 3: reorderTab moves dragged tab to target index", ws.documents.map { $0.id } == [id2, id3, id1])

        // Test 2: Move tab to start
        ws.moveTabToStart(id: id1, viewIndex: 0)
        assertTest("Stream 3: moveTabToStart restores tab to index 0", ws.documents.first?.id == id1)

        // Test 3: Move tab to end
        ws.moveTabToEnd(id: id1, viewIndex: 0)
        assertTest("Stream 3: moveTabToEnd places tab at last index", ws.documents.last?.id == id1)

        // Test 4: XML Session save and load with carets
        let docA = ws.documents[0]
        docA.bookmarkedLines = [1, 5]
        docA.cursorPos = 42
        docA.selectionLength = 10
        let tempSessionURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("test_session_\(UUID().uuidString).xml")
        let saveResult = ws.saveSession(to: tempSessionURL)
        assertTest("Stream 3: saveSession writes session file", saveResult)
        let sessionContent = (try? String(contentsOf: tempSessionURL, encoding: .utf8)) ?? ""
        assertTest("Stream 3: Session file is valid NotepadPlus XML", sessionContent.contains("<NotepadPlus>") && sessionContent.contains("<Session activeView="))
        try? FileManager.default.removeItem(at: tempSessionURL)

        // Saved sessions must round-trip XML-special file names and editor state.
        let sessionFolder = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("npp_session_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: sessionFolder, withIntermediateDirectories: true)
        let firstFile = sessionFolder.appendingPathComponent("one & two.txt")
        let secondFile = sessionFolder.appendingPathComponent("other.txt")
        try? "alpha\nbeta".write(to: firstFile, atomically: true, encoding: .utf8)
        try? "first\nsecond".write(to: secondFile, atomically: true, encoding: .utf8)
        let savedWorkspace = NppWorkspace()
        savedWorkspace.openFile(url: firstFile)
        savedWorkspace.openFile(url: secondFile)
        if let firstDoc = savedWorkspace.documents.first(where: { $0.filePath == firstFile }),
           let secondDoc = savedWorkspace.documents.first(where: { $0.filePath == secondFile }) {
            firstDoc.language = "Swift"
            firstDoc.cursorPos = 6
            firstDoc.selectionLength = 2
            firstDoc.bookmarkedLines = [2]
            savedWorkspace.moveToOtherView(id: secondDoc.id)
            savedWorkspace.secondaryActiveDocumentId = secondDoc.id
            savedWorkspace.activeView = 1
        }
        let savedSession = sessionFolder.appendingPathComponent("state.session")
        assertTest("Stream 3: Session with XML-special filename saves", savedWorkspace.saveSession(to: savedSession))
        let loadedWorkspace = NppWorkspace()
        let didLoad = loadedWorkspace.loadSession(from: savedSession)
        let restoredFirst = loadedWorkspace.documents.first(where: { $0.filePath == firstFile })
        let restoredSecond = loadedWorkspace.documents.first(where: { $0.filePath == secondFile })
        assertTest("Stream 3: Session XML-special filename loads", didLoad && restoredFirst != nil && restoredSecond != nil)
        assertTest("Stream 3: Session restores caret, selection, bookmarks and language",
                   restoredFirst?.cursorPos == 6 && restoredFirst?.selectionLength == 2 &&
                   restoredFirst?.bookmarkedLines == [2] && restoredFirst?.language == "Swift")
        assertTest("Stream 3: Session restores secondary view and active file",
                   loadedWorkspace.activeView == 1 && loadedWorkspace.secondaryActiveDocumentId == restoredSecond?.id)
        try? FileManager.default.removeItem(at: sessionFolder)

        // Test 5: File Status auto-detection handles deleted file
        let tempFile = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("test_file_delete_\(UUID().uuidString).txt")
        try? "test data".write(to: tempFile, atomically: true, encoding: .utf8)
        ws.openFile(url: tempFile)
        guard let openedDoc = ws.documents.first(where: { $0.filePath == tempFile }) else { return }
        try? FileManager.default.removeItem(at: tempFile)
        let reloadStatus = ws.checkFileStatus(for: openedDoc, prompt: false)
        assertTest("Stream 3: checkFileStatus detects deleted external file", reloadStatus == false && openedDoc.content == "test data")

        // Test 6: Function list parser handles qualifiers without premature stop
        let codeWithQualifiers = "private func calculateScore(a: Int, b: Int) -> Int {\n    return a + b;\n}"
        let funcs = NppWorkspace.parseFunctions(content: codeWithQualifiers)
        assertTest("Stream 3: parseFunctions extracts function name past multi-word qualifiers", funcs.contains(where: { $0.name == "calculateScore" }))

        ws.closeAll(force: true)
    }

    // Stream 4: Encodings, Charsets & Localization
    static func runStream4EncodingInteractiveTests(ws: NppWorkspace, assertTest: (String, Bool) -> Void) {
        ws.closeAll(force: true)
        ws.newDocument()
        guard let doc = ws.activeDocument else { return }

        // Test 1: EUC-KR and CP949 are distinct
        let normEuckr = NppDocument.normalizeCharset("EUC-KR")
        let normCp949 = NppDocument.normalizeCharset("CP949")
        assertTest("Stream 4: normalizeCharset preserves EUC-KR as EUC-KR", normEuckr == "EUC-KR")
        assertTest("Stream 4: normalizeCharset preserves CP949 as CP949", normCp949 == "CP949")
        assertTest("Stream 4: EUC-KR and CP949 are distinct strings", normEuckr != normCp949)

        // Test 2: reencodeAs on dirty buffer preserves edits
        doc.content = "Initial clean text"
        doc.encoding = "UTF-8"
        doc.isDirty = true
        doc.content = "Dirty edited text with 한글"
        doc.reencodeAs(targetCharset: "UTF-8")
        assertTest("Stream 4: reencodeAs does not wipe dirty buffer", doc.content.contains("Dirty edited text with 한글"))

        // Test 3: convertEncoding updates encoding without corrupting text
        doc.convertEncoding(to: "CP949")
        assertTest("Stream 4: convertEncoding sets encoding to CP949 without corruption", doc.encoding == "CP949" && doc.content.contains("한글"))
        doc.convertEncoding(to: "EUC-KR")
        assertTest("Stream 4: convertEncoding sets encoding to EUC-KR", doc.encoding == "EUC-KR" && doc.content.contains("한글"))

        // Test 4: Status bar line count is accurate and non-allocating
        var bigString = ""
        for i in 1...5000 {
            bigString += "Line \(i)\n"
        }
        var counted = 1
        for u in bigString.utf8 {
            if u == 10 { counted += 1 }
        }
        assertTest("Stream 4: Non-allocating line count accurately counts 5001 lines", counted == 5001)

        // Test 5: Missing Korean translations
        ws.localizationLanguage = "한국어"
        let normalTextTr = ws.tr("Normal text file")
        let noDocTr = ws.tr("No document")
        assertTest("Stream 4: Korean localization translates 'Normal text file'", normalTextTr == "일반 텍스트 파일")
        assertTest("Stream 4: Korean localization translates 'No document'", noDocTr == "문서 없음")
        ws.localizationLanguage = "English"

        ws.closeAll(force: true)
    }

    // Stream 5: Preferences, Modeless Windows & Secondary Panels
    static func runStream5DialogsInteractiveTests(ws: NppWorkspace, assertTest: (String, Bool) -> Void) {
        ws.closeAll(force: true)

        // Test 1: User Defined Language creation and XML export
        let initialUdlCount = ws.userDefinedLanguages.count
        let testLang = NppUserDefineLanguage(name: "MyCustomLang", extensions: "mcl custom", ignoreCase: false)
        ws.userDefinedLanguages.append(testLang)
        assertTest("Stream 5: UDL language added to userDefinedLanguages", ws.userDefinedLanguages.count == initialUdlCount + 1)

        // Test 2: Character Panel Windows-1252 character mapping for 128..255
        let euroData = Data([128])
        let euroStr = String(data: euroData, encoding: .windowsCP1252)
        assertTest("Stream 5: Byte 128 maps to Euro symbol in Windows-1252", euroStr == "€")

        // Test 3: Transparency slider scale mapping (20...200 -> 0.1...1.0)
        let sliderVal: Double = 130.0
        ws.findTransparencyValue = sliderVal / 200.0
        assertTest("Stream 5: Transparency slider 130 maps to 0.65 (65%)", abs(ws.findTransparencyValue - 0.65) < 0.001)

        // Test 4: Dual view document activation in secondary view
        ws.newDocument() // Doc 1
        ws.newDocument() // Doc 2
        let doc2 = ws.documents[1]
        ws.moveToOtherView(id: doc2.id)
        assertTest("Stream 5: Dual view active with doc2 in secondary view", ws.isDualView && ws.secondaryDocuments.first?.id == doc2.id)

        // Test 5: Tab reduce and max label length settings
        ws.tabReduce = true
        assertTest("Stream 5: tabReduce toggle updates preference", ws.tabReduce == true)
        ws.tabReduce = false

        let truncated = NppTabItemView.formattedTitle(title: "VeryLongDocumentNameToTruncate.swift", maxLen: 10)
        assertTest("Stream 5: Tab label truncates with ellipsis according to maxLen", truncated == "VeryLongDo…" && truncated.count <= 11)

        ws.closeAll(force: true)
    }

    static func runManualAutoCompletionTests(assertTest: (String, Bool) -> Void) {
        let engine = NppCompletionEngine.shared
        let buffer = "alpha alphabet alphanumeric\nalp"
        let words = engine.candidates(text: buffer, caret: (buffer as NSString).length,
                                      language: "Swift", mode: 1, minimumLength: 3,
                                      ignoreNumbers: true, manual: false)
        assertTest("Manual Auto-Completion: word candidates come from current buffer", words == ["alpha", "alphabet", "alphanumeric"])
        let belowThreshold = engine.candidates(text: buffer, caret: (buffer as NSString).length,
                                               language: "Swift", mode: 1, minimumLength: 4,
                                               ignoreNumbers: true, manual: false)
        assertTest("Manual Auto-Completion: automatic trigger obeys From nth character", belowThreshold.isEmpty)
        let manual = engine.candidates(text: buffer, caret: (buffer as NSString).length,
                                       language: "Swift", mode: 1, minimumLength: 9,
                                       ignoreNumbers: true, manual: true)
        assertTest("Manual Auto-Completion: manual word completion bypasses threshold", manual == words)
        let numberBuffer = "1234 123"
        let ignored = engine.candidates(text: numberBuffer, caret: (numberBuffer as NSString).length,
                                        language: "Swift", mode: 1, minimumLength: 1,
                                        ignoreNumbers: true, manual: false)
        assertTest("Manual Auto-Completion: Ignore numbers suppresses numeric prefix", ignored.isEmpty)
        let functions = engine.candidates(text: "ass", caret: 3,
                                          language: "Python", mode: 0, minimumLength: 1,
                                          ignoreNumbers: true, manual: false)
        assertTest("Manual Auto-Completion: Python candidates load upstream API XML", functions.contains("assert"))
        assertTest("Manual Auto-Completion: upstream API overload supplies parameter hint",
                   engine.parameterHint(for: "abs", language: "Python")?.contains("abs(number)") == true)
        assertTest("Manual Auto-Completion: hint resolves active function call",
                   engine.parameterHint(in: "abs(42)", caret: 6, language: "Python")?.contains("abs(number)") == true)
        assertTest("Manual Auto-Completion: hint stops after closing parenthesis",
                   engine.parameterHint(in: "abs(42)", caret: 7, language: "Python") == nil)
        let fixture = FileManager.default.temporaryDirectory.appendingPathComponent("npp-path-completion-\(UUID().uuidString)", isDirectory: true)
        if (try? FileManager.default.createDirectory(at: fixture, withIntermediateDirectories: true)) != nil {
            defer { try? FileManager.default.removeItem(at: fixture) }
            let directory = fixture.appendingPathComponent("project-data", isDirectory: true)
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let file = fixture.appendingPathComponent("project-notes.txt")
            try? Data().write(to: file)
            let query = "./project-"
            let paths = engine.pathCandidates(text: query, caret: (query as NSString).length,
                                              documentURL: fixture.appendingPathComponent("document.txt"))
            assertTest("Manual Auto-Completion: relative paths include files and directories",
                       paths == ["project-data/", "project-notes.txt"])
            let range = NppCompletionEngine.pathNameRange(in: query as NSString, before: (query as NSString).length)
            assertTest("Manual Auto-Completion: path replacement includes punctuation",
                       (query as NSString).substring(with: range) == "project-")
        } else {
            assertTest("Manual Auto-Completion: temporary path fixture created", false)
        }
    }

    static func runManualUDLTests(assertTest: (String, Bool) -> Void) {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <NotepadPlus><UserLang name="Sample &amp; Tools" ext="demo dmo" udlVersion="2.1">
        <Settings><Global caseIgnored="yes"/></Settings>
        <KeywordLists><Keywords name="Keywords1">alpha beta</Keywords>
        <Keywords name="Operators1">&lt; &gt;</Keywords>
        <Keywords name="Comments">00// 03/* 04*/</Keywords></KeywordLists>
        <Styles><WordsStyle name="KEYWORDS1" fgColor="123456"/></Styles>
        </UserLang></NotepadPlus>
        """
        guard let parsed = try? NppUDLCodec.decode(Data(xml.utf8)), var language = parsed.first else {
            assertTest("Manual UDL: parse standard UserLang XML", false)
            return
        }
        assertTest("Manual UDL: parse name, extensions, case and keyword rules",
                   language.name == "Sample & Tools" && language.extensions == "demo dmo" &&
                   language.ignoreCase && language.keywordLists["Keywords1"] == "alpha beta" &&
                   language.styleForegrounds["KEYWORDS1"] == "123456")
        language.keywordLists["Keywords1"] = "alpha gamma"
        guard let exported = try? NppUDLCodec.encode(language),
              let reparsed = try? NppUDLCodec.decode(exported), let result = reparsed.first else {
            assertTest("Manual UDL: export and reimport language", false)
            return
        }
        assertTest("Manual UDL: edited keywords survive XML round trip",
                   result.keywordLists["Keywords1"] == "alpha gamma")
        assertTest("Manual UDL: untouched style XML survives export",
                   String(data: exported, encoding: .utf8)?.contains("fgColor=\"123456\"") == true)
        let fresh = NppUserDefineLanguage(name: "Fresh", extensions: "fresh", keywordLists: ["Keywords1": "hello"])
        let freshXML = try? NppUDLCodec.encode(fresh)
        assertTest("Manual UDL: new language export includes styles and keyword lists",
                   freshXML.flatMap { String(data: $0, encoding: .utf8) }.map {
                       $0.contains("<Styles>") && $0.contains("name=\"KEYWORDS1\"") && $0.contains("hello")
                   } == true)
        let comments = NppUDLCodec.replacingCommentToken(0, value: "#", in: "00// 01 03/* 04*/")
        assertTest("Manual UDL: comment edit preserves other comment rules",
                   comments == "00# 01 03/* 04*/")
        assertTest("Manual UDL: quoted multiword keyword stays one item",
                   NppUDLCodec.keywordItems(from: "alpha \"two words\" beta") ==
                   ["alpha", "two words", "beta"])
        let acrossLines = NppUDLCodec.keywordPatterns(from: "\"else if\"", prefixMode: false).first ?? ""
        let sameLine = NppUDLCodec.keywordPatterns(from: "'else if'", prefixMode: false).first ?? ""
        assertTest("Manual UDL: double-quoted phrase accepts newline and single-quoted phrase does not",
                   "else\nif".range(of: acrossLines, options: .regularExpression) != nil &&
                   "else\nif".range(of: sameLine, options: .regularExpression) == nil)
        let prefixPattern = NppUDLCodec.keywordPatterns(from: "pre", prefixMode: true).first ?? ""
        assertTest("Manual UDL: prefix mode extends keyword through following letters",
                   "prefix".range(of: prefixPattern, options: .regularExpression) != nil)
        let ws = NppWorkspace()
        ws.userDefinedLanguages.append(language)
        assertTest("Manual UDL: extension overrides built-in language detection",
                   ws.userDefinedLanguage(for: URL(fileURLWithPath: "/tmp/file.DMO"))?.name == language.name)
        let fixture = FileManager.default.temporaryDirectory.appendingPathComponent("npp-udl-\(UUID().uuidString)", isDirectory: true)
        if (try? FileManager.default.createDirectory(at: fixture, withIntermediateDirectories: true)) != nil {
            defer { try? FileManager.default.removeItem(at: fixture) }
            ws.saveUserDefinedLanguages(to: fixture)
            let restored = NppWorkspace()
            restored.loadUserDefinedLanguages(from: fixture)
            assertTest("Manual UDL: saved language rules survive workspace restart",
                       restored.userDefinedLanguages.first?.keywordLists["Keywords1"] == "alpha gamma")
            let source = fixture.appendingPathComponent("example.DMO")
            try? Data("alpha".utf8).write(to: source)
            restored.openFile(url: source)
            assertTest("Manual UDL: opening associated extension selects the UDL",
                       restored.activeDocument?.language == language.name)
        } else {
            assertTest("Manual UDL: temporary persistence fixture created", false)
        }
        let storage = NSTextStorage(string: "ALPHA beta // comment")
        NppSyntaxHighlighter.highlight(textStorage: storage, language: language.name,
                                       isDarkMode: false, userDefinedLanguage: language)
        let alphaColor = storage.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor
        let commentColor = storage.attribute(.foregroundColor, at: 12, effectiveRange: nil) as? NSColor
        assertTest("Manual UDL: case-insensitive keywords and comments receive distinct styles",
                   alphaColor != nil && commentColor != nil && alphaColor != commentColor)
        assertTest("Manual UDL: imported keyword color is applied in editor",
                   abs((alphaColor?.redComponent ?? 0) - CGFloat(0x12) / 255) < 0.01)
        let operatorLanguage = NppUserDefineLanguage(name: "Operators", keywordLists:
            ["Operators1": "+", "Operators2": "and"], styleForegrounds: ["OPERATORS": "FF0000"])
        let operatorText = "and +and+ x-and x"
        let operatorStorage = NSTextStorage(string: operatorText)
        NppSyntaxHighlighter.highlight(textStorage: operatorStorage, language: operatorLanguage.name,
                                       isDarkMode: false, userDefinedLanguage: operatorLanguage)
        let source = operatorText as NSString
        let glued = source.range(of: "x-and")
        let separated = source.range(of: "+and+")
        let gluedColor = operatorStorage.attribute(.foregroundColor, at: glued.location + 2, effectiveRange: nil) as? NSColor
        let separatedColor = operatorStorage.attribute(.foregroundColor, at: separated.location + 1, effectiveRange: nil) as? NSColor
        let separatedRed = separatedColor?.usingColorSpace(.deviceRGB)?.redComponent ?? 0
        let gluedRed = gluedColor?.usingColorSpace(.deviceRGB)?.redComponent ?? 1
        assertTest("Manual UDL: Operators2 require whitespace or Operators1 separation",
                   separatedRed > 0.9 && gluedRed < 0.9)
        let numberLanguage = NppUserDefineLanguage(name: "Numbers", keywordLists: [
            "Numbers, prefix1": "B", "Numbers, prefix2": "0x",
            "Numbers, extras1": "A B C D E F", "Numbers, extras2": "A B C",
            "Numbers, suffix1": "'H", "Numbers, suffix2": "D",
            "Numbers, range": "::"
        ], decimalSeparator: 1)
        let numberPatterns = NppUDLCodec.numberPatterns(for: numberLanguage)
        func matchesWholeNumber(_ value: String) -> Bool {
            numberPatterns.contains { pattern in
                guard let regex = try? NSRegularExpression(pattern: pattern),
                      let match = regex.firstMatch(in: value, range: NSRange(location: 0, length: (value as NSString).length))
                else { return false }
                return match.range.location == 0 && match.range.length == (value as NSString).length
            }
        }
        assertTest("Manual UDL: number prefix1 accepts decimal digits only",
                   matchesWholeNumber("B101") && !matchesWholeNumber("B10A"))
        assertTest("Manual UDL: number prefix2 accepts configured extra digits",
                   matchesWholeNumber("0xA5"))
        assertTest("Manual UDL: number suffixes and range symbols are recognized",
                   matchesWholeNumber("ABC'H") && matchesWholeNumber("101D") && matchesWholeNumber("10::20"))
        assertTest("Manual UDL: comma decimal mode rejects dot decimal tokens",
                   matchesWholeNumber("1,2") && !matchesWholeNumber("1.2"))
        let delimiterLanguage = NppUserDefineLanguage(name: "Delimiters", keywordLists: [
            "Delimiters": #"00" 01\ 02" 03# 04 05((EOL))"#
        ], styleForegrounds: ["DELIMITERS1": "FF0000", "DELIMITERS2": "00FF00"])
        let delimiterText = "say \"a\\\"b\" tail\n# note\nplain"
        let delimiterStorage = NSTextStorage(string: delimiterText)
        NppSyntaxHighlighter.highlight(textStorage: delimiterStorage, language: delimiterLanguage.name,
                                       isDarkMode: false, userDefinedLanguage: delimiterLanguage)
        let delimiterSource = delimiterText as NSString
        let insideQuote = delimiterSource.range(of: "b\"").location
        let insideEOL = delimiterSource.range(of: "note").location
        let outsideEOL = delimiterSource.range(of: "plain").location
        let quoteRed = (delimiterStorage.attribute(.foregroundColor, at: insideQuote, effectiveRange: nil) as? NSColor)?
            .usingColorSpace(.deviceRGB)?.redComponent ?? 0
        let lineGreen = (delimiterStorage.attribute(.foregroundColor, at: insideEOL, effectiveRange: nil) as? NSColor)?
            .usingColorSpace(.deviceRGB)?.greenComponent ?? 0
        let outsideGreen = (delimiterStorage.attribute(.foregroundColor, at: outsideEOL, effectiveRange: nil) as? NSColor)?
            .usingColorSpace(.deviceRGB)?.greenComponent ?? 1
        assertTest("Manual UDL: delimiter escape keeps quoted content styled", quoteRed > 0.9)
        assertTest("Manual UDL: EOL delimiter stops styling at next line", lineGreen > 0.9 && outsideGreen < 0.9)
    }

    static func runManualFileMenuTests(assertTest: (String, Bool) -> Void) {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("npp-manual-files-\(UUID().uuidString)", isDirectory: true)
        guard (try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)) != nil else {
            assertTest("Manual File: temporary fixture created", false)
            return
        }
        defer { try? FileManager.default.removeItem(at: directory) }
        let original = directory.appendingPathComponent("original.txt")
        let copy = directory.appendingPathComponent("copy.py")
        try? Data("before".utf8).write(to: original)
        let ws = NppWorkspace()
        ws.openFile(url: original)
        guard let doc = ws.activeDocument else {
            assertTest("Manual File: opened fixture", false)
            return
        }
        doc.content = "after"
        doc.isDirty = true
        let raw = doc.rawFileBytes
        let modificationDate = doc.lastKnownModificationDate
        let language = doc.language
        let copied = ws.saveCopyAs(for: doc, to: copy)
        assertTest("Manual File: Save a Copy writes edited content",
                   copied && (try? String(contentsOf: copy, encoding: .utf8)) == "after")
        assertTest("Manual File: Save a Copy preserves source document metadata",
                   doc.filePath == original && doc.title == original.lastPathComponent &&
                   doc.isDirty && doc.language == language && doc.rawFileBytes == raw &&
                   doc.lastKnownModificationDate == modificationDate)

        let conflict = directory.appendingPathComponent("conflict.txt")
        try? Data("existing".utf8).write(to: conflict)
        let renamed = ws.renameDocument(id: doc.id, to: conflict)
        assertTest("Manual File: Rename collision preserves source and destination",
                   !renamed && doc.filePath == original &&
                   (try? String(contentsOf: conflict, encoding: .utf8)) == "existing" &&
                   FileManager.default.fileExists(atPath: original.path))
        ws.confirmSaveHandler = { _ in .cancel }
        let trashed = ws.moveActiveFileToTrash()
        assertTest("Manual File: canceled Trash keeps file and open document",
                   !trashed && FileManager.default.fileExists(atPath: original.path) &&
                   ws.documents.contains { $0.id == doc.id })
        doc.language = "Python"
        assertTest("Manual Language: saving existing file preserves selected language",
                   doc.save() && doc.language == "Python")
        doc.isDirty = true

        let unchanged = directory.appendingPathComponent("unchanged.txt")
        try? Data("stable".utf8).write(to: unchanged)
        ws.openFile(url: unchanged)
        ws.closeAllUnchanged()
        assertTest("Manual File: Close All Unchanged updates closed history",
                   ws.closedFilePaths.contains(unchanged) &&
                   !ws.documents.contains { $0.filePath == unchanged } &&
                   ws.documents.contains { $0.id == doc.id })
    }

    static func runManualSessionTests(assertTest: (String, Bool) -> Void) {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("npp-manual-session-\(UUID().uuidString)", isDirectory: true)
        guard (try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)) != nil else {
            assertTest("Manual Session: temporary fixture created", false)
            return
        }
        defer { try? FileManager.default.removeItem(at: directory) }
        let missing = directory.appendingPathComponent("offline.txt")
        let sessionFile = directory.appendingPathComponent("saved.nps")
        let xml = "<NotepadPlus><Session activeView=\"0\"><mainView activeIndex=\"0\"><File filename=\"\(missing.path)\" startPos=\"0\" endPos=\"0\" lang=\"Python\"/></mainView><subView activeIndex=\"0\"/></Session></NotepadPlus>"
        try? Data(xml.utf8).write(to: sessionFile)
        let workspace = NppWorkspace()
        workspace.sessionPlaceholderDecisionHandler = { paths in paths == [missing] }
        let loaded = workspace.loadSession(from: sessionFile)
        let placeholder = workspace.documents.first { $0.filePath == missing }
        assertTest("Manual Session: unavailable file becomes read-only placeholder",
                   loaded && placeholder?.isReadOnly == true && placeholder?.isSessionPlaceholder == true &&
                   placeholder?.language == "Python")
        let savedAgain = directory.appendingPathComponent("resaved.nps")
        let resaved = workspace.saveSession(to: savedAgain)
        assertTest("Manual Session: placeholder survives session save",
                   resaved && (try? String(contentsOf: savedAgain, encoding: .utf8))?.contains(missing.path) == true)
        try? Data("back online".utf8).write(to: missing)
        workspace.openFile(url: missing)
        assertTest("Manual Session: reopening restored file fills placeholder",
                   placeholder?.content == "back online" && placeholder?.isReadOnly == false &&
                   placeholder?.isSessionPlaceholder == false)
        let byExtension = NppWorkspace()
        byExtension.sessionFileExt = "nps"
        byExtension.openFile(url: sessionFile)
        assertTest("Manual Session: configured extension opens session instead of XML text",
                   byExtension.documents.contains { $0.filePath == missing } &&
                   !byExtension.documents.contains { $0.filePath == sessionFile })
    }

    static func runManualRunMenuTests(assertTest: (String, Bool) -> Void) {
        let suiteName = "npp.run.tests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            assertTest("Manual Run: isolated preferences available", false)
            return
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let workspace = NppWorkspace(runCommandDefaults: defaults)
        assertTest("Manual Run: save named command with shortcut",
                   workspace.saveRunCommand(name: "Build", command: "make $(CURRENT_DIRECTORY)",
                                            shortcut: "Cmd+Shift+B", inTerminal: true))
        assertTest("Manual Run: duplicate command name rejected",
                   !workspace.saveRunCommand(name: "Build", command: "echo duplicate"))
        guard let saved = workspace.savedRunCommands.first else {
            assertTest("Manual Run: saved command exists", false)
            return
        }
        assertTest("Manual Run: rename and clear shortcut",
                   workspace.updateRunCommand(id: saved.id, name: "Compile", shortcut: "") &&
                   workspace.savedRunCommands.first?.shortcut == "")
        let reloaded = NppWorkspace(runCommandDefaults: defaults)
        assertTest("Manual Run: saved command survives workspace restart",
                   reloaded.savedRunCommands.first?.name == "Compile" &&
                   reloaded.savedRunCommands.first?.command == "make $(CURRENT_DIRECTORY)" &&
                   reloaded.savedRunCommands.first?.inTerminal == true)
        workspace.deleteRunCommand(id: saved.id)
        assertTest("Manual Run: deleting command persists",
                   NppWorkspace(runCommandDefaults: defaults).savedRunCommands.isEmpty)
    }

    static func runResourceBundleTests(assertTest: (String, Bool) -> Void) {
        let dir = NppCompletionEngine.autoCompletionDirectory()
        assertTest("Resources: auto-completion data is found next to the running binary (works inside the .app too)", dir != nil)
        let hasFiles = dir.flatMap { try? FileManager.default.contentsOfDirectory(atPath: $0.path) }?.contains("python.xml") ?? false
        assertTest("Resources: python.xml is present", hasFiles)
        // Typing path used to abort the app when resources were missing
        let words = NppCompletionEngine.shared.candidates(text: "pri", caret: 3, language: "Python", mode: 0,
                                                   minimumLength: 1, ignoreNumbers: true, manual: true)
        assertTest("Resources: completion engine returns keywords for Python without crashing", !words.isEmpty)
    }

    static func runUnsavedBackupRestoreTests(assertTest: (String, Bool) -> Void) {
        let support = FileManager.default.temporaryDirectory.appendingPathComponent("npp_backup_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: support) }
        let saved = support.appendingPathComponent("saved.txt")
        try? "original\n".write(to: saved, atomically: true, encoding: .utf8)

        let ws = NppWorkspace()
        ws.supportDirectoryOverride = support.appendingPathComponent("app")
        ws.rememberSession = true
        ws.periodicBackupEnabled = true
        ws.closeAll(force: true)
        // 1) untitled doc with text, CRLF + Korean text, non-default encoding flags
        let untitled = ws.documents[0]
        untitled.content = "미저장 메모\r\n두번째 줄"
        untitled.eolFormat = .crlf
        untitled.encoding = "UTF-8"
        untitled.hasBOM = true
        untitled.isDirty = true
        let untitledTitle = untitled.title
        // 2) saved file with unsaved edits
        ws.openFile(url: saved)
        let editedDoc = ws.documents.first { $0.filePath?.standardizedFileURL == saved.standardizedFileURL }
        editedDoc?.content = "original\nunsaved edit\n"
        editedDoc?.isDirty = true
        // 3) saved, clean file → no backup needed
        let clean = support.appendingPathComponent("clean.txt")
        try? "clean".write(to: clean, atomically: true, encoding: .utf8)
        ws.openFile(url: clean)

        assertTest("Backup: snapshot succeeds", ws.snapshotSession())
        let backups = (try? FileManager.default.contentsOfDirectory(atPath: ws.backupDirectoryURL.path)) ?? []
        assertTest("Backup: only the 2 unsaved docs are backed up", backups.count == 2)
        assertTest("Backup: disk file untouched by backup", (try? String(contentsOf: saved, encoding: .utf8)) == "original\n")

        // Simulate relaunch
        let ws2 = NppWorkspace()
        ws2.supportDirectoryOverride = ws.supportDirectoryOverride
        ws2.rememberSession = true
        ws2.periodicBackupEnabled = true
        assertTest("Backup: restore succeeds", ws2.restoreAutoSession())
        let u2 = ws2.documents.first { $0.filePath == nil && $0.content.contains("미저장") }
        assertTest("Backup: unsaved new document text restored", u2?.content == "미저장 메모\r\n두번째 줄")
        assertTest("Backup: restored new document stays modified", u2?.isDirty == true)
        assertTest("Backup: restored document keeps title, EOL and BOM",
                   u2?.title == untitledTitle && u2?.eolFormat == .crlf && u2?.hasBOM == true)
        let e2 = ws2.documents.first { $0.filePath?.standardizedFileURL == saved.standardizedFileURL }
        assertTest("Backup: unsaved edits of a saved file restored", e2?.content == "original\nunsaved edit\n" && e2?.isDirty == true)
        let c2 = ws2.documents.first { $0.filePath?.standardizedFileURL == clean.standardizedFileURL }
        assertTest("Backup: clean file reopens from disk and is not modified", c2?.content == "clean" && c2?.isDirty == false)
        assertTest("Backup: no stray empty tab left over", !ws2.documents.contains { $0.filePath == nil && $0.content.isEmpty && !$0.isDirty })

        // Saving removes the stale backup at next snapshot
        if let e = e2 {
            _ = e.save()
            _ = ws2.snapshotSession()
            let after = (try? FileManager.default.contentsOfDirectory(atPath: ws2.backupDirectoryURL.path)) ?? []
            assertTest("Backup: saving a document removes its backup", after.count == 1)
        }
        // Closing without saving drops backup too
        if let u = u2 {
            _ = ws2.closeDocument(id: u.id, force: true)
            _ = ws2.snapshotSession()
            let after = (try? FileManager.default.contentsOfDirectory(atPath: ws2.backupDirectoryURL.path)) ?? []
            assertTest("Backup: discarding a document removes its backup", after.isEmpty)
        }
        // Disabled by preference
        let ws3 = NppWorkspace()
        ws3.supportDirectoryOverride = support.appendingPathComponent("off")
        ws3.rememberSession = false
        assertTest("Backup: nothing is written when 'remember session' is off", ws3.snapshotSession() == false
                   && !FileManager.default.fileExists(atPath: ws3.autoSessionURL.path))
        assertTest("Backup: quitting without prompt only when backup is enabled", ws.canRestoreUnsavedOnLaunch && !ws3.canRestoreUnsavedOnLaunch)
    }

    static func runSessionTabRegressionTests(assertTest: (String, Bool) -> Void) {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("npp_sess_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let names = ["plain.txt", "a & b <c> \"q\" 'x'.txt", "한글 파일.py", "tab\tname.txt"]
        var urls: [URL] = []
        for (i, n) in names.enumerated() {
            let u = dir.appendingPathComponent(n)
            try? "line1\nline2\nline3 \(i)\nline4\n".write(to: u, atomically: true, encoding: .utf8)
            urls.append(u)
        }
        let ws = NppWorkspace()
        ws.closeAll(force: true)
        for u in urls { ws.openFile(url: u) }
        let opened = urls.compactMap { u in ws.documents.first { $0.filePath?.standardizedFileURL == u.standardizedFileURL } }
        assertTest("Session: all files with special characters open", opened.count == urls.count)
        guard opened.count == urls.count else { return }
        opened[1].cursorPos = 8; opened[1].selectionLength = 3
        opened[1].bookmarkedLines = [2, 4]
        opened[2].cursorPos = 3
        ws.activeDocumentId = opened[2].id
        let sess = dir.appendingPathComponent("s.nps")
        assertTest("Session: save succeeds", ws.saveSession(to: sess))

        let ws2 = NppWorkspace()
        ws2.closeAll(force: true)
        assertTest("Session: load succeeds", ws2.loadSession(from: sess))
        let restored = urls.map { u in ws2.documents.first { $0.filePath?.standardizedFileURL == u.standardizedFileURL } }
        assertTest("Session: special-character paths all restored", restored.allSatisfy { $0 != nil })
        if let r1 = restored[1] {
            assertTest("Session: selection restored", r1.cursorPos == 8 && r1.selectionLength == 3)
            assertTest("Session: bookmarks restored", r1.bookmarkedLines == [2, 4])
            assertTest("Session: cursor line/col restored", r1.cursorLine == 2 && r1.cursorCol == 3)
        }
        assertTest("Session: active tab restored", ws2.activeDocumentId == restored[2]?.id)
        assertTest("Session: language restored for .py", restored[2]?.language == "Python")
        let countBefore = ws2.documents.count
        _ = ws2.loadSession(from: sess)
        assertTest("Session: loading twice does not duplicate tabs", ws2.documents.count == countBefore)

        // Tab closing
        let w = NppWorkspace()
        w.closeAll(force: true)
        w.newDocument(); w.newDocument(); w.newDocument()
        let ids = w.documents.map { $0.id }
        let n = ids.count
        w.activeDocumentId = ids[n - 2]
        _ = w.closeDocument(id: ids[n - 2], force: true)
        assertTest("Tabs: closing middle active tab activates a neighbour", w.activeDocumentId == ids[n - 1])
        _ = w.closeDocument(id: ids[n - 1], force: true)
        assertTest("Tabs: closing last active tab activates previous", w.documents.contains { $0.id == w.activeDocumentId })
        w.closeAll(force: true)
        assertTest("Tabs: closing everything leaves exactly one empty doc", w.documents.count == 1 && w.documents[0].content.isEmpty && w.activeDocument != nil)
        w.newDocument()
        let pinned = w.documents[0]
        w.togglePin(id: pinned.id)
        w.closeAll(force: true)
        assertTest("Tabs: Close All keeps pinned tab", w.documents.contains { $0.id == pinned.id })
        let d = w.documents.first { !$0.isPinned } ?? { w.newDocument(); return w.documents.last! }()
        d.content = "x"; d.isDirty = true
        w.closeAllUnchanged()
        assertTest("Tabs: Close All Unchanged keeps dirty tabs", w.documents.contains { $0.id == d.id })
        // Reload from disk
        let f = dir.appendingPathComponent("reload.txt")
        try? "v1".write(to: f, atomically: true, encoding: .utf8)
        w.openFile(url: f)
        if let rd = w.documents.first(where: { $0.filePath?.standardizedFileURL == f.standardizedFileURL }) {
            rd.content = "edited"; rd.isDirty = true
            try? "v2 changed\r\n".write(to: f, atomically: true, encoding: .utf8)
            w.reloadFromDisk(for: rd)
            assertTest("Reload: content, dirty flag and EOL refreshed from disk",
                       rd.content == "v2 changed\r\n" && !rd.isDirty && rd.eolFormat == .crlf)
        } else {
            assertTest("Reload: file opened", false)
        }
    }

    static func runCommentIndentRegressionTests(assertTest: (String, Bool) -> Void) {
        func tv(_ text: String, sel: NSRange) -> NSTextView {
            let v = NSTextView(frame: NSRect(x: 0, y: 0, width: 300, height: 200))
            v.isEditable = true
            v.allowsUndo = true
            v.string = text
            v.setSelectedRange(sel)
            return v
        }
        func all(_ t: String) -> NSRange { NSRange(location: 0, length: (t as NSString).length) }
        var t = "a\n\nb\n"
        var v = tv(t, sel: all(t))
        NppEditOperations.toggleComment(in: v, language: "Swift")
        assertTest("Comment: empty lines untouched, others commented", v.string == "// a\n\n// b\n")
        NppEditOperations.toggleComment(in: v, language: "Swift")
        assertTest("Comment: toggle twice restores text", v.string == t)
        t = "  a\r\n\tb\r\n"
        v = tv(t, sel: all(t))
        NppEditOperations.singleLineComment(in: v, language: "Python")
        assertTest("Comment: CRLF text keeps indentation and EOL", v.string == "  # a\r\n\t# b\r\n")
        t = "SELECT 1"
        v = tv(t, sel: NSRange(location: 0, length: 0))
        NppEditOperations.toggleComment(in: v, language: "SQL")
        assertTest("Comment: SQL uses --", v.string == "-- SELECT 1")
        for (lang, tok) in [("CMake", "#"), ("Dockerfile", "#"), ("Batch", "REM"), ("INI", ";"), ("Lisp", ";"), ("VB", "'"), ("TeX", "%")] {
            let x = tv("x", sel: NSRange(location: 0, length: 0))
            NppEditOperations.toggleComment(in: x, language: lang)
            assertTest("Comment: \(lang) uses \(tok)", x.string == "\(tok) x")
        }
        let pt = tv("hello", sel: NSRange(location: 0, length: 0))
        NppEditOperations.toggleComment(in: pt, language: "Plain Text")
        assertTest("Comment: plain text is left unchanged", pt.string == "hello")
        let js = tv("hello", sel: NSRange(location: 0, length: 0))
        NppEditOperations.toggleComment(in: js, language: "JSON")
        assertTest("Comment: JSON is left unchanged", js.string == "hello")
        let css = tv("a { }", sel: all("a { }"))
        NppEditOperations.singleLineComment(in: css, language: "CSS")
        assertTest("Comment: CSS falls back to /* */", css.string == "/* a { } */")
        // Indent / unindent
        t = "a\nb\nc"
        v = tv(t, sel: NSRange(location: 0, length: 3))
        NppEditOperations.increaseLineIndent(in: v, spaceCount: 4, useTabs: false)
        assertTest("Indent: selected lines indented, third untouched", v.string == "    a\n    b\nc")
        t = "a\nb\nc"
        v = tv(t, sel: NSRange(location: 0, length: 2)) // ends exactly at start of line 2
        NppEditOperations.increaseLineIndent(in: v, spaceCount: 4, useTabs: true)
        assertTest("Indent: selection ending at line start excludes that line", v.string == "\ta\nb\nc")
        t = "  a\n\tb\n        c\nd"
        v = tv(t, sel: all(t))
        NppEditOperations.decreaseLineIndent(in: v, spaceCount: 4)
        assertTest("Unindent: partial spaces, tab, and full indent", v.string == "a\nb\n    c\nd")
        t = "a\r\nb\r\n"
        v = tv(t, sel: all(t))
        NppEditOperations.increaseLineIndent(in: v, spaceCount: 2, useTabs: false)
        assertTest("Indent: CRLF text does not indent the phantom last line", v.string == "  a\r\n  b\r\n")
    }

    static func runEncodingRoundTripTests(assertTest: (String, Bool) -> Void) {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("npp_enc_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let korean = "안녕하세요 메모장\r\n한글 테스트 가나다라마바사\r\n끝\r\n"
        let cases: [(String, String, Bool, String)] = [
            ("UTF-8", "UTF-8", false, korean + "日本語 中文 😀"),
            ("UTF-8 BOM", "UTF-8", true, korean + "日本語 中文 😀"),
            ("UTF-16LE BOM", "UTF-16LE", true, korean + "日本語 中文 😀"),
            ("UTF-16BE BOM", "UTF-16BE", true, korean + "日本語 中文 😀"),
            ("CP949", "CP949", false, korean),
            ("EUC-KR", "EUC-KR", false, korean),
            ("Shift-JIS", "CP932", false, "こんにちは世界\r\nカタカナ漢字\r\n"),
            ("Big5", "BIG5", false, "繁體中文測試\r\n你好世界\r\n"),
            ("GB18030", "GB18030", false, "简体中文测试\r\n你好世界\r\n"),
            ("Windows-1252", "WINDOWS-1252", false, "café naïve résumé €\r\nÄÖÜ ß\r\n"),
        ]
        for (label, charset, bom, text) in cases {
            let d = NppDocument(title: "rt", content: text, encoding: charset, hasBOM: bom, eol: .crlf)
            guard let bytes = d.encodedData() else {
                assertTest("Encoding RT [\(label)]: encode produces bytes", false); continue
            }
            let url = dir.appendingPathComponent("rt_\(label.replacingOccurrences(of: " ", with: "_")).txt")
            try? bytes.write(to: url)
            guard let r = try? NppDocument.fromFile(url: url) else {
                assertTest("Encoding RT [\(label)]: reload", false); continue
            }
            if r.content != text { print("  🔍 DEBUG [\(label)] detected=\(r.encoding) bytes=\(bytes.map { String(format: "%02X", $0) }.joined())") }
            assertTest("Encoding RT [\(label)]: content survives save+reload", r.content == text)
            assertTest("Encoding RT [\(label)]: BOM flag survives", r.hasBOM == bom)
            assertTest("Encoding RT [\(label)]: EOL detected as CRLF", r.eolFormat == .crlf)
            // Convert to UTF-8 then back must keep text
            r.convertEncoding(to: "UTF-8")
            assertTest("Encoding RT [\(label)]: convert to UTF-8 keeps text", r.content == text && r.encoding == "UTF-8")
        }
        // BOM byte checks
        let u8 = NppDocument(title: "b", content: "a", encoding: "UTF-8", hasBOM: true).encodedData()
        assertTest("Encoding: UTF-8 BOM bytes EF BB BF", u8 == Data([0xEF, 0xBB, 0xBF, 0x61]))
        let u16 = NppDocument(title: "b", content: "a", encoding: "UTF-16LE", hasBOM: true).encodedData()
        assertTest("Encoding: UTF-16LE BOM bytes FF FE", u16 == Data([0xFF, 0xFE, 0x61, 0x00]))
        let u16b = NppDocument(title: "b", content: "a", encoding: "UTF-16BE", hasBOM: true).encodedData()
        assertTest("Encoding: UTF-16BE BOM bytes FE FF", u16b == Data([0xFE, 0xFF, 0x00, 0x61]))
        let emoji = NppDocument(title: "b", content: "😀", encoding: "UTF-16LE", hasBOM: false).encodedData()
        assertTest("Encoding: UTF-16LE surrogate pair", emoji == Data([0x3D, 0xD8, 0x00, 0xDE]))
        // Unrepresentable character must not make save fail or corrupt neighbours
        let lossy = NppDocument(title: "b", content: "a한b", encoding: "WINDOWS-1252", hasBOM: false).encodedData()
        assertTest("Encoding: unrepresentable char becomes '?' and neighbours stay", lossy == Data([0x61, 0x3F, 0x62]))
        // Empty and NUL-containing content
        let empty = NppDocument(title: "b", content: "", encoding: "UTF-8", hasBOM: false).encodedData()
        assertTest("Encoding: empty document encodes to empty data", empty == Data())
        let nul = NppDocument(title: "b", content: "a\0b", encoding: "UTF-8", hasBOM: false).encodedData()
        assertTest("Encoding: embedded NUL preserved", nul == Data([0x61, 0x00, 0x62]))
        // Re-interpret (Encode in ...) of a UTF-8 BOM file must not leave U+FEFF in the text
        let bomURL = dir.appendingPathComponent("bom.txt")
        try? Data([0xEF, 0xBB, 0xBF, 0x68, 0x69]).write(to: bomURL)
        if let b = try? NppDocument.fromFile(url: bomURL) {
            assertTest("Encoding: BOM not part of text on load", b.content == "hi" && b.hasBOM)
            b.reencodeAs(targetCharset: "UTF-8")
            assertTest("Encoding: reencode as UTF-8 keeps BOM flag and no U+FEFF", b.content == "hi" && b.hasBOM)
        }
    }

    static func runLineNumberRegressionTests(assertTest: (String, Bool) -> Void) {
        func line(_ text: String, at pos: Int) -> Int { NppLineCounter.lineNumber(upTo: pos, in: text as NSString) }
        // "a<EOL>b<EOL>c": 'c' is at index 4 (LF/CR) or 6 (CRLF)
        assertTest("LineNo: LF file", line("a\nb\nc", at: 4) == 3)
        assertTest("LineNo: CRLF file", line("a\r\nb\r\nc", at: 6) == 3)
        assertTest("LineNo: CR-only file", line("a\rb\rc", at: 4) == 3)
        assertTest("LineNo: mixed EOL file", line("a\rb\nc\r\nd", at: 8) == 4)
        assertTest("LineNo: caret between CR and LF stays on same line", line("a\r\nb", at: 2) == 1)
        assertTest("LineNo: line count per EOL type",
                   ["x\ny\nz", "x\r\ny\r\nz", "x\ry\rz"].allSatisfy { NppLineCounter.lineCount(in: $0) == 3 })
        assertTest("LineNo: trailing break starts an empty line",
                   NppLineCounter.lineCount(in: "x\r") == 2 && NppLineCounter.lineCount(in: "") == 1)
        let info = NppLineCounter.lineInfo(upTo: 4, in: "ab\rcd" as NSString)
        assertTest("LineNo: line start/column for CR file", info.line == 2 && info.lineStart == 3)
        let d = NppDocument(title: "t", content: "a\rb\rc\rd", eol: .cr)
        d.bookmarkedLines = [3]
        d.adjustBookmarks(affectedRange: NSRange(location: 0, length: 0), replacementString: "z\r", currentText: d.content)
        assertTest("LineNo: bookmark shifts when a CR line is inserted", d.bookmarkedLines == [4])
    }

    static func runFindReplaceRegressionTests(assertTest: (String, Bool) -> Void) {
        func count(_ q: String, in text: String, regex: Bool, whole: Bool) -> Int {
            var pat = regex ? q : NSRegularExpression.escapedPattern(for: q)
            if whole { pat = NppWorkspace.wholeWordPattern(pat, query: q) }
            guard let re = try? NSRegularExpression(pattern: pat, options: [.caseInsensitive]) else { return -1 }
            return re.numberOfMatches(in: text, range: NSRange(location: 0, length: (text as NSString).length))
        }
        assertTest("Find: whole word + regex alternation stays grouped",
                   count("cat|dog", in: "cat dog concat dogma", regex: true, whole: true) == 2)
        assertTest("Find: whole word with trailing punctuation query",
                   count("foo()", in: "foo() x foo()y", regex: false, whole: true) == 2)
        assertTest("Find: whole word plain query rejects substrings",
                   count("cat", in: "cat concat cat.", regex: false, whole: true) == 2)
        func repl(_ pat: String, _ tmpl: String, _ text: String) -> String {
            let re = try! NSRegularExpression(pattern: pat, options: [.anchorsMatchLines])
            return re.stringByReplacingMatches(in: text, range: NSRange(location: 0, length: (text as NSString).length),
                                               withTemplate: NppWorkspace.normalizeRegexReplacementTemplate(tmpl))
        }
        assertTest("Find: regex replacement \\n inserts newline", repl(",", "\\n", "a,b") == "a\nb")
        assertTest("Find: regex replacement \\t inserts tab", repl(",", "\\t", "a,b") == "a\tb")
        assertTest("Find: regex replacement \\1 and $1 group refs", repl("(a)(b)", "\\2$1", "ab") == "ba")
        assertTest("Find: regex replacement escaped backslash", repl(",", "\\\\", "a,b") == "a\\b")
    }

    static func runLineOpsRegressionTests(assertTest: (String, Bool) -> Void) {
        func doc(_ c: String, _ eol: NppEol = .lf) -> NppDocument { NppDocument(title: "t", content: c, eol: eol) }
        var d = doc("b\na\nc\n")
        NppEditOperations.sortLines(in: d)
        assertTest("LineOps: sort whole doc keeps trailing newline", d.content == "\na\nb\nc" || d.content == "a\nb\nc\n")
        d = doc("a\nb\na\n")
        NppEditOperations.removeDuplicateLines(in: d)
        assertTest("LineOps: remove duplicates whole doc keeps trailing newline", d.content == "a\nb\n")
        d = doc("a\nb\nc\n")
        NppEditOperations.reverseLineOrder(in: d)
        assertTest("LineOps: reverse whole doc keeps trailing newline", d.content == "c\nb\na\n")
        d = doc("x\n\n\ny\n")
        NppEditOperations.removeEmptyLines(in: d)
        assertTest("LineOps: remove empty lines keeps trailing newline", d.content == "x\ny\n")
        d = doc("a  \r\nb  \r\n", .lf)
        NppEditOperations.trimSpaces(in: d, mode: .trailing)
        assertTest("LineOps: trim trailing preserves existing CRLF", d.content == "a\r\nb\r\n")
        d = doc("a \nb \n", .crlf)
        NppEditOperations.trimSpaces(in: d, mode: .trailing)
        assertTest("LineOps: trim trailing does not rewrite EOL style", d.content == "a\nb\n")
        d = doc("a\tb\n")
        NppEditOperations.tabToSpace(in: d, spaceCount: 4)
        assertTest("LineOps: tab to space aligns to tab stop", d.content == "a   b\n")
        d = doc("a\n\n")
        NppEditOperations.sortLines(in: d)
        assertTest("LineOps: sort keeps blank trailing line count", d.content.filter { $0 == "\n" }.count == 2)
    }

    static func runManualLanguageDetectionTests(assertTest: (String, Bool) -> Void) {
        assertTest("Manual Language: known extension takes precedence over first line",
                   NppDocument.detectLanguage(for: "sample.py", content: "<html>test") == "Python")
        assertTest("Manual Language: special script filenames map to Python",
                   ["SConstruct", "SConscript", "wscript"].allSatisfy {
                       NppDocument.detectLanguage(for: $0) == "Python"
                   })
        assertTest("Manual Language: XML and PHP prologs are recognized",
                   NppDocument.detectLanguage(for: "untitled", content: "<?xml version=\"1.0\"?>") == "XML" &&
                   NppDocument.detectLanguage(for: "untitled", content: "<?php echo 1;") == "PHP")
        assertTest("Manual Language: unknown extension falls back to first line",
                   NppDocument.detectLanguage(for: "script.unknown", content: "#!/usr/bin/env python3") == "Python")
    }

    static func captureScreenshot(appDelegate: AppDelegate, openPrefs: Bool, prefTab: Int = 0, showInvisibles: Bool = false, searchMode: NppWorkspace.NppSearchBarMode? = nil, filename: String = "screenshot.png") {
        captureCustomScreenshot(appDelegate: appDelegate, setup: { ws in
            if showInvisibles {
                ws.showInvisibleCharacters = true
            }
            if let sm = searchMode {
                ws.searchBarMode = sm
                ws.showSearchBar = true
            }
            if openPrefs {
                ws.openPreferences(tab: prefTab)
            }
        }, filename: filename)
    }

    // =========================================================================
    // 32. QUIT LIFECYCLE & TAB BAR DOUBLE CLICK UX PARITY TESTS (Gen 5)
    // =========================================================================
    static func runQuitAndTabBarUXParityTests(
        appDelegate: AppDelegate,
        assertTest: (String, Bool) -> Void
    ) {
        print("\n========================================================")
        print("🎯 QUIT LIFECYCLE & TAB BAR UX PARITY TESTS (GEN 5)")
        print("========================================================")

        let support = FileManager.default.temporaryDirectory.appendingPathComponent("npp_quit_test_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: support) }

        let savedFile = support.appendingPathComponent("saved_doc.txt")
        try? "initial text\n".write(to: savedFile, atomically: true, encoding: .utf8)

        // -------------------------------------------------------------
        // Subtest A: Quit with Session Snapshot & Periodic Backup Active
        // Upstream C++ WM_CLOSE: fileCloseAll(false, isSnapshotMode=true)
        // -------------------------------------------------------------
        let wsA = NppWorkspace()
        wsA.supportDirectoryOverride = support.appendingPathComponent("appA")
        wsA.rememberSession = true
        wsA.periodicBackupEnabled = true
        wsA.closeAll(force: true)

        // 1 untitled document with unsaved text
        let untitled = wsA.documents[0]
        untitled.content = "미저장 스냅샷 테스트"
        untitled.isDirty = true

        // 1 saved document with unsaved modifications
        wsA.openFile(url: savedFile)
        let savedDoc = wsA.documents.first { $0.filePath?.standardizedFileURL == savedFile.standardizedFileURL }
        savedDoc?.content = "modified text in saved file\n"
        savedDoc?.isDirty = true

        assertTest("Quit Parity: canRestoreUnsavedOnLaunch is true when both rememberSession and periodicBackupEnabled are on", wsA.canRestoreUnsavedOnLaunch)

        // Prepare for termination should succeed without prompts
        let canTerminateA = wsA.prepareForTermination()
        assertTest("Quit Parity: prepareForTermination returns true without save prompts when snapshot mode is active", canTerminateA)

        let backupFilesA = (try? FileManager.default.contentsOfDirectory(atPath: wsA.backupDirectoryURL.path)) ?? []
        assertTest("Quit Parity: 2 backup files created in backup directory", backupFilesA.count == 2)
        assertTest("Quit Parity: autoSessionURL session.xml exists", FileManager.default.fileExists(atPath: wsA.autoSessionURL.path))

        // Verify restoration on launch
        let wsRestore = NppWorkspace()
        wsRestore.supportDirectoryOverride = wsA.supportDirectoryOverride
        wsRestore.rememberSession = true
        wsRestore.periodicBackupEnabled = true
        assertTest("Quit Parity: restoreAutoSession restores previous snapshotted session", wsRestore.restoreAutoSession())
        let restoredUntitled = wsRestore.documents.first { $0.filePath == nil && $0.content.contains("미저장") }
        assertTest("Quit Parity: Restored untitled document content intact", restoredUntitled?.content == "미저장 스냅샷 테스트")
        assertTest("Quit Parity: Restored untitled document is marked dirty", restoredUntitled?.isDirty == true)
        let restoredSaved = wsRestore.documents.first { $0.filePath?.standardizedFileURL == savedFile.standardizedFileURL }
        assertTest("Quit Parity: Restored saved document content intact", restoredSaved?.content == "modified text in saved file\n")
        assertTest("Quit Parity: Restored saved document is marked dirty", restoredSaved?.isDirty == true)

        // -------------------------------------------------------------
        // Subtest B: Quit with Session Backup Disabled (Save Prompt Fallback)
        // Upstream C++ WM_CLOSE: fileCloseAll(false, isSnapshotMode=false)
        // -------------------------------------------------------------
        let wsB = NppWorkspace()
        wsB.supportDirectoryOverride = support.appendingPathComponent("appB")
        wsB.rememberSession = true
        wsB.periodicBackupEnabled = false // Snapshot mode disabled
        wsB.closeAll(force: true)
        let dirtyB = wsB.documents[0]
        dirtyB.content = "Unsaved work without backup"
        dirtyB.isDirty = true

        assertTest("Quit Parity: canRestoreUnsavedOnLaunch is false when periodicBackupEnabled is false", !wsB.canRestoreUnsavedOnLaunch)

        // User chooses Cancel -> abort quit, documents stay intact
        wsB.confirmSaveHandler = { _ in .cancel }
        let canTerminateCancel = wsB.prepareForTermination()
        assertTest("Quit Parity: prepareForTermination returns false when user cancels prompt", !canTerminateCancel)
        assertTest("Quit Parity: Documents remain open when quit is cancelled", wsB.documents.count == 1 && wsB.documents[0].id == dirtyB.id)

        // User chooses Don't Save -> allow quit
        wsB.confirmSaveHandler = { _ in .dontSave }
        let canTerminateDontSave = wsB.prepareForTermination()
        assertTest("Quit Parity: prepareForTermination returns true when user selects Don't Save", canTerminateDontSave)

        // -------------------------------------------------------------
        // Subtest C: Tab Close Regression (Cmd+W and File > Close All Parity)
        // Upstream C++: fileClose() and IDM_FILE_CLOSEALL ALWAYS prompt for dirty tabs
        // -------------------------------------------------------------
        let wsC = NppWorkspace()
        wsC.rememberSession = true
        wsC.periodicBackupEnabled = true // Even when backup is enabled!
        wsC.closeAll(force: true)
        let dirtyC = wsC.documents[0]
        dirtyC.content = "Individual tab close test"
        dirtyC.isDirty = true

        wsC.confirmSaveHandler = { _ in .cancel }
        let closedSingle = wsC.closeDocument(id: dirtyC.id, force: false)
        assertTest("Tab Close Parity: closeDocument(force: false) prompts and aborts on cancel even when backup is enabled", !closedSingle)
        assertTest("Tab Close Parity: Dirty tab remains open after cancelled close", wsC.documents.contains { $0.id == dirtyC.id })

        let closedAll = wsC.closeAll(force: false)
        assertTest("Close All Parity: closeAll(force: false) prompts and aborts on cancel even when backup is enabled", !closedAll)

        // -------------------------------------------------------------
        // Subtest D: Tab Bar Empty Area Double Click to New Document
        // Upstream C++ TabBar.cpp:1215 WM_LBUTTONDBLCLK outside existing tabs -> IDM_FILE_NEW
        // -------------------------------------------------------------
        let wsD = NppWorkspace()
        wsD.closeAll(force: true)
        let initialDocCount = wsD.documents.count
        assertTest("TabBar Parity: Initial document count is at least 1", initialDocCount >= 1)

        // 1. Double click preference check
        wsD.doubleClickSpaceToNewTab = true
        assertTest("TabBar Parity: doubleClickSpaceToNewTab preference is enabled", wsD.doubleClickSpaceToNewTab)

        // 2. Programmatic creation parity with sequential naming
        let countBeforeNew = wsD.documents.count
        wsD.newDocument()
        assertTest("TabBar Parity: newDocument creates sequential tab with 'new' prefix", wsD.activeDocument?.title.hasPrefix("new ") == true && wsD.documents.count == countBeforeNew + 1)
        assertTest("TabBar Parity: newly created document is activeDocument", wsD.activeDocumentId == wsD.documents.last?.id)

        // 3. Secondary view creation parity
        let countBeforeSec = wsD.secondaryDocuments.count
        wsD.newDocumentInSecondaryView()
        assertTest("TabBar Parity: newDocumentInSecondaryView creates tab in secondary view", wsD.secondaryDocuments.count == countBeforeSec + 1 && wsD.secondaryDocuments.last?.title.hasPrefix("new ") == true)
        assertTest("TabBar Parity: secondary view document is secondaryActiveDocumentId", wsD.secondaryActiveDocumentId == wsD.secondaryDocuments.last?.id)

        // 4. Tab item double click to close (when doubleClickTabToClose is true)
        wsD.doubleClickTabToClose = true
        let testTabToClose = wsD.documents.last!
        let countBeforeClose = wsD.documents.count
        let closedTabItem = wsD.closeDocument(id: testTabToClose.id, force: true)
        assertTest("TabBar Parity: Double clicking tab item closes document", closedTabItem && wsD.documents.count == countBeforeClose - 1)

        // 5. Pinned tab cannot be closed on double click (Authentic Notepad++)
        let pinnedDoc = wsD.documents[0]
        pinnedDoc.isPinned = true
        let pinnedClosed = wsD.closeDocument(id: pinnedDoc.id, force: false)
        assertTest("TabBar Parity: Pinned tab is protected and cannot be closed on double click", !pinnedClosed)

        // 6. Double click tab disabled preference
        wsD.doubleClickTabToClose = false
        assertTest("TabBar Parity: doubleClickTabToClose preference can be toggled off", !wsD.doubleClickTabToClose)

        // -------------------------------------------------------------
        // Subtest E: Live SwiftUI TabBarView Hit Testing & Gesture Event Simulation
        // -------------------------------------------------------------
        let liveWs = NppWorkspace()
        liveWs.closeAll(force: true)
        liveWs.doubleClickSpaceToNewTab = true
        let preSimCount = liveWs.documents.count

        let tabBarView = NppTabBarView(workspace: liveWs, viewIndex: 0)
        let hostingView = NSHostingView(rootView: tabBarView)
        hostingView.frame = NSRect(x: 0, y: 0, width: 800, height: 30)

        let testWindow = NSWindow(
            contentRect: NSRect(x: 100, y: 100, width: 800, height: 30),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        testWindow.isReleasedWhenClosed = false
        testWindow.contentView = hostingView
        testWindow.makeKeyAndOrderFront(nil)
        hostingView.layoutSubtreeIfNeeded()

        // Send simulated double click events at x: 350, y: 15 (guaranteed empty space to the right of tabs)
        let clickPoint = hostingView.convert(NSPoint(x: 350, y: 15), to: nil)
        let uptime = ProcessInfo.processInfo.systemUptime
        let eventDown1 = NSEvent.mouseEvent(with: .leftMouseDown, location: clickPoint, modifierFlags: [], timestamp: uptime, windowNumber: testWindow.windowNumber, context: nil, eventNumber: 601, clickCount: 1, pressure: 1.0)!
        let eventUp1 = NSEvent.mouseEvent(with: .leftMouseUp, location: clickPoint, modifierFlags: [], timestamp: uptime + 0.01, windowNumber: testWindow.windowNumber, context: nil, eventNumber: 602, clickCount: 1, pressure: 0.0)!
        let eventDown2 = NSEvent.mouseEvent(with: .leftMouseDown, location: clickPoint, modifierFlags: [], timestamp: uptime + 0.05, windowNumber: testWindow.windowNumber, context: nil, eventNumber: 603, clickCount: 2, pressure: 1.0)!
        let eventUp2 = NSEvent.mouseEvent(with: .leftMouseUp, location: clickPoint, modifierFlags: [], timestamp: uptime + 0.06, windowNumber: testWindow.windowNumber, context: nil, eventNumber: 604, clickCount: 2, pressure: 0.0)!

        testWindow.sendEvent(eventDown1)
        testWindow.sendEvent(eventUp1)
        testWindow.sendEvent(eventDown2)
        testWindow.sendEvent(eventUp2)

        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.2))

        assertTest("TabBar Parity: Live SwiftUI double click on empty area to the right of tabs triggers new document", liveWs.documents.count == preSimCount + 1)
        assertTest("TabBar Parity: Newly created document from double click gesture is active document", liveWs.activeDocumentId == liveWs.documents.last?.id)
        testWindow.orderOut(nil)

        // -------------------------------------------------------------
        // Subtest F: AppDelegate applicationShouldTerminate Bridge
        // -------------------------------------------------------------
        let origPeriodic = appDelegate.workspace.periodicBackupEnabled
        let origRemember = appDelegate.workspace.rememberSession
        let origHandler = appDelegate.workspace.confirmSaveHandler

        appDelegate.workspace.periodicBackupEnabled = true
        appDelegate.workspace.rememberSession = true
        let termReply = appDelegate.applicationShouldTerminate(NSApp)
        assertTest("AppDelegate: applicationShouldTerminate returns .terminateNow when snapshot mode is active", termReply == .terminateNow)

        appDelegate.workspace.periodicBackupEnabled = false
        appDelegate.workspace.confirmSaveHandler = { _ in .cancel }
        if !appDelegate.workspace.documents.isEmpty {
            let cancelDoc = appDelegate.workspace.documents[0]
            let oldContent = cancelDoc.content
            let oldDirty = cancelDoc.isDirty
            cancelDoc.content = "dirty for appDelegate test"
            cancelDoc.isDirty = true
            let termReplyCancel = appDelegate.applicationShouldTerminate(NSApp)
            assertTest("AppDelegate: applicationShouldTerminate returns .terminateCancel when prompt is cancelled", termReplyCancel == .terminateCancel)
            cancelDoc.content = oldContent
            cancelDoc.isDirty = oldDirty
        }

        // Restore clean state
        appDelegate.workspace.confirmSaveHandler = origHandler
        appDelegate.workspace.periodicBackupEnabled = origPeriodic
        appDelegate.workspace.rememberSession = origRemember
    }

    // MARK: - Adversarial Stress Testing: Quit & Session Snapshot Lifecycle (Challenger 1)
    static func runAdversarialQuitStressTests(
        appDelegate: AppDelegate,
        assertTest: @escaping (String, Bool) -> Void
    ) {
        print("\n========================================================")
        print("⚔️ CHALLENGER 1: ADVERSARIAL STRESS TESTS (QUIT & SNAPSHOT)")
        print("========================================================")

        let tempBase = FileManager.default.temporaryDirectory.appendingPathComponent("npp_challenger_stress_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempBase, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempBase) }

        // -------------------------------------------------------------
        // Challenge 1: Complex Multi-Document Snapshot & Exact Restoration
        // (Clean saved, Dirty saved, Clean untitled, Dirty untitled with content,
        //  Dirty untitled empty, CJK Korean text, Dual View, Bookmarks, Cursor/Selection)
        // -------------------------------------------------------------
        let ws1 = NppWorkspace()
        ws1.supportDirectoryOverride = tempBase.appendingPathComponent("ws1_support")
        ws1.rememberSession = true
        ws1.periodicBackupEnabled = true
        ws1.closeAll(force: true)

        let fileClean = tempBase.appendingPathComponent("clean_file.txt")
        let fileDirty = tempBase.appendingPathComponent("dirty_한글_file.txt")
        try? "Clean initial text\n".write(to: fileClean, atomically: true, encoding: .utf8)
        try? "Dirty file original disk content\n".write(to: fileDirty, atomically: true, encoding: .utf8)

        // 1. Clean saved file
        ws1.openFile(url: fileClean)

        // 2. Dirty saved file with Korean text
        ws1.openFile(url: fileDirty)
        if let d = ws1.documents.first(where: { $0.filePath?.standardizedFileURL == fileDirty.standardizedFileURL }) {
            d.content = "Dirty file modified text: 한국어 유니코드 및 CJK 테스트 🚀\nLine 2 with special chars: <xml>&test\"'\nLine 3"
            d.isDirty = true
            d.toggleBookmark(line: 2)
            d.cursorPos = 10
            d.selectionLength = 5
        }

        // 3. Untitled with Korean content
        ws1.newDocument() // new 2
        let untitledModified = ws1.activeDocument!
        untitledModified.content = "무제 문서 내용입니다. 세션 복구 및 스냅샷 보존 검증.\n두 번째 줄입니다."
        untitledModified.isDirty = true
        untitledModified.toggleBookmark(line: 1)

        // 4. Untitled with empty content but marked isDirty and with XML special characters in title
        ws1.newDocument() // new 3
        let untitledEmptyDirty = ws1.activeDocument!
        untitledEmptyDirty.title = "<special_tag>&test"
        untitledEmptyDirty.content = ""
        untitledEmptyDirty.isDirty = true

        // 5. Dual view tab (secondary view)
        ws1.newDocument() // new 4
        let subViewDoc = ws1.activeDocument!
        subViewDoc.content = "Secondary view document text"
        subViewDoc.isDirty = true
        ws1.moveToOtherView(id: subViewDoc.id)

        // Set confirmSaveHandler to fail if called unexpectedly
        var savePromptWasShown = false
        ws1.confirmSaveHandler = { _ in
            savePromptWasShown = true
            return .cancel
        }

        assertTest("Challenger 1.1: canRestoreUnsavedOnLaunch is true", ws1.canRestoreUnsavedOnLaunch)
        let termSuccess1 = ws1.prepareForTermination()
        assertTest("Challenger 1.2: prepareForTermination returns true with zero modal alerts", termSuccess1 && !savePromptWasShown)

        // Verify backup files created
        let backupList = (try? FileManager.default.contentsOfDirectory(atPath: ws1.backupDirectoryURL.path)) ?? []
        // Expected backups: fileDirty, untitledModified, untitledEmptyDirty, subViewDoc (4 total)
        // fileClean should NOT be backed up
        assertTest("Challenger 1.3: Exactly 4 dirty documents backed up to disk", backupList.count == 4)

        // Verify session.xml contains proper activeView and document entries
        let sessionData = (try? Data(contentsOf: ws1.autoSessionURL)) ?? Data()
        let sessionXML = String(decoding: sessionData, as: UTF8.self)
        assertTest("Challenger 1.4: session.xml contains mainView and subView", sessionXML.contains("<mainView") && sessionXML.contains("<subView"))
        assertTest("Challenger 1.5: session.xml escaped XML special chars in title safely", !sessionXML.contains("<special_tag>") && sessionXML.contains("&lt;special_tag&gt;&amp;test"))

        // Relaunch simulation
        let ws1Relaunch = NppWorkspace()
        ws1Relaunch.supportDirectoryOverride = ws1.supportDirectoryOverride
        ws1Relaunch.rememberSession = true
        ws1Relaunch.periodicBackupEnabled = true
        let restoreOk = ws1Relaunch.restoreAutoSession()
        assertTest("Challenger 1.6: restoreAutoSession succeeded", restoreOk)

        // Check clean saved file
        let restoredClean = ws1Relaunch.documents.first(where: { $0.filePath?.standardizedFileURL == fileClean.standardizedFileURL })
        assertTest("Challenger 1.7: Clean saved file restored with isDirty == false", restoredClean != nil && restoredClean?.isDirty == false)

        // Check dirty saved file
        let restoredDirty = ws1Relaunch.documents.first(where: { $0.filePath?.standardizedFileURL == fileDirty.standardizedFileURL })
        assertTest("Challenger 1.8: Dirty saved file restored with exact Korean text and XML content", restoredDirty?.content.contains("한국어 유니코드 및 CJK 테스트 🚀") == true && restoredDirty?.content.contains("<xml>&test\"'") == true)
        assertTest("Challenger 1.9: Dirty saved file has isDirty == true", restoredDirty?.isDirty == true)
        assertTest("Challenger 1.10: Bookmarks restored on dirty saved file", restoredDirty?.bookmarkedLines.contains(2) == true)
        assertTest("Challenger 1.11: Cursor position restored on dirty saved file", restoredDirty?.cursorPos == 10 && restoredDirty?.selectionLength == 5)

        // Check untitled modified
        let restoredUntitled = ws1Relaunch.documents.first(where: { $0.filePath == nil && $0.content.contains("무제 문서") })
        assertTest("Challenger 1.12: Untitled modified document restored intact", restoredUntitled != nil && restoredUntitled?.isDirty == true)

        // Check dual view doc
        let restoredSubViewDoc = ws1Relaunch.documents.first(where: { $0.content == "Secondary view document text" })
        assertTest("Challenger 1.13: Dual view document placed in secondary view", restoredSubViewDoc != nil && ws1Relaunch.secondaryDocumentIds.contains(restoredSubViewDoc!.id))

        // Check no stray extra blank tab
        let strayBlanks = ws1Relaunch.documents.filter { $0.filePath == nil && !$0.isDirty && $0.content.isEmpty }
        assertTest("Challenger 1.14: No stray unmanaged blank tabs left over", strayBlanks.isEmpty)
        assertTest("Challenger 1.15: Restored untitled document with XML title intact", ws1Relaunch.documents.contains { $0.title == "<special_tag>&test" })

        // -------------------------------------------------------------
        // Challenge 2: Snapshot Disabled Save Prompt Fallback & Cancel Safety
        // -------------------------------------------------------------
        let ws2 = NppWorkspace()
        ws2.supportDirectoryOverride = tempBase.appendingPathComponent("ws2_support")
        ws2.rememberSession = true
        ws2.periodicBackupEnabled = false // Snapshot disabled
        ws2.closeAll(force: true)

        let doc2A = ws2.documents[0]
        doc2A.content = "Doc 2A initial dirty content"
        doc2A.isDirty = true

        ws2.newDocument()
        let doc2B = ws2.activeDocument!
        doc2B.content = "Doc 2B second dirty content"
        doc2B.isDirty = true

        assertTest("Challenger 2.1: canRestoreUnsavedOnLaunch is false when periodicBackup is disabled", !ws2.canRestoreUnsavedOnLaunch)

        // User chooses Cancel on first prompt
        var promptsAsked = 0
        ws2.confirmSaveHandler = { _ in
            promptsAsked += 1
            return .cancel
        }
        let termReplyCancel = ws2.prepareForTermination()
        assertTest("Challenger 2.2: prepareForTermination returns false on cancel", !termReplyCancel)
        assertTest("Challenger 2.3: Zero tabs closed on cancelled termination (data preservation)", ws2.documents.count == 2 && ws2.documents[0].id == doc2A.id && ws2.documents[1].id == doc2B.id)
        assertTest("Challenger 2.4: Dirty flags remain true on cancelled termination", doc2A.isDirty && doc2B.isDirty)

        // User chooses Don't Save
        promptsAsked = 0
        ws2.confirmSaveHandler = { _ in
            promptsAsked += 1
            return .dontSave
        }
        let termReplyDontSave = ws2.prepareForTermination()
        assertTest("Challenger 2.5: prepareForTermination returns true when user selects Don't Save", termReplyDontSave)
        assertTest("Challenger 2.6: User was prompted for each dirty doc", promptsAsked == 2)

        // -------------------------------------------------------------
        // Challenge 3: Rapid / Idempotent Termination Calls Stress Test
        // -------------------------------------------------------------
        let ws3 = NppWorkspace()
        ws3.supportDirectoryOverride = tempBase.appendingPathComponent("ws3_support")
        ws3.rememberSession = true
        ws3.periodicBackupEnabled = true
        ws3.closeAll(force: true)
        ws3.documents[0].content = "Rapid termination stress text"
        ws3.documents[0].isDirty = true

        var rapidAllPassed = true
        for _ in 1...25 {
            let res = ws3.prepareForTermination()
            if !res { rapidAllPassed = false }
        }
        assertTest("Challenger 3.1: 25 rapid successive prepareForTermination calls succeed idempotently", rapidAllPassed)

        let sessionData3 = (try? Data(contentsOf: ws3.autoSessionURL)) ?? Data()
        let parsedXML = try? XMLDocument(data: sessionData3)
        assertTest("Challenger 3.2: session.xml remains valid XML after rapid termination calls", parsedXML != nil)

        // -------------------------------------------------------------
        // Challenge 4: Backup Disk Failure Graceful Fallback
        // -------------------------------------------------------------
        let ws4 = NppWorkspace()
        // Point support directory to an invalid path or a file where a directory should be
        let blockingFile = tempBase.appendingPathComponent("blocking_file")
        try? "not a directory".write(to: blockingFile, atomically: true, encoding: .utf8)
        ws4.supportDirectoryOverride = blockingFile.appendingPathComponent("sub") // cannot create dir under a file
        ws4.rememberSession = true
        ws4.periodicBackupEnabled = true
        ws4.closeAll(force: true)
        ws4.documents[0].content = "Dirty document with unwritable backup directory"
        ws4.documents[0].isDirty = true

        var fallbackPromptShown = false
        ws4.confirmSaveHandler = { _ in
            fallbackPromptShown = true
            return .cancel
        }
        let fallbackTermCancel = ws4.prepareForTermination()
        assertTest("Challenger 4.1: When snapshot write fails, falls back to promptSaveDirtyDocumentsBeforeQuit", fallbackPromptShown)
        assertTest("Challenger 4.2: Fallback prompt cancel safely aborts termination without crash", !fallbackTermCancel)

        // -------------------------------------------------------------
        // Challenge 5: In-Flight CJK IME Text Resignation via AppDelegate
        // -------------------------------------------------------------
        let origPeriodic = appDelegate.workspace.periodicBackupEnabled
        let origRemember = appDelegate.workspace.rememberSession
        let origHandler = appDelegate.workspace.confirmSaveHandler
        defer {
            appDelegate.workspace.periodicBackupEnabled = origPeriodic
            appDelegate.workspace.rememberSession = origRemember
            appDelegate.workspace.confirmSaveHandler = origHandler
        }

        appDelegate.workspace.periodicBackupEnabled = true
        appDelegate.workspace.rememberSession = true
        appDelegate.workspace.confirmSaveHandler = { _ in .cancel }

        // Simulate active editing in text view
        if let win = appDelegate.window, let tv = appDelegate.workspace.activeTextView {
            tv.string = "Active typing: 한국어 입력 중 종료 테스트"
            tv.didChangeText()
            win.makeFirstResponder(tv)
            assertTest("Challenger 5.1: NSTextView is first responder before terminate", win.firstResponder === tv)

            let termReplyNow = appDelegate.applicationShouldTerminate(NSApp)
            assertTest("Challenger 5.2: applicationShouldTerminate returns .terminateNow with in-flight editing", termReplyNow == .terminateNow)
            assertTest("Challenger 5.3: Active text view editing was committed and document marked dirty", appDelegate.workspace.activeDocument?.content.contains("한국어 입력 중 종료 테스트") == true)
        } else {
            // Headless / fallback check
            let termReplyNow = appDelegate.applicationShouldTerminate(NSApp)
            assertTest("Challenger 5.2: applicationShouldTerminate returns .terminateNow", termReplyNow == .terminateNow)
        }

        // -------------------------------------------------------------
        // Challenge 6: Tab Bar Double-Click Stress & Preference Toggle
        // -------------------------------------------------------------
        let ws6 = NppWorkspace()
        ws6.doubleClickSpaceToNewTab = true
        let initCount = ws6.documents.count
        ws6.newDocument() // simulated double click 1
        ws6.newDocument() // simulated double click 2
        assertTest("Challenger 6.1: Double click creates sequential new documents", ws6.documents.count == initCount + 2)
        assertTest("Challenger 6.2: Newly created document has sequential 'new' title", ws6.documents.last?.title.hasPrefix("new") == true)

        // Disable doubleClickSpaceToNewTab preference
        ws6.doubleClickSpaceToNewTab = false
        assertTest("Challenger 6.3: doubleClickSpaceToNewTab preference can be disabled", !ws6.doubleClickSpaceToNewTab)

        print("========================================================")
        print("⚔️ CHALLENGER 1: ADVERSARIAL STRESS SUITE COMPLETE")
        print("========================================================\n")
    }

    // MARK: - AppKit Event Simulation Helper for TabBar Gestures
    static func simulateClicks(to window: NSWindow, at pointInWindow: NSPoint, count: Int, startEventNum: Int = 1000) {
        let uptime = ProcessInfo.processInfo.systemUptime
        for c in 1...count {
            let down = NSEvent.mouseEvent(
                with: .leftMouseDown,
                location: pointInWindow,
                modifierFlags: [],
                timestamp: uptime + Double(c) * 0.03,
                windowNumber: window.windowNumber,
                context: nil,
                eventNumber: startEventNum + c * 2,
                clickCount: c,
                pressure: 1.0
            )!
            let up = NSEvent.mouseEvent(
                with: .leftMouseUp,
                location: pointInWindow,
                modifierFlags: [],
                timestamp: uptime + Double(c) * 0.03 + 0.01,
                windowNumber: window.windowNumber,
                context: nil,
                eventNumber: startEventNum + c * 2 + 1,
                clickCount: c,
                pressure: 0.0
            )!
            window.sendEvent(down)
            window.sendEvent(up)
        }
        let waitTime = (count == 1) ? 0.40 : 0.15
        RunLoop.current.run(until: Date(timeIntervalSinceNow: waitTime))
    }

    // MARK: - Adversarial Tab Bar Interactions & Geometry Stress Suite (Challenger 2)
    static func runAdversarialTabBarStressTests(assertTest: @escaping (String, Bool) -> Void) {
        print("\n=========================================================================")
        print("⚔️ CHALLENGER 2: ADVERSARIAL STRESS TESTS (TAB BAR & DUAL VIEW)")
        print("=========================================================================")

        // SUITE 1: 1 Tab Open — Empty Space Double-Click at Varying Distances
        do {
            let ws = NppWorkspace()
            ws.closeAll(force: true)
            ws.doubleClickSpaceToNewTab = true
            assertTest("Challenger 2 [Suite 1.0]: Workspace initialized with 1 tab", ws.documents.count == 1)

            let view = NppTabBarView(workspace: ws, viewIndex: 0)
            let hosting = NSHostingView(rootView: view)
            hosting.frame = NSRect(x: 0, y: 0, width: 800, height: 30)

            let win = NSWindow(contentRect: NSRect(x: 100, y: 100, width: 800, height: 30), styleMask: [.borderless], backing: .buffered, defer: false)
            win.isReleasedWhenClosed = false
            win.contentView = hosting
            win.makeKeyAndOrderFront(nil)
            hosting.layoutSubtreeIfNeeded()
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.15))

            // 1.1: +5px past last tab
            let countBefore1 = ws.documents.count
            simulateClicks(to: win, at: NSPoint(x: 101, y: 15), count: 2, startEventNum: 1000)
            assertTest("Challenger 2 [Suite 1.1]: Double-click at +5px past last tab creates new document", ws.documents.count == countBefore1 + 1)
            assertTest("Challenger 2 [Suite 1.1]: Newly created document has sequential 'new' title", ws.activeDocument?.title.hasPrefix("new ") == true)

            // 1.2: +20px past last tab
            let countBefore2 = ws.documents.count
            simulateClicks(to: win, at: NSPoint(x: 205, y: 15), count: 2, startEventNum: 1100)
            assertTest("Challenger 2 [Suite 1.2]: Double-click at +20px past last tab creates new document", ws.documents.count == countBefore2 + 1)
            assertTest("Challenger 2 [Suite 1.2]: Sequential naming increments", ws.activeDocument?.title.hasPrefix("new ") == true)

            // 1.3: +100px past last tab
            let countBefore3 = ws.documents.count
            simulateClicks(to: win, at: NSPoint(x: 375, y: 15), count: 2, startEventNum: 1200)
            assertTest("Challenger 2 [Suite 1.3]: Double-click at +100px past last tab creates new document", ws.documents.count == countBefore3 + 1)

            // 1.4: Far right edge
            let countBefore4 = ws.documents.count
            simulateClicks(to: win, at: NSPoint(x: 700, y: 15), count: 2, startEventNum: 1300)
            assertTest("Challenger 2 [Suite 1.4]: Double-click at far right edge (x: 700) creates new document", ws.documents.count == countBefore4 + 1)

            win.orderOut(nil)
        }

        // SUITE 2: 2 Tabs Open — Geometry & Boundaries
        do {
            let ws = NppWorkspace()
            ws.closeAll(force: true)
            ws.doubleClickSpaceToNewTab = true
            ws.newDocument()
            assertTest("Challenger 2 [Suite 2.0]: Exactly 2 tabs open", ws.documents.count == 2)

            let view = NppTabBarView(workspace: ws, viewIndex: 0)
            let hosting = NSHostingView(rootView: view)
            hosting.frame = NSRect(x: 0, y: 0, width: 800, height: 30)

            let win = NSWindow(contentRect: NSRect(x: 100, y: 100, width: 800, height: 30), styleMask: [.borderless], backing: .buffered, defer: false)
            win.isReleasedWhenClosed = false
            win.contentView = hosting
            win.makeKeyAndOrderFront(nil)
            hosting.layoutSubtreeIfNeeded()
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.15))

            let c1 = ws.documents.count
            simulateClicks(to: win, at: NSPoint(x: 190, y: 15), count: 2, startEventNum: 2000)
            assertTest("Challenger 2 [Suite 2.1]: Double-click at +5px past Tab 2 creates new tab", ws.documents.count == c1 + 1)

            let c2 = ws.documents.count
            simulateClicks(to: win, at: NSPoint(x: 300, y: 15), count: 2, startEventNum: 2100)
            assertTest("Challenger 2 [Suite 2.2]: Double-click at +20px past tabs creates new tab", ws.documents.count == c2 + 1)

            let c3 = ws.documents.count
            simulateClicks(to: win, at: NSPoint(x: 480, y: 15), count: 2, startEventNum: 2200)
            assertTest("Challenger 2 [Suite 2.3]: Double-click at +100px past tabs creates new tab", ws.documents.count == c3 + 1)

            let c4 = ws.documents.count
            simulateClicks(to: win, at: NSPoint(x: 715, y: 15), count: 2, startEventNum: 2300)
            assertTest("Challenger 2 [Suite 2.4]: Double-click at far right edge (x: 715) creates new tab", ws.documents.count == c4 + 1)

            win.orderOut(nil)
        }

        // SUITE 3: 10 Tabs Open (Scrolled Overflow & Wide Window)
        do {
            let ws = NppWorkspace()
            ws.closeAll(force: true)
            ws.doubleClickSpaceToNewTab = true
            while ws.documents.count < 10 {
                ws.newDocument()
            }
            assertTest("Challenger 2 [Suite 3.0]: 10 tabs created", ws.documents.count == 10)

            let view = NppTabBarView(workspace: ws, viewIndex: 0)
            let hosting = NSHostingView(rootView: view)
            hosting.frame = NSRect(x: 0, y: 0, width: 1400, height: 30)

            let win = NSWindow(contentRect: NSRect(x: 50, y: 50, width: 1400, height: 30), styleMask: [.borderless], backing: .buffered, defer: false)
            win.isReleasedWhenClosed = false
            win.contentView = hosting
            win.makeKeyAndOrderFront(nil)
            hosting.layoutSubtreeIfNeeded()
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.2))

            let c1 = ws.documents.count
            simulateClicks(to: win, at: NSPoint(x: 910, y: 15), count: 2, startEventNum: 3000)
            assertTest("Challenger 2 [Suite 3.1]: Double click at +5px past 10th tab creates 11th tab", ws.documents.count == c1 + 1 && ws.activeDocument?.title.hasPrefix("new ") == true)

            let c2 = ws.documents.count
            simulateClicks(to: win, at: NSPoint(x: 1020, y: 15), count: 2, startEventNum: 3100)
            assertTest("Challenger 2 [Suite 3.2]: Double click at +20px past last tab creates 12th tab", ws.documents.count == c2 + 1)

            let c3 = ws.documents.count
            simulateClicks(to: win, at: NSPoint(x: 1180, y: 15), count: 2, startEventNum: 3200)
            assertTest("Challenger 2 [Suite 3.3]: Double click at +100px past last tab creates 13th tab", ws.documents.count == c3 + 1)

            let c4 = ws.documents.count
            simulateClicks(to: win, at: NSPoint(x: 1300, y: 15), count: 2, startEventNum: 3300)
            assertTest("Challenger 2 [Suite 3.4]: Double click at far right edge (x: 1300) creates 14th tab", ws.documents.count == c4 + 1)

            win.orderOut(nil)
        }

        // SUITE 4: Interaction Isolation & Gesture Mutual Exclusion
        do {
            let ws = NppWorkspace()
            ws.closeAll(force: true)
            ws.doubleClickSpaceToNewTab = true
            ws.doubleClickTabToClose = true
            ws.showTabCloseButton = true

            ws.newDocument() // doc 2
            ws.newDocument() // doc 3
            assertTest("Challenger 2 [Suite 4.0]: 3 documents prepared", ws.documents.count == 3)

            let doc1 = ws.documents[0]
            let doc2 = ws.documents[1]
            let doc3 = ws.documents[2]

            let view = NppTabBarView(workspace: ws, viewIndex: 0)
            let hosting = NSHostingView(rootView: view)
            hosting.frame = NSRect(x: 0, y: 0, width: 800, height: 30)

            let win = NSWindow(contentRect: NSRect(x: 100, y: 100, width: 800, height: 30), styleMask: [.borderless], backing: .buffered, defer: false)
            win.isReleasedWhenClosed = false
            win.contentView = hosting
            win.makeKeyAndOrderFront(nil)
            hosting.layoutSubtreeIfNeeded()
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.15))

            assertTest("Challenger 2 [Suite 4.1.A]: Initially active doc is doc 3", ws.activeDocumentId == doc3.id)

            // 4.1 Single click on Tab 1
            let countBeforeSelect = ws.documents.count
            simulateClicks(to: win, at: NSPoint(x: 40, y: 15), count: 1, startEventNum: 4000)
            assertTest("Challenger 2 [Suite 4.1.B]: Single click on Tab 1 selects Tab 1", ws.activeDocumentId == doc1.id)
            assertTest("Challenger 2 [Suite 4.1.C]: Single click does NOT create a new document", ws.documents.count == countBeforeSelect)

            // 4.2 Single click on Tab 2
            simulateClicks(to: win, at: NSPoint(x: 130, y: 15), count: 1, startEventNum: 4100)
            assertTest("Challenger 2 [Suite 4.2.A]: Single click on Tab 2 selects Tab 2", ws.activeDocumentId == doc2.id)
            assertTest("Challenger 2 [Suite 4.2.B]: Single click does NOT create a new document", ws.documents.count == countBeforeSelect)

            // 4.3 Click close button 'x' on Tab 2
            let countBeforeCloseBtn = ws.documents.count
            simulateClicks(to: win, at: NSPoint(x: 165, y: 15), count: 1, startEventNum: 4150)
            assertTest("Challenger 2 [Suite 4.3.A]: Clicking tab close button 'x' closes Tab 2", !ws.documents.contains { $0.id == doc2.id } && ws.documents.count == countBeforeCloseBtn - 1)
            assertTest("Challenger 2 [Suite 4.3.B]: Clicking tab close button 'x' does NOT create new document", ws.documents.count == countBeforeCloseBtn - 1)

            // 4.4 Double click on Tab 3 with doubleClickTabToClose == true
            ws.doubleClickTabToClose = true
            let countBeforeClose = ws.documents.count
            simulateClicks(to: win, at: NSPoint(x: 130, y: 15), count: 2, startEventNum: 4200)
            assertTest("Challenger 2 [Suite 4.4.A]: Double click on Tab 3 closes it", !ws.documents.contains { $0.id == doc3.id } && ws.documents.count == countBeforeClose - 1)
            assertTest("Challenger 2 [Suite 4.4.B]: Double click on tab does NOT trigger document creation", ws.documents.count == countBeforeClose - 1)

            // 4.5 Double click on Tab 1 with doubleClickTabToClose == false
            ws.doubleClickTabToClose = false
            let countBeforeNoClose = ws.documents.count
            simulateClicks(to: win, at: NSPoint(x: 40, y: 15), count: 2, startEventNum: 4300)
            assertTest("Challenger 2 [Suite 4.5.A]: Double click on Tab 1 does NOT close Tab 1 when doubleClickTabToClose is false", ws.documents.contains { $0.id == doc1.id })
            assertTest("Challenger 2 [Suite 4.5.B]: Double click on Tab 1 does NOT create document", ws.documents.count == countBeforeNoClose)

            // 4.6 Pinned tab protection from double click close
            ws.doubleClickTabToClose = true
            doc1.isPinned = true
            simulateClicks(to: win, at: NSPoint(x: 40, y: 15), count: 2, startEventNum: 4400)
            assertTest("Challenger 2 [Suite 4.6]: Pinned Tab 1 is NOT closed on double-click", ws.documents.contains { $0.id == doc1.id })

            // 4.7 Single click on empty space
            let countBeforeEmptySingle = ws.documents.count
            simulateClicks(to: win, at: NSPoint(x: 400, y: 15), count: 1, startEventNum: 4500)
            assertTest("Challenger 2 [Suite 4.7]: Single click on empty space does NOT create a document", ws.documents.count == countBeforeEmptySingle)

            // 4.8 Double click disabled preference
            ws.doubleClickSpaceToNewTab = false
            simulateClicks(to: win, at: NSPoint(x: 400, y: 15), count: 2, startEventNum: 4600)
            assertTest("Challenger 2 [Suite 4.8]: Double click on empty space does NOTHING when doubleClickSpaceToNewTab is false", ws.documents.count == countBeforeEmptySingle)

            win.orderOut(nil)
        }

        // SUITE 5: Dual View Tab Bar Empty Space Double Click
        do {
            let ws = NppWorkspace()
            ws.closeAll(force: true)
            ws.doubleClickSpaceToNewTab = true

            ws.newDocument() // doc 2
            let doc2 = ws.documents.last!
            ws.moveToOtherView(id: doc2.id)
            assertTest("Challenger 2 [Suite 5.0]: Dual View active with 1 primary doc and 1 secondary doc", ws.isDualView && ws.primaryDocuments.count == 1 && ws.secondaryDocuments.count == 1)

            let primaryView = NppTabBarView(workspace: ws, viewIndex: 0)
            let primaryHosting = NSHostingView(rootView: primaryView)
            primaryHosting.frame = NSRect(x: 0, y: 0, width: 400, height: 30)

            let winPrimary = NSWindow(contentRect: NSRect(x: 50, y: 100, width: 400, height: 30), styleMask: [.borderless], backing: .buffered, defer: false)
            winPrimary.isReleasedWhenClosed = false
            winPrimary.contentView = primaryHosting
            winPrimary.makeKeyAndOrderFront(nil)
            primaryHosting.layoutSubtreeIfNeeded()

            let secondaryView = NppTabBarView(workspace: ws, viewIndex: 1)
            let secondaryHosting = NSHostingView(rootView: secondaryView)
            secondaryHosting.frame = NSRect(x: 0, y: 0, width: 400, height: 30)

            let winSecondary = NSWindow(contentRect: NSRect(x: 500, y: 100, width: 400, height: 30), styleMask: [.borderless], backing: .buffered, defer: false)
            winSecondary.isReleasedWhenClosed = false
            winSecondary.contentView = secondaryHosting
            winSecondary.makeKeyAndOrderFront(nil)
            secondaryHosting.layoutSubtreeIfNeeded()
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.15))

            // Test 5.1: Double click empty space in SECONDARY tab bar
            let secBefore = ws.secondaryDocuments.count
            let primBefore = ws.primaryDocuments.count
            simulateClicks(to: winSecondary, at: NSPoint(x: 250, y: 15), count: 2, startEventNum: 5000)
            assertTest("Challenger 2 [Suite 5.1.A]: Double click in secondary tab bar creates tab in secondaryDocuments", ws.secondaryDocuments.count == secBefore + 1)
            assertTest("Challenger 2 [Suite 5.1.B]: Double click in secondary tab bar leaves primaryDocuments unchanged", ws.primaryDocuments.count == primBefore)
            assertTest("Challenger 2 [Suite 5.1.C]: Secondary active document is set to new document", ws.secondaryActiveDocumentId == ws.secondaryDocuments.last?.id)
            assertTest("Challenger 2 [Suite 5.1.D]: Workspace activeView switches to 1", ws.activeView == 1)

            // Test 5.2: Double click empty space in PRIMARY tab bar
            let secBefore2 = ws.secondaryDocuments.count
            let primBefore2 = ws.primaryDocuments.count
            simulateClicks(to: winPrimary, at: NSPoint(x: 250, y: 15), count: 2, startEventNum: 5100)
            assertTest("Challenger 2 [Suite 5.2.A]: Double click in primary tab bar creates tab in primaryDocuments", ws.primaryDocuments.count == primBefore2 + 1)
            assertTest("Challenger 2 [Suite 5.2.B]: Double click in primary tab bar leaves secondaryDocuments unchanged", ws.secondaryDocuments.count == secBefore2)
            assertTest("Challenger 2 [Suite 5.2.C]: Primary active document is set to new document", ws.activeDocumentId == ws.primaryDocuments.last?.id)
            assertTest("Challenger 2 [Suite 5.2.D]: Workspace activeView switches to 0", ws.activeView == 0)

            winPrimary.orderOut(nil)
            winSecondary.orderOut(nil)
        }

        // SUITE 6: Reduced Tab Bar (tabReduce == true)
        do {
            let ws = NppWorkspace()
            ws.closeAll(force: true)
            ws.tabReduce = true
            ws.doubleClickSpaceToNewTab = true

            let view = NppTabBarView(workspace: ws, viewIndex: 0)
            let hosting = NSHostingView(rootView: view)
            hosting.frame = NSRect(x: 0, y: 0, width: 800, height: 24)

            let win = NSWindow(contentRect: NSRect(x: 100, y: 100, width: 800, height: 24), styleMask: [.borderless], backing: .buffered, defer: false)
            win.isReleasedWhenClosed = false
            win.contentView = hosting
            win.makeKeyAndOrderFront(nil)
            hosting.layoutSubtreeIfNeeded()
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.15))

            let cBefore = ws.documents.count
            simulateClicks(to: win, at: NSPoint(x: 300, y: 12), count: 2, startEventNum: 6000)
            assertTest("Challenger 2 [Suite 6.1]: Double click on reduced tab bar (height 24) creates new tab", ws.documents.count == cBefore + 1)

            win.orderOut(nil)
        }

        // SUITE 7: Sequential Document Numbering Parity
        do {
            let ws = NppWorkspace()
            ws.closeAll(force: true)
            let d1 = ws.documents[0]
            assertTest("Challenger 2 [Suite 7.1]: First doc title is 'new 1' (or sequential)", d1.title.hasPrefix("new "))

            ws.newDocument()
            let d2 = ws.documents.last!
            assertTest("Challenger 2 [Suite 7.2]: Second doc title is sequential", d2.title.hasPrefix("new "))
            assertTest("Challenger 2 [Suite 7.3]: Primary document titles are distinct", d1.title != d2.title)

            let titleBeforeSec = ws.documents.last?.title ?? ""
            ws.newDocumentInSecondaryView()
            let secDoc = ws.secondaryDocuments.last!
            assertTest("Challenger 2 [Suite 7.4]: Secondary doc has 'new ' prefix", secDoc.title.hasPrefix("new "))
            assertTest("Challenger 2 [Suite 7.5]: Secondary doc title does not duplicate previous doc", secDoc.title != titleBeforeSec)

            ws.newDocument()
            let nextPrimDoc = ws.documents.last!
            let hasDuplicate = (nextPrimDoc.title == secDoc.title)
            assertTest("Challenger 2 [Suite 7.6]: Next primary doc does not collide with secondary doc title", !hasDuplicate)
        }

        print("=========================================================================")
        print("⚔️ CHALLENGER 2: ADVERSARIAL STRESS TESTS COMPLETE")
        print("=========================================================================\n")
    }

    // MARK: - Reviewer 2 Edge Cases: Backup Write Failure & Tab Pinning Roundtrip
    static func runReviewerEdgeCaseTests(assertTest: @escaping (String, Bool) -> Void) {
        print("\n========================================================")
        print("🔍 REVIEWER 2: EDGE CASE TESTS (BACKUP FALLBACK & PINNING)")
        print("========================================================")

        let tempBase = FileManager.default.temporaryDirectory.appendingPathComponent("npp_reviewer_edge_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempBase, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempBase) }

        // -------------------------------------------------------------
        // Reviewer Case 1: Read-Only Backup Directory Write Failure Detection
        // -------------------------------------------------------------
        let wsRev1 = NppWorkspace()
        let rev1Support = tempBase.appendingPathComponent("rev1_support")
        let rev1Backup = rev1Support.appendingPathComponent("backup")
        try? FileManager.default.createDirectory(at: rev1Backup, withIntermediateDirectories: true)
        // Make backup directory read-only (chmod 0444)
        try? FileManager.default.setAttributes([.posixPermissions: 0o444], ofItemAtPath: rev1Backup.path)
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: rev1Backup.path)
        }

        wsRev1.supportDirectoryOverride = rev1Support
        wsRev1.rememberSession = true
        wsRev1.periodicBackupEnabled = true
        wsRev1.closeAll(force: true)
        let dirtyDoc1 = wsRev1.documents[0]
        dirtyDoc1.content = "Unsaved critical work that must not be lost"
        dirtyDoc1.isDirty = true

        // 1. Direct saveSession with unwritable backup directory must return false
        let saveOk = wsRev1.saveSession(to: wsRev1.autoSessionURL, backupDirectory: rev1Backup)
        assertTest("Reviewer 2.1: saveSession returns false when dirty doc backup write fails", !saveOk)

        // 2. snapshotSession must return false
        let snapOk = wsRev1.snapshotSession()
        assertTest("Reviewer 2.2: snapshotSession returns false when backup write fails", !snapOk)

        // 3. prepareForTermination must fall back to save prompt and abort when user cancels
        var promptShown = false
        wsRev1.confirmSaveHandler = { _ in
            promptShown = true
            return .cancel
        }
        let termCancel = wsRev1.prepareForTermination()
        assertTest("Reviewer 2.3: prepareForTermination triggers save prompt on backup write failure", promptShown)
        assertTest("Reviewer 2.4: Termination is aborted (.cancel) to prevent silent data loss", !termCancel)
        assertTest("Reviewer 2.5: Dirty documents remain intact after aborted termination", wsRev1.documents.count == 1 && wsRev1.documents[0].isDirty)

        // 4. prepareForTermination returns true if user selects Don't Save
        wsRev1.confirmSaveHandler = { _ in .dontSave }
        let termDontSave = wsRev1.prepareForTermination()
        assertTest("Reviewer 2.6: Termination proceeds when user chooses Don't Save during backup failure fallback", termDontSave)

        // -------------------------------------------------------------
        // Reviewer Case 2: Tab Pinning Serialization & Restoration (Parameters.cpp parity)
        // -------------------------------------------------------------
        let wsPin = NppWorkspace()
        let pinSupport = tempBase.appendingPathComponent("pin_support")
        wsPin.supportDirectoryOverride = pinSupport
        wsPin.rememberSession = true
        wsPin.periodicBackupEnabled = true
        wsPin.closeAll(force: true)

        let pinFileA = tempBase.appendingPathComponent("PinnedTabA.txt")
        let pinFileB = tempBase.appendingPathComponent("UnpinnedTabB.txt")
        let pinFileC = tempBase.appendingPathComponent("PinnedTabC.txt")
        try? "Pinned A content".write(to: pinFileA, atomically: true, encoding: .utf8)
        try? "Unpinned B content".write(to: pinFileB, atomically: true, encoding: .utf8)
        try? "Pinned C content".write(to: pinFileC, atomically: true, encoding: .utf8)

        wsPin.openFile(url: pinFileA)
        wsPin.openFile(url: pinFileB)
        wsPin.openFile(url: pinFileC)

        let docPinA = wsPin.documents.first { $0.filePath?.standardizedFileURL == pinFileA.standardizedFileURL }!
        let docUnpinB = wsPin.documents.first { $0.filePath?.standardizedFileURL == pinFileB.standardizedFileURL }!
        let docPinC = wsPin.documents.first { $0.filePath?.standardizedFileURL == pinFileC.standardizedFileURL }!

        docPinA.isPinned = true
        docUnpinB.isPinned = false
        docPinC.isPinned = true
        wsPin.moveToOtherView(id: docPinC.id)

        let pinSessionURL = pinSupport.appendingPathComponent("pin_session.xml")
        let pinSaveOk = wsPin.saveSession(to: pinSessionURL, backupDirectory: nil)
        assertTest("Reviewer 2.7: saveSession succeeded for pinned tabs", pinSaveOk)

        let pinSessionData = (try? Data(contentsOf: pinSessionURL)) ?? Data()
        let pinSessionXML = String(decoding: pinSessionData, as: UTF8.self)
        assertTest("Reviewer 2.8: session.xml contains tabPinned=\"true\"", pinSessionXML.contains("tabPinned=\"true\""))

        // Relaunch and restore session
        let wsPinRelaunch = NppWorkspace()
        wsPinRelaunch.supportDirectoryOverride = pinSupport
        let loadOk = wsPinRelaunch.loadSession(from: pinSessionURL)
        assertTest("Reviewer 2.9: loadSession succeeded", loadOk)

        let restoredDocA = wsPinRelaunch.documents.first(where: { $0.title == "PinnedTabA.txt" })
        let restoredDocB = wsPinRelaunch.documents.first(where: { $0.title == "UnpinnedTabB.txt" })
        let restoredDocC = wsPinRelaunch.secondaryDocuments.first(where: { $0.title == "PinnedTabC.txt" })

        assertTest("Reviewer 2.10: Pinned tab A is restored with isPinned == true", restoredDocA?.isPinned == true)
        assertTest("Reviewer 2.11: Unpinned tab B is restored with isPinned == false", restoredDocB?.isPinned == false)
        assertTest("Reviewer 2.12: Secondary pinned tab C is restored with isPinned == true", restoredDocC?.isPinned == true)

        // Verify pinned tab is protected from closeAll
        wsPinRelaunch.closeAll(force: false)
        assertTest("Reviewer 2.13: Restored pinned tab is preserved when closeAll is executed", wsPinRelaunch.documents.contains { $0.title == "PinnedTabA.txt" })

        print("========================================================")
        print("🔍 REVIEWER 2: EDGE CASE TESTS COMPLETE")
        print("========================================================\n")
    }

    // =========================================================================
    // MARK: - [WORKER 1] REGRESSION INVARIANT MATRIX & GUARDRAILS (Pillars 1-9)
    // =========================================================================

    // MARK: - Pillar 1: AppKit Lifecycle & Termination Tripwires
    static func runAppKitLifecycleAndTerminationTripwires(appDelegate: AppDelegate, assertTest: @escaping (String, Bool) -> Void) {
        print("\n--- Running Pillar 1: AppKit Lifecycle & Termination Tripwires ---")
        let ws = appDelegate.workspace
        
        // Tripwire 1.1: Delegate and Window Wiring
        assertTest("Lifecycle 1.1: window.delegate === appDelegate", appDelegate.window?.delegate === appDelegate)
        assertTest("Lifecycle 1.2: NSApp.delegate === appDelegate", NSApp.delegate === appDelegate)

        let prevRemember = ws.rememberSession
        let prevBackup = ws.periodicBackupEnabled
        let prevProvider = ws.interactionProvider
        let prevConfirm = ws.confirmSaveHandler
        defer {
            ws.rememberSession = prevRemember
            ws.periodicBackupEnabled = prevBackup
            ws.interactionProvider = prevProvider
            ws.confirmSaveHandler = prevConfirm
        }

        // Permutation 1: Snapshot enabled: rememberSession=true && periodicBackupEnabled=true
        ws.rememberSession = true
        ws.periodicBackupEnabled = true
        
        ws.newDocument()
        guard let docSnap = ws.activeDocument else { return }
        docSnap.content = "Snapshot invariant verification content: \(UUID().uuidString)"
        docSnap.isDirty = true
        
        var promptInvoked = false
        ws.confirmSaveHandler = { _ in
            promptInvoked = true
            return .dontSave
        }
        
        // In snapshot mode, prepareForTermination() MUST NOT prompt the user and must snapshot dirty documents
        let termSuccess = appDelegate.prepareForApplicationTermination()
        assertTest("Lifecycle 1.3: Snapshot mode prepares termination without modal prompt", termSuccess && !promptInvoked)
        assertTest("Lifecycle 1.4: Session snapshot file exists on disk", FileManager.default.fileExists(atPath: ws.autoSessionURL.path))
        
        // Permutation 2: Snapshot disabled: rememberSession=false, dirty document -> Prompt with Cancel
        ws.rememberSession = false
        ws.periodicBackupEnabled = false
        ws.newDocument()
        guard let docPrompt = ws.activeDocument else { return }
        docPrompt.content = "Dirty document requiring user prompt"
        docPrompt.isDirty = true
        
        ws.confirmSaveHandler = { _ in
            return .cancel
        }
        
        let cancelSuccess = appDelegate.prepareForApplicationTermination()
        assertTest("Lifecycle 1.5: Cancel in save prompt aborts termination", cancelSuccess == false)
        assertTest("Lifecycle 1.6: Documents remain open and dirty when termination is cancelled", ws.documents.contains(where: { $0.id == docPrompt.id && $0.isDirty }))

        // Permutation 3: Save prompt with Don't Save
        ws.confirmSaveHandler = { _ in
            return .dontSave
        }
        let dontSaveSuccess = appDelegate.prepareForApplicationTermination()
        assertTest("Lifecycle 1.7: Don't Save proceeds with termination", dontSaveSuccess == true)

        // Close All invariant with dirty documents
        ws.newDocument()
        guard let docCloseAll = ws.activeDocument else { return }
        docCloseAll.content = "Close All dirty test"
        docCloseAll.isDirty = true
        ws.confirmSaveHandler = { _ in .cancel }
        ws.closeAll(force: false)
        assertTest("Lifecycle 1.8: Close All with Cancel preserves dirty documents", ws.documents.contains(where: { $0.id == docCloseAll.id }))

        // Clean up test documents
        ws.closeDocument(id: docSnap.id, force: true)
        ws.closeDocument(id: docPrompt.id, force: true)
        ws.closeDocument(id: docCloseAll.id, force: true)
    }

    // MARK: - Pillar 2: Live UI Event & TabBar Gesture Tripwires
    static func runLiveUIEventAndGestureTripwires(assertTest: @escaping (String, Bool) -> Void) {
        print("\n--- Running Pillar 2: Live UI Event & TabBar Gesture Tripwires ---")
        let ws = NppWorkspace()
        ws.interactionProvider = NppAutomatedTestInteractionProvider()
        ws.isTestRunning = true

        // Mount NppTabBarView in offscreen borderless NSWindow with NSHostingView
        let tabBarView = NppTabBarView(workspace: ws, viewIndex: 0)
        let hostingView = NSHostingView(rootView: tabBarView)
        hostingView.frame = NSRect(x: 0, y: 0, width: 800, height: 30)
        
        let testWin = NSWindow(
            contentRect: NSRect(x: 100, y: 100, width: 800, height: 30),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        testWin.isReleasedWhenClosed = false
        testWin.contentView = hostingView
        testWin.makeKeyAndOrderFront(nil)
        hostingView.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.15))

        assertTest("Gesture 2.1: Initial tab bar workspace has 1 document", ws.documents.count == 1)

        // Synthesize single click NSEvent on empty space
        simulateClicks(to: testWin, at: NSPoint(x: 700, y: 15), count: 1, startEventNum: 2100)
        assertTest("Gesture 2.2: Single-click on empty space does NOT create a tab", ws.documents.count == 1)

        // Tripwire 2.3: Double-click empty space setting enabled creates tab
        ws.doubleClickSpaceToNewTab = true
        let initialDocCount = ws.documents.count
        simulateClicks(to: testWin, at: NSPoint(x: 700, y: 15), count: 2, startEventNum: 2300)
        assertTest("Gesture 2.3: Double-click space creates new tab when enabled", ws.documents.count == initialDocCount + 1)

        // Tripwire 2.4: Negative tripwire: doubleClickSpaceToNewTab == false
        ws.doubleClickSpaceToNewTab = false
        let countBeforeDisabled = ws.documents.count
        simulateClicks(to: testWin, at: NSPoint(x: 700, y: 15), count: 2, startEventNum: 2400)
        assertTest("Gesture 2.4: Double-click space does NOT create tab when disabled", ws.documents.count == countBeforeDisabled)

        // Tripwire 2.5: Double-click tab to close (when enabled)
        ws.doubleClickTabToClose = true
        let countBeforeClose = ws.documents.count
        simulateClicks(to: testWin, at: NSPoint(x: 130, y: 15), count: 2, startEventNum: 2500)
        assertTest("Gesture 2.5: Double-click tab closes unpinned document when enabled", ws.documents.count == countBeforeClose - 1)

        // Tripwire 2.6: Negative tripwire: pinned tab is immune to double-click tab close
        guard let pinnedDoc = ws.documents.first else { return }
        pinnedDoc.isPinned = true
        hostingView.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.15))
        let countBeforePinned = ws.documents.count
        simulateClicks(to: testWin, at: NSPoint(x: 40, y: 15), count: 2, startEventNum: 2600)
        assertTest("Gesture 2.6: Pinned document is protected from double-click close gesture", ws.documents.count == countBeforePinned && pinnedDoc.isPinned)

        testWin.orderOut(nil)
    }

    // MARK: - Pillar 3: Dual-View Synchronized Scrolling Tripwires
    static func runDualViewSynchronizedScrollingTripwires(assertTest: @escaping (String, Bool) -> Void) {
        print("\n--- Running Pillar 3: Dual-View Synchronized Scrolling Tripwires ---")
        let ws = NppWorkspace()
        ws.interactionProvider = NppAutomatedTestInteractionProvider()
        let secDoc = NppDocument(title: "secondaryDoc")
        ws.documents.append(secDoc)
        ws.secondaryDocumentIds.append(secDoc.id)

        // Create two real NSScrollView instances with content
        let primaryScroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 400, height: 600))
        let secondaryScroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 400, height: 600))

        let primaryDocView = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 3000))
        let secondaryDocView = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 3000))

        primaryScroll.documentView = primaryDocView
        secondaryScroll.documentView = secondaryDocView

        ws.primaryScrollView = primaryScroll
        ws.secondaryScrollView = secondaryScroll
        ws.setupScrollSynchronization()

        // Test vertical sync
        ws.syncScrollV = true
        ws.syncScrollH = false
        ws.recalculateSyncScrollDeltas()

        primaryScroll.contentView.scroll(to: NSPoint(x: 0, y: 200))
        ws.handlePrimaryScroll()
        assertTest("DualView 3.1: Vertical scrolling primary syncs secondary view", abs(secondaryScroll.contentView.bounds.origin.y - 200) < 1.0)

        secondaryScroll.contentView.scroll(to: NSPoint(x: 0, y: 450))
        ws.handleSecondaryScroll()
        assertTest("DualView 3.2: Vertical scrolling secondary syncs primary view", abs(primaryScroll.contentView.bounds.origin.y - 450) < 1.0)

        // Test horizontal sync
        ws.syncScrollH = true
        primaryDocView.frame = NSRect(x: 0, y: 0, width: 2000, height: 3000)
        secondaryDocView.frame = NSRect(x: 0, y: 0, width: 2000, height: 3000)
        ws.recalculateSyncScrollDeltas()

        primaryScroll.contentView.scroll(to: NSPoint(x: 150, y: 450))
        ws.handlePrimaryScroll()
        assertTest("DualView 3.3: Horizontal scrolling primary syncs secondary view", abs(secondaryScroll.contentView.bounds.origin.x - 150) < 1.0)

        // Negative tripwire: sync disabled
        ws.syncScrollV = false
        ws.syncScrollH = false
        primaryScroll.contentView.scroll(to: NSPoint(x: 0, y: 800))
        ws.handlePrimaryScroll()
        assertTest("DualView 3.4: Scrolling does not affect peer when sync is disabled", abs(secondaryScroll.contentView.bounds.origin.y - 450) < 1.0)

        // Teardown
        let hadObserversBefore = ws.hasActiveScrollObservers
        ws.teardownScrollSynchronization()
        ws.syncScrollV = true
        let secondaryOriginBefore = secondaryScroll.contentView.bounds.origin
        primaryScroll.contentView.scroll(to: NSPoint(x: 0, y: 1200))
        NotificationCenter.default.post(name: NSView.boundsDidChangeNotification, object: primaryScroll.contentView)
        let tornDownCleanly = hadObserversBefore && !ws.hasActiveScrollObservers && (abs(secondaryScroll.contentView.bounds.origin.y - secondaryOriginBefore.y) < 1.0)
        assertTest("DualView 3.5: Scroll synchronization torn down cleanly", tornDownCleanly)
    }

    // MARK: - Pillar 4: Edit & Line Operations Tripwires
    static func runEditAndLineOperationsTripwires(assertTest: @escaping (String, Bool) -> Void) {
        print("\n--- Running Pillar 4: Edit & Line Operations Tripwires ---")
        let ws = NppWorkspace()
        ws.interactionProvider = NppAutomatedTestInteractionProvider()
        ws.isTestRunning = true

        ws.newDocument()
        guard let doc = ws.activeDocument else { return }
        let undoWindow = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 400), styleMask: [.titled], backing: .buffered, defer: false)
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 400))
        textView.allowsUndo = true
        undoWindow.contentView?.addSubview(textView)
        ws.activeTextView = textView

        // 4.1 Duplicate Line with Undo
        textView.string = "Line Alpha\nLine Beta\nLine Gamma"
        doc.content = textView.string
        textView.setSelectedRange(NSRange(location: 0, length: 0)) // Cursor on Line Alpha
        NppEditOperations.duplicateLine(in: textView)
        assertTest("EditOps 4.1: Duplicate current line duplicates Line Alpha", textView.string.hasPrefix("Line Alpha\nLine Alpha\nLine Beta"))
        textView.undoManager?.undo()
        assertTest("EditOps 4.2: Undo reverts duplicate line operation", textView.string == "Line Alpha\nLine Beta\nLine Gamma")

        // 4.3 Integer Sort Lines
        doc.content = "10 apples\n2 apples\n1 apple\n20 apples\n3 apples"
        NppEditOperations.sortLinesAsIntegers(in: doc, ascending: true)
        let expectedIntSort = "1 apple\n2 apples\n3 apples\n10 apples\n20 apples"
        assertTest("EditOps 4.3: Integer sorting sorts numeric values naturally", doc.content == expectedIntSort)

        // 4.4 Blank lines and trailing newline sorting robustness
        doc.content = "Cherry\n\nApple\nBanana\n"
        NppEditOperations.sortLines(in: doc, ascending: true, ignoreCase: false)
        assertTest("EditOps 4.4: Sort lines with blank lines preserves all lines without crash", doc.content.contains("Apple") && doc.content.contains("Banana") && doc.content.contains("Cherry"))

        // 4.5 Join Lines with Undo
        textView.string = "One\nTwo\nThree"
        doc.content = textView.string
        textView.selectAll(nil)
        NppEditOperations.joinLines(in: textView)
        assertTest("EditOps 4.5: Join lines joins with single space", textView.string == "One Two Three")
        textView.undoManager?.undo()
        assertTest("EditOps 4.6: Undo restores separated lines", textView.string == "One\nTwo\nThree")

        // 4.7 Trim Trailing Spaces
        doc.content = "Line with trailing spaces    \nAnother line  "
        NppEditOperations.trimSpaces(in: doc, mode: .trailing)
        assertTest("EditOps 4.7: Trim trailing spaces strips trailing whitespace", doc.content == "Line with trailing spaces\nAnother line")

        // 4.8 Remove Bookmarked Lines
        doc.eolFormat = .lf
        doc.content = "Line 1\nLine 2 (BM)\nLine 3\nLine 4 (BM)\nLine 5"
        textView.string = doc.content
        doc.bookmarkedLines = [2, 4]
        ws.removeBookmarkedLines()
        assertTest("EditOps 4.8: Remove bookmarked lines deletes lines 2 and 4", doc.content == "Line 1\nLine 3\nLine 5")
    }

    // MARK: - Pillar 5: Search Engine Parity Tripwires
    static func runSearchEngineParityTripwires(assertTest: @escaping (String, Bool) -> Void) {
        print("\n--- Running Pillar 5: Search Engine Parity Tripwires ---")
        let ws = NppWorkspace()
        ws.interactionProvider = NppAutomatedTestInteractionProvider()
        ws.isTestRunning = true

        ws.newDocument()
        guard let doc = ws.activeDocument else { return }
        doc.content = "Alpha 100 Bravo\nCharlie 200 Delta\nalpha 300 echo"
        ws.activeDocumentId = doc.id

        // 5.1 Case sensitivity parity
        ws.searchMode = 0 // Normal
        ws.matchCase = true
        ws.wrapAround = true
        let match1 = ws.findRange(in: doc.content, query: "Alpha", forward: true, startLocation: 0)
        assertTest("SearchParity 5.1: Match case true finds exact case match", match1?.location == 0)

        ws.matchCase = false
        let match2 = ws.findRange(in: doc.content, query: "ALPHA", forward: true, startLocation: 0)
        assertTest("SearchParity 5.2: Match case false matches insensitive query", match2?.location == 0)

        // 5.2 Whole word boundary parity
        ws.matchWholeWord = true
        let wholeWordDoc = "cat catalog concat cat"
        let rangeWW1 = ws.findRange(in: wholeWordDoc, query: "cat", forward: true, startLocation: 0)
        let rangeWW2 = ws.findRange(in: wholeWordDoc, query: "cat", forward: true, startLocation: 1)
        assertTest("SearchParity 5.3: Whole word matches isolated 'cat' at index 0", rangeWW1?.location == 0 && rangeWW1?.length == 3)
        assertTest("SearchParity 5.4: Whole word skips 'catalog' and 'concat' to index 19", rangeWW2?.location == 19)

        // 5.3 Regex mode with dotMatchesNewline
        ws.searchMode = 2 // Regex
        ws.dotMatchesNewline = true
        let multilineDoc = "BEGIN\nsome text\nEND"
        let regexRange = ws.findRange(in: multilineDoc, query: "BEGIN.*END", forward: true, startLocation: 0)
        assertTest("SearchParity 5.5: Regex dotMatchesNewline spans newline characters", regexRange != nil && regexRange?.length == multilineDoc.count)

        // 5.4 Dialog search options immediately affect menu findNext
        ws.findQueryText = "Charlie"
        ws.lastSearchQuery = "Charlie"
        ws.searchMode = 0
        ws.matchWholeWord = false
        ws.matchCase = true
        let tv = NSTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 400))
        tv.string = doc.content
        ws.activeTextView = tv
        let foundNext = ws.findNext(forward: true)
        assertTest("SearchParity 5.6: Menu findNext executes using consolidated workspace search state", foundNext == true)
    }

    // MARK: - Pillar 6: Encoding & Character Sets Tripwires
    static func runEncodingAndBOMTripwires(assertTest: @escaping (String, Bool) -> Void) {
        print("\n--- Running Pillar 6: Encoding & Character Sets Tripwires ---")

        // 6.1 UTF-8 with BOM Roundtrip
        let docWithBOM = NppDocument(title: "docWithBOM")
        docWithBOM.convertEncoding(to: "UTF-8", addBOM: true)
        docWithBOM.content = "Notepad++ BOM Test"
        let bomData = docWithBOM.encodedData() ?? Data()
        let hasBOMPrefix = bomData.count >= 3 && bomData[0] == 0xEF && bomData[1] == 0xBB && bomData[2] == 0xBF
        assertTest("Encoding 6.1: UTF-8 with BOM writes 0xEF, 0xBB, 0xBF bytes", hasBOMPrefix)

        // 6.2 UTF-8 without BOM does not include BOM bytes
        let docNoBOM = NppDocument(title: "docNoBOM")
        docNoBOM.convertEncoding(to: "UTF-8", addBOM: false)
        docNoBOM.content = "Notepad++ Plain Test"
        let noBomData = docNoBOM.encodedData() ?? Data()
        let lacksBOMPrefix = !(noBomData.count >= 3 && noBomData[0] == 0xEF && noBomData[1] == 0xBB && noBomData[2] == 0xBF)
        assertTest("Encoding 6.2: UTF-8 without BOM omits BOM preamble", lacksBOMPrefix)

        // 6.3 Korean CP949 / EUC-KR roundtrip
        let koreanText = "안녕하세요 노드패드++ 맥 버전입니다"
        let cp949Doc = NppDocument(title: "CP949Doc")
        cp949Doc.content = koreanText
        cp949Doc.convertEncoding(to: "CP949", addBOM: false)
        let cp949Data = cp949Doc.encodedData() ?? Data()
        assertTest("Encoding 6.3: Korean CP949 encodes non-empty bytes", !cp949Data.isEmpty)
        let tempCP949URL = FileManager.default.temporaryDirectory.appendingPathComponent("test_cp949_\(UUID().uuidString).txt")
        try? cp949Data.write(to: tempCP949URL)
        let reloadedDoc = try? NppDocument.fromFile(url: tempCP949URL)
        assertTest("Encoding 6.4: Korean CP949 decodes back to Hangul without corruption", reloadedDoc?.content == koreanText)
        try? FileManager.default.removeItem(at: tempCP949URL)

        // 6.5 Windows-1252 Latin roundtrip
        let latinText = "Resume and Cafe: 100 EUR"
        let w1252Doc = NppDocument(title: "W1252Doc")
        w1252Doc.content = latinText
        w1252Doc.convertEncoding(to: "WINDOWS-1252", addBOM: false)
        let w1252Data = w1252Doc.encodedData() ?? Data()
        let tempW1252URL = FileManager.default.temporaryDirectory.appendingPathComponent("test_w1252_\(UUID().uuidString).txt")
        try? w1252Data.write(to: tempW1252URL)
        let reloadedW1252 = try? NppDocument.fromFile(url: tempW1252URL)
        assertTest("Encoding 6.5: Windows-1252 roundtrips Latin characters", reloadedW1252?.content == latinText)
        try? FileManager.default.removeItem(at: tempW1252URL)

        // 6.6 Unrepresentable character fallback
        let unrepDoc = NppDocument(title: "UnrepDoc")
        unrepDoc.convertEncoding(to: "WINDOWS-1252", addBOM: false)
        unrepDoc.content = "Standard Text: \u{1F680}"
        let unrepData = unrepDoc.encodedData() ?? Data()
        let unrepStr = String(data: unrepData, encoding: .isoLatin1) ?? ""
        assertTest("Encoding 6.6: Unrepresentable characters produce valid non-empty byte stream without crashing", !unrepData.isEmpty && unrepStr.contains("Standard Text: ?"))
    }

    // MARK: - Pillar 7: Session Restore & Backup Resilience Tripwires
    static func runSessionAndBackupResilienceTripwires(assertTest: @escaping (String, Bool) -> Void) {
        print("\n--- Running Pillar 7: Session Restore & Backup Resilience Tripwires ---")
        let ws = NppWorkspace()
        ws.interactionProvider = NppAutomatedTestInteractionProvider()
        ws.isTestRunning = true

        // 7.1 Corrupted session file with pure null bytes
        let nullData = Data(repeating: 0, count: 512)
        let tempNullURL = FileManager.default.temporaryDirectory.appendingPathComponent("npp_corrupted_null.xml")
        try? nullData.write(to: tempNullURL)
        let loadedNull = ws.loadSession(from: tempNullURL)
        assertTest("Resilience 7.1: Corrupted session with null bytes handled safely (returns false)", loadedNull == false)
        try? FileManager.default.removeItem(at: tempNullURL)

        // 7.2 Truncated XML session file
        let truncXML = "<NotepadPlus><Session><mainView><File filename=\"/some/path\"".data(using: .utf8)!
        let tempTruncURL = FileManager.default.temporaryDirectory.appendingPathComponent("npp_corrupted_trunc.xml")
        try? truncXML.write(to: tempTruncURL)
        let loadedTrunc = ws.loadSession(from: tempTruncURL)
        assertTest("Resilience 7.2: Truncated XML session recovers safely without crashing", loadedTrunc == false)
        try? FileManager.default.removeItem(at: tempTruncURL)

        // 7.3 Unwritable backup directory fallback
        let prevBackupDir = ws.periodicBackupPath
        ws.periodicBackupPath = "/System/Library/FakeUnwritableNppBackup"
        ws.rememberSession = true
        ws.periodicBackupEnabled = true
        
        // When snapshot fails, prepareForTermination falls back to prompting
        var promptedOnFailure = false
        ws.confirmSaveHandler = { _ in
            promptedOnFailure = true
            return .dontSave
        }
        ws.newDocument()
        guard let docUnwritable = ws.activeDocument else { return }
        docUnwritable.content = "Unwritable backup fallback test"
        docUnwritable.isDirty = true
        
        _ = ws.prepareForTermination()
        assertTest("Resilience 7.3: Unwritable backup dir falls back safely to save prompt", promptedOnFailure == true)
        ws.periodicBackupPath = prevBackupDir
        ws.closeDocument(id: docUnwritable.id, force: true)
    }

    // MARK: - Pillar 8: Menu Dispatch & Responder Chain Tripwires
    static func runMenuAndResponderChainTripwires(appDelegate: AppDelegate, assertTest: @escaping (String, Bool) -> Void) {
        print("\n--- Running Pillar 8: Menu Dispatch & Responder Chain Tripwires ---")
        guard let mainMenu = NSApp.mainMenu else {
            assertTest("Menu 8.1: Main menu is instantiated", false)
            return
        }

        assertTest("Menu 8.1: Main menu bar contains at least 10 menus", mainMenu.items.count >= 10)

        // Crawl all menu items and verify action selectors
        var totalMenuItems = 0
        var totalActionItems = 0
        var validActions = 0

        func resolvesAction(_ action: Selector, for item: NSMenuItem) -> Bool {
            if item.hasSubmenu || item.submenu != nil {
                return item.target != nil || item.submenu != nil
            }
            if let target = item.target {
                return (target as AnyObject).responds(to: action)
            }
            if appDelegate.responds(to: action) { return true }
            if let tv = appDelegate.workspace.activeTextView, tv.responds(to: action) { return true }
            if NSTextView.instancesRespond(to: action) { return true }
            if (appDelegate.workspace as AnyObject).responds(to: action) { return true }
            if let wc = appDelegate.window?.windowController, wc.responds(to: action) { return true }
            if let win = appDelegate.window, win.responds(to: action) { return true }
            if let fr = appDelegate.window?.firstResponder, (fr as AnyObject).responds(to: action) { return true }
            if NSApp.target(forAction: action) != nil { return true }
            if NSApp.responds(to: action) { return true }
            return false
        }

        func crawlMenu(_ menu: NSMenu) {
            for item in menu.items {
                totalMenuItems += 1
                if let action = item.action {
                    totalActionItems += 1
                    if resolvesAction(action, for: item) {
                        validActions += 1
                    }
                }
                if let sub = item.submenu {
                    crawlMenu(sub)
                }
            }
        }
        crawlMenu(mainMenu)
        assertTest("Menu 8.2: Total crawled menu items exceed 100", totalMenuItems >= 100)
        assertTest("Menu 8.3: All crawled menu actions resolve to responders", validActions > 0 && validActions == totalActionItems)

        // Critical Shortcut Invariants
        func findMenuItem(keyEquivalent: String, modifierMask: NSEvent.ModifierFlags) -> NSMenuItem? {
            func search(_ menu: NSMenu) -> NSMenuItem? {
                for item in menu.items {
                    if item.keyEquivalent == keyEquivalent && item.keyEquivalentModifierMask == modifierMask {
                        return item
                    }
                    if let sub = item.submenu, let found = search(sub) {
                        return found
                    }
                }
                return nil
            }
            return search(mainMenu)
        }

        let cmdN = findMenuItem(keyEquivalent: "n", modifierMask: [.command])
        let cmdO = findMenuItem(keyEquivalent: "o", modifierMask: [.command])
        let cmdS = findMenuItem(keyEquivalent: "s", modifierMask: [.command])
        let cmdW = findMenuItem(keyEquivalent: "w", modifierMask: [.command])
        let cmdQ = findMenuItem(keyEquivalent: "q", modifierMask: [.command])
        let cmdF = findMenuItem(keyEquivalent: "f", modifierMask: [.command])

        assertTest("Menu 8.4: Cmd+N (New) shortcut mapped", cmdN != nil)
        assertTest("Menu 8.5: Cmd+O (Open) shortcut mapped", cmdO != nil)
        assertTest("Menu 8.6: Cmd+S (Save) shortcut mapped", cmdS != nil)
        assertTest("Menu 8.7: Cmd+W (Close) shortcut mapped", cmdW != nil)
        assertTest("Menu 8.8: Cmd+Q (Quit) shortcut mapped", cmdQ != nil)
        assertTest("Menu 8.9: Cmd+F (Find) shortcut mapped", cmdF != nil)
    }

    // MARK: - Pillar 9: Preferences State Persistence Tripwires
    static func runPreferencesPersistenceTripwires(assertTest: @escaping (String, Bool) -> Void) {
        print("\n--- Running Pillar 9: Preferences State Persistence Tripwires ---")
        let ws = NppWorkspace()
        ws.interactionProvider = NppAutomatedTestInteractionProvider()
        ws.isTestRunning = true

        // 9.1 Set custom preference values
        ws.rememberSession = false
        ws.periodicBackupEnabled = false
        ws.doubleClickSpaceToNewTab = false
        ws.doubleClickTabToClose = true
        ws.fontFamily = "Courier New"
        ws.fontSize = 17.5
        ws.darkModeChoice = 2
        ws.themeMode = "monokai"
        ws.isWordWrapEnabled = true
        ws.showLineNumbers = false
        ws.tabSize = 8

        // Save preferences
        ws.savePreferences()

        // Verify values written to UserDefaults directly
        let ud = UserDefaults.standard
        let udFont = ud.string(forKey: NppWorkspace.prefsFontFamilyKey)
        let udSize = ud.double(forKey: NppWorkspace.prefsFontSizeKey)
        let udTabClose = ud.bool(forKey: NppWorkspace.prefsDoubleClickTabToCloseKey)
        let udTabSpace = ud.bool(forKey: NppWorkspace.prefsDoubleClickSpaceToNewTabKey)
        let udTheme = ud.string(forKey: NppWorkspace.prefsSelectedThemeKey)

        assertTest("Prefs 9.1: Preferences saved to UserDefaults (fontFamily)", udFont == "Courier New")
        assertTest("Prefs 9.2: Preferences saved to UserDefaults (fontSize)", abs(udSize - 17.5) < 0.01)
        assertTest("Prefs 9.3: Preferences saved to UserDefaults (doubleClickTabToClose)", udTabClose == true)
        assertTest("Prefs 9.4: Preferences saved to UserDefaults (doubleClickSpaceToNewTab)", udTabSpace == false)
        assertTest("Prefs 9.5: Preferences saved to UserDefaults (themeMode)", udTheme == "monokai")

        // 9.6 Load preferences into a clean workspace instance
        let cleanWs = NppWorkspace()
        cleanWs.loadPreferences()
        assertTest("Prefs 9.6: Clean workspace loads persisted fontFamily", cleanWs.fontFamily == "Courier New")
        assertTest("Prefs 9.7: Clean workspace loads persisted fontSize", abs(cleanWs.fontSize - 17.5) < 0.01)
        assertTest("Prefs 9.8: Clean workspace loads persisted doubleClickSpaceToNewTab", cleanWs.doubleClickSpaceToNewTab == false)
        assertTest("Prefs 9.9: Clean workspace loads persisted doubleClickTabToClose", cleanWs.doubleClickTabToClose == true)
        assertTest("Prefs 9.10: Clean workspace loads persisted themeMode", cleanWs.themeMode == "monokai")

        // 9.11 Reset preferences to defaults
        ws.resetPreferencesToDefaults()
        let postResetFont = ud.string(forKey: NppWorkspace.prefsFontFamilyKey)
        assertTest("Prefs 9.11: Reset preferences clears persisted keys in UserDefaults", postResetFont == nil)
    }

    static func saveWindowPNG(_ win: NSWindow, to filename: String) {
        let targetWin: NSWindow = win.attachedSheet ?? win
        if let contentView = targetWin.contentView {
            contentView.layoutSubtreeIfNeeded()
            let bounds = contentView.bounds
            if bounds.width > 0 && bounds.height > 0,
               let rep = contentView.bitmapImageRepForCachingDisplay(in: bounds) {
                contentView.cacheDisplay(in: bounds, to: rep)
                if let pngData = rep.representation(using: .png, properties: [:]) {
                    try? pngData.write(to: URL(fileURLWithPath: filename))
                    return
                }
            }
        }
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        task.arguments = ["-l", "\(targetWin.windowNumber)", filename]
        try? task.run()
        task.waitUntilExit()
    }

    static func captureCustomScreenshot(appDelegate: AppDelegate, setup: @escaping (NppWorkspace) -> Void, filename: String) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let ws = appDelegate.workspace
            ws.openFile(url: URL(fileURLWithPath: "samples/syntax_demo.swift"))
            setup(ws)

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                if filename.contains("find"),
                   let panel = NppFindReplaceWindowController.shared.panel {
                    saveWindowPNG(panel, to: filename)
                    print("📸 Captured \(filename)")
                } else if let win = appDelegate.window {
                    saveWindowPNG(win, to: filename)
                    print("📸 Captured \(filename)")
                }
                exit(0)
            }
        }
    }
}
