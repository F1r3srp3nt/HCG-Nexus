#import "HCGTestHarness.h"
#import "HCGCore.h"

// HCG Interchange Protocol (HIP) v1, package versions and lists, and the ecosystem activity log.

static NSComparisonResult Cmp(NSString *a, NSString *b) {
    return [HCGDebianVersion compare:a with:b];
}

static void testDebianVersionOrdering(void) {
    NSArray *ascending = [NSArray arrayWithObjects:
        @"0.1.0-1", @"0.1.0~beta1", nil];
    // ~ sorts before everything, so a beta is older than its release.
    HCG_CHECK(Cmp(@"0.1.0~beta1", @"0.1.0") == NSOrderedAscending, "beta before release");
    HCG_CHECK(Cmp(@"0.2.0~rc2", @"0.2.0~rc3") == NSOrderedAscending, "rc2 < rc3");
    HCG_CHECK(Cmp(@"0.2.0~dev.5", @"0.2.0~rc1") == NSOrderedAscending, "dev builds before rc1");
    HCG_CHECK(Cmp(@"0.2.0~rc2", @"0.2.0") == NSOrderedAscending, "rc before release");
    HCG_CHECK(Cmp(@"0.2.0", @"0.2.0-1") == NSOrderedAscending, "revision after bare");
    HCG_CHECK(Cmp(@"0.1.0-1", @"0.2.0~rc1") == NSOrderedAscending, "0.1.0-1 < 0.2.0~rc1");
    HCG_CHECK(Cmp(@"0.3.3~beta1", @"0.3.2~beta1") == NSOrderedDescending, "0.3.3 > 0.3.2");
    HCG_CHECK(Cmp(@"0.3.10~beta1", @"0.3.9~beta1") == NSOrderedDescending, "numeric, not lexical");
    HCG_CHECK(Cmp(@"0.4.0~beta1", @"0.3.3~beta1") == NSOrderedDescending, "0.4.0~beta1 > 0.3.3~beta1");
    HCG_CHECK(Cmp(@"1:0.1", @"9.9") == NSOrderedDescending, "epoch wins");
    HCG_CHECK(Cmp(@"0.2.0~rc2", @"0.2.0~rc2") == NSOrderedSame, "equal");
    HCG_CHECK(Cmp(@"16.5", @"17.0") == NSOrderedAscending, "iOS 16.5 < 17.0");
    HCG_CHECK(Cmp(@"17.4", @"17.0") == NSOrderedDescending, "iOS 17.4 > 17.0");
    HCG_CHECK(Cmp(@"17.0", @"17") == NSOrderedDescending, "17.0 vs 17");
    HCG_CHECK(Cmp(@"", @"0.1") == NSOrderedAscending, "invalid sorts first");
    HCG_CHECK(Cmp(nil, nil) == NSOrderedSame, "two invalid are equal");
    HCG_CHECK(Cmp(@"0.1 beta", @"0.1") == NSOrderedAscending, "space is invalid");
    HCG_CHECK(![HCGDebianVersion isValid:@"abc"], "must start with a digit");
    HCG_CHECK(![HCGDebianVersion isValid:@"1:2:3"], "one epoch only");
    HCG_CHECK(![HCGDebianVersion isValid:@"0.1-"], "empty revision");
    HCG_CHECK([HCGDebianVersion isValid:@"0.2.0~rc2"], "rc valid");
    HCG_CHECK(ascending.count == 2, "fixture");
}

static NSString *const kStatusText =
    @"Package: com.hakmicapitalgroup.hcgterminal.unleashed\n"
    @"Status: install ok installed\n"
    @"Architecture: iphoneos-arm64\n"
    @"Version: 0.2.0~rc2\n"
    @"Description: HCG Terminal Unleashed\n"
    @" a continuation line: Version: 9.9.9\n"
    @"\n"
    @"Package: com.hakmicapitalgroup.halo\n"
    @"Status: deinstall ok config-files\n"
    @"Version: 0.3.0~beta1\n"
    @"\n"
    @"Package: com.hakmicapitalgroup.hcgnexus\n"
    @"Status: install ok installed\n"
    @"Version: 0.3.3~beta1\n"
    @"\n"
    @"Package: com.example.other\n"
    @"Status: install ok installed\n"
    @"Version: 1.0\n"
    @"\n"
    @"Package: com.hakmicapitalgroup.broken\n"
    @"Status: install ok installed\n"
    @"Version: not a version\n";

