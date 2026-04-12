# SCREEN A: Menu Bar Popover (300 × auto, dark)

## Layout (top to bottom):

**[HEADER — 60pt tall]**
- **Left:** `waveform.circle.fill` icon (18pt, accent) + "FlowKeys" (15pt semibold)
- **Right:** `?` icon (14pt, secondary) + gear icon (14pt, secondary)
- **Below:** shortcut hint left "[\`] or [F5]" (10pt mono, tertiary) + provider capsule right "Groq ⚡" (10pt, accent text, accent-soft bg, cornerRadius 10, px8 py3)

**[DIVIDER — separator color]**

**[LANGUAGE ROW — 44pt tall, px16]**
- **Left:** `globe` icon (12pt, secondary)
- **Right:** segmented control "MIX 🇮🇳 | HI 🇮🇳 | EN" (full remaining width, cornerRadius 6, bg-tertiary bg)

**[DIVIDER — separator color]**

**[TONE SECTION — px16 py12]**
- **Header row:** `sliders.horizontal` icon (12pt, secondary) left, "Edit modes" (10pt, accent) right
- **3×2 grid of tone buttons (gap 8pt):**
  - **Each button:** SF Symbol icon centered (16pt), name below (10pt medium). Size: ~(84×52), cornerRadius 8. Inactive: bg-secondary bg, no border. Active: accent-soft bg, accent border 1.5pt
  - **Buttons:**
    - "bubble.left.fill"    → Casual
    - "envelope.fill"       → Email  
    - "chevron.left.forwardslash.chevron.right" → Code
    - "note.text"           → Notes
    - "heart.fill"          → Social
    - "equal.circle.fill"   → Literal

**[DIVIDER — separator color]**

**[RECENT SECTION — px16 py12]**
- **Header:** `clock` icon (12pt, secondary) left, "2m ago" (10pt, tertiary) right
- **Card:** bg-secondary, cornerRadius 8, p10
  - **Transcript text:** 13pt, 3 lines max, text-primary
  - **Copy icon button:** `doc.on.doc` (12pt, accent) — right aligned
  - **Empty state:** `mic` icon (24pt, secondary, centered), "Say something to get started" (11pt, secondary, centered)

**[DIVIDER — separator color]**

**[ACTIONS — px16 py12, bg-secondary]**
- **Primary CTA button:** "🎙 Start Dictating" (13pt semibold, white). Full width, cornerRadius 8, bg: accent. Shadow: `0 4px 12px #FF6B3540`
- **Recording state variant:** "⏹ Stop Recording" (13pt semibold, white). Full width, cornerRadius 8, bg: `#FF453A` (red)
- **Below button:** "v1.1.1" (9pt, tertiary) left. "Quit FlowKeys" (10pt, secondary) right
