/* iPadUAE-specific glue compiled into the core (gets the core's include
 * context without patching upstream). */

#include "sysconfig.h"
#include "sysdeps.h"
#include "options.h"
#include "statusline.h"
#include "inputdevice.h"
#include "savestate.h"
#include "keyboard.h"
#include "gui.h"
#include "disk.h"
#include <sys/stat.h>
#include <unistd.h>
#include <CoreFoundation/CoreFoundation.h>

/* iOS termination must be immediate: the desktop-style teardown
 * (do_leave_program → drawing_free etc.) waits unbounded on emulator
 * threads, and once real_main stops pumping the runloop the app can no
 * longer answer FrontBoard — after 5s iOS kills it with 0x8BADF00D.
 * There is no quit-to-desktop on iOS: any quit means the process is
 * going away. The autosave was already queued on willResignActive and
 * written file data survives _exit, so skip teardown entirely. */
extern "C" void ipaduae_fast_exit(const char *why)
{
    fprintf(stderr, "iPadUAE: fast exit (%s)\n", why ? why : "?");
    /* A clean quit is not a crash: clear the pending-config-change marker
     * so the next launch doesn't roll back a change that worked fine
     * (ConfigStore.riskyChangeKey — kept in sync by hand). */
    CFPreferencesSetAppValue(CFSTR("riskyConfigChangePending"), NULL,
                             kCFPreferencesCurrentApplication);
    CFPreferencesAppSynchronize(kCFPreferencesCurrentApplication);
    _exit(0);
}

/* Toggle 1:1 pointer sync (tablet/mousehack) at runtime — no reboot.
 * inputdevice_mh_abs() calls mousehack_enable() on every absolute event,
 * so the guest-side driver activates on the next touch after enabling. */
extern "C" void ipaduae_set_tablet_runtime(int on)
{
    const int mode = on ? TABLET_MOUSEHACK : TABLET_OFF;
    currprefs.input_tablet = mode;
    changed_prefs.input_tablet = mode;
}

/* Apple Pencil hover → absolute pointer (only meaningful in 1:1/tablet
 * mode; relative mode has no absolute pointer concept). Normalized [0,1]
 * window coordinates from the UIKit hover recognizer. */
extern bool unix_video_pointer_abs_normalized(float nx, float ny);

extern "C" void ipaduae_pointer_hover(float nx, float ny)
{
    if (currprefs.input_tablet != TABLET_OFF) {
        unix_video_pointer_abs_normalized(nx, ny);
    }
}

/* Save states: quick slots through the core's queued input-code path so
 * the actual save/restore executes at a safe vsync boundary on the
 * emulation thread. Slot 0 = autosave (state.uss), 1..9 = user slots
 * (state_N.uss). The unix port never seeds savestate_fname (the win32
 * GUI does that); set the base here on every call. */
extern "C" void ipaduae_state_op(int slot, int save)
{
    const char *home = getenv("HOME");
    if (!home) {
        return;
    }
    char dir[MAX_DPATH];
    snprintf(dir, sizeof dir, "%s/Documents/SaveStates", home);
    mkdir(dir, 0755);
    snprintf(savestate_fname, sizeof savestate_fname, "%s/state.uss", dir);
    if (slot < 0) slot = 0;
    if (slot > 9) slot = 9;
    inputdevice_add_inputcode(
        (save ? AKS_STATESAVEQUICK : AKS_STATERESTOREQUICK) + 2 * slot, 1, NULL);
}

/* Palm rejection: while the Apple Pencil hovers, finger touches are
 * ignored by the touch layer (they would left-click in 1:1 mode). */
extern bool unix_input_pen_hover_active;

extern "C" void ipaduae_set_pen_hover(int active)
{
    unix_input_pen_hover_active = active != 0;
}

/* Mouse button injection for UIKit-side input (Apple Pencil squeeze /
 * double-tap → right mouse button). 0=left 1=right 2=middle. */
extern void unix_input_mouse_button(int button, bool pressed);

extern "C" void ipaduae_mouse_button(int button, int pressed)
{
    unix_input_mouse_button(button, pressed != 0);
}

/* External display (living-room mode): auto-attaches when a second screen
 * appears; this toggle lets the user opt out. */
extern void unix_video_set_external_display(bool enabled);

extern "C" void ipaduae_set_external_display(int on)
{
    unix_video_set_external_display(on != 0);
}

/* Live toggle for safe-area layout (applies on the next presented frame). */
extern bool unix_video_use_safe_area;

extern "C" void ipaduae_set_safe_area(int on)
{
    unix_video_use_safe_area = on != 0;
}

/* Game controller routing (Controller panel): port -1=off, 0=Amiga mouse
 * port, 1=Amiga joystick port; cd32 enables CD32-pad mode; autofire 0/1.
 * Applied immediately and re-applied automatically on connect/disconnect. */
