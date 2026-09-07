---
name: Kinetic Precision
colors:
  surface: '#131315'
  surface-dim: '#131315'
  surface-bright: '#39393b'
  surface-container-lowest: '#0e0e10'
  surface-container-low: '#1b1b1d'
  surface-container: '#201f21'
  surface-container-high: '#2a2a2c'
  surface-container-highest: '#353437'
  on-surface: '#e5e1e4'
  on-surface-variant: '#e1bfb5'
  inverse-surface: '#e5e1e4'
  inverse-on-surface: '#303032'
  outline: '#a98a80'
  outline-variant: '#594139'
  surface-tint: '#ffb59d'
  primary: '#ffb59d'
  on-primary: '#5d1900'
  primary-container: '#ff6b35'
  on-primary-container: '#5f1900'
  inverse-primary: '#ab3500'
  secondary: '#ffb59d'
  on-secondary: '#512313'
  secondary-container: '#6f3b29'
  on-secondary-container: '#efa790'
  tertiary: '#53e16f'
  on-tertiary: '#003911'
  tertiary-container: '#06b146'
  on-tertiary-container: '#003a11'
  error: '#ffb4ab'
  on-error: '#690005'
  error-container: '#93000a'
  on-error-container: '#ffdad6'
  primary-fixed: '#ffdbd0'
  primary-fixed-dim: '#ffb59d'
  on-primary-fixed: '#390c00'
  on-primary-fixed-variant: '#832600'
  secondary-fixed: '#ffdbd0'
  secondary-fixed-dim: '#ffb59d'
  on-secondary-fixed: '#360f03'
  on-secondary-fixed-variant: '#6c3927'
  tertiary-fixed: '#72fe88'
  tertiary-fixed-dim: '#53e16f'
  on-tertiary-fixed: '#002107'
  on-tertiary-fixed-variant: '#00531c'
  background: '#131315'
  on-background: '#e5e1e4'
  surface-variant: '#353437'
typography:
  display:
    fontFamily: Geist
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 32px
    letterSpacing: -0.025em
  headline-lg:
    fontFamily: Geist
    fontSize: 18px
    fontWeight: '600'
    lineHeight: 24px
    letterSpacing: -0.02em
  headline-md:
    fontFamily: Geist
    fontSize: 15px
    fontWeight: '500'
    lineHeight: 20px
    letterSpacing: -0.015em
  body-lg:
    fontFamily: Geist
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
    letterSpacing: -0.01em
  body-default:
    fontFamily: Geist
    fontSize: 13px
    fontWeight: '400'
    lineHeight: 18px
    letterSpacing: -0.005em
  body-compact:
    fontFamily: Geist
    fontSize: 12px
    fontWeight: '400'
    lineHeight: 16px
    letterSpacing: 0em
  label-md:
    fontFamily: Geist
    fontSize: 12px
    fontWeight: '500'
    lineHeight: 16px
    letterSpacing: 0.01em
  label-sm:
    fontFamily: Geist
    fontSize: 11px
    fontWeight: '500'
    lineHeight: 14px
    letterSpacing: 0.02em
  mono-metric:
    fontFamily: JetBrains Mono
    fontSize: 12px
    fontWeight: '500'
    lineHeight: 16px
    letterSpacing: -0.02em
  mono-keycap:
    fontFamily: JetBrains Mono
    fontSize: 10px
    fontWeight: '500'
    lineHeight: 12px
    letterSpacing: 0.04em
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  space-2xs: 0.125rem
  space-xs: 0.25rem
  space-sm: 0.375rem
  space-md: 0.5rem
  space-base: 0.75rem
  space-lg: 1rem
  space-xl: 1.25rem
  space-2xl: 1.5rem
  space-3xl: 2rem
  panel-padding-compact: 0.5rem
  panel-padding-standard: 0.75rem
  panel-padding-modal: 1.25rem
---

## Brand & Style

This design system embodies the focused ergonomics of high-tier native desktop utilities. Built exclusively for dark mode, it draws inspiration from pro-grade productivity software: quiet, distraction-free surfaces, sharp internal hierarchies, and instantaneous visual feedback. The aesthetic unites precise structural minimalism with tactile, macOS-grade materiality—soft ambient depth, micro-hairlines, and organic squircle geometry.

