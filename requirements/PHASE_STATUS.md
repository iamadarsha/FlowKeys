# FlowKeys Local AI — Phase Status

Tracks the 5-phase build from `requirements/UNIFIED_UPGRADE_PLAN.md`.
Each phase: own branch → CI green → manual `REGRESSION_CHECKLIST.md` → version bump → release.

| Phase | Branch | Build/CI | Regression | Released | Notes |
|---|---|---|---|---|---|
| **1 — scaffold (no-op)** | `feature/local-ai-phase-1` | ✅ CI green | ⬜ manual pending | ⬜ v1.3.0 | Inert `Sources/LocalAI/`, Makefile SDK fix, ci.yml, smoke script |
| **2 — local Whisper ASR** | `feature/local-ai-phase-2` | 🟡 CI running | ⬜ manual pending | ⬜ v1.4.0 | whisper.cpp v1.9.3 vendored, C bridge, model manager, offline route, Local AI settings tab, 47 unit assertions. Verified E2E locally. |
| **3 — VAD + disfluency** | — | — | — | ⬜ v1.5.0 | Silero VAD, deterministic filler/pause/self-correction, Whisper Mode |
| **4 — Bengali + local LLM + hybrid** | — | — | — | ⬜ v1.6.0 | `LanguageSelection` live, Bengali prompts, IndicConformer, Qwen3-0.6B, confidence routing |
| **5 — streaming + Command Mode + design** | — | — | — | ⬜ v2.0.0 | streaming overlay, Command Mode, Stitch design refresh, full test matrix |

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
