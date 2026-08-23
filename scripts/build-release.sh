#!/bin/bash
# Build a signed distribution archive ready for TestFlight/App Store upload.
# Output: build/Amigo.xcarchive  (open in Xcode Organizer to distribute)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

BUILD_NUMBER="${1:-$(date +%Y%m%d)}"

# Refuse to push the DATE part into the future.
#
# On 2026-08-20 six builds went up as 20260819..20260824 — every same-day
# rebuild bumped the date by one instead of adding a .N suffix. That put
# the scheme four days ahead of the calendar, so for the next four days
# `date +%Y%m%d` produced a number LOWER than the last upload and App
# Store Connect rejected it. For a second build on the same day use a
# suffix: 20260822.1, 20260822.2 — never tomorrow's date.
TODAY="$(date +%Y%m%d)"
DATE_PART="${BUILD_NUMBER%%.*}"
if [[ "$DATE_PART" =~ ^[0-9]{8}$ ]] && [ "$DATE_PART" -gt "$TODAY" ]; then
    echo "ERROR: build number ${BUILD_NUMBER} has a date part in the future (today is ${TODAY})." >&2
    echo "       Advancing the date is what desynchronised this scheme before." >&2
    echo "       For another build today use a suffix: ${TODAY}.1, ${TODAY}.2, ..." >&2
    echo "       If the scheme is still ahead of the calendar and ASC needs a" >&2
    echo "       higher number, add a suffix to the LAST UPLOADED build instead" >&2
    echo "       (e.g. 20260824.1) — that re-syncs sooner than picking a new date." >&2
    echo "       Override deliberately with: ALLOW_FUTURE_BUILD=1 $0 ${BUILD_NUMBER}" >&2
    [ "${ALLOW_FUTURE_BUILD:-0}" = "1" ] || exit 1
    echo "       (ALLOW_FUTURE_BUILD=1 set — continuing anyway)" >&2
fi
echo "==> Build number: ${BUILD_NUMBER}"

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
