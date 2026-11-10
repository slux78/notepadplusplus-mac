# Inert settings audit (setting exists in Preferences but nothing reads it)

| Section | Property | UI label | Status |
|---|---|---|---|
| (no UI) | `defaultEol` |  | done (tested) |
| (no UI) | `distractionFreePadding` |  | done (tested) |
| (no UI) | `insertMode` |  | done (tested) |
| (no UI) | `showWindowsDialog` |  | done (tested) |
| 0. General (IDD_PREFERENCE_SUB_GENERAL) | `dialogFontName` | Name: | done (tested) |
| 0. General (IDD_PREFERENCE_SUB_GENERAL) | `dialogFontSize` | Size: | done (tested) |
| 0. General (IDD_PREFERENCE_SUB_GENERAL) | `hideMenuBar` | Hide (use Alt or F10 key to toggle) | N/A (macOS platform) |
| 11. Language (IDD_PREFERENCE_SUB_LANGUAGE) | `treatBackslashAsEscapeForSql` | Treat backslash as escape character for SQL | done (tested) |
| 12. Indentation (IDD_PREFERENCE_SUB_INDENTATION) | `backspaceUnindents` |  | done (tested) |
| 12. Indentation (IDD_PREFERENCE_SUB_INDENTATION) | `useDefaultTabValue` |  | done (tested) |
| 13. Highlighting (IDD_PREFERENCE_SUB_HIGHLIGHTING) | `highlightMatchingTags` | Enable | done (tested) |
| 13. Highlighting (IDD_PREFERENCE_SUB_HIGHLIGHTING) | `highlightNoneHtmlZone` | Highlight comment/php/asp zone | done (tested) |
| 13. Highlighting (IDD_PREFERENCE_SUB_HIGHLIGHTING) | `highlightTagAttributes` | Highlight tag attributes | done (tested) |
| 13. Highlighting (IDD_PREFERENCE_SUB_HIGHLIGHTING) | `markAllMatchCase` | Match case | done (tested) |
| 13. Highlighting (IDD_PREFERENCE_SUB_HIGHLIGHTING) | `markAllWholeWord` | Match whole word only | done (tested) |
| 13. Highlighting (IDD_PREFERENCE_SUB_HIGHLIGHTING) | `smartHighlightAnotherView` | Highlight another view | done (tested) |
| 13. Highlighting (IDD_PREFERENCE_SUB_HIGHLIGHTING) | `smartHighlightMatchCase` | Match case | done (tested) |
| 13. Highlighting (IDD_PREFERENCE_SUB_HIGHLIGHTING) | `smartHighlightUseFindSettings` | Use Find dialog settings | done (tested) |
| 13. Highlighting (IDD_PREFERENCE_SUB_HIGHLIGHTING) | `smartHighlightWholeWord` | Match whole word only | done (tested) |
| 13. Highlighting (IDD_PREFERENCE_SUB_HIGHLIGHTING) | `smartHighlighting` | Enable | done (tested) |
| 14. Print (IDD_PREFERENCE_SUB_PRINT) | `printColorOption` |  | done (tested) |
| 14. Print (IDD_PREFERENCE_SUB_PRINT) | `printFooterLeft` |  | done (tested) |
| 14. Print (IDD_PREFERENCE_SUB_PRINT) | `printFooterMiddle` |  | done (tested) |
| 14. Print (IDD_PREFERENCE_SUB_PRINT) | `printFooterRight` |  | done (tested) |
| 14. Print (IDD_PREFERENCE_SUB_PRINT) | `printFormFeedPageBreak` | Print formfeed as page break | done (tested) |
| 14. Print (IDD_PREFERENCE_SUB_PRINT) | `printHeaderLeft` |  | done (tested) |
| 14. Print (IDD_PREFERENCE_SUB_PRINT) | `printHeaderMiddle` | Time | done (tested) |
| 14. Print (IDD_PREFERENCE_SUB_PRINT) | `printHeaderRight` |  | done (tested) |
| 14. Print (IDD_PREFERENCE_SUB_PRINT) | `printLineNumbers` | Print line number | done (tested) |
| 14. Print (IDD_PREFERENCE_SUB_PRINT) | `printMarginBottom` | Bottom: | done (tested) |
| 14. Print (IDD_PREFERENCE_SUB_PRINT) | `printMarginLeft` | Left: | done (tested) |
| 14. Print (IDD_PREFERENCE_SUB_PRINT) | `printMarginRight` | Right: | done (tested) |
| 14. Print (IDD_PREFERENCE_SUB_PRINT) | `printMarginTop` | Top: | done (tested) |
| 14. Print (IDD_PREFERENCE_SUB_PRINT) | `printVariableSelection` | Variable: | done (tested) |
| 15. Searching (IDD_PREFERENCE_SUB_SEARCHING) | `confirmReplaceAllInAllOpenedDocs` | Confirm Replace All in All Opened Documents | done (tested) |
| 15. Searching (IDD_PREFERENCE_SUB_SEARCHING) | `fifIgnoreOpenedFiles` | Find in Files: Prefer on-disk file content over open buffers | done (tested) |
| 15. Searching (IDD_PREFERENCE_SUB_SEARCHING) | `findDlgAlwaysVisible` | Find dialog remains open after search that outputs to results window | done (tested) |
| 15. Searching (IDD_PREFERENCE_SUB_SEARCHING) | `incSearchBarAtTop` | Incremental Search: show the bar at the top | done (tested) |
| 15. Searching (IDD_PREFERENCE_SUB_SEARCHING) | `replaceAndStop` | Replace: Don't move to the following occurrence | done (tested) |
| 15. Searching (IDD_PREFERENCE_SUB_SEARCHING) | `showOncePerFoundLine` | Search Result window: show only one entry per found line if possible | done (tested) |
| 15. Searching (IDD_PREFERENCE_SUB_SEARCHING) | `useMonospacedFontInFindDlg` | Use Monospaced font in Find dialog (Need to restart Notepad++) | done (tested) |
| 16. Backup (IDD_PREFERENCE_SUB_BACKUP) | `backupOnSaveMode` |  | done (tested) |
| 16. Backup (IDD_PREFERENCE_SUB_BACKUP) | `customBackupDir` | Directory: | done (tested) |
| 16. Backup (IDD_PREFERENCE_SUB_BACKUP) | `customBackupDirEnabled` | Custom Backup Directory | done (tested) |
| 17. Auto-Completion (IDD_PREFERENCE_SUB_AUTOCOMPLETION) | `autoCompletionBrief` | Make auto-completion list brief | done (tested) |
| 18. Multi-Instance & Date (IDD_PREFERENCE_SUB_MULTIINSTANCE) | `dateTimeCustomFormat` | Format: | done (tested) |
| 18. Multi-Instance & Date (IDD_PREFERENCE_SUB_MULTIINSTANCE) | `dateTimeReverseOrder` | Reverse default date time order | done (tested) |
| 18. Multi-Instance & Date (IDD_PREFERENCE_SUB_MULTIINSTANCE) | `multiInstanceMode` |  | done (tested) |
| 18. Multi-Instance & Date (IDD_PREFERENCE_SUB_MULTIINSTANCE) | `rememberCharacterPanel` | Character Panel | done (tested) |
| 18. Multi-Instance & Date (IDD_PREFERENCE_SUB_MULTIINSTANCE) | `rememberClipboardHistory` | Clipboard History | done (tested) |
| 18. Multi-Instance & Date (IDD_PREFERENCE_SUB_MULTIINSTANCE) | `rememberPanelStateDocList` | Document List | done (tested) |
| 18. Multi-Instance & Date (IDD_PREFERENCE_SUB_MULTIINSTANCE) | `rememberPanelStateFAW` | Folder as Workspace | done (tested) |
| 18. Multi-Instance & Date (IDD_PREFERENCE_SUB_MULTIINSTANCE) | `rememberPluginPanels` | Plugin Panels | done (tested) |
| 19. Delimiter (IDD_PREFERENCE_SUB_DELIMITER) | `delimiterClose` | Close: | done (tested) |
| 19. Delimiter (IDD_PREFERENCE_SUB_DELIMITER) | `delimiterOpen` | Open: | done (tested) |
| 19. Delimiter (IDD_PREFERENCE_SUB_DELIMITER) | `delimiterSeveralLines` | Allow on several lines | done (tested) |
| 2. Tab Bar (IDD_PREFERENCE_SUB_TABBAR) | `exitOnCloseLastTab` | Exit on close the last tab | done (tested) |
| 2. Tab Bar (IDD_PREFERENCE_SUB_TABBAR) | `tabAltIcons` | Alternate icons | done (tested) |
| 2. Tab Bar (IDD_PREFERENCE_SUB_TABBAR) | `tabColorIndicator` | Draw a coloured bar on active tab | done (tested) |
| 2. Tab Bar (IDD_PREFERENCE_SUB_TABBAR) | `tabLock` | Lock (no drag and drop) | done (tested) |
| 2. Tab Bar (IDD_PREFERENCE_SUB_TABBAR) | `tabMultiLine` | Multi-line | done (tested) |
| 2. Tab Bar (IDD_PREFERENCE_SUB_TABBAR) | `tabPinFeature` | Enable pin tab feature | done (tested) |
| 2. Tab Bar (IDD_PREFERENCE_SUB_TABBAR) | `tabShowOnlyPinnedButton` | Show only pinned button | done (tested) |
| 2. Tab Bar (IDD_PREFERENCE_SUB_TABBAR) | `tabVertical` | Vertical | done (tested) |
| 20. Performance (IDD_PREFERENCE_SUB_PERFORMANCE) | `performanceAllowAutoCompletion` | Allow Auto-Completion | done (tested) |
| 20. Performance (IDD_PREFERENCE_SUB_PERFORMANCE) | `performanceAllowBraceMatch` | Allow Brace Match | done (tested) |
| 20. Performance (IDD_PREFERENCE_SUB_PERFORMANCE) | `performanceAllowClickableLink` | Allow URL Clickable Link | done (tested) |
| 20. Performance (IDD_PREFERENCE_SUB_PERFORMANCE) | `performanceAllowSmartHighlighting` | Allow Smart Highlighting | done (tested) |
| 20. Performance (IDD_PREFERENCE_SUB_PERFORMANCE) | `performanceDeactivateWordWrap` | Deactivate Word Wrap globally | done (tested) |
| 20. Performance (IDD_PREFERENCE_SUB_PERFORMANCE) | `performanceSuppress2GBWarning` | Suppress warning when opening ≥2GB files | done (tested) |
| 21. Cloud & Link (IDD_PREFERENCE_SUB_CLOUD_LINK) | `clickableLinkEnable` | Enable | done (tested) |
| 21. Cloud & Link (IDD_PREFERENCE_SUB_CLOUD_LINK) | `clickableLinkFullBoxMode` | Enable fullbox mode | done (tested) |
| 21. Cloud & Link (IDD_PREFERENCE_SUB_CLOUD_LINK) | `clickableLinkNoUnderline` | No underline | done (tested) |
| 21. Cloud & Link (IDD_PREFERENCE_SUB_CLOUD_LINK) | `cloudMode` | No Cloud | done (tested) |
| 21. Cloud & Link (IDD_PREFERENCE_SUB_CLOUD_LINK) | `cloudPath` | Set your cloud location path here: | done (tested) |
| 21. Cloud & Link (IDD_PREFERENCE_SUB_CLOUD_LINK) | `uriCustomSchemes` | URI customized schemes: | done (tested) |
| 23. MISC. (IDD_PREFERENCE_SUB_MISC) | `allowSymlinksInFAW` | Allow loading symlinks in Folder as Workspace panel | done (tested) |
| 23. MISC. (IDD_PREFERENCE_SUB_MISC) | `autoDetectEncoding` | Autodetect character encoding | done (tested) |
| 23. MISC. (IDD_PREFERENCE_SUB_MISC) | `docPeekerOnMap` | Peek on document map | done (tested) |
| 23. MISC. (IDD_PREFERENCE_SUB_MISC) | `docPeekerOnTab` | Peek on tab | done (tested) |
| 23. MISC. (IDD_PREFERENCE_SUB_MISC) | `docSwitcherEnabled` | Enable | done (tested) |
| 23. MISC. (IDD_PREFERENCE_SUB_MISC) | `docSwitcherMRU` | Enable MRU behaviour | done (tested) |
| 23. MISC. (IDD_PREFERENCE_SUB_MISC) | `fileStatusGoToEOF` | Scroll to the last line after update | done (tested) |
| 23. MISC. (IDD_PREFERENCE_SUB_MISC) | `muteAllSounds` | Mute all sounds | done (tested) |
| 23. MISC. (IDD_PREFERENCE_SUB_MISC) | `saveAllConfirmDialog` | Enable Save All confirm dialog | done (tested) |
| 23. MISC. (IDD_PREFERENCE_SUB_MISC) | `shortTitleInBar` | Show only filename in title bar | done (tested) |
| 23. MISC. (IDD_PREFERENCE_SUB_MISC) | `workspaceFileExt` | Workspace file ext.: | done (tested) |
| 3. Editing 1 (IDD_PREFERENCE_SUB_EDITING) | `caretBlinkRate` | F | done (tested) |
| 3. Editing 1 (IDD_PREFERENCE_SUB_EDITING) | `disableSelectedTextDragDrop` | Disable selected text drag-and-drop | done (tested) |
| 3. Editing 1 (IDD_PREFERENCE_SUB_EDITING) | `disableTouchpadScroll` | Disable advanced scrolling feature due to touchpad issue | done (tested) |
| 3. Editing 1 (IDD_PREFERENCE_SUB_EDITING) | `foldingToggle` | Make current level folding/unfolding commands toggleable | done (tested) |
| 3. Editing 1 (IDD_PREFERENCE_SUB_EDITING) | `lineCutCopyWithNoSelection` | Enable Copy/Cut Line without selection | done (tested) |
| 3. Editing 1 (IDD_PREFERENCE_SUB_EDITING) | `lineWrapMode` |  | done (tested) |
| 3. Editing 1 (IDD_PREFERENCE_SUB_EDITING) | `rightClickKeepsSelection` | Keep selection when right-click outside of selection | done (tested) |
| 3. Editing 1 (IDD_PREFERENCE_SUB_EDITING) | `scrollBeyondLastLine` | Enable scrolling beyond last line | done (tested) |
| 3. Editing 1 (IDD_PREFERENCE_SUB_EDITING) | `selectedTextForegroundCustom` | Apply custom color to selected text foreground | done (tested) |
| 3. Editing 1 (IDD_PREFERENCE_SUB_EDITING) | `smoothFont` | Enable smooth font | done (tested) |
| 3. Editing 1 (IDD_PREFERENCE_SUB_EDITING) | `virtualSpace` | Enable virtual space | done (tested) |
| 4. Editing 2 (IDD_PREFERENCE_SUB_EDITING2) | `columnToMultiEditing` | Enable Column Selection to Multi-Editing | done (tested) |
| 4. Editing 2 (IDD_PREFERENCE_SUB_EDITING2) | `eolAppearance` |  | done (tested) |
| 4. Editing 2 (IDD_PREFERENCE_SUB_EDITING2) | `eolCustomColor` | Custom Color | done (tested) |
| 4. Editing 2 (IDD_PREFERENCE_SUB_EDITING2) | `npcAppearance` |  | done (tested) |
| 4. Editing 2 (IDD_PREFERENCE_SUB_EDITING2) | `npcCustomColor` | Custom Color | done (tested) |
| 4. Editing 2 (IDD_PREFERENCE_SUB_EDITING2) | `npcIncludeUnicodeEol` | Apply Appearance settings to C0, C1 & Unicode EOL | done (tested) |
| 4. Editing 2 (IDD_PREFERENCE_SUB_EDITING2) | `npcNoInputC0` | Prevent control character (C0 code) typing into document | done (tested) |
| 5. Dark Mode (IDD_PREFERENCE_SUB_DARKMODE) | `darkModeTone` |  | done (tested) |
| 6. Margins/Border/Edge (IDD_PREFERENCE_SUB_MARGING_BORDER_EDGE) | `borderWidth` |  | done (tested) |
| 6. Margins/Border/Edge (IDD_PREFERENCE_SUB_MARGING_BORDER_EDGE) | `changeHistoryMargin` | Show in the margin | done (tested) |
| 6. Margins/Border/Edge (IDD_PREFERENCE_SUB_MARGING_BORDER_EDGE) | `changeHistoryText` | Show in the text | done (tested) |
| 6. Margins/Border/Edge (IDD_PREFERENCE_SUB_MARGING_BORDER_EDGE) | `foldMarginStyle` |  | done (tested) |
| 6. Margins/Border/Edge (IDD_PREFERENCE_SUB_MARGING_BORDER_EDGE) | `paddingRight` | Right: | done (tested) |
| 6. Margins/Border/Edge (IDD_PREFERENCE_SUB_MARGING_BORDER_EDGE) | `verticalEdgeBgMode` | Background mode | done (tested) |
| 7. New Document (IDD_PREFERENCE_SUB_NEWDOCUMENT) | `addNewDocOnStartup` | Always open a new document in addition at startup | done (tested) |
| 7. New Document (IDD_PREFERENCE_SUB_NEWDOCUMENT) | `openAnsiAsUtf8` | Apply to opened ANSI files | done (tested) |
| 7. New Document (IDD_PREFERENCE_SUB_NEWDOCUMENT) | `useFirstLineAsTabName` | Use the first line of document as untitled tab name | done (tested) |
| 8. Default Directory (IDD_PREFERENCE_SUB_DEFAULTDIRECTORY) | `customDefaultDirectory` | Always on: | done (tested) |
| 8. Default Directory (IDD_PREFERENCE_SUB_DEFAULTDIRECTORY) | `defaultDirectoryMode` | Follow current document | done (tested) |
| 8. Default Directory (IDD_PREFERENCE_SUB_DEFAULTDIRECTORY) | `dropFolderOpenAllFiles` | Open all files of folder instead of launching Folder as Workspace on folder dropping | done (tested) |
| 9. Recent Files History (IDD_PREFERENCE_SUB_RECENTFILESHISTORY) | `dontCheckHistoryAtLaunch` | Don't check at launch time | done (tested) |
| 9. Recent Files History (IDD_PREFERENCE_SUB_RECENTFILESHISTORY) | `recentFilesCustomLength` |  | done (tested) |
| 9. Recent Files History (IDD_PREFERENCE_SUB_RECENTFILESHISTORY) | `recentFilesInSubmenu` | In Submenu | done (tested) |
