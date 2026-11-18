#import <UIKit/UIKit.h>
#import "HCGPanelContext.h"

NS_ASSUME_NONNULL_BEGIN

// Device facts the panel can genuinely read (public APIs only). Nothing is estimated
// or simulated; a value that cannot be read is shown as "Unavailable".
@interface HCGDeviceFacts : NSObject
// Battery level/state need UIDevice battery monitoring for this process. Begin
// while the Overview is visible; End restores the previous setting.
+ (void)beginMonitoring;
+ (void)endMonitoring;
// Ordered [title, value] pairs: model, iOS, battery, Low Power Mode, thermal state, free storage, uptime.
+ (NSArray<NSArray<NSString *> *> *)rows;
@end

// Redacted plain-text report (HCGDiagnostics) for the Copy Diagnostics tool.
FOUNDATION_EXPORT NSString *HCGPanelDiagnosticsReport(HCGPanelContext *context);
// Candidate builds (version with a "~" pre-release tag) are free public demos.
FOUNDATION_EXPORT BOOL HCGIsCandidateBuild(void);

NS_ASSUME_NONNULL_END
