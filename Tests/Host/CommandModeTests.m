#import "HCGTestHarness.h"
#import "HCGCore.h"

// Command Mode status mapping (Sources/Core/HCGCommandMode). Every display
// state, every device field and missing/unknown/out-of-range input.

@interface HCGCommandModeProbe : NSObject <HCGAppInstallationProbe> {
    NSSet *_installed;
    BOOL _canDetermine;
    BOOL _canLaunch;
}
- (instancetype)initWithInstalled:(NSSet *)installed canDetermine:(BOOL)canDetermine canLaunch:(BOOL)canLaunch;
@end

@implementation HCGCommandModeProbe
- (instancetype)initWithInstalled:(NSSet *)installed canDetermine:(BOOL)canDetermine canLaunch:(BOOL)canLaunch {
    if ((self = [super init])) { _installed = [installed copy]; _canDetermine = canDetermine; _canLaunch = canLaunch; }
    return self;
}
- (BOOL)canLaunchApplicationsByBundleIdentifier { return _canLaunch; }
- (BOOL)canDetermineInstallation { return _canDetermine; }
- (BOOL)isApplicationInstalled:(NSString *)bundleIdentifier { return [_installed containsObject:bundleIdentifier]; }
@end

// Nothing Command Mode shows may claim live activity that is not measured.
static void CheckNoImpliedActivity(HCGStatusDisplay *display) {
    NSArray *words = [NSArray arrayWithObjects:@"online", @"syncing", @"synced", @"live", @"streaming", nil];
    NSString *text = [[NSString stringWithFormat:@"%@ %@", display.value, display.detail] lowercaseString];
    NSUInteger i;
    for (i = 0; i < words.count; i++) {
        HCG_CHECK([text rangeOfString:[words objectAtIndex:i]].location == NSNotFound, "'%s' implies activity: %s",
                  [[words objectAtIndex:i] UTF8String], [text UTF8String]);
    }
    HCG_CHECK(display.title.length > 0 && display.value.length > 0 && display.detail.length > 0 && display.symbolName.length > 0,
              "display fields filled for %s", [display.title UTF8String]);
    HCG_CHECK([[display accessibilityText] rangeOfString:display.value].location != NSNotFound, "accessibility text carries the value");
}

static HCGIntegrationStatus *ReadyStatus(HCGIntegrationReachability reach, HCGIntegrationSession session) {
    HCGIntegrationStatus *s = [[HCGIntegrationStatus alloc] init];
    s.identifier = HCGIntegrationTerminal;
    s.displayName = @"HCG Terminal";
    s.recognized = YES;
    s.contractAvailable = YES;
    s.configured = YES;
    s.state = HCGIntegrationStateReady;
    s.reachability = reach;
    s.session = session;
    return s;
}

static HCGConnectionDisplayState Map(HCGIntegrationStatus *status) {
    HCGStatusDisplay *display = [HCGCommandModeStatus displayForIntegrationStatus:status];
    HCGConnectionDisplayState state = [HCGCommandModeStatus connectionStateForIntegrationStatus:status];
    HCG_CHECK_EQ_INT(display.connectionState, state);
    HCG_CHECK_EQ_STR(display.value, [HCGCommandModeStatus labelForConnectionState:state]);
    HCG_CHECK_EQ_INT(display.colorRole, [HCGCommandModeStatus colorRoleForConnectionState:state]);
    CheckNoImpliedActivity(display);
    return state;
}

