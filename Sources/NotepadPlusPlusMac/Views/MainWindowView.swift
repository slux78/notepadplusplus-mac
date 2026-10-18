import SwiftUI

public struct NppMainWindowView: View {
    @ObservedObject var workspace: NppWorkspace

    public init(workspace: NppWorkspace) {
        self.workspace = workspace
    }

    public var body: some View {
        VStack(spacing: 0) {
            // 1. Toolbar
            NppToolbarView(workspace: workspace)

            // 2. Tab Bar
            NppTabBarView(workspace: workspace)

            // 3. Search Bar (if visible)
            if workspace.showSearchBar {
                NppSearchBarView(workspace: workspace)
            }

            // 4. Editor Area
            if let doc = workspace.activeDocument {
                NppEditorView(document: doc, workspace: workspace)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack {
                    Spacer()
                    Text("No Document Open")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    Button("Create New") {
                        workspace.newDocument()
                    }
                    .padding(.top, 8)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(NSColor.textBackgroundColor))
            }

            // 5. Search Results Panel (Notepad++ Find Result dock)
            if workspace.showSearchResultsPanel && !workspace.searchFileGroups.isEmpty {
                NppSearchResultsView(workspace: workspace)
            }

            // 6. Status Bar
            NppStatusBarView(workspace: workspace)
        }
        .frame(minWidth: 700, minHeight: 450)
    }
}
