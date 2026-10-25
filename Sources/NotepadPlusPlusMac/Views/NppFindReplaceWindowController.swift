import AppKit
import SwiftUI

public final class NppFindReplaceWindowController: NSObject, NSWindowDelegate {
    public static let shared = NppFindReplaceWindowController()

    public private(set) var panel: NSPanel?
    private weak var workspace: NppWorkspace?

    private override init() {
        super.init()
    }

    public func show(workspace: NppWorkspace) {
        self.workspace = workspace

        if let existing = panel {
            updateTitle()
            updateTransparency()
            existing.makeKeyAndOrderFront(nil)
            DispatchQueue.main.async {
                existing.selectNextKeyView(nil)
                if let editor = existing.fieldEditor(false, for: nil) as? NSTextView {
                    editor.selectAll(nil)
                }
            }
            return
        }

        let newPanel = NSPanel(
            contentRect: NSRect(x: 150, y: 200, width: 730, height: 360),
            styleMask: [.titled, .closable, .resizable, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        newPanel.isFloatingPanel = true
        newPanel.level = .floating
        newPanel.hidesOnDeactivate = true
        newPanel.isReleasedWhenClosed = false
        newPanel.delegate = self

        let isPresentedBinding = Binding<Bool>(
            get: { [weak workspace] in workspace?.showFindReplaceDialog ?? false },
            set: { [weak workspace] val in
                workspace?.showFindReplaceDialog = val
                if !val {
                    NppFindReplaceWindowController.shared.close()
                }
            }
        )

        let hostingView = NSHostingView(rootView: NppFindReplaceDialogView(workspace: workspace, isPresented: isPresentedBinding))
        newPanel.contentView = hostingView
        newPanel.minSize = NSSize(width: 730, height: 360)

        self.panel = newPanel
        updateTitle()
        updateTransparency()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleWindowDidResignKey(_:)),
            name: NSWindow.didResignKeyNotification,
            object: newPanel
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleWindowDidBecomeKey(_:)),
            name: NSWindow.didBecomeKeyNotification,
            object: newPanel
        )
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
        switch ws.findReplaceTab {
        case 0: panel.title = ws.tr("Find")
        case 1: panel.title = ws.tr("Replace")
        case 2: panel.title = ws.tr("Find in Files")
        case 3: panel.title = ws.tr("Mark")
        default: panel.title = ws.tr("Find")
        }
    }

    public func updateTransparency(isKeyOverride: Bool? = nil) {
        guard let panel = panel, let ws = workspace else { return }
        let isKey = isKeyOverride ?? panel.isKeyWindow

        if !ws.findTransparencyEnabled {
            panel.animator().alphaValue = 1.0
            return
        }

        if ws.findTransparencyMode == 1 {
            // Always semi-transparent
            let alpha = CGFloat(max(0.15, min(1.0, ws.findTransparencyValue)))
            panel.animator().alphaValue = alpha
        } else {
            // On losing focus: opaque if key, semi-transparent if not key
            let alpha: CGFloat = isKey ? 1.0 : CGFloat(max(0.15, min(1.0, ws.findTransparencyValue)))
            panel.animator().alphaValue = alpha
        }
    }

    @objc private func handleWindowDidResignKey(_ notification: Notification) {
        updateTransparency(isKeyOverride: false)
    }

    @objc private func handleWindowDidBecomeKey(_ notification: Notification) {
        updateTransparency(isKeyOverride: true)
    }

    @objc private func handleMainWindowMiniaturize(_ notification: Notification) {
        if let win = notification.object as? NSWindow, !(win is NSPanel) {
            panel?.orderOut(nil)
        }
    }

    @objc private func handleMainWindowDeminiaturize(_ notification: Notification) {
        if let win = notification.object as? NSWindow, !(win is NSPanel), let ws = workspace, ws.showFindReplaceDialog {
            panel?.orderFront(nil)
        }
    }

    public func windowWillResize(_ sender: NSWindow, to frameSize: NSSize) -> NSSize {
        return NSSize(width: max(frameSize.width, 730), height: max(frameSize.height, 360))
    }

    public func windowWillClose(_ notification: Notification) {
        if let ws = workspace, ws.showFindReplaceDialog {
            ws.showFindReplaceDialog = false
        }
    }
}
