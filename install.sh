#!/bin/bash
set -e

APP_NAME="FlowKeys"
REPO="iamadarsha/FlowKeys"
INSTALL_DIR="/Applications"
RELEASE_API="https://api.github.com/repos/$REPO/releases/latest"

echo ""
echo "🎙  FlowKeys Installer"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "   Aapki awaaz, aapke words. 🇮🇳"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check macOS
if [[ "$(uname)" != "Darwin" ]]; then
  echo "❌ FlowKeys is macOS only. This script won't work on other systems."
  exit 1
fi

# Check curl
if ! command -v curl &> /dev/null; then
  echo "❌ curl is not installed. Install Xcode Command Line Tools first:"
  echo "   xcode-select --install"
  exit 1
fi

echo "⬇️  Fetching latest release info from GitHub..."

# Try latest endpoint first, then fallback to releases list
JSON_DATA=$(curl -fsSL -H "Accept: application/vnd.github.v3+json" "$RELEASE_API" || \
             curl -fsSL -H "Accept: application/vnd.github.v3+json" "https://api.github.com/repos/$REPO/releases")

# Extract the first DMG link found in the JSON
DMG_URL=$(echo "$JSON_DATA" \
  | grep "browser_download_url" \
  | grep "\.dmg" \
  | head -1 \
  | cut -d '"' -f 4)

if [[ -z "$DMG_URL" ]]; then
  echo "❌ Could not find a DMG in the latest release."
  echo "   Check: https://github.com/$REPO/releases"
  # Show what we got for debugging
  echo "Debug: Data received size: $(echo "$JSON_DATA" | wc -c) bytes"
  exit 1
fi

echo "📦 Found: $DMG_URL"
echo ""

# Download to temp file
TMP_DMG=$(mktemp /tmp/FlowKeys_XXXXXX.dmg)
echo "⬇️  Downloading FlowKeys..."
curl -L "$DMG_URL" -o "$TMP_DMG" --progress-bar

if [[ ! -f "$TMP_DMG" ]]; then
  echo "❌ Download failed."
  exit 1
fi

echo ""
echo "💿 Mounting DMG..."
MOUNT_OUTPUT=$(hdiutil attach "$TMP_DMG" -nobrowse -quiet)
MOUNT_POINT=$(echo "$MOUNT_OUTPUT" | grep "Volumes" | awk '{print $NF}')

if [[ -z "$MOUNT_POINT" ]]; then
  echo "❌ Could not mount DMG. File may be corrupted."
  rm -f "$TMP_DMG"
  exit 1
fi

echo "📂 Mounted at: $MOUNT_POINT"

# Check app exists in DMG
if [[ ! -d "$MOUNT_POINT/$APP_NAME.app" ]]; then
  echo "❌ $APP_NAME.app not found inside DMG."
  hdiutil detach "$MOUNT_POINT" -quiet
  rm -f "$TMP_DMG"
  exit 1
fi

# Remove old version if exists
if [[ -d "$INSTALL_DIR/$APP_NAME.app" ]]; then
  echo "🗑  Removing old version of $APP_NAME..."
  rm -rf "$INSTALL_DIR/$APP_NAME.app"
fi

# Copy to Applications
echo "📦 Installing to $INSTALL_DIR..."
cp -R "$MOUNT_POINT/$APP_NAME.app" "$INSTALL_DIR/"

# THE KEY STEP — Remove Apple quarantine flag
# This is what lets the app open without Gatekeeper warnings
echo "🔓 Removing quarantine flag (this is safe)..."
xattr -dr com.apple.quarantine "$INSTALL_DIR/$APP_NAME.app"

# Cleanup
echo "🧹 Cleaning up..."
hdiutil detach "$MOUNT_POINT" -quiet
rm -f "$TMP_DMG"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ FlowKeys installed successfully!"
echo ""
echo "NEXT STEPS:"
echo "  1. Open /Applications/FlowKeys.app"
echo "  2. Allow Microphone access when prompted"
echo "  3. Allow Accessibility access in:"
echo "     System Settings → Privacy & Security → Accessibility"
echo "  4. Choose your AI provider (Groq is free to start)"
echo "  5. Hold [Fn] anywhere to start talking!"
echo ""
echo "🎙  Aapki awaaz, aapke words. Built for Bharat."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Offer to open app immediately
read -p "Open FlowKeys now? (y/n): " OPEN_NOW
if [[ "$OPEN_NOW" == "y" || "$OPEN_NOW" == "Y" ]]; then
  open "$INSTALL_DIR/$APP_NAME.app"
fi
