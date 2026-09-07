// ============================================================
// FILE: Sources/LocalAI/LocalLLMEngine.swift
// FlowKeys — Local AI (Phase 4b)
//
// Swift wrapper over the llama.cpp C bridge (Sources/LocalAI/CLlama).
// Only compiled when built with LOCAL_LLM=1 (-D FLK_LOCAL_LLM). Serializes
// access to the llama_context (not thread-safe) via an actor, and unloads
// the model after use so it never co-resides with the ASR model on 8 GB.
// ============================================================

import Foundation
import os.log

private let llmLog = OSLog(subsystem: "com.flowkeys.app", category: "LocalLLM")

enum LocalLLMError: LocalizedError {
    case notBuiltWithLocalLLM
    case modelMissing(String)
    case openFailed(String)
    case generateFailed(String)

    var errorDescription: String? {
        switch self {
        case .notBuiltWithLocalLLM: return "This build has no on-device cleanup model."
        case .modelMissing(let p):  return "Local cleanup model not found at \(p)."
        case .openFailed(let m):     return "Could not load the cleanup model: \(m)"
        case .generateFailed(let m): return "On-device cleanup failed: \(m)"
        }
    }
}

actor LocalLLMEngine {

    private var loadedModelPath: String?
    private var threadCount: Int
    private var unloadTask: Task<Void, Never>?

    #if FLK_LOCAL_LLM
    private var ctx: OpaquePointer?
    #endif

    init(threadCount: Int = 0) { self.threadCount = threadCount }

    nonisolated var isAvailable: Bool {
        #if FLK_LOCAL_LLM
        return true
        #else
        return false
        #endif
    }

    func setThreadCount(_ n: Int) { threadCount = n }

    /// Deterministic chat completion. `/no_think` is appended so Qwen3 skips its
    /// reasoning block; any `<think>…</think>` is also stripped by the bridge.
    func generate(systemPrompt: String,
                  userPrompt: String,
                  modelPath: String,
                  maxTokens: Int = 1024,
                  keepWarmSeconds: Int = 0) async throws -> String {
        #if !FLK_LOCAL_LLM
        throw LocalLLMError.notBuiltWithLocalLLM
        #else
        unloadTask?.cancel(); unloadTask = nil

        if ctx == nil || loadedModelPath != modelPath {
            unloadLocked()
            guard FileManager.default.fileExists(atPath: modelPath) else {
                throw LocalLLMError.modelMissing(modelPath)
            }
            let opened = modelPath.withCString { flk_llama_open($0, 4096, Int32(threadCount)) }
            guard let opened else {
                throw LocalLLMError.openFailed(String(cString: flk_llama_last_error()))
            }
            ctx = opened
            loadedModelPath = modelPath
            os_log(.info, log: llmLog, "loaded cleanup model %{public}@",
                   (modelPath as NSString).lastPathComponent)
        }
        guard let handle = ctx else { throw LocalLLMError.openFailed("context unavailable") }

        let sys = systemPrompt + "\n\n/no_think"
        let out: UnsafeMutablePointer<CChar>? = sys.withCString { s in
            userPrompt.withCString { u in
                flk_llama_generate(handle, s, u, Int32(maxTokens))
            }
        }
        guard let out else {
            throw LocalLLMError.generateFailed(String(cString: flk_llama_last_error()))
        }
        let text = String(cString: out)
        flk_llama_string_free(out)

        scheduleUnload(after: keepWarmSeconds)
        return text
        #endif
    }

    func unload() {
        #if FLK_LOCAL_LLM
        unloadTask?.cancel(); unloadTask = nil
        unloadLocked()
        #endif
    }

    #if FLK_LOCAL_LLM
    private func unloadLocked() {
        if let handle = ctx {
            flk_llama_close(handle)
            os_log(.info, log: llmLog, "unloaded cleanup model")
        }
        ctx = nil
        loadedModelPath = nil
    }

    private func scheduleUnload(after seconds: Int) {
        unloadTask?.cancel()
        guard seconds > 0 else { unloadLocked(); return }
        unloadTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(seconds) * 1_000_000_000)
            guard !Task.isCancelled else { return }
            await self?.unload()
        }
    }
    #endif
}
