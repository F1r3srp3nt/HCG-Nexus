#import <Foundation/Foundation.h>
#import "HCGHaloBorderLink.h"

NS_ASSUME_NONNULL_BEGIN

// Platform side of "Use HCG Halo border" (jailbreak package only: SpringBoard tweak and Settings bundle).
//
// Reads what is installed (HCG Halo's Settings bundle Info.plist), Halo's documented preferences and
// status domains, and Nexus's own HaloBorder.plist; switches the panel border only through HCG Halo's
// API (HaloNexusControl, contract HCGHaloNexusControl 1). Nexus never writes Halo's preferences itself
// and contains none of Halo's rendering code. See docs/HALO-BORDER.md.
@interface HCGHaloBridge : NSObject

// <jbroot> derived from Nexus's own loaded image (tweak dylib or Settings bundle); nil elsewhere
// (standalone app, preview harness), where HCG Halo does not apply.
+ (nullable NSString *)jailbreakRoot;

// Snapshot of everything Nexus can know. `attached` and `visible` are Nexus's own observation of its
// panel (border host has a decoration; panel shown).
+ (HCGHaloBorderFacts *)factsWithBorderAttached:(BOOL)attached panelVisible:(BOOL)visible;
+ (HCGHaloBorderStatus *)statusWithBorderAttached:(BOOL)attached panelVisible:(BOOL)visible;

// Asks HCG Halo to turn its panel border on or off. NO with a reason when Halo or its API is missing,
// of an unknown version, or refuses (e.g. kill switch). Halo decides how its own settings change and
// never turns on its screen-edge effects for this.
+ (BOOL)setPanelBorderEnabled:(BOOL)enabled error:(NSString *_Nullable *_Nullable)error;

// Darwin notification asking SpringBoard's HCG Halo to rewrite its status (payload-free).
+ (void)requestHaloStatus;

@end

NS_ASSUME_NONNULL_END
