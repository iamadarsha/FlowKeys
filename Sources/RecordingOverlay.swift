import SwiftUI
import AppKit

// MARK: - State

final class RecordingOverlayState: ObservableObject {
    @Published var phase: OverlayPhase = .recording
    @Published var audioLevel: Float = 0.0
    @Published var recordingTriggerMode: RecordingTriggerMode = .hold
    @Published var errorMessage: String = ""
    @Published var languageMode: UserLanguageMode = .pureEnglish
    @Published var activeModeName: String = ""
    @Published var activeModeIcon: String = ""
    @Published var recordingStartDate: Date? = nil
    @Published var transcribeProgress: Int = -1
    /// Live interim hypothesis shown in the pill's centre zone (optional).
    @Published var interimText: String = ""
    /// Whisper-Mode low-decibel gain is boosting the signal.
    @Published var whisperGainActive: Bool = false
    /// Offline model provisioning: (name, percent 0–100). Empty name = inactive.
    @Published var downloadModelName: String = ""
    @Published var downloadPercent: Int = 0
    /// Command Mode ("rewrite selection by voice") — shows the selection preview
    /// instead of the timer while the instruction is being spoken.
    @Published var commandModeActive: Bool = false
    @Published var commandSelectionPreview: String = ""
}

enum OverlayPhase {
    case initializing
    case recording
    case paused          // VAD detected a silence — audio eased to a flat line
    case transcribing
    case cleaning        // post-process / LLM polish sweep
    case downloadingModel
    case micPermission
    case done
    case error
}

// MARK: - Theme Colors

struct OverlayTheme {
    static let accent      = NSColor(red: 1.0,   green: 0.42,  blue: 0.21,  alpha: 1.0) // #FF6B35
    static let salmon      = NSColor(red: 1.0,   green: 0.71,  blue: 0.62,  alpha: 1.0) // #FFB59D
    static let green       = NSColor(red: 0.325, green: 0.882, blue: 0.435, alpha: 1.0) // #53E16F
    static let pillBg      = NSColor(red: 0.051, green: 0.051, blue: 0.059, alpha: 0.92)

    static let bengaliGreen = NSColor(red: 0.043, green: 0.451, blue: 0.271, alpha: 1.0) // #0B7345

    static func borderColor(for mode: UserLanguageMode) -> NSColor {
        switch mode {
        case .hinglish:    return accent
        case .pureHindi:   return NSColor(red: 0.075, green: 0.533, blue: 0.031, alpha: 1.0)
        case .pureEnglish: return NSColor(red: 0.29,  green: 0.565, blue: 0.886, alpha: 1.0)
        case .pureBengali, .banglish: return bengaliGreen
        }
    }

    static func borderGradient(for mode: UserLanguageMode) -> [Color] {
        switch mode {
        case .hinglish:
            return [Color(accent), Color(salmon)]
        case .pureHindi:
            return [Color(red: 0.075, green: 0.533, blue: 0.031),
                    Color(red: 0.075, green: 0.533, blue: 0.031).opacity(0.7)]
        case .pureEnglish:
            return [Color(red: 0.29, green: 0.565, blue: 0.886),
                    Color(red: 0.29, green: 0.565, blue: 0.886).opacity(0.7)]
        case .pureBengali, .banglish:
            return [Color(bengaliGreen), Color(bengaliGreen).opacity(0.65)]
        }
    }
}

// MARK: - Manager

final class RecordingOverlayManager {
    private var pillWindow: NSPanel?
    private let overlayState = RecordingOverlayState()

    // Error / permission pills are wider
    private let normalWidth: CGFloat  = 264
    private let wideWidth: CGFloat    = 344
    private let pillHeight: CGFloat   = 52
    private let pillCornerRadius: CGFloat = 26
    private let bottomOffset: CGFloat = 40

    var onStopButtonPressed: (() -> Void)?
    var onRetryButtonPressed: (() -> Void)?
    var onEnableMicPressed: (() -> Void)?

