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
}

enum OverlayPhase {
    case initializing
    case recording
    case transcribing
    case done
    case error
}

// MARK: - Theme Colors

struct OverlayTheme {
    static let saffron = NSColor(red: 1.0, green: 0.42, blue: 0.21, alpha: 1.0)        // #FF6B35
    static let saffronLight = NSColor(red: 1.0, green: 0.55, blue: 0.41, alpha: 1.0)    // #FF8C69
    static let indiaGreen = NSColor(red: 0.075, green: 0.533, blue: 0.031, alpha: 1.0)  // #138808
    static let neutralBlue = NSColor(red: 0.29, green: 0.565, blue: 0.886, alpha: 1.0)  // #4A90E2

    static func borderColor(for mode: UserLanguageMode) -> NSColor {
        switch mode {
        case .hinglish: return saffron
        case .pureHindi: return indiaGreen
        case .pureEnglish: return neutralBlue
        }
    }

    static func borderGradient(for mode: UserLanguageMode) -> [Color] {
        switch mode {
        case .hinglish: return [Color(saffron), Color(saffronLight)]
        case .pureHindi: return [Color(indiaGreen), Color(indiaGreen.withAlphaComponent(0.8))]
        case .pureEnglish: return [Color(neutralBlue), Color(neutralBlue.withAlphaComponent(0.8))]
        }
    }
}

// MARK: - Manager

final class RecordingOverlayManager {
    private var pillWindow: NSPanel?
    private let overlayState = RecordingOverlayState()
    private let pillWidth: CGFloat = 280
    private let pillHeight: CGFloat = 52
    private let pillCornerRadius: CGFloat = 26
    private let bottomOffset: CGFloat = 40

    var onStopButtonPressed: (() -> Void)?
    var onRetryButtonPressed: (() -> Void)?

    private var overlayAcceptsMouseEvents: Bool {
        (overlayState.phase == .recording && overlayState.recordingTriggerMode == .toggle)
            || overlayState.phase == .error
    }

    // MARK: Public API (preserves existing contract with AppState)

    func showInitializing(mode: RecordingTriggerMode = .hold) {
        DispatchQueue.main.async {
            self.overlayState.recordingTriggerMode = mode
            self.overlayState.phase = .initializing
            self.overlayState.audioLevel = 0
            self.overlayState.recordingStartDate = nil
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
        }
    }

    func updateLanguageMode(_ mode: UserLanguageMode) {
        DispatchQueue.main.async {
            self.overlayState.languageMode = mode
        }
    }

    func updateModeName(_ name: String, icon: String = "") {
        DispatchQueue.main.async {
            self.overlayState.activeModeName = name
            self.overlayState.activeModeIcon = icon
        }
    }

    func showTranscribing() {
        DispatchQueue.main.async {
            self.overlayState.phase = .transcribing
            self.overlayState.recordingStartDate = nil
            self.updatePillInteractivity()
        }
    }

    func slideUpToNotch(completion: @escaping () -> Void) {
        DispatchQueue.main.async {
            // The new pill is at the bottom — just show transcribing state
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
            self.dismissPill()
        }
    }

    // MARK: Private — Window Management

