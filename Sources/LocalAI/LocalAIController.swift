// ============================================================
// FILE: Sources/LocalAI/LocalAIController.swift
// FlowKeys — Local AI (Phase 2)
//
// Public face of the optional on-device AI subsystem. `AppState` holds one and
// observes it. Local AI is OFF by default; when off (or when this build has no
// engine), `routeDecision()` always returns `.useExistingCloud`, so the app
// behaves exactly as it does today.
//
// Not `@MainActor` — `AppState` is a nonisolated `@unchecked Sendable` class and
// owns this as a stored property. `@Published` writes hop to main via `publish`.
// ============================================================

import Foundation
import Combine
import os.log

private let localAILog = OSLog(subsystem: "com.flowkeys.app", category: "LocalAI")

enum LocalAIState: Equatable, Sendable {
    case idle
    case transcribing
    case unavailable(reason: String)
}

enum LocalRouteDecision: Equatable, Sendable {
    case useExistingCloud
    case useLocal
    case useHybrid(cloudFallback: Bool)
}

struct LocalTranscriptionReport: Sendable {
    let text: String              // deterministically pre-cleaned; feed to the LLM
    let rawText: String           // straight ASR
    let routeLabel: String        // "Local" / "Hybrid → cloud"
    let modelID: String?
    let detectedLanguage: String?
    let loadMs: Int?
    let transcribeMs: Int?
    let usedCloudFallback: Bool
    let fillersRemoved: [String]
    let correctionCount: Int
    let usedVAD: Bool
    /// When true the deterministic pass produced a final answer and the LLM
    /// cleanup can be skipped (short, clean utterance).
    let canSkipLLM: Bool
}

final class LocalAIController: ObservableObject, @unchecked Sendable {

    @Published private(set) var state: LocalAIState = .idle
    @Published private(set) var settings: LocalAISettings
    @Published private(set) var isOperational: Bool = false

    let modelManager: LocalModelManager
    private let engine: LocalWhisperEngine
    private let store: LocalAISettingsStore

    init(store: LocalAISettingsStore = LocalAISettingsStore(),
         modelManager: LocalModelManager = LocalModelManager()) {
        self.store = store
        self.settings = store.load()
        self.modelManager = modelManager
        self.engine = LocalWhisperEngine()
        os_log(.info, log: localAILog,
               "LocalAIController init — enabled=%{public}d route=%{public}@ builtWithLocalAI=%{public}d",
               settings.isEnabled, settings.route.rawValue, isBuiltWithLocalAI ? 1 : 0)
        recomputeOperational()
    }

    var isBuiltWithLocalAI: Bool {
        #if FLK_LOCAL_AI
        return true
        #else
        return false
        #endif
    }

    var engineVersion: String {
        #if FLK_LOCAL_AI
        return "whisper.cpp v1.9.3"
        #else
        return "n/a"
        #endif
    }

    private func publish(_ work: @escaping () -> Void) {
        if Thread.isMainThread { work() }
        else { DispatchQueue.main.async(execute: work) }
    }

    // MARK: - Settings

    func update(_ mutate: (inout LocalAISettings) -> Void) {
        var next = settings
        mutate(&next)
        store.save(next)
        publish { self.settings = next; self.recomputeOperational() }
    }

    func refreshModels() {
        modelManager.refreshInstalledState()
        publish { self.recomputeOperational() }
    }

    private func recomputeOperational() {
        guard isBuiltWithLocalAI, settings.isEnabled else {
            isOperational = false
            state = settings.localPathActive
                ? .unavailable(reason: "This build has no on-device engine.")
                : .idle
            return
        }
        let hasASR = LocalModelManifest.models(of: .asrWhisper)
                .contains { modelManager.isInstalled($0) }
            || LocalModelManifest.models(of: .asrIndicConformer)
                .contains { modelManager.isInstalled($0) && $0.isActivatable }
        isOperational = hasASR
        state = (settings.localPathActive && !hasASR)
            ? .unavailable(reason: "Download a speech model in Settings → Local AI.")
            : .idle
    }

    // MARK: - Routing

