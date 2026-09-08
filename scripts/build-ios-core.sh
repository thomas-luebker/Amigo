#!/bin/bash
# Cross-compile the WinUAE core as a static library for iOS.
#   ./build-ios-core.sh [device|simulator]   (default: device)
# Output: build/ios/libuaecore.a  or  build/ios-sim/libuaecore.a
set -euo pipefail

# Xcode's script phases don't source the shell profile — make sure
# Homebrew's cmake is reachable when invoked from a GUI build.
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PLATFORM="${1:-device}"
if [[ $# -gt 0 ]]; then shift; fi

case "$PLATFORM" in
  device)
    BUILD="$ROOT/build/ios"
    SYSROOT=iphoneos
    ARCHS=arm64
    SDL_FRAMEWORK="$ROOT/vendor/SDL3/SDL3.xcframework/ios-arm64/SDL3.framework"
    FLAC_LIB="$ROOT/vendor/FLAC/lib-ios/libFLAC.a"
    ;;
  simulator)
    BUILD="$ROOT/build/ios-sim"
    SYSROOT=iphonesimulator
    ARCHS="$(uname -m)"
    SDL_FRAMEWORK="$ROOT/vendor/SDL3/SDL3.xcframework/ios-arm64_x86_64-simulator/SDL3.framework"
    FLAC_LIB="$ROOT/vendor/FLAC/lib-ios-sim/libFLAC.a"
    ;;
  tvos)
    # Apple TV probe (feature/tvos). A static library needs SDL3's headers,
    # not its binary, and the headers are identical across Apple slices, so
    # the iOS device slice serves until an appletvos SDL3 exists. FLAC has
    # no tvOS build yet, and this tree makes CHD require FLAC, so the probe
    # builds without CHD; build-flac-ios.sh needs an appletvos variant first.
    BUILD="$ROOT/build/tvos"
    SYSROOT=appletvos
    ARCHS=arm64
    SYSTEM_NAME=tvOS
    SDL_FRAMEWORK="$ROOT/vendor/SDL3/SDL3.xcframework/ios-arm64/SDL3.framework"
    FLAC_LIB=""
    EXTRA=(-DWINUAE_UNIX_WITH_CHD=OFF -DWINUAE_UNIX_WITH_CHD_FLAC=OFF)
    ;;
  *)
    echo "usage: $0 [device|simulator|tvos]" >&2; exit 1 ;;
esac
SYSTEM_NAME="${SYSTEM_NAME:-iOS}"
EXTRA=("${EXTRA[@]-}")

# The upstream SDL3 fallback discovery wants a directory containing SDL3/SDL.h;
# frameworks keep headers in SDL3.framework/Headers, so shim it with a symlink.
SHIM="$BUILD/sdl3-include"
mkdir -p "$SHIM"
ln -sfn "$SDL_FRAMEWORK/Headers" "$SHIM/SDL3"

cmake -S "$ROOT/core-ios" -B "$BUILD" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_CXX_FLAGS_RELEASE="-O3 -DNDEBUG" \
  -DCMAKE_C_FLAGS_RELEASE="-O3 -DNDEBUG" \
  -DCMAKE_SYSTEM_NAME="$SYSTEM_NAME" \
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
  -DWINUAE_UNIX_WITH_CHD=ON \
  -DWINUAE_UNIX_WITH_CHD_FLAC=ON \
  -DWINUAE_UNIX_FLAC_INCLUDE_DIR="$ROOT/vendor/FLAC/include" \
  -DWINUAE_UNIX_FLAC_STATIC_LIB="$FLAC_LIB" \
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
  ${EXTRA[@]:+"${EXTRA[@]}"} \
  "$@"

cmake --build "$BUILD" --target uaecore -j "$(sysctl -n hw.ncpu)"
ls -la "$BUILD"/libuaecore.a
