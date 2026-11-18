#import "HCGIntegrations.h"
#import "HCGSettings.h"

NSString *const HCGIntegrationTerminal = @"terminal";
NSString *const HCGIntegrationServer = @"server";
NSString *const HCGIntegrationNews = @"news";
NSString *const HCGIntegrationExecutableMaker = @"executable-maker";
NSString *const HCGIntegrationSentinel = @"sentinel";

NSString *const HCGTerminalBundleIdentifier = @"com.hakmicapitalgroup.hcgterminal";
NSString *const HCGTerminalUnleashedBundleIdentifier = @"com.hakmicapitalgroup.hcgterminal.unleashed";
NSString *const HCGNewsBundleIdentifier = @"com.hakmicapitalgroup.hcgnews";
NSString *const HCGSentinelBundleIdentifier = @"com.hcg.sentinel";
NSString *const HCGSentinelURLScheme = @"hcgsentinel";

static NSString *const kNotConnected = @"Not connected";

@implementation HCGIntegrationStatus

@synthesize identifier = _identifier;
@synthesize displayName = _displayName;
@synthesize symbolName = _symbolName;
@synthesize state = _state;
@synthesize headline = _headline;
@synthesize detail = _detail;
@synthesize launchBundleIdentifier = _launchBundleIdentifier;
@synthesize recognized = _recognized;
@synthesize contractAvailable = _contractAvailable;
@synthesize configured = _configured;
@synthesize reachability = _reachability;
@synthesize session = _session;

- (BOOL)canLaunch {
    return (self.state == HCGIntegrationStateReady || self.state == HCGIntegrationStateUnverified)
        && self.launchBundleIdentifier.length > 0;
}

@end

@implementation HCGIntegrationCatalog

+ (NSArray *)allIdentifiers {
    return [NSArray arrayWithObjects:HCGIntegrationTerminal, HCGIntegrationServer, HCGIntegrationNews, HCGIntegrationExecutableMaker, HCGIntegrationSentinel, nil];
}

+ (NSArray *)offeredIdentifiers {
    return [NSArray arrayWithObjects:HCGIntegrationTerminal, HCGIntegrationNews, HCGIntegrationSentinel, nil];
}

+ (NSString *)displayNameForIdentifier:(NSString *)identifier {
    if ([identifier isEqualToString:HCGIntegrationTerminal]) return @"HCG Terminal";
    if ([identifier isEqualToString:HCGIntegrationServer]) return @"HCG Server";
    if ([identifier isEqualToString:HCGIntegrationNews]) return @"HCG News";
    if ([identifier isEqualToString:HCGIntegrationExecutableMaker]) return @"Executable Maker";
    if ([identifier isEqualToString:HCGIntegrationSentinel]) return @"HCG Sentinel";
    return nil;
}

+ (NSString *)symbolNameForIdentifier:(NSString *)identifier {
    if ([identifier isEqualToString:HCGIntegrationTerminal]) return @"terminal";
    if ([identifier isEqualToString:HCGIntegrationServer]) return @"server.rack";
    if ([identifier isEqualToString:HCGIntegrationNews]) return @"newspaper";
    if ([identifier isEqualToString:HCGIntegrationExecutableMaker]) return @"hammer";
    if ([identifier isEqualToString:HCGIntegrationSentinel]) return @"checkmark.shield";
    return @"questionmark.square.dashed";
}

+ (HCGIntegrationStatus *)baseStatusForIdentifier:(NSString *)identifier {
    HCGIntegrationStatus *status = [[HCGIntegrationStatus alloc] init];
    status.identifier = identifier;
    status.displayName = [self displayNameForIdentifier:identifier] ?: identifier;
    status.symbolName = [self symbolNameForIdentifier:identifier];
    status.state = HCGIntegrationStateNotConnected;
    status.headline = kNotConnected;
    status.detail = @"";
    status.recognized = [[self allIdentifiers] containsObject:identifier];
    status.contractAvailable = NO;
    status.configured = NO;
    status.reachability = HCGIntegrationReachabilityUnknown;
    status.session = HCGIntegrationSessionUnknown;
    return status;
}

