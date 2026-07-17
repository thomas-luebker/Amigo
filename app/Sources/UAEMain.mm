// iPad entry point. SDL3 owns the UIKit lifecycle: SDL_main.h turns main()
// into SDL_main, and SDL's UIApplicationMain wrapper calls it on the SDL
// main thread once the app has launched.
//
// The WinUAE core is linked with NO_MAIN_IN_MAIN_C, so this replicates the
// small main() from vendor/WinUAE/main.cpp:1342.
#include <SDL3/SDL_main.h>
#import <Foundation/Foundation.h>

// od-unix entry points (TCHAR == char in the Unix port).
extern void real_main(int argc, char **argv);
extern void target_main_set_args(int argc, char **argv);
extern int target_main_handle_early(int argc, char **argv);

// The Unix port roots all user data at $HOME/Documents/WinUAE/…, which on
// iOS lands in the Files-app-visible Documents directory. Pre-create the
// folders users need to drop files into.
static void prepare_data_directories(void)
{
    NSString *docs = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    NSString *base = [docs stringByAppendingPathComponent:@"WinUAE"];
    for (NSString *sub in @[ @"Configuration", @"Kickstarts", @"Floppies", @"HardDrives", @"SaveStates", @"SaveImages" ]) {
        [NSFileManager.defaultManager createDirectoryAtPath:[base stringByAppendingPathComponent:sub]
                                withIntermediateDirectories:YES
                                                 attributes:nil
                                                      error:NULL];
    }

    // First run: boot an A1200 with the built-in open-source AROS ROM so the
    // app shows a living Amiga before the user imports any Kickstart.
    NSString *defaultConfig = [base stringByAppendingPathComponent:@"Configuration/default.uae"];
    if (![NSFileManager.defaultManager fileExistsAtPath:defaultConfig]) {
        NSString *bundled = [NSBundle.mainBundle pathForResource:@"default" ofType:@"uae"];
        if (bundled) {
            [NSFileManager.defaultManager copyItemAtPath:bundled toPath:defaultConfig error:NULL];
        }
    }
}

extern "C" void ipaduae_install_overlay(void);

int main(int argc, char *argv[])
{
    // Device consoles only see flushed stdio; make the core's write_log
    // stream immediately so stalls show their exact location.
    setvbuf(stdout, NULL, _IONBF, 0);
    setvbuf(stderr, NULL, _IONBF, 0);
    fprintf(stderr, "iPadUAE: main() entered\n");
    @autoreleasepool {
        prepare_data_directories();
    }
    fprintf(stderr, "iPadUAE: data dirs ready\n");
    // Touches feed the patched finger-event path in video_sdl.cpp
    // (trackpad-style); disabling SDL's synthesis keeps hardware
    // (GCMouse/trackpad) pointers on the regular mouse path.
    setenv("SDL_TOUCH_MOUSE_EVENTS", "0", 1);
    setenv("SDL_MOUSE_TOUCH_EVENTS", "0", 1);

    // Mounts the SwiftUI control overlay once SDL's window exists; the
    // emulator loop pumps the UIKit runloop, so the dispatch fires normally.
    ipaduae_install_overlay();
    target_main_set_args(argc, argv);
    const int early_exit = target_main_handle_early(argc, argv);
    if (early_exit >= 0)
        return early_exit;
    fprintf(stderr, "iPadUAE: entering real_main\n");
    real_main(argc, argv);
    return 0;
}
