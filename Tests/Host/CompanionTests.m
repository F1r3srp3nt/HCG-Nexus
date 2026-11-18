// HCG Halo panel border state and HCG Terminal handoff: every state from documented inputs,
// missing companions, incompatible versions, a disabled Halo, open/close, and link validation.
#import "HCGTestHarness.h"
#import "HCGCore.h"

#pragma mark - HCG Halo

static NSDictionary *HaloPrefs(BOOL enabled, NSString *target) {
    NSMutableDictionary *d = [NSMutableDictionary dictionary];
    [d setObject:[NSNumber numberWithBool:enabled] forKey:HCGHaloKeyEnabled];
    if (target) [d setObject:target forKey:HCGHaloKeyTarget];
    return d;
}

static NSDictionary *HaloStatus(NSString *engine, NSString *nexusState, NSString *nexusDetail) {
    NSMutableDictionary *d = [NSMutableDictionary dictionary];
    if (engine) [d setObject:engine forKey:HCGHaloStatusKeyState];
    if (nexusState) [d setObject:nexusState forKey:HCGHaloStatusKeyNexusState];
    if (nexusDetail) [d setObject:nexusDetail forKey:HCGHaloStatusKeyNexusDetail];
    return d;
}

// Halo 0.3.1~beta1 with the switch API, panel border on, engine active, waiting for the panel.
static HCGHaloBorderFacts *ReadyFacts(void) {
    HCGHaloBorderFacts *f = [[HCGHaloBorderFacts alloc] init];
    f.haloInstalled = YES;
    f.haloVersion = @"0.3.1~beta1";
    f.integrationVersion = 1;
    f.controlVersion = 1;
    f.haloPreferences = HaloPrefs(YES, @"nexus");
    f.haloStatus = HaloStatus(@"active", @"waiting", nil);
    return f;
}

static void testHaloMissingAndIncompatible(void) {
    HCGHaloBorderFacts *none = [[HCGHaloBorderFacts alloc] init];
    HCGHaloBorderStatus *s = [HCGHaloBorderStatus statusWithFacts:none];
    HCG_CHECK_EQ_INT(s.state, HCGHaloBorderStateNotInstalled);
    HCG_CHECK(!s.canSwitch && !s.switchOn, "nothing to switch without Halo");
    HCG_CHECK([s.detail rangeOfString:@"own outline"].location != NSNotFound, "Nexus keeps its outline");

    // Halo 0.1.x: no Nexus border at all.
    HCGHaloBorderFacts *old = ReadyFacts();
    old.haloVersion = @"0.1.0~beta1";
    old.integrationVersion = 0;
    old.controlVersion = 0;
    s = [HCGHaloBorderStatus statusWithFacts:old];
    HCG_CHECK_EQ_INT(s.state, HCGHaloBorderStateIncompatible);
    HCG_CHECK(!s.canSwitch, "no switch for an incompatible Halo");
    HCG_CHECK([s.detail rangeOfString:@"0.1.0~beta1"].location != NSNotFound, "names the installed version");

    // Nexus's own definition broken.
    HCGHaloBorderFacts *def = ReadyFacts();
    def.definitionProblem = @"HaloBorder.plist is missing";
    HCG_CHECK_EQ_INT([HCGHaloBorderStatus statusWithFacts:def].state, HCGHaloBorderStateIncompatible);

    // Halo can't attach (e.g. Nexus updated without a respring): its own reason is shown.
    HCGHaloBorderFacts *mismatch = ReadyFacts();
    mismatch.haloStatus = HaloStatus(@"active", @"unavailable", @"HCG Nexus was updated; respring to use the border");
    s = [HCGHaloBorderStatus statusWithFacts:mismatch];
    HCG_CHECK_EQ_INT(s.state, HCGHaloBorderStateIncompatible);
    HCG_CHECK_EQ_STR(s.detail, @"HCG Nexus was updated; respring to use the border");
    HCG_CHECK(s.switchOn, "the switch still reflects Halo's setting");

    // Halo reports an unsupported iOS.
    HCGHaloBorderFacts *ios = ReadyFacts();
    ios.haloStatus = HaloStatus(@"incompatible", @"off", nil);
    HCG_CHECK_EQ_INT([HCGHaloBorderStatus statusWithFacts:ios].state, HCGHaloBorderStateIncompatible);

    // A future switch interface is not driven blindly.
    HCGHaloBorderFacts *future = ReadyFacts();
    future.controlVersion = 2;
    s = [HCGHaloBorderStatus statusWithFacts:future];
    HCG_CHECK(!s.canSwitch, "unknown control version is not used");
    HCG_CHECK(s.switchNote.length > 0, "explains why");
}

