/* SerTest — probe Amigo's virtual Wacom tablet from inside the Amiga.
 *
 * Runs in the guest, opens serial.device at 9600 baud, and does exactly
 * what a tablet driver does: ask the device what it is, ask for its
 * coordinate range, tell it to start, and decode what comes back.
 *
 * This is the half the Mac-side test cannot reach. scripts/test-wacom-serial.sh
 * proves the device encodes Protocol IV correctly; this proves the bytes
 * survive the emulated UART, arrive at the right rate, and look like a
 * tablet to Amiga software.
 *
 * Build (see scripts/build-guest-tests.sh):
 *   m68k-amigaos-gcc -noixemul -O2 -o SerTest sertest.c
 *
 * Usage in the guest, with Serial Tablet enabled in Amigo:
 *   SerTest            - handshake, then decode packets until Ctrl-C
 *   SerTest QUIET      - handshake only, one line of verdict
 */

#include <exec/types.h>
#include <exec/io.h>
#include <exec/memory.h>
#include <devices/serial.h>
#include <dos/dos.h>

#include <proto/exec.h>
#include <proto/dos.h>
#include <clib/alib_protos.h>   /* CreatePort/CreateExtIO live in amiga.lib */

#include <stdio.h>
#include <string.h>

/* Two requests on two ports. A queued read owns its IORequest until it
 * completes, so writing through the same one — as this test did at first —
 * scribbles over a request the device is still holding. The symptoms are
 * maddening and never the same twice: a truncated reply here, a stream
 * that stops there. Real drivers use one request per direction. */
static struct MsgPort *port, *wport;
static struct IOExtSer *req, *wreq;

static void cleanup(void)
{
    if (req) {
        if (req->IOSer.io_Device) {
            AbortIO((struct IORequest *)req);
            WaitIO((struct IORequest *)req);
            CloseDevice((struct IORequest *)req);
        }
        DeleteExtIO((struct IORequest *)req);
    }
    if (wreq) {
        DeleteExtIO((struct IORequest *)wreq);
    }
    if (wport) {
        DeletePort(wport);
    }
    if (port) {
        DeletePort(port);
    }
}

/* Read with a timeout.
 *
 * Queue an asynchronous CMD_READ and wait for it, rather than polling
 * SDCMD_QUERY and only then reading. SDCMD_QUERY reports what is already
 * in serial.device's own buffer, so it says "nothing here" both when the
 * line is idle and when the device is waiting for someone to ask — and a
 * reader that only reads when QUERY is non-zero can sit forever opposite
 * a device that is only filling on demand. A queued read is what a real
 * driver does and it cannot deadlock that way. */
static int read_timeout(UBYTE *buf, int want, int ticks)
{
    int got = 0;

    while (got < want) {
        int waited = 0;

        /* Ask for the whole packet in one request. One IO exchange per
         * byte is an enormous per-byte cost on the Amiga side, and at
         * ~120 packets a second the reader falls behind serial.device's
         * input buffer, overruns it and stops — which reads as "the
         * tablet went quiet" when it is the reader that could not keep
         * up. Real drivers read in blocks; so does this now. */
        req->IOSer.io_Command = CMD_READ;
        req->IOSer.io_Length = want - got;
        req->IOSer.io_Data = buf + got;
        SendIO((struct IORequest *)req);

        while (!CheckIO((struct IORequest *)req)) {
            if (waited++ >= ticks) {
                AbortIO((struct IORequest *)req);
                WaitIO((struct IORequest *)req);
                return got;
            }
            Delay(1);           /* 1/50s */
        }
        WaitIO((struct IORequest *)req);
        if (req->IOSer.io_Error) {
            /* An overrun is worth knowing about but not worth stopping
             * for: the next read starts clean. */
            return got;
        }
        got += req->IOSer.io_Actual;
    }
    return got;
}

