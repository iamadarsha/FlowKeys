// ============================================================
// FILE: Tests/local_ai_tests.swift
// FlowKeys — Local AI test harness (dependency-free)
//
// Compiled and run by `make test-local` / regression_smoke.sh / CI.
// A failing assertion prints "FAIL: ..." and the process exits non-zero.
//
// Kept as a plain executable (not XCTest/SPM) to match the repo's
// zero-dependency `swiftc` build.
// ============================================================

import Foundation

var failures = 0
func check(_ cond: Bool, _ label: String) {
    if cond { print("  ok   \(label)") }
    else { print("  FAIL \(label)"); failures += 1 }
}
func section(_ s: String) { print("\n[\(s)]") }

@main
enum LocalAITests {
  static func main() {
    setbuf(stdout, nil)
    run()
    print("")
    if failures == 0 { print("LOCAL AI TESTS: PASS"); exit(0) }
    else { print("LOCAL AI TESTS: \(failures) FAILURE(S)"); exit(1) }
  }

  static func run() {

// ---------------------------------------------------------------------------
section("LocalAISettings — safe defaults")
do {
    let s = LocalAISettings()
    check(s.isEnabled == false, "isEnabled defaults false")
    check(s.route == .existingCloud, "route defaults to existingCloud")
    check(s.localPathActive == false, "localPathActive false by default")
    check(s.schemaVersion == LocalAISettings.currentSchemaVersion, "schemaVersion current")
    check(s.effectiveUnloadAfterSeconds == 30, "balanced profile unloads after 30s")

    var lowPower = s
    lowPower.performanceProfile = .lowPower
    check(lowPower.effectiveUnloadAfterSeconds == 0, "low-power unloads immediately")

    var enabled = s
    enabled.isEnabled = true
    enabled.route = .local
    check(enabled.localPathActive == true, "enabled + local => localPathActive")
}

// ---------------------------------------------------------------------------
section("LocalAISettings — round-trip persistence, corrupt-safe")
do {
    let defaults = UserDefaults(suiteName: "flowkeys.test.\(UUID().uuidString)")!
    let store = LocalAISettingsStore(defaults: defaults)
    check(store.load() == .disabledDefault, "absent key => disabled default")

    var s = LocalAISettings()
    s.isEnabled = true
    s.route = .hybrid
    s.asrModelID = "whisper-base-q5_1"
    store.save(s)
    let reloaded = store.load()
    check(reloaded.isEnabled && reloaded.route == .hybrid && reloaded.asrModelID == "whisper-base-q5_1",
          "settings round-trip")

    defaults.set(Data([0x00, 0x01, 0x02]), forKey: LocalAISettingsStore.storageKey)
    check(store.load() == .disabledDefault, "corrupt payload => disabled default (no crash)")
}

// ---------------------------------------------------------------------------
section("LocalModelManifest — security invariants")
do {
    check(!LocalModelManifest.all.isEmpty, "manifest is non-empty")
    for m in LocalModelManifest.all {
        check(m.url.scheme == "https", "\(m.id): https")
        check(LocalModelManifest.allowedHosts.contains(m.url.host ?? ""), "\(m.id): host allow-listed")
        check(m.expectedByteSize > 0, "\(m.id): has expected size")
        if m.verified {
            check(m.checksumSHA256?.count == 64, "\(m.id): verified => 64-hex checksum")
            check(m.isActivatable, "\(m.id): verified => activatable")
        }
    }
    check(LocalModelManifest.descriptor(id: "whisper-base-q5_1")?.verified == true,
          "base-q5_1 checksum pinned")
    check(LocalModelManifest.descriptor(id: "whisper-large-v3-turbo-q5_0")?.verified == true,
          "turbo-q5_0 checksum pinned")
    check(!LocalModelManifest.isAllowed(URL(string: "https://evil.example.com/model.bin")!),
          "unknown host rejected")
    check(!LocalModelManifest.isAllowed(URL(string: "http://huggingface.co/x")!),
          "non-https rejected")
    check(LocalModelManifest.models(of: .asrWhisper).count >= 2, "≥2 whisper ASR models offered")
}

// ---------------------------------------------------------------------------
section("LanguageRouting — legacy mapping never changes meaning")
do {
    let en = LanguageSelection(legacy: .pureEnglish)
    check(en.language == .english && en.script == .automatic, ".pureEnglish -> English/auto")
    check(en.language.asrLanguageToken == "en", "English ASR token = en")

    let hi = LanguageSelection(legacy: .pureHindi)
    check(hi.language == .hindi && hi.script == .native, ".pureHindi -> Hindi/native")
    check(hi.language.asrLanguageToken == "hi", "Hindi ASR token = hi")

    let hinglish = LanguageSelection(legacy: .hinglish)
    check(hinglish.language == .hinglish && hinglish.script == .roman, ".hinglish -> Hinglish/roman")
    check(hinglish.language.asrLanguageToken == "hi", "Hinglish ASR token = hi (code-mix)")
    check(hinglish.language.allowsCodeSwitching, "Hinglish allows code-switching")

    check(LanguageSelection.Language.bengali.asrLanguageToken == "bn", "Bengali ASR token = bn")
    check(LanguageSelection.Language.auto.asrLanguageToken == nil, "auto => no token")

    // Router defers to legacy when no override.
    let resolved = LanguageRouter.resolve(legacyMode: .pureHindi, override: nil)
    check(resolved.language == .hindi, "router uses legacy mode when no override")
    let overridden = LanguageRouter.resolve(legacyMode: .pureEnglish,
                                            override: LanguageSelection(language: .bengali, script: .native))
    check(overridden.language == .bengali, "router honors override")
}

// ---------------------------------------------------------------------------
section("FillerDetector — removes noise, keeps meaning")
do {
    let (en, rmEn) = FillerDetector.strip(
        "um so I I wanted to uh say that the report is done",
        level: .standard, language: .english)
    check(!en.lowercased().contains("um") && !en.contains(" uh "), "English um/uh removed")
    check(en.contains("wanted to say") || en.contains("wanted to  say") || en.contains("to say"), "false-start 'I I' collapsed")
    check(rmEn.contains("um") && rmEn.contains("uh"), "removed list reports um/uh")

    let (lit, rmLit) = FillerDetector.strip("um so I wanted to say", level: .literal, language: .english)
    check(lit == "um so I wanted to say" && rmLit.isEmpty, "literal level removes nothing")

    let (hi, _) = FillerDetector.strip("matlab aaj meeting hai umm theek hai yaar",
                                      level: .standard, language: .hinglish)
    check(!hi.lowercased().contains("umm"), "Hinglish umm removed")
    check(hi.contains("yaar"), "trailing 'yaar' (tone marker) kept")
    check(hi.contains("theek hai"), "'theek hai' kept (carries meaning)")

    // Never strip a meaningful mid-sentence word.
    let (keep, _) = FillerDetector.strip("I actually finished the actually hard part",
                                        level: .standard, language: .english)
    check(keep.contains("hard part"), "mid-sentence 'actually' not blindly removed")
}

// ---------------------------------------------------------------------------
section("SelfCorrectionDetector — events, not edits")
do {
    let e = SelfCorrectionDetector.detect("let's meet Thursday no actually Wednesday after lunch")
    check(e.count == 1 && e[0].marker == "no actually", "detects 'no actually'")
    check(e[0].keptText.hasPrefix("wednesday"), "kept span starts at correction")
    check(SelfCorrectionDetector.detect("the meeting is on Friday").isEmpty, "no false positives")
}

// ---------------------------------------------------------------------------
section("PauseAnalyzer — classifies gaps")
do {
    let spans: [ClosedRange<Double>] = [0.0...1.0, 1.15...2.0, 2.9...4.0, 6.0...7.0]
    let p = PauseAnalyzer.pauses(from: spans)
    check(p.count == 3, "three inter-span gaps above the 0.12s floor")
    check(p.count == 3 && p[0].kind == .micro, "0.15s gap => micro")
    check(p.count == 3 && p[1].kind == .hesitation, "0.9s gap => hesitation")
    check(p.count == 3 && p[2].kind == .boundary, "2.0s gap => boundary")
    check(PauseAnalyzer.pauses(from: [0.0...1.0, 1.05...2.0]).isEmpty, "sub-0.12s gap ignored")
}

// ---------------------------------------------------------------------------
section("TextNormalizer + whisper-mode gain")
do {
    check(TextNormalizer.tidy("hello   world ,  ok .") == "hello world, ok.", "spacing/punct tidied")
    let quiet = (0..<8000).map { Float(sin(Double($0) * 0.1)) * 0.02 }   // ~-34 dBFS
    let boosted = WhisperModeGain.apply(quiet)
    let peak = boosted.map { abs($0) }.max() ?? 0
    check(peak > 0.05 && peak <= 1.0, "quiet speech boosted, no clipping")
    let silent = [Float](repeating: 0, count: 8000)
    check(WhisperModeGain.apply(silent) == silent, "pure silence untouched")
}

// ---------------------------------------------------------------------------
section("CryptoKitSHA256 — known vector")
do {
    let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("flk-sha-\(UUID().uuidString)")
    try? "abc".data(using: .utf8)!.write(to: tmp)
    defer { try? FileManager.default.removeItem(at: tmp) }
    let digest = (try? CryptoKitSHA256.hex(of: tmp)) ?? ""
    check(digest == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
          "SHA-256(\"abc\") matches NIST vector")
}

  }
}
