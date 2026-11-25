#import "HCGInterchange.h"
#import "HCGConstants.h"
#include <math.h>

const NSInteger HCGInterchangeProtocolVersion = 1;
NSString *const HCGInterchangeInfoKey = @"HCGInterchange";
NSString *const HCGInterchangeProtocolKey = @"protocol";
NSString *const HCGInterchangeProductKey = @"product";
NSString *const HCGInterchangeRoutesKey = @"routes";
NSString *const HCGInterchangeCapabilitiesKey = @"capabilities";

NSString *const HCGHIPProductNexus = @"nexus";
NSString *const HCGHIPProductTerminalUnleashed = @"terminal-unleashed";
NSString *const HCGHIPProductTerminal = @"terminal";
NSString *const HCGHIPProductSentinel = @"sentinel";
NSString *const HCGHIPProductHalo = @"halo";
NSString *const HCGHIPProductVortex = @"vortex";
NSString *const HCGHIPProductPortal = @"portal";
NSString *const HCGHIPProductAnimationCenter = @"animation-center";
NSString *const HCGHIPProductRepo = @"repo";
NSString *const HCGHIPProductAgentRuntime = @"agent-runtime";
NSString *const HCGHIPProductServer = @"server";
NSString *const HCGHIPLocalDevelopmentLabel = @"LOCAL DEVELOPMENT — not an HCG account";
NSString *const HCGHIPProductConnect = @"connect";
NSString *const HCGHIPProductNews = @"news";
NSString *const HCGHIPProductExecutableMaker = @"executable-maker";

NSString *const HCGNexusOpenEcosystemDarwinNotification = @"com.hakmicapitalgroup.hcgnexus/open/ecosystem";
NSString *const HCGNexusOpenProductDarwinPrefix = @"com.hakmicapitalgroup.hcgnexus/open/product/";
const NSTimeInterval HCGNexusOpenRequestMinimumInterval = 2.0;

NSString *const HCGEcosystemActivityStoreKey = @"ecosystemActivity";
const NSUInteger HCGEcosystemActivityLimit = 40;

#pragma mark Model objects

@implementation HCGHIPRoute
@synthesize identifier = _identifier, title = _title, symbolName = _symbolName, kind = _kind, target = _target,
            requirement = _requirement, detail = _detail, fallbackRouteIdentifier = _fallbackRouteIdentifier;
@end

@implementation HCGHIPCapability
@synthesize identifier = _identifier, title = _title, state = _state, permission = _permission, note = _note;
@end

@implementation HCGHIPReadout
@synthesize key = _key, title = _title, kind = _kind, defaultValue = _defaultValue;
@end

@implementation HCGHIPProductDescriptor
@synthesize productID = _productID, name = _name, symbolName = _symbolName, kind = _kind,
            packageIdentifier = _packageIdentifier, bundleIdentifier = _bundleIdentifier, urlScheme = _urlScheme,
            settingsBundleName = _settingsBundleName, minimumOSVersion = _minimumOSVersion,
            integrationMinimumVersion = _integrationMinimumVersion, summary = _summary,
            unavailableReason = _unavailableReason, preferenceDomain = _preferenceDomain, enabledKey = _enabledKey,
            enabledByDefault = _enabledByDefault, statusDomain = _statusDomain, statusRecordKey = _statusRecordKey,
            productPageURL = _productPageURL, routes = _routes, capabilities = _capabilities, readouts = _readouts;

- (HCGHIPRoute *)routeWithIdentifier:(NSString *)identifier {
    NSUInteger i;
    for (i = 0; i < self.routes.count; i++) {
        HCGHIPRoute *route = [self.routes objectAtIndex:i];
        if ([route.identifier isEqualToString:identifier]) return route;
    }
    return nil;
}
@end

@implementation HCGHIPFacts
@synthesize productID = _productID, hostCanInspect = _hostCanInspect, hostCanLaunchApps = _hostCanLaunchApps,
            packageVersion = _packageVersion, appInstalled = _appInstalled, appVersion = _appVersion,
            appBuild = _appBuild, declaredSchemes = _declaredSchemes, declaration = _declaration,
            settingsBundlePresent = _settingsBundlePresent, canOpenScheme = _canOpenScheme, osVersion = _osVersion,
            offeredVersion = _offeredVersion, preferences = _preferences, statusRecord = _statusRecord,
            packageManagers = _packageManagers, simulated = _simulated, serviceLinkState = _serviceLinkState,
            serviceLinkDetail = _serviceLinkDetail, serviceLinkServerName = _serviceLinkServerName,
            serviceLinkLocalDevelopment = _serviceLinkLocalDevelopment, serviceLinkHostedServices = _serviceLinkHostedServices;

- (instancetype)init {
    if ((self = [super init])) {
        _serviceLinkHostedServices = -1;
    }
    return self;
}

- (BOOL)installed {
    return self.packageVersion.length > 0 || self.appInstalled;
}
@end

@implementation HCGHIPResolvedCapability
@synthesize capability = _capability, state = _state, reason = _reason;
@end

@implementation HCGHIPProductStatus
@synthesize descriptor = _descriptor, availability = _availability, stateTitle = _stateTitle, versionText = _versionText,
            compatibilityText = _compatibilityText, healthText = _healthText, integrationText = _integrationText,
            updateText = _updateText, offeredVersion = _offeredVersion, updateAvailable = _updateAvailable,
            routes = _routes, routeNotes = _routeNotes, capabilities = _capabilities, readouts = _readouts,
            declarationNote = _declarationNote, simulated = _simulated;

- (BOOL)installed {
    return self.availability == HCGHIPAvailabilityReady || self.availability == HCGHIPAvailabilityOff ||
           self.availability == HCGHIPAvailabilityAttention || self.availability == HCGHIPAvailabilityNeedsUpdate ||
           self.availability == HCGHIPAvailabilityHub;
}
@end

#pragma mark Registry builders

static HCGHIPRoute *HCGRoute(NSString *identifier, NSString *title, NSString *symbol, HCGHIPRouteKind kind, NSString *target,
                             HCGHIPRouteRequirement requirement, NSString *detail, NSString *fallback) {
    HCGHIPRoute *route = [[HCGHIPRoute alloc] init];
    route.identifier = identifier;
    route.title = title;
    route.symbolName = symbol;
    route.kind = kind;
    route.target = target;
    route.requirement = requirement;
    route.detail = detail;
    route.fallbackRouteIdentifier = fallback;
    return route;
}

static HCGHIPRoute *HCGLink(NSString *scheme, NSString *path, NSString *identifier, NSString *title, NSString *symbol,
                            HCGHIPRouteRequirement requirement, NSString *detail, NSString *fallback) {
    return HCGRoute(identifier, title, symbol, HCGHIPRouteKindAppLink, [NSString stringWithFormat:@"%@://open/%@", scheme, path],
                    requirement, detail, fallback);
}

static HCGHIPRoute *HCGOpenApp(NSString *bundle, NSString *name) {
    return HCGRoute(@"open-app", [@"Open " stringByAppendingString:name], @"arrow.up.forward.app", HCGHIPRouteKindOpenApp, bundle,
                    HCGHIPRouteRequirementInstalled, @"Opens the app. Nothing starts by itself.", nil);
}

static HCGHIPRoute *HCGSettingsRoute(NSString *label) {
    return HCGRoute(@"settings", @"Open in Settings", @"gearshape", HCGHIPRouteKindSettingsApp, @"com.apple.Preferences",
                    HCGHIPRouteRequirementInstalled,
                    [NSString stringWithFormat:@"Opens the Settings app, where %@ is listed. Its own page has no documented link, so Nexus does not guess one.", label], nil);
}

static HCGHIPRoute *HCGPackageRoute(void) {
    return HCGRoute(@"package-manager", @"View in Package Manager", @"shippingbox", HCGHIPRouteKindPackageManager, @"",
                    HCGHIPRouteRequirementNone, @"Opens the package in Zebra or Sileo. Nexus never installs or removes packages; your package manager asks first.", nil);
}

static HCGHIPCapability *HCGCap(NSString *identifier, NSString *title, HCGHIPCapabilityState state, HCGHIPPermission permission, NSString *note) {
    HCGHIPCapability *capability = [[HCGHIPCapability alloc] init];
    capability.identifier = identifier;
    capability.title = title;
    capability.state = state;
    capability.permission = permission;
    capability.note = note;
    return capability;
}

static HCGHIPReadout *HCGRead(NSString *key, NSString *title, HCGHIPReadoutKind kind, id defaultValue) {
    HCGHIPReadout *readout = [[HCGHIPReadout alloc] init];
    readout.key = key;
    readout.title = title;
    readout.kind = kind;
    readout.defaultValue = defaultValue;
    return readout;
}

static NSNumber *HCGBool(BOOL value) {
    return [NSNumber numberWithBool:value];
}

static NSNumber *HCGNum(double value) {
    return [NSNumber numberWithDouble:value];
}

static HCGHIPProductDescriptor *HCGProductDescriptor(NSString *productID, NSString *name, NSString *symbol, HCGHIPProductKind kind, NSString *summary) {
    HCGHIPProductDescriptor *d = [[HCGHIPProductDescriptor alloc] init];
    d.productID = productID;
    d.name = name;
    d.symbolName = symbol;
    d.kind = kind;
    d.summary = summary;
    d.routes = [NSArray array];
    d.capabilities = [NSArray array];
    d.readouts = [NSArray array];
    return d;
}