static void testHaloDisabledStates(void) {
    // Halo installed (0.2.1) with the panel border off in each way.
    NSArray *offPrefs = [NSArray arrayWithObjects:HaloPrefs(NO, @"nexus"), HaloPrefs(NO, @"both"), HaloPrefs(YES, @"screen"),
                                                  HaloPrefs(YES, nil), HaloPrefs(YES, @"NEXUS"), [NSDictionary dictionary], nil];
    for (NSDictionary *prefs in offPrefs) {
        HCGHaloBorderFacts *f = ReadyFacts();
        f.haloPreferences = prefs;
        f.haloStatus = HaloStatus(@"active", @"off", nil);
        HCGHaloBorderStatus *s = [HCGHaloBorderStatus statusWithFacts:f];
        HCG_CHECK_EQ_INT(s.state, HCGHaloBorderStateDisabled);
        HCG_CHECK(!s.switchOn, "off: %s", [[prefs description] UTF8String]);
        HCG_CHECK(s.canSwitch, "Halo 0.3.1 can be switched on from Nexus");
    }
    // A malformed 'enabled' value means off.
    HCGHaloBorderFacts *bad = ReadyFacts();
    NSMutableDictionary *p = [NSMutableDictionary dictionaryWithObject:@"yes" forKey:HCGHaloKeyEnabled];
    [p setObject:@"nexus" forKey:HCGHaloKeyTarget];
    bad.haloPreferences = p;
    HCG_CHECK(![HCGHaloBorderStatus panelBorderOnInPreferences:p], "string 'yes' is not a boolean");
    HCG_CHECK_EQ_INT([HCGHaloBorderStatus statusWithFacts:bad].state, HCGHaloBorderStateDisabled);

    // Halo stopped: Disabled whatever the settings say, and not switchable from Nexus.
    NSArray *stopped = [NSArray arrayWithObjects:@"kill-switch", @"auto-disabled", @"fault", nil];
    for (NSString *engine in stopped) {
        HCGHaloBorderFacts *f = ReadyFacts();
        f.haloStatus = HaloStatus(engine, @"off", nil);
        f.borderAttached = YES;
        f.panelVisible = YES;
        HCGHaloBorderStatus *s = [HCGHaloBorderStatus statusWithFacts:f];
        HCG_CHECK_EQ_INT(s.state, HCGHaloBorderStateDisabled);
        HCG_CHECK(!s.canSwitch, "%s: not switchable", [engine UTF8String]);
        HCG_CHECK(s.switchNote.length > 0, "%s: says how to recover", [engine UTF8String]);
    }
    // Fault: never Ready, and the remedy HCG Halo needs (Enable off and on).
    HCGHaloBorderFacts *fault = ReadyFacts();
    fault.haloStatus = HaloStatus(@"fault", @"off", nil);
    HCGHaloBorderStatus *faulted = [HCGHaloBorderStatus statusWithFacts:fault];
    HCG_CHECK_EQ_INT(faulted.state, HCGHaloBorderStateDisabled);
    HCG_CHECK([faulted.switchNote rangeOfString:@"Enable off and on"].location != NSNotFound, "fault remedy: %s", [faulted.switchNote UTF8String]);

    // Halo 0.2.0~beta1 (no switch API): state is still truthful, the switch points to Halo's settings.
    HCGHaloBorderFacts *older = ReadyFacts();
    older.haloVersion = @"0.2.0~beta1";
    older.controlVersion = 0;
    older.haloPreferences = HaloPrefs(YES, @"screen");
    HCGHaloBorderStatus *s = [HCGHaloBorderStatus statusWithFacts:older];
    HCG_CHECK_EQ_INT(s.state, HCGHaloBorderStateDisabled);
    HCG_CHECK(!s.canSwitch, "0.2.0 has no switch API");
    HCG_CHECK([s.switchNote rangeOfString:@"Border Target"].location != NSNotFound, "points to Halo's own setting");
}