    private var currentPillWidth: CGFloat {
        switch overlayState.phase {
        case .error, .micPermission: return wideWidth
        case .recording where overlayState.commandModeActive: return wideWidth
        default:                     return normalWidth
        }
    }

    private var overlayAcceptsMouseEvents: Bool {
        (overlayState.phase == .recording && overlayState.recordingTriggerMode == .toggle)
            || overlayState.phase == .error
            || overlayState.phase == .micPermission
    }

    // MARK: Public API

    func showInitializing(mode: RecordingTriggerMode = .hold) {
        DispatchQueue.main.async {
            self.overlayState.recordingTriggerMode = mode
            self.overlayState.phase = .initializing
            self.overlayState.audioLevel = 0
            self.overlayState.interimText = ""
            self.overlayState.recordingStartDate = nil
            self.showPill(animated: true)
        }
    }

    /// Command Mode listening — capturing a spoken edit for the given selection.
    func showCommandListening(selection: String, mode: RecordingTriggerMode = .toggle) {
        DispatchQueue.main.async {
            self.overlayState.commandModeActive = true
            self.overlayState.commandSelectionPreview = String(selection.prefix(120))
            self.overlayState.recordingTriggerMode = mode
            self.overlayState.phase = .recording
            self.overlayState.audioLevel = 0
            if self.overlayState.recordingStartDate == nil {
                self.overlayState.recordingStartDate = Date()
            }
            self.showPill(animated: true)
        }
    }

    func showRecording(mode: RecordingTriggerMode = .hold) {
        DispatchQueue.main.async {
            self.overlayState.recordingTriggerMode = mode
            self.overlayState.phase = .recording
            self.overlayState.audioLevel = 0
            if self.overlayState.recordingStartDate == nil {
                self.overlayState.recordingStartDate = Date()
            }
            self.showPill(animated: true)
        }
    }

    func transitionToRecording(mode: RecordingTriggerMode = .hold) {
        DispatchQueue.main.async {
            self.overlayState.recordingTriggerMode = mode
            self.overlayState.phase = .recording
            if self.overlayState.recordingStartDate == nil {
                self.overlayState.recordingStartDate = Date()
            }
            self.updatePillInteractivity()
        }
    }

    func setRecordingTriggerMode(_ mode: RecordingTriggerMode, animated: Bool) {
        DispatchQueue.main.async {
            self.overlayState.recordingTriggerMode = mode
            self.updatePillInteractivity()
        }
    }

    func updateAudioLevel(_ level: Float) {
        DispatchQueue.main.async {
            self.overlayState.audioLevel = level
            // Auto-recover from a VAD pause when the speaker resumes.
            if self.overlayState.phase == .paused && level > 0.08 {
                self.overlayState.phase = .recording
            }
        }
    }

    func updateLanguageMode(_ mode: UserLanguageMode) {
        DispatchQueue.main.async { self.overlayState.languageMode = mode }
    }

    func updateModeName(_ name: String, icon: String = "") {
        DispatchQueue.main.async {
            self.overlayState.activeModeName = name
            self.overlayState.activeModeIcon = icon
        }
    }

    /// Live interim hypothesis (streaming preview). Pass "" to clear.
    func updateInterim(_ text: String) {
        DispatchQueue.main.async { self.overlayState.interimText = text }
    }

    func setWhisperGain(_ active: Bool) {
        DispatchQueue.main.async { self.overlayState.whisperGainActive = active }
    }

    /// VAD detected a sustained silence.
    func showPaused() {
        DispatchQueue.main.async {
            guard self.overlayState.phase == .recording else { return }
            self.overlayState.phase = .paused
            self.updatePillInteractivity()
        }
    }

    func showTranscribing() {
        DispatchQueue.main.async {
            self.overlayState.phase = .transcribing
            self.overlayState.recordingStartDate = nil
            self.updatePillInteractivity()
        }
    }

