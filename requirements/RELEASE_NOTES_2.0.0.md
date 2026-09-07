# FlowKeys 2.0.0 — On-device AI

The big one. FlowKeys can now run **entirely on your Mac** — speech recognition,
voice detection, cleanup — with no internet and no API key. Your existing cloud
providers (Groq, OpenAI, Gemini, Grok, Claude) work exactly as before; on-device
AI is **opt-in and off by default**, so updating from 1.x changes nothing until
you turn it on.

## New

### Private, offline dictation
- **On-device speech recognition** via whisper.cpp — English, Hindi, Bengali and
  90+ languages, in native script. Two models: *Fast* (57 MB) or *Best quality*
  (547 MB), downloaded on first use from a pinned, integrity-checked link.
- **Best-for-Indic model** — AI4Bharat's IndicConformer for markedly better
  Hindi/Bengali/Assamese/Gujarati/… recognition, native Devanagari & Bangla
  output, and it's *fast* (~200 ms for a 10-second clip).
- **Local / Hybrid / Cloud** route switch. Hybrid runs on-device and only reaches
  for your cloud provider when it's genuinely unsure (shown in your history).
- Nothing is ever sent to a FlowKeys server — there isn't one.

### Bengali
- Full Bengali and Banglish (Bengali–English code-switch) support, alongside the
  existing English / Hindi / Hinglish.
- A **hard output-script contract** — pick Native, Roman, or Auto, and FlowKeys
  honors it. It never translates unless you ask.

### Speech intelligence (on-device)
- **Voice detection** trims silence and finds your pauses — the Flow Bar shows
  when you've stopped talking.
- Deterministic **filler / false-start / self-correction cleanup** with a
  Literal → Polished slider. "um so Thursday, no actually Wednesday" → "Wednesday."
- **Whisper Mode** boosts very quiet speech without amplifying room noise.

### Command Mode
- Select text anywhere → **"Rewrite selection by voice"** from the menu bar →
  speak an instruction ("make it shorter", "translate to Bengali", "fix grammar",
  "bullet points") → the selection is rewritten in place.

### Optional fully-offline cleanup
- A small on-device language model (Qwen 0.6B) can do the final polish with no
  network at all. Experimental — slower and less capable than cloud cleanup, so
  it's an explicit opt-in.

### UI
- Live transcription progress in the Flow Bar ("Transcribing 45%").
- A new **Local AI** settings tab: route, models, speech intelligence,
  performance/battery.

## Notes

- **Minimum macOS is now 13.4** (was 13.0) when the Indic engine is included —
  its ONNX runtime requires it. A `LOCAL_INDIC=0` source build stays at 13.0.
- The app is larger (~34 → ~55 MB) because it bundles the on-device engines.
  **Model weights are never bundled** — they download only if you enable local AI.
- Cloud-only users: nothing changes. Same providers, keys, shortcuts, snippets,
  modes, prompts, history.

## Under the hood

whisper.cpp v1.9.3 · llama.cpp v0.4.0 · sherpa-onnx v1.13.7 · Silero VAD ·
AI4Bharat IndicConformer · Qwen3-0.6B. All open source, all free. Built as one
universal (Apple Silicon + Intel) binary.
