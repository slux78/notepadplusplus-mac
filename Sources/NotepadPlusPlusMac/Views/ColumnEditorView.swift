import SwiftUI
import AppKit

/// 1:1 port of Notepad++ Column / Multi-Selection Editor (`IDD_COLUMNEDIT` in `columnEditor.rc` & `ColumnEditor.cpp`).
public struct NppColumnEditorView: View {
    @ObservedObject var workspace: NppWorkspace
    @Binding var isPresented: Bool

    @State private var mode: Int = 0 // 0: Text to Insert (IDC_COL_TEXT_RADIO), 1: Number to Insert (IDC_COL_NUM_RADIO)
    @State private var insertText: String = ""

    @State private var initialNumber: String = "1"
    @State private var increaseBy: String = "1"
    @State private var repeatCount: String = "1"
    @State private var leadingOption: String = "None" // "None", "Zeros", "Spaces" (IDC_COL_LEAD_COMBO)
    @State private var numberFormat: String = "Dec"   // "Dec", "Hex", "Oct", "Bin"
    @State private var hexCase: String = "a-f"        // "a-f", "A-F" (IDC_COL_HEX_COMBO)

    let leadingOptions = ["None", "Zeros", "Spaces"]
    let formats = ["Dec", "Hex", "Oct", "Bin"]
    let hexCases = ["a-f", "A-F"]

    public init(workspace: NppWorkspace, isPresented: Binding<Bool>) {
        self.workspace = workspace
        self._isPresented = isPresented
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header (`IDD_COLUMNEDIT`: "Column / Multi-Selection Editor")
            HStack {
                Text(workspace.tr("Column / Multi-Selection Editor"))
                    .font(.system(size: 13, weight: .semibold))
                    .fixedSize()
                Spacer()
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 14))
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                // Choice 1: Text to Insert (`IDC_COL_TEXT_RADIO` + `IDC_COL_TEXT_GRP_STATIC`)
                GroupBox(label:
                    Button(action: { mode = 0 }) {
                        HStack(spacing: 5) {
                            Image(systemName: mode == 0 ? "largecircle.fill.circle" : "circle")
                                .foregroundColor(mode == 0 ? .accentColor : .secondary)
                                .font(.system(size: 12))
                            Text(workspace.tr("Text to Insert"))
                                .font(.system(size: 11, weight: .semibold))
                                .fixedSize()
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                ) {
                    HStack {
                        TextField("", text: $insertText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .font(.system(size: 12, design: .monospaced))
                            .disabled(mode != 0)
                    }
                    .padding(6)
                }

                // Choice 2: Number to Insert (`IDC_COL_NUM_RADIO` + `IDC_COL_NUM_GRP_STATIC`)
                GroupBox(label:
                    Button(action: { mode = 1 }) {
                        HStack(spacing: 5) {
                            Image(systemName: mode == 1 ? "largecircle.fill.circle" : "circle")
                                .foregroundColor(mode == 1 ? .accentColor : .secondary)
                                .font(.system(size: 12))
                            Text(workspace.tr("Number to Insert"))
                                .font(.system(size: 11, weight: .semibold))
                                .fixedSize()
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                ) {
                    HStack(alignment: .top, spacing: 14) {
                        // Left column: Initial number, Increase by, Repeat, Leading
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 6) {
                                Text(workspace.tr("Initial number :"))
                                    .font(.system(size: 11))
                                    .fixedSize()
                                    .frame(width: 95, alignment: .trailing)
                                TextField("", text: $initialNumber)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .frame(width: 85)
                                    .disabled(mode != 1)
                            }

                            HStack(spacing: 6) {
                                Text(workspace.tr("Increase by :"))
                                    .font(.system(size: 11))
                                    .fixedSize()
                                    .frame(width: 95, alignment: .trailing)
                                TextField("", text: $increaseBy)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .frame(width: 85)
                                    .disabled(mode != 1)
                            }

                            HStack(spacing: 6) {
                                Text(workspace.tr("Repeat :"))
                                    .font(.system(size: 11))
                                    .fixedSize()
                                    .frame(width: 95, alignment: .trailing)
                                TextField("", text: $repeatCount)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .frame(width: 85)
                                    .disabled(mode != 1)
                            }

                            HStack(spacing: 6) {
                                Text(workspace.tr("Leading :"))
                                    .font(.system(size: 11))
                                    .fixedSize()
                                    .frame(width: 95, alignment: .trailing)
                                Picker("", selection: $leadingOption) {
                                    ForEach(leadingOptions, id: \.self) { opt in
                                        Text(workspace.tr(opt)).tag(opt)
                                    }
                                }
                                .labelsHidden()
                                .frame(width: 85)
                                .disabled(mode != 1)
                            }
                        }

                        // Right column: Format GroupBox (`IDC_COL_FORMAT_GRP_STATIC`: Dec, Hex, Oct, Bin)
                        GroupBox(label: Text(workspace.tr("Format")).font(.system(size: 11, weight: .semibold)).fixedSize()) {
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(formats, id: \.self) { fmt in
                                    HStack(spacing: 6) {
                                        Button(action: {
                                            if mode == 1 { numberFormat = fmt }
                                        }) {
                                            HStack(spacing: 5) {
                                                Image(systemName: numberFormat == fmt ? "largecircle.fill.circle" : "circle")
                                                    .foregroundColor(mode == 1 && numberFormat == fmt ? .accentColor : .secondary)
                                                    .font(.system(size: 11))
                                                Text(workspace.tr(fmt))
                                                    .font(.system(size: 11))
                                                    .fixedSize()
                                            }
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                        .disabled(mode != 1)

                                        if fmt == "Hex" {
                                            Picker("", selection: $hexCase) {
                                                ForEach(hexCases, id: \.self) { c in
                                                    Text(c).tag(c)
                                                }
                                            }
                                            .labelsHidden()
                                            .frame(width: 62)
                                            .disabled(mode != 1 || numberFormat != "Hex")
                                        }
                                    }
                                }
                            }
                            .padding(6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(width: 155)
                    }
                    .padding(8)
                }
            }
            .padding(14)

            Divider()

            // Footer Buttons (`IDOK`, `IDCANCEL`)
            HStack(spacing: 12) {
                Spacer()
                Button(workspace.tr("OK")) {
                    applyColumnEdit()
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
                .frame(minWidth: 75)

                Button(workspace.tr("Cancel")) {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)
                .frame(minWidth: 75)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(width: 410, height: 350)
        .background(Color(NSColor.controlBackgroundColor))
    }

    private func applyColumnEdit() {
        let isText = (mode == 0)
        let radix: Int
        switch numberFormat {
        case "Hex": radix = 16
        case "Oct": radix = 8
        case "Bin": radix = 2
        default: radix = 10
        }
        let initNum = Int(initialNumber.trimmingCharacters(in: .whitespaces), radix: radix) ?? 1
        let inc = Int(increaseBy.trimmingCharacters(in: .whitespaces), radix: radix) ?? (increaseBy.isEmpty ? 1 : 0)
        let rep = Int(repeatCount.trimmingCharacters(in: .whitespaces)) ?? 1
        let fmt = (numberFormat == "Hex" && hexCase == "a-f") ? "hex_lower" : numberFormat
        workspace.executeColumnEditor(
            isText: isText,
            text: insertText,
            initialNumber: initNum,
            increaseBy: inc,
            repeatCount: rep,
            format: fmt,
            leadingZeros: (leadingOption == "Zeros"),
            leadingSpaces: (leadingOption == "Spaces")
        )
    }
}