static NSString *const kOwnerDevice = @"Seen working on the owner's iPhone 11 Pro Max (iOS 17.4, Dopamine) with 0.2.0~rc2, Nov 2026.";

static NSArray *HCGTerminalRoutes(NSString *scheme, BOOL unleashed) {
    NSMutableArray *routes = [NSMutableArray array];
    [routes addObject:HCGOpenApp(unleashed ? @"com.hakmicapitalgroup.hcgterminal.unleashed" : @"com.hakmicapitalgroup.hcgterminal",
                                 unleashed ? @"HCG Terminal Unleashed" : @"HCG Terminal")];
    HCGHIPRouteRequirement s = HCGHIPRouteRequirementDeclaredScheme, d = HCGHIPRouteRequirementDeclaredRoute;
    [routes addObject:HCGLink(scheme, @"dashboard", @"dashboard", @"Dashboard", @"rectangle.grid.2x2", s, @"HCG Terminal's dashboard.", nil)];
    if (unleashed) {
        [routes addObject:HCGLink(scheme, @"tools", @"tools", @"Unleashed Tools", @"wrench.and.screwdriver", s,
                                  @"Installed packages, Programs, Processes, Environment and Jailbreak Diagnostics.", nil)];
        [routes addObject:HCGLink(scheme, @"jailbreak-diagnostics", @"jailbreak-diagnostics", @"Jailbreak Diagnostics", @"stethoscope", d,
                                  @"Checks of the rootless environment, read-only.", @"tools")];
        [routes addObject:HCGLink(scheme, @"packages", @"packages", @"Installed Packages", @"shippingbox", d,
                                  @"The installed-package list. Changing packages needs your approval inside HCG Terminal.", @"tools")];
        [routes addObject:HCGLink(scheme, @"processes", @"processes", @"Processes", @"list.bullet.rectangle", d,
                                  @"Running processes, as far as iOS shows them to HCG Terminal.", @"tools")];
    }
    [routes addObject:HCGLink(scheme, @"diagnostics", @"diagnostics", @"Diagnostics", @"waveform.path.ecg", s, @"HCG Terminal's own diagnostics and build information.", nil)];
    [routes addObject:HCGLink(scheme, @"files", @"files", @"Files", @"folder", s, @"HCG Terminal's file browser.", nil)];
    [routes addObject:HCGLink(scheme, @"console", @"console", @"Log Console", @"text.alignleft", s, @"HCG Terminal's log console.", nil)];
    [routes addObject:HCGLink(scheme, @"hosts", @"hosts", @"SSH Hosts", @"server.rack", s, @"Saved hosts. Connecting needs you to tap Connect; HCG Terminal keeps its own credentials.", nil)];
    [routes addObject:HCGLink(scheme, @"capabilities", @"capabilities", @"Capabilities and Access", @"checklist", s, @"What HCG Terminal can do on this device, and why.", nil)];
    [routes addObject:HCGLink(scheme, @"settings", @"settings", @"Terminal Settings", @"gearshape", s, @"HCG Terminal's preferences.", nil)];
    [routes addObject:HCGPackageRoute()];
    return routes;
}

static NSArray *HCGSentinelRoutes(void) {
    NSMutableArray *routes = [NSMutableArray array];
    HCGHIPRouteRequirement s = HCGHIPRouteRequirementDeclaredScheme;
    [routes addObject:HCGOpenApp(@"com.hcg.sentinel", @"HCG Sentinel")];
    [routes addObject:HCGLink(@"hcgsentinel", @"securityLab", @"securityLab", @"Security Lab", @"shield.lefthalf.filled", s,
                              @"Security Lab. Every assessment starts only when you press Start in Sentinel.", nil)];
    [routes addObject:HCGLink(@"hcgsentinel", @"dashboard", @"dashboard", @"Dashboard", @"rectangle.grid.2x2", s, @"Sentinel's dashboard.", nil)];
    [routes addObject:HCGLink(@"hcgsentinel", @"networkCheck", @"networkCheck", @"Check My Network", @"network", s, @"Sentinel's network check (runs when you start it).", nil)];
    [routes addObject:HCGLink(@"hcgsentinel", @"capabilities", @"capabilities", @"Capabilities", @"checklist", s, @"What Sentinel can check on this device.", nil)];
    [routes addObject:HCGLink(@"hcgsentinel", @"network", @"network", @"Network", @"wifi", s, @"Network status in Sentinel.", nil)];
    [routes addObject:HCGLink(@"hcgsentinel", @"bluetooth", @"bluetooth", @"Bluetooth", @"dot.radiowaves.left.and.right", s, @"Bluetooth in Sentinel.", nil)];
    [routes addObject:HCGLink(@"hcgsentinel", @"radio", @"radio", @"Radio", @"antenna.radiowaves.left.and.right", s, @"Radio information in Sentinel.", nil)];
    [routes addObject:HCGLink(@"hcgsentinel", @"requests", @"requests", @"Requests", @"arrow.left.arrow.right", s, @"Sentinel's request log.", nil)];
    [routes addObject:HCGLink(@"hcgsentinel", @"settings", @"settings", @"Sentinel Settings", @"gearshape", s, @"Sentinel's settings.", nil)];
    [routes addObject:HCGPackageRoute()];
    return routes;
}

