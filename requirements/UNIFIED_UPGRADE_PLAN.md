# FlowKeys — Unified Upgrade Plan (Claude plan ⊕ ChatGPT plan)

**Date:** 2026-09-07
**Inputs merged:**
- `requirements/UPGRADE_PLAN_2026.md` (Claude — model/repo research, streaming, command mode)
- `~/Downloads/FlowKeys_Claude_Code_Analysis.md` (ChatGPT — non-breaking discipline, 8 GB / Intel / battery, tiny models, lazy lifecycle)

**Prime directive (from both, non-negotiable):** *Do not rewrite FlowKeys. Extend it.*
Every existing setting key, shortcut, provider, prompt, Settings tab, snippet, macro,
history and update behavior stays **byte-for-byte** unchanged. All new AI is **additive,
optional, OFF by default, lazily loaded, and ephemeral.**

---

## 1. Plan comparison — where each was right

| Topic | Claude plan | ChatGPT plan | **Unified decision** |
|---|---|---|---|
| **Local ASR engine** | WhisperKit (CoreML/ANE) + sherpa-onnx | **whisper.cpp + tiny C ABI** | **whisper.cpp.** WhisperKit is Apple-Silicon-only → breaks the Intel + 8 GB floor. whisper.cpp is universal, CPU-first, Metal/Accelerate when available, MIT. ✅ ChatGPT |
| **Default ASR model** | large-v3-turbo (~0.8 GB) | **base-q5_1 (~57 MB)**, multilingual | **Ship both as one-tap options.** 57 MB "Fast" is the instant floor; **large-v3-turbo-q5_0 (~547 MB) "Best" is the recommended pick** and covers the weak-Hindi/Bengali problem. User chooses in the optional post-setup card. ✅ merge |
| **Indic accuracy** | IndicConformer 600M (native script, MIT) | not included (base Whisper "compatible") | **Add IndicConformer-600M int8 ONNX via sherpa-onnx (~300 MB) as the optional "Best for Hindi/Bengali" model in Phase 4.** sherpa-onnx is ONNX-Runtime/CPU → universal, fits ChatGPT's constraints. Base Whisper Hindi WER (~30 %+) is genuinely poor; this is the real quality answer. ✅ Claude, repackaged |
| **Local cleanup LLM** | Qwen3-4B / Gemma-3-4B (MLX, ~2.5 GB) | **Qwen3-0.6B Q4_K_M (~0.5 GB, llama.cpp)** | **Qwen3-0.6B.** 4B won't co-reside with ASR on 8 GB. Keep 4B as a 16 GB+ "max quality" opt-in for Phase 5+ only. ✅ ChatGPT |
| **Build system** | add `Package.swift` (SwiftPM) | **extend Makefile, vendor whisper.cpp static** | **Vendored static C/C++ libs built by the Makefile**, `swiftc` stays. Pin commits, tiny C ABI. No SPM churn, stays universal. ✅ ChatGPT |
| **Cleanup approach** | LLM pass + slider | **deterministic Swift layer FIRST, LLM only if needed** | **Deterministic-first.** FillerDetector / PauseAnalyzer / SelfCorrectionDetector run before any model; many short dictations never load the LLM. ✅ ChatGPT (Claude agreed, ChatGPT structured it) |
| **Model lifecycle** | model-manager UI | **lazy load + unload-after-N-sec, nothing resident while idle, thermal/memory-pressure aware** | ✅ ChatGPT — this is what makes 8 GB viable. Adopt fully. |
| **VAD** | Silero via FluidAudio | **Silero (ONNX, few MB)** | **Silero via ONNX Runtime** (not FluidAudio — that's Apple-Silicon CoreML). ✅ merge |
| **Streaming partial text** | Phase 2 headline | Phase C / P2, "after basics stable" | **Phase 5.** Big perceived-speed win but not at the cost of the universal baseline. ✅ ChatGPT ordering |
| **Command Mode** (select → speak instruction → rewrite in place) | included | not included | **Add in Phase 5.** Wispr Flow's headline Pro feature; FlowKeys already has AX selected-text + a cleanup route. ✅ Claude |
| **Bengali + script contract** | `.bengali` + `targetScript` enum | `LanguageSelection{language, script}`, legacy modes mapped | **ChatGPT's struct shape**, keep `UserLanguageMode` persisted and map it. Add `BengaliContextPrompts` mirroring `IndianContextPrompts`. ✅ merge |
| **Roman → native script** | IndicXlit (dedicated 11M model) | LLM instruction | **LLM instruction first (Phase 4), IndicXlit optional later.** Fewer moving parts. ✅ ChatGPT |
| **Confidence-aware hybrid routing** | brief | **detailed: easy→local, hard→configured cloud, never silent from Local-only** | ✅ ChatGPT — adopt fully |
| **Model download safety** | "download, show progress" | **app-owned pinned manifest + SHA-256, never trust mutable README URLs, resumable, atomic, free-space check** | ✅ ChatGPT — adopt fully. **Direct HF resolve URLs embedded in the app**, user never downloads manually. |
| **Design / UI refresh** | model-manager tab, streaming overlay | additive status chips only, "don't redesign" | **Both:** additive + non-destructive in Phases 2-4, then a **full visual refresh in Phase 5** driven by Google Stitch (`Design/STITCH_PROMPTS.md`), implemented against the existing Kinetic Monolith tokens. |
| **Test rigor** | phase regression | **full test matrix (Intel 8 GB / AS 8 GB / AS 16 GB / AS 24 GB+), acceptance criteria, benchmark corpus, per-component unit tests** | ✅ ChatGPT — adopt the whole matrix + acceptance checklist |

**Net:** ChatGPT's plan is the better *skeleton* (constraints, non-breaking discipline,
lifecycle, universal build, tiny models). Claude's plan contributes the *quality ceiling*
(IndicConformer for real Indic accuracy, streaming, Command Mode) and the *reference apps*
(VoiceInk, FluidAudio, Handy) plus the design track.

