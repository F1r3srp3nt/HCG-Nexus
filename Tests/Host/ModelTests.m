#import "HCGTestHarness.h"
#import "HCGCore.h"

#pragma mark - Settings

static void testSettingsDefaultsStartDisabled(void) {
    HCGSettings *s = [HCGSettings defaultSettings];
    HCG_CHECK(!s.enabled, "fresh install must be disabled");
    HCG_CHECK_EQ_INT(s.handleSide, HCGHandleSideRight);
    HCG_CHECK(s.keyboardSafeZone, "keyboard safe zone defaults on");
    HCG_CHECK(s.animationsEnabled && s.hapticsEnabled, "animations/haptics default on");
    HCG_CHECK_EQ_INT(s.terminalVariant, HCGTerminalVariantNone);
    HCG_CHECK(!s.newsConnected, "integrations start unconnected");

    HCGMemoryKeyValueStore *empty = [[HCGMemoryKeyValueStore alloc] init];
    HCGSettings *loaded = [HCGSettings settingsFromStore:empty];
    HCG_CHECK(!loaded.enabled, "missing preference file must read as disabled");
}

static void testSettingsClamping(void) {
    HCGSettings *s = [HCGSettings defaultSettings];
    s.handlePosition = 7.0;
    HCG_CHECK_NEAR(s.handlePosition, 1.0, 1e-9);
    s.handlePosition = -3;
    HCG_CHECK_NEAR(s.handlePosition, 0.0, 1e-9);
    s.handlePosition = NAN;
    HCG_CHECK_NEAR(s.handlePosition, 0.0, 1e-9);
    s.handleOpacity = 0.0;
    HCG_CHECK_NEAR(s.handleOpacity, [HCGSettings minimumHandleOpacity], 1e-9);
    s.handleSide = (HCGHandleSide)42;
    HCG_CHECK_EQ_INT(s.handleSide, HCGHandleSideRight);
    s.terminalVariant = (HCGTerminalVariant)9;
    HCG_CHECK_EQ_INT(s.terminalVariant, HCGTerminalVariantNone);
}

static void testSettingsPersistenceAndTypeSafety(void) {
    HCGMemoryKeyValueStore *store = [[HCGMemoryKeyValueStore alloc] init];
    HCGSettings *s = [HCGSettings defaultSettings];
    s.enabled = YES;
    s.handleSide = HCGHandleSideLeft;
    s.handlePosition = 0.8;
    s.hapticsEnabled = NO;
    s.terminalVariant = HCGTerminalVariantUnleashed;
    [s writeToStore:store];
    HCGSettings *reloaded = [HCGSettings settingsFromStore:store];
    HCG_CHECK([reloaded isEqual:s], "round trip must preserve values");

    [store setObject:@"yes" forKey:HCGSettingEnabled];
    [store setObject:[NSArray array] forKey:HCGSettingHandlePosition];
    [store setObject:[NSNumber numberWithDouble:99] forKey:HCGSettingHandleOpacity];
    HCGSettings *bad = [HCGSettings settingsFromStore:store];
    HCG_CHECK(!bad.enabled, "a string is not a valid 'enabled' value; must fail closed");
    HCG_CHECK_NEAR(bad.handlePosition, 0.35, 1e-9);
    HCG_CHECK_NEAR(bad.handleOpacity, 1.0, 1e-9);
}

static void testSettingsResetPreservesEnabledAndIntegrations(void) {
    HCGSettings *s = [HCGSettings defaultSettings];
    s.enabled = YES;
    s.newsConnected = YES;
    s.terminalVariant = HCGTerminalVariantStandard;
    s.handleSide = HCGHandleSideLeft;
    s.handleOpacity = 0.3;
    s.animationsEnabled = NO;
    [s resetPreservingEnabledAndIntegrations];
    HCG_CHECK(s.enabled, "reset must not toggle enablement");
    HCG_CHECK(s.newsConnected && s.terminalVariant == HCGTerminalVariantStandard, "reset keeps integration choices");
    HCG_CHECK_EQ_INT(s.handleSide, HCGHandleSideRight);
    HCG_CHECK(s.animationsEnabled, "reset restores animations");
}

