# FlowKeys — Google Stitch Prompt Pack (Wispr Flow–grade UI/UX)

**Goal:** a full, coherent design system + every screen FlowKeys needs, tuned to feel
as polished and calm as **Wispr Flow**, with the signature "floating widget that comes
alive when you speak."

**How to use**
1. Paste **Prompt 0 (Design System)** into a new Stitch project. Then **Prompt 0-M
   (Motion System)**. These set global rules Stitch reuses.
2. Paste each screen prompt as a **new screen** in the same project. Prompts are
   self-contained but assume Prompt 0/0-M are loaded.
3. Where a prompt says *"attach reference"*, add the matching screenshot from
   `Design/References/` (see the capture guide at the end) so Stitch adapts the layout
   idea to our system.
4. Export each screen (PNG + Stitch spec) into `Design/Screens/<Section>-<name>/` and
   hand the folder back to Claude Code. The **implementation map** at the end says which
   Swift file each screen becomes.

**What FlowKeys is** — a macOS **menu-bar utility**, not a windowed app you keep open.
Three kinds of surface:
- **Flow Bar** — a tiny always-on-top widget over other apps. The star of the show.
- **Menu-bar popover** — the quick panel from the status-bar icon.
- **Hub window** — opened on demand (Settings / History / Dictionary / …). Wispr-Flow
  style sidebar. ~860 × 620 pt.

Design **dark only**. All copy is sentence case, short, human. Never show the words
GGUF, quantization, tensor, ggml, whisper.cpp, llama.cpp in primary UI — those belong
in an Advanced/Debug area.

---

## Prompt 0 — Design system ("Kinetic Monolith" × Wispr calm)

```
Create a design system for "FlowKeys", a premium macOS voice-dictation utility.
Reference feel: Wispr Flow, Raycast, Linear, Superhuman — dark, quiet, precise,
a little warm, zero clutter. The product should feel like it disappears until you
speak, then responds instantly and beautifully.

PLATFORM: macOS desktop. Dark theme ONLY. No light mode. Retina.

COLOR TOKENS (use exactly):
- bg              #0F0F11   (app background, deepest)
- surface         #131313   (panels, sidebars)
- surface-raised  #20201F   (cards)
- surface-top     #2A2A2A   (hover, pressed, inputs)
- hairline        rgba(255,255,255,0.07)   (1px borders, dividers)
- accent          #FF6B35   (warm orange — the ONE primary action color)
- accent-soft     #FFB59D   (salmon — secondary accent, gradients)
- success         #53E16F
- warning         #FFC24B
- error           #FFB4AB
- text-primary    rgba(255,255,255,0.90)
- text-secondary  rgba(255,255,255,0.62)
- text-muted      rgba(255,255,255,0.40)
- lang-en         #4A90E2   (English tint)
- lang-hi         #138808   (Hindi tint)
- lang-bn         #0B7345   (Bengali tint)
- lang-mix        gradient #FF6B35 → #FFB59D   (code-switch tint)

TYPE: SF Pro / system. Scale 11 / 12 / 13 / 15 / 20 / 28 / 40.
Weights regular / medium / semibold. Line-height tight (1.25–1.35).
Numbers use tabular/monospaced digits in stats and timers.

SHAPE: continuous ("squircle") corners everywhere.
- cards 12pt · panels 16–20pt · the Flow Bar and its buttons are full-capsule.
- 1px hairline borders. Never heavy strokes, never drop-shadows on flat UI.
- Floating surfaces get ONE large soft ambient shadow (y 12, blur 40, black 40%)
  and a 1px hairline.

PRIMARY BUTTON: horizontal gradient accent → accent 80%, white text, capsule,
faint orange glow. Destructive = red gradient. Secondary = surface-top fill,
hairline border, text-secondary. Tertiary = text-only, text-muted.

SPACING: 8pt grid. Card padding 16. Panel padding 20. Section gap 16.
Density = compact but breathable (Linear-like).

ICONOGRAPHY: SF Symbols style — thin, geometric, monochrome. Accent color used only
for the single primary action or the active state in a view. Everything else is
text-muted.

ELEVATION MODEL (3 layers):
1. Hub window / popover — flat on bg, hairline-separated regions.
2. Sheets / dialogs — surface-raised, 16pt corners, dim scrim behind (black 45%).
3. Floating widgets (Flow Bar, Command Mode) — capsule, ambient shadow, always-on-top,
   background solid surface with 92% opacity + a very subtle 8px inner vibrancy so
   text stays legible over any app.

VOICE OF COPY: calm, direct, second person. "Hold Fn and talk." not
"Initiate a dictation session." Errors are one line + at most two actions.

DELIVERABLES: color styles, text styles, a component library (button variants,
segmented control, toggle, slider, list row, card, sidebar item, pill/chip,
progress bar, model row, waveform placeholder, empty-state block).
```

---

## Prompt 0-M — Motion & the "speaking" animation system

