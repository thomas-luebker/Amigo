// iPad entry point. SDL3 owns the UIKit lifecycle: SDL_main.h turns main()
// into SDL_main, and SDL's UIApplicationMain wrapper calls it on the SDL
// main thread once the app has launched.
//
// The WinUAE core is linked with NO_MAIN_IN_MAIN_C, so this replicates the
// small main() from vendor/WinUAE/main.cpp:1342.
#include <SDL3/SDL_main.h>
#include <SDL3/SDL_events.h>
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
    NSFileManager *fm = NSFileManager.defaultManager;
    NSString *base = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;

    // Migrate from the earlier Documents/WinUAE/ layout: move any resource
    // subfolders up into Documents/ so existing Kickstarts/HDFs aren't lost.
    NSString *legacy = [base stringByAppendingPathComponent:@"WinUAE"];
    if ([fm fileExistsAtPath:legacy]) {
        for (NSString *item in [fm contentsOfDirectoryAtPath:legacy error:NULL]) {
            NSString *dst = [base stringByAppendingPathComponent:item];
            if (![fm fileExistsAtPath:dst]) {
                [fm moveItemAtPath:[legacy stringByAppendingPathComponent:item] toPath:dst error:NULL];
            }
        }
        // Remove the old folder if it's now empty.
        if ([fm contentsOfDirectoryAtPath:legacy error:NULL].count == 0) {
            [fm removeItemAtPath:legacy error:NULL];
        }
    }

    for (NSString *sub in @[ @"Configuration", @"Kickstarts", @"Floppies", @"HardDrives", @"SaveStates", @"SaveImages" ]) {
        [fm createDirectoryAtPath:[base stringByAppendingPathComponent:sub]
      withIntermediateDirectories:YES attributes:nil error:NULL];
    }

    // First run: boot an A1200 with the built-in open-source AROS ROM so the
    // app shows a living Amiga before the user imports any Kickstart.
    NSString *defaultConfig = [base stringByAppendingPathComponent:@"Configuration/default.uae"];
    if (![fm fileExistsAtPath:defaultConfig]) {
        NSString *bundled = [NSBundle.mainBundle pathForResource:@"default" ofType:@"uae"];
        if (bundled) {
            [fm copyItemAtPath:bundled toPath:defaultConfig error:NULL];
        }
    }
}

extern "C" void ipaduae_install_overlay(void);
extern "C" void ipaduae_heal_config_paths(void);
extern "C" void ipaduae_fast_exit(const char *why);

// SDL runs event watches synchronously from inside applicationWillTerminate,
// so this fires even when the emulator loop is between pumps (or already
// stuck in teardown, where the queued event would never be polled). Without
// it, iOS gives the app 5s to die and then reports a 0x8BADF00D crash.
static bool terminating_watch(void *, SDL_Event *event)
{
    if (event->type == SDL_EVENT_TERMINATING) {
        ipaduae_fast_exit("SDL_EVENT_TERMINATING");
    }
    return true;
}

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
    // Rewrite stale container-UUID media paths (Kickstart/HDF) before the
    // core reads default.uae — reinstalls change the container UUID.
    ipaduae_heal_config_paths();
    fprintf(stderr, "iPadUAE: data dirs ready\n");
    // Touches feed the patched finger-event path in video_sdl.cpp
    // (trackpad-style); disabling SDL's synthesis keeps hardware
    // (GCMouse/trackpad) pointers on the regular mouse path.
    setenv("SDL_TOUCH_MOUSE_EVENTS", "0", 1);
    setenv("SDL_MOUSE_TOUCH_EVENTS", "0", 1);

    // Registered before real_main: watches survive SDL_Init, and the
    // termination race is lost if we wait until the emulator is up.
    SDL_AddEventWatch(terminating_watch, NULL);

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
