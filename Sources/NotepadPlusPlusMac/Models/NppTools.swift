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
}