static void testPackageIndexParsing(void) {
    NSDictionary *installed = [HCGPackageIndex installedVersionsFromStatusText:kStatusText packages:[HCGInterchange packageIdentifiers]];
    HCG_CHECK_EQ_STR([installed objectForKey:@"com.hakmicapitalgroup.hcgterminal.unleashed"], @"0.2.0~rc2");
    HCG_CHECK_EQ_STR([installed objectForKey:@"com.hakmicapitalgroup.hcgnexus"], @"0.3.3~beta1");
    HCG_CHECK([installed objectForKey:@"com.hakmicapitalgroup.halo"] == nil, "config-files is not installed");
    HCG_CHECK([installed objectForKey:@"com.example.other"] == nil, "only HCG packages");
    HCG_CHECK([installed objectForKey:@"com.hakmicapitalgroup.broken"] == nil, "invalid version dropped");
    HCG_CHECK_EQ_INT([[HCGPackageIndex installedVersionsFromStatusText:kStatusText packages:nil] count], 3);
    HCG_CHECK_EQ_INT([[HCGPackageIndex recordsFromText:@"\r\n\r\nPackage: a\r\nVersion: 1\r\n"] count], 1);
    HCG_CHECK_EQ_INT([[HCGPackageIndex recordsFromText:nil] count], 0);

    NSString *candidate = @"Package: com.hakmicapitalgroup.hcgnexus\nVersion: 0.3.3~beta1\nArchitecture: iphoneos-arm64\n\n"
                          @"Package: com.hakmicapitalgroup.hcgnexus\nVersion: 0.4.0~beta1\nArchitecture: iphoneos-arm64\n\n"
                          @"Package: com.hakmicapitalgroup.hcgnexus\nVersion: 9.0\nArchitecture: iphoneos-arm\n\n"
                          @"Package: com.hakmicapitalgroup.halo\nVersion: 0.3.1~beta1\nArchitecture: all\n";
    NSString *stable = @"Package: com.hakmicapitalgroup.hcgnexus\nVersion: 0.2.0\nArchitecture: iphoneos-arm64\n";
    NSDictionary *offered = [HCGPackageIndex highestVersionsFromIndexTexts:[NSArray arrayWithObjects:stable, candidate, nil]
                                                                  packages:[HCGInterchange packageIdentifiers]
                                                             architectures:[NSSet setWithObject:@"iphoneos-arm64"]];
    HCG_CHECK_EQ_STR([offered objectForKey:@"com.hakmicapitalgroup.hcgnexus"], @"0.4.0~beta1");
    HCG_CHECK_EQ_STR([offered objectForKey:@"com.hakmicapitalgroup.halo"], @"0.3.1~beta1");
    HCG_CHECK([HCGPackageIndex isUpdate:@"0.4.0~beta1" over:@"0.3.3~beta1"], "newer is an update");
    HCG_CHECK(![HCGPackageIndex isUpdate:@"0.3.3~beta1" over:@"0.3.3~beta1"], "same is not");
    HCG_CHECK(![HCGPackageIndex isUpdate:@"0.3.2~beta1" over:@"0.3.3~beta1"], "older is not");
    HCG_CHECK(![HCGPackageIndex isUpdate:nil over:@"0.3.3~beta1"], "nothing offered");

    HCG_CHECK([HCGPackageIndex isHCGRepoListFileName:@"repo.hakmicapitalgroup.com_repo_candidate_Packages"], "apt list name");
    HCG_CHECK([HCGPackageIndex isHCGRepoListFileName:@"repo.hakmicapitalgroup.com_repo_candidate_._Packages"], "Zebra list name");
    HCG_CHECK(![HCGPackageIndex isHCGRepoListFileName:@"repo.example.com_Packages"], "other repo");
    HCG_CHECK(![HCGPackageIndex isHCGRepoListFileName:@"repo.hakmicapitalgroup.com_repo_candidate_Release"], "not a package list");
    HCG_CHECK_EQ_STR([HCGPackageIndex channelForListFileName:@"repo.hakmicapitalgroup.com_repo_candidate_Packages"], @"candidate");
    HCG_CHECK_EQ_STR([HCGPackageIndex channelForListFileName:@"repo.hakmicapitalgroup.com_repo_._Packages"], @"stable");
}

