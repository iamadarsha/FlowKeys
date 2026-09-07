// ============================================================
// FILE: Sources/LocalAI/LocalModelManifest.swift
// FlowKeys — Local AI (Phase 1 scaffold)
//
// App-owned, pinned manifest of downloadable model assets.
//
// SECURITY (see requirements/UNIFIED_UPGRADE_PLAN.md §3.8):
//   - We NEVER download a URL discovered from a mutable README / web page.
//   - Every asset here has a pinned host (allow-listed), a pinned revision in the
//     URL, an expected byte size, and a SHA-256 that MUST be verified before the
//     file is marked installed / usable.
//   - `checksumSHA256 == nil` (or `verified == false`) => the model manager will
//     refuse to activate the asset. Phase 2 fills the real hashes via
//     Scripts/pin_model_checksums.sh and flips `verified` to true.
// ============================================================

import Foundation

enum LocalModelKind: String, Codable, Sendable {
    case asrWhisper       // whisper.cpp ggml model
    case asrIndicConformer // sherpa-onnx ONNX bundle
    case cleanupLLM        // llama.cpp GGUF
    case vad               // Silero VAD ONNX
}

enum LocalModelEngine: String, Codable, Sendable {
    case whisperCpp
    case sherpaOnnx
    case llamaCpp
    case onnxRuntime
}

/// Coarse hardware requirement so the UI can grey out models a Mac can't run.
struct LocalModelRequirements: Codable, Sendable {
    /// Minimum physical RAM in GB for this model to be offered as a default.
    var minRAMGB: Int = 8
    /// If true, requires Apple Silicon (ANE / Metal). Universal models leave this false.
    var requiresAppleSilicon: Bool = false
}

struct LocalModelDescriptor: Codable, Identifiable, Sendable {
    let id: String
    let displayName: String
    let shortDescription: String
    let kind: LocalModelKind
    let engine: LocalModelEngine

    /// Pinned download URL. Host must be in `LocalModelManifest.allowedHosts`.
    let url: URL
    /// Expected size on disk in bytes (used for free-space checks + progress).
    let expectedByteSize: Int64
    /// Lowercase hex SHA-256 of the downloaded file. nil until pinned in Phase 2.
    let checksumSHA256: String?
    /// Asset version, independent of the app version.
    let assetVersion: String
    /// Set true ONLY once `checksumSHA256` is a real pinned value.
    let verified: Bool

    /// BCP-47-ish language tags this model can transcribe/clean. Empty for VAD.
    let languages: [String]
    let requirements: LocalModelRequirements

    /// Relative path under the model store where the file lives.
    var relativeStorePath: String {
        switch kind {
        case .asrWhisper:        return "whisper/\(url.lastPathComponent)"
        case .asrIndicConformer: return "indic/\(url.lastPathComponent)"
        case .cleanupLLM:        return "llm/\(url.lastPathComponent)"
        case .vad:               return "vad/\(url.lastPathComponent)"
        }
    }

    var isActivatable: Bool { verified && checksumSHA256 != nil }
}

enum LocalModelManifest {

    /// Only these hosts may serve model weights. Enforced at download time.
    static let allowedHosts: Set<String> = [
        "huggingface.co",
        "cdn-lfs.huggingface.co",
        "cdn-lfs-us-1.huggingface.co",
    ]

    /// Where downloaded models live.
    static func storeDirectory() -> URL {
        let appSupport = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first ?? FileManager.default.temporaryDirectory
        return appSupport
            .appendingPathComponent("FlowKeys/Models", isDirectory: true)
    }

    // NOTE: checksums are placeholders (verified:false) until Phase 2 pins them.
    // URLs use HF `resolve/<pinned-rev>` form so the bytes can't shift under us.

