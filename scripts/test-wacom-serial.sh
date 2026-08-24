#!/bin/bash
# Protocol test for the virtual Wacom tablet (core-ios/wacom_serial.cpp).
#
# Runs on the Mac, no emulator and no Amiga: the device is compiled against
# stub headers, driven through the Protocol IV handshake, and its packets
# are decoded back and checked. That covers everything except the one thing
# only TVPaint can answer — whether it is the protocol TVPaint wants.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/build/tests"
mkdir -p "$OUT"
clang++ -std=c++17 -Wall \
    -I"$ROOT/core-ios/tests/stub" \
    -o "$OUT/wacom_serial_test" \
    "$ROOT/core-ios/tests/wacom_serial_test.cpp"
"$OUT/wacom_serial_test"