static void testConnectionStatesAreDistinct(void) {
    NSMutableSet *labels = [[NSMutableSet alloc] init];
    NSMutableSet *symbols = [[NSMutableSet alloc] init];
    NSInteger state;
    for (state = HCGConnectionDisplayStateUnknown; state <= HCGConnectionDisplayStateConnected; state++) {
        NSString *label = [HCGCommandModeStatus labelForConnectionState:(HCGConnectionDisplayState)state];
        HCG_CHECK(label.length > 0, "label for state %ld", (long)state);
        [labels addObject:label];
        [symbols addObject:[HCGCommandModeStatus symbolNameForConnectionState:(HCGConnectionDisplayState)state]];
    }
    HCG_CHECK_EQ_INT(labels.count, 6);
    HCG_CHECK_EQ_INT(symbols.count, 6);
    HCG_CHECK_EQ_STR([HCGCommandModeStatus labelForConnectionState:HCGConnectionDisplayStateUnknown], @"Unknown");
    HCG_CHECK_EQ_STR([HCGCommandModeStatus labelForConnectionState:HCGConnectionDisplayStateUnavailable], @"Unavailable");
    HCG_CHECK_EQ_STR([HCGCommandModeStatus labelForConnectionState:HCGConnectionDisplayStateOff], @"Off");
    HCG_CHECK_EQ_STR([HCGCommandModeStatus labelForConnectionState:HCGConnectionDisplayStateDisconnected], @"Disconnected");
    HCG_CHECK_EQ_STR([HCGCommandModeStatus labelForConnectionState:HCGConnectionDisplayStateSignedOut], @"Signed out");
    HCG_CHECK_EQ_STR([HCGCommandModeStatus labelForConnectionState:HCGConnectionDisplayStateConnected], @"Connected");
    // Colour roles: only Connected is positive; attention states are caution.
    HCG_CHECK_EQ_INT([HCGCommandModeStatus colorRoleForConnectionState:HCGConnectionDisplayStateConnected], HCGStatusColorRolePositive);
    HCG_CHECK_EQ_INT([HCGCommandModeStatus colorRoleForConnectionState:HCGConnectionDisplayStateDisconnected], HCGStatusColorRoleCaution);
    HCG_CHECK_EQ_INT([HCGCommandModeStatus colorRoleForConnectionState:HCGConnectionDisplayStateSignedOut], HCGStatusColorRoleCaution);
    HCG_CHECK_EQ_INT([HCGCommandModeStatus colorRoleForConnectionState:HCGConnectionDisplayStateUnavailable], HCGStatusColorRoleMuted);
    HCG_CHECK_EQ_INT([HCGCommandModeStatus colorRoleForConnectionState:HCGConnectionDisplayStateOff], HCGStatusColorRoleMuted);
    HCG_CHECK_EQ_INT([HCGCommandModeStatus colorRoleForConnectionState:HCGConnectionDisplayStateUnknown], HCGStatusColorRoleNeutral);
    // Out-of-range values fall back to Unknown, never to Connected.
    HCG_CHECK_EQ_STR([HCGCommandModeStatus labelForConnectionState:(HCGConnectionDisplayState)99], @"Unknown");
    HCG_CHECK_EQ_STR([HCGCommandModeStatus labelForConnectionState:(HCGConnectionDisplayState)-1], @"Unknown");
    HCG_CHECK_EQ_INT([HCGCommandModeStatus colorRoleForConnectionState:(HCGConnectionDisplayState)99], HCGStatusColorRoleNeutral);
}

