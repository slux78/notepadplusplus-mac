import AppKit

public struct NppSyntaxRules {
    public static let controlFlowKeywords: [String: [String]] = [
        "C++": ["if", "else", "switch", "case", "default", "break", "continue", "return", "goto", "for", "while", "do", "try", "catch", "throw"],
        "C": ["if", "else", "switch", "case", "default", "break", "continue", "return", "goto", "for", "while", "do"],
        "Swift": ["if", "else", "switch", "case", "default", "break", "continue", "return", "fallthrough", "for", "while", "repeat", "in", "where", "guard", "defer", "try", "catch", "throw", "throws", "rethrows", "async", "await", "yield"],
        "Python": ["if", "elif", "else", "for", "while", "break", "continue", "pass", "return", "yield", "try", "except", "finally", "raise", "with", "assert", "async", "await"],
        "JavaScript": ["if", "else", "switch", "case", "default", "break", "continue", "return", "for", "while", "do", "try", "catch", "finally", "throw", "yield", "await"],
        "TypeScript": ["if", "else", "switch", "case", "default", "break", "continue", "return", "for", "while", "do", "try", "catch", "finally", "throw", "yield", "await"],
        "Java": ["if", "else", "switch", "case", "default", "break", "continue", "return", "for", "while", "do", "try", "catch", "finally", "throw", "throws", "assert"],
        "Rust": ["if", "else", "match", "return", "break", "continue", "loop", "while", "for", "in", "where", "yield", "await", "try"],
        "Go": ["if", "else", "switch", "case", "default", "for", "range", "break", "continue", "return", "goto", "fallthrough", "defer", "go", "select"],
        "C#": ["if", "else", "switch", "case", "default", "break", "continue", "return", "goto", "for", "foreach", "in", "while", "do", "try", "catch", "finally", "throw", "yield", "await"],
        "PHP": ["if", "else", "elseif", "switch", "case", "default", "break", "continue", "return", "while", "do", "for", "foreach", "as", "try", "catch", "finally", "throw", "yield"],
        "Ruby": ["if", "elsif", "else", "unless", "switch", "case", "when", "then", "break", "next", "redo", "retry", "return", "while", "until", "for", "in", "begin", "rescue", "ensure", "raise", "yield"],
        "Shell": ["if", "then", "else", "elif", "fi", "case", "esac", "for", "while", "until", "do", "done", "in", "return", "exit", "select"]
    ]

    public static let declarationKeywords: [String: [String]] = [
        "C++": ["class", "struct", "union", "enum", "namespace", "template", "typename", "public", "private", "protected", "friend", "virtual", "inline", "explicit", "export", "operator", "const", "constexpr", "static", "extern", "volatile", "mutable", "register", "typedef", "decltype"],
        "C": ["struct", "union", "enum", "const", "static", "extern", "volatile", "register", "typedef", "inline"],
        "Swift": ["class", "struct", "enum", "protocol", "extension", "actor", "func", "var", "let", "init", "deinit", "subscript", "typealias", "associatedtype", "import", "public", "private", "fileprivate", "internal", "open", "final", "static", "mutating", "nonmutating", "override", "required", "convenience", "dynamic", "weak", "unowned", "lazy"],
        "Python": ["def", "class", "import", "from", "as", "global", "nonlocal", "lambda", "del"],
        "JavaScript": ["function", "var", "let", "const", "class", "extends", "super", "import", "export", "from", "new", "typeof", "instanceof", "in", "of", "delete", "void"],
        "TypeScript": ["function", "var", "let", "const", "class", "extends", "super", "import", "export", "from", "new", "typeof", "instanceof", "in", "of", "delete", "void", "type", "interface", "declare", "module", "namespace", "keyof", "readonly", "enum", "implements", "override", "abstract", "as", "is"],
        "Java": ["class", "interface", "enum", "extends", "implements", "package", "import", "public", "private", "protected", "static", "final", "abstract", "synchronized", "volatile", "transient", "native", "strictfp", "new", "instanceof"],
        "Rust": ["fn", "let", "mut", "pub", "struct", "enum", "trait", "impl", "type", "const", "static", "mod", "use", "crate", "unsafe", "extern", "as", "ref", "move"],
        "Go": ["func", "var", "const", "type", "struct", "interface", "package", "import", "chan", "map"],
        "C#": ["class", "struct", "interface", "enum", "record", "delegate", "namespace", "using", "public", "private", "protected", "internal", "static", "readonly", "const", "virtual", "override", "abstract", "sealed", "new", "event", "var", "is", "as", "sizeof", "typeof"],
        "PHP": ["function", "class", "interface", "trait", "namespace", "use", "public", "private", "protected", "static", "final", "abstract", "const", "new", "instanceof", "require", "require_once", "include", "include_once", "echo", "print"],
        "Ruby": ["def", "class", "module", "end", "self", "super", "alias", "undef", "require", "require_relative", "include", "extend", "attr_accessor", "attr_reader", "attr_writer", "puts", "print"],
        "Shell": ["function", "local", "export", "source", "alias", "readonly", "declare", "typeset"]
    ]

