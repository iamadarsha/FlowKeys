# FlowKeys → "Wispr Flow grade", $0 cost — Upgrade Research & Plan (Sept 2026)

Author: research pass by Claude, 2026‑09‑07
Scope: read of the full `Sources/*.swift` tree (13,306 LOC) + web research on 2026
open‑source dictation apps and local speech / LLM models.

---

## 1. What FlowKeys is today (codebase audit)

### Architecture (confirmed from source)

| Layer | File(s) | Notes |
|---|---|---|
| App shell | `App.swift`, `AppDelegate.swift` | MenuBarExtra `.window` style, no Dock icon |
| Orchestrator | `AppState.swift` (1,692 LOC) | Owns the whole pipeline, persistence, permissions |
| Trigger | `HotkeyManager.swift`, `DictationShortcutSessionController.swift`, `ShortcutBinding.swift` | Hold + toggle + latch state machine |
| Capture | `AudioRecorder.swift` | `AVAudioEngine` tap, watchdog + engine‑rebuild logic, RMS meter |
| Normalize | `AudioNormalization.swift` | Down‑convert to 16 kHz mono int16 WAV |
| STT | `TranscriptionService.swift`, `TranscriptionProvider.swift` | **Cloud only** |
| Context | `AppContextService.swift` | AX tree + window screenshot → cloud vision LLM → 2‑sentence summary |
| Cleanup | `PostProcessingService.swift` | Cloud LLM, big hand‑written system prompt + Indian addendum |
| Indic logic | `IndianContextPrompts.swift` | Prompt engineering only — no model |
| Features | `SnippetEngine.swift`, `PersonalDictionary.swift`, `DictationMode.swift`, voice macros | Text‑substitution + prompt injection |
| Output | `AppState` pasteboard helpers | Clipboard write → synthetic ⌘V → clipboard restore |
| Update | `UpdateManager.swift` | Polls GitHub releases, downloads DMG |
| Build | `Makefile` | **Bare `swiftc`**, universal binary, no SwiftPM / Xcode project, zero deps |

### Providers today (`TranscriptionProvider.swift`)

- **Groq** — `whisper-large-v3-turbo` STT + `openai/gpt-oss-20b` cleanup (free tier, default)
- **OpenAI** — `whisper-1` + `gpt-4o-mini`
- **Gemini** — `gemini-2.5-flash` for both STT and cleanup
- **Grok** — `whisper-1` + `grok-2-latest`
- **Claude** — hybrid: Groq Whisper STT + `claude-3-5-haiku` cleanup

### Languages today (`UserLanguageMode`)

Only three: `hinglish`, `pureHindi`, `pureEnglish`. Whisper language token is `hi` or
`en`. Script handling is **entirely** delegated to the cleanup LLM via
`INDIAN_POSTPROCESSING_PROMPT_ADDENDUM` and the `hindiOnly` DictationMode prompt.
**No Bengali anywhere.**

### Real strengths (keep these)

- Clean provider abstraction — adding a "local" provider is a natural extension point.
- Genuinely good prompt engineering for Indian English / Hinglish (dialects, fillers,
  brand nouns, code‑switching rules).
- Anti‑hallucination: Whisper primer + `whisperHallucinationBlocklist` post‑filter.
- Solid audio‑engine resilience (config‑change observer, watchdog, rebuild attempts).
- Context pipeline (screenshot + AX + selected text) is more than most competitors do.
- Snippets / personal dictionary / voice macros / per‑app modes already exist.

### Concrete gaps vs. Wispr Flow / superwhisper / VoiceInk

