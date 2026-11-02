import Foundation
import AppKit

public enum NppProjectNodeType: Int, Codable {
    case workspace = 0
    case project = 1
    case folder = 2
    case file = 3
}

public final class NppProjectElement: Identifiable, ObservableObject, Equatable {
    public let id: UUID
    public var type: NppProjectNodeType
    public var name: String
    public var filePath: String?
    public var relativePath: String?
    public var isMissing: Bool = false
    public var children: [NppProjectElement] = []
    public weak var parent: NppProjectElement?

    public init(
        id: UUID = UUID(),
        type: NppProjectNodeType,
        name: String,
        filePath: String? = nil,
        relativePath: String? = nil,
        isMissing: Bool = false,
        children: [NppProjectElement] = [],
        parent: NppProjectElement? = nil
    ) {
        self.id = id
        self.type = type
        self.name = name
        self.filePath = filePath
        self.relativePath = relativePath
        self.isMissing = isMissing
        self.children = children
        self.parent = parent
        for child in children {
            child.parent = self
        }
    }

    public static func == (lhs: NppProjectElement, rhs: NppProjectElement) -> Bool {
        lhs.id == rhs.id
    }
}

public final class NppProjectWorkspace: ObservableObject {
    public let panelIndex: Int
    @Published public var rootNode: NppProjectElement
    @Published public var filePath: URL?
    @Published public var isDirty: Bool = false

    public init(panelIndex: Int = 1) {
        self.panelIndex = panelIndex
        self.rootNode = NppProjectElement(type: .workspace, name: "Workspace")
        self.filePath = nil
        self.isDirty = false
    }

    public var displayName: String {
        if let path = filePath {
            return path.lastPathComponent
        }
        return rootNode.name
    }

    public func newWorkspace() {
        self.rootNode = NppProjectElement(type: .workspace, name: "Workspace")
        self.filePath = nil
        self.isDirty = false
    }

    @discardableResult
    public func addProject(name: String = "Project Name") -> NppProjectElement {
        let proj = NppProjectElement(type: .project, name: name, parent: rootNode)
        rootNode.children.append(proj)
        isDirty = true
        return proj
    }

    @discardableResult
    public func addFolder(parent: NppProjectElement, name: String = "Folder Name") -> NppProjectElement {
        let folder = NppProjectElement(type: .folder, name: name, parent: parent)
        parent.children.append(folder)
        isDirty = true
        return folder
    }

    @discardableResult
    public func addFile(parent: NppProjectElement, fileUrl: URL) -> NppProjectElement {
        let filename = fileUrl.lastPathComponent
        let fullPath = fileUrl.standardizedFileURL.path
        let exists = FileManager.default.fileExists(atPath: fullPath)
        let fileElem = NppProjectElement(
            type: .file,
            name: filename,
            filePath: fullPath,
            isMissing: !exists,
            parent: parent
        )
        parent.children.append(fileElem)
        isDirty = true
        return fileElem
    }

    @discardableResult
    public func moveNode(_ node: NppProjectElement, up: Bool) -> Bool {
        guard let p = node.parent ?? findParent(of: node, in: rootNode) else { return false }
        guard let idx = p.children.firstIndex(where: { $0.id == node.id }) else { return false }

        if up {
            if idx == 0 { return false }
            p.children.swapAt(idx, idx - 1)
            isDirty = true
            return true
        } else {
            if idx >= p.children.count - 1 { return false }
            p.children.swapAt(idx, idx + 1)
            isDirty = true
            return true
        }
    }

    public func renameNode(_ node: NppProjectElement, to newName: String) {
        node.name = newName
        if node.type == .file, let oldPath = node.filePath {
            let parentDir = (oldPath as NSString).deletingLastPathComponent
            let newPath = (parentDir as NSString).appendingPathComponent(newName)
            node.filePath = newPath
            node.isMissing = !FileManager.default.fileExists(atPath: newPath)
        }
        isDirty = true
    }

    public func modifyFilePath(node: NppProjectElement, newUrl: URL) {
        node.name = newUrl.lastPathComponent
        node.filePath = newUrl.standardizedFileURL.path
        node.isMissing = !FileManager.default.fileExists(atPath: node.filePath!)
        isDirty = true
    }

    public func removeNode(_ node: NppProjectElement) {
        guard let p = node.parent ?? findParent(of: node, in: rootNode) else { return }
        p.children.removeAll(where: { $0.id == node.id })
        isDirty = true
    }

