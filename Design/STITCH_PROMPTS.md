# FlowKeys — Google Stitch Prompts (design track for Phase 5)

How to use: open Google Stitch (Pro), paste **Prompt 0** first to establish the design
system, then paste each screen prompt as a new screen in the same project. Stitch also
accepts **reference images** — see §Reference Screenshots at the end. Export the generated
screens as PNG + the Stitch spec, drop them in `Design/Screens/<name>/`, and hand them back
to Claude Code to implement against `Sources/DesignSystem.swift`.

FlowKeys is a **macOS menu-bar app** (not iOS, not a web app). Every screen is either a
small floating panel, a menu-bar popover (~320 pt wide), a settings window (~720 pt wide),
or a tiny always-on-top overlay. Design **dark only**.

---

## Prompt 0 — Design system (paste first)

```
Create a design system for "FlowKeys", a premium macOS menu-bar voice dictation app.
Aesthetic: "Kinetic Monolith" — dark, quiet, precise, a little warm. Think Linear +
Raycast + Wispr Flow, but calmer.

Platform: macOS desktop. Dark theme ONLY. No light mode.

Color tokens:
- background            #0F0F11
- surface               #131313
- surface raised        #20201F
- surface top           #2A2A2A
- hairline / outline    rgba(255,255,255,0.07)
- accent (primary)      #FF6B35  (warm orange)
- accent soft           #FFB59D  (salmon)
- success               #53E16F
- error                 #FFB4AB
- text primary          rgba(255,255,255,0.87)
- text muted            rgba(255,255,255,0.40)

Type: SF Pro / system. Sizes 11 / 13 / 15 / 20 / 28. Weights: regular, medium, semibold.
Tight line-height. Sentence case, never ALL CAPS.

Shape: continuous ("squircle") corner radius. Cards 12pt. Panels 16-20pt. Buttons are
pill/capsule. 1px hairline borders, never heavy.

Primary button: horizontal gradient #FF6B35 → #FF6B35 at 80% opacity, white text, capsule,
soft orange glow shadow. Destructive: red gradient.

Motion vocabulary (describe, don't animate): spring, 200-260ms, subtle scale + opacity.
Waveform bars ease with fast attack / slow release.

Density: compact but breathable. 8pt spacing grid. Generous internal padding on cards.

Iconography: SF Symbols style — thin, geometric, monochrome, accent color only for the
one primary action per view.

Tone of copy: short, human, no jargon. "Private offline dictation" not "On-device ASR
inference". Never show the words GGUF, quantization, tensor, ggml in primary UI.
```

---

## Prompt 1 — Menu-bar popover (the main surface)

```
Screen: FlowKeys menu-bar popover. A floating panel that drops from the macOS menu bar.
Width 320pt, height hugs content (~380pt). Solid #0F0F11 background, 16pt continuous
corners, 1px hairline border, large soft shadow.

Top row (header):
- Left: FlowKeys wordmark (15pt semibold) + a tiny 6pt status dot.
- Right: two 24pt icon buttons — Settings (gear), Quit (power).
- A single compact "provider badge": pill, surface-raised, showing an icon + short name
  ("Groq" / "Local" / "Hybrid"). Tappable.

Section 1 — Quick language (segmented control, full width):
  [ EN ][ HI ][ BN ][ MIX ][ AUTO ]  — selected segment uses accent fill, others surface.
  Below it, a smaller inline row: "Script:  Auto · Native · Roman" as tappable text toggles.

Section 2 — Tone / mode (3x2 grid of small square cards, 12pt radius):
  Casual, Email, Code, Notes, Social, Literal. Each: emoji/icon + label (11pt).
  Selected card: accent hairline + faint accent glow.

Section 3 — primary CTA (full-width capsule, gradient accent):
  "Hold Fn to dictate"  with a mic icon. Under it, muted 11pt: "or tap ⌘Fn to toggle".

Footer (muted 11pt, single line): "Local model ready · 57 MB" OR "Using Groq (cloud)".

States to show as variants:
A) Idle (default).
B) Recording — CTA becomes a live waveform strip + red dot + timer "0:04".
C) Local model not downloaded — footer shows "Enable offline mode" as an accent link.
```

---

## Prompt 2 — Recording overlay (tiny always-on-top pill)

