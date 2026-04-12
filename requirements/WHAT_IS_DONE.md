# What Is Done (Progress Snapshot)

## Completed
- Added provider abstraction enum (`TranscriptionProvider`) with display metadata and endpoint/model defaults.
- Added per-provider key storage in Keychain (`APIKeyStore`).
- Rewrote transcription service to provider-aware design:
  - OpenAI-compatible multipart path
  - Gemini path
  - Claude hybrid STT rule (Groq dependency)
  - timeout + retry structure
- Rewrote post-processing service to provider-aware request adapters:
  - OpenAI-compatible
  - Gemini
  - Claude
  - Preserved original system prompt contract text
- App state now tracks and persists:
  - `activeTranscriptionProvider`
  - `activeLLMProvider`
- Setup flow updated to provider-first onboarding and provider-specific key validation.
- Settings API section refactored to provider rows with edit/remove and active provider selection.
- Overlay model extended to support error phase with retry button callback.
- App naming/build metadata refactor started for `FlowKeys`:
  - app title usage updates in multiple files
  - Makefile defaults updated
  - Info.plist renamed fields updated
  - FlowKeys entitlements file added

## Partially done / needs verification
- Full compile pass is not yet confirmed green after refactor.
- Context inference (`AppContextService`) remains openai-compatible and may need provider adapters for non-openai LLMs.
- Some UX text and labels may still need final consistency pass.
- DMG generation/output naming needs end-to-end verification.

## Pending validation checklist
- [ ] `make clean && make -j1` succeeds
- [ ] `make dmg` succeeds and outputs `FlowKeys.dmg`
- [ ] Setup flow works end-to-end for each provider path
- [ ] Settings provider key management persists and reloads correctly
- [ ] Recording/transcription/post-processing still works with existing hotkey UX
- [ ] Overlay error + retry behavior is user-usable

## Suggested next command
```bash
make clean && make -j1
```