static void send(const char *s)
{
    wreq->IOSer.io_Command = CMD_WRITE;
    wreq->IOSer.io_Length = strlen(s);
    wreq->IOSer.io_Data = (APTR)s;
    DoIO((struct IORequest *)wreq);
}

/* A CR-terminated reply, as the identification commands produce. */
static int read_line(char *out, int max, int ticks)
{
    int n = 0;
    while (n < max - 1) {
        UBYTE c;
        if (read_timeout(&c, 1, ticks) != 1) {
            break;
        }
        if (c == '\r' || c == '\n') {
            break;
        }
        out[n++] = (char)c;
    }
    out[n] = 0;
    return n;
}

int main(int argc, char **argv)
{
    const int quiet = (argc > 1 && !strcmp(argv[1], "QUIET"));
    char line[128];
    int failures = 0;

    port = CreatePort(NULL, 0);
    if (!port) {
        printf("SerTest: no message port\n");
        return RETURN_FAIL;
    }
    req = (struct IOExtSer *)CreateExtIO(port, sizeof(struct IOExtSer));
    if (!req) {
        printf("SerTest: no IO request\n");
        cleanup();
        return RETURN_FAIL;
    }
    /* SERF_SHARED so this can run alongside anything else holding the
     * port; the tablet does not care. Some serial.device versions refuse
     * a shared open outright, so fall back to an exclusive one and report
     * both codes — "cannot open" with no number tells you nothing. */
    req->io_SerFlags = SERF_SHARED | SERF_XDISABLED;
    LONG err = OpenDevice((CONST_STRPTR)"serial.device", 0, (struct IORequest *)req, 0);
    if (err) {
        printf("SerTest: shared open failed (err %d, io_Error %d), trying exclusive\n",
               (int)err, (int)req->IOSer.io_Error);
        req->io_SerFlags = SERF_XDISABLED;
        req->IOSer.io_Device = NULL;
        err = OpenDevice((CONST_STRPTR)"serial.device", 0, (struct IORequest *)req, 0);
    }
    if (err) {
        printf("SerTest: cannot open serial.device unit 0 (err %d, io_Error %d)\n",
               (int)err, (int)req->IOSer.io_Error);
        /* -1 is IOERR_OPENFAIL, which says nothing about why. List what
         * exec actually has, so "the device is missing" and "the device
         * refused us" stop looking alike. */
        {
            struct Node *n;
            int count = 0;
            printf("SerTest: exec device list:");
            Forbid();
            for (n = SysBase->DeviceList.lh_Head; n->ln_Succ; n = n->ln_Succ) {
                printf(" %s", n->ln_Name ? (char *)n->ln_Name : "?");
                count++;
            }
            Permit();
            printf("\nSerTest: %d devices\n", count);
        }
        cleanup();
        return RETURN_FAIL;
    }

    req->IOSer.io_Command = SDCMD_SETPARAMS;
    /* CreateExtIO zeroes the request, so io_RBufLen arrives as 0. Ask for
     * a real input buffer: a serial.device with no room to buffer cannot
     * absorb a continuous stream between reads. */
    req->io_RBufLen = 4096;
    req->io_Baud = 9600;
    req->io_ReadLen = 8;
    req->io_WriteLen = 8;
    req->io_StopBits = 1;
    req->io_SerFlags = SERF_SHARED | SERF_XDISABLED;
    if (DoIO((struct IORequest *)req)) {
        printf("SerTest: SDCMD_SETPARAMS failed (error %d)\n", req->IOSer.io_Error);
        cleanup();
        return RETURN_FAIL;
    }

    /* Second request for the write direction, sharing the open device. */
    wport = CreatePort(NULL, 0);
    wreq = (struct IOExtSer *)CreateExtIO(wport, sizeof(struct IOExtSer));
    if (!wport || !wreq) {
        printf("SerTest: no write request\n");
        cleanup();
        return RETURN_FAIL;
    }
    wreq->IOSer.io_Device = req->IOSer.io_Device;
    wreq->IOSer.io_Unit = req->IOSer.io_Unit;

    if (!quiet) {
        printf("SerTest: serial.device open at 9600 baud\n");
    }

    /* Protocol IV reset, exactly as a real driver opens the conversation. */
    send("\r$");
    Delay(13);              /* ~250ms */
    send("\r#");
    Delay(4);               /* ~75ms */

    /* Who are you? */
    send("~#\r");
    if (read_line(line, sizeof line, 50) > 0) {
        printf("SerTest: model reply: \"%s\"\n", line);
    } else {
        printf("SerTest: FAIL no answer to ~# (nothing on the port)\n");
        failures++;
    }

    /* How big are you? */
    send("~C\r");
    if (read_line(line, sizeof line, 50) > 0) {
        int mx = 0, my = 0;
        printf("SerTest: max coords reply: \"%s\"\n", line);
        if (sscanf(line, "~C%d,%d", &mx, &my) == 2 && mx > 0 && my > 0) {
            printf("SerTest: range %d x %d\n", mx, my);
        } else {
            printf("SerTest: FAIL max coords did not parse\n");
            failures++;
        }
    } else {
        printf("SerTest: FAIL no answer to ~C\n");
        failures++;
    }

    send("PH1\r");          /* pressure mode */
    send("ST\r");           /* start sending */

    if (quiet) {
        printf("SerTest: %s\n", failures ? "FAILED" : "tablet answered");
        cleanup();
        return failures ? RETURN_WARN : RETURN_OK;
    }

    printf("SerTest: streaming — move the Pencil. Ctrl-C to stop.\n");
    LONG packets = 0, gaps = 0, shorts = 0, resyncs = 0;
    for (;;) {
        UBYTE p[7];
        int n;

        if (SetSignal(0, 0) & SIGBREAKF_CTRL_C) {
            break;
        }
        /* Resynchronise on the framing bit rather than trusting
         * alignment: byte 0 is the only one with bit 7 set. */
        n = read_timeout(p, 1, 100);
        if (n != 1) {
            /* A gap is not a failure: the pen may simply be still, or the
             * host may be busy. Count them and keep listening — a driver
             * would. Only a long total silence ends the run. */
            gaps++;
            if (gaps > 20) {
                printf("SerTest: stream ended after %d packets, %d gaps\n",
                       (int)packets, (int)gaps);
                goto done;
            }
            continue;
        }
        if (!(p[0] & 0x80)) {
            resyncs++;
            continue;
        }
        if (read_timeout(p + 1, 6, 50) != 6) {
            shorts++;
            continue;
        }

        packets++;
        /* Print one in ten. An Amiga console cannot render 120 lines a
         * second, and a program that tries falls behind serial.device's
         * input buffer and overruns it — which looks like the tablet
         * stopping when it is really the printing that cannot keep up. */
        if (packets % 25) {
            continue;
        }
        {
            LONG x = ((LONG)(p[0] & 0x03) << 14) | ((LONG)p[1] << 7) | p[2];
            LONG y = ((LONG)(p[3] & 0x03) << 14) | ((LONG)p[4] << 7) | p[5];
            LONG pr = (((LONG)(p[6] & 0x3f)) << 2) |
                      ((p[3] & 0x04) >> 1) | ((p[0] & 0x04) >> 2);
            printf("[%4d] x=%5d y=%5d pressure=%3d prox=%d tip=%d\n",
                   (int)packets, (int)x, (int)y, (int)pr,
                   (p[0] & 0x40) ? 1 : 0,
                   (p[3] & 0x08) ? 1 : 0);
        }
    }

done:
    printf("SerTest: %d packets, %d gaps, %d short, %d resyncs\n",
           (int)packets, (int)gaps, (int)shorts, (int)resyncs);
    cleanup();
    return failures ? RETURN_WARN : RETURN_OK;
}
