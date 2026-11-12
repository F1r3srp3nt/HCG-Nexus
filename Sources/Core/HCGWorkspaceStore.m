#import "HCGWorkspaceStore.h"
#import "HCGWorkspacePresets.h"
#import "HCGConstants.h"

NSString *const HCGStoreKeyWorkspaces = @"workspaces";
NSString *const HCGStoreKeyActiveWorkspace = @"activeWorkspace";
NSString *const HCGStoreKeySchemaVersion = @"workspacesSchemaVersion";

const NSUInteger HCGMaxWorkspaces = 24;
const NSUInteger HCGMaxActionsPerWorkspace = 48;
const NSUInteger HCGMaxWorkspaceNameLength = 32;

static const NSInteger kSchemaVersion = 1;

@implementation HCGWorkspaceStore

@synthesize droppedEntriesOnLoad = _droppedEntriesOnLoad;
@synthesize seededOnLoad = _seededOnLoad;

- (instancetype)initWithStore:(id<HCGKeyValueStore>)store {
    if ((self = [super init])) {
        _backingStore = store;
        _workspaces = [[NSMutableArray alloc] init];
    }
    return self;
}

- (NSArray *)workspaces {
    return [_workspaces copy];
}

- (HCGWorkspace *)activeWorkspace {
    if (_activeWorkspaceIdentifier) {
        HCGWorkspace *found = [self workspaceWithIdentifier:_activeWorkspaceIdentifier];
        if (found) return found;
    }
    return _workspaces.count > 0 ? [_workspaces objectAtIndex:0] : nil;
}

- (void)setActiveIdentifierInternal:(NSString *)identifier {
    _activeWorkspaceIdentifier = [identifier copy];
}

#pragma mark - Persistence

- (void)load {
    [_backingStore reload];
    [_workspaces removeAllObjects];
    _droppedEntriesOnLoad = 0;
    _seededOnLoad = NO;

    id stored = [_backingStore objectForKey:HCGStoreKeyWorkspaces];
    if (stored == nil) {
        NSArray *presets = [HCGWorkspacePresets presetIdentifiers];
        NSUInteger i;
        for (i = 0; i < presets.count; i++) {
            [_workspaces addObject:[HCGWorkspacePresets workspaceForPreset:[presets objectAtIndex:i] name:nil]];
        }
        _seededOnLoad = YES;
        [self setActiveIdentifierInternal:[[_workspaces objectAtIndex:0] identifier]];
        [self persist];
        return;
    }

    if ([stored isKindOfClass:[NSArray class]]) {
        NSMutableSet *seen = [[NSMutableSet alloc] init];
        NSUInteger i;
        for (i = 0; i < [stored count]; i++) {
            NSUInteger droppedActions = 0;
            HCGWorkspace *workspace = [HCGWorkspace workspaceFromDictionary:[stored objectAtIndex:i] droppedActions:&droppedActions];
            _droppedEntriesOnLoad += droppedActions;
            if (workspace == nil || [seen containsObject:workspace.identifier] || _workspaces.count >= HCGMaxWorkspaces) {
                _droppedEntriesOnLoad += 1;
                continue;
            }
            [seen addObject:workspace.identifier];
            [_workspaces addObject:workspace];
        }
    } else {
        _droppedEntriesOnLoad += 1;
    }

    id active = [_backingStore objectForKey:HCGStoreKeyActiveWorkspace];
    if ([active isKindOfClass:[NSString class]] && [self workspaceWithIdentifier:active]) {
        [self setActiveIdentifierInternal:active];
    } else {
        [self setActiveIdentifierInternal:(_workspaces.count > 0 ? [[_workspaces objectAtIndex:0] identifier] : nil)];
    }
}

- (BOOL)persist {
    NSMutableArray *list = [[NSMutableArray alloc] init];
    NSUInteger i;
    for (i = 0; i < _workspaces.count; i++) {
        [list addObject:[[_workspaces objectAtIndex:i] dictionaryRepresentation]];
    }
    [_backingStore setObject:list forKey:HCGStoreKeyWorkspaces];
    [_backingStore setObject:_activeWorkspaceIdentifier forKey:HCGStoreKeyActiveWorkspace];
    [_backingStore setObject:[NSNumber numberWithInteger:kSchemaVersion] forKey:HCGStoreKeySchemaVersion];
    return [_backingStore flush];
}