    /// Post-process / LLM cleanup sweep.
    func showCleaning() {
        DispatchQueue.main.async {
            self.overlayState.phase = .cleaning
            self.overlayState.recordingStartDate = nil
            self.updatePillInteractivity()
        }
    }

    /// Offline model provisioning progress (0–100). Pass percent < 0 to leave.
    func showModelDownload(name: String, percent: Int) {
        DispatchQueue.main.async {
            if percent < 0 {
                if self.overlayState.phase == .downloadingModel { self.dismissPill() }
                return
            }
            self.overlayState.downloadModelName = name
            self.overlayState.downloadPercent = max(0, min(100, percent))
            self.overlayState.phase = .downloadingModel
            self.showPill(animated: true)
        }
    }

    func showMicPermission() {
        DispatchQueue.main.async {
            self.overlayState.phase = .micPermission
            self.overlayState.recordingStartDate = nil
            self.showPill(animated: true)
        }
    }

    /// Local-transcription progress (0–100), or -1 to clear. No-op for cloud runs.
    func setTranscribeProgress(_ percent: Int) {
        DispatchQueue.main.async { self.overlayState.transcribeProgress = percent }
    }

    func slideUpToNotch(completion: @escaping () -> Void) {
        DispatchQueue.main.async {
            self.overlayState.phase = .transcribing
            self.overlayState.recordingStartDate = nil
            completion()
        }
    }

    func showDone() {
        DispatchQueue.main.async {
            self.overlayState.phase = .done
            self.flashDone()
        }
    }

    func showError(message: String) {
        DispatchQueue.main.async {
            self.overlayState.errorMessage = message
            self.overlayState.phase = .error
            self.overlayState.recordingStartDate = nil
            self.showPill(animated: true)
        }
    }

    func dismiss() {
        DispatchQueue.main.async {
            self.overlayState.interimText = ""
            self.overlayState.whisperGainActive = false
            self.overlayState.downloadModelName = ""
            self.overlayState.commandModeActive = false
            self.overlayState.commandSelectionPreview = ""
            self.dismissPill()
        }
    }

    // MARK: Private — Window Management

    private func showPill(animated: Bool) {
        guard let screen = NSScreen.main else { return }
        let w = currentPillWidth

        if let panel = pillWindow {
            panel.ignoresMouseEvents = !overlayAcceptsMouseEvents
            panel.contentView = makePillContent(width: w)
            let targetFrame = pillFrame(on: screen, width: w)
            if animated {
                NSAnimationContext.runAnimationGroup { ctx in
                    ctx.duration = 0.3
                    ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 1.0, 0.3, 1.0)
                    panel.animator().setFrame(targetFrame, display: true)
                    panel.animator().alphaValue = 1.0
                }
            } else {
                panel.setFrame(targetFrame, display: true)
                panel.alphaValue = 1.0
            }
            panel.orderFrontRegardless()
            return
        }

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: w, height: pillHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.level = .floating
        panel.ignoresMouseEvents = !overlayAcceptsMouseEvents
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary]
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.contentView = makePillContent(width: w)

        let targetFrame = pillFrame(on: screen, width: w)
        let startFrame = NSRect(x: targetFrame.origin.x, y: targetFrame.origin.y - 24,
                                width: targetFrame.width, height: targetFrame.height)
        panel.setFrame(startFrame, display: true)
        panel.alphaValue = 0.0
        panel.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.35
            ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 1.0, 0.3, 1.0)
            panel.animator().setFrame(targetFrame, display: true)
            panel.animator().alphaValue = 1.0
        }

        pillWindow = panel
    }

    private func flashDone() {
        guard let panel = pillWindow else { dismissPill(); return }
        overlayState.phase = .done
        panel.contentView = makePillContent(width: currentPillWidth)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.3
                panel.animator().alphaValue = 0.0
            }, completionHandler: { self.dismissPill() })
        }
    }

    private func dismissPill() {
        guard let panel = pillWindow else { return }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.2
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0.0
        }, completionHandler: {
            panel.orderOut(nil)
            self.pillWindow = nil
        })
    }

    private func updatePillInteractivity() {
        guard let panel = pillWindow else { return }
        let w = currentPillWidth
        panel.ignoresMouseEvents = !overlayAcceptsMouseEvents
        panel.contentView = makePillContent(width: w)
        if let screen = NSScreen.main {
            panel.setFrame(pillFrame(on: screen, width: w), display: true)
        }
    }

    private func pillFrame(on screen: NSScreen, width: CGFloat) -> NSRect {
        let x = screen.frame.midX - width / 2
        let y = screen.visibleFrame.origin.y + bottomOffset
        return NSRect(x: x, y: y, width: width, height: pillHeight)
    }

    private func makePillContent(width: CGFloat) -> NSView {
        let rootView = PillOverlayView(
            state: overlayState,
            cornerRadius: pillCornerRadius,
            onStopButtonPressed: { [weak self] in self?.onStopButtonPressed?() },
            onRetryButtonPressed: { [weak self] in self?.onRetryButtonPressed?() },
            onEnableMicPressed:  { [weak self] in self?.onEnableMicPressed?() }
        )
        .frame(width: width, height: pillHeight)

        let hosting = NSHostingView(rootView: rootView)
        hosting.frame = NSRect(x: 0, y: 0, width: width, height: pillHeight)
        hosting.autoresizingMask = [.width, .height]
        return hosting
    }
}

