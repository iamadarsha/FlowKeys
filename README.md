# 🎙 FlowKeys

> **Aapki awaaz, aapke words.** 🇮🇳  
> AI-powered voice dictation for macOS — built for India.

FlowKeys lets you dictate in **English, Hindi, Hinglish, Bengali, or Banglish**
into any app on your Mac. Hold a hotkey → talk → text appears wherever your
cursor is, in the script you chose. Works with Gmail, WhatsApp Web, Notion,
Slack, VS Code, Notes — literally everywhere.

**New in 2.0:** run it **entirely on your Mac** — speech recognition, voice
detection and cleanup, no internet, no API key. Cloud providers still work
exactly as before; on-device AI is opt-in. See
[release notes](requirements/RELEASE_NOTES_2.0.0.md).

---

## ⬇️ Install (One Command)

Open **Terminal** on your Mac and paste this:

```bash
curl -fsSL https://raw.githubusercontent.com/iamadarsha/FlowKeys/main/install.sh | bash
```

That's it. No App Store. No account. No warnings. Takes ~30 seconds.

---

## ✨ Features

- 🎙 **Hold [Fn]** to record, release to paste — or tap **[⌘+Fn]** to toggle
- 🌐 **English · Hindi · Hinglish · Bengali · Banglish** — native code-switching,
  and text lands in the script you pick (Native / Roman / Auto)
- 💻 **Run offline** — on-device speech recognition (whisper.cpp), voice
  detection (Silero), and best-for-Indic ASR (AI4Bharat IndicConformer). Private,
  free, no key. Opt-in.
- ✂️ **On-device cleanup** — removes "um / matlab / mane", collapses
  self-corrections, fixes punctuation, before any LLM touches it
- ✨ **Command Mode** — select text, speak an edit ("make it shorter",
  "translate to Bengali"), it's rewritten in place
- 🧠 **Context-aware** — reads your app and formats text accordingly
- ⚡ **7 Dictation Modes** — Casual, Email, Code, Meeting, Social, Literal, Hindi
- 🔤 **Personal Dictionary** — learns your names, brands, and custom vocab
- 📋 **Snippet Engine** — say "mera address" → types your full address
- 📁 **File Transcription** — drag any audio/video file to transcribe it
- 🔑 **5 cloud AI providers** — Groq (free), OpenAI, Gemini, Grok, Claude — BYOK
- 🔒 **100% Private** — API keys in macOS Keychain; local mode never leaves your Mac

---

## 🔑 Get a Free API Key (Takes 2 Minutes)

FlowKeys needs one AI API key to work. **Groq is free** and fastest:

1. Go to [console.groq.com](https://console.groq.com) → Sign up free
2. Click "Create API Key" → copy the key
3. Paste it into FlowKeys when prompted on first launch

Other supported providers: OpenAI, Google Gemini, xAI Grok, Anthropic Claude

---

## 🚀 How to Use

| Action | Hotkey |
|--------|--------|
| Hold to dictate | Hold `Fn` |
| Toggle dictate on/off | `⌘ + Fn` |
| Open settings | Click menubar icon → ⚙️ |
| Switch language mode | Click menubar icon → HI / EN / MIX |

---

## 💻 System Requirements

- macOS 13.4 or later (13.0 for a cloud-only / `LOCAL_INDIC=0` build)
- Apple Silicon (M1–M4) or Intel Mac — one universal binary
- Microphone
- Internet only if you use a cloud provider — local mode works offline

---

## 🛠 Build From Source

If you prefer to build yourself:

```bash
# Clone the repo
git clone https://github.com/iamadarsha/FlowKeys.git
cd FlowKeys

# Install build tools
brew install create-dmg fileicon

# Build universal DMG
ARCH=universal make dmg

# Install from DMG
open build/FlowKeys.dmg
```

---

## ❓ FAQ

**Does it work offline?**  
No — transcription needs an API call. Groq's free tier is very generous.

**Is my voice data stored anywhere?**  
Only your chosen AI provider receives the audio (for transcription).
FlowKeys itself has no server and stores nothing.

**Why does macOS show a warning on first install?**  
FlowKeys is not from the App Store. The install script handles this
automatically. If you downloaded the DMG manually, run:
```bash
xattr -dr com.apple.quarantine /Applications/FlowKeys.app
```

**Which provider should I use?**  
Start with Groq — it's free, fastest (<1 second), and most reliable
for Indian languages.

---

## 📄 License

MIT — free to use, modify, and distribute.

---

<p align="center">Built with ❤️ for Bharat 🇮🇳</p>
