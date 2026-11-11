# Notepad++ for Mac (Unofficial Native Port)

A high-performance, native macOS port of **Notepad++**, honoring the upstream feature set, UI paradigms, and keyboard shortcuts from the official C++ source code.

> **Note**: This is an independent, unofficial native macOS port shared at [slux78/notepadplusplus-mac](https://github.com/slux78/notepadplusplus-mac). It is not an official Notepad++ release. Notepad++ is originally created by [Don HO](https://github.com/donho) and the Notepad++ team.

---

## Upstream Base Version (Original Notepad++)

- **Original Version**: **Notepad++ v8.9.8.1** (`VERSION_INTERNAL_VALUE`: `8.981`, `VERSION_DIGITALVALUE`: `8, 9, 8, 1`)
- **Upstream Repository**: [notepad-plus-plus/notepad-plus-plus](https://github.com/notepad-plus-plus/notepad-plus-plus)
- **Upstream Commit Reference**: [`fd2f5c2783`](https://github.com/notepad-plus-plus/notepad-plus-plus/commit/fd2f5c27839e943518b5a53325ffd5e95bb3e0d9)
- **Ported Upstream Components & Resources**:
  - Menu & dialog layouts (`Notepad_plus.rc`, `menuCmdID.h`, `Preferences.rc`, `FindReplaceDlg.rc`, `UserDefineDialog.rc`, `ShortcutMapper.rc`)
  - Encoding detection core (`PowerEditor/src/uchardet`)
  - Auto-completion definitions (`PowerEditor/installer/APIs/*.xml`)
  - Localization strings (`PowerEditor/installer/nativeLang/*.xml`) and theme stylers (`stylers.model.xml`, `themes/*.xml`)

---

## Features

- **Native macOS Experience**: Built with modern Swift, SwiftUI, AppKit, and Apple TextKit 2, combined with C++17 encoding cores (`uchardet` & `iconv`).
- **Full Notepad++ Keyboard & Menu Parity**: Complete 13-menu architecture matching upstream Notepad++ (File, Edit, Search, View, Encoding, Language, Settings, Tools, Macro, Run, Window, ?, etc.).
- **Smart Delimiter Auto-Completion & Overtype**:
  - Auto-inserts matched pairs `()`, `[]`, `{}`, `""`, `''`.
  - Intelligent overtype step-over prevents duplicate closing delimiters (e.g. typing `int main()` never produces `int main())`).
  - Safe state-tracking based on upstream `InsertedMatchedChars`—intentional user keystrokes are never blocked.
  - Smart backspace deletes matching empty pairs cleanly.
- **Authentic Theme & Styler Support**: 9 authentic Notepad++ themes including *Notepad++ Classic (stylers.xml)*, *Notepad++ Dark Mode*, *Monokai*, *Dracula*, *Solarized*, *Nord*, and *Zenburn*.
- **Comprehensive Encoding & EOL Handling**: Full CP949, EUC-KR, UTF-8 (with/without BOM), UTF-16, Shift-JIS, GB18030, and Windows (CR LF) / Unix (LF) / Mac (CR) conversion.
- **Modeless Find & Replace Dialog**: Floating panel with Focus-loss Transparency, Find in Files, and Find All dock results.
- **Extensive Macro System**: Macro recording, playback, multi-run, and saved shortcuts.
- **Line Number Gutter**: Fixed-width font digit advancement matching Scintilla C++ source, ensuring rock-solid width stability across multi-byte Korean/CJK text.

---

## Building and Running

### Requirements
- macOS 13.0 (Ventura) or later
- Xcode 15+ / Swift 5.9+

### Build App Bundle
```bash
# Clone the repository
git clone https://github.com/slux78/notepadplusplus-mac.git
cd notepadplusplus-mac

# Build the release app bundle
./bundle.sh

# Launch the app
open build/Notepad++.app
```

### Run Automated Test Suite
```bash
swift run NotepadPlusPlusMac --run-tests
```

---

## License & Attribution

- **Original Project**: [Notepad++](https://notepad-plus-plus.org/) by **Don HO** ([GitHub Repository](https://github.com/notepad-plus-plus/notepad-plus-plus))
- **License**: **GNU General Public License Version 3 (GPLv3)**
  This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; version 3 of the License.
  See the [LICENSE](LICENSE) file for complete terms.
