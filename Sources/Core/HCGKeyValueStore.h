#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// Storage abstraction. Values must be property-list types.
// Device: HCGPreferencesKeyValueStore (CFPreferences, Sources/Platform).
// Preview harness: NSUserDefaults-backed store. Tests: HCGMemoryKeyValueStore.
@protocol HCGKeyValueStore <NSObject>
- (nullable id)objectForKey:(NSString *)key;
- (void)setObject:(nullable id)object forKey:(NSString *)key;
// Re-reads values written by other processes where the backend supports it.
- (void)reload;
// Flushes pending writes. Returns NO if the backend reported a failure.
- (BOOL)flush;
@end

@interface HCGMemoryKeyValueStore : NSObject <HCGKeyValueStore> {
    NSMutableDictionary *_storage;
    NSUInteger _flushCount;
}
@property (nonatomic, readonly) NSUInteger flushCount;
@end

NS_ASSUME_NONNULL_END
