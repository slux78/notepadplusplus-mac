# Notepad++ for Mac (Unofficial Native Port)

A high-performance, native macOS port of **Notepad++**, honoring the upstream feature set, UI paradigms, and keyboard shortcuts from the official C++ source code.

> **Note**: This is an independent, unofficial native macOS port shared at [slux78/notepadplusplus-mac](https://github.com/slux78/notepadplusplus-mac). It is not an official Notepad++ release. Notepad++ is originally created by [Don HO](https://github.com/donho) and the Notepad++ team.

---

## Upstream Base Version (Original Notepad++)

- **Original Version**: **Notepad++ v8.9.9.1** (`VERSION_INTERNAL_VALUE`: `8.991`, `VERSION_DIGITALVALUE`: `8, 9, 9, 1`)
- **Upstream Repository**: [notepad-plus-plus/notepad-plus-plus](https://github.com/notepad-plus-plus/notepad-plus-plus)
- **Upstream Commit Reference**: [`066c93ac06`](https://github.com/notepad-plus-plus/notepad-plus-plus/commit/066c93ac06) (`v8.9.9.1` release, plus macOS-applicable `master` fixes through [`a96c442396`](https://github.com/notepad-plus-plus/notepad-plus-plus/commit/a96c442396))
- **Ported Upstream Components & Resources**:
  - Menu & dialog layouts (`Notepad_plus.rc`, `menuCmdID.h`, `Preferences.rc`, `FindReplaceDlg.rc`, `UserDefineDialog.rc`, `ShortcutMapper.rc`)
  - Encoding detection core (`PowerEditor/src/uchardet`)
  - Auto-completion definitions (`PowerEditor/installer/APIs/*.xml`)
  - Localization strings (`PowerEditor/installer/nativeLang/*.xml`) and theme stylers (`stylers.model.xml`, `themes/*.xml`)

---

## Download & Installation

1. Download **`Notepad++-v8.9.9.1.dmg`** (and optionally `Notepad++-v8.9.9.1.dmg.sha256` to verify checksums) from the [Latest Release](https://github.com/slux78/notepadplusplus-mac/releases/latest).
2. Open the `.dmg` file and drag **`Notepad++.app`** into your **`/Applications`** folder.
3. Because this independent build uses ad-hoc code signing, if macOS Gatekeeper warns on first launch, run:
   ```bash
   xattr -cr /Applications/Notepad++.app
   open /Applications/Notepad++.app
   ```

---

## Features

- **Native macOS Experience**: Built with modern Swift, SwiftUI, AppKit, and Apple TextKit 2, combined with C++17 encoding cores (`uchardet` & `iconv`).
- **Full Notepad++ Keyboard & Menu Parity**: Complete menu architecture matching upstream Notepad++ (`File`, `Edit`, `Search`, `View`, `Encoding`, `Language`, `Settings`, `Tools`, `Macro`, `Run`, `Plugins`, `Window`, `?`) plus customizable Shortcut Mapper and Style Configurator.
- **Modeless Find, Replace & Incremental Search**:
  - Floating panel with Focus-loss Transparency, real-time **Highlight all matches** (`v8.9.9.1`), Find in Files, Find in Projects, and clickable Search Results dock.
  - Persistent Incremental Search options (`Match case`, `Match whole word`, `Regex`, `Highlight all`, `Show at top`) and dedicated Mark / Copy Marked Text controls.
- **Side Panels & Workspace Tools**: Project Panels 1–3, Folder as Workspace (with symlink & circular-link safety), Document List, Function List (`Swift`, `C/C++`, `Python`, `TypeScript`, `Bash`, `INI`, `PowerShell`), Document Map, Clipboard History (128-char UTF-16/emoji-safe previews), and Character Panel.
- **Multi-Editing, Column Mode & Tab Management**: Multi-caret editing, Column Mode Editor (`Alt+C`), pinned tab protection on sorting/reordering, and Windows management dialog.
- **User Defined Languages & Expanded Syntax Highlighting**: Visual UDL configurator (including default new-document UDL support), 9 authentic Notepad++ themes, and syntax/file-type parity including Structured Text (`.st`), R (with string escapes), and C++ user-defined literals (`USERLITERAL`).
- **Smart Delimiter Auto-Completion & Overtype**:
  - Auto-inserts matched pairs `()`, `[]`, `{}`, `""`, `''`.
  - Intelligent overtype step-over prevents duplicate closing delimiters (e.g. typing `int main()` never produces `int main())`).
  - Safe state-tracking based on upstream `InsertedMatchedChars`—intentional user keystrokes are never blocked.
  - Smart backspace deletes matching empty pairs cleanly.
- **Comprehensive Encoding & EOL Handling**: Full CP949, EUC-KR, UTF-8 (with/without BOM), UTF-16, Shift-JIS, GB18030, and Windows (CR LF) / Unix (LF) / Mac (CR) conversion.
- **Extensive Macro System**: Macro recording, playback, multi-run, and saved shortcuts.
- **Line Number Gutter**: Fixed-width font digit advancement matching Scintilla C++ source, ensuring rock-solid width stability across multi-byte Korean/CJK text.

---

## Building and Running

### Requirements
- macOS 13.0 (Ventura) or later
- Xcode 15+ / Swift 5.9+

### Build App Bundle & DMG Package
```bash
# Clone the repository
git clone https://github.com/slux78/notepadplusplus-mac.git
cd notepadplusplus-mac

# Build the release app bundle
./bundle.sh

# Package and verify the distributable DMG (creates build/Notepad++-v8.9.9.1.dmg & .sha256)
./create_dmg.sh
# Or build both app bundle and DMG in one step:
# ./bundle.sh --dmg

# Launch the app
open build/Notepad++.app
```

### Run Automated Test Suite (1,609 tests)
```bash
swift run NotepadPlusPlusMac --run-tests
```

---

## License & Attribution

- **Original Project**: [Notepad++](https://notepad-plus-plus.org/) by **Don HO** ([GitHub Repository](https://github.com/notepad-plus-plus/notepad-plus-plus))
- **License**: **GNU General Public License Version 3 (GPLv3)**
  This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; version 3 of the License.
  See the [LICENSE](LICENSE) file for complete terms.
