#import <Foundation/Foundation.h>
#import "HCGKeyValueStore.h"
#import "HCGWorkspaceStore.h"
#import "HCGAppLibrary.h"

NS_ASSUME_NONNULL_BEGIN

// Layout 2 (HCG Nexus 0.3): Overview / Workspaces / Tools / HCG Products /
// Connected Devices / Apps / Account replace the single list of per-workspace
// shortcuts.
//
// The migration is additive and reversible:
//   * the stored workspaces and active workspace are backed up verbatim first;
//   * every workspace keeps all of its shortcuts;
//   * app and link shortcuts from all workspaces are copied into Apps
//     (de-duplicated by target, active workspace first);
//   * each workspace gets up to four quick actions (its first app/link shortcuts)
//     and default tools for its preset.
// Restoring writes the backup back unchanged, empties Apps and records that the
// new layout was declined, so it is not silently applied again.
FOUNDATION_EXPORT NSString *const HCGStoreKeyLayoutVersion;
FOUNDATION_EXPORT NSString *const HCGStoreKeyLayoutBackup;
FOUNDATION_EXPORT NSString *const HCGStoreKeyLayoutDeclined;
FOUNDATION_EXPORT const NSInteger HCGCurrentLayoutVersion; // 2

typedef NS_ENUM(NSInteger, HCGLayoutMigrationOutcome) {
    HCGLayoutMigrationAlreadyCurrent = 0,
    HCGLayoutMigrationDeclined = 1,       // the user restored the previous layout earlier
    HCGLayoutMigrationMigrated = 2,
};

@interface HCGLayoutMigration : NSObject
+ (NSInteger)layoutVersionInStore:(id<HCGKeyValueStore>)store;
+ (BOOL)hasBackupInStore:(id<HCGKeyValueStore>)store;
// Call after both stores are loaded. *imported receives the number of Apps entries created.
+ (HCGLayoutMigrationOutcome)migrateStore:(id<HCGKeyValueStore>)store
                           workspaceStore:(HCGWorkspaceStore *)workspaces
                                  library:(HCGAppLibrary *)library
                                 imported:(NSUInteger *_Nullable)imported;
// Tools › Import Workspace Shortcuts. Returns how many new Apps entries were added (saved).
+ (NSUInteger)importShortcutsFromWorkspaces:(HCGWorkspaceStore *)workspaces intoLibrary:(HCGAppLibrary *)library;
// Tools › Restore Previous Layout. Reload the workspace store and library afterwards.
+ (BOOL)restorePreviousLayoutInStore:(id<HCGKeyValueStore>)store error:(NSError *_Nullable *_Nullable)error;
// Re-applies layout 2 after a restore (clears the declined flag; the backup is kept).
+ (void)clearDeclinedInStore:(id<HCGKeyValueStore>)store;
@end

NS_ASSUME_NONNULL_END
