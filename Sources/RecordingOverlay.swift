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
    private var pillWidth: CGFloat { overlayState.phase == .error ? 340 : 260 }
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
            y: targetFrame.origin.y - 20,
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
            // Background: deep frosted glass
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color.black.opacity(0.75))
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(.ultraThinMaterial)
                )
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))

            // Main Content
            contentView
                .padding(.horizontal, 16)
        }
    }

    @ViewBuilder
    private var contentView: some View {
        if state.phase == .error {
            errorContent
        } else if state.phase == .done {
            doneContent
        } else if state.phase == .transcribing || state.phase == .initializing {
            transcribingContent
        } else {
            recordingContent
        }
    }

    // MARK: Recording State Content
    private var recordingContent: some View {
        HStack {
            // LEFT side: Pulsing Mic Icon
            MicPulsingView(audioLevel: state.audioLevel)
                .frame(width: 24, height: 24, alignment: .leading)
            
            Spacer()

            // CENTER: Waveform
            PillWaveformView(audioLevel: state.audioLevel)
            
            Spacer()

            // RIGHT side: Timer
            RecordingTimerView(startDate: state.recordingStartDate ?? Date())
                .frame(width: 36, alignment: .trailing)
        }
    }
    
    // MARK: Transcribing State Content
    private var transcribingContent: some View {
        HStack(spacing: 8) {
            ProgressView()
                .progressViewStyle(.circular)
                .controlSize(.small)
                .colorScheme(.dark)
            Text("Processing")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white)
        }
    }

    // MARK: Done State Content
    private var doneContent: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.green)
            Text("Done")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
        }
    }

    // MARK: Error State Content
    private var errorContent: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.red)

            Text(state.errorMessage)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .lineLimit(1)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: onRetryButtonPressed) {
                Text("Retry")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(.black)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.white))
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Pulsing Mic View
struct MicPulsingView: View {
    let audioLevel: Float
    
    var body: some View {
        Image(systemName: "mic.fill")
            .font(.system(size: 16))
            .foregroundColor(.white)
            .scaleEffect(1.0 + CGFloat(audioLevel) * 0.4)
            .animation(.interpolatingSpring(stiffness: 300, damping: 20), value: audioLevel)
    }
}

// MARK: - Pill Waveform (5 bars, white)
struct PillWaveformView: View {
    let audioLevel: Float

    private static let barCount = 5
    private static let multipliers: [CGFloat] = [0.4, 0.8, 1.0, 0.8, 0.4]
    private let barWidth: CGFloat = 3
    private let barSpacing: CGFloat = 4
    private let minHeight: CGFloat = 6
    private let maxHeight: CGFloat = 24

    var body: some View {
        HStack(spacing: barSpacing) {
            ForEach(0..<Self.barCount, id: \.self) { index in
                Capsule()
                    .fill(.white.opacity(isActive(for: index) ? 1.0 : 0.2))
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

    private func isActive(for index: Int) -> Bool {
        let level = CGFloat(audioLevel)
        return (level * Self.multipliers[index]) > 0.05
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
            .foregroundColor(.white.opacity(0.7))
            .onAppear {
                timer?.invalidate()
                timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                    let newElapsed = Date().timeIntervalSince(startDate)
                    if Int(newElapsed) != Int(self.elapsed) {
                        self.elapsed = newElapsed
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