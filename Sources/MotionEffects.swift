import SwiftUI

// ============================================================
// FILE: Sources/MotionEffects.swift
// FlowKeys — Kinetic Precision v2.2 native motion library
//
// Native SwiftUI recreations of the transitions.dev / thinking-orbs /
// border-beam visual language (orb loader, border glow, icon-swap,
// success-check, error-shake, spinning counter, dot-matrix loader).
// Zero new dependencies — same Canvas/TimelineView pattern already used
// by `PillWaveformView` (see RecordingOverlay.swift), same `KM.*` tokens
// and `Motion` curves as the rest of Kinetic Precision.
//
// Every component here is additive: nothing in this file changes an
// existing type's public API or an existing enum's case list.
// ============================================================

// MARK: - Orb (thinking / listening indicator)
//
// Nothing else in the codebase checked `accessibilityReduceMotion` before
// this file — every component below does, falling back to its static
// end-state instantly when the user has motion reduction on.

enum KMOrbState {
    case idle        // ambient breathing, nothing happening
    case listening   // actively capturing audio
    case working     // transcribing / initializing
    case solving     // cleanup / LLM polish pass
}

/// Small canvas-based orb — a handful of particles drifting on tilted orbits,
/// speed and tightness driven by `state`. Mirrors `PillWaveformView`'s
/// non-`@State` `Field`-class-mutated-inside-Canvas pattern so this can run
/// at 60fps without triggering SwiftUI view-update warnings.
struct KMOrb: View {
    var state: KMOrbState = .idle
    var gradient: LinearGradient = KM.accentGradient

    private static let particleCount = 5

    private final class Field {
        var lastTime: Double = 0
    }
    @State private var field = Field()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if reduceMotion {
            staticGlyph
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                Canvas { ctx, size in
                    let now = timeline.date.timeIntervalSinceReferenceDate
                    field.lastTime = now
                    let c = CGPoint(x: size.width / 2, y: size.height / 2)
                    let r = min(size.width, size.height) / 2

                    for i in 0..<Self.particleCount {
                        let phase = Double(i) / Double(Self.particleCount) * .pi * 2
                        let speed = speedMultiplier
                        let angle = now * speed + phase
                        let orbitR = r * (0.45 + 0.35 * sin(now * 0.6 + phase))
                        let x = c.x + CGFloat(cos(angle)) * orbitR
                        let y = c.y + CGFloat(sin(angle)) * orbitR * 0.62 // tilted ellipse
                        let dotR: CGFloat = size.width * 0.09
                        let rect = CGRect(x: x - dotR, y: y - dotR, width: dotR * 2, height: dotR * 2)
                        ctx.fill(Path(ellipseIn: rect), with: .color(dotColor(index: i).opacity(dotOpacity)))
                    }

                    // Soft core glow so the orb reads as one object, not loose dots.
                    let coreR = r * 0.28
                    let coreRect = CGRect(x: c.x - coreR, y: c.y - coreR, width: coreR * 2, height: coreR * 2)
                    ctx.fill(Path(ellipseIn: coreRect), with: .color(dotColor(index: 0).opacity(0.35)))
                }
            }
        }
    }

    private var speedMultiplier: Double {
        switch state {
        case .idle:      return 0.25
        case .listening: return 0.9
        case .working:   return 1.6
        case .solving:   return 1.1
        }
    }

    private var dotOpacity: Double {
        switch state {
        case .idle: return 0.55
        default:    return 0.9
        }
    }

    private func dotColor(index: Int) -> Color {
        index.isMultiple(of: 2) ? KM.accent : KM.steel
    }

    /// Reduced-motion / non-animated fallback — a plain filled orb, no drift.
    private var staticGlyph: some View {
        Circle().fill(gradient)
    }
}

// MARK: - Border beam

/// A traveling gradient glow around a view's border — native recreation of
/// the `border-beam` React component. Applied via `.kmBorderBeam(active:)`.
private struct KMBorderBeamModifier: ViewModifier {
    var active: Bool
    var cornerRadius: CGFloat = KM.rCard
    var lineWidth: CGFloat = 1.5
    @State private var rotation: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(KM.outline, lineWidth: 1)
            )
            .overlay {
                if active {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(
                            AngularGradient(
                                colors: [.clear, KM.accent, KM.steel, .clear],
                                center: .center,
                                angle: .degrees(rotation)
                            ),
                            lineWidth: lineWidth
                        )
                        .onAppear {
                            guard !reduceMotion else { return }
                            withAnimation(.linear(duration: 3.2).repeatForever(autoreverses: false)) {
                                rotation = 360
                            }
                        }
                }
            }
    }
}