    private func showPill(animated: Bool) {
        guard let screen = NSScreen.main else { return }

        if let panel = pillWindow {
            panel.ignoresMouseEvents = !overlayAcceptsMouseEvents
            panel.contentView = makePillContent()
            if animated {
                let targetFrame = pillFrame(on: screen)
                NSAnimationContext.runAnimationGroup { ctx in
                    ctx.duration = 0.3
                    ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 1.0, 0.3, 1.0)
                    panel.animator().setFrame(targetFrame, display: true)
                    panel.animator().alphaValue = 1.0
                }
            } else {
                panel.setFrame(pillFrame(on: screen), display: true)
                panel.alphaValue = 1.0
            }
            panel.orderFrontRegardless()
            return
        }

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: pillWidth, height: pillHeight),
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
        panel.contentView = makePillContent()

        // Animate in: start scale (below screen) and fade
        let targetFrame = pillFrame(on: screen)
        let startFrame = NSRect(
            x: targetFrame.origin.x,
            y: targetFrame.origin.y - 30,
            width: targetFrame.width,
            height: targetFrame.height
        )
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
        guard let panel = pillWindow else {
            dismissPill()
            return
        }

        // Brief green flash then fade out
        overlayState.phase = .done
        panel.contentView = makePillContent()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.3
                panel.animator().alphaValue = 0.0
            }, completionHandler: {
                self.dismissPill()
            })
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
        panel.ignoresMouseEvents = !overlayAcceptsMouseEvents
        panel.contentView = makePillContent()
    }

    private func pillFrame(on screen: NSScreen) -> NSRect {
        let x = screen.frame.midX - pillWidth / 2
        // Position at bottom center, above the dock
        let visibleBottom = screen.visibleFrame.origin.y
        let y = visibleBottom + bottomOffset
        return NSRect(x: x, y: y, width: pillWidth, height: pillHeight)
    }

    private func makePillContent() -> NSView {
        let rootView = PillOverlayView(
            state: overlayState,
            cornerRadius: pillCornerRadius,
            onStopButtonPressed: { [weak self] in
                self?.onStopButtonPressed?()
            },
            onRetryButtonPressed: { [weak self] in
                self?.onRetryButtonPressed?()
            }
        )
        .frame(width: pillWidth, height: pillHeight)

        let hosting = NSHostingView(rootView: rootView)
        hosting.frame = NSRect(x: 0, y: 0, width: pillWidth, height: pillHeight)
        hosting.autoresizingMask = [.width, .height]
        return hosting
    }
}

// MARK: - Pill View (Dynamic Island–inspired)

struct PillOverlayView: View {
    @ObservedObject var state: RecordingOverlayState
    let cornerRadius: CGFloat
    let onStopButtonPressed: () -> Void
    let onRetryButtonPressed: () -> Void

    var body: some View {
        ZStack {
            // Background: dark glass
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color.black.opacity(0.65))
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(.ultraThinMaterial)
                )
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))

            // Gradient border based on language mode
            RoundedRectangle(cornerRadius: cornerRadius)
                .strokeBorder(
                    LinearGradient(
                        colors: borderColors,
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    lineWidth: borderWidth
                )

            // Content
            contentView
                .padding(.horizontal, 12)
        }
        .shadow(color: .black.opacity(0.4), radius: 16, x: 0, y: 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    private var borderColors: [Color] {
        switch state.phase {
        case .done:
            return [Color.green, Color.green.opacity(0.7)]
        case .error:
            return [Color.red, Color.red.opacity(0.7)]
        default:
            return OverlayTheme.borderGradient(for: state.languageMode)
        }
    }

    private var borderWidth: CGFloat {
        state.phase == .done || state.phase == .error ? 2.0 : 1.0
    }

    private var accessibilityDescription: String {
        switch state.phase {
        case .initializing: return "FlowKeys: preparing to record"
        case .recording: return "FlowKeys: recording audio"
        case .transcribing: return "FlowKeys: transcribing your speech"
        case .done: return "FlowKeys: transcription complete"
        case .error: return "FlowKeys: error occurred — \(state.errorMessage)"
        }
    }

    @ViewBuilder
    private var contentView: some View {
        if state.phase == .error {
            errorContent
        } else if state.phase == .done {
            doneContent
        } else {
            recordingContent
        }
    }

    // MARK: Recording State Content
    private var recordingContent: some View {
        HStack(spacing: 8) {
            // Language badge
            languageBadge

            Spacer(minLength: 4)

            // Waveform or initializing dots
            Group {
                if state.phase == .initializing || state.phase == .transcribing {
                    ProcessingDotsView()
                        .transition(.opacity)
                } else {
                    PillWaveformView(audioLevel: state.audioLevel)
                        .transition(.opacity)
                }
            }
            .frame(width: 60)

            Spacer(minLength: 4)

            // Timer or processing indicator
            if state.phase == .recording {
                RecordingTimerView(startDate: state.recordingStartDate ?? Date())
            } else {
                Text("...")
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.6))
            }

            // Mode tag (if active)
            if !state.activeModeName.isEmpty, state.phase == .recording {
                modeTag
            }

            // Stop button for toggle mode
            if state.phase == .recording && state.recordingTriggerMode == .toggle {
                Button(action: onStopButtonPressed) {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(Color.red.opacity(0.85)))
                }
                .buttonStyle(.plain)
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: state.phase)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: state.recordingTriggerMode)
    }

    // MARK: Language Badge
    private var languageBadge: some View {
        Text(languageBadgeText)
            .font(.system(size: 11, weight: .semibold, design: .monospaced))
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(OverlayTheme.borderColor(for: state.languageMode)).opacity(0.3))
            )
            .fixedSize()
    }

    private var languageBadgeText: String {
        switch state.languageMode {
        case .hinglish: return "MIX🇮🇳"
        case .pureHindi: return "HI🇮🇳"
        case .pureEnglish: return "EN🇺🇸"
        }
    }

    // MARK: Mode Tag
    private var modeTag: some View {
        HStack(spacing: 2) {
            if !state.activeModeIcon.isEmpty {
                Text(state.activeModeIcon)
                    .font(.system(size: 9))
            }
            Text(state.activeModeName)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .lineLimit(1)
        }
        .foregroundColor(.white.opacity(0.6))
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(.white.opacity(0.08))
        )
        .fixedSize()
    }

    // MARK: Done State
    private var doneContent: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.green)
            Text("Done")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
        }
    }

    // MARK: Error State
    private var errorContent: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.yellow)

            Text(state.errorMessage)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .lineLimit(2)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: onRetryButtonPressed) {
                Text("Retry")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.blue.opacity(0.85)))
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Pill Waveform (7 bars, spring animated)

