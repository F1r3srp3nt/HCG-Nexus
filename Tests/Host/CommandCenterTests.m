#import "HCGTestHarness.h"
#import "HCGCore.h"

// HCG Nexus 0.6.0 Command Center: registry, connection status, roadmap, gaps, LifeOS export, System Tester inventory,
// public feeds (docs/COMMAND-CENTER.md).

NSData *HCGTrustFixture(NSString *name);

static NSData *CCFixture(NSString *name) {
    return HCGTrustFixture([@"../commandcenter/" stringByAppendingString:name]);
}

static NSDate *CCNow(void) {
    return [NSDate dateWithTimeIntervalSince1970:1795700000];
}

static HCGRegistry *Registry(void) {
    return [HCGRegistry builtInRegistry];
}

static HCGRegistry *RegistryFromJSON(NSString *json, NSString **error) {
    return [HCGRegistry registryWithJSONData:[json dataUsingEncoding:NSUTF8StringEncoding] source:@"test" error:error];
}

static NSString *MiniRegistry(NSInteger version, NSString *products) {
    return [NSString stringWithFormat:@"{\"schema\":\"hcg.nexus.registry/1\",\"registryVersion\":%ld,\"generatedAt\":\"2026-11-26\","
            "\"categories\":[{\"id\":\"media\",\"name\":\"Media\",\"symbol\":\"newspaper\"}],"
            "\"connectionMethods\":[{\"id\":\"https-api\",\"name\":\"HTTPS API\",\"kind\":\"remote\",\"detail\":\"\",\"twoWay\":true},"
            "{\"id\":\"url-scheme\",\"name\":\"URL scheme\",\"kind\":\"local\",\"detail\":\"\",\"twoWay\":false},"
            "{\"id\":\"website\",\"name\":\"Website\",\"kind\":\"web\",\"detail\":\"\",\"twoWay\":false}],"
            "\"products\":[%@]}", (long)version, products];
}

#pragma mark Registry

static void testBuiltInRegistry(void) {
    HCGRegistry *r = Registry();
    HCG_CHECK(r != nil, "the built-in registry loads");
    HCG_CHECK_EQ_INT(r.version, 1);
    HCG_CHECK_EQ_INT(r.categories.count, 13);
    HCG_CHECK_EQ_INT(r.problems.count, 0);
    if (r.problems.count) NSLog(@"registry problems: %@", r.problems);
    HCG_CHECK(r.deviceClasses.count >= 10, "device classes");
    NSArray *required = [@"hcg-ai agent-runtime server build-host sentinel vanguard offensive-frontier trust-center system-tester "
                          "signal-contractor executable-maker executable-maker-unleashed terminal terminal-unleashed store repo connect "
                          "executive-control-center erp central-app-access trading trading-lab payments news ads representation lifeos "
                          "mail one cardx studio signature-studios halo vortex portal animation-center sovereign-os sovereign-robotics "
                          "sovereign-infrastructure sovereign-hardware nexus" componentsSeparatedByString:@" "];
    for (NSString *identifier in required) HCG_CHECK([r entryWithIdentifier:identifier] != nil, "registry lists %s", [identifier UTF8String]);
    for (HCGRegistryCategory *c in r.categories) {
        NSUInteger n = 0;
        for (HCGRegistryEntry *e in r.entries) if ([e.categoryID isEqualToString:c.identifier]) n++;
        HCG_CHECK(n > 0, "category %s is not empty", [c.identifier UTF8String]);
    }
    for (HCGRegistryEntry *e in r.entries) {
        HCG_CHECK(e.lastVerified.length == 10, "%s has a verification date", [e.identifier UTF8String]);
        HCG_CHECK(e.verifiedFrom.length > 0, "%s says where it was verified", [e.identifier UTF8String]);
        if (e.websiteURL) HCG_CHECK(HCGRegistryIsAllowedURL(e.websiteURL), "%s website allowed", [e.identifier UTF8String]);
        for (HCGRegistryEndpoint *ep in e.endpoints) HCG_CHECK(HCGRegistryIsAllowedURL(ep.url), "endpoint allowed");
        // A registry entry never claims the product is connected or installed: those are runtime facts.
        for (HCGRegistryConnection *c in e.connections) HCG_CHECK(![c.state isEqualToString:@"connected"], "no static connection claims");
    }
    // Existing HIP adapters stay attached (Terminal, Server, Trust Center preserved).
    HCG_CHECK_EQ_STR([r entryWithIdentifier:@"terminal-unleashed"].hipProductID, HCGHIPProductTerminalUnleashed);
    HCG_CHECK_EQ_STR([r entryWithIdentifier:@"terminal"].hipProductID, HCGHIPProductTerminal);
    HCG_CHECK_EQ_STR([r entryWithIdentifier:@"server"].hipProductID, HCGHIPProductServer);
    HCG_CHECK_EQ_STR([r entryWithIdentifier:@"news"].hipProductID, HCGHIPProductNews);
    HCG_CHECK_EQ_STR([r entryWithIdentifier:@"trust-center"].adapter, @"trust-center");
    HCG_CHECK([r entryForHIPProductID:HCGHIPProductHalo] != nil, "HIP lookup");
    // Official names and central identifiers as registered.
    HCG_CHECK_EQ_STR([r entryWithIdentifier:@"repo"].officialName, @"HCG Package Repository");
    HCG_CHECK_EQ_STR([r entryWithIdentifier:@"trading-lab"].centralProductID, @"hcg.trading.lab");
    HCG_CHECK_EQ_STR([r entryWithIdentifier:@"signature-studios"].officialName, @"Hakmi Signature Studios");
    HCG_CHECK_EQ_STR([r entryWithIdentifier:@"cardx"].centralProductID, @"hcg-cardx");
    HCG_CHECK(![r entryWithIdentifier:@"trading"].nameVerified, "unverified names are marked");
    HCG_CHECK([r entryWithIdentifier:@"trading"].websiteURL == nil, "no invented link for HCG Trading");
    HCG_CHECK([[r entryWithIdentifier:@"nexus"].centralRegistration isEqualToString:@"proposed"], "Nexus is not centrally registered");
    // Search.
    NSArray *visible = [r visibleEntriesWithGrants:nil];
    HCG_CHECK_EQ_INT([HCGRegistry entries:visible matchingQuery:@"terminal" registry:r].count, 2);
    HCG_CHECK([[HCGRegistry entries:visible matchingQuery:@"simulator" registry:r] containsObject:[r entryWithIdentifier:@"trading-lab"]], "aliases searched");
    HCG_CHECK([HCGRegistry entries:visible matchingQuery:@"security vanguard" registry:r].count == 1, "every word must match");
    HCG_CHECK_EQ_INT([HCGRegistry entries:visible matchingQuery:@"   " registry:r].count, visible.count);
}

