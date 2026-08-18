// Thin C bridge between the Swift UI layer and the WinUAE core.
//
// The emulator loop runs on the SDL main thread, which on iOS is the UIKit
// main thread — UI actions land between emulation frames, and these core
// entry points are the same ones WinUAE's Windows GUI thread uses (they go
// through changed_prefs / config change queueing).

#import <GameController/GameController.h>
#import <UIKit/UIKit.h>

/* Amiga -> iOS clipboard. Called from od-unix/clipboard.cpp when a
 * Workbench program puts text on the Amiga clipboard.
 *
 * Writing to UIPasteboard requires no user consent and raises no privacy
 * banner (only *reading* does), so this direction is automatic. The
 * reverse direction never reads the pasteboard here at all — it comes in
 * through a SwiftUI PasteButton, where the tap is the consent. */
extern "C" int ipaduae_host_set_pasteboard_text(const char *text)
{
    if (!text) {
        return 0;
    }
    NSString *s = [NSString stringWithUTF8String:text];
    if (!s) {
        return 0;
    }
    /* UIPasteboard wants the main thread; the emulation loop already runs
     * there, but this can also be reached from a trap callback. */
    if ([NSThread isMainThread]) {
        UIPasteboard.generalPasteboard.string = s;
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            UIPasteboard.generalPasteboard.string = s;
        });
    }
    return 1;
}

/* Authoritative per-side shift state, read straight from the hardware.
 *
 * iOS delivers a phantom release for one shift when the other is pressed,
 * so the key *event* stream cannot be trusted to track the two sides
 * (that is why both used to collapse into a single Amiga shift, which
 * broke games using the two shifts as separate controls — pinball
 * flippers). Polling the button state instead is immune to phantom
 * events. SDL owns keyChangedHandler, so this only ever reads.
 *
 * Returns 1 when a hardware keyboard is present and the state is valid. */
extern "C" int ipaduae_hw_shift_state(int *left, int *right)
{
    GCKeyboardInput *input = GCKeyboard.coalescedKeyboard.keyboardInput;
    if (!input) {
        return 0;
    }
    GCControllerButtonInput *l = [input buttonForKeyCode:GCKeyCodeLeftShift];
    GCControllerButtonInput *r = [input buttonForKeyCode:GCKeyCodeRightShift];
    if (!l && !r) {
        return 0;
    }
    *left = (l && l.isPressed) ? 1 : 0;
    *right = (r && r.isPressed) ? 1 : 0;
    return 1;
}

// Core prototypes (TCHAR == char in the Unix port; overloads must match
// the mangled symbols in libuaecore.a exactly).
extern void disk_insert(int num, const char *name);
extern void disk_eject(int num);
extern void uae_reset(int hardreset, int keyboardreset);

extern "C" void ipaduae_insert_floppy(int drive, const char *path)
{
    disk_insert(drive, path);
}

extern "C" void ipaduae_eject_floppy(int drive)
{
    disk_eject(drive);
}

extern "C" void ipaduae_reset(int hard)
{
    uae_reset(hard, 1);
}

// Virtual keyboard/joystick: feed SDL scancodes straight into the Unix
// input layer (same entry the SDL key-event path uses).
extern void unix_input_keyboard_key(int scancode, bool pressed, int lockstate);

extern "C" void ipaduae_send_key(int sdl_scancode, int pressed)
{
    unix_input_keyboard_key(sdl_scancode, pressed != 0, 0);
}

// Restart the emulator with a (rewritten) config file. real_main's outer
// loop re-runs real_main2, which loads restart_config — same mechanism the
// desktop GUI uses for machine changes (Kickstart, mounted hardfiles, ...).
struct uae_prefs;
extern void uae_restart(struct uae_prefs *p, int opengui, const char *cfgfile);

extern "C" void ipaduae_restart_with_config(const char *configpath)
{
    uae_restart(nullptr, -1, configpath);
}
