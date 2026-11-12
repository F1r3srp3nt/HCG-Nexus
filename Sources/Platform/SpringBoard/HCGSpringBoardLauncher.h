#import <Foundation/Foundation.h>
#import "HCGLauncher.h"

NS_ASSUME_NONNULL_BEGIN

// Launch adapter for use inside SpringBoard. Uses LSApplicationWorkspace
// (MobileCoreServices, private) for installation checks and app launches and
// UIApplication for URLs. Each private class/selector is looked up at runtime;
// when one is missing the adapter reports a "launcher unavailable" error
// instead of crashing SpringBoard.
@interface HCGSpringBoardLauncher : NSObject <HCGLauncher>
@property (nonatomic, readonly) BOOL canLaunchApplications;
@end

NS_ASSUME_NONNULL_END
