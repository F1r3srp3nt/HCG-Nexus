#import <UIKit/UIKit.h>
#import "HCGHaloBorderLink.h"
#import "HCGNexusModel.h"
#import "HCGActionRunner.h"

NS_ASSUME_NONNULL_BEGIN

// Where the panel UI is running. Decides which controls are operational.
typedef NS_ENUM(NSInteger, HCGPanelMode) {
    HCGPanelModeOverlay = 0,       // jailbreak package: SpringBoard overlay
    HCGPanelModeSettingsApp = 1,   // jailbreak package: Settings › HCG Nexus
    HCGPanelModeStandaloneApp = 2, // sandboxed iPhone/iPad app (Xcode project)
    HCGPanelModePreview = 3,       // Theos preview harness (simulation)
};

FOUNDATION_EXPORT NSString *HCGPanelModeName(HCGPanelMode mode);

// HCG account and Connected Devices status, provided ONLY by the standalone app
// (over HCG Device Link's HCG Connect session). The jailbreak tweak, Settings
// bundle and preview have no provider: they never sign in or hold tokens.
@protocol HCGAccountProviding <NSObject>
- (HCGAccountState)accountState;
- (nullable NSString *)accountDisplayName;        // from the signed-in session; nil otherwise
- (nullable NSString *)accountDetail;             // why not configured / why the session ended
- (nullable NSArray<NSString *> *)organisationNames; // nil: not loaded (requires /me after sign-in)
- (NSString *)connectionSummary;                  // HCG Device Link connection, in words
- (BOOL)canSignIn;
- (void)signInFromViewController:(UIViewController *)presenter;
- (void)signOut;
@end

// Everything a panel screen needs, passed down the navigation stack.
@interface HCGPanelContext : NSObject
@property (nonatomic) HCGPanelMode mode;
@property (nonatomic, strong) HCGNexusModel *model;
@property (nonatomic, strong, nullable) HCGActionRunner *runner;      // nil in Settings.app
@property (nonatomic, copy) NSString *environmentName;               // "SpringBoard", "Preview harness", "Settings"
@property (nonatomic) BOOL isPreview;                                // mode == Preview (kept for callers)
@property (nonatomic, copy, nullable) void (^closePanel)(void);       // animated close
@property (nonatomic, copy, nullable) void (^closePanelImmediately)(void);
@property (nonatomic, copy, nullable) NSDictionary *_Nonnull (^diagnosticsProvider)(void);
// Standalone app only: builds the Connected Devices screen (HCG Device Link,
// Sources/Platform/App/DeviceLink). nil in the jailbreak package, the Settings
// bundle and the preview harness, which never connect to HCG Server.
@property (nonatomic, copy, nullable) UIViewController *_Nullable (^connectedDevicesScreen)(HCGPanelContext *context);
// Standalone app only (see HCGAccountProviding). nil everywhere else.
@property (nonatomic, strong, nullable) id<HCGAccountProviding> accountProvider;
// Set by the panel home: a short success/failure message shown to the user.
@property (nonatomic, copy, nullable) void (^showFeedback)(NSString *message, BOOL success);
// Switches the home to another section (set by the panel home).
@property (nonatomic, copy, nullable) void (^showSection)(NSInteger section);
@property (nonatomic, readonly) HCGHost host;
@property (nonatomic, readonly) HCGToolEnvironment toolEnvironment;
- (void)feedback:(NSString *)message success:(BOOL)success;
// Shows Command Mode inside the host (SpringBoard overlay / preview harness:
// on the rotated overlay canvas). When nil, the home screen presents it full
// screen itself (standalone app).
@property (nonatomic, copy, nullable) void (^presentCommandMode)(void);
// SpringBoard overlay only: YES while a decoration (HCG Halo's border) is attached to the panel's border
// host. Nexus's own observation, used for the "Active" state; nil elsewhere.
@property (nonatomic, copy, nullable) BOOL (^borderDecorationAttached)(void);
// "Use HCG Halo border" (jailbreak package only; nil in the standalone app): current status, and a switch
// that asks HCG Halo's own API to turn its panel border on or off.
@property (nonatomic, copy, nullable) HCGHaloBorderStatus *_Nonnull (^haloBorderStatus)(void);
@property (nonatomic, copy, nullable) BOOL (^setHaloBorderEnabled)(BOOL enabled, NSString *_Nullable *_Nullable error);
@property (nonatomic, readonly) BOOL insideOverlay;                  // closePanel != nil
// YES only where the system-wide edge handle and overlay actually exist
// (SpringBoard overlay, Settings bundle, preview simulation). NO in the
// standalone app, which must not present overlay controls as operational.
@property (nonatomic, readonly) BOOL overlayControlsOperational;
@property (nonatomic, readonly) BOOL isStandaloneApp;
@end

// Presents an error with its recovery suggestion as an accessible alert.
FOUNDATION_EXPORT void HCGPresentError(UIViewController *presenter, NSError *error, UIAlertAction *_Nullable extraAction);

NS_ASSUME_NONNULL_END
