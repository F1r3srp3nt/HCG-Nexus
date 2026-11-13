#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// Path of an optional emergency kill switch. If this file exists when
// SpringBoard starts, HCG Nexus does nothing at all (no window, no observers).
// It lives outside the jailbreak prefix so it is the same on rootless and
// rootful layouts.
FOUNDATION_EXPORT NSString *const HCGKillSwitchPath;

// Minimal SpringBoard integration layer. Installs no method hooks: after
// SpringBoard finishes launching it reads one preference value. Only when the
// user enables HCG Nexus does it build the model, window and lock monitor.
@interface HCGSpringBoardBootstrap : NSObject
+ (void)startAfterLaunch;
// Same, recording how activation was reached ("launch notification" or
// "late-load fallback"); shown in Settings › HCG Nexus › Diagnostics.
+ (void)startAfterLaunchWithReason:(NSString *)reason;
@end

NS_ASSUME_NONNULL_END
