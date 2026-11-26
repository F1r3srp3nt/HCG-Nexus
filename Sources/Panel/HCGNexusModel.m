#import "HCGNexusModel.h"

NSNotificationName const HCGNexusModelDidChangeNotification = @"HCGNexusModelDidChangeNotification";

@implementation HCGNexusModel {
    id<HCGChangeNotifier> _notifier;
    HCGSettings *_settings;
}

- (instancetype)initWithStore:(id<HCGKeyValueStore>)store notifier:(id<HCGChangeNotifier>)notifier launcher:(id<HCGLauncher>)launcher {
    if ((self = [super init])) {
        _store = store;
        _notifier = notifier;
        _launcher = launcher;
        _workspaceStore = [[HCGWorkspaceStore alloc] initWithStore:store];
        _recents = [[HCGRecents alloc] initWithStore:store];
        _appLibrary = [[HCGAppLibrary alloc] initWithStore:store];
        _settings = [HCGSettings defaultSettings];
        [self reloadWithoutNotifying];
    }
    return self;
}

- (HCGSettings *)settings {
    return [_settings copy];
}

- (void)reloadWithoutNotifying {
    [_store reload];
    _settings = [HCGSettings settingsFromStore:_store];
    [_workspaceStore load];
    [_recents load];
    [_appLibrary load];
    NSUInteger imported = 0;
    _lastMigrationOutcome = [HCGLayoutMigration migrateStore:_store workspaceStore:_workspaceStore library:_appLibrary imported:&imported];
    if (_lastMigrationOutcome == HCGLayoutMigrationMigrated) {
        _lastMigrationImported = imported;
        [_workspaceStore load];
        [_appLibrary load];
        [_notifier postWorkspacesChanged];
    }
}

- (void)notifyLocal {
    if ([NSThread isMainThread]) {
        [[NSNotificationCenter defaultCenter] postNotificationName:HCGNexusModelDidChangeNotification object:self];
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:HCGNexusModelDidChangeNotification object:self];
        });
    }
}

- (void)reload {
    [self reloadWithoutNotifying];
    // A first-run seed writes the presets; let other processes know.
    if (_workspaceStore.seededOnLoad) [_notifier postWorkspacesChanged];
    [self notifyLocal];
}

- (void)saveSettings:(HCGSettings *)settings {
    _settings = [settings copy];
    [_settings writeToStore:_store];
    [_notifier postSettingsChanged];
    [self notifyLocal];
}

- (void)resetSettings {
    HCGSettings *settings = [_settings copy];
    [settings resetPreservingEnabledAndIntegrations];
    [self saveSettings:settings];
}

- (void)workspacesDidChange {
    [_notifier postWorkspacesChanged];
    [self notifyLocal];
}

- (NSArray *)ecosystemActivity {
    return [HCGEcosystemActivity entriesFromStoredValue:[_store objectForKey:HCGEcosystemActivityStoreKey]];
}

// Kept in Nexus's own preferences without a change notification: the history is shown, never acted on.
- (void)recordEcosystemActivity:(NSString *)text productID:(NSString *)productID {
    NSDictionary *entry = [HCGEcosystemActivity entryWithText:text productID:productID time:[NSDate date]];
    if (!entry) return;
    [_store setObject:[HCGEcosystemActivity entries:[_store objectForKey:HCGEcosystemActivityStoreKey] byAdding:entry]
               forKey:HCGEcosystemActivityStoreKey];
    [_store flush];
}

- (NSArray *)trustedRepositories {
    return [HCGTrustedRepositoryList repositoriesFromStoredValue:[_store objectForKey:HCGTrustedRepositoriesStoreKey]];
}

// Only ever called after the user confirms a pin or removal in the Trust Center.
- (void)saveTrustedRepositories:(NSArray *)repositories {
    [_store setObject:[HCGTrustedRepositoryList storedValueForRepositories:repositories] forKey:HCGTrustedRepositoriesStoreKey];
    [_store flush];
}

#pragma mark Command Center

static NSString *const kRegistryUpdateKey = @"registryUpdate";
static NSString *const kExpandedCategoriesKey = @"expandedCategories";
static const NSUInteger kMaxStoredImport = 256 * 1024;

- (HCGCentralSnapshot *)centralSnapshot {
    return [HCGCentralSnapshot snapshotFromStoredValue:[_store objectForKey:HCGCentralSnapshotStoreKey]];
}

