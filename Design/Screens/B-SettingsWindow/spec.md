# SCREEN B: Settings Window (740 × 560, dark)

## LEFT SIDEBAR (200pt wide, bg-sidebar):
- **Top:** app icon (40pt) + "FlowKeys" (13pt semibold) + "v1.1.1" (10pt, tertiary) — centered, py20
- **Divider**
- **Nav items (height 36pt each, px12):**
  - **Each:** SF Symbol icon (14pt) + label (13pt medium)
  - **Inactive:** transparent bg, secondary text
  - **Active:** bg-tertiary bg, accent left border (2pt), primary text
  - **Items:**
    - `gearshape.fill`     → General
    - `sparkles`           → Smart Modes  
    - `text.quote`         → Quick Snippets
    - `character.book.closed` → Vocabulary
    - `text.bubble`        → Prompts
    - `waveform.badge.mic` → Voice Macros
    - `list.bullet.clipboard` → Run Log
- **Bottom (pinned):** GitHub link row: person avatar (20pt circle) + "iamadarsha/FlowKeys" (10pt, secondary) + star button (10pt, accent)

## RIGHT CONTENT AREA (540pt wide, bg-primary, scrollable):

### ── GENERAL TAB ──
- **App icon card (centered, py24):** Icon 64pt, cornerRadius 14. "FlowKeys" (20pt semibold display) below. "v1.1.1" (12pt, secondary) below.

- **Card: "App" section**
  - Header: `power` icon (14pt, accent) + "App" (13pt semibold)
  - Toggle row: "Launch FlowKeys at login"
  - Toggle row: "Show menu bar icon"

- **Card: "Updates" section**
  - Header: `arrow.clockwise` icon (14pt, accent) + "Updates" (13pt semibold)
  - Toggle row: "Automatically check for updates"
  - Button + status row: "Check for Updates Now" button (secondary style) + "Last checked: Apr 12 at 19:09" (11pt, tertiary)

- **Card: "API Keys" section**
  - Header: `key` icon (14pt, accent) + "API Key" (13pt semibold)
  - Subtitle: "Keys are stored securely in the macOS Keychain." (11pt, secondary)
  - Two-column row: "Active Transcription Provider" dropdown (bg-tertiary, cornerRadius 6). "Post-Processing LLM Provider" dropdown (bg-tertiary, cornerRadius 6). "Change Provider" button (secondary style)
  - Provider list item: Name bold (13pt) + tagline (11pt, secondary) below. Right: "✓ Configured" (green) or "Add Key" button (accent). API key preview: "gsk_...naUG" (10pt mono, tertiary). Edit + Remove buttons (text style, secondary)

### Card style spec:
- `bg-secondary` background
- `cornerRadius 12`
- `border`: 1pt separator color
- `padding`: 16pt
- `section header`: icon + text, margin-bottom 12pt
- `toggle rows`: full-width HStack, label left, Toggle right
- `row height`: 40pt
- `row separator`: subtle separator line between rows
