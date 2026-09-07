#!/usr/bin/env bash
# FlowKeys — regression smoke test
#
# Fast, static, no-simulator checks that guard the "do not break what works"
# contract. Run before merging any Local AI phase.
#
#   ./Scripts/regression_smoke.sh              # static checks + arm64 build
#   FULL=1 ./Scripts/regression_smoke.sh       # + universal build + dmg
#
# Requires full Xcode (not just Command Line Tools) for the build steps:
#   sudo xcode-select -s /Applications/Xcode.app

set -uo pipefail
cd "$(dirname "$0")/.."

fail=0
say()  { printf '\n\033[1m%s\033[0m\n' "$*"; }
ok()   { printf '  \033[32m✓\033[0m %s\n' "$*"; }
bad()  { printf '  \033[31m✗\033[0m %s\n' "$*"; fail=1; }

# ---------------------------------------------------------------------------
say "1. Existing settings keys must not be renamed or removed"
REQUIRED_KEYS=(
  active_transcription_provider active_llm_provider hold_shortcut toggle_shortcut
  saved_hold_custom_shortcut saved_toggle_custom_shortcut custom_vocabulary
  selected_microphone_id custom_system_prompt custom_context_prompt
  shortcut_start_delay preserve_clipboard force_http2_transcription
  sound_volume voice_macros language_mode
)
for k in "${REQUIRED_KEYS[@]}"; do
  if grep -rq "\"$k\"" Sources/AppState.swift; then ok "$k"; else bad "missing key reference: $k"; fi
done

# ---------------------------------------------------------------------------
say "2. Provider enum intact (Groq/OpenAI/Gemini/Grok/Claude)"
for p in 'case groq' 'case openai' 'case gemini' 'case grok' 'case claude'; do
  if grep -q "$p" Sources/TranscriptionProvider.swift; then ok "$p"; else bad "TranscriptionProvider $p"; fi
done

# ---------------------------------------------------------------------------
say "3. Settings tabs intact"
for t in general modes snippets dictionary prompts macros runLog; do
  if grep -q "case $t" Sources/AppState.swift; then ok "SettingsTab.$t"; else bad "SettingsTab.$t"; fi
done

# ---------------------------------------------------------------------------
say "4. Local AI must be additive & default-off"
grep -q 'local_ai_settings_v1' Sources/LocalAI/LocalAISettings.swift \
  && ok "own versioned key local_ai_settings_v1" || bad "versioned key missing"
grep -q 'isEnabled: Bool = false' Sources/LocalAI/LocalAISettings.swift \
  && ok "isEnabled defaults false" || bad "Local AI not default-off"
grep -q 'route: TranscriptionRoute = .existingCloud' Sources/LocalAI/LocalAISettings.swift \
  && ok "route defaults to existingCloud" || bad "route default wrong"
grep -q 'return .useExistingCloud' Sources/LocalAI/LocalAIController.swift \
  && ok "routeDecision defers to cloud when inert" || bad "routeDecision default wrong"

# ---------------------------------------------------------------------------
say "5. Model manifest security"
grep -q 'allowedHosts' Sources/LocalAI/LocalModelManifest.swift \
  && ok "download host allow-list present" || bad "no host allow-list"
if grep -qE 'url: URL\(string: "http://' Sources/LocalAI/LocalModelManifest.swift; then
  bad "non-HTTPS model URL"; else ok "all model URLs HTTPS"; fi

# ---------------------------------------------------------------------------
say "6. No force-unwraps in new Local AI code"
if grep -nE '!\s*$|as!|try!|\.first!' Sources/LocalAI/*.swift | grep -v '// ok:'; then
  bad "force-unwrap / force-cast in Sources/LocalAI"
else
  ok "no obvious force-unwraps in Sources/LocalAI"
fi

# ---------------------------------------------------------------------------
say "7. Build"
if ! xcode-select -p 2>/dev/null | grep -q 'Xcode.app'; then
  printf '  \033[33m•\033[0m skipped — full Xcode not selected (Command Line Tools only)\n'
  printf '     run: sudo xcode-select -s /Applications/Xcode.app\n'
else
  if [ "${FULL:-0}" = "1" ]; then
    make clean >/dev/null && make -j1 && ok "universal build" || bad "universal build failed"
    make dmg >/dev/null && [ -f build/FlowKeys.dmg ] && ok "dmg built" || bad "dmg failed"
    du -h build/FlowKeys.dmg 2>/dev/null | awk '{print "     dmg size: "$1}'
  else
    make clean >/dev/null && make -j1 ARCH=arm64 && ok "arm64 build" || bad "arm64 build failed"
  fi
fi

# ---------------------------------------------------------------------------
echo
if [ "$fail" -eq 0 ]; then
  printf '\033[32mSMOKE PASS\033[0m — still run requirements/REGRESSION_CHECKLIST.md manually.\n'
else
  printf '\033[31mSMOKE FAIL\033[0m\n'
fi
exit "$fail"
