import AppKit
import SwiftUI

public final class NppFindCharsInRangeWindowController: NSObject, NSWindowDelegate {
    public static let shared = NppFindCharsInRangeWindowController()

    public private(set) var panel: NSPanel?
    private weak var workspace: NppWorkspace?

    private override init() {
        super.init()
    }

    public func show(workspace: NppWorkspace) {
        self.workspace = workspace

        if let existing = panel {
            updateTitle()
            existing.makeKeyAndOrderFront(nil)
            return
        }

        let newPanel = NSPanel(
            contentRect: NSRect(x: 200, y: 300, width: 400, height: 180),
            styleMask: [.titled, .closable, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        newPanel.isFloatingPanel = true
        newPanel.level = .floating
        newPanel.hidesOnDeactivate = true
        newPanel.isReleasedWhenClosed = false
        newPanel.delegate = self

        let isPresentedBinding = Binding<Bool>(
            get: { [weak workspace] in workspace?.showFindCharsInRangeDialog ?? false },
            set: { [weak workspace] val in
                workspace?.showFindCharsInRangeDialog = val
                if !val {
                    NppFindCharsInRangeWindowController.shared.close()
                }
            }
        )

        let hostingView = NSHostingView(
            rootView: NppFindCharsInRangeDialogView(workspace: workspace, isPresented: isPresentedBinding)
        )
        newPanel.contentView = hostingView
        newPanel.title = workspace.tr("Find Characters in Range...")

        self.panel = newPanel

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMainWindowMiniaturize(_:)),
            name: NSWindow.didMiniaturizeNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMainWindowDeminiaturize(_:)),
            name: NSWindow.didDeminiaturizeNotification,
            object: nil
        )

        newPanel.center()
        newPanel.makeKeyAndOrderFront(nil)
    }

    public func close() {
        panel?.orderOut(nil)
        panel = nil
        NotificationCenter.default.removeObserver(self)
    }

    public func updateTitle() {
        guard let panel = panel, let ws = workspace else { return }
        panel.title = ws.tr("Find Characters in Range...")
    }

    public func windowWillClose(_ notification: Notification) {
        workspace?.showFindCharsInRangeDialog = false
        panel = nil
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func handleMainWindowMiniaturize(_ notification: Notification) {
        if let win = notification.object as? NSWindow, win != panel {
            panel?.orderOut(nil)
        }
    }

    @objc private func handleMainWindowDeminiaturize(_ notification: Notification) {
        if let win = notification.object as? NSWindow, win != panel {
            if workspace?.showFindCharsInRangeDialog == true {
                panel?.makeKeyAndOrderFront(nil)
            }
        }
    }
}
