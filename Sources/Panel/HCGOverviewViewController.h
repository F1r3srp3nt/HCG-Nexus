#import "HCGPanelTableViewController.h"

NS_ASSUME_NONNULL_BEGIN

// Overview: Nexus banner (or brand header when no banner is bundled), the active
// workspace with one-tap switching, that workspace's quick actions, genuine device
// facts, and truthful account / Connected Devices / HCG Products summaries.
@interface HCGOverviewViewController : HCGPanelTableViewController
- (void)panelDidAppear;     // starts the subtle glow (if motion is allowed) and battery monitoring
- (void)panelDidDisappear;  // stops both
@end

NS_ASSUME_NONNULL_END
