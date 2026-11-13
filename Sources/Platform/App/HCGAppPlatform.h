#import <UIKit/UIKit.h>
#import "HCGKeyValueStore.h"
#import "HCGLauncher.h"

NS_ASSUME_NONNULL_BEGIN

// ---------------------------------------------------------------------------
// Standalone iPhone/iPad app platform (HCGNexus.xcodeproj). PUBLIC APIs ONLY:
// no SpringBoard, LaunchServices-private or CFPreferences-domain access. The
// app runs in the normal iOS sandbox; signing it does not change that.
// ---------------------------------------------------------------------------

// Suite that holds the app's own workspaces/settings/recents. Distinct from the
// jailbreak package's preference domain (com.hakmicapitalgroup.hcgnexus) and the
// preview harness suite (com.hakmicapitalgroup.hcgnexus.preview), and in any
// case stored inside this app's sandbox container.
FOUNDATION_EXPORT NSString *const HCGAppDataSuiteName;

@interface HCGAppDefaultsStore : NSObject <HCGKeyValueStore>
- (instancetype)initWithSuiteName:(NSString *)suiteName;
@property (nonatomic, readonly) NSString *suiteName;
- (void)removeAllValues;
@end

// Opens links with -[UIApplication openURL:options:completionHandler:] and
// reports the real result. Opening another app by bundle identifier has no
// public API, so it is reported as unavailable instead of being simulated.
@interface HCGAppLauncher : NSObject <HCGLauncher>
// Injected for tests; defaults to [UIApplication sharedApplication].
- (instancetype)initWithApplication:(nullable UIApplication *)application NS_DESIGNATED_INITIALIZER;
@end

NS_ASSUME_NONNULL_END