static void testURLRules(void) {
    HCG_CHECK(HCGRegistryIsAllowedURL(@"https://news.hakmicapitalgroup.com/"), "subdomain");
    HCG_CHECK(HCGRegistryIsAllowedURL(@"https://hakmicapitalgroup.com/x"), "apex");
    HCG_CHECK(!HCGRegistryIsAllowedURL(@"http://news.hakmicapitalgroup.com/"), "http");
    HCG_CHECK(!HCGRegistryIsAllowedURL(@"https://evilhakmicapitalgroup.com/"), "look-alike");
    HCG_CHECK(!HCGRegistryIsAllowedURL(@"https://hakmicapitalgroup.com.evil.io/"), "suffix trick");
    HCG_CHECK(!HCGRegistryIsAllowedURL(@"https://a@hakmicapitalgroup.com/"), "user");
    HCG_CHECK(!HCGRegistryIsAllowedURL(@"https://hakmicapitalgroup.com:8443/"), "port");
    HCG_CHECK(!HCGRegistryIsAllowedURL(@"https://hakmicapitalgroup.com/x?token=1"), "query");
    HCG_CHECK(!HCGRegistryIsAllowedURL(@"https://hakmicapitalgroup.com/x#a"), "fragment");
    HCG_CHECK(!HCGRegistryIsAllowedURL(@"https://.hakmicapitalgroup.com/"), "empty label");
    HCG_CHECK(HCGRegistryIsValidIdentifier(@"build-host") && !HCGRegistryIsValidIdentifier(@"Build") && !HCGRegistryIsValidIdentifier(@"-x"), "ids");
}