// MARK: - Pill View

struct PillOverlayView: View {
    @ObservedObject var state: RecordingOverlayState
    let cornerRadius: CGFloat
    let onStopButtonPressed: () -> Void
    let onRetryButtonPressed: () -> Void
    var onEnableMicPressed: () -> Void = {}

    private let accentColor  = Color(red: 1.0,   green: 0.42,  blue: 0.21)   // #FF6B35
    private let greenColor   = Color(red: 0.325, green: 0.882, blue: 0.435)  // #53E16F
    private let bgColor      = Color(red: 0.051, green: 0.051, blue: 0.059)

    private var dialectColor: Color { state.languageMode.accentColor }

    private var isLive: Bool { state.phase == .recording || state.phase == .paused }

    var body: some View {
        ZStack {
            // Glass background
            Capsule()
                .fill(bgColor.opacity(0.92))
                .overlay(
                    Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1)
                        .blendMode(.plusLighter).opacity(0.5)
                )

            // Border
            Capsule()
                .strokeBorder(
                    LinearGradient(colors: borderColors, startPoint: .leading, endPoint: .trailing),
                    lineWidth: borderWidth
                )

            // Content
            contentView
                .padding(.horizontal, 14)
        }
        .kmHUDShadow()
        .kmAudioGlow(state.phase == .recording, color: state.languageMode == .hinglish ? accentColor : dialectColor)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    private var borderColors: [Color] {
        switch state.phase {
        case .done:            return [greenColor, greenColor.opacity(0.6)]
        case .error:           return [Color(red: 1, green: 0.706, blue: 0.671), Color(red: 1, green: 0.706, blue: 0.671).opacity(0.6)]
        case .micPermission:   return [Color(red: 1, green: 0.76, blue: 0.29), Color(red: 1, green: 0.76, blue: 0.29).opacity(0.5)]
        case .downloadingModel: return [accentColor, accentColor.opacity(0.5)]
        default:               return OverlayTheme.borderGradient(for: state.languageMode)
        }
    }

    private var borderWidth: CGFloat {
        switch state.phase {
        case .done, .error, .micPermission: return 1.5
        default: return 1.0
        }
    }

    private var accessibilityDescription: String {
        switch state.phase {
        case .initializing:     return "FlowKeys: preparing to record"
        case .recording:        return "FlowKeys: recording audio"
        case .paused:           return "FlowKeys: paused — waiting for speech"
        case .transcribing:     return "FlowKeys: transcribing your speech"
        case .cleaning:         return "FlowKeys: cleaning up the transcript"
        case .downloadingModel: return "FlowKeys: downloading \(state.downloadModelName), \(state.downloadPercent) percent"
        case .micPermission:    return "FlowKeys: microphone access needed"
        case .done:             return "FlowKeys: transcription complete"
        case .error:            return "FlowKeys: error — \(state.errorMessage)"
        }
    }

