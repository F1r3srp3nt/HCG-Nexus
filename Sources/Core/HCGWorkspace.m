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

@implementation HCGWorkspace

@synthesize identifier = _identifier;
@synthesize name = _name;
@synthesize preset = _preset;

- (instancetype)init {
    return [self initWithName:@"Workspace" preset:HCGPresetCustom];
}

- (instancetype)initWithName:(NSString *)name preset:(NSString *)preset {
    if ((self = [super init])) {
        self.identifier = [[NSUUID UUID] UUIDString];
        self.name = name;
        self.preset = preset ?: HCGPresetCustom;
        _mutableActions = [[NSMutableArray alloc] init];
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
    return dict;
}

@end
