# FlowKeys Local AI — Phase Status

Tracks the 5-phase build from `requirements/UNIFIED_UPGRADE_PLAN.md`.
Each phase: own branch → CI green → manual `REGRESSION_CHECKLIST.md` → version bump → release.

| Phase | Branch | Build/CI | Regression | Released | Notes |
|---|---|---|---|---|---|
| **1 — scaffold (no-op)** | `feature/local-ai-phase-1` | ✅ CI green | ⬜ manual pending | ⬜ v1.3.0 | Inert `Sources/LocalAI/`, Makefile SDK fix, ci.yml, smoke script |
| **2 — local Whisper ASR** | `feature/local-ai-phase-2` | ✅ CI green | ⬜ manual pending | ⬜ v1.4.0 | whisper.cpp v1.9.3 vendored, C bridge, model manager, offline route, Local AI settings tab, onboarding card, file-transcription route. Verified E2E. |
| **3 — VAD + disfluency** | `feature/local-ai-phase-3` | ✅ CI green | ⬜ manual pending | ⬜ v1.5.0 | whisper.cpp built-in Silero VAD, deterministic FillerDetector / SelfCorrectionDetector / PauseAnalyzer / TextNormalizer, Whisper Mode gain, "Filler cleanup" slider. 68 assertions. |
| **4a — Bengali + script + hybrid** | `feature/local-ai-phase-4` | 🟡 CI running | ⬜ manual pending | ⬜ v1.6.0 | `UserLanguageMode` += `pureBengali`/`banglish`; `BengaliContextPrompts` (bKash/Nagad/Pathao/GP/Robi, দাদা/দিদি, punctuation); **hard `OUTPUT_SCRIPT` contract** in post-processing (Devanagari/Bangla/mirror); menu-bar EN·HI·BN·MIX; confidence-aware hybrid escalation. 76 assertions. |
| **4b — offline local LLM** | `feature/local-ai-phase-4b` | 🟡 CI running | ⬜ manual pending | ⬜ v1.6.x | **llama.cpp v0.4.0** as a universal dylib in Contents/Frameworks/ (ggml 0.23 vs whisper's 0.20 — two-level namespace isolates); Qwen3-0.6B (unsloth GGUF, pinned+verified); `disable-library-validation` entitlement; `LocalLLMEngine` + `LocalTextProcessingService`; **opt-in, experimental** (0.6B quality is marginal — cloud cleanup stays default). |
| **5a — progress + Command Mode** | `feature/local-ai-phase-5` | ✅ CI green | ⬜ manual pending | ⬜ v2.0.0 | whisper.cpp progress callback → "Transcribing 45%" in overlay; **Command Mode** (menu-bar "Rewrite selection by voice" → AX selection + spoken instruction → in-place rewrite). |
| **4c — IndicConformer** | — | — | — | ⬜ v1.6.x | sherpa-onnx + AI4Bharat IndicConformer for best-in-class native-script Hindi/Bengali ASR. Whisper base/turbo already do HI/BN natively, just less accurately. Another vendored C++ lib. |
| **5b — design refresh** | — | — | — | ⬜ v2.0.0 | Implement the Google Stitch screens (Design/STITCH_PROMPTS.md → Design/Screens/) against DesignSystem.swift. Needs the user's Stitch outputs. |

## Branch stack (each branches off the previous)

```
main
 └─ feature/local-ai-phase-1   scaffold                      CI ✅
     └─ feature/local-ai-phase-2   local Whisper ASR         CI ✅
         └─ feature/local-ai-phase-3   VAD + disfluency      CI ✅
             └─ feature/local-ai-phase-4   Bengali + script  CI ✅
                 ├─ feature/local-ai-phase-4b  offline LLM    CI 🟡
                 └─ feature/local-ai-phase-5   progress + Command Mode  CI ✅
```

To ship: merge 1→2→3→4→(4b, 5) into main in order, tag `v1.3.0`…`v2.0.0`
(the release workflow builds each tag). Or squash-merge the whole stack as one
`v2.0.0` after the manual regression pass.

## Phase 4b — fully-offline path (deferred)

Phase 4a gives Bengali + correct script **today** via local Whisper ASR + the
cloud LLM's `OUTPUT_SCRIPT` contract (romanized→native conversion). A 100%
offline path additionally needs:
- **AI4Bharat IndicConformer** (better Hindi/Bengali WER, native script from the
  ASR itself) — vendor `sherpa-onnx` (Apache-2.0, ONNX Runtime, universal).
- **Qwen3-0.6B** local cleanup — vendor `llama.cpp` (MIT). Fix the manifest URL
  (`qwen3-0.6b-q4_k_m` currently 404s).
Both are additive behind the existing `LocalASREngine` / cleanup abstraction.

## Phase 2 — remaining follow-ups (do before v1.4.0 release)

- [ ] Post-setup optional "download offline model" card (`SetupView`) — functional path already exists via Settings → Local AI
- [ ] Recording overlay "Local" chip while processing (`RecordingOverlay`)
- [ ] `FileTranscriptionView` — "Transcribe with: Current provider / Local Whisper" option
- [ ] Persistent Run Log columns (route / model / latency) — deferred to Phase 3's schema bump
- [ ] Fix `qwen3-0.6b-q4_k_m` manifest URL (currently 404s) — Phase 4 model, fix when wiring llama.cpp
- [ ] Manual `REGRESSION_CHECKLIST.md` pass on the built DMG (needs human tester)
- [ ] 8 GB / Intel latency + memory measurements (`REGRESSION_CHECKLIST.md` §H)

## Toolchain notes

- Build needs full Xcode (`sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`).
- Makefile resolves the SDK via `xcrun --sdk macosx --show-sdk-path` (bare `--show-sdk-path`
  returns a stale Command Line Tools SDK when both are installed).
- `cmake` required for the vendored whisper.cpp build (`brew install cmake`).
- First build compiles whisper.cpp (~1–2 min); subsequent builds reuse `build/whisper`.
  `make clean` keeps the whisper libs; `make clean-all` wipes them.
