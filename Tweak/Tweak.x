// HCG Nexus — SpringBoard entry point.
//
// Deliberately installs NO method hooks. The constructor only registers for
// UIApplicationDidFinishLaunchingNotification; everything else happens in
// HCGSpringBoardBootstrap, which verifies every class/selector it uses and
// stays inactive (normal SpringBoard UI untouched) when anything is missing,
// when the kill-switch file exists, or while HCG Nexus is disabled.
//
// Injection is limited to SpringBoard by HCGNexus.plist.

#import <UIKit/UIKit.h>
#import "HCGSpringBoardBootstrap.h"

%ctor {
    @autoreleasepool {
        NSString *bundleIdentifier = [NSBundle mainBundle].bundleIdentifier;
        if (![bundleIdentifier isEqualToString:@"com.apple.springboard"]) return;
        [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidFinishLaunchingNotification
                                                          object:nil
                                                           queue:[NSOperationQueue mainQueue]
                                                      usingBlock:^(NSNotification *note) {
            [HCGSpringBoardBootstrap startAfterLaunch];
        }];
    }
}