- (BOOL)persistOrFail:(NSError **)error {
    if ([self persist]) return YES;
    if (error) *error = HCGMakeError(HCGErrorLaunchFailed, @"Workspaces could not be saved.", @"Try again. If it keeps failing, check Diagnostics in HCG Nexus settings.");
    return NO;
}

#pragma mark - Lookup

- (NSUInteger)indexOfWorkspaceWithIdentifier:(NSString *)identifier {
    if (identifier == nil) return NSNotFound;
    NSUInteger i;
    for (i = 0; i < _workspaces.count; i++) {
        if ([[[_workspaces objectAtIndex:i] identifier] isEqualToString:identifier]) return i;
    }
    return NSNotFound;
}

- (HCGWorkspace *)workspaceWithIdentifier:(NSString *)identifier {
    NSUInteger index = [self indexOfWorkspaceWithIdentifier:identifier];
    return index == NSNotFound ? nil : [_workspaces objectAtIndex:index];
}

static NSError *NotFound(void) {
    return HCGMakeError(HCGErrorNotFound, @"That workspace no longer exists.", @"Reopen the panel to refresh the list.");
}

#pragma mark - Workspaces

- (NSString *)validatedName:(NSString *)rawName excludingWorkspace:(NSString *)identifier error:(NSError **)error {
    NSString *name = [rawName stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (name.length == 0) {
        if (error) *error = HCGMakeError(HCGErrorInvalidName, @"Workspace names can't be empty.", @"Enter a name such as \"Studio\".");
        return nil;
    }
    if (name.length > HCGMaxWorkspaceNameLength) {
        if (error) *error = HCGMakeError(HCGErrorInvalidName,
                                         [NSString stringWithFormat:@"Workspace names are limited to %lu characters.", (unsigned long)HCGMaxWorkspaceNameLength],
                                         @"Choose a shorter name.");
        return nil;
    }
    NSUInteger i;
    for (i = 0; i < _workspaces.count; i++) {
        HCGWorkspace *workspace = [_workspaces objectAtIndex:i];
        if (identifier && [workspace.identifier isEqualToString:identifier]) continue;
        if ([workspace.name caseInsensitiveCompare:name] == NSOrderedSame) {
            if (error) *error = HCGMakeError(HCGErrorDuplicateName,
                                             [NSString stringWithFormat:@"A workspace named \"%@\" already exists.", workspace.name],
                                             @"Choose a different name.");
            return nil;
        }
    }
    return name;
}

- (NSString *)uniqueNameFromBase:(NSString *)base {
    if ([self validatedName:base excludingWorkspace:nil error:NULL]) return base;
    NSUInteger n;
    for (n = 2; n < 100; n++) {
        NSString *candidate = [NSString stringWithFormat:@"%@ %lu", base, (unsigned long)n];
        if ([self validatedName:candidate excludingWorkspace:nil error:NULL]) return candidate;
    }
    return [[NSUUID UUID] UUIDString];
}

- (HCGWorkspace *)createWorkspaceNamed:(NSString *)name preset:(NSString *)preset error:(NSError **)error {
    if (_workspaces.count >= HCGMaxWorkspaces) {
        if (error) *error = HCGMakeError(HCGErrorLimitReached,
                                         [NSString stringWithFormat:@"You can have up to %lu workspaces.", (unsigned long)HCGMaxWorkspaces],
                                         @"Delete a workspace you no longer use first.");
        return nil;
    }
    NSString *finalName = nil;
    if (name.length > 0) {
        finalName = [self validatedName:name excludingWorkspace:nil error:error];
        if (!finalName) return nil;
    } else {
        finalName = [self uniqueNameFromBase:[HCGWorkspacePresets displayNameForPreset:preset]];
    }
    HCGWorkspace *workspace = [HCGWorkspacePresets workspaceForPreset:preset name:finalName];
    [_workspaces addObject:workspace];
    if (_activeWorkspaceIdentifier == nil) [self setActiveIdentifierInternal:workspace.identifier];
    if (![self persistOrFail:error]) return nil;
    return workspace;
}

- (BOOL)renameWorkspace:(NSString *)identifier to:(NSString *)name error:(NSError **)error {
    HCGWorkspace *workspace = [self workspaceWithIdentifier:identifier];
    if (!workspace) { if (error) *error = NotFound(); return NO; }
    NSString *finalName = [self validatedName:name excludingWorkspace:identifier error:error];
    if (!finalName) return NO;
    workspace.name = finalName;
    return [self persistOrFail:error];
}

- (BOOL)moveWorkspaceFromIndex:(NSUInteger)from toIndex:(NSUInteger)to error:(NSError **)error {
    if (from >= _workspaces.count || to >= _workspaces.count) {
        if (error) *error = NotFound();
        return NO;
    }
    if (from == to) return YES;
    id item = [_workspaces objectAtIndex:from];
    [_workspaces removeObjectAtIndex:from];
    [_workspaces insertObject:item atIndex:to];
    return [self persistOrFail:error];
}

- (BOOL)deleteWorkspace:(NSString *)identifier error:(NSError **)error {
    NSUInteger index = [self indexOfWorkspaceWithIdentifier:identifier];
    if (index == NSNotFound) { if (error) *error = NotFound(); return NO; }
    [_workspaces removeObjectAtIndex:index];
    if ([_activeWorkspaceIdentifier isEqualToString:identifier]) {
        NSString *next = nil;
        if (_workspaces.count > 0) {
            NSUInteger nextIndex = index < _workspaces.count ? index : _workspaces.count - 1;
            next = [[_workspaces objectAtIndex:nextIndex] identifier];
        }
        [self setActiveIdentifierInternal:next];
    }
    return [self persistOrFail:error];
}

- (BOOL)setActiveWorkspace:(NSString *)identifier error:(NSError **)error {
    if (![self workspaceWithIdentifier:identifier]) { if (error) *error = NotFound(); return NO; }
    if ([_activeWorkspaceIdentifier isEqualToString:identifier]) return YES;
    [self setActiveIdentifierInternal:identifier];
    return [self persistOrFail:error];
}

#pragma mark - Actions

- (BOOL)addAction:(HCGAction *)action toWorkspace:(NSString *)identifier error:(NSError **)error {
    HCGWorkspace *workspace = [self workspaceWithIdentifier:identifier];
    if (!workspace) { if (error) *error = NotFound(); return NO; }
    NSError *validation = [HCGAction validationErrorForKind:action.kind title:action.title target:action.target];
    if (validation) { if (error) *error = validation; return NO; }
    if (workspace.actions.count >= HCGMaxActionsPerWorkspace) {
        if (error) *error = HCGMakeError(HCGErrorLimitReached,
                                         [NSString stringWithFormat:@"A workspace can hold up to %lu shortcuts.", (unsigned long)HCGMaxActionsPerWorkspace],
                                         @"Remove a shortcut or create another workspace.");
        return NO;
    }
    if ([workspace indexOfActionWithIdentifier:action.identifier] != NSNotFound) {
        if (error) *error = HCGMakeError(HCGErrorDuplicateName, @"That shortcut is already in this workspace.", nil);
        return NO;
    }
    [workspace appendAction:[action copy]];
    return [self persistOrFail:error];
}

- (BOOL)removeAction:(NSString *)actionIdentifier fromWorkspace:(NSString *)identifier error:(NSError **)error {
    HCGWorkspace *workspace = [self workspaceWithIdentifier:identifier];
    if (!workspace) { if (error) *error = NotFound(); return NO; }
    NSUInteger index = [workspace indexOfActionWithIdentifier:actionIdentifier];
    if (index == NSNotFound) {
        if (error) *error = HCGMakeError(HCGErrorNotFound, @"That shortcut no longer exists.", nil);
        return NO;
    }
    [workspace removeActionAtIndex:index];
    return [self persistOrFail:error];
}

- (BOOL)moveActionInWorkspace:(NSString *)identifier fromIndex:(NSUInteger)from toIndex:(NSUInteger)to error:(NSError **)error {
    HCGWorkspace *workspace = [self workspaceWithIdentifier:identifier];
    if (!workspace) { if (error) *error = NotFound(); return NO; }
    NSUInteger count = workspace.actions.count;
    if (from >= count || to >= count) {
        if (error) *error = HCGMakeError(HCGErrorNotFound, @"That shortcut no longer exists.", nil);
        return NO;
    }
    if (from == to) return YES;
    [workspace moveActionFromIndex:from toIndex:to];
    return [self persistOrFail:error];
}

@end
