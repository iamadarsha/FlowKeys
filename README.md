<div align="center">

<img src="https://raw.githubusercontent.com/iamadarsha/FlowKeys/main/Resources/logo-animated.svg" width="120" height="120" alt="FlowKeys" />

# FlowKeys

### *Aapki awaaz, aapke words.* 🇮🇳
**A forever-free dictation app for macOS — built for Hindi, Bengali, and Hinglish.**

[![Platform](https://img.shields.io/badge/macOS-13.4%2B-000?style=for-the-badge&logo=apple&logoColor=white)](#-system-requirements)
[![Universal Binary](https://img.shields.io/badge/Apple_Silicon_%26_Intel-Universal-555?style=for-the-badge)](#-system-requirements)
[![Languages](https://img.shields.io/badge/Hindi_·_Bengali_·_English_·_Hinglish-6C63FF?style=for-the-badge)](#-features)
[![Free Forever](https://img.shields.io/badge/Free_Forever-22c55e?style=for-the-badge)](#-license)
[![License](https://img.shields.io/badge/License-MIT-4A6FA1?style=for-the-badge)](LICENSE)

[**Install**](#-one-line-install) · [**Features**](#-features) · [**On-Device AI**](#-on-device-ai-optional) · [**How It Works**](#-how-it-works) · [**Build From Source**](#-build-from-source) · [**FAQ**](#-faq)

</div>

---

> **v2.2 —** every surface refreshed to a new indigo/steel design system, a
> from-scratch app icon, and a real reliability pass: fixed a mic-loss race
> during video calls and a floating-pill state bug that could get stuck. See
> [release notes](requirements/RELEASE_NOTES_2.2.0.md). On-device AI (fully
> offline speech recognition, no API key, no audio ever leaving your Mac) has
> shipped since v2.0 and remains **opt-in, off by default** — cloud providers
> work exactly as they always have.

---

## Recruiter Quick Scan

| Signal | Details |
|---|---|
| Product | Native macOS dictation app for Hindi, Bengali, English, and Hinglish |
| What it demonstrates | Swift/AppKit/SwiftUI engineering, real-time audio capture, concurrent systems design, on-device ML inference (whisper.cpp / sherpa-onnx / llama.cpp), multi-provider API orchestration, Keychain-backed credential handling |
| Differentiator | An India-aware dictation layer — code-switching, native-script output, snippets, personal vocabulary, context prompts — with an optional fully-offline pipeline |
| Stack | Swift, SwiftUI, AppKit, AVFoundation, Combine, Keychain, whisper.cpp, llama.cpp, sherpa-onnx, Groq / OpenAI / Gemini / Claude / Grok |

---

## ⚡ One-line install

Open **Terminal** on your Mac and paste:

```bash
curl -fsSL https://raw.githubusercontent.com/iamadarsha/FlowKeys/main/install.sh | bash
```

No App Store. No account. **Takes under a minute.** Universal binary — works
on Apple Silicon and Intel Macs alike.

<div align="center">
<img src="https://raw.githubusercontent.com/iamadarsha/FlowKeys/main/Resources/demo.gif" width="560" alt="FlowKeys recording, thinking, and pasting to the cursor" />
</div>

---

## 🎙 What is FlowKeys?

FlowKeys lets you dictate in **Hindi, Bengali, English, or Hinglish** into
any app on your Mac. Hold a hotkey → talk → text appears wherever your
cursor is. Gmail, WhatsApp Web, Notion, Slack, VS Code, Notes — anywhere a
keyboard works.

It's the dictation layer Apple never shipped for Indian languages: it
code-switches naturally, writes in the correct native script when you want
it to, adapts its formatting to the app you're in, and — if you'd rather it
never touch the network — can run the entire pipeline on-device.

<div align="center">
<img src="https://raw.githubusercontent.com/iamadarsha/FlowKeys/main/Resources/showcase.png" width="720" alt="FlowKeys UI — listening, thinking, done, and the Settings card, all real renders of the shipped app" />
</div>

---

## ✨ Features

<div align="center">
<img src="https://raw.githubusercontent.com/iamadarsha/FlowKeys/main/Resources/features.svg" width="800" alt="FlowKeys features: hold-to-talk, 4 languages, Command Mode, on-device AI, personal dictionary, snippet engine, file transcription, 5 cloud providers, private by default" />
</div>

Also: context-aware formatting (reads the active app and adapts tone —
formal email vs. casual WhatsApp), and 7 dictation modes (Casual · Email ·
Code · Meeting · Social · Literal · Hindi-only) layered on top of the four
languages above.

---

## 🔑 Get a free API key (2 minutes)

The cloud path needs one AI API key. **Groq is free, fastest, and the best
starting point for Hindi and Hinglish.**

1. Go to **[console.groq.com](https://console.groq.com)** → sign up free
2. Click **Create API Key** → copy the key
3. Paste it into FlowKeys when prompted on first launch

Other providers supported: OpenAI · Google Gemini · xAI Grok · Anthropic Claude.

Prefer not to use a cloud key at all? Skip straight to [on-device AI](#-on-device-ai-optional) below.

---

## 💻 On-device AI (optional)

Since v2.0, FlowKeys can run the entire pipeline locally — no network call,
no API key, no audio or text ever leaving your Mac. It's **off by default**;
turning it on doesn't change anything else about how the app behaves.

| Stage | Local engine |
|---|---|
| Speech recognition (English) | [whisper.cpp](https://github.com/ggml-org/whisper.cpp) |
| Speech recognition (Hindi / Bengali) | [AI4Bharat IndicConformer](https://huggingface.co/ai4bharat/indic-conformer-600m-multilingual) via [sherpa-onnx](https://github.com/k2-fsa/sherpa-onnx) |
| Cleanup / filler removal | Deterministic pass, or an optional local LLM ([Qwen3-0.6B](https://huggingface.co/unsloth/Qwen3-0.6B-GGUF) via [llama.cpp](https://github.com/ggml-org/llama.cpp)) |
| Voice activity detection | Silero VAD |

Models download on demand (a few hundred MB each, not bundled in the DMG),
are SHA-256 verified before use, and can be deleted any time from Settings →
Local AI. A **Hybrid** route is also available: local-first, escalating to
your cloud provider only when local confidence is low.

---

## 🚀 How It Works

| Action | Hotkey |
|---|---|
| **Hold to dictate** | Hold `Fn` |
| **Toggle dictate on/off** | `⌘ + Fn` |
| **Open settings** | Click menubar icon → ⚙️ |
| **Switch language mode** | Click menubar icon → `HI` / `BN` / `EN` / `MIX` |

Every hotkey is rebindable in Settings.

### The pipeline

<div align="center">
<img src="https://raw.githubusercontent.com/iamadarsha/FlowKeys/main/Resources/pipeline.svg" width="800" alt="Pipeline: Hotkey, Capture, Transcribe, Clean up, Paste" />
</div>

Cloud transcription typically returns in under a second; total time end to
end depends on how much cleanup the text needs.

---

## 💻 System Requirements

- macOS **13.4 (Ventura)** or later
- Apple Silicon (M1–M4) **or** Intel Mac — universal binary
- Microphone
- Internet for cloud transcription — **not required** if you use on-device AI

---

## 🛠 Build From Source

```bash
# Clone
git clone https://github.com/iamadarsha/FlowKeys.git
cd FlowKeys

# Universal build + DMG (compiles whisper.cpp / llama.cpp / sherpa-onnx —
# first build takes a while, subsequent ones reuse the cache)
ARCH=universal make dmg

# Install
open build/FlowKeys.dmg
```

The repo ships clean Swift sources with no binary blobs — fully reproducible
builds. See [`requirements/`](requirements) for architecture notes and the
regression checklist run before every release.

---

## ❓ FAQ

<details>
<summary><strong>Does it work offline?</strong></summary><br>
Yes, if you turn on <strong>on-device AI</strong> in Settings — the whole pipeline (speech recognition, cleanup) runs locally with no network call. It's opt-in and off by default; without it, transcription uses your chosen cloud provider's API, and Groq's free tier is generous enough that most people rarely hit a limit.
</details>

<details>
<summary><strong>Is my voice data stored anywhere?</strong></summary><br>
With on-device AI, no — audio never leaves your Mac. With a cloud provider, only that provider receives the audio (for transcription). FlowKeys itself has no server, no analytics, no logging. Audio is discarded the moment text comes back.
</details>

<details>
<summary><strong>Why does macOS show a warning on first install?</strong></summary><br>
FlowKeys isn't notarized by Apple — that requires a $99/year developer account, and passing that cost on to users would break the "forever free" promise. The install script clears the quarantine flag automatically. If you downloaded the DMG manually instead, run:

```bash
xattr -dr com.apple.quarantine /Applications/FlowKeys.app
```
</details>

<details>
<summary><strong>Which provider should I use?</strong></summary><br>
Start with <strong>Groq</strong> — it's free, fast, and reliable for Hindi and Hinglish. If you already have an OpenAI/Gemini/Claude/Grok key, those work too. Or skip cloud entirely and use on-device AI.
</details>

<details>
<summary><strong>Will FlowKeys ever be paid?</strong></summary><br>
No. MIT-licensed, forever free. Bring your own API key (or use on-device AI and skip keys entirely) — that's the whole model.
</details>

---

## 🗺️ Roadmap

- [ ] Apple Developer ID signing + notarization (removes the Gatekeeper warning — cost-dependent)
- [ ] Tamil, Telugu, Marathi language support
- [ ] Per-app default mode memory
- [ ] Snippet packs (shareable JSON bundles)

---

## 📄 License

MIT — free to use, modify, distribute, and ship in your own products.

---

<div align="center">

**Built with ❤️ for Bharat 🇮🇳**

⭐ Star this repo if FlowKeys saves you time.

</div>
