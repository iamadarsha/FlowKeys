// ============================================================
// FILE: Sources/LocalAI/LocalAISettingsView.swift
// FlowKeys — Local AI (Phase 2)
//
// The new "Local AI" Settings tab. Additive — every existing tab is untouched.
// Default state is OFF; when off the app behaves exactly as before.
// ============================================================

import SwiftUI

struct LocalAISettingsView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        LocalAISettingsContent(
            controller: appState.localAI,
            models: appState.localAI.modelManager
        )
    }
}

private struct LocalAISettingsContent: View {
    @ObservedObject var controller: LocalAIController
    @ObservedObject var models: LocalModelManager

    @State private var deleteError: String?

    private var settings: LocalAISettings { controller.settings }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                header

                if !controller.isBuiltWithLocalAI {
                    KMCard {
                        Label("This build was compiled without the on-device engine.",
                              systemImage: "exclamationmark.triangle")
                            .font(.system(size: 12))
                            .foregroundColor(KM.muted)
                    }
                }

                enableCard

                if settings.isEnabled {
                    processingCard
                    speechModelCard
                    speechIntelligenceCard
                    if controller.isBuiltWithLocalAI { cleanupCard }
                    performanceCard
                }

                footer
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(KM.bg)
        .onAppear { controller.refreshModels() }
        .alert("Couldn't delete model", isPresented: .constant(deleteError != nil)) {
            Button("OK") { deleteError = nil }
        } message: { Text(deleteError ?? "") }
    }

    // MARK: Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Local AI")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(KM.onSurface)
            Text("Run speech recognition on this Mac. Private, offline, free. "
                 + "Your cloud providers stay exactly as configured.")
                .font(.system(size: 12))
                .foregroundColor(KM.muted)
        }
    }

    private var enableCard: some View {
        KMCard {
            VStack(alignment: .leading, spacing: 6) {
                Toggle(isOn: Binding(
                    get: { settings.isEnabled },
                    set: { newValue in controller.update { $0.isEnabled = newValue } }
                )) {
                    Text("Use local AI").font(.system(size: 13, weight: .semibold))
                        .foregroundColor(KM.onSurface)
                }
                .toggleStyle(.switch)
                .tint(KM.accent)

                Text(statusLine)
                    .font(.system(size: 11))
                    .foregroundColor(statusIsWarning ? KM.error : KM.muted)
            }
        }
    }

    private var processingCard: some View {
        KMCard {
            VStack(alignment: .leading, spacing: 10) {
                KMSectionHeader(title: "Processing", icon: "arrow.triangle.branch")
                Picker("", selection: Binding(
                    get: { settings.route },
                    set: { newValue in controller.update { $0.route = newValue } }
                )) {
                    Text("Local").tag(TranscriptionRoute.local)
                    Text("Hybrid").tag(TranscriptionRoute.hybrid)
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                if settings.route == .hybrid {
                    Toggle(isOn: Binding(
                        get: { settings.hybridCloudFallbackEnabled },
                        set: { v in controller.update { $0.hybridCloudFallbackEnabled = v } }
                    )) {
                        Text("Use your cloud provider only when local can't handle it")
                            .font(.system(size: 11)).foregroundColor(KM.muted)
                    }
                    .toggleStyle(.checkbox)
                }
                Text(settings.route == .local
                     ? "Everything stays on this Mac. Never falls back to the cloud."
                     : "Local first. Cloud is used only per the rule above and is shown in the Run Log.")
                    .font(.system(size: 11)).foregroundColor(KM.muted)
            }
        }
    }

    private var speechModelCard: some View {
        KMCard {
            VStack(alignment: .leading, spacing: 12) {
                KMSectionHeader(title: "Speech model", icon: "waveform")
                ForEach(LocalModelManifest.models(of: .asrWhisper)
                    + LocalModelManifest.models(of: .asrIndicConformer)) { model in
                    modelRow(model)
                    if model.id != lastModelID { Divider().background(KM.outline) }
                }
            }
        }
    }

    private var speechIntelligenceCard: some View {
        KMCard {
            VStack(alignment: .leading, spacing: 12) {
                KMSectionHeader(title: "Speech intelligence", icon: "wand.and.stars")

                // VAD model row
                if let vad = LocalModelManifest.models(of: .vad).first {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(vad.displayName).font(.system(size: 12, weight: .semibold))
                                .foregroundColor(KM.onSurface)
                            Text(vad.shortDescription).font(.system(size: 10)).foregroundColor(KM.muted)
                        }
                        Spacer()
                        modelAction(vad, models.status(vad.id))
                    }
                    Divider().background(KM.outline)
                }

                Text("Filler cleanup").font(.system(size: 12)).foregroundColor(KM.onSurface)
                Picker("", selection: Binding(
                    get: { settings.disfluencyLevel },
                    set: { v in controller.update { $0.disfluencyLevel = v } }
                )) {
                    ForEach(DisfluencyAggressiveness.allCases, id: \.self) { l in
                        Text(l.displayName).tag(l)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                Text(disfluencyHint).font(.system(size: 10)).foregroundColor(KM.muted)

                Toggle(isOn: Binding(
                    get: { settings.whisperModeEnabled },
                    set: { v in controller.update { $0.whisperModeEnabled = v } }
                )) {
                    Text("Whisper Mode — boost very quiet speech")
                        .font(.system(size: 11)).foregroundColor(KM.muted)
                }
                .toggleStyle(.checkbox)
            }
        }
    }

    private var disfluencyHint: String {
        switch settings.disfluencyLevel {
        case .literal:  return "Nothing removed — exact transcript."
        case .light:    return "Removes only \"um\", \"uh\", \"hmm\"."
        case .standard: return "Removes fillers and repeated false starts."
        case .polished: return "Also tightens spacing around long pauses. Never rephrases."
        }
    }

    private var cleanupCard: some View {
        KMCard {
            VStack(alignment: .leading, spacing: 10) {
                KMSectionHeader(title: "Writing cleanup", icon: "text.badge.checkmark")
                Text("The filler / pause / punctuation pass always runs on-device. "
                     + "The final polish normally uses your cloud provider (Groq/Gemini — free, fast, better). "
                     + "You can run it on-device too for a fully-offline flow.")
                    .font(.system(size: 11)).foregroundColor(KM.muted)
                    .fixedSize(horizontal: false, vertical: true)

                if let llm = LocalModelManifest.models(of: .cleanupLLM).first {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(llm.displayName).font(.system(size: 12, weight: .semibold))
                                .foregroundColor(KM.onSurface)
                            Text("~\(ByteCountFormatter.string(fromByteCount: llm.expectedByteSize, countStyle: .file)) · slower, less capable than cloud")
                                .font(.system(size: 10)).foregroundColor(KM.muted)
                        }
                        Spacer()
                        modelAction(llm, models.status(llm.id))
                    }

                    if case .installed = models.status(llm.id) {
                        Toggle(isOn: Binding(
                            get: { settings.useLocalCleanup },
                            set: { v in controller.update { $0.useLocalCleanup = v } }
                        )) {
                            Text("Use on-device cleanup (experimental)")
                                .font(.system(size: 11)).foregroundColor(KM.muted)
                        }
                        .toggleStyle(.checkbox)
                    }
                }
            }
        }
    }

    private var performanceCard: some View {
        KMCard {
            VStack(alignment: .leading, spacing: 10) {
                KMSectionHeader(title: "Performance", icon: "bolt")
                Picker("", selection: Binding(
                    get: { settings.performanceProfile },
                    set: { v in controller.update { $0.performanceProfile = v } }
                )) {
                    ForEach(LocalPerformanceProfile.allCases, id: \.self) { p in
                        Text(p.displayName).tag(p)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                HStack {
                    Text("Unload models after").font(.system(size: 12)).foregroundColor(KM.onSurface)
                    Spacer()
                    Text("\(settings.effectiveUnloadAfterSeconds)s")
                        .font(.system(size: 12)).foregroundColor(KM.muted)
                }
            }
        }
    }

    private var footer: some View {
        Text("Models are stored in Application Support and are never bundled in the app. "
             + "whisper.cpp \(controller.isBuiltWithLocalAI ? "v1.9.3" : "n/a").")
            .font(.system(size: 10))
            .foregroundColor(KM.muted)
    }

    // MARK: Model row

    @ViewBuilder
    private func modelRow(_ model: LocalModelDescriptor) -> some View {
        let status = models.status(model.id)
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(model.displayName)
                    .font(.system(size: 13, weight: .semibold)).foregroundColor(KM.onSurface)
                Text(model.shortDescription)
                    .font(.system(size: 11)).foregroundColor(KM.muted)
                Text(ByteCountFormatter.string(fromByteCount: model.expectedByteSize, countStyle: .file))
                    .font(.system(size: 10)).foregroundColor(KM.muted)
            }
            Spacer()
            modelAction(model, status)
        }
    }

    @ViewBuilder
    private func modelAction(_ model: LocalModelDescriptor, _ status: LocalModelStatus) -> some View {
        switch status {
        case .notInstalled:
            Button("Download") { models.download(model) }
                .buttonStyle(.borderedProminent).tint(KM.accent)
                .disabled(!model.isActivatable && model.kind != .asrWhisper)
        case .downloading(let p, let got, let total):
            VStack(alignment: .trailing, spacing: 4) {
                ProgressView(value: p).frame(width: 120)
                Text("\(ByteCountFormatter.string(fromByteCount: got, countStyle: .file)) / "
                     + ByteCountFormatter.string(fromByteCount: total, countStyle: .file))
                    .font(.system(size: 10)).foregroundColor(KM.muted)
                Button("Cancel") { models.cancelDownload(model.id) }
                    .font(.system(size: 10)).buttonStyle(.plain).foregroundColor(KM.muted)
            }
        case .verifying:
            Text("Verifying…").font(.system(size: 11)).foregroundColor(KM.muted)
        case .installed:
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill").foregroundColor(KM.green)
                Button("Delete") {
                    do { try models.delete(model) } catch { deleteError = error.localizedDescription }
                }
                .font(.system(size: 11)).buttonStyle(.plain).foregroundColor(KM.muted)
            }
        case .failed(let msg):
            VStack(alignment: .trailing, spacing: 2) {
                Button("Retry") { models.download(model) }
                    .buttonStyle(.bordered).tint(KM.accent)
                Text(msg).font(.system(size: 9)).foregroundColor(KM.error)
                    .frame(maxWidth: 160, alignment: .trailing)
            }
        case .incompatible(let reason):
            Text(reason).font(.system(size: 10)).foregroundColor(KM.muted)
        }
    }

    // MARK: Helpers

    private var lastModelID: String? {
        (LocalModelManifest.models(of: .asrWhisper)
         + LocalModelManifest.models(of: .asrIndicConformer)).last?.id
    }

    private var statusLine: String {
        switch controller.state {
        case .idle:
            return settings.isEnabled
                ? (controller.isOperational ? "Ready — dictation runs on this Mac." : "Enabled — download a speech model below.")
                : "Off — using your cloud provider."
        case .transcribing: return "Transcribing on-device…"
        case .cleaning: return "Cleaning up on-device…"
        case .unavailable(let reason): return reason
        }
    }

    private var statusIsWarning: Bool {
        if case .unavailable = controller.state { return true }
        return false
    }
}
