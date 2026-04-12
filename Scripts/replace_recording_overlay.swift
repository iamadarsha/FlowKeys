import Foundation

let path = "Sources/RecordingOverlay.swift"
var content = try! String(contentsOfFile: path)

// 1. Change pillWidth
content = content.replacingOccurrences(of: "private let pillWidth: CGFloat = 280", with: "private var pillWidth: CGFloat { overlayState.phase == .error ? 340 : 260 }")

// 2. Adjust animations in RecordingOverlayManager
content = content.replacingOccurrences(of: """
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.2
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0.0
        }, completionHandler: {
""", with: """
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.2
            panel.animator().alphaValue = 0.0
        }, completionHandler: {
""")

let startAnim = """
        let targetFrame = pillFrame(on: screen)
        let startFrame = NSRect(
            x: targetFrame.origin.x,
            y: targetFrame.origin.y - 30,
            width: targetFrame.width,
            height: targetFrame.height
        )
"""
let newStartAnim = """
        let targetFrame = pillFrame(on: screen)
        let startFrame = NSRect(
            x: targetFrame.origin.x,
            y: targetFrame.origin.y - 20,
            width: targetFrame.width,
            height: targetFrame.height
        )
"""
content = content.replacingOccurrences(of: startAnim, with: newStartAnim)

// 3. Extract the PillOverlayView range
if let range = content.range(of: "// MARK: - Pill View") {
    let newViews = """
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
            ForEach(0..<Self.barCount, id: \\.self) { index in
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
"""
    content.replaceSubrange(range.lowerBound..<content.endIndex, with: newViews)
}

try! content.write(toFile: path, atomically: true, encoding: .utf8)
