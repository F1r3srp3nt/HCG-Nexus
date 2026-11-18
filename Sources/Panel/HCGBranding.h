#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

// Bundled HCG artwork (Resources/Branding/README.md). Looked up in the app's
// asset catalog / bundle (standalone app, preview harness) and in the tweak's
// support folder (<install prefix>/Library/Application Support/HCGNexus).
// Missing files return nil; callers fall back to typography, never to
// invented artwork.
@interface HCGBranding : NSObject
+ (nullable UIImage *)hcgLogo;       // official chrome HCG logo
+ (nullable UIImage *)nexusEmblem;   // HCG Nexus app-icon emblem
+ (nullable UIImage *)nexusBanner;   // official HCG Nexus banner — not supplied yet
// Paths searched for the tweak, for diagnostics.
+ (NSArray<NSString *> *)supportDirectories;
@end

NS_ASSUME_NONNULL_END
