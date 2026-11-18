#import <Foundation/Foundation.h>
#import "HCGKeyValueStore.h"
#import "HCGAction.h"

NS_ASSUME_NONNULL_BEGIN

// Store key holding the App Library: { "items": [action dictionaries], "favourites": [identifiers] }.
FOUNDATION_EXPORT NSString *const HCGStoreKeyAppLibrary;
FOUNDATION_EXPORT const NSUInteger HCGAppLibraryMaxItems;

// The Apps section: ordinary app and link shortcuts in one ordered list, with
// favourites. Workspaces pick their Overview quick actions from it.
// Only HCGActionKindApp and HCGActionKindURL items are accepted; HCG products
// live in the HCG Products section instead.
@interface HCGAppLibrary : NSObject {
    id<HCGKeyValueStore> _backingStore;
    NSMutableArray *_items;
    NSMutableArray *_favourites;
    NSUInteger _droppedOnLoad;
}
@property (nonatomic, readonly) NSArray<HCGAction *> *items;
@property (nonatomic, readonly) NSArray<NSString *> *favouriteIdentifiers;
@property (nonatomic, readonly) NSUInteger droppedOnLoad;  // malformed or duplicate entries skipped

- (instancetype)initWithStore:(id<HCGKeyValueStore>)store;
- (void)load;
- (BOOL)save;

// Same kind and same target (case-insensitive) means the same shortcut.
+ (NSString *)keyForAction:(HCGAction *)action;
+ (BOOL)acceptsKind:(HCGActionKind)kind;

- (nullable HCGAction *)itemWithIdentifier:(NSString *)identifier;
- (nullable HCGAction *)itemMatchingAction:(HCGAction *)action;   // by key
- (NSUInteger)indexOfItemWithIdentifier:(NSString *)identifier;

// Validates, rejects duplicates and persists. Returns the stored item.
- (nullable HCGAction *)addItem:(HCGAction *)action error:(NSError *_Nullable *_Nullable)error;
// Adds without saving when not already present (by key); returns the stored item. Used by migration.
- (nullable HCGAction *)mergeItem:(HCGAction *)action;
- (BOOL)removeItemWithIdentifier:(NSString *)identifier error:(NSError *_Nullable *_Nullable)error;
- (BOOL)moveItemFromIndex:(NSUInteger)from toIndex:(NSUInteger)to error:(NSError *_Nullable *_Nullable)error;

- (BOOL)isFavourite:(NSString *)identifier;
- (BOOL)setFavourite:(BOOL)favourite forItem:(NSString *)identifier error:(NSError *_Nullable *_Nullable)error;

// Case-insensitive match on title and target, library order kept.
- (NSArray<HCGAction *> *)itemsMatchingQuery:(nullable NSString *)query favouritesOnly:(BOOL)favouritesOnly;
- (void)removeAll;
@end

NS_ASSUME_NONNULL_END
