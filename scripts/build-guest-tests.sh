#!/bin/bash
# Build the Amiga-side test programs and the bootable disk that runs them.
#
# Output: build/tests/SerTest.hdf — an 8 MB RDB image whose Startup-Sequence
# runs SerTest, so booting it is the whole test. Mount it in Amigo (or point
# a config at it), enable Serial Tablet, and the guest reports what it sees
# on the serial port.
#
# Needs bebbo's amiga-gcc (see the amiga-68k skill) and AmigaDiskCLI (the
# amiga-disk skill). Neither is on PATH.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GCC="${AMIGA_GCC:-$HOME/opt/amiga/bin/m68k-amigaos-gcc}"
CLI="${AMIGA_DISK_CLI:-$HOME/Development/AmigaDiskKit/.build/arm64-apple-macosx/release/AmigaDiskCLI}"
OUT="$ROOT/build/tests"
SRC="$ROOT/core-ios/tests/guest"

[ -x "$GCC" ] || { echo "no 68k compiler at $GCC (amiga-68k skill)" >&2; exit 1; }
[ -x "$CLI" ] || { echo "no AmigaDiskCLI at $CLI (amiga-disk skill)" >&2; exit 1; }
mkdir -p "$OUT"

echo "==> Cross-compiling SerTest"
"$GCC" -noixemul -O2 -Wall -o "$SRC/SerTest" "$SRC/sertest.c"
"$GCC" -noixemul -O2 -Wall -o "$SRC/TabTest" "$SRC/tabtest.c"
file "$SRC/SerTest" "$SRC/TabTest"

echo "==> Building the bootable test disk"
rm -f "$OUT/SerTest.hdf"
# The boot flag is the fourth field and it is NOT the default: without it
# the RDB mounts, the volume is readable, and the machine still shows the
# insert-disk screen. Fields are name:dostype:cyls:boot — cyls empty keeps
# the default (the whole disk).
"$CLI" disk rdb-build "$OUT/SerTest.hdf" 8388608 --part "DH0:DOS3::1"
# Its own volume name: two volumes sharing one name and AmigaOS silently
# drops the duplicate, so a test disk mounted next to a system image must
# never be called Workbench or Work.
"$CLI" disk rdb-format "$OUT/SerTest.hdf" DH0 SerTestVol
"$CLI" disk fs mkdir "$OUT/SerTest.hdf" DH0 S
# TabTest first: it exits after 20 samples, SerTest streams until stopped.
# TabTest first with a generous sample count — on a device a human needs
# time to pick the Pencil up — then leave the shell at its prompt so
# SerTest can be run by hand when they are ready.
printf 'TabTest 150\nEcho "Now run SerTest to test the serial tablet"\n' > "$OUT/startup.txt"
"$CLI" disk fs copy "$OUT/SerTest.hdf" DH0 "$OUT/startup.txt" "S/Startup-Sequence"
"$CLI" disk fs copy "$OUT/SerTest.hdf" DH0 "$SRC/SerTest" "SerTest"
"$CLI" disk fs copy "$OUT/SerTest.hdf" DH0 "$SRC/TabTest" "TabTest"

# serial.device is NOT in the Kickstart ROM — it is a disk-based device in
# DEVS:, and a bare boot disk without it fails OpenDevice with a bald
# IOERR_OPENFAIL (-1). The exec device list on a stock 3.2 boot is nine
# devices and serial is not among them. Lift one out of a system image
# rather than committing Amiga OS files to this repo.
SYSIMG="${SYSTEM_IMAGE:-$HOME/Desktop/build/uae_3.2.3_rtg_8gb_180826.hdf}"
if [ -f "$SYSIMG" ]; then
    echo "==> Borrowing serial.device from $(basename "$SYSIMG")"
    "$CLI" disk fs extract "$SYSIMG" DH0 "Devs/serial.device" "$OUT/serial.device"
    "$CLI" disk fs mkdir "$OUT/SerTest.hdf" DH0 Devs
    "$CLI" disk fs copy "$OUT/SerTest.hdf" DH0 "$OUT/serial.device" "Devs/serial.device"
else
    echo "!! no system image at $SYSIMG — the test disk will have no serial.device" >&2
    echo "   set SYSTEM_IMAGE=/path/to/workbench.hdf" >&2
fi
"$CLI" disk fs dir "$OUT/SerTest.hdf" DH0 --recursive

echo
echo "==> $OUT/SerTest.hdf"
echo "    Simulator:  scripts/test-tablet-simulator.sh <udid>"
echo "    Device:     copy it into Amigo's HardDrives folder and mount it,"
echo "                then enable Serial Tablet and run SerTestVol:SerTest"