void HCGRunSettingsTests(void) {
    HCG_RUN(testSettingsDefaultsStartDisabled);
    HCG_RUN(testSettingsClamping);
    HCG_RUN(testSettingsPersistenceAndTypeSafety);
    HCG_RUN(testSettingsResetPreservesEnabledAndIntegrations);
}

#pragma mark - Actions

static void testActionValidation(void) {
    HCG_CHECK([HCGAction validationErrorForKind:HCGActionKindApp title:@"Notes" target:@"com.apple.mobilenotes"] == nil, "valid bundle id");
    HCG_CHECK([HCGAction validationErrorForKind:HCGActionKindApp title:@"Bad" target:@"notes"] != nil, "bundle id needs a dot");
    HCG_CHECK([HCGAction validationErrorForKind:HCGActionKindApp title:@"Bad" target:@"com..apple"] != nil, "no empty components");
    HCG_CHECK([HCGAction validationErrorForKind:HCGActionKindApp title:@"Bad" target:@"com.apple/x"] != nil, "no slashes");
    HCG_CHECK([HCGAction validationErrorForKind:HCGActionKindApp title:@"   " target:@"com.apple.x"] != nil, "blank title rejected");
    HCG_CHECK([HCGAction validationErrorForKind:HCGActionKindURL title:@"Site" target:@"https://example.com/a"] == nil, "https ok");
    HCG_CHECK([HCGAction validationErrorForKind:HCGActionKindURL title:@"Site" target:@"https://"] != nil, "https without host rejected");
    HCG_CHECK([HCGAction validationErrorForKind:HCGActionKindURL title:@"Site" target:@"example.com"] != nil, "scheme required");
    HCG_CHECK([HCGAction validationErrorForKind:HCGActionKindURL title:@"F" target:@"file:///etc/passwd"] != nil, "file: blocked");
    HCG_CHECK([HCGAction validationErrorForKind:HCGActionKindURL title:@"J" target:@"javascript:alert(1)"] != nil, "javascript: blocked");
    HCG_CHECK([HCGAction validationErrorForKind:HCGActionKindIntegration title:@"T" target:@"terminal"] == nil, "known integration");
    HCG_CHECK([HCGAction validationErrorForKind:HCGActionKindIntegration title:@"X" target:@"erp-admin"] != nil, "unknown integration rejected");

    NSError *error = [HCGAction validationErrorForKind:HCGActionKindApp title:@"Bad" target:@"notes"];
    HCG_CHECK([[[error userInfo] objectForKey:NSLocalizedRecoverySuggestionErrorKey] length] > 0, "errors carry a recovery suggestion");
}

static void testActionDictionaryRoundTrip(void) {
    HCGAction *a = [HCGAction actionWithKind:HCGActionKindURL title:@"  Docs " target:@"https://example.com" symbol:@"book"];
    HCG_CHECK_EQ_STR(a.title, @"Docs");
    HCGAction *b = [HCGAction actionFromDictionary:[a dictionaryRepresentation] error:NULL];
    HCG_CHECK([a isEqual:b], "round trip equal");
    NSMutableDictionary *broken = [[a dictionaryRepresentation] mutableCopy];
    [broken setObject:@"teleport" forKey:@"kind"];
    NSError *error = nil;
    HCG_CHECK([HCGAction actionFromDictionary:broken error:&error] == nil && error != nil, "unknown kind rejected");
    HCG_CHECK([HCGAction actionFromDictionary:(NSDictionary *)@"nope" error:NULL] == nil, "non-dictionary rejected");
}

void HCGRunActionTests(void) {
    HCG_RUN(testActionValidation);
    HCG_RUN(testActionDictionaryRoundTrip);
}