// Real statuses from the catalog, as the panel produces them.
static void testCatalogStatusesMapToDisplayStates(void) {
    NSSet *installed = [NSSet setWithObjects:HCGTerminalBundleIdentifier, nil];
    HCGCommandModeProbe *device = [[HCGCommandModeProbe alloc] initWithInstalled:installed canDetermine:YES canLaunch:YES];
    HCGCommandModeProbe *sandboxed = [[HCGCommandModeProbe alloc] initWithInstalled:[NSSet set] canDetermine:NO canLaunch:NO];
    HCGSettings *off = [HCGSettings defaultSettings];
    HCGSettings *on = [HCGSettings defaultSettings];
    on.terminalVariant = HCGTerminalVariantStandard;
    on.newsConnected = YES;

    // Not turned on → Off (not "Disconnected": nothing is configured).
    HCGIntegrationStatus *t = [HCGIntegrationCatalog statusForIdentifier:HCGIntegrationTerminal settings:off probe:device];
    HCG_CHECK(t.recognized && t.contractAvailable && !t.configured, "terminal off: recognised, has contract, not configured");
    HCG_CHECK_EQ_INT(Map(t), HCGConnectionDisplayStateOff);
    HCG_CHECK_EQ_INT(Map([HCGIntegrationCatalog statusForIdentifier:HCGIntegrationNews settings:off probe:device]), HCGConnectionDisplayStateOff);

    // Turned on and installed → Launch available (app link). Never "Connected": opening an app proves no session.
    t = [HCGIntegrationCatalog statusForIdentifier:HCGIntegrationTerminal settings:on probe:device];
    HCG_CHECK(t.configured, "terminal configured");
    HCG_CHECK_EQ_INT(t.reachability, HCGIntegrationReachabilityNotApplicable);
    HCG_CHECK_EQ_INT(t.session, HCGIntegrationSessionNotApplicable);
    HCG_CHECK_EQ_INT(Map(t), HCGConnectionDisplayStateLaunchAvailable);
    HCGStatusDisplay *d = [HCGCommandModeStatus displayForIntegrationStatus:t];
    HCG_CHECK_EQ_STR(d.value, @"Launch available");
    HCG_CHECK([d.detail rangeOfString:@"No session or sync status"].location != NSNotFound, "connected app link says no session is visible: %s", [d.detail UTF8String]);
    HCG_CHECK_EQ_STR(d.title, @"HCG Terminal");

    // Turned on, app missing → Unavailable.
    HCGIntegrationStatus *n = [HCGIntegrationCatalog statusForIdentifier:HCGIntegrationNews settings:on probe:device];
    HCG_CHECK_EQ_INT(Map(n), HCGConnectionDisplayStateUnavailable);
    HCG_CHECK([[HCGCommandModeStatus displayForIntegrationStatus:n].detail rangeOfString:@"not installed"].location != NSNotFound, "missing app explained");

    // Installation cannot be checked → Unknown, not Connected.
    HCG_CHECK_EQ_INT(Map([HCGIntegrationCatalog statusForIdentifier:HCGIntegrationNews settings:on probe:nil]), HCGConnectionDisplayStateUnknown);
    HCGCommandModeProbe *unchecked = [[HCGCommandModeProbe alloc] initWithInstalled:[NSSet set] canDetermine:NO canLaunch:YES];
    HCG_CHECK_EQ_INT(Map([HCGIntegrationCatalog statusForIdentifier:HCGIntegrationTerminal settings:on probe:unchecked]), HCGConnectionDisplayStateUnknown);

    // Sandboxed standalone app → Unavailable (needs the jailbreak package).
    HCGIntegrationStatus *sb = [HCGIntegrationCatalog statusForIdentifier:HCGIntegrationTerminal settings:on probe:sandboxed];
    HCG_CHECK_EQ_INT(Map(sb), HCGConnectionDisplayStateUnavailable);
    HCG_CHECK([[HCGCommandModeStatus displayForIntegrationStatus:sb].detail rangeOfString:@"jailbreak package"].location != NSNotFound, "explains why");
    // ...but an unconfigured one in the app is still Off.
    HCG_CHECK_EQ_INT(Map([HCGIntegrationCatalog statusForIdentifier:HCGIntegrationNews settings:off probe:sandboxed]), HCGConnectionDisplayStateOff);

    // No phone-reachable contract → Unavailable, whatever the settings say.
    HCGIntegrationStatus *server = [HCGIntegrationCatalog statusForIdentifier:HCGIntegrationServer settings:on probe:device];
    HCGIntegrationStatus *maker = [HCGIntegrationCatalog statusForIdentifier:HCGIntegrationExecutableMaker settings:on probe:device];
    HCG_CHECK(server.recognized && !server.contractAvailable, "server recognised, no contract");
    HCG_CHECK_EQ_INT(Map(server), HCGConnectionDisplayStateUnavailable);
    HCG_CHECK_EQ_INT(Map(maker), HCGConnectionDisplayStateUnavailable);

    // Unrecognised identifier (e.g. a corrupt shortcut) → Unknown.
    HCGIntegrationStatus *bogus = [HCGIntegrationCatalog statusForIdentifier:@"erp-admin" settings:on probe:device];
    HCG_CHECK(!bogus.recognized, "unknown identifier not recognised");
    HCG_CHECK_EQ_INT(Map(bogus), HCGConnectionDisplayStateUnknown);

    // The existing launch rules are unchanged by the new fields.
    HCG_CHECK(t.canLaunch && !n.canLaunch && !sb.canLaunch && !server.canLaunch, "canLaunch unchanged");
}

// States no shipped integration produces yet (no contract publishes them),
// mapped from explicit values so a future contract cannot be misreported.
static void testReachabilityAndSessionStates(void) {
    HCG_CHECK_EQ_INT(Map(ReadyStatus(HCGIntegrationReachabilityUnreachable, HCGIntegrationSessionSignedIn)), HCGConnectionDisplayStateDisconnected);
    // Unreachable wins over signed out: the session cannot be known.
    HCG_CHECK_EQ_INT(Map(ReadyStatus(HCGIntegrationReachabilityUnreachable, HCGIntegrationSessionSignedOut)), HCGConnectionDisplayStateDisconnected);
    HCG_CHECK_EQ_INT(Map(ReadyStatus(HCGIntegrationReachabilityReachable, HCGIntegrationSessionSignedOut)), HCGConnectionDisplayStateSignedOut);
    HCG_CHECK_EQ_INT(Map(ReadyStatus(HCGIntegrationReachabilityNotApplicable, HCGIntegrationSessionSignedOut)), HCGConnectionDisplayStateSignedOut);
    HCG_CHECK_EQ_INT(Map(ReadyStatus(HCGIntegrationReachabilityReachable, HCGIntegrationSessionSignedIn)), HCGConnectionDisplayStateConnected);
    HCG_CHECK_EQ_INT(Map(ReadyStatus(HCGIntegrationReachabilityReachable, HCGIntegrationSessionNotApplicable)), HCGConnectionDisplayStateConnected);
    // An app link (no service, no session): Launch available, never Connected.
    HCG_CHECK_EQ_INT(Map(ReadyStatus(HCGIntegrationReachabilityNotApplicable, HCGIntegrationSessionNotApplicable)), HCGConnectionDisplayStateLaunchAvailable);
    HCG_CHECK_EQ_STR([HCGCommandModeStatus labelForConnectionState:HCGConnectionDisplayStateLaunchAvailable], @"Launch available");
    HCG_CHECK([HCGCommandModeStatus colorRoleForConnectionState:HCGConnectionDisplayStateLaunchAvailable] != HCGStatusColorRolePositive,
              "launch available is not shown in the 'connected' colour");
    // Not reported → Unknown, never Connected.
    HCG_CHECK_EQ_INT(Map(ReadyStatus(HCGIntegrationReachabilityUnknown, HCGIntegrationSessionSignedIn)), HCGConnectionDisplayStateUnknown);
    HCG_CHECK_EQ_INT(Map(ReadyStatus(HCGIntegrationReachabilityReachable, HCGIntegrationSessionUnknown)), HCGConnectionDisplayStateUnknown);
    HCG_CHECK_EQ_INT(Map(ReadyStatus((HCGIntegrationReachability)42, HCGIntegrationSessionSignedIn)), HCGConnectionDisplayStateUnknown);
    HCG_CHECK_EQ_INT(Map(ReadyStatus(HCGIntegrationReachabilityReachable, (HCGIntegrationSession)42)), HCGConnectionDisplayStateUnknown);
    HCGStatusDisplay *signedOut = [HCGCommandModeStatus displayForIntegrationStatus:ReadyStatus(HCGIntegrationReachabilityReachable, HCGIntegrationSessionSignedOut)];
    HCG_CHECK([signedOut.detail rangeOfString:@"sign in"].location != NSNotFound, "signed out explains sign-in: %s", [signedOut.detail UTF8String]);
}

