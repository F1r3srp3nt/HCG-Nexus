#import "HCGPanelTableViewController.h"

NS_ASSUME_NONNULL_BEGIN

// Account: HCG main-site (HCG Connect) sign-in state, kept separate from owning
// Nexus and from permission to use connected services. Sign-in exists only in the
// standalone app (HCGPanelContext.accountProvider); elsewhere this screen says so.
// Nothing here simulates a signed-in state.
@interface HCGAccountViewController : HCGPanelTableViewController
@end

NS_ASSUME_NONNULL_END
