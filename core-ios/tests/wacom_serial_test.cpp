#include "stub/sysdeps.h"
#include "../wacom_serial.cpp"

#include <assert.h>
#include <string>

static std::string drain(int max_hsync = 200000)
{
    std::string out;
    for (int i = 0; i < max_hsync; i++) {
        wacom_serial_hsync(9600);
        int c;
        while (wacom_serial_readavail() && wacom_serial_read(&c)) {
            out.push_back((char)c);
        }
        if (out.size() && rx_used() == 0 && i > 400) break;
    }
    return out;
}

static void send(const char *s)
{
    while (*s) wacom_serial_write(*s++);
}

static int fails = 0;
static void check(bool ok, const char *what)
{
    printf("%s  %s\n", ok ? "PASS" : "FAIL", what);
    if (!ok) fails++;
}

int main(void)
{
    check(wacom_serial_is_name("WACOM_TABLET") == 1, "device name matches (case-insensitive)");
    check(wacom_serial_is_name("wacom_tablet") == 1, "device name lowercase");
    check(wacom_serial_is_name("LOOPBACK_SERIAL") == 0, "other names rejected");

    wacom_serial_open();

    // --- Linux/Wacom IV init sequence -------------------------------
    send("\r$");           // reset speed
    send("\r#");           // reset to protocol IV
    std::string r;

    send("~#\r");
    r = drain();
    check(r.rfind("~#UD", 0) == 0, "~# answers with a model string");
    check(r.find('V') != std::string::npos && r.back() == '\r', "model reply carries a version and ends CR");
    check(r[2] == 'U' && r[3] == 'D', "model letters land at bytes 2-3 (where drivers read them)");

    send("~C\r");
    r = drain();
    check(r.rfind("~C", 0) == 0, "~C answers with max coordinates");
    int mx = 0, my = 0;
    check(sscanf(r.c_str(), "~C%d,%d", &mx, &my) == 2, "max coords parse");
    check(mx == WACOM_MAX_X && my == WACOM_MAX_Y, "max coords match what packets use");

    // --- Before ST: a real tablet stays silent ----------------------
    wacom_serial_pen(0.5f, 0.5f, 0.5f, 1, 1);
    r = drain(2000);
    check(r.empty(), "no packets before ST");

    send("PH1\r");
    send("ST\r");
    r = drain(2000);
    check(r.empty(), "ST itself produces no output");

    // --- A pen sample ------------------------------------------------
    wacom_serial_pen(0.25f, 0.75f, 1.0f, 1, 1);
    r = drain();
    check(r.size() == 7, "one sample = one 7-byte packet");

    const unsigned char *p = (const unsigned char *)r.data();
    check((p[0] & 0x80) != 0, "byte 0 has the sync bit");
    bool others_clear = true;
    for (int i = 1; i < 7; i++) if (p[i] & 0x80) others_clear = false;
    check(others_clear, "bytes 1-6 have bit 7 clear (self-synchronising)");
    check((p[0] & 0x40) != 0, "proximity bit set");
    check((p[0] & 0x20) != 0, "stylus bit set");

    int x = ((p[0] & 0x03) << 14) | (p[1] << 7) | p[2];
    int y = ((p[3] & 0x03) << 14) | (p[4] << 7) | p[5];
    int expect_x = (int)(0.25f * WACOM_MAX_X + 0.5f);
    int expect_y = (int)(0.75f * WACOM_MAX_Y + 0.5f);
    printf("     decoded x=%d y=%d (expected %d,%d)\n", x, y, expect_x, expect_y);
    check(x == expect_x, "X round-trips through the packet");
    check(y == expect_y, "Y round-trips through the packet");

    int pressure = (((p[6] & 0x3f) << 2) | ((p[3] & 0x04) >> 1) | ((p[0] & 0x04) >> 2));
    printf("     decoded pressure=%d of %d\n", pressure, WACOM_MAX_PRESSURE);
    check(pressure == WACOM_MAX_PRESSURE, "full tip force decodes to full scale");
    check((p[6] & 0x40) != 0, "pressure sign bit set for positive pressure");
    check((p[3] & 0x08) != 0, "tip switch reported as button B0");

    // --- Zero pressure, and monotonicity -----------------------------
    wacom_serial_pen(0.5f, 0.5f, 0.0f, 1, 0);
    r = drain();
    p = (const unsigned char *)r.data();
    int p0 = (((p[6] & 0x3f) << 2) | ((p[3] & 0x04) >> 1) | ((p[0] & 0x04) >> 2));
    check(p0 == 0, "zero force decodes to zero pressure");
    check((p[3] & 0x08) == 0, "tip switch clear at zero force");

    int prev = -1; bool mono = true;
    for (int i = 0; i <= 20; i++) {
        wacom_serial_pen(0.5f, 0.5f, i / 20.0f, 1, 1);
        r = drain();
        p = (const unsigned char *)r.data();
        int v = (((p[6] & 0x3f) << 2) | ((p[3] & 0x04) >> 1) | ((p[0] & 0x04) >> 2));
        if (v < prev) mono = false;
        prev = v;
    }
    check(mono, "pressure rises monotonically across the range");

    // --- Leaving proximity -------------------------------------------
    wacom_serial_pen(0.5f, 0.5f, 0.0f, 0, 0);
    r = drain();
    check(r.size() == 7, "leaving proximity emits a final packet");
    p = (const unsigned char *)r.data();
    check((p[0] & 0x40) == 0, "proximity bit clear in it");
    wacom_serial_pen(0.5f, 0.5f, 0.0f, 0, 0);
    r = drain(2000);
    check(r.empty(), "no further packets once out of proximity");

    // --- SP stops the stream -----------------------------------------
    wacom_serial_pen(0.5f, 0.5f, 0.5f, 1, 1);
    (void)drain();
    send("SP\r");
    wacom_serial_pen(0.6f, 0.5f, 0.5f, 1, 1);
    r = drain(2000);
    check(r.empty(), "SP stops the stream");

    // --- Baud pacing --------------------------------------------------
    // Oversupply: a sample every 50 scanlines is ~312/s, well past what
    // 9600 baud can carry, so the drain rate is the pacing, not the input.
    send("ST\r");
    int bytes = 0;
    for (int i = 0; i < WACOM_HSYNC_HZ; i++) {
        if (i % 50 == 0) wacom_serial_pen(0.5f, 0.5f, 0.5f, 1, 1);
        wacom_serial_hsync(9600);
        int c;
        while (wacom_serial_readavail() && wacom_serial_read(&c)) bytes++;
    }
    printf("     oversupplied: drained %d bytes in one second (9600 baud = 960)\n", bytes);
    // The ceiling is 960 plus the 32-byte burst bucket a port may have
    // banked while idle — the measured overshoot is exactly that.
    check(bytes <= 960 + 32 && bytes > 930, "receive stream is metered at the programmed baud");

    // At the rate the Pencil actually reports (120 Hz = 840 bytes/s) the
    // line has headroom and nothing should be dropped. Drain first so the
    // previous overflow does not spill into the count.
    (void)drain();
    int sent = 0;
    bytes = 0;
    for (int i = 0; i < WACOM_HSYNC_HZ; i++) {
        if (i % 130 == 0) { wacom_serial_pen(0.5f, 0.5f, 0.5f, 1, 1); sent++; }
        wacom_serial_hsync(9600);
        int c;
        while (wacom_serial_readavail() && wacom_serial_read(&c)) bytes++;
    }
    printf("     at Pencil rate: %d samples in, %d packets out\n", sent, bytes / 7);
    check(bytes / 7 == sent, "no samples dropped at the Pencil's own report rate");

    (void)drain();
    bytes = 0;
    for (int i = 0; i < WACOM_HSYNC_HZ; i++) {
        if (i % 20 == 0) wacom_serial_pen(0.5f, 0.5f, 0.5f, 1, 1);
        wacom_serial_hsync(19200);
        int c;
        while (wacom_serial_readavail() && wacom_serial_read(&c)) bytes++;
    }
    printf("     at 19200 baud: %d bytes in one second (= 1920)\n", bytes);
    check(bytes <= 1920 + 32 && bytes > 1880, "pacing follows the guest's programmed baud");

    printf("\n%s (%d failure%s)\n", fails ? "FAILURES" : "all checks passed",
           fails, fails == 1 ? "" : "s");
    return fails ? 1 : 0;
}