    public static let builtinTypes: [String: [String]] = [
        "C++": ["void", "bool", "char", "wchar_t", "char16_t", "char32_t", "int", "short", "long", "float", "double", "signed", "unsigned", "size_t", "int8_t", "int16_t", "int32_t", "int64_t", "uint8_t", "uint16_t", "uint32_t", "uint64_t", "string", "wstring", "vector", "map", "unordered_map", "set", "unordered_set", "pair", "tuple", "unique_ptr", "shared_ptr", "weak_ptr", "auto"],
        "C": ["void", "char", "short", "int", "long", "float", "double", "signed", "unsigned", "size_t", "int8_t", "int16_t", "int32_t", "int64_t", "uint8_t", "uint16_t", "uint32_t", "uint64_t", "bool"],
        "Swift": ["Int", "Int8", "Int16", "Int32", "Int64", "UInt", "UInt8", "UInt16", "UInt32", "UInt64", "Double", "Float", "Float80", "Bool", "String", "Character", "Substring", "Array", "Dictionary", "Set", "Optional", "Result", "Any", "AnyObject", "Void", "Never", "UUID", "URL", "Date", "Data", "Error", "View", "Text", "Image", "Color", "Button", "HStack", "VStack", "ZStack"],
        "Python": ["int", "float", "complex", "str", "bytes", "bytearray", "bool", "list", "tuple", "range", "dict", "set", "frozenset", "object", "type", "Exception", "ValueError", "TypeError", "KeyError", "IndexError"],
        "JavaScript": ["Number", "String", "Boolean", "Object", "Array", "Function", "Symbol", "BigInt", "Map", "Set", "WeakMap", "WeakSet", "Promise", "Date", "RegExp", "Error"],
        "TypeScript": ["number", "string", "boolean", "object", "symbol", "bigint", "any", "unknown", "never", "void", "Array", "Record", "Partial", "Readonly", "Pick", "Omit", "Promise", "Map", "Set"],
        "Java": ["byte", "short", "int", "long", "float", "double", "char", "boolean", "void", "Byte", "Short", "Integer", "Long", "Float", "Double", "Character", "Boolean", "String", "Object", "List", "ArrayList", "Map", "HashMap", "Set", "HashSet", "Thread", "Runnable", "Exception"],
        "Rust": ["i8", "i16", "i32", "i64", "i128", "isize", "u8", "u16", "u32", "u64", "u128", "usize", "f32", "f64", "bool", "char", "str", "String", "Vec", "Option", "Result", "Box", "Rc", "Arc", "Cell", "RefCell"],
        "Go": ["bool", "string", "int", "int8", "int16", "int32", "int64", "uint", "uint8", "uint16", "uint32", "uint64", "uintptr", "byte", "rune", "float32", "float64", "complex64", "complex128", "error"],
        "C#": ["void", "bool", "byte", "sbyte", "char", "decimal", "double", "float", "int", "uint", "long", "ulong", "short", "ushort", "object", "string", "dynamic", "Int32", "Int64", "String", "Boolean", "Object", "List", "Dictionary", "Task", "Thread", "Exception"]
    ]

    public static let constants: [String: [String]] = [
        "C++": ["true", "false", "nullptr", "NULL", "this"],
        "C": ["true", "false", "NULL"],
        "Swift": ["true", "false", "nil", "self", "Self"],
        "Python": ["True", "False", "None", "self", "cls"],
        "JavaScript": ["true", "false", "null", "undefined", "NaN", "Infinity", "this"],
        "TypeScript": ["true", "false", "null", "undefined", "NaN", "Infinity", "this"],
        "Java": ["true", "false", "null", "this", "super"],
        "Rust": ["true", "false", "self", "Self", "None", "Some", "Ok", "Err"],
        "Go": ["true", "false", "nil", "iota"],
        "C#": ["true", "false", "null", "this", "base"],
        "PHP": ["true", "false", "null", "TRUE", "FALSE", "NULL", "$this"],
        "Ruby": ["true", "false", "nil", "self"],
        "JSON": ["true", "false", "null"],
        "YAML": ["true", "false", "yes", "no", "null", "TRUE", "FALSE"]
    ]
}