- (HCGCentralSnapshot *)previousCentralSnapshot {
    return [HCGCentralSnapshot snapshotFromStoredValue:[_store objectForKey:HCGCentralSnapshotPreviousKey]];
}

- (void)saveCentralSnapshot:(HCGCentralSnapshot *)snapshot {
    id current = [_store objectForKey:HCGCentralSnapshotStoreKey];
    HCGCentralSnapshot *old = [HCGCentralSnapshot snapshotFromStoredValue:current];
    if (old && ![old.version isEqualToString:snapshot.version]) [_store setObject:current forKey:HCGCentralSnapshotPreviousKey];
    [_store setObject:[snapshot storedValue] forKey:HCGCentralSnapshotStoreKey];
    [_store flush];
}

- (BOOL)revertCentralSnapshot {
    id current = [_store objectForKey:HCGCentralSnapshotStoreKey], previous = [_store objectForKey:HCGCentralSnapshotPreviousKey];
    if (![HCGCentralSnapshot snapshotFromStoredValue:previous]) return NO;
    [_store setObject:previous forKey:HCGCentralSnapshotStoreKey];
    [_store setObject:current forKey:HCGCentralSnapshotPreviousKey];
    [_store flush];
    return YES;
}

- (void)clearCentralSnapshots {
    [_store setObject:nil forKey:HCGCentralSnapshotStoreKey];
    [_store setObject:nil forKey:HCGCentralSnapshotPreviousKey];
    [_store flush];
}

- (HCGRegistry *)ecosystemRegistry {
    // Built in, then the central registry's identities (if a snapshot was fetched), then an imported update (text and
    // status only; it can never change identity or authority).
    HCGRegistry *base = [[HCGRegistry builtInRegistry] registryByApplyingCentralSnapshot:[self centralSnapshot] matched:NULL];
    id stored = [_store objectForKey:kRegistryUpdateKey];
    if (![stored isKindOfClass:[NSString class]]) return base;
    HCGRegistry *update = [HCGRegistry registryWithJSONData:[stored dataUsingEncoding:NSUTF8StringEncoding] source:@"imported" error:NULL];
    return update ? [base registryByApplyingUpdate:update problem:NULL] : base;
}