#pragma mark - Workspace store

static void testFirstLoadSeedsPresets(void) {
    HCGMemoryKeyValueStore *kv = [[HCGMemoryKeyValueStore alloc] init];
    HCGWorkspaceStore *store = [[HCGWorkspaceStore alloc] initWithStore:kv];
    [store load];
    HCG_CHECK(store.seededOnLoad, "first run seeds");
    HCG_CHECK_EQ_INT(store.workspaces.count, 4);
    NSArray *expected = [NSArray arrayWithObjects:@"Command", @"Developer", @"Studio", @"Infrastructure", nil];
    NSUInteger i;
    for (i = 0; i < 4 && i < store.workspaces.count; i++) {
        HCG_CHECK_EQ_STR([[store.workspaces objectAtIndex:i] name], [expected objectAtIndex:i]);
        HCG_CHECK([[[store.workspaces objectAtIndex:i] actions] count] > 0, "preset has shortcuts");
    }
    HCG_CHECK_EQ_STR(store.activeWorkspace.name, @"Command");
    HCG_CHECK([kv objectForKey:HCGStoreKeyWorkspaces] != nil, "seed is persisted immediately");

    HCGWorkspaceStore *again = [[HCGWorkspaceStore alloc] initWithStore:kv];
    [again load];
    HCG_CHECK(!again.seededOnLoad, "second launch must not reseed");
    HCG_CHECK_EQ_INT(again.workspaces.count, 4);
}

static void testCreateRenameReorderDeletePersist(void) {
    HCGMemoryKeyValueStore *kv = [[HCGMemoryKeyValueStore alloc] init];
    HCGWorkspaceStore *store = [[HCGWorkspaceStore alloc] initWithStore:kv];
    [store load];
    NSError *error = nil;

    HCGWorkspace *ops = [store createWorkspaceNamed:@"  Ops  " preset:HCGPresetCustom error:&error];
    HCG_CHECK(ops != nil && error == nil, "create custom");
    HCG_CHECK_EQ_STR(ops.name, @"Ops");
    HCG_CHECK_EQ_INT(ops.actions.count, 0);

    HCGWorkspace *dup = [store createWorkspaceNamed:@"ops" preset:HCGPresetCustom error:&error];
    HCG_CHECK(dup == nil && error.code == HCGErrorDuplicateName, "case-insensitive duplicate rejected");

    error = nil;
    HCGWorkspace *studio2 = [store createWorkspaceNamed:nil preset:HCGPresetStudio error:&error];
    HCG_CHECK_EQ_STR(studio2.name, @"Studio 2");

    HCG_CHECK([store renameWorkspace:ops.identifier to:@"Operations" error:&error], "rename");
    HCG_CHECK(![store renameWorkspace:ops.identifier to:@"   " error:&error] && error.code == HCGErrorInvalidName, "blank rename rejected");
    HCG_CHECK(![store renameWorkspace:ops.identifier to:@"Studio" error:&error] && error.code == HCGErrorDuplicateName, "rename to existing rejected");
    HCG_CHECK(![store renameWorkspace:ops.identifier to:@"012345678901234567890123456789012" error:&error], "too long rejected");
    HCG_CHECK([store renameWorkspace:ops.identifier to:@"operations" error:&error], "renaming to a different case of itself is fine");

    NSUInteger opsIndex = [store indexOfWorkspaceWithIdentifier:ops.identifier];
    HCG_CHECK([store moveWorkspaceFromIndex:opsIndex toIndex:0 error:&error], "reorder");
    HCG_CHECK_EQ_STR([[store.workspaces objectAtIndex:0] name], @"operations");
    HCG_CHECK(![store moveWorkspaceFromIndex:99 toIndex:0 error:&error], "out of range reorder rejected");

    HCGWorkspaceStore *reloaded = [[HCGWorkspaceStore alloc] initWithStore:kv];
    [reloaded load];
    HCG_CHECK_EQ_INT(reloaded.workspaces.count, 6);
    HCG_CHECK_EQ_STR([[reloaded.workspaces objectAtIndex:0] name], @"operations");
    HCG_CHECK_EQ_STR([[reloaded.workspaces objectAtIndex:5] name], @"Studio 2");

    HCG_CHECK([store deleteWorkspace:studio2.identifier error:&error], "delete");
    HCG_CHECK(![store deleteWorkspace:studio2.identifier error:&error] && error.code == HCGErrorNotFound, "double delete reports not found");
    [reloaded load];
    HCG_CHECK_EQ_INT(reloaded.workspaces.count, 5);
}

