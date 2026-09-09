#!/bin/bash
# Rebuild SDL3 from source as an xcframework with camera support disabled
# (SDL_CAMERA=OFF) so the binary no longer references AVCaptureDevice — no
# camera purpose string needed. Produces vendor/SDL3/SDL3.xcframework.
#
# Usage: scripts/build-sdl3.sh /path/to/SDL-source
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="${1:?path to SDL source checkout required}"
OUT="$ROOT/build/sdl3"
rm -rf "$OUT"; mkdir -p "$OUT"

common=(
  -DSDL_CAMERA=OFF
  # Disabling HIDAPI drops the CoreBluetooth dependency entirely (SDL's own
  # header docs recommend this for iOS/tvOS). We have no BLE/HIDAPI
  # controllers to support, but the linked framework alone is enough for
  # iOS to treat the app as touching Bluetooth on first launch — on a
  # device where the app has never been installed before (unlike any of
  # our own test devices, whose permission decision persists across
  # reinstalls) that can surface as a permission prompt blocking first
  # render, which is indistinguishable from "hung" to anyone not there to
  # answer it. Matches an App Review report of exactly that on a fresh
  # device. MFi/GameController-based controllers (our supported input
  # path) are untouched by this — they don't go through HIDAPI.
  -DSDL_HIDAPI=OFF
  -DSDL_SHARED=ON -DSDL_STATIC=OFF
  -DSDL_FRAMEWORK=ON
  -DSDL_TEST_LIBRARY=OFF -DSDL_EXAMPLES=OFF -DSDL_TESTS=OFF
  # RelWithDebInfo keeps the -g debug info so a real dSYM can be produced
  # (a plain Release build strips it → empty dSYM → upload-symbols warning).
  -DCMAKE_BUILD_TYPE=RelWithDebInfo
  -DCMAKE_OSX_DEPLOYMENT_TARGET=17.0
)

build() {
  local name="$1" sysroot="$2" archs="$3" sysname="${4:-iOS}"
  cmake -S "$SRC" -B "$OUT/$name" -GXcode \
    -DCMAKE_SYSTEM_NAME="$sysname" \
    -DCMAKE_OSX_SYSROOT="$sysroot" \
    -DCMAKE_OSX_ARCHITECTURES="$archs" \
    "${common[@]}" >/dev/null
  # CODE_SIGNING_ALLOWED=NO: the Xcode generator's framework code-sign step
  # fails without a signing identity; the xcframework is signed later anyway.
  # dwarf-with-dsym: produce SDL3.framework.dSYM so App Store upload has
  # symbols (avoids the "Upload Symbols Failed" warning).
  xcodebuild -project "$OUT/$name/SDL3.xcodeproj" -target SDL3-shared \
    -configuration RelWithDebInfo -sdk "$sysroot" CODE_SIGNING_ALLOWED=NO \
    DEBUG_INFORMATION_FORMAT=dwarf-with-dsym \
    DEPLOYMENT_POSTPROCESSING=NO STRIP_INSTALLED_PRODUCT=NO COPY_PHASE_STRIP=NO \
    -quiet
}

echo "==> Building SDL3 (device, camera off)"
build device iphoneos arm64
echo "==> Building SDL3 (simulator, camera off)"
build sim iphonesimulator "arm64;x86_64"
# Apple TV slice (feature/tvos). Same source, same patch; SDL3's UIKit
# backend carries its own tvOS conditionals, so nothing else changes.
echo "==> Building SDL3 (tvOS device, camera off)"
build tvos appletvos arm64 tvOS
echo "==> Building SDL3 (tvOS simulator, camera off)"
build tvsim appletvsimulator arm64 tvOS

# Locate the dSYM (unambiguous), then derive the real framework as its
# sibling — avoids matching the EagerLinkingTBDs stub framework.
DEV_DSYM=$(find "$OUT/device" -name "SDL3.framework.dSYM" -type d | head -1)
SIM_DSYM=$(find "$OUT/sim" -name "SDL3.framework.dSYM" -type d | head -1)
TV_DSYM=$(find "$OUT/tvos" -name "SDL3.framework.dSYM" -type d | head -1)
TVSIM_DSYM=$(find "$OUT/tvsim" -name "SDL3.framework.dSYM" -type d | head -1)
DEV_FW="${DEV_DSYM%.dSYM}"
SIM_FW="${SIM_DSYM%.dSYM}"
TV_FW="${TV_DSYM%.dSYM}"
TVSIM_FW="${TVSIM_DSYM%.dSYM}"
echo "device: $DEV_FW  dSYM: $DEV_DSYM"
echo "sim:    $SIM_FW  dSYM: $SIM_DSYM"
echo "tvos:   $TV_FW  dSYM: $TV_DSYM"
echo "tvsim:  $TVSIM_FW  dSYM: $TVSIM_DSYM"
[ -d "$DEV_FW" ] && [ -d "$SIM_FW" ] && [ -d "$TV_FW" ] && [ -d "$TVSIM_FW" ] || { echo "framework(s) not found — aborting"; exit 1; }
[ -d "$DEV_DSYM" ] && [ -d "$SIM_DSYM" ] && [ -d "$TV_DSYM" ] && [ -d "$TVSIM_DSYM" ] || { echo "dSYM(s) not found — aborting"; exit 1; }

# dSYMs now hold the debug info; strip it from the shipped binaries so the
# framework stays small (UUID is preserved, so the dSYM still matches).
strip -x "$DEV_FW/SDL3" "$SIM_FW/SDL3" "$TV_FW/SDL3" "$TVSIM_FW/SDL3"

# Build into a temp path first; only replace vendor/ once it succeeds.
# -debug-symbols bundles the dSYMs into the xcframework so the app archive
# carries them (no "Upload Symbols Failed" warning).
TMP_XC="$OUT/SDL3.xcframework"
rm -rf "$TMP_XC"
xcodebuild -create-xcframework \
  -framework "$DEV_FW" -debug-symbols "$DEV_DSYM" \
  -framework "$SIM_FW" -debug-symbols "$SIM_DSYM" \
  -framework "$TV_FW" -debug-symbols "$TV_DSYM" \
  -framework "$TVSIM_FW" -debug-symbols "$TVSIM_DSYM" \
  -output "$TMP_XC"

# The CMake SDL_FRAMEWORK build omits CFBundleVersion / CFBundle
# ShortVersionString, which App Store upload requires (ITMS 90056/90057).
for slice_fw in "$TMP_XC"/*/SDL3.framework; do
  [ -d "$slice_fw" ] || continue
  pl="$slice_fw/Info.plist"
  /usr/libexec/PlistBuddy -c "Add :CFBundleShortVersionString string 3.4.12" "$pl" 2>/dev/null \
    || /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString 3.4.12" "$pl"
  /usr/libexec/PlistBuddy -c "Add :CFBundleVersion string 3.4.12" "$pl" 2>/dev/null \
    || /usr/libexec/PlistBuddy -c "Set :CFBundleVersion 3.4.12" "$pl"
done

rm -rf "$ROOT/vendor/SDL3/SDL3.xcframework"
cp -R "$TMP_XC" "$ROOT/vendor/SDL3/SDL3.xcframework"

echo "==> vendor/SDL3/SDL3.xcframework rebuilt (SDL_CAMERA=OFF, versioned, ios + sim + tvos + tvos-sim slices)"
