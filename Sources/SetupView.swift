import SwiftUI
import AVFoundation
import Combine
import Foundation
import ServiceManagement

struct SetupView: View {
    var onComplete: () -> Void
    @EnvironmentObject var appState: AppState
    @Environment(\.openURL) private var openURL
    private let flowKeysRepoURL = URL(string: "https://github.com/iamadarsha/FlowKeys")!
    private enum SetupStep: Int, CaseIterable {
        case provider = 0
        case apiKey
        case micPermission
        case accessibility
        case screenRecording
        case holdShortcut
        case toggleShortcut
        case snippets
        case vocabulary
        case launchAtLogin
        case testTranscription
        case ready
    }

    @State private var currentStep = SetupStep.provider
    @State private var micPermissionGranted = false
    @State private var accessibilityGranted = false
    @State private var apiKeyInput: String = ""
    @State private var selectedProvider: TranscriptionProvider = .groq
    @State private var isValidatingKey = false
    @State private var keyValidationError: String?
    @State private var accessibilityTimer: Timer?
    @State private var screenRecordingTimer: Timer?
    @State private var customVocabularyInput: String = ""
    @State private var newSnippetTrigger: String = ""
    @State private var newSnippetReplacement: String = ""
    @StateObject private var githubCache = GitHubMetadataCache.shared

    // Test transcription state
    private enum TestPhase: Equatable {
        case idle, recording, transcribing, done
    }
    @State private var testPhase: TestPhase = .idle
    @State private var testAudioRecorder: AudioRecorder? = nil
    @State private var testAudioLevel: Float = 0.0
    @State private var testTranscript: String = ""
    @State private var testError: String? = nil
    @State private var testAudioLevelCancellable: AnyCancellable? = nil
    @State private var testMicPulsing = false
    @State private var holdShortcutValidationMessage: String?
    @State private var toggleShortcutValidationMessage: String?
    @State private var isCapturingHoldShortcut = false
    @State private var isCapturingToggleShortcut = false
    @StateObject private var testHotkeyHarness = SetupTestHotkeyHarness()

    private let totalSteps: [SetupStep] = SetupStep.allCases
    private var isCapturingShortcut: Bool {
        isCapturingHoldShortcut || isCapturingToggleShortcut
    }

    var body: some View {
        VStack(spacing: 0) {
            // Step dots
            HStack(spacing: 6) {
                ForEach(SetupStep.allCases, id: \.rawValue) { step in
                    let isCurrent = step == currentStep
                    let isDone = step.rawValue < currentStep.rawValue
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(isCurrent ? KM.accent : (isDone ? KM.accent.opacity(0.5) : KM.surfaceHi))
                        .frame(width: isCurrent ? 20 : 6, height: 6)
                        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: currentStep)
                }
            }
            .padding(.top, 16)
            .padding(.bottom, 4)

            ScrollView {
                currentStepView
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 24)
            }

            // Footer navigation
            Rectangle()
                .fill(KM.outline)
                .frame(height: 1)

