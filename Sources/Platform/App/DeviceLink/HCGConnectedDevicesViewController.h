#import "HCGPanelTableViewController.h"
#import "HCGLinkTypes.h"

NS_ASSUME_NONNULL_BEGIN

// Connected Devices (HCG Device Link) — STANDALONE APP ONLY.
//
// HCG Connect account; this device (LOCAL) with its key fingerprint; pairing
// with an HCG Server from an hcg1-… invitation; paired devices (REMOTE) with
// presence and advertised capabilities; shared reports; pending approvals
// (always empty: execution is disabled); removing this device.
//
// Nexus contacts the server only while this screen is visible and the app is
// active. With a nil service (a build without the Swift client) the screen
// says so instead of pretending to work.
@interface HCGConnectedDevicesViewController : HCGPanelTableViewController
- (instancetype)initWithContext:(HCGPanelContext *)context service:(nullable id<HCGLinkServicing>)service;
@property (nonatomic, readonly, nullable) id<HCGLinkServicing> service;
@end

NS_ASSUME_NONNULL_END
