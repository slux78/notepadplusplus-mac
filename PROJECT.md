# Project: Notepad++ for Mac Native Porting

## Architecture
- **Language & Runtime**: Swift 5.9+, AppKit, SwiftUI, C++17 (via NppCore)
- **Core Modules**:
  - `Sources/NppCore`: C++ library integrating uchardet and iconv for encoding detection.
  - `Sources/NotepadPlusPlusMac`: Native AppKit / SwiftUI application and test runner.
    - `Models/`: `NppWorkspace`, `NppDocument`, `NppPreferences`
    - `Views/`: `MainWindowView`, `TabBarView`, `ToolbarView`, `StatusBarView`, `EditorView`, `FindReplaceDialogView`, `NppFindReplaceWindowController`, `PreferencesView`, `StyleConfiguratorView`, `ColumnEditorView`
    - `NppAutomatedTestSuite.swift`: Integrated automated test harness running via `--run-tests`
- **Specification Source of Truth**:
  - Upstream C++: `upstream_npp/PowerEditor/src/`
  - Upstream Manual: `npp-user-manual.org`
  - Audit Log: `SPEC_AUDIT_LOG.md`

## Feature Inventory
| # | Feature | Description | Milestone | Source |
|---|---------|-------------|-----------|--------|
| 1 | Modeless Find/Replace Dialog | Modeless floating panel with hidesOnDeactivate and minimize sync | M1 | [AUDIT-001], R1, R2 |
| 2 | Inline Search Bar Separation | Disables inline searchbar on Cmd+F to prevent UI duplication | M1 | [AUDIT-002], R1, R2 |
| 3 | Find Dialog Layout & Compact Sizing | Flush top tabs, compact 360pt height, side-by-side search mode/transparency, minSize 730x360 | M1 | [AUDIT-003], [AUDIT-011], R1, R2 |
| 4 | Tab Bar Double-Click Actions | Empty space double-click -> New tab; tab item double-click -> close | M1 | [AUDIT-004], R1 |
| 5 | Standard 28-Button Toolbar | Complete 28+ toolbar button suite with Fluent UI icons | M1 | [AUDIT-005], R1 |
| 6 | Upstream v8.9.8.1 Versioning | Application version strictly v8.9.8.1 across bundle and about box | M1 | [AUDIT-006], R1 |
| 7 | Full 13-Menu Architecture | Complete 13 top-level menus matching upstream C++ command hierarchy | M1 | [AUDIT-007], R1 |
| 8 | Status Bar 6-Box System (Anti-Clipping) | 6 interactive boxes with dynamic intrinsic widths (240/270-340pt base) | M1 | [AUDIT-008], [AUDIT-011], R1, R2 |
| 9 | Dialog Transparency | Modeless dialog focus-loss (WA_INACTIVE) and persistent opacity | M1 | [AUDIT-009], R1 |
| 10 | Tab Pinning & Batch Close | Pin tab leftmost, close immunity, closeAllToLeft/Right/Unchanged | M1 | [AUDIT-010], R1 |
| 11 | Dynamic Window Titlebar Sync | Window titlebar updates dirty prefix and document name on tab switch via Combine | M1 | [AUDIT-011], R2 |
| 12 | Style Configurator Theme Selector | Expanded picker width (280pt) preventing theme name truncation | M1 | [AUDIT-011], R2 |
| 13 | Automated Test Suite (195 tests) | 195 tests passing with 0 failures, all acceptance criteria satisfied | M2 | R3, Acceptance Criteria |
| 14 | Upstream C++ Spec Audit Log | SPEC_AUDIT_LOG.md updated with verified [AUDIT-001]~[AUDIT-011] entries | M2 | R1, Acceptance Criteria |
| 15 | Visual & Rendering Quality | Zero clipping, no abnormal margins, verified via screenshots & Apple Vision OCR | M2 | R2, Acceptance Criteria |
| 16 | Forensic Integrity Verification | Clean independent forensic audits across all iterations | M2 | Integrity Forensics |

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| M1 | UI Quality, Layout & Window Title Hardening | Fix status bar clipping, find dialog whitespace/bounds, window title sync, theme picker width, add tests & [AUDIT-011] | none | DONE |
| M2 | Full Verification, Final Audit & Acceptance Sign-off | Re-verify all acceptance criteria (177+ test suite, upstream parity, visual standards), victory audit, Sentinel report | M1 | IN_PROGRESS |

## Interface Contracts
### `StatusBarView` ↔ `NppWorkspace`
- Box 2 base width: 240pt, dynamically sized via `max(240, textWidth + 24)` (displays "length : %d lines : %d")
- Box 3 base width: 270pt unselected, 340pt selected, dynamically sized via `max(base, textWidth + 24)` (displays "Ln : %d Col : %d Pos : %d [Sel : %d]")

### `NppFindReplaceWindowController`
- ContentRect: 730 x 360 pt
- minSize: NSSize(width: 730, height: 360) enforced via `NSWindowDelegate.windowWillResize(_:to:)`
- hidesOnDeactivate: true
- Side-by-side Search Mode and Transparency groupboxes matching upstream `FindReplaceDlg.rc:56,88`

### `AppDelegate` ↔ `NppWorkspace`
- Combine pipeline observing `workspace.$activeDocumentId`, `workspace.objectWillChange`, and active document `doc.objectWillChange`
- Window title updates dynamically: `window?.title = "\(dirtyPrefix)\(pathOrTitle) - Notepad++"`

## Code Layout
- `Sources/NotepadPlusPlusMac/Views/StatusBarView.swift`: Status bar UI components and box widths
- `Sources/NotepadPlusPlusMac/Views/NppFindReplaceWindowController.swift`: Modeless panel controller and frame bounds
- `Sources/NotepadPlusPlusMac/Views/FindReplaceDialogView.swift`: Modeless panel content view
- `Sources/NotepadPlusPlusMac/Views/StyleConfiguratorView.swift`: Theme picker width
- `Sources/NotepadPlusPlusMac/main.swift`: Window title binding and app delegate
- `Sources/NotepadPlusPlusMac/NppAutomatedTestSuite.swift`: Automated regression test suite
- `SPEC_AUDIT_LOG.md`: Upstream spec audit log
