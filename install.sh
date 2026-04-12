#!/bin/bash
set -euo pipefail

# FlowKeys Installer v1.0.8
# https://github.com/iamadarsha/FlowKeys

APP_NAME="FlowKeys"
REPO="iamadarsha/FlowKeys"
INSTALL_DIR="/Applications"

echo ""
echo "🎙  FlowKeys Installer"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "   Aapki awaaz, aapke words. 🇮🇳"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# ── Platform check ────────────────────────────────────

if [[ "$(uname)" != "Darwin" ]]; then
  echo "❌ FlowKeys is macOS only."
  exit 1
fi

MACOS_VER=$(sw_vers -productVersion)
echo "✅ macOS ${MACOS_VER} — let's go"

for cmd in curl hdiutil xattr; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "❌ Required tool not found: $cmd. This shouldn't happen on macOS."
    exit 1
  fi
done

# ── Fetch release info ────────────────────────────────────

echo "⬇️  Fetching latest release from GitHub..."

RELEASE_JSON=$(curl -fsSL \
  -H "Accept: application/vnd.github.v3+json" \
  "https://api.github.com/repos/${REPO}/releases/latest" 2>/dev/null) || {
  echo "❌ Failed to reach GitHub API. Check your internet connection."
  exit 1
}

# Robust JSON parsing — python3 first, grep fallback
if command -v python3 &>/dev/null; then
  DMG_URL=$(echo "$RELEASE_JSON" | python3 -c \
    "import sys,json; assets=json.load(sys.stdin).get('assets',[]); \
     dmgs=[a['browser_download_url'] for a in assets if a['name'].endswith('.dmg')]; \
     print(dmgs[0] if dmgs else '')" 2>/dev/null || echo "")
  RELEASE_TAG=$(echo "$RELEASE_JSON" | python3 -c \
    "import sys,json; print(json.load(sys.stdin).get('tag_name',''))" 2>/dev/null || echo "")
else
  DMG_URL=$(echo "$RELEASE_JSON" | grep '"browser_download_url"' | grep '\.dmg"' | head -1 | \
    sed 's/.*"browser_download_url": *"\([^"]*\)".*/\1/')
  RELEASE_TAG=$(echo "$RELEASE_JSON" | grep '"tag_name"' | head -1 | \
    sed 's/.*"tag_name": *"\([^"]*\)".*/\1/')
fi

if [[ -z "$DMG_URL" ]]; then
  echo "❌ No DMG found in latest release."
  echo "   Visit: https://github.com/${REPO}/releases"
  exit 1
fi

echo "📦 Found ${RELEASE_TAG}: ${DMG_URL}"
echo ""

# ── Safe temp file ──────────────────────────────────────────

# Clean up any stale temp files from previous failed runs
rm -f /tmp/FlowKeys_*.dmg 2>/dev/null || true

# macOS mktemp does NOT support suffix — create base temp then rename
TMP_BASE=$(mktemp -t FlowKeys)
TMP_DMG="${TMP_BASE}.dmg"
mv "$TMP_BASE" "$TMP_DMG"

trap 'rm -f "$TMP_DMG" "$TMP_BASE" 2>/dev/null || true' EXIT

# ── Download ──────────────────────────────────────────────

echo "⬇️  Downloading FlowKeys..."
HTTP_CODE=$(curl -L "$DMG_URL" -o "$TMP_DMG" --progress-bar \
  -w "%{http_code}" --retry 3 --retry-delay 2 2>/dev/null) || HTTP_CODE="000"

if [[ "$HTTP_CODE" != "200" ]]; then
  echo "❌ Download failed (HTTP ${HTTP_CODE})."
  exit 1
fi

FILE_SIZE=$(stat -f%z "$TMP_DMG" 2>/dev/null || echo 0)
if [[ "$FILE_SIZE" -lt 2000000 ]]; then
  echo "❌ Download looks incomplete (${FILE_SIZE} bytes). Expected > 2MB."
  exit 1
fi
echo "✅ Downloaded ${FILE_SIZE} bytes"

# ── Verify DMG integrity ──────────────────────────────────

echo "🔍 Verifying DMG integrity..."
if ! hdiutil verify "$TMP_DMG" -quiet 2>/dev/null; then
  echo "❌ DMG integrity check failed — file may be corrupted. Please retry."
  exit 1
fi
echo "✅ DMG integrity OK"

# ── Mount ─────────────────────────────────────────────────

echo "💿 Mounting DMG..."
MOUNT_OUTPUT=$(hdiutil attach "$TMP_DMG" -nobrowse -plist 2>&1)

MOUNT_POINT=$(echo "$MOUNT_OUTPUT" | grep -A1 "mount-point" | \
  grep "<string>" | sed 's/.*<string>\(.*\)<\/string>/\1/' | head -1)

if [[ -z "$MOUNT_POINT" ]]; then
  MOUNT_POINT=$(echo "$MOUNT_OUTPUT" | awk '/\/Volumes\//{print $NF}' | head -1)
fi

if [[ -z "$MOUNT_POINT" ]] || [[ ! -d "$MOUNT_POINT" ]]; then
  echo "❌ Failed to mount DMG."
  echo "   hdiutil output: $MOUNT_OUTPUT"
  exit 1
fi
echo "📂 Mounted at: $MOUNT_POINT"

unmount_dmg() {
  hdiutil detach "$MOUNT_POINT" -quiet 2>/dev/null || true
}
trap 'unmount_dmg; rm -f "$TMP_DMG" 2>/dev/null || true' EXIT

# ── Find .app ────────────────────────────────────────────────

APP_PATH=$(find "$MOUNT_POINT" -maxdepth 2 -name "${APP_NAME}.app" -type d 2>/dev/null | head -1)

if [[ -z "$APP_PATH" ]]; then
  echo "❌ ${APP_NAME}.app not found in DMG."
  echo "   DMG contents:"
  ls -F "$MOUNT_POINT"
  exit 1
fi

# ── Install ───────────────────────────────────────────────

if [[ -d "${INSTALL_DIR}/${APP_NAME}.app" ]]; then
  echo "🗑  Removing old version..."
  rm -rf "${INSTALL_DIR:?}/${APP_NAME}.app"
fi

echo "📦 Installing to ${INSTALL_DIR}..."
cp -R "$APP_PATH" "$INSTALL_DIR/"

echo "🔓 Removing quarantine flag..."
xattr -dr com.apple.quarantine "${INSTALL_DIR}/${APP_NAME}.app" 2>/dev/null || true

if [[ ! -d "${INSTALL_DIR}/${APP_NAME}.app" ]]; then
  echo "❌ Installation failed — ${APP_NAME}.app not found in ${INSTALL_DIR}."
  exit 1
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ FlowKeys ${RELEASE_TAG} installed!"
echo ""
echo "NEXT STEPS:"
echo "  1. Open /Applications/FlowKeys.app"
echo "  2. Allow Microphone + Accessibility access when prompted"
echo "  3. Hold [Fn] anywhere to talk — text appears at your cursor"
echo ""
echo "🎙  Aapki awaaz, aapke words."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

read -r -p "Open FlowKeys now? (y/n): " OPEN_NOW 2>/dev/null || OPEN_NOW="n"
if [[ "$OPEN_NOW" == "y" || "$OPEN_NOW" == "Y" ]]; then
  open "${INSTALL_DIR}/${APP_NAME}.app"
fi
