#import "HCGPanelTableViewController.h"

NS_ASSUME_NONNULL_BEGIN

// One HCG product in the HCG Ecosystem dashboard: status (installed, version and build, compatibility, health,
// integration, updates), its navigation shortcuts, its current settings (read-only), its capabilities (verified on a
// device / available / planned / unavailable) and identifiers. HCG Halo's page also carries the existing
// "Use HCG Halo border" switch, which goes through HCG Halo's own HaloNexusControl.
@interface HCGProductDetailViewController : HCGPanelTableViewController
- (instancetype)initWithContext:(HCGPanelContext *)context productID:(NSString *)productID;
@end

NS_ASSUME_NONNULL_END
