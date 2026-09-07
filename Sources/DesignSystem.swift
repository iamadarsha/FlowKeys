import SwiftUI

// MARK: - Kinetic Precision Design Tokens
//
// Evolution of the v1.2 "Kinetic Monolith" system. Same obsidian base + thermal
// orange accent, refined per Design/stitch_five_phase_task_roadmap*/kinetic_precision.
// All existing `KM.*` symbols are preserved for source compatibility.

enum KM {
    // Canvas & surface hierarchy (luminance stepping)
    static let bg          = Color(hex: "#0F0F11")   // L0 — canvas / inactive base
    static let surface     = Color(hex: "#131313")   // L1 — window containers
    static let surfaceHi   = Color(hex: "#20201F")   // L2 — cards, list rows, pickers
    static let surfaceTop  = Color(hex: "#2A2A2A")   // L3 — popovers, keycaps, active selection
    static let outline     = Color.white.opacity(0.07) // structural hairline

    // Accent & feedback
    static let accent      = Color(hex: "#FF6B35")   // active / record / primary trigger
    static let salmon      = Color(hex: "#FFB59D")   // soft highlight, glow falloff
    static let green       = Color(hex: "#53E16F")   // signal confirmation, engine ready
    static let warning     = Color(hex: "#FFC24B")   // clipping, fallback, network jitter
    static let error       = Color(hex: "#FFB4AB")   // mic disconnect, permission lock

    // Typographic contrast
    static let textPrimary   = Color.white.opacity(0.90)
    static let textSecondary = Color.white.opacity(0.62)
    static let textMuted     = Color.white.opacity(0.40)
    // Legacy aliases
    static let onSurface   = Color.white.opacity(0.90)
    static let muted       = Color.white.opacity(0.40)

    // Language / dialect indicators
    static let langEN      = Color(hex: "#4A90E2")   // cerulean
    static let langHI      = Color(hex: "#138808")   // saffron/emerald flag node
    static let langBN      = Color(hex: "#0B7345")   // forest green
    static let langMIX     = Color(hex: "#FF6B35")   // inherits primary warmth

    // Corner radii (continuous squircle)
    static let rCard: CGFloat    = 12   // cards, inner sections, dialogs
    static let rControl: CGFloat = 8    // controls, dropdowns, inputs
    static let rChip: CGFloat    = 6    // keycaps, tags, mini pills
}

// MARK: - Motion

/// Micro-interaction timing. Snappy 100–180ms curves; audio-reactive attack/release
/// tuned for organic, water-ripple fluidity per the A2 waveform spec.
enum Motion {
    static let attackDuration: Double  = 0.06   // waveform bar rise (fast ease-out)
    static let releaseDuration: Double = 0.22   // waveform bar fall (fluid ease-in)

    static let micro  = Animation.easeOut(duration: 0.14)   // state chrome, hovers
    static let snappy = Animation.spring(response: 0.28, dampingFraction: 0.78)
}

// MARK: - Elevation

extension View {
    /// L3 — floating capsule HUD dispersion.
    func kmHUDShadow() -> some View {
        self
            .shadow(color: .black.opacity(0.85), radius: 24, x: 0, y: 20)
            .shadow(color: .black.opacity(0.50), radius: 8, x: 0, y: 8)
    }

    /// L4 — active recording accent aura beneath the HUD. Deliberately subtle.
    func kmAudioGlow(_ active: Bool, color: Color = KM.accent) -> some View {
        self
            .shadow(color: active ? color.opacity(0.25) : .clear, radius: 1, x: 0, y: 0)
            .shadow(color: active ? color.opacity(0.11) : .clear, radius: 7, x: 0, y: 4)
    }
}

// MARK: - Color(hex:) Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB,
                  red: Double(r) / 255,
                  green: Double(g) / 255,
                  blue: Double(b) / 255,
                  opacity: Double(a) / 255)
    }
}

// MARK: - Language accent mapping

extension UserLanguageMode {
    /// Dialect indicator colour used by the Flow Bar, menu-bar segment, badges.
    var accentColor: Color {
        switch self {
        case .pureEnglish:            return KM.langEN
        case .pureHindi:              return KM.langHI
        case .pureBengali, .banglish: return KM.langBN
        case .hinglish:               return KM.langMIX
        }
    }