static NSArray *HCGBuildRegistry(void) {
    NSMutableArray *all = [NSMutableArray array];
    HCGHIPProductDescriptor *d;

    // HCG Nexus — this hub.
    d = HCGProductDescriptor(HCGHIPProductNexus, @"HCG Nexus", @"square.grid.3x3.square", HCGHIPProductKindHub,
                             @"This control hub: the panel, the HCG Ecosystem dashboard and its integrations.");
    d.packageIdentifier = @"com.hakmicapitalgroup.hcgnexus";
    d.productPageURL = @"https://repo.hakmicapitalgroup.com/";
    d.routes = [NSArray arrayWithObjects:HCGPackageRoute(), nil];
    d.capabilities = [NSArray arrayWithObjects:
        HCGCap(@"discovery", @"Read-only discovery of HCG products", HCGHIPCapabilityStateAvailable, HCGHIPPermissionNone, @"Installed packages, app versions and each product's own status record; nothing is changed."),
        HCGCap(@"halo-border", @"HCG Halo border around the panel", HCGHIPCapabilityStateAvailable, HCGHIPPermissionProductOwnedSwitch, @"HCGNexusBorderInterface v1; switched through HCG Halo's own HaloNexusControl."),
        HCGCap(@"portal-open", @"HCG Portal can open the panel", HCGHIPCapabilityStateAvailable, HCGHIPPermissionNone, @"HCGNexusPortalInterface v1, the interface HCG Portal already calls (after your unlock)."),
        HCGCap(@"app-open", @"HCG apps can open the Ecosystem dashboard", HCGHIPCapabilityStateAvailable, HCGHIPPermissionNone, @"Darwin request com.hakmicapitalgroup.hcgnexus/open/…; navigation only, unlocked only, can be turned off."),
        HCGCap(@"package-changes", @"Install, update or remove packages", HCGHIPCapabilityStateUnavailable, HCGHIPPermissionNotOffered, @"Not offered: Nexus shows versions and opens your package manager."),
        nil];
    [all addObject:d];

    // HCG Terminal Unleashed — jailbreak edition app.
    d = HCGProductDescriptor(HCGHIPProductTerminalUnleashed, @"HCG Terminal Unleashed", @"terminal.fill", HCGHIPProductKindApp,
                             @"Jailbreak edition of HCG Terminal: local rootless shell, packages, processes, files and jailbreak diagnostics.");
    d.packageIdentifier = @"com.hakmicapitalgroup.hcgterminal.unleashed";
    d.bundleIdentifier = @"com.hakmicapitalgroup.hcgterminal.unleashed";
    d.urlScheme = @"hcgterminal-unleashed";
    d.minimumOSVersion = @"17.0";
    d.productPageURL = @"https://repo.hakmicapitalgroup.com/products/hcg-terminal-unleashed/";
    d.routes = HCGTerminalRoutes(@"hcgterminal-unleashed", YES);
    d.capabilities = [NSArray arrayWithObjects:
        HCGCap(@"local-shell", @"Local shell in the rootless environment", HCGHIPCapabilityStateVerified, HCGHIPPermissionApprovalInProduct, kOwnerDevice),
        HCGCap(@"package-inventory", @"Installed-package information", HCGHIPCapabilityStateVerified, HCGHIPPermissionNone, kOwnerDevice),
        HCGCap(@"filesystem", @"File-system browsing", HCGHIPCapabilityStateVerified, HCGHIPPermissionNone, kOwnerDevice),
        HCGCap(@"jailbreak-diagnostics", @"Jailbreak diagnostics", HCGHIPCapabilityStateVerified, HCGHIPPermissionNone, kOwnerDevice),
        HCGCap(@"process-list", @"Running processes", HCGHIPCapabilityStateAvailable, HCGHIPPermissionNone, @"In Unleashed Tools › Processes; not separately confirmed on a device."),
        HCGCap(@"package-changes", @"Install or remove packages", HCGHIPCapabilityStateAvailable, HCGHIPPermissionApprovalInProduct, @"Inside HCG Terminal only, each change approved there and run visibly. Nexus never asks it to."),
        HCGCap(@"ssh", @"SSH sessions", HCGHIPCapabilityStateAvailable, HCGHIPPermissionApprovalInProduct, @"HCG Terminal keeps its hosts, keys and passwords; Nexus never sees them."),
        HCGCap(@"nexus-links", @"Opens from Nexus (navigation links)", HCGHIPCapabilityStateAvailable, HCGHIPPermissionNone, @"hcgterminal-unleashed://open/<screen>; a link never starts a session or runs a command."),
        HCGCap(@"open-nexus", @"Opens HCG Nexus", HCGHIPCapabilityStatePlanned, HCGHIPPermissionNone, @"Needs an HCG Terminal build with the HCG Interchange declaration (proposed on HCG-Terminal branch claude/nexus-interchange)."),
        nil];
    [all addObject:d];

    // HCG Terminal — standard (App Store) app.
    d = HCGProductDescriptor(HCGHIPProductTerminal, @"HCG Terminal", @"terminal", HCGHIPProductKindApp,
                             @"HCG Terminal for SSH hosts, files and builds (standard edition, no jailbreak access).");
    d.bundleIdentifier = @"com.hakmicapitalgroup.hcgterminal";
    d.urlScheme = @"hcgterminal";
    d.minimumOSVersion = @"17.0";
    d.routes = HCGTerminalRoutes(@"hcgterminal", NO);
    d.capabilities = [NSArray arrayWithObjects:
        HCGCap(@"ssh", @"SSH sessions", HCGHIPCapabilityStateAvailable, HCGHIPPermissionApprovalInProduct, @"HCG Terminal keeps its hosts, keys and passwords; Nexus never sees them."),
        HCGCap(@"nexus-links", @"Opens from Nexus (navigation links)", HCGHIPCapabilityStateAvailable, HCGHIPPermissionNone, @"hcgterminal://open/<screen>."),
        HCGCap(@"local-shell", @"Local shell", HCGHIPCapabilityStateUnavailable, HCGHIPPermissionNotOffered, @"The standard edition is sandboxed; use HCG Terminal Unleashed."),
        nil];
    [all addObject:d];

    // HCG Sentinel — app (jailbreak package of the same app).
    d = HCGProductDescriptor(HCGHIPProductSentinel, @"HCG Sentinel", @"shield.lefthalf.filled", HCGHIPProductKindApp,
                             @"Security Lab, network and radio checks. Assessments start only from inside Sentinel.");
    d.packageIdentifier = @"com.hakmicapitalgroup.hcgsentinel";
    d.bundleIdentifier = @"com.hcg.sentinel";
    d.urlScheme = @"hcgsentinel";
    d.minimumOSVersion = @"15.0";
    d.productPageURL = @"https://repo.hakmicapitalgroup.com/products/hcg-sentinel/";
    d.routes = HCGSentinelRoutes();
    d.capabilities = [NSArray arrayWithObjects:
        HCGCap(@"security-lab", @"Security Lab (secret scanner, exposure check, authentication defence lab)", HCGHIPCapabilityStateAvailable, HCGHIPPermissionApprovalInProduct, @"Each run starts when you press Start in Sentinel."),
        HCGCap(@"network-check", @"Check My Network", HCGHIPCapabilityStateAvailable, HCGHIPPermissionApprovalInProduct, @"Runs when you start it in Sentinel."),
        HCGCap(@"nexus-links", @"Opens from Nexus (navigation links)", HCGHIPCapabilityStateAvailable, HCGHIPPermissionNone, @"hcgsentinel://open/<section>, validated with Sentinel's own rules."),
        HCGCap(@"status-snapshot", @"Status for Nexus (activity, verified checks)", HCGHIPCapabilityStatePlanned, HCGHIPPermissionNone, @"Sentinel defines NexusStatusSnapshot but does not publish it yet, so Nexus shows no Sentinel activity."),
        HCGCap(@"device-health", @"Device health screen", HCGHIPCapabilityStateUnavailable, HCGHIPPermissionNone, @"HCG Sentinel has no device-health screen; Nexus's own device overview shows battery, storage and network."),
        nil];
    [all addObject:d];

    // HCG Halo — edge lighting tweak, the existing panel-border integration.
    d = HCGProductDescriptor(HCGHIPProductHalo, @"HCG Halo", @"circle.dashed", HCGHIPProductKindTweak,
                             @"Animated edge lighting for the screen and, through Nexus's border interface, for this panel.");
    d.packageIdentifier = @"com.hakmicapitalgroup.halo";
    d.settingsBundleName = @"HCGHaloPrefs.bundle";
    d.minimumOSVersion = @"15.0";
    d.integrationMinimumVersion = @"0.2.0~beta1";
    d.preferenceDomain = @"com.hakmicapitalgroup.halo";
    d.enabledKey = @"enabled";
    d.enabledByDefault = NO;
    d.statusDomain = @"com.hakmicapitalgroup.halo.status";
    d.statusRecordKey = @"status";
    d.productPageURL = @"https://repo.hakmicapitalgroup.com/products/hcg-halo/";
    d.routes = [NSArray arrayWithObjects:
        HCGRoute(@"nexus-border", @"Use HCG Halo border", @"square.dashed", HCGHIPRouteKindNexusControl, @"halo-border",
                 HCGHIPRouteRequirementInstalled, @"Switches HCG Halo's panel border through HCG Halo's own HaloNexusControl. Never turns on the screen-edge light.", nil),
        HCGSettingsRoute(@"HCG Halo"), HCGPackageRoute(), nil];
    d.capabilities = [NSArray arrayWithObjects:
        HCGCap(@"panel-border", @"Border around the Nexus panel", HCGHIPCapabilityStateAvailable, HCGHIPPermissionProductOwnedSwitch, @"Follows the panel; never takes a touch. Phone test pending."),
        HCGCap(@"border-switch", @"Switch from Nexus", HCGHIPCapabilityStateAvailable, HCGHIPPermissionProductOwnedSwitch, @"HaloNexusControl v1 (HCG Halo 0.3.1~beta1 or later)."),
        HCGCap(@"screen-edge", @"Screen-edge lighting", HCGHIPCapabilityStateAvailable, HCGHIPPermissionNotOffered, @"Controlled only in HCG Halo's settings; Nexus never turns it on."),
        HCGCap(@"appearance-read", @"Colours, animation, brightness and speed (read-only here)", HCGHIPCapabilityStateAvailable, HCGHIPPermissionNone, @"Read from HCG Halo's own preferences."),
        HCGCap(@"appearance-write", @"Change colours or animation from Nexus", HCGHIPCapabilityStateUnavailable, HCGHIPPermissionNotOffered, @"HCG Halo has no API for it; change them in Settings › HCG Halo."),
        HCGCap(@"preview", @"Live preview and Replay Opening", HCGHIPCapabilityStateAvailable, HCGHIPPermissionNone, @"In HCG Halo's own Settings pages."),
        nil];
    d.readouts = [NSArray arrayWithObjects:
        HCGRead(@"enabled", @"Enabled", HCGHIPReadoutKindBool, HCGBool(NO)),
        HCGRead(@"target", @"Draws on", HCGHIPReadoutKindText, @"screen"),
        HCGRead(@"mode", @"Animation", HCGHIPReadoutKindText, @"static"),
        HCGRead(@"colourStyle", @"Colour style", HCGHIPReadoutKindText, @"gradient"),
        HCGRead(@"colours", @"Colours", HCGHIPReadoutKindColours, [NSArray arrayWithObjects:@"#00E5FF", @"#7B61FF", @"#C026FF", nil]),
        HCGRead(@"brightness", @"Brightness", HCGHIPReadoutKindPercent, HCGNum(0.9)),
        HCGRead(@"speed", @"Speed", HCGHIPReadoutKindNumber, HCGNum(1.0)),
        HCGRead(@"thickness", @"Thickness (pt)", HCGHIPReadoutKindNumber, HCGNum(3.0)),
        HCGRead(@"glow", @"Glow", HCGHIPReadoutKindPercent, HCGNum(0.5)),
        nil];
    [all addObject:d];

    // HCG Vortex — Home Screen page transitions.
    d = HCGProductDescriptor(HCGHIPProductVortex, @"HCG Vortex", @"tornado", HCGHIPProductKindTweak,
                             @"Home Screen page transitions: Tornado, Orbital, Warp, Holographic, Circuit Flow, Magnetic and more.");
    d.packageIdentifier = @"com.hakmicapitalgroup.vortex";
    d.settingsBundleName = @"HCGVortexPrefs.bundle";
    d.minimumOSVersion = @"15.0";
    d.preferenceDomain = @"com.hakmicapitalgroup.vortex";
    d.enabledKey = @"enabled";
    d.enabledByDefault = YES;
    d.statusDomain = @"com.hakmicapitalgroup.vortex.status";
    d.statusRecordKey = nil;
    d.productPageURL = @"https://repo.hakmicapitalgroup.com/products/hcg-vortex/";
    d.routes = [NSArray arrayWithObjects:HCGSettingsRoute(@"HCG Vortex"), HCGPackageRoute(), nil];
    d.capabilities = [NSArray arrayWithObjects:
        HCGCap(@"transitions", @"Page transitions (12 presets, per-direction effects)", HCGHIPCapabilityStateAvailable, HCGHIPPermissionNone, @"Written against iOS 17; other iOS versions are reported as untested by HCG Vortex."),
        HCGCap(@"effect-settings", @"Effect settings (speed, intensity, easing, effect parameters)", HCGHIPCapabilityStateAvailable, HCGHIPPermissionNone, @"Read-only here; change them in Settings › HCG Vortex."),
        HCGCap(@"preview", @"Effect previews", HCGHIPCapabilityStateAvailable, HCGHIPPermissionNone, @"On each effect page in HCG Vortex's Settings."),
        HCGCap(@"nexus-integration", @"Nexus-specific integration", HCGHIPCapabilityStatePlanned, HCGHIPPermissionNone, @"HCG Vortex lists it as not implemented."),
        HCGCap(@"shared-appearance", @"Shared HCG appearance (accent colour, motion)", HCGHIPCapabilityStatePlanned, HCGHIPPermissionNone, @"Proposed in HCG Vortex's docs only."),
        nil];
    d.readouts = [NSArray arrayWithObjects:
        HCGRead(@"enabled", @"Enabled", HCGHIPReadoutKindBool, HCGBool(YES)),
        HCGRead(@"preset", @"Transition", HCGHIPReadoutKindText, @"vertical-rise"),
        HCGRead(@"swipeLeftEffect", @"Swipe left", HCGHIPReadoutKindText, @"vertical-rise"),
        HCGRead(@"swipeRightEffect", @"Swipe right", HCGHIPReadoutKindText, @"vertical-fall"),
        HCGRead(@"speed", @"Speed", HCGHIPReadoutKindNumber, HCGNum(1.0)),
        HCGRead(@"intensity", @"Intensity", HCGHIPReadoutKindPercent, HCGNum(1.0)),
        HCGRead(@"easing", @"Easing", HCGHIPReadoutKindText, @"linear"),
        HCGRead(@"accentColor", @"Accent", HCGHIPReadoutKindText, @"cyan"),
        nil];
    [all addObject:d];

    // HCG Portal — Lock Screen orb and radial launcher.
    d = HCGProductDescriptor(HCGHIPProductPortal, @"HCG Portal", @"circle.hexagongrid", HCGHIPProductKindTweak,
                             @"An orb with a radial menu after unlock: favourite apps, backgrounds, and HCG Nexus.");
    d.packageIdentifier = @"com.hakmicapitalgroup.portal";
    d.settingsBundleName = @"HCGPortalPrefs.bundle";
    d.minimumOSVersion = @"15.0";
    d.preferenceDomain = @"com.hakmicapitalgroup.portal";
    d.enabledKey = @"enabled";
    d.enabledByDefault = NO;
    d.statusDomain = @"com.hakmicapitalgroup.portal.status";
    d.statusRecordKey = @"status";
    d.productPageURL = @"https://repo.hakmicapitalgroup.com/products/hcg-portal/";
    d.routes = [NSArray arrayWithObjects:HCGSettingsRoute(@"HCG Portal"), HCGPackageRoute(), nil];
    d.capabilities = [NSArray arrayWithObjects:
        HCGCap(@"orb", @"Orb and radial menu (tap gesture)", HCGHIPCapabilityStateAvailable, HCGHIPPermissionNone, @"Tap the orb to open the menu; HCG Portal has no other gestures yet."),
        HCGCap(@"open-nexus", @"Opens the Nexus panel", HCGHIPCapabilityStateAvailable, HCGHIPPermissionNone, @"Through HCGNexusPortalInterface v1, which this Nexus provides; only after a successful unlock."),
        HCGCap(@"lighting-events", @"Lighting events for HCG Halo", HCGHIPCapabilityStateAvailable, HCGHIPPermissionNone, @"Posted by HCG Portal; no HCG Halo build listens to them yet."),
        HCGCap(@"hold-gestures", @"Hold-to-open commands and more gestures", HCGHIPCapabilityStatePlanned, HCGHIPPermissionNone, @"On HCG Portal's roadmap."),
        nil];
    d.readouts = [NSArray arrayWithObjects:
        HCGRead(@"enabled", @"Enabled", HCGHIPReadoutKindBool, HCGBool(NO)),
        HCGRead(@"palette", @"Palette", HCGHIPReadoutKindText, @"signature"),
        HCGRead(@"brightness", @"Brightness", HCGHIPReadoutKindPercent, HCGNum(0.85)),
        HCGRead(@"intensity", @"Glow and particles", HCGHIPReadoutKindPercent, HCGNum(0.6)),
        HCGRead(@"speed", @"Speed", HCGHIPReadoutKindNumber, HCGNum(1.0)),
        HCGRead(@"size", @"Orb size (pt)", HCGHIPReadoutKindNumber, HCGNum(132)),
        HCGRead(@"unlockAnimation", @"Unlock animation", HCGHIPReadoutKindBool, HCGBool(YES)),
        HCGRead(@"apps", @"Menu apps", HCGHIPReadoutKindCount, [NSArray array]),
        nil];
    [all addObject:d];

    // HCG Animation Center — animated Home and Lock Screen backgrounds.
    d = HCGProductDescriptor(HCGHIPProductAnimationCenter, @"HCG Animation Center", @"sparkles.rectangle.stack", HCGHIPProductKindTweak,
                             @"Animated Home Screen and Lock Screen backgrounds with a media library and a live-preview editor.");
    d.packageIdentifier = @"com.hakmicapitalgroup.animationcenter";
    d.settingsBundleName = @"HCGAnimationCenterPrefs.bundle";
    d.minimumOSVersion = @"15.0";
    d.preferenceDomain = @"com.hakmicapitalgroup.animationcenter";
    d.enabledKey = @"enabled";
    d.enabledByDefault = NO;
    d.statusDomain = @"com.hakmicapitalgroup.animationcenter.status";
    d.statusRecordKey = @"status";
    d.productPageURL = @"https://repo.hakmicapitalgroup.com/products/hcg-animation-center/";
    d.routes = [NSArray arrayWithObjects:HCGSettingsRoute(@"HCG Animation Center"), HCGPackageRoute(), nil];
    d.capabilities = [NSArray arrayWithObjects:
        HCGCap(@"backgrounds", @"Animated Home and Lock Screen backgrounds", HCGHIPCapabilityStateAvailable, HCGHIPPermissionNone, @"Simulator-tested by HCG Animation Center; no device test recorded."),
        HCGCap(@"library", @"Media library", HCGHIPCapabilityStateAvailable, HCGHIPPermissionNone, @"In Settings › HCG Animation Center."),
        HCGCap(@"preview", @"Editor with live preview", HCGHIPCapabilityStateAvailable, HCGHIPPermissionNone, @"In Settings › HCG Animation Center."),
        HCGCap(@"ai-backgrounds", @"AI-generated backgrounds", HCGHIPCapabilityStatePlanned, HCGHIPPermissionNone, @"The page exists but is not connected."),
        nil];
    d.readouts = [NSArray arrayWithObjects:
        HCGRead(@"enabled", @"Enabled", HCGHIPReadoutKindBool, HCGBool(NO)),
        HCGRead(@"homeEnabled", @"Home Screen", HCGHIPReadoutKindBool, HCGBool(YES)),
        HCGRead(@"lockEnabled", @"Lock Screen", HCGHIPReadoutKindBool, HCGBool(NO)),
        HCGRead(@"lockSource", @"Lock Screen source", HCGHIPReadoutKindText, @"same"),
        HCGRead(@"reduceMotion", @"With Reduce Motion", HCGHIPReadoutKindText, @"still"),
        HCGRead(@"lowPower", @"In Low Power Mode", HCGHIPReadoutKindText, @"still"),
        nil];
    [all addObject:d];

    // HCG News — app.
    d = HCGProductDescriptor(HCGHIPProductNews, @"HCG News", @"newspaper", HCGHIPProductKindApp, @"HCG's news app.");
    d.bundleIdentifier = @"com.hakmicapitalgroup.hcgnews";
    d.routes = [NSArray arrayWithObjects:HCGOpenApp(@"com.hakmicapitalgroup.hcgnews", @"HCG News"), nil];
    d.capabilities = [NSArray arrayWithObjects:
        HCGCap(@"open", @"Open the app", HCGHIPCapabilityStateAvailable, HCGHIPPermissionNone, @"Opened by bundle identifier."),
        HCGCap(@"headlines", @"Headlines in Nexus", HCGHIPCapabilityStateUnavailable, HCGHIPPermissionNone, @"HCG News publishes no links or headlines for other apps."),
        nil];
    [all addObject:d];

    // HCG Executable Maker — desktop app.
    d = HCGProductDescriptor(HCGHIPProductExecutableMaker, @"HCG Executable Maker", @"hammer", HCGHIPProductKindService,
                             @"Desktop app (Windows, macOS, Linux) that builds and packages HCG projects.");
    d.unavailableReason = @"Not available: a desktop app with no phone-reachable build-status interface. Use it on your computer.";
    d.capabilities = [NSArray arrayWithObjects:
        HCGCap(@"build-status", @"Build status on this iPhone", HCGHIPCapabilityStateUnavailable, HCGHIPPermissionNone, @"No interface a phone can reach."),
        nil];
    [all addObject:d];

    // HCG Repo — distribution.
    d = HCGProductDescriptor(HCGHIPProductRepo, @"HCG Repo", @"shippingbox.circle", HCGHIPProductKindRepository,
                             @"Where HCG packages come from (Candidate channel for betas). Nexus reads, your package manager installs.");
    d.productPageURL = @"https://repo.hakmicapitalgroup.com/";
    d.routes = [NSArray arrayWithObjects:
        HCGRoute(@"web", @"Open HCG Repo", @"safari", HCGHIPRouteKindWeb, @"https://repo.hakmicapitalgroup.com/", HCGHIPRouteRequirementNone, @"HCG Repo's website.", nil),
        nil];
    d.capabilities = [NSArray arrayWithObjects:
        HCGCap(@"installed-versions", @"Installed HCG package versions", HCGHIPCapabilityStateAvailable, HCGHIPPermissionNone, @"Read from dpkg's status file."),
        HCGCap(@"candidate-updates", @"Candidate updates", HCGHIPCapabilityStateAvailable, HCGHIPPermissionNone, @"From the package lists Zebra or Sileo last downloaded; refresh there for the newest."),
        HCGCap(@"package-changes", @"Install or remove from Nexus", HCGHIPCapabilityStateUnavailable, HCGHIPPermissionNotOffered, @"Not offered. Nexus opens your package manager, which asks before changing anything."),
        nil];
    [all addObject:d];

    // HCG Agent Runtime — prepared adapter only.
    d = HCGProductDescriptor(HCGHIPProductAgentRuntime, @"HCG Agent Runtime", @"cpu", HCGHIPProductKindService,
                             @"Local agent runtime (hcg.agentruntime/1) with previews, approvals and an audit trail.");
    d.unavailableReason = @"Unavailable: HCG Agent Runtime 0.1.0 is an unreleased macOS app that listens on loopback only and refuses tasks from HCG Nexus until authenticated connections exist. There is no iOS build.";
    d.capabilities = [NSArray arrayWithObjects:
        HCGCap(@"device.info", @"device.info", HCGHIPCapabilityStatePlanned, HCGHIPPermissionApprovalInProduct, @"Runtime capability; no device connection exists."),
        HCGCap(@"workspace.list", @"workspace.list", HCGHIPCapabilityStatePlanned, HCGHIPPermissionApprovalInProduct, @"Runtime capability; no device connection exists."),
        HCGCap(@"workspace.read", @"workspace.read", HCGHIPCapabilityStatePlanned, HCGHIPPermissionApprovalInProduct, @"Runtime capability; no device connection exists."),
        HCGCap(@"workspace.command", @"workspace.command", HCGHIPCapabilityStatePlanned, HCGHIPPermissionApprovalInProduct, @"Every task previewed and approved in the runtime; Nexus would only propose."),
        HCGCap(@"ios-runtime", @"Runtime on this jailbroken iPhone", HCGHIPCapabilityStatePlanned, HCGHIPPermissionNone, @"Planned by HCG Agent Runtime (docs/platforms/IOS.md); not implemented."),
        nil];
    [all addObject:d];

    // HCG Server — HCG Device Link (standalone app). Its state comes from the app's real connection
    // (HCGHIPFacts.serviceLinkState); builds without the client show unavailableReason.
    d = HCGProductDescriptor(HCGHIPProductServer, @"HCG Server", @"server.rack", HCGHIPProductKindService,
                             @"Host agent on your computer (development host for HCG System Tester); HCG Device Link (hcg.devicelink/1) pairs this iPhone with it.");
    d.unavailableReason = @"Not available: HCG Device Link runs only in the standalone HCG Nexus app (Connected Devices); the jailbreak package and Settings never connect to HCG Server. Nexus never claims a paired device.";
    d.capabilities = [NSArray arrayWithObjects:
        HCGCap(@"pairing", @"Pair this iPhone", HCGHIPCapabilityStateAvailable, HCGHIPPermissionApprovalInProduct, @"Invitation code; the owner approves each device on the server after comparing key fingerprints."),
        HCGCap(@"reports", @"View shared diagnostic reports", HCGHIPCapabilityStateAvailable, HCGHIPPermissionNone, @"hcg.diagnostic-report/1, shown as plain text only."),
        HCGCap(@"hosted-services", @"Hosted services and their health", HCGHIPCapabilityStateAvailable, HCGHIPPermissionNone, @"Read from the server (link/services); never placeholders."),
        HCGCap(@"open-service", @"Open a hosted service in Safari", HCGHIPCapabilityStateAvailable, HCGHIPPermissionApprovalInProduct, @"Single-use 60 s ticket; Safari verifies the HCG Server Local CA. Needs the owner's local-network approval on the Mac."),
        HCGCap(@"diagnostics", @"Server diagnostics (read-only)", HCGHIPCapabilityStateAvailable, HCGHIPPermissionNone, @"Redacted by the server; no logs or credentials."),
        HCGCap(@"remote-actions", @"Remote control or commands", HCGHIPCapabilityStateUnavailable, HCGHIPPermissionNotOffered, @"HCG Server refuses every action (action_execution_disabled); local development pairing never grants one."),
        nil];
    [all addObject:d];

    // HCG Connect — identity.
    d = HCGProductDescriptor(HCGHIPProductConnect, @"HCG Connect", @"person.badge.key", HCGHIPProductKindIdentity,
                             @"HCG's central sign-in. Nexus never runs its own accounts and passes no credentials between apps.");
    d.unavailableReason = @"Not available: no HCG Connect sign-in client has been issued for HCG Nexus, so Nexus has no sign-in. Apps keep their own sessions; Nexus never sees passwords, keys or tokens.";
    d.capabilities = [NSArray arrayWithObjects:
        HCGCap(@"sign-in", @"Sign in to HCG", HCGHIPCapabilityStatePlanned, HCGHIPPermissionApprovalInProduct, @"System browser with PKCE once HCG issues Nexus a client."),
        HCGCap(@"credential-sharing", @"Share credentials between apps", HCGHIPCapabilityStateUnavailable, HCGHIPPermissionNotOffered, @"Never: each app keeps its own credentials."),
        nil];
    [all addObject:d];

    return all;
}