static void testDeletingActiveSelectsNeighbourAndEmptyListPersists(void) {
    HCGMemoryKeyValueStore *kv = [[HCGMemoryKeyValueStore alloc] init];
    HCGWorkspaceStore *store = [[HCGWorkspaceStore alloc] initWithStore:kv];
    [store load];
    NSError *error = nil;
    HCGWorkspace *developer = [store.workspaces objectAtIndex:1];
    HCG_CHECK([store setActiveWorkspace:developer.identifier error:&error], "activate");
    HCG_CHECK([store deleteWorkspace:developer.identifier error:&error], "delete active");
    HCG_CHECK_EQ_STR(store.activeWorkspace.name, @"Studio");

    while (store.workspaces.count > 0) {
        [store deleteWorkspace:[[store.workspaces objectAtIndex:0] identifier] error:NULL];
    }
    HCG_CHECK(store.activeWorkspace == nil, "no active workspace when empty");
    HCGWorkspaceStore *reloaded = [[HCGWorkspaceStore alloc] initWithStore:kv];
    [reloaded load];
    HCG_CHECK(!reloaded.seededOnLoad && reloaded.workspaces.count == 0, "deleting everything must not resurrect presets");
}

static void testActionsInWorkspace(void) {
    HCGMemoryKeyValueStore *kv = [[HCGMemoryKeyValueStore alloc] init];
    HCGWorkspaceStore *store = [[HCGWorkspaceStore alloc] initWithStore:kv];
    [store load];
    NSError *error = nil;
    HCGWorkspace *ws = [store createWorkspaceNamed:@"Mine" preset:HCGPresetCustom error:&error];
    HCGAction *a = [HCGAction actionWithKind:HCGActionKindApp title:@"Notes" target:@"com.apple.mobilenotes" symbol:nil];
    HCGAction *b = [HCGAction actionWithKind:HCGActionKindURL title:@"Docs" target:@"https://example.com" symbol:nil];
    HCGAction *bad = [HCGAction actionWithKind:HCGActionKindURL title:@"Bad" target:@"file:///x" symbol:nil];
    HCG_CHECK([store addAction:a toWorkspace:ws.identifier error:&error], "add a");
    HCG_CHECK([store addAction:b toWorkspace:ws.identifier error:&error], "add b");
    HCG_CHECK(![store addAction:bad toWorkspace:ws.identifier error:&error] && error.code == HCGErrorUnsupportedAction, "invalid action rejected");
    HCG_CHECK(![store addAction:a toWorkspace:ws.identifier error:&error] && error.code == HCGErrorDuplicateName, "duplicate id rejected");
    HCG_CHECK([store moveActionInWorkspace:ws.identifier fromIndex:1 toIndex:0 error:&error], "move");
    HCG_CHECK_EQ_STR([[ws.actions objectAtIndex:0] title], @"Docs");
    HCG_CHECK([store removeAction:b.identifier fromWorkspace:ws.identifier error:&error], "remove");

    HCGWorkspaceStore *reloaded = [[HCGWorkspaceStore alloc] initWithStore:kv];
    [reloaded load];
    HCGWorkspace *ws2 = [reloaded workspaceWithIdentifier:ws.identifier];
    HCG_CHECK_EQ_INT(ws2.actions.count, 1);
    HCG_CHECK_EQ_STR([[ws2.actions objectAtIndex:0] target], @"com.apple.mobilenotes");
}

