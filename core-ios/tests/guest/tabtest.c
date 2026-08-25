/* TabTest — probe the guest's tablet.library from inside the Amiga.
 *
 * The other half of the pressure story. SerTest checks the serial Wacom,
 * which is what TVPaint drives itself; this checks tablet.library, which
 * is what Deluxe Paint opens (upstream's own changelog: "Deluxe Paint
 * requires it for pressure support"). The library comes from the UAE boot
 * ROM — vendor/WinUAE/tabletlibrary.cpp — and core-ios/ios_glue.cpp feeds
 * it from the Pencil.
 *
 * The library's vectors, in the order tabletlib_install() lays them out:
 *
 *   -30  AllocTablet(taglist)      -> TabletData *
 *   -36  FreeTablet(td)
 *   -42  DoTablet(inputevent, td)  -> refreshes td from the current pen
 *
 * struct TabletData: +4 x, +8 y, +12 range x, +16 range y, +20 taglist.
 * Pressure arrives as tag TABLETA_Pressure (0x8003A006), a signed 32-bit
 * value where full scale is 0x7FFF8000 — see the scaling note in
 * core-ios/ios_glue.cpp.
 *
 * Build: see scripts/build-guest-tests.sh
 */

#include <exec/types.h>
#include <exec/libraries.h>
#include <dos/dos.h>

#include <proto/exec.h>
#include <proto/dos.h>

#include <stdio.h>

#define TABLETA_Dummy       (0x80000000 + 0x3A000)
#define TABLETA_Pressure    (TABLETA_Dummy + 0x06)
#define TABLETA_InProximity (TABLETA_Dummy + 0x08)
#define TAG_DONE            0L

static struct Library *TabletBase;

static APTR AllocTabletA(APTR tags)
{
    register struct Library *a6 __asm("a6") = TabletBase;
    register APTR a0 __asm("a0") = tags;
    register APTR res __asm("d0");
    __asm volatile ("jsr -30(%%a6)"
                    : "=r"(res)
                    : "r"(a6), "r"(a0)
                    : "d1", "a1", "cc", "memory");
    return res;
}

static void FreeTabletA(APTR td)
{
    register struct Library *a6 __asm("a6") = TabletBase;
    register APTR a0 __asm("a0") = td;
    __asm volatile ("jsr -36(%%a6)"
                    :
                    : "r"(a6), "r"(a0)
                    : "d0", "d1", "a1", "cc", "memory");
}

static LONG DoTabletA(APTR ie, APTR td)
{
    register struct Library *a6 __asm("a6") = TabletBase;
    register APTR a0 __asm("a0") = ie;
    register APTR a1 __asm("a1") = td;
    register LONG res __asm("d0");
    __asm volatile ("jsr -42(%%a6)"
                    : "=r"(res)
                    : "r"(a6), "r"(a0), "r"(a1)
                    : "d1", "cc", "memory");
    return res;
}

/* Walk the TagItem array for one tag. */
static LONG find_tag(ULONG *tags, ULONG want, LONG *out)
{
    if (!tags) {
        return 0;
    }
    while (*tags) {
        if (*tags == want) {
            *out = (LONG)tags[1];
            return 1;
        }
        tags += 2;
    }
    return 0;
}

int main(int argc, char **argv)
{
    /* Sample count on the command line: a human needs time to pick up the
     * Pencil, and the default 20 samples are gone in four seconds. */
    int samples = 20;
    ULONG taglist[6];
    UBYTE fake_event[64];
    APTR td;
    int i;
    int seen_pressure = 0;

    if (argc > 1) {
        int n = 0;
        const char *a = argv[1];
        while (*a >= '0' && *a <= '9') {
            n = n * 10 + (*a++ - '0');
        }
        if (n > 0) {
            samples = n;
        }
    }

    TabletBase = OpenLibrary((CONST_STRPTR)"tablet.library", 0);
    if (!TabletBase) {
        printf("TabTest: no tablet.library — is Pencil Pressure on, and did\n");
        printf("TabTest: the machine reset since it was turned on?\n");
        return RETURN_WARN;
    }
    printf("TabTest: tablet.library v%d.%d open\n",
           (int)TabletBase->lib_Version, (int)TabletBase->lib_Revision);

    /* Ask for pressure and proximity. AllocTablet keeps only the tags it
     * knows and turns the rest into TAG_IGNORE. */
    taglist[0] = TABLETA_Pressure;
    taglist[1] = 0;
    taglist[2] = TABLETA_InProximity;
    taglist[3] = 0;
    taglist[4] = TAG_DONE;
    taglist[5] = 0;

    td = AllocTabletA(taglist);
    if (!td) {
        printf("TabTest: AllocTablet failed\n");
        CloseLibrary(TabletBase);
        return RETURN_FAIL;
    }

    for (i = 0; i < 64; i++) {
        fake_event[i] = 0;
    }

    printf("TabTest: sampling — hover or draw with the Pencil\n");
    for (i = 0; i < samples; i++) {
        LONG x, y, rx, ry, pressure = 0;
        ULONG *tags;

        /* Refresh from the current pen state. */
        DoTabletA(fake_event, td);

        x  = *(LONG *)((UBYTE *)td + 4);
        y  = *(LONG *)((UBYTE *)td + 8);
        rx = *(LONG *)((UBYTE *)td + 12);
        ry = *(LONG *)((UBYTE *)td + 16);
        tags = *(ULONG **)((UBYTE *)td + 20);

        if (find_tag(tags, TABLETA_Pressure, &pressure) && pressure != 0) {
            seen_pressure = 1;
        }
        /* Report pressure as a percentage of full scale as well as raw:
         * the raw number is meaningless without knowing the convention,
         * and the percentage is what tells you the scaling is right. */
        printf("[%2d] x=%5d/%5d y=%5d/%5d pressure=%11d (%3d%%)\n",
               i, (int)x, (int)rx, (int)y, (int)ry,
               (int)pressure, (int)((pressure >> 16) * 100 / 0x7FFF));
        Delay(10);      /* 1/5 s */
    }

    printf("TabTest: %s\n", seen_pressure
           ? "pressure reached the Amiga side"
           : "no pressure seen — the pen never touched down");

    FreeTabletA(td);
    CloseLibrary(TabletBase);
    return seen_pressure ? RETURN_OK : RETURN_WARN;
}