    @ViewBuilder
    private var contentView: some View {
        switch state.phase {
        case .done:             doneContent
        case .error:            errorContent
        case .micPermission:    micPermissionContent
        case .downloadingModel: downloadContent
        case .recording where state.commandModeActive: commandListeningContent
        default:                recordingContent
        }
    }

    // MARK: Command Mode — listening for the spoken edit

    private var commandListeningContent: some View {
        HStack(spacing: 10) {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(LinearGradient(colors: [accentColor, Color(red: 1, green: 0.71, blue: 0.62)],
                                                startPoint: .topLeading, endPoint: .bottomTrailing))

            VStack(alignment: .leading, spacing: 1) {
                Text("EDITING SELECTION")
                    .font(.system(size: 8, weight: .bold))
                    .tracking(0.9)
                    .foregroundColor(.white.opacity(0.4))
                Text(state.commandSelectionPreview)
                    .font(.system(size: 11))
                    .italic()
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // compact activity cue — the preview text is the priority here
            PillWaveformView(audioLevel: state.audioLevel, tint: dialectColor)
                .frame(width: 30)
                .clipped()

            KMLangBadge(mode: state.languageMode)

            if state.recordingTriggerMode == .toggle {
                Button(action: onStopButtonPressed) {
                    Circle().fill(Color.red.opacity(0.9)).frame(width: 26, height: 26)
                        .overlay(RoundedRectangle(cornerRadius: 2).fill(.white).frame(width: 8, height: 8))
                }
                .buttonStyle(.plain)
            }
        }
        .animation(Motion.snappy, value: state.phase)
    }

    // MARK: Recording / Initializing / Paused / Transcribing / Cleaning

    private var recordingContent: some View {
        HStack(spacing: 10) {
            // Leading glyph
            Image(systemName: leadingGlyph)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(colors: [accentColor, Color(red: 1, green: 0.71, blue: 0.62)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .symbolEffectPulseIfAvailable(active: state.phase == .initializing)

            // Visualiser
            Group {
                switch state.phase {
                case .transcribing where state.transcribeProgress > 0 && state.transcribeProgress < 100:
                    ProgressBarView(percent: state.transcribeProgress).frame(width: 52)
                case .transcribing, .initializing:
                    ProcessingDotsView().frame(width: 44)
                case .cleaning:
                    CleaningSweepView().frame(width: 52)
                case .paused:
                    PausedLineView().frame(width: 52)
                default:
                    PillWaveformView(audioLevel: state.audioLevel, tint: state.languageMode == .hinglish ? nil : dialectColor)
                }
            }

            // Centre text
            centreText

            // Trailing zone
            Spacer(minLength: 0)

            if state.whisperGainActive && isLive {
                whisperGainChip
            }

            if isLive && !state.activeModeName.isEmpty && state.interimText.isEmpty
                && !(state.whisperGainActive) {
                modeTag
            }

            // The stop button takes priority over the badge in the tight toggle layout.
            if isLive && !(state.phase == .recording && state.recordingTriggerMode == .toggle) {
                KMLangBadge(mode: state.languageMode)
            }

            // Stop button (toggle mode)
            if state.phase == .recording && state.recordingTriggerMode == .toggle {
                Button(action: onStopButtonPressed) {
                    Circle()
                        .fill(Color.red.opacity(0.9))
                        .frame(width: 26, height: 26)
                        .overlay(
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.white)
                                .frame(width: 8, height: 8)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .animation(Motion.snappy, value: state.phase)
        .animation(Motion.snappy, value: state.recordingTriggerMode)
        .animation(Motion.micro, value: state.whisperGainActive)
    }

    private var leadingGlyph: String {
        switch state.phase {
        case .transcribing: return "waveform"
        case .cleaning:     return "sparkles"
        case .paused:       return "pause.fill"
        default:            return "mic.fill"
        }
    }

    @ViewBuilder
    private var centreText: some View {
        switch state.phase {
        case .recording:
            if !state.interimText.isEmpty {
                Text(state.interimText)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.75))
                    .lineLimit(1)
                    .truncationMode(.head)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                RecordingTimerView(startDate: state.recordingStartDate ?? Date())
                    .foregroundColor(.white.opacity(0.8))
            }
        case .paused:
            Text("PAUSED")
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.2)
                .foregroundColor(.white.opacity(0.5))
        case .cleaning:
            Text("Cleaning syntax & fillers…")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
                .lineLimit(1)
        default:
            Text(state.transcribeProgress > 0 && state.transcribeProgress < 100
                 ? "Transcribing \(state.transcribeProgress)%"
                 : "Processing")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
                .monospacedDigit()
        }
    }

    private var whisperGainChip: some View {
        HStack(spacing: 3) {
            Image(systemName: "waveform.badge.mic").font(.system(size: 8))
            Text("Gain").font(.system(size: 9, weight: .semibold))
        }
        .foregroundColor(greenColor)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(greenColor.opacity(0.14))
        .clipShape(Capsule())
        .fixedSize()
        .help("Whisper Mode — boosting quiet speech")
    }

    private var modeTag: some View {
        HStack(spacing: 2) {
            if !state.activeModeIcon.isEmpty {
                Text(state.activeModeIcon).font(.system(size: 9))
            }
            Text(state.activeModeName)
                .font(.system(size: 10, weight: .medium))
                .lineLimit(1)
        }
        .foregroundColor(.white.opacity(0.55))
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        .fixedSize()
    }

    // MARK: Done

    private var doneContent: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(greenColor)
                .frame(width: 22, height: 22)
                .overlay(
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.black)
                )
            Text("Pasted to cursor")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    // MARK: Error

    private var errorContent: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 13))
                .foregroundColor(Color(red: 1, green: 0.71, blue: 0.62))