static void testHaloReadyAndActiveFollowThePanel(void) {
    HCGHaloBorderFacts *f = ReadyFacts();
    HCGHaloBorderStatus *s = [HCGHaloBorderStatus statusWithFacts:f];
    HCG_CHECK_EQ_INT(s.state, HCGHaloBorderStateReady);
    HCG_CHECK(s.switchOn && s.canSwitch, "on and switchable");

    // Panel opens and Halo attaches: Active only with both facts, from Nexus's own observation.
    f.panelVisible = YES;
    HCG_CHECK_EQ_INT([HCGHaloBorderStatus statusWithFacts:f].state, HCGHaloBorderStateReady);
    f.borderAttached = YES;
    HCG_CHECK_EQ_INT([HCGHaloBorderStatus statusWithFacts:f].state, HCGHaloBorderStateActive);
    // Closing the panel: back to Ready, never "Active" while nothing is drawn.
    f.panelVisible = NO;
    HCG_CHECK_EQ_INT([HCGHaloBorderStatus statusWithFacts:f].state, HCGHaloBorderStateReady);
    // Attached but Halo's settings say off (e.g. just switched off): Disabled.
    f.panelVisible = YES;
    f.haloPreferences = HaloPrefs(YES, @"screen");
    HCG_CHECK_EQ_INT([HCGHaloBorderStatus statusWithFacts:f].state, HCGHaloBorderStateDisabled);
    // 'both' also counts as on.
    f.haloPreferences = HaloPrefs(YES, @"both");
    HCG_CHECK_EQ_INT([HCGHaloBorderStatus statusWithFacts:f].state, HCGHaloBorderStateActive);
    // Every state has a title.
    for (NSInteger i = HCGHaloBorderStateNotInstalled; i <= HCGHaloBorderStateActive; i++) {
        HCG_CHECK([HCGHaloBorderStatus titleForState:(HCGHaloBorderState)i].length > 0, "title for %ld", (long)i);
    }
    HCG_CHECK_EQ_STR([HCGHaloBorderStatus titleForState:HCGHaloBorderStateActive], @"Active");
}

#pragma mark - HCG Terminal

static HCGTerminalAppFacts *TerminalFacts(HCGTerminalVariant v, BOOL installed, NSString *version, NSInteger handoff, BOOL declaresScheme) {
    HCGTerminalAppFacts *f = [[HCGTerminalAppFacts alloc] init];
    f.variant = v;
    f.installedKnown = YES;
    f.installed = installed;
    f.version = version;
    f.handoffVersion = handoff;
    f.urlSchemes = declaresScheme ? [NSArray arrayWithObject:[HCGTerminalHandoff urlSchemeForVariant:v]] : nil;
    f.canLaunchByBundle = YES;
    return f;
}

