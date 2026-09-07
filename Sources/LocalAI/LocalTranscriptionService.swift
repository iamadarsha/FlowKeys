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
    private let indicEngine: LocalIndicEngine
    private let modelManager: LocalModelManager
    private let settings: LocalAISettings

    init(engine: LocalWhisperEngine,
         indicEngine: LocalIndicEngine,
         modelManager: LocalModelManager,
         settings: LocalAISettings) {
        self.engine = engine
        self.indicEngine = indicEngine
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
                    initialPrompt: String?,
                    onProgress: (@Sendable (Int) -> Void)? = nil) async throws -> LocalTranscriptionOutcome {

        guard let descriptor = resolvedModel(for: selection) else {
            throw LocalWhisperError.openFailed("no local speech model installed")
        }

        let samples = try LocalWhisperEngine.loadMono16kFloat(from: fileURL)
        guard !samples.isEmpty else { throw LocalWhisperError.emptyAudio }
        let processed = settings.whisperModeEnabled ? WhisperModeGain.apply(samples) : samples

        let rawText: String
        let detectedLang: String
        let loadMs: Int
        let txMs: Int
        var usedVAD = false

        if descriptor.kind == .asrIndicConformer && indicEngine.isAvailable {
            guard let dir = modelManager.installedModelDir(descriptor)?.path else {
                throw LocalIndicError.filesMissing(descriptor.displayName)
            }
            await indicEngine.setThreadCount(settings.performanceProfile.suggestedThreadCap)
            let r = try await indicEngine.transcribe(
                samples: processed, modelDir: dir,
                keepWarmSeconds: settings.effectiveUnloadAfterSeconds)
            rawText = r.text
            detectedLang = selection.language.asrLanguageToken ?? ""
            loadMs = r.loadMilliseconds
            txMs = r.transcribeMilliseconds
            onProgress?(100)
        } else {
            guard let modelPath = modelManager.installedPath(descriptor)?.path else {
                throw LocalWhisperError.modelMissing(descriptor.displayName)
            }
            await engine.setThreadCount(settings.performanceProfile.suggestedThreadCap)
            let vadPath = vadModelPath()
            let r = try await engine.transcribe(
                samples: processed,
                languageToken: selection.language.asrLanguageToken,
                initialPrompt: initialPrompt,
                modelPath: modelPath,
                vadModelPath: vadPath,
                keepWarmSeconds: settings.effectiveUnloadAfterSeconds,
                onProgress: onProgress)
            rawText = r.text
            detectedLang = r.detectedLanguage
            loadMs = r.loadMilliseconds
            txMs = r.transcribeMilliseconds
            usedVAD = vadPath != nil
        }

        let whisperResult = LocalWhisperResult(
            text: rawText, detectedLanguage: detectedLang,
            loadMilliseconds: loadMs, transcribeMilliseconds: txMs,
            segments: [], vadSpans: [])
        let analysis = SpeechAnalysisService.analyze(
            rawText: rawText, result: whisperResult,
            level: settings.disfluencyLevel, language: selection.language)

        os_log(.info, log: localTxLog,
               "local ASR: model=%{public}@ load=%dms tx=%dms fillers=%d",
               descriptor.id, loadMs, txMs, analysis.fillersRemoved.count)

        return LocalTranscriptionOutcome(
            rawText: rawText,
            cleanedText: analysis.cleanedText.isEmpty ? rawText : analysis.cleanedText,
            detectedLanguage: detectedLang,
            modelID: descriptor.id,
            loadMs: loadMs,
            transcribeMs: txMs,
            analysis: analysis,
            usedVAD: usedVAD
        )
    }

}
