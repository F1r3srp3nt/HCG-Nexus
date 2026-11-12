#import <Foundation/Foundation.h>
#import "HCGWorkspace.h"

NS_ASSUME_NONNULL_BEGIN

// Starting shortcut sets. Presets only organise shortcuts: they do not alter
// Focus/notification policy, keep other apps' state, or grant permissions.
// Shortcuts use stock Apple bundle identifiers plus HCG integrations; any of
// them may be missing on a given device and then report "App not installed".
@interface HCGWorkspacePresets : NSObject
+ (NSArray<NSString *> *)presetIdentifiers; // command, developer, studio, infrastructure
+ (NSString *)displayNameForPreset:(NSString *)preset;
+ (NSString *)summaryForPreset:(NSString *)preset;
+ (NSString *)symbolNameForPreset:(NSString *)preset;
// New workspace with fresh identifiers. Unknown preset => empty custom workspace.
+ (HCGWorkspace *)workspaceForPreset:(NSString *)preset name:(nullable NSString *)name;
@end

NS_ASSUME_NONNULL_END
