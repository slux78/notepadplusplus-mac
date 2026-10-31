import Foundation

/// Reads and writes Notepad++ UserLang XML while retaining rules the Mac editor does not yet expose.
public enum NppUDLCodec {
    public enum CodecError: Error { case invalidDocument, noLanguages }

    public static func decode(_ data: Data) throws -> [NppUserDefineLanguage] {
        let document = try XMLDocument(data: data)
        guard let root = document.rootElement() else { throw CodecError.invalidDocument }
        let elements = root.name == "UserLang" ? [root] : root.elements(forName: "UserLang")
        guard !elements.isEmpty else { throw CodecError.noLanguages }
        return elements.compactMap { element in
            guard let name = element.attribute(forName: "name")?.stringValue, !name.isEmpty else { return nil }
            let global = element.elements(forName: "Settings").first?.elements(forName: "Global").first
            let prefix = element.elements(forName: "Settings").first?.elements(forName: "Prefix").first
            var keywords: [String: String] = [:]
            var prefixModes: [String: Bool] = [:]
            var styles: [String: String] = [:]
            if let lists = element.elements(forName: "KeywordLists").first {
                for entry in lists.elements(forName: "Keywords") {
                    if let key = entry.attribute(forName: "name")?.stringValue {
                        keywords[key] = entry.stringValue ?? ""
                    }
                }
            }
            for group in 1...8 {
                let key = "Keywords\(group)"
                prefixModes[key] = prefix?.attribute(forName: key)?.stringValue == "yes"
            }
            if let styleList = element.elements(forName: "Styles").first {
                for entry in styleList.elements(forName: "WordsStyle") {
                    if let key = entry.attribute(forName: "name")?.stringValue,
                       let color = entry.attribute(forName: "fgColor")?.stringValue {
                        styles[key] = color
                    }
                }
            }
            return NppUserDefineLanguage(
                name: name,
                extensions: element.attribute(forName: "ext")?.stringValue ?? "",
                ignoreCase: global?.attribute(forName: "caseIgnored")?.stringValue == "yes",
                keywordLists: keywords,
                prefixModes: prefixModes,
                decimalSeparator: Int(global?.attribute(forName: "decimalSeparator")?.stringValue ?? "0") ?? 0,
                styleForegrounds: styles,
                sourceXML: element.xmlString
            )
        }
    }