- (BOOL)importRegistryUpdate:(NSData *)data error:(NSString **)error {
    if (data.length > kMaxStoredImport) {
        if (error) *error = @"The registry update is larger than 256 KB.";
        return NO;
    }
    HCGRegistry *update = [HCGRegistry registryWithJSONData:data source:@"imported" error:error];
    if (!update) return NO;
    if (![[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]) {
        if (error) *error = @"The registry update is not UTF-8 text.";
        return NO;
    }
    NSString *problem = nil;
    if ([[HCGRegistry builtInRegistry] registryByApplyingUpdate:update problem:&problem] == [HCGRegistry builtInRegistry]) {
        if (error) *error = problem;
        return NO;
    }
    [_store setObject:[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] forKey:kRegistryUpdateKey];
    [_store flush];
    return YES;
}

- (void)removeRegistryUpdate {
    [_store setObject:nil forKey:kRegistryUpdateKey];
    [_store flush];
}

- (BOOL)hasRegistryUpdate {
    return [[_store objectForKey:kRegistryUpdateKey] isKindOfClass:[NSString class]];
}

- (NSArray *)connectionLedger {
    return [HCGConnectionLedger entriesFromStoredValue:[_store objectForKey:HCGConnectionLedgerStoreKey]];
}

- (void)recordConnectionForProduct:(NSString *)productID method:(NSString *)method success:(BOOL)success text:(NSString *)text {
    NSDictionary *entry = [HCGConnectionLedger entryForProduct:productID method:method success:success text:text time:[NSDate date]];
    if (!entry) return;
    [_store setObject:[HCGConnectionLedger entries:[_store objectForKey:HCGConnectionLedgerStoreKey] byAdding:entry] forKey:HCGConnectionLedgerStoreKey];
    [_store flush];
}

- (NSArray *)favoriteProductIDs {
    return [HCGCommandCenter favoritesFromStoredValue:[_store objectForKey:HCGCommandCenterFavoritesKey]];
}

- (void)setFavorite:(BOOL)favorite forProduct:(NSString *)productID {
    NSMutableArray *ids = [[self favoriteProductIDs] mutableCopy];
    [ids removeObject:productID];
    if (favorite) [ids insertObject:productID atIndex:0];
    [_store setObject:[HCGCommandCenter favoritesFromStoredValue:ids] forKey:HCGCommandCenterFavoritesKey];
    [_store flush];
}

- (NSArray *)expandedCategoryIDs {
    return [HCGCommandCenter favoritesFromStoredValue:[_store objectForKey:kExpandedCategoriesKey]];
}

- (void)setCategory:(NSString *)categoryID expanded:(BOOL)expanded {
    NSMutableArray *ids = [[self expandedCategoryIDs] mutableCopy];
    [ids removeObject:categoryID];
    if (expanded) [ids addObject:categoryID];
    [_store setObject:ids forKey:kExpandedCategoriesKey];
    [_store flush];
}

- (NSDictionary *)roadmapStore {
    id v = [_store objectForKey:HCGRoadmapStoreKey];
    return [v isKindOfClass:[NSDictionary class]] ? v : @{};
}

- (void)saveRoadmapStore:(NSDictionary *)store {
    [_store setObject:store forKey:HCGRoadmapStoreKey];
    [_store flush];
}

- (NSDictionary *)lifeOSExported {
    id v = [_store objectForKey:HCGLifeOSExportStoreKey];
    return [v isKindOfClass:[NSDictionary class]] ? v : @{};
}

- (void)markLifeOSExport:(HCGLifeOSExport *)export_ {
    [_store setObject:[HCGCommandCenter exportedStore:[self lifeOSExported] byMarking:export_] forKey:HCGLifeOSExportStoreKey];
    [_store flush];
}

- (HCGDeviceInventory *)deviceInventory {
    id stored = [_store objectForKey:HCGDeviceInventoryStoreKey];
    if (![stored isKindOfClass:[NSString class]]) return nil;
    return [HCGDeviceInventory inventoryWithData:[stored dataUsingEncoding:NSUTF8StringEncoding] error:NULL];
}

- (BOOL)importDeviceInventory:(NSData *)data error:(NSString **)error {
    if (data.length > kMaxStoredImport) {
        if (error) *error = @"The inventory is larger than 256 KB; export fewer devices from HCG System Tester.";
        return NO;
    }
    NSString *text = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (!text) {
        if (error) *error = @"The inventory is not UTF-8 text.";
        return NO;
    }
    if (![HCGDeviceInventory inventoryWithData:data error:error]) return NO;
    [_store setObject:text forKey:HCGDeviceInventoryStoreKey];
    [_store flush];
    return YES;
}

- (void)removeDeviceInventory {
    [_store setObject:nil forKey:HCGDeviceInventoryStoreKey];
    [_store flush];
}

- (void)clearEcosystemActivity {
    [_store setObject:nil forKey:HCGEcosystemActivityStoreKey];
    [_store flush];
}

- (void)clearRecents {
    [_recents clear];
    [_notifier postWorkspacesChanged];
    [self notifyLocal];
}

- (void)appsDidChange {
    [_notifier postWorkspacesChanged];
    [self notifyLocal];
}

- (NSUInteger)importShortcutsFromWorkspaces {
    [HCGLayoutMigration clearDeclinedInStore:_store];
    NSUInteger added = [HCGLayoutMigration importShortcutsFromWorkspaces:_workspaceStore intoLibrary:_appLibrary];
    [self reload];
    [_notifier postWorkspacesChanged];
    return added;
}

- (BOOL)restorePreviousLayout:(NSError **)error {
    if (![HCGLayoutMigration restorePreviousLayoutInStore:_store error:error]) return NO;
    _lastMigrationImported = 0;
    [self reload];
    [_notifier postWorkspacesChanged];
    return YES;
}

- (BOOL)hasLayoutBackup {
    return [HCGLayoutMigration hasBackupInStore:_store];
}

- (NSArray<HCGIntegrationStatus *> *)integrationStatuses {
    return [HCGIntegrationCatalog allStatusesWithSettings:_settings probe:_launcher];
}

- (HCGIntegrationStatus *)statusForIntegration:(NSString *)identifier {
    return [HCGIntegrationCatalog statusForIdentifier:identifier settings:_settings probe:_launcher];
}

@end