static void testTerminalStatesStaySeparate(void) {
    // Today's HCG Terminal 0.1.0: installed and launchable, no handoff, session never "connected".
    HCGTerminalStatus *s = [HCGTerminalHandoff statusWithFacts:TerminalFacts(HCGTerminalVariantStandard, YES, @"0.1.0", 0, NO)];
    HCG_CHECK_EQ_STR(s.installedText, @"Installed · 0.1.0");
    HCG_CHECK(s.launchAvailable, "launch by bundle id");
    HCG_CHECK(!s.integrationAvailable, "0.1.0 has no handoff");
    HCG_CHECK([s.integrationText rangeOfString:@"0.1.0"].location != NSNotFound, "names the version");
    HCG_CHECK([s.sessionText rangeOfString:@"never shows it as connected"].location != NSNotFound, "session never inferred");
    HCG_CHECK([s.sessionText rangeOfString:@"Connected"].location == NSNotFound, "no 'Connected' state");

    // A build with the handoff.
    s = [HCGTerminalHandoff statusWithFacts:TerminalFacts(HCGTerminalVariantStandard, YES, @"0.2.0", 1, YES)];
    HCG_CHECK(s.integrationAvailable, "handoff v1 + scheme");
    // Declares the key but not its own scheme: not available.
    s = [HCGTerminalHandoff statusWithFacts:TerminalFacts(HCGTerminalVariantStandard, YES, @"0.2.0", 1, NO)];
    HCG_CHECK(!s.integrationAvailable, "scheme required");
    // The other variant's scheme does not count.
    HCGTerminalAppFacts *wrong = TerminalFacts(HCGTerminalVariantUnleashed, YES, @"0.2.0", 1, NO);
    wrong.urlSchemes = [NSArray arrayWithObject:@"hcgterminal"];
    HCG_CHECK(![HCGTerminalHandoff statusWithFacts:wrong].integrationAvailable, "Unleashed needs hcgterminal-unleashed");
    // Newer handoff than Nexus knows.
    s = [HCGTerminalHandoff statusWithFacts:TerminalFacts(HCGTerminalVariantStandard, YES, @"0.3.0", 2, YES)];
    HCG_CHECK(!s.integrationAvailable, "v2 not used blindly");
    // Missing companion.
    s = [HCGTerminalHandoff statusWithFacts:TerminalFacts(HCGTerminalVariantUnleashed, NO, nil, 0, NO)];
    HCG_CHECK_EQ_STR(s.installedText, @"Not installed");
    HCG_CHECK(!s.launchAvailable && !s.integrationAvailable, "nothing for a missing app");
    // Sandboxed host: installation unknown, only the link can be tried.
    HCGTerminalAppFacts *sandbox = [[HCGTerminalAppFacts alloc] init];
    sandbox.variant = HCGTerminalVariantStandard;
    s = [HCGTerminalHandoff statusWithFacts:sandbox];
    HCG_CHECK([s.installedText hasPrefix:@"Unable to determine"], "unknown, not 'Not installed'");
    HCG_CHECK(!s.launchAvailable, "no scheme, no launch");
    sandbox.canOpenScheme = YES;
    HCG_CHECK([HCGTerminalHandoff statusWithFacts:sandbox].launchAvailable, "link opens it");
}

static void testTerminalVariantChoice(void) {
    HCGTerminalAppFacts *std = TerminalFacts(HCGTerminalVariantStandard, YES, @"0.1.0", 0, NO);
    HCGTerminalAppFacts *unl = TerminalFacts(HCGTerminalVariantUnleashed, YES, @"0.1.0", 0, NO);
    HCGTerminalAppFacts *stdMissing = TerminalFacts(HCGTerminalVariantStandard, NO, nil, 0, NO);
    HCGTerminalAppFacts *unlMissing = TerminalFacts(HCGTerminalVariantUnleashed, NO, nil, 0, NO);
    HCG_CHECK_EQ_INT([HCGTerminalHandoff variantToUseWithStandard:std unleashed:unlMissing preferred:HCGTerminalVariantUnleashed], HCGTerminalVariantStandard);
    HCG_CHECK_EQ_INT([HCGTerminalHandoff variantToUseWithStandard:stdMissing unleashed:unl preferred:HCGTerminalVariantNone], HCGTerminalVariantUnleashed);
    HCG_CHECK_EQ_INT([HCGTerminalHandoff variantToUseWithStandard:std unleashed:unl preferred:HCGTerminalVariantUnleashed], HCGTerminalVariantUnleashed);
    HCG_CHECK_EQ_INT([HCGTerminalHandoff variantToUseWithStandard:std unleashed:unl preferred:HCGTerminalVariantNone], HCGTerminalVariantStandard);
    HCG_CHECK_EQ_INT([HCGTerminalHandoff variantToUseWithStandard:stdMissing unleashed:unlMissing preferred:HCGTerminalVariantStandard], HCGTerminalVariantNone);
    HCG_CHECK_EQ_STR([HCGTerminalHandoff bundleIdentifierForVariant:HCGTerminalVariantUnleashed], @"com.hakmicapitalgroup.hcgterminal.unleashed");
    HCG_CHECK_EQ_INT([HCGTerminalHandoff variantForBundleIdentifier:@"com.hakmicapitalgroup.hcgterminal"], HCGTerminalVariantStandard);
    HCG_CHECK_EQ_STR([[HCGTerminalHandoff openURLForVariant:HCGTerminalVariantUnleashed] absoluteString], @"hcgterminal-unleashed://open");
    HCG_CHECK([HCGTerminalHandoff openURLForVariant:HCGTerminalVariantNone] == nil, "no URL without a variant");
}