static void testRegistryInvariants(void) {
    NSArray *registry = [HCGInterchange registry];
    HCG_CHECK(registry.count == 14, "fourteen products, got %lu", (unsigned long)registry.count);
    NSMutableSet *ids = [NSMutableSet set], *packages = [NSMutableSet set];
    NSUInteger verified = 0;
    for (HCGHIPProductDescriptor *d in registry) {
        HCG_CHECK(![ids containsObject:d.productID], "unique id %s", [d.productID UTF8String]);
        [ids addObject:d.productID];
        if (d.packageIdentifier) {
            HCG_CHECK(![packages containsObject:d.packageIdentifier], "unique package %s", [d.packageIdentifier UTF8String]);
            [packages addObject:d.packageIdentifier];
        }
        HCG_CHECK(d.name.length && d.summary.length && d.symbolName.length, "described: %s", [d.productID UTF8String]);
        HCG_CHECK([[HCGInterchange descriptorForProductID:d.productID] isEqual:d], "lookup %s", [d.productID UTF8String]);
        for (HCGHIPRoute *route in d.routes) {
            NSString *t = route.target;
            // Fixed, navigation-only targets: nothing a parameter could ride on.
            HCG_CHECK([t rangeOfString:@"?"].location == NSNotFound && [t rangeOfString:@"&"].location == NSNotFound &&
                      [t rangeOfString:@"#"].location == NSNotFound && [t rangeOfString:@" "].location == NSNotFound,
                      "plain target %s", [t UTF8String]);
            if (route.kind == HCGHIPRouteKindAppLink) {
                NSString *prefix = [d.urlScheme stringByAppendingString:@"://open/"];
                HCG_CHECK([t hasPrefix:prefix] && [[t substringFromIndex:prefix.length] rangeOfString:@"/"].location == NSNotFound,
                          "one-screen link %s", [t UTF8String]);
                HCG_CHECK([HCGInterchange isRegistryLink:t], "registered %s", [t UTF8String]);
            }
            if (route.kind == HCGHIPRouteKindWeb) HCG_CHECK([t hasPrefix:@"https://"], "https only: %s", [t UTF8String]);
            if (route.requirement == HCGHIPRouteRequirementDeclaredRoute) {
                HCG_CHECK(route.kind == HCGHIPRouteKindAppLink, "only links can be declared");
                HCG_CHECK(route.fallbackRouteIdentifier == nil || [d routeWithIdentifier:route.fallbackRouteIdentifier] != nil, "fallback exists");
            }
        }
        for (HCGHIPCapability *c in d.capabilities) {
            HCG_CHECK(c.note.length > 0, "every capability explains itself: %s", [c.identifier UTF8String]);
            if (c.state == HCGHIPCapabilityStateVerified) verified++;
        }
        // HCG Server's capabilities are built (standalone app), but a build without the Device Link client
        // resolves them as unavailable (testPreparedAdaptersClaimNothing); everything else claims nothing.
        if (d.unavailableReason.length && ![d.productID isEqualToString:HCGHIPProductServer]) {
            for (HCGHIPCapability *c in d.capabilities) {
                HCG_CHECK(c.state == HCGHIPCapabilityStatePlanned || c.state == HCGHIPCapabilityStateUnavailable,
                          "nothing claimed for %s: %s", [d.productID UTF8String], [c.identifier UTF8String]);
            }
        }
    }
    HCG_CHECK(verified == 4, "only the owner-confirmed Terminal Unleashed capabilities are verified (%lu)", (unsigned long)verified);
    HCG_CHECK([HCGInterchange descriptorForProductID:@"nope"] == nil, "unknown id");
    HCG_CHECK_EQ_STR([[HCGInterchange descriptorForBundleIdentifier:@"com.hcg.sentinel"] productID], HCGHIPProductSentinel);
    HCG_CHECK_EQ_STR([[HCGInterchange descriptorForProductID:HCGHIPProductTerminalUnleashed] minimumOSVersion], @"17.0");
    HCG_CHECK([HCGInterchange isRegistryLink:@"hcgsentinel://open/securityLab"], "Sentinel Security Lab");
    HCG_CHECK(![HCGInterchange isRegistryLink:@"hcgsentinel://open/securityLab?x"], "exact text only");
    // Registry Sentinel sections are a subset of what HCG Sentinel accepts.
    for (HCGHIPRoute *route in [[HCGInterchange descriptorForProductID:HCGHIPProductSentinel] routes]) {
        if (route.kind == HCGHIPRouteKindAppLink) {
            HCG_CHECK([HCGSentinelLinks problemWithURLString:route.target] == nil, "Sentinel accepts %s", [route.target UTF8String]);
        }
    }
}

static HCGHIPFacts *Facts(NSString *productID, NSString *os) {
    HCGHIPFacts *f = [[HCGHIPFacts alloc] init];
    f.productID = productID;
    f.hostCanInspect = YES;
    f.hostCanLaunchApps = YES;
    f.osVersion = os;
    return f;
}

static HCGHIPRoute *RouteNamed(HCGHIPProductStatus *s, NSString *identifier) {
    for (HCGHIPRoute *route in s.routes) if ([route.identifier isEqualToString:identifier]) return route;
    return nil;
}

static HCGHIPResolvedCapability *CapabilityNamed(HCGHIPProductStatus *s, NSString *identifier) {
    for (HCGHIPResolvedCapability *c in s.capabilities) if ([c.capability.identifier isEqualToString:identifier]) return c;
    return nil;
}

static HCGHIPFacts *UnleashedRC2(void) {
    HCGHIPFacts *f = Facts(HCGHIPProductTerminalUnleashed, @"17.4");
    f.packageVersion = @"0.2.0~rc2";
    f.appInstalled = YES;
    f.appVersion = @"0.2.0";
    f.appBuild = @"2";
    f.declaredSchemes = [NSArray arrayWithObject:@"hcgterminal-unleashed"];
    return f;
}

