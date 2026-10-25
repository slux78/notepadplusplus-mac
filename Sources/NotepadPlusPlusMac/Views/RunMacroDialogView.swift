import SwiftUI
import AppKit

// MARK: - Authentic Notepad++ Run a Macro Multiple Times Dialog (matching upstream RunMacroDlg.rc IDD_RUN_MACRO_DLG & RunMacroDlg.cpp)
public struct NppRunMacroDialogView: View {
    @ObservedObject var workspace: NppWorkspace
    @Binding var isPresented: Bool

    @State private var runMode: Int = 0 // 0: Run N times (IDC_M_RUN_MULTI), 1: Run until the end of file (IDC_M_RUN_EOF)
    @State private var runTimesText: String = "1"

    public init(workspace: NppWorkspace, isPresented: Binding<Bool>) {
        self.workspace = workspace
        self._isPresented = isPresented
    }

    public var availableMacros: [String] {
        workspace.availableMacros
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Dialog Title Header (CAPTION "Run a Macro Multiple Times")
            HStack {
                Text(workspace.tr("Run a Macro Multiple Times"))
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

            VStack(alignment: .leading, spacing: 14) {
                // GROUPBOX "&Macro to run", IDC_MACRO2RUN_STATIC (RunMacroDlg.rc lines 28-29)
                NppGroupBox(workspace.tr("Macro to run")) {
                    HStack {
                        Picker("", selection: $workspace.selectedMacroToRun) {
                            ForEach(workspace.availableMacros, id: \.self) { name in
                                Text(workspace.tr(name)).tag(name)
                            }
                        }
                        .labelsHidden()
                        .frame(maxWidth: .infinity)
                    }
                }

                // Radio Controls: IDC_M_RUN_MULTI + IDC_M_RUN_TIMES + IDC_TIMES_STATIC & IDC_M_RUN_EOF (RunMacroDlg.rc lines 31-36)
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        NppRadioButton(
                            title: workspace.tr("Run"),
                            value: 0,
                            selection: $runMode
                        )
                        .fixedSize()

                        TextField("1", text: $runTimesText)
                            .font(.system(size: 12, design: .monospaced))
                            .multilineTextAlignment(.center)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 56)
                            .disabled(runMode != 0)
                            .onChange(of: runTimesText) { newValue in
                                let filtered = newValue.filter { $0.isNumber }
                                if filtered != newValue {
                                    runTimesText = String(filtered.prefix(4))
                                } else if filtered.count > 4 {
                                    runTimesText = String(filtered.prefix(4))
                                }
                            }

                        Text(workspace.tr("times"))
                            .font(.system(size: 11))
                            .foregroundColor(runMode == 0 ? .primary : .secondary)
                            .fixedSize()
                    }

                    NppRadioButton(
                        title: workspace.tr("Run until the end of file"),
                        value: 1,
                        selection: $runMode
                    )
                    .fixedSize()
                }
                .padding(.horizontal, 6)
            }
            .padding(14)

            Divider()

            // DEFPUSHBUTTON "&Run", IDOK / PUSHBUTTON "&Cancel", IDCANCEL (RunMacroDlg.rc lines 38-39)
            HStack(spacing: 10) {
                Spacer()
                Button(workspace.tr("Run")) {
                    let count = max(1, Int(runTimesText) ?? 1)
                    runTimesText = "\(count)"
                    workspace.executeMultiMacro(
                        macroName: workspace.selectedMacroToRun,
                        runUntilEOF: (runMode == 1),
                        times: count
                    )
                    isPresented = false
                }
                .frame(minWidth: 75)
                .disabled(availableMacros.isEmpty)
                .keyboardShortcut(.defaultAction)

                Button(workspace.tr("Cancel")) {
                    isPresented = false
                }
                .frame(minWidth: 75)
                .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(width: 340, height: 225)
        .background(Color(NSColor.windowBackgroundColor))
        .preferredColorScheme(workspace.currentTheme.isDark ? .dark : .light)
        .onAppear {
            workspace.ensureValidSelectedMacro()
        }
    }
}