---

## 2. Final stack

```
UI              SwiftUI + AppKit (unchanged shell), Kinetic Monolith tokens
Input           existing HotkeyManager (unchanged)
Audio           existing AVAudioEngine + AudioNormalization (unchanged, 16 kHz mono WAV)
Route selector  NEW — TranscriptionRoute { existingCloud | local | hybrid }, default existingCloud

VAD (opt/lazy)  Silero VAD  — ONNX, ~2 MB, only while recording
ASR default     whisper.cpp + Whisper base-q5_1        ~57 MB   (EN/HI/BN, one file)
ASR recommended whisper.cpp + Whisper large-v3-turbo-q5_0 ~547 MB (accuracy pick)
ASR Indic (opt) sherpa-onnx + IndicConformer-600M int8  ~300 MB (best Hindi/Bengali, native script)
Cleanup         deterministic Swift rules FIRST  (FillerDetector / PauseAnalyzer / SelfCorrectionDetector)
Local LLM (opt) Qwen3-0.6B Q4_K_M  ~0.5 GB  via llama.cpp — lazy, only on medium confidence
Cloud (unchanged) Groq / OpenAI / Gemini / Grok / Claude-hybrid  — STT + LLM exactly as today
Hybrid          local first → configured cloud only when confidence low AND user opted in

Context         existing AppContextService + NEW lightweight metadata-only path for local mode
Personalization existing PersonalDictionary / SnippetEngine / DictationModeStore + NEW accepted-correction memory
Storage         existing UserDefaults + Keychain (untouched) + NEW local_ai_settings_v1 + model cache
Packaging       small FlowKeys.app; models downloaded on first use from pinned URLs; never in the DMG
```

**Model store:** `~/Library/Application Support/FlowKeys/Models/{whisper,indic,llm,vad}/`
**DMG stays ~small** (only the compiled static engines add weight; weights are downloads).

---

## 3. Cross-cutting rules (apply in every phase)

1. New persisted state → **new versioned keys only** (`local_ai_*_v1`), ideally one
   `LocalAISettings` Codable blob. Never touch existing keys.
2. New runtime lives in `Sources/LocalAI/` composed classes; `AppState` only *observes*.
3. `TranscriptionProvider` is **not** extended with local models — separate
   `LocalASREngine` / `LocalASRModelID` enums.
4. Local AI **default OFF** for existing users → zero behavior change on update.
5. No model in memory while idle. Unload after use (timer, default 30 s; 0 s on Low Power).
6. No mic / VAD / inference activity while idle.
7. Never silently: replace a provider, change a language setting, translate, or
   cloud-fall-back from **Local-only** mode.
