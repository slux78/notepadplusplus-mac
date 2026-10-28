import AppKit
import SwiftUI
import CryptoKit

// MARK: - Hash Algorithm Definition
public enum NppHashAlgorithm: String, CaseIterable, Identifiable {
    case md5 = "MD5"
    case sha1 = "SHA-1"
    case sha256 = "SHA-256"
    case sha512 = "SHA-512"

    public var id: String { rawValue }

    public func compute(data: Data) -> String {
        switch self {
        case .md5:
            return Insecure.MD5.hash(data: data).map { String(format: "%02x", $0) }.joined()
        case .sha1:
            return Insecure.SHA1.hash(data: data).map { String(format: "%02x", $0) }.joined()
        case .sha256:
            return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        case .sha512:
            return SHA512.hash(data: data).map { String(format: "%02x", $0) }.joined()
        }
    }

    public func compute(string: String) -> String {
        let data = string.data(using: .utf8) ?? Data()
        return compute(data: data)
    }

    public func computeLineByLine(text: String) -> String {
        if text.isEmpty { return "" }
        let lines = text.components(separatedBy: "\n")
        var output: [String] = []
        for line in lines {
            let cleanLine = line.hasSuffix("\r") ? String(line.dropLast()) : line
            if cleanLine.isEmpty {
                output.append("")
            } else {
                output.append(compute(string: cleanLine))
            }
        }
        return output.joined(separator: "\n")
    }
}

// MARK: - Hash From Text Dialog View (Notepad++ HashFromTextDlg parity)
public struct NppHashFromTextDialogView: View {
    public let algorithm: NppHashAlgorithm
    @ObservedObject public var workspace: NppWorkspace
    @State public var inputText: String = ""
    @State public var treatEachLineSeparately: Bool = false
    public let onClose: () -> Void

    public init(algorithm: NppHashAlgorithm, workspace: NppWorkspace, initialText: String? = nil, onClose: @escaping () -> Void) {
        self.algorithm = algorithm
        self.workspace = workspace
        self._inputText = State(initialValue: initialText ?? "")
        self.onClose = onClose
    }

    public var calculatedHash: String {
        if treatEachLineSeparately {
            return algorithm.computeLineByLine(text: inputText)
        } else {
            return inputText.isEmpty ? "" : algorithm.compute(string: inputText)
        }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(workspace.tr("Treat each line as a separate string"), isOn: $treatEachLineSeparately)
                .font(.system(size: 11))
                .toggleStyle(CheckboxToggleStyle())

            Text(workspace.tr("Text to Hash:"))
                .font(.system(size: 11, weight: .semibold))

            TextEditor(text: $inputText)
                .font(.system(size: 11, design: .monospaced))
                .frame(minHeight: 80, maxHeight: 120)
                .border(Color.secondary.opacity(0.3), width: 1)

            Text(workspace.tr("Hash Result:"))
                .font(.system(size: 11, weight: .semibold))

            ScrollView {
                Text(calculatedHash)
                    .font(.system(size: 11, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(4)
                    .textSelection(.enabled)
            }
            .frame(minHeight: 80, maxHeight: 120)
            .border(Color.secondary.opacity(0.3), width: 1)
            .background(Color(NSColor.textBackgroundColor))

            HStack {
                Spacer()
                Button(workspace.tr("Copy to Clipboard")) {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(calculatedHash, forType: .string)
                }
                .keyboardShortcut("c", modifiers: [.command])

                Button(workspace.tr("Close")) {
                    onClose()
                }
                .keyboardShortcut(.cancelAction)
            }
        }
        .padding(14)
        .frame(minWidth: 420, minHeight: 340)
    }
}

// MARK: - Hash From Text Window Controller
public final class NppHashFromTextWindowController: NSObject, NSWindowDelegate {
    public static let shared = NppHashFromTextWindowController()
    public private(set) var panel: NSPanel?
    private weak var workspace: NppWorkspace?

    private override init() {
        super.init()
    }

