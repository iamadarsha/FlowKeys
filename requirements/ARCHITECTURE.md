# FlowKeys Architecture

## Top-level app model
- `App.swift`: App entry (`@main`) and MenuBarExtra shell.
- `AppDelegate.swift`: lifecycle orchestration, setup/settings windows, activation policy.
- `AppState.swift`: central orchestration state and pipeline coordinator.

## Core pipeline
1. Trigger from hotkey/controller (`HotkeyManager` + `DictationShortcutSessionController`)
2. Audio capture (`AudioRecorder`)
3. Audio normalization (`AudioNormalization`)
4. Transcription (`TranscriptionService`)
5. Context capture (`AppContextService`)
6. LLM cleanup (`PostProcessingService`)
7. Paste & clipboard restoration (`AppState` helpers)
8. Persist run (`PipelineHistoryStore` + `PipelineHistoryItem`)

## Provider abstraction layer
- `TranscriptionProvider.swift`: provider metadata and endpoint/model declarations.
- `APIKeyStore.swift`: per-provider keychain storage.

## UI surfaces
- Setup: `SetupView.swift`
- Settings: `SettingsView.swift`
- Menubar dropdown: `MenuBarView.swift`
- Overlay: `RecordingOverlay.swift`
- Debug: `PipelineDebugPanelView.swift`, `PipelineDebugContentView.swift`

## Persistence boundaries
- Keychain: API keys per provider (`APIKeyStore`)
- UserDefaults: non-sensitive app state (selected providers, shortcuts, prompts, flags)
- Core Data/SQLite: pipeline run history (`PipelineHistoryStore`)

## Update system
- `UpdateManager.swift` checks GitHub releases and handles download/install flow.
