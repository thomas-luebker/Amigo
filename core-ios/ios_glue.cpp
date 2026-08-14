/* iPadUAE-specific glue compiled into the core (gets the core's include
 * context without patching upstream). */

#include "sysconfig.h"
#include "sysdeps.h"
#include "options.h"
#include "statusline.h"
#include "inputdevice.h"
#include "savestate.h"
#include "keyboard.h"
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