static void testCorruptDataIsDroppedNotFatal(void) {
    HCGMemoryKeyValueStore *kv = [[HCGMemoryKeyValueStore alloc] init];
    NSDictionary *goodAction = [[HCGAction actionWithKind:HCGActionKindApp title:@"Notes" target:@"com.apple.mobilenotes" symbol:nil] dictionaryRepresentation];
    NSDictionary *badAction = [NSDictionary dictionaryWithObjectsAndKeys:@"x", @"id", @"t", @"title", @"app", @"kind", @"nodot", @"target", nil];
    NSDictionary *good = [NSDictionary dictionaryWithObjectsAndKeys:
                          @"W1", @"id", @"Keep", @"name", @"custom", @"preset",
                          [NSArray arrayWithObjects:goodAction, badAction, @"junk", nil], @"actions", nil];
    NSDictionary *dupe = [NSDictionary dictionaryWithObjectsAndKeys:@"W1", @"id", @"Dup", @"name", nil];
    NSDictionary *nameless = [NSDictionary dictionaryWithObjectsAndKeys:@"W2", @"id", nil];
    [kv setObject:[NSArray arrayWithObjects:good, dupe, nameless, @"junk", nil] forKey:HCGStoreKeyWorkspaces];
    [kv setObject:@"missing" forKey:HCGStoreKeyActiveWorkspace];
    HCGWorkspaceStore *store = [[HCGWorkspaceStore alloc] initWithStore:kv];
    [store load];
    HCG_CHECK_EQ_INT(store.workspaces.count, 1);
    HCG_CHECK_EQ_INT([[[store.workspaces objectAtIndex:0] actions] count], 1);
    HCG_CHECK_EQ_INT(store.droppedEntriesOnLoad, 5);
    HCG_CHECK_EQ_STR(store.activeWorkspace.identifier, @"W1");

    [kv setObject:@"not a list" forKey:HCGStoreKeyWorkspaces];
    [store load];
    HCG_CHECK_EQ_INT(store.workspaces.count, 0);
    HCG_CHECK(!store.seededOnLoad, "corrupt (present) data must not be silently replaced by presets");
}

static void testWorkspaceLimit(void) {
    HCGMemoryKeyValueStore *kv = [[HCGMemoryKeyValueStore alloc] init];
    HCGWorkspaceStore *store = [[HCGWorkspaceStore alloc] initWithStore:kv];
    [store load];
    NSError *error = nil;
    while (store.workspaces.count < HCGMaxWorkspaces) {
        HCG_CHECK([store createWorkspaceNamed:nil preset:HCGPresetCustom error:&error] != nil, "create up to limit");
        if (error) break;
    }
    HCG_CHECK([store createWorkspaceNamed:nil preset:HCGPresetCustom error:&error] == nil && error.code == HCGErrorLimitReached, "limit enforced");
}

void HCGRunWorkspaceStoreTests(void) {
    HCG_RUN(testFirstLoadSeedsPresets);
    HCG_RUN(testCreateRenameReorderDeletePersist);
    HCG_RUN(testDeletingActiveSelectsNeighbourAndEmptyListPersists);
    HCG_RUN(testActionsInWorkspace);
    HCG_RUN(testCorruptDataIsDroppedNotFatal);
    HCG_RUN(testWorkspaceLimit);
}

#pragma mark - Recents

