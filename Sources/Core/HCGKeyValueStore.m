#import "HCGKeyValueStore.h"

@implementation HCGMemoryKeyValueStore

@synthesize flushCount = _flushCount;

- (instancetype)init {
    if ((self = [super init])) {
        _storage = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (id)objectForKey:(NSString *)key {
    return [_storage objectForKey:key];
}

- (void)setObject:(id)object forKey:(NSString *)key {
    if (object) {
        // Deep-copy through a property-list round trip so tests catch
        // non-plist values exactly like CFPreferences would.
        NSError *error = nil;
        NSData *data = [NSPropertyListSerialization dataWithPropertyList:object
                                                                  format:NSPropertyListBinaryFormat_v1_0
                                                                 options:0
                                                                   error:&error];
        if (!data) {
            [NSException raise:NSInvalidArgumentException
                        format:@"Value for %@ is not a property list: %@", key, error];
        }
        id copy = [NSPropertyListSerialization propertyListWithData:data
                                                            options:NSPropertyListImmutable
                                                             format:NULL
                                                              error:NULL];
        [_storage setObject:copy forKey:key];
    } else {
        [_storage removeObjectForKey:key];
    }
}

- (void)reload {
}

- (BOOL)flush {
    _flushCount += 1;
    return YES;
}

@end