    public static func encode(_ language: NppUserDefineLanguage) throws -> Data {
        let userLang: XMLElement
        if let source = language.sourceXML,
           let original = try? XMLDocument(data: Data(source.utf8)),
           let element = original.rootElement(), element.name == "UserLang" {
            userLang = element.copy() as! XMLElement
        } else {
            userLang = XMLElement(name: "UserLang")
        }
        setAttribute("name", value: language.name, on: userLang)
        setAttribute("ext", value: language.extensions, on: userLang)
        setAttribute("udlVersion", value: "2.1", on: userLang)

        let settings = child(named: "Settings", in: userLang)
        let global = child(named: "Global", in: settings)
        setAttribute("caseIgnored", value: language.ignoreCase ? "yes" : "no", on: global)
        if global.attribute(forName: "allowFoldOfComments") == nil {
            setAttribute("allowFoldOfComments", value: "no", on: global)
        }
        if global.attribute(forName: "foldCompact") == nil {
            setAttribute("foldCompact", value: "no", on: global)
        }
        if global.attribute(forName: "forcePureLC") == nil {
            setAttribute("forcePureLC", value: "0", on: global)
        }
        setAttribute("decimalSeparator", value: String(language.decimalSeparator), on: global)
        let prefix = child(named: "Prefix", in: settings)
        for group in 1...8 {
            let key = "Keywords\(group)"
            setAttribute(key, value: language.prefixModes[key] == true ? "yes" : "no", on: prefix)
        }
        let lists = child(named: "KeywordLists", in: userLang)
        for (name, value) in language.keywordLists.sorted(by: { $0.key < $1.key }) {
            let entry = lists.elements(forName: "Keywords").first {
                $0.attribute(forName: "name")?.stringValue == name
            } ?? {
                let created = XMLElement(name: "Keywords")
                setAttribute("name", value: name, on: created)
                lists.addChild(created)
                return created
            }()
            entry.stringValue = value
        }
        if userLang.elements(forName: "Styles").isEmpty {
            let styles = XMLElement(name: "Styles")
            let names = ["DEFAULT", "COMMENTS", "LINE COMMENTS", "NUMBERS"] +
                (1...8).map { "KEYWORDS\($0)" } +
                ["OPERATORS", "FOLDER IN CODE1", "FOLDER IN CODE2", "FOLDER IN COMMENT"] +
                (1...8).map { "DELIMITERS\($0)" }
            for name in names {
                let style = XMLElement(name: "WordsStyle")
                setAttribute("name", value: name, on: style)
                let foreground: String
                if name.contains("COMMENT") { foreground = "008000" }
                else if name == "NUMBERS" { foreground = "0080FF" }
                else if name.hasPrefix("KEYWORDS") { foreground = "0000CC" }
                else if name == "OPERATORS" { foreground = "800080" }
                else { foreground = "000000" }
                setAttribute("fgColor", value: foreground, on: style)
                setAttribute("bgColor", value: "FFFFFF", on: style)
                setAttribute("colorStyle", value: "1", on: style)
                setAttribute("fontStyle", value: "0", on: style)
                setAttribute("nesting", value: "0", on: style)
                styles.addChild(style)
            }
            userLang.addChild(styles)
        }
        if let styles = userLang.elements(forName: "Styles").first {
            for entry in styles.elements(forName: "WordsStyle") {
                if let name = entry.attribute(forName: "name")?.stringValue,
                   let color = language.styleForegrounds[name] {
                    setAttribute("fgColor", value: color, on: entry)
                }
            }
        }

        let root = XMLElement(name: "NotepadPlus")
        root.addChild(userLang)
        let document = XMLDocument(rootElement: root)
        document.version = "1.0"
        document.characterEncoding = "UTF-8"
        return document.xmlData(options: [.nodePrettyPrint])
    }

    public static func encode(_ languages: [NppUserDefineLanguage]) throws -> Data {
        let root = XMLElement(name: "NotepadPlus")
        for language in languages {
            let encoded = try encode(language)
            let document = try XMLDocument(data: encoded)
            if let element = document.rootElement()?.elements(forName: "UserLang").first {
                root.addChild(element.copy() as! XMLElement)
            }
        }
        let document = XMLDocument(rootElement: root)
        document.version = "1.0"
        document.characterEncoding = "UTF-8"
        return document.xmlData(options: [.nodePrettyPrint])
    }

