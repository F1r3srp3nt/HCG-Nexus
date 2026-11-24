// Layout 2 (redesign): settings, App Library, migration + restore, tools,
// products and the account/authentication boundaries.
#import "HCGTestHarness.h"
#import "HCGCore.h"

@interface HCGRedesignProbe : NSObject <HCGAppInstallationProbe> {
    NSSet *_installed;
    BOOL _canDetermine;
    BOOL _canLaunch;
}
- (instancetype)initWithInstalled:(NSSet *)installed canDetermine:(BOOL)canDetermine canLaunch:(BOOL)canLaunch;
@end

@implementation HCGRedesignProbe
- (instancetype)initWithInstalled:(NSSet *)installed canDetermine:(BOOL)canDetermine canLaunch:(BOOL)canLaunch {
    if ((self = [super init])) { _installed = [installed copy]; _canDetermine = canDetermine; _canLaunch = canLaunch; }
    return self;
}
- (BOOL)canLaunchApplicationsByBundleIdentifier { return _canLaunch; }
- (BOOL)canDetermineInstallation { return _canDetermine; }
- (BOOL)isApplicationInstalled:(NSString *)bundleIdentifier { return [_installed containsObject:bundleIdentifier]; }
@end

static HCGAction *App(NSString *title, NSString *bundle) {
    return [HCGAction actionWithKind:HCGActionKindApp title:title target:bundle symbol:nil];
}

static HCGAction *Link(NSString *title, NSString *url) {
    return [HCGAction actionWithKind:HCGActionKindURL title:title target:url symbol:nil];
}

#pragma mark - Settings

static void testPanelAppearanceSettings(void) {
    HCGSettings *defaults = [HCGSettings defaultSettings];
    HCG_CHECK_NEAR(defaults.panelOpacity, 0.72, 0.0001);
    HCG_CHECK_EQ_INT(defaults.panelBlur, HCGPanelBlurStandard);

    HCGSettings *s = [HCGSettings defaultSettings];
    s.panelOpacity = 0.1;
    HCG_CHECK_NEAR(s.panelOpacity, [HCGSettings minimumPanelOpacity], 0.0001);
    s.panelOpacity = 7;
    HCG_CHECK_NEAR(s.panelOpacity, 1.0, 0.0001);
    s.panelBlur = (HCGPanelBlur)42;
    HCG_CHECK_EQ_INT(s.panelBlur, HCGPanelBlurStandard);

    // Readability floor without blur; Reduce Transparency forces an opaque, unblurred panel.
    s.panelOpacity = 0.4;
    s.panelBlur = HCGPanelBlurOff;
    HCG_CHECK_NEAR([s effectivePanelOpacityWithReduceTransparency:NO], 0.6, 0.0001);
    s.panelBlur = HCGPanelBlurLight;
    HCG_CHECK_NEAR([s effectivePanelOpacityWithReduceTransparency:NO], 0.4, 0.0001);
    HCG_CHECK_NEAR([s effectivePanelOpacityWithReduceTransparency:YES], 1.0, 0.0001);
    HCG_CHECK_EQ_INT([s effectivePanelBlurWithReduceTransparency:YES], HCGPanelBlurOff);
    HCG_CHECK_EQ_INT([s effectivePanelBlurWithReduceTransparency:NO], HCGPanelBlurLight);

    // Persists, and wrong types fall back to defaults.
    HCGMemoryKeyValueStore *kv = [[HCGMemoryKeyValueStore alloc] init];
    s.panelOpacity = 0.9;
    s.panelBlur = HCGPanelBlurStrong;
    [s writeToStore:kv];
    HCGSettings *read = [HCGSettings settingsFromStore:kv];
    HCG_CHECK_NEAR(read.panelOpacity, 0.9, 0.0001);
    HCG_CHECK_EQ_INT(read.panelBlur, HCGPanelBlurStrong);
    [kv setObject:@"opaque" forKey:HCGSettingPanelOpacity];
    HCG_CHECK_NEAR([HCGSettings settingsFromStore:kv].panelOpacity, 0.72, 0.0001);
    // Reset restores appearance but keeps the enabled state.
    read.enabled = YES;
    [read resetPreservingEnabledAndIntegrations];
    HCG_CHECK(read.enabled, "reset keeps enabled");
    HCG_CHECK_EQ_INT(read.panelBlur, HCGPanelBlurStandard);
}

