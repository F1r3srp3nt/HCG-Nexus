#import "HCGPanelTableViewController.h"
#import "HCGInterchange.h"

NS_ASSUME_NONNULL_BEGIN

// HCG Ecosystem dashboard (the panel's ecosystem section): device overview, one card per HCG product with its
// version, state, compatibility, capabilities and updates, integration diagnostics and the activity history.
// Facts come from the HCG Interchange registry and a read-only scan (HCGEcosystemScanner); nothing is changed.
@interface HCGProductsViewController : HCGPanelTableViewController
- (void)showProductWithID:(NSString *)productID;
@end

FOUNDATION_EXPORT UIColor *HCGEcosystemColorForAvailability(HCGHIPAvailability availability);

NS_ASSUME_NONNULL_END