    public func addFilesFromDirectory(parent: NppProjectElement, dirUrl: URL) {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: dirUrl,
            includingPropertiesForKeys: [.isDirectoryKey, .isHiddenKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        var folderMap: [String: NppProjectElement] = [dirUrl.standardizedFileURL.path: parent]

        for case let fileUrl as URL in enumerator {
            let path = fileUrl.standardizedFileURL.path
            let parentPath = fileUrl.deletingLastPathComponent().standardizedFileURL.path
            let parentElem = folderMap[parentPath] ?? parent

            var isDir: AnyObject?
            try? (fileUrl as NSURL).getResourceValue(&isDir, forKey: .isDirectoryKey)
            if let isDir = isDir as? Bool, isDir {
                let folder = addFolder(parent: parentElem, name: fileUrl.lastPathComponent)
                folderMap[path] = folder
            } else {
                _ = addFile(parent: parentElem, fileUrl: fileUrl)
            }
        }
        isDirty = true
    }

    public func findParent(of target: NppProjectElement, in current: NppProjectElement) -> NppProjectElement? {
        for child in current.children {
            if child.id == target.id {
                return current
            }
            if let found = findParent(of: target, in: child) {
                return found
            }
        }
        return nil
    }

    public func enumAllNodes(from start: NppProjectElement? = nil) -> [NppProjectElement] {
        let base = start ?? rootNode
        var result: [NppProjectElement] = []
        for child in base.children {
            result.append(child)
            result.append(contentsOf: enumAllNodes(from: child))
        }
        return result
    }

    public func enumAllFiles(from start: NppProjectElement? = nil) -> [NppProjectElement] {
        return enumAllNodes(from: start).filter { $0.type == .file }
    }

    // MARK: - XML Serialization & Deserialization (.npp_project)

    public func exportToXml() throws -> String {
        let wsDir = filePath?.deletingLastPathComponent().standardizedFileURL.path

        var xml = "<?xml version=\"1.0\" encoding=\"UTF-8\" ?>\n<NotepadPlus>\n"
        for proj in rootNode.children where proj.type == .project {
            xml += "    <Project name=\"\(escapeXml(proj.name))\">\n"
            xml += serializeChildren(children: proj.children, wsDir: wsDir, indent: "        ")
            xml += "    </Project>\n"
        }
        xml += "</NotepadPlus>\n"
        return xml
    }

    private func serializeChildren(children: [NppProjectElement], wsDir: String?, indent: String) -> String {
        var result = ""
        for child in children {
            switch child.type {
            case .folder:
                result += "\(indent)<Folder name=\"\(escapeXml(child.name))\">\n"
                result += serializeChildren(children: child.children, wsDir: wsDir, indent: indent + "    ")
                result += "\(indent)</Folder>\n"
            case .file:
                let pathAttr: String
                if let fp = child.filePath {
                    if let wsDir = wsDir, fp.hasPrefix(wsDir + "/") {
                        pathAttr = String(fp.dropFirst(wsDir.count + 1))
                    } else {
                        pathAttr = fp
                    }
                } else {
                    pathAttr = child.name
                }
                result += "\(indent)<File name=\"\(escapeXml(pathAttr))\" />\n"
            default:
                break
            }
        }
        return result
    }

    public func saveWorkspace(to destinationUrl: URL) throws {
        self.filePath = destinationUrl
        let xml = try exportToXml()
        try xml.write(to: destinationUrl, atomically: true, encoding: .utf8)
        self.isDirty = false
    }

    public func loadWorkspace(from sourceUrl: URL) throws {
        let data = try Data(contentsOf: sourceUrl)
        let doc = try XMLDocument(data: data, options: [])

        guard let root = doc.rootElement(), root.name == "NotepadPlus" else {
            throw NSError(domain: "NppProjectWorkspace", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid root XML tag. Expected <NotepadPlus>"])
        }

        let newRoot = NppProjectElement(type: .workspace, name: "Workspace")
        let wsDir = sourceUrl.deletingLastPathComponent().standardizedFileURL.path

        if let children = root.children as? [XMLElement] {
            for projElem in children where projElem.name == "Project" {
                let projName = projElem.attribute(forName: "name")?.stringValue ?? "Project"
                let proj = NppProjectElement(type: .project, name: projName, parent: newRoot)
                newRoot.children.append(proj)
                parseChildren(from: projElem, parent: proj, wsDir: wsDir)
            }
        }

        self.rootNode = newRoot
        self.filePath = sourceUrl
        self.isDirty = false
    }

    private func parseChildren(from xmlElement: XMLElement, parent: NppProjectElement, wsDir: String) {
        guard let elements = xmlElement.children as? [XMLElement] else { return }
        for elem in elements {
            if elem.name == "Folder" {
                let folderName = elem.attribute(forName: "name")?.stringValue ?? "Folder"
                let folder = NppProjectElement(type: .folder, name: folderName, parent: parent)
                parent.children.append(folder)
                parseChildren(from: elem, parent: folder, wsDir: wsDir)
            } else if elem.name == "File" {
                let nameAttr = elem.attribute(forName: "name")?.stringValue ?? ""
                let resolvedPath: String
                if nameAttr.hasPrefix("/") {
                    resolvedPath = nameAttr
                } else {
                    resolvedPath = (wsDir as NSString).appendingPathComponent(nameAttr)
                }
                let filename = (nameAttr as NSString).lastPathComponent
                let exists = FileManager.default.fileExists(atPath: resolvedPath)
                let fileNode = NppProjectElement(
                    type: .file,
                    name: filename,
                    filePath: resolvedPath,
                    relativePath: nameAttr,
                    isMissing: !exists,
                    parent: parent
                )
                parent.children.append(fileNode)
            }
        }
    }

    private func escapeXml(_ string: String) -> String {
        return string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}