| # | Gap | Where it hurts |
|---|---|---|
| G1 | **100% cloud, no offline path** | needs internet; audio leaves device; latency = network RTT; Groq free tier rate‑limits |
| G2 | **No streaming / partial text** | user stares at a spinner; feels slower than it is |
| G3 | **No client‑side VAD / endpointing** | whole clip uploaded incl. silence; no "stopped talking → auto‑send"; `minimumPeakRMS` is a crude gate |
| G4 | **Disfluency removal = LLM only** | "um / ah / matlab / false starts" handled by a prompt, not by timestamps or a dedicated pass; inconsistent |
| G5 | **No Bengali; script output not guaranteed** | `UserLanguageMode` has no `.bengali`; romanized→Devanagari/Bangla depends on LLM mood |
| G6 | **`whisper-large-v3-turbo` is mediocre for Indic** | ~20% WER Hindi, worse Bengali; turbo is *distilled* and weakest on low‑resource langs |
| G7 | **Bare `swiftc` Makefile** | cannot add SwiftPM deps → blocks WhisperKit / FluidAudio / MLX / sherpa‑onnx |
| G8 | **No language auto‑detect** | user must pre‑pick HI/EN/MIX in the menu bar |
| G9 | **No "command mode"** (edit selected text by voice) | Wispr Flow's headline Pro feature |
| G10 | **No model manager UI** | needed the moment you ship local models |

---

## 2. Open‑source apps/repos to clone or study

Ranked by relevance to FlowKeys (Swift, macOS, local, multilingual).

### Tier 1 — study deeply, port patterns

| Repo | Stars | Stack | What to take |
|---|---|---|---|
| **VoiceInk** — `Beingpax/VoiceInk` | ~4.3k | Swift + `whisper.cpp` + WhisperKit + Parakeet, GPL‑v3 | Closest analog to FlowKeys. Model‑download manager, per‑app "Power Mode" (you already have DictationMode — compare), local‑model switching UI, BYOK cloud fallback. **Best single reference.** |
| **FluidAudio** — `FluidInference/FluidAudio` | active | Swift SPM, **MIT** | Drop‑in CoreML/ANE runtime for **Parakeet TDT v3 ASR + Silero VAD + Pyannote diarization + streaming EOU**. 1h audio in ~19s on M4 Pro. This is your fastest route to local STT + VAD without writing CoreML glue. |
| **argmax‑oss‑swift** (was WhisperKit) — `argmaxinc/argmax-oss-swift` | ~5k | Swift 6 SPM, **MIT** | `WhisperKit` + `SpeakerKit` + `TTSKit`. CoreML Whisper (incl. `large-v3-turbo`) on ANE, **real streaming transcription**, word timestamps. Pre‑converted weights on HF (`argmaxinc/whisperkit-coreml`). |
| **Handy** — `cjpais/Handy` | ~23k | Tauri/Rust, MIT | Not Swift, but the UX bar: push‑to‑talk, Whisper.cpp *or* Parakeet v3 w/ auto language detect, paste‑at‑cursor. Read `transcribe-rs` for a clean multi‑engine abstraction (Parakeet, Canary, Moonshine, SenseVoice, Whisper). |

### Tier 2 — reference for specific pieces

| Repo | Take |
|---|---|
| **Ghost Pepper** (WhisperKit + local LLM filler‑word removal, Apple Silicon) | exact pattern for G4: local small‑LLM disfluency pass |
| **Pindrop** / **Yap** / **OpenSuperWhisper** | menu‑bar + streaming on‑device UX, Apple Speech `SpeechAnalyzer` fallback (macOS 26) |
| **whisper.cpp** — `ggml-org/whisper.cpp` | if you want zero‑framework GGUF Whisper w/ a tiny Swift bridge; has a Core ML path too |
| **sherpa‑onnx** — `k2-fsa/sherpa-onnx` | **the practical way to run AI4Bharat IndicConformer on‑device** (ONNX, has Swift/C API, CoreML provider) |
| **openwhispr/openwhispr** | BYOK + local + custom dictionary cross‑platform layout |
| `primaprashant/awesome-voice-typing` | the full catalog, keep an eye on it |

### Wispr Flow features worth copying (from 2026 reviews)

- **Auto‑edits**: filler removal, auto‑punctuation/caps, "first/second/third" → list, per‑app tone. *You have most of this in prompts — make it deterministic.*
- **Whisper Mode**: detect low‑amplitude speech, boost gain / swap to a model tuned for quiet speech.
- **Command Mode** (Pro): select text → hotkey → "make this concise / translate to Bengali / turn into bullets" → in‑place rewrite. **High‑value, you have all the plumbing** (AX selected text + cleanup LLM).
- **Personalized Style** slider per app category (Very Casual … Formal).

