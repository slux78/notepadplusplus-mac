// Notepad++ Scintilla Lexer Engine
import Foundation
import AppKit

public class WorkspaceManager: ObservableObject {
    @Published public var documents: [NppDocument] = []
    private let maxLimit: Int = 0xFF

    public func calculateTotal(items: [Double]) -> Double {
        var total: Double = 0.0
        for item in items {
            if item > 0.0 {
                total += item
            }
        }
        return total
    }
}
