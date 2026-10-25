import SwiftUI
import AppKit

public struct NppTheme: Identifiable, Hashable {
    public let id: String
    public let name: String
    public let isDark: Bool
    public let backgroundColor: NSColor
    public let foregroundColor: NSColor
    public let gutterBackground: NSColor
    public let gutterForeground: NSColor
    public let activeLineColor: NSColor
    public let selectionColor: NSColor
    public let keywordColor: NSColor
    public let stringColor: NSColor
    public let commentColor: NSColor
    public let numberColor: NSColor

    public init(
        id: String,
        name: String,
        isDark: Bool,
        backgroundColor: NSColor,
        foregroundColor: NSColor,
        gutterBackground: NSColor,
        gutterForeground: NSColor,
        activeLineColor: NSColor,
        selectionColor: NSColor,
        keywordColor: NSColor,
        stringColor: NSColor,
        commentColor: NSColor,
        numberColor: NSColor
    ) {
        self.id = id
        self.name = name
        self.isDark = isDark
        self.backgroundColor = backgroundColor
        self.foregroundColor = foregroundColor
        self.gutterBackground = gutterBackground
        self.gutterForeground = gutterForeground
        self.activeLineColor = activeLineColor
        self.selectionColor = selectionColor
        self.keywordColor = keywordColor
        self.stringColor = stringColor
        self.commentColor = commentColor
        self.numberColor = numberColor
    }

