#!/bin/bash
# Build static libFLAC for iOS (device + simulator) and vendor it into
# vendor/FLAC/ for the CHD codecs (WINUAE_UNIX_WITH_CHD_FLAC).
#   ./build-flac-ios.sh <path-to-flac-source-tree>
# Source: https://github.com/xiph/flac (release tarball, e.g. 1.5.0).
# FLAC's library is BSD-licensed — credited in AboutPanel/LICENSING.md.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="${1:?usage: $0 <flac-source-dir>}"
OUT="$ROOT/build/flac"

common=(
  -DCMAKE_BUILD_TYPE=Release
  -DCMAKE_SYSTEM_NAME=iOS
  -DCMAKE_OSX_DEPLOYMENT_TARGET=17.0
  -DBUILD_SHARED_LIBS=OFF
  -DBUILD_CXXLIBS=OFF
  -DBUILD_PROGRAMS=OFF
  -DBUILD_EXAMPLES=OFF
  -DBUILD_DOCS=OFF
  -DBUILD_TESTING=OFF
  -DINSTALL_MANPAGES=OFF
  -DWITH_OGG=OFF
  -DWITH_STACK_PROTECTOR=OFF
)

build() {
  local name="$1" sysroot="$2" archs="$3"
  cmake -S "$SRC" -B "$OUT/$name" \
    -DCMAKE_OSX_SYSROOT="$sysroot" \
    -DCMAKE_OSX_ARCHITECTURES="$archs" \
    "${common[@]}" >/dev/null
  cmake --build "$OUT/$name" --target FLAC -j >/dev/null
}

echo "==> Building libFLAC (device)"
build device iphoneos arm64
echo "==> Building libFLAC (simulator)"
build sim iphonesimulator "$(uname -m)"

DEV_LIB=$(find "$OUT/device" -name "libFLAC.a" | head -1)
SIM_LIB=$(find "$OUT/sim" -name "libFLAC.a" | head -1)
[ -f "$DEV_LIB" ] && [ -f "$SIM_LIB" ] || { echo "libFLAC.a not found — aborting"; exit 1; }

DEST="$ROOT/vendor/FLAC"
rm -rf "$DEST"
mkdir -p "$DEST/lib-ios" "$DEST/lib-ios-sim"
cp "$DEV_LIB" "$DEST/lib-ios/libFLAC.a"
cp "$SIM_LIB" "$DEST/lib-ios-sim/libFLAC.a"
cp -R "$SRC/include/FLAC" "$DEST/include-staging"
mkdir -p "$DEST/include"
mv "$DEST/include-staging" "$DEST/include/FLAC"
cp "$SRC/COPYING.Xiph" "$DEST/" 2>/dev/null || true

echo "==> Vendored:"
lipo -info "$DEST/lib-ios/libFLAC.a"
lipo -info "$DEST/lib-ios-sim/libFLAC.a"