```
Define the motion system for FlowKeys. Motion is the product's personality — it must
feel alive but never jittery or attention-seeking. Describe these as animation specs
(timing, easing, what moves); Stitch should render representative keyframes.

GLOBAL TIMING
- Micro (hover, toggle, chip select): 140ms, ease-out.
- Standard (panel/sheet in-out, tab change): 220–260ms, spring (response 0.32,
  damping 0.85).
- Widget state changes: 200ms spring (response 0.26, damping 0.8), slight
  overshoot on grow, none on shrink.
- Nothing loops faster than 1.2s except the live waveform.

────────────────────────────────────────────────────────
THE FLOW BAR LIFE CYCLE  (design each as its own keyframe/frame)
────────────────────────────────────────────────────────

0. HIDDEN — nothing on screen.

1. IDLE DOCKED — a 14pt circular "seed": a soft dark disc with a 2pt accent ring at
   40% opacity. It "breathes": scale 0.94 ↔ 1.0 over 2.6s ease-in-out, ring opacity
   0.3 ↔ 0.5 in sync. Sits ~40pt from the bottom-center of the screen (draggable,
   snaps to any screen edge; while docked to a side it becomes a half-pill tab).

2. SUMMON (hotkey pressed) — the seed springs open into a 200pt-wide capsule
   (overshoot to 210, settle). A row of 3 dots does a left-to-right "loading"
   shimmer. Label under/beside: "Starting…". Duration ~0.4s or until first audio.

3. LISTENING — the capsule now shows a LIVE WAVEFORM:
   - 20–28 thin vertical bars (2pt wide, 3pt gap), centered, min height 3pt.
   - Each bar's height is driven by the live mic amplitude for its frequency band
     (or evenly by RMS if no FFT): FAST ATTACK (rise in ~60ms), SLOW RELEASE
     (fall over ~220ms). Result: a fluid, water-like ripple, not a jumpy bar chart.
   - Bar fill = vertical gradient accent (top) → accent-soft (bottom).
   - A soft GLOW RING around the whole capsule pulses outward on volume peaks
     (opacity + 6pt blur bloom, 180ms), tinted by the active language
     (lang-en/hi/bn/mix).
   - Left: a 6pt solid red "REC" dot, slow 1.4s pulse. Right: elapsed timer
     "0:07" (tabular digits, text-secondary). Far right: a tiny language chip
     ("HI"), and a "Local" chip if the on-device engine is running.
   - When toggle-mode: a 24pt circular Stop button (red) on the right.

4. PAUSE DETECTED (VAD says silence) — bars ease down to a calm flat centered line
   (~4pt tall, gentle 2s sine wobble), glow ring dims to 20%. Returns to full
   waveform the instant speech resumes. This is how the user *sees* endpointing.

5. QUIET / WHISPER MODE — if the input is very low but speech is present, the bars
   render at boosted height with a faint horizontal shimmer sweep every 1.6s, and a
   tiny "whisper" glyph (a lowercase speech bubble) appears next to the timer.
   Communicates "we hear you even though you're quiet."

6. STOP → TRANSCRIBING — bars FREEZE, then collapse toward the center into a single
   3pt horizontal line (160ms). A shimmer highlight travels along the line
   left→right on a 1.1s loop. Label: "Transcribing" — or "Transcribing 47%" with a
   thin progress fill under the line when the local model reports progress.

7. STREAMING PARTIAL (Phase 5) — the line expands vertically into a 1–2 line text
   row. Words appear left-to-right as recognized; the last 1–3 words are rendered
   at 55% opacity (low confidence) and snap to full opacity when confirmed. A thin
   1pt caret blinks at the end. Older text scrolls up and fades.

8. CLEANING — a single sparkle/di­amond glint sweeps across the text once
   (left→right, 600ms) with the label "Cleaning". (Only shown if the cleanup pass
   is non-trivial; skip for instant results.)

9. DONE — the text row collapses to a capsule; a success-green check "blooms"
   (scale 0→1 with a soft ring expand) with "Pasted". Hold 700ms, then the whole
   widget shrinks back to the IDLE seed (2).

10. ERROR — capsule border turns error-color, a 2px horizontal shake (one cycle,
    120ms), short message ("Couldn't transcribe"), and two capsule buttons:
    "Retry" (accent) / "Use cloud" (surface). No stack traces, ever.

11. MODEL DOWNLOADING — if a needed local model is still downloading when the user
    starts, the capsule shows a thin progress ring around a small download glyph
    and "Getting the offline model ready — 41%". It auto-continues (cloud, or waits)
    per settings.

────────────────────────────────────────────────────────
MENU-BAR ICON  (16pt template icon, monochrome)
────────────────────────────────────────────────────────
- Idle: a simple sound-wave / sunburst mark.
- Recording: the mark's center dot pulses red (1.4s).
- Transcribing: a 1pt arc sweeps around the mark (1s rotation).
- Error: a tiny error-color dot at top-right.
- Model downloading: a tiny progress arc fills clockwise.

────────────────────────────────────────────────────────
COMMAND MODE PANEL
────────────────────────────────────────────────────────
- Appears near the current text selection with a spring + a faint connecting
  "tether" line to the selection for ~300ms, then the tether fades.
- Listening: same waveform vocabulary as the Flow Bar but smaller.
- Applying: "Rewriting…" with the sparkle glint.
- Diff: the old text crossfades to the new text in place (200ms), then Replace/Cancel.

TRANSITIONS BETWEEN HUB SCREENS
- Sidebar tab change: content slides 12pt + crossfades (asymmetric — new content
  enters from the trailing edge).
- Sheets: scale 0.96→1 + fade, scrim fades in behind.
- List items appear with a 20ms-staggered fade+rise on first load only.
```

---

# SECTION A — Floating surfaces (the signature UX)

## A1 — Flow Bar: the complete state set

```
Screen: the FlowKeys "Flow Bar" — a floating always-on-top widget, rendered as a
gallery of ALL its states on one frame so the whole life cycle reads at a glance.
Use Prompt 0-M as the spec. Dark, capsule, ambient shadow, 1px hairline.

Lay out these states as labelled tiles (the widget is ~200–320pt wide, ~44pt tall
except where noted):

1. IDLE SEED — 14pt breathing disc with a faint accent ring, docked bottom-center.
2. IDLE SIDE-TAB — when snapped to the right screen edge: a half-capsule that only
   shows a 3pt vertical accent sliver + the seed.
3. SUMMONING — expanded capsule, 3 loading dots, "Starting…".
4. LISTENING (normal volume) — full live waveform (gradient bars), red REC dot,
   "0:06" timer, "EN" language chip, glow ring (blue-tinted for EN).
5. LISTENING (Hindi) — same, "HI" chip, green-tinted glow ring, a Devanagari-tinted
   accent.
6. LISTENING (code-switch / MIX) — "MIX" chip, gradient glow ring.
7. LISTENING + toggle mode — adds a red circular Stop button on the right.
8. LISTENING + Local — adds a small "Local" chip; a lock glyph.
9. PAUSE DETECTED — calm flat line, dimmed ring, timer still running.
10. WHISPER MODE — boosted bars + shimmer + tiny whisper glyph.
11. TRANSCRIBING — frozen collapsed line + traveling shimmer, "Transcribing".
12. TRANSCRIBING (local, with progress) — thin progress fill + "Transcribing 47%".
13. STREAMING PARTIAL — 2-line text row, last words dimmed, blinking caret.
14. CLEANING — text row + single sparkle glint, "Cleaning".
15. DONE — capsule + green check bloom, "Pasted".
16. ERROR — error border, message "Couldn't transcribe", [Retry] [Use cloud].
17. OFFLINE MODEL DOWNLOADING — progress ring + "Getting the offline model ready — 41%".
18. NO MIC / NO PERMISSION — amber border, "Microphone access needed", [Open Settings].

Also show: the drag affordance (a 2pt grabber dots cluster on hover) and the
right-click context menu (list: Hide Flow Bar · Settings… · Microphone ▸ ·
Language ▸ · Recent transcripts… · Paste last transcript).
```