---

## 3. Local models to download & run in the background (2026, free)

Everything below is open‑weight, license‑clean, and runs on Apple Silicon with no API cost.

### 3A. Speech‑to‑text

| Model | Size | Langs relevant to you | Script output | Runtime on Mac | WER notes |
|---|---|---|---|---|---|
| **Whisper `large-v3` (full, not turbo)** | 1.5 GB (CoreML ~1.6 GB) | EN + HI + BN (all 3!) | **native** Devanagari / Bangla / Latin | WhisperKit CoreML (ANE) | ~20% Hindi, ~25–30% Bengali — baseline |
| **Whisper `large-v3-turbo`** | ~0.8 GB | EN great, HI ok, BN weak | native | WhisperKit CoreML (ANE), streaming | fast, ~5–8× turbo; **keep for English** |
| **AI4Bharat `indic-conformer-600m-multilingual`** | ~600 M (int8 ONNX ~300 MB) | **22 Indic incl. Hindi + Bengali + Assamese…** | **native Devanagari / Bangla** (CTC + RNNT heads) | **sherpa‑onnx** (ONNX, CoreML EP) | best open Indic WER, beats IndicWhisper/Whisper on Vistaar; **MIT** |
| **NVIDIA Parakeet TDT `0.6b` v3** | 0.6 B | EN + 24 Euro/CJK — **NO Hindi/Bengali** | native | FluidAudio CoreML (ANE), streaming EOU | Open‑ASR‑leaderboard #1 for English speed/accuracy (~1.9% WER) |
| **Moonshine** (tiny/base) | 27–60 M | EN only | — | ONNX / tiny | ultra‑low‑latency English fallback for weak hardware |

**Recommended STT strategy — a router, not one model:**

```
languageMode == .pureEnglish / .englishFast   → WhisperKit large-v3-turbo (ANE, streaming)
                                                 (or Parakeet v3 via FluidAudio if you want #1 English speed)
languageMode == .hindi / .bengali / mixed     → IndicConformer 600M via sherpa-onnx (native script)
fallback / "highest accuracy" toggle          → Whisper large-v3 full (all 3 langs, native script)
offline unavailable / user opted cloud        → existing Groq / Gemini path (UNCHANGED)
```

Total disk if you ship turbo + IndicConformer‑int8: **~1.1 GB**. Acceptable as an
opt‑in download (not bundled in the DMG).

### 3B. Small LLM for cleanup / grammar / disfluency / command‑mode (local option)

Keep **Groq `gpt-oss-20b` and Gemini 2.5 Flash exactly as they are** — they're free and
excellent. Add a *local* option for offline / privacy:

| Model | Size (4‑bit MLX) | Why | Runtime |
|---|---|---|---|
| **Qwen3‑4B‑Instruct‑2507** | ~2.4 GB | best small multilingual (strong Hindi/Bengali), Apache‑2.0, great instruction‑following for "return only cleaned text" | **MLX Swift** (`mlx-swift-examples`) or `llama.cpp` |
| **Gemma 3 4B** | ~2.6 GB | 140+ languages, 128K ctx, good Indic, permissive Gemma license | MLX / Ollama |
| **Qwen3‑1.7B** | ~1 GB | if you need it to run alongside STT on 8 GB Macs | MLX |
| Phi‑4‑mini | ~2.3 GB | strongest reasoning at 4B for command‑mode rewrites | MLX / llama.cpp |

MLX is ~20–50% faster than llama.cpp on Apple Silicon and is Swift‑native — the right
pick given this is a Swift app.

**Cleanup‑LLM strategy:**
```
provider == .local → Qwen3-4B (MLX)  [new]
provider == .groq/.gemini/... → unchanged cloud path
```
Reuse the *existing* `PostProcessingService` system prompt verbatim — it's already good.

