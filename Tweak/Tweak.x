// HCG Nexus — SpringBoard entry point.
//
// Deliberately installs NO method hooks. Injection is limited to SpringBoard by
// HCGNexus.plist ({ Filter = { Bundles = ( "com.apple.springboard" ); }; }).
//
// Activation path (see docs/RUNTIME.md):
//   1. The injector (ElleKit / Substitute / Substrate / libhooker) loads
//      HCGNexus.dylib into SpringBoard; this constructor runs before
//      UIApplicationMain.
//   2. When SpringBoard posts UIApplicationDidFinishLaunchingNotification,
//      HCGSpringBoardBootstrap starts: it checks the kill switch and iOS/UIKit
//      support, reads one preference value and registers Darwin observers.
//   3. Only when Enable HCG Nexus is on does it build the model, the overlay
//      window and the lock monitor.
//
// Fallback: if the dylib is loaded after SpringBoard already finished
// launching, that notification never comes. A delayed, idempotent start covers
// that case without running anything during SpringBoard's normal launch.

#import <UIKit/UIKit.h>
#import "HCGSpringBoardBootstrap.h"

static const int64_t kHCGLateStartDelaySeconds = 15;

%ctor {
    @autoreleasepool {
        NSString *bundleIdentifier = [NSBundle mainBundle].bundleIdentifier;
        if (![bundleIdentifier isEqualToString:@"com.apple.springboard"]) return;
        [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidFinishLaunchingNotification
                                                          object:nil
                                                           queue:[NSOperationQueue mainQueue]
                                                      usingBlock:^(NSNotification *note) {
            [HCGSpringBoardBootstrap startAfterLaunchWithReason:@"launch notification"];
        }];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, kHCGLateStartDelaySeconds * (int64_t)NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            if ([UIApplication sharedApplication]) [HCGSpringBoardBootstrap startAfterLaunchWithReason:@"late-load fallback"];
        });
    }
}
