/* A Wacom Protocol IV drawing tablet on the emulated serial port, driven
 * by the Apple Pencil.
 *
 * Why this exists. TVPaint on the Amiga does not use tablet.library or any
 * Amiga driver — its tablet support is built into the application and
 * talks to a serial tablet directly, chosen from the menu it shows when
 * you right-click at launch. The tablets people actually ran it with were
 * Wacom UD/UltraPad units (an A4000 with a UD-0806 and an A1200 with an
 * UltraPad A5 are both on record on the TVPaint forum), which speak
 * Protocol IV at 9600 baud. So the way to give TVPaint pressure is not to
 * write an Amiga driver: it is to be the tablet.
 *
 * The same door serves every other program that expects a serial Wacom,
 * including the real Amiga drivers (PenPartner, Tableau Pro, FormAldiHyd,
 * AccuPoint) — with this device in place they run inside Amigo and feed
 * the genuine tablet.library, rather than the boot ROM's stand-in.
 *
 * This is a device, not a byte generator: the guest opens the port, walks
 * a speed/reset handshake, asks the tablet what it is, and only then says
 * "start sending". Answering those questions convincingly is most of the
 * work; the coordinate packets are the easy part.
 *
 * Protocol reference: the linuxwacom Protocol IV notes and the Linux
 * wacom_serial4.c decoder. Where those disagree with what TVPaint wants,
 * TVPaint wins — see the UNVERIFIED notes below, which are the things a
 * session with the real program will settle.
 */

#include "sysconfig.h"
#include "sysdeps.h"
#include "options.h"

#include <string.h>
#include <stdlib.h>

/* Config value for serial_port= that selects this device instead of a
 * host tty or a TCP endpoint. */
#define WACOM_SERIAL_NAME _T("WACOM_TABLET")

/* The tablet we claim to be: a UD-0608, 8x6 inches at 1270 lpi.
 *
 * "Self-consistent is enough" was wrong, and the device said so. A guest
 * that asks ~C scales against what we answer — but TVPaint never asks. It
 * assumes a range per model, so the range has to match the model the user
 * picks. Verified on the iPad 2026-08-25: with TVPaint set to
 * "Wacom A5 Pressure" the pointer pegged at the edge and ink landed
 * nowhere near the pen; **"Wacom A4+ Pressure" tracks correctly**, an A4
 * being about twice an A5. Change these numbers and that pairing changes
 * with them. */
#define WACOM_MAX_X    10160
#define WACOM_MAX_Y     7620
#define WACOM_RES_LPI   1270

/* Protocol IV carries pressure as 6 bits in the last byte plus two more
 * spread across bytes 0 and 3 ("extra Z bits"), so 8 bits end to end.
 * Decoders that ignore the extra two still see a monotonic 6-bit value,
 * which is why the low bits go there and not the high ones. */
#define WACOM_MAX_PRESSURE 255

/* Scanlines per second, used only to pace the receive stream at the baud
 * rate the guest programmed — serial_hsynchandler() is the tick. PAL and
 * NTSC differ by under 1%, which is far inside what a UART tolerates. */
#define WACOM_HSYNC_HZ 15625

/* UNVERIFIED: origin corner. Wacom digitizers historically count Y up
 * from the bottom edge, screens count it down from the top. If drawing
 * comes out vertically mirrored in TVPaint, this is the line to flip. */
#define WACOM_Y_DOWN 1

static bool s_open;
static bool s_started;        /* ST received: the guest wants packets */
static bool s_pressure_mode = true;

static uae_u8 s_rx[1024];
static int s_rx_head, s_rx_tail;

static char s_cmd[64];
static int s_cmdlen;

/* Baud pacing. Credit accrues per scanline and is spent one byte at a
 * time, so a driver that times its reads sees a 9600-baud tablet rather
 * than a firehose — and the emulated UART never overruns. */
static int s_credit;
static int s_credit_acc;

/* Last pen sample, so a button-only or proximity-only change still emits
 * a positionally correct packet. */
static int s_emits, s_drops;
static int s_pen_x, s_pen_y, s_pen_pressure, s_pen_buttons;
static bool s_pen_proximity;

static int rx_used(void)
{
    return (s_rx_head - s_rx_tail + (int)sizeof s_rx) % (int)sizeof s_rx;
}

static int rx_free(void)
{
    return (int)sizeof s_rx - 1 - rx_used();
}

