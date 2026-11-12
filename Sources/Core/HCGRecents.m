#import "HCGRecents.h"

NSString *const HCGStoreKeyRecents = @"recents";
const NSUInteger HCGMaxRecents = 10;

static NSString *const kAction = @"action";
static NSString *const kDate = @"date";
static NSString *const kSucceeded = @"ok";
static NSString *const kMessage = @"message";

@implementation HCGRecentEntry
@synthesize action = _action;
@synthesize date = _date;
@synthesize succeeded = _succeeded;
@synthesize message = _message;
@end

@implementation HCGRecents

- (instancetype)initWithStore:(id<HCGKeyValueStore>)store {
    if ((self = [super init])) {
        _backingStore = store;
        _entries = [[NSMutableArray alloc] init];
    }
    return self;
}

- (NSArray *)entries {
    return [_entries copy];
}

- (void)load {
    [_backingStore reload];
    [_entries removeAllObjects];
    id stored = [_backingStore objectForKey:HCGStoreKeyRecents];
    if (![stored isKindOfClass:[NSArray class]]) return;
    NSUInteger i;
    for (i = 0; i < [stored count] && _entries.count < HCGMaxRecents; i++) {
        NSDictionary *dict = [stored objectAtIndex:i];
        if (![dict isKindOfClass:[NSDictionary class]]) continue;
        HCGAction *action = [HCGAction actionFromDictionary:[dict objectForKey:kAction] error:NULL];
        id when = [dict objectForKey:kDate];
        id ok = [dict objectForKey:kSucceeded];
        id message = [dict objectForKey:kMessage];
        if (!action || ![when isKindOfClass:[NSNumber class]] || ![ok isKindOfClass:[NSNumber class]]) continue;
        HCGRecentEntry *entry = [[HCGRecentEntry alloc] init];
        entry.action = action;
        entry.date = [NSDate dateWithTimeIntervalSince1970:[when doubleValue]];
        entry.succeeded = [ok boolValue];
        entry.message = [message isKindOfClass:[NSString class]] ? message : nil;
        [_entries addObject:entry];
    }
}

- (void)persist {
    NSMutableArray *list = [[NSMutableArray alloc] init];
    NSUInteger i;
    for (i = 0; i < _entries.count; i++) {
        HCGRecentEntry *entry = [_entries objectAtIndex:i];
        NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
        [dict setObject:[entry.action dictionaryRepresentation] forKey:kAction];
        [dict setObject:[NSNumber numberWithDouble:[entry.date timeIntervalSince1970]] forKey:kDate];
        [dict setObject:[NSNumber numberWithBool:entry.succeeded] forKey:kSucceeded];
        if (entry.message.length > 0) [dict setObject:entry.message forKey:kMessage];
        [list addObject:dict];
    }
    [_backingStore setObject:list forKey:HCGStoreKeyRecents];
    [_backingStore flush];
}

- (void)recordAction:(HCGAction *)action succeeded:(BOOL)succeeded message:(NSString *)message date:(NSDate *)date {
    NSUInteger i = 0;
    while (i < _entries.count) {
        HCGRecentEntry *existing = [_entries objectAtIndex:i];
        if ([existing.action.identifier isEqualToString:action.identifier]) {
            [_entries removeObjectAtIndex:i];
        } else {
            i++;
        }
    }
    HCGRecentEntry *entry = [[HCGRecentEntry alloc] init];
    entry.action = action;
    entry.date = date;
    entry.succeeded = succeeded;
    entry.message = message;
    [_entries insertObject:entry atIndex:0];
    while (_entries.count > HCGMaxRecents) [_entries removeLastObject];
    [self persist];
}

- (void)clear {
    [_entries removeAllObjects];
    [self persist];
}

@end
