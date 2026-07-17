// Thin C bridge between the Swift UI layer and the WinUAE core.
//
// The emulator loop runs on the SDL main thread, which on iOS is the UIKit
// main thread — UI actions land between emulation frames, and these core
// entry points are the same ones WinUAE's Windows GUI thread uses (they go
// through changed_prefs / config change queueing).

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