static void rx_put(uae_u8 b)
{
    if (rx_free() <= 0) {
        return;
    }
    s_rx[s_rx_head] = b;
    s_rx_head = (s_rx_head + 1) % (int)sizeof s_rx;
}

static void rx_put_string(const char *s)
{
    while (*s) {
        rx_put((uae_u8)*s++);
    }
}

static void rx_clear(void)
{
    s_rx_head = s_rx_tail = 0;
}

/* One Protocol IV data packet.
 *
 *   byte 0: 1 PP S 0 B xx        sync, proximity, stylus, button, X15-14
 *                                 (bit 2 carries pressure bit 0)
 *   byte 1: 0 X13-X7
 *   byte 2: 0 X6-X0
 *   byte 3: 0 B3-B0 . yy         buttons, Y15-14 (bit 2 = pressure bit 1)
 *   byte 4: 0 Y13-Y7
 *   byte 5: 0 Y6-Y0
 *   byte 6: 0 s P7-P2            sign bit set = positive pressure
 *
 * Only byte 0 has bit 7 set, which is what makes the stream
 * self-synchronising: a reader that joins mid-packet resynchronises on
 * the next one without any framing protocol.
 */
static void emit_packet(void)
{
    if (!s_started) {
        return;
    }
    /* Drop the sample rather than queue behind a backlog: at 9600 baud
     * the line carries ~137 packets a second and the Pencil can report
     * faster than that. Stale coordinates are worse than missing ones. */
    if (rx_free() < 7) {
        s_drops++;
        return;
    }
    if ((++s_emits % 500) == 0) {
        write_log(_T("WACOM emit: %d packets, %d dropped, buffered=%d credit=%d\n"),
                  s_emits, s_drops, rx_used(), s_credit);
    }

    const int x = s_pen_x < 0 ? 0 : (s_pen_x > WACOM_MAX_X ? WACOM_MAX_X : s_pen_x);
    const int y = s_pen_y < 0 ? 0 : (s_pen_y > WACOM_MAX_Y ? WACOM_MAX_Y : s_pen_y);
    const int p = s_pressure_mode ? s_pen_pressure : 0;
    const bool tip = p > 0;

    uae_u8 b[7];
    b[0] = 0x80;
    if (s_pen_proximity) {
        b[0] |= 0x40;
    }
    b[0] |= 0x20;                       /* stylus, not the puck */
    if (tip || (s_pen_buttons & ~1)) {
        b[0] |= 0x08;                   /* "a button is down" summary */
    }
    b[0] |= (uae_u8)((p & 0x01) << 2);  /* pressure bit 0 */
    b[0] |= (uae_u8)((x >> 14) & 0x03);
    b[1] = (uae_u8)((x >> 7) & 0x7f);
    b[2] = (uae_u8)(x & 0x7f);

    /* Buttons: B0 is the tip switch, B1 the barrel switch — which is
     * where the Pencil's squeeze and double-tap land. */
    uae_u8 buttons = 0;
    if (tip) {
        buttons |= 0x01;
    }
    if (s_pen_buttons & 0x02) {
        buttons |= 0x02;
    }
    b[3] = (uae_u8)((buttons & 0x0f) << 3);
    b[3] |= (uae_u8)((p & 0x02) << 1);  /* pressure bit 1 */
    b[3] |= (uae_u8)((y >> 14) & 0x03);
    b[4] = (uae_u8)((y >> 7) & 0x7f);
    b[5] = (uae_u8)(y & 0x7f);

    /* Offset binary: 0x40 is "zero pressure", and the six value bits are
     * P7..P2. A decoder recovers the sign by XORing the same 0x40. */
    b[6] = (uae_u8)(0x40 | ((p >> 2) & 0x3f));

    for (int i = 0; i < 7; i++) {
        rx_put(b[i]);
    }
}

/* Answers to the identification commands. A driver that gets silence here
 * concludes there is no tablet on the port and gives up, so these matter
 * as much as the packets.
 *
 * UNVERIFIED: the exact text. The model reply is shaped so that bytes 2
 * and 3 are the model letters, which is where wacom_serial4.c reads them;
 * the configuration reply is a plausible guess, because no reachable
 * document records its format. */
static void reply_model(void)
{
    rx_put_string("~#UD-0608-R00 V1.3-2\r");
}