static void testRecentsBoundedDedupedPersisted(void) {
    HCGMemoryKeyValueStore *kv = [[HCGMemoryKeyValueStore alloc] init];
    HCGRecents *recents = [[HCGRecents alloc] initWithStore:kv];
    [recents load];
    HCGAction *first = nil;
    int i;
    for (i = 0; i < 15; i++) {
        HCGAction *a = [HCGAction actionWithKind:HCGActionKindApp title:[NSString stringWithFormat:@"App %d", i]
                                          target:[NSString stringWithFormat:@"com.example.app%d", i] symbol:nil];
        if (i == 0) first = a;
        [recents recordAction:a succeeded:(i % 2 == 0) message:(i % 2 ? @"App not installed" : nil) date:[NSDate dateWithTimeIntervalSince1970:1000 + i]];
    }
    HCG_CHECK_EQ_INT(recents.entries.count, HCGMaxRecents);
    HCG_CHECK_EQ_STR([[[recents.entries objectAtIndex:0] action] title], @"App 14");
    HCGAction *again = [[[recents.entries objectAtIndex:5] action] copy];
    [recents recordAction:again succeeded:YES message:nil date:[NSDate date]];
    HCG_CHECK_EQ_INT(recents.entries.count, HCGMaxRecents);
    HCG_CHECK_EQ_STR([[[recents.entries objectAtIndex:0] action] identifier], again.identifier);

    HCGRecents *reloaded = [[HCGRecents alloc] initWithStore:kv];
    [reloaded load];
    HCG_CHECK_EQ_INT(reloaded.entries.count, HCGMaxRecents);
    HCG_CHECK_EQ_STR([[[reloaded.entries objectAtIndex:0] action] identifier], again.identifier);
    HCG_CHECK(first != nil, "sanity");

    [reloaded clear];
    [recents load];
    HCG_CHECK_EQ_INT(recents.entries.count, 0);
}

void HCGRunRecentsTests(void) {
    HCG_RUN(testRecentsBoundedDedupedPersisted);
}

#pragma mark - Search

static void testSearchRanking(void) {
    HCGWorkspace *active = [[HCGWorkspace alloc] initWithName:@"A" preset:HCGPresetCustom];
    [active appendAction:[HCGAction actionWithKind:HCGActionKindApp title:@"Mail" target:@"com.apple.mobilemail" symbol:nil]];
    [active appendAction:[HCGAction actionWithKind:HCGActionKindApp title:@"Voice Memos" target:@"com.apple.VoiceMemos" symbol:nil]];
    HCGWorkspace *other = [[HCGWorkspace alloc] initWithName:@"B" preset:HCGPresetCustom];
    [other appendAction:[HCGAction actionWithKind:HCGActionKindApp title:@"Mémo Café" target:@"com.example.cafe" symbol:nil]];
    [other appendAction:[HCGAction actionWithKind:HCGActionKindApp title:@"Notes" target:@"com.apple.mobilenotes" symbol:nil]];
    NSArray *all = [NSArray arrayWithObjects:active, other, nil];

    NSArray *empty = [HCGSearch resultsForQuery:@"  " inWorkspaces:all activeWorkspace:active];
    HCG_CHECK_EQ_INT(empty.count, 2);

    NSArray *memo = [HCGSearch resultsForQuery:@"MEMO" inWorkspaces:all activeWorkspace:active];
    HCG_CHECK_EQ_INT(memo.count, 2);
    if (memo.count == 2) {
        // "Mémo Café" is a title-prefix match (score 0) after diacritic folding;
        // "Voice Memos" is a word-prefix match (score 1).
        HCG_CHECK_EQ_STR([[[memo objectAtIndex:0] action] title], @"Mémo Café");
        HCG_CHECK_EQ_STR([[[memo objectAtIndex:1] workspace] name], @"A");
    }
    NSArray *byTarget = [HCGSearch resultsForQuery:@"mobilenotes" inWorkspaces:all activeWorkspace:active];
    HCG_CHECK_EQ_INT(byTarget.count, 1);
    HCG_CHECK_EQ_INT([HCGSearch resultsForQuery:@"zzz" inWorkspaces:all activeWorkspace:active].count, 0);
    HCG_CHECK_EQ_INT([HCGSearch resultsForQuery:nil inWorkspaces:all activeWorkspace:nil].count, 0);
}

