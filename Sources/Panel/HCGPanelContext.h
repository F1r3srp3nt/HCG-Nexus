#import <UIKit/UIKit.h>
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