static void testMissingAndInconsistentIntegrationData(void) {
    // No status at all.
    HCG_CHECK_EQ_INT(Map(nil), HCGConnectionDisplayStateUnknown);
    HCG_CHECK_EQ_STR([HCGCommandModeStatus displayForIntegrationStatus:nil].title, @"Integration");
    // A freshly allocated status (nothing filled in) is Unknown.
    HCGIntegrationStatus *blank = [[HCGIntegrationStatus alloc] init];
    HCG_CHECK_EQ_INT(Map(blank), HCGConnectionDisplayStateUnknown);
    // Default reachability/session (not filled in) never reads as connected.
    HCGIntegrationStatus *defaults = ReadyStatus(HCGIntegrationReachabilityUnknown, HCGIntegrationSessionUnknown);
    HCGIntegrationStatus *fresh = [[HCGIntegrationStatus alloc] init];
    HCG_CHECK_EQ_INT(fresh.reachability, HCGIntegrationReachabilityUnknown);
    HCG_CHECK_EQ_INT(fresh.session, HCGIntegrationSessionUnknown);
    HCG_CHECK_EQ_INT(Map(defaults), HCGConnectionDisplayStateUnknown);
    // Configured but the model says NotConnected, or an out-of-range state.
    HCGIntegrationStatus *odd = ReadyStatus(HCGIntegrationReachabilityNotApplicable, HCGIntegrationSessionNotApplicable);
    odd.state = HCGIntegrationStateNotConnected;
    HCG_CHECK_EQ_INT(Map(odd), HCGConnectionDisplayStateUnknown);
    odd.state = (HCGIntegrationState)42;
    HCG_CHECK_EQ_INT(Map(odd), HCGConnectionDisplayStateUnknown);
}

static HCGDeviceStatusSnapshot *Battery(double level, HCGBatteryChargeState state) {
    HCGDeviceStatusSnapshot *s = [HCGDeviceStatusSnapshot unavailableSnapshot];
    s.batteryLevel = level;
    s.batteryState = state;
    return s;
}