### 3C. Voice Activity Detection

- **Silero VAD** (via FluidAudio, CoreML) — endpointing ("user stopped talking → send"),
  silence trimming before STT, and the amplitude signal for **Whisper Mode**.
- Gives you free latency wins (don't transcribe 2s of trailing silence) and fixes G3.

---

## 4. Hindi + Bengali + English with correct script output

User requirement: *"text must get typed in English, Hindi or Bengali as per the language selected."*

### Model layer

- **IndicConformer** natively emits Devanagari for Hindi and Bangla script for Bengali —
  no transliteration needed for pure dictation.
- **Whisper large-v3** also emits native script when the language token is `hi` / `bn`.

### Code changes

1. `UserLanguageMode` — add cases:
   ```
   case bengali            // "বাংলা (Bengali)"
   case banglish           // Bengali–English code-switch, Latin or Bangla out
   case englishFast        // English, local turbo model
   case auto               // detect per utterance
   ```
   Add `whisperLanguageCode` → `"bn"`, and a `targetScript` enum (`.devanagari`,
   `.bengali`, `.latin`, `.mirrorInput`).

2. New `INDIC_WHISPER_PRIMER` / post‑processing addendum for Bengali (mirror the Hindi
   one in `IndianContextPrompts.swift` — Bengali brands: bKash, Nagad, Pathao, Daraz,
   Chaldal, Shohoz, Robi, Grameenphone, Bikash; common names; দাদা/দিদি particles).

3. **Romanized → native script** when the user types Banglish/Hinglish but selected a
   pure‑script mode: **AI4Bharat IndicXlit** (`ai4bharat-transliteration`, ~11 M,
   Roman↔native for Hindi + Bengali + 19 more). Ship as a tiny ONNX model, or let the
   local/cloud LLM do it (cheaper to start — the `hindiOnly` DictationMode already
   proves the LLM can).

4. `PostProcessingService` — make script a **hard constraint** in the user message, not a
   soft prompt hint: `OUTPUT_SCRIPT: Bengali. Any Latin-script Bengali words must be
   converted to Bangla script. Keep English proper nouns in Latin.`

5. Menu bar: HI / EN / MIX → **EN / HI / BN / MIX / AUTO** segmented control
   (`MenuBarView.swift` already has the segment UI from the KM redesign).

---

## 5. "Better um / ah / pause analysis" (G4)

Make disfluency handling a real pipeline stage instead of a prompt clause:

1. **VAD segmentation** (Silero) → know where pauses are and how long.
2. **Word timestamps** from WhisperKit / IndicConformer RNNT → detect:
   - filled pauses (`um, uh, er, hmm, matlab, आ, ভানে, mane`)
   - repetitions / false starts ("I want— I need")
   - long silent gaps (> 600 ms) that should become sentence breaks, not commas
3. **Deterministic pre‑clean** in Swift (regex + timestamp rules) removes the obvious
   fillers *before* the LLM — cheaper, consistent, testable.
4. LLM does the judgement calls (self‑corrections across languages — you already have
   great rules for this in `PostProcessingService.defaultSystemPrompt`).
5. Add a **"disfluency aggressiveness"** slider (Literal → Light → Standard → Polished),
   mapped to which stages run. Literal mode already exists as a DictationMode — unify.
6. **Whisper Mode**: if VAD reports sustained low RMS + speech present, apply +12 dB
   pre‑gain and note "quiet speech" in context so the LLM doesn't treat it as noise.

---

## 6. UI / UX upgrades

| Area | Change |
|---|---|
| Recording overlay | **Stream partial transcript** into the pill as you speak (WhisperKit/Parakeet streaming). Huge perceived‑speed win. |
| Model manager | New Settings tab: list local models, size, download/delete, "active for language X", disk usage, background‑download progress. (VoiceInk has a clean version of this.) |
| Language control | EN/HI/BN/MIX/AUTO in menu bar + per‑app override in DictationMode. |
| Command Mode | Select text anywhere → `⌥⌘Fn` → speak an instruction → in‑place rewrite (translate to Bengali, shorten, bulletize, fix grammar). Reuses AX selected‑text + cleanup LLM. |
| Latency HUD | Debug panel: show ms for VAD / STT / context / cleanup / paste. You already log all of this via `os_log`. |
| Onboarding | Add "Run locally (private, offline)" vs "Use a free API key" fork; if local, pick model by Mac RAM. |
| First‑token feedback | Play the start sound on first VAD speech frame, not first buffer (you're close — `onRecordingReady` fires on first non‑silent buffer). |
| Auto‑punctuation preview | Show the cleaned vs raw diff in Run Log (you store both already). |

---

## 7. Build‑system change (the blocker — do this first)

`swiftc`‑only Makefile cannot pull SwiftPM dependencies. Everything local needs it.

**Option A (recommended): add `Package.swift`**, keep the Makefile as a thin wrapper
(`swift build -c release` then bundle). Dependencies:
```swift
.package(url: "https://github.com/argmaxinc/argmax-oss-swift", from: "1.0.0"),   // WhisperKit
.package(url: "https://github.com/FluidInference/FluidAudio", from: "0.x"),      // Parakeet + Silero VAD
.package(url: "https://github.com/ml-explore/mlx-swift-examples", branch: "main"), // local LLM
// sherpa-onnx: vendored xcframework for IndicConformer
```
Universal build still works (`swift build --arch arm64 --arch x86_64`), though note
CoreML/ANE models are Apple‑Silicon‑only — gate local features on `arch == arm64`.

**Option B:** generate an `.xcodeproj` (XcodeGen / Tuist). More capable for CoreML asset
compilation and entitlements, more moving parts.

Also add to `FlowKeys.entitlements`: keep `com.apple.security.app-sandbox` off (already
is) — local model files live in `Application Support/FlowKeys/models/`.

---

## 8. Phased roadmap

**Phase 0 — unblock (1–2 days)**
- Add `Package.swift`; migrate build; CI still produces `FlowKeys.dmg`.
- No behavior change. Ship as v1.3.0.

**Phase 1 — local English STT (v1.4)**
- Integrate WhisperKit; add `.local` transcription provider; `large-v3-turbo` CoreML.
- Model‑manager Settings tab (download/delete).
- Streaming partial text in the overlay.
- Keep Groq/Gemini default; local is opt‑in.

**Phase 2 — VAD + disfluency (v1.5)**
- FluidAudio Silero VAD: endpointing, silence trim, Whisper Mode.
- Deterministic filler pre‑clean stage + aggressiveness slider.
- Latency HUD in debug panel.

**Phase 3 — Hindi + Bengali local (v1.6)**
- sherpa‑onnx + IndicConformer 600M (int8); language router.
- `UserLanguageMode` += `bengali`, `banglish`, `auto`; `targetScript`.
- Bengali primer + post‑processing addendum.
- EN/HI/BN/MIX/AUTO menu‑bar control.
- Optional IndicXlit for roman→native.

**Phase 4 — local LLM + command mode (v1.7)**
- MLX Qwen3‑4B as `.local` cleanup provider (offline parity).
- Command Mode (select → speak instruction → rewrite).
- Personalized Style slider per app category.

**Phase 5 — polish (v2.0)**
- Language auto‑detect (Whisper LID or IndicConformer LID head).
- Per‑app model + language + style profiles (extend DictationMode).
- Optional speaker diarization for meeting notes (Pyannote via FluidAudio).

---

## 9. Cost check — everything here is $0

| Component | License | Cost |
|---|---|---|
| WhisperKit / argmax‑oss‑swift | MIT | free |
| FluidAudio (Parakeet, Silero, Pyannote CoreML) | MIT | free |
| Whisper large‑v3 / turbo weights | MIT | free |
| AI4Bharat IndicConformer / IndicXlit | MIT | free |
| Parakeet TDT v3 | CC‑BY‑4.0 | free |
| Qwen3 / Gemma 3 (MLX 4‑bit) | Apache‑2.0 / Gemma | free |
| sherpa‑onnx | Apache‑2.0 | free |
| MLX Swift | MIT | free |
| Groq / Gemini (existing) | free tier | $0 |

No inference servers, no subscriptions. Compute is the user's Mac.

---

## 10. Immediate next actions

1. `Package.swift` + build migration (Phase 0). Nothing else can proceed without it.
2. Spike: add WhisperKit, transcribe a test clip locally behind a hidden
   `local_stt_enabled` flag, compare latency vs Groq on your Mac.
3. Spike: run `indic-conformer-600m-multilingual` int8 via sherpa‑onnx CLI on a Hindi
   and a Bengali sample; confirm native‑script output quality.
4. Decide bundle vs. download for models (recommend: download, show progress).
5. Clone `Beingpax/VoiceInk` and `FluidInference/FluidAudio` locally and read their
   model‑manager + engine‑router code before writing FlowKeys' version.

---

## Sources

- [7 Best Open Source Wispr Flow Alternatives 2026 — OpenAlternative](https://openalternative.co/alternatives/wisprflow)
- [wispr-flow-alternative — GitHub Topics](https://github.com/topics/wispr-flow-alternative)
- [VoiceInk — tryvoiceink.com](https://tryvoiceink.com/) · [VoiceInk build write-up — Starlog](https://starlog.is/articles/developer-tools/beingpax-voiceink/)
- [cjpais/Handy — GitHub](https://github.com/cjpais/Handy) · [cjpais/transcribe-rs](https://github.com/cjpais/transcribe-rs)
- [FluidInference/FluidAudio — GitHub](https://github.com/FluidInference/FluidAudio)
- [argmaxinc/argmax-oss-swift — GitHub](https://github.com/argmaxinc/argmax-oss-swift) · [WhisperKit paper (arXiv 2507.10860)](https://arxiv.org/html/2507.10860v1) · [argmaxinc/whisperkit-coreml — HF](https://huggingface.co/argmaxinc/whisperkit-coreml)
- [nvidia/parakeet-tdt-0.6b-v3 — HF](https://huggingface.co/nvidia/parakeet-tdt-0.6b-v3)
- [Parakeet vs Whisper: Best Local Speech Model 2026 — Spokenly](https://spokenly.app/blog/parakeet-vs-whisper) · [Best Local STT Models 2026 — onResonant](https://www.onresonant.com/resources/local-stt-models-2026)
- [ai4bharat/indic-conformer-600m-multilingual — HF](https://huggingface.co/ai4bharat/indic-conformer-600m-multilingual) · [AI4Bharat/IndicConformerASR — GitHub](https://github.com/AI4Bharat/IndicConformerASR)
- [AI4Bharat/IndicXlit — GitHub](https://github.com/AI4Bharat/IndicXlit) · [xlit.ai4bharat.org](https://xlit.ai4bharat.org)
- [Whisper vs IndicWhisper vs Shunya — ShunyaLabs](https://www.shunyalabs.ai/blog/whisper-vs-indicwhisper-vs-shunya-best-speech-to-text-for-indian-languages)
- [Best Open Source STT Model 2026 (benchmarks) — Northflank](https://northflank.com/blog/best-open-source-speech-to-text-stt-model-in-2026-benchmarks)
- [Best Open Source / Open-Weight LLMs to Run Locally 2026 — Hugging Face blog](https://huggingface.co/blog/daya-shankar/open-source-llm-models-to-run-locally)
- [Best Small Language Models 2026 (1B–14B) — LocalAIMaster](https://localaimaster.com/blog/small-language-models-guide-2026)
- [Wispr Flow Review 2026 — Spokenly](https://spokenly.app/blog/wispr-flow-review)
- [primaprashant/awesome-voice-typing — GitHub](https://github.com/primaprashant/awesome-voice-typing)
- [k2-fsa/sherpa-onnx — GitHub](https://github.com/k2-fsa/sherpa-onnx)
- [ml-explore/mlx-swift-examples — GitHub](https://github.com/ml-explore/mlx-swift-examples)
