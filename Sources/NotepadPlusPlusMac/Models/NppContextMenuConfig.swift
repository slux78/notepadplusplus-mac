import Foundation
import AppKit

public struct NppContextMenuItem {
    public let id: String?
    public let menuEntryName: String?
    public let menuItemName: String?
    public let folderName: String?
}

public final class NppContextMenuConfig: NSObject, XMLParserDelegate {
    public static let shared = NppContextMenuConfig()

    public static var configURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("Notepad++", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("contextMenu.xml")
    }

    public static let defaultXML = """
    <?xml version="1.0" encoding="UTF-8" ?>
    <NotepadPlus>
        <ScintillaContextMenu>
            <Item id="42020"/> <!-- Cut -->
            <Item id="42021"/> <!-- Copy -->
            <Item id="42022"/> <!-- Paste -->
            <Item id="42023"/> <!-- Delete -->
            <Item id="42024"/> <!-- Select All -->
            <Item id="0"/>     <!-- Separator -->
            <Item MenuEntryName="Edit" MenuItemName="Convert to UPPERCASE" />
            <Item MenuEntryName="Edit" MenuItemName="Convert to lowercase" />
            <Item MenuEntryName="Edit" MenuItemName="Trim Trailing Space" />
            <Item id="0"/>     <!-- Separator -->
            <Item MenuEntryName="Search" MenuItemName="Find..." />
            <Item MenuEntryName="Search" MenuItemName="Replace..." />
            <Item MenuEntryName="Search" MenuItemName="Find All in Current Document" />
            <Item id="0"/>     <!-- Separator -->
            <Item MenuEntryName="Run" MenuItemName="Run in Terminal" />
        </ScintillaContextMenu>
    </NotepadPlus>
    """

    public static func ensureConfigFileExists() -> URL {
        let url = configURL
        if !FileManager.default.fileExists(atPath: url.path) {
            try? defaultXML.write(to: url, atomically: true, encoding: .utf8)
        }
        return url
    }

    private var parsedItems: [NppContextMenuItem] = []

    public func loadItems() -> [NppContextMenuItem] {
        let url = Self.ensureConfigFileExists()
        guard let data = try? Data(contentsOf: url) else {
            return defaultItems()
        }
        parsedItems = []
        let parser = XMLParser(data: data)
        parser.delegate = self
        if parser.parse() && !parsedItems.isEmpty {
            return parsedItems
        }
        return defaultItems()
    }

    private func defaultItems() -> [NppContextMenuItem] {
        return [
            NppContextMenuItem(id: "42020", menuEntryName: nil, menuItemName: nil, folderName: nil),
            NppContextMenuItem(id: "42021", menuEntryName: nil, menuItemName: nil, folderName: nil),
            NppContextMenuItem(id: "42022", menuEntryName: nil, menuItemName: nil, folderName: nil),
            NppContextMenuItem(id: "42023", menuEntryName: nil, menuItemName: nil, folderName: nil),
            NppContextMenuItem(id: "42024", menuEntryName: nil, menuItemName: nil, folderName: nil),
            NppContextMenuItem(id: "0", menuEntryName: nil, menuItemName: nil, folderName: nil),
            NppContextMenuItem(id: nil, menuEntryName: "Edit", menuItemName: "Convert to UPPERCASE", folderName: nil),
            NppContextMenuItem(id: nil, menuEntryName: "Edit", menuItemName: "Convert to lowercase", folderName: nil),
            NppContextMenuItem(id: nil, menuEntryName: "Edit", menuItemName: "Trim Trailing Space", folderName: nil),
            NppContextMenuItem(id: "0", menuEntryName: nil, menuItemName: nil, folderName: nil),
            NppContextMenuItem(id: nil, menuEntryName: "Search", menuItemName: "Find...", folderName: nil),
            NppContextMenuItem(id: nil, menuEntryName: "Search", menuItemName: "Replace...", folderName: nil),
            NppContextMenuItem(id: nil, menuEntryName: "Search", menuItemName: "Find All in Current Document", folderName: nil),
            NppContextMenuItem(id: "0", menuEntryName: nil, menuItemName: nil, folderName: nil),
            NppContextMenuItem(id: nil, menuEntryName: "Run", menuItemName: "Run in Terminal", folderName: nil),
        ]
    }

    // MARK: - XMLParserDelegate
    public func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        if elementName == "Item" {
            let id = attributeDict["id"]
            let menuEntry = attributeDict["MenuEntryName"]
            let menuItem = attributeDict["MenuItemName"]
            let folder = attributeDict["FolderName"]
            parsedItems.append(NppContextMenuItem(id: id, menuEntryName: menuEntry, menuItemName: menuItem, folderName: folder))
        }
    }
}
