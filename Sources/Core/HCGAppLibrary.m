#import "HCGAppLibrary.h"
#import "HCGConstants.h"

NSString *const HCGStoreKeyAppLibrary = @"appLibrary";
const NSUInteger HCGAppLibraryMaxItems = 200;

static NSString *const kItems = @"items";
static NSString *const kFavourites = @"favourites";

@implementation HCGAppLibrary

@synthesize droppedOnLoad = _droppedOnLoad;

- (instancetype)initWithStore:(id<HCGKeyValueStore>)store {
    if ((self = [super init])) {
        _backingStore = store;
        _items = [[NSMutableArray alloc] init];
        _favourites = [[NSMutableArray alloc] init];
    }
    return self;
}

- (NSArray *)items {
    return [_items copy];
}

- (NSArray *)favouriteIdentifiers {
    return [_favourites copy];
}

+ (BOOL)acceptsKind:(HCGActionKind)kind {
    return kind == HCGActionKindApp || kind == HCGActionKindURL;
}

+ (NSString *)keyForAction:(HCGAction *)action {
    NSString *target = [action.target ?: @"" lowercaseString];
    return [NSString stringWithFormat:@"%@|%@", HCGActionKindName(action.kind), target];
}

- (void)load {
    [_items removeAllObjects];
    [_favourites removeAllObjects];
    _droppedOnLoad = 0;
    id stored = [_backingStore objectForKey:HCGStoreKeyAppLibrary];
    if (![stored isKindOfClass:[NSDictionary class]]) return;
    id items = [stored objectForKey:kItems];
    if ([items isKindOfClass:[NSArray class]]) {
        NSUInteger i;
        for (i = 0; i < [items count]; i++) {
            HCGAction *action = [HCGAction actionFromDictionary:[items objectAtIndex:i] error:NULL];
            if (action && [HCGAppLibrary acceptsKind:action.kind] && _items.count < HCGAppLibraryMaxItems &&
                [self indexOfItemWithIdentifier:action.identifier] == NSNotFound && [self itemMatchingAction:action] == nil) {
                [_items addObject:action];
            } else {
                _droppedOnLoad += 1;
            }
        }
    }
    id favourites = [stored objectForKey:kFavourites];
    if ([favourites isKindOfClass:[NSArray class]]) {
        NSUInteger i;
        for (i = 0; i < [favourites count]; i++) {
            id identifier = [favourites objectAtIndex:i];
            if ([identifier isKindOfClass:[NSString class]] && [self itemWithIdentifier:identifier] && ![_favourites containsObject:identifier]) {
                [_favourites addObject:identifier];
            }
        }
    }
}

- (BOOL)save {
    NSMutableArray *items = [[NSMutableArray alloc] init];
    NSUInteger i;
    for (i = 0; i < _items.count; i++) {
        [items addObject:[[_items objectAtIndex:i] dictionaryRepresentation]];
    }
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
    [dict setObject:items forKey:kItems];
    [dict setObject:[_favourites copy] forKey:kFavourites];
    [_backingStore setObject:dict forKey:HCGStoreKeyAppLibrary];
    return [_backingStore flush];
}

- (BOOL)saveOrFail:(NSError **)error {
    if ([self save]) return YES;
    if (error) *error = HCGMakeError(HCGErrorLaunchFailed, @"Apps could not be saved.", @"Try again. If it keeps failing, copy the diagnostics report from Tools.");
    return NO;
}

- (NSUInteger)indexOfItemWithIdentifier:(NSString *)identifier {
    if (identifier == nil) return NSNotFound;
    NSUInteger i;
    for (i = 0; i < _items.count; i++) {
        if ([[[_items objectAtIndex:i] identifier] isEqualToString:identifier]) return i;
    }
    return NSNotFound;
}

- (HCGAction *)itemWithIdentifier:(NSString *)identifier {
    NSUInteger index = [self indexOfItemWithIdentifier:identifier];
    return index == NSNotFound ? nil : [_items objectAtIndex:index];
}

- (HCGAction *)itemMatchingAction:(HCGAction *)action {
    NSString *key = [HCGAppLibrary keyForAction:action];
    NSUInteger i;
    for (i = 0; i < _items.count; i++) {
        if ([[HCGAppLibrary keyForAction:[_items objectAtIndex:i]] isEqualToString:key]) return [_items objectAtIndex:i];
    }
    return nil;
}

