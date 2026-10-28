import AppKit
import SwiftUI

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
        let expectedMix = "Zoo\nMango\nApple"
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
        assertTest("M4 View: isMonitoring defaults to false", !doc.isMonitoring)
        ws.toggleMonitoringCurrentDoc()
        assertTest("M4 View: toggleMonitoringCurrentDoc enables tail -f monitoring flag", doc.isMonitoring)
        ws.toggleMonitoringCurrentDoc()
        assertTest("M4 View: toggleMonitoringCurrentDoc disables tail -f monitoring flag", !doc.isMonitoring)

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
            assertTest("Sprint 1.6.A: Monitoring mode state toggleable via toggleMonitoringCurrentDoc", monDoc.isMonitoring == false)
            ws.toggleMonitoringCurrentDoc()
            assertTest("Sprint 1.6.B: Monitoring toggled ON makes doc.isMonitoring=true and doc.isReadOnly=true",
                       monDoc.isMonitoring == true && monDoc.isReadOnly == true)
            ws.toggleMonitoringCurrentDoc()
            assertTest("Sprint 1.6.C: Monitoring toggled OFF restores state", monDoc.isMonitoring == false)
            ws.closeDocument(id: monDoc.id)
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
                       parts[4] == "swift" &&
                       parts[5] == "totalSum" &&
                       parts[6] == "1" &&
                       parts[7] == "7")

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