static void testVisibilityAndValidation(void) {
    NSString *error = nil;
    NSString *json = MiniRegistry(1, @"{\"id\":\"pub\",\"officialName\":\"Public\",\"category\":\"media\",\"kind\":\"website\",\"links\":{\"website\":\"https://x.hakmicapitalgroup.com/\"}},"
                                      "{\"id\":\"priv\",\"officialName\":\"Private\",\"category\":\"media\",\"kind\":\"app\",\"visibility\":\"private\",\"entitlement\":{\"product\":\"hcg.secret\",\"feature\":\"secret.view\"}},"
                                      "{\"id\":\"priv2\",\"officialName\":\"Private without entitlement\",\"category\":\"media\",\"visibility\":\"unlisted\"},"
                                      "{\"id\":\"bad\",\"officialName\":\"Bad link\",\"category\":\"media\",\"links\":{\"website\":\"https://evil.example.com/\"},"
                                      "\"endpoints\":[{\"id\":\"x\",\"url\":\"https://x.hakmicapitalgroup.com/api\",\"auth\":\"bearer\",\"access\":\"read\"}]},"
                                      "{\"id\":\"pub\",\"officialName\":\"Duplicate\",\"category\":\"media\"},"
                                      "{\"id\":\"nocat\",\"officialName\":\"No category\",\"category\":\"nope\"}");
    HCGRegistry *r = RegistryFromJSON(json, &error);
    HCG_CHECK(r != nil, "loads: %s", [error UTF8String] ?: "");
    HCG_CHECK_EQ_INT(r.entries.count, 4);
    HCG_CHECK(r.problems.count >= 3, "problems reported");
    NSArray *anonymous = [r visibleEntriesWithGrants:nil];
    HCG_CHECK_EQ_INT(anonymous.count, 2); // pub + bad (its link removed)
    HCG_CHECK(![anonymous containsObject:[r entryWithIdentifier:@"priv"]], "private hidden without sign-in");
    NSArray *granted = [r visibleEntriesWithGrants:[NSSet setWithObject:@"hcg.secret/secret.view"]];
    HCG_CHECK([granted containsObject:[r entryWithIdentifier:@"priv"]], "shown with the entitlement");
    HCG_CHECK(![granted containsObject:[r entryWithIdentifier:@"priv2"]], "private without entitlement is never shown");
    HCG_CHECK([r entryWithIdentifier:@"bad"].websiteURL == nil && [r entryWithIdentifier:@"bad"].endpoints.count == 0, "bad link and bearer endpoint refused");
    HCG_CHECK(RegistryFromJSON(@"{\"schema\":\"other\"}", &error) == nil, "wrong schema");
    HCG_CHECK(RegistryFromJSON(@"[1]", &error) == nil, "not an object");
}

static void testUpdatesOnlyNarrow(void) {
    HCGRegistry *base = Registry();
    NSString *error = nil;
    NSString *updateJSON = MiniRegistry(2,
        @"{\"id\":\"news\",\"officialName\":\"HCG News\",\"category\":\"media\",\"kind\":\"app\",\"developmentStatus\":\"released\",\"lifecycle\":\"active\","
         "\"links\":{\"website\":\"https://news.hakmicapitalgroup.com/\"},"
         "\"endpoints\":[{\"id\":\"news.articles\",\"url\":\"https://other.hakmicapitalgroup.com/feed\",\"auth\":\"none\",\"access\":\"read\"}],"
         "\"connectionMethods\":[{\"method\":\"https-api\",\"state\":\"implemented\",\"detail\":\"x\"}]},"
        "{\"id\":\"ads\",\"officialName\":\"HCG ADS\",\"category\":\"media\",\"lifecycle\":\"suspended\",\"links\":{\"website\":\"https://ads.hakmicapitalgroup.com/\"}},"
        "{\"id\":\"brand-new\",\"officialName\":\"Brand New\",\"category\":\"media\",\"kind\":\"app\",\"adapter\":\"news.v1\","
         "\"links\":{\"website\":\"https://new.hakmicapitalgroup.com/\"},\"validations\":[{\"date\":\"2026-11-26\",\"device\":\"x\",\"summary\":\"y\"}],"
         "\"capabilities\":[{\"id\":\"c\",\"title\":\"C\",\"state\":\"verified\"}],\"connectionMethods\":[{\"method\":\"https-api\",\"state\":\"implemented\"}]}");
    HCGRegistry *update = RegistryFromJSON(updateJSON, &error);
    HCG_CHECK(update != nil, "update parses: %s", [error UTF8String] ?: "");
    NSString *problem = nil;
    HCGRegistry *merged = [base registryByApplyingUpdate:update problem:&problem];
    HCG_CHECK(merged != base && problem == nil, "applied");
    HCGRegistryEntry *news = [merged entryWithIdentifier:@"news"];
    HCG_CHECK_EQ_STR(news.developmentStatus, @"released");
    HCG_CHECK_EQ_STR(news.websiteURL, @"https://news.hakmicapitalgroup.com/"); // same link kept
    HCG_CHECK_EQ_INT(news.endpoints.count, 0);                                  // a changed endpoint URL is dropped, never adopted
    HCG_CHECK(news.hipProductID != nil && [news.adapter isEqualToString:@"news.v1"], "adapters come from the build");
    HCG_CHECK([news connectionForMethod:@"local-app"] == nil, "methods the update does not list are dropped");
    HCGRegistryEntry *ads = [merged entryWithIdentifier:@"ads"];
    HCG_CHECK_EQ_STR(ads.lifecycle, @"suspended");
    HCG_CHECK(ads.websiteURL == nil, "an update cannot add a link");
    HCGRegistryEntry *added = [merged entryWithIdentifier:@"brand-new"];
    HCG_CHECK(added.fromUpdate && !added.adapter && !added.websiteURL && added.validations.count == 0, "added entries are text only");
    HCG_CHECK([[added connectionForMethod:@"https-api"].state isEqualToString:@"planned"], "implemented becomes planned");
    HCG_CHECK(((HCGHIPCapability *)[added.capabilities objectAtIndex:0]).state == HCGHIPCapabilityStatePlanned, "capability lowered");
    HCG_CHECK([[merged entryWithIdentifier:@"terminal-unleashed"].validations count] == 1, "untouched entries keep their evidence");
    HCG_CHECK(merged.methods.count == base.methods.count, "methods are never imported");
    // Not newer: refused.
    HCGRegistry *old = RegistryFromJSON(MiniRegistry(1, @"{\"id\":\"x1\",\"officialName\":\"X\",\"category\":\"media\"}"), &error);
    problem = nil;
    HCG_CHECK([base registryByApplyingUpdate:old problem:&problem] == base && problem.length, "older update refused");
}