#pragma mark Formatting helpers

static NSString *HCGStringValue(NSDictionary *d, NSString *key) {
    id v = [d isKindOfClass:[NSDictionary class]] ? [d objectForKey:key] : nil;
    return [v isKindOfClass:[NSString class]] ? (NSString *)v : nil;
}

static NSString *HCGClip(NSString *s, NSUInteger max) {
    if (![s isKindOfClass:[NSString class]]) return nil;
    NSString *flat = [[s componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]] componentsJoinedByString:@" "];
    if (flat.length <= max) return flat;
    return [[flat substringToIndex:max - 1] stringByAppendingString:@"…"];
}

static BOOL HCGArrayContainsStringCaseInsensitive(NSArray *array, NSString *value) {
    if (![array isKindOfClass:[NSArray class]] || value.length == 0) return NO;
    NSUInteger i;
    for (i = 0; i < array.count; i++) {
        id item = [array objectAtIndex:i];
        if ([item isKindOfClass:[NSString class]] && [(NSString *)item caseInsensitiveCompare:value] == NSOrderedSame) return YES;
    }
    return NO;
}

static NSString *HCGReadoutText(HCGHIPReadout *readout, id value) {
    switch (readout.kind) {
        case HCGHIPReadoutKindBool:
            if (![value isKindOfClass:[NSNumber class]]) value = readout.defaultValue;
            return [value boolValue] ? @"On" : @"Off";
        case HCGHIPReadoutKindText: {
            if (![value isKindOfClass:[NSString class]] || [value length] == 0) value = readout.defaultValue;
            NSString *text = HCGClip(value, 40);
            return text.length ? text : @"—";
        }
        case HCGHIPReadoutKindPercent:
            if (![value isKindOfClass:[NSNumber class]]) value = readout.defaultValue;
            return [NSString stringWithFormat:@"%ld%%", (long)lround([value doubleValue] * 100.0)];
        case HCGHIPReadoutKindNumber: {
            if (![value isKindOfClass:[NSNumber class]]) value = readout.defaultValue;
            double v = [value doubleValue];
            return fabs(v - (double)lround(v)) < 0.001 ? [NSString stringWithFormat:@"%ld", (long)lround(v)] : [NSString stringWithFormat:@"%.2f", v];
        }
        case HCGHIPReadoutKindColours: {
            if (![value isKindOfClass:[NSArray class]] || [value count] == 0) value = readout.defaultValue;
            NSMutableArray *colours = [NSMutableArray array];
            NSUInteger i;
            for (i = 0; i < [value count] && colours.count < 6; i++) {
                id c = [value objectAtIndex:i];
                if ([c isKindOfClass:[NSString class]] && [c length] == 7 && [c hasPrefix:@"#"]) [colours addObject:[c uppercaseString]];
            }
            return colours.count ? [colours componentsJoinedByString:@" "] : @"—";
        }
        case HCGHIPReadoutKindCount:
            if (![value isKindOfClass:[NSArray class]]) value = readout.defaultValue;
            return [NSString stringWithFormat:@"%lu", (unsigned long)[value count]];
    }
    return @"—";
}