    public func show(algorithm: NppHashAlgorithm, workspace: NppWorkspace, initialText: String? = nil) {
        self.workspace = workspace
        close()

        let newPanel = NSPanel(
            contentRect: NSRect(x: 240, y: 320, width: 460, height: 380),
            styleMask: [.titled, .closable, .resizable, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        newPanel.isFloatingPanel = true
        newPanel.level = .floating
        newPanel.hidesOnDeactivate = true
        newPanel.isReleasedWhenClosed = false
        newPanel.delegate = self
        newPanel.title = workspace.tr("Generate \(algorithm.rawValue)")

        let hostingView = NSHostingView(
            rootView: NppHashFromTextDialogView(
                algorithm: algorithm,
                workspace: workspace,
                initialText: initialText,
                onClose: { [weak self] in
                    self?.close()
                }
            )
        )
        newPanel.contentView = hostingView
        self.panel = newPanel

        newPanel.center()
        newPanel.makeKeyAndOrderFront(nil)
    }

    public func close() {
        panel?.orderOut(nil)
        panel = nil
    }

    public func windowWillClose(_ notification: Notification) {
        panel = nil
    }
}

// MARK: - Hash From Files Dialog View (Notepad++ HashFromFilesDlg parity)
public struct NppHashFromFilesDialogView: View {
    public let algorithm: NppHashAlgorithm
    @ObservedObject public var workspace: NppWorkspace
    @State public var selectedPaths: [URL] = []
    @State public var formattedResults: String = ""
    public let onClose: () -> Void

    public init(algorithm: NppHashAlgorithm, workspace: NppWorkspace, onClose: @escaping () -> Void) {
        self.algorithm = algorithm
        self.workspace = workspace
        self.onClose = onClose
    }

    private var pathsText: String {
        selectedPaths.map { $0.path }.joined(separator: "\n")
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(workspace.tr("Choose files to generate \(algorithm.rawValue)...")) {
                pickFiles()
            }
            .font(.system(size: 11))

            Text(workspace.tr("File Paths:"))
                .font(.system(size: 11, weight: .semibold))

            ScrollView {
                Text(pathsText)
                    .font(.system(size: 11, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(4)
                    .textSelection(.enabled)
            }
            .frame(minHeight: 70, maxHeight: 110)
            .border(Color.secondary.opacity(0.3), width: 1)
            .background(Color(NSColor.textBackgroundColor))

            Text(workspace.tr("Hash Result:"))
                .font(.system(size: 11, weight: .semibold))

            ScrollView {
                Text(formattedResults)
                    .font(.system(size: 11, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(4)
                    .textSelection(.enabled)
            }
            .frame(minHeight: 100, maxHeight: 150)
            .border(Color.secondary.opacity(0.3), width: 1)
            .background(Color(NSColor.textBackgroundColor))

            HStack {
                Spacer()
                Button(workspace.tr("Copy to Clipboard")) {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(formattedResults, forType: .string)
                }
                .disabled(formattedResults.isEmpty)

                Button(workspace.tr("Close")) {
                    onClose()
                }
                .keyboardShortcut(.cancelAction)
            }
        }
        .padding(14)
        .frame(minWidth: 460, minHeight: 380)
    }

    private func pickFiles() {
        let openPanel = NSOpenPanel()
        openPanel.allowsMultipleSelection = true
        openPanel.canChooseDirectories = false
        openPanel.canChooseFiles = true
        if openPanel.runModal() == .OK {
            selectedPaths = openPanel.urls
            computeHashes(for: openPanel.urls)
        }
    }

    public func computeHashes(for urls: [URL]) {
        var lines: [String] = []
        for url in urls {
            if let data = try? Data(contentsOf: url) {
                let hash = algorithm.compute(data: data)
                // Official Notepad++ format: <hash>  <filename>\n strictly two spaces!
                lines.append("\(hash)  \(url.lastPathComponent)")
            } else {
                lines.append("<Error reading file>  \(url.lastPathComponent)")
            }
        }
        formattedResults = lines.joined(separator: "\n")
    }
}

// MARK: - Hash From Files Window Controller
public final class NppHashFromFilesWindowController: NSObject, NSWindowDelegate {
    public static let shared = NppHashFromFilesWindowController()
    public private(set) var panel: NSPanel?
    private weak var workspace: NppWorkspace?

    private override init() {
        super.init()
    }

    public func show(algorithm: NppHashAlgorithm, workspace: NppWorkspace) {
        self.workspace = workspace
        close()

        let newPanel = NSPanel(
            contentRect: NSRect(x: 260, y: 300, width: 500, height: 420),
            styleMask: [.titled, .closable, .resizable, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        newPanel.isFloatingPanel = true
        newPanel.level = .floating
        newPanel.hidesOnDeactivate = true
        newPanel.isReleasedWhenClosed = false
        newPanel.delegate = self
        newPanel.title = workspace.tr("Generate \(algorithm.rawValue) from files")

        let hostingView = NSHostingView(
            rootView: NppHashFromFilesDialogView(
                algorithm: algorithm,
                workspace: workspace,
                onClose: { [weak self] in
                    self?.close()
                }
            )
        )
        newPanel.contentView = hostingView
        self.panel = newPanel

        newPanel.center()
        newPanel.makeKeyAndOrderFront(nil)
    }

    public func close() {
        panel?.orderOut(nil)
        panel = nil
    }

    public func windowWillClose(_ notification: Notification) {
        panel = nil
    }
}
