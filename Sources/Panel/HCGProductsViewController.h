#import "HCGPanelTableViewController.h"

NS_ASSUME_NONNULL_BEGIN

// HCG Products: one entry per HCG product with installation (installed / not installed /
// unable to determine / no iPhone app), what this build can open, the validated routes,
// and — separately — the account state, which Nexus never infers from installation.
@interface HCGProductsViewController : HCGPanelTableViewController
@end

NS_ASSUME_NONNULL_END
