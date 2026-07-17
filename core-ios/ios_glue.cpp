/* iPadUAE-specific glue compiled into the core (gets the core's include
 * context without patching upstream). */

#include "sysconfig.h"
#include "sysdeps.h"
#include "options.h"

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
