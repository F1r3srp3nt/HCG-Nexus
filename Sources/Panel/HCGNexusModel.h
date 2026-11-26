#import <Foundation/Foundation.h>
#import "HCGCore.h"
#import "HCGLauncher.h"

NS_ASSUME_NONNULL_BEGIN

// Posted (in-process, main thread) whenever settings, workspaces or recents
// change, whether locally or after a reload triggered by another process.
FOUNDATION_EXPORT NSNotificationName const HCGNexusModelDidChangeNotification;

// Shared façade over the Core stores. Used by the overlay panel (SpringBoard),
// the Settings bundle (Preferences.app) and the preview harness.
@interface HCGNexusModel : NSObject
- (instancetype)initWithStore:(id<HCGKeyValueStore>)store
                     notifier:(nullable id<HCGChangeNotifier>)notifier
                     launcher:(nullable id<HCGLauncher>)launcher NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

@property (nonatomic, readonly) id<HCGKeyValueStore> store;
@property (nonatomic, readonly, nullable) id<HCGLauncher> launcher;
@property (nonatomic, readonly) HCGWorkspaceStore *workspaceStore;
@property (nonatomic, readonly) HCGRecents *recents;
@property (nonatomic, readonly) HCGAppLibrary *appLibrary;
// Outcome of the layout-2 migration on the most recent load, and how many
// Apps entries it created (shown once on the Overview with an Undo hint).
@property (nonatomic, readonly) HCGLayoutMigrationOutcome lastMigrationOutcome;
@property (nonatomic, readonly) NSUInteger lastMigrationImported;
@property (nonatomic, readonly) HCGSettings *settings; // copy

// Re-reads everything from the backing store (cheap preference read).
- (void)reload;
// Persists and broadcasts.
- (void)saveSettings:(HCGSettings *)settings;
- (void)resetSettings;
// Call after any HCGWorkspaceStore mutation (the store already persisted).
- (void)workspacesDidChange;
- (void)clearRecents;
// The HCG Ecosystem activity history, newest first (HCGEcosystemActivity entries).
- (NSArray<NSDictionary *> *)ecosystemActivity;
- (void)recordEcosystemActivity:(NSString *)text productID:(nullable NSString *)productID;
- (void)clearEcosystemActivity;
// Package Trust Center: the repositories you check, and the key fingerprints YOU pinned.
- (NSArray<HCGTrustedRepository *> *)trustedRepositories;
- (void)saveTrustedRepositories:(NSArray<HCGTrustedRepository *> *)repositories;
// HCG Nexus Command Center (docs/COMMAND-CENTER.md). Stored in Nexus's own preferences; nothing is sent anywhere.
// The ecosystem registry: built in, plus an imported update (narrowing only) when one was imported.
- (HCGRegistry *)ecosystemRegistry;
// Validates and stores an hcg.nexus.registry/1 update (at most 256 KB). NO with `error` when refused.
- (BOOL)importRegistryUpdate:(NSData *)data error:(NSString *_Nullable *_Nullable)error;
- (void)removeRegistryUpdate;
- (BOOL)hasRegistryUpdate;
// The central registry snapshot (docs/CENTRAL-REGISTRY.md): current and previous, for rollback.
- (nullable HCGCentralSnapshot *)centralSnapshot;
- (nullable HCGCentralSnapshot *)previousCentralSnapshot;
// Stores a validated snapshot as current; the old current becomes previous (unless the version is unchanged).
- (void)saveCentralSnapshot:(HCGCentralSnapshot *)snapshot;
- (BOOL)revertCentralSnapshot;     // swap current and previous
- (void)clearCentralSnapshots;     // built-in registry only
// Two-way reads Nexus made (HCGConnectionLedger), newest first.
- (NSArray<NSDictionary *> *)connectionLedger;
- (void)recordConnectionForProduct:(NSString *)productID method:(NSString *)method success:(BOOL)success text:(NSString *)text;
- (NSArray<NSString *> *)favoriteProductIDs;
- (void)setFavorite:(BOOL)favorite forProduct:(NSString *)productID;
- (NSArray<NSString *> *)expandedCategoryIDs;
- (void)setCategory:(NSString *)categoryID expanded:(BOOL)expanded;
- (NSDictionary *)roadmapStore;
- (void)saveRoadmapStore:(NSDictionary *)store;
- (NSDictionary *)lifeOSExported;
- (void)markLifeOSExport:(HCGLifeOSExport *)export_;
// HCG System Tester inventory (validated; at most 256 KB kept).
- (nullable HCGDeviceInventory *)deviceInventory;
- (BOOL)importDeviceInventory:(NSData *)data error:(NSString *_Nullable *_Nullable)error;
- (void)removeDeviceInventory;
// Call after any HCGAppLibrary mutation (the library already persisted).
- (void)appsDidChange;
// Tools › Import Workspace Shortcuts: returns how many entries were added.
- (NSUInteger)importShortcutsFromWorkspaces;
// Tools › Restore Previous Layout: puts the pre-0.3 workspaces back and empties Apps.
- (BOOL)restorePreviousLayout:(NSError *_Nullable *_Nullable)error;
- (BOOL)hasLayoutBackup;

- (NSArray<HCGIntegrationStatus *> *)integrationStatuses;
- (HCGIntegrationStatus *)statusForIntegration:(NSString *)identifier;
@end

NS_ASSUME_NONNULL_END