- (HCGAction *)validatedCopyOf:(HCGAction *)action error:(NSError **)error {
    if (![HCGAppLibrary acceptsKind:action.kind]) {
        if (error) *error = HCGMakeError(HCGErrorInvalidTarget, @"Apps holds app and link shortcuts only.", @"HCG products are under HCG Products.");
        return nil;
    }
    NSError *problem = [HCGAction validationErrorForKind:action.kind title:action.title target:action.target];
    if (problem) {
        if (error) *error = problem;
        return nil;
    }
    return [action copy];
}

- (HCGAction *)addItem:(HCGAction *)action error:(NSError **)error {
    HCGAction *copy = [self validatedCopyOf:action error:error];
    if (!copy) return nil;
    if ([self itemMatchingAction:copy]) {
        if (error) *error = HCGMakeError(HCGErrorDuplicateName, [NSString stringWithFormat:@"%@ is already in Apps.", copy.title], @"Find it with search, or edit the existing entry.");
        return nil;
    }
    if (_items.count >= HCGAppLibraryMaxItems) {
        if (error) *error = HCGMakeError(HCGErrorLimitReached, @"Apps is full.", @"Remove shortcuts you no longer use.");
        return nil;
    }
    if ([self indexOfItemWithIdentifier:copy.identifier] != NSNotFound) copy.identifier = [[NSUUID UUID] UUIDString];
    [_items addObject:copy];
    if (![self saveOrFail:error]) {
        [_items removeLastObject];
        return nil;
    }
    return copy;
}

- (HCGAction *)mergeItem:(HCGAction *)action {
    HCGAction *existing = [self itemMatchingAction:action];
    if (existing) return existing;
    HCGAction *copy = [self validatedCopyOf:action error:NULL];
    if (!copy || _items.count >= HCGAppLibraryMaxItems) return nil;
    if ([self indexOfItemWithIdentifier:copy.identifier] != NSNotFound) copy.identifier = [[NSUUID UUID] UUIDString];
    [_items addObject:copy];
    return copy;
}

- (BOOL)removeItemWithIdentifier:(NSString *)identifier error:(NSError **)error {
    NSUInteger index = [self indexOfItemWithIdentifier:identifier];
    if (index == NSNotFound) {
        if (error) *error = HCGMakeError(HCGErrorNotFound, @"That shortcut no longer exists.", nil);
        return NO;
    }
    [_items removeObjectAtIndex:index];
    [_favourites removeObject:identifier];
    return [self saveOrFail:error];
}

- (BOOL)moveItemFromIndex:(NSUInteger)from toIndex:(NSUInteger)to error:(NSError **)error {
    if (from >= _items.count || to >= _items.count) {
        if (error) *error = HCGMakeError(HCGErrorNotFound, @"That shortcut no longer exists.", nil);
        return NO;
    }
    if (from == to) return YES;
    HCGAction *item = [_items objectAtIndex:from];
    [_items removeObjectAtIndex:from];
    [_items insertObject:item atIndex:to];
    return [self saveOrFail:error];
}

- (BOOL)isFavourite:(NSString *)identifier {
    return identifier != nil && [_favourites containsObject:identifier];
}

- (BOOL)setFavourite:(BOOL)favourite forItem:(NSString *)identifier error:(NSError **)error {
    if (![self itemWithIdentifier:identifier]) {
        if (error) *error = HCGMakeError(HCGErrorNotFound, @"That shortcut no longer exists.", nil);
        return NO;
    }
    if (favourite && ![_favourites containsObject:identifier]) [_favourites addObject:identifier];
    if (!favourite) [_favourites removeObject:identifier];
    return [self saveOrFail:error];
}

- (NSArray *)itemsMatchingQuery:(NSString *)query favouritesOnly:(BOOL)favouritesOnly {
    NSString *needle = [[query ?: @"" stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] lowercaseString];
    NSMutableArray *out = [[NSMutableArray alloc] init];
    NSUInteger i;
    for (i = 0; i < _items.count; i++) {
        HCGAction *item = [_items objectAtIndex:i];
        if (favouritesOnly && ![self isFavourite:item.identifier]) continue;
        if (needle.length > 0 && [[item.title lowercaseString] rangeOfString:needle].location == NSNotFound &&
            [[item.target lowercaseString] rangeOfString:needle].location == NSNotFound) continue;
        [out addObject:item];
    }
    return out;
}

- (void)removeAll {
    [_items removeAllObjects];
    [_favourites removeAllObjects];
}

@end