static void testTerminalUnleashedOnTheOwnersIPhone11(void) {
    HCGHIPProductDescriptor *d = [HCGInterchange descriptorForProductID:HCGHIPProductTerminalUnleashed];
    HCGHIPProductStatus *s = [HCGInterchange statusForDescriptor:d facts:UnleashedRC2()];
    HCG_CHECK_EQ_INT(s.availability, HCGHIPAvailabilityReady);
    HCG_CHECK_EQ_STR(s.versionText, @"0.2.0~rc2 · app 0.2.0 (2)");
    HCG_CHECK(![s.stateTitle isEqualToString:@"Connected"] && [s.integrationText rangeOfString:@"Connected"].location == NSNotFound, "never Connected");
    HCG_CHECK(RouteNamed(s, @"open-app") != nil, "open app");
    HCG_CHECK_EQ_STR(RouteNamed(s, @"tools").target, @"hcgterminal-unleashed://open/tools");
    HCG_CHECK_EQ_STR(RouteNamed(s, @"diagnostics").target, @"hcgterminal-unleashed://open/diagnostics");
    // rc2 has no direct links for these: offered through Unleashed Tools, and said so.
    HCGHIPRoute *jb = RouteNamed(s, @"jailbreak-diagnostics");
    HCG_CHECK_EQ_STR(jb.target, @"hcgterminal-unleashed://open/tools");
    HCG_CHECK([jb.detail rangeOfString:@"no direct link"].location != NSNotFound, "honest detail");
    HCG_CHECK_EQ_STR(RouteNamed(s, @"packages").target, @"hcgterminal-unleashed://open/tools");
    HCG_CHECK_EQ_STR(RouteNamed(s, @"processes").target, @"hcgterminal-unleashed://open/tools");
    HCG_CHECK(RouteNamed(s, @"package-manager") == nil, "no package manager found");
    HCG_CHECK_EQ_INT(CapabilityNamed(s, @"local-shell").state, HCGHIPCapabilityStateVerified);
    HCG_CHECK_EQ_INT(CapabilityNamed(s, @"jailbreak-diagnostics").state, HCGHIPCapabilityStateVerified);
    HCG_CHECK_EQ_INT(CapabilityNamed(s, @"process-list").state, HCGHIPCapabilityStateAvailable);
    HCG_CHECK_EQ_INT(CapabilityNamed(s, @"open-nexus").state, HCGHIPCapabilityStatePlanned);
    HCG_CHECK_EQ_INT(CapabilityNamed(s, @"package-changes").capability.permission, HCGHIPPermissionApprovalInProduct);
    for (HCGHIPRoute *route in s.routes) {
        HCG_CHECK(route.kind != HCGHIPRouteKindAppLink || [HCGTerminalHandoff problemWithLinkText:route.target] == nil,
                  "every offered link passes Nexus's own validation: %s", [route.target UTF8String]);
    }

    // A build that declares the direct routes (the proposed HCG Terminal companion change).
    HCGHIPFacts *f = UnleashedRC2();
    NSMutableDictionary *declaration = [NSMutableDictionary dictionary];
    [declaration setObject:[NSNumber numberWithInt:1] forKey:HCGInterchangeProtocolKey];
    [declaration setObject:HCGHIPProductTerminalUnleashed forKey:HCGInterchangeProductKey];
    [declaration setObject:[NSArray arrayWithObjects:@"jailbreak-diagnostics", @"packages", @"processes", @"run-shell", @"tools", nil]
                    forKey:HCGInterchangeRoutesKey];
    f.declaration = declaration;
    s = [HCGInterchange statusForDescriptor:d facts:f];
    HCG_CHECK_EQ_STR(RouteNamed(s, @"jailbreak-diagnostics").target, @"hcgterminal-unleashed://open/jailbreak-diagnostics");
    HCG_CHECK_EQ_STR(RouteNamed(s, @"packages").target, @"hcgterminal-unleashed://open/packages");
    HCG_CHECK(RouteNamed(s, @"run-shell") == nil, "a declaration cannot add a route Nexus does not know");
    HCG_CHECK([s.declarationNote rangeOfString:@"run-shell"].location != NSNotFound, "ignored routes are reported");

    // Capabilities in a declaration can only switch things off.
    [declaration setObject:[NSArray arrayWithObjects:@"local-shell", @"open-nexus", @"remote-root", nil] forKey:HCGInterchangeCapabilitiesKey];
    f.declaration = declaration;
    s = [HCGInterchange statusForDescriptor:d facts:f];
    HCG_CHECK_EQ_INT(CapabilityNamed(s, @"local-shell").state, HCGHIPCapabilityStateVerified);
    HCG_CHECK_EQ_INT(CapabilityNamed(s, @"ssh").state, HCGHIPCapabilityStateUnavailable);
    HCG_CHECK_EQ_INT(CapabilityNamed(s, @"open-nexus").state, HCGHIPCapabilityStatePlanned);
    HCG_CHECK(CapabilityNamed(s, @"remote-root") == nil, "unknown capability not added");

    // Declarations for another product or protocol are ignored entirely.
    [declaration setObject:HCGHIPProductSentinel forKey:HCGInterchangeProductKey];
    f.declaration = declaration;
    s = [HCGInterchange statusForDescriptor:d facts:f];
    HCG_CHECK_EQ_STR(RouteNamed(s, @"packages").target, @"hcgterminal-unleashed://open/tools");
    HCG_CHECK(s.declarationNote.length > 0, "explained");
    [declaration setObject:HCGHIPProductTerminalUnleashed forKey:HCGInterchangeProductKey];
    [declaration setObject:[NSNumber numberWithInt:2] forKey:HCGInterchangeProtocolKey];
    f.declaration = declaration;
    s = [HCGInterchange statusForDescriptor:d facts:f];
    HCG_CHECK_EQ_STR(RouteNamed(s, @"packages").target, @"hcgterminal-unleashed://open/tools");
    HCG_CHECK_EQ_INT(CapabilityNamed(s, @"ssh").state, HCGHIPCapabilityStateAvailable);
    f.declaration = @"garbage";
    s = [HCGInterchange statusForDescriptor:d facts:f];
    HCG_CHECK_EQ_INT(s.availability, HCGHIPAvailabilityReady);
}