extern void unix_input_set_controller(int port, int cd32, int autofire);
extern const char *unix_input_controller_name(void);

extern "C" void ipaduae_set_controller(int port, int cd32, int autofire)
{
    unix_input_set_controller(port, cd32, autofire);
}

extern "C" const char *ipaduae_controller_name(void)
{
    return unix_input_controller_name();
}

/* Keyboard-layout-B joystick (cursor keys + right Ctrl on the joystick
 * port): on while the virtual joystick overlay is shown, off otherwise
 * so cursor keys type as cursor keys. */
extern void unix_input_set_kbd_joystick(int on);

extern "C" void ipaduae_set_kbd_joystick(int on)
{
    unix_input_set_kbd_joystick(on);
}

/* Bottom strip of the window reserved for the virtual keyboard (fraction
 * of window height); the picture lays out above it. 0 restores overlay. */
extern float unix_video_bottom_inset;

extern "C" void ipaduae_set_bottom_inset(float fraction)
{
    if (fraction < 0.0f) fraction = 0.0f;
    if (fraction > 0.7f) fraction = 0.7f;
    unix_video_bottom_inset = fraction;
}

/* Picture proportions: fit (letterbox) vs the historical stretch. */
extern bool unix_video_aspect_fit;

extern "C" void ipaduae_set_aspect_fit(int on)
{
    unix_video_aspect_fit = on != 0;
}

/* Live toggle for the on-screen LED status line. */
extern "C" void ipaduae_set_leds(int on)
{
    const int mask = on ? STATUSLINE_CHIPSET : 0;
    currprefs.leds_on_screen = mask;
    changed_prefs.leds_on_screen = mask;
}

/* Live toggle for host-accelerated RTG blits. Off = uaegfx software
 * fallback (correct in >8-bit modes where accel is incomplete). */
extern bool unix_rtg_accel_enabled;

extern "C" void ipaduae_set_rtg_accel(int on)
{
    unix_rtg_accel_enabled = on != 0;
}

/* Present vsync — off decouples emulation throughput from the display
 * refresh (the emulation thread no longer blocks on vblank). */
extern bool unix_video_vsync;
extern void unix_video_apply_vsync(void);

extern "C" void ipaduae_set_vsync(int on)
{
    unix_video_vsync = on != 0;
    unix_video_apply_vsync();
}

/* CRT look. The SDL renderer already composites a scanline overlay from
 * the filter prefs (render_scanline_overlay in video_sdl.cpp), which is
 * read fresh out of currprefs every frame — so this is a live toggle
 * with no restart and no shader pipeline.
 *
 * level 0 = off, 1..3 = increasing strength. The ratio packs lit lines
 * in the low nibble and shaded lines in the high one; 1 lit / 1 shaded
 * is the classic every-other-line look. */
extern "C" void ipaduae_set_crt(int level)
{
    if (level < 0) level = 0;
    if (level > 3) level = 3;
    static const int opacity[4] = { 0, 25, 45, 70 };
    for (int i = 0; i < MAX_FILTERDATA; i++) {
        struct gfx_filterdata *gf = &currprefs.gf[i];
        struct gfx_filterdata *cgf = &changed_prefs.gf[i];
        gf->gfx_filter_scanlines = cgf->gfx_filter_scanlines = opacity[level];
        /* Shaded lines are drawn black; "level" here is the brightness of
         * the shade itself, kept at 0 so the darkening is pure. */
        gf->gfx_filter_scanlinelevel = cgf->gfx_filter_scanlinelevel = 0;
        gf->gfx_filter_scanlineratio = cgf->gfx_filter_scanlineratio = (1 << 4) | 1;
        gf->gfx_filter_scanlineoffset = cgf->gfx_filter_scanlineoffset = 0;
        /* Deliberately does NOT touch gfx_filter_bilinear. It is a
         * separate rendering preference that also governs the RTG and
         * interlace contexts, and driving it from a CRT setting meant
         * every launch silently overwrote it for all three. */
    }
}

/* Floppy drive activity, polled by the app for haptics. Bit N = DFN
 * busy. gui_ledstate is maintained by gui_led() on the emulation thread;
 * a torn read is harmless here (worst case a tick is one poll late). */
extern "C" int ipaduae_floppy_led_mask(void)
{
    unsigned int mask = 0;
    for (int i = 0; i < 4; i++) {
        if (gui_ledstate & (1u << (LED_DF0 + i))) {
            mask |= 1u << i;
        }
    }
    return (int)mask;
}

/* Number of emulated floppy drives (1..4). Drives beyond the count are
 * set to DRV_NONE so they vanish from the Amiga's device list. Applied
 * through changed_prefs, so it takes effect on the next config check
 * without a restart. */
