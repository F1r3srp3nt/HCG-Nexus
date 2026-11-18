#import "HCGPanelTableViewController.h"

NS_ASSUME_NONNULL_BEGIN

// Connected Devices where HCG Device Link does not run (jailbreak tweak, Settings
// bundle, preview harness). The standalone app shows the real Device Link screen
// instead (HCGPanelContext.connectedDevicesScreen). No mock devices or data.
@interface HCGDevicesInfoViewController : HCGPanelTableViewController
@end

NS_ASSUME_NONNULL_END