+ (void)applyAppBundle:(NSString *)bundleIdentifier
              toStatus:(HCGIntegrationStatus *)status
                 probe:(id<HCGAppInstallationProbe>)probe
           openingNote:(NSString *)openingNote {
    status.launchBundleIdentifier = bundleIdentifier;
    if (probe != nil && ![probe canLaunchApplicationsByBundleIdentifier]) {
        status.state = HCGIntegrationStateUnavailableHere;
        status.headline = @"Needs jailbreak package";
        status.detail = [NSString stringWithFormat:@"This build cannot open other apps by bundle identifier (%@). iOS only lets ordinary apps open links; opening apps directly needs the HCG Nexus jailbreak package.", bundleIdentifier];
        return;
    }
    if (probe == nil || ![probe canDetermineInstallation]) {
        status.state = HCGIntegrationStateUnverified;
        status.headline = @"Configured";
        status.detail = [NSString stringWithFormat:@"Installation of %@ could not be checked in this environment. %@", bundleIdentifier, openingNote];
    } else if ([probe isApplicationInstalled:bundleIdentifier]) {
        status.state = HCGIntegrationStateReady;
        status.headline = @"Ready";
        status.detail = openingNote;
    } else {
        status.state = HCGIntegrationStateAppMissing;
        status.headline = @"App not installed";
        status.detail = [NSString stringWithFormat:@"%@ is not installed. Install it, or turn this integration off in HCG Nexus settings.", bundleIdentifier];
    }
}

+ (HCGIntegrationStatus *)statusForIdentifier:(NSString *)identifier settings:(HCGSettings *)settings probe:(id<HCGAppInstallationProbe>)probe {
    HCGIntegrationStatus *status = [self baseStatusForIdentifier:identifier];

    if ([identifier isEqualToString:HCGIntegrationTerminal] || [identifier isEqualToString:HCGIntegrationNews]) {
        // App-launch integrations: Nexus opens the app. There is no service
        // for Nexus to reach and no Nexus-held session to sign in to.
        status.contractAvailable = YES;
        status.reachability = HCGIntegrationReachabilityNotApplicable;
        status.session = HCGIntegrationSessionNotApplicable;
    }

    if ([identifier isEqualToString:HCGIntegrationTerminal]) {
        NSString *bundle = nil;
        if (settings.terminalVariant == HCGTerminalVariantStandard) bundle = HCGTerminalBundleIdentifier;
        if (settings.terminalVariant == HCGTerminalVariantUnleashed) bundle = HCGTerminalUnleashedBundleIdentifier;
        if (bundle == nil) {
            status.detail = @"Choose HCG Terminal or HCG Terminal Unleashed in HCG Nexus settings. Nexus opens the app; HCG Terminal reports no session state to Nexus.";
            return status;
        }
        status.configured = YES;
        [self applyAppBundle:bundle toStatus:status probe:probe
                 openingNote:@"Opens the app; it never runs a command. Saved-connection links need an HCG Terminal build with the Nexus handoff. Sessions stay inside HCG Terminal."];
        return status;
    }

    if ([identifier isEqualToString:HCGIntegrationNews]) {
        if (!settings.newsConnected) {
            status.detail = @"Turn on HCG News in HCG Nexus settings to open the app from the panel. Headlines are unavailable: the HCG News content API is not deployed.";
            return status;
        }
        status.configured = YES;
        [self applyAppBundle:HCGNewsBundleIdentifier toStatus:status probe:probe
                 openingNote:@"Opens the app. No headlines are shown because the HCG News content API is still a proposal."];
        return status;
    }

    if ([identifier isEqualToString:HCGIntegrationSentinel]) {
        if (!settings.sentinelConnected) {
            status.detail = @"Turn on HCG Sentinel in HCG Nexus settings to open the app from the panel. Shortcuts can open Sentinel's own screens with hcgsentinel://open/<section> links, which only navigate. Sentinel publishes no status yet, so none is shown.";
            return status;
        }
        [self applyAppBundle:HCGSentinelBundleIdentifier toStatus:status probe:probe
                 openingNote:@"Opens HCG Sentinel. Status is not available: Sentinel does not publish a status snapshot yet, so Nexus shows no activity and never reports it as connected."];
        return status;
    }

    if ([identifier isEqualToString:HCGIntegrationServer]) {
        status.detail = @"Nexus never uses HCG Server's admin API or its local admin token. In the standalone HCG Nexus app, Settings › Connected Devices pairs with an HCG Server through HCG Device Link (HCG Connect sign-in, owner approval). The jailbreak package does not connect to HCG Server.";
        return status;
    }

    if ([identifier isEqualToString:HCGIntegrationExecutableMaker]) {
        status.detail = @"Executable Maker is a desktop app that keeps build status in a local database. It publishes no build-status interface a phone can read, so no build status is shown.";
        return status;
    }

    status.detail = @"Unknown integration.";
    return status;
}

