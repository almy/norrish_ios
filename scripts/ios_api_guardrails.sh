#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

echo "Running iOS API guardrails..."

# 1) App must include Photos usage description.
if ! /usr/libexec/PlistBuddy -c "Print :NSPhotoLibraryUsageDescription" healthScanner/Info.plist >/dev/null 2>&1; then
  echo "ERROR: NSPhotoLibraryUsageDescription missing in healthScanner/Info.plist"
  exit 1
fi

# 2) Photo library must not be opened via UIImagePickerController.
if rg -n "sourceType\\s*=\\s*\\.photoLibrary" healthScanner/Views --glob "*.swift" >/tmp/guardrails_photo_library_hits.txt; then
  echo "ERROR: Found UIImagePickerController photo-library usage. Use PHPickerViewController instead."
  cat /tmp/guardrails_photo_library_hits.txt
  exit 1
fi

# 3) Centralize Photos permission request logic in one place.
hits="$(rg -n "PHPhotoLibrary\\.requestAuthorization\\(" healthScanner --glob "*.swift" || true)"
if [ -n "$hits" ]; then
  count="$(printf "%s\n" "$hits" | wc -l | tr -d ' ')"
  if [ "$count" -ne 1 ] || ! printf "%s\n" "$hits" | rg -q "Views/Common/MediaPickers.swift"; then
    echo "ERROR: PHPhotoLibrary.requestAuthorization must only be called in Views/Common/MediaPickers.swift"
    printf "%s\n" "$hits"
    exit 1
  fi
fi

echo "iOS API guardrails passed."