```
Screen: FlowKeys recording overlay. A small pill/capsule that floats near the bottom-center
or the notch of a macOS screen. Not a window — no title bar. ~220pt wide when idle,
grows to ~320pt when showing text. Solid #131313, full-capsule radius, 1px hairline that
tints by language (EN neutral, HI accent orange, BN salmon, MIX gradient). Soft shadow.

Show these 6 states as separate frames:

1) Initializing — 3 pulsing dots, muted. Label "Starting…".
2) Recording — animated waveform (12-16 thin vertical bars, accent color, fast-attack
   ease), a small red dot, elapsed timer "0:06", and a tiny language chip "HI" on the right.
   A subtle "Local" chip if local route.
3) Transcribing — waveform freezes to a thin equalizer shimmer, label "Transcribing…".
4) Cleaning — same, label "Cleaning…" with a tiny sparkle icon.
5) Streaming partial (Phase 5) — the pill expands; live transcript text appears in text-primary,
   the last few words dimmer (low confidence), a caret. Max 2 lines, older text scrolls up.
6) Done — brief green check + "Pasted" then auto-dismiss.
7) Error — error-color hairline, short message "Couldn't transcribe", two tiny pill buttons:
   "Retry" (accent) and "Use cloud" (surface). Never show a stack trace.

Keep it whisper-quiet. No big headings. Everything 11-13pt.
```

---

## Prompt 3 — Onboarding: optional offline-model card

```
Screen: a single card shown AFTER the existing FlowKeys setup finishes (not a setup step).
Context: setup window, ~560pt wide, dark. The card sits centered on #0F0F11.

Card (#20201F, 12pt corners, hairline, generous padding):
- Icon: a small shield + waveform, accent.
- Title (20pt semibold): "Private offline dictation"
- Body (13pt muted, 2 lines): "Run speech recognition entirely on your Mac. No internet,
  nothing leaves this device. You can turn it on later in Settings."
- Two model options as selectable rows (radio):
    ( ) Fast          Whisper Base · 57 MB · works on any Mac
    (•) Best quality  Whisper Turbo · 547 MB · recommended
- Free-disk line (11pt muted): "Free space: 84 GB"
- Button row: "Not now" (text button, muted)   "Download & enable" (accent capsule)
- Tiny progress variant: the accent button becomes a progress bar "Downloading 41% · 224 MB / 547 MB · Cancel".

No jargon. Do not imply the app won't work without it.
```

---

## Prompt 4 — Settings window: shell + new "Local AI" tab

```
Screen: FlowKeys Settings window. ~720pt wide, ~560pt tall, dark (#0F0F11).
Left sidebar (200pt, #131313): vertical list of tabs, each an SF-Symbol + label, selected
row has an accent left-bar + surface-raised fill:
  General · Smart Modes · Quick Snippets · Vocabulary · Prompts · Voice Macros · Run Log · Local AI
(Local AI is NEW and last. All others already exist — keep them.)

Right pane: the "Local AI" tab content, scrollable, as stacked cards (#20201F, 12pt,
hairline, 16pt padding, 16pt gap):

Card 1 — "Use local AI" : big toggle (OFF by default). Muted sub-line "Off — using your
cloud provider". When ON, reveal Card 2-5.

Card 2 — "Processing" : segmented  [ Local ]  [ Hybrid ]
  Local = "Everything on this Mac." Hybrid = "Local first, cloud only when unsure."
  A checkbox under Hybrid: "Use Groq / Gemini only when local confidence is low".

Card 3 — "Speech model" : row with name "Whisper Turbo", size "547 MB", status pill
  "Installed" + a "Change…" text button. Expandable list: Base 57MB / Turbo 547MB /
  "Best for Hindi & Bengali" 300MB — each with Download / Installed / Delete.

Card 4 — "Writing cleanup" : "Qwen 0.6B · ~0.5 GB" with Download / Installed. Muted line:
  "Only runs when a sentence needs it."

Card 5 — "Performance" : segmented [ Low Power ] [ Balanced ] [ Accuracy ]  +
  "Unload models after" stepper "30 sec".

Footer strip (muted 11pt): "Models stored in Application Support · 604 MB used · Reveal in Finder".

Everything additive — no existing setting is moved or removed.
```

---

## Prompt 5 — Model manager (expanded detail sheet)

```
Screen: FlowKeys "Manage models" sheet, ~480pt wide, dark, 16pt corners.
Header: "Models" + total size "604 MB" + close.

A list of model rows grouped under two headers: "Speech recognition" and "Writing cleanup".
Each row (#20201F, 12pt, hairline):
- Left: model display name (13pt semibold) + one-line description (11pt muted)
  e.g. "Whisper Turbo — best general accuracy, English + 90 languages".
- Middle: size chip, and language chips ("EN" "HI" "BN").
- Right: state —
    Not installed → "Download" accent pill
    Downloading  → thin progress bar + "224 / 547 MB · Cancel"
    Installed    → green check + "Delete" muted text button
    Active       → "Active" accent chip (no delete)
    Verify failed→ error chip "Re-download"
- Row disabled/greyed if incompatible with this Mac (e.g. needs more RAM) with a muted
  "Needs 16 GB" note.

Bottom: "Free disk space: 84 GB" and a muted note "Deleting the active model switches you
back to cloud."
```