+ (NSArray *)allStatusesWithSettings:(HCGSettings *)settings probe:(id<HCGAppInstallationProbe>)probe {
    NSMutableArray *result = [[NSMutableArray alloc] init];
    NSArray *identifiers = [self offeredIdentifiers];
    NSUInteger i;
    for (i = 0; i < identifiers.count; i++) {
        [result addObject:[self statusForIdentifier:[identifiers objectAtIndex:i] settings:settings probe:probe]];
    }
    return result;
}

@end

@implementation HCGSentinelLinks

+ (NSArray *)sections {
    return [NSArray arrayWithObjects:@"dashboard", @"network", @"networkCheck", @"securityLab", @"bluetooth", @"radio",
                                     @"requests", @"capabilities", @"settings", nil];
}

+ (NSURL *)URLForSection:(NSString *)section {
    NSArray *sections = [self sections];
    NSUInteger i;
    for (i = 0; i < sections.count; i++) {
        NSString *known = [sections objectAtIndex:i];
        if ([known caseInsensitiveCompare:section] == NSOrderedSame) {
            return [NSURL URLWithString:[NSString stringWithFormat:@"%@://open/%@", HCGSentinelURLScheme, known]];
        }
    }
    return nil;
}

static BOOL HCGIsUUIDString(NSString *s) {
    if (s.length != 36) return NO;
    NSUInteger i;
    for (i = 0; i < 36; i++) {
        unichar c = [s characterAtIndex:i];
        BOOL dash = (i == 8 || i == 13 || i == 18 || i == 23);
        if (dash) { if (c != '-') return NO; continue; }
        if (!((c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F'))) return NO;
    }
    return YES;
}

+ (NSString *)problemWithURLString:(NSString *)string {
    NSURL *url = [NSURL URLWithString:string];
    if (url == nil || [[url.scheme lowercaseString] isEqualToString:HCGSentinelURLScheme] == NO) return @"Not an HCG Sentinel link.";
    if (url.query != nil || url.fragment != nil || url.user != nil || url.password != nil || url.port != nil)
        return @"HCG Sentinel links have no query, fragment, user, password or port.";
    NSString *host = [url.host lowercaseString];
    NSMutableArray *parts = [NSMutableArray array];
    NSArray *raw = [url.path componentsSeparatedByString:@"/"];
    NSUInteger i;
    for (i = 0; i < raw.count; i++) if ([[raw objectAtIndex:i] length] > 0) [parts addObject:[raw objectAtIndex:i]];
    if (parts.count != 1) return @"HCG Sentinel links have exactly one path component.";
    NSString *last = [parts objectAtIndex:0];
    if ([host isEqualToString:@"open"]) {
        return [self URLForSection:last] != nil ? nil
            : [NSString stringWithFormat:@"\"%@\" is not an HCG Sentinel screen. Use one of: %@.", last, [[self sections] componentsJoinedByString:@", "]];
    }
    if ([host isEqualToString:@"report"]) {
        return HCGIsUUIDString(last) ? nil : @"An HCG Sentinel report link needs the report's UUID.";
    }
    return @"HCG Sentinel accepts only hcgsentinel://open/<screen> and hcgsentinel://report/<uuid>. Links never start an operation.";
}

@end
