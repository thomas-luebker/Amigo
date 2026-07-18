/* iPadUAE-specific glue compiled into the core (gets the core's include
 * context without patching upstream). */

#include "sysconfig.h"
#include "sysdeps.h"
#include "options.h"
#include "statusline.h"

/* Toggle 1:1 pointer sync (tablet/mousehack) at runtime — no reboot.
 * inputdevice_mh_abs() calls mousehack_enable() on every absolute event,
 * so the guest-side driver activates on the next touch after enabling. */
extern "C" void ipaduae_set_tablet_runtime(int on)
{
    const int mode = on ? TABLET_MOUSEHACK : TABLET_OFF;
    currprefs.input_tablet = mode;
    changed_prefs.input_tablet = mode;
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
