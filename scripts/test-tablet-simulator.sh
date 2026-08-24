#!/bin/bash
# End-to-end test of the virtual Wacom tablet in the iOS Simulator.
#
# scripts/test-wacom-serial.sh proves the device speaks Protocol IV.
# This proves the other half: that the bytes cross the emulated UART and
# reach an Amiga program through serial.device. It boots a tiny bootable
# HDF whose Startup-Sequence runs SerTest (core-ios/tests/guest), with
# AMIGO_TABLET_SELFTEST=1 so the tablet moves its own pen — no Pencil and
# no human needed.
#
#   scripts/test-tablet-simulator.sh <simulator-udid> [kickstart.rom]
#
# Leaves a screenshot in build/tests/. Read the Amiga console in it: the
# model and coordinate replies mean the device answered, and streaming
# packet lines mean the whole path works.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
UDID="${1:?simulator UDID required — xcrun simctl list devices}"
ROM="${2:-$HOME/Desktop/build/kicka1200.rom}"
BUNDLE=de.amiga-imager.uae
OUT="$ROOT/build/tests"

[ -f "$ROM" ] || { echo "no Kickstart at $ROM" >&2; exit 1; }
[ -f "$OUT/SerTest.hdf" ] || { echo "run scripts/build-guest-tests.sh first" >&2; exit 1; }

echo "==> Booting simulator"
xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b >/dev/null 2>&1 || true

echo "==> Installing"
xcrun simctl install "$UDID" "$OUT/Amigo.app"

# First launch creates the Documents folders; kill it again before seeding.
xcrun simctl launch "$UDID" "$BUNDLE" >/dev/null
sleep 5
xcrun simctl terminate "$UDID" "$BUNDLE" >/dev/null 2>&1 || true

DOCS="$(xcrun simctl get_app_container "$UDID" "$BUNDLE" data)/Documents"
echo "==> Seeding $DOCS"
mkdir -p "$DOCS/Configuration" "$DOCS/Kickstarts" "$DOCS/HardDrives"
cp "$ROM" "$DOCS/Kickstarts/kick.rom"
cp -c "$OUT/SerTest.hdf" "$DOCS/HardDrives/SerTest.hdf" 2>/dev/null ||
    cp "$OUT/SerTest.hdf" "$DOCS/HardDrives/SerTest.hdf"

cat > "$DOCS/Configuration/default.uae" <<EOF
config_description=Wacom serial tablet end-to-end test
kickstart_rom_file=$DOCS/Kickstarts/kick.rom
chipset=aga
chipset_compatible=A1200
cpu_type=68ec020
cpu_model=68020
chipmem_size=4
fastmem_size=8
cpu_speed=max
sound_output=none
gfx_width=720
gfx_height=568
gfx_linemode=double
show_leds=true
joyport0=mouse
unix.serial_port=WACOM_TABLET
tablet_library=true
hardfile2=rw,DH0:$DOCS/HardDrives/SerTest.hdf,0,0,0,512,0,,uae0
EOF

echo "==> Launching with the self-test sweep"
SIMCTL_CHILD_AMIGO_TABLET_SELFTEST=1 xcrun simctl launch "$UDID" "$BUNDLE" >/dev/null

echo "==> Waiting for the guest to boot and run SerTest"
sleep 40
xcrun simctl io "$UDID" screenshot "$OUT/tablet-test.png"
echo "==> Screenshot: $OUT/tablet-test.png"
echo "    Emulator log: $DOCS/amigo-log.txt"
grep -i "wacom\|SERIAL" "$DOCS/amigo-log.txt" | tail -20 || true