static void testTerminalUnleashedOnTheIPhone13(void) {
    HCGHIPProductDescriptor *d = [HCGInterchange descriptorForProductID:HCGHIPProductTerminalUnleashed];
    HCGHIPFacts *f = Facts(HCGHIPProductTerminalUnleashed, @"16.5");
    f.offeredVersion = @"0.2.0~rc2";
    f.packageManagers = [NSArray arrayWithObject:@"zebra"];
    HCGHIPProductStatus *s = [HCGInterchange statusForDescriptor:d facts:f];
    HCG_CHECK_EQ_INT(s.availability, HCGHIPAvailabilityUnsupportedOS);
    HCG_CHECK([s.compatibilityText rangeOfString:@"Requires iOS 17.0"].location != NSNotFound, "says why: %s", [s.compatibilityText UTF8String]);
    HCG_CHECK([s.compatibilityText rangeOfString:@"16.5"].location != NSNotFound, "names this iOS");
    HCG_CHECK(s.routes.count == 1 && RouteNamed(s, @"package-manager") != nil, "only viewing the package");
    HCG_CHECK_EQ_INT(CapabilityNamed(s, @"local-shell").state, HCGHIPCapabilityStateUnavailable);
    HCG_CHECK(!s.updateAvailable, "no update for something not installed");

    // Same iPhone, a product that supports it: Nexus keeps working, HCG Halo not installed.
    HCGHIPProductStatus *halo = [HCGInterchange statusForDescriptor:[HCGInterchange descriptorForProductID:HCGHIPProductHalo] facts:Facts(HCGHIPProductHalo, @"16.5")];
    HCG_CHECK_EQ_INT(halo.availability, HCGHIPAvailabilityNotInstalled);
    HCG_CHECK(halo.routes.count == 0, "no routes for a missing tweak without a package manager");

    // An older Unleashed without Nexus links.
    f = Facts(HCGHIPProductTerminalUnleashed, @"17.4");
    f.packageVersion = @"0.1.0-1";
    f.appInstalled = YES;
    s = [HCGInterchange statusForDescriptor:d facts:f];
    HCG_CHECK_EQ_INT(s.availability, HCGHIPAvailabilityNeedsUpdate);
    HCG_CHECK(RouteNamed(s, @"open-app") != nil && RouteNamed(s, @"tools") == nil, "opens, but no links");

    // The sandboxed standalone app: installation is private; the link still opens it.
    f = [[HCGHIPFacts alloc] init];
    f.productID = HCGHIPProductTerminalUnleashed;
    f.canOpenScheme = YES;
    s = [HCGInterchange statusForDescriptor:d facts:f];
    HCG_CHECK_EQ_INT(s.availability, HCGHIPAvailabilityUnknown);
    HCG_CHECK(RouteNamed(s, @"tools") != nil && RouteNamed(s, @"open-app") == nil, "links only in the sandbox");
    s = [HCGInterchange statusForDescriptor:d facts:nil];
    HCG_CHECK_EQ_INT(s.availability, HCGHIPAvailabilityUnknown);
    HCG_CHECK(s.routes.count == 0, "nothing without facts");
}

static NSDictionary *HaloStatus(NSString *state) {
    return [NSDictionary dictionaryWithObject:[NSDictionary dictionaryWithObject:state forKey:@"state"] forKey:@"status"];
}

