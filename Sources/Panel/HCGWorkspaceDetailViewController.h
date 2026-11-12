#import "HCGPanelTableViewController.h"

NS_ASSUME_NONNULL_BEGIN

// Shortcuts inside one workspace: add, reorder, delete; rename; make active.
@interface HCGWorkspaceDetailViewController : HCGPanelTableViewController
- (instancetype)initWithContext:(HCGPanelContext *)context workspaceIdentifier:(NSString *)identifier;
@end

NS_ASSUME_NONNULL_END