#pragma mark Connection and roadmap

static HCGHIPProductStatus *HIPStatus(NSString *productID, HCGHIPFacts *facts) {
    return [HCGInterchange statusForDescriptor:[HCGInterchange descriptorForProductID:productID] facts:facts];
}

static HCGHIPFacts *InstalledFacts(NSString *productID, NSString *version) {
    HCGHIPFacts *f = [[HCGHIPFacts alloc] init];
    f.productID = productID;
    f.hostCanInspect = YES;
    f.hostCanLaunchApps = YES;
    f.packageVersion = version;
    f.appInstalled = YES;
    f.appVersion = @"0.2.0";
    f.declaredSchemes = [NSArray arrayWithObject:@"hcgterminal-unleashed"];
    f.osVersion = @"17.4";
    return f;
}

static void testConnectionNeedsEvidence(void) {
    HCGRegistry *r = Registry();
    NSDate *now = CCNow();
    // Installed is not connected.
    HCGRegistryEntry *tu = [r entryWithIdentifier:@"terminal-unleashed"];
    HCGHIPProductStatus *installed = HIPStatus(HCGHIPProductTerminalUnleashed, InstalledFacts(HCGHIPProductTerminalUnleashed, @"0.2.0~rc2"));
    HCGConnectionSummary *c = [HCGCommandCenter connectionForEntry:tu hipStatus:installed ledger:nil registry:r now:now];
    HCG_CHECK_EQ_INT(c.state, HCGConnectionStateInstalled);
    // Sandboxed app: an openable scheme is still not a connection.
    HCGHIPFacts *sandbox = [[HCGHIPFacts alloc] init];
    sandbox.productID = HCGHIPProductTerminalUnleashed;
    sandbox.canOpenScheme = YES;
    c = [HCGCommandCenter connectionForEntry:tu hipStatus:HIPStatus(HCGHIPProductTerminalUnleashed, sandbox) ledger:nil registry:r now:now];
    HCG_CHECK_EQ_INT(c.state, HCGConnectionStateUnableToCheck);
    // Opening a screen (url-scheme, one-way) is recorded but never makes it Connected.
    NSArray *ledger = [NSArray arrayWithObject:[HCGConnectionLedger entryForProduct:@"terminal-unleashed" method:@"url-scheme" success:YES text:@"Opened Packages." time:now]];
    c = [HCGCommandCenter connectionForEntry:tu hipStatus:installed ledger:ledger registry:r now:now];
    HCG_CHECK_EQ_INT(c.state, HCGConnectionStateInstalled);

    // News: Ready until a read succeeds; Connected only while fresh; then Disconnected.
    HCGRegistryEntry *news = [r entryWithIdentifier:@"news"];
    c = [HCGCommandCenter connectionForEntry:news hipStatus:nil ledger:nil registry:r now:now];
    HCG_CHECK_EQ_INT(c.state, HCGConnectionStateReady);
    NSDictionary *ok = [HCGConnectionLedger entryForProduct:@"news" method:@"https-api" success:YES text:@"Read 6 published articles." time:[now dateByAddingTimeInterval:-60]];
    ledger = [HCGConnectionLedger entries:nil byAdding:ok];
    c = [HCGCommandCenter connectionForEntry:news hipStatus:nil ledger:ledger registry:r now:now];
    HCG_CHECK_EQ_INT(c.state, HCGConnectionStateConnected);
    HCG_CHECK(c.lastSuccess != nil && [c.lastSuccessText isEqualToString:@"Read 6 published articles."], "last successful communication");
    c = [HCGCommandCenter connectionForEntry:news hipStatus:nil ledger:ledger registry:r now:[now dateByAddingTimeInterval:3600]];
    HCG_CHECK_EQ_INT(c.state, HCGConnectionStateDisconnected);
    NSDictionary *fail = [HCGConnectionLedger entryForProduct:@"news" method:@"https-api" success:NO text:@"No answer (timed out)." time:now];
    c = [HCGCommandCenter connectionForEntry:news hipStatus:nil ledger:[HCGConnectionLedger entries:ledger byAdding:fail] registry:r now:now];
    HCG_CHECK_EQ_INT(c.state, HCGConnectionStateDisconnected);
    c = [HCGCommandCenter connectionForEntry:news hipStatus:nil ledger:[NSArray arrayWithObject:fail] registry:r now:now];
    HCG_CHECK_EQ_INT(c.state, HCGConnectionStateFailed);
    // Ledger hygiene.
    HCG_CHECK([[[HCGConnectionLedger entryForProduct:@"news" method:@"https-api" success:YES text:@"GET https://x/?token=abc" time:now] objectForKey:@"text"] rangeOfString:@"token"].location == NSNotFound, "no URLs in the ledger");
    HCG_CHECK([HCGConnectionLedger entryForProduct:@"News!" method:@"https-api" success:YES text:@"x" time:now] == nil, "invalid product");
    NSArray *mixed = [NSArray arrayWithObjects:@"junk", ok, nil];
    HCG_CHECK_EQ_INT([HCGConnectionLedger entriesFromStoredValue:mixed].count, 1);

    // Lifecycle, planned, website, built in.
    HCG_CHECK_EQ_INT([HCGCommandCenter connectionForEntry:[r entryWithIdentifier:@"vanguard"] hipStatus:nil ledger:nil registry:r now:now].state, HCGConnectionStatePlanned);
    HCG_CHECK_EQ_INT([HCGCommandCenter connectionForEntry:[r entryWithIdentifier:@"trading-lab"] hipStatus:nil ledger:nil registry:r now:now].state, HCGConnectionStateWebsite);
    HCG_CHECK_EQ_INT([HCGCommandCenter connectionForEntry:[r entryWithIdentifier:@"trust-center"] hipStatus:nil ledger:nil registry:r now:now].state, HCGConnectionStateBuiltIn);
    HCG_CHECK_EQ_INT([HCGCommandCenter connectionForEntry:[r entryWithIdentifier:@"build-host"] hipStatus:nil ledger:nil registry:r now:now].state, HCGConnectionStateNotSupported);
    // HCG Server: only the Device Link state decides (not paired → not configured; never Connected by itself).
    HCGHIPFacts *server = [[HCGHIPFacts alloc] init];
    server.productID = HCGHIPProductServer;
    server.serviceLinkState = HCGHIPServiceLinkStateNotPaired;
    c = [HCGCommandCenter connectionForEntry:[r entryWithIdentifier:@"server"] hipStatus:HIPStatus(HCGHIPProductServer, server) ledger:nil registry:r now:now];
    HCG_CHECK(c.state != HCGConnectionStateConnected, "unpaired server is not connected");
    server.serviceLinkState = HCGHIPServiceLinkStateConnected;
    c = [HCGCommandCenter connectionForEntry:[r entryWithIdentifier:@"server"] hipStatus:HIPStatus(HCGHIPProductServer, server) ledger:nil registry:r now:now];
    HCG_CHECK_EQ_INT(c.state, HCGConnectionStateConnected);
}

