// Apple TV probe entry point — docs/TVOS.md milestone 3.
//
// A cut-down copy of app/Sources/UAEMain.mm: SDL3 owns the UIKit
// lifecycle (SDL_main.h turns main() into SDL_main), and the WinUAE core
// is linked with NO_MAIN_IN_MAIN_C, so this replicates main() from
// vendor/WinUAE/main.cpp. Dropped from the iPad version: the SwiftUI
// overlay, the config-path healer (Swift), the touch environment
// variables. Everything else is the same call sequence, so a difference
// in behaviour is tvOS, not the probe.

#include <SDL3/SDL_main.h>
#include <SDL3/SDL_events.h>
#import <Foundation/Foundation.h>

extern void real_main(int argc, char **argv);
extern void target_main_set_args(int argc, char **argv);
extern int target_main_handle_early(int argc, char **argv);
extern "C" void ipaduae_open_debug_log(const char *path);
extern "C" void ipaduae_start_hang_watchdog(void);
extern "C" void ipaduae_fast_exit(const char *why);

static void prepare_data_directories(void)
{
    NSFileManager *fm = NSFileManager.defaultManager;
    NSString *base = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    for (NSString *sub in @[ @"Configuration", @"Kickstarts", @"Floppies", @"HardDrives", @"CDs", @"SaveStates", @"SaveImages" ]) {
        [fm createDirectoryAtPath:[base stringByAppendingPathComponent:sub]
      withIntermediateDirectories:YES attributes:nil error:NULL];
    }
    NSString *defaultConfig = [base stringByAppendingPathComponent:@"Configuration/default.uae"];
    if (![fm fileExistsAtPath:defaultConfig]) {
        NSString *bundled = [NSBundle.mainBundle pathForResource:@"default" ofType:@"uae"];
        if (bundled) {
            [fm copyItemAtPath:bundled toPath:defaultConfig error:NULL];
        }
    }
    fprintf(stderr, "AmigoTV: data root %s\n", base.UTF8String);
}

static bool terminating_watch(void *, SDL_Event *event)
{
    if (event->type == SDL_EVENT_TERMINATING) {
        ipaduae_fast_exit("SDL_EVENT_TERMINATING");
    }
    return true;
}

int main(int argc, char *argv[])
{
    setvbuf(stdout, NULL, _IONBF, 0);
    setvbuf(stderr, NULL, _IONBF, 0);
    fprintf(stderr, "AmigoTV: main() entered\n");
    @autoreleasepool {
        prepare_data_directories();
        NSString *base = NSSearchPathForDirectoriesInDomains(
            NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
        ipaduae_open_debug_log(
            [base stringByAppendingPathComponent:@"amigo-log.txt"].UTF8String);
    }
    SDL_AddEventWatch(terminating_watch, NULL);
    target_main_set_args(argc, argv);
    const int early_exit = target_main_handle_early(argc, argv);
    if (early_exit >= 0)
        return early_exit;
    ipaduae_start_hang_watchdog();
    fprintf(stderr, "AmigoTV: entering real_main\n");
    real_main(argc, argv);
    return 0;
}