            ZStack {
                stepIndicator

                HStack(alignment: .center) {
                    Group {
                        if currentStep != .provider {
                            Button("Back") {
                                keyValidationError = nil
                                withAnimation { currentStep = previousStep(currentStep) }
                            }
                            .foregroundColor(KM.muted)
                            .disabled(isValidatingKey)
                        }
                    }

                    Spacer()

                    Group {
                        if currentStep != .ready {
                            if currentStep == .apiKey {
                                kmContinueButton(
                                    label: isValidatingKey ? "Validating…" : "Continue",
                                    disabled: !canContinueFromCurrentStep || isValidatingKey
                                ) { validateAndContinue() }
                            } else if currentStep == .vocabulary {
                                kmContinueButton(label: "Continue", disabled: false) {
                                    saveCustomVocabularyAndContinue()
                                }
                            } else if currentStep == .testTranscription {
                                HStack(spacing: 10) {
                                    Button("Skip") {
                                        stopTestHotkeyMonitoring()
                                        withAnimation { currentStep = nextStep(currentStep) }
                                    }
                                    .foregroundColor(KM.muted)
                                    .buttonStyle(.plain)

                                    kmContinueButton(
                                        label: "Continue",
                                        disabled: testPhase != .done || testTranscript.isEmpty || testError != nil
                                    ) {
                                        stopTestHotkeyMonitoring()
                                        withAnimation { currentStep = nextStep(currentStep) }
                                    }
                                }
                            } else {
                                kmContinueButton(label: "Continue", disabled: !canContinueFromCurrentStep) {
                                    withAnimation { currentStep = nextStep(currentStep) }
                                }
                            }
                        } else {
                            kmContinueButton(label: "Get Started", disabled: false) { onComplete() }
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(KM.bg)
        }
        .background(KM.bg)
        .frame(width: 520, height: 680)
        .onAppear {
            selectedProvider = appState.activeLLMProvider
            apiKeyInput = appState.apiKey(for: selectedProvider)
            customVocabularyInput = appState.customVocabulary
            checkMicPermission()
            checkAccessibility()
            Task {
                await githubCache.fetchIfNeeded()
            }
        }
        .onDisappear {
            accessibilityTimer?.invalidate()
            screenRecordingTimer?.invalidate()
            appState.resumeHotkeyMonitoringAfterShortcutCapture()
        }
        .onChange(of: isCapturingShortcut) { isCapturing in
            if isCapturing {
                appState.suspendHotkeyMonitoringForShortcutCapture()
            } else {
                appState.resumeHotkeyMonitoringAfterShortcutCapture()
            }
        }
    }

    @ViewBuilder
    private var currentStepView: some View {
        switch currentStep {
        case .provider:
            providerStep
        case .apiKey:
            apiKeyStep
        case .micPermission:
            micPermissionStep
        case .accessibility:
            accessibilityStep
        case .screenRecording:
            screenRecordingStep
        case .holdShortcut:
            holdShortcutStep
        case .toggleShortcut:
            toggleShortcutStep
        case .snippets:
            snippetsStep
        case .vocabulary:
            vocabularyStep
        case .launchAtLogin:
            launchAtLoginStep
        case .testTranscription:
            testTranscriptionStep
        case .ready:
            readyStep
        }
    }

    // MARK: - Steps

    var providerStep: some View {
        VStack(spacing: 20) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 100, height: 100)

            VStack(spacing: 6) {
                Text("Choose Your AI Provider")
                    .font(.system(size: 28, weight: .bold, design: .rounded))

                Text("FlowKeys lets you pick your preferred provider now,\nand you can switch providers later in Settings.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 8) {
                ForEach(TranscriptionProvider.allCases) { provider in
                    providerCard(provider)
                }
            }

            // Clean attribution footer — no random user avatars
            HStack(spacing: 8) {
                Image(systemName: "chevron.left.forwardslash.chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("Made by ")
                    .font(.caption)
                    .foregroundColor(.secondary)
                +
                Text("Adarsha")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.primary)

                Text("·")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Button {
                    openURL(flowKeysRepoURL)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.right.square")
                            .font(.caption2)
                        Text("iamadarsha/FlowKeys")
                            .font(.system(.caption, design: .monospaced).weight(.medium))
                    }
                }
                .buttonStyle(.plain)
                .foregroundColor(.blue)

                if githubCache.isLoading {
                    ProgressView().scaleEffect(0.45)
                } else if let count = githubCache.starCount, count > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundColor(.yellow)
                        Text("\(count)")
                            .font(.caption2.weight(.semibold))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.yellow.opacity(0.12)))
                }

                Spacer()