static void testRoadmap(void) {
    HCGRegistry *r = Registry();
    NSDate *now = CCNow();
    NSMutableDictionary *assessments = [NSMutableDictionary dictionary];
    for (HCGRegistryEntry *e in r.entries) {
        HCGHIPProductStatus *hip = e.hipProductID ? HIPStatus(e.hipProductID, nil) : nil;
        HCGConnectionSummary *c = [HCGCommandCenter connectionForEntry:e hipStatus:hip ledger:nil registry:r now:now];
        HCGRoadmapAssessment *a = [HCGCommandCenter roadmapForEntry:e connection:c hipStatus:hip];
        HCG_CHECK(a.evidence.length > 0, "%s has evidence", [e.identifier UTF8String]);
        HCG_CHECK(a.state != HCGRoadmapStateConnected, "%s: nothing is Connected without a read", [e.identifier UTF8String]);
        [assessments setObject:a forKey:e.identifier];
    }
    HCG_CHECK_EQ_INT(((HCGRoadmapAssessment *)[assessments objectForKey:@"terminal-unleashed"]).state, HCGRoadmapStateValidated);
    HCG_CHECK_EQ_INT(((HCGRoadmapAssessment *)[assessments objectForKey:@"build-host"]).state, HCGRoadmapStateContractAvailable);
    HCG_CHECK_EQ_INT(((HCGRoadmapAssessment *)[assessments objectForKey:@"vanguard"]).state, HCGRoadmapStateResearchRequired);
    HCG_CHECK_EQ_INT(((HCGRoadmapAssessment *)[assessments objectForKey:@"connect"]).state, HCGRoadmapStateConfigurationRequired);
    HCG_CHECK_EQ_INT(((HCGRoadmapAssessment *)[assessments objectForKey:@"news"]).state, HCGRoadmapStateReadyToConnect);
    HCG_CHECK_EQ_INT(((HCGRoadmapAssessment *)[assessments objectForKey:@"sovereign-os"]).state, HCGRoadmapStateRegistered);
    HCG_CHECK_EQ_INT(((HCGRoadmapAssessment *)[assessments objectForKey:@"agent-runtime"]).state, HCGRoadmapStateBlocked);
    HCG_CHECK_EQ_INT(((HCGRoadmapAssessment *)[assessments objectForKey:@"executable-maker-unleashed"]).state, HCGRoadmapStateResearchRequired);

    // Connected only from a successful read; the historical validation stays in the registry entry.
    HCGRegistryEntry *news = [r entryWithIdentifier:@"news"];
    NSArray *ledger = [NSArray arrayWithObject:[HCGConnectionLedger entryForProduct:@"news" method:@"https-api" success:YES text:@"Read 6 published articles." time:now]];
    HCGConnectionSummary *c = [HCGCommandCenter connectionForEntry:news hipStatus:nil ledger:ledger registry:r now:now];
    HCG_CHECK_EQ_INT([HCGCommandCenter roadmapForEntry:news connection:c hipStatus:nil].state, HCGRoadmapStateConnected);

    // Persistence: history grows only on change.
    BOOL changed = NO;
    NSDictionary *store = [HCGCommandCenter roadmapStore:nil byRecordingAssessments:assessments now:now changed:&changed];
    HCG_CHECK(changed && store.count == r.entries.count, "first record");
    store = [HCGCommandCenter roadmapStore:store byRecordingAssessments:assessments now:[now dateByAddingTimeInterval:60] changed:&changed];
    HCG_CHECK(!changed, "same states: no change");
    NSMutableDictionary *next = [NSMutableDictionary dictionaryWithDictionary:assessments];
    [next setObject:[HCGCommandCenter roadmapForEntry:news connection:c hipStatus:nil] forKey:@"news"];
    store = [HCGCommandCenter roadmapStore:store byRecordingAssessments:next now:[now dateByAddingTimeInterval:120] changed:&changed];
    HCG_CHECK(changed, "a new state is recorded");
    NSArray *history = [HCGCommandCenter roadmapHistoryForEntry:@"news" store:store];
    HCG_CHECK_EQ_INT(history.count, 2);
    HCG_CHECK_EQ_STR([[history objectAtIndex:0] objectForKey:@"state"], @"connected");
    HCG_CHECK_EQ_STR([[history objectAtIndex:1] objectForKey:@"state"], @"ready-to-connect");
    BOOL found = NO;
    HCG_CHECK_EQ_INT([HCGCommandCenter roadmapStateForKey:@"partially-integrated" found:&found], HCGRoadmapStatePartiallyIntegrated);
    HCG_CHECK(found, "key round trip");
    NSInteger i;
    for (i = 0; i < HCGRoadmapStateCount; i++) {
        HCG_CHECK([HCGCommandCenter roadmapStateForKey:[HCGCommandCenter keyForRoadmapState:(HCGRoadmapState)i] found:&found] == (HCGRoadmapState)i && found, "state %ld", (long)i);
    }
}