// The product's own status state, as written by its SpringBoard side.
static NSString *HCGHealthForState(NSString *state, HCGHIPAvailability *availability) {
    if ([state isEqualToString:@"active"]) return @"Active";
    if ([state isEqualToString:@"disabled"]) return @"Off";
    if ([state isEqualToString:@"waiting"]) return @"Waiting (for example until the iPhone is unlocked)";
    if ([state isEqualToString:@"incompatible"]) {
        *availability = HCGHIPAvailabilityAttention;
        return @"Reports that this iOS version is not supported";
    }
    if ([state isEqualToString:@"kill-switch"]) {
        *availability = HCGHIPAvailabilityAttention;
        return @"Stopped by its kill switch";
    }
    if ([state isEqualToString:@"auto-disabled"]) {
        *availability = HCGHIPAvailabilityAttention;
        return @"Turned itself off after repeated SpringBoard restarts; turn it back on in its settings";
    }
    if ([state isEqualToString:@"fault"]) {
        *availability = HCGHIPAvailabilityAttention;
        return @"Stopped after an error; turn it off and on again in its settings";
    }
    return nil;
}

@implementation HCGInterchange

static NSArray *gRegistry = nil;

+ (NSArray *)registry {
    // Read from the main thread and from the background scan: built once, under a lock.
    @synchronized(self) {
        if (!gRegistry) gRegistry = [[NSArray alloc] initWithArray:HCGBuildRegistry()];
        return gRegistry;
    }
}

