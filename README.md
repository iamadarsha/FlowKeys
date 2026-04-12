# 🎙 FlowKeys

> **Aapki awaaz, aapke words.** 🇮🇳  
> AI-powered voice dictation for macOS — built for India.

FlowKeys lets you dictate in **Hindi, English, or Hinglish** into any
app on your Mac. Hold a hotkey → talk → text appears wherever your
cursor is. Works with Gmail, WhatsApp Web, Notion, Slack, VS Code,
Notes — literally everywhere.

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
- 🇮🇳 **Hindi + English + Hinglish** — understands code-switching naturally
- 🧠 **Context-aware** — reads your app and formats text accordingly
  - Emails → formal tone  
  - WhatsApp → casual Hinglish  
  - Terminal → literal, no cleanup
- ⚡ **7 Dictation Modes** — Casual, Email, Code, Meeting, Social, Literal, Hindi
- 🔤 **Personal Dictionary** — learns your names, brands, and custom vocab
- 📋 **Snippet Engine** — say "mera address" → types your full address
- 📁 **File Transcription** — drag any audio/video file to transcribe it
- 🔑 **5 AI Providers** — Groq (free), OpenAI, Gemini, Grok, Claude
- 🔒 **100% Private** — API keys stored in macOS Keychain, no server

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

- macOS 13.0 (Ventura) or later
- Apple Silicon (M1/M2/M3/M4) or Intel Mac
- Internet connection (for AI transcription API calls)
- Microphone

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