extension View {
    /// Wraps this view (typically a `KMCard`) with a traveling indigo→steel
    /// beam along its border. Purely decorative — pass `active: false` to
    /// keep the static hairline only.
    func kmBorderBeam(active: Bool = true, cornerRadius: CGFloat = KM.rCard) -> some View {
        modifier(KMBorderBeamModifier(active: active, cornerRadius: cornerRadius))
    }
}

// MARK: - Success check (animated draw-in)

/// Replaces a static checkmark circle with a draw-in stroke animation.
/// Drop-in visual upgrade for `RecordingOverlay.doneContent`.
struct KMSuccessCheck: View {
    var size: CGFloat = 22
    var color: Color = KM.green
    @State private var progress: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Circle().fill(color)
            Path { path in
                path.move(to: CGPoint(x: size * 0.28, y: size * 0.52))
                path.addLine(to: CGPoint(x: size * 0.44, y: size * 0.68))
                path.addLine(to: CGPoint(x: size * 0.74, y: size * 0.32))
            }
            .trim(from: 0, to: progress)
            .stroke(Color.black, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        }
        .frame(width: size, height: size)
        .onAppear {
            if reduceMotion {
                progress = 1
            } else {
                withAnimation(.easeOut(duration: 0.32)) { progress = 1 }
            }
        }
    }
}

// MARK: - Error shake

private struct KMShakeModifier: ViewModifier {
    var trigger: Int
    @State private var offset: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .offset(x: offset)
            .onChange(of: trigger) { _ in
                guard !reduceMotion else { return }
                withAnimation(.linear(duration: 0.06).repeatCount(5, autoreverses: true)) {
                    offset = offset == 0 ? 6 : 0
                }
                // Settle back to zero once the shake sequence finishes.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
                    withAnimation(.easeOut(duration: 0.08)) { offset = 0 }
                }
            }
    }
}

extension View {
    /// Shakes horizontally each time `trigger` changes (e.g. an incrementing
    /// counter bumped whenever the overlay enters `.error`).
    func kmShake(trigger: Int) -> some View {
        modifier(KMShakeModifier(trigger: trigger))
    }
}

// MARK: - Spinning counter

/// Animates digit changes on a numeric label (e.g. GitHub star count).
/// Uses native `.contentTransition(.numericText())` where available;
/// falls back to an instant label swap on older macOS / reduced motion.
struct KMSpinningCounter: View {
    var value: Int
    var font: Font = .system(size: 12, weight: .semibold)
    var color: Color = KM.textPrimary
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if #available(macOS 14.0, *), !reduceMotion {
                Text(value.formatted())
                    .contentTransition(.numericText(value: Double(value)))
                    .animation(.snappy, value: value)
            } else {
                Text(value.formatted())
            }
        }
        .font(font)
        .foregroundColor(color)
        .monospacedDigit()
    }
}

// MARK: - Dot-matrix loader

/// Small dot-grid loader — a wave sweeps across a grid of dots rather than
/// three dots pulsing in place (`ProcessingDotsView`'s look). Same
/// `Timer.scheduledTimer` cycling pattern already used there.
struct KMDotMatrixLoader: View {
    var columns: Int = 5
    var rows: Int = 3
    var color: Color = KM.accent
    @State private var tick = 0
    @State private var timer: Timer?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 3) {
            ForEach(0..<rows, id: \.self) { row in
                HStack(spacing: 3) {
                    ForEach(0..<columns, id: \.self) { col in
                        let dist = abs(col - tick % (columns + 4))
                        let active = dist <= 1
                        Circle()
                            .fill(color.opacity(active ? 0.95 : 0.15))
                            .frame(width: 3, height: 3)
                    }
                }
                .offset(x: CGFloat(row.isMultiple(of: 2) ? 0 : 2))
            }
        }
        .onAppear {
            guard !reduceMotion else { return }
            timer?.invalidate()
            timer = Timer.scheduledTimer(withTimeInterval: 0.09, repeats: true) { _ in
                DispatchQueue.main.async { tick += 1 }
            }
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }
}

// MARK: - Icon swap

extension View {
    /// Crossfade+scale transition for an SF Symbol whose name changes
    /// (mic ↔ stop, provider glyph, etc). Native `.symbolEffect(.replace)`
    /// where available (macOS 14+); a plain view otherwise — same
    /// availability-shim pattern as `symbolEffectPulseIfAvailable` in
    /// RecordingOverlay.swift.
    @ViewBuilder
    func kmIconSwap() -> some View {
        if #available(macOS 14.0, *) {
            self.contentTransition(.symbolEffect(.replace))
        } else {
            self
        }
    }
}
