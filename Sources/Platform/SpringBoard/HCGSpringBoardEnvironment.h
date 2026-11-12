#import <UIKit/UIKit.h>
#import "HCGOverlayController.h"

NS_ASSUME_NONNULL_BEGIN

// Window level for the overlay: above app content, below the status bar and
// therefore below Notification/Control Centre, alerts and the lock screen in
// SpringBoard's window stack. Must be confirmed on the target iOS version.
FOUNDATION_EXPORT const UIWindowLevel HCGOverlayWindowLevel;

// Hosts the overlay in one dedicated SpringBoard window. The window is never
// made "secure", so it is not shown above the lock screen, and it returns nil
// from hit-testing everywhere except on the handle or the open panel.
@interface HCGSpringBoardEnvironment : NSObject <HCGOverlayEnvironment>
@property (nonatomic, readonly, nullable) UIWindow *window;
- (NSString *)orientationSourceSummary;
@end

NS_ASSUME_NONNULL_END