struct PillWaveformView: View {
    let audioLevel: Float

    private static let barCount = 7
    private static let multipliers: [CGFloat] = [0.35, 0.55, 0.8, 1.0, 0.8, 0.55, 0.35]
    private let barWidth: CGFloat = 3
    private let barSpacing: CGFloat = 4
    private let minHeight: CGFloat = 8
    private let maxHeight: CGFloat = 28

    var body: some View {
        HStack(spacing: barSpacing) {
            ForEach(0..<Self.barCount, id: \.self) { index in
                Capsule()
                    .fill(barColor(for: index))
                    .frame(width: barWidth, height: barHeight(for: index))
                    .animation(
                        .interpolatingSpring(stiffness: 500, damping: 25),
                        value: audioLevel
                    )
            }
        }
        .frame(height: maxHeight)
    }

    private func barHeight(for index: Int) -> CGFloat {
        let level = CGFloat(audioLevel)
        let amplitude = min(level * Self.multipliers[index], 1.0)
        return minHeight + (maxHeight - minHeight) * amplitude
    }

    private func barColor(for index: Int) -> Color {
        let level = CGFloat(audioLevel)
        let activity = level * Self.multipliers[index]
        return activity > 0.1 ? .white : .white.opacity(0.3)
    }
}

// MARK: - Processing Dots

struct ProcessingDotsView: View {
    @State private var activeDot = 0
    @State private var timer: Timer?

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(.white.opacity(activeDot == index ? 0.9 : 0.25))
                    .frame(width: 6, height: 6)
                    .scaleEffect(activeDot == index ? 1.2 : 1.0)
                    .animation(.easeInOut(duration: 0.4), value: activeDot)
            }
        }
        .onAppear {
            timer?.invalidate()
            timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
                DispatchQueue.main.async {
                    activeDot = (activeDot + 1) % 3
                }
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
                    DispatchQueue.main.async {
                        elapsed = Date().timeIntervalSince(startDate)
                    }
                }
            }
            .onDisappear {
                timer?.invalidate()
                timer = nil
            }
    }

    private var formattedTime: String {
        let totalSeconds = Int(elapsed)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Legacy Compat (TranscribingIndicatorView)

struct TranscribingIndicatorView: View {
    var body: some View {
        ProcessingDotsView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
