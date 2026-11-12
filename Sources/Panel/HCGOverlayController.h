#import <UIKit/UIKit.h>
#import "HCGCore.h"
#import "HCGNexusModel.h"

NS_ASSUME_NONNULL_BEGIN

// Where the overlay lives. SpringBoard: a dedicated, non-secure UIWindow that
// is never shown on the lock screen. Preview harness: a child view controller
// on top of a mock "current app".
@protocol HCGOverlayEnvironment <NSObject>
@property (nonatomic, readonly) NSString *environmentName;
@property (nonatomic, readonly) BOOL isPreview;
// Called exactly once. Must embed `containerViewController` (window root VC on
// device, child VC in the harness).
- (void)overlayInstallContainerViewController:(UIViewController *)containerViewController;
- (void)overlaySetContainerVisible:(BOOL)visible;
// YES when the container does not rotate with the frontmost app, so the
// overlay rotates its canvas itself (SpringBoard on iPhone).
- (BOOL)overlayUsesManualRotation;
- (HCGInterfaceOrientation)overlayInterfaceOrientation;
// Text entry in the panel needs keyboard focus; restore it afterwards.
- (void)overlayTextInputActive:(BOOL)active;
// Number of overlay windows that currently exist (diagnostics; must be <= 1).
- (NSUInteger)overlayWindowCount;
@end

// Owns the handle, dimming layer and panel; implements HCGOverlayHost so all
// enable/lock/transition rules live in the (host-tested) HCGOverlayCoordinator.
@interface HCGOverlayController : NSObject <HCGOverlayHost>
- (instancetype)initWithModel:(HCGNexusModel *)model environment:(id<HCGOverlayEnvironment>)environment;
@property (nonatomic, readonly) HCGOverlayCoordinator *coordinator;
@property (nonatomic, readonly) HCGNexusModel *model;

// Pulls settings from the model and applies them (enable/disable is immediate).
- (void)applyModelSettings;
- (void)updateSystemSignals:(HCGSystemSignals)signals;
// Call when the frontmost interface orientation may have changed.
- (void)interfaceOrientationMayHaveChanged;
// Called synchronously before a handle activation is evaluated, so the host
// can re-read lock / cover-sheet state that has no change notification.
@property (nonatomic, copy, nullable) void (^beforeActivation)(void);

- (NSUInteger)installedGestureRecognizerCount;
- (NSDictionary *)diagnostics;

// Test/harness hooks.
- (BOOL)isPanelOnScreen;
- (BOOL)isHandleOnScreen;
- (void)simulateHandleActivation;
- (void)simulateOutsideTap;
@end

NS_ASSUME_NONNULL_END