extern "C" void ipaduae_set_floppy_drives(int count)
{
    if (count < 1) count = 1;
    if (count > 4) count = 4;
    for (int i = 0; i < 4; i++) {
        const int type = (i < count) ? DRV_35_DD : DRV_NONE;
        changed_prefs.floppyslots[i].dfxtype = type;
    }
    set_config_changed();
}

extern "C" int ipaduae_floppy_drives(void)
{
    int count = 0;
    for (int i = 0; i < 4; i++) {
        if (currprefs.floppyslots[i].dfxtype != DRV_NONE) {
            count = i + 1;
        }
    }
    return count < 1 ? 1 : count;
}

/* Clipboard sharing between iOS and the Amiga.
 *
 * WinUAE's clipboard machinery is complete and already compiled in: the
 * Amiga side hooks clipboard.device through the filesys uae-boot handler,
 * and od-unix/clipboard.cpp does the IFF FTXT/ILBM conversion. It is
 * gated behind currprefs.clipboard_sharing, which defaults off.
 *
 * The two directions are deliberately asymmetric, because iOS treats them
 * differently:
 *
 *   Amiga -> iOS   automatic. Writing to UIPasteboard raises no banner
 *                  and needs no consent, so a copy in Workbench simply
 *                  lands on the iOS clipboard.
 *   iOS -> Amiga   explicit only. Reading UIPasteboard without user
 *                  intent raises the "Amigo pasted from <app>" banner, so
 *                  the poll is compiled out on iOS (clipboard.cpp) and
 *                  the app pushes text in from a SwiftUI PasteButton
 *                  instead — the tap is the consent, and no code here
 *                  ever reads the pasteboard. */
extern void unix_clipboard_push_host_text(const char *text);
extern int unix_clipboard_ready(void);

extern "C" void ipaduae_set_clipboard_sharing(int on)
{
    currprefs.clipboard_sharing = changed_prefs.clipboard_sharing = on != 0;
}

extern "C" int ipaduae_clipboard_sharing(void)
{
    return currprefs.clipboard_sharing ? 1 : 0;
}

extern "C" void ipaduae_clipboard_push_text(const char *text)
{
    unix_clipboard_push_host_text(text);
}

/* Paste as keystrokes. Works in any program, including everything that
 * never supported clipboard.device, and needs no Amiga-side clipboard
 * task — so it works even with sharing switched off. */
extern void unix_clipboard_type_host_text(const char *text);

extern "C" void ipaduae_clipboard_type_text(const char *text)
{
    unix_clipboard_type_host_text(text);
}

/* False until the Amiga side has started its clipboard task — lets the UI
 * explain itself instead of dropping a paste on the floor. */
extern "C" int ipaduae_clipboard_ready(void)
{
    return unix_clipboard_ready();
}

/* Whether the guest-side mousehack driver is actually servicing absolute
 * positioning. It needs Kickstart 2.0+, so on a 1.3 setup this stays 0
 * and the touch path silently falls back to relative drag-and-hold — the
 * menu claimed "1:1 Mouse: On" regardless, which is what the EAB report
 * described as "1:1 touch doesn't seem to work".
 *
 * Reads 0 for a moment after enabling on a capable Kickstart too: the
 * guest driver activates on the first absolute event, so the UI must say
 * "not active yet" rather than "unsupported". */
extern int mousehack_alive(void);

extern "C" int ipaduae_mousehack_alive(void)
{
    return mousehack_alive() ? 1 : 0;
}

/* File-backed log, because `devicectl --console` cannot be trusted.
 *
 * Three times on 2026-08-19 a console session went silent while the
 * process stayed alive and the app kept running — capture died, the log
 * simply stopped growing, and an empty log is indistinguishable from a
 * quiet system. That cost one wrong conclusion (the clipboard change hook
 * declared dead) and two void test rounds.
 *
 * write_log() already mirrors to `debugfile` when it is set, so pointing
 * that at a file under Documents gives a record that survives console
 * drops, app termination and reinstalls, and can be pulled off the device
 * with `devicectl device copy from`. always_flush_log makes it durable
 * across a kill, which matters precisely when investigating a crash. */
extern FILE *debugfile;
extern int always_flush_log;