## A2 — Speaking waveform — deep visual study

```
Screen: a large, focused study of the FlowKeys "speaking" waveform animation, for
a designer + engineer to implement. Dark background, one big rendering plus callouts.

Render the waveform at three amplitude moments side by side:
- QUIET SPEECH: bars ~10–25% height, gentle.
- NORMAL SPEECH: bars 30–70% with 2–3 taller peaks, fluid.
- LOUD / EMPHASIS: a few bars near 100%, glow ring blooming.

Callouts (annotate with thin leader lines):
- Bar geometry: 2pt wide, 3pt gap, 24 bars, centered vertically, min 3pt / max 28pt,
  radius 1pt (pill-cap bars).
- Fill: vertical linear gradient — top #FF6B35, bottom #FFB59D. 100% opacity.
- Envelope per bar: attack 60ms (ease-out), release 220ms (ease-in). Neighboring
  bars are lightly coupled (±1 bar smoothing) so it ripples like water, not like a
  bar chart.
- Glow ring: 1pt accent ring at 30% around the capsule; on a volume peak it blooms
  to 55% + 6pt outer blur for 180ms then decays. Ring hue = active language tint.
- Idle/pause fallback: a single 3pt horizontal line with a slow 2s sine wobble
  (amplitude 2pt).
- Language tint swatches shown: EN blue ring, HI green ring, BN deep-green ring,
  MIX gradient ring.
- A tiny inset: the same waveform at 1/2 scale for Command Mode.

Include a 6-frame filmstrip of one "syllable": rest → attack → peak → hold →
release → rest.
```

## A3 — Command Mode floating panel

```
Screen: FlowKeys "Command Mode" — a floating rounded panel (~360pt wide) that appears
next to a text selection in any app when the user triggers "Rewrite selection by
voice". Dark, 16pt corners, ambient shadow, a faint tether line to the selection
that fades after 300ms.

State A — LISTENING:
- Header: "Editing selection" + a 2-line dimmed preview of the selected text.
- A compact live waveform + "Listening — say what to change".
- Example chips (muted, tappable to pre-fill): "make it shorter" · "fix grammar" ·
  "translate to Bengali" · "more formal" · "bullet points" · "expand this".
- Hint row (11pt muted): "Enter to apply · Esc to cancel".

State B — APPLYING:
- "Rewriting…" with a single sparkle glint sweeping the panel.

State C — DIFF PREVIEW:
- Two stacked blocks: "Before" (text-muted, subtle strikethrough tint) and
  "After" (text-primary). If the change is small, show an inline word-level diff
  instead (removed = red tint + strikethrough, added = green tint).
- Buttons: "Replace" (accent capsule) · "Cancel" (tertiary). "Try again" link.

State D — ERROR: "Couldn't rewrite that — try rephrasing the instruction." [Retry].
```

## A4 — Floating permission & fallback toasts

```
Screen: a gallery of FlowKeys' small floating toasts / nudges — dark capsules that
slide up from the Flow Bar, auto-dismiss after ~2.5s (except actionable ones).

1. "Microphone access needed" · [Open Settings]  (amber dot)
2. "Accessibility access needed to type text" · [Open Settings]
3. "Screen Recording off — context awareness limited" · [Turn on] · [Ignore]
4. "No internet — switched to the offline model" · (info, auto-dismiss)
5. "Offline model still downloading — using Groq for now" · (info)
6. "Low on memory — used the cloud for this one" · (info)
7. "Not enough disk space to download (need 547 MB, 210 MB free)" · [Manage models]
8. "Nothing to transcribe" · (auto-dismiss)
9. "Snippet expanded: my address" · (success, auto-dismiss)
10. "Copied to clipboard" · (success)

Each: one line, ≤ 2 pill actions, a small leading status dot. No titles.
```

---

# SECTION B — Menu bar

## B1 — Menu-bar popover (primary quick panel)

```
Screen: the FlowKeys menu-bar popover — drops from the macOS status-bar icon.
Width 320pt, height hugs content (~420pt). Solid #0F0F11, 16pt corners, hairline,
large ambient shadow.

HEADER ROW:
- Left: "FlowKeys" wordmark (15pt semibold) + a 6pt status dot (green = ready,
  amber = permission needed, blue pulse = recording).
- Right: two 26pt icon buttons — History (clock) and Settings (gear).
- A compact provider/route badge pill (icon + short label): "Groq" / "Local" /
  "Hybrid". Tap → route switcher (Prompt D1).

SECTION — QUICK LANGUAGE (full-width segmented):
  [ EN ][ HI ][ BN ][ MIX ]   selected = accent fill.
  Below, smaller tappable text toggles: "Script:  Auto · Native · Roman".

SECTION — TONE / MODE (3×2 grid of small square cards, 12pt radius):
  Casual · Email · Code · Notes · Social · Literal.
  Selected: accent hairline + faint accent glow. A 7th wide row: "＋ New mode".

PRIMARY CTA (full-width capsule, gradient accent):
  "Hold Fn to dictate"  with a mic glyph. When recording: turns red, "Stop",
  a live mini-waveform replaces the label. Under it, muted 11pt:
  "or tap ⌘Fn to toggle · ⌥⌘Fn to rewrite a selection".

SECONDARY ROW (tertiary buttons): "Rewrite selection by voice" · "Transcribe a file…".

FOOTER (muted 11pt, one line, context-dependent):
  "Local model ready · 57 MB"  /  "Using Groq (cloud)"  /  "Enable offline mode".

STATES to show as variants:
A) Idle.
B) Recording (CTA red + waveform, status dot pulsing).
C) Permission needed (amber banner at top: "Grant microphone access", [Open Settings]).
D) Offline mode on, no model yet ("Download the 57 MB speech model", accent link).
```

## B2 — Menu-bar icon menu (right-click / secondary)

