import Foundation
import CryptoKit
import AppKit

public enum NppTools {
    public static func md5(data: Data) -> String {
        let digest = Insecure.MD5.hash(data: data)
        return digest.map { String(format: "%02hhx", $0) }.joined()
    }

    public static func sha1(data: Data) -> String {
        let digest = Insecure.SHA1.hash(data: data)
        return digest.map { String(format: "%02hhx", $0) }.joined()
    }

    public static func sha256(data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02hhx", $0) }.joined()
    }

    public static func sha512(data: Data) -> String {
        let digest = SHA512.hash(data: data)
        return digest.map { String(format: "%02hhx", $0) }.joined()
    }

    public static func base64Encode(string: String) -> String {
        guard let data = string.data(using: .utf8) else { return string }
        return data.base64EncodedString()
    }

    public static func base64Decode(string: String) -> String {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = Data(base64Encoded: trimmed),
              let decoded = String(data: data, encoding: .utf8) else {
            return string
        }
        return decoded
    }

    public static func urlEncode(string: String) -> String {
        return string.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? string
    }

    public static func urlDecode(string: String) -> String {
        return string.removingPercentEncoding ?? string
    }

    public static func asciiToHex(string: String) -> String {
        let bytes = [UInt8](string.utf8)
        return bytes.map { String(format: "%02X", $0) }.joined(separator: " ")
    }

    public static func hexToAscii(string: String) -> String {
        let cleanHex = string.replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: "\r", with: "")
            .replacingOccurrences(of: "\t", with: "")
        var bytes = [UInt8]()
        var index = cleanHex.startIndex
        while index < cleanHex.endIndex {
            guard let nextIndex = cleanHex.index(index, offsetBy: 2, limitedBy: cleanHex.endIndex) else { break }
            let hexByte = String(cleanHex[index..<nextIndex])
            if let byte = UInt8(hexByte, radix: 16) {
                bytes.append(byte)
            }
            index = nextIndex
        }
        return String(bytes: bytes, encoding: .utf8) ?? String(bytes: bytes, encoding: .ascii) ?? string
    }

    public static func copyRTFToClipboard(text: String, fontName: String, fontSize: CGFloat) {
        let font = NSFont(name: fontName, size: fontSize) ?? NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        let attrString = NSAttributedString(string: text, attributes: [.font: font])
        if let rtfData = try? attrString.data(from: NSRange(location: 0, length: attrString.length), documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]) {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setData(rtfData, forType: .rtf)
            NSPasteboard.general.setString(text, forType: .string)
        }
    }

    public static func copyHTMLToClipboard(text: String) {
        let escaped = text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\n", with: "<br/>\n")
        let html = "<pre style=\"font-family: monospace; font-size: 13px; color: #222;\">\(escaped)</pre>"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(html, forType: .html)
        NSPasteboard.general.setString(text, forType: .string)
    }

    public static func showHashDialog(title: String, hash: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = hash
        alert.addButton(withTitle: "Copy to Clipboard")
        alert.addButton(withTitle: "Close")

        if alert.runModal() == .alertFirstButtonReturn {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(hash, forType: .string)
        }
    }

    /// Opens macOS Terminal with its current working directory set directly to the specified folder.
    public static func openTerminal(at dirUrl: URL) {
        var targetUrl = dirUrl
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: dirUrl.path, isDirectory: &isDir) {
            if !isDir.boolValue {
                targetUrl = dirUrl.deletingLastPathComponent()
            }
        }

        if let termUrl = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Terminal") {
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true
            NSWorkspace.shared.open([targetUrl], withApplicationAt: termUrl, configuration: config) { _, error in
                if error != nil {
                    fallbackOpenTerminal(at: targetUrl)
                }
            }
        } else {
            fallbackOpenTerminal(at: targetUrl)
        }
    }

    private static func fallbackOpenTerminal(at dirUrl: URL) {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        proc.arguments = ["-a", "Terminal", dirUrl.path]
        try? proc.run()
    }
}