extern "C" void ipaduae_open_debug_log(const char *path)
{
    if (debugfile || !path) {
        return;
    }
    /* Rotate rather than truncate. Opening "w" destroyed the previous
     * session's log on every launch — which is precisely the log you want
     * after a crash or hang, and the restart that follows wipes it. The
     * previous run is kept alongside as amigo-log.prev.txt, so exactly one
     * generation survives without unbounded growth. */
    char prev[1024];
    snprintf(prev, sizeof prev, "%s", path);
    char *dot = strrchr(prev, '.');
    if (dot) {
        snprintf(dot, sizeof prev - (dot - prev), ".prev.txt");
    } else {
        strncat(prev, ".prev.txt", sizeof prev - strlen(prev) - 1);
    }
    rename(path, prev);

    debugfile = fopen(path, "w");
    if (debugfile) {
        always_flush_log = 1;
        fprintf(debugfile, "iPadUAE: file log opened at %s\n", path);
        fprintf(debugfile, "iPadUAE: previous session kept at %s\n", prev);
        fflush(debugfile);
    }
}

/* Hang watchdog.
 *
 * When the emulation wedges, the SDL main thread wedges with it — so a
 * timer on the main thread can never report the hang. This runs on its
 * own thread, watches vpos for movement, and when the beam stops moving
 * dumps the state Toni asked about (STOP + interrupt mask, ERSY without
 * genlock, BEAMCON0, and whether anything is advancing at all).
 *
 * Sampled twice a second apart: if vpos differs between the two dumps the
 * machine is spinning, if it is identical it is genuinely blocked. That
 * distinction is the one thing the logs so far could not settle. */
#include <pthread.h>

extern "C" int ipaduae_get_vpos(void);
extern "C" void ipaduae_log_hang_state(const char *tag);

static void *ipaduae_hang_watchdog(void *)
{
    int last = -1, stalls = 0;
    bool reported = false;
    /* Prove the instrument works on every boot. A watchdog that silently
     * fails is worse than none: it turns "we captured nothing" into what
     * looks like "nothing happened". One line at startup shows the thread
     * runs and the symbols read sane values. */
    sleep(20);
    ipaduae_log_hang_state("boot");
    for (;;) {
        sleep(3);
        const int now = ipaduae_get_vpos();
        if (now == last) {
            stalls++;
            /* ~6s of a motionless beam is a hang, not a slow frame. */
            if (stalls >= 2 && !reported) {
                reported = true;
                ipaduae_log_hang_state("stall");
                sleep(1);
                ipaduae_log_hang_state("stall+1s");
            }
        } else {
            stalls = 0;
            reported = false;
        }
        last = now;
    }
    return NULL;
}

extern "C" void ipaduae_start_hang_watchdog(void)
{
    static bool started;
    if (started) {
        return;
    }
    started = true;
    pthread_t t;
    if (pthread_create(&t, NULL, ipaduae_hang_watchdog, NULL) == 0) {
        pthread_detach(t);
    }
}

/* Floppy drive speed — the targeted answer to "ADF loading is slow",
 * and a far better fit than warp was.
 *
 * Warp uncapped the whole machine: it paused sound and set
 * gfx_framerate=10, so the display drew one frame in ten and everything
 * FELT slower even though emulation ran faster. This touches only the
 * emulated drive timing. Sound keeps playing, the display keeps drawing,
 * and the disk simply loads faster.
 *
 * Scale (disk.cpp get_floppy_speed): 100 = real hardware timing, higher
 * = proportionally faster, and 0 = turbo, where the DMA completes
 * instantly. Values 1..10 are treated as 100 by the core.
 *
 * Turbo is ignored for non-standard ADFs — disk.cpp declines it if a
 * selected drive holds an image with custom track timing, which is most
 * copy-protected originals. Those fall back to normal speed on their own.
 *
 * Applied through changed_prefs: DISK_check_change() copies it every
 * vsync, so this takes effect live with no restart. */
extern "C" void ipaduae_set_floppy_speed(int speed)
{
    if (speed < 0) speed = 0;
    if (speed > 800) speed = 800;
    changed_prefs.floppy_speed = speed;
}

extern "C" int ipaduae_floppy_speed(void)
{
    return currprefs.floppy_speed;
}

/* Stress-driver marker, so the cycle lands in the FILE log. Swift NSLog
 * does not reach debugfile — only the core's write_log does, which made
 * an earlier run look like the driver had never fired. */
extern "C" void ipaduae_log_stress(int cycle, const char *what)
{
    write_log(_T("autostress: cycle %d — %s\n"), cycle, what ? what : "?");
}

/* What is actually in a drive, read from the core.
 *
 * The disk panel used to read `floppyN` out of the config file to decide
 * whether to offer an Eject row — but ipaduae_insert_floppy() calls
 * disk_insert() straight into the core and never touches the config. So
 * after inserting from the panel the config still said "empty" and the
 * Eject row never appeared. currprefs.floppyslots[] is the truth.
 *
 * Returns NULL for an empty drive. */
extern "C" const char *ipaduae_floppy_name(int drive)
{
    if (drive < 0 || drive > 3) {
        return NULL;
    }
    const char *df = currprefs.floppyslots[drive].df;
    return (df && df[0]) ? df : NULL;
}