+ (HCGHIPProductDescriptor *)descriptorForProductID:(NSString *)productID {
    if (![productID isKindOfClass:[NSString class]]) return nil;
    NSArray *registry = [self registry];
    NSUInteger i;
    for (i = 0; i < registry.count; i++) {
        HCGHIPProductDescriptor *d = [registry objectAtIndex:i];
        if ([d.productID isEqualToString:productID]) return d;
    }
    return nil;
}

+ (HCGHIPProductDescriptor *)descriptorForBundleIdentifier:(NSString *)bundleIdentifier {
    if (![bundleIdentifier isKindOfClass:[NSString class]] || bundleIdentifier.length == 0) return nil;
    NSArray *registry = [self registry];
    NSUInteger i;
    for (i = 0; i < registry.count; i++) {
        HCGHIPProductDescriptor *d = [registry objectAtIndex:i];
        if ([d.bundleIdentifier isEqualToString:bundleIdentifier]) return d;
    }
    return nil;
}

+ (NSSet *)packageIdentifiers {
    NSMutableSet *set = [NSMutableSet set];
    NSArray *registry = [self registry];
    NSUInteger i;
    for (i = 0; i < registry.count; i++) {
        NSString *package = [[registry objectAtIndex:i] packageIdentifier];
        if (package.length) [set addObject:package];
    }
    return set;
}

#pragma mark Declarations

static BOOL HCGDeclarationHeaderIsValid(id declaration, HCGHIPProductDescriptor *descriptor, NSString **problem) {
    if (declaration == nil) return NO;
    if (![declaration isKindOfClass:[NSDictionary class]]) {
        if (problem) *problem = @"Its HCGInterchange declaration is not a dictionary and was ignored.";
        return NO;
    }
    id protocol = [declaration objectForKey:HCGInterchangeProtocolKey];
    if (![protocol isKindOfClass:[NSNumber class]] || [protocol integerValue] != HCGInterchangeProtocolVersion) {
        if (problem) *problem = [NSString stringWithFormat:@"It declares HCG Interchange protocol %@; this Nexus understands %ld, so the declaration was ignored.",
                                 [protocol isKindOfClass:[NSNumber class]] ? [protocol stringValue] : @"(none)", (long)HCGInterchangeProtocolVersion];
        return NO;
    }
    id product = [declaration objectForKey:HCGInterchangeProductKey];
    if (![product isKindOfClass:[NSString class]] || ![product isEqualToString:descriptor.productID]) {
        if (problem) *problem = @"Its declaration names another product and was ignored.";
        return NO;
    }
    return YES;
}

+ (NSSet *)declaredRouteIdentifiersFromDeclaration:(id)declaration descriptor:(HCGHIPProductDescriptor *)descriptor problem:(NSString **)problem {
    if (problem) *problem = nil;
    NSMutableSet *accepted = [NSMutableSet set];
    if (!HCGDeclarationHeaderIsValid(declaration, descriptor, problem)) return accepted;
    id routes = [declaration objectForKey:HCGInterchangeRoutesKey];
    if (routes != nil && ![routes isKindOfClass:[NSArray class]]) {
        if (problem) *problem = @"Its declared routes are not a list and were ignored.";
        return accepted;
    }
    NSMutableArray *ignored = [NSMutableArray array];
    NSUInteger i;
    for (i = 0; i < [routes count] && i < 64; i++) {
        id identifier = [routes objectAtIndex:i];
        HCGHIPRoute *route = [identifier isKindOfClass:[NSString class]] ? [descriptor routeWithIdentifier:identifier] : nil;
        if (route && route.requirement == HCGHIPRouteRequirementDeclaredRoute) {
            [accepted addObject:route.identifier];
        } else if (route) {
            // Known route that needs no declaration: nothing to switch on.
        } else {
            [ignored addObject:[identifier isKindOfClass:[NSString class]] ? HCGClip(identifier, 40) : @"(not text)"];
        }
    }
    if (ignored.count && problem) {
        *problem = [NSString stringWithFormat:@"Unknown routes in its declaration were ignored: %@.", [ignored componentsJoinedByString:@", "]];
    }
    return accepted;
}

+ (NSSet *)declaredCapabilityIdentifiersFromDeclaration:(id)declaration descriptor:(HCGHIPProductDescriptor *)descriptor {
    if (!HCGDeclarationHeaderIsValid(declaration, descriptor, NULL)) return nil;
    id capabilities = [declaration objectForKey:HCGInterchangeCapabilitiesKey];
    if (![capabilities isKindOfClass:[NSArray class]]) return nil;
    NSMutableSet *set = [NSMutableSet set];
    NSUInteger i;
    for (i = 0; i < [capabilities count] && i < 128; i++) {
        id identifier = [capabilities objectAtIndex:i];
        if ([identifier isKindOfClass:[NSString class]]) [set addObject:identifier];
    }
    return set;
}

#pragma mark Status

static BOOL HCGRouteUsable(HCGHIPRoute *route, HCGHIPProductDescriptor *d, HCGHIPFacts *f, NSSet *declaredRoutes, BOOL installed) {
    switch (route.kind) {
        case HCGHIPRouteKindPackageManager:
            return d.packageIdentifier.length > 0 && f.packageManagers.count > 0 && f.hostCanLaunchApps;
        case HCGHIPRouteKindWeb:
            return YES;
        case HCGHIPRouteKindOpenApp:
            return installed && f.hostCanLaunchApps;
        case HCGHIPRouteKindSettingsApp:
            return installed && f.settingsBundlePresent && f.hostCanLaunchApps;
        case HCGHIPRouteKindNexusControl:
            return installed;
        case HCGHIPRouteKindAppLink:
            break;
    }
    BOOL schemeReachable = f.hostCanInspect ? (installed && HCGArrayContainsStringCaseInsensitive(f.declaredSchemes, d.urlScheme))
                                            : f.canOpenScheme;
    switch (route.requirement) {
        case HCGHIPRouteRequirementNone: return YES;
        case HCGHIPRouteRequirementInstalled: return installed;
        case HCGHIPRouteRequirementDeclaredScheme: return schemeReachable;
        case HCGHIPRouteRequirementDeclaredRoute: return schemeReachable && [declaredRoutes containsObject:route.identifier];
    }
    return NO;
}

// A service reached through HCG Device Link: only the platform's real state, never an assumption.
static HCGHIPAvailability HCGServiceLinkStatus(HCGHIPProductDescriptor *d, HCGHIPFacts *f, HCGHIPProductStatus *status, NSString **capabilityReason) {
    NSString *server = f.serviceLinkServerName.length ? f.serviceLinkServerName : d.name;
    NSString *detail = f.serviceLinkDetail.length ? f.serviceLinkDetail : nil;
    HCGHIPAvailability availability = HCGHIPAvailabilityNotConnected;
    NSString *health = nil;
    switch (f.serviceLinkState) {
        case HCGHIPServiceLinkStateConnected:
            availability = HCGHIPAvailabilityConnected;
            health = [NSString stringWithFormat:@"Connected to %@", server];
            if (f.serviceLinkHostedServices >= 0) {
                health = [health stringByAppendingFormat:@" · %ld hosted service%@", (long)f.serviceLinkHostedServices,
                                                         f.serviceLinkHostedServices == 1 ? @"" : @"s"];
            }
            break;
        case HCGHIPServiceLinkStateUnreachable:
            availability = HCGHIPAvailabilityUnreachable;
            health = [NSString stringWithFormat:@"%@ is unreachable", server];
            break;
        case HCGHIPServiceLinkStateAwaitingApproval:
            health = [NSString stringWithFormat:@"Waiting for the owner of %@ to approve this iPhone", server];
            break;
        case HCGHIPServiceLinkStateNotConnected:
            health = [NSString stringWithFormat:@"Paired with %@, not connected now", server];
            break;
        case HCGHIPServiceLinkStateEnded:
            health = @"Not connected: the pairing ended";
            break;
        case HCGHIPServiceLinkStateNotPaired:
        case HCGHIPServiceLinkStateNotReported:
            health = @"Not paired with an HCG Server";
            break;
    }
    if (detail) health = [health stringByAppendingFormat:@". %@", detail];
    status.healthText = health;
    status.compatibilityText = @"Runs on your computer; this app reaches it through HCG Device Link";
    status.versionText = @"On your computer · HCG Device Link (hcg.devicelink/1)";
    NSMutableString *integration = [NSMutableString string];
    if (f.serviceLinkLocalDevelopment) [integration appendFormat:@"%@. Paired with the owner's approval only; this server only, never HCG services. ", HCGHIPLocalDevelopmentLabel];
    [integration appendString:availability == HCGHIPAvailabilityConnected
        ? @"Connected: the last signed request to the server succeeded. Remote actions stay disabled."
        : @"Not connected. Nexus says Connected only after a signed request to the server succeeds. Pair or reconnect in Connected Devices."];
    status.integrationText = integration;
    if (availability != HCGHIPAvailabilityConnected) *capabilityReason = @"Not connected to HCG Server.";
    return availability;
}

