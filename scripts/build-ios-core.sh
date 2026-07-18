#!/bin/bash
# Cross-compile the WinUAE core as a static library for iOS.
#   ./build-ios-core.sh [device|simulator]   (default: device)
# Output: build/ios/libuaecore.a  or  build/ios-sim/libuaecore.a
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PLATFORM="${1:-device}"
if [[ $# -gt 0 ]]; then shift; fi

case "$PLATFORM" in
  device)
    BUILD="$ROOT/build/ios"
    SYSROOT=iphoneos
    ARCHS=arm64
    SDL_FRAMEWORK="$ROOT/vendor/SDL3/SDL3.xcframework/ios-arm64/SDL3.framework"
    ;;
  simulator)
    BUILD="$ROOT/build/ios-sim"
    SYSROOT=iphonesimulator
    ARCHS="$(uname -m)"
    SDL_FRAMEWORK="$ROOT/vendor/SDL3/SDL3.xcframework/ios-arm64_x86_64-simulator/SDL3.framework"
    ;;
  *)
    echo "usage: $0 [device|simulator]" >&2; exit 1 ;;
esac

# The upstream SDL3 fallback discovery wants a directory containing SDL3/SDL.h;
# frameworks keep headers in SDL3.framework/Headers, so shim it with a symlink.
SHIM="$BUILD/sdl3-include"
mkdir -p "$SHIM"
ln -sfn "$SDL_FRAMEWORK/Headers" "$SHIM/SDL3"

cmake -S "$ROOT/core-ios" -B "$BUILD" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_CXX_FLAGS_RELEASE="-O3 -DNDEBUG" \
  -DCMAKE_C_FLAGS_RELEASE="-O3 -DNDEBUG" \
  -DCMAKE_SYSTEM_NAME=iOS \
  -DCMAKE_OSX_SYSROOT="$SYSROOT" \
  -DCMAKE_OSX_ARCHITECTURES="$ARCHS" \
  -DCMAKE_OSX_DEPLOYMENT_TARGET=17.0 \
  -DBUILD_TESTING=OFF \
  -DWINUAE_UNIX_SDL3_INCLUDE_DIR="$SHIM" \
  -DWINUAE_UNIX_SDL3_FALLBACK_LIBRARY="$SDL_FRAMEWORK/SDL3" \
  -DWINUAE_UNIX_BUILD_EXECUTABLE=OFF \
  -DWINUAE_UNIX_WITH_JIT=OFF \
  -DWINUAE_UNIX_WITH_QT_UI=OFF \
  -DWINUAE_UNIX_WITH_INTEGRATED_QT_UI=OFF \
  -DWINUAE_UNIX_WITH_CHD=OFF \
  -DWINUAE_UNIX_WITH_CHD_FLAC=OFF \
  -DWINUAE_UNIX_WITH_LIBMPEG2=OFF \
  -DWINUAE_UNIX_WITH_LIBPNG=OFF \
  -DWINUAE_UNIX_WITH_UAENET_PCAP=OFF \
  -DWINUAE_UNIX_WITH_SANA2=OFF \
  -DWINUAE_UNIX_WITH_NATIVE_HARDDRIVES=OFF \
  -DWINUAE_UNIX_WITH_NATIVE_CD=OFF \
  -DWINUAE_UNIX_WITH_NATIVE_SCSI=OFF \
  -DWINUAE_UNIX_WITH_UAESCSI=OFF \
  -DWINUAE_UNIX_WITH_UAESERIAL=OFF \
  -DWINUAE_UNIX_WITH_MIDI=OFF \
  -DWINUAE_UNIX_WITH_MIDIEMU=OFF \
  -DWINUAE_UNIX_WITH_SAMPLER=OFF \
  -DWINUAE_UNIX_WITH_AVIOUTPUT=OFF \
  -DWINUAE_UNIX_WITH_OPENGL_SHADER_PIPELINE=OFF \
  -DWINUAE_UNIX_WITH_PPC_QEMU=OFF \
  -DWINUAE_UNIX_BUILD_QEMU_UAE_PLUGIN=OFF \
  "$@"

cmake --build "$BUILD" --target uaecore -j "$(sysctl -n hw.ncpu)"
ls -la "$BUILD"/libuaecore.a
