#import <Foundation/Foundation.h>
#import "HCGIntegrations.h"

NS_ASSUME_NONNULL_BEGIN

// HCG Products section. Three questions are kept apart on purpose:
//   1. Is the app installed?          (installed / not installed / unable to determine / not a phone app)
//   2. Can this build open it?        (bundle-ID launch needs the jailbreak package)
//   3. Is an account connected?       Never inferred from 1 or 2. No HCG app publishes its sign-in
//                                     state to Nexus today, so the answer is "not shared".

typedef NS_ENUM(NSInteger, HCGProductInstallState) {
    HCGProductInstallStateInstalled = 0,
    HCGProductInstallStateNotInstalled = 1,
    HCGProductInstallStateUnknown = 2,      // this build cannot check installation
    HCGProductInstallStateNotPhoneApp = 3,  // the product has no iPhone app (desktop or server software)
};

typedef NS_ENUM(NSInteger, HCGProductLaunchState) {
    HCGProductLaunchStateAvailable = 0,         // installed and this build can open it
    HCGProductLaunchStateAttempt = 1,           // installation unknown; opening will be tried and its result reported
    HCGProductLaunchStateAppMissing = 2,
    HCGProductLaunchStateUnavailableHere = 3,   // this build cannot open apps by bundle identifier
    HCGProductLaunchStateNoPhoneApp = 4,
};

FOUNDATION_EXPORT NSString *const HCGProductTerminal;
FOUNDATION_EXPORT NSString *const HCGProductTerminalUnleashed;
FOUNDATION_EXPORT NSString *const HCGProductNews;
FOUNDATION_EXPORT NSString *const HCGProductSentinel;
FOUNDATION_EXPORT NSString *const HCGProductServer;
FOUNDATION_EXPORT NSString *const HCGProductExecutableMaker;

@interface HCGProductInfo : NSObject {
    NSString *_identifier;
    NSString *_name;
    NSString *_symbolName;
    NSString *_platform;
    NSString *_bundleIdentifier;
    NSString *_integrationIdentifier;
    NSString *_routesSummary;
    NSString *_noPhoneAppNextStep;
}
@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *symbolName;
@property (nonatomic, copy) NSString *platform;                          // "iPhone & iPad app", "macOS/Linux service", ...
@property (nonatomic, copy, nullable) NSString *bundleIdentifier;        // nil: no phone app
@property (nonatomic, copy, nullable) NSString *integrationIdentifier;   // HCGIntegration* toggle in Settings, if any
@property (nonatomic, copy) NSString *routesSummary;                     // validated routes, in words
@property (nonatomic, copy, nullable) NSString *noPhoneAppNextStep;      // for desktop/server products
@property (nonatomic, readonly) BOOL hasPhoneApp;
@end

@interface HCGProductCatalog : NSObject
+ (NSArray<HCGProductInfo *> *)allProducts;
+ (nullable HCGProductInfo *)productWithIdentifier:(NSString *)identifier;
// probe may be nil (no probe: unable to determine).
+ (HCGProductInstallState)installStateForProduct:(HCGProductInfo *)product probe:(nullable id<HCGAppInstallationProbe>)probe;
+ (HCGProductLaunchState)launchStateForProduct:(HCGProductInfo *)product probe:(nullable id<HCGAppInstallationProbe>)probe;
+ (NSString *)titleForInstallState:(HCGProductInstallState)state;
// One honest sentence: what the user can do next.
+ (NSString *)nextStepForProduct:(HCGProductInfo *)product launchState:(HCGProductLaunchState)state;
// Account connection is a separate state; Nexus never infers it from installation.
+ (NSString *)accountStateTextForProduct:(HCGProductInfo *)product;
@end

NS_ASSUME_NONNULL_END
