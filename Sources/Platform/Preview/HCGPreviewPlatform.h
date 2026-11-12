#import <UIKit/UIKit.h>
#import "HCGKeyValueStore.h"
#import "HCGLauncher.h"
#import "HCGOverlayController.h"

NS_ASSUME_NONNULL_BEGIN

// ---------------------------------------------------------------------------
// Preview-harness platform. NOTHING here touches SpringBoard, private APIs or
// another process. Results obtained with these classes are PREVIEW results and
// say nothing about whether the tweak works on a jailbroken device.
// ---------------------------------------------------------------------------

// NSUserDefaults suite store, isolated from the real tweak preferences.
@interface HCGUserDefaultsKeyValueStore : NSObject <HCGKeyValueStore>
- (instancetype)initWithSuiteName:(NSString *)suiteName;
- (void)removeAllValues;
@end

// Simulated launcher: app launches are not performed (a sandboxed app cannot
// launch others by bundle identifier). Installation state comes from an
// editable "installed apps" set so missing-app errors can be exercised.
@interface HCGPreviewLauncher : NSObject <HCGLauncher>
@property (nonatomic, copy) NSSet<NSString *> *simulatedInstalledApps;
@property (nonatomic) BOOL simulateURLFailure;
@property (nonatomic, readonly) NSArray<NSString *> *launchLog;
+ (NSSet<NSString *> *)defaultInstalledApps;
@end

// Embeds the overlay as a child view controller above the harness' mock app.
@interface HCGPreviewEnvironment : NSObject <HCGOverlayEnvironment>
- (instancetype)initWithHostViewController:(UIViewController *)host;
@property (nonatomic, readonly) NSUInteger containerInstallCount;
@end

NS_ASSUME_NONNULL_END
