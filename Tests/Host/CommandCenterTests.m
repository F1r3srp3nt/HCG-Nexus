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
    HCG_CHECK_EQ_INT(r.version, 4);
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
    NSString *updateJSON = MiniRegistry(5,
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
    HCGRegistry *old = RegistryFromJSON(MiniRegistry(4, @"{\"id\":\"x1\",\"officialName\":\"X\",\"category\":\"media\"}"), &error);
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
    HCG_CHECK_EQ_INT(c.state, HCGConnectionStateReachable); // a public read is never Connected
    HCG_CHECK_EQ_STR(c.lastSuccessAccess, @"public");
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

static void testEvidenceLayers(void) {
    HCGRegistry *r = Registry();
    NSDate *now = CCNow();
    HCG_CHECK_EQ_STR([r methodWithIdentifier:@"https-api"].access, @"public");
    HCG_CHECK_EQ_STR([r methodWithIdentifier:@"hcg-server"].access, @"authenticated");
    HCG_CHECK_EQ_STR([r methodWithIdentifier:@"local-ipc"].access, @"local");
    HCG_CHECK_EQ_STR([r methodWithIdentifier:@"url-scheme"].access, @"none");
    // HCG Halo's own interface answering: Connected (local), not authenticated.
    HCGRegistryEntry *halo = [r entryWithIdentifier:@"halo"];
    NSArray *ledger = [NSArray arrayWithObject:[HCGConnectionLedger entryForProduct:@"halo" method:@"local-ipc" success:YES text:@"HCG Halo accepted a border change." time:now]];
    HCGConnectionSummary *c = [HCGCommandCenter connectionForEntry:halo hipStatus:nil ledger:ledger registry:r now:now];
    HCG_CHECK_EQ_INT(c.state, HCGConnectionStateConnected);
    HCG_CHECK_EQ_STR(c.title, @"Connected (local interface)");
    NSArray *layers = [HCGCommandCenter evidenceLayersForEntry:halo connection:c hipStatus:nil ledger:ledger registry:r now:now];
    HCG_CHECK_EQ_INT(layers.count, 7);
    NSArray *titles = [NSArray arrayWithObjects:@"Registered product", @"Installed application", @"Available service", @"Authenticated connection",
                                                @"Verified capability", @"Current connection health", @"Historical validation", nil];
    NSUInteger i;
    for (i = 0; i < 7 && i < layers.count; i++) HCG_CHECK_EQ_STR([[layers objectAtIndex:i] objectAtIndex:0], [titles objectAtIndex:i]);
    HCG_CHECK([[[layers objectAtIndex:3] objectAtIndex:1] hasPrefix:@"Not authenticated"], "a local interface is not authentication");
    // HCG Connect: the public discovery read is availability only; the roadmap stays partial (no client).
    HCGRegistryEntry *connect = [r entryWithIdentifier:@"connect"];
    ledger = [NSArray arrayWithObject:[HCGConnectionLedger entryForProduct:@"connect" method:@"https-api" success:YES text:@"Read the public identity discovery." time:now]];
    c = [HCGCommandCenter connectionForEntry:connect hipStatus:nil ledger:ledger registry:r now:now];
    HCG_CHECK_EQ_INT(c.state, HCGConnectionStateReachable);
    HCG_CHECK_EQ_INT([HCGCommandCenter roadmapForEntry:connect connection:c hipStatus:nil].state, HCGRoadmapStatePartiallyIntegrated);
    layers = [HCGCommandCenter evidenceLayersForEntry:connect connection:c hipStatus:nil ledger:ledger registry:r now:now];
    HCG_CHECK([[[layers objectAtIndex:2] objectAtIndex:1] hasPrefix:@"Public read succeeded"], "available service");
    HCG_CHECK([[[layers objectAtIndex:3] objectAtIndex:1] hasPrefix:@"None"], "a public read is not authenticated access");
    HCG_CHECK([[[layers objectAtIndex:0] objectAtIndex:1] rangeOfString:@"hcg.connect"].location != NSNotFound, "central ID");
    // HCG News: a public-only integration; a public read completes its roadmap, still not authenticated.
    HCGRegistryEntry *news = [r entryWithIdentifier:@"news"];
    ledger = [NSArray arrayWithObject:[HCGConnectionLedger entryForProduct:@"news" method:@"https-api" success:YES text:@"Read 13 published articles." time:now]];
    c = [HCGCommandCenter connectionForEntry:news hipStatus:nil ledger:ledger registry:r now:now];
    HCG_CHECK_EQ_INT([HCGCommandCenter roadmapForEntry:news connection:c hipStatus:nil].state, HCGRoadmapStateConnected);
    // Terminal Unleashed: historical validation stays separate from current health.
    HCGRegistryEntry *tu = [r entryWithIdentifier:@"terminal-unleashed"];
    c = [HCGCommandCenter connectionForEntry:tu hipStatus:nil ledger:nil registry:r now:now];
    layers = [HCGCommandCenter evidenceLayersForEntry:tu connection:c hipStatus:nil ledger:nil registry:r now:now];
    HCG_CHECK([[[layers objectAtIndex:6] objectAtIndex:1] rangeOfString:@"iPhone 11 Pro Max"].location != NSNotFound, "historical validation");
    HCG_CHECK([[[layers objectAtIndex:5] objectAtIndex:1] rangeOfString:@"Connected"].location == NSNotFound, "history is not current health");
}

static void testLiveCaptures(void) {
    NSString *error = nil;
    NSInteger total = 0;
    NSArray *articles = [HCGPublicFeeds newsArticlesFromData:CCFixture(@"live-news-2026-11-26.json") total:&total error:&error];
    HCG_CHECK(articles.count == 3, "the live news.v1 answer parses (%s)", [error UTF8String] ?: "");
    HCG_CHECK_EQ_INT(total, 13);
    for (HCGNewsArticle *a in articles) HCG_CHECK(a.title.length && a.webURL && a.publishedAt.length == 10, "live article fields");
    NSArray *rows = [HCGPublicFeeds identityDiscoveryRowsFromData:CCFixture(@"live-discovery-2026-11-26.json") error:&error];
    HCG_CHECK(rows.count >= 5, "the live discovery parses");
    NSString *all = [rows description];
    NSDictionary *raw = [NSJSONSerialization JSONObjectWithData:CCFixture(@"live-discovery-2026-11-26.json") options:0 error:NULL];
    id clientID = [raw objectForKey:@"private_beta_client_id"];
    if ([clientID isKindOfClass:[NSString class]] && [clientID length]) HCG_CHECK([all rangeOfString:clientID].location == NSNotFound, "live client IDs are never shown");
    HCG_CHECK([all rangeOfString:@"S256 supported"].location != NSNotFound, "PKCE S256 live");
    HCG_CHECK([all rangeOfString:@"Not advertised"].location != NSNotFound, "no revocation endpoint live");
    NSArray *store = [HCGPublicFeeds storeHealthRowsFromData:CCFixture(@"live-store-health-2026-11-26.json") error:&error];
    HCG_CHECK(store.count >= 6, "the live Store health parses");
    HCG_CHECK([[store description] rangeOfString:@"production"].location != NSNotFound, "Store mode");
    HCG_CHECK([HCGPublicFeeds storeHealthRowsFromData:[@"{}" dataUsingEncoding:NSUTF8StringEncoding] error:&error] == nil, "invalid health");
    HCGRegistry *r = Registry();
    HCG_CHECK([r entryWithIdentifier:@"store-manager"] != nil && [r entryWithIdentifier:@"one-unleashed"] != nil, "new entries");
    for (HCGHIPCapability *c in [r entryWithIdentifier:@"store-manager"].capabilities) {
        HCG_CHECK(c.state != HCGHIPCapabilityStateAvailable && c.state != HCGHIPCapabilityStateVerified, "Store Manager offers nothing yet");
    }
    HCG_CHECK([r entryWithIdentifier:@"trading"].websiteURL == nil, "HCG Trading: no link while its host does not answer");
}

static void testCentralRegistry(void) {
    NSString *error = nil;
    NSData *live = CCFixture(@"live-central-catalog-2026-11-26.json");
    HCGCentralSnapshot *snap = [HCGCentralSnapshot snapshotWithData:live fetchedAt:CCNow() error:&error];
    HCG_CHECK(snap != nil, "the live central catalogue parses (%s)", [error UTF8String] ?: "");
    HCG_CHECK_EQ_INT(snap.products.count, 31);
    HCG_CHECK_EQ_INT(snap.version.length, 16);
    HCG_CHECK_EQ_STR(((HCGCentralProduct *)[snap.products objectForKey:@"hcg.connect"]).name, @"HCG Connect / HCG Auth");
    // The version depends only on identity fields: the same catalogue (re-serialised) keeps its version.
    id json = [NSJSONSerialization JSONObjectWithData:live options:0 error:NULL];
    NSData *again = [NSJSONSerialization dataWithJSONObject:json options:NSJSONWritingPrettyPrinted error:NULL];
    HCG_CHECK_EQ_STR([HCGCentralSnapshot snapshotWithData:again fetchedAt:CCNow() error:NULL].version, snap.version);
    // Storage round trip and validation.
    HCGCentralSnapshot *restored = [HCGCentralSnapshot snapshotFromStoredValue:[snap storedValue]];
    HCG_CHECK_EQ_STR(restored.version, snap.version);
    HCG_CHECK([HCGCentralSnapshot snapshotWithData:[@"{\"api_version\":\"2\",\"products\":[]}" dataUsingEncoding:NSUTF8StringEncoding] fetchedAt:CCNow() error:&error] == nil, "other api_version");
    HCG_CHECK([HCGCentralSnapshot snapshotWithData:[@"{\"api_version\":\"1\",\"products\":[{\"product_id\":\"hcg.x\",\"name\":\"X\"}]}" dataUsingEncoding:NSUTF8StringEncoding] fetchedAt:CCNow() error:&error] == nil, "too few products");
    HCG_CHECK([HCGCentralSnapshot snapshotWithData:[@"<html>" dataUsingEncoding:NSUTF8StringEncoding] fetchedAt:CCNow() error:&error] == nil, "not JSON");
    HCG_CHECK([HCGCentralSnapshot snapshotFromStoredValue:@"junk"] == nil, "stored junk");

    HCGRegistry *base = Registry();
    NSUInteger matched = 0;
    HCGRegistry *r = [base registryByApplyingCentralSnapshot:snap matched:&matched];
    HCG_CHECK(matched >= 15, "matched %lu entries", (unsigned long)matched);
    HCG_CHECK_EQ_INT(r.entries.count, base.entries.count);             // never adds products
    HCG_CHECK_EQ_STR([r entryWithIdentifier:@"connect"].officialName, @"HCG Connect / HCG Auth");
    HCG_CHECK_EQ_STR([base entryWithIdentifier:@"connect"].officialName, @"HCG Connect"); // the built-in registry is untouched
    HCG_CHECK_EQ_STR([r entryWithIdentifier:@"terminal"].developmentStatus, @"planned");
    HCG_CHECK_EQ_STR([r entryWithIdentifier:@"trading-lab"].developmentStatus, @"in-development");
    HCG_CHECK_EQ_STR([r entryWithIdentifier:@"nexus"].centralRegistration, @"proposed");    // hcg.nexus is not registered centrally
    HCG_CHECK_EQ_STR([r entryWithIdentifier:@"server"].centralRegistration, @"proposed");
    HCG_CHECK_EQ_STR([r entryWithIdentifier:@"terminal-unleashed"].centralRegistration, @"edition"); // editions keep their own identity
    for (HCGRegistryEntry *e in r.entries) {
        HCGRegistryEntry *b = [base entryWithIdentifier:e.identifier];
        HCG_CHECK((e.websiteURL == b.websiteURL || [e.websiteURL isEqualToString:b.websiteURL]) && e.endpoints.count == b.endpoints.count &&
                  [e.visibility isEqualToString:b.visibility] && (e.adapter == b.adapter || [e.adapter isEqualToString:b.adapter]),
                  "%s: the central registry changes identity only", [e.identifier UTF8String]);
    }
    HCG_CHECK([r.source rangeOfString:snap.version].location != NSNotFound, "source names the snapshot");
    HCG_CHECK([base registryByApplyingCentralSnapshot:nil matched:NULL] == base, "no snapshot: built in");

    // An imported registry file cannot redefine identity or authority.
    NSString *update = MiniRegistry(9, @"{\"id\":\"connect\",\"officialName\":\"Totally Official\",\"category\":\"media\",\"central\":{\"productId\":\"hcg.evil\",\"registration\":\"registered\"}},"
                                        "{\"id\":\"newcomer\",\"officialName\":\"Newcomer\",\"category\":\"media\",\"central\":{\"productId\":\"hcg.newcomer\",\"registration\":\"registered\"},\"nameVerified\":true}");
    HCGRegistry *u = RegistryFromJSON(update, &error);
    HCGRegistry *merged = [r registryByApplyingUpdate:u problem:NULL];
    HCG_CHECK_EQ_STR([merged entryWithIdentifier:@"connect"].officialName, @"HCG Connect / HCG Auth");
    HCG_CHECK_EQ_STR([merged entryWithIdentifier:@"connect"].centralProductID, @"hcg.connect");
    HCG_CHECK_EQ_STR([merged entryWithIdentifier:@"newcomer"].centralRegistration, @"not-registered");
    HCG_CHECK(![merged entryWithIdentifier:@"newcomer"].nameVerified, "an imported name is never verified");
}

static void testStoreProgressAndUEM(void) {
    NSString *error = nil;
    // HCG Store release resolution (live capture).
    NSArray *rows = [HCGPublicFeeds storeReleaseRowsFromData:CCFixture(@"live-store-release-hcg-nexus-2026-11-27.json") error:&error];
    HCG_CHECK(rows.count >= 3, "live release resolution parses (%s)", [error UTF8String] ?: "");
    NSString *all = [rows description];
    HCG_CHECK([all rangeOfString:@"None published in HCG Store yet"].location != NSNotFound, "no releases published (live)");
    HCG_CHECK([all rangeOfString:@"https://"].location == NSNotFound, "no URLs shown");
    NSString *withRelease = @"{\"format\":\"hcg.store.release-resolution/1\",\"product\":{\"name\":\"HCG Nexus\",\"developmentStatus\":\"testing\"},"
        "\"releases\":[{\"version\":\"0.7.0\",\"channel\":\"beta\",\"releaseDate\":\"2026-12-01\",\"source\":\"hcg-store-publication\"}],"
        "\"options\":[{\"platform\":\"ios\",\"fileName\":\"HCGNexus.ipa\",\"sha256\":\"004e6a9ea2db3428e821249546c5baef01e113c2396ab944e232001bbad3e611\",\"signing\":\"signed\","
        "\"access\":{\"kind\":\"free-testing\",\"requiresHcgAccount\":true,\"freeUntil\":\"2026-12-15T00:00:00Z\"},\"getUrl\":\"https://store.hakmicapitalgroup.com/apps/hcg-nexus\"}]}";
    rows = [HCGPublicFeeds storeReleaseRowsFromData:[withRelease dataUsingEncoding:NSUTF8StringEncoding] error:&error];
    all = [rows description];
    HCG_CHECK([all rangeOfString:@"temporary free testing until 2026-12-15"].location != NSNotFound, "testing offer");
    HCG_CHECK([all rangeOfString:@"Current release 0.7.0"].location != NSNotFound, "current release");
    HCG_CHECK([all rangeOfString:@"getUrl"].location == NSNotFound && [all rangeOfString:@"apps/hcg-nexus"].location == NSNotFound, "links are not shown from data");
    HCG_CHECK([HCGPublicFeeds storeReleaseRowsFromData:[@"{\"format\":\"x\"}" dataUsingEncoding:NSUTF8StringEncoding] error:&error] == nil, "other format");

    // Integration progress: nine checkpoints from evidence.
    HCGRegistry *r = Registry();
    NSDate *now = CCNow();
    HCGRegistryEntry *trust = [r entryWithIdentifier:@"trust-center"];
    HCGConnectionSummary *c = [HCGCommandCenter connectionForEntry:trust hipStatus:nil ledger:nil registry:r now:now];
    NSArray *progress = [HCGCommandCenter integrationProgressForEntry:trust connection:c hipStatus:nil];
    HCG_CHECK_EQ_INT(progress.count, 9);
    NSArray *dims = [@"Central registration|Authentication|API contract|Adapter implementation|Configuration|Successful communication|Capability validation|Physical testing|Security review" componentsSeparatedByString:@"|"];
    NSUInteger i;
    for (i = 0; i < 9 && i < progress.count; i++) HCG_CHECK_EQ_STR([[progress objectAtIndex:i] objectAtIndex:0], [dims objectAtIndex:i]);
    HCG_CHECK_EQ_STR([[progress objectAtIndex:8] objectAtIndex:1], @"done");    // the recorded independent review
    HCG_CHECK_EQ_STR([[progress objectAtIndex:7] objectAtIndex:1], @"pending"); // never physically validated without a result
    HCGRegistryEntry *uem = [r entryWithIdentifier:@"uem"];
    progress = [HCGCommandCenter integrationProgressForEntry:uem connection:[HCGCommandCenter connectionForEntry:uem hipStatus:nil ledger:nil registry:r now:now] hipStatus:nil];
    HCG_CHECK_EQ_STR([[progress objectAtIndex:0] objectAtIndex:1], @"pending");
    HCG_CHECK_EQ_STR([[progress objectAtIndex:3] objectAtIndex:1], @"pending");
    HCG_CHECK_EQ_STR([[progress objectAtIndex:5] objectAtIndex:1], @"pending");
    HCG_CHECK([HCGCommandCenter connectionForEntry:uem hipStatus:nil ledger:nil registry:r now:now].state == HCGConnectionStatePlanned, "UEM is planned, not connected");
    // Registered is not connected: HCG News is registered centrally but has no successful communication yet.
    HCGRegistryEntry *news = [r entryWithIdentifier:@"news"];
    progress = [HCGCommandCenter integrationProgressForEntry:news connection:[HCGCommandCenter connectionForEntry:news hipStatus:nil ledger:nil registry:r now:now] hipStatus:nil];
    HCG_CHECK_EQ_STR([[progress objectAtIndex:0] objectAtIndex:1], @"done");
    HCG_CHECK_EQ_STR([[progress objectAtIndex:5] objectAtIndex:1], @"pending");
    HCG_CHECK_EQ_STR([[progress objectAtIndex:1] objectAtIndex:1], @"not needed");

    // HCG UEM (proposed contract): tiers only from the document's policy; Nexus never authorizes.
    HCG_CHECK(!HCGUEMNexusMayAuthorize(), "Nexus never authorizes");
    NSString *status = @"{\"schema\":\"hcg.uem.device-status/1\",\"policy\":{\"id\":\"p\",\"version\":3,\"tiers\":[{\"level\":4,\"name\":\"Administrative Device\"},{\"level\":1,\"name\":\"Personal Device\"}]},"
        "\"device\":{\"hcgDeviceId\":\"dev-123\",\"enrollment\":\"enrolled\",\"identityVerified\":true,\"tier\":4,\"credential\":\"valid\",\"posture\":{\"state\":\"compliant\"},"
        "\"permissions\":[\"hcg.server/link.devices.read\"],\"lifecycle\":\"active\",\"jailbroken\":true},\"history\":[{}],\"inventory\":[{},{}]}";
    rows = [HCGUEM rowsFromDeviceStatus:[status dataUsingEncoding:NSUTF8StringEncoding] error:&error];
    all = [rows description];
    HCG_CHECK([all rangeOfString:@"Tier 4: Administrative Device (policy 3)"].location != NSNotFound, "tier name from policy");
    HCG_CHECK([all rangeOfString:@"never adds privileges"].location != NSNotFound, "jailbreak gains nothing");
    HCG_CHECK([all rangeOfString:@"Nexus grants nothing"].location != NSNotFound, "authorization stays with UEM / Connect");
    NSString *unknownTier = [status stringByReplacingOccurrencesOfString:@"\"tier\":4" withString:@"\"tier\":5"];
    all = [[HCGUEM rowsFromDeviceStatus:[unknownTier dataUsingEncoding:NSUTF8StringEncoding] error:&error] description];
    HCG_CHECK([all rangeOfString:@"Not classified by HCG UEM policy"].location != NSNotFound, "no hard-coded tier names");
    NSString *suspended = [status stringByReplacingOccurrencesOfString:@"\"lifecycle\":\"active\"" withString:@"\"lifecycle\":\"suspended\""];
    all = [[HCGUEM rowsFromDeviceStatus:[suspended dataUsingEncoding:NSUTF8StringEncoding] error:&error] description];
    HCG_CHECK([all rangeOfString:@"not in effect while suspended"].location != NSNotFound && [all rangeOfString:@"link.devices.read"].location == NSNotFound, "suspension wins");
    HCG_CHECK([HCGUEM rowsFromDeviceStatus:[@"{\"schema\":\"other\"}" dataUsingEncoding:NSUTF8StringEncoding] error:&error] == nil, "other schema");
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
    testEvidenceLayers();
    testLiveCaptures();
    testCentralRegistry();
    testStoreProgressAndUEM();
}