void HCGRunSearchTests(void) {
    HCG_RUN(testSearchRanking);
}

#pragma mark - Integrations

@interface HCGFakeProbe : NSObject <HCGAppInstallationProbe> {
    NSSet *_installed;
    BOOL _canDetermine;
    BOOL _canLaunch;
}
- (instancetype)initWithInstalled:(NSSet *)installed canDetermine:(BOOL)canDetermine;
- (instancetype)initSandboxedApp; // like the standalone app: no bundle-ID launching
@end

@implementation HCGFakeProbe
- (instancetype)initWithInstalled:(NSSet *)installed canDetermine:(BOOL)canDetermine {
    if ((self = [super init])) { _installed = [installed copy]; _canDetermine = canDetermine; _canLaunch = YES; }
    return self;
}
- (instancetype)initSandboxedApp {
    if ((self = [super init])) { _installed = [[NSSet alloc] init]; _canDetermine = NO; _canLaunch = NO; }
    return self;
}
- (BOOL)canLaunchApplicationsByBundleIdentifier { return _canLaunch; }
- (BOOL)canDetermineInstallation { return _canDetermine; }
- (BOOL)isApplicationInstalled:(NSString *)bundleIdentifier { return [_installed containsObject:bundleIdentifier]; }
@end

static void testUnconfiguredIntegrationsAreNotConnected(void) {
    HCGSettings *s = [HCGSettings defaultSettings];
    HCGFakeProbe *probe = [[HCGFakeProbe alloc] initWithInstalled:[NSSet setWithObjects:HCGTerminalBundleIdentifier, HCGNewsBundleIdentifier, nil] canDetermine:YES];
    NSArray *statuses = [HCGIntegrationCatalog allStatusesWithSettings:s probe:probe];
    HCG_CHECK_EQ_INT(statuses.count, 2);
    NSUInteger i;
    for (i = 0; i < statuses.count; i++) {
        HCGIntegrationStatus *st = [statuses objectAtIndex:i];
        HCG_CHECK_EQ_STR(st.headline, @"Not connected");
        HCG_CHECK(!st.canLaunch, "unconfigured integration must not launch");
        HCG_CHECK(st.detail.length > 0, "explains why");
    }
}

static void testConfiguredIntegrations(void) {
    HCGSettings *s = [HCGSettings defaultSettings];
    s.terminalVariant = HCGTerminalVariantUnleashed;
    s.newsConnected = YES;
    HCGFakeProbe *probe = [[HCGFakeProbe alloc] initWithInstalled:[NSSet setWithObject:HCGTerminalUnleashedBundleIdentifier] canDetermine:YES];

    HCGIntegrationStatus *t = [HCGIntegrationCatalog statusForIdentifier:HCGIntegrationTerminal settings:s probe:probe];
    HCG_CHECK_EQ_INT(t.state, HCGIntegrationStateReady);
    HCG_CHECK_EQ_STR(t.launchBundleIdentifier, @"com.hakmicapitalgroup.hcgterminal.unleashed");
    HCG_CHECK(t.canLaunch, "ready terminal launches");

    HCGIntegrationStatus *n = [HCGIntegrationCatalog statusForIdentifier:HCGIntegrationNews settings:s probe:probe];
    HCG_CHECK_EQ_INT(n.state, HCGIntegrationStateAppMissing);
    HCG_CHECK(!n.canLaunch, "missing app cannot launch");

    HCGIntegrationStatus *u = [HCGIntegrationCatalog statusForIdentifier:HCGIntegrationNews settings:s probe:nil];
    HCG_CHECK_EQ_INT(u.state, HCGIntegrationStateUnverified);

    // No phone-reachable contract exists for these, whatever the settings say.
    HCGIntegrationStatus *server = [HCGIntegrationCatalog statusForIdentifier:HCGIntegrationServer settings:s probe:probe];
    HCGIntegrationStatus *maker = [HCGIntegrationCatalog statusForIdentifier:HCGIntegrationExecutableMaker settings:s probe:probe];
    HCG_CHECK_EQ_STR(server.headline, @"Not connected");
    HCG_CHECK_EQ_STR(maker.headline, @"Not connected");
    HCG_CHECK(!server.canLaunch && !maker.canLaunch, "no fabricated launch targets");
}