#pragma mark - App Library

static void testAppLibraryPersistence(void) {
    HCGMemoryKeyValueStore *kv = [[HCGMemoryKeyValueStore alloc] init];
    HCGAppLibrary *library = [[HCGAppLibrary alloc] initWithStore:kv];
    [library load];
    HCG_CHECK_EQ_INT(library.items.count, 0);
    NSError *error = nil;
    HCGAction *files = [library addItem:App(@"Files", @"com.apple.DocumentsApp") error:&error];
    HCG_CHECK(files != nil, "add app: %s", [[error localizedDescription] UTF8String]);
    HCGAction *docs = [library addItem:Link(@"HCG Docs", @"https://hakmicapitalgroup.com/docs") error:&error];
    HCG_CHECK(docs != nil, "add link");
    HCG_CHECK([library addItem:App(@"Files again", @"COM.APPLE.DOCUMENTSAPP") error:&error] == nil, "duplicate target refused");
    HCG_CHECK_EQ_INT(error.code, HCGErrorDuplicateName);
    HCGAction *integration = [HCGAction actionWithKind:HCGActionKindIntegration title:@"Terminal" target:HCGIntegrationTerminal symbol:nil];
    HCG_CHECK([library addItem:integration error:&error] == nil, "integrations are not Apps");
    HCG_CHECK([library addItem:App(@"Bad", @"not a bundle id") error:&error] == nil, "invalid bundle id refused");

    HCG_CHECK([library setFavourite:YES forItem:docs.identifier error:NULL], "favourite");
    HCG_CHECK([library moveItemFromIndex:1 toIndex:0 error:NULL], "reorder");

    HCGAppLibrary *reloaded = [[HCGAppLibrary alloc] initWithStore:kv];
    [reloaded load];
    HCG_CHECK_EQ_INT(reloaded.items.count, 2);
    HCG_CHECK_EQ_STR([[reloaded.items objectAtIndex:0] identifier], docs.identifier);
    HCG_CHECK([reloaded isFavourite:docs.identifier], "favourite persisted");
    HCG_CHECK(![reloaded isFavourite:files.identifier], "not favourite");
    HCG_CHECK_EQ_INT([reloaded itemsMatchingQuery:@"files" favouritesOnly:NO].count, 1);
    HCG_CHECK_EQ_INT([reloaded itemsMatchingQuery:@"hakmi" favouritesOnly:NO].count, 1);   // matches target
    HCG_CHECK_EQ_INT([reloaded itemsMatchingQuery:nil favouritesOnly:YES].count, 1);
    HCG_CHECK_EQ_INT([reloaded itemsMatchingQuery:@"files" favouritesOnly:YES].count, 0);

    HCG_CHECK([reloaded removeItemWithIdentifier:docs.identifier error:NULL], "remove");
    HCG_CHECK_EQ_INT(reloaded.favouriteIdentifiers.count, 0);

    // Malformed storage is tolerated; bad entries are dropped and counted.
    NSMutableDictionary *junk = [NSMutableDictionary dictionary];
    [junk setObject:[NSArray arrayWithObjects:@"x", [files dictionaryRepresentation], [files dictionaryRepresentation], nil] forKey:@"items"];
    [junk setObject:[NSArray arrayWithObjects:@"missing", [NSNumber numberWithInt:3], nil] forKey:@"favourites"];
    [kv setObject:junk forKey:HCGStoreKeyAppLibrary];
    HCGAppLibrary *tolerant = [[HCGAppLibrary alloc] initWithStore:kv];
    [tolerant load];
    HCG_CHECK_EQ_INT(tolerant.items.count, 1);
    HCG_CHECK_EQ_INT(tolerant.droppedOnLoad, 2);
    HCG_CHECK_EQ_INT(tolerant.favouriteIdentifiers.count, 0);
    [kv setObject:@"garbage" forKey:HCGStoreKeyAppLibrary];
    [tolerant load];
    HCG_CHECK_EQ_INT(tolerant.items.count, 0);
}

