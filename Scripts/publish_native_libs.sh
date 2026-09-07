#!/usr/bin/env bash
# Publish the locally-built native engine libraries as a GitHub pre-release so CI
# doesn't have to compile whisper.cpp + llama.cpp + sherpa-onnx (which builds
# ONNX Runtime from source, ~90 min) on every run.
#
# Run this after a submodule bump, once you have a clean local universal build:
#   ARCH=universal make whisper-libs llama-libs sherpa-libs
#   Scripts/publish_native_libs.sh
#
# The key is sha256(sorted submodule SHAs)[:16] — the same value ci.yml and
# release.yml compute, so a bump automatically points CI at a fresh asset (and
# falls back to a source build until this script publishes it).
set -euo pipefail
cd "$(dirname "$0")/.."

key=$(git submodule status | awk '{gsub(/^[+-]/,"",$1); print $1}' | sort | shasum -a 256 | cut -c1-16)
tag="native-libs-${key}"
tarball="build/native-macos.tar.gz"

for d in build/whisper build/llama build/sherpa build/Frameworks; do
  [[ -d "$d" ]] || { echo "❌ missing $d — run 'ARCH=universal make whisper-libs llama-libs sherpa-libs' first"; exit 1; }
done

echo "→ packing $tarball"
tar czf "$tarball" build/whisper build/llama build/sherpa build/Frameworks
ls -lh "$tarball"

if gh release view "$tag" >/dev/null 2>&1; then
  echo "→ $tag exists — replacing asset"
  gh release upload "$tag" "$tarball" --clobber
else
  echo "→ creating $tag"
  gh release create "$tag" "$tarball" --prerelease \
    --title "CI native libs — ${key}" \
    --notes "Prebuilt whisper.cpp + llama.cpp + sherpa-onnx universal libs for CI. Not a user-facing release."
fi
echo "✓ published $tag"
