// ============================================================
// FILE: Sources/LocalAI/LanguageRouting.swift
// FlowKeys — Local AI (Phase 1 scaffold)
//
// Richer language + output-script model that layers ON TOP of the existing
// `UserLanguageMode` (hinglish / hindi / english) WITHOUT changing it.
//
//   - `UserLanguageMode` stays the persisted source of truth (key "language_mode").
//   - This file only *derives* a `LanguageSelection` from it, and adds Bengali +
//     explicit script control that nothing consumes yet (wired in Phase 4).
//   - Mapping never changes the meaning of an existing mode
//     (see requirements/UNIFIED_UPGRADE_PLAN.md §1 "Bengali + script contract").
// ============================================================

import Foundation

struct LanguageSelection: Codable, Equatable, Sendable {

    enum Language: String, Codable, CaseIterable, Sendable {
        case auto
        case english
        case hindi
        case bengali
        case hinglish   // Hindi–English code-switch
        case banglish   // Bengali–English code-switch

        var displayName: String {
            switch self {
            case .auto:     return "Auto-detect"
            case .english:  return "English"
            case .hindi:    return "हिंदी"
            case .bengali:  return "বাংলা"
            case .hinglish: return "Hinglish"
            case .banglish: return "Banglish"
            }
        }

        /// Whisper / ASR language token. `auto` => let the engine decide.
        var asrLanguageToken: String? {
            switch self {
            case .auto:     return nil
            case .english:  return "en"
            case .hindi:    return "hi"
            case .bengali:  return "bn"
            case .hinglish: return "hi"   // <|hi|> outperforms <|en|> for code-mix
            case .banglish: return "bn"
            }
        }

        var allowsCodeSwitching: Bool {
            switch self {
            case .hinglish, .banglish, .auto: return true
            case .english, .hindi, .bengali:  return false
            }
        }
    }

    /// Script the *output text* should be written in.
    enum Script: String, Codable, CaseIterable, Sendable {
        /// Mirror whatever script the speaker/ASR produced.
        case automatic
        /// Force the language's native script (Devanagari / Bangla / Latin).
        case native
        /// Force Latin transliteration.
        case roman

        var displayName: String {
            switch self {
            case .automatic: return "Auto"
            case .native:    return "Native"
            case .roman:     return "Roman"
            }
        }
    }

    var language: Language
    var script: Script

    static let englishAuto = LanguageSelection(language: .english, script: .automatic)

    // MARK: - Legacy bridge (non-destructive)

    /// Derive a selection from the existing persisted `UserLanguageMode`.
    /// This must preserve current behavior exactly:
    ///   .pureEnglish -> English, automatic script
    ///   .pureHindi   -> Hindi, native script (current app already outputs Devanagari)
    ///   .hinglish    -> Hinglish, roman script (current app keeps Roman for Hinglish)
    init(legacy mode: UserLanguageMode) {
        switch mode {
        case .pureEnglish:
            self = LanguageSelection(language: .english, script: .automatic)
        case .pureHindi:
            self = LanguageSelection(language: .hindi, script: .native)
        case .hinglish:
            self = LanguageSelection(language: .hinglish, script: .roman)
        }
    }

    init(language: Language, script: Script) {
        self.language = language
        self.script = script
    }

    /// Best-effort reverse map, used only where legacy APIs still require a
    /// `UserLanguageMode`. Bengali/Banglish/Auto collapse to the closest legacy
    /// value so existing cloud paths keep working until Phase 4 teaches them Bengali.
    var closestLegacyMode: UserLanguageMode {
        switch language {
        case .english:            return .pureEnglish
        case .hindi:              return .pureHindi
        case .hinglish, .banglish: return .hinglish
        case .bengali:            return script == .roman ? .hinglish : .pureHindi
        case .auto:               return .pureEnglish
        }
    }
}

/// Non-persisted helper that resolves the *effective* language selection for a run.
/// Phase 1: always returns the legacy-derived value. Later phases add per-app
/// overrides, auto-detect results, and the menu-bar quick switcher.
struct LanguageRouter {

    /// - Parameters:
    ///   - legacyMode: the current `AppState.languageMode`.
    ///   - override: an explicit selection from the (future) quick switcher / mode.
    static func resolve(legacyMode: UserLanguageMode,
                        override: LanguageSelection? = nil) -> LanguageSelection {
        override ?? LanguageSelection(legacy: legacyMode)
    }
}