static void testTweakStatesAndReadouts(void) {
    HCGHIPProductDescriptor *halo = [HCGInterchange descriptorForProductID:HCGHIPProductHalo];
    HCGHIPFacts *f = Facts(HCGHIPProductHalo, @"16.5");
    f.packageVersion = @"0.3.1~beta1";
    f.settingsBundlePresent = YES;
    HCGHIPProductStatus *s = [HCGInterchange statusForDescriptor:halo facts:f];
    HCG_CHECK_EQ_INT(s.availability, HCGHIPAvailabilityOff); // HCG Halo is off by default
    HCG_CHECK(RouteNamed(s, @"nexus-border") != nil && RouteNamed(s, @"settings") != nil, "border switch and Settings");
    HCG_CHECK_EQ_INT(CapabilityNamed(s, @"panel-border").state, HCGHIPCapabilityStateDisabled);
    HCG_CHECK_EQ_INT(CapabilityNamed(s, @"appearance-write").state, HCGHIPCapabilityStateUnavailable);
    HCG_CHECK(s.readouts.count == halo.readouts.count, "readouts shown");
    HCG_CHECK_EQ_STR([[s.readouts objectAtIndex:4] objectAtIndex:1], @"#00E5FF #7B61FF #C026FF");
    HCG_CHECK_EQ_STR([[s.readouts objectAtIndex:5] objectAtIndex:1], @"90%");

    NSMutableDictionary *prefs = [NSMutableDictionary dictionary];
    [prefs setObject:[NSNumber numberWithBool:YES] forKey:@"enabled"];
    [prefs setObject:@"flow" forKey:@"mode"];
    [prefs setObject:[NSArray arrayWithObjects:@"#ff0000", @"red", [NSNumber numberWithInt:3], nil] forKey:@"colours"];
    [prefs setObject:@"not a number" forKey:@"brightness"];
    f.preferences = prefs;
    f.statusRecord = HaloStatus(@"active");
    s = [HCGInterchange statusForDescriptor:halo facts:f];
    HCG_CHECK_EQ_INT(s.availability, HCGHIPAvailabilityReady);
    HCG_CHECK_EQ_STR(s.healthText, @"Active");
    HCG_CHECK_EQ_STR([[s.readouts objectAtIndex:2] objectAtIndex:1], @"flow");
    HCG_CHECK_EQ_STR([[s.readouts objectAtIndex:4] objectAtIndex:1], @"#FF0000");
    HCG_CHECK_EQ_STR([[s.readouts objectAtIndex:5] objectAtIndex:1], @"90%"); // wrong type: the product's default

    NSArray *attention = [NSArray arrayWithObjects:@"fault", @"kill-switch", @"auto-disabled", @"incompatible", nil];
    for (NSString *state in attention) {
        f.statusRecord = HaloStatus(state);
        s = [HCGInterchange statusForDescriptor:halo facts:f];
        HCG_CHECK_EQ_INT(s.availability, HCGHIPAvailabilityAttention);
        HCG_CHECK(s.healthText.length > 0, "explains %s", [state UTF8String]);
    }
    f.statusRecord = [NSDictionary dictionaryWithObject:@"fault" forKey:@"state"]; // wrong shape for HCG Halo
    s = [HCGInterchange statusForDescriptor:halo facts:f];
    HCG_CHECK_EQ_INT(s.availability, HCGHIPAvailabilityReady);

    f.packageVersion = @"0.1.0~beta1";
    s = [HCGInterchange statusForDescriptor:halo facts:f];
    HCG_CHECK_EQ_INT(s.availability, HCGHIPAvailabilityNeedsUpdate);

    // HCG Vortex: on by default, status fields are top-level keys.
    HCGHIPProductDescriptor *vortex = [HCGInterchange descriptorForProductID:HCGHIPProductVortex];
    f = Facts(HCGHIPProductVortex, @"17.4");
    f.packageVersion = @"0.3.1~beta1";
    s = [HCGInterchange statusForDescriptor:vortex facts:f];
    HCG_CHECK_EQ_INT(s.availability, HCGHIPAvailabilityReady);
    f.statusRecord = [NSDictionary dictionaryWithObject:@"kill-switch" forKey:@"state"];
    s = [HCGInterchange statusForDescriptor:vortex facts:f];
    HCG_CHECK_EQ_INT(s.availability, HCGHIPAvailabilityAttention);
    HCG_CHECK(RouteNamed(s, @"settings") == nil, "no Settings route without its bundle");

    // Updates from the package manager's lists.
    f = Facts(HCGHIPProductPortal, @"17.4");
    f.packageVersion = @"0.1.0~beta3";
    f.offeredVersion = @"0.1.0~beta4";
    s = [HCGInterchange statusForDescriptor:[HCGInterchange descriptorForProductID:HCGHIPProductPortal] facts:f];
    HCG_CHECK(s.updateAvailable && [s.updateText rangeOfString:@"0.1.0~beta4"].location != NSNotFound, "update shown");
    f.offeredVersion = @"0.1.0~beta2";
    s = [HCGInterchange statusForDescriptor:[HCGInterchange descriptorForProductID:HCGHIPProductPortal] facts:f];
    HCG_CHECK(!s.updateAvailable, "older offer is not an update");
}

static void testPreparedAdaptersClaimNothing(void) {
    NSArray *ids = [NSArray arrayWithObjects:HCGHIPProductAgentRuntime, HCGHIPProductServer, HCGHIPProductConnect, HCGHIPProductExecutableMaker, nil];
    for (NSString *productID in ids) {
        HCGHIPFacts *f = Facts(productID, @"17.4");
        f.packageManagers = [NSArray arrayWithObject:@"zebra"];
        HCGHIPProductStatus *s = [HCGInterchange statusForDescriptor:[HCGInterchange descriptorForProductID:productID] facts:f];
        HCG_CHECK_EQ_INT(s.availability, HCGHIPAvailabilityNotAvailable);
        HCG_CHECK(s.routes.count == 0, "no routes: %s", [productID UTF8String]);
        HCG_CHECK([s.healthText hasPrefix:@"Unavailable:"] || [s.healthText hasPrefix:@"Not available:"], "says it is not available: %s", [productID UTF8String]);
        HCG_CHECK_EQ_STR(s.stateTitle, @"Not available yet");
        for (HCGHIPResolvedCapability *c in s.capabilities) {
            HCG_CHECK(c.state != HCGHIPCapabilityStateAvailable && c.state != HCGHIPCapabilityStateVerified, "%s claims %s",
                      [productID UTF8String], [c.capability.identifier UTF8String]);
        }
    }
    HCGHIPProductStatus *nexus = [HCGInterchange statusForDescriptor:[HCGInterchange descriptorForProductID:HCGHIPProductNexus] facts:Facts(HCGHIPProductNexus, @"16.5")];
    HCG_CHECK_EQ_INT(nexus.availability, HCGHIPAvailabilityHub);
    HCG_CHECK_EQ_STR(nexus.versionText, HCG_NEXUS_VERSION);
    HCG_CHECK_EQ_INT(CapabilityNamed(nexus, @"package-changes").state, HCGHIPCapabilityStateUnavailable);
}