8. Every download: HTTPS + pinned SHA-256 + expected size + `.download` temp + atomic
   rename + resume + cancel + free-space check. Not "installed" until checksum passes.
9. No force-unwraps in new code. No API keys / raw audio / screenshots in logs.
10. Universal build must stay green (arm64 **and** x86_64). Gate ANE-only experiments behind `#if arch(arm64)`.
11. After every phase: `make clean && make -j1` → `make dmg` → run `requirements/REGRESSION_CHECKLIST.md`.

---

## 4. The 5 phases (end to end)

Each phase = one focused work session, its own branch, its own CI build, its own
regression pass, its own version bump + GitHub release.

### PHASE 1 — Baseline freeze + additive scaffolding — `v1.3.0`
*No user-visible change. Nothing wired into the pipeline.*

- Confirm `make clean && make -j1` green in CI; record baseline build log + DMG size + `wc -l`.
- `requirements/REGRESSION_CHECKLIST.md` — the manual pass (setup, hold/toggle/latch, all 5
  providers, snippets, macros, vocab, Smart Modes, file transcription, Run Log, debug panel, updater).
- `Scripts/regression_smoke.sh` — clean build + DMG + static asserts (no renamed keys, no
  removed Settings tabs, provider enum intact).
- `Sources/LocalAI/` (pure Foundation, compiles, unused):
  - `LocalAISettings.swift` — Codable, versioned, `isEnabled = false`, `route = .existingCloud`, `unloadAfterSeconds = 30`, `performanceProfile = .balanced`. Own key `local_ai_settings_v1`.
  - `LocalModelManifest.swift` — pinned `LocalModelDescriptor` list: base-q5_1, large-v3-turbo-q5_0, qwen3-0.6b-q4_k_m, silero-vad, indic-conformer-600m — each with **embedded HF resolve URL + SHA-256 + byteSize + version**. (SHA-256s filled from the real files during this phase.)
  - `LanguageRouting.swift` — `LanguageSelection { Language(auto/english/hindi/bengali/hinglish), Script(native/roman/automatic) }` + `UserLanguageMode → LanguageSelection` map. Bengali present, nothing consumes it yet.
  - `LocalAIController.swift` — `ObservableObject`, `state: LocalAIState = .idle`, holds settings, **all methods no-op**. `AppState` gets a `let localAI = LocalAIController()` line and nothing else.
- Makefile: `SOURCES = $(shell find Sources -name '*.swift')` (picks up the subdir); add
  commented `vendor/` + `build-whisper` placeholder targets + `LICENSES/` note.
- Unit tests: `LanguageRoutingTests`, `LocalModelManifestTests` (URL/host allow-list, checksum format).
- **Exit criteria:** CI green, DMG builds, byte-identical UX, new files covered by tests, `LocalAIController` proven inert.

### PHASE 2 — Local ASR + model manager + offline route — `v1.4.0`

- Vendor **whisper.cpp** (pinned commit, `LICENSES/whisper.cpp.MIT`), build universal
  static lib in the Makefile; `Sources/LocalAI/CWhisper/whisper_bridge.{h,cpp}` — minimal
  C ABI (`create/transcribe/destroy`).
- `LocalModelManager.swift` — download (resumable/atomic/checksum/free-space), delete,
  disk usage, **lazy load + unload timer**, thermal + `NSProcessInfo` memory-pressure hooks
  → release + optional cloud fallback.
- `LocalTranscriptionService.swift` — WAV in → text out via bridge; language token from
  `LanguageSelection`.
- `TranscriptionRoute` adapter wraps the **existing** `TranscriptionService` (cloud
  branches untouched). `activeTranscriptionProvider = .groq` still means exactly Groq.
- Models wired: base-q5_1 + large-v3-turbo-q5_0.
- **Settings → new "Local AI" tab** (all 7 existing tabs untouched): OFF default,
  Local/Hybrid radio, model cards with Download/Installed/Delete + size + free-space,
  performance profile (Low Power / Balanced / Accuracy), "Unload after" stepper.
- Post-setup optional card (not a setup step): *"Private offline dictation? Fast · 57 MB / Best · 547 MB / Not now."*
- Recording overlay: subtle `Local` chip **only while processing**.
- Run Log + debug panel: `route`, `asrModel`, `asrLoadMs`, `asrMs`, `totalLocalMs` fields
  (schema-compatible, optional).