The emotional tone is calm, disciplined, and frictionless. Voice input should feel like thought transferred directly into structured text; the UI serves as an understated, responsive instrument rather than an intrusive overlay. Micro-interactions are snappy (100–180ms curves), state changes are crisp, and high-frequency metrics prioritize cognitive clarity over decorative flourish.

## Colors

The system relies strictly on a calibrated obsidian base hierarchy punctuated by a vivid thermal orange accent for activation, recording, and priority states.

### Core Canvas & Surface System
- **Base Canvas (`#0F0F11`)**: Deep neutral void behind all panels and floating widgets.
- **Surface (`#131313`)**: Primary container background for persistent windows and floating HUD foundations.
- **Surface Raised (`#20201F`)**: Inset containers, segmented pickers, list rows, and card modules.
- **Surface Top (`#2A2A2A`)**: Flyout popovers, active menu selections, keycap badges, and drag handles.
- **Hairline (`rgba(255, 255, 255, 0.07)`)**: Subtle structural divider; replaces heavy solid borders across all components.

### Accent & Feedback
- **Primary Accent (`#FF6B35`)**: Active recording state, primary command triggers, cursor pulsing indicators.
- **Secondary Accent (`#FFB59D`)**: Subtle highlight tags, micro-badges, and soft glow falloffs.
- **Success (`#53E16F`)**: Audio input signal confirmation, engine readiness, verified sync.
- **Warning (`#FFC24B`)**: Audio clipping, low latency network fluctuations, fallback modes.
- **Error (`#FFB4AB`)**: Mic disconnect, permission locks, engine failure.

### Typographic Contrast
- **Text Primary (`rgba(255, 255, 255, 0.90)`)**: Main dictated output, action headers, hotkey values.
- **Text Secondary (`rgba(255, 255, 255, 0.62)`)**: Descriptive labels, breadcrumbs, status captions.
- **Text Muted (`rgba(255, 255, 255, 0.40)`)**: Shortcut key glyphs, metadata, inactive placeholders.

### Language Indicators
- **English (`#4A90E2`)**: Clean cerulean identifier.
- **Hindi (`#138808`)**: Deep saffron/emerald flag node.
- **Bengali (`#0B7345`)**: Forest green badge.
- **Multilingual Mix (`#FF6B35`)**: Inherits primary action warmth for dynamic bilingual dictation.

## Typography

Typography prioritizes high-density desktop scanning, technical clarity, and tabular consistency. The stack utilizes native system proportions (rendered via `Geist` for interfaces and `JetBrains Mono` for metadata, durations, and keycaps).

### Usage Rules
- All numeric measurements, decibel readouts, timestamps (e.g., `00:14.32`), and hotkey shortcuts must use `font-variant-numeric: tabular-nums` or the designated monospaced tokens (`mono-metric`, `mono-keycap`).
- Body text remains compact at 12–13px with tight vertical leading to support dense, data-rich macOS windows and quick-reference panels.
- Micro-labels and shortcut notations employ uppercase styling paired with subtle tracking (`letter-spacing: 0.02em – 0.04em`) to prevent visual mudding on dark backgrounds.

## Layout & Spacing

The layout model is compact, modular, and engineered for floating HUDs, menu bar drop-downs, and configuration settings windows. Spacing follows a strict 4pt baseline rhythm, anchored around `0.25rem` (4px) increments.

### Density & Rhythms
- **Floating Pill HUD**: Compact dynamic width (minimum 180px, expanding contextually to 360px during transcription stream). Height fixed at 36px or 44px with `space-sm` (6px) inline padding.
- **Main Command / Configuration Window**: Fixed-width side navigation (200px) paired with a fluid content workspace (constrained to 540px–680px for optimal readability).
- **Component Padding**: Dense 6px–8px vertical padding for list items and row toggles to allow rapid keyboard-driven navigation.

## Elevation & Depth

Visual hierarchy is maintained through three tactile levers: **luminance stepping**, **crisp hairlines**, and **ambient dual-stage shadows**. Glassmorphic background blur is reserved exclusively for floating overlays that detach from the desktop.

### Elevation Levels

1. **L0 — Canvas / Inactive Base (`#0F0F11`)**: The host level. Zero projection.
2. **L1 — Structural Surface (`#131313`)**: Standard window containers. Enclosed with a continuous `1px solid rgba(255, 255, 255, 0.07)` border. No shadow required when docked; floating dialogs receive:
   `box-shadow: 0 16px 36px -8px rgba(0, 0, 0, 0.75), 0 4px 12px -2px rgba(0, 0, 0, 0.40)`.
