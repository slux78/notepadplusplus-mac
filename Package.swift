// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "NotepadPlusPlusMac",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "NotepadPlusPlusMac",
            targets: ["NotepadPlusPlusMac"]
        ),
        .library(
            name: "NppCore",
            targets: ["NppCore"]
        )
    ],
    targets: [
        .target(
            name: "NppCore",
            path: "Sources/NppCore",
            exclude: [
                "uchardet/Big5Freq.tab",
                "uchardet/EUCKRFreq.tab",
                "uchardet/EUCTWFreq.tab",
                "uchardet/GB2312Freq.tab",
                "uchardet/JISFreq.tab",
                "uchardet/README.TXT"
            ],
            sources: ["NppEncoding.cpp", "uchardet"],
            publicHeadersPath: "include",
            cxxSettings: [
                .headerSearchPath("."),
                .headerSearchPath("uchardet")
            ],
            linkerSettings: [
                .linkedLibrary("iconv")
            ]
        ),
        .executableTarget(
            name: "NotepadPlusPlusMac",
            dependencies: ["NppCore"],
            path: "Sources/NotepadPlusPlusMac"
        )
    ],
    cxxLanguageStandard: .cxx17
)