static void testBatteryDisplay(void) {
    HCGStatusDisplay *d = [HCGCommandModeStatus batteryDisplayForSnapshot:Battery(-1, HCGBatteryChargeStateUnknown)];
    HCG_CHECK_EQ_STR(d.value, @"Unavailable");
    HCG_CHECK_EQ_INT(d.colorRole, HCGStatusColorRoleMuted);
    CheckNoImpliedActivity(d);
    HCG_CHECK_EQ_STR([HCGCommandModeStatus batteryDisplayForSnapshot:nil].value, @"Unavailable");
    HCG_CHECK_EQ_STR([HCGCommandModeStatus batteryDisplayForSnapshot:Battery(NAN, HCGBatteryChargeStateUnplugged)].value, @"Unavailable");
    HCG_CHECK_EQ_STR([HCGCommandModeStatus batteryDisplayForSnapshot:Battery(1.7, HCGBatteryChargeStateUnplugged)].value, @"Unavailable");

    d = [HCGCommandModeStatus batteryDisplayForSnapshot:Battery(0.82, HCGBatteryChargeStateUnplugged)];
    HCG_CHECK_EQ_STR(d.value, @"82%");
    HCG_CHECK_EQ_STR(d.detail, @"On battery");
    HCG_CHECK_EQ_INT(d.colorRole, HCGStatusColorRoleNeutral);
    CheckNoImpliedActivity(d);
    HCG_CHECK_EQ_INT([HCGCommandModeStatus batteryDisplayForSnapshot:Battery(0.15, HCGBatteryChargeStateUnplugged)].colorRole, HCGStatusColorRoleCaution);
    HCG_CHECK_EQ_INT([HCGCommandModeStatus batteryDisplayForSnapshot:Battery(0.05, HCGBatteryChargeStateUnplugged)].colorRole, HCGStatusColorRoleCritical);
    d = [HCGCommandModeStatus batteryDisplayForSnapshot:Battery(0.0, HCGBatteryChargeStateUnplugged)];
    HCG_CHECK_EQ_STR(d.value, @"0%");
    HCG_CHECK_EQ_INT(d.colorRole, HCGStatusColorRoleCritical);

    d = [HCGCommandModeStatus batteryDisplayForSnapshot:Battery(0.05, HCGBatteryChargeStateCharging)];
    HCG_CHECK_EQ_STR(d.value, @"5%");
    HCG_CHECK_EQ_STR(d.detail, @"Charging");
    HCG_CHECK_EQ_INT(d.colorRole, HCGStatusColorRolePositive);
    HCG_CHECK_EQ_STR(d.symbolName, @"battery.100.bolt");
    d = [HCGCommandModeStatus batteryDisplayForSnapshot:Battery(1.0, HCGBatteryChargeStateFull)];
    HCG_CHECK_EQ_STR(d.value, @"100%");
    HCG_CHECK_EQ_INT(d.colorRole, HCGStatusColorRolePositive);
    // Charging is real even when the level is not reported.
    d = [HCGCommandModeStatus batteryDisplayForSnapshot:Battery(-1, HCGBatteryChargeStateCharging)];
    HCG_CHECK_EQ_STR(d.value, @"Unavailable");
    HCG_CHECK_EQ_STR(d.detail, @"Charging");
    // Level known, state unknown or out of range.
    d = [HCGCommandModeStatus batteryDisplayForSnapshot:Battery(0.5, HCGBatteryChargeStateUnknown)];
    HCG_CHECK_EQ_STR(d.value, @"50%");
    HCG_CHECK_EQ_STR(d.detail, @"Charging state unavailable");
    d = [HCGCommandModeStatus batteryDisplayForSnapshot:Battery(0.5, (HCGBatteryChargeState)9)];
    HCG_CHECK_EQ_STR(d.detail, @"Charging state unavailable");
    HCG_CHECK_EQ_INT(d.colorRole, HCGStatusColorRoleNeutral);
}

static void testLowPowerDisplay(void) {
    HCGDeviceStatusSnapshot *s = [HCGDeviceStatusSnapshot unavailableSnapshot];
    HCG_CHECK_EQ_STR([HCGCommandModeStatus lowPowerDisplayForSnapshot:s].value, @"Unavailable");
    HCG_CHECK_EQ_STR([HCGCommandModeStatus lowPowerDisplayForSnapshot:nil].value, @"Unavailable");
    s.lowPowerMode = HCGLowPowerModeStateOn;
    HCGStatusDisplay *d = [HCGCommandModeStatus lowPowerDisplayForSnapshot:s];
    HCG_CHECK_EQ_STR(d.value, @"On");
    HCG_CHECK_EQ_INT(d.colorRole, HCGStatusColorRoleCaution);
    CheckNoImpliedActivity(d);
    s.lowPowerMode = HCGLowPowerModeStateOff;
    d = [HCGCommandModeStatus lowPowerDisplayForSnapshot:s];
    HCG_CHECK_EQ_STR(d.value, @"Off");
    HCG_CHECK_EQ_INT(d.colorRole, HCGStatusColorRoleNeutral);
    s.lowPowerMode = (HCGLowPowerModeState)7;
    HCG_CHECK_EQ_STR([HCGCommandModeStatus lowPowerDisplayForSnapshot:s].value, @"Unavailable");
}

static HCGDeviceStatusSnapshot *Network(HCGNetworkPathStatus status, HCGNetworkInterfaceKind kind) {
    HCGDeviceStatusSnapshot *s = [HCGDeviceStatusSnapshot unavailableSnapshot];
    s.networkStatus = status;
    s.networkInterface = kind;
    return s;
}