```
Screen: the FlowKeys status-bar icon's secondary menu (native macOS menu style,
dark). Matches the calm of Wispr Flow's tray menu. Rows:

  Open FlowKeys
  Paste last transcript                    ⇧⌘V
  ─────────────
  Start dictation                          Fn
  Rewrite selection by voice               ⌥⌘Fn
  ─────────────
  Language                                 ▸  (EN · HI · BN · MIX · Auto)
  Microphone                               ▸  (device list, ✓ current)
  Smart mode                               ▸  (Casual · Email · Code · … · Auto)
  ─────────────
  Recent transcripts                       ▸  (last 5, click = copy)
  Local AI…
  Settings…                                ⌘,
  ─────────────
  Help & shortcuts
  Quit FlowKeys                            ⌘Q

Show the "Language ▸" submenu expanded as an example, with a "Script" sub-row.
```

---

# SECTION C — Hub window (Wispr-Flow-style sidebar app)

## C0 — Hub window shell + sidebar

```
Screen: the FlowKeys Hub window shell. ~860 × 620pt, dark (#0F0F11), traffic-light
buttons only (no custom titlebar clutter).

LEFT SIDEBAR (208pt, #131313, hairline divider):
- Top: FlowKeys wordmark + a tiny version tag.
- Nav list (SF-Symbol + label; selected row = accent left-bar 3pt + surface-raised
  fill + accent icon):
    Home            house
    History         clock.arrow.circlepath
    Dictionary      character.book.closed
    Snippets        text.badge.plus
    Smart Modes     swirl.circle.righthalf.filled
    Style           slider.horizontal.3
    Voice Macros    music.mic
    Local AI        cpu
    ─────────
    Settings        gearshape
- Bottom of sidebar: a compact "streak" pill — a small flame + "12-day streak",
  and "1,204 words today". Tapping opens Home.

RIGHT PANE: shows the selected section (see C1–C8). Each section has its own
header row: title (20pt semibold) + a short one-line description + section-specific
action on the right.

Show the shell with "Home" selected.
```

## C1 — Home / dashboard

```
Screen: FlowKeys Hub → Home. Reference: Wispr Flow's home dashboard. Dark.
(attach reference: wispr-home.png)

TOP: a search field ("Search your transcripts…") full-width, subtle.

STATS STRIP (3 cards, equal width, surface-raised, 12pt):
1. "Today"  — big tabular number "1,204" + "words" + a faint sparkline of the last
   7 days.
2. "Streak" — "12" + "days" + a row of 7 tiny flame/dot pips (filled = active day).
3. "Speed"  — "142" + "wpm avg" + "vs 128 last week" (success tint if up).

SHORTCUT REMINDER (thin inline card): "Hold  Fn  to dictate anywhere · tap  ⌘Fn
to toggle" with the keys rendered as small keycaps. A "Change shortcut" link.

TRANSCRIPT HISTORY (the main content), grouped by day:
- Group headers: "Today", "Yesterday", "Monday, 2 Mar" (text-muted, sticky).
- Each row: time (11pt muted) · a route chip (Local / Cloud / Hybrid, color-coded) ·
  a language chip · the final text (13pt, 1–2 lines, truncated) · on hover: copy,
  "insert again", flag/star, delete icons appear on the right.
- Click a row → expands inline to show raw vs cleaned + context + timings +
  "Retry" (see C2 for the full detail view).

EMPTY STATE (no history yet): centered — a soft mic/waveform glyph, "Your
transcripts show up here", "Hold Fn anywhere and start talking." + the shortcut keycaps.
```

## C2 — History detail (expanded run)

```
Screen: FlowKeys Hub → History, with one transcript row expanded (and the list
behind it). Dark. This is the debug/trust surface — show everything, calmly.

Expanded card (surface-raised, 12pt, generous padding):
- Header: timestamp · route chip ("Hybrid → cloud (low confidence)") · language chip
  · total latency "0.9s" · a copy button · a ⋯ menu (Delete, Star, Report issue).
- "Final text" — primary, selectable, in a bordered block.
- "Raw transcript" — text-muted, monospace-ish, collapsible ("show raw").
- "What we removed" — small chips for each filler/fix ("um ×2", "false start",
  "self-correction: Thursday→Wednesday"). Only if non-empty.
- "Context" — 2 lines of the inferred activity summary + a small screenshot
  thumbnail (click to enlarge) if present.
- "Timings" — a horizontal strip of tiny chips:
   "VAD 3ms · model load 180ms · transcribe 410ms · analysis 2ms · cleanup 620ms
    · paste 12ms".
- If hybrid escalated: an accent line "Local confidence 0.62 → used Groq".
- Actions: "Retry" (re-runs the pipeline) · "Insert again" · "Delete".
- NEVER show API keys.

Header of the section: "History" + "Stored on this Mac only · last 20 runs" +
a filter segmented [ All ][ Local ][ Cloud ] + "Clear all" (destructive text btn).
```

## C3 — Dictionary / Vocabulary

```
Screen: FlowKeys Hub → Dictionary. Reference: Wispr Flow's dictionary.
(attach reference: wispr-dictionary.png)

Header: "Dictionary" + "Names, brands and fixes FlowKeys should always get right" +
a primary "＋ Add word" button.

Toolbar: a sort dropdown (Starred first · Newest · Oldest · A–Z) + a search field +
a count "38 of 500".

LIST (each row, surface-raised, 12pt):
- Left: a star toggle.
- The word / phrase (13pt semibold) — max 500 entries, 30 chars each.
- If it's a replacement: "spoken 'tame nos' → 'Temenos'" shown as a subtle
  from→to with a small arrow.
- A language chip if language-specific (EN/HI/BN).
- A source tag: "Added by you" / "Learned" (auto-added after 3 uses) / "From
  corrections".
- On hover: edit + delete.

ADD/EDIT SHEET (surface-raised, 420pt):
- "Word or phrase" field.
- Toggle: "This is a correction" → reveals "When I say…" + "Write it as…" fields.
- "Language" segmented (Any · EN · HI · BN).
- Note: "FlowKeys sends only the words relevant to each dictation to the model,
  not the whole list."
- [Cancel] [Save].

LEARN-FROM-CORRECTIONS card at top (dismissible): "You changed 'Rhaul' to 'Rahul'
3 times. Remember this spelling?" [Add] [No thanks].

EMPTY STATE: "No custom words yet", "Add the names and terms FlowKeys keeps
getting wrong."
```

## C4 — Snippets