                Button {
                    openURL(flowKeysRepoURL)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "star")
                        Text("Star")
                    }
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.yellow.opacity(0.15)))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                    )
            )
        }
    }

    var apiKeyStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "key.fill")
                .font(.system(size: 52))
                .foregroundStyle(LinearGradient(colors: [KM.accent, KM.salmon], startPoint: .topLeading, endPoint: .bottomTrailing))

            Text("Enter Your \(selectedProvider.displayName) API Key")
                .font(.title)
                .fontWeight(.bold)

            Text(selectedProvider.shortDescription)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("How to get your API key:")
                        .font(.subheadline.weight(.semibold))
                    HStack {
                        Text("Use the provider console to create an API key.")
                            .font(.subheadline)
                        Spacer()
                        Button("Get free API key →") {
                            if let url = URL(string: selectedProvider.apiKeyURL) {
                                openURL(url)
                            }
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.blue)
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.blue.opacity(0.06))
                )

                VStack(alignment: .leading, spacing: 6) {
                    Text("API Key")
                        .font(.headline)
                    SecureField(selectedProvider.apiKeyPlaceholder, text: $apiKeyInput)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .disabled(isValidatingKey)
                        .onChange(of: apiKeyInput) { _ in
                            keyValidationError = nil
                        }

                    if let error = keyValidationError {
                        Label(error, systemImage: "xmark.circle.fill")
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
        }
    }

    var micPermissionStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "mic.fill")
                .font(.system(size: 52))
                .foregroundStyle(LinearGradient(colors: [KM.accent, KM.salmon], startPoint: .topLeading, endPoint: .bottomTrailing))

            Text("Microphone Access")
                .font(.title)
                .fontWeight(.bold)

            Text("FlowKeys needs access to your microphone to record audio for transcription.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Image(systemName: "mic.fill")
                    .frame(width: 24)
                    .foregroundColor(.blue)
                Text("Microphone")
                Spacer()
                if micPermissionGranted {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Granted")
                        .foregroundColor(.green)
                } else {
                    Button("Grant Access") {
                        requestMicPermission()
                    }
                }
            }
            .padding(12)
            .background(KM.surfaceHi)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(KM.outline, lineWidth: 1))
        }
    }

    var accessibilityStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 52))
                .foregroundStyle(LinearGradient(colors: [KM.accent, KM.salmon], startPoint: .topLeading, endPoint: .bottomTrailing))

            Text("Accessibility Access")
                .font(.title)
                .fontWeight(.bold)

            Text("FlowKeys needs Accessibility access to paste transcribed text into your apps.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Image(systemName: "hand.raised.fill")
                    .frame(width: 24)
                    .foregroundColor(.blue)
                Text("Accessibility")
                Spacer()
                if accessibilityGranted {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Granted")
                        .foregroundColor(.green)
                } else {
                    Button("Open Settings") {
                        requestAccessibility()
                    }
                }
            }
            .padding(12)
            .background(KM.surfaceHi)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(KM.outline, lineWidth: 1))

            if !accessibilityGranted {
                Text("Note: If you rebuilt the app, you may need to\nremove and re-add it in Accessibility settings.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .onAppear { startAccessibilityPolling() }
        .onDisappear { accessibilityTimer?.invalidate() }
    }

    var screenRecordingStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 52))
                .foregroundStyle(LinearGradient(colors: [KM.accent, KM.salmon], startPoint: .topLeading, endPoint: .bottomTrailing))

            Text("Screen Recording")
                .font(.title)
                .fontWeight(.bold)

            Text("FlowKeys intelligently adapts the transcription to the current app you're working in (e.g. spelling names in an email correctly).")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Text("It needs this permission to see which app you're working in and any in-progress work. Nothing is stored on FlowKeys servers.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Image(systemName: "camera.viewfinder")
                    .frame(width: 24)
                    .foregroundColor(.blue)
                Text("Screen Recording")
                Spacer()
                if appState.hasScreenRecordingPermission {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Granted")
                        .foregroundColor(.green)
                } else {
                    Button("Grant Access") {
                        appState.requestScreenCapturePermission()
                    }
                }
            }
            .padding(12)
            .background(KM.surfaceHi)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(KM.outline, lineWidth: 1))
        }
        .onAppear { startScreenRecordingPolling() }
        .onDisappear { screenRecordingTimer?.invalidate() }
    }

    var holdShortcutStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "keyboard.fill")
                .font(.system(size: 52))
                .foregroundStyle(LinearGradient(colors: [KM.accent, KM.salmon], startPoint: .topLeading, endPoint: .bottomTrailing))

            Text("Hold to Talk Shortcut")
                .font(.title)
                .fontWeight(.bold)

            Text("Choose the shortcut you want to hold while speaking.\nRelease it to stop unless you latch into tap mode later, or disable hold-to-talk entirely.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            ShortcutRoleSection(
                role: .hold,
                selection: appState.holdShortcut,
                validationMessage: holdShortcutValidationMessage,
                isCapturing: $isCapturingHoldShortcut,
                onSelect: { binding in
                    holdShortcutValidationMessage = appState.setShortcut(binding, for: .hold)
                }
            )
            .padding(.top, 10)

            if appState.holdShortcut.usesFnKey {
                Text("Tip: If Fn opens Emoji picker, go to System Settings > Keyboard and change \"Press fn key to\" to \"Do Nothing\".")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .multilineTextAlignment(.center)
            }
        }
    }

    var toggleShortcutStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "switch.2")
                .font(.system(size: 52))
                .foregroundStyle(LinearGradient(colors: [KM.accent, KM.salmon], startPoint: .topLeading, endPoint: .bottomTrailing))

            Text("Tap to Toggle Shortcut")
                .font(.title)
                .fontWeight(.bold)

            Text("Choose the shortcut you want to tap once to start dictating and tap again to stop.\nIf this shortcut becomes active while you are holding the hold shortcut, FlowKeys latches into tap mode. You can also disable tap-to-toggle entirely.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            ShortcutRoleSection(
                role: .toggle,
                selection: appState.toggleShortcut,
                validationMessage: toggleShortcutValidationMessage,
                isCapturing: $isCapturingToggleShortcut,
                onSelect: { binding in
                    toggleShortcutValidationMessage = appState.setShortcut(binding, for: .toggle)
                }
            )
            .padding(.top, 10)

            if appState.toggleShortcut.usesFnKey {
                Text("Tip: If Fn opens Emoji picker, go to System Settings > Keyboard and change \"Press fn key to\" to \"Do Nothing\".")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .multilineTextAlignment(.center)
            }
        }
    }

    var snippetsStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "text.badge.plus")
                .font(.system(size: 52))
                .foregroundStyle(LinearGradient(colors: [KM.accent, KM.salmon], startPoint: .topLeading, endPoint: .bottomTrailing))

            Text("Quick Snippets")
                .font(.title)
                .fontWeight(.bold)

            Text("Define shorthand phrases (like 'my email') that automatically expand to full text during transcription.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("When I say...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("e.g. my email", text: $newSnippetTrigger)
                            .textFieldStyle(.roundedBorder)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Replace with...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("e.g. adarsha@example.com", text: $newSnippetReplacement)
                            .textFieldStyle(.roundedBorder)
                    }
                }

                Button("Add Snippet") {
                    let s = VoiceSnippet(
                        trigger: newSnippetTrigger,
                        replacement: newSnippetReplacement
                    )
                    appState.snippetEngine.addSnippet(s)
                    newSnippetTrigger = ""
                    newSnippetReplacement = ""
                }
                .disabled(newSnippetTrigger.isEmpty || newSnippetReplacement.isEmpty)
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)

            if !appState.snippetEngine.snippets.isEmpty {
                Text("\(appState.snippetEngine.snippets.count) snippet(s) configured. Manage them later in Settings.")
                    .font(.caption)
                    .foregroundColor(.green)
            }
        }
    }

    var vocabularyStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "text.book.closed.fill")
                .font(.system(size: 52))
                .foregroundStyle(LinearGradient(colors: [KM.accent, KM.salmon], startPoint: .topLeading, endPoint: .bottomTrailing))

            Text("Custom Vocabulary")
                .font(.title)
                .fontWeight(.bold)

            Text("Add words and phrases that should be preserved in post-processing.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 8) {
                Text("Vocabulary")
                    .font(.headline)

                TextEditor(text: $customVocabularyInput)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 130)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                    )

                Text("Separate entries with commas, new lines, or semicolons.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    var launchAtLoginStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "sunrise.fill")
                .font(.system(size: 52))
                .foregroundStyle(LinearGradient(colors: [KM.accent, KM.salmon], startPoint: .topLeading, endPoint: .bottomTrailing))

            Text("Launch at Login")
                .font(.title)
                .fontWeight(.bold)

            Text("Start FlowKeys automatically when you log in so it's always ready.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Image(systemName: "sunrise.fill")
                    .frame(width: 24)
                    .foregroundColor(.blue)
                Toggle("Launch FlowKeys at login", isOn: $appState.launchAtLogin)
            }
            .padding(12)
            .background(KM.surfaceHi)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(KM.outline, lineWidth: 1))
        }
    }

    var testTranscriptionStep: some View {
        VStack(spacing: 20) {
            VStack(spacing: 4) {
                Picker("Microphone:", selection: $appState.selectedMicrophoneID) {
                    Text("System Default").tag("default")
                    ForEach(appState.availableMicrophones) { device in
                        Text(device.name).tag(device.uid)
                    }
                }
                .frame(maxWidth: 340)

                Text("You can change this later in the menu bar or settings.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Group {
                switch testPhase {
                case .idle:
                    VStack(spacing: 20) {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                            .scaleEffect(testMicPulsing ? 1.15 : 1.0)
                            .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: testMicPulsing)

                        Text("Let's Try It Out!")
                            .font(.title)
                            .fontWeight(.bold)

                        Text(testShortcutPrompt)
                            .font(.headline)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(10)

                        Text("Say anything — a sentence or two is perfect.")
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }

                case .recording:
                    VStack(spacing: 20) {
                        ZStack {
                            Circle()
                                .fill(Color.blue.opacity(0.65))
                                .frame(width: 100, height: 100)

                            Circle()
                                .stroke(Color.blue.opacity(0.8), lineWidth: 3)
                                .frame(width: 100, height: 100)
                                .shadow(color: .blue.opacity(0.5), radius: 10)

                            PillWaveformView(audioLevel: testAudioLevel)
                        }

                        Text("Listening...")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                    }

                case .transcribing:
                    VStack(spacing: 20) {
                        InlineTranscribingDots()

                        Text("Transcribing...")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                    }

                case .done:
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.green)

                        if let error = testError {
                            Text("Something went wrong")
                                .font(.title2)
                                .fontWeight(.semibold)

                            Text(error)
                                .font(.callout)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)

                            Text(retryShortcutPrompt)
                                .font(.callout)
                                .foregroundColor(.secondary)
                        } else if testTranscript.isEmpty {
                            Text("No speech detected")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)

                            Text(retryShortcutPrompt)
                                .font(.callout)
                                .foregroundColor(.secondary)
                        } else {
                            Text("Perfect — FlowKeys is ready to go.")
                                .font(.title2)
                                .fontWeight(.semibold)

                            Text(testTranscript)
                                .font(.body)
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(nsColor: .controlBackgroundColor))
                                .cornerRadius(10)
                                .transition(.move(edge: .bottom).combined(with: .opacity))

                            Text(retryShortcutPrompt)
                                .font(.callout)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .transition(.opacity)
            .id(testPhase)

            Spacer()
        }
        .onAppear {
            appState.refreshAvailableMicrophones()
            testMicPulsing = true
            startTestHotkeyMonitoring()
        }
        .onDisappear {
            stopTestHotkeyMonitoring()
        }
    }

    var readyStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)

            Text("You're All Set!")
                .font(.title)
                .fontWeight(.bold)

            Text("FlowKeys lives in your menu bar.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 12) {
                if appState.hasEnabledHoldShortcut {
                    HowToRow(icon: "keyboard", text: "Hold \(appState.holdShortcut.displayName) to record")
                }
                if appState.hasEnabledToggleShortcut {
                    HowToRow(icon: "switch.2", text: "Tap \(appState.toggleShortcut.displayName) to start and stop")
                }
                if appState.hasEnabledHoldShortcut && appState.hasEnabledToggleShortcut {
                    HowToRow(icon: "arrow.triangle.branch", text: "While holding, press the toggle shortcut to latch on")
                }
                HowToRow(icon: "doc.on.clipboard", text: "Text is typed at your cursor & copied")
            }
            .padding(.top, 10)
        }
    }

    var stepIndicator: some View {
        // Hidden — step progress is shown as pill dots at top
        EmptyView()
    }

    private func providerCard(_ provider: TranscriptionProvider) -> some View {
        let isActive = selectedProvider == provider
        return Button {
            selectedProvider = provider
            apiKeyInput = appState.apiKey(for: provider)
            keyValidationError = nil
        } label: {
            HStack(alignment: .center, spacing: 12) {
                // Check indicator
                ZStack {
                    Circle()
                        .stroke(isActive ? KM.accent : KM.outline, lineWidth: 1.5)
                        .frame(width: 22, height: 22)
                    if isActive {
                        Circle().fill(KM.accent).frame(width: 22, height: 22)
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(provider.displayName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(isActive ? KM.onSurface : KM.onSurface.opacity(0.6))
                    Text(provider.shortDescription)
                        .font(.system(size: 11))
                        .foregroundColor(KM.muted)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 0)
            }
            .padding(14)
            .background(isActive ? KM.accent.opacity(0.1) : KM.surfaceHi)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isActive ? KM.accent : KM.outline, lineWidth: isActive ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isActive)
    }

    private var canContinueFromCurrentStep: Bool {
        switch currentStep {
        case .provider:
            return true
        case .apiKey:
            let key = apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
            return selectedProvider.keyLikelyValidFormat(key)
        case .micPermission:
            return micPermissionGranted
        case .accessibility:
            return accessibilityGranted
        case .screenRecording:
            return appState.hasScreenRecordingPermission
        case .testTranscription:
            return testPhase == .done && !testTranscript.isEmpty && testError == nil
        default:
            return true
        }
    }

    private var testShortcutPrompt: String {
        switch (appState.hasEnabledHoldShortcut, appState.hasEnabledToggleShortcut) {
        case (true, true):
            return "Hold \(appState.holdShortcut.displayName) or tap \(appState.toggleShortcut.displayName)"
        case (true, false):
            return "Hold \(appState.holdShortcut.displayName)"
        case (false, true):
            return "Tap \(appState.toggleShortcut.displayName)"
        case (false, false):
            return "Use Start Dictating from the menu bar"
        }
    }

    private var retryShortcutPrompt: String {
        "\(testShortcutPrompt) to try again"
    }

    // MARK: - Helpers

    private func instructionRow(number: String, text: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text(number + ".")
                .font(.subheadline.monospacedDigit())
                .foregroundColor(.secondary)
                .frame(width: 16, alignment: .trailing)
            Text(text)
                .font(.subheadline)
                .tint(.blue)
        }
    }

    // MARK: - Actions

    func validateAndContinue() {
        let key = apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard selectedProvider.keyLikelyValidFormat(key) else {
            keyValidationError = "The key format does not look valid for \(selectedProvider.displayName)."
            return
        }
        isValidatingKey = true
        keyValidationError = nil

        Task {
            let valid = await TranscriptionService.validateAPIKey(key, for: selectedProvider)
            await MainActor.run {
                isValidatingKey = false
                if valid {
                    appState.saveAPIKey(key, for: selectedProvider)
                    if selectedProvider == .claude {
                        appState.activeTranscriptionProvider = .claude
                        appState.activeLLMProvider = .claude
                    } else {
                        appState.activeTranscriptionProvider = selectedProvider
                        appState.activeLLMProvider = selectedProvider
                    }
                    withAnimation {
                        currentStep = nextStep(currentStep)
                    }
                } else {
                    keyValidationError = "Invalid API key. Please check and try again."
                }
            }
        }
    }

    func saveCustomVocabularyAndContinue() {
        appState.customVocabulary = customVocabularyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        withAnimation {
            currentStep = nextStep(currentStep)
        }
    }

    @ViewBuilder
    private func kmContinueButton(label: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 22)
                .padding(.vertical, 9)
                .background(Group {
                    if disabled {
                        KM.surfaceHi
                    } else {
                        LinearGradient(colors: [KM.accent, KM.accent.opacity(0.8)],
                                       startPoint: .leading, endPoint: .trailing)
                    }
                })
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .keyboardShortcut(.defaultAction)
    }

    private func previousStep(_ step: SetupStep) -> SetupStep {
        let previous = SetupStep(rawValue: step.rawValue - 1)
        return previous ?? .provider
    }

    private func nextStep(_ step: SetupStep) -> SetupStep {
        let next = SetupStep(rawValue: step.rawValue + 1)
        return next ?? .ready
    }

    func checkMicPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            micPermissionGranted = true
        default:
            break
        }
    }

    func requestMicPermission() {
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            DispatchQueue.main.async {
                micPermissionGranted = granted
            }
        }
    }

    func checkAccessibility() {
        accessibilityGranted = AXIsProcessTrusted()
    }

    func startAccessibilityPolling() {
        accessibilityTimer?.invalidate()
        accessibilityTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            DispatchQueue.main.async {
                checkAccessibility()
            }
        }
    }

    func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    func startScreenRecordingPolling() {
        screenRecordingTimer?.invalidate()
        screenRecordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            DispatchQueue.main.async {
                appState.hasScreenRecordingPermission = CGPreflightScreenCaptureAccess()
            }
        }
    }

    // MARK: - Test Transcription

    private func startTestHotkeyMonitoring() {
        testHotkeyHarness.onAction = { action in
            switch action {
            case .start:
                guard testPhase == .idle || testPhase == .done else { return }
                if testPhase == .done { resetTest() }
                do {
                    let recorder = AudioRecorder()
                    try recorder.startRecording(deviceUID: appState.selectedMicrophoneID)
                    testAudioRecorder = recorder
                    testAudioLevelCancellable = recorder.$audioLevel
                        .receive(on: DispatchQueue.main)
                        .sink { level in testAudioLevel = level }
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        testPhase = .recording
                    }
                } catch {
                    testHotkeyHarness.resetSession()
                    testError = error.localizedDescription
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        testPhase = .done
                    }
                }

            case .stop:
                guard testPhase == .recording, let recorder = testAudioRecorder else { return }
                let fileURL = recorder.stopRecording()
                testAudioLevelCancellable?.cancel()
                testAudioLevelCancellable = nil
                testAudioLevel = 0.0
                testHotkeyHarness.isTranscribing = true

                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    testPhase = .transcribing
                }

                guard let url = fileURL else {
                    testHotkeyHarness.isTranscribing = false
                    testError = "No audio file was created."
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        testPhase = .done
                    }
                    return
                }

                Task {
                    do {
                        let service = TranscriptionService(
                            provider: appState.activeTranscriptionProvider,
                            keyStore: appState.apiKeyStore,
                            forceHTTP2: appState.forceHTTP2Transcription,
                            languageMode: appState.languageMode
                        )
                        let transcript = try await service.transcribe(fileURL: url)
                        await MainActor.run {
                            testHotkeyHarness.isTranscribing = false
                            testTranscript = transcript
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                                testPhase = .done
                            }
                        }
                    } catch {
                        await MainActor.run {
                            testHotkeyHarness.isTranscribing = false
                            testError = error.localizedDescription
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                                testPhase = .done
                            }
                        }
                    }
                    recorder.cleanup()
                }

            case .switchedToToggle:
                break
            }
        }

        testHotkeyHarness.start(configuration: ShortcutConfiguration(
            hold: appState.holdShortcut,
            toggle: appState.toggleShortcut
        ), startDelay: appState.shortcutStartDelay)
    }

    private func stopTestHotkeyMonitoring() {
        testHotkeyHarness.stop()
        testAudioLevelCancellable?.cancel()
        testAudioLevelCancellable = nil
        if let recorder = testAudioRecorder, recorder.isRecording {
            _ = recorder.stopRecording()
            recorder.cleanup()
        }
        testAudioRecorder = nil
    }

    private func resetTest() {
        testPhase = .idle
        testTranscript = ""
        testError = nil
        testAudioLevel = 0.0
        testMicPulsing = true
        testHotkeyHarness.isTranscribing = false
        testHotkeyHarness.resetSession()
        if let recorder = testAudioRecorder {
            if recorder.isRecording { _ = recorder.stopRecording() }
            recorder.cleanup()
            testAudioRecorder = nil
        }
    }
}

