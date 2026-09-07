// ============================================================
// FILE: Sources/LocalAI/LocalWhisperEngine.swift
// FlowKeys — Local AI (Phase 2)
//
// Swift wrapper over the whisper.cpp C bridge (Sources/LocalAI/CWhisper).
// Only compiled when the app is built with LOCAL_AI=1 (-D FLK_LOCAL_AI).
//
// Lifecycle discipline (requirements/UNIFIED_UPGRADE_PLAN.md §3.5):
//   - model is loaded on first use, kept warm briefly, then unloaded
//   - `unload()` fully releases the whisper_context
//   - nothing is resident while the app is idle
// ============================================================

import Foundation
@preconcurrency import AVFoundation
import os.log

private let engineLog = OSLog(subsystem: "com.flowkeys.app", category: "LocalWhisper")

// `WhisperSegment` and `LocalWhisperResult` are defined in SpeechAnalysis.swift
// (plain data types shared with the deterministic analysis layer).

enum LocalWhisperError: LocalizedError {
    case notBuiltWithLocalAI
    case modelMissing(String)
    case openFailed(String)
    case transcribeFailed(String)
    case emptyAudio

    var errorDescription: String? {
        switch self {
        case .notBuiltWithLocalAI: return "This build does not include the on-device engine."
        case .modelMissing(let p): return "Local model file not found at \(p)."
        case .openFailed(let m): return "Could not load the local model: \(m)"
        case .transcribeFailed(let m): return "Local transcription failed: \(m)"
        case .emptyAudio: return "No audio to transcribe."
        }
    }
}