```
Screen: FlowKeys Hub → Snippets. Reference: Wispr Flow snippets.
(attach reference: wispr-snippets.png)

Header: "Snippets" + "Say a trigger, get a block of text" + "＋ New snippet".
Toolbar: sort (Newest · Oldest · A–Z · Most used) + search.

LIST rows (surface-raised):
- Trigger phrase in a mono chip: "mera address" (≤ 60 chars).
- The expansion preview (2 lines, text-secondary, ≤ 4000 chars).
- A usage count "used 27×" + last-used date.
- A language chip; a fuzzy-match indicator ("also matches 'my address'").
- Hover: edit, duplicate, delete.

NEW/EDIT SHEET:
- "When I say" (trigger) · "Insert this text" (multi-line, grows).
- Toggle "Match loosely (fuzzy)".
- "Languages this trigger works in" (multi-select chips).
- Live preview: "Say 'mera address' → …".
- Import / Export buttons in the sheet footer.

EMPTY STATE: "No snippets yet", "Great for addresses, email sign-offs, boilerplate."
+ an example card the user can tap to create.
```

## C5 — Smart Modes

```
Screen: FlowKeys Hub → Smart Modes. Dark.

Header: "Smart Modes" + "How FlowKeys formats text, per situation" + "＋ New mode".
A master toggle on the right: "Switch modes automatically by app" (on).

GRID of mode cards (2 columns, surface-raised, 12pt, ~160pt tall):
Each card:
- Emoji/icon in a rounded tinted square + mode name (Casual, Email, Code, Notes,
  Social, Literal, Hindi).
- A one-line description of what it does.
- "Auto-activates in:" a row of small app icons (WhatsApp, Mail, VS Code…).
- A language chip if the mode forces a language.
- Active mode: accent hairline + a small "Active now" pill.
- ⋯ menu: Edit, Duplicate, Delete (built-ins can't be deleted, only reset).

EDIT SHEET (surface-raised, 480pt):
- Name, icon (emoji picker), accent color.
- "Base behavior": a segmented [ Use my default prompt ][ Custom prompt ] — custom
  reveals a text editor with a "Reset to built-in" link.
- "Extra rules (added to the prompt)" — a smaller text field.
- "Force language" (None · EN · HI · BN) and "Force script".
- "Auto-activate for these apps" — an app multi-picker (bundle-id chips).
- Live "try it": a tiny input → shows the cleaned output using this mode.
```

## C6 — Style / Tone (Wispr's "Style")

```
Screen: FlowKeys Hub → Style. Reference: Wispr Flow's "Style" screen.
(attach reference: wispr-style.png)

Header: "Style" + "How casual or formal FlowKeys makes your writing, by where you
type it".

FOUR category cards (surface-raised, stacked or 2×2):
- "Personal messages"  (WhatsApp, iMessage, Telegram…)
- "Work chat"          (Slack, Teams…)
- "Email"              (Mail, Outlook, Gmail…)
- "Everywhere else"

Each card:
- The category name + its matched apps as small icons.
- A horizontal SLIDER with 5 detents, labelled under the track:
    Very casual · Casual · Neutral · Polished · Formal
  The active detent shows a live example sentence transformed to that tone
  (e.g. Very casual: "yo can u send that over" · Formal: "Could you please send
  that over?").
- A small "Match my past messages" toggle (uses context) with a privacy note.

Bottom: "Style currently applies to English, Hindi and Bengali." + a link to
Language settings.
```

## C7 — Voice Macros

```
Screen: FlowKeys Hub → Voice Macros. Dark.

Header: "Voice Macros" + "Say an exact phrase, run an exact action" + "＋ New macro".

LIST rows (surface-raised):
- Command phrase in a mono chip ("insert my signature").
- An arrow → payload preview (text, or a described action).
- Hover: edit, delete.

NEW/EDIT SHEET:
- "Command (say exactly)" field — note: "matched exactly, punctuation ignored".
- "Payload" multi-line.
- A warning chip if the command collides with a snippet trigger.

EMPTY STATE: "No macros yet", "Different from snippets: macros need an exact match
and can do more than paste text."
```

## C8 — Prompts (advanced)

```
Screen: FlowKeys Hub → Settings → Prompts (or its own sidebar row under Advanced).
Dark. For power users.

Two editors, stacked, each in a bordered block:
1. "Cleanup prompt" — the system prompt that polishes every transcript.
   - A large monospace-ish text area, pre-filled with the current default.
   - Header: "Modified 12 Mar" badge if changed · "Reset to default" link ·
     a char count.
   - A callout: "This is used for cloud cleanup. On-device cleanup uses a shorter,
     built-in prompt tuned for the small model."
2. "Context prompt" — how FlowKeys summarizes what you're doing.
   - Same layout.

Footer: "Changes apply to the next dictation." + "Export prompts" / "Import".
A subtle danger note: "A broken prompt can make cleanup worse — keep a copy."
```

---

# SECTION D — Local AI (FlowKeys' headline addition)

## D1 — Route switcher (compact popover)

```
Screen: a small popover (240pt) shown when the user taps the route/provider badge
(menu bar or Hub header). Dark, 14pt corners.

Three big selectable rows (radio):
  ( ) Cloud    — "Fast, best quality. Uses your Groq / Gemini key."
  ( ) Local    — "Everything on this Mac. Private, works offline, free."
  ( ) Hybrid   — "Local first, cloud only when it's unsure."

Under Hybrid (when selected): a checkbox "Only use cloud when local confidence is
low" + a muted line "Shown in your history when it happens."

Footer status line: "Local model: Whisper Turbo (547 MB) · ready" or "Local model
not downloaded — [Set up]".

If this build has no engine: rows for Local/Hybrid are disabled with "Not in this
build".
```

## D2 — Local AI overview

