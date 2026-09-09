// The three app-layer symbols libuaecore.a needs, tvOS edition.
// (Computed from the archive: everything else the core references is
// defined inside it — see docs/TVOS.md.)
//
// The iPad versions live in app/Sources/UAEBridge.mm. UIPasteboard does
// not exist on tvOS, so the clipboard directions report "not handled"
// and the core keeps the data on the Amiga side. GCKeyboard exists on
// tvOS, so the per-side shift state is the same code.

#import <GameController/GameController.h>

extern "C" int ipaduae_host_set_pasteboard_image(const void *bytes, int len)
{
    (void)bytes; (void)len;
    return 0;
}

extern "C" int ipaduae_host_set_pasteboard_text(const char *text)
{
    (void)text;
    return 0;
}

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