    func routeDecision() -> LocalRouteDecision {
        guard settings.localPathActive, isOperational else { return .useExistingCloud }
        switch settings.route {
        case .existingCloud: return .useExistingCloud
        case .local:         return .useLocal
        case .hybrid:        return .useHybrid(cloudFallback: settings.hybridCloudFallbackEnabled)
        }
    }

    // MARK: - Transcription

    /// Transcribe locally. `cloudFallback` is invoked only when this is a
    /// `.useHybrid` run and local transcription fails.
    func transcribe(fileURL: URL,
                    languageMode: UserLanguageMode,
                    languageOverride: LanguageSelection?,
                    initialPrompt: String?,
                    cloudFallback: (() async throws -> String)?) async throws -> LocalTranscriptionReport {

        let selection = LanguageRouter.resolve(legacyMode: languageMode, override: languageOverride)
        let service = LocalTranscriptionService(engine: engine,
                                                modelManager: modelManager,
                                                settings: settings)
        publish { self.state = .transcribing }
        defer { publish { self.state = .idle } }

        do {
            let outcome = try await service.transcribe(fileURL: fileURL,
                                                       selection: selection,
                                                       initialPrompt: initialPrompt)

            // Confidence-aware hybrid escalation: if the local result looks
            // unreliable and a sanctioned cloud fallback exists, use it.
            if let cloudFallback, Self.looksLowConfidence(outcome) {
                os_log(.info, log: localAILog,
                       "hybrid: local result low-confidence — escalating to cloud")
                let text = try await cloudFallback()
                return LocalTranscriptionReport(
                    text: text, rawText: outcome.rawText, routeLabel: "Hybrid → cloud (low confidence)",
                    modelID: outcome.modelID, detectedLanguage: nil,
                    loadMs: outcome.loadMs, transcribeMs: outcome.transcribeMs,
                    usedCloudFallback: true, fillersRemoved: [], correctionCount: 0,
                    usedVAD: outcome.usedVAD, canSkipLLM: false)
            }

            return LocalTranscriptionReport(
                text: outcome.cleanedText,
                rawText: outcome.rawText,
                routeLabel: "Local",
                modelID: outcome.modelID,
                detectedLanguage: outcome.detectedLanguage.isEmpty ? nil : outcome.detectedLanguage,
                loadMs: outcome.loadMs,
                transcribeMs: outcome.transcribeMs,
                usedCloudFallback: false,
                fillersRemoved: outcome.analysis.fillersRemoved,
                correctionCount: outcome.analysis.corrections.count,
                usedVAD: outcome.usedVAD,
                canSkipLLM: outcome.analysis.isTrivialResult
            )
        } catch {
            os_log(.error, log: localAILog, "local transcription failed: %{public}@", error.localizedDescription)
            if let cloudFallback {
                let text = try await cloudFallback()
                return LocalTranscriptionReport(
                    text: text, rawText: text, routeLabel: "Hybrid → cloud",
                    modelID: nil, detectedLanguage: nil, loadMs: nil, transcribeMs: nil,
                    usedCloudFallback: true, fillersRemoved: [], correctionCount: 0,
                    usedVAD: false, canSkipLLM: false)
            }
            throw error
        }
    }

    /// Heuristic (no per-token confidence from whisper.cpp without more plumbing):
    /// treat a near-empty or degenerate transcript as unreliable.
    static func looksLowConfidence(_ o: LocalTranscriptionOutcome) -> Bool {
        let t = o.rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty { return true }
        let lower = t.lowercased()
        if lower.contains("[blank_audio]") || lower.contains("[ silence ]") { return true }
        // Very short output for non-trivial audio (> 2 s of speech).
        if o.analysis.speechSeconds > 2.0 && t.split(separator: " ").count < 2 { return true }
        // A single token repeated to fill the window.
        let words = lower.split(separator: " ").map(String.init)
        if words.count >= 6, Set(words).count == 1 { return true }
        return false
    }

    // MARK: - Lifecycle

    func releaseAllModels() {
        Task { await engine.unload() }
        publish { self.state = .idle }
    }

    func handleResourcePressure() {
        os_log(.info, log: localAILog, "resource pressure — releasing local models")
        releaseAllModels()
    }
}
