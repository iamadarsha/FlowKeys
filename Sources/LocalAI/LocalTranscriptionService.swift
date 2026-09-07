// ============================================================
// FILE: Sources/LocalAI/LocalTranscriptionService.swift
// FlowKeys — Local AI (Phase 2)
//
// On-device transcription path. Mirrors the surface of the existing
// `TranscriptionService.transcribe(fileURL:)` so `AppState` can route to it
// without touching the cloud code.
// ============================================================

import Foundation
import os.log

private let localTxLog = OSLog(subsystem: "com.flowkeys.app", category: "LocalTranscription")

struct LocalTranscriptionOutcome: Sendable {
    let text: String
    let detectedLanguage: String
    let modelID: String
    let loadMs: Int
    let transcribeMs: Int
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

    /// The ASR model FlowKeys should use for `selection`, honoring the user's
    /// explicit choice, then falling back to any installed Whisper model.
    func resolvedModel(for selection: LanguageSelection) -> LocalModelDescriptor? {
        // Explicit user choice first.
        if let id = settings.asrModelID,
           let d = LocalModelManifest.descriptor(id: id),
           modelManager.isInstalled(d) {
            return d
        }
        // Indic languages prefer the IndicConformer model when installed (Phase 4).
        if selection.language == .hindi || selection.language == .bengali
            || selection.language == .banglish {
            if let indic = LocalModelManifest.models(of: .asrIndicConformer)
                .first(where: { modelManager.isInstalled($0) && $0.isActivatable }) {
                return indic
            }
        }
        // Any installed Whisper model.
        return LocalModelManifest.models(of: .asrWhisper)
            .first { modelManager.isInstalled($0) }
    }

    /// Transcribe a normalized WAV file produced by FlowKeys' AudioNormalization.
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

        // whisper.cpp path (Phase 2). IndicConformer via sherpa-onnx arrives in Phase 4.
        let samples = try LocalWhisperEngine.loadMono16kFloat(from: fileURL)
        guard !samples.isEmpty else { throw LocalWhisperError.emptyAudio }

        let result = try await engine.transcribe(
            samples: samples,
            languageToken: selection.language.asrLanguageToken,
            initialPrompt: initialPrompt,
            modelPath: modelPath,
            keepWarmSeconds: settings.effectiveUnloadAfterSeconds
        )

        os_log(.info, log: localTxLog,
               "local ASR: model=%{public}@ load=%dms tx=%dms lang=%{public}@",
               descriptor.id, result.loadMilliseconds, result.transcribeMilliseconds,
               result.detectedLanguage)

        return LocalTranscriptionOutcome(
            text: result.text,
            detectedLanguage: result.detectedLanguage,
            modelID: descriptor.id,
            loadMs: result.loadMilliseconds,
            transcribeMs: result.transcribeMilliseconds
        )
    }
}
