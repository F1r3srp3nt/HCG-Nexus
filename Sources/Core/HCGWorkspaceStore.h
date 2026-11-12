#import <Foundation/Foundation.h>
#import "HCGKeyValueStore.h"
#import "HCGWorkspace.h"

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString *const HCGStoreKeyWorkspaces;
FOUNDATION_EXPORT NSString *const HCGStoreKeyActiveWorkspace;
FOUNDATION_EXPORT NSString *const HCGStoreKeySchemaVersion;

FOUNDATION_EXPORT const NSUInteger HCGMaxWorkspaces;
FOUNDATION_EXPORT const NSUInteger HCGMaxActionsPerWorkspace;
FOUNDATION_EXPORT const NSUInteger HCGMaxWorkspaceNameLength;

// Local, login-free workspace persistence. Every mutating call validates its
// input, persists immediately and returns NO with an actionable error on
// failure. Not thread-safe: use from the main thread.
@interface HCGWorkspaceStore : NSObject {
    id<HCGKeyValueStore> _backingStore;
    NSMutableArray *_workspaces;
    NSString *_activeWorkspaceIdentifier;
    NSUInteger _droppedEntriesOnLoad;
    BOOL _seededOnLoad;
}
@property (nonatomic, readonly) NSArray<HCGWorkspace *> *workspaces;
@property (nonatomic, readonly, nullable) HCGWorkspace *activeWorkspace;
@property (nonatomic, readonly) NSUInteger droppedEntriesOnLoad; // malformed entries skipped
@property (nonatomic, readonly) BOOL seededOnLoad;               // first run created presets

- (instancetype)initWithStore:(id<HCGKeyValueStore>)store;

// Reads from the backing store. A missing key seeds the four presets; an
// existing empty list stays empty (the user deleted everything).
- (void)load;

- (nullable HCGWorkspace *)workspaceWithIdentifier:(NSString *)identifier;
- (NSUInteger)indexOfWorkspaceWithIdentifier:(NSString *)identifier;

- (nullable HCGWorkspace *)createWorkspaceNamed:(nullable NSString *)name
                                         preset:(NSString *)preset
                                          error:(NSError *_Nullable *_Nullable)error;
- (BOOL)renameWorkspace:(NSString *)identifier to:(NSString *)name error:(NSError *_Nullable *_Nullable)error;
- (BOOL)moveWorkspaceFromIndex:(NSUInteger)from toIndex:(NSUInteger)to error:(NSError *_Nullable *_Nullable)error;
- (BOOL)deleteWorkspace:(NSString *)identifier error:(NSError *_Nullable *_Nullable)error;
- (BOOL)setActiveWorkspace:(NSString *)identifier error:(NSError *_Nullable *_Nullable)error;

- (BOOL)addAction:(HCGAction *)action toWorkspace:(NSString *)identifier error:(NSError *_Nullable *_Nullable)error;
- (BOOL)removeAction:(NSString *)actionIdentifier fromWorkspace:(NSString *)identifier error:(NSError *_Nullable *_Nullable)error;
- (BOOL)moveActionInWorkspace:(NSString *)identifier fromIndex:(NSUInteger)from toIndex:(NSUInteger)to error:(NSError *_Nullable *_Nullable)error;

// Returns the trimmed name or nil with an error.
- (nullable NSString *)validatedName:(nullable NSString *)name excludingWorkspace:(nullable NSString *)identifier error:(NSError *_Nullable *_Nullable)error;
@end

NS_ASSUME_NONNULL_END