public final class NppSyntaxHighlighter {
    public static func highlight(textStorage: NSTextStorage, language: String, isDarkMode: Bool,
                                 baseFont: NSFont? = nil, theme: NppTheme? = nil,
                                 maxFileSizeMB: Int = 200, userDefinedLanguage: NppUserDefineLanguage? = nil,
                                 treatBackslashAsEscapeForSql: Bool = false,
                                 userKeywords: [String: String] = [:]) {
        let string = textStorage.string
        guard !string.isEmpty else { return }
        if maxFileSizeMB > 0 && (string as NSString).length > maxFileSizeMB * 1024 * 1024 {
            return
        }

        textStorage.beginEditing()
        let fullRange = NSRange(location: 0, length: (string as NSString).length)

        // Set base font for entire text storage so all characters use the user's selected font
        let effectiveFont = baseFont ?? NppWorkspace.resolveFont(name: "Menlo", size: 13)
        textStorage.addAttribute(.font, value: effectiveFont, range: fullRange)

        // Palette Definition (Tailored for authentic Scintilla / Notepad++ stylers)
        let defaultTextColor: NSColor
        if isDarkMode {
            defaultTextColor = (theme?.isDark == true ? theme?.foregroundColor : nil) ?? NSColor(calibratedWhite: 0.90, alpha: 1.0)
        } else {
            defaultTextColor = (theme?.isDark == false ? theme?.foregroundColor : nil) ?? NSColor(calibratedWhite: 0.15, alpha: 1.0)
        }
        textStorage.addAttribute(.foregroundColor, value: defaultTextColor, range: fullRange)

        let controlFlowColor = isDarkMode ? NSColor(calibratedRed: 0.77, green: 0.52, blue: 0.75, alpha: 1.0) : NSColor(calibratedRed: 0.68, green: 0.0, blue: 0.85, alpha: 1.0) // Magenta/Purple #C586C0
        let declarationColor = theme?.keywordColor ?? (isDarkMode ? NSColor(calibratedRed: 0.34, green: 0.61, blue: 0.84, alpha: 1.0) : NSColor(calibratedRed: 0.0, green: 0.0, blue: 0.85, alpha: 1.0)) // Blue #569CD6
        let typeColor = isDarkMode ? NSColor(calibratedRed: 0.30, green: 0.79, blue: 0.69, alpha: 1.0) : NSColor(calibratedRed: 0.15, green: 0.50, blue: 0.60, alpha: 1.0) // Teal/Cyan #4EC9B0
        let functionColor = isDarkMode ? NSColor(calibratedRed: 0.86, green: 0.86, blue: 0.67, alpha: 1.0) : NSColor(calibratedRed: 0.47, green: 0.37, blue: 0.15, alpha: 1.0) // Warm Gold #DCDCAA
        let constantColor = isDarkMode ? NSColor(calibratedRed: 0.34, green: 0.61, blue: 0.84, alpha: 1.0) : NSColor(calibratedRed: 0.0, green: 0.20, blue: 0.80, alpha: 1.0)
        let numberColor = theme?.numberColor ?? (isDarkMode ? NSColor(calibratedRed: 0.71, green: 0.81, blue: 0.66, alpha: 1.0) : NSColor(calibratedRed: 0.03, green: 0.52, blue: 0.34, alpha: 1.0)) // Mint Green #B5CEA8
        let stringColor = theme?.stringColor ?? (isDarkMode ? NSColor(calibratedRed: 0.81, green: 0.57, blue: 0.47, alpha: 1.0) : NSColor(calibratedRed: 0.64, green: 0.08, blue: 0.08, alpha: 1.0)) // Coral #CE9178
        let escapeCharColor = isDarkMode ? NSColor(calibratedRed: 0.84, green: 0.73, blue: 0.49, alpha: 1.0) : NSColor(calibratedRed: 0.93, green: 0.0, blue: 0.0, alpha: 1.0) // Gold #D7BA7D
        let commentColor = theme?.commentColor ?? (isDarkMode ? NSColor(calibratedRed: 0.42, green: 0.60, blue: 0.33, alpha: 1.0) : NSColor(calibratedRed: 0.0, green: 0.50, blue: 0.0, alpha: 1.0)) // Forest Green #6A9955
        let preprocColor = isDarkMode ? NSColor(calibratedRed: 0.77, green: 0.52, blue: 0.75, alpha: 1.0) : NSColor(calibratedRed: 0.50, green: 0.0, blue: 0.50, alpha: 1.0)
        let variableColor = isDarkMode ? NSColor(calibratedRed: 0.61, green: 0.86, blue: 0.99, alpha: 1.0) : NSColor(calibratedRed: 0.0, green: 0.10, blue: 0.60, alpha: 1.0) // Cyan #9CDCFE
        let operatorColor = isDarkMode ? NSColor(calibratedWhite: 0.83, alpha: 1.0) : NSColor(calibratedWhite: 0.20, alpha: 1.0)

        if let udl = userDefinedLanguage {
            applyUserDefinedLanguage(udl, to: textStorage, string: string,
                                     baseFont: effectiveFont,
                                     keywordColors: [declarationColor, controlFlowColor, typeColor,
                                                     constantColor, functionColor, preprocColor,
                                                     variableColor, operatorColor],
                                     numberColor: numberColor, operatorColor: operatorColor,
                                     commentColor: commentColor)
            textStorage.endEditing()
            return
        }

        // 0. Operators & Arrows
        if language != "Plain Text" && language != "JSON" {
            applyPattern(#"(->|=>|::|==|!=|<=|>=|&&|\|\|)"#, in: string, color: operatorColor, textStorage: textStorage)
        }

        // 1. General PascalCase Identifiers (Classes / Structs / Types)
        if language != "Plain Text" && language != "HTML" && language != "XML" && language != "JSON" {
            applyPattern(#"\b[A-Z][a-zA-Z0-9_]*\b"#, in: string, color: typeColor, textStorage: textStorage)
        }

        // 2. Builtin Types
        if let types = NppSyntaxRules.builtinTypes[language] {
            let pattern = "\\b(" + types.joined(separator: "|") + ")\\b"
            applyPattern(pattern, in: string, color: typeColor, textStorage: textStorage)
        }

        // 3. Function Calls & Declarations: name(...)
        if language != "Plain Text" && language != "HTML" && language != "XML" && language != "JSON" && language != "CSS" {
            applyPattern(#"\b([a-zA-Z_][a-zA-Z0-9_]*)(?=\s*\()"#, in: string, color: functionColor, textStorage: textStorage)
        }

        // 4. Numbers & Numeric Literals (Hex 0x..., Binary 0b..., Floats, Decimals)
        applyPattern(#"\b0x[0-9a-fA-F]+[uUlL]*\b|\b0b[01]+\b|\b\d+(\.\d+)?([eE][+-]?\d+)?[fFdD]?\b"#, in: string, color: numberColor, textStorage: textStorage)

        // 5. Constants & Booleans
        if let consts = NppSyntaxRules.constants[language] {
            let pattern = "\\b(" + consts.joined(separator: "|") + ")\\b"
            applyPattern(pattern, in: string, color: constantColor, textStorage: textStorage)
        }

        // 6. Declaration & Storage Keywords
        if let decls = NppSyntaxRules.declarationKeywords[language] {
            let pattern = "\\b(" + decls.joined(separator: "|") + ")\\b"
            applyPattern(pattern, in: string, color: declarationColor, textStorage: textStorage)
        }

        // 7. Control Flow Keywords
        if let flows = NppSyntaxRules.controlFlowKeywords[language] {
            let pattern = "\\b(" + flows.joined(separator: "|") + ")\\b"
            applyPattern(pattern, in: string, color: controlFlowColor, textStorage: textStorage)
        }

        // 7b. User-defined Keywords from Style Configurator (workspace.styleUserKeywords)
        if !userKeywords.isEmpty {
            let langKeys = (language == "Shell") ? ["Shell", "Bash / Shell"] : [language]
            for lk in langKeys {
                for (styleName, targetColor) in [("INSTRUCTION WORD", declarationColor), ("TYPE WORD", typeColor)] {
                    if let kwStr = userKeywords["\(lk)|\(styleName)"], !kwStr.isEmpty {
                        let words = kwStr.split(whereSeparator: { $0.isWhitespace })
                            .map { NSRegularExpression.escapedPattern(for: String($0)) }
                            .filter { !$0.isEmpty }
                        if !words.isEmpty {
                            let pattern = "\\b(" + words.joined(separator: "|") + ")\\b"
                            applyPattern(pattern, in: string, color: targetColor, textStorage: textStorage)
                        }
                    }
                }
            }
        }

        // 8. Preprocessor & Decorators
        if language == "C++" || language == "C" || language == "C#" {
            applyPattern(#"^\s*#[a-zA-Z_]+"#, in: string, color: preprocColor, textStorage: textStorage, options: [.anchorsMatchLines])
        }
        if language == "Swift" || language == "Python" || language == "TypeScript" {
            applyPattern(#"@[a-zA-Z_][a-zA-Z0-9_]*"#, in: string, color: preprocColor, textStorage: textStorage)
        }

        // 9. Language Specific Syntax Enhancements
        if language == "HTML" || language == "XML" {
            // Tag names in Blue
            applyPattern(#"</?[a-zA-Z0-9_\-]+|/?>"#, in: string, color: declarationColor, textStorage: textStorage)
            // Attribute names in Cyan
            applyPattern(#"\b[a-zA-Z0-9_\-]+(?=\s*=)"#, in: string, color: variableColor, textStorage: textStorage)
        } else if language == "JSON" {
            // JSON Keys
            applyPattern(#"\"([^\"\\]|\\.)*\"(?=\s*:)"#, in: string, color: variableColor, textStorage: textStorage)
        } else if language == "CSS" {
            // Properties
            applyPattern(#"\b([a-zA-Z\-]+)(?=\s*:)"#, in: string, color: variableColor, textStorage: textStorage)
            // Selectors (.class, #id)
            applyPattern(#"(\.[a-zA-Z0-9_\-]+|#[a-zA-Z0-9_\-]+)"#, in: string, color: functionColor, textStorage: textStorage)
            // Units (px, rem, em, %)
            applyPattern(#"\b\d+(px|em|rem|%|vh|vw|pt|s|ms)\b"#, in: string, color: typeColor, textStorage: textStorage)
        } else if language == "SQL" {
            // SQL Clauses
            let sqlClauses = #"\b(SELECT|FROM|WHERE|INSERT|INTO|VALUES|UPDATE|SET|DELETE|JOIN|LEFT|RIGHT|INNER|OUTER|CROSS|ON|GROUP\s+BY|ORDER\s+BY|HAVING|LIMIT|OFFSET|UNION\s+ALL|UNION|CREATE\s+TABLE|DROP\s+TABLE|ALTER\s+TABLE|PRIMARY\s+KEY|FOREIGN\s+KEY|REFERENCES|INDEX|VIEW|AS|AND|OR|NOT|NULL|IS|IN|LIKE|BETWEEN|CASE|WHEN|THEN|ELSE|END|EXISTS|DISTINCT|CASCADE)\b"#
            applyPattern(sqlClauses, in: string, color: declarationColor, textStorage: textStorage, options: [.caseInsensitive])
            // SQL Functions
            let sqlFuncs = #"\b(COUNT|SUM|AVG|MAX|MIN|COALESCE|CONCAT|SUBSTRING|TRIM|UPPER|LOWER|LENGTH|NOW|DATE|IFNULL|ROUND|CAST)\b"#
            applyPattern(sqlFuncs, in: string, color: functionColor, textStorage: textStorage, options: [.caseInsensitive])
        } else if language == "PHP" {
            // PHP Variables $var
            applyPattern(#"\$[a-zA-Z_][a-zA-Z0-9_]*"#, in: string, color: variableColor, textStorage: textStorage)
        } else if language == "Shell" {
            // Environment variables
            applyPattern(#"\$[a-zA-Z0-9_]+|\$\{[^}]+\}|\$[@*#?$!]"#, in: string, color: variableColor, textStorage: textStorage)
            // Flags
            applyPattern(#"\s(-[a-zA-Z]|--[a-zA-Z0-9_-]+)"#, in: string, color: constantColor, textStorage: textStorage)
        }

        // 10. Strings: Multi-line and Single-line strings
        let stringPattern: String
        if language == "SQL" {
            if treatBackslashAsEscapeForSql {
                // MySQL style: backslash escapes single quotes
                stringPattern = #"\"([^\"\\]|\\.)*\"|'([^'\\]|\\.)*'|`([^`\\]|\\.)*`"#
            } else {
                // Standard SQL: only doubled single quotes '' are escaped inside strings, backslash is literal
                stringPattern = #"\"([^\"\\]|\\.)*\"|'([^']|'')*'|`([^`\\]|\\.)*`"#
            }
        } else {
            stringPattern = #"\"\"\"[\s\S]*?\"\"\"|'''[\s\S]*?'''|\"([^\"\\]|\\.)*\"|'([^'\\]|\\.)*'|`([^`\\]|\\.)*`"#
        }
        if let regex = try? NSRegularExpression(pattern: stringPattern, options: []) {
            let matches = regex.matches(in: string, options: [], range: fullRange)
            for m in matches {
                textStorage.addAttribute(.foregroundColor, value: stringColor, range: m.range)
                // Highlight escape sequences inside this string
                let subStr = (string as NSString).substring(with: m.range)
                if let escRegex = try? NSRegularExpression(pattern: #"\\[nrt0"'\\]|\\x[0-9a-fA-F]{2}|\\u[0-9a-fA-F]{4}"#, options: []) {
                    let escMatches = escRegex.matches(in: subStr, options: [], range: NSRange(location: 0, length: (subStr as NSString).length))
                    for esc in escMatches {
                        let actualRange = NSRange(location: m.range.location + esc.range.location, length: esc.range.length)
                        textStorage.addAttribute(.foregroundColor, value: escapeCharColor, range: actualRange)
                    }
                }
            }
        }

        // 11. Comments (Overriding all tokens inside comments, styled with Italic Font)
        var commentRanges: [NSRange] = []
        if language == "Python" || language == "Shell" || language == "Ruby" || language == "YAML" {
            collectRanges(#"#.*$"#, in: string, options: [.anchorsMatchLines], into: &commentRanges)
        } else if language == "SQL" {
            collectRanges(#"--.*$"#, in: string, options: [.anchorsMatchLines], into: &commentRanges)
            collectRanges(#"/\*[\s\S]*?\*/"#, in: string, options: [], into: &commentRanges)
        } else if language == "HTML" || language == "XML" {
            collectRanges(#"<!--[\s\S]*?-->"#, in: string, options: [], into: &commentRanges)
        } else if language != "Plain Text" {
            collectRanges(#"//.*$"#, in: string, options: [.anchorsMatchLines], into: &commentRanges)
            collectRanges(#"/\*[\s\S]*?\*/"#, in: string, options: [], into: &commentRanges)
        }

        let italicFont: NSFont?
        if let f = baseFont {
            italicFont = NSFontManager.shared.convert(f, toHaveTrait: .italicFontMask)
        } else {
            italicFont = nil
        }

        for cr in commentRanges {
            textStorage.addAttribute(.foregroundColor, value: commentColor, range: cr)
            if let itFont = italicFont {
                textStorage.addAttribute(.font, value: itFont, range: cr)
            }
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

    private static func applyUDLStyle(named styleName: String,
                                      language: NppUserDefineLanguage,
                                      range: NSRange,
                                      textStorage: NSTextStorage,
                                      fallbackFgColor: NSColor,
                                      baseFont: NSFont,
                                      defaultItalicForComments: Bool = false) {
        let fgColor = udlColor(named: styleName, in: language) ?? fallbackFgColor
        textStorage.addAttribute(.foregroundColor, value: fgColor, range: range)

        if let bgHex = language.styleBackgrounds[styleName], let bgColor = colorFromHex(bgHex) {
            textStorage.addAttribute(.backgroundColor, value: bgColor, range: range)
        }

        let fontStyle = language.styleFontStyles[styleName] ?? (defaultItalicForComments ? 2 : 0)
        let fontName = language.styleFontNames[styleName]
        let fontSize = language.styleFontSizes[styleName]

        var targetFont = baseFont
        if let fn = fontName, !fn.isEmpty {
            let size = fontSize.map { CGFloat($0) } ?? baseFont.pointSize
            if let custom = NSFont(name: fn, size: size) {
                targetFont = custom
            }
        } else if let fs = fontSize, CGFloat(fs) != baseFont.pointSize {
            if let sized = NSFont(descriptor: baseFont.fontDescriptor, size: CGFloat(fs)) {
                targetFont = sized
            }
        }

        if (fontStyle & 1) != 0 { // Bold
            targetFont = NSFontManager.shared.convert(targetFont, toHaveTrait: .boldFontMask)
        }
        if (fontStyle & 2) != 0 { // Italic
            targetFont = NSFontManager.shared.convert(targetFont, toHaveTrait: .italicFontMask)
        }
        textStorage.addAttribute(.font, value: targetFont, range: range)

        if (fontStyle & 4) != 0 { // Underline
            textStorage.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
        }
    }

    private static func applyPatternWithUDLStyle(_ pattern: String,
                                                 in string: String,
                                                 styleName: String,
                                                 language: NppUserDefineLanguage,
                                                 textStorage: NSTextStorage,
                                                 fallbackFgColor: NSColor,
                                                 baseFont: NSFont,
                                                 options: NSRegularExpression.Options = [],
                                                 defaultItalicForComments: Bool = false) {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return }
        let matches = regex.matches(in: string, options: [], range: NSRange(location: 0, length: (string as NSString).length))
        for match in matches {
            applyUDLStyle(named: styleName, language: language, range: match.range,
                          textStorage: textStorage, fallbackFgColor: fallbackFgColor,
                          baseFont: baseFont, defaultItalicForComments: defaultItalicForComments)
        }
    }

    private static func applyUserDefinedLanguage(_ language: NppUserDefineLanguage,
                                                 to storage: NSTextStorage, string: String,
                                                 baseFont: NSFont,
                                                 keywordColors: [NSColor], numberColor: NSColor,
                                                 operatorColor: NSColor, commentColor: NSColor) {
        let fullRange = NSRange(location: 0, length: (string as NSString).length)
        guard fullRange.length > 0 else { return }

        // 0. Base DEFAULT Style
        if let defaultFg = udlColor(named: "DEFAULT", in: language) {
            storage.addAttribute(.foregroundColor, value: defaultFg, range: fullRange)
        }
        if let defaultBg = udlBgColor(named: "DEFAULT", in: language) {
            storage.addAttribute(.backgroundColor, value: defaultBg, range: fullRange)
        }
        if let defFs = language.styleFontStyles["DEFAULT"] {
            var defFont = baseFont
            if (defFs & 1) != 0 { defFont = NSFontManager.shared.convert(defFont, toHaveTrait: .boldFontMask) }
            if (defFs & 2) != 0 { defFont = NSFontManager.shared.convert(defFont, toHaveTrait: .italicFontMask) }
            storage.addAttribute(.font, value: defFont, range: fullRange)
            if (defFs & 4) != 0 {
                storage.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: fullRange)
            }
        }

        let options: NSRegularExpression.Options = language.ignoreCase ? [.caseInsensitive] : []

        // 1. Keywords 1..8
        for group in 1...8 {
            let key = "Keywords\(group)"
            let patterns = NppUDLCodec.keywordPatterns(from: language.keywordLists[key] ?? "",
                                                        prefixMode: language.prefixModes[key] == true)
            guard !patterns.isEmpty else { continue }
            let pattern = patterns.joined(separator: "|")
            let fallback = keywordColors[group - 1]
            applyPatternWithUDLStyle(pattern, in: string, styleName: "KEYWORDS\(group)",
                                    language: language, textStorage: storage,
                                    fallbackFgColor: fallback, baseFont: baseFont, options: options)
        }

        // 2. Numbers
        let numericFallback = numberColor
        for pattern in NppUDLCodec.numberPatterns(for: language) {
            applyPatternWithUDLStyle(pattern, in: string, styleName: "NUMBERS",
                                    language: language, textStorage: storage,
                                    fallbackFgColor: numericFallback, baseFont: baseFont)
        }

        // 3. Operators 1
        let operators = (language.keywordLists["Operators1"] ?? "")
            .split(whereSeparator: { $0.isWhitespace }).map(String.init)
        if !operators.isEmpty {
            let pattern = operators.sorted { $0.count > $1.count }
                .map(NSRegularExpression.escapedPattern(for:)).joined(separator: "|")
            applyPatternWithUDLStyle(pattern, in: string, styleName: "OPERATORS",
                                    language: language, textStorage: storage,
                                    fallbackFgColor: operatorColor, baseFont: baseFont)
        }

        // 4. Operators 2
        let backwardOperators = NppUDLCodec.keywordPatterns(
            from: language.keywordLists["Operators2"] ?? "", prefixMode: false
        )
        if !backwardOperators.isEmpty,
           let regex = try? NSRegularExpression(pattern: backwardOperators.joined(separator: "|"), options: options) {
            let source = string as NSString
            for match in regex.matches(in: string, range: NSRange(location: 0, length: source.length)) {
                let before = source.substring(to: match.range.location)
                let after = source.substring(from: NSMaxRange(match.range))
                let leftSeparated = before.isEmpty || before.last?.isWhitespace == true ||
                    operators.contains { before.hasSuffix($0) }
                let rightSeparated = after.isEmpty || after.first?.isWhitespace == true ||
                    operators.contains { after.hasPrefix($0) }
                if leftSeparated && rightSeparated {
                    applyUDLStyle(named: "OPERATORS", language: language, range: match.range,
                                  textStorage: storage, fallbackFgColor: operatorColor, baseFont: baseFont)
                }
            }
        }

        // 5. Delimiters 1..8
        applyUserDefinedDelimiters(language, to: storage, string: string, baseFont: baseFont)

        // 6. Comments (Line & Block)
        let comments = language.keywordLists["Comments"] ?? ""
        let line = NppUDLCodec.commentToken(0, in: comments)
        if !line.isEmpty {
            let escapedLine = NSRegularExpression.escapedPattern(for: line)
            let pattern: String
            switch language.forcePureLC {
            case 1: // Force at beginning of line
                pattern = "^" + escapedLine + ".*$"
            case 2: // Allow preceding whitespace
                pattern = "^[ \\t]*" + escapedLine + ".*$"
            default: // Anywhere
                pattern = escapedLine + ".*$"
            }
            applyPatternWithUDLStyle(pattern, in: string, styleName: "LINE COMMENTS",
                                    language: language, textStorage: storage,
                                    fallbackFgColor: commentColor, baseFont: baseFont,
                                    options: [.anchorsMatchLines], defaultItalicForComments: true)
        }

        let blockOpen = NppUDLCodec.commentToken(3, in: comments)
        let blockClose = NppUDLCodec.commentToken(4, in: comments)
        if !blockOpen.isEmpty, !blockClose.isEmpty {
            let pattern = NSRegularExpression.escapedPattern(for: blockOpen) + "[\\s\\S]*?" +
                NSRegularExpression.escapedPattern(for: blockClose)
            applyPatternWithUDLStyle(pattern, in: string, styleName: "COMMENTS",
                                    language: language, textStorage: storage,
                                    fallbackFgColor: commentColor, baseFont: baseFont,
                                    defaultItalicForComments: true)
        }
    }

    private static func applyUserDefinedDelimiters(_ language: NppUserDefineLanguage,
                                                    to storage: NSTextStorage, string: String, baseFont: NSFont) {
        let source = string as NSString
        let rules = language.keywordLists["Delimiters"] ?? ""
        for group in 1...8 {
            let first = (group - 1) * 3
            let opening = NppUDLCodec.commentToken(first, in: rules)
            let escape = NppUDLCodec.commentToken(first + 1, in: rules)
            let closing = NppUDLCodec.commentToken(first + 2, in: rules)
            guard !opening.isEmpty, !closing.isEmpty else { continue }
            var position = 0
            while position < source.length {
                let openRange = source.range(of: opening, range: NSRange(location: position,
                                                length: source.length - position))
                guard openRange.location != NSNotFound else { break }
                let contentStart = NSMaxRange(openRange)
                var end = source.length
                if closing == "((EOL))" {
                    let newline = source.rangeOfCharacter(from: .newlines,
                        range: NSRange(location: contentStart, length: source.length - contentStart))
                    if newline.location != NSNotFound { end = newline.location }
                } else {
                    var search = contentStart
                    while search < source.length {
                        let closeRange = source.range(of: closing,
                            range: NSRange(location: search, length: source.length - search))
                        guard closeRange.location != NSNotFound else { break }
                        if !escape.isEmpty, closeRange.location >= (escape as NSString).length {
                            var escapeCount = 0
                            var before = closeRange.location
                            while before >= (escape as NSString).length {
                                let candidate = NSRange(location: before - (escape as NSString).length,
                                                        length: (escape as NSString).length)
                                guard source.substring(with: candidate) == escape else { break }
                                escapeCount += 1
                                before -= (escape as NSString).length
                            }
                            if escapeCount % 2 == 1 {
                                search = NSMaxRange(closeRange)
                                continue
                            }
                        }
                        end = NSMaxRange(closeRange)
                        break
                    }
                }
                if end > openRange.location {
                    let delimRange = NSRange(location: openRange.location, length: end - openRange.location)
                    applyUDLStyle(named: "DELIMITERS\(group)", language: language, range: delimRange,
                                  textStorage: storage, fallbackFgColor: NSColor.systemOrange, baseFont: baseFont)
                }
                position = max(end, contentStart)
            }
        }
    }

    private static func colorFromHex(_ hex: String) -> NSColor? {
        let clean = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard clean.count == 6, let value = Int(clean, radix: 16) else { return nil }
        return NSColor(calibratedRed: CGFloat((value >> 16) & 0xFF) / 255.0,
                       green: CGFloat((value >> 8) & 0xFF) / 255.0,
                       blue: CGFloat(value & 0xFF) / 255.0, alpha: 1.0)
    }

    private static func udlColor(named name: String, in language: NppUserDefineLanguage) -> NSColor? {
        guard let hex = language.styleForegrounds[name] else { return nil }
        return colorFromHex(hex)
    }

    private static func udlBgColor(named name: String, in language: NppUserDefineLanguage) -> NSColor? {
        guard let hex = language.styleBackgrounds[name] else { return nil }
        return colorFromHex(hex)
    }

    private static func collectRanges(_ pattern: String, in string: String, options: NSRegularExpression.Options, into ranges: inout [NSRange]) {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return }
        let matches = regex.matches(in: string, options: [], range: NSRange(location: 0, length: (string as NSString).length))
        for m in matches {
            ranges.append(m.range)
        }
    }
}