static HCGHIPProductStatus *ServerStatus(HCGHIPFacts *f) {
    return [HCGInterchange statusForDescriptor:[HCGInterchange descriptorForProductID:HCGHIPProductServer] facts:f];
}

// HCG Server's card follows the app's real HCG Device Link state; Connected only when the platform says a
// request succeeded, otherwise the real reason. Nothing is invented.
static void testServerReflectsTheRealDeviceLinkState(void) {
    HCGHIPFacts *f = Facts(HCGHIPProductServer, @"17.4");
    f.hostCanInspect = NO;

    // Not reported (jailbreak package, Settings, preview): not available, nothing claimed.
    HCGHIPProductStatus *s = ServerStatus(f);
    HCG_CHECK_EQ_INT(s.availability, HCGHIPAvailabilityNotAvailable);
    HCG_CHECK([s.healthText rangeOfString:@"standalone HCG Nexus app"].location != NSNotFound, "says where Device Link runs");

    f.serviceLinkState = HCGHIPServiceLinkStateNotPaired;
    s = ServerStatus(f);
    HCG_CHECK_EQ_INT(s.availability, HCGHIPAvailabilityNotConnected);
    HCG_CHECK_EQ_STR(s.stateTitle, @"Not connected");
    HCG_CHECK(!s.installed, "a server is never 'installed'");
    HCG_CHECK(s.routes.count == 0, "no routes");
    HCG_CHECK_EQ_INT(CapabilityNamed(s, @"pairing").state, HCGHIPCapabilityStateAvailable);
    HCG_CHECK_EQ_INT(CapabilityNamed(s, @"hosted-services").state, HCGHIPCapabilityStateUnavailable);
    HCG_CHECK_EQ_INT(CapabilityNamed(s, @"remote-actions").state, HCGHIPCapabilityStateUnavailable);
    HCG_CHECK([s.integrationText rangeOfString:@"Connected only after"].location != NSNotFound, "explains when it says connected");

    f.serviceLinkState = HCGHIPServiceLinkStateUnreachable;
    f.serviceLinkServerName = @"Studio Mac";
    f.serviceLinkDetail = @"The connection timed out.";
    s = ServerStatus(f);
    HCG_CHECK_EQ_INT(s.availability, HCGHIPAvailabilityUnreachable);
    HCG_CHECK_EQ_STR(s.stateTitle, @"Unreachable");
    HCG_CHECK_EQ_STR(s.healthText, @"Studio Mac is unreachable. The connection timed out.");

    f.serviceLinkState = HCGHIPServiceLinkStateEnded;
    f.serviceLinkDetail = @"Studio Mac changed how it authorizes apps.";
    s = ServerStatus(f);
    HCG_CHECK_EQ_INT(s.availability, HCGHIPAvailabilityNotConnected);
    HCG_CHECK([s.healthText hasSuffix:@"changed how it authorizes apps."], "real reason shown");

    f.serviceLinkState = HCGHIPServiceLinkStateConnected;
    f.serviceLinkDetail = nil;
    f.serviceLinkHostedServices = 1;
    f.serviceLinkLocalDevelopment = YES;
    s = ServerStatus(f);
    HCG_CHECK_EQ_INT(s.availability, HCGHIPAvailabilityConnected);
    HCG_CHECK_EQ_STR(s.stateTitle, @"Connected");
    HCG_CHECK_EQ_STR(s.healthText, @"Connected to Studio Mac · 1 hosted service");
    HCG_CHECK([s.integrationText hasPrefix:HCGHIPLocalDevelopmentLabel], "local development is labelled");
    HCG_CHECK_EQ_STR(HCGHIPLocalDevelopmentLabel, @"LOCAL DEVELOPMENT — not an HCG account");
    HCG_CHECK_EQ_INT(CapabilityNamed(s, @"hosted-services").state, HCGHIPCapabilityStateAvailable);
    HCG_CHECK_EQ_INT(CapabilityNamed(s, @"remote-actions").state, HCGHIPCapabilityStateUnavailable);

    f.serviceLinkLocalDevelopment = NO;
    f.serviceLinkHostedServices = -1;
    s = ServerStatus(f);
    HCG_CHECK_EQ_STR(s.healthText, @"Connected to Studio Mac");
    HCG_CHECK([s.integrationText rangeOfString:@"LOCAL DEVELOPMENT"].location == NSNotFound, "HCG Connect pairing is not labelled local");

    // Other products ignore service-link facts.
    HCGHIPFacts *halo = Facts(HCGHIPProductHalo, @"17.4");
    halo.serviceLinkState = HCGHIPServiceLinkStateConnected;
    HCG_CHECK([HCGInterchange statusForDescriptor:[HCGInterchange descriptorForProductID:HCGHIPProductHalo] facts:halo].availability == HCGHIPAvailabilityNotInstalled,
              "only services use the link state");
    HCG_CHECK_EQ_STR([HCGInterchange titleForAvailability:HCGHIPAvailabilityNotConnected], @"Not connected");
}

