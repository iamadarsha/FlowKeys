// ============================================================
// FILE: Sources/LocalAI/LocalAISettings.swift
// FlowKeys — Local AI (Phase 1 scaffold)
//
// Versioned, additive settings for the optional on-device AI subsystem.
// NOTHING here changes existing behavior:
//   - Stored under its OWN UserDefaults key ("local_ai_settings_v1").
//   - Defaults to fully disabled (`isEnabled == false`, route == .existingCloud).
//   - No existing key is read or written.
//
// Design rules (see requirements/UNIFIED_UPGRADE_PLAN.md §3):
//   - New persisted state uses new versioned keys only.
//   - Local AI is OFF by default so an app update is a zero-behavior-change event.
// ============================================================

import Foundation

/// Where a dictation run is processed.
enum TranscriptionRoute: String, Codable, CaseIterable, Sendable {
    /// Unchanged: use the currently selected cloud `TranscriptionProvider`.
    case existingCloud
    /// Everything on-device. Never falls back to cloud silently.
    case local
    /// Local first; configured cloud only when local confidence is low
    /// AND the user opted in (`hybridCloudFallbackEnabled`).
    case hybrid

    var displayName: String {
        switch self {
        case .existingCloud: return "Cloud"
        case .local: return "Local"
        case .hybrid: return "Hybrid"
        }
    }
}

/// Battery / accuracy trade-off for the local path.
enum LocalPerformanceProfile: String, Codable, CaseIterable, Sendable {
    case lowPower
    case balanced
    case accuracy

    var displayName: String {
        switch self {
        case .lowPower: return "Low Power"
        case .balanced: return "Balanced"
        case .accuracy: return "Accuracy"
        }
    }

    /// Seconds to keep a model resident after use before unloading.
    /// Low Power unloads immediately.
    var defaultUnloadAfterSeconds: Int {
        switch self {
        case .lowPower: return 0
        case .balanced: return 30
        case .accuracy: return 120
        }
    }

    /// Suggested inference thread cap starting point (benchmarked/tuned later).
    var suggestedThreadCap: Int {
        switch self {
        case .lowPower: return 2
        case .balanced: return 4
        case .accuracy: return 6
        }
    }
}

/// Single versioned payload for all Local-AI preferences.
/// Persist as one Codable blob rather than scattering many UserDefaults keys.
struct LocalAISettings: Codable, Equatable, Sendable {

    /// Bump when the schema changes; `migrate(from:)` handles upgrades.
    static let currentSchemaVersion = 1

    var schemaVersion: Int = LocalAISettings.currentSchemaVersion

    /// Master switch. When false the entire subsystem is inert and the app
    /// behaves exactly as it does today.
    var isEnabled: Bool = false

    var route: TranscriptionRoute = .existingCloud

    /// Only consulted when `route == .hybrid`.
    var hybridCloudFallbackEnabled: Bool = true

    var performanceProfile: LocalPerformanceProfile = .balanced

    /// nil → derive from `performanceProfile.defaultUnloadAfterSeconds`.
    var unloadAfterSecondsOverride: Int? = nil

    /// Chosen local ASR model id (see `LocalModelManifest`). nil → nothing selected yet.
    var asrModelID: String? = nil

    /// Chosen local cleanup-LLM model id. nil → deterministic cleanup only.
    var cleanupModelID: String? = nil

    /// Chosen local VAD model id. nil → VAD disabled.
    var vadModelID: String? = nil

    /// Developer diagnostics (timings, VAD segments, filler hits). Off by default.
    var showLocalDiagnostics: Bool = false

    var effectiveUnloadAfterSeconds: Int {
        unloadAfterSecondsOverride ?? performanceProfile.defaultUnloadAfterSeconds
    }

    /// True only when local processing should actually be attempted.
    var localPathActive: Bool {
        isEnabled && route != .existingCloud
    }

    static let disabledDefault = LocalAISettings()
}

// MARK: - Persistence

/// Thin, self-contained store. Uses its own key; never touches `AppState`'s keys.
final class LocalAISettingsStore {

    static let storageKey = "local_ai_settings_v1"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> LocalAISettings {
        guard let data = defaults.data(forKey: Self.storageKey) else {
            return .disabledDefault
        }
        do {
            let decoded = try JSONDecoder().decode(LocalAISettings.self, from: data)
            return Self.migrate(decoded)
        } catch {
            // Corrupt payload → fall back to safe disabled defaults, do not crash.
            return .disabledDefault
        }
    }

    func save(_ settings: LocalAISettings) {
        var toSave = settings
        toSave.schemaVersion = LocalAISettings.currentSchemaVersion
        guard let data = try? JSONEncoder().encode(toSave) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }

    /// Remove all Local-AI settings (used by "reset" / uninstall-local flows later).
    func clear() {
        defaults.removeObject(forKey: Self.storageKey)
    }

    static func migrate(_ settings: LocalAISettings) -> LocalAISettings {
        // Only v1 exists today. Future versions add cases here.
        settings
    }
}