static void testWorkspaceQuickActionsAndTools(void) {
    HCGMemoryKeyValueStore *kv = [[HCGMemoryKeyValueStore alloc] init];
    HCGWorkspaceStore *store = [[HCGWorkspaceStore alloc] initWithStore:kv];
    [store load];
    HCGWorkspace *first = [store.workspaces objectAtIndex:0];
    NSArray *quick = [NSArray arrayWithObjects:@"a", @"b", @"a", @"c", @"d", @"e", [NSNumber numberWithInt:1], nil];
    HCG_CHECK([store setQuickActionIdentifiers:quick forWorkspace:first.identifier error:NULL], "set quick actions");
    HCG_CHECK([store setToolIdentifiers:[NSArray arrayWithObject:HCGToolCopyDiagnostics] forWorkspace:first.identifier error:NULL], "set tools");
    HCG_CHECK(![store setToolIdentifiers:[NSArray array] forWorkspace:@"missing" error:NULL], "unknown workspace");

    HCGWorkspaceStore *reloaded = [[HCGWorkspaceStore alloc] initWithStore:kv];
    [reloaded load];
    HCGWorkspace *again = [reloaded workspaceWithIdentifier:first.identifier];
    HCG_CHECK_EQ_INT(again.quickActionIdentifiers.count, HCGWorkspaceMaxQuickActions);   // capped, de-duplicated
    HCG_CHECK_EQ_STR([again.quickActionIdentifiers objectAtIndex:2], @"c");
    HCG_CHECK_EQ_STR([again.toolIdentifiers objectAtIndex:0], HCGToolCopyDiagnostics);
    HCG_CHECK_EQ_INT(again.actions.count, first.actions.count);                           // shortcuts untouched

    // A workspace written by an older build (no new keys) reads as empty lists.
    NSMutableDictionary *old = [[again dictionaryRepresentation] mutableCopy];
    [old removeObjectForKey:@"quickActions"];
    [old setObject:@"not a list" forKey:@"tools"];
    HCGWorkspace *legacy = [HCGWorkspace workspaceFromDictionary:old droppedActions:NULL];
    HCG_CHECK(legacy != nil, "legacy decodes");
    HCG_CHECK_EQ_INT(legacy.quickActionIdentifiers.count, 0);
    HCG_CHECK_EQ_INT(legacy.toolIdentifiers.count, 0);
}

#pragma mark - Migration