+ (HCGHIPProductStatus *)statusForDescriptor:(HCGHIPProductDescriptor *)d facts:(HCGHIPFacts *)facts {
    HCGHIPFacts *f = facts;
    if (!f) {
        f = [[HCGHIPFacts alloc] init];
        f.productID = d.productID;
    }
    HCGHIPProductStatus *status = [[HCGHIPProductStatus alloc] init];
    status.descriptor = d;
    status.simulated = f.simulated;
    status.routeNotes = [NSArray array];
    status.readouts = [NSArray array];
    status.integrationText = @"";
    status.compatibilityText = @"";
    status.healthText = @"";
    BOOL installed = f.installed;

    // Version text: the package and, for apps, the app's own version and build.
    NSMutableString *version = [NSMutableString string];
    if (f.packageVersion.length) [version appendString:f.packageVersion];
    if (f.appVersion.length) {
        if (version.length) [version appendString:@" · "];
        [version appendFormat:@"app %@", f.appVersion];
        if (f.appBuild.length) [version appendFormat:@" (%@)", f.appBuild];
    }
    if (version.length == 0) [version appendString:installed ? @"Installed (version not readable)" : @"Not installed"];
    if (d.kind == HCGHIPProductKindHub) [version setString:HCG_NEXUS_VERSION];
    status.versionText = version;

    HCGHIPAvailability availability = HCGHIPAvailabilityReady;
    NSString *capabilityReason = nil; // why Available capabilities are not usable here

    if (d.kind == HCGHIPProductKindHub) {
        availability = HCGHIPAvailabilityHub;
        status.compatibilityText = @"Runs on this iPhone";
        status.healthText = @"Running";
        status.integrationText = @"Discovers HCG products read-only and opens them; it is not an account or security authority.";
    } else if (d.kind == HCGHIPProductKindService && f.serviceLinkState != HCGHIPServiceLinkStateNotReported) {
        availability = HCGServiceLinkStatus(d, f, status, &capabilityReason);
    } else if (d.unavailableReason.length) {
        availability = HCGHIPAvailabilityNotAvailable;
        status.healthText = d.unavailableReason;
        status.compatibilityText = d.kind == HCGHIPProductKindService ? @"Runs on your computer, not on this iPhone" : @"No client for this iPhone yet";
        status.integrationText = @"Adapter prepared; nothing is connected.";
        capabilityReason = @"Nothing on this iPhone connects to it yet.";
    } else if (d.kind == HCGHIPProductKindRepository) {
        availability = f.hostCanInspect ? HCGHIPAvailabilityReady : HCGHIPAvailabilityUnknown;
        status.compatibilityText = f.packageManagers.count ? [NSString stringWithFormat:@"Package manager: %@", [[f.packageManagers componentsJoinedByString:@", "] capitalizedString]]
                                                           : (f.hostCanInspect ? @"No Zebra or Sileo found" : @"This app cannot see installed packages");
        status.healthText = f.hostCanInspect ? @"Reading installed versions and your package manager's lists" : @"Installed packages are private to this app";
        status.integrationText = @"Read-only. Nexus never installs, updates or removes packages.";
        if (!f.hostCanInspect) capabilityReason = @"This build cannot read package information.";
    } else if (!f.hostCanInspect) {
        availability = HCGHIPAvailabilityUnknown;
        status.compatibilityText = @"Unable to check here: iOS keeps installed apps private from this app";
        status.healthText = @"Not reported to this app";
        status.integrationText = f.canOpenScheme ? @"Opens through its own link" : @"Use the HCG Nexus jailbreak package to see it";
        if (!f.canOpenScheme) capabilityReason = @"This build cannot see whether it is installed.";
    } else if (!installed) {
        BOOL tooOld = d.minimumOSVersion.length && f.osVersion.length &&
                      [HCGDebianVersion compare:f.osVersion with:d.minimumOSVersion] == NSOrderedAscending;
        availability = tooOld ? HCGHIPAvailabilityUnsupportedOS : HCGHIPAvailabilityNotInstalled;
        status.compatibilityText = tooOld
            ? [NSString stringWithFormat:@"Requires iOS %@ or later; this iPhone runs iOS %@", d.minimumOSVersion, f.osVersion]
            : (d.minimumOSVersion.length ? [NSString stringWithFormat:@"Supported on this iPhone (needs iOS %@+)", d.minimumOSVersion] : @"");
        status.healthText = @"Not installed";
        status.integrationText = @"Nothing to connect to. Nexus works without it.";
        capabilityReason = tooOld ? [NSString stringWithFormat:@"Needs iOS %@ or later.", d.minimumOSVersion] : @"Not installed.";
    } else {
        // Installed.
        BOOL declaresScheme = d.urlScheme.length == 0 || HCGArrayContainsStringCaseInsensitive(f.declaredSchemes, d.urlScheme);
        BOOL tooOldForAdapter = d.integrationMinimumVersion.length && f.packageVersion.length &&
                                [HCGDebianVersion compare:f.packageVersion with:d.integrationMinimumVersion] == NSOrderedAscending;
        status.compatibilityText = @"Compatible";
        if (tooOldForAdapter) {
            availability = HCGHIPAvailabilityNeedsUpdate;
            status.compatibilityText = [NSString stringWithFormat:@"Nexus's integration needs %@ or later", d.integrationMinimumVersion];
        } else if (!declaresScheme) {
            availability = HCGHIPAvailabilityNeedsUpdate;
            status.compatibilityText = @"This version has no Nexus links (opening the app still works)";
        }
        NSString *state = d.statusRecordKey.length ? HCGStringValue([f.statusRecord objectForKey:d.statusRecordKey], @"state")
                                                   : HCGStringValue(f.statusRecord, @"state");
        HCGHIPAvailability health = HCGHIPAvailabilityReady;
        NSString *healthText = HCGHealthForState(state, &health);
        BOOL enabled = d.enabledByDefault;
        if (d.enabledKey.length) {
            id value = [f.preferences objectForKey:d.enabledKey];
            if ([value isKindOfClass:[NSNumber class]]) enabled = [value boolValue];
        }
        if (availability == HCGHIPAvailabilityReady) {
            if (health == HCGHIPAvailabilityAttention) availability = HCGHIPAvailabilityAttention;
            else if (d.enabledKey.length && !enabled) availability = HCGHIPAvailabilityOff;
        }
        if (!healthText) {
            if (d.kind == HCGHIPProductKindTweak) healthText = d.enabledKey.length && !enabled ? @"Off in its settings" : @"No status reported yet (respring after installing or updating)";
            else healthText = @"Apps report no status to Nexus";
        }
        if (d.enabledKey.length && !enabled && health != HCGHIPAvailabilityAttention) healthText = @"Off in its settings";
        status.healthText = healthText;
        if (availability == HCGHIPAvailabilityOff) capabilityReason = @"Switched off in its settings.";

        if (d.kind == HCGHIPProductKindApp) {
            status.integrationText = declaresScheme && d.urlScheme.length
                ? @"Navigation links only: Nexus never starts a session, sends a command or reads its data. Not \"connected\": it shares no session."
                : @"Opens the app. It shares no session with Nexus.";
        } else {
            status.integrationText = [d.productID isEqualToString:HCGHIPProductHalo]
                ? @"Read-only status and settings, plus the panel-border switch through HCG Halo's own API."
                : @"Read-only: its own status record and settings. Change settings in the Settings app.";
        }
    }

    // Updates offered by HCG Repo (as of the package manager's last refresh).
    status.offeredVersion = f.offeredVersion;
    if (installed && f.packageVersion.length && [HCGPackageIndex isUpdate:f.offeredVersion over:f.packageVersion]) {
        status.updateAvailable = YES;
        status.updateText = [NSString stringWithFormat:@"%@ available in HCG Repo (as of your package manager's last refresh)", f.offeredVersion];
    } else if (!installed && f.offeredVersion.length && availability == HCGHIPAvailabilityNotInstalled) {
        status.updateText = [NSString stringWithFormat:@"HCG Repo offers %@", f.offeredVersion];
    } else if (installed && f.packageVersion.length && f.offeredVersion.length) {
        status.updateText = @"Up to date with your package manager's lists";
    }
    status.availability = availability;
    status.stateTitle = [self titleForAvailability:availability];

    // Declaration (claims) from the installed product.
    NSString *problem = nil;
    NSSet *declaredRoutes = installed ? [self declaredRouteIdentifiersFromDeclaration:f.declaration descriptor:d problem:&problem] : [NSSet set];
    status.declarationNote = problem;
    NSSet *declaredCapabilities = installed ? [self declaredCapabilityIdentifiersFromDeclaration:f.declaration descriptor:d] : nil;

    // Routes.
    NSMutableArray *routes = [NSMutableArray array];
    NSMutableArray *notes = [NSMutableArray array];
    BOOL reachable = availability != HCGHIPAvailabilityNotAvailable;
    NSUInteger i;
    for (i = 0; reachable && i < d.routes.count; i++) {
        HCGHIPRoute *route = [d.routes objectAtIndex:i];
        if (HCGRouteUsable(route, d, f, declaredRoutes, installed)) {
            [routes addObject:route];
            continue;
        }
        HCGHIPRoute *fallback = route.fallbackRouteIdentifier ? [d routeWithIdentifier:route.fallbackRouteIdentifier] : nil;
        if (fallback && HCGRouteUsable(fallback, d, f, declaredRoutes, installed)) {
            // Same screen, one more tap: offered under its own name, honestly described.
            HCGHIPRoute *via = HCGRoute(route.identifier, route.title, route.symbolName, fallback.kind, fallback.target, fallback.requirement,
                                        [NSString stringWithFormat:@"Opens %@; tap %@ there. This version has no direct link.", fallback.title, route.title], nil);
            [routes addObject:via];
        } else if (installed && route.kind == HCGHIPRouteKindAppLink && route.requirement == HCGHIPRouteRequirementDeclaredRoute) {
            [notes addObject:[NSString stringWithFormat:@"%@: needs a newer build that declares it.", route.title]];
        }
    }
    status.routes = routes;
    status.routeNotes = notes;

    // Capabilities, resolved for this device.
    NSMutableArray *capabilities = [NSMutableArray array];
    for (i = 0; i < d.capabilities.count; i++) {
        HCGHIPCapability *capability = [d.capabilities objectAtIndex:i];
        HCGHIPResolvedCapability *resolved = [[HCGHIPResolvedCapability alloc] init];
        resolved.capability = capability;
        resolved.state = capability.state;
        resolved.reason = capability.note;
        BOOL usable = capability.state == HCGHIPCapabilityStateAvailable || capability.state == HCGHIPCapabilityStateVerified;
        BOOL pairingWhileDisconnected = d.kind == HCGHIPProductKindService && f.serviceLinkState != HCGHIPServiceLinkStateNotReported &&
                                        [capability.identifier isEqualToString:@"pairing"];
        if (usable && capabilityReason && !pairingWhileDisconnected) {
            resolved.state = availability == HCGHIPAvailabilityOff ? HCGHIPCapabilityStateDisabled : HCGHIPCapabilityStateUnavailable;
            resolved.reason = capabilityReason;
        } else if (usable && declaredCapabilities && ![declaredCapabilities containsObject:capability.identifier]) {
            resolved.state = HCGHIPCapabilityStateUnavailable;
            resolved.reason = @"The installed build does not declare it.";
        }
        [capabilities addObject:resolved];
    }
    status.capabilities = capabilities;

    // Read-only settings from the product's own preferences.
    if (installed && f.hostCanInspect) {
        NSMutableArray *readouts = [NSMutableArray array];
        for (i = 0; i < d.readouts.count; i++) {
            HCGHIPReadout *readout = [d.readouts objectAtIndex:i];
            [readouts addObject:[NSArray arrayWithObjects:readout.title, HCGReadoutText(readout, [f.preferences objectForKey:readout.key]), nil]];
        }
        status.readouts = readouts;
    }
    return status;
}

