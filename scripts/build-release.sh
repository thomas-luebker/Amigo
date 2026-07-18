#!/bin/bash
# Build a signed distribution archive ready for TestFlight/App Store upload.
# Output: build/iPadUAE.xcarchive  (open in Xcode Organizer to distribute)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "==> Building WinUAE core (arm64 device, -O3)"
./scripts/build-ios-core.sh device

echo "==> Regenerating Xcode project"
xcodegen -s app/project.yml

echo "==> Archiving (Release, automatic signing)"
xcodebuild -project app/iPadUAE.xcodeproj -scheme iPadUAE \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -allowProvisioningUpdates \
  -archivePath build/iPadUAE.xcarchive \
  archive

echo
echo "==> Archive ready: build/iPadUAE.xcarchive"
echo "    Open Xcode → Organizer → Distribute App → TestFlight & App Store."