struct GitHubRepoInfo: Decodable {
    let stargazersCount: Int

    private enum CodingKeys: String, CodingKey {
        case stargazersCount = "stargazers_count"
    }
}

struct GitHubStarRecord: Decodable, Identifiable {
    let user: GitHubStarUser
    var id: Int { user.id }
}

struct GitHubStarUser: Decodable {
    let id: Int
    let login: String
    let avatarUrl: URL
    let htmlUrl: URL

    var avatarThumbnailUrl: URL {
        let separator = avatarUrl.absoluteString.contains("?") ? "&" : "?"
        return URL(string: avatarUrl.absoluteString + "\(separator)s=44") ?? avatarUrl
    }

    private enum CodingKeys: String, CodingKey {
        case id; case login
        case avatarUrl = "avatar_url"
        case htmlUrl = "html_url"
    }
}

@MainActor
class GitHubMetadataCache: ObservableObject {
    static let shared = GitHubMetadataCache()

    @Published var starCount: Int?
    @Published var recentStargazers: [GitHubStarRecord] = []
    @Published var isLoading = true

    private var lastFetchDate: Date?
    private let cacheDuration: TimeInterval = 5 * 60
    private let repoAPIURL = URL(string: "https://api.github.com/repos/iamadarsha/FlowKeys")!

