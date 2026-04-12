# SCREEN E: Pipeline Debug Panel (compact, 380 × 300pt)

- Dark floating panel, cornerRadius 12
- **Header:** "Pipeline Debug" (12pt semibold) + X close button
- **Three collapsible rows:**
  - 🎙 Transcription — shows raw Whisper output, provider, latency
  - ✨ Post-Processing — shows LLM output, model used, latency  
  - 📋 Context — shows app name, window title, activity summary
- **Each row:** icon + label + chevron.right (collapsed) or chevron.down (expanded)
- **Expanded content:** monospaced text block, bg-tertiary bg, cornerRadius 6, p8
- **Bottom:** "Copy All" text button (accent, 10pt)
