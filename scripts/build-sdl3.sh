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
  -DCMAKE_BUILD_TYPE=Release
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
  xcodebuild -project "$OUT/$name/SDL3.xcodeproj" -target SDL3-shared \
    -configuration Release -sdk "$sysroot" CODE_SIGNING_ALLOWED=NO -quiet
}

echo "==> Building SDL3 (device, camera off)"
build device iphoneos arm64
echo "==> Building SDL3 (simulator, camera off)"
build sim iphonesimulator "arm64;x86_64"

DEV_FW=$(find "$OUT/device" -name SDL3.framework -type d | head -1)
SIM_FW=$(find "$OUT/sim" -name SDL3.framework -type d | head -1)
echo "device: $DEV_FW"
echo "sim:    $SIM_FW"
[ -d "$DEV_FW" ] && [ -d "$SIM_FW" ] || { echo "framework(s) not found — aborting"; exit 1; }

# Build into a temp path first; only replace vendor/ once it succeeds.
TMP_XC="$OUT/SDL3.xcframework"
rm -rf "$TMP_XC"
xcodebuild -create-xcframework \
  -framework "$DEV_FW" \
  -framework "$SIM_FW" \
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