            Text(state.errorMessage)
                .font(.system(size: 11, weight: .medium))
                .lineLimit(2)
                .foregroundColor(.white.opacity(0.85))
                .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: onRetryButtonPressed) {
                Text("Retry")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(accentColor.opacity(0.9)))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: Mic permission

    private var micPermissionContent: some View {
        HStack(spacing: 8) {
            Image(systemName: "mic.slash.fill")
                .font(.system(size: 13))
                .foregroundColor(Color(red: 1, green: 0.76, blue: 0.29))

            Text("Microphone access needed")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.85))
                .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: onEnableMicPressed) {
                Text("Enable")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color(red: 1, green: 0.76, blue: 0.29)))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: Model download

    private var downloadContent: some View {
        HStack(spacing: 10) {
            DownloadRingView(percent: state.downloadPercent)
                .frame(width: 22, height: 22)
            Text("\(state.downloadModelName): \(state.downloadPercent)%")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.85))
                .monospacedDigit()
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Waveform (24 bars, thermal gradient, dialect-tinted)
//
// Per Design a2_speaking_waveform_deep_visual_study: exactly 24 bars, 2px wide,
// 3px gap, 1px squircle, 3px min / 26px max. Asymmetric ballistic envelope —
// 60ms attack (fast ease-out), 220ms release (fluid ease-in) — with ±1-bar
// Gaussian neighbour smoothing so the field flows like water. Rendered on a
// Canvas driven by TimelineView(.animation) for a jank-free 60fps.

struct PillWaveformView: View {
    let audioLevel: Float
    /// Optional dialect tint. `nil` keeps the default accent→salmon thermal gradient.
    var tint: Color? = nil

    // 20 bars keeps the field readable at the compact 52pt HUD-inset width
    // while preserving the a2 spec's ballistic feel.
    static let barCount = 20
    private let barWidth: CGFloat   = 1.6
    private let barSpacing: CGFloat = 1.1
    private let minHeight: CGFloat  = 3
    private let maxHeight: CGFloat  = 24