---

## Prompt 6 — Language + script quick switcher (compact popover)

```
Screen: a small popover (240pt wide) that appears when the user clicks the language badge
in the menu bar. Dark, 14pt corners.

Row 1 — "Language" : 2x3 grid of pill toggles: English, हिंदी, বাংলা, Hinglish, Banglish,
Auto-detect. Selected = accent fill. Each pill shows the name in its own script.

Row 2 — "Output script" : three segments — Auto · Native · Roman. A muted helper line that
changes with selection:
  Native → "मुझे कल रिपोर्ट भेज देना"
  Roman  → "mujhe kal report bhej dena"

Row 3 — muted 11pt: "Never translates. Language sets the output, not the meaning."
```

---

## Prompt 7 — Run Log + pipeline debug

```
Screen: FlowKeys "Run Log" tab in Settings (~520pt content width, dark).
A vertical list of recent dictation runs (max ~20). Each run is a collapsible card (#20201F):

Collapsed row: timestamp (11pt muted) · a route chip (Local / Cloud / Hybrid, color-coded) ·
the final text (13pt, 1 line truncated) · total latency "0.9s" · a copy icon.

Expanded card shows labeled sections:
- Raw transcript (muted, monospace-ish)
- Final text (primary)
- Context summary (2 lines, muted)
- A small screenshot thumbnail if present
- A timings strip as tiny chips: "VAD 3ms · ASR load 180ms · ASR 410ms · analysis 2ms ·
  cleanup skipped · paste 12ms"
- If hybrid: "Local confidence 0.62 → escalated to Groq" line in accent.
- Buttons: "Retry", "Delete".

Header: title + "Clear all" (destructive text button) + a filter segmented
[ All ] [ Local ] [ Cloud ].
Never render API keys.
```

---

## Prompt 8 — Command Mode overlay (Phase 5)

```
Screen: FlowKeys "Command Mode" overlay. Triggered when the user has text selected in any
app and presses a hotkey. A floating rounded panel (~360pt wide) near the selection.

State A — listening:
- Small header: "Editing selection" + a muted preview of the selected text (2 lines, dimmed).
- A live waveform + "Listening… say what to change".
- Example chips (muted, tappable to insert): "make it shorter", "translate to Bengali",
  "fix grammar", "bullet points".

State B — applying:
- "Rewriting…" with a sparkle.

State C — diff preview:
- Two stacked blocks: "Before" (muted, strikethrough-tinted) and "After" (primary).
- Buttons: "Replace" (accent capsule) · "Cancel".

Quiet, fast, keyboard-first (Enter = replace, Esc = cancel — show these hints as 11pt).
```

---

## Prompt 9 — Failure & fallback states (collect in one frame)

```
Screen: a gallery frame showing FlowKeys' error and fallback micro-UI, all in the overlay
pill / small toasts, dark, friendly:

1) "Local model still downloading — using Groq for now" (info, accent dot).
2) "No internet and no local model" → "Download offline model" accent button.
3) "Local transcription couldn't start" → "Retry" / "Use cloud".
4) "Low on memory — switched to cloud for this one" (muted, auto-dismiss).
5) "Not enough disk space to download (need 547 MB, 210 MB free)".
6) Permission nudges reused from current app: mic / accessibility / screen recording.

No error codes, no stack traces, no red walls. One line + at most two pill actions.
```

---

## Reference screenshots (feed these to Stitch AND to Claude Code)

Capture from **publicly available marketing / docs pages** and save to
`Design/References/<app>-<screen>.png`. These are inspiration inputs only — do not clone
another product's exact layout or brand.

| App | Screens worth capturing | Why |
|---|---|---|
| **Wispr Flow** (wisprflow.ai, docs.wisprflow.ai) | recording pill, auto-edits before/after, command mode, context-awareness panel | interaction model + the "quiet pill" feel |
| **VoiceInk** (tryvoiceink.com, GitHub README) | model manager, per-app Power Mode settings | model-management IA |
| **superwhisper** | mode switcher, settings layout | dense settings that still feel calm |
| **Raycast** | command palette, settings sidebar | the dark-panel + sidebar language |
| **Linear** | settings pages, empty states | restraint, hairlines, typography |

In Stitch: attach the reference image + the matching prompt above and ask it to "adapt the
layout idea to the FlowKeys design system from Prompt 0". Then export and pass results to
Claude Code with the target file (`MenuBarView.swift`, `RecordingOverlay.swift`,
`SettingsView.swift`, etc.).
