import SwiftUI

// MARK: - Kinetic Monolith Design Tokens

enum KM {
    static let bg          = Color(hex: "#0F0F11")
    static let surface     = Color(hex: "#131313")
    static let surfaceHi   = Color(hex: "#20201F")
    static let surfaceTop  = Color(hex: "#2A2A2A")
    static let outline     = Color.white.opacity(0.07)
    static let accent      = Color(hex: "#FF6B35")
    static let salmon      = Color(hex: "#FFB59D")
    static let green       = Color(hex: "#53E16F")
    static let error       = Color(hex: "#FFB4AB")
    static let onSurface   = Color.white.opacity(0.87)
    static let muted       = Color.white.opacity(0.40)
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

// MARK: - Shared Card Component

struct KMCard<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(KM.surfaceHi)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
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
