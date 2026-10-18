import Foundation
import AppKit

public final class NppWorkspace: ObservableObject {
    @Published public var documents: [NppDocument] = []
    @Published public var activeDocumentId: UUID?

    @Published public var fontSize: CGFloat = 13.0
    @Published public var isWordWrapEnabled: Bool = false
    @Published public var showInvisibleCharacters: Bool = false
    @Published public var showSearchBar: Bool = false

    private var newDocCounter: Int = 1

    public var activeDocument: NppDocument? {
        guard let id = activeDocumentId else { return nil }
        return documents.first(where: { $0.id == id })
    }

    public init() {
        newDocument()
    }

    public func newDocument() {
        let title = "new \(newDocCounter)"
        newDocCounter += 1
        let doc = NppDocument(title: title, content: "", encoding: "UTF-8", hasBOM: false, eol: .crlf)
        documents.append(doc)
        activeDocumentId = doc.id
    }

    public func openFile(url: URL) {
        // If already open, just switch to it
        if let existing = documents.first(where: { $0.filePath == url }) {
            activeDocumentId = existing.id
            return
        }

        do {
            let doc = try NppDocument.fromFile(url: url)
            // If only single untitled document is open and empty, replace it
            if documents.count == 1 && documents[0].filePath == nil && documents[0].content.isEmpty && !documents[0].isDirty {
                documents = [doc]
            } else {
                documents.append(doc)
            }
            activeDocumentId = doc.id
        } catch {
            print("Failed to open file: \(error)")
        }
    }

    public func closeDocument(id: UUID) {
        guard let index = documents.firstIndex(where: { $0.id == id }) else { return }
        documents.remove(at: index)

        if documents.isEmpty {
            newDocument()
        } else if activeDocumentId == id {
            let nextIndex = min(index, documents.count - 1)
            activeDocumentId = documents[nextIndex].id
        }
    }

    public func closeAll() {
        documents.removeAll()
        newDocCounter = 1
        newDocument()
    }

    public func saveActive() {
        guard let doc = activeDocument else { return }
        if doc.filePath != nil {
            _ = doc.save()
        } else {
            promptSaveAs(for: doc)
        }
    }

    public func saveAll() {
        for doc in documents where doc.isDirty {
            if doc.filePath != nil {
                _ = doc.save()
            } else {
                promptSaveAs(for: doc)
            }
        }
    }

    public func promptSaveAs(for doc: NppDocument) {
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = doc.filePath?.lastPathComponent ?? doc.title
        panel.begin { response in
            if response == .OK, let url = panel.url {
                _ = doc.save(to: url)
            }
        }
    }

    public func promptOpenFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.begin { [weak self] response in
            if response == .OK {
                for url in panel.urls {
                    self?.openFile(url: url)
                }
            }
        }
    }

    public func zoomIn() {
        fontSize = min(fontSize + 1.0, 36.0)
    }

    public func zoomOut() {
        fontSize = max(fontSize - 1.0, 8.0)
    }

    public func resetZoom() {
        fontSize = 13.0
    }
}
