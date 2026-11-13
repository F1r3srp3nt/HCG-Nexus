#import "HCGIntegrations.h"
#import "HCGSettings.h"

NSString *const HCGIntegrationTerminal = @"terminal";
NSString *const HCGIntegrationServer = @"server";
NSString *const HCGIntegrationNews = @"news";
NSString *const HCGIntegrationExecutableMaker = @"executable-maker";

NSString *const HCGTerminalBundleIdentifier = @"com.hakmicapitalgroup.hcgterminal";
NSString *const HCGTerminalUnleashedBundleIdentifier = @"com.hakmicapitalgroup.hcgterminal.unleashed";
NSString *const HCGNewsBundleIdentifier = @"com.hakmicapitalgroup.hcgnews";

static NSString *const kNotConnected = @"Not connected";

@implementation HCGIntegrationStatus

@synthesize identifier = _identifier;
@synthesize displayName = _displayName;
@synthesize symbolName = _symbolName;
@synthesize state = _state;
@synthesize headline = _headline;
@synthesize detail = _detail;
@synthesize launchBundleIdentifier = _launchBundleIdentifier;

- (BOOL)canLaunch {
    return (self.state == HCGIntegrationStateReady || self.state == HCGIntegrationStateUnverified)
        && self.launchBundleIdentifier.length > 0;
}

@end

@implementation HCGIntegrationCatalog

+ (NSArray *)allIdentifiers {
    return [NSArray arrayWithObjects:HCGIntegrationTerminal, HCGIntegrationServer, HCGIntegrationNews, HCGIntegrationExecutableMaker, nil];
}

+ (NSString *)displayNameForIdentifier:(NSString *)identifier {
    if ([identifier isEqualToString:HCGIntegrationTerminal]) return @"HCG Terminal";
    if ([identifier isEqualToString:HCGIntegrationServer]) return @"HCG Server";
    if ([identifier isEqualToString:HCGIntegrationNews]) return @"HCG News";
    if ([identifier isEqualToString:HCGIntegrationExecutableMaker]) return @"Executable Maker";
    return nil;
}

+ (NSString *)symbolNameForIdentifier:(NSString *)identifier {
    if ([identifier isEqualToString:HCGIntegrationTerminal]) return @"terminal";
    if ([identifier isEqualToString:HCGIntegrationServer]) return @"server.rack";
    if ([identifier isEqualToString:HCGIntegrationNews]) return @"newspaper";
    if ([identifier isEqualToString:HCGIntegrationExecutableMaker]) return @"hammer";
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

    if ([identifier isEqualToString:HCGIntegrationTerminal]) {
        NSString *bundle = nil;
        if (settings.terminalVariant == HCGTerminalVariantStandard) bundle = HCGTerminalBundleIdentifier;
        if (settings.terminalVariant == HCGTerminalVariantUnleashed) bundle = HCGTerminalUnleashedBundleIdentifier;
        if (bundle == nil) {
            status.detail = @"Choose HCG Terminal or HCG Terminal Unleashed in HCG Nexus settings. Nexus can open the app; HCG Terminal publishes no deep links or status interface.";
            return status;
        }
        [self applyAppBundle:bundle toStatus:status probe:probe
                 openingNote:@"Opens the app. HCG Terminal publishes no deep links, so sessions and build history stay inside the app."];
        return status;
    }

    if ([identifier isEqualToString:HCGIntegrationNews]) {
        if (!settings.newsConnected) {
            status.detail = @"Turn on HCG News in HCG Nexus settings to open the app from the panel. Headlines are unavailable: the HCG News content API is not deployed.";
            return status;
        }
        [self applyAppBundle:HCGNewsBundleIdentifier toStatus:status probe:probe
                 openingNote:@"Opens the app. No headlines are shown because the HCG News content API is still a proposal."];
        return status;
    }

    if ([identifier isEqualToString:HCGIntegrationServer]) {
        status.detail = @"HCG Server's admin API is only reachable on the host Mac's loopback interface and requires its local admin token. Nexus will not store that token; a phone connection needs an HCG Connect-authorised interface that does not exist yet.";
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
    NSArray *identifiers = [self allIdentifiers];
    NSUInteger i;
    for (i = 0; i < identifiers.count; i++) {
        [result addObject:[self statusForIdentifier:[identifiers objectAtIndex:i] settings:settings probe:probe]];
    }
    return result;
}

@end