    public static func commentToken(_ number: Int, in comments: String) -> String {
        let marker = String(format: "%02d", number)
        let pattern = "(?:^|\\s)" + marker + "([^\\s]*)"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: comments, range: NSRange(location: 0, length: (comments as NSString).length)),
              match.range(at: 1).location != NSNotFound else { return "" }
        return (comments as NSString).substring(with: match.range(at: 1))
    }

    public static func replacingCommentToken(_ number: Int, value: String, in comments: String) -> String {
        let marker = String(format: "%02d", number)
        let pattern = "(^|\\s)" + marker + "[^\\s]*"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return comments }
        let range = NSRange(location: 0, length: (comments as NSString).length)
        if let match = regex.firstMatch(in: comments, range: range) {
            let leading = (comments as NSString).substring(with: match.range(at: 1))
            return (comments as NSString).replacingCharacters(in: match.range, with: leading + marker + value)
        }
        return comments.isEmpty ? marker + value : comments + " " + marker + value
    }

    public static func keywordItems(from list: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: #""[^"]+"|'[^']+'|\S+"#) else { return [] }
        let source = list as NSString
        return regex.matches(in: list, range: NSRange(location: 0, length: source.length)).map { match in
            let item = source.substring(with: match.range)
            return ((item.hasPrefix("\"") && item.hasSuffix("\"")) ||
                    (item.hasPrefix("'") && item.hasSuffix("'")))
                ? String(item.dropFirst().dropLast()) : item
        }
    }

    public static func keywordPatterns(from list: String, prefixMode: Bool) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: #""[^"]+"|'[^']+'|\S+"#) else { return [] }
        let source = list as NSString
        return regex.matches(in: list, range: NSRange(location: 0, length: source.length)).compactMap { match in
            let raw = source.substring(with: match.range)
            let doubleQuoted = raw.hasPrefix("\"") && raw.hasSuffix("\"")
            let singleQuoted = raw.hasPrefix("'") && raw.hasSuffix("'")
            let content = doubleQuoted || singleQuoted ? String(raw.dropFirst().dropLast()) : raw
            let parts = content.split(whereSeparator: { $0.isWhitespace })
            guard !parts.isEmpty else { return nil }
            let separator = doubleQuoted ? #"\s+"# : #"[ \t]+"#
            let core = parts.map { NSRegularExpression.escapedPattern(for: String($0)) }
                .joined(separator: separator)
            let suffix = prefixMode ? #"[\p{L}\p{N}_]*"# : ""
            let ending = prefixMode ? "" : #"(?![\p{L}\p{N}_])"#
            return #"(?<![\p{L}\p{N}_])(?:"# + core + suffix + ")" + ending
        }
    }

    public static func numberPatterns(for language: NppUserDefineLanguage) -> [String] {
        let separator: String
        switch language.decimalSeparator {
        case 1: separator = ","
        case 2: separator = "[.,]"
        default: separator = #"\."#
        }
        let decimal = "[0-9]+(?:" + separator + "[0-9]+)?"
        let digits = "[0-9]+"
        let lists = language.keywordLists
        let extras1 = keywordItems(from: lists["Numbers, extras1"] ?? "")
        let extras2 = keywordItems(from: lists["Numbers, extras2"] ?? "")
        func digitOrExtras(_ extras: [String]) -> String {
            guard !extras.isEmpty else { return digits }
            let choices = extras.map(NSRegularExpression.escapedPattern(for:)).joined(separator: "|")
            return "(?:[0-9]|" + choices + ")+"
        }
        var atoms = [decimal]
        for item in keywordItems(from: lists["Numbers, prefix1"] ?? "") {
            atoms.append(NSRegularExpression.escapedPattern(for: item) + digits)
        }
        for item in keywordItems(from: lists["Numbers, prefix2"] ?? "") {
            atoms.append(NSRegularExpression.escapedPattern(for: item) + digitOrExtras(extras1))
        }
        for item in keywordItems(from: lists["Numbers, suffix1"] ?? "") {
            atoms.append(digitOrExtras(extras2) + NSRegularExpression.escapedPattern(for: item))
        }
        for item in keywordItems(from: lists["Numbers, suffix2"] ?? "") {
            atoms.append(digits + NSRegularExpression.escapedPattern(for: item))
        }
        let boundaryStart = #"(?<![\p{L}\p{N}_])"#
        let boundaryEnd = #"(?![\p{L}\p{N}_])"#
        var patterns = atoms.map { boundaryStart + "(?:" + $0 + ")" + boundaryEnd }
        let atomAlternatives = atoms.joined(separator: "|")
        for symbol in keywordItems(from: lists["Numbers, range"] ?? "") {
            let core = "(?:" + atomAlternatives + ")" +
                NSRegularExpression.escapedPattern(for: symbol) + "(?:" + atomAlternatives + ")"
            patterns.append(boundaryStart + core + boundaryEnd)
        }
        return patterns
    }

    private static func child(named name: String, in parent: XMLElement) -> XMLElement {
        if let existing = parent.elements(forName: name).first { return existing }
        let element = XMLElement(name: name)
        parent.addChild(element)
        return element
    }

    private static func setAttribute(_ name: String, value: String, on element: XMLElement) {
        if let existing = element.attribute(forName: name) {
            existing.stringValue = value
        } else if let attribute = XMLNode.attribute(withName: name, stringValue: value) as? XMLNode {
            element.addAttribute(attribute)
        }
    }
}
