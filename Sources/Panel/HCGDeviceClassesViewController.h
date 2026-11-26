#import "HCGPanelTableViewController.h"

NS_ASSUME_NONNULL_BEGIN

// Connected devices through HCG System Tester, the hardware communication authority. Nexus imports System Tester's
// exported inventory (hcg.systemtester.inventory/1) and shows device classes: what System Tester can identify today,
// which adapters exist, what is missing, instructions and the safety rule. Nexus never talks to a device itself and
// never offers vehicle, robot or industrial control or firmware changes.
@interface HCGDeviceClassesViewController : HCGPanelTableViewController
@end

NS_ASSUME_NONNULL_END
