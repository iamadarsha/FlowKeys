// ============================================================
// FILE: Sources/LocalAI/LocalAIOnboardingCard.swift
// FlowKeys — Local AI (Phase 2)
//
// Optional card shown on the final setup step. NOT a setup step — the user
// can finish without touching it. Downloading a model here flips Local AI on
// with route = .local; skipping leaves everything on the cloud path.
// ============================================================

import SwiftUI

struct LocalAIOnboardingCard: View {
    @ObservedObject var controller: LocalAIController
    @ObservedObject var models: LocalModelManager
    @State private var dismissed = false

    private let fast = LocalModelManifest.descriptor(id: "whisper-base-q5_1")
    private let best = LocalModelManifest.descriptor(id: "whisper-large-v3-turbo-q5_0")

    var body: some View {
        if controller.isBuiltWithLocalAI && !dismissed && !anyInstalled {
            KMCard {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "lock.shield")
                            .foregroundColor(KM.accent)
                            .font(.system(size: 14, weight: .semibold))
                        Text("Private offline dictation")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(KM.onSurface)
                        Spacer()
                        Button {
                            withAnimation { dismissed = true }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(KM.muted)
                        }
                        .buttonStyle(.plain)
                    }

                    Text("Run speech recognition entirely on this Mac — no internet, "
                         + "nothing leaves your device. Optional. You can turn it on later "
                         + "in Settings → Local AI.")
                        .font(.system(size: 11))
                        .foregroundColor(KM.muted)
                        .fixedSize(horizontal: false, vertical: true)

                    if downloading == nil {
                        HStack(spacing: 8) {
                            if let fast { modelButton(fast, label: "Fast", subtitle: "57 MB") }
                            if let best { modelButton(best, label: "Best quality", subtitle: "547 MB", prominent: true) }
                        }
                    } else if let d = downloading {
                        downloadProgress(d)
                    }
                }
            }
            .transition(.opacity.combined(with: .move(edge: .bottom)))
        }
    }

    // MARK: helpers

    private var anyInstalled: Bool {
        LocalModelManifest.models(of: .asrWhisper).contains { models.isInstalled($0) }
    }

    private var downloading: LocalModelDescriptor? {
        [fast, best].compactMap { $0 }.first {
            if case .downloading = models.status($0.id) { return true }
            if case .verifying = models.status($0.id) { return true }
            return false
        }
    }

    private func modelButton(_ d: LocalModelDescriptor,
                             label: String, subtitle: String,
                             prominent: Bool = false) -> some View {
        Button {
            models.download(d)
            controller.update {
                $0.isEnabled = true
                if $0.route == .existingCloud { $0.route = .local }
                $0.asrModelID = d.id
            }
        } label: {
            VStack(spacing: 2) {
                Text(label).font(.system(size: 12, weight: .semibold))
                Text(subtitle).font(.system(size: 10)).opacity(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .buttonStyle(.borderedProminent)
        .tint(prominent ? KM.accent : KM.surfaceTop)
    }

    private func downloadProgress(_ d: LocalModelDescriptor) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if case .downloading(let p, let got, let total) = models.status(d.id) {
                ProgressView(value: p)
                Text("Downloading \(d.displayName) — "
                     + "\(ByteCountFormatter.string(fromByteCount: got, countStyle: .file)) / "
                     + ByteCountFormatter.string(fromByteCount: total, countStyle: .file))
                    .font(.system(size: 10)).foregroundColor(KM.muted)
            } else {
                Text("Verifying \(d.displayName)…")
                    .font(.system(size: 10)).foregroundColor(KM.muted)
            }
            Button("Cancel") { models.cancelDownload(d.id) }
                .font(.system(size: 10)).buttonStyle(.plain).foregroundColor(KM.muted)
        }
    }
}