static void testMigrationKeepsShortcutsAndIsReversible(void) {
    HCGMemoryKeyValueStore *kv = [[HCGMemoryKeyValueStore alloc] init];
    HCGWorkspaceStore *store = [[HCGWorkspaceStore alloc] initWithStore:kv];
    [store load];
    // A user's own workspace from 0.2: app, link, an integration, and a duplicate of a preset app.
    NSError *error = nil;
    HCGWorkspace *mine = [store createWorkspaceNamed:@"Trading" preset:HCGPresetCustom error:&error];
    [store addAction:App(@"Broker", @"com.example.broker") toWorkspace:mine.identifier error:NULL];
    [store addAction:Link(@"Desk", @"https://desk.example.com") toWorkspace:mine.identifier error:NULL];
    [store addAction:[HCGAction actionWithKind:HCGActionKindIntegration title:@"News" target:HCGIntegrationNews symbol:nil]
         toWorkspace:mine.identifier error:NULL];
    [store addAction:App(@"Files", @"com.apple.DocumentsApp") toWorkspace:mine.identifier error:NULL];
    [store setActiveWorkspace:mine.identifier error:NULL];
    id beforeWorkspaces = [[kv objectForKey:HCGStoreKeyWorkspaces] copy];
    id beforeActive = [[kv objectForKey:HCGStoreKeyActiveWorkspace] copy];
    NSUInteger totalActionsBefore = 0, appLinkKeys = 0;
    NSMutableSet *keys = [NSMutableSet set];
    NSUInteger w, a;
    for (w = 0; w < store.workspaces.count; w++) {
        NSArray *actions = [[store.workspaces objectAtIndex:w] actions];
        totalActionsBefore += actions.count;
        for (a = 0; a < actions.count; a++) {
            HCGAction *action = [actions objectAtIndex:a];
            if ([HCGAppLibrary acceptsKind:action.kind]) [keys addObject:[HCGAppLibrary keyForAction:action]];
        }
    }
    appLinkKeys = keys.count;
    HCG_CHECK_EQ_INT([HCGLayoutMigration layoutVersionInStore:kv], 1);

    HCGAppLibrary *library = [[HCGAppLibrary alloc] initWithStore:kv];
    [library load];
    NSUInteger imported = 0;
    HCG_CHECK_EQ_INT([HCGLayoutMigration migrateStore:kv workspaceStore:store library:library imported:&imported], HCGLayoutMigrationMigrated);
    HCG_CHECK_EQ_INT(imported, appLinkKeys);                       // every distinct app/link shortcut, once
    HCG_CHECK_EQ_STR([[library.items objectAtIndex:0] title], @"Broker"); // active workspace first
    HCG_CHECK([HCGLayoutMigration hasBackupInStore:kv], "backup written");
    HCG_CHECK_EQ_INT([HCGLayoutMigration layoutVersionInStore:kv], HCGCurrentLayoutVersion);

    // Reload from storage: shortcuts retained, quick actions resolve to Apps entries, tools default by preset.
    HCGWorkspaceStore *after = [[HCGWorkspaceStore alloc] initWithStore:kv];
    [after load];
    HCGAppLibrary *afterLibrary = [[HCGAppLibrary alloc] initWithStore:kv];
    [afterLibrary load];
    NSUInteger totalAfter = 0;
    for (w = 0; w < after.workspaces.count; w++) {
        HCGWorkspace *workspace = [after.workspaces objectAtIndex:w];
        totalAfter += workspace.actions.count;
        HCG_CHECK(workspace.toolIdentifiers.count > 0, "tools seeded for %s", [workspace.name UTF8String]);
        for (a = 0; a < workspace.quickActionIdentifiers.count; a++) {
            HCG_CHECK([afterLibrary itemWithIdentifier:[workspace.quickActionIdentifiers objectAtIndex:a]] != nil, "quick action resolves");
        }
    }
    HCG_CHECK_EQ_INT(totalAfter, totalActionsBefore);
    HCGWorkspace *trading = [after workspaceWithIdentifier:mine.identifier];
    HCG_CHECK_EQ_INT(trading.quickActionIdentifiers.count, 3);   // Broker, Desk, Files (the integration is not an App)
    HCG_CHECK_EQ_STR(after.activeWorkspace.identifier, mine.identifier);

    // Idempotent.
    HCG_CHECK_EQ_INT([HCGLayoutMigration migrateStore:kv workspaceStore:after library:afterLibrary imported:NULL], HCGLayoutMigrationAlreadyCurrent);

    // Restore writes the backup back verbatim, empties Apps and is not re-applied silently.
    NSError *restoreError = nil;
    HCG_CHECK([HCGLayoutMigration restorePreviousLayoutInStore:kv error:&restoreError], "restore");
    HCG_CHECK([[kv objectForKey:HCGStoreKeyWorkspaces] isEqual:beforeWorkspaces], "workspaces restored verbatim");
    HCG_CHECK([[kv objectForKey:HCGStoreKeyActiveWorkspace] isEqual:beforeActive], "active restored");
    HCG_CHECK([kv objectForKey:HCGStoreKeyAppLibrary] == nil, "Apps emptied");
    HCGWorkspaceStore *restored = [[HCGWorkspaceStore alloc] initWithStore:kv];
    [restored load];
    HCGAppLibrary *restoredLibrary = [[HCGAppLibrary alloc] initWithStore:kv];
    [restoredLibrary load];
    HCG_CHECK_EQ_INT([HCGLayoutMigration migrateStore:kv workspaceStore:restored library:restoredLibrary imported:NULL], HCGLayoutMigrationDeclined);
    HCG_CHECK_EQ_INT(restoredLibrary.items.count, 0);
    // The user can opt back in; the original backup is kept, not overwritten.
    [HCGLayoutMigration clearDeclinedInStore:kv];
    HCG_CHECK_EQ_INT([HCGLayoutMigration migrateStore:kv workspaceStore:restored library:restoredLibrary imported:NULL], HCGLayoutMigrationMigrated);
    HCG_CHECK([[[kv objectForKey:HCGStoreKeyLayoutBackup] objectForKey:@"workspaces"] isEqual:beforeWorkspaces], "backup kept");
}

