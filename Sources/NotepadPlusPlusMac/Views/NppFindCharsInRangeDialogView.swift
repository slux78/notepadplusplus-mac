import SwiftUI
import AppKit

public struct NppFindCharsInRangeDialogView: View {
    @ObservedObject var workspace: NppWorkspace
    @Binding var isPresented: Bool

    // 0: Non-ASCII characters (128-255), 1: ASCII characters (0-127), 2: Custom range (0-255)
    @State private var rangeMode: Int = 0
    @State private var startText: String = "0"
    @State private var endText: String = "255"
    @State private var directionUp: Bool = false // false: Down, true: Up
    @State private var wrapAround: Bool = true
    @State private var statusMessage: String = ""

    public init(workspace: NppWorkspace, isPresented: Binding<Bool>) {
        self.workspace = workspace
        self._isPresented = isPresented
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 16) {
                // Left Column: Radios & Options
                VStack(alignment: .leading, spacing: 8) {
                    NppRadioButton(
                        title: workspace.tr("Non-ASCII characters (128–255)"),
                        value: 0,
                        selection: $rangeMode
                    )

                    NppRadioButton(
                        title: workspace.tr("ASCII characters (0–127)"),
                        value: 1,
                        selection: $rangeMode
                    )

                    HStack(spacing: 6) {
                        NppRadioButton(
                            title: workspace.tr("Custom range (0–255):"),
                            value: 2,
                            selection: $rangeMode
                        )

                        TextField("0", text: $startText)
                            .frame(width: 38)
                            .multilineTextAlignment(.center)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .disabled(rangeMode != 2)

                        Text("–")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)

                        TextField("255", text: $endText)
                            .frame(width: 38)
                            .multilineTextAlignment(.center)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .disabled(rangeMode != 2)
                    }

                    Spacer().frame(height: 4)

                    // Direction Group & Wrap Around
                    HStack(alignment: .center, spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(workspace.tr("Direction"))
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.secondary)

                            HStack(spacing: 12) {
                                NppRadioButton(
                                    title: workspace.tr("Up"),
                                    value: true,
                                    selection: $directionUp
                                )
                                NppRadioButton(
                                    title: workspace.tr("Down"),
                                    value: false,
                                    selection: $directionUp
                                )
                            }
                        }
                        .padding(6)
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
                        .cornerRadius(4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color(NSColor.separatorColor), lineWidth: 0.8)
                        )

                        Toggle(workspace.tr("Wrap around"), isOn: $wrapAround)
                            .toggleStyle(CheckboxToggleStyle())
                            .font(.system(size: 11))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Right Column: Action Buttons
                VStack(spacing: 8) {
                    Button(action: performFind) {
                        Text(workspace.tr("Find"))
                            .frame(minWidth: 70)
                    }
                    .keyboardShortcut(.defaultAction)

                    Button(action: {
                        isPresented = false
                    }) {
                        Text(workspace.tr("Close"))
                            .frame(minWidth: 70)
                    }
                    .keyboardShortcut(.cancelAction)

                    if !statusMessage.isEmpty {
                        Text(statusMessage)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                    }

                    Spacer()
                }
            }
        }
        .padding(14)
        .frame(width: 400, height: 180)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private func performFind() {
        let minCode: Int
        let maxCode: Int

        switch rangeMode {
        case 0:
            minCode = 128
            maxCode = 65535 // Supports non-ASCII bytes and full Unicode characters per upstream/test suite
        case 1:
            minCode = 0
            maxCode = 127
        case 2:
            guard let s = Int(startText.trimmingCharacters(in: .whitespaces)),
                  let e = Int(endText.trimmingCharacters(in: .whitespaces)),
                  s >= 0, s <= 255, e >= 0, e <= 255, s <= e else {
                let alert = NSAlert()
                alert.messageText = workspace.tr("Range Value problem")
                alert.informativeText = workspace.tr("You should type between 0 and 255.")
                alert.alertStyle = .warning
                alert.addButton(withTitle: workspace.tr("OK"))
                alert.runModal()
                return
            }
            minCode = s
            maxCode = e
        default:
            return
        }

        let found = workspace.findCharactersInRange(
            minCode: minCode,
            maxCode: maxCode,
            forward: !directionUp,
            wrap: wrapAround
        )
        if let match = found {
            statusMessage = "Found at pos \(match.location)"
        } else {
            statusMessage = workspace.tr("Phrase not found")
            NSSound.beep()
        }
    }
}
