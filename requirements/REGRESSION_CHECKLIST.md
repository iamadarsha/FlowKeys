# FlowKeys — Regression Checklist

Run this **before merging any phase** and **after each phase's build**. Nothing in the
Local AI upgrade may change a "✓ today" answer.

## A. Build & package

- [ ] `make clean && make -j1` succeeds (universal) with **0 errors**
- [ ] `make dmg` produces `build/FlowKeys.dmg`
- [ ] DMG size within +X MB of the recorded baseline (static engines only; **no model weights bundled**)
- [ ] `codesign --verify --deep build/FlowKeys.app` passes
- [ ] App launches; menu-bar icon appears; **no Dock icon**
- [ ] CI (`.github/workflows/release.yml`) green on the branch

## B. Settings — nothing renamed, moved, or removed

- [ ] Tabs present & in order: General · Smart Modes · Quick Snippets · Vocabulary · Prompts · Voice Macros · Run Log  *(+ Local AI last, from Phase 2)*
- [ ] All existing controls in each tab still render and persist
- [ ] `defaults read com.flowkeys.app` — every pre-existing key unchanged in name/type:
      `active_transcription_provider`, `active_llm_provider`, `hold_shortcut`, `toggle_shortcut`,
      `saved_hold_custom_shortcut`, `saved_toggle_custom_shortcut`, `custom_vocabulary`,
      `selected_microphone_id`, `custom_system_prompt`, `custom_context_prompt`,
      `custom_system_prompt_last_modified`, `custom_context_prompt_last_modified`,
      `shortcut_start_delay`, `preserve_clipboard`, `force_http2_transcription`,
      `sound_volume`, `voice_macros`, `language_mode`, `hasCompletedSetup`,
      `dictation_modes_v1`, `active_dictation_mode_id`, `auto_dictation_mode_enabled`
- [ ] New keys are additive only: `local_ai_settings_v1` (and any `local_ai_*_v1`)

## C. Onboarding

- [ ] Fresh install → setup starts at **provider selection**
- [ ] Provider-specific API key entry, stored in **Keychain** (not UserDefaults)
- [ ] Mic / Accessibility / Screen Recording permission steps work
- [ ] Hold + toggle shortcut capture works
- [ ] Snippets / vocabulary / launch-at-login steps unchanged
- [ ] Test transcription step succeeds
- [ ] Local-model download is **NOT** a mandatory setup step (Phase 2: optional card only, after setup)

## D. Core dictation (per provider: Groq, OpenAI, Gemini, Grok, Claude-hybrid)

- [ ] Hold shortcut: press-hold → speak → release → text pasted at cursor
- [ ] Toggle shortcut: tap → speak → tap → text pasted
- [ ] Latch: hold, then tap toggle → stays recording in toggle mode
- [ ] Recording overlay: initializing → recording (waveform) → transcribing → done
- [ ] Overlay error state + Retry works
- [ ] Clipboard restored after paste when "preserve clipboard" is ON
- [ ] `activeTranscriptionProvider = groq` still means **exactly Groq** (not hybrid/local)
- [ ] Switching transcription provider and LLM provider independently still works
- [ ] Anti-hallucination: short/silent recording does **not** paste "Thank you" / "you"

## E. Language modes

- [ ] English / Hindi / Hinglish menu-bar switch works
- [ ] `language_mode` persists across relaunch
- [ ] Pure Hindi still outputs Devanagari; Hinglish still preserves Roman code-switching
- [ ] *(Phase 4+)* Bengali native + roman; EN/HI/BN/MIX/AUTO switcher; script toggle

## F. Features

- [ ] Snippets: spoken trigger → expansion; fuzzy match threshold unchanged
- [ ] Voice macros: exact command → payload
- [ ] Personal dictionary: learns after 3 appearances; injected into prompt
- [ ] Smart Modes: per-app auto-mode + manual override
- [ ] File transcription: drag audio/video → transcribes *(Phase 2+: optional local backend)*
- [ ] Run Log: entries recorded, raw + cleaned + context shown, retry works, clear works
- [ ] Pipeline debug panel: opens, shows last run's stages
- [ ] UpdateManager: checks GitHub releases, no crash

## G. Local AI (from Phase 2)

- [ ] Local AI **OFF by default** on update from a prior version
- [ ] With Local AI OFF: every A–F item behaves identically to the prior release
- [ ] Model download: resumable, SHA-256 verified, atomic, free-space checked, cancellable
- [ ] Corrupt / partial model → not marked installed; actionable error, no crash
- [ ] Model delete works; active model can't be deleted without switching route
- [ ] **Idle: `Activity Monitor` shows no FlowKeys model memory, no sustained CPU**
- [ ] Model unloads within the configured "unload after" window post-run
- [ ] Local-only mode never sends audio to cloud (verify with Little Snitch / `nettop`)
- [ ] Hybrid escalation is shown in Run Log, never silent

## H. Performance (record numbers in requirements/BENCHMARK_CORPUS.md)

| Machine | idle RSS | ASR load | ASR latency | cleanup latency | peak RSS | notes |
|---|---|---|---|---|---|---|
| Intel 8 GB | | | | | | |
| Apple Silicon 8 GB | | | | | | |
| Apple Silicon 16 GB | | | | | | |
| Apple Silicon 24 GB+ | | | | | | |

## Sign-off

- Phase: ____  Version: ____  Date: ____  Tester: ____
- All boxes ticked, or deviations documented with justification: ________________