static void testNetworkDisplay(void) {
    HCGStatusDisplay *d = [HCGCommandModeStatus networkDisplayForSnapshot:Network(HCGNetworkPathStatusSatisfied, HCGNetworkInterfaceKindWiFi)];
    HCG_CHECK_EQ_STR(d.value, @"Wi-Fi");
    HCG_CHECK_EQ_INT(d.colorRole, HCGStatusColorRoleNeutral); // a route, not a verified service
    HCG_CHECK([d.detail rangeOfString:@"network path"].location != NSNotFound, "says it is a path, not an internet check");
    CheckNoImpliedActivity(d);
    HCG_CHECK_EQ_STR([HCGCommandModeStatus networkDisplayForSnapshot:Network(HCGNetworkPathStatusSatisfied, HCGNetworkInterfaceKindCellular)].value, @"Cellular");
    HCG_CHECK_EQ_STR([HCGCommandModeStatus networkDisplayForSnapshot:Network(HCGNetworkPathStatusSatisfied, HCGNetworkInterfaceKindWired)].value, @"Wired");
    HCG_CHECK_EQ_STR([HCGCommandModeStatus networkDisplayForSnapshot:Network(HCGNetworkPathStatusSatisfied, HCGNetworkInterfaceKindOther)].value, @"Other network");
    HCG_CHECK_EQ_STR([HCGCommandModeStatus networkDisplayForSnapshot:Network(HCGNetworkPathStatusSatisfied, HCGNetworkInterfaceKindNone)].value, @"Available");
    HCGDeviceStatusSnapshot *lowData = Network(HCGNetworkPathStatusSatisfied, HCGNetworkInterfaceKindCellular);
    lowData.networkConstrained = YES;
    lowData.networkExpensive = YES;
    HCG_CHECK([[HCGCommandModeStatus networkDisplayForSnapshot:lowData].detail rangeOfString:@"Low Data Mode"].location != NSNotFound, "low data mode shown");
    lowData.networkConstrained = NO;
    HCG_CHECK([[HCGCommandModeStatus networkDisplayForSnapshot:lowData].detail rangeOfString:@"metered"].location != NSNotFound, "metered shown");

    d = [HCGCommandModeStatus networkDisplayForSnapshot:Network(HCGNetworkPathStatusUnsatisfied, HCGNetworkInterfaceKindNone)];
    HCG_CHECK_EQ_STR(d.value, @"No connection");
    HCG_CHECK_EQ_INT(d.colorRole, HCGStatusColorRoleCaution);
    d = [HCGCommandModeStatus networkDisplayForSnapshot:Network(HCGNetworkPathStatusRequiresConnection, HCGNetworkInterfaceKindNone)];
    HCG_CHECK_EQ_STR(d.value, @"Not connected yet");
    CheckNoImpliedActivity(d);
    d = [HCGCommandModeStatus networkDisplayForSnapshot:Network(HCGNetworkPathStatusUnknown, HCGNetworkInterfaceKindWiFi)];
    HCG_CHECK_EQ_STR(d.value, @"Unknown"); // interface is ignored until a path is reported
    d = [HCGCommandModeStatus networkDisplayForSnapshot:Network(HCGNetworkPathStatusUnavailable, HCGNetworkInterfaceKindNone)];
    HCG_CHECK_EQ_STR(d.value, @"Unavailable");
    HCG_CHECK_EQ_INT(d.colorRole, HCGStatusColorRoleMuted);
    HCG_CHECK_EQ_STR([HCGCommandModeStatus networkDisplayForSnapshot:nil].value, @"Unavailable");
    HCG_CHECK_EQ_STR([HCGCommandModeStatus networkDisplayForSnapshot:Network((HCGNetworkPathStatus)77, HCGNetworkInterfaceKindWiFi)].value, @"Unavailable");
}

