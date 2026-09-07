// ============================================================
// FILE: Sources/LocalAI/LocalAIController.swift
// FlowKeys — Local AI (Phase 1 scaffold)
//
// Public face of the optional on-device AI subsystem. `AppState` holds one of
// these and observes it. In Phase 1 it is INERT:
//   - constructs with disabled settings,
//   - loads no model, touches no microphone, starts no work,
//   - every action method is a no-op that returns a "not available yet" result.
//
// Phases 2-5 flesh this out (model manager, whisper.cpp bridge, VAD, cleanup,
// hybrid routing) behind this same interface so `AppState` wiring never churns.
// ============================================================

import Foundation
import Combine
import os.log

private let localAILog = OSLog(subsystem: "com.flowkeys.app", category: "LocalAI")

enum LocalAIState: Equatable, Sendable {
    case idle
    case preparing
    case downloadingModel(progress: Double)
    case transcribing
    case analyzing
    case cleaning
    case unavailable(reason: String)
}

/// Result of asking the local subsystem to handle a run.
enum LocalRouteDecision: Equatable, Sendable {
    /// Local AI is off / not ready — caller must use the existing cloud path.
    case useExistingCloud
    /// Local path should handle this run (Phase 2+).
    case useLocal
    /// Try local, but the given cloud provider is the sanctioned fallback (Phase 4+).
    case useHybrid(cloudFallback: Bool)
}

final class LocalAIController: ObservableObject {

    @Published private(set) var state: LocalAIState = .idle
    @Published private(set) var settings: LocalAISettings

    /// True when the subsystem can actually run something on-device.
    /// Phase 1: always false (no engine, no verified models).
    @Published private(set) var isOperational: Bool = false

    private let store: LocalAISettingsStore

    init(store: LocalAISettingsStore = LocalAISettingsStore()) {
        self.store = store
        self.settings = store.load()
        os_log(.info, log: localAILog,
               "LocalAIController init — enabled=%{public}d route=%{public}@ (Phase 1: inert)",
               settings.isEnabled, settings.route.rawValue)
    }

    // MARK: - Settings

    func update(_ mutate: (inout LocalAISettings) -> Void) {
        var next = settings
        mutate(&next)
        settings = next
        store.save(next)
        recomputeOperational()
    }

    private func recomputeOperational() {
        // Phase 1: nothing is verified/installed, so never operational.
        // Phase 2 replaces this with a real check against installed+verified models.
        isOperational = false
        if settings.localPathActive && !isOperational {
            state = .unavailable(reason: "Local AI is not installed yet.")
        } else {
            state = .idle
        }
    }

    // MARK: - Routing (called by AppState before a run)

    /// Decide how a dictation run should be processed.
    /// Phase 1: always defers to the existing cloud pipeline, guaranteeing
    /// zero behavior change for current users.
    func routeDecision() -> LocalRouteDecision {
        guard settings.localPathActive, isOperational else {
            return .useExistingCloud
        }
        switch settings.route {
        case .existingCloud: return .useExistingCloud
        case .local:         return .useLocal
        case .hybrid:        return .useHybrid(cloudFallback: settings.hybridCloudFallbackEnabled)
        }
    }

    // MARK: - Lifecycle hooks (no-ops in Phase 1)

    /// Called when the app goes idle — must guarantee no model stays resident.
    func releaseAllModels() {
        // Phase 1: nothing to release.
        state = .idle
    }

    /// Called on memory pressure / thermal events.
    func handleResourcePressure() {
        releaseAllModels()
    }
}