static void testFreshInstallMigration(void) {
    HCGMemoryKeyValueStore *kv = [[HCGMemoryKeyValueStore alloc] init];
    HCGWorkspaceStore *store = [[HCGWorkspaceStore alloc] initWithStore:kv];
    [store load];
    HCGAppLibrary *library = [[HCGAppLibrary alloc] initWithStore:kv];
    [library load];
    [HCGLayoutMigration migrateStore:kv workspaceStore:store library:library imported:NULL];
    HCG_CHECK(library.items.count > 0, "preset shortcuts become Apps");
    HCG_CHECK(![HCGLayoutMigration hasBackupInStore:kv] || [[kv objectForKey:HCGStoreKeyWorkspaces] isKindOfClass:[NSArray class]], "backup only of stored data");
    NSError *error = nil;
    HCG_CHECK([HCGLayoutMigration importShortcutsFromWorkspaces:store intoLibrary:library] == 0, "import is idempotent");
    (void)error;
}

static void testRestoreWithoutBackupFails(void) {
    HCGMemoryKeyValueStore *kv = [[HCGMemoryKeyValueStore alloc] init];
    NSError *error = nil;
    HCG_CHECK(![HCGLayoutMigration restorePreviousLayoutInStore:kv error:&error], "no backup");
    HCG_CHECK_EQ_INT(error.code, HCGErrorNotFound);
}

#pragma mark - Tools

static void testToolAvailability(void) {
    HCGToolEnvironment overlay = { HCGHostOverlay, YES, NO };
    HCGToolEnvironment app = { HCGHostStandaloneApp, YES, YES };
    HCGToolEnvironment settingsApp = { HCGHostSettingsApp, NO, NO };
    HCGToolEnvironment preview = { HCGHostPreview, YES, NO };
    HCG_CHECK([HCGToolCatalog unavailableReasonForTool:HCGToolDisableNexus environment:overlay] == nil, "overlay can turn off");
    HCG_CHECK([HCGToolCatalog unavailableReasonForTool:HCGToolDisableNexus environment:app] != nil, "app has no handle");
    HCG_CHECK([HCGToolCatalog unavailableReasonForTool:HCGToolDisableNexus environment:preview] != nil, "preview has no handle");
    HCG_CHECK([HCGToolCatalog unavailableReasonForTool:HCGToolRepoPage environment:settingsApp] != nil, "no launcher in Settings");
    HCG_CHECK([HCGToolCatalog unavailableReasonForTool:HCGToolRestoreLayout environment:overlay] != nil, "nothing to restore");
    HCG_CHECK([HCGToolCatalog unavailableReasonForTool:HCGToolRestoreLayout environment:app] == nil, "backup present");
    HCG_CHECK([HCGToolCatalog unavailableReasonForTool:@"tool.made.up" environment:app] != nil, "unknown tool");
    NSArray *tools = [HCGToolCatalog allTools];
    NSUInteger i;
    for (i = 0; i < tools.count; i++) {
        HCGToolInfo *tool = [tools objectAtIndex:i];
        HCG_CHECK(tool.title.length > 0 && tool.summary.length > 0 && tool.symbolName.length > 0, "tool %s described", [tool.identifier UTF8String]);
    }
    NSArray *valid = [HCGToolCatalog validToolIdentifiers:[NSArray arrayWithObjects:HCGToolAppearance, @"bogus", HCGToolAppearance, nil]];
    HCG_CHECK_EQ_INT(valid.count, 1);
    HCG_CHECK([HCGToolCatalog defaultToolIdentifiersForPreset:HCGPresetDeveloper].count > 0, "developer defaults");
}

#pragma mark - Products