3. **L2 — Elevated Modules (`#20201F`)**: Cards, dropdown trays, and hovered list tiles. Border: `1px solid rgba(255, 255, 255, 0.05)`.
4. **L3 — Floating Capsule HUD (`rgba(19, 19, 19, 0.85)` + Backdrop Blur)**: Floating speech indicator. Surface combines a frosted backdrop filter (`backdrop-filter: blur(24px) saturate(180%)`), an inner top hairline highlight (`box-shadow: inset 0 1px 0 0 rgba(255, 255, 255, 0.12)`), and an external low-frequency ambient dispersion (`0 20px 48px -4px rgba(0, 0, 0, 0.85), 0 8px 16px -2px rgba(0, 0, 0, 0.50)`).
5. **L4 — Active Audio Glow**: Active recording states layer an ultra-subtle primary accent aura beneath the HUD:
   `box-shadow: 0 0 0 1px rgba(255, 107, 53, 0.35), 0 8px 28px -2px rgba(255, 107, 53, 0.20)`.

## Shapes

The design system uses continuous Apple-style squircle radii tailored precisely to scale:

- **Panels & Main Windows**: 16px–20px corner radius (`rounded-xl` equivalent).
- **Cards, Inner Sections, & Dialogs**: 12px corner radius.
- **Controls, Dropdowns, & Inputs**: 8px corner radius.
- **Keycaps, Tags, & Mini Pills**: 5px–6px corner radius.
- **Floating HUD & Audio Waveform Bars**: Fully circular capsules (`rounded-full` / 9999px) for continuous fluid boundaries.

## Components

### Buttons & Interactive Triggers
- **Primary Action (Active/Record)**: Solid `#FF6B35` fill with `#0F0F11` text at weight 600. Subtle top-edge inner light (`inset 0 1px 0 rgba(255, 255, 255, 0.25)`). Transitions to `#E55A27` on press with an 0.98 scale compression.
- **Secondary / Ghost**: `#20201F` background with `rgba(255, 255, 255, 0.07)` hairline stroke, text `rgba(255, 255, 255, 0.90)`. Hover shifts to `#2A2A2A` with immediate 120ms transition.
- **Destructive**: Hairline-only with `#FFB4AB` text; hover produces an ambient `rgba(255, 180, 171, 0.08)` surface fill.

### Floating Voice HUD
- Compact horizontal capsule floating above foreground macOS windows.
- Left zone: Live audio reactive visualizer (3–5 vertical rounded bars pulsing smoothly, colored `#FF6B35` when speaking, `#53E16F` when idling, fading to muted white when paused).
- Center zone: Streaming interim speech preview in `body-compact` font, truncation configured to inline trailing ellipses.
- Right zone: Language switcher pill (e.g., `EN` in `#4A90E2`, `HI` in `#138808`) with instant click toggle.

### Keyboard Badges (Keycaps)
- Inset visual cues for shortcut execution (e.g., `⌥ Space`).
- Rendered on `#2A2A2A` surface with `1px solid rgba(255, 255, 255, 0.12)`, text colored `rgba(255, 255, 255, 0.62)` using `mono-keycap`.
- Padded with 2px 5px, minimum width 18px, perfectly center-aligned.

### Input Fields & Search Bars
- Background `#131313` with `#20201F` inner fill and hairline border. Height: 32px for compact utility feel.
- Focus state switches border to `#FF6B35` with an immediate zero-offset focus ring (`box-shadow: 0 0 0 1px #FF6B35`). Placeholder rendered in `rgba(255, 255, 255, 0.40)`.

### Lists & Navigation Rows
- Linear-grade row density: 28px–32px height.
- Hovered item receives `#20201F` with a soft 4px squircle inset from parent boundaries.
- Active/selected item takes `#2A2A2A` with an accent dot or leading glyph rendered in `#FF6B35`.

### Chips & Language Badges
- 20px pill capsules with `rgba(255, 255, 255, 0.04)` fill and hairline outline.
- Includes a 6px saturated indicator dot showing dialect assignment (`#4A90E2`, `#138808`, `#0B7345`, or `#FF6B35`).

### Cards & Settings Containers
- `#20201F` background framed with `1px solid rgba(255, 255, 255, 0.07)` and 12px squircle radius.
- Headers inside cards utilize `headline-md` at 15px with direct 4px margin to secondary descriptive copy.