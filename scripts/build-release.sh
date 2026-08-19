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

# Auto build number = today's date (YYYYMMDD). Every build uploaded to App
# Store Connect so far has used this scheme (20260814.2 ... 20260816), and
# App Store Connect requires each build number to be HIGHER than the last.
# The previous default here was `git rev-list --count HEAD`, which is
# currently 159 — far below 20260816 — so an unattended release would have
# been rejected on upload. Override for a second build on the same day:
#   ./build-release.sh 20260819.2
BUILD_NUMBER="${1:-$(date +%Y%m%d)}"
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
