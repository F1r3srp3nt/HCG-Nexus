#import <UIKit/UIKit.h>
#import "HCGPanelContext.h"

NS_ASSUME_NONNULL_BEGIN

// Root panel screen (layout 2): HCG logo header, a section bar (Overview, Workspaces,
// Tools, HCG Products, Devices, Apps, Account) and the selected section below it.
// Success/failure feedback from any section is shown as a short toast.
@interface HCGPanelHomeViewController : UIViewController
- (instancetype)initWithContext:(HCGPanelContext *)context;
- (void)reloadContent;
- (void)resetTransientState;
- (nullable id)accessibilityFocusElement;
- (void)selectSection:(NSInteger)section;
@property (nonatomic, readonly) NSInteger selectedSection;
// The overlay calls these when the panel opens/closes; decorative motion and
// battery monitoring run only in between.
- (void)panelDidAppear;
- (void)panelDidDisappear;
@end

NS_ASSUME_NONNULL_END
