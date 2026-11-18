#import "HCGProductCatalog.h"

NSString *const HCGProductTerminal = @"product.terminal";
NSString *const HCGProductTerminalUnleashed = @"product.terminal.unleashed";
NSString *const HCGProductNews = @"product.news";
NSString *const HCGProductSentinel = @"product.sentinel";
NSString *const HCGProductServer = @"product.server";
NSString *const HCGProductExecutableMaker = @"product.executablemaker";

@implementation HCGProductInfo
@synthesize identifier = _identifier;
@synthesize name = _name;
@synthesize symbolName = _symbolName;
@synthesize platform = _platform;
@synthesize bundleIdentifier = _bundleIdentifier;
@synthesize integrationIdentifier = _integrationIdentifier;
@synthesize routesSummary = _routesSummary;
@synthesize noPhoneAppNextStep = _noPhoneAppNextStep;

- (BOOL)hasPhoneApp {
    return self.bundleIdentifier.length > 0;
}
@end

static HCGProductInfo *HCGProduct(NSString *identifier, NSString *name, NSString *symbol, NSString *platform, NSString *bundle,
                                  NSString *integration, NSString *routes, NSString *noPhoneNext) {
    HCGProductInfo *product = [[HCGProductInfo alloc] init];
    product.identifier = identifier;
    product.name = name;
    product.symbolName = symbol;
    product.platform = platform;
    product.bundleIdentifier = bundle;
    product.integrationIdentifier = integration;
    product.routesSummary = routes;
    product.noPhoneAppNextStep = noPhoneNext;
    return product;
}

@implementation HCGProductCatalog

+ (NSArray *)allProducts {
    return [NSArray arrayWithObjects:
        HCGProduct(HCGProductTerminal, @"HCG Terminal", @"terminal", @"iPhone & iPad app", HCGTerminalBundleIdentifier, HCGIntegrationTerminal,
                   @"Opens the app. HCG Terminal publishes no deep links.", nil),
        HCGProduct(HCGProductTerminalUnleashed, @"HCG Terminal Unleashed", @"terminal.fill", @"Jailbreak edition app", HCGTerminalUnleashedBundleIdentifier,
                   HCGIntegrationTerminal, @"Opens the app. No deep links.", nil),
        HCGProduct(HCGProductNews, @"HCG News", @"newspaper", @"iPhone & iPad app", HCGNewsBundleIdentifier, HCGIntegrationNews,
                   @"Opens the app. HCG News publishes no deep links; headlines are not available to Nexus.", nil),
        HCGProduct(HCGProductSentinel, @"HCG Sentinel", @"shield.lefthalf.filled", @"iPhone & iPad app", HCGSentinelBundleIdentifier, HCGIntegrationSentinel,
                   @"Opens the app, or one of its screens with hcgsentinel://open/<section> (navigation only, validated with Sentinel's own rules).", nil),
        HCGProduct(HCGProductServer, @"HCG Server", @"server.rack", @"macOS/Linux service", nil, nil,
                   @"No iPhone app. Its admin interface is loopback-only on the host Mac.",
                   @"Pair with your HCG Server through Connected Devices in the standalone HCG Nexus app (HCG Device Link)."),
        HCGProduct(HCGProductExecutableMaker, @"HCG Executable Maker", @"hammer", @"Desktop app (Windows, macOS, Linux)", nil, nil,
                   @"No iPhone app and no phone-reachable build-status interface.",
                   @"Use Executable Maker on your computer. Nexus does not show its build status."),
        nil];
}

+ (HCGProductInfo *)productWithIdentifier:(NSString *)identifier {
    NSArray *products = [self allProducts];
    NSUInteger i;
    for (i = 0; i < products.count; i++) {
        if ([[[products objectAtIndex:i] identifier] isEqualToString:identifier]) return [products objectAtIndex:i];
    }
    return nil;
}

+ (HCGProductInstallState)installStateForProduct:(HCGProductInfo *)product probe:(id<HCGAppInstallationProbe>)probe {
    if (!product.hasPhoneApp) return HCGProductInstallStateNotPhoneApp;
    if (probe == nil || ![probe canDetermineInstallation]) return HCGProductInstallStateUnknown;
    return [probe isApplicationInstalled:product.bundleIdentifier] ? HCGProductInstallStateInstalled : HCGProductInstallStateNotInstalled;
}

+ (HCGProductLaunchState)launchStateForProduct:(HCGProductInfo *)product probe:(id<HCGAppInstallationProbe>)probe {
    if (!product.hasPhoneApp) return HCGProductLaunchStateNoPhoneApp;
    if (probe == nil || ![probe canLaunchApplicationsByBundleIdentifier]) return HCGProductLaunchStateUnavailableHere;
    switch ([self installStateForProduct:product probe:probe]) {
        case HCGProductInstallStateInstalled: return HCGProductLaunchStateAvailable;
        case HCGProductInstallStateNotInstalled: return HCGProductLaunchStateAppMissing;
        default: return HCGProductLaunchStateAttempt;
    }
}

+ (NSString *)titleForInstallState:(HCGProductInstallState)state {
    switch (state) {
        case HCGProductInstallStateInstalled: return @"Installed";
        case HCGProductInstallStateNotInstalled: return @"Not installed";
        case HCGProductInstallStateUnknown: return @"Unable to determine";
        case HCGProductInstallStateNotPhoneApp: return @"No iPhone app";
    }
    return @"Unable to determine";
}

+ (NSString *)nextStepForProduct:(HCGProductInfo *)product launchState:(HCGProductLaunchState)state {
    switch (state) {
        case HCGProductLaunchStateAvailable:
            return [NSString stringWithFormat:@"Tap Open to launch %@.", product.name];
        case HCGProductLaunchStateAttempt:
            return [NSString stringWithFormat:@"Installation can't be checked here. Open will try %@ and report the result.", product.name];
        case HCGProductLaunchStateAppMissing:
            return [NSString stringWithFormat:@"%@ is not installed on this device. Install it, then come back.", product.name];
        case HCGProductLaunchStateUnavailableHere:
            return @"This build can't open other apps by bundle identifier (the iOS sandbox). The HCG Nexus jailbreak package can.";
        case HCGProductLaunchStateNoPhoneApp:
            return product.noPhoneAppNextStep ?: @"This product has no iPhone app.";
    }
    return @"";
}

+ (NSString *)accountStateTextForProduct:(HCGProductInfo *)product {
    if (!product.hasPhoneApp) return @"Not applicable on this phone";
    return @"Not shared: the app does not publish its HCG sign-in state to Nexus";
}

@end
