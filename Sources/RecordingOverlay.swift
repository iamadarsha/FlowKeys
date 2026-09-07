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

    // Error pill is wider
    private let normalWidth: CGFloat  = 260
    private let errorWidth: CGFloat   = 340
    private let pillHeight: CGFloat   = 52
    private let pillCornerRadius: CGFloat = 26
    private let bottomOffset: CGFloat = 40

    var onStopButtonPressed: (() -> Void)?
    var onRetryButtonPressed: (() -> Void)?

    private var currentPillWidth: CGFloat {
        overlayState.phase == .error ? errorWidth : normalWidth
    }

    private var overlayAcceptsMouseEvents: Bool {
        (overlayState.phase == .recording && overlayState.recordingTriggerMode == .toggle)
            || overlayState.phase == .error
    }

    // MARK: Public API

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
        DispatchQueue.main.async { self.overlayState.audioLevel = level }
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

    func showTranscribing() {
        DispatchQueue.main.async {
            self.overlayState.phase = .transcribing
            self.overlayState.recordingStartDate = nil
            self.updatePillInteractivity()
        }
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
        DispatchQueue.main.async { self.dismissPill() }
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
            onRetryButtonPressed: { [weak self] in self?.onRetryButtonPressed?() }
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

    private let accentColor  = Color(red: 1.0,   green: 0.42,  blue: 0.21)   // #FF6B35
    private let greenColor   = Color(red: 0.325, green: 0.882, blue: 0.435)  // #53E16F
    private let bgColor      = Color(red: 0.051, green: 0.051, blue: 0.059)

    var body: some View {
        ZStack {
            // Glass background
            Capsule()
                .fill(bgColor.opacity(0.92))

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
        .shadow(color: .black.opacity(0.5), radius: 20, x: 0, y: 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    private var borderColors: [Color] {
        switch state.phase {
        case .done:  return [greenColor, greenColor.opacity(0.6)]
        case .error: return [Color(red: 1, green: 0.706, blue: 0.671), Color(red: 1, green: 0.706, blue: 0.671).opacity(0.6)]
        default:     return OverlayTheme.borderGradient(for: state.languageMode)
        }
    }

    private var borderWidth: CGFloat {
        state.phase == .done || state.phase == .error ? 1.5 : 1.0
    }

    private var accessibilityDescription: String {
        switch state.phase {
        case .initializing: return "FlowKeys: preparing to record"
        case .recording:    return "FlowKeys: recording audio"
        case .transcribing: return "FlowKeys: transcribing your speech"
        case .done:         return "FlowKeys: transcription complete"
        case .error:        return "FlowKeys: error — \(state.errorMessage)"
        }
    }

    @ViewBuilder
    private var contentView: some View {
        switch state.phase {
        case .done:
            doneContent
        case .error:
            errorContent
        default:
            recordingContent
        }
    }

    // MARK: Recording / Initializing / Transcribing

    private var recordingContent: some View {
        HStack(spacing: 10) {
            // Mic icon with gradient
            Image(systemName: state.phase == .transcribing ? "waveform" : "mic.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(colors: [accentColor, Color(red: 1, green: 0.71, blue: 0.62)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                )

            // Waveform bars
            if state.phase == .transcribing || state.phase == .initializing {
                ProcessingDotsView()
                    .frame(width: 44)
            } else {
                PillWaveformView(audioLevel: state.audioLevel)
                    .frame(width: 54)
            }

            // Timer or "Processing"
            if state.phase == .recording {
                RecordingTimerView(startDate: state.recordingStartDate ?? Date())
                    .foregroundColor(.white.opacity(0.8))
            } else {
                Text("Processing")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
            }

            // Mode tag
            if !state.activeModeName.isEmpty && state.phase == .recording {
                modeTag
            }

            Spacer(minLength: 0)

            // Stop button (toggle mode)
            if state.phase == .recording && state.recordingTriggerMode == .toggle {
                Button(action: onStopButtonPressed) {
                    Circle()
                        .fill(Color.red.opacity(0.85))
                        .frame(width: 28, height: 28)
                        .overlay(
                            Image(systemName: "stop.fill")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: state.phase)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: state.recordingTriggerMode)
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
            Text("Done")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
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
                    .background(
                        Capsule().fill(accentColor.opacity(0.85))
                    )
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Waveform (5 bars, orange accent)

struct PillWaveformView: View {
    let audioLevel: Float

    private static let barCount     = 5
    private static let multipliers: [CGFloat] = [0.5, 0.75, 1.0, 0.75, 0.5]
    private let barWidth: CGFloat   = 3
    private let barSpacing: CGFloat = 3
    private let minHeight: CGFloat  = 6
    private let maxHeight: CGFloat  = 26

    private let accentColor = Color(red: 1.0, green: 0.42, blue: 0.21)

    var body: some View {
        HStack(spacing: barSpacing) {
            ForEach(0..<Self.barCount, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(accentColor)
                    .frame(width: barWidth, height: barHeight(for: i))
                    .animation(.interpolatingSpring(stiffness: 480, damping: 22), value: audioLevel)
            }
        }
        .frame(height: maxHeight)
    }

    private func barHeight(for i: Int) -> CGFloat {
        let level = CGFloat(audioLevel)
        let amplitude = min(level * Self.multipliers[i], 1.0)
        return minHeight + (maxHeight - minHeight) * amplitude
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

// MARK: - Legacy Compat

struct TranscribingIndicatorView: View {
    var body: some View {
        ProcessingDotsView().frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