    private let accent = Color(red: 1.0, green: 0.42, blue: 0.21)   // #FF6B35
    private let salmon = Color(red: 1.0, green: 0.71, blue: 0.62)   // #FFB59D

    // Centre-weighted envelope — middle bars reach higher.
    private static let envelope: [CGFloat] = (0..<barCount).map { i in
        let x = CGFloat(i) / CGFloat(barCount - 1)
        return 0.4 + 0.6 * sin(x * .pi)
    }
    // Stable per-bar random phase so the field reads organic, not uniform.
    private static let phase: [CGFloat] = (0..<barCount).map { i in
        let v = sin(Double(i) * 12.9898 + 4.1) * 43758.5453
        return CGFloat(abs(v.truncatingRemainder(dividingBy: 1))) * 6.2831853
    }

    /// Bar physics live in a plain class so the Canvas draw closure can advance
    /// them in place without mutating SwiftUI state during a view update.
    private final class Field {
        var heights = [CGFloat](repeating: 0.06, count: PillWaveformView.barCount)
        var lastTime: Double = 0

        func step(dt: Double, t: Double, level: CGFloat) {
            let attackK  = CGFloat(1 - exp(-dt / Motion.attackDuration))
            let releaseK = CGFloat(1 - exp(-dt / Motion.releaseDuration))
            let n = PillWaveformView.barCount

            var target = [CGFloat](repeating: 0, count: n)
            for i in 0..<n {
                let idle = 0.05 + 0.04 * (0.5 + 0.5 * sin(t * 2.1 + PillWaveformView.phase[i]))
                let drive = level * PillWaveformView.envelope[i]
                    * (0.7 + 0.4 * sin(t * 6.0 + PillWaveformView.phase[i] * 2.0))
                target[i] = max(idle, min(1.0, drive))
            }
            var smoothed = target
            for i in 0..<n {
                let l = target[max(0, i - 1)]
                let r = target[min(n - 1, i + 1)]
                smoothed[i] = 0.25 * l + 0.5 * target[i] + 0.25 * r
            }
            for i in 0..<n {
                let k = smoothed[i] > heights[i] ? attackK : releaseK
                heights[i] += (smoothed[i] - heights[i]) * k
            }
        }
    }

    @State private var field = Field()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            Canvas { ctx, size in
                let now = timeline.date.timeIntervalSinceReferenceDate
                var dt = now - field.lastTime
                if dt <= 0 || dt > 0.1 { dt = 1.0 / 60.0 }
                field.lastTime = now
                field.step(dt: dt, t: now, level: CGFloat(max(0, min(1, audioLevel))))

                let topColor = tint ?? accent
                let botColor = tint.map { $0.opacity(0.55) } ?? salmon
                let totalW = CGFloat(Self.barCount) * barWidth + CGFloat(Self.barCount - 1) * barSpacing
                var x = max(0, (size.width - totalW) / 2)
                for i in 0..<Self.barCount {
                    let h = minHeight + (maxHeight - minHeight) * field.heights[i]
                    let rect = CGRect(x: x, y: (size.height - h) / 2, width: barWidth, height: h)
                    let path = Path(roundedRect: rect, cornerRadius: 1, style: .continuous)
                    ctx.fill(path, with: .linearGradient(
                        Gradient(colors: [topColor, botColor]),
                        startPoint: CGPoint(x: rect.midX, y: rect.minY),
                        endPoint: CGPoint(x: rect.midX, y: rect.maxY)))
                    x += barWidth + barSpacing
                }
            }
        }
        .frame(width: CGFloat(Self.barCount) * barWidth + CGFloat(Self.barCount - 1) * barSpacing,
               height: maxHeight)
        .clipped()
    }
}

// MARK: - Paused flat line (VAD silence)

