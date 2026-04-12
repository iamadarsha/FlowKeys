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
            divider
            statusSection
            divider
            languageModeSection
            divider
            toneModeSection
            divider
            recentSection
            divider
            quickActionsSection
            divider
            providerStatusSection

            if updateManager.updateAvailable {
                divider
                updateSection
            }

            divider
            footerSection
        }
        .frame(width: 340)
        .padding(.vertical, 4)
    }

    private var divider: some View {
        Divider().padding(.horizontal, 12)
    }

    // ─── HEADER ──────────────────────────────────────────────

    private var headerSection: some View {
        HStack {
            Image(systemName: "mic.circle.fill")
                .font(.system(size: 16))
                .foregroundColor(accentColor)
            Text("FlowKeys")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
            Spacer()
            Button {
                NotificationCenter.default.post(name: .showSettings, object: nil)
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)

            Button {
                if let url = URL(string: "https://github.com/iamadarsha/FlowKeys") {
                    NSWorkspace.shared.open(url)
                }
            } label: {
                Image(systemName: "questionmark.circle")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // ─── STATUS ──────────────────────────────────────────────

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                statusDot
                Text(statusText)
                    .font(.system(size: 12, weight: .medium))
                Spacer()
            }
            Text(shortcutHint)
                .font(.system(size: 10, weight: .regular, design: .monospaced))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private var statusDot: some View {
        Circle()
            .fill(statusColor)
            .frame(width: 8, height: 8)
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
        let hold = appState.holdShortcut.isDisabled ? "" : "Hold [\(appState.holdShortcut.displayName)]"
        let toggle = appState.toggleShortcut.isDisabled ? "" : "Tap [\(appState.toggleShortcut.displayName)]"
        if !hold.isEmpty && !toggle.isEmpty {
            return "\(hold) or \(toggle)"
        }
        return hold + toggle
    }

    // ─── LANGUAGE MODE ───────────────────────────────────────

    private var languageModeSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("MODE")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.secondary)
                .tracking(1.2)

            HStack(spacing: 4) {
                ForEach(UserLanguageMode.allCases) { mode in
                    languagePill(mode)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private func languagePill(_ mode: UserLanguageMode) -> some View {
        Button {
            appState.languageMode = mode
        } label: {
            Text(languagePillText(mode))
                .font(.system(size: 12, weight: appState.languageMode == mode ? .semibold : .regular))
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(appState.languageMode == mode ? accentColor.opacity(0.2) : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(appState.languageMode == mode ? accentColor : Color.gray.opacity(0.3), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func languagePillText(_ mode: UserLanguageMode) -> String {
        switch mode {
        case .hinglish: return "MIX 🇮🇳"
        case .pureHindi: return "HI 🇮🇳"
        case .pureEnglish: return "EN"
        }
    }

    // ─── TONE / MODE ─────────────────────────────────────────

    private var toneModeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TONE")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.secondary)
                .tracking(1.2)

            // Replaced ScrollView with a fixed 2-row grid so all tones are visible without scrolling
            let tones: [(icon: String, name: String, id: UUID)] = [
                ("🗣️", "Casual", DictationMode.casualHinglish.id),
                ("📧", "Email", DictationMode.professionalEmail.id),
                ("💻", "Code", DictationMode.codeAndTerminal.id),
                ("📝", "Notes", DictationMode.meetingNotes.id),
                ("📱", "Social", DictationMode.socialMedia.id),
                ("🔇", "Literal", DictationMode.literalNoEdit.id)
            ]

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: 6) {
                ForEach(tones, id: \.id) { tone in
                    toneButton(icon: tone.icon, name: tone.name, id: tone.id)
                }
            }

            Button {
                appState.selectedSettingsTab = .general
                NotificationCenter.default.post(name: .showSettings, object: nil)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 11))
                    Text("Custom modes")
                        .font(.system(size: 11))
                }
                .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private func toneButton(icon: String, name: String, id: UUID) -> some View {
        let isActive = appState.dictationModeStore.activeModeID == id

        return Button {
            if isActive {
                appState.dictationModeStore.activeModeID = nil
            } else {
                appState.dictationModeStore.activeModeID = id
            }
        } label: {
            HStack(spacing: 6) {
                Text(icon)
                    .font(.system(size: 14))
                Text(name)
                    .font(.system(size: 11, weight: isActive ? .semibold : .regular))
                    .foregroundColor(isActive ? accentColor : .primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isActive ? accentColor.opacity(0.15) : Color.gray.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isActive ? accentColor : Color.gray.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // ─── RECENT TRANSCRIPTIONS ───────────────────────────────

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("📋 Recent")
                    .font(.system(size: 11, weight: .semibold))
                Spacer()
            }

            if !appState.lastTranscript.isEmpty && !appState.isRecording && !appState.isTranscribing {
                VStack(alignment: .leading, spacing: 4) {
                    Text(appState.lastTranscript.count > 80
                        ? String(appState.lastTranscript.prefix(80)) + "…"
                        : appState.lastTranscript)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Button("Copy") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(appState.lastTranscript, forType: .string)
                    }
                    .font(.system(size: 10))
                    .buttonStyle(.plain)
                    .foregroundColor(accentColor)
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.gray.opacity(0.08))
                )
            } else {
                Text("No recent transcriptions")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // ─── QUICK ACTIONS ───────────────────────────────────────

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !appState.hasScreenRecordingPermission {
                warningButton(
                    label: "Screen Recording Needed",
                    icon: "camera.viewfinder",
                    color: .orange
                ) {
                    appState.requestScreenCapturePermission()
                }
            }

            if !appState.hasAccessibility {
                warningButton(
                    label: "Accessibility Required",
                    icon: "exclamationmark.triangle.fill",
                    color: .red
                ) {
                    appState.showAccessibilityAlert()
                }
            }

            Button(appState.isRecording ? "⏹ Stop Recording" : "🎙 Start Dictating") {
                appState.toggleRecording()
            }
            .font(.system(size: 12, weight: .medium))
            .disabled(appState.isTranscribing)

            if let error = appState.errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.system(size: 10))
                    .lineLimit(2)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private func warningButton(label: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(label, systemImage: icon)
        }
        .buttonStyle(.plain)
        .foregroundColor(.white)
        .font(.system(size: 10, weight: .semibold))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 6).fill(color))
    }

    // ─── PROVIDER STATUS ─────────────────────────────────────

    private var providerStatusSection: some View {
        HStack {
            Text("Provider:")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)

            Text(appState.activeTranscriptionProvider.displayName)
                .font(.system(size: 10, weight: .semibold))

            Text("✅")
                .font(.system(size: 10))

            Spacer()

            Button("Change") {
                NotificationCenter.default.post(name: .showSettings, object: nil)
            }
            .font(.system(size: 10))
            .buttonStyle(.plain)
            .foregroundColor(accentColor)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // ─── UPDATE ──────────────────────────────────────────────

    private var updateSection: some View {
        Group {
            switch updateManager.updateStatus {
            case .downloading:
                VStack(spacing: 4) {
                    Text("Downloading update... \(Int((updateManager.downloadProgress ?? 0) * 100))%")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white)
                    ProgressView(value: updateManager.downloadProgress ?? 0)
                        .progressViewStyle(.linear)
                        .tint(.white)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(Color.blue)

            case .installing, .readyToRelaunch:
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text("Installing...")
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity)
                .background(Color.blue)

            default:
                Button {
                    updateManager.showUpdateAlert()
                } label: {
                    Label("Update Available", systemImage: "arrow.down.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundColor(.white)
                .font(.system(size: 10, weight: .semibold))
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity)
                .background(Color.blue)
            }
        }
    }

    // ─── FOOTER ──────────────────────────────────────────────

    private var footerSection: some View {
        HStack {
            Text("v\(appVersion)")
                .font(.system(size: 9))
                .foregroundColor(.secondary)
            Spacer()
            Button("Transcribe File...") {
                NotificationCenter.default.post(name: .showFileTranscription, object: nil)
            }
            .font(.system(size: 11))
            Spacer()
            Button("Settings") {
                NotificationCenter.default.post(name: .showSettings, object: nil)
            }
            .font(.system(size: 11))
            Spacer()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .font(.system(size: 11))
            .keyboardShortcut("q")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

extension Notification.Name {
    static let showSetup = Notification.Name("showSetup")
    static let showSettings = Notification.Name("showSettings")
    static let showFileTranscription = Notification.Name("showFileTranscription")
}
