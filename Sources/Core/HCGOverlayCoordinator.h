#import <Foundation/Foundation.h>
#import "HCGSettings.h"
#import "HCGPanelStateMachine.h"
#import "HCGOverlayPolicy.h"

NS_ASSUME_NONNULL_BEGIN

// Implemented by the UIKit overlay (SpringBoard window or preview harness view)
// and by the fake host in Tests/Host.
@protocol HCGOverlayHost <NSObject>
// Creates the window/handle/panel container and installs gesture recognisers.
// The coordinator calls this at most once, and only after Nexus is enabled
// while the system allows presentation.
- (void)overlayInstall;
// Shows/hides the overlay. Hidden means no window on screen and no touch
// interception at all.
- (void)overlaySetVisible:(BOOL)visible;
- (void)overlayApplySettings:(HCGSettings *)settings;
// Starts a panel transition. The host must call
// -[HCGOverlayCoordinator panelTransitionFinished:] with the same generation
// when the transition completes (immediately when not animated).
- (void)overlayBeginPanelTransition:(HCGPanelCommand)command generation:(NSUInteger)generation animated:(BOOL)animated;
// Removes the panel immediately with no animation (lock / disable).
- (void)overlayForceHidePanel;
@end

@interface HCGOverlayCoordinator : NSObject {
    __unsafe_unretained id<HCGOverlayHost> _host;
    HCGSettings *_settings;
    HCGSystemSignals _signals;
    HCGPanelStateMachine *_stateMachine;
    BOOL _installed;
    BOOL _visible;
    BOOL _reduceMotion;
    NSUInteger _installCount;
    NSUInteger _rejectedActivations;
}
// The host owns the coordinator; the back-reference is unretained.
- (instancetype)initWithHost:(id<HCGOverlayHost>)host;

@property (nonatomic, readonly) HCGSettings *settings;
@property (nonatomic, readonly) HCGSystemSignals signals;
@property (nonatomic, readonly) HCGPanelStateMachine *stateMachine;
@property (nonatomic, readonly) BOOL installed;
@property (nonatomic, readonly) BOOL visible;
@property (nonatomic, readonly) NSUInteger installCount;
@property (nonatomic, readonly) NSUInteger rejectedActivations;
@property (nonatomic) BOOL reduceMotion;              // UIAccessibilityIsReduceMotionEnabled()
@property (nonatomic, readonly) BOOL animationsAllowed;

- (void)updateSettings:(HCGSettings *)settings;
- (void)updateSignals:(HCGSystemSignals)signals;
// Re-applies the policy (e.g. after rotation the host re-lays out itself).
- (void)reevaluate;

// User intents. Return NO when ignored because Nexus is unavailable.
- (BOOL)handleActivated;      // tap / swipe on the edge handle
- (void)requestClose;         // close button, outside tap, escape gesture
- (void)requestCloseImmediately; // e.g. after launching an app

- (void)panelTransitionFinished:(NSUInteger)generation;

- (NSDictionary *)diagnostics;
@end

NS_ASSUME_NONNULL_END