static void testStorageDisplayAndFormatting(void) {
    HCGDeviceStatusSnapshot *s = [HCGDeviceStatusSnapshot unavailableSnapshot];
    HCGStatusDisplay *d = [HCGCommandModeStatus storageDisplayForSnapshot:s];
    HCG_CHECK_EQ_STR(d.value, @"Unavailable");
    HCG_CHECK_EQ_INT(d.colorRole, HCGStatusColorRoleMuted);
    HCG_CHECK_EQ_STR([HCGCommandModeStatus storageDisplayForSnapshot:nil].value, @"Unavailable");

    s.storageAvailableBytes = 64200000000LL;
    s.storageTotalBytes = 128000000000LL;
    d = [HCGCommandModeStatus storageDisplayForSnapshot:s];
    HCG_CHECK_EQ_STR(d.value, @"64.2 GB");
    HCG_CHECK_EQ_STR(d.detail, @"available of 128 GB");
    HCG_CHECK_EQ_INT(d.colorRole, HCGStatusColorRoleNeutral);
    CheckNoImpliedActivity(d);
    s.storageTotalBytes = -1;
    HCG_CHECK([[HCGCommandModeStatus storageDisplayForSnapshot:s].detail rangeOfString:@"total capacity unavailable"].location != NSNotFound, "total missing");
    s.storageAvailableBytes = 3000000000LL;
    HCG_CHECK_EQ_INT([HCGCommandModeStatus storageDisplayForSnapshot:s].colorRole, HCGStatusColorRoleCaution);
    s.storageAvailableBytes = 500000000LL;
    d = [HCGCommandModeStatus storageDisplayForSnapshot:s];
    HCG_CHECK_EQ_STR(d.value, @"500 MB");
    HCG_CHECK_EQ_INT(d.colorRole, HCGStatusColorRoleCritical);
    s.storageAvailableBytes = 0;
    HCG_CHECK_EQ_STR([HCGCommandModeStatus storageDisplayForSnapshot:s].value, @"0 bytes");

    HCG_CHECK([HCGCommandModeStatus formattedByteCount:-5] == nil, "negative is unavailable");
    HCG_CHECK_EQ_STR([HCGCommandModeStatus formattedByteCount:999], @"999 bytes");
    HCG_CHECK_EQ_STR([HCGCommandModeStatus formattedByteCount:1000], @"1.0 KB");
    HCG_CHECK_EQ_STR([HCGCommandModeStatus formattedByteCount:999950], @"1.0 MB");
    HCG_CHECK_EQ_STR([HCGCommandModeStatus formattedByteCount:12345678], @"12.3 MB");
    HCG_CHECK_EQ_STR([HCGCommandModeStatus formattedByteCount:2000000000000LL], @"2.0 TB");
}

static void testUnavailableSnapshotShowsNoValues(void) {
    HCGDeviceStatusSnapshot *s = [HCGDeviceStatusSnapshot unavailableSnapshot];
    NSArray *displays = [HCGCommandModeStatus deviceDisplaysForSnapshot:s];
    HCG_CHECK_EQ_INT(displays.count, 4);
    HCG_CHECK_EQ_STR([[displays objectAtIndex:0] value], @"Unavailable"); // battery
    HCG_CHECK_EQ_STR([[displays objectAtIndex:1] value], @"Unavailable"); // low power
    HCG_CHECK_EQ_STR([[displays objectAtIndex:2] value], @"Unknown");     // network: no update yet
    HCG_CHECK_EQ_STR([[displays objectAtIndex:3] value], @"Unavailable"); // storage
    NSUInteger i;
    for (i = 0; i < displays.count; i++) CheckNoImpliedActivity([displays objectAtIndex:i]);
    NSArray *none = [HCGCommandModeStatus deviceDisplaysForSnapshot:nil];
    HCG_CHECK_EQ_INT(none.count, 4);
    HCG_CHECK_EQ_STR([[none objectAtIndex:2] value], @"Unavailable");

    // Copies keep every field.
    s.batteryLevel = 0.4;
    s.batteryState = HCGBatteryChargeStateCharging;
    s.lowPowerMode = HCGLowPowerModeStateOn;
    s.networkStatus = HCGNetworkPathStatusSatisfied;
    s.networkInterface = HCGNetworkInterfaceKindWired;
    s.networkConstrained = YES;
    s.networkExpensive = YES;
    s.storageAvailableBytes = 42;
    s.storageTotalBytes = 84;
    HCGDeviceStatusSnapshot *c = [s copy];
    HCG_CHECK(c.batteryLevel == 0.4 && c.batteryState == HCGBatteryChargeStateCharging && c.lowPowerMode == HCGLowPowerModeStateOn &&
              c.networkStatus == HCGNetworkPathStatusSatisfied && c.networkInterface == HCGNetworkInterfaceKindWired &&
              c.networkConstrained && c.networkExpensive && c.storageAvailableBytes == 42 && c.storageTotalBytes == 84, "copy keeps fields");
}

static void testPresentationPolicy(void) {
    double normal = [HCGCommandModeStatus scrimAlphaReducingTransparency:NO increaseContrast:NO];
    double contrast = [HCGCommandModeStatus scrimAlphaReducingTransparency:NO increaseContrast:YES];
    double solid = [HCGCommandModeStatus scrimAlphaReducingTransparency:YES increaseContrast:NO];
    HCG_CHECK(normal >= 0.25 && normal <= 0.35, "restrained dim: %.2f", normal);
    HCG_CHECK(contrast >= normal && contrast <= 0.35, "increase contrast dims a little more: %.2f", contrast);
    HCG_CHECK(solid >= 0.9, "reduce transparency is nearly opaque: %.2f", solid);
    HCG_CHECK([HCGCommandModeStatus scrimAlphaReducingTransparency:YES increaseContrast:YES] >= 0.9, "reduce transparency wins");
    HCG_CHECK([HCGCommandModeStatus animatesTransitionsWithReduceMotion:NO animationsEnabled:YES], "animates by default");
    HCG_CHECK(![HCGCommandModeStatus animatesTransitionsWithReduceMotion:YES animationsEnabled:YES], "reduce motion: no animation");
    HCG_CHECK(![HCGCommandModeStatus animatesTransitionsWithReduceMotion:NO animationsEnabled:NO], "animations off: no animation");
    HCG_CHECK(![HCGCommandModeStatus animatesTransitionsWithReduceMotion:YES animationsEnabled:NO], "both off: no animation");
}

