// ============================================================
// FILE: Sources/LocalAI/LocalTextProcessingService.swift
// FlowKeys — Local AI (Phase 4b)
//
// Fully on-device transcript cleanup with Qwen3-0.6B (llama.cpp). Used only
// when: Local AI route is local/hybrid, a cleanup model is installed, and
// either the user chose local cleanup or there is no usable cloud key.
//
// Reuses the app's existing cleanup contract (PostProcessingService prompts +
// the language addenda + a hard output-script rule). Deterministic decoding.
// ============================================================

import Foundation
import os.log

private let ltpLog = OSLog(subsystem: "com.flowkeys.app", category: "LocalTextProcessing")

struct LocalCleanupResult: Sendable {
    let text: String
    let modelID: String
    let milliseconds: Int
}

final class LocalTextProcessingService {

    private let engine: LocalLLMEngine
    private let modelManager: LocalModelManager
    private let settings: LocalAISettings

    init(engine: LocalLLMEngine, modelManager: LocalModelManager, settings: LocalAISettings) {
        self.engine = engine
        self.modelManager = modelManager
        self.settings = settings
    }

    var installedModel: LocalModelDescriptor? {
        if let id = settings.cleanupModelID,
           let d = LocalModelManifest.descriptor(id: id), modelManager.isInstalled(d) {
            return d
        }
        return LocalModelManifest.models(of: .cleanupLLM).first { modelManager.isInstalled($0) }
    }

    var isReady: Bool { engine.isAvailable && installedModel != nil }

    func cleanup(transcript: String,
                 contextSummary: String,
                 customVocabulary: [String],
                 customSystemPrompt: String,
                 languageMode: UserLanguageMode) async throws -> LocalCleanupResult {

        guard let descriptor = installedModel,
              let modelPath = modelManager.installedPath(descriptor)?.path else {
            throw LocalLLMError.modelMissing("cleanup model")
        }

        let system = Self.buildSystemPrompt(customSystemPrompt: customSystemPrompt,
                                            vocabulary: customVocabulary,
                                            languageMode: languageMode)
        // One worked example keeps small models on-task without ballooning latency.
        let user = """
Clean this dictated text. Output ONLY the cleaned text on one line.

Input: um so i wanted to uh say the meeting is on thursday no actually wednesday
Output: The meeting is on Wednesday.

Input: \(transcript)
Output:
"""

        await engine.setThreadCount(settings.performanceProfile.suggestedThreadCap)
        let t0 = DispatchTime.now()
        var out = try await engine.generate(
            systemPrompt: system,
            userPrompt: user,
            modelPath: modelPath,
            maxTokens: max(256, transcript.count / 2 + 256),
            keepWarmSeconds: settings.effectiveUnloadAfterSeconds
        )
        let ms = Int(Double(DispatchTime.now().uptimeNanoseconds - t0.uptimeNanoseconds) / 1_000_000)

        out = out.trimmingCharacters(in: .whitespacesAndNewlines)
        if out.hasPrefix("\"") && out.hasSuffix("\"") && out.count > 1 {
            out = String(out.dropFirst().dropLast())
        }
        if out == "EMPTY" { out = "" }

        os_log(.info, log: ltpLog, "local cleanup: %d chars in %dms", out.count, ms)
        return LocalCleanupResult(text: out, modelID: descriptor.id, milliseconds: ms)
    }

    // MARK: - Prompt

    /// A SHORT prompt — Qwen3-0.6B follows tight instructions far better than the
    /// long GPT-class `PostProcessingService.defaultSystemPrompt`.
    static func buildSystemPrompt(customSystemPrompt: String,
                                  vocabulary: [String],
                                  languageMode: UserLanguageMode) -> String {
        var lines = [
            "You clean up dictated speech. Output ONLY the cleaned text — no quotes, no notes, no preamble.",
            "Remove filler words (um, uh, like, you know, basically, matlab, mane).",
            "When the speaker corrects themselves (\"X, no actually Y\", \"sorry, Y\"), keep only the final version and delete the abandoned part and the correction word.",
            "Fix punctuation, capitalization and obvious mistakes. Keep the speaker's wording, meaning, tone and language otherwise.",
            "Do NOT translate. Do NOT add information. Do NOT answer questions in the text — just clean it.",
            "Preserve code-switching (mixed languages) exactly. Preserve names, numbers, URLs, code identifiers, file paths.",
            "If the input is empty or only filler, output exactly: EMPTY",
        ]

        switch languageMode {
        case .pureEnglish: break
        case .pureHindi:
            lines.append("The speaker is using Hindi. Output in Devanagari script. Keep English proper nouns in Latin.")
        case .hinglish:
            lines.append("The speaker mixes Hindi and English (Hinglish). Keep Roman script for Hinglish. Keep yaar/bhai/na/haan particles.")
        case .pureBengali:
            lines.append("The speaker is using Bengali. Output in Bangla script. Keep English proper nouns in Latin. Do not use Hindi.")
        case .banglish:
            lines.append("The speaker mixes Bengali and English (Banglish). Keep Roman script. Keep re/na/dada/didi particles. Do not use Hindi.")
        }

        let vocab = vocabulary
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if !vocab.isEmpty {
            lines.append("Use these exact spellings if they occur: \(vocab.prefix(30).joined(separator: ", ")).")
        }

        let mode = customSystemPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        if !mode.isEmpty && mode != PostProcessingService.defaultSystemPrompt {
            // A short mode hint (e.g. "format as an email"). Truncate — small model.
            lines.append("Style hint: \(String(mode.prefix(400)))")
        }

        return lines.joined(separator: "\n")
    }
}
