# FlowKeys 2.1.0 — Kinetic Precision

A visual pass over every surface you actually touch. No behaviour changes, no
new permissions, no settings moved — updating from 2.0 is a pure refinement.

## Flow Bar

The floating dictation pill is rebuilt around a real audio-reactive waveform —
20 bars with a ballistic attack/release envelope and neighbour smoothing, drawn
on a Metal-backed canvas so it stays smooth. It now:

- **tints to the language you're dictating in** — cerulean for English, emerald
  for Hindi, forest green for Bengali, thermal orange for a code-switch mix, with
  a matching live language badge.
- shows a **calm flat line when voice detection pauses you**, a **sparkle sweep
  while the transcript is being cleaned**, a **progress bar for on-device
  transcription**, and dedicated states for model download and a missing mic.
- carries a subtle accent glow only while actually recording.

## Command Mode

"Rewrite selection by voice" now shows the selected text right in the pill while
you speak the edit, so you can see what you're about to change.

## Menu bar & settings

- The menu-bar panel shows your active route at a glance — **Cloud, Hybrid, or
  On-device** — with a live status dot, and the language switch is colour-coded
  by dialect.
- Empty screens (History, Snippets, Dictionary) share one calm template: a soft
  icon, a clear next step, and always an action — never a dead end.
- Shortcut keys render as proper inset keycaps throughout.

## Under the hood

- New shared design system (`Kinetic Precision`) — an evolution of the 1.2
  "Kinetic Monolith" tokens, not a rewrite.
- CI/release builds no longer compile the native speech engines from source on
  every run (they're restored from a prebuilt artifact), cutting build time from
  ~90 minutes to ~5.
