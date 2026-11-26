#import "HCGPanelTableViewController.h"

NS_ASSUME_NONNULL_BEGIN

// The ecosystem roadmap: every product by roadmap state (with the evidence for it), every development gap, and
// "Export to HCG LifeOS": a lifeos.v1 import file with stable IDs. Only gaps not exported before are included;
// nothing is sent, and no XP is claimed (LifeOS awards none for imports).
@interface HCGRoadmapViewController : HCGPanelTableViewController
@end

// The registry itself: version, source, categories, problems; import or remove a registry update (standalone app and
// Settings only). An update can only narrow what Nexus offers.
@interface HCGRegistryInfoViewController : HCGPanelTableViewController
@end

NS_ASSUME_NONNULL_END
