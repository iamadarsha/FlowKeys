# FlowKeys UI Design System — v1.1 Refresh

Reference aesthetic: Wispr Flow (https://wisprflow.ai/)
Brand differentiator: Indian language support (Hinglish/Hindi)
Accent: #FF6B35 (saffron — brand identity, use sparingly)

## Screens
Since the Stitch MCP was unavailable, the design specifications have been provided as Markdown files in their respective screen folders:
- [Screen A - MenuBarPopover](Screens/A-MenuBarPopover/spec.md)
- [Screen B - SettingsWindow](Screens/B-SettingsWindow/spec.md)
- [Screen C - RecordingPill](Screens/C-RecordingPill/spec.md)
- [Screen D - Onboarding](Screens/D-Onboarding/spec.md)
- [Screen E - DebugPanel](Screens/E-DebugPanel/spec.md)

## Implementation Notes for Engineers
- All colors map directly to NSColor/SwiftUI Color in SettingsView.swift
- Pill UI maps to RecordingOverlay.swift — PillOverlayView
- Menu popover maps to MenuBarView.swift
- No source file changes were made in this branch — this is design reference only.
