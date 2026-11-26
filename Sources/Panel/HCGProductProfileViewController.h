#import "HCGPanelTableViewController.h"

NS_ASSUME_NONNULL_BEGIN

// One registry product: overview, install status and version, connection status and last successful communication,
// capabilities, connection methods, permissions, how to connect, troubleshooting, development requirements, roadmap
// (current state with evidence, history, and historical device validations kept separately) and where the facts
// were verified. Actions appear only when they are actually supported: open the app and its screens (through the
// existing HIP page), the product's registered website, Check now (a read-only request to a registry endpoint),
// Package Trust Center, Connected Devices (standalone app), System Tester import and LifeOS export.
@interface HCGProductProfileViewController : HCGPanelTableViewController
- (instancetype)initWithContext:(HCGPanelContext *)context entryID:(NSString *)entryID;
@end

NS_ASSUME_NONNULL_END
