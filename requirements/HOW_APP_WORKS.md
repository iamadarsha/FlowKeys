# How FlowKeys Works (Runtime)

## User journey
1. User opens app from menubar setup flow.
2. User selects provider and adds provider key.
3. User grants permissions (mic/accessibility/screen capture).
4. User sets shortcuts (hold + toggle).
5. User records speech.
6. App transcribes + post-processes contextually.
7. App pastes result at cursor and stores run in history/debug log.

## Trigger behavior
- Hold shortcut: press-and-hold to record, release to stop.
- Toggle shortcut: tap once to start, tap again to stop.
- Latch behavior: while holding, activate toggle to remain in toggle mode.

## Provider behavior
- Transcription provider and LLM provider can be selected independently.
- Claude mode is intended hybrid: Claude for post-processing, Groq Whisper for STT.
- Gemini uses provider-specific request format for audio + text generation flow.

## Error behavior
- Errors should surface in app state and overlay error UI with retry option.
- Pipeline should avoid crashes and produce user-readable failures.

## Data safety
- API keys: Keychain only.
- Non-sensitive settings: UserDefaults.
- Run logs/history: local app data store.