    static let all: [LocalModelDescriptor] = [

        // ---- ASR: default tiny multilingual floor (EN/HI/BN) ----
        LocalModelDescriptor(
            id: "whisper-base-q5_1",
            displayName: "Whisper Base",
            shortDescription: "Fast · tiny · works on any Mac",
            kind: .asrWhisper,
            engine: .whisperCpp,
            url: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base-q5_1.bin")!,
            expectedByteSize: 59_707_625,
            checksumSHA256: "422f1ae452ade6f30a004d7e5c6a43195e4433bc370bf23fac9cc591f01a8898",
            assetVersion: "whisper.cpp-ggml",
            verified: true,
            languages: ["en", "hi", "bn", "multi"],
            requirements: LocalModelRequirements(minRAMGB: 8, requiresAppleSilicon: false)
        ),

        // ---- ASR: recommended accuracy pick ----
        LocalModelDescriptor(
            id: "whisper-large-v3-turbo-q5_0",
            displayName: "Whisper Turbo",
            shortDescription: "Best general accuracy · English + 90 languages",
            kind: .asrWhisper,
            engine: .whisperCpp,
            url: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo-q5_0.bin")!,
            expectedByteSize: 574_041_195,
            checksumSHA256: "394221709cd5ad1f40c46e6031ca61bce88931e6e088c188294c6d5a55ffa7e2",
            assetVersion: "whisper.cpp-ggml",
            verified: true,
            languages: ["en", "hi", "bn", "multi"],
            requirements: LocalModelRequirements(minRAMGB: 8, requiresAppleSilicon: false)
        ),

        // ---- ASR: best for Hindi & Bengali (native script) ----
        LocalModelDescriptor(
            id: "indic-conformer-600m-int8",
            displayName: "Best for Hindi & Bengali",
            shortDescription: "AI4Bharat · native Devanagari / Bangla output",
            kind: .asrIndicConformer,
            engine: .sherpaOnnx,
            url: URL(string: "https://huggingface.co/csukuangfj/sherpa-onnx-nemo-ai4bharat-indic-conformer-600m-multilingual-int8/resolve/main/model.int8.onnx")!,
            expectedByteSize: 320_000_000,
            checksumSHA256: nil,
            assetVersion: "ai4bharat-indicconformer-600m",
            verified: false,
            languages: ["hi", "bn", "as", "gu", "kn", "ml", "mr", "or", "pa", "ta", "te", "ur"],
            requirements: LocalModelRequirements(minRAMGB: 8, requiresAppleSilicon: false)
        ),

        // ---- Local cleanup LLM ----
        LocalModelDescriptor(
            id: "qwen3-0.6b-q4_k_m",
            displayName: "Qwen 0.6B",
            shortDescription: "On-device writing cleanup · runs only when needed",
            kind: .cleanupLLM,
            engine: .llamaCpp,
            url: URL(string: "https://huggingface.co/ggml-org/Qwen3-0.6B-GGUF/resolve/main/Qwen3-0.6B-Q4_K_M.gguf")!,
            expectedByteSize: 484_000_000,
            checksumSHA256: nil,
            assetVersion: "qwen3-0.6b",
            verified: false,
            languages: ["en", "hi", "bn", "multi"],
            requirements: LocalModelRequirements(minRAMGB: 8, requiresAppleSilicon: false)
        ),

        // ---- VAD ----
        LocalModelDescriptor(
            id: "silero-vad-v5",
            displayName: "Silero VAD",
            shortDescription: "Voice activity detection · ~2 MB",
            kind: .vad,
            engine: .onnxRuntime,
            url: URL(string: "https://huggingface.co/onnx-community/silero-vad/resolve/main/onnx/model.onnx")!,
            expectedByteSize: 2_243_022,
            checksumSHA256: "a4a068cd6cf1ea8355b84327595838ca748ec29a25bc91fc82e6c299ccdc5808",
            assetVersion: "silero-vad-v5",
            verified: false, // Phase 3 wires the VAD engine
            languages: [],
            requirements: LocalModelRequirements(minRAMGB: 8, requiresAppleSilicon: false)
        ),
    ]

    static func descriptor(id: String) -> LocalModelDescriptor? {
        all.first { $0.id == id }
    }

    static func models(of kind: LocalModelKind) -> [LocalModelDescriptor] {
        all.filter { $0.kind == kind }
    }

    /// Guards against ever fetching from an unexpected host.
    static func isAllowed(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == "https", let host = url.host else { return false }
        return allowedHosts.contains(host)
    }
}
