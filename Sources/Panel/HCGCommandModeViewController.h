#import <UIKit/UIKit.h>
#import "HCGPanelContext.h"

NS_ASSUME_NONNULL_BEGIN

// Command Mode: a translucent control-centre view inside Nexus.
//
// * A restrained scrim dims what is behind it (30%; nearly opaque with Reduce
//   Transparency). Opening and closing are instant with Reduce Motion or when
//   animations are off in HCG Nexus settings.
// * Device status from public iOS APIs (HCGDeviceStatusMonitor), the active
//   workspace's shortcuts (the existing workspace store) and HCG integration
//   connection states (the existing integrations model, mapped by
//   HCGCommandModeStatus in Sources/Core).
// * Decoration (scanlines, rings, rim light) is static. Nothing animates and
//   nothing claims a live service, session or sync.
//
// Hosts: the SpringBoard overlay and the preview harness embed it on the
// overlay canvas (HCGOverlayController), so it follows the canvas's manual
// rotation; the standalone app presents it full screen.
@interface HCGCommandModeViewController : UIViewController
- (instancetype)initWithContext:(HCGPanelContext *)context;

// Called when the user closes Command Mode (close button, scrim tap, VoiceOver
// escape). When nil, the controller dismisses itself if it was presented.
@property (nonatomic, copy, nullable) void (^dismissHandler)(void);

// Hosts that rotate their canvas themselves pass the safe-area insets of the
// rotated canvas here; otherwise the view's own safe area is used.
@property (nonatomic) BOOL usesHostContentInsets;
@property (nonatomic) UIEdgeInsets hostContentInsets;

- (void)reloadContent;
// Device status updates run only while Command Mode is on screen; hosts call
// -stopUpdates when they remove it (also called from viewDidDisappear).
- (void)startUpdates;
- (void)stopUpdates;
- (nullable id)accessibilityFocusElement;
@end

NS_ASSUME_NONNULL_END