// Standalone app: configured app integrations must not claim to work.
static void testSandboxedAppReportsBundleLaunchUnavailable(void) {
    HCGSettings *s = [HCGSettings defaultSettings];
    s.terminalVariant = HCGTerminalVariantStandard;
    s.newsConnected = YES;
    HCGFakeProbe *probe = [[HCGFakeProbe alloc] initSandboxedApp];
    NSArray *ids = [NSArray arrayWithObjects:HCGIntegrationTerminal, HCGIntegrationNews, nil];
    NSUInteger i;
    for (i = 0; i < ids.count; i++) {
        HCGIntegrationStatus *st = [HCGIntegrationCatalog statusForIdentifier:[ids objectAtIndex:i] settings:s probe:probe];
        HCG_CHECK_EQ_INT(st.state, HCGIntegrationStateUnavailableHere);
        HCG_CHECK_EQ_STR(st.headline, @"Needs jailbreak package");
        HCG_CHECK(!st.canLaunch, "sandboxed app must not report a launchable integration");
        HCG_CHECK([st.detail rangeOfString:@"bundle identifier"].location != NSNotFound, "explains why");
    }
    // Unconfigured stays "Not connected"; Server/Executable Maker unchanged.
    HCGSettings *off = [HCGSettings defaultSettings];
    HCGIntegrationStatus *t = [HCGIntegrationCatalog statusForIdentifier:HCGIntegrationTerminal settings:off probe:probe];
    HCG_CHECK_EQ_STR(t.headline, @"Not connected");
    HCGIntegrationStatus *server = [HCGIntegrationCatalog statusForIdentifier:HCGIntegrationServer settings:s probe:probe];
    HCG_CHECK_EQ_STR(server.headline, @"Not connected");
}

// Placeholders must not be offered: no phone-reachable interface exists.
static void testOnlyWorkingIntegrationsAreOffered(void) {
    NSArray *offered = [HCGIntegrationCatalog offeredIdentifiers];
    HCG_CHECK([offered containsObject:HCGIntegrationTerminal] && [offered containsObject:HCGIntegrationNews], "terminal + news offered");
    HCG_CHECK(![offered containsObject:HCGIntegrationServer] && ![offered containsObject:HCGIntegrationExecutableMaker], "server/maker not offered");
    // Saved shortcuts from older builds still validate.
    HCG_CHECK([HCGAction validationErrorForKind:HCGActionKindIntegration title:@"S" target:HCGIntegrationServer] == nil, "legacy shortcut validates");
    NSArray *presets = [HCGWorkspacePresets presetIdentifiers];
    NSUInteger p, a;
    for (p = 0; p < presets.count; p++) {
        HCGWorkspace *ws = [HCGWorkspacePresets workspaceForPreset:[presets objectAtIndex:p] name:nil];
        for (a = 0; a < ws.actions.count; a++) {
            HCGAction *action = [ws.actions objectAtIndex:a];
            if (action.kind == HCGActionKindIntegration) {
                HCG_CHECK([offered containsObject:action.target], "preset %s uses unoffered integration %s",
                          [[presets objectAtIndex:p] UTF8String], [action.target UTF8String]);
            }
        }
    }
}

void HCGRunIntegrationTests(void) {
    HCG_RUN(testOnlyWorkingIntegrationsAreOffered);
    HCG_RUN(testUnconfiguredIntegrationsAreNotConnected);
    HCG_RUN(testConfiguredIntegrations);
    HCG_RUN(testSandboxedAppReportsBundleLaunchUnavailable);
}