```
Screen: FlowKeys Hub → Local AI (overview). Dark. The calm control center for
on-device processing.

Header: "Local AI" + "Run speech recognition and cleanup on this Mac. Optional.
Your cloud providers stay exactly as configured."

CARD 1 — big master toggle "Use local AI" (off by default). Sub-line reflects
state: "Off — using your cloud provider" / "On — Whisper Turbo ready" / "On —
download a speech model below".

When ON, reveal:

CARD 2 — "Processing": segmented [ Local ][ Hybrid ] + the Hybrid checkbox.
A one-line explainer under the choice.

CARD 3 — "Privacy at a glance": a tiny 3-row table
   Route     Audio leaves this Mac?   Transcript leaves?
   Local     No                       No
   Hybrid    Only when escalating     Only when escalating
   Cloud     Yes (to your provider)   Yes
"FlowKeys has no server. Nothing is ever sent to us."

CARD 4 — "Models" summary: 3 mini rows (Speech · Voice detection · Cleanup) each
with name + size + a status pill (Installed / Download / Downloading 41%).
A "Manage models" button → D3.

CARD 5 — "Storage": "604 MB used in Application Support" + [Reveal in Finder] +
[Remove all local models].

FOOTER (muted, tiny): "Speech: Whisper (whisper.cpp). Cleanup: Qwen. All open
source, all free." — this is the ONLY place engine names appear.
```

## D3 — Model manager

```
Screen: FlowKeys Hub → Local AI → Manage models. A full sheet or sub-page.
(attach reference: voiceink-models.png)

Header: "Models" + total "604 MB" + free-disk "84 GB free".

GROUP: "Speech recognition"
Rows (surface-raised, 12pt), each:
- Name + one-line description:
    "Whisper Fast — tiny, works on any Mac"           57 MB   [EN][HI][BN]
    "Whisper Turbo — best general accuracy"           547 MB  [EN][HI][BN]  ★ recommended
    "Best for Hindi & Bengali — native script"        300 MB  [HI][BN]
- Right side state:
    Not installed → "Download" accent pill
    Downloading  → thin progress bar + "224 / 547 MB · Cancel"
    Verifying    → "Checking…"
    Installed    → green check + "Delete"
    Active       → accent "Active" chip (no delete) + "This model handles: English"
    Failed       → error chip "Re-download" + a one-line reason
- Grey/disabled if incompatible: "Needs 16 GB RAM" / "Apple Silicon only".
- A "Use for" control on installed models: a small dropdown to assign a model to
  a language ("English → Turbo", "Hindi → Indic").

GROUP: "Voice detection"
- "Voice detection — trims silence, finds pauses"     0.9 MB   [Download]/[Installed]

GROUP: "Writing cleanup (optional, experimental)"
- "Qwen 0.6B — on-device cleanup"                     378 MB
  Sub-line: "Slower and less capable than cloud cleanup. The filler/pause pass
  already runs on-device regardless."
  When installed: a toggle "Use on-device cleanup instead of the cloud".

Footer: "Deleting the active speech model switches that language back to cloud."
Download rules note: "Downloads resume if interrupted and are checked for
integrity before use."
```

## D4 — Speech intelligence

```
Screen: FlowKeys Hub → Local AI → Speech intelligence. Dark.

Header: "Speech intelligence" + "How FlowKeys handles fillers, pauses and quiet
speech — on device."

CARD — "Filler cleanup": a segmented control with 4 detents:
   Literal · Light · Standard · Polished
Under it, a live before→after example that changes with the detent:
   Standard: "um so I I wanted to say the report is done"
           → "The report is done."
   Literal:  (unchanged)
A muted line per detent (from Prompt copy: "Removes only um/uh/hmm" … "Also tightens
spacing around long pauses. Never rephrases.").

CARD — "Voice detection (VAD)": toggle. "Trims leading and trailing silence, splits
on natural pauses, and lets the Flow Bar show when you've stopped." + the 0.9 MB
model row inline if not installed.

CARD — "Whisper Mode": toggle (on). "Boosts very quiet speech so you can dictate
under your breath. Never amplifies background noise."

CARD — "Diagnostics" (collapsed, for tinkerers): checkboxes — "Show inference
timings", "Show detected pauses", "Show which fillers were removed", "Keep the
model warm between dictations".
```

## D5 — Performance & battery

```
Screen: FlowKeys Hub → Local AI → Performance. Dark.

Header: "Performance" + "Balance speed against battery. FlowKeys never runs a model
while it's idle."

CARD — a segmented [ Low Power ][ Balanced ][ Accuracy ] with a description each:
- Low Power: "Smallest model, unloads immediately, fewest threads. Best on battery
  and 8 GB Macs."
- Balanced: "Turbo model, keeps warm 30s, moderate threads." (default)
- Accuracy: "Largest installed model, keeps warm 2 min, more threads."

CARD — "Unload models after": a stepper (0s / 15s / 30s / 1m / 2m / 5m). "0 = unload
the instant a dictation finishes."

CARD — "This Mac": a small readout — "Apple Silicon · 16 GB RAM · 8 cores" and
"Recommended: Balanced". (On Intel: "Intel Mac · Metal acceleration unavailable —
CPU only.")

CARD — "Measured" (only after some use): idle memory, model-load time, typical
transcribe time, energy impact — as a tidy little table.
```

## D6 — Onboarding: "Try offline dictation" card

```
Screen: the optional card shown at the end of first-run setup (not a step;
dismissible). Dark, centered on #0F0F11.

Card (surface-raised, generous padding):
- A small shield + waveform glyph, accent.
- Title (20pt semibold): "Private offline dictation"
- Body (13pt secondary, 2 lines): "Run speech recognition entirely on this Mac —
  no internet, nothing leaves your device. You can turn it on any time in Settings."
- Two selectable model rows (radio):
    ( ) Fast          Whisper · 57 MB · works on any Mac
    (•) Best quality  Whisper Turbo · 547 MB · recommended
- Free-disk line: "84 GB free".
- Buttons: "Not now" (tertiary) · "Download & turn on" (accent).
- Progress variant: the accent button becomes a slim progress bar
  "Downloading 41% · 224 / 547 MB · Cancel".
- Success variant: green check + "Offline mode is on."
```

---

# SECTION E — System settings

## E1 — Settings → General

```
Screen: FlowKeys Hub → Settings → General. Dark. Grouped cards.

GROUP — "Shortcuts":
- "Hold to dictate" — a keycap capture field showing "Fn", [Change].
- "Toggle dictation" — "⌘ Fn", [Change].
- "Rewrite selection by voice" — "⌥ ⌘ Fn", [Change].
- A note: "While holding, tap the toggle key to latch on."
- "Start delay" — a small slider "0 ms" (helps if the first word gets cut).

GROUP — "Audio":
- "Microphone" — a dropdown (system devices + "Automatic").
- A live input-level meter under it.
- "Play sounds" toggle + a volume slider.

GROUP — "Text output":
- "Preserve clipboard after pasting" toggle (on).
- "Insert method" — segmented [ Paste (⌘V) ][ Type character by character ].

GROUP — "Network" (collapsed / advanced):
- "Force HTTP/2 for uploads" toggle.
```