    private init() {}

    func fetchIfNeeded() async {
        if let lastFetch = lastFetchDate, Date().timeIntervalSince(lastFetch) < cacheDuration { return }
        isLoading = true
        do {
            let repoResult = try await URLSession.shared.data(from: repoAPIURL)
            guard let repoHTTP = repoResult.1 as? HTTPURLResponse,
                  (200..<300).contains(repoHTTP.statusCode) else {
                throw URLError(.badServerResponse)
            }
            let count = try JSONDecoder().decode(GitHubRepoInfo.self, from: repoResult.0).stargazersCount
            starCount = count
            isLoading = false
            lastFetchDate = Date()
        } catch {
            isLoading = false
        }
    }
}

private struct InlineTranscribingDots: View {
    @State private var activeDot = 0
    let timer = Timer.publish(every: 0.4, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Color.blue.opacity(activeDot == index ? 1.0 : 0.3))
                    .frame(width: 12, height: 12)
                    .scaleEffect(activeDot == index ? 1.3 : 1.0)
                    .animation(.easeInOut(duration: 0.3), value: activeDot)
            }
        }
        .onReceive(timer) { _ in
            activeDot = (activeDot + 1) % 3
        }
    }
}

struct HowToRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .frame(width: 24)
                .foregroundColor(.blue)
            Text(text)
                .foregroundColor(.secondary)
        }
    }
}
