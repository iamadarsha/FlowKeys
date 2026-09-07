// ============================================================
// FILE: Sources/LocalAI/LocalIndicEngine.swift
// FlowKeys — Local AI (Phase 4c)
//
// Swift wrapper over the sherpa-onnx C bridge (Sources/LocalAI/CSherpa) running
// AI4Bharat's IndicConformer (NeMo CTC ONNX) for on-device native-script Hindi /
// Bengali / other Indic ASR. Only compiled with LOCAL_INDIC=1 (-D FLK_LOCAL_INDIC).
//
// Same lifecycle discipline as the whisper engine: lazy load, unload after use.
// ============================================================

import Foundation
@preconcurrency import AVFoundation
import os.log

private let indicLog = OSLog(subsystem: "com.flowkeys.app", category: "LocalIndic")

enum LocalIndicError: LocalizedError {
    case notBuiltWithIndic
    case filesMissing(String)
    case openFailed(String)
    case transcribeFailed(String)
    case emptyAudio

    var errorDescription: String? {
        switch self {
        case .notBuiltWithIndic:  return "This build has no Indic speech engine."
        case .filesMissing(let p): return "IndicConformer files missing: \(p)"
        case .openFailed(let m):    return "Could not load IndicConformer: \(m)"
        case .transcribeFailed(let m): return "IndicConformer transcription failed: \(m)"
        case .emptyAudio:           return "No audio to transcribe."
        }
    }
}

struct LocalIndicResult: Sendable {
    let text: String
    let loadMilliseconds: Int
    let transcribeMilliseconds: Int
}

actor LocalIndicEngine {

    private var loadedModelDir: String?
    private var threadCount: Int
    private var unloadTask: Task<Void, Never>?

    #if FLK_LOCAL_INDIC
    private var ctx: OpaquePointer?
    #endif

    init(threadCount: Int = 0) { self.threadCount = threadCount }

    nonisolated var isAvailable: Bool {
        #if FLK_LOCAL_INDIC
        return true
        #else
        return false
        #endif
    }

    func setThreadCount(_ n: Int) { threadCount = n }

    /// `modelDir` must contain `model.int8.onnx` and `tokens.txt`.
    func transcribe(fileURL: URL,
                    modelDir: String,
                    keepWarmSeconds: Int) async throws -> LocalIndicResult {
        #if !FLK_LOCAL_INDIC
        throw LocalIndicError.notBuiltWithIndic
        #else
        let samples = try LocalWhisperEngine.loadMono16kFloat(from: fileURL)
        guard !samples.isEmpty else { throw LocalIndicError.emptyAudio }
        return try await transcribe(samples: samples, modelDir: modelDir, keepWarmSeconds: keepWarmSeconds)
        #endif
    }

    func transcribe(samples: [Float],
                    modelDir: String,
                    keepWarmSeconds: Int = 0) async throws -> LocalIndicResult {
        #if !FLK_LOCAL_INDIC
        throw LocalIndicError.notBuiltWithIndic
        #else
        unloadTask?.cancel(); unloadTask = nil

        let modelPath = (modelDir as NSString).appendingPathComponent("model.int8.onnx")
        let tokensPath = (modelDir as NSString).appendingPathComponent("tokens.txt")

        var loadMs = 0
        if ctx == nil || loadedModelDir != modelDir {
            unloadLocked()
            let fm = FileManager.default
            guard fm.fileExists(atPath: modelPath) else { throw LocalIndicError.filesMissing(modelPath) }
            guard fm.fileExists(atPath: tokensPath) else { throw LocalIndicError.filesMissing(tokensPath) }
            let t0 = DispatchTime.now()
            let opened = modelPath.withCString { m in
                tokensPath.withCString { t in
                    flk_sherpa_open(m, t, Int32(threadCount))
                }
            }
            loadMs = Int(Double(DispatchTime.now().uptimeNanoseconds - t0.uptimeNanoseconds) / 1_000_000)
            guard let opened else {
                throw LocalIndicError.openFailed(String(cString: flk_sherpa_last_error()))
            }
            ctx = opened
            loadedModelDir = modelDir
            os_log(.info, log: indicLog, "loaded IndicConformer in %dms", loadMs)
        }
        guard let handle = ctx else { throw LocalIndicError.openFailed("context unavailable") }

        let t1 = DispatchTime.now()
        let raw: UnsafeMutablePointer<CChar>? = samples.withUnsafeBufferPointer { buf in
            flk_sherpa_transcribe(handle, buf.baseAddress, Int32(buf.count))
        }
        let txMs = Int(Double(DispatchTime.now().uptimeNanoseconds - t1.uptimeNanoseconds) / 1_000_000)

        guard let raw else {
            throw LocalIndicError.transcribeFailed(String(cString: flk_sherpa_last_error()))
        }
        let text = String(cString: raw)
        flk_sherpa_string_free(raw)

        scheduleUnload(after: keepWarmSeconds)
        os_log(.info, log: indicLog, "IndicConformer: %d chars in %dms", text.count, txMs)
        return LocalIndicResult(text: text, loadMilliseconds: loadMs, transcribeMilliseconds: txMs)
        #endif
    }

    func unload() {
        #if FLK_LOCAL_INDIC
        unloadTask?.cancel(); unloadTask = nil
        unloadLocked()
        #endif
    }

    #if FLK_LOCAL_INDIC
    private func unloadLocked() {
        if let handle = ctx {
            flk_sherpa_close(handle)
            os_log(.info, log: indicLog, "unloaded IndicConformer")
        }
        ctx = nil
        loadedModelDir = nil
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
