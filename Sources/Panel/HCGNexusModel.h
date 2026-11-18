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