static void testTerminalLinksCannotCarryCommands(void) {
    NSString *uuid = @"0F8FAD5B-D9CB-469F-A165-70867728950E";
    HCGTerminalVariant v = HCGTerminalVariantNone;
    NSString *reason = nil;
    NSString *ok = [HCGTerminalHandoff validatedConnectionLink:[@"hcgterminal://connection?id=" stringByAppendingString:uuid] variant:&v reason:&reason];
    HCG_CHECK(ok != nil, "standard link accepted");
    HCG_CHECK_EQ_INT(v, HCGTerminalVariantStandard);
    ok = [HCGTerminalHandoff validatedConnectionLink:[@"hcgterminal-unleashed://connection?id=" stringByAppendingString:[uuid lowercaseString]] variant:&v reason:&reason];
    HCG_CHECK(ok != nil, "Unleashed link accepted (lowercase UUID)");
    HCG_CHECK_EQ_INT(v, HCGTerminalVariantUnleashed);

    NSArray *bad = [NSArray arrayWithObjects:
        @"",
        @"hcgterminal://connection?id=",
        @"hcgterminal://connection?id=not-a-uuid",
        [NSString stringWithFormat:@"hcgterminal://connection?id=%@&command=rm%%20-rf", uuid],
        [NSString stringWithFormat:@"hcgterminal://connection?id=%@&run=1", uuid],
        [NSString stringWithFormat:@"hcgterminal://connection?id=%@&id=%@", uuid, uuid],
        [NSString stringWithFormat:@"hcgterminal://connection?id=%@#frag", uuid],
        [NSString stringWithFormat:@"hcgterminal://connection/x?id=%@", uuid],
        [NSString stringWithFormat:@"hcgterminal://user@connection?id=%@", uuid],
        [NSString stringWithFormat:@"hcgterminal://connection:22?id=%@", uuid],
        [NSString stringWithFormat:@"hcgterminal://exec?id=%@", uuid],
        [NSString stringWithFormat:@"HCGTERMINAL://connection?id=%@", uuid],
        [NSString stringWithFormat:@"https://connection?id=%@", uuid],
        [NSString stringWithFormat:@"hcgterminalx://connection?id=%@", uuid],
        [NSString stringWithFormat:@" hcgterminal://connection?id=%@", uuid],
        [NSString stringWithFormat:@"hcgterminal://connection?id=%@ ", uuid],
        [NSString stringWithFormat:@"hcgterminal://connection?id=%@%@", uuid, [@"" stringByPaddingToLength:260 withString:@"a" startingAtIndex:0]],
        nil];
    for (NSString *text in bad) {
        reason = nil;
        HCG_CHECK([HCGTerminalHandoff validatedConnectionLink:text variant:&v reason:&reason] == nil, "rejected: %s", [text UTF8String]);
        HCG_CHECK(reason.length > 0, "explains: %s", [text UTF8String]);
        HCG_CHECK_EQ_INT(v, HCGTerminalVariantNone);
    }

    // As workspace shortcuts: the same rules, plus <scheme>://open.
    NSError *error = nil;
    HCG_CHECK([HCGAction validationErrorForKind:HCGActionKindURL title:@"Terminal" target:@"hcgterminal://open"] == nil, "open link allowed");
    HCG_CHECK([HCGAction validationErrorForKind:HCGActionKindURL title:@"Mac" target:[@"hcgterminal://connection?id=" stringByAppendingString:uuid]] == nil, "saved connection allowed");
    error = [HCGAction validationErrorForKind:HCGActionKindURL title:@"Bad" target:@"hcgterminal://run?command=ls"];
    HCG_CHECK(error != nil, "command link refused as a shortcut");
    error = [HCGAction validationErrorForKind:HCGActionKindURL title:@"Bad" target:@"hcgterminal-unleashed://open?x=1"];
    HCG_CHECK(error != nil, "extra parameters refused");
}

void HCGRunCompanionTests(void) {
    testHaloMissingAndIncompatible();
    testHaloDisabledStates();
    testHaloReadyAndActiveFollowThePanel();
    testTerminalStatesStaySeparate();
    testTerminalVariantChoice();
    testTerminalLinksCannotCarryCommands();
}
