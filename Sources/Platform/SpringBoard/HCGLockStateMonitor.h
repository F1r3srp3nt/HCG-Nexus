#import <Foundation/Foundation.h>
#import "HCGOverlayPolicy.h"

NS_ASSUME_NONNULL_BEGIN

// Read-only lock / cover-sheet / screen state for SpringBoard. Installs no
// hooks. Sources, each verified before use:
//   * Darwin state "com.apple.springboard.lockstate" (notify_get_state)
//   * Darwin state "com.apple.springboard.hasBlankedScreen"
//   * -[SBLockScreenManager isUILocked]           (if present)
//   * -[SBCoverSheetPresentationManager isVisible] (if present)
//   * UIApplicationProtectedDataWillBecomeUnavailable
// While the cover sheet is up on an authenticated device it polls the cover
// sheet state every 0.5 s (two message sends) until it goes away; it never
// polls otherwise.
@interface HCGLockStateMonitor : NSObject
@property (nonatomic, copy, nullable) void (^changeHandler)(HCGSystemSignals signals);
@property (nonatomic, readonly) HCGSystemSignals signals;
- (void)start;
- (void)stop;
- (void)refresh;          // re-read every source now
- (NSString *)sourceSummary;
@end

NS_ASSUME_NONNULL_END