    /// Compact badge label.
    var badgeCode: String {
        switch self {
        case .hinglish:   return "MIX"
        case .pureHindi:  return "HI"
        case .pureEnglish: return "EN"
        case .pureBengali: return "BN"
        case .banglish:   return "BN·EN"
        }
    }
}

// MARK: - Shared Card Component

struct KMCard<Content: View>: View {
    var padding: CGFloat = 16
    let content: Content
    init(padding: CGFloat = 16, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(KM.surfaceHi)
            .clipShape(RoundedRectangle(cornerRadius: KM.rCard, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: KM.rCard, style: .continuous)
                    .stroke(KM.outline, lineWidth: 1)
            )
    }
}

// MARK: - Section Header

struct KMSectionHeader: View {
    let title: String
    let icon: String
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(KM.accent)
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(KM.onSurface)
        }
    }
}

/// Uppercase micro eyebrow label with tracking, per Kinetic Precision `label-sm`.
struct KMEyebrow: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 9, weight: .bold))
            .tracking(1.2)
            .foregroundColor(KM.textMuted)
    }
}

// MARK: - Gradient Pill Button

struct KMPillButton: View {
    let label: String
    let icon: String
    var isDestructive = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                Text(label)
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(
                LinearGradient(
                    colors: isDestructive
                        ? [Color.red.opacity(0.85), Color.red.opacity(0.7)]
                        : [KM.accent, KM.accent.opacity(0.8)],
                    startPoint: .leading, endPoint: .trailing
                )
            )
            .clipShape(Capsule())
            .shadow(color: (isDestructive ? Color.red : KM.accent).opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Keycap

/// Inset shortcut glyph, e.g. `⌥ Space`. Renders on surfaceTop with a 0.12 hairline.
struct KMKeycap: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .tracking(0.4)
            .foregroundColor(KM.textSecondary)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .frame(minWidth: 18)
            .background(KM.surfaceTop)
            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
    }
}

// MARK: - Language Badge

/// 20pt pill with a 6pt saturated dialect dot.
struct KMLangBadge: View {
    let mode: UserLanguageMode
    var showDot = true
    var body: some View {
        HStack(spacing: 4) {
            if showDot {
                Circle()
                    .fill(mode.accentColor)
                    .frame(width: 6, height: 6)
            }
            Text(mode.badgeCode)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(mode.accentColor)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(Color.white.opacity(0.04))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(KM.outline, lineWidth: 1))
    }
}

// MARK: - Empty State
//
// Canonical zero-data template (Design G1). Soft monochrome icon, a clear
// primary instruction, and — always — an action affordance so the state never
// dead-ends the operator.

struct KMEmptyState<Action: View>: View {
    let icon: String
    let title: String
    let message: String
    var hint: String? = nil          // e.g. "⌥Space  ·  Speak naturally"
    @ViewBuilder var action: () -> Action

    init(icon: String, title: String, message: String, hint: String? = nil,
         @ViewBuilder action: @escaping () -> Action = { EmptyView() }) {
        self.icon = icon
        self.title = title
        self.message = message
        self.hint = hint
        self.action = action
    }

    var body: some View {
        VStack(spacing: 14) {
            Spacer(minLength: 0)
            ZStack {
                Circle().fill(KM.surfaceTop).frame(width: 64, height: 64)
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .regular))
                    .foregroundColor(KM.textSecondary)
            }
            VStack(spacing: 5) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(KM.textPrimary)
                Text(message)
                    .font(.system(size: 12))
                    .foregroundColor(KM.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 320)
            }
            if let hint {
                Text(hint)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(KM.textMuted)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(KM.surfaceHi)
                    .clipShape(RoundedRectangle(cornerRadius: KM.rChip, style: .continuous))
            }
            action()
                .padding(.top, 2)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
    }
}

/// Small accent-tinted ghost button used inside empty states.
struct KMGhostButton: View {
    let label: String
    var icon: String? = nil
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon { Image(systemName: icon).font(.system(size: 11, weight: .semibold)) }
                Text(label).font(.system(size: 12, weight: .semibold))
            }
            .foregroundColor(KM.accent)
            .padding(.horizontal, 16).padding(.vertical, 7)
            .background(KM.accent.opacity(0.12))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
