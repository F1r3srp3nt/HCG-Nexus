#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// HCG Nexus Portal interface, version 1 — docs/INTERCHANGE.md ("Opening Nexus").
//
// The interface HCG Portal (com.hakmicapitalgroup.portal) already calls to open this panel, exactly as HCG Portal
// defines it (HCG-Jailbreak-Research HCGPortal/src/PortalCompanions.{h,m}, docs/INTEGRATIONS.md §1):
//   * In-process, SpringBoard, main thread. Looked up by name; no link-time dependency either way.
//   * +interfaceVersion is 1. +activeInterface is nil while Nexus is disabled or has not built its panel.
//   * -canOpenPanel: enabled, "Let HCG Apps Open Nexus" on, panel built.
//   * -openPanelFromSource:completion: opens the panel at the HCG Ecosystem dashboard. Refused while the iPhone is
//     locked: Nexus waits up to 3 s for its own lock monitor to report unlocked, then opens or refuses. The
//     completion is called exactly once, on the main thread. `source` is a fixed identifier ("hcg-portal");
//     no argument carries user data, and nothing but navigation happens.
// HCG apps in other processes use the Darwin requests in HCGInterchange.h, which end in the same code path.

#define HCG_NEXUS_PORTAL_INTERFACE_VERSION 1

typedef void (^HCGNexusPortalOpenCompletion)(BOOL opened, NSString *_Nullable reason);

@interface HCGNexusPortalInterface : NSObject
+ (NSInteger)interfaceVersion;
+ (nullable instancetype)activeInterface;
- (BOOL)canOpenPanel;
- (void)openPanelFromSource:(NSString *)source completion:(HCGNexusPortalOpenCompletion)completion;

#pragma mark Nexus-internal (HCGOverlayController only)
- (instancetype)initWithCanOpen:(BOOL (^)(void))canOpen
                           open:(void (^)(NSString *source, HCGNexusPortalOpenCompletion completion))open;
+ (void)setActiveInterface:(nullable HCGNexusPortalInterface *)interface;
@end

NS_ASSUME_NONNULL_END
