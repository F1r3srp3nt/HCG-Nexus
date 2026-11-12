#import <UIKit/UIKit.h>
#import "HCGPanelContext.h"

NS_ASSUME_NONNULL_BEGIN

// Root panel screen: HCG header, workspace chips, search, shortcuts, recent
// actions, integration status, and entry points to Workspaces and Settings.
@interface HCGPanelHomeViewController : UIViewController
- (instancetype)initWithContext:(HCGPanelContext *)context;
- (void)reloadContent;
- (void)resetTransientState;
- (nullable id)accessibilityFocusElement;
@end

NS_ASSUME_NONNULL_END
