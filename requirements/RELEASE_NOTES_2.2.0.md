# FlowKeys 2.2.0 — Reliability + Indigo/Steel

This release fixes two real bugs users could actually hit, and refreshes the
Kinetic Precision design system's accent from orange to an indigo→steel
gradient. No settings moved, no behaviour changed for anyone who isn't hitting
the two bugs below.

## Fixed — the app could get stuck

- **Losing the mic during a video call.** FlowKeys handled audio-hardware
  changes (a call starting, a route/device switching) by tearing down and
  rebuilding the recording engine synchronously inside Apple's own
  configuration-change notification — which Apple's docs warn can deadlock.
  Recovery now happens on a dedicated, fully serialized queue instead, so a
  config change can never race a watchdog-triggered rebuild or a normal
  start/stop.
- **The floating pill getting stuck on "Processing" forever.** Two causes,
  both fixed: (1) if the on-device audio engine failed well after recording
  had already started, FlowKeys never found out and kept believing it was
  still recording; it now gets a failure signal, generation-guarded so a
  stale failure can never kill a newer, healthy session. (2) app-context
  capture (screenshot + accessibility + an optional cloud vision call) had no
  timeout and could block the entire pipeline even after transcription had
  already succeeded; it's now bounded to ~1 second with a fallback.
- Transient error pills (a failed transcription, a dropped connection) now
  auto-dismiss after a couple of seconds instead of sitting there
  indefinitely — permission prompts are unaffected and stay actionable.

## Design — Indigo/Steel

- Replaced the orange accent with an indigo→steel gradient across every
  surface that used it — the menu bar, Settings, the recording pill, language
  badges.
- New native "thinking" orb replaces the old three-dot spinner during
  transcription/cleanup — canvas-based, no new dependencies.
- Settings gets a quick-filter search field, an animated star counter, and a
  border-beam treatment on the GitHub card.
- Your own GitHub avatar next to the repo link is now the FlowKeys icon
  instead.
- Every new animated element respects Reduce Motion.

## Under the hood

- The disfluency filler list now also catches "okay / right / so / alright"
  and the Hindi/Banglish equivalents as sentence-opening verbal tics, not
  just um/uh.
- Verified end-to-end against the real transcription and cleanup APIs, not
  just unit tests, before this release was cut.