## E2 — Settings → System

```
Screen: FlowKeys Hub → Settings → System. Dark.

- "Launch FlowKeys at login" toggle.
- "Show menu-bar icon" toggle (with a warning if turned off: "You'll only be able
  to open FlowKeys from the app").
- "Show the Flow Bar" toggle + "Position" (Bottom center · Follow cursor · Last
  place I dragged it).
- "Keep the Flow Bar on top of full-screen apps" toggle.
- "Notifications" — checkboxes (errors only · every transcript · never).
- "Check for updates automatically" toggle + "You're on 2.0.0 · Check now".
```

## E3 — Settings → Providers & API keys

```
Screen: FlowKeys Hub → Settings → Providers. Dark. (The existing multi-provider UI,
refined.)

Intro line: "FlowKeys works with your own API keys. Groq has a generous free tier
and is the fastest for Indian languages."

PROVIDER ROWS (surface-raised, 12pt), one per provider (Groq · OpenAI · Gemini ·
xAI Grok · Anthropic Claude):
- Provider icon + name + a one-line strength ("⚡ Fastest, free tier" etc.).
- State: "No key" → [Add key] · "Key added" → masked "gsk_••••1a2b" + [Edit]
  [Remove] + a green "Validated" or amber "Not checked" chip.
- A "Get a key" external link.

BELOW — two selectors:
- "Transcription provider" — a segmented / dropdown of providers that have a key.
- "Cleanup provider" — same, independent.
- A note: "Claude mode uses Groq for speech and Claude for cleanup."

ADD/EDIT KEY SHEET:
- Provider name, a single secure field (placeholder "gsk_…"), [Validate] button
  showing a spinner → green check / red "Invalid key".
- "Stored only in your macOS Keychain. Never sent to us."
- [Cancel] [Save].
```

## E4 — Settings → Language & script

```
Screen: FlowKeys Hub → Settings → Language & script. Dark.

CARD — "Default language": a 2×3 grid of pills, each label in its own script:
  English · हिंदी · বাংলা · Hinglish · Banglish · Auto-detect.
Selected = accent fill.

CARD — "Output script": segmented  Auto · Native · Roman.
Live helper text that changes:
  Native → "मुझे कल रिपोर्ट भेज देना" / "কাল রিপোর্টটা পাঠিয়ে দিও"
  Roman  → "mujhe kal report bhej dena"
A muted line: "Language sets the output, not the meaning. FlowKeys never
translates unless you ask it to (in Command Mode)."

CARD — "Per-app language" (optional): a list where the user maps an app to a
language override ("WhatsApp → Hinglish", "Mail → English"). [＋ Add rule].

CARD — "Auto-detect" (only if Auto is selected): "FlowKeys picks the language each
time from what it hears" + a confidence note + "Fall back to: [English ▾]".
```

## E5 — Settings → Permissions

```
Screen: FlowKeys Hub → Settings → Permissions (or a card on General). Dark.
Three rows, each with a live status chip and an action:

- "Microphone" — Granted (green) / "Needed" (amber) → [Open System Settings].
- "Accessibility" — required to type text at your cursor.
- "Screen Recording" — optional, improves context awareness. If off:
  "FlowKeys still works — it just can't read the screen to format better."

Each row: icon, name, one-line why, status, button. A top note: "FlowKeys asks for
the minimum. Screen Recording is never used to take screenshots you don't trigger."
```

---

# SECTION F — Onboarding (first run, Wispr-grade)

## F1 — Full onboarding flow (one prompt, then per-step frames)

```
Screen set: FlowKeys first-run onboarding. A single centered window (~560 × 600pt),
dark, with a slim progress indicator (dots) at the top and a large app glyph.
Calm, one decision per screen, "Back"/"Continue" at the bottom, "Skip setup" as a
quiet tertiary link. Design each step as its own frame:

STEP 1 — WELCOME
"FlowKeys" wordmark, a gentle animated waveform mark, tagline "Your voice, your
words — in English, Hindi and Bengali." One line: "Hold a key, talk, and clean
text appears wherever your cursor is." [Get started].

STEP 2 — HOW YOU WANT TO RUN IT
Two big cards:
  ( ) Use a free API key   "Fastest, best quality. Groq's free tier is generous."
  ( ) Run on this Mac      "Private, offline, free. Downloads a small model."
(You can change this later.)

STEP 3a — API KEY  (if "API key")
Provider picker (Groq preselected, "recommended"), a "Get a free key" link that
opens the browser, a secure paste field, [Validate] → green check. 
STEP 3b — OFFLINE MODEL  (if "Run on this Mac")
The D6 card: Fast 57 MB / Best 547 MB, a download progress bar, "84 GB free".

STEP 4 — PERMISSIONS
Three rows (Microphone, Accessibility, Screen Recording-optional) each with a
"Grant" button that opens the right System Settings pane and a live-updating
status chip. "Continue" is disabled until Mic + Accessibility are granted.

STEP 5 — YOUR SHORTCUT
"Hold this key to dictate:" a big keycap showing "Fn" with [Use a different key].
"Tap ⌘Fn to toggle hands-free." A small animated hand/press hint.

STEP 6 — LANGUAGE
The 2×3 language pills + the Auto option + a script toggle. "You can switch
per-dictation from the menu bar."

STEP 7 — TRY IT (live)
A text box + "Hold Fn and say something." The Flow Bar appears docked; when the
user speaks, the waveform animates and the recognized text lands in the box.
A success check when they get a non-empty result. [That works ✓].

STEP 8 — OPTIONAL EXTRAS (skippable, one screen with 3 toggles)
"Add a few snippets now" · "Import names into your dictionary" · "Turn on offline
mode too".

STEP 9 — YOU'RE SET
A tidy cheat-sheet card: Hold Fn · ⌘Fn toggle · ⌥⌘Fn rewrite selection · click the
menu-bar icon for languages & modes. [Start using FlowKeys].
```

---

# SECTION G — States, empty screens, polish

## G1 — Empty states gallery

