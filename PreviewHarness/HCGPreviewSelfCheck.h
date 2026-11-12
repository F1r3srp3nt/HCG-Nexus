#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

// Automated checks executed INSIDE the preview harness against the real Panel
// and Core code with the preview platform. They validate UI wiring only; they
// are not evidence that the SpringBoard tweak works on a device.
@interface HCGPreviewSelfCheck : NSObject
// Runs synchronously on the main thread using a hidden, temporary overlay
// hosted in `host`. Returns a human-readable report; *passed is set.
+ (NSString *)runInHostViewController:(UIViewController *)host passed:(BOOL *)passed;
@end

NS_ASSUME_NONNULL_END
