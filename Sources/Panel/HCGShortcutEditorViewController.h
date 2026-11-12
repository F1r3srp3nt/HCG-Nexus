#import "HCGPanelTableViewController.h"

NS_ASSUME_NONNULL_BEGIN

// Form for a new shortcut: App (bundle identifier), Link (URL) or HCG
// integration. Validates with HCGAction before saving and shows inline,
// VoiceOver-announced errors.
@interface HCGShortcutEditorViewController : HCGPanelTableViewController
- (instancetype)initWithContext:(HCGPanelContext *)context workspaceIdentifier:(NSString *)identifier;
@end

NS_ASSUME_NONNULL_END