static void reply_max_coords(void)
{
    char buf[32];
    snprintf(buf, sizeof buf, "~C%05d,%05d\r", WACOM_MAX_X, WACOM_MAX_Y);
    rx_put_string(buf);
}

static void reply_config(void)
{
    rx_put_string("~R1,4,0,0,0\r");
}

static void tablet_reset(void)
{
    s_started = false;
    s_pressure_mode = true;
    s_cmdlen = 0;
    rx_clear();
}

static void run_command(const char *cmd)
{
    if (!cmd[0]) {
        return;
    }
    write_log(_T("WACOM cmd: \"%s\"\n"), cmd);
    if (!strcmp(cmd, "~#")) {
        reply_model();
    } else if (!strncmp(cmd, "~C", 2)) {
        reply_max_coords();
    } else if (!strncmp(cmd, "~R", 2)) {
        reply_config();
    } else if (!strcmp(cmd, "ST") || !strcmp(cmd, "SR")) {
        /* Two ways to start. The linuxwacom notes document ST; TVPaint
         * 3.59 never sends it — its init sequence, read off the wire on a
         * real Amiga, is:
         *
         *     SR · AS1 · LA2 · IT4 · IC1 · SU0 · AS1 · PH1
         *
         * SR is stream mode, and it is what starts the flow. Honouring
         * only ST left the tablet initialised, in pressure mode, and
         * silent — which looks exactly like a tablet that is not there. */
        s_started = true;
    } else if (!strcmp(cmd, "SP")) {
        s_started = false;
    } else if (!strncmp(cmd, "PH", 2)) {
        s_pressure_mode = cmd[2] != '0';
    } else if (!strcmp(cmd, "#") || !strcmp(cmd, "$")) {
        tablet_reset();
    }
    /* Everything else — IT, SU, FM, AS, DE and the rest of the
     * configuration verbs — is accepted silently. A real tablet does not
     * answer them either, and refusing would only fail the handshake. */
}

/* The guest's bytes. Commands are CR-terminated, except the two reset
 * forms ("\r#" and "\r$"), which are only ever followed by a delay — so
 * they are executed the moment they arrive rather than waiting for a
 * terminator that never comes. */
extern "C" void wacom_serial_write(int c)
{
    const char ch = (char)(c & 0xff);
    if (ch == '\r' || ch == '\n') {
        s_cmd[s_cmdlen] = 0;
        run_command(s_cmd);
        s_cmdlen = 0;
        return;
    }
    if (s_cmdlen == 0 && (ch == '#' || ch == '$')) {
        tablet_reset();
        return;
    }
    if (s_cmdlen < (int)sizeof s_cmd - 1) {
        s_cmd[s_cmdlen++] = ch;
    }
}

extern "C" int wacom_serial_readavail(void)
{
    if (!s_open || s_credit <= 0) {
        return 0;
    }
    return rx_used() > 0 ? rx_used() : 0;
}

extern "C" int wacom_serial_read(int *out)
{
    if (!s_open || s_credit <= 0 || rx_used() <= 0) {
        return 0;
    }
    *out = s_rx[s_rx_tail];
    s_rx_tail = (s_rx_tail + 1) % (int)sizeof s_rx;
    s_credit--;
    return 1;
}

/* Called once per scanline with the baud rate the guest has programmed
 * into SERPER (0 before it programs one, which a driver does before it
 * expects anything back). */
/* The sweep feeds the pen, not this device: ipaduae_pen_tablet() fans one
 * sample out to both consumers — this tablet and the guest's
 * tablet.library — so a self-test exercises the same path the Pencil
 * does, and both halves can be probed from inside the Amiga. */
extern "C" void ipaduae_pen_tablet(float nx, float ny, float pressure,
                                   int in_proximity, int buttons);

/* Self-test sweep. With no Pencil — a simulator, a desktop build, an
 * automated run — there is no pen to move, and the half of this that
 * needs proving is the half between here and the Amiga program: config,
 * open, UART, serial.device. AMIGO_TABLET_SELFTEST=1 makes the tablet
 * draw its own slow circle with a triangular pressure ramp, so a probe in
 * the guest sees a deterministic, checkable stream. */
static int s_selftest = -1;
static int s_selftest_tick;

static bool selftest_enabled(void)
{
    if (s_selftest < 0) {
        const char *v = getenv("AMIGO_TABLET_SELFTEST");
        s_selftest = (v && *v && *v != '0') ? 1 : 0;
        if (s_selftest) {
            write_log(_T("SERIAL: Wacom tablet self-test sweep enabled\n"));
        }
    }
    return s_selftest > 0;
}

