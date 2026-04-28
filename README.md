<div align="center">

<img src="https://raw.githubusercontent.com/iamadarsha/FlowKeys/main/Resources/AppIcon-Source.png" width="120" alt="FlowKeys" />

# FlowKeys

### *Aapki awaaz, aapke words.* 🇮🇳
**A forever-free, intelligent dictation app for macOS — built for India.**

[![Platform](https://img.shields.io/badge/macOS-13%2B-000?style=for-the-badge&logo=apple&logoColor=white)](#-system-requirements)
[![Apple Silicon](https://img.shields.io/badge/Apple_Silicon-Ready-555?style=for-the-badge)](#-system-requirements)
[![Languages](https://img.shields.io/badge/Hindi_·_English_·_Hinglish-FF9933?style=for-the-badge)](#-features)
[![Free Forever](https://img.shields.io/badge/Free_Forever-22c55e?style=for-the-badge)](#-license)
[![License](https://img.shields.io/badge/License-MIT-3b82f6?style=for-the-badge)](LICENSE)

[**Install**](#-install-one-command) · [**Features**](#-features) · [**How It Works**](#-how-it-works) · [**Build From Source**](#-build-from-source) · [**FAQ**](#-faq)

</div>

---

## ⚡ One-line install

Open **Terminal** on your Mac and paste:

```bash
curl -fsSL https://raw.githubusercontent.com/iamadarsha/FlowKeys/main/install.sh | bash
```

No App Store. No account. No warnings. **Takes ~30 seconds.**

<div align="center">
<img src="https://raw.githubusercontent.com/iamadarsha/FlowKeys/main/Resources/demo.gif" width="720" alt="FlowKeys demo" />
</div>

---

## 🎙 What is FlowKeys?

FlowKeys lets you dictate in **Hindi, English, or Hinglish** into any app on your Mac. Hold a hotkey → talk → text appears wherever your cursor is. It works in Gmail, WhatsApp Web, Notion, Slack, VS Code, Notes — literally everywhere a keyboard works.

It's the dictation app Apple should have shipped for India: code-switches naturally, formats text for the app you're in, and stays out of your way.

---

## 🧩 Product Snapshot

| Product surface | What it does | Why it matters |
|---|---|---|
| **Menubar-first UX** | Lives quietly in macOS with a compact popover, recording pill, settings, and provider controls. | Feels native instead of like another browser tab to babysit. |
| **Smart dictation pipeline** | Captures audio, normalizes it, transcribes through your selected provider, then post-processes for the active app. | Turns raw speech into usable writing instead of dumping messy transcripts. |
| **India-aware language layer** | Ships Hindi, English, Hinglish, personal vocabulary, snippets, and Indian context prompts. | Handles the code-switching and proper nouns that generic dictation often mangles. |

## 🏗️ Build Highlights

- Native Swift/macOS app with AppKit, SwiftUI, global hotkeys, menubar state, and permission-aware onboarding.
- BYO-key architecture across Groq, OpenAI, Gemini, Grok, and Claude, with API keys stored in macOS Keychain.
- File transcription, personal dictionary, snippet expansion, debug history, and smart mode settings built as first-class workflows.

---

## ✨ Features

| | |
|---|---|
| 🎙 **Hold-to-talk** | Hold `Fn` to record, release to paste — or `⌘+Fn` to toggle |
| 🇮🇳 **Trilingual** | Hindi + English + Hinglish — understands code-switching naturally |
| 🧠 **Context-aware** | Reads the active app and adapts tone (formal email vs casual WhatsApp) |
| ⚡ **7 Modes** | Casual · Email · Code · Meeting · Social · Literal · Hindi |
| 🔤 **Personal Dictionary** | Learns your names, brands, and custom vocabulary |
| 📋 **Snippet Engine** | Say *"mera address"* → expands to your full address |
| 📁 **File Transcription** | Drag any audio/video file to transcribe it |
| 🔑 **5 AI Providers** | Groq (free) · OpenAI · Gemini · Grok · Claude |
| 🔒 **Private by default** | API keys stored in macOS Keychain. No FlowKeys server. Ever. |

---

## 🔑 Get a Free API Key (2 minutes)

FlowKeys needs one AI API key. **Groq is free, fastest, and best for Indian languages** — start there.

1. Go to **[console.groq.com](https://console.groq.com)** → sign up free
2. Click **Create API Key** → copy the key
3. Paste it into FlowKeys when prompted on first launch

Other providers supported: OpenAI · Google Gemini · xAI Grok · Anthropic Claude

---

## 🚀 How It Works

| Action | Hotkey |
|---|---|
| **Hold to dictate** | Hold `Fn` |
| **Toggle dictate on/off** | `⌘ + Fn` |
| **Open settings** | Click menubar icon → ⚙️ |
| **Switch language mode** | Click menubar icon → `HI` / `EN` / `MIX` |

### The pipeline

```
🎙  You hold Fn
     ↓
🎤  Audio captured at 16kHz mono
     ↓
🌐  Sent to your chosen provider (default: Groq Whisper)
     ↓
🧠  Context-aware reformatting (Email? Code? Casual?)
     ↓
⌨️  Pasted into the active app — under 1 second end-to-end
```

---

## 💻 System Requirements

- macOS **13.0 (Ventura)** or later
- Apple Silicon (M1/M2/M3/M4) or Intel Mac
- Microphone
- Internet (for the AI transcription call)

---

## 🛠 Build From Source

If you'd rather build yourself:

```bash
# Clone
git clone https://github.com/iamadarsha/FlowKeys.git
cd FlowKeys

# Install build tools
brew install create-dmg fileicon

# Build universal DMG
ARCH=universal make dmg

# Install
open build/FlowKeys.dmg
```

The repo ships clean Swift sources, no binary blobs, fully reproducible builds.

---

## ❓ FAQ

<details>
<summary><strong>Does it work offline?</strong></summary><br>
No — transcription needs an API call. Groq's free tier is very generous (rarely a limit you'll hit in normal use).
</details>

<details>
<summary><strong>Is my voice data stored anywhere?</strong></summary><br>
Only your chosen AI provider receives the audio (for transcription). FlowKeys itself has no server, no analytics, no logging. Audio is discarded the moment text comes back.
</details>

<details>
<summary><strong>Why does macOS show a warning on first install?</strong></summary><br>
FlowKeys is not from the App Store. The install script handles this automatically. If you downloaded the DMG manually, run:

```bash
xattr -dr com.apple.quarantine /Applications/FlowKeys.app
```
</details>

<details>
<summary><strong>Which provider should I use?</strong></summary><br>
Start with <strong>Groq</strong> — it's free, fastest (&lt;1 second), and the most reliable for Hindi and Hinglish. If you have an OpenAI/Gemini/Claude/Grok key already, those all work too.
</details>

<details>
<summary><strong>Will FlowKeys ever be paid?</strong></summary><br>
No. The app is MIT-licensed and forever free. You bring your own API key — that's the entire business model.
</details>

---

## 🗺️ Roadmap

- [ ] 🎯 Custom hotkey bindings
- [ ] 📜 Local-first transcription (whisper.cpp on-device)
- [ ] 🌏 Bengali, Tamil, Telugu, Marathi support
- [ ] 🪟 Per-app default mode memory
- [ ] 🧩 Snippet packs (shareable JSON bundles)

---

## 📄 License

MIT — free to use, modify, distribute, and ship in your own products.

---

<div align="center">

**Built with ❤️ for Bharat 🇮🇳**

⭐ Star this repo if FlowKeys saves you time.

</div>