static void testAccountConfiguration(void) {
    HCGAccountConfiguration *none = [HCGAccountConfiguration configurationWithClientID:@"" redirectURI:@""];
    HCG_CHECK(!none.isConfigured && none.problem.length > 0, "empty Info.plist values: not configured");
    HCG_CHECK(![HCGAccountConfiguration configurationWithClientID:nil redirectURI:nil].isConfigured, "missing keys");
    HCG_CHECK(![HCGAccountConfiguration configurationWithClientID:[NSNumber numberWithInt:5] redirectURI:HCGAccountProposedRedirectURI].isConfigured, "wrong type");
    HCG_CHECK(![HCGAccountConfiguration configurationWithClientID:@"nexus" redirectURI:HCGAccountProposedRedirectURI].isConfigured, "not a client id");
    // Another product's client is never reused (Store production, Store development, Executable Maker, HCG AI, prefix-only ones).
    NSArray *foreign = [NSArray arrayWithObjects:@"94e51fe2-ba09-426d-8b41-8d36bf0dcac5", @"AF487795-EAD1-4671-8B09-76301762EE2C",
                        @"fb9b6edf-2bfc-4b5e-a354-dbb1af697029", @"f883ee38-3a62-431e-b5bf-4a563f59b765", @"3eb7b66b-0000-4000-8000-000000000000", nil];
    NSUInteger i;
    for (i = 0; i < foreign.count; i++) {
        HCGAccountConfiguration *c = [HCGAccountConfiguration configurationWithClientID:[foreign objectAtIndex:i] redirectURI:HCGAccountProposedRedirectURI];
        HCG_CHECK(!c.isConfigured && [c.problem rangeOfString:@"another HCG product"].location != NSNotFound, "foreign client %lu refused", (unsigned long)i);
    }
    NSString *fresh = @"0d8a7c56-2b7e-4f4c-9a51-7d1e2f3a4b5c";
    HCG_CHECK([HCGAccountConfiguration configurationWithClientID:fresh redirectURI:HCGAccountProposedRedirectURI].isConfigured, "own client + exact redirect");
    HCG_CHECK(![HCGAccountConfiguration configurationWithClientID:fresh redirectURI:@"https://evil.example.com/cb"].isConfigured, "foreign redirect");
    HCG_CHECK(![HCGAccountConfiguration configurationWithClientID:fresh redirectURI:@"com.hakmicapitalgroup.hcgnexus.app://auth/callback?token=x"].isConfigured, "query refused");
    HCG_CHECK(![HCGAccountConfiguration configurationWithClientID:fresh redirectURI:@""].isConfigured, "redirect required");

    NSString *request = [HCGAccountRules registrationRequestText];
    HCG_CHECK([request rangeOfString:@"hcg.nexus"].location != NSNotFound, "integration key");
    HCG_CHECK([request rangeOfString:@"S256"].location != NSNotFound, "PKCE");
    HCG_CHECK([request rangeOfString:HCGAccountProposedRedirectURI].location != NSNotFound, "redirect");
    HCG_CHECK([request rangeOfString:@"openid email profile"].location != NSNotFound, "scopes");
}

static void testPermissionCheckIsStrict(void) {
    NSDictionary *granted = [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES] forKey:@"allowed"];
    HCG_CHECK([HCGAccountRules isPermissionGrantedWithHTTPStatus:200 response:granted], "200 + allowed true");
    HCG_CHECK(![HCGAccountRules isPermissionGrantedWithHTTPStatus:403 response:granted], "non-200 denies");
    HCG_CHECK(![HCGAccountRules isPermissionGrantedWithHTTPStatus:500 response:granted], "service error denies");
    HCG_CHECK(![HCGAccountRules isPermissionGrantedWithHTTPStatus:200 response:nil], "no body denies");
    HCG_CHECK(![HCGAccountRules isPermissionGrantedWithHTTPStatus:200 response:@"allowed"], "wrong shape denies");
    HCG_CHECK(![HCGAccountRules isPermissionGrantedWithHTTPStatus:200 response:[NSDictionary dictionaryWithObject:@"true" forKey:@"allowed"]], "string true denies");
    HCG_CHECK(![HCGAccountRules isPermissionGrantedWithHTTPStatus:200 response:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:1] forKey:@"allowed"]], "integer 1 denies");
    HCG_CHECK(![HCGAccountRules isPermissionGrantedWithHTTPStatus:200 response:[NSDictionary dictionaryWithObject:[NSNumber numberWithBool:NO] forKey:@"allowed"]], "false denies");
    HCG_CHECK(![HCGAccountRules isPermissionGrantedWithHTTPStatus:200 response:[NSDictionary dictionaryWithObject:@"expired" forKey:@"reason"]], "missing allowed denies");
    // Offline: no response at all (status 0) denies.
    HCG_CHECK(![HCGAccountRules isPermissionGrantedWithHTTPStatus:0 response:nil], "offline denies");
}