#pragma mark Gaps and LifeOS

static BOOL IsLifeOSStableID(NSString *s) {
    if (s.length < 1 || s.length > 120) return NO;
    NSCharacterSet *ok = [NSCharacterSet characterSetWithCharactersInString:@"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789:._-"];
    unichar first = [s characterAtIndex:0];
    BOOL alnum = (first >= 'a' && first <= 'z') || (first >= 'A' && first <= 'Z') || (first >= '0' && first <= '9');
    return alnum && [s rangeOfCharacterFromSet:[ok invertedSet]].location == NSNotFound;
}

static void testGapsAndLifeOSExport(void) {
    HCGRegistry *r = Registry();
    NSArray *gaps = [HCGCommandCenter gapsForEntries:[r visibleEntriesWithGrants:nil]];
    HCG_CHECK(gaps.count > 20, "gaps found (%lu)", (unsigned long)gaps.count);
    NSMutableSet *ids = [NSMutableSet set];
    BOOL connectClient = NO, systemTesterRegistration = NO;
    for (HCGDevelopmentGap *g in gaps) {
        HCG_CHECK(IsLifeOSStableID(g.stableID), "stable ID %s", [g.stableID UTF8String]);
        HCG_CHECK(![ids containsObject:g.stableID], "unique %s", [g.stableID UTF8String]);
        [ids addObject:g.stableID];
        if ([g.stableID isEqualToString:@"nexus.connect.client-id"]) connectClient = YES;
        if ([g.stableID isEqualToString:@"nexus.system-tester.register-central"]) systemTesterRegistration = YES;
    }
    HCG_CHECK(connectClient && systemTesterRegistration, "expected gaps present");

    HCGLifeOSExport *x = [HCGCommandCenter lifeOSExportForGaps:gaps exported:nil registryVersion:1
                                                     requestID:@"6f1c2d3e-0000-4000-8000-00000000abcd" now:CCNow()];
    NSDictionary *payload = x.payload;
    HCG_CHECK_EQ_STR([payload objectForKey:@"version"], @"lifeos.v1");
    NSArray *ops = [payload objectForKey:@"operations"];
    HCG_CHECK_EQ_INT(ops.count, gaps.count + 1);
    HCG_CHECK_EQ_STR([[ops objectAtIndex:0] objectForKey:@"kind"], @"project");
    NSSet *allowed = [NSSet setWithArray:[@"title notes description status priority project_id parent_id due_date start_date dependencies progress source" componentsSeparatedByString:@" "]];
    NSMutableSet *opIDs = [NSMutableSet set];
    for (NSDictionary *op in ops) {
        HCG_CHECK([[op objectForKey:@"expected_revision"] intValue] == 0, "new records");
        HCG_CHECK(![opIDs containsObject:[op objectForKey:@"id"]], "no duplicate_id");
        [opIDs addObject:[op objectForKey:@"id"]];
        if (![[op objectForKey:@"kind"] isEqual:@"task"]) continue;
        NSDictionary *f = [op objectForKey:@"fields"];
        HCG_CHECK([[NSSet setWithArray:[f allKeys]] isSubsetOfSet:allowed], "only lifeos.v1 task fields");
        HCG_CHECK([[f objectForKey:@"title"] length] <= 300, "title length");
        NSString *status = [f objectForKey:@"status"];
        HCG_CHECK([status isEqualToString:@"Later"] || [status isEqualToString:@"Stuck"], "status");
    }
    NSData *bytes = [NSJSONSerialization dataWithJSONObject:payload options:0 error:NULL];
    NSString *text = [[NSString alloc] initWithData:bytes encoding:NSUTF8StringEncoding];
    HCG_CHECK(bytes.length > 0 && [[text lowercaseString] rangeOfString:@"\"xp"].location == NSNotFound &&
              [[text lowercaseString] rangeOfString:@"xp_"].location == NSNotFound, "serialises; never claims XP");
    // Duplicate protection: after marking, the same gaps export nothing.
    NSDictionary *store = [HCGCommandCenter exportedStore:nil byMarking:x];
    HCGLifeOSExport *again = [HCGCommandCenter lifeOSExportForGaps:gaps exported:store registryVersion:1 requestID:@"6f1c2d3e-0000-4000-8000-00000000abce" now:CCNow()];
    HCG_CHECK(again.payload == nil, "nothing new");
    HCG_CHECK_EQ_INT(again.alreadyExported, gaps.count);
    // A changed gap is reported, not re-added.
    HCGDevelopmentGap *g = [gaps objectAtIndex:0];
    g.title = [g.title stringByAppendingString:@" (reworded)"];
    again = [HCGCommandCenter lifeOSExportForGaps:gaps exported:store registryVersion:1 requestID:@"6f1c2d3e-0000-4000-8000-00000000abcf" now:CCNow()];
    HCG_CHECK(again.payload == nil && again.changed.count == 1, "changed, not duplicated");
    // Favorites.
    NSArray *fav = [HCGCommandCenter favoritesFromStoredValue:[NSArray arrayWithObjects:@"news", @"news", @"BAD", [NSNumber numberWithInt:1], @"server", nil]];
    HCG_CHECK_EQ_INT(fav.count, 2);
}

