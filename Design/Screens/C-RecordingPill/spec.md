# SCREEN C: Recording Pill States (5 variants)

**Pill size:** 260 × 52pt, cornerRadius 26
**Background:** `#0D0D0F` at 90% opacity + `ultraThinMaterial`
**Shadow:** `0 8px 24px rgba(0,0,0,0.5)`
**Position note:** "Shown at bottom center, 40pt above dock"

## State 1 — RECORDING (hold mode):
- **Left (px14):** `mic.fill` icon (14pt, white) breathing scale animation indicator (shown as 1.2x scale)
- **Center:** 5-bar waveform, bars: 3pt wide, 6pt spacing. Heights from left: 12 / 22 / 34 / 22 / 12 pt (active sample). Bar color: white for active, white 20% for rest
- **Right (px14):** "0:03" timer (12pt mono, white 70%)

## State 2 — RECORDING (toggle mode):
- Same as State 1 but add ⏹ stop button (28pt circle, red 85%) at far right

## State 3 — TRANSCRIBING / PROCESSING:
- **Left:** `ProgressView` spinning arc (mini, white) + "Processing" (12pt medium, white 80%) — side by side
- **Center:** empty / hidden waveform
- **Right:** "..." (12pt mono, white 40%)

## State 4 — DONE:
- **Center:** `checkmark.circle.fill` (18pt, success green) + "Done" (14pt semibold, white)
- **Note:** "Fades out after 0.5s"

## State 5 — ERROR (expanded to 340pt wide):
- **Left:** `exclamationmark.triangle.fill` (14pt, warning yellow)
- **Center:** error message text (11pt, white, 1 line truncated)
- **Right:** "Retry" capsule button (10pt semibold white, blue bg, px10 py6)