static void testAccountSummaryCarriesNoCredentials(void) {
    NSMutableDictionary *ok = [NSMutableDictionary dictionary];
    [ok setObject:[NSNumber numberWithInteger:HCGAccountStateSignedIn] forKey:HCGAccountSummaryState];
    [ok setObject:@"Yasmin H." forKey:HCGAccountSummaryDisplayName];
    [ok setObject:@"Hakmi Capital Group" forKey:HCGAccountSummaryOrganisation];
    [ok setObject:@"extra" forKey:@"unexpected"];
    NSDictionary *clean = [HCGAccountSummary sanitizedSummary:ok];
    HCG_CHECK(clean != nil, "plain summary accepted");
    HCG_CHECK([clean objectForKey:@"unexpected"] == nil, "unknown keys dropped");
    HCG_CHECK_EQ_INT(clean.count, 3);

    NSMutableDictionary *withToken = [ok mutableCopy];
    [withToken setObject:@"abc" forKey:@"access_token"];
    HCG_CHECK([HCGAccountSummary sanitizedSummary:withToken] == nil, "token key refused");
    NSMutableDictionary *withRefresh = [ok mutableCopy];
    [withRefresh setObject:@"x" forKey:@"refreshToken"];
    HCG_CHECK([HCGAccountSummary sanitizedSummary:withRefresh] == nil, "refresh token key refused");
    NSMutableDictionary *jwtName = [ok mutableCopy];
    [jwtName setObject:@"eyJhbGciOiJFUzI1NiJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.c2lnbmF0dXJlLXZhbHVlLWhlcmU" forKey:HCGAccountSummaryDisplayName];
    HCG_CHECK([HCGAccountSummary sanitizedSummary:jwtName] == nil, "JWT-looking value refused");
    NSMutableDictionary *bearer = [ok mutableCopy];
    [bearer setObject:@"Bearer abcdef" forKey:HCGAccountSummaryOrganisation];
    HCG_CHECK([HCGAccountSummary sanitizedSummary:bearer] == nil, "bearer refused");
    NSMutableDictionary *badState = [ok mutableCopy];
    [badState setObject:[NSNumber numberWithInt:99] forKey:HCGAccountSummaryState];
    HCG_CHECK([HCGAccountSummary sanitizedSummary:badState] == nil, "unknown state refused");
    HCG_CHECK([HCGAccountSummary sanitizedSummary:@"string"] == nil, "wrong type refused");
    HCG_CHECK(![HCGAccountSummary looksLikeCredential:@"Hakmi Capital Group"], "normal names pass");
    HCG_CHECK([[HCGAccountRules titleForState:HCGAccountStateNotConfigured] isEqualToString:@"Not configured"], "state title");
}

void HCGRunRedesignTests(void) {
    HCG_RUN(testPanelAppearanceSettings);
    HCG_RUN(testAppLibraryPersistence);
    HCG_RUN(testWorkspaceQuickActionsAndTools);
    HCG_RUN(testMigrationKeepsShortcutsAndIsReversible);
    HCG_RUN(testFreshInstallMigration);
    HCG_RUN(testRestoreWithoutBackupFails);
    HCG_RUN(testToolAvailability);
    HCG_RUN(testAccountConfiguration);
    HCG_RUN(testPermissionCheckIsStrict);
    HCG_RUN(testAccountSummaryCarriesNoCredentials);
}
