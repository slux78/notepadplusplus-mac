import SwiftUI
import AppKit

public struct NppSearchResultsView: View {
    @ObservedObject var workspace: NppWorkspace
    @State private var collapsedGroupIds: Set<UUID> = []
    @State private var selectedMatchId: UUID? = nil
    @State private var selectedGroupId: UUID? = nil

    public init(workspace: NppWorkspace) {
        self.workspace = workspace
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            HStack(spacing: 8) {
                Image(systemName: "list.bullet.rectangle")
                    .foregroundColor(.accentColor)
                    .font(.system(size: 12))

                Text("Search \"\(workspace.lastSearchQuery)\" (\(workspace.totalSearchHits) hits in \(workspace.searchFileGroups.count) files)")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(.primary)

                Spacer()

                Button(workspace.tr("Collapse All")) {
                    collapsedGroupIds = Set(workspace.searchFileGroups.map { $0.id })
                }
                .buttonStyle(PlainButtonStyle())
                .font(.system(size: 11))
                .foregroundColor(.secondary)

                Button(workspace.tr("Expand All")) {
                    collapsedGroupIds.removeAll()
                }
                .buttonStyle(PlainButtonStyle())
                .font(.system(size: 11))
                .foregroundColor(.secondary)

                Divider().frame(height: 12)

                Button(workspace.tr("Clear All")) {
                    workspace.clearSearchResults()
                }
                .buttonStyle(PlainButtonStyle())
                .font(.system(size: 11))
                .foregroundColor(.secondary)

                Button(action: {
                    workspace.showSearchResultsPanel = false
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                        .padding(2)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color(NSColor.controlBackgroundColor))
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Color(NSColor.separatorColor)),
                alignment: .bottom
            )

            // Results List
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(workspace.searchFileGroups) { group in
                        VStack(alignment: .leading, spacing: 1) {
                            // File Group Header
                            HStack(spacing: 4) {
                                Button(action: {
                                    if collapsedGroupIds.contains(group.id) {
                                        collapsedGroupIds.remove(group.id)
                                    } else {
                                        collapsedGroupIds.insert(group.id)
                                    }
                                }) {
                                    Image(systemName: collapsedGroupIds.contains(group.id) ? "chevron.right" : "chevron.down")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(.secondary)
                                        .frame(width: 12, height: 12)
                                }
                                .buttonStyle(PlainButtonStyle())

                                Image(systemName: "doc.text")
                                    .font(.system(size: 11))
                                    .foregroundColor(.blue)

                                Text(group.filePath?.path ?? group.documentTitle)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.primary)

                                Text("(\(group.matches.count) hits)")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(.secondary)

                                Spacer()
                            }
                            .padding(.vertical, 3)
                            .padding(.horizontal, 6)
                            .background(selectedGroupId == group.id ? Color.accentColor.opacity(0.25) : Color(NSColor.selectedControlColor).opacity(0.12))
                            .cornerRadius(3)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedGroupId = group.id
                                selectedMatchId = nil
                            }
                            .contextMenu {
                                Button(workspace.tr("Copy Selected Pathname(s)")) {
                                    workspace.copySelectedSearchPathnames(filePaths: [group.filePath?.path ?? group.documentTitle])
                                }
                                Button(workspace.tr("Open selected pathname(s)")) {
                                    workspace.openSelectedSearchPathname(filePath: group.filePath)
                                }
                                Divider()
                                Button(workspace.tr("Delete")) {
                                    workspace.deleteSearchGroup(groupId: group.id)
                                }
                                Button(workspace.tr("Clear all")) {
                                    workspace.clearSearchResults()
                                }
                            }

                            // Matches inside File
                            if !collapsedGroupIds.contains(group.id) {
                                ForEach(group.matches) { match in
                                    let allMatches = workspace.searchFileGroups.flatMap { $0.matches }
                                    let isCurrentMatch = workspace.currentSearchResultIndex >= 0 &&
                                                         workspace.currentSearchResultIndex < allMatches.count &&
                                                         allMatches[workspace.currentSearchResultIndex].id == match.id

                                    HStack(spacing: 6) {
                                        Text("Line \(match.lineNumber):")
                                            .font(.system(size: 11, design: .monospaced))
                                            .foregroundColor(.secondary)
                                            .frame(width: 65, alignment: .trailing)

                                        HighlightMatchText(
                                            fullText: match.lineContent,
                                            matchRange: match.matchRangeInLine
                                        )
                                        .font(.system(size: 11, design: .monospaced))

                                        Spacer()
                                    }
                                    .padding(.vertical, 2)
                                    .padding(.horizontal, 8)
                                    .background((selectedMatchId == match.id || isCurrentMatch) ? Color.accentColor.opacity(0.25) : Color.clear)
                                    .cornerRadius(2)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        selectedMatchId = match.id
                                        selectedGroupId = nil
                                        workspace.jumpToMatch(match)
                                    }
                                    .contextMenu {
                                        Button(workspace.tr("Copy Selected Line(s)")) {
                                            workspace.copySelectedSearchLines(matches: [match])
                                        }
                                        Button(workspace.tr("Copy Selected Pathname(s)")) {
                                            workspace.copySelectedSearchPathnames(filePaths: [group.filePath?.path ?? group.documentTitle])
                                        }
                                        Button(workspace.tr("Open selected pathname(s)")) {
                                            workspace.openSelectedSearchPathname(filePath: group.filePath, match: match)
                                        }
                                        Divider()
                                        Button(workspace.tr("Delete")) {
                                            workspace.deleteSearchResult(matchId: match.id)
                                        }
                                        Button(workspace.tr("Clear all")) {
                                            workspace.clearSearchResults()
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 4)
                        .padding(.top, 2)
                    }
                }
                .padding(.vertical, 4)
            }
            .frame(height: 180)
            .background(Color(NSColor.textBackgroundColor))
            // Hidden buttons to capture Delete and Backspace keys (searching.md:420-450)
            .background(
                Group {
                    Button(action: {
                        if let mId = selectedMatchId {
                            workspace.deleteSearchResult(matchId: mId)
                            selectedMatchId = nil
                        } else if let gId = selectedGroupId {
                            workspace.deleteSearchGroup(groupId: gId)
                            selectedGroupId = nil
                        }
                    }) {
                        EmptyView()
                    }
                    .keyboardShortcut(.delete, modifiers: [])

                    Button(action: {
                        if let mId = selectedMatchId {
                            workspace.deleteSearchResult(matchId: mId)
                            selectedMatchId = nil
                        } else if let gId = selectedGroupId {
                            workspace.deleteSearchGroup(groupId: gId)
                            selectedGroupId = nil
                        }
                    }) {
                        EmptyView()
                    }
                    .keyboardShortcut(.deleteForward, modifiers: [])
                }
            )
        }
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(NSColor.separatorColor)),
            alignment: .top
        )
    }
}

public struct HighlightMatchText: View {
    let fullText: String
    let matchRange: NSRange

    public var body: some View {
        let ns = fullText as NSString
        if matchRange.location != NSNotFound && NSMaxRange(matchRange) <= ns.length {
            let prefix = ns.substring(with: NSRange(location: 0, length: matchRange.location))
            let match = ns.substring(with: matchRange)
            let suffix = ns.substring(with: NSRange(location: NSMaxRange(matchRange), length: ns.length - NSMaxRange(matchRange)))

            HStack(spacing: 0) {
                Text(prefix).foregroundColor(.primary)
                Text(match)
                    .foregroundColor(.black)
                    .padding(.horizontal, 2)
                    .background(Color.yellow)
                    .cornerRadius(2)
                Text(suffix).foregroundColor(.primary)
            }
        } else {
            Text(fullText).foregroundColor(.primary)
        }
    }
}
