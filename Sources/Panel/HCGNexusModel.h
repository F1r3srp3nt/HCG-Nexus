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
@property (nonatomic, readonly) HCGSettings *settings; // copy

// Re-reads everything from the backing store (cheap preference read).
- (void)reload;
// Persists and broadcasts.
- (void)saveSettings:(HCGSettings *)settings;
- (void)resetSettings;
// Call after any HCGWorkspaceStore mutation (the store already persisted).
- (void)workspacesDidChange;
- (void)clearRecents;

- (NSArray<HCGIntegrationStatus *> *)integrationStatuses;
- (HCGIntegrationStatus *)statusForIntegration:(NSString *)identifier;
@end

NS_ASSUME_NONNULL_END
