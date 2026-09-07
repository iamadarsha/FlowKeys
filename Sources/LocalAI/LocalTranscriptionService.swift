// ============================================================
// FILE: Sources/LocalAI/LocalTranscriptionService.swift
// FlowKeys — Local AI (Phase 2 + Phase 3)
//
// On-device transcription path. Mirrors the surface of the existing
// `TranscriptionService.transcribe(fileURL:)` so `AppState` can route to it
// without touching the cloud code.
//
// Phase 3 adds: VAD (silence-trim + speech spans) and a deterministic
// speech-cleanup pass that runs before the LLM.
// ============================================================

import Foundation
import os.log

private let localTxLog = OSLog(subsystem: "com.flowkeys.app", category: "LocalTranscription")

struct LocalTranscriptionOutcome: Sendable {
    let rawText: String            // straight ASR output
    let cleanedText: String        // after deterministic pre-clean (feed this to the LLM)
    let detectedLanguage: String
    let modelID: String
    let loadMs: Int
    let transcribeMs: Int
    let analysis: SpeechAnalysis
    let usedVAD: Bool
}

final class LocalTranscriptionService {

    private let engine: LocalWhisperEngine
    private let modelManager: LocalModelManager
    private let settings: LocalAISettings

    init(engine: LocalWhisperEngine, modelManager: LocalModelManager, settings: LocalAISettings) {
        self.engine = engine
        self.modelManager = modelManager
        self.settings = settings
    }

    func resolvedModel(for selection: LanguageSelection) -> LocalModelDescriptor? {
        if let id = settings.asrModelID,
           let d = LocalModelManifest.descriptor(id: id),
           modelManager.isInstalled(d) {
            return d
        }
        if selection.language == .hindi || selection.language == .bengali
            || selection.language == .banglish {
            if let indic = LocalModelManifest.models(of: .asrIndicConformer)
                .first(where: { modelManager.isInstalled($0) && $0.isActivatable }) {
                return indic
            }
        }
        return LocalModelManifest.models(of: .asrWhisper)
            .first { modelManager.isInstalled($0) }
    }

    private func vadModelPath() -> String? {
        guard let vad = LocalModelManifest.models(of: .vad)
            .first(where: { modelManager.isInstalled($0) && $0.isActivatable }) else { return nil }
        return modelManager.installedPath(vad)?.path
    }

    func transcribe(fileURL: URL,
                    selection: LanguageSelection,
                    initialPrompt: String?) async throws -> LocalTranscriptionOutcome {

        guard let descriptor = resolvedModel(for: selection) else {
            throw LocalWhisperError.openFailed("no local speech model installed")
        }
        guard let modelPath = modelManager.installedPath(descriptor)?.path else {
            throw LocalWhisperError.modelMissing(descriptor.displayName)
        }

        await engine.setThreadCount(settings.performanceProfile.suggestedThreadCap)

        let samples = try LocalWhisperEngine.loadMono16kFloat(from: fileURL)
        guard !samples.isEmpty else { throw LocalWhisperError.emptyAudio }

        let processed = settings.whisperModeEnabled ? WhisperModeGain.apply(samples) : samples
        let vadPath = vadModelPath()

        let result = try await engine.transcribe(
            samples: processed,
            languageToken: selection.language.asrLanguageToken,
            initialPrompt: initialPrompt,
            modelPath: modelPath,
            vadModelPath: vadPath,
            keepWarmSeconds: settings.effectiveUnloadAfterSeconds
        )

        let analysis = SpeechAnalysisService.analyze(
            rawText: result.text,
            result: result,
            level: settings.disfluencyLevel,
            language: selection.language
        )

        os_log(.info, log: localTxLog,
               "local ASR: model=%{public}@ load=%dms tx=%dms vad=%{public}d fillers=%d lang=%{public}@",
               descriptor.id, result.loadMilliseconds, result.transcribeMilliseconds,
               vadPath != nil ? 1 : 0, analysis.fillersRemoved.count, result.detectedLanguage)

        return LocalTranscriptionOutcome(
            rawText: result.text,
            cleanedText: analysis.cleanedText.isEmpty ? result.text : analysis.cleanedText,
            detectedLanguage: result.detectedLanguage,
            modelID: descriptor.id,
            loadMs: result.loadMilliseconds,
            transcribeMs: result.transcribeMilliseconds,
            analysis: analysis,
            usedVAD: vadPath != nil
        )
    }

}