```
Screen: a gallery of every empty state, dark, each a centered soft glyph + a
one-line title + a one-line hint + (sometimes) a primary action:

- History: "Your transcripts show up here" · "Hold Fn anywhere and start talking."
- Dictionary: "No custom words yet" · "Add names and terms FlowKeys keeps getting
  wrong." · [Add word]
- Snippets: "No snippets yet" · "Great for addresses and sign-offs." · [New snippet]
- Voice Macros: "No macros yet" · "Exact phrase in, exact action out."
- Smart Modes: (never empty — 7 built-ins) show the "＋ New mode" card instead.
- Local AI (engine present, nothing installed): "Offline mode is ready to set up" ·
  [Download the 57 MB model]
- Search (no results): "Nothing matches 'foo'" · "Try fewer words."
```

## G2 — Errors, updates, misc

```
Screen: a gallery frame:
- Update available card (menu bar or Hub banner): "FlowKeys 2.1 is available" ·
  "What's new" link · [Update & relaunch] · [Later].
- Downloading update: slim progress.
- "Something went wrong" full-card (rare): a calm apology, [Copy diagnostics]
  (no keys), [Restart FlowKeys].
- Rate-limit toast: "Groq is rate-limiting — waiting a moment…" (auto-retries).
- First-transcribe-after-update: "Models re-verified ✓" (auto-dismiss).
- Offline + no model + no key: a blocking-but-friendly card "FlowKeys needs either
  an API key or the offline model to work" · [Add key] · [Download model].
```

## G3 — App icon & menu-bar icon set

```
Screen: the FlowKeys icon family, dark canvas:
- App icon (1024): a rounded-square, deep charcoal ground, a warm-orange sunburst /
  sound-wave mark centered, subtle inner glow. macOS Big Sur+ style (soft depth,
  not skeuomorphic).
- Menu-bar template icon (16/18/22pt @1x @2x): the same mark, monochrome, hairline
  weight, plus the 4 state variants from Prompt 0-M (idle, rec red dot,
  transcribing arc, downloading arc).
- A small "Flow Bar seed" mark used as the docked idle widget.
```

---

# Reference screenshots to capture

Save to `Design/References/`. Public marketing / docs / help-center pages only —
these are **inspiration inputs**, not to be copied 1:1. Attach the matching one when
a prompt says *"attach reference"*.

| File | From | For prompt |
|---|---|---|
| `wispr-flowbar.png` | wisprflow.ai hero / demo video still | A1, A2 |
| `wispr-flowbar-listening.png` | any Wispr demo mid-dictation (waveform visible) | A2, 0-M |
| `wispr-home.png` | docs.wisprflow.ai "Navigating the app" | C1 |
| `wispr-dictionary.png` | Wispr help center — Dictionary | C3 |
| `wispr-snippets.png` | Wispr help center — Snippets | C4 |
| `wispr-style.png` | Wispr help center — Style | C6 |
| `wispr-settings.png` | Wispr help center — Settings | E1, E2 |
| `wispr-menubar.png` | Wispr tray menu | B2 |
| `voiceink-models.png` | tryvoiceink.com / VoiceInk GitHub README | D3 |
| `superwhisper-modes.png` | superwhisper.com | C5 |
| `raycast-settings.png` | raycast.com | C0, E1 |
| `linear-empty-state.png` | linear.app | G1 |

Also capture a **15–30s screen recording of Wispr Flow mid-dictation** if you can —
the waveform motion is the single hardest thing to get right from stills. Drop it in
`Design/References/wispr-dictation.mov` and reference it when briefing the
implementation of Prompt 0-M / A2.

---

# Implementation map (screen → Swift file)

After Stitch, hand each exported screen folder to Claude Code with this mapping.

| Stitch screen | Swift target |
|---|---|
| 0 / 0-M (system) | `Sources/DesignSystem.swift` (tokens), a new `Sources/Motion.swift` (durations/curves), `flowkeys-animations.css/js` (the HTML prototypes) |
| A1, A2 (Flow Bar + waveform) | `Sources/RecordingOverlay.swift` — `OverlayPhase`, `PillWaveformView`, `ProcessingDotsView`, `OverlayTheme`; add seed/breathing, pause, whisper, streaming, download states |
| A3 (Command Mode) | new `Sources/CommandModeOverlayView.swift` + wire from `AppState.startCommandMode` |
| A4 (toasts) | `RecordingOverlay.swift` (`showError`, new `showToast`) |
| B1 (menu-bar popover) | `Sources/MenuBarView.swift` |
| B2 (icon menu) | `Sources/App.swift` MenuBarExtra / `AppDelegate.swift` |
| C0 (hub shell + sidebar) | `Sources/SettingsView.swift` (extend the sidebar), new `Sources/HubWindow.swift` |
| C1, C2 (Home, History) | new `Sources/HomeView.swift`; `Sources/PipelineDebugContentView.swift` / `RunLogView` for detail |
| C3 (Dictionary) | `Sources/PersonalDictionary.swift` + its settings view in `SettingsView.swift` |
| C4 (Snippets) | `Sources/SnippetEngine.swift` + `SnippetsSettingsView` |
| C5 (Smart Modes) | `Sources/DictationMode.swift` + `SmartModesSettingsView` |
| C6 (Style) | new `Sources/StyleSettingsView.swift` + a `perAppTone` model; feeds the cleanup prompt |
| C7 (Voice Macros) | `VoiceMacrosSettingsView` in `SettingsView.swift` |
| C8 (Prompts) | `PromptsSettingsView` in `SettingsView.swift` |
| D1 (route switcher) | new `Sources/LocalAI/RouteSwitcherView.swift` |
| D2–D5 (Local AI) | `Sources/LocalAI/LocalAISettingsView.swift` — split into overview / models / intelligence / performance sub-views |
| D6 (offline card) | `Sources/LocalAI/LocalAIOnboardingCard.swift` |
| E1–E5 (settings) | `Sources/SettingsView.swift` (`GeneralSettingsView`, new `SystemSettingsView`, provider rows, new `LanguageSettingsView`, permissions) |
| F1 (onboarding) | `Sources/SetupView.swift` — its `SetupStep` enum + step views |
| G1 (empty states) | a shared `Sources/EmptyStateView.swift` used across the hub |
| G2 (updates/errors) | `Sources/UpdateManager.swift` UI + `RecordingOverlay` toasts |
| G3 (icons) | `Resources/AppIcon-Source.png`, `Scripts/GenerateSunburstIcon.swift` |
```
