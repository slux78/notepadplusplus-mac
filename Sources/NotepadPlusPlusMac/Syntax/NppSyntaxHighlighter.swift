import AppKit

public struct NppSyntaxRules {
    public static let keywords: [String: [String]] = [
        "C++": ["auto", "break", "case", "char", "const", "continue", "default", "do", "double", "else", "enum", "extern", "float", "for", "goto", "if", "int", "long", "register", "return", "short", "signed", "sizeof", "static", "struct", "switch", "typedef", "union", "unsigned", "void", "volatile", "while", "class", "namespace", "public", "private", "protected", "template", "typename", "this", "friend", "virtual", "inline", "explicit", "operator", "export", "bool", "true", "false", "constexpr", "nullptr"],
        "C": ["auto", "break", "case", "char", "const", "continue", "default", "do", "double", "else", "enum", "extern", "float", "for", "goto", "if", "int", "long", "register", "return", "short", "signed", "sizeof", "static", "struct", "switch", "typedef", "union", "unsigned", "void", "volatile", "while"],
        "Swift": ["class", "struct", "enum", "protocol", "extension", "func", "var", "let", "init", "deinit", "self", "Self", "import", "public", "private", "fileprivate", "internal", "open", "final", "static", "guard", "if", "else", "switch", "case", "default", "where", "for", "while", "repeat", "in", "return", "throw", "throws", "try", "catch", "defer", "as", "is", "nil", "true", "false", "async", "await", "actor"],
        "Python": ["def", "class", "import", "from", "as", "return", "if", "elif", "else", "for", "while", "break", "continue", "pass", "try", "except", "finally", "raise", "with", "yield", "lambda", "global", "nonlocal", "assert", "del", "True", "False", "None", "and", "or", "not", "is", "in", "async", "await"],
        "JavaScript": ["function", "var", "let", "const", "return", "if", "else", "switch", "case", "default", "for", "while", "do", "break", "continue", "try", "catch", "finally", "throw", "new", "this", "class", "extends", "super", "import", "export", "from", "async", "await", "yield", "null", "undefined", "true", "false", "typeof", "instanceof", "in", "of"],
        "JSON": ["true", "false", "null"],
        "SQL": ["SELECT", "FROM", "WHERE", "INSERT", "INTO", "VALUES", "UPDATE", "SET", "DELETE", "JOIN", "LEFT", "RIGHT", "INNER", "OUTER", "ON", "GROUP", "BY", "ORDER", "HAVING", "LIMIT", "CREATE", "TABLE", "DROP", "ALTER", "ADD", "PRIMARY", "KEY", "FOREIGN", "REFERENCES", "INDEX", "VIEW", "AS", "AND", "OR", "NOT", "NULL", "IS", "IN", "LIKE", "BETWEEN", "UNION", "ALL", "CASE", "WHEN", "THEN", "ELSE", "END"],
        "Shell": ["echo", "if", "then", "else", "elif", "fi", "case", "esac", "for", "while", "until", "do", "done", "in", "function", "return", "exit", "export", "local", "source", "alias"]
    ]
}

public final class NppSyntaxHighlighter {
    public static func highlight(textStorage: NSTextStorage, language: String, isDarkMode: Bool) {
        let string = textStorage.string
        guard !string.isEmpty else { return }

        textStorage.beginEditing()
        let fullRange = NSRange(location: 0, length: (string as NSString).length)

        // Base text color
        let defaultTextColor = isDarkMode ? NSColor(white: 0.9, alpha: 1.0) : NSColor(white: 0.15, alpha: 1.0)
        textStorage.addAttribute(.foregroundColor, value: defaultTextColor, range: fullRange)

        // Palette
        let keywordColor = isDarkMode ? NSColor(red: 0.35, green: 0.65, blue: 0.95, alpha: 1.0) : NSColor(red: 0.0, green: 0.0, blue: 0.8, alpha: 1.0)
        let stringColor = isDarkMode ? NSColor(red: 0.85, green: 0.55, blue: 0.35, alpha: 1.0) : NSColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0)
        let commentColor = isDarkMode ? NSColor(red: 0.45, green: 0.70, blue: 0.45, alpha: 1.0) : NSColor(red: 0.0, green: 0.5, blue: 0.0, alpha: 1.0)
        let numberColor = isDarkMode ? NSColor(red: 0.95, green: 0.50, blue: 0.50, alpha: 1.0) : NSColor(red: 0.9, green: 0.0, blue: 0.0, alpha: 1.0)
        let preprocColor = isDarkMode ? NSColor(red: 0.80, green: 0.50, blue: 0.80, alpha: 1.0) : NSColor(red: 0.5, green: 0.0, blue: 0.5, alpha: 1.0)

        // 1. Strings: "..." and '...'
        applyPattern(#"\"([^\"\\]|\\.)*\"|'([^'\\]|\\.)*'"#, in: string, color: stringColor, textStorage: textStorage)

        // 2. Numbers
        applyPattern(#"\b\d+(\.\d+)?\b"#, in: string, color: numberColor, textStorage: textStorage)

        // 3. Preprocessor directives for C/C++ (#include, #define, #pragma)
        if language == "C++" || language == "C" {
            applyPattern(#"^\s*#[a-zA-Z_]+"#, in: string, color: preprocColor, textStorage: textStorage, options: [.anchorsMatchLines])
        }

        // 4. Keywords
        if let kws = NppSyntaxRules.keywords[language] {
            let pattern = "\\b(" + kws.joined(separator: "|") + ")\\b"
            applyPattern(pattern, in: string, color: keywordColor, textStorage: textStorage)
        }

        // 5. Comments (Single line // or # and multi-line /* ... */)
        if language == "Python" || language == "Shell" {
            applyPattern(#"#.*$"#, in: string, color: commentColor, textStorage: textStorage, options: [.anchorsMatchLines])
        } else if language != "Plain Text" {
            applyPattern(#"//.*$"#, in: string, color: commentColor, textStorage: textStorage, options: [.anchorsMatchLines])
            applyPattern(#"/\*[\s\S]*?\*/"#, in: string, color: commentColor, textStorage: textStorage)
        }

        textStorage.endEditing()
    }

    private static func applyPattern(_ pattern: String, in string: String, color: NSColor, textStorage: NSTextStorage, options: NSRegularExpression.Options = []) {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return }
        let matches = regex.matches(in: string, options: [], range: NSRange(location: 0, length: (string as NSString).length))
        for match in matches {
            textStorage.addAttribute(.foregroundColor, value: color, range: match.range)
        }
    }
}