/// Serializes access to the whisper context (not thread-safe in whisper.cpp).
actor LocalWhisperEngine {

    private var loadedModelPath: String?
    private var threadCount: Int
    private var unloadTask: Task<Void, Never>?

    #if FLK_LOCAL_AI
    private var ctx: OpaquePointer?
    #endif

    init(threadCount: Int = 0) {
        self.threadCount = threadCount
    }

    var isBuiltWithLocalAI: Bool {
        #if FLK_LOCAL_AI
        return true
        #else
        return false
        #endif
    }

    func setThreadCount(_ n: Int) { threadCount = n }

    /// Transcribe a mono/interleaved audio file (any format AVAudioFile can read;
    /// FlowKeys feeds a 16 kHz mono int16 WAV from AudioNormalization).
    func transcribe(fileURL: URL,
                    languageToken: String?,
                    initialPrompt: String?,
                    vadModelPath: String? = nil,
                    keepWarmSeconds: Int) async throws -> LocalWhisperResult {
        #if !FLK_LOCAL_AI
        throw LocalWhisperError.notBuiltWithLocalAI
        #else
        let samples = try Self.loadMono16kFloat(from: fileURL)
        guard !samples.isEmpty else { throw LocalWhisperError.emptyAudio }
        return try await transcribe(samples: samples,
                                    languageToken: languageToken,
                                    initialPrompt: initialPrompt,
                                    vadModelPath: vadModelPath,
                                    keepWarmSeconds: keepWarmSeconds)
        #endif
    }

    func transcribe(samples: [Float],
                    languageToken: String?,
                    initialPrompt: String?,
                    modelPath: String? = nil,
                    vadModelPath: String? = nil,
                    keepWarmSeconds: Int = 0) async throws -> LocalWhisperResult {
        #if !FLK_LOCAL_AI
        throw LocalWhisperError.notBuiltWithLocalAI
        #else
        unloadTask?.cancel(); unloadTask = nil

        var loadMs = 0
        let targetModel = modelPath ?? loadedModelPath
        guard let modelPath = targetModel else {
            throw LocalWhisperError.openFailed("no model selected")
        }
        if ctx == nil || loadedModelPath != modelPath {
            unloadLocked()
            guard FileManager.default.fileExists(atPath: modelPath) else {
                throw LocalWhisperError.modelMissing(modelPath)
            }
            let t0 = DispatchTime.now()
            let opened = modelPath.withCString { flk_whisper_open($0, Int32(threadCount)) }
            loadMs = Int(Double(DispatchTime.now().uptimeNanoseconds - t0.uptimeNanoseconds) / 1_000_000)
            guard let opened else {
                throw LocalWhisperError.openFailed(String(cString: flk_whisper_last_error()))
            }
            ctx = opened
            loadedModelPath = modelPath
            os_log(.info, log: engineLog, "loaded %{public}@ in %dms", (modelPath as NSString).lastPathComponent, loadMs)
        }

        guard let handle = ctx else { throw LocalWhisperError.openFailed("context unavailable") }

        let lang = languageToken.flatMap { $0.isEmpty ? nil : $0 }
        let prompt = initialPrompt.flatMap { $0.isEmpty ? nil : $0 }
        let vad = vadModelPath.flatMap {
            (!$0.isEmpty && FileManager.default.fileExists(atPath: $0)) ? $0 : nil
        }

        let t1 = DispatchTime.now()
        let raw: UnsafeMutablePointer<CChar>? = samples.withUnsafeBufferPointer { buf in
            Self.withOptionalCString(lang) { cLang in
                Self.withOptionalCString(prompt) { cPrompt in
                    Self.withOptionalCString(vad) { cVad in
                        flk_whisper_transcribe(handle, buf.baseAddress, Int32(buf.count),
                                               cLang, cPrompt, 0, cVad)
                    }
                }
            }
        }
        let txMs = Int(Double(DispatchTime.now().uptimeNanoseconds - t1.uptimeNanoseconds) / 1_000_000)

        guard let raw else {
            throw LocalWhisperError.transcribeFailed(String(cString: flk_whisper_last_error()))
        }
        let text = String(cString: raw)
        flk_whisper_string_free(raw)

        let detected = String(cString: flk_whisper_detected_language(handle))
        let segments = Self.readSegments(handle)
        let vadSpans = Self.readVadSpans(handle)

        scheduleUnload(after: keepWarmSeconds)

        return LocalWhisperResult(text: text,
                                  detectedLanguage: detected,
                                  loadMilliseconds: loadMs,
                                  transcribeMilliseconds: txMs,
                                  segments: segments,
                                  vadSpans: vadSpans)
        #endif
    }

    #if FLK_LOCAL_AI
    private static func readSegments(_ handle: OpaquePointer) -> [WhisperSegment] {
        let n = Int(flk_whisper_segment_count(handle))
        guard n > 0 else { return [] }
        var out: [WhisperSegment] = []
        out.reserveCapacity(n)
        for i in 0..<n {
            var t0: Int64 = 0, t1: Int64 = 0
            var textPtr: UnsafePointer<CChar>?
            guard flk_whisper_segment(handle, Int32(i), &t0, &t1, &textPtr) == 1 else { continue }
            let text = textPtr.map { String(cString: $0) } ?? ""
            out.append(WhisperSegment(text: text,
                                      startSeconds: Double(t0) / 100.0,
                                      endSeconds: Double(t1) / 100.0))
        }
        return out
    }

    private static func readVadSpans(_ handle: OpaquePointer) -> [ClosedRange<Double>] {
        let n = Int(flk_whisper_vad_segment_count(handle))
        guard n > 0 else { return [] }
        var out: [ClosedRange<Double>] = []
        for i in 0..<n {
            var t0: Int64 = 0, t1: Int64 = 0
            guard flk_whisper_vad_segment(handle, Int32(i), &t0, &t1) == 1 else { continue }
            let a = Double(t0) / 100.0, b = Double(t1) / 100.0
            if b >= a { out.append(a...b) }
        }
        return out
    }
    #endif

    /// Preload a model so the first real dictation is fast (optional, profile-gated).
    func preload(modelPath: String) async throws {
        #if FLK_LOCAL_AI
        guard ctx == nil || loadedModelPath != modelPath else { return }
        guard FileManager.default.fileExists(atPath: modelPath) else {
            throw LocalWhisperError.modelMissing(modelPath)
        }
        unloadLocked()
        let opened = modelPath.withCString { flk_whisper_open($0, Int32(threadCount)) }
        guard let opened else {
            throw LocalWhisperError.openFailed(String(cString: flk_whisper_last_error()))
        }
        ctx = opened
        loadedModelPath = modelPath
        #endif
    }

    func unload() {
        #if FLK_LOCAL_AI
        unloadTask?.cancel(); unloadTask = nil
        unloadLocked()
        #endif
    }

    var version: String {
        #if FLK_LOCAL_AI
        return String(cString: flk_whisper_version())
        #else
        return "n/a"
        #endif
    }

    // MARK: - Private

    #if FLK_LOCAL_AI
    private func unloadLocked() {
        if let handle = ctx {
            flk_whisper_close(handle)
            os_log(.info, log: engineLog, "unloaded whisper model")
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

    private static func withOptionalCString<R>(_ s: String?,
                                               _ body: (UnsafePointer<CChar>?) -> R) -> R {
        if let s { return s.withCString(body) }
        return body(nil)
    }

    // MARK: - Audio loading (16 kHz mono float)

    static func loadMono16kFloat(from url: URL) throws -> [Float] {
        let file = try AVAudioFile(forReading: url)
        let srcFormat = file.processingFormat
        guard let dstFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                            sampleRate: 16_000,
                                            channels: 1,
                                            interleaved: false) else {
            return []
        }

        let srcBuffer = AVAudioPCMBuffer(pcmFormat: srcFormat,
                                         frameCapacity: AVAudioFrameCount(max(file.length, 1)))
        guard let srcBuffer else { return [] }
        try file.read(into: srcBuffer)

        // Fast path: already 16 kHz mono float.
        if abs(srcFormat.sampleRate - 16_000) < 0.5,
           srcFormat.channelCount == 1,
           srcFormat.commonFormat == .pcmFormatFloat32,
           let ch = srcBuffer.floatChannelData {
            return Array(UnsafeBufferPointer(start: ch[0], count: Int(srcBuffer.frameLength)))
        }

        guard let converter = AVAudioConverter(from: srcFormat, to: dstFormat) else { return [] }
        let ratio = 16_000.0 / srcFormat.sampleRate
        let outCapacity = AVAudioFrameCount(Double(srcBuffer.frameLength) * ratio) + 4096
        guard let outBuffer = AVAudioPCMBuffer(pcmFormat: dstFormat, frameCapacity: outCapacity) else {
            return []
        }

        var fed = false
        var convError: NSError?
        let statusValue = converter.convert(to: outBuffer, error: &convError) { _, inStatus in
            if fed { inStatus.pointee = .endOfStream; return nil }
            fed = true
            inStatus.pointee = .haveData
            return srcBuffer
        }
        if statusValue == .error || convError != nil { return [] }
        guard let ch = outBuffer.floatChannelData else { return [] }
        return Array(UnsafeBufferPointer(start: ch[0], count: Int(outBuffer.frameLength)))
    }
}
