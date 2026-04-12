# SCREEN D: Onboarding / Setup Flow (4 steps)

**Window:** 480 × 420pt, centered, dark, cornerRadius 12
**Progress:** step dots at top (4 dots, active = accent filled)

## Step 1 — Welcome:
- Large `waveform.circle.fill` icon (64pt, accent)
- "Welcome to FlowKeys" (24pt semibold display)
- "Voice dictation powered by AI. Works everywhere on your Mac." (14pt, secondary, centered, max-width 320pt)
- "Get Started →" button (accent, full width of 280pt, cornerRadius 8)

## Step 2 — Permissions:
- "Two permissions needed" (18pt semibold)
- Two permission cards:
  - **Card 1:** `mic.fill` icon (24pt, accent) + "Microphone". "Required to record your voice" (11pt secondary). Status: "✓ Granted" green OR "Grant Access →" accent button
  - **Card 2:** `accessibility` icon + "Accessibility". "Required to paste text at cursor". Status: same pattern
- "Continue →" button (accent, disabled until both granted)

## Step 3 — API Key:
- "Connect your AI provider" (18pt semibold)
- Provider selector: 3 cards in a row
  - Groq (⚡ fastest, free), OpenAI, Gemini
  - Active card: accent border, accent-soft bg
- API key input field: bg-tertiary, cornerRadius 8, p10
  - Placeholder: "Paste your API key here"
  - Right side: eye toggle + validate button
- "Validate & Continue →" accent button

## Step 4 — Ready:
- Large `checkmark.circle.fill` (64pt, success green)
- "You're all set!" (24pt semibold)
- "Press [\`] or [F5] anywhere to start dictating." (14pt, secondary, centered)
- Shortcut display: two capsule badges side by side "[\`]" and "[F5]" — bg-tertiary, mono font, cornerRadius 6
- "Start Dictating →" accent button (full width 280pt)
