#import "HCGLayoutMigration.h"
#import "HCGConstants.h"
#import "HCGToolCatalog.h"

NSString *const HCGStoreKeyLayoutVersion = @"layoutVersion";
NSString *const HCGStoreKeyLayoutBackup = @"layoutBackupV1";
NSString *const HCGStoreKeyLayoutDeclined = @"layoutDeclined";
const NSInteger HCGCurrentLayoutVersion = 2;

static NSString *const kBackupWorkspaces = @"workspaces";
static NSString *const kBackupActive = @"activeWorkspace";
static NSString *const kBackupSchema = @"workspacesSchemaVersion";
static NSString *const kBackupCreated = @"created";

@implementation HCGLayoutMigration

+ (NSInteger)layoutVersionInStore:(id<HCGKeyValueStore>)store {
    id value = [store objectForKey:HCGStoreKeyLayoutVersion];
    return [value isKindOfClass:[NSNumber class]] ? [value integerValue] : 1;
}

+ (BOOL)hasBackupInStore:(id<HCGKeyValueStore>)store {
    id backup = [store objectForKey:HCGStoreKeyLayoutBackup];
    return [backup isKindOfClass:[NSDictionary class]] && [[backup objectForKey:kBackupWorkspaces] isKindOfClass:[NSArray class]];
}

// Workspaces in migration order: the active one first, then the rest as listed.
+ (NSArray *)orderedWorkspaces:(HCGWorkspaceStore *)workspaces {
    NSMutableArray *ordered = [[NSMutableArray alloc] init];
    HCGWorkspace *active = workspaces.activeWorkspace;
    if (active) [ordered addObject:active];
    NSArray *all = workspaces.workspaces;
    NSUInteger i;
    for (i = 0; i < all.count; i++) {
        if (![ordered containsObject:[all objectAtIndex:i]]) [ordered addObject:[all objectAtIndex:i]];
    }
    return ordered;
}

+ (NSUInteger)mergeShortcutsFrom:(HCGWorkspaceStore *)workspaces into:(HCGAppLibrary *)library {
    NSUInteger before = library.items.count;
    NSArray *ordered = [self orderedWorkspaces:workspaces];
    NSUInteger w, a;
    for (w = 0; w < ordered.count; w++) {
        NSArray *actions = [[ordered objectAtIndex:w] actions];
        for (a = 0; a < actions.count; a++) {
            HCGAction *action = [actions objectAtIndex:a];
            if ([HCGAppLibrary acceptsKind:action.kind]) [library mergeItem:action];
        }
    }
    return library.items.count - before;
}

+ (HCGLayoutMigrationOutcome)migrateStore:(id<HCGKeyValueStore>)store
                           workspaceStore:(HCGWorkspaceStore *)workspaces
                                  library:(HCGAppLibrary *)library
                                 imported:(NSUInteger *)imported {
    if (imported) *imported = 0;
    if ([self layoutVersionInStore:store] >= HCGCurrentLayoutVersion) return HCGLayoutMigrationAlreadyCurrent;
    id declined = [store objectForKey:HCGStoreKeyLayoutDeclined];
    if ([declined isKindOfClass:[NSNumber class]] && [declined boolValue]) return HCGLayoutMigrationDeclined;

    // 1. Verbatim backup of what an earlier version stored (nothing to back up on a fresh install).
    id rawWorkspaces = [store objectForKey:HCGStoreKeyWorkspaces];
    if ([rawWorkspaces isKindOfClass:[NSArray class]] && ![self hasBackupInStore:store]) {
        NSMutableDictionary *backup = [[NSMutableDictionary alloc] init];
        [backup setObject:rawWorkspaces forKey:kBackupWorkspaces];
        id active = [store objectForKey:HCGStoreKeyActiveWorkspace];
        if ([active isKindOfClass:[NSString class]]) [backup setObject:active forKey:kBackupActive];
        id schema = [store objectForKey:HCGStoreKeySchemaVersion];
        if ([schema isKindOfClass:[NSNumber class]]) [backup setObject:schema forKey:kBackupSchema];
        [backup setObject:[NSNumber numberWithDouble:[[NSDate date] timeIntervalSince1970]] forKey:kBackupCreated];
        [store setObject:backup forKey:HCGStoreKeyLayoutBackup];
    }

    // 2. Apps: every app/link shortcut, de-duplicated.
    NSUInteger added = [self mergeShortcutsFrom:workspaces into:library];
    [library save];

    // 3. Quick actions and tools per workspace; shortcuts themselves stay in place.
    NSArray *all = workspaces.workspaces;
    NSUInteger w, a;
    for (w = 0; w < all.count; w++) {
        HCGWorkspace *workspace = [all objectAtIndex:w];
        if (workspace.quickActionIdentifiers.count == 0) {
            NSMutableArray *quick = [[NSMutableArray alloc] init];
            for (a = 0; a < workspace.actions.count && quick.count < HCGWorkspaceMaxQuickActions; a++) {
                HCGAction *item = [library itemMatchingAction:[workspace.actions objectAtIndex:a]];
                if (item && ![quick containsObject:item.identifier]) [quick addObject:item.identifier];
            }
            [workspaces setQuickActionIdentifiers:quick forWorkspace:workspace.identifier error:NULL];
        }
        if (workspace.toolIdentifiers.count == 0) {
            [workspaces setToolIdentifiers:[HCGToolCatalog defaultToolIdentifiersForPreset:workspace.preset]
                              forWorkspace:workspace.identifier error:NULL];
        }
    }

    [store setObject:[NSNumber numberWithInteger:HCGCurrentLayoutVersion] forKey:HCGStoreKeyLayoutVersion];
    [store flush];
    if (imported) *imported = added;
    return HCGLayoutMigrationMigrated;
}

+ (NSUInteger)importShortcutsFromWorkspaces:(HCGWorkspaceStore *)workspaces intoLibrary:(HCGAppLibrary *)library {
    NSUInteger added = [self mergeShortcutsFrom:workspaces into:library];
    if (added > 0) [library save];
    return added;
}

+ (BOOL)restorePreviousLayoutInStore:(id<HCGKeyValueStore>)store error:(NSError **)error {
    if (![self hasBackupInStore:store]) {
        if (error) *error = HCGMakeError(HCGErrorNotFound, @"There is no earlier layout to restore on this device.", nil);
        return NO;
    }
    NSDictionary *backup = [store objectForKey:HCGStoreKeyLayoutBackup];
    [store setObject:[backup objectForKey:kBackupWorkspaces] forKey:HCGStoreKeyWorkspaces];
    [store setObject:[backup objectForKey:kBackupActive] forKey:HCGStoreKeyActiveWorkspace];
    [store setObject:[backup objectForKey:kBackupSchema] forKey:HCGStoreKeySchemaVersion];
    [store setObject:nil forKey:HCGStoreKeyAppLibrary];
    [store setObject:[NSNumber numberWithInteger:1] forKey:HCGStoreKeyLayoutVersion];
    [store setObject:[NSNumber numberWithBool:YES] forKey:HCGStoreKeyLayoutDeclined];
    if (![store flush]) {
        if (error) *error = HCGMakeError(HCGErrorLaunchFailed, @"The previous layout could not be saved.", @"Try again.");
        return NO;
    }
    return YES;
}

+ (void)clearDeclinedInStore:(id<HCGKeyValueStore>)store {
    [store setObject:nil forKey:HCGStoreKeyLayoutDeclined];
    [store flush];
}

@end
