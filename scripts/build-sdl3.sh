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
  -DSDL_SHARED=ON -DSDL_STATIC=OFF
  -DSDL_FRAMEWORK=ON
  -DSDL_TEST_LIBRARY=OFF -DSDL_EXAMPLES=OFF -DSDL_TESTS=OFF
  # RelWithDebInfo keeps the -g debug info so a real dSYM can be produced
  # (a plain Release build strips it → empty dSYM → upload-symbols warning).
  -DCMAKE_BUILD_TYPE=RelWithDebInfo
  -DCMAKE_OSX_DEPLOYMENT_TARGET=17.0
)

build() {
  local name="$1" sysroot="$2" archs="$3"
  cmake -S "$SRC" -B "$OUT/$name" -GXcode \
    -DCMAKE_SYSTEM_NAME=iOS \
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

# Locate the dSYM (unambiguous), then derive the real framework as its
# sibling — avoids matching the EagerLinkingTBDs stub framework.
DEV_DSYM=$(find "$OUT/device" -name "SDL3.framework.dSYM" -type d | head -1)
SIM_DSYM=$(find "$OUT/sim" -name "SDL3.framework.dSYM" -type d | head -1)
DEV_FW="${DEV_DSYM%.dSYM}"
SIM_FW="${SIM_DSYM%.dSYM}"
echo "device: $DEV_FW  dSYM: $DEV_DSYM"
echo "sim:    $SIM_FW  dSYM: $SIM_DSYM"
[ -d "$DEV_FW" ] && [ -d "$SIM_FW" ] || { echo "framework(s) not found — aborting"; exit 1; }
[ -d "$DEV_DSYM" ] && [ -d "$SIM_DSYM" ] || { echo "dSYM(s) not found — aborting"; exit 1; }

# dSYMs now hold the debug info; strip it from the shipped binaries so the
# framework stays small (UUID is preserved, so the dSYM still matches).
strip -x "$DEV_FW/SDL3" "$SIM_FW/SDL3"

# Build into a temp path first; only replace vendor/ once it succeeds.
# -debug-symbols bundles the dSYMs into the xcframework so the app archive
# carries them (no "Upload Symbols Failed" warning).
TMP_XC="$OUT/SDL3.xcframework"
rm -rf "$TMP_XC"
xcodebuild -create-xcframework \
  -framework "$DEV_FW" -debug-symbols "$DEV_DSYM" \
  -framework "$SIM_FW" -debug-symbols "$SIM_DSYM" \
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

echo "==> vendor/SDL3/SDL3.xcframework rebuilt (SDL_CAMERA=OFF, versioned)"
