#import "HCGPanelTableViewController.h"

NS_ASSUME_NONNULL_BEGIN

// In-panel settings: enable/disable, handle position & visibility, motion and
// haptics, integrations, workspace management, reset, diagnostics & version.
@interface HCGPanelSettingsViewController : HCGPanelTableViewController
@end

FOUNDATION_EXPORT NSString *HCGBuildDescription(void);
// Section identifiers (HCGSettingsSection raw values) shown for a mode;
// exposed for regression tests.
FOUNDATION_EXPORT NSArray<NSNumber *> *HCGSettingsSectionsForMode(HCGPanelMode mode);

NS_ASSUME_NONNULL_END
