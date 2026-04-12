# Handover Notes (For Agentic AI)

## Repository root
`/Users/iamadarsha/Documents/SpeakFlo/FlowKeys`

## Current objective
Complete a production-grade `FlowKeys` refactor from single-provider (Groq-focused) to multi-provider architecture:
- Groq
- OpenAI
- Gemini
- Grok (xAI)
- Claude (Anthropic, hybrid for STT)

## High-priority files touched
- `Sources/TranscriptionProvider.swift` (new)
- `Sources/APIKeyStore.swift` (new)
- `Sources/TranscriptionService.swift` (rewritten)
- `Sources/PostProcessingService.swift` (rewritten)
- `Sources/AppState.swift` (provider state + key store wiring)
- `Sources/SetupView.swift` (new provider-first onboarding)
- `Sources/SettingsView.swift` (provider API management UI)
- `Sources/RecordingOverlay.swift` (error + retry overlay state)
- `Sources/App.swift`, `Sources/AppDelegate.swift`, `Sources/MenuBarView.swift` (renaming to FlowKeys)
- `Sources/UpdateManager.swift` (repo/app naming updates)
- `Makefile`, `Info.plist`, `FlowKeys.entitlements` (build metadata updates)

## Build status
Last attempted build failed earlier due actor-isolation on `APIKeyStore`; `@MainActor` was removed to fix that class of errors. Re-run full build to discover remaining issues.

## Key constraints to preserve
- Menubar-only app, no Dock icon
- Existing hotkey UX (hold + toggle + latch behavior)
- Existing debug panel and pipeline history
- Context-aware post-processing prompt quality (do not simplify default prompts)
- API keys must remain in macOS Keychain only

## Immediate next actions for next agent
1. Run `make clean && make -j1` and fix compile errors to green.
2. Verify onboarding compiles and step order is provider -> API key -> remaining flow.
3. Verify settings provider rows and key edit/remove actions compile and persist.
4. Validate transcription + post-processing behavior for each provider path.
5. Build DMG (`make dmg`) and verify output name/path.

## Risk notes
- `AppContextService` still uses OpenAI-compatible `/chat/completions` shape; non-openai LLM providers may need adapter logic if used for context inference.
- Ensure no regression in hold/toggle event state machine and overlay transitions.
- Ensure naming is consistently `FlowKeys` across alerts/UI/build outputs.
