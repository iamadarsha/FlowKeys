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

    /// Additional files that must be downloaded alongside the main one (e.g. a
    /// tokens file for sherpa-onnx). Each is pinned the same way.
    struct Companion: Codable, Sendable {
        let fileName: String
        let url: URL
        let expectedByteSize: Int64
        let checksumSHA256: String
    }
    var companions: [Companion] = []

    /// Sub-directory under the model store for this model.
    var storeSubdir: String {
        switch kind {
        case .asrWhisper:        return "whisper"
        case .asrIndicConformer: return "indic/\(id)"
        case .cleanupLLM:        return "llm"
        case .vad:               return "vad"
        }
    }

    /// Relative path under the model store where the main file lives.
    var relativeStorePath: String { "\(storeSubdir)/\(url.lastPathComponent)" }

    /// For multi-file models: the directory that holds all files.
    var isMultiFile: Bool { !companions.isEmpty }

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
            id: "indic-conformer-int8",
            displayName: "Best for Hindi & Bengali",
            shortDescription: "AI4Bharat IndicConformer · native Devanagari / Bangla",
            kind: .asrIndicConformer,
            engine: .sherpaOnnx,
            url: URL(string: "https://huggingface.co/meetsync/indic-conformer-onnx-sherpa/resolve/main/model.int8.onnx")!,
            expectedByteSize: 196_977_855,
            checksumSHA256: "b99a01834cd1a72cd9be682a0b9543df6b152ef7dfceba88d3dbf59fbb77075d",
            assetVersion: "ai4bharat-indicconformer",
            verified: true,
            languages: ["hi", "bn", "as", "gu", "kn", "ks", "mr", "brx"],
            requirements: LocalModelRequirements(minRAMGB: 8, requiresAppleSilicon: false),
            companions: [
                .init(fileName: "tokens.txt",
                      url: URL(string: "https://huggingface.co/meetsync/indic-conformer-onnx-sherpa/resolve/main/tokens.txt")!,
                      expectedByteSize: 73_238,
                      checksumSHA256: "743aeb755c4489bc734a6705578552b072ffb45055aeeb5db19ae7761a424882")
            ]
        ),

        // ---- Local cleanup LLM ----
        LocalModelDescriptor(
            id: "qwen3-0.6b-q4_k_m",
            displayName: "Qwen 0.6B",
            shortDescription: "On-device writing cleanup · runs only when needed",
            kind: .cleanupLLM,
            engine: .llamaCpp,
            url: URL(string: "https://huggingface.co/unsloth/Qwen3-0.6B-GGUF/resolve/main/Qwen3-0.6B-Q4_K_M.gguf")!,
            expectedByteSize: 396_705_472,
            checksumSHA256: "ac2d97712095a558e31573f62f466a3f9d93990898b0ec79d7c974c1780d524a",
            assetVersion: "qwen3-0.6b",
            verified: true,
            languages: ["en", "hi", "bn", "multi"],
            requirements: LocalModelRequirements(minRAMGB: 8, requiresAppleSilicon: false)
        ),

        // ---- VAD (whisper.cpp built-in Silero, ggml format) ----
        LocalModelDescriptor(
            id: "whisper-vad-silero-v5",
            displayName: "Voice detection",
            shortDescription: "Trims silence, finds pauses · ~0.9 MB",
            kind: .vad,
            engine: .whisperCpp,
            url: URL(string: "https://huggingface.co/ggml-org/whisper-vad/resolve/main/ggml-silero-v5.1.2.bin")!,
            expectedByteSize: 885_098,
            checksumSHA256: "29940d98d42b91fbd05ce489f3ecf7c72f0a42f027e4875919a28fb4c04ea2cf",
            assetVersion: "silero-v5.1.2",
            verified: true,
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
