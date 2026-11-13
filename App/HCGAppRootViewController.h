#import <UIKit/UIKit.h>
#import "HCGNexusModel.h"
#import "HCGPanelContext.h"

NS_ASSUME_NONNULL_BEGIN

// Root of the standalone app: obsidian backdrop, brushed-chrome panel and the
// shared HCG Nexus panel screens (home, workspaces, shortcuts, settings) in
// HCGPanelModeStandaloneApp. On iPad the panel is centred at a readable width.
@interface HCGAppRootViewController : UIViewController
- (instancetype)initWithModel:(HCGNexusModel *)model;
@property (nonatomic, readonly) HCGPanelContext *context;
@end

NS_ASSUME_NONNULL_END