/* One sample every 130 scanlines is ~120/s, the rate the Pencil itself
 * reports at, and inside what 9600 baud carries.
 *
 * The shape is a pressure ladder: eight left-to-right strokes at constant
 * speed, each at a fixed pressure one eighth higher than the last, with
 * the tip lifted between them. Constant speed is the point — TVPaint's
 * brushes respond to pen speed as well as pressure, so a freehand
 * scribble cannot tell the two apart. Here velocity is identical on every
 * rung, so any difference in width is pressure and nothing else. */
#define SWEEP_RUNGS   8
#define SWEEP_SAMPLES 60      /* per rung: 55 drawing, 5 lifted */

static void selftest_step(void)
{
    if (++s_selftest_tick < 130) {
        return;
    }
    s_selftest_tick = 0;

    static int n;
    const int rung = (n / SWEEP_SAMPLES) % SWEEP_RUNGS;
    const int step = n % SWEEP_SAMPLES;
    n++;

    const float t = (float)step / (float)(SWEEP_SAMPLES - 5);
    const bool lifted = step >= SWEEP_SAMPLES - 5;

    const float nx = 0.12f + 0.76f * (t > 1.0f ? 1.0f : t);
    const float ny = 0.18f + 0.08f * (float)rung;
    const float pr = lifted ? 0.0f : (float)(rung + 1) / (float)SWEEP_RUNGS;

    ipaduae_pen_tablet(nx, ny, pr, 1, pr > 0.0f ? 1 : 0);
}

extern "C" void wacom_serial_hsync(int baud)
{
    if (!s_open) {
        return;
    }
    if (selftest_enabled()) {
        selftest_step();
    }
    if (baud <= 0) {
        baud = 9600;
    }
    /* 8N1: ten bits carry each byte. */
    s_credit_acc += baud;
    while (s_credit_acc >= WACOM_HSYNC_HZ * 10) {
        s_credit_acc -= WACOM_HSYNC_HZ * 10;
        s_credit++;
    }
    if (s_credit > 32) {
        s_credit = 32;      /* an idle port must not bank a burst */
    }
}

extern "C" int wacom_serial_is_name(const TCHAR *name)
{
    return name && !_tcsicmp(name, WACOM_SERIAL_NAME) ? 1 : 0;
}

extern "C" void wacom_serial_open(void)
{
    s_open = true;
    s_credit = 0;
    s_credit_acc = 0;
    s_pen_proximity = false;
    s_pen_pressure = 0;
    s_pen_buttons = 0;
    tablet_reset();
    write_log(_T("SERIAL: virtual Wacom tablet attached (%dx%d, %d lpi)\n"),
              WACOM_MAX_X, WACOM_MAX_Y, WACOM_RES_LPI);
}

extern "C" void wacom_serial_close(void)
{
    s_open = false;
    s_started = false;
    rx_clear();
}

/* Pen sample from the iOS side (ios_glue.cpp). Normalized position,
 * pressure 0..1, buttons bit 0 = tip, bit 1 = barrel. */
extern "C" void wacom_serial_pen(float nx, float ny, float pressure,
                                 int in_proximity, int buttons)
{
    if (!s_open) {
        return;
    }
    if (nx < 0.0f) nx = 0.0f;
    if (nx > 1.0f) nx = 1.0f;
    if (ny < 0.0f) ny = 0.0f;
    if (ny > 1.0f) ny = 1.0f;
    if (pressure < 0.0f) pressure = 0.0f;
    if (pressure > 1.0f) pressure = 1.0f;

#if WACOM_Y_DOWN
    const float ty = ny;
#else
    const float ty = 1.0f - ny;
#endif

    const bool was_in = s_pen_proximity;
    s_pen_x = (int)(nx * WACOM_MAX_X + 0.5f);
    s_pen_y = (int)(ty * WACOM_MAX_Y + 0.5f);
    s_pen_pressure = (int)(pressure * WACOM_MAX_PRESSURE + 0.5f);
    s_pen_buttons = buttons;
    s_pen_proximity = in_proximity != 0;

    /* Leaving proximity is an event in its own right: without a final
     * packet the guest keeps the last position and thinks the pen is
     * still resting on the tablet. */
    if (was_in || s_pen_proximity) {
        emit_packet();
    }
}