    public static let allThemes: [NppTheme] = [
        // 1. Notepad++ Dark Mode (notepad4ever signature)
        NppTheme(
            id: "dark",
            name: "Notepad++ Dark Mode (Default)",
            isDark: true,
            backgroundColor: NSColor(calibratedRed: 0.125, green: 0.125, blue: 0.125, alpha: 1.0), // #202020
            foregroundColor: NSColor(calibratedRed: 0.90, green: 0.90, blue: 0.90, alpha: 1.0),
            gutterBackground: NSColor(calibratedRed: 0.094, green: 0.094, blue: 0.094, alpha: 1.0), // #181818
            gutterForeground: NSColor(calibratedRed: 0.55, green: 0.55, blue: 0.55, alpha: 1.0),
            activeLineColor: NSColor(calibratedRed: 0.18, green: 0.196, blue: 0.22, alpha: 0.95), // #2e3238
            selectionColor: NSColor(calibratedRed: 0.26, green: 0.38, blue: 0.55, alpha: 0.6),
            keywordColor: NSColor(calibratedRed: 0.95, green: 0.55, blue: 0.35, alpha: 1.0),
            stringColor: NSColor(calibratedRed: 0.55, green: 0.85, blue: 0.55, alpha: 1.0),
            commentColor: NSColor(calibratedRed: 0.45, green: 0.65, blue: 0.45, alpha: 1.0),
            numberColor: NSColor(calibratedRed: 0.90, green: 0.45, blue: 0.45, alpha: 1.0)
        ),
        // 2. Notepad++ Classic Light (stylers.xml)
        NppTheme(
            id: "light",
            name: "Notepad++ Classic (stylers.xml)",
            isDark: false,
            backgroundColor: NSColor.white,
            foregroundColor: NSColor.black,
            gutterBackground: NSColor(calibratedRed: 0.93, green: 0.93, blue: 0.93, alpha: 1.0),
            gutterForeground: NSColor(calibratedRed: 0.45, green: 0.45, blue: 0.45, alpha: 1.0),
            activeLineColor: NSColor(calibratedRed: 0.91, green: 0.95, blue: 0.99, alpha: 1.0), // #E8F2FE
            selectionColor: NSColor(calibratedRed: 0.70, green: 0.83, blue: 0.98, alpha: 0.6),
            keywordColor: NSColor(calibratedRed: 0.0, green: 0.0, blue: 0.80, alpha: 1.0),
            stringColor: NSColor(calibratedRed: 0.50, green: 0.50, blue: 0.50, alpha: 1.0),
            commentColor: NSColor(calibratedRed: 0.0, green: 0.50, blue: 0.0, alpha: 1.0),
            numberColor: NSColor(calibratedRed: 1.0, green: 0.40, blue: 0.0, alpha: 1.0)
        ),
        // 3. Monokai
        NppTheme(
            id: "monokai",
            name: "Monokai",
            isDark: true,
            backgroundColor: NSColor(calibratedRed: 0.153, green: 0.157, blue: 0.133, alpha: 1.0), // #272822
            foregroundColor: NSColor(calibratedRed: 0.97, green: 0.97, blue: 0.95, alpha: 1.0),
            gutterBackground: NSColor(calibratedRed: 0.118, green: 0.122, blue: 0.110, alpha: 1.0), // #1e1f1c
            gutterForeground: NSColor(calibratedRed: 0.55, green: 0.55, blue: 0.50, alpha: 1.0),
            activeLineColor: NSColor(calibratedRed: 0.243, green: 0.239, blue: 0.196, alpha: 0.95), // #3E3D32
            selectionColor: NSColor(calibratedRed: 0.31, green: 0.31, blue: 0.28, alpha: 0.7),
            keywordColor: NSColor(calibratedRed: 0.976, green: 0.149, blue: 0.447, alpha: 1.0), // #F92672
            stringColor: NSColor(calibratedRed: 0.902, green: 0.859, blue: 0.455, alpha: 1.0), // #E6DB74
            commentColor: NSColor(calibratedRed: 0.459, green: 0.443, blue: 0.369, alpha: 1.0), // #75715E
            numberColor: NSColor(calibratedRed: 0.682, green: 0.506, blue: 1.0, alpha: 1.0)    // #AE81FF
        ),
        // 4. Dracula
        NppTheme(
            id: "dracula",
            name: "Dracula",
            isDark: true,
            backgroundColor: NSColor(calibratedRed: 0.157, green: 0.165, blue: 0.212, alpha: 1.0), // #282A36
            foregroundColor: NSColor(calibratedRed: 0.973, green: 0.973, blue: 0.949, alpha: 1.0),
            gutterBackground: NSColor(calibratedRed: 0.129, green: 0.133, blue: 0.173, alpha: 1.0), // #21222C
            gutterForeground: NSColor(calibratedRed: 0.384, green: 0.447, blue: 0.643, alpha: 1.0), // #6272A4
            activeLineColor: NSColor(calibratedRed: 0.267, green: 0.278, blue: 0.353, alpha: 0.95), // #44475A
            selectionColor: NSColor(calibratedRed: 0.267, green: 0.278, blue: 0.353, alpha: 0.8),
            keywordColor: NSColor(calibratedRed: 1.0, green: 0.475, blue: 0.776, alpha: 1.0), // #FF79C6
            stringColor: NSColor(calibratedRed: 0.945, green: 0.980, blue: 0.549, alpha: 1.0), // #F1FA8C
            commentColor: NSColor(calibratedRed: 0.384, green: 0.447, blue: 0.643, alpha: 1.0), // #6272A4
            numberColor: NSColor(calibratedRed: 0.741, green: 0.576, blue: 0.976, alpha: 1.0)  // #BD93F9
        ),
        // 5. Solarized Dark
        NppTheme(
            id: "solarized_dark",
            name: "Solarized Dark",
            isDark: true,
            backgroundColor: NSColor(calibratedRed: 0.0, green: 0.169, blue: 0.212, alpha: 1.0), // #002B36
            foregroundColor: NSColor(calibratedRed: 0.576, green: 0.631, blue: 0.631, alpha: 1.0), // #93A1A1
            gutterBackground: NSColor(calibratedRed: 0.027, green: 0.212, blue: 0.259, alpha: 1.0), // #073642
            gutterForeground: NSColor(calibratedRed: 0.345, green: 0.431, blue: 0.459, alpha: 1.0), // #586E75
            activeLineColor: NSColor(calibratedRed: 0.027, green: 0.212, blue: 0.259, alpha: 0.95),
            selectionColor: NSColor(calibratedRed: 0.027, green: 0.212, blue: 0.259, alpha: 0.8),
            keywordColor: NSColor(calibratedRed: 0.522, green: 0.600, blue: 0.0, alpha: 1.0), // #859900
            stringColor: NSColor(calibratedRed: 0.165, green: 0.631, blue: 0.596, alpha: 1.0), // #2AA198
            commentColor: NSColor(calibratedRed: 0.345, green: 0.431, blue: 0.459, alpha: 1.0), // #586E75
            numberColor: NSColor(calibratedRed: 0.827, green: 0.212, blue: 0.510, alpha: 1.0)  // #D33682
        ),
        // 6. Solarized Light
        NppTheme(
            id: "solarized_light",
            name: "Solarized Light",
            isDark: false,
            backgroundColor: NSColor(calibratedRed: 0.992, green: 0.965, blue: 0.890, alpha: 1.0), // #FDF6E3
            foregroundColor: NSColor(calibratedRed: 0.396, green: 0.482, blue: 0.514, alpha: 1.0), // #657B83
            gutterBackground: NSColor(calibratedRed: 0.933, green: 0.910, blue: 0.835, alpha: 1.0), // #EEE8D5
            gutterForeground: NSColor(calibratedRed: 0.576, green: 0.631, blue: 0.631, alpha: 1.0), // #93A1A1
            activeLineColor: NSColor(calibratedRed: 0.933, green: 0.910, blue: 0.835, alpha: 0.95),
            selectionColor: NSColor(calibratedRed: 0.933, green: 0.910, blue: 0.835, alpha: 0.8),
            keywordColor: NSColor(calibratedRed: 0.522, green: 0.600, blue: 0.0, alpha: 1.0),
            stringColor: NSColor(calibratedRed: 0.165, green: 0.631, blue: 0.596, alpha: 1.0),
            commentColor: NSColor(calibratedRed: 0.576, green: 0.631, blue: 0.631, alpha: 1.0),
            numberColor: NSColor(calibratedRed: 0.827, green: 0.212, blue: 0.510, alpha: 1.0)
        ),
        // 7. Deep Black
        NppTheme(
            id: "deep_black",
            name: "Deep Black (OLED)",
            isDark: true,
            backgroundColor: NSColor.black,
            foregroundColor: NSColor(calibratedRed: 0.88, green: 0.88, blue: 0.88, alpha: 1.0),
            gutterBackground: NSColor(calibratedRed: 0.05, green: 0.05, blue: 0.05, alpha: 1.0),
            gutterForeground: NSColor(calibratedRed: 0.40, green: 0.40, blue: 0.40, alpha: 1.0),
            activeLineColor: NSColor(calibratedRed: 0.12, green: 0.12, blue: 0.12, alpha: 0.95),
            selectionColor: NSColor(calibratedRed: 0.20, green: 0.25, blue: 0.35, alpha: 0.8),
            keywordColor: NSColor(calibratedRed: 0.40, green: 0.70, blue: 1.0, alpha: 1.0),
            stringColor: NSColor(calibratedRed: 0.40, green: 0.90, blue: 0.60, alpha: 1.0),
            commentColor: NSColor(calibratedRed: 0.40, green: 0.45, blue: 0.40, alpha: 1.0),
            numberColor: NSColor(calibratedRed: 1.0, green: 0.60, blue: 0.30, alpha: 1.0)
        ),
        // 8. Nord
        NppTheme(
            id: "nord",
            name: "Nord",
            isDark: true,
            backgroundColor: NSColor(calibratedRed: 0.180, green: 0.204, blue: 0.251, alpha: 1.0), // #2E3440
            foregroundColor: NSColor(calibratedRed: 0.925, green: 0.937, blue: 0.957, alpha: 1.0), // #ECEFF4
            gutterBackground: NSColor(calibratedRed: 0.141, green: 0.161, blue: 0.200, alpha: 1.0), // #242933
            gutterForeground: NSColor(calibratedRed: 0.298, green: 0.337, blue: 0.416, alpha: 1.0), // #4C566A
            activeLineColor: NSColor(calibratedRed: 0.231, green: 0.259, blue: 0.322, alpha: 0.95), // #3B4252
            selectionColor: NSColor(calibratedRed: 0.263, green: 0.298, blue: 0.369, alpha: 0.8),
            keywordColor: NSColor(calibratedRed: 0.506, green: 0.631, blue: 0.757, alpha: 1.0), // #81A1C1
            stringColor: NSColor(calibratedRed: 0.639, green: 0.745, blue: 0.549, alpha: 1.0), // #A3BE8C
            commentColor: NSColor(calibratedRed: 0.392, green: 0.451, blue: 0.545, alpha: 1.0), // #616E88
            numberColor: NSColor(calibratedRed: 0.706, green: 0.557, blue: 0.678, alpha: 1.0)  // #B48EAD
        ),
        // 9. Zenburn
        NppTheme(
            id: "zenburn",
            name: "Zenburn",
            isDark: true,
            backgroundColor: NSColor(calibratedRed: 0.247, green: 0.247, blue: 0.247, alpha: 1.0), // #3F3F3F
            foregroundColor: NSColor(calibratedRed: 0.863, green: 0.863, blue: 0.800, alpha: 1.0), // #DCDCCC
            gutterBackground: NSColor(calibratedRed: 0.200, green: 0.200, blue: 0.200, alpha: 1.0),
            gutterForeground: NSColor(calibratedRed: 0.500, green: 0.500, blue: 0.450, alpha: 1.0),
            activeLineColor: NSColor(calibratedRed: 0.310, green: 0.310, blue: 0.310, alpha: 0.95),
            selectionColor: NSColor(calibratedRed: 0.35, green: 0.35, blue: 0.30, alpha: 0.8),
            keywordColor: NSColor(calibratedRed: 0.941, green: 0.875, blue: 0.686, alpha: 1.0), // #F0DFAF
            stringColor: NSColor(calibratedRed: 0.800, green: 0.576, blue: 0.576, alpha: 1.0), // #CC9393
            commentColor: NSColor(calibratedRed: 0.475, green: 0.533, blue: 0.475, alpha: 1.0), // #7F9F7F
            numberColor: NSColor(calibratedRed: 0.549, green: 0.784, blue: 0.702, alpha: 1.0)  // #8CD0D3
        )
    ]

    public static func theme(withId id: String) -> NppTheme {
        if id == "npp_classic" {
            return allThemes.first(where: { $0.id == "light" }) ?? allThemes[0]
        }
        return allThemes.first(where: { $0.id == id }) ?? allThemes[0]
    }
}
