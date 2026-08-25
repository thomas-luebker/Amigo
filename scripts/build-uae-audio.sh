#!/bin/bash
# Assemble vendor/WinUAE/uaesnd_ahi.s into `uae.audio`, the AHI driver for
# the UAESND sound board Amigo puts on the guest's Zorro II bus.
#
# This is a TEST INSTRUMENT, not something the app ships. It exists so the
# UAESND board can be proven end-to-end on a real AmigaOS with AHI, and so
# the "should we ship the driver?" question can be decided against a real
# binary rather than a guess. Output: build/amiga/uae.audio.
#
# Three things the recipe needs that are not obvious:
#
#  1. bebbo's amiga-gcc ships vasm and the NDK, but its exec/exec_lib.i is a
#     FUNCDEF table the application is expected to parse itself, while
#     uaesnd_ahi.s wants plain _LVO equates. ndk-include/lvo/exec_lib.i is
#     the same table pre-expanded, so a one-line shim redirects to it.
#
#  2. The AHI includes must come from AHI's BRANCH_6, not from the public
#     ahidev_4.18.lha on Aminet. 4.18's Asm side is still ahi_sub.i 4.1 from
#     1997 and predates both AHIST_L7_1 ($00c3000a) and
#     AHISF_KNOWMULTICHANNEL (bit 7), which this driver uses. There is no
#     released AHI SDK that can build it — that is a real obstacle to
#     shipping the driver, not a detail.
#
#  3. -opt-allbra: one `beq.s` at uaesnd_ahi.s:1145 is out of short range,
#     so the assembler has to widen it. -m68020 because of `mulu.l`.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VASM="$HOME/opt/amiga/bin/vasmm68k_mot"
NDK="$HOME/opt/amiga/m68k-amigaos/ndk-include"
OUT="$ROOT/build/amiga"
WORK="$OUT/work"

[ -x "$VASM" ] || { echo "ERROR: vasm not found at $VASM (see the amiga-68k skill)" >&2; exit 1; }
[ -d "$NDK" ] || { echo "ERROR: NDK includes not found at $NDK" >&2; exit 1; }

mkdir -p "$WORK/shim/exec" "$WORK/ahi/devices" "$WORK/ahi/libraries" "$OUT"

cat > "$WORK/shim/exec/exec_lib.i" <<'EOF'
	IFND	EXEC_LIB_I
EXEC_LIB_I	SET	1
	include	lvo/exec_lib.i
	ENDC
EOF

AHI_RAW="https://raw.githubusercontent.com/mheyer32/AHI/BRANCH_6/Include/Asm"
for f in devices/ahi.i libraries/ahi_sub.i; do
    if [ ! -s "$WORK/ahi/$f" ]; then
        echo "==> fetching AHI BRANCH_6 $f"
        curl -sSLf -o "$WORK/ahi/$f" "$AHI_RAW/$f"
    fi
done

echo "==> assembling uae.audio"
"$VASM" -Fhunkexe -m68020 -opt-allbra \
    -I "$WORK/shim" -I "$WORK/ahi" -I "$NDK" \
    -o "$OUT/uae.audio" "$ROOT/vendor/WinUAE/uaesnd_ahi.s"

echo "==> $OUT/uae.audio"
