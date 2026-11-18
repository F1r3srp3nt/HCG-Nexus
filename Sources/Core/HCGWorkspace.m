#import "HCGWorkspace.h"

NSString *const HCGPresetCommand = @"command";
NSString *const HCGPresetDeveloper = @"developer";
NSString *const HCGPresetStudio = @"studio";
NSString *const HCGPresetInfrastructure = @"infrastructure";
NSString *const HCGPresetCustom = @"custom";

static NSString *const kID = @"id";
static NSString *const kName = @"name";
static NSString *const kPreset = @"preset";
static NSString *const kActions = @"actions";
static NSString *const kQuickActions = @"quickActions";
static NSString *const kTools = @"tools";

const NSUInteger HCGWorkspaceMaxQuickActions = 4;

// Strings only, de-duplicated, order kept, capped. Anything else is dropped.
static NSArray *HCGCleanIdentifierList(id value, NSUInteger limit) {
    NSMutableArray *out = [[NSMutableArray alloc] init];
    if (![value isKindOfClass:[NSArray class]]) return out;
    NSUInteger i;
    for (i = 0; i < [value count] && out.count < limit; i++) {
        id item = [value objectAtIndex:i];
        if ([item isKindOfClass:[NSString class]] && [item length] > 0 && [item length] <= 200 && ![out containsObject:item]) {
            [out addObject:item];
        }
    }
    return out;
}

@implementation HCGWorkspace

@synthesize identifier = _identifier;
@synthesize name = _name;
@synthesize preset = _preset;
@synthesize quickActionIdentifiers = _quickActionIdentifiers;
@synthesize toolIdentifiers = _toolIdentifiers;

- (void)setQuickActionIdentifiers:(NSArray *)identifiers {
    _quickActionIdentifiers = [HCGCleanIdentifierList(identifiers, HCGWorkspaceMaxQuickActions) copy];
}

- (void)setToolIdentifiers:(NSArray *)identifiers {
    _toolIdentifiers = [HCGCleanIdentifierList(identifiers, 64) copy];
}

- (instancetype)init {
    return [self initWithName:@"Workspace" preset:HCGPresetCustom];
}

- (instancetype)initWithName:(NSString *)name preset:(NSString *)preset {
    if ((self = [super init])) {
        self.identifier = [[NSUUID UUID] UUIDString];
        self.name = name;
        self.preset = preset ?: HCGPresetCustom;
        _mutableActions = [[NSMutableArray alloc] init];
        _quickActionIdentifiers = [[NSArray alloc] init];
        _toolIdentifiers = [[NSArray alloc] init];
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone {
    HCGWorkspace *copy = [[[self class] allocWithZone:zone] initWithName:self.name preset:self.preset];
    copy.identifier = self.identifier;
    NSUInteger i;
    for (i = 0; i < _mutableActions.count; i++) {
        HCGAction *action = [[_mutableActions objectAtIndex:i] copy];
        [copy appendAction:action];
    }
    copy.quickActionIdentifiers = self.quickActionIdentifiers;
    copy.toolIdentifiers = self.toolIdentifiers;
    return copy;
}

- (NSArray *)actions {
    return [_mutableActions copy];
}

- (void)replaceActions:(NSArray *)actions {
    [_mutableActions removeAllObjects];
    [_mutableActions addObjectsFromArray:actions];
}

- (void)appendAction:(HCGAction *)action {
    [_mutableActions addObject:action];
}

- (void)insertAction:(HCGAction *)action atIndex:(NSUInteger)index {
    if (index > _mutableActions.count) index = _mutableActions.count;
    [_mutableActions insertObject:action atIndex:index];
}

- (void)removeActionAtIndex:(NSUInteger)index {
    if (index < _mutableActions.count) [_mutableActions removeObjectAtIndex:index];
}

- (void)moveActionFromIndex:(NSUInteger)from toIndex:(NSUInteger)to {
    if (from >= _mutableActions.count || to >= _mutableActions.count || from == to) return;
    id item = [_mutableActions objectAtIndex:from];
    [_mutableActions removeObjectAtIndex:from];
    [_mutableActions insertObject:item atIndex:to];
}

- (NSUInteger)indexOfActionWithIdentifier:(NSString *)identifier {
    NSUInteger i;
    for (i = 0; i < _mutableActions.count; i++) {
        HCGAction *action = [_mutableActions objectAtIndex:i];
        if ([action.identifier isEqualToString:identifier]) return i;
    }
    return NSNotFound;
}

- (HCGAction *)actionWithIdentifier:(NSString *)identifier {
    NSUInteger index = [self indexOfActionWithIdentifier:identifier];
    return index == NSNotFound ? nil : [_mutableActions objectAtIndex:index];
}

+ (instancetype)workspaceFromDictionary:(NSDictionary *)dictionary droppedActions:(NSUInteger *)droppedActions {
    if (droppedActions) *droppedActions = 0;
    if (![dictionary isKindOfClass:[NSDictionary class]]) return nil;
    id identifier = [dictionary objectForKey:kID];
    id name = [dictionary objectForKey:kName];
    id preset = [dictionary objectForKey:kPreset];
    id actions = [dictionary objectForKey:kActions];
    if (![identifier isKindOfClass:[NSString class]] || [identifier length] == 0) return nil;
    if (![name isKindOfClass:[NSString class]] || [name length] == 0) return nil;
    if (![preset isKindOfClass:[NSString class]]) preset = HCGPresetCustom;
    if (actions != nil && ![actions isKindOfClass:[NSArray class]]) actions = nil;

    HCGWorkspace *workspace = [[self alloc] initWithName:name preset:preset];
    workspace.identifier = identifier;
    NSUInteger dropped = 0;
    NSUInteger i;
    for (i = 0; i < [actions count]; i++) {
        HCGAction *action = [HCGAction actionFromDictionary:[actions objectAtIndex:i] error:NULL];
        if (action && [workspace indexOfActionWithIdentifier:action.identifier] == NSNotFound) {
            [workspace appendAction:action];
        } else {
            dropped += 1;
        }
    }
    if (droppedActions) *droppedActions = dropped;
    // Optional (layout 2). Missing or malformed lists read as empty; older
    // builds ignore these keys, so a downgrade keeps working.
    workspace.quickActionIdentifiers = [dictionary objectForKey:kQuickActions];
    workspace.toolIdentifiers = [dictionary objectForKey:kTools];
    return workspace;
}

- (NSDictionary *)dictionaryRepresentation {
    NSMutableArray *actions = [[NSMutableArray alloc] init];
    NSUInteger i;
    for (i = 0; i < _mutableActions.count; i++) {
        [actions addObject:[[_mutableActions objectAtIndex:i] dictionaryRepresentation]];
    }
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
    [dict setObject:self.identifier forKey:kID];
    [dict setObject:self.name forKey:kName];
    [dict setObject:self.preset forKey:kPreset];
    [dict setObject:actions forKey:kActions];
    [dict setObject:self.quickActionIdentifiers forKey:kQuickActions];
    [dict setObject:self.toolIdentifiers forKey:kTools];
    return dict;
}

@end
