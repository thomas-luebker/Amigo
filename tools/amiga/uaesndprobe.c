/* uaesndprobe — does the UAESND sound board exist on the guest's bus?
 *
 * Run this INSIDE the emulated Amiga (amiagent makes that a one-liner) to
 * settle the question the host log can only hint at. It does exactly what
 * uae.audio does when AHI opens it — FindConfigDev(NULL, 6502, 2), see
 * vendor/WinUAE/uaesnd_ahi.s:1242 — and then reads the board's own
 * identification registers, which live at board base + $80 (the UAESNDHW
 * structure in that same file).
 *
 * ABSENT means the config has no uaesnd_z2_rom_file=:ENABLED line, which is
 * the bug Oli Förster reported on 2026-08-25: AHI's uae.audio driver had no
 * device to open.
 *
 * Build (see the amiga-68k skill for the toolchain):
 *   ~/opt/amiga/bin/m68k-amigaos-gcc -Os -fomit-frame-pointer -m68000 \
 *       -o uaesndprobe tools/amiga/uaesndprobe.c -s -lgcc
 */
#include <proto/exec.h>
#include <proto/dos.h>
#include <proto/expansion.h>
#include <libraries/configvars.h>

int main(void)
{
    struct Library *ExpansionBase;
    struct ConfigDev *cd;
    volatile UBYTE *base;

    ExpansionBase = OpenLibrary("expansion.library", 0);
    if (!ExpansionBase) {
        Printf("FAIL: no expansion.library\n");
        return 20;
    }

    cd = (struct ConfigDev *)FindConfigDev(NULL, 6502, 2);
    if (!cd) {
        Printf("ABSENT: no board with manufacturer 6502 product 2\n");
        CloseLibrary(ExpansionBase);
        return 5;
    }

    base = (volatile UBYTE *)cd->cd_BoardAddr;
    Printf("PRESENT: UAESND at 0x%08lx, %ld bytes\n",
           (ULONG)base, (LONG)cd->cd_BoardSize);
    Printf("  uae_version = 0x%08lx\n", *(volatile ULONG *)(base + 0x80));
    Printf("  snd version = %ld.%ld\n",
           (LONG)*(volatile UWORD *)(base + 0x84),
           (LONG)*(volatile UWORD *)(base + 0x86));
    Printf("  frequency   = %ld\n", *(volatile ULONG *)(base + 0x88));
    Printf("  max channels= %ld, max streams = %ld\n",
           (LONG)*(volatile UBYTE *)(base + 0x8c),
           (LONG)*(volatile UBYTE *)(base + 0x8e));

    CloseLibrary(ExpansionBase);
    return 0;
}