#pragma mark System Tester inventory and feeds

static void testInventory(void) {
    NSString *error = nil;
    HCGDeviceInventory *inv = [HCGDeviceInventory inventoryWithData:CCFixture(@"inventory.json") error:&error];
    HCG_CHECK(inv != nil, "parses: %s", [error UTF8String] ?: "");
    HCG_CHECK_EQ_INT(inv.devices.count, 4);
    HCG_CHECK_EQ_STR(inv.installationSuffix, @"ABCD");
    HCG_CHECK_EQ_STR(inv.appVersion, @"0.3.0");
    HCG_CHECK(inv.problems.count == 1, "unknown values reported");
    HCGInventoryDevice *phone = [inv.devices objectAtIndex:0];
    HCG_CHECK_EQ_STR(phone.statusTitle, @"Diagnostics available");
    HCG_CHECK_EQ_STR(phone.connectionTitle, @"USB / USB-C");
    HCG_CHECK(!phone.synthetic, "hardware");
    HCG_CHECK(((HCGInventoryDevice *)[inv.devices objectAtIndex:2]).synthetic, "synthetic flagged");
    HCG_CHECK_EQ_STR(((HCGInventoryDevice *)[inv.devices objectAtIndex:3]).category, @"unknown");
    HCGRegistry *r = Registry();
    HCGRegistryDeviceClass *mobile = nil, *consoles = nil;
    for (HCGRegistryDeviceClass *c in r.deviceClasses) {
        if ([c.identifier isEqualToString:@"mobile"]) mobile = c;
        if ([c.identifier isEqualToString:@"consoles"]) consoles = c;
        HCG_CHECK([c.safety rangeOfString:@"never"].location != NSNotFound, "%s states the safety rule", [c.identifier UTF8String]);
    }
    HCG_CHECK_EQ_INT([inv devicesInClass:mobile].count, 1);
    HCG_CHECK_EQ_INT([inv devicesInClass:consoles].count, 1);
    HCG_CHECK_EQ_INT([inv devicesInNoClassOf:r.deviceClasses].count, 1);
    HCG_CHECK([HCGDeviceInventory inventoryWithData:[@"{\"schema\":\"hcg.systemtester.report/1\"}" dataUsingEncoding:NSUTF8StringEncoding] error:&error] == nil, "other schema refused");
    HCG_CHECK_EQ_INT((long)[[HCGDeviceInventory dateFromISO8601:@"2026-11-26T09:30:00Z"] timeIntervalSince1970], 1795685400);
    HCG_CHECK_EQ_INT((long)[[HCGDeviceInventory dateFromISO8601:@"2026-11-26T10:30:00.123+01:00"] timeIntervalSince1970], 1795685400);
    HCG_CHECK([HCGDeviceInventory dateFromISO8601:@"26/11/2026"] == nil, "bad date");
}

