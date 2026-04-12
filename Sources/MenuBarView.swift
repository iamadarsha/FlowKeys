import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject private var updateManager = UpdateManager.shared

    private let accentColor = Color(red: 1.0, green: 0.42, blue: 0.21) // #FF6B35

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    var body: some View {
        VStack(spacing: 0) {
            headerSection
            Divider()
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 16) {
                    languageModeSection
                    toneModeSection
                    recentSection
                }
                .padding(.vertical, 16)
                .padding(.horizontal, 16)
            }
            .frame(maxHeight: 400)
            
            Divider()
            
            actionsSection
            
            if updateManager.updateAvailable {
                Divider()
                updateSection
            }
        }
        .frame(width: 320)
        .background(Color(red: 12/255, green: 12/255, blue: 14/255)) // #0C0C0E
        .preferredColorScheme(.dark)
    }

    // ─── HEADER ──────────────────────────────────────────────

    private var headerSection: some View {
        VStack(spacing: 12) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "waveform.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(accentColor)
                    Text("FlowKeys")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                }
                
                Spacer()
                
                HStack(spacing: 12) {
                    Button(action: {
                        if let url = URL(string: "https://github.com/iamadarsha/FlowKeys") {
                            NSWorkspace.shared.open(url)
                        }
                    }) {
                        Image(systemName: "questionmark.circle")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                    }.buttonStyle(.plain)
                    
                    Button(action: {
                        NotificationCenter.default.post(name: .showSettings, object: nil)
                    }) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                    }.buttonStyle(.plain)
                }
            }
            
            HStack {
                if !shortcutHint.isEmpty {
                    Text(shortcutHint)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color(red: 32/255, green: 32/255, blue: 31/255)) // #20201F
                        .cornerRadius(4)
                } else {
                    Text("No shortcuts set")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text("\(appState.activeTranscriptionProvider.displayName) \(appState.activeTranscriptionProvider == .groq ? "⚡️" : "")")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(accentColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(accentColor.opacity(0.15))
                    .cornerRadius(10)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 12)
        .background(Color(red: 19/255, green: 19/255, blue: 19/255)) // #131313
    }

    private var statusColor: Color {
        if appState.isRecording { return .red }
        if appState.isTranscribing { return .yellow }
        return .green
    }

    private var statusText: String {
        if appState.isRecording { return "Recording..." }
        if appState.isTranscribing { return appState.debugStatusMessage }
        return "Ready to dictate"
    }

    private var shortcutHint: String {
        let hold = appState.holdShortcut.isDisabled ? "" : "[\(appState.holdShortcut.displayName)]"
        let toggle = appState.toggleShortcut.isDisabled ? "" : "[\(appState.toggleShortcut.displayName)]"
        
        if !hold.isEmpty && !toggle.isEmpty {
            return "\(hold) or \(toggle)"
        }
        return hold + toggle
    }

    // ─── SETTINGS & MODES ────────────────────────────────────

    private var languageModeSection: some View {
        HStack(spacing: 8) {
            Image(systemName: "globe")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .frame(width: 16)
            
            Picker("Language Mode", selection: $appState.languageMode) {
                Text("MIX 🇮🇳").tag(UserLanguageMode.hinglish)
                Text("HI 🇮🇳").tag(UserLanguageMode.pureHindi)
                Text("EN").tag(UserLanguageMode.pureEnglish)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: .infinity)
            .cornerRadius(6)
        }
    }

    private var toneModeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .frame(width: 16)
                Spacer()
                Button(action: {
                    appState.selectedSettingsTab = .general
                    NotificationCenter.default.post(name: .showSettings, object: nil)
                }) {
                    Text("Edit modes")
                        .font(.system(size: 10))
                        .foregroundColor(accentColor)
                }
                .buttonStyle(.plain)
            }

            let tones: [(icon: String, name: String, id: UUID)] = [
                ("bubble.left.fill", "Casual", DictationMode.casualHinglish.id),
                ("envelope.fill", "Email", DictationMode.professionalEmail.id),
                ("chevron.left.forwardslash.chevron.right", "Code", DictationMode.codeAndTerminal.id),
                ("note.text", "Notes", DictationMode.meetingNotes.id),
                ("heart.fill", "Social", DictationMode.socialMedia.id),
                ("equal.circle.fill", "Literal", DictationMode.literalNoEdit.id)
            ]

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(tones, id: \.id) { tone in
                    toneButton(icon: tone.icon, name: tone.name, id: tone.id)
                }
            }
        }
    }

    private func toneButton(icon: String, name: String, id: UUID) -> some View {
        let isActive = appState.dictationModeStore.activeModeID == id

        return Button(action: {
            appState.dictationModeStore.activeModeID = isActive ? nil : id
        }) {
            VStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 14))
                Text(name).font(.system(size: 10, weight: isActive ? .semibold : .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isActive ? accentColor.opacity(0.15) : Color(red: 32/255, green: 32/255, blue: 31/255)) // #20201F
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isActive ? accentColor : Color.white.opacity(0.05), lineWidth: 1.5)
            )
            .foregroundColor(isActive ? accentColor : .white.opacity(0.8))
        }
        .buttonStyle(.plain)
    }

    // ─── RECENT ───────────────────────────────────────────────

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "clock")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .frame(width: 16)
            }

            if !appState.lastTranscript.isEmpty && !appState.isRecording && !appState.isTranscribing {
                HStack(alignment: .top) {
                    Text(appState.lastTranscript)
                        .font(.system(size: 12))
                        .lineLimit(3)
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Button(action: {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(appState.lastTranscript, forType: .string)
                    }) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 12))
                            .foregroundColor(accentColor)
                            .padding(6)
                            .background(accentColor.opacity(0.1))
                            .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                }
                .padding(12)
                .background(Color(red: 32/255, green: 32/255, blue: 31/255)) // #20201F
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.05), lineWidth: 1))
            } else {
                Text("No recent transcriptions")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.4))
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(red: 32/255, green: 32/255, blue: 31/255)) // #20201F
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.05), lineWidth: 1))
            }
        }
    }

    // ─── ACTIONS ──────────────────────────────────────────────

    private var actionsSection: some View {
        VStack(spacing: 12) {
            if !appState.hasScreenRecordingPermission {
                warningButton(label: "Screen Recording Needed", icon: "camera.viewfinder", color: .orange) { appState.requestScreenCapturePermission() }
            }

            if !appState.hasAccessibility {
                warningButton(label: "Accessibility Required", icon: "exclamationmark.triangle.fill", color: .red) { appState.showAccessibilityAlert() }
            }

            Button(action: {
                appState.toggleRecording()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: appState.isRecording ? "stop.fill" : "mic.fill")
                    Text(appState.isRecording ? "Stop Recording" : "Start Dictating")
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(appState.isRecording ? Color.red : accentColor)
                .cornerRadius(6)
                .shadow(color: (appState.isRecording ? Color.red : accentColor).opacity(0.3), radius: 4, y: 2)
            }
            .buttonStyle(.plain)
            .disabled(appState.isTranscribing)

            if let error = appState.errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.system(size: 11))
                    .lineLimit(2)
            }
            
            HStack {
                Spacer()
                Button("Transcribe File...") {
                    NotificationCenter.default.post(name: .showFileTranscription, object: nil)
                }
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(accentColor)
                .buttonStyle(.plain)
            }
            
            HStack {
                Text("v\(appVersion)")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                Spacer()
                Button("Quit FlowKeys") {
                    NSApplication.shared.terminate(nil)
                }
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(Color(red: 19/255, green: 19/255, blue: 19/255)) // #131313
    }

    private func warningButton(label: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(label, systemImage: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(color)
                .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }

    // ─── UPDATE ──────────────────────────────────────────────

    private var updateSection: some View {
        Group {
            switch updateManager.updateStatus {
            case .downloading:
                VStack(spacing: 4) {
                    Text("Downloading update... \(Int((updateManager.downloadProgress ?? 0) * 100))%")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                    ProgressView(value: updateManager.downloadProgress ?? 0)
                        .progressViewStyle(.linear)
                        .tint(.white)
                }
                .padding(16)
                .background(Color.blue)

            case .installing, .readyToRelaunch:
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small).tint(.white)
                    Text("Installing update...")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .padding(16)
                .background(Color.blue)

            default:
                Button(action: {
                    updateManager.showUpdateAlert()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.down.circle.fill")
                        Text("Update Available")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(12)
                    .background(Color.blue)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

extension Notification.Name {
    static let showSetup = Notification.Name("showSetup")
    static let showSettings = Notification.Name("showSettings")
    static let showFileTranscription = Notification.Name("showFileTranscription")
}
