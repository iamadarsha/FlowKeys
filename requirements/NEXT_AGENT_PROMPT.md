# Next Agent Prompt (Continue From Here)

You are taking over the `FlowKeys` macOS app refactor from the previous agent.

## Repository
`/Users/iamadarsha/Documents/SpeakFlo/FlowKeys`

## Context
This project started as a fork of Alt-Whisperflow and is being refactored into `FlowKeys` with multi-provider AI support.
A substantial portion is implemented, but the work is not yet fully validated.

Read these first:
1. `requirements/WHAT_IS_DONE.md`
2. `requirements/HANDOVER.md`
3. `requirements/ARCHITECTURE.md`
4. `requirements/HOW_APP_WORKS.md`

## Your Task
Complete and stabilize the in-progress implementation without removing existing core behavior.

### Must preserve
- Menubar-only app (no Dock icon)
- Existing hotkey UX (hold-to-record + toggle/latch behavior)
- Recording overlay UX and debug panel
- Context-aware post-processing quality and original prompt intent
- API key storage only in macOS Keychain (never UserDefaults)

### What remains
1. **Compile to green**
   - Run:
     ```bash
     make clean && make -j1
     ```
   - Fix all compile/runtime-breaking issues from the current refactor.

2. **Provider pipeline validation**
   - Verify transcription + post-processing paths for:
     - Groq
     - OpenAI
     - Gemini
     - Grok
     - Claude (hybrid: Groq STT + Claude LLM)
   - Ensure all provider-specific request formats and error handling are correct.

3. **UI flow validation**
   - Setup must start with provider selection.
   - API key input must be provider-specific and stored in Keychain.
   - Settings must support per-provider key management and active provider selection for:
     - Transcription provider
     - LLM provider

4. **Error UX validation**
   - Ensure overlay error state displays actionable messages.
   - Retry button must work and re-trigger pipeline correctly.

5. **FlowKeys naming/build consistency**
   - Ensure all app/repo/user-facing strings are consistent with `FlowKeys`.
   - Verify bundle + build metadata consistency:
     - App name: `FlowKeys`
     - Bundle ID: `com.flowkeys.app`

6. **Package output**
   - Build DMG:
     ```bash
     make dmg
     ```
   - Verify output artifact is `FlowKeys.dmg`.

## Non-negotiable engineering constraints
- No force unwraps for new/changed code.
- Keep API keys out of logs.
- Async network code uses timeout (30s) + one retry.
- UI updates on main actor; background work off main thread.

## Final deliverable expected from you
Provide:
1. Exact files changed.
2. Summary of compile errors found and fixes applied.
3. Validation results for each provider path.
4. Final build outputs (`app` + `dmg`) and their paths.
5. Any remaining known issues with concrete next steps.