static void testPublicFeeds(void) {
    NSString *error = nil;
    NSInteger total = 0;
    NSArray *articles = [HCGPublicFeeds newsArticlesFromData:CCFixture(@"news.json") total:&total error:&error];
    HCG_CHECK_EQ_INT(articles.count, 2);
    HCG_CHECK_EQ_INT(total, 2);
    HCGNewsArticle *a = [articles objectAtIndex:0];
    HCG_CHECK_EQ_STR(a.section, @"Technology");
    HCG_CHECK_EQ_STR(a.publishedAt, @"2026-11-01");
    HCG_CHECK_EQ_STR(a.webURL, @"https://news.hakmicapitalgroup.com/technology/jailbreakwithai");
    HCGNewsArticle *demo = [articles objectAtIndex:1];
    HCG_CHECK(demo.demo && demo.webURL == nil, "demo labelled; foreign link dropped");
    HCG_CHECK([HCGPublicFeeds newsArticlesFromData:[@"{\"error\":{\"code\":\"unavailable\"}}" dataUsingEncoding:NSUTF8StringEncoding] total:NULL error:&error] == nil &&
              [error rangeOfString:@"unavailable"].location != NSNotFound, "API errors reported");
    HCG_CHECK([HCGPublicFeeds newsArticlesFromData:[@"<html>" dataUsingEncoding:NSUTF8StringEncoding] total:NULL error:&error] == nil, "not JSON");
    HCG_CHECK_EQ_STR([HCGPublicFeeds newsRequestURLForEndpoint:@"https://beta.hakmicapitalgroup.com/api/public/news/v1/articles"],
                     @"https://beta.hakmicapitalgroup.com/api/public/news/v1/articles?page=1&per_page=20");
    NSArray *rows = [HCGPublicFeeds identityDiscoveryRowsFromData:CCFixture(@"discovery.json") error:&error];
    HCG_CHECK(rows.count >= 5, "discovery rows");
    NSString *all = [rows description];
    HCG_CHECK([all rangeOfString:@"11111111"].location == NSNotFound, "client IDs are never shown");
    HCG_CHECK([all rangeOfString:@"Not issued"].location != NSNotFound, "says Nexus has no client");
    HCG_CHECK([HCGPublicFeeds identityDiscoveryRowsFromData:[@"{}" dataUsingEncoding:NSUTF8StringEncoding] error:&error] == nil, "invalid discovery");
}

void HCGRunCommandCenterTests(void) {
    HCGCurrentTest = "command-center";
    testBuiltInRegistry();
    testURLRules();
    testVisibilityAndValidation();
    testUpdatesOnlyNarrow();
    testConnectionNeedsEvidence();
    testRoadmap();
    testGapsAndLifeOSExport();
    testInventory();
    testPublicFeeds();
}