#pragma mark Links and names

+ (BOOL)isRegistryLink:(NSString *)urlText {
    if (![urlText isKindOfClass:[NSString class]] || urlText.length == 0) return NO;
    NSArray *registry = [self registry];
    NSUInteger i, j;
    for (i = 0; i < registry.count; i++) {
        HCGHIPProductDescriptor *d = [registry objectAtIndex:i];
        for (j = 0; j < d.routes.count; j++) {
            HCGHIPRoute *route = [d.routes objectAtIndex:j];
            if ((route.kind == HCGHIPRouteKindAppLink || route.kind == HCGHIPRouteKindWeb) && [route.target isEqualToString:urlText]) return YES;
        }
    }
    return NO;
}

+ (NSString *)openProductDarwinNotificationForProductID:(NSString *)productID {
    if (![self descriptorForProductID:productID]) return nil;
    return [HCGNexusOpenProductDarwinPrefix stringByAppendingString:productID];
}

+ (NSString *)productIDForOpenDarwinNotification:(NSString *)name {
    if (![name isKindOfClass:[NSString class]] || ![name hasPrefix:HCGNexusOpenProductDarwinPrefix]) return nil;
    NSString *productID = [name substringFromIndex:HCGNexusOpenProductDarwinPrefix.length];
    return [self descriptorForProductID:productID] ? productID : nil;
}

+ (NSString *)titleForAvailability:(HCGHIPAvailability)availability {
    switch (availability) {
        case HCGHIPAvailabilityReady: return @"Ready";
        case HCGHIPAvailabilityOff: return @"Off";
        case HCGHIPAvailabilityAttention: return @"Needs attention";
        case HCGHIPAvailabilityNeedsUpdate: return @"Needs update";
        case HCGHIPAvailabilityNotInstalled: return @"Not installed";
        case HCGHIPAvailabilityUnsupportedOS: return @"Not for this iOS";
        case HCGHIPAvailabilityUnknown: return @"Unable to check";
        case HCGHIPAvailabilityNotAvailable: return @"Not available yet";
        case HCGHIPAvailabilityHub: return @"This hub";
        case HCGHIPAvailabilityConnected: return @"Connected";
        case HCGHIPAvailabilityNotConnected: return @"Not connected";
        case HCGHIPAvailabilityUnreachable: return @"Unreachable";
    }
    return @"Unable to check";
}

+ (NSString *)titleForCapabilityState:(HCGHIPCapabilityState)state {
    switch (state) {
        case HCGHIPCapabilityStateAvailable: return @"Available";
        case HCGHIPCapabilityStateVerified: return @"Verified on a device";
        case HCGHIPCapabilityStateUnavailable: return @"Unavailable";
        case HCGHIPCapabilityStateDisabled: return @"Disabled";
        case HCGHIPCapabilityStatePlanned: return @"Planned";
    }
    return @"Unavailable";
}

+ (NSString *)packageManagerLinkForManager:(NSString *)manager packageIdentifier:(NSString *)packageIdentifier {
    if (![[self packageIdentifiers] containsObject:packageIdentifier]) return nil;
    if ([manager isEqualToString:@"zebra"]) return [@"zbra://packages/" stringByAppendingString:packageIdentifier];
    if ([manager isEqualToString:@"sileo"]) return [@"sileo://package/" stringByAppendingString:packageIdentifier];
    return nil;
}

@end

#pragma mark Activity

@implementation HCGEcosystemActivity

+ (NSDictionary *)entryWithText:(NSString *)text productID:(NSString *)productID time:(NSDate *)time {
    NSString *clean = HCGClip(text, 140);
    if (clean.length == 0 || [clean rangeOfString:@"://"].location != NSNotFound) return nil;
    NSMutableDictionary *entry = [NSMutableDictionary dictionary];
    [entry setObject:clean forKey:@"text"];
    [entry setObject:[NSNumber numberWithDouble:[(time ?: [NSDate date]) timeIntervalSince1970]] forKey:@"time"];
    if ([HCGInterchange descriptorForProductID:productID]) [entry setObject:productID forKey:@"product"];
    return entry;
}

+ (NSArray *)entriesFromStoredValue:(id)value {
    NSMutableArray *out = [NSMutableArray array];
    if (![value isKindOfClass:[NSArray class]]) return out;
    NSUInteger i;
    for (i = 0; i < [value count] && out.count < HCGEcosystemActivityLimit; i++) {
        id entry = [value objectAtIndex:i];
        if (![entry isKindOfClass:[NSDictionary class]]) continue;
        id text = [entry objectForKey:@"text"], time = [entry objectForKey:@"time"], product = [entry objectForKey:@"product"];
        if (![text isKindOfClass:[NSString class]] || ![time isKindOfClass:[NSNumber class]]) continue;
        NSDictionary *clean = [self entryWithText:text productID:[product isKindOfClass:[NSString class]] ? product : nil
                                             time:[NSDate dateWithTimeIntervalSince1970:[time doubleValue]]];
        if (clean) [out addObject:clean];
    }
    return out;
}

+ (NSArray *)entries:(NSArray *)entries byAdding:(NSDictionary *)entry {
    NSMutableArray *out = [NSMutableArray array];
    if ([entry isKindOfClass:[NSDictionary class]]) [out addObject:entry];
    NSArray *existing = [self entriesFromStoredValue:entries];
    NSUInteger i;
    for (i = 0; i < existing.count && out.count < HCGEcosystemActivityLimit; i++) [out addObject:[existing objectAtIndex:i]];
    return out;
}

@end