- `FileTranscriptionView`: add "Transcribe with: Current provider / Local Whisper".
- Tests: `ModelDownloadServiceTests`, `ModelIntegrityServiceTests`, bridge smoke test
  (bundled 3-sec WAV → non-empty). Manual: offline transcription on 8 GB + Intel.
- **Exit criteria:** offline EN dictation works; cloud paths bit-identical; interrupt/resume/
  corrupt-model/no-space all handled; idle = 0 models resident.

### PHASE 3 — Speech intelligence (VAD + disfluency + pauses + self-correction) — `v1.5.0`

- Vendor ONNX Runtime (or `sherpa-onnx`'s VAD) static; **Silero VAD** — endpointing,
  leading/trailing silence trim, quiet-speech flag. Active **only during recording**.
- `SpeechAnalysisService.swift` returns structured metadata (fillers, pauses, corrections,
  low-confidence spans, WPM, speech/silence durations).
- `FillerDetector.swift` / `PauseAnalyzer.swift` / `SelfCorrectionDetector.swift` — 100 %
  deterministic, position/pause/repetition/grammar-aware. Filler sets for EN + HI/Hinglish
  + **conservative BN**. Return events, don't edit text.
- Deterministic cleanup layer runs **before** any LLM (whitespace, dup punctuation,
  existing hallucination blocklist, configured filler removal, self-correction collapse,
  protected-span extraction for Code mode).
- "Disfluency aggressiveness": Literal / Light / Standard / Polished (unifies existing
  Literal mode; maps to which stages run).
- Whisper Mode: sustained low-RMS + speech → +gain, no noise amplification.
- Debug panel (dev flag): VAD segments, filler hits, low-confidence spans, per-stage ms.
- Tests: `FillerDetectorTests`, `PauseAnalyzerTests`, `SelfCorrectionDetectorTests` with
  EN/HI/BN fixtures + "do not remove meaningful `actually`/`haan`/`মানে`" negative cases.
- **Exit criteria:** "Thursday no actually Wednesday" → "Wednesday" deterministically;
  fillers removed per mode; Code mode identifiers untouched; latency lower (silence trimmed).

### PHASE 4 — Bengali + script contract + local LLM + hybrid routing — `v1.6.0`

- Activate `LanguageSelection` + `Script` end to end. Legacy `UserLanguageMode` values
  keep meaning via the map; existing users see their current modes.
- Menu bar quick switcher: **EN · HI · BN · MIX** (+ `AUTO`), compact `Script: Auto|Native|Roman`.
- `BengaliContextPrompts.swift` mirroring `IndianContextPrompts` — native script preservation,
  BN-EN code-switch, punctuation, names, brands (bKash, Nagad, Pathao, Robi, Grameenphone,
  Daraz, Chaldal, Shohoz), দাদা/দিদি particles, no Hindi normalization, no translation.
  Lean prompts — rules + small relevant vocab + user dictionary, not a mega-list.
- **IndicConformer-600M int8 ONNX via sherpa-onnx** as optional "Best for Hindi/Bengali"
  ASR model (~300 MB, native Devanagari/Bangla output).
- Roman→native as an explicit output-contract instruction (LLM); IndicXlit deferred.
- Vendor **llama.cpp** static; `LocalTextProcessingService.swift` + **Qwen3-0.6B Q4_K_M**,
  lazy, **only when deterministic cleanup + confidence say it's needed**, constrained
  transform prompt (no paraphrase, no facts, no translation unless contract says so),
  deterministic sampling. Never both ASR + LLM resident on 8 GB.
- **Confidence-aware hybrid routing**: high → deterministic only; medium → local Qwen;
  low/risky → configured cloud (only if Hybrid enabled). Visible in Run Log. Never silent
  from Local-only.
- Numbers/dates/money preservation (lakh/crore/₹/INR/AM-PM/dates/phone).
- Accepted-correction memory (opt-in) extending `PersonalDictionary` ("Remember this spelling?").
- **Benchmark corpus** (`requirements/BENCHMARK_CORPUS.md`): EN/HI/BN × native/roman/code-switch
  /noise/fast/quiet/names/numbers/code + product nouns. Record WER / semantic / formatting / latency.
- **Exit criteria:** Bengali native + roman dictation works; script contract honored;
  Hinglish/Banglish code-switching preserved; local LLM loads only when needed; hybrid
  escalation explicit; full language regression pass.

### PHASE 5 — Streaming + Command Mode + full design refresh — `v2.0.0`

- Streaming partial transcript in the overlay (whisper.cpp partials). Off on Low Power.
- **Command Mode**: select text anywhere → `⌥⌘Fn` → speak instruction → in-place rewrite
  (translate to Bengali, shorten, bulletize, fix grammar). Reuses AX selected-text +
  cleanup route (local or cloud per settings).
- Personalized Style slider per app category (Very Casual … Formal).
- Language auto-detect (`AUTO` mode) via Whisper LID / IndicConformer LID.
- **Full visual refresh** from `Design/STITCH_PROMPTS.md`: menu bar popover, recording
  overlay (all states), Local AI settings, model manager, onboarding offline card,
  language/script switcher, Run Log / debug, Command Mode overlay, Settings shell.
  Implemented against `DesignSystem.swift` (KM tokens) — visual polish, not IA changes;
  all existing controls remain.
- Optional: Qwen3-4B "max quality" cleanup for 16 GB+; speaker diarization for meeting notes.
- **Full test matrix** (Intel 8 GB / AS 8 GB / AS 16 GB / AS 24 GB+): startup/idle memory,
  model load, ASR + cleanup latency, peak RSS, CPU %, Energy Impact, scripted battery drain.
- **Acceptance checklist** (ChatGPT §68) signed off before calling it "Wispr Flow grade".
- **Exit criteria:** every acceptance box ticked; measured battery numbers recorded;
  design refresh shipped; v2.0.0 released.

---

## 5. Reference repos (study, don't bulk-copy; respect licenses)

| Repo | License | Take |
|---|---|---|
| `Beingpax/VoiceInk` | GPL-3.0 (study only) | model-manager UX, per-app Power Mode |
| `FluidInference/FluidAudio` | MIT | Silero/Parakeet CoreML patterns (AS-only ref) |
| `cjpais/Handy` + `cjpais/transcribe-rs` | MIT | multi-engine abstraction, auto language detect |
| `OpenWhispr/openwhispr` | MIT | local/cloud routing, BYOK + dictionary |
| `ggml-org/whisper.cpp` | MIT | **the ASR engine** (vendor it) |
| `k2-fsa/sherpa-onnx` | Apache-2.0 | **IndicConformer + VAD runtime** (vendor it) |
| `ggml-org/llama.cpp` | MIT | **local LLM engine** (vendor it) |
| `snakers4/silero-vad` | MIT | VAD model |
| `ex2mple/VoiceFlow` | MIT | filler / self-correction cleanup ideas |
| Wispr Flow / superwhisper | proprietary | **behavior benchmark only — never clone source** |

---

## 6. Model manifest (pinned, embedded in-app — user never downloads manually)

| id | file | ~size | source (HF `resolve/main`) | used |
|---|---|---:|---|---|
| `whisper-base-q5_1` | `ggml-base-q5_1.bin` | 57 MB | `ggerganov/whisper.cpp` | P2 default |
| `whisper-large-v3-turbo-q5_0` | `ggml-large-v3-turbo-q5_0.bin` | 547 MB | `ggerganov/whisper.cpp` | P2 "Best" |
| `indic-conformer-600m-int8` | onnx bundle | ~300 MB | `ai4bharat` / `OpenVoiceOS` onnx mirror | P4 Indic |
| `qwen3-0.6b-q4_k_m` | `Qwen3-0.6B-Q4_K_M.gguf` | ~0.5 GB | `ggml-org/Qwen3-0.6B-GGUF` | P4 cleanup |
| `silero-vad` | `silero_vad.onnx` | ~2 MB | `snakers4/silero-vad` | P3 VAD |

Exact revisions + SHA-256 are pinned in `Sources/LocalAI/LocalModelManifest.swift` in Phase 1.

---

## 7. "Absolutely free" holds

whisper.cpp / llama.cpp / sherpa-onnx / Silero / Whisper weights / IndicConformer / Qwen3
are all MIT / Apache-2.0 / CC-BY. $0 per transcription, $0 per cleanup, no subscription,
no FlowKeys server. Cloud routes stay BYOK exactly as today.