static void testOpenRequestsAndLinks(void) {
    NSString *name = [HCGInterchange openProductDarwinNotificationForProductID:HCGHIPProductHalo];
    HCG_CHECK_EQ_STR(name, @"com.hakmicapitalgroup.hcgnexus/open/product/halo");
    HCG_CHECK_EQ_STR([HCGInterchange productIDForOpenDarwinNotification:name], HCGHIPProductHalo);
    HCG_CHECK([HCGInterchange openProductDarwinNotificationForProductID:@"../x"] == nil, "unknown product");
    HCG_CHECK([HCGInterchange productIDForOpenDarwinNotification:@"com.hakmicapitalgroup.hcgnexus/open/product/evil"] == nil, "unknown name");
    HCG_CHECK([HCGInterchange productIDForOpenDarwinNotification:HCGNexusOpenEcosystemDarwinNotification] == nil, "overview has no product");
    HCG_CHECK(HCGNexusOpenRequestMinimumInterval >= 1.0, "rate limited");
    HCG_CHECK_EQ_STR([HCGInterchange packageManagerLinkForManager:@"zebra" packageIdentifier:@"com.hakmicapitalgroup.halo"], @"zbra://packages/com.hakmicapitalgroup.halo");
    HCG_CHECK_EQ_STR([HCGInterchange packageManagerLinkForManager:@"sileo" packageIdentifier:@"com.hakmicapitalgroup.portal"], @"sileo://package/com.hakmicapitalgroup.portal");
    HCG_CHECK([HCGInterchange packageManagerLinkForManager:@"zebra" packageIdentifier:@"com.evil"] == nil, "HCG packages only");
    HCG_CHECK([HCGInterchange packageManagerLinkForManager:@"cydia" packageIdentifier:@"com.hakmicapitalgroup.halo"] == nil, "known managers only");
}

static void testActivityLog(void) {
    NSDate *t = [NSDate dateWithTimeIntervalSince1970:1700000000];
    NSDictionary *e = [HCGEcosystemActivity entryWithText:@"Opened HCG Terminal Unleashed › Jailbreak Diagnostics" productID:HCGHIPProductTerminalUnleashed time:t];
    HCG_CHECK(e != nil && [[e objectForKey:@"product"] isEqualToString:HCGHIPProductTerminalUnleashed], "entry");
    HCG_CHECK([HCGEcosystemActivity entryWithText:@"Opened hcgterminal://open/tools" productID:nil time:t] == nil, "no URLs");
    HCG_CHECK([HCGEcosystemActivity entryWithText:@"" productID:nil time:t] == nil, "no empty text");
    NSDictionary *unknown = [HCGEcosystemActivity entryWithText:@"x" productID:@"evil" time:t];
    HCG_CHECK([unknown objectForKey:@"product"] == nil, "unknown products dropped");
    NSString *longText = [@"" stringByPaddingToLength:500 withString:@"a" startingAtIndex:0];
    HCG_CHECK([[[HCGEcosystemActivity entryWithText:longText productID:nil time:t] objectForKey:@"text"] length] == 140, "clipped");
    HCG_CHECK([[[HCGEcosystemActivity entryWithText:@"two\nlines" productID:nil time:t] objectForKey:@"text"] isEqualToString:@"two lines"], "one line");

    NSArray *list = [NSArray array];
    for (int i = 0; i < 50; i++) {
        list = [HCGEcosystemActivity entries:list byAdding:[HCGEcosystemActivity entryWithText:[NSString stringWithFormat:@"event %d", i] productID:nil time:t]];
    }
    HCG_CHECK_EQ_INT(list.count, HCGEcosystemActivityLimit);
    HCG_CHECK_EQ_STR([[list objectAtIndex:0] objectForKey:@"text"], @"event 49");
    NSArray *stored = [NSArray arrayWithObjects:@"junk", [NSDictionary dictionaryWithObject:@"no time" forKey:@"text"], e, nil];
    HCG_CHECK_EQ_INT([[HCGEcosystemActivity entriesFromStoredValue:stored] count], 1);
    HCG_CHECK_EQ_INT([[HCGEcosystemActivity entriesFromStoredValue:@"junk"] count], 0);
}

void HCGRunEcosystemTests(void) {
    HCG_RUN(testDebianVersionOrdering);
    HCG_RUN(testPackageIndexParsing);
    HCG_RUN(testRegistryInvariants);
    HCG_RUN(testTerminalUnleashedOnTheOwnersIPhone11);
    HCG_RUN(testTerminalUnleashedOnTheIPhone13);
    HCG_RUN(testTweakStatesAndReadouts);
    HCG_RUN(testPreparedAdaptersClaimNothing);
    HCG_RUN(testServerReflectsTheRealDeviceLinkState);
    HCG_RUN(testOpenRequestsAndLinks);
    HCG_RUN(testActivityLog);
}