struct PausedLineView: View {
    @State private var wobble: CGFloat = 0
    private let timer = Timer.publish(every: 1.0 / 20.0, on: .main, in: .common).autoconnect()
    var body: some View {
        Capsule()
            .fill(Color.white.opacity(0.25))
            .frame(height: 3)
            .scaleEffect(x: 1, y: 1 + 0.4 * sin(wobble), anchor: .center)
            .onReceive(timer) { _ in wobble += 0.18 }
    }
}

// MARK: - Cleaning sweep (sparkle glint across a stream line)

struct CleaningSweepView: View {
    @State private var x: CGFloat = 0
    private let timer = Timer.publish(every: 1.0 / 30.0, on: .main, in: .common).autoconnect()
    var body: some View {
        GeometryReader { geo in
            let track = max(1, geo.size.width - 14)
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.14)).frame(height: 3)
                Capsule()
                    .fill(Color(red: 1.0, green: 0.42, blue: 0.21))
                    .frame(width: 14, height: 3)
                    .offset(x: min(max(0, x), 1) * track)
            }
            .frame(maxHeight: .infinity, alignment: .center)
        }
        .clipShape(Capsule())
        .onReceive(timer) { _ in
            x += 0.045
            if x > 1 { x = 0 }
        }
    }
}

// MARK: - Progress bar (local transcription %)

struct ProgressBarView: View {
    let percent: Int
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.14)).frame(height: 3)
                Capsule()
                    .fill(Color(red: 1.0, green: 0.42, blue: 0.21))
                    .frame(width: geo.size.width * CGFloat(max(0, min(100, percent))) / 100, height: 3)
                    .animation(.easeOut(duration: 0.25), value: percent)
            }
            .frame(maxHeight: .infinity, alignment: .center)
        }
    }
}

// MARK: - Download ring

struct DownloadRingView: View {
    let percent: Int
    var body: some View {
        ZStack {
            Circle().stroke(Color.white.opacity(0.15), lineWidth: 2.5)
            Circle()
                .trim(from: 0, to: CGFloat(max(0, min(100, percent))) / 100)
                .stroke(Color(red: 1.0, green: 0.42, blue: 0.21),
                        style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.3), value: percent)
        }
    }
}

// MARK: - Processing Dots

struct ProcessingDotsView: View {
    @State private var activeDot = 0
    @State private var timer: Timer?

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Color(red: 1.0, green: 0.42, blue: 0.21).opacity(activeDot == i ? 1.0 : 0.25))
                    .frame(width: 5, height: 5)
                    .scaleEffect(activeDot == i ? 1.3 : 1.0)
                    .animation(.easeInOut(duration: 0.4), value: activeDot)
            }
        }
        .onAppear {
            timer?.invalidate()
            timer = Timer.scheduledTimer(withTimeInterval: 0.45, repeats: true) { _ in
                DispatchQueue.main.async { activeDot = (activeDot + 1) % 3 }
            }
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }
}

// MARK: - Recording Timer

struct RecordingTimerView: View {
    let startDate: Date
    @State private var elapsed: TimeInterval = 0
    @State private var timer: Timer?

    var body: some View {
        Text(formattedTime)
            .font(.system(size: 13, weight: .medium, design: .monospaced))
            .foregroundColor(.white.opacity(0.8))
            .fixedSize()
            .onAppear {
                timer?.invalidate()
                timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                    DispatchQueue.main.async { elapsed = Date().timeIntervalSince(startDate) }
                }
            }
            .onDisappear {
                timer?.invalidate()
                timer = nil
            }
    }

    private var formattedTime: String {
        let s = Int(elapsed)
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}

// MARK: - Symbol effect shim

private extension View {
    @ViewBuilder
    func symbolEffectPulseIfAvailable(active: Bool) -> some View {
        if #available(macOS 14.0, *), active {
            self.symbolEffect(.pulse, options: .repeating)
        } else {
            self
        }
    }
}

// MARK: - Legacy Compat

struct TranscribingIndicatorView: View {
    var body: some View {
        ProcessingDotsView().frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