// Command Mode's card follows the panel glass the user chose, by the panel's own rules.
static void testCardGlassFollowsPanelSettings(void) {
    HCGSettings *s = [HCGSettings defaultSettings];
    s.panelOpacity = 0.4;
    s.panelBlur = HCGPanelBlurLight;
    HCG_CHECK([HCGCommandModeStatus cardBlurForSettings:s reduceTransparency:NO] == HCGPanelBlurLight, "configured blur kept");
    HCG_CHECK([HCGCommandModeStatus cardTintAlphaForSettings:s reduceTransparency:NO increaseContrast:NO] == 0.4, "configured opacity kept");
    s.panelBlur = HCGPanelBlurStrong;
    s.panelOpacity = 0.9;
    HCG_CHECK([HCGCommandModeStatus cardBlurForSettings:s reduceTransparency:NO] == HCGPanelBlurStrong, "strong blur kept");
    HCG_CHECK([HCGCommandModeStatus cardTintAlphaForSettings:s reduceTransparency:NO increaseContrast:NO] == 0.9, "high opacity kept");
    HCG_CHECK([HCGCommandModeStatus cardTintAlphaForSettings:s reduceTransparency:NO increaseContrast:YES] == 0.9,
              "increase contrast never lowers a higher opacity");

    // Blur off: the panel's readability floor applies to the card too.
    s.panelBlur = HCGPanelBlurOff;
    s.panelOpacity = 0.4;
    double unblurred = [HCGCommandModeStatus cardTintAlphaForSettings:s reduceTransparency:NO increaseContrast:NO];
    HCG_CHECK(unblurred == [s effectivePanelOpacityWithReduceTransparency:NO] && unblurred > 0.4, "unblurred floor: %.2f", unblurred);
    HCG_CHECK([HCGCommandModeStatus cardBlurForSettings:s reduceTransparency:NO] == HCGPanelBlurOff, "blur off kept");

    // Increase Contrast raises a thin tint to a readable minimum.
    s.panelBlur = HCGPanelBlurStandard;
    s.panelOpacity = 0.4;
    HCG_CHECK([HCGCommandModeStatus cardTintAlphaForSettings:s reduceTransparency:NO increaseContrast:YES] == 0.86, "contrast minimum");

    // Reduce Transparency overrides the configured glass: opaque and unblurred.
    s.panelBlur = HCGPanelBlurStrong;
    s.panelOpacity = 0.4;
    HCG_CHECK([HCGCommandModeStatus cardBlurForSettings:s reduceTransparency:YES] == HCGPanelBlurOff, "reduce transparency: no blur");
    HCG_CHECK([HCGCommandModeStatus cardTintAlphaForSettings:s reduceTransparency:YES increaseContrast:NO] == 1.0, "reduce transparency: opaque");
    HCG_CHECK([HCGCommandModeStatus cardTintAlphaForSettings:s reduceTransparency:YES increaseContrast:YES] == 1.0, "reduce transparency wins");

    // Same answer as the panel for the defaults, and nil settings mean the defaults.
    HCGSettings *d = [HCGSettings defaultSettings];
    HCG_CHECK([HCGCommandModeStatus cardTintAlphaForSettings:nil reduceTransparency:NO increaseContrast:NO] ==
              [d effectivePanelOpacityWithReduceTransparency:NO], "nil settings: default opacity");
    HCG_CHECK([HCGCommandModeStatus cardBlurForSettings:nil reduceTransparency:NO] == [d effectivePanelBlurWithReduceTransparency:NO],
              "nil settings: default blur");
}

void HCGRunCommandModeTests(void) {
    HCG_RUN(testPresentationPolicy);
    HCG_RUN(testCardGlassFollowsPanelSettings);
    HCG_RUN(testConnectionStatesAreDistinct);
    HCG_RUN(testCatalogStatusesMapToDisplayStates);
    HCG_RUN(testReachabilityAndSessionStates);
    HCG_RUN(testMissingAndInconsistentIntegrationData);
    HCG_RUN(testBatteryDisplay);
    HCG_RUN(testLowPowerDisplay);
    HCG_RUN(testNetworkDisplay);
    HCG_RUN(testStorageDisplayAndFormatting);
    HCG_RUN(testUnavailableSnapshotShowsNoValues);
}
