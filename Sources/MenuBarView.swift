import SwiftUI

// MARK: - MenuBarView

struct MenuBarView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject private var updateManager = UpdateManager.shared

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                headerSection
                kmDivider
                languageSection
                kmDivider
                toneGridSection
                kmDivider
                recentSection

                if updateManager.updateAvailable {
                    kmDivider
                        .transition(.opacity)
                    updateBanner
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                ctaSection
                footerSection
            }
            .frame(width: 300)
            .background(KM.bg)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(KM.outline, lineWidth: 1)
            )

            // Bottom gradient line decoration
            LinearGradient(
                colors: [KM.accent.opacity(0), KM.accent.opacity(0.2), KM.accent.opacity(0)],
                startPoint: .leading, endPoint: .trailing
            )
            .frame(height: 1)
        }
    }

    // MARK: Divider

    private var kmDivider: some View {
        Rectangle()
            .fill(KM.outline)
            .frame(height: 1)
    }

    // MARK: Header

    private var headerSection: some View {
        HStack(spacing: 8) {
            // Logo
            HStack(spacing: 6) {
                Image(systemName: "waveform")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(colors: [KM.accent, KM.salmon], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                Text("FlowKeys")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(KM.onSurface)
            }

            Spacer()

            // Hotkey badge
            hotkeyBadge

            // Provider badge
            providerBadge

            // Settings icon
            Button {
                NotificationCenter.default.post(name: .showSettings, object: nil)
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 13))
                    .foregroundColor(KM.muted)
            }
            .buttonStyle(.plain)

            // Help icon
            Button {
                if let url = URL(string: "https://github.com/iamadarsha/FlowKeys") {
                    NSWorkspace.shared.open(url)
                }
            } label: {
                Image(systemName: "questionmark.circle")
                    .font(.system(size: 13))
                    .foregroundColor(KM.muted)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .frame(height: 52)
    }

    private var hotkeyBadge: some View {
        let shortcutText: String = {
            if !appState.holdShortcut.isDisabled {
                return appState.holdShortcut.displayName
            } else if !appState.toggleShortcut.isDisabled {
                return appState.toggleShortcut.displayName
            }
            return "—"
        }()

        return Text(shortcutText)
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .foregroundColor(KM.muted)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(KM.surfaceHi)
            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
    }

    private var providerBadge: some View {
        HStack(spacing: 3) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 7))
                .foregroundColor(KM.accent)
            Text(appState.activeTranscriptionProvider.shortName)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(KM.accent)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(KM.accent.opacity(0.12))
        .clipShape(Capsule())
    }

    // MARK: Language Mode

    private var languageSection: some View {
        HStack(spacing: 8) {
            Image(systemName: "globe")
                .font(.system(size: 13))
                .foregroundColor(KM.muted)

            HStack(spacing: 2) {
                ForEach(UserLanguageMode.allCases) { mode in
                    languageSegment(mode)
                }
            }
            .padding(3)
            .background(KM.surfaceHi)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .padding(.horizontal, 14)
        .frame(height: 44)
    }

    private func languageSegment(_ mode: UserLanguageMode) -> some View {
        let isActive = appState.languageMode == mode
        return Button {
            withAnimation(.spring(response: 0.22, dampingFraction: 0.85)) {
                appState.languageMode = mode
            }
        } label: {
            Text(languagePillText(mode))
                .font(.system(size: 11, weight: isActive ? .semibold : .regular))
                .foregroundColor(isActive ? KM.onSurface : KM.muted)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    isActive
                        ? KM.accent.opacity(0.25)
                        : Color.clear
                )
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .animation(.spring(response: 0.22, dampingFraction: 0.85), value: isActive)
        }
        .buttonStyle(.plain)
    }

    private func languagePillText(_ mode: UserLanguageMode) -> String {
        switch mode {
        case .hinglish: return "MIX"
        case .pureHindi: return "HI"
        case .pureEnglish: return "EN"
        }
    }

    // MARK: Tone Grid

    private var toneGridSection: some View {
        let tones: [(icon: String, name: String, id: UUID)] = [
            ("🗣️", "Casual",  DictationMode.casualHinglish.id),
            ("📧", "Email",   DictationMode.professionalEmail.id),
            ("💻", "Code",    DictationMode.codeAndTerminal.id),
            ("📝", "Notes",   DictationMode.meetingNotes.id),
            ("📱", "Social",  DictationMode.socialMedia.id),
            ("🔇", "Literal", DictationMode.literalNoEdit.id)
        ]

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("TONE")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(KM.muted)
                    .tracking(1.2)
                Spacer()
                Button {
                    appState.selectedSettingsTab = .general
                    NotificationCenter.default.post(name: .showSettings, object: nil)
                } label: {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 11))
                        .foregroundColor(KM.muted)
                }
                .buttonStyle(.plain)
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: 6) {
                ForEach(tones, id: \.id) { tone in
                    toneCell(icon: tone.icon, name: tone.name, id: tone.id)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private func toneCell(icon: String, name: String, id: UUID) -> some View {
        let isActive = appState.dictationModeStore.activeModeID == id
        return Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
                if isActive {
                    appState.dictationModeStore.activeModeID = nil
                } else {
                    appState.dictationModeStore.activeModeID = id
                }
            }
        } label: {
            VStack(spacing: 4) {
                Text(icon).font(.system(size: 16))
                Text(name)
                    .font(.system(size: 10, weight: isActive ? .semibold : .regular))
                    .foregroundColor(isActive ? KM.accent : KM.muted)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                isActive
                    ? KM.accent.opacity(0.15)
                    : KM.surfaceHi.opacity(0.7)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isActive ? KM.accent : Color.clear, lineWidth: 1.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .scaleEffect(isActive ? 1.04 : 1.0)
            .animation(.spring(response: 0.28, dampingFraction: 0.72), value: isActive)
        }
        .buttonStyle(.plain)
    }

    // MARK: Recent

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("RECENT")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(KM.muted)
                .tracking(1.2)

            if !appState.lastTranscript.isEmpty && !appState.isRecording && !appState.isTranscribing {
                HStack(alignment: .top, spacing: 8) {
                    Text(appState.lastTranscript.count > 72
                         ? String(appState.lastTranscript.prefix(72)) + "…"
                         : appState.lastTranscript)
                        .font(.system(size: 11))
                        .foregroundColor(KM.onSurface.opacity(0.75))
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(appState.lastTranscript, forType: .string)
                    } label: {
                        Image(systemName: "doc.on.clipboard")
                            .font(.system(size: 11))
                            .foregroundColor(KM.muted)
                    }
                    .buttonStyle(.plain)
                }
                .padding(10)
                .background(KM.surfaceHi)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .transition(.move(edge: .top).combined(with: .opacity))
            } else {
                Text("No recent transcriptions")
                    .font(.system(size: 11))
                    .foregroundColor(KM.muted)
                    .transition(.opacity)
            }

            if let error = appState.errorMessage {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(Color(hex: "#FFB4AB"))
                    Text(error)
                        .font(.system(size: 10))
                        .foregroundColor(Color(hex: "#FFB4AB"))
                        .lineLimit(2)
                }
                .padding(8)
                .background(Color(hex: "#FFB4AB").opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: appState.lastTranscript)
        .animation(.easeOut(duration: 0.25), value: appState.errorMessage)
    }

    // MARK: Update Banner

    private var updateBanner: some View {
        Button {
            updateManager.showUpdateAlert()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 12))
                Text("Update Available")
                    .font(.system(size: 11, weight: .semibold))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 10))
                    .foregroundColor(KM.muted)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.blue.opacity(0.2))
        }
        .buttonStyle(.plain)
    }

    // MARK: CTA

    private var ctaSection: some View {
        VStack(spacing: 8) {
            if !appState.hasScreenRecordingPermission || !appState.hasAccessibility {
                permissionWarnings
            }

            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                    appState.toggleRecording()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: appState.isRecording ? "stop.fill" : "mic.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .transition(.opacity)
                    Text(appState.isRecording ? "Stop Recording" : "Start Dictating")
                        .font(.system(size: 13, weight: .semibold))
                        .transition(.opacity)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(
                    LinearGradient(
                        colors: appState.isRecording
                            ? [Color.red.opacity(0.85), Color.red.opacity(0.7)]
                            : [KM.accent, KM.accent.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(Capsule())
                .shadow(color: (appState.isRecording ? Color.red : KM.accent).opacity(0.4), radius: 8, x: 0, y: 4)
                .scaleEffect(appState.isTranscribing ? 0.97 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.75), value: appState.isRecording)
                .animation(.easeOut(duration: 0.2), value: appState.isTranscribing)
            }
            .buttonStyle(.plain)
            .disabled(appState.isTranscribing)
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 10)
    }

    private var permissionWarnings: some View {
        VStack(spacing: 4) {
            if !appState.hasScreenRecordingPermission {
                permWarningRow(label: "Screen Recording Needed", icon: "camera.viewfinder", color: .orange) {
                    appState.requestScreenCapturePermission()
                }
            }
            if !appState.hasAccessibility {
                permWarningRow(label: "Accessibility Required", icon: "exclamationmark.triangle.fill", color: Color(hex: "#FFB4AB")) {
                    appState.showAccessibilityAlert()
                }
            }
        }
    }

    private func permWarningRow(label: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 10))
                Text(label).font(.system(size: 11, weight: .medium))
                Spacer()
                Image(systemName: "arrow.right.circle").font(.system(size: 10))
            }
            .foregroundColor(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(color.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: Footer

    private var footerSection: some View {
        HStack {
            Text("v\(appVersion)")
                .font(.system(size: 9))
                .foregroundColor(KM.muted)

            Spacer()

            Button("File Transcription") {
                NotificationCenter.default.post(name: .showFileTranscription, object: nil)
            }
            .font(.system(size: 10))
            .foregroundColor(KM.muted)
            .buttonStyle(.plain)

            Spacer()

            Button("Quit FlowKeys") {
                NSApplication.shared.terminate(nil)
            }
            .font(.system(size: 10))
            .foregroundColor(KM.muted)
            .buttonStyle(.plain)
            .keyboardShortcut("q")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

extension Notification.Name {
    static let showSetup             = Notification.Name("showSetup")
    static let showSettings          = Notification.Name("showSettings")
    static let showFileTranscription = Notification.Name("showFileTranscription")
}
