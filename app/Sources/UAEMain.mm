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
}

int main(int argc, char *argv[])
{
    @autoreleasepool {
        prepare_data_directories();
    }
    target_main_set_args(argc, argv);
    const int early_exit = target_main_handle_early(argc, argv);
    if (early_exit >= 0)
        return early_exit;
    real_main(argc, argv);
    return 0;
}
