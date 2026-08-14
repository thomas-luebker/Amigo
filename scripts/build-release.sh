#!/bin/bash
# Build a signed distribution archive ready for TestFlight/App Store upload.
# Output: build/Amigo.xcarchive  (open in Xcode Organizer to distribute)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "==> Building WinUAE core (arm64 device, -O3)"
./scripts/build-ios-core.sh device

echo "==> Regenerating Xcode project"
xcodegen -s app/project.yml

# Auto build number = git commit count (monotonic), so re-uploads never
# collide. Overrideable: ./build-release.sh <build-number>
BUILD_NUMBER="${1:-$(git rev-list --count HEAD)}"
echo "==> Build number: ${BUILD_NUMBER}"

echo "==> Archiving (Release, automatic signing)"
# Own DerivedData: sharing Xcode's default location corrupts the GUI's
# incremental build database when both build ("error accessing build
# database"), especially since this script also regenerates the project.
xcodebuild -project app/Amigo.xcodeproj -scheme Amigo \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -allowProvisioningUpdates \
  -derivedDataPath build/DerivedData-release \
  CURRENT_PROJECT_VERSION="${BUILD_NUMBER}" \
  -archivePath build/Amigo.xcarchive \
  archive

echo
echo "==> Archive ready: build/Amigo.xcarchive"
echo "    Open Xcode → Organizer → Distribute App → TestFlight & App Store."
