#import "HCGTerminalHandoff.h"
#import "HCGIntegrations.h"

NSString *const HCGTerminalHandoffInfoKey = @"HCGNexusHandoff";
const NSInteger HCGTerminalSupportedHandoffVersion = 1;
const NSUInteger HCGTerminalLinkMaximumLength = 256;

@implementation HCGTerminalAppFacts
@synthesize variant = _variant, installedKnown = _installedKnown, installed = _installed, version = _version,
            urlSchemes = _urlSchemes, handoffVersion = _handoffVersion, canLaunchByBundle = _canLaunchByBundle,
            canOpenScheme = _canOpenScheme;
@end

@interface HCGTerminalStatus ()
- (instancetype)initWithVariant:(HCGTerminalVariant)variant installed:(NSString *)installed launch:(NSString *)launch
                    integration:(NSString *)integration launchAvailable:(BOOL)launchAvailable
           integrationAvailable:(BOOL)integrationAvailable;
@end

@implementation HCGTerminalStatus
@synthesize variant = _variant, installedText = _installedText, launchText = _launchText, integrationText = _integrationText,
            sessionText = _sessionText, launchAvailable = _launchAvailable, integrationAvailable = _integrationAvailable;

- (instancetype)initWithVariant:(HCGTerminalVariant)variant installed:(NSString *)installed launch:(NSString *)launch
                    integration:(NSString *)integration launchAvailable:(BOOL)launchAvailable
           integrationAvailable:(BOOL)integrationAvailable {
    if ((self = [super init])) {
        _variant = variant;
        _installedText = [installed copy];
        _launchText = [launch copy];
        _integrationText = [integration copy];
        _sessionText = @"Not shared: HCG Terminal does not report sessions to Nexus, so Nexus never shows it as connected.";
        _launchAvailable = launchAvailable;
        _integrationAvailable = integrationAvailable;
    }
    return self;
}
@end

static BOOL HCGIsLowerHex(unichar c) {
    return (c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F');
}

static BOOL HCGIsUUIDString(NSString *s) {
    if (s.length != 36) return NO;
    for (NSUInteger i = 0; i < 36; i++) {
        unichar c = [s characterAtIndex:i];
        BOOL dash = (i == 8 || i == 13 || i == 18 || i == 23);
        if (dash ? c != '-' : !HCGIsLowerHex(c)) return NO;
    }
    return YES;
}

@implementation HCGTerminalHandoff

+ (NSString *)bundleIdentifierForVariant:(HCGTerminalVariant)variant {
    if (variant == HCGTerminalVariantStandard) return HCGTerminalBundleIdentifier;
    if (variant == HCGTerminalVariantUnleashed) return HCGTerminalUnleashedBundleIdentifier;
    return @"";
}

+ (NSString *)urlSchemeForVariant:(HCGTerminalVariant)variant {
    if (variant == HCGTerminalVariantStandard) return @"hcgterminal";
    if (variant == HCGTerminalVariantUnleashed) return @"hcgterminal-unleashed";
    return @"";
}

+ (NSString *)displayNameForVariant:(HCGTerminalVariant)variant {
    if (variant == HCGTerminalVariantStandard) return @"HCG Terminal";
    if (variant == HCGTerminalVariantUnleashed) return @"HCG Terminal Unleashed";
    return @"HCG Terminal";
}

+ (HCGTerminalVariant)variantForBundleIdentifier:(NSString *)bundleIdentifier {
    if ([bundleIdentifier isEqualToString:HCGTerminalBundleIdentifier]) return HCGTerminalVariantStandard;
    if ([bundleIdentifier isEqualToString:HCGTerminalUnleashedBundleIdentifier]) return HCGTerminalVariantUnleashed;
    return HCGTerminalVariantNone;
}

+ (BOOL)facts:(HCGTerminalAppFacts *)facts declaresScheme:(NSString *)scheme {
    for (id s in facts.urlSchemes) {
        if ([s isKindOfClass:[NSString class]] && [(NSString *)s isEqualToString:scheme]) return YES;
    }
    return NO;
}

+ (HCGTerminalStatus *)statusWithFacts:(HCGTerminalAppFacts *)facts {
    HCGTerminalVariant variant = facts.variant;
    NSString *name = [self displayNameForVariant:variant];
    NSString *scheme = [self urlSchemeForVariant:variant];

    if (!facts.installedKnown) {
        // Sandboxed host (standalone app): only "can this link be opened" is knowable.
        BOOL viaLink = facts.canOpenScheme;
        return [[HCGTerminalStatus alloc] initWithVariant:variant
                                                installed:@"Unable to determine: iOS keeps installed apps private from this app"
                                                   launch:viaLink ? @"Available through its link" : @"Not available here"
                                              integration:viaLink ? @"Saved-connection handoff available" : @"Unable to determine"
                                          launchAvailable:viaLink integrationAvailable:viaLink];
    }
    if (!facts.installed) {
        return [[HCGTerminalStatus alloc] initWithVariant:variant installed:@"Not installed"
                                                   launch:@"Not available: not installed"
                                              integration:@"Not available: not installed"
                                          launchAvailable:NO integrationAvailable:NO];
    }
    NSString *installed = facts.version.length ? [@"Installed · " stringByAppendingString:facts.version] : @"Installed";
    BOOL launch = facts.canLaunchByBundle || facts.canOpenScheme;
    NSString *launchText = facts.canLaunchByBundle ? @"Available" : (facts.canOpenScheme ? @"Available through its link" : @"Not available on this iOS");

    BOOL declares = [self facts:facts declaresScheme:scheme];
    NSString *integration;
    BOOL integrationAvailable = NO;
    if (facts.handoffVersion == HCGTerminalSupportedHandoffVersion && declares) {
        integration = @"Saved-connection handoff available";
        integrationAvailable = YES;
    } else if (facts.handoffVersion > HCGTerminalSupportedHandoffVersion && declares) {
        integration = [NSString stringWithFormat:@"Not available: %@ uses handoff version %ld; update HCG Nexus", name, (long)facts.handoffVersion];
    } else {
        NSString *v = facts.version.length ? [@" " stringByAppendingString:facts.version] : @"";
        integration = [NSString stringWithFormat:@"Not in %@%@: it has no Nexus handoff yet (opening the app works)", name, v];
    }
    return [[HCGTerminalStatus alloc] initWithVariant:variant installed:installed launch:launchText integration:integration
                                      launchAvailable:launch integrationAvailable:integrationAvailable];
}

+ (HCGTerminalVariant)variantToUseWithStandard:(HCGTerminalAppFacts *)standard unleashed:(HCGTerminalAppFacts *)unleashed
                                     preferred:(HCGTerminalVariant)preferred {
    BOOL s = standard.installedKnown ? standard.installed : standard.canOpenScheme;
    BOOL u = unleashed.installedKnown ? unleashed.installed : unleashed.canOpenScheme;
    if (s && u) return preferred == HCGTerminalVariantUnleashed ? HCGTerminalVariantUnleashed : HCGTerminalVariantStandard;
    if (s) return HCGTerminalVariantStandard;
    if (u) return HCGTerminalVariantUnleashed;
    return HCGTerminalVariantNone;
}

+ (NSURL *)openURLForVariant:(HCGTerminalVariant)variant {
    NSString *scheme = [self urlSchemeForVariant:variant];
    if (!scheme.length) return nil;
    return [NSURL URLWithString:[scheme stringByAppendingString:@"://open"]];
}

+ (NSString *)validatedConnectionLink:(NSString *)text variant:(HCGTerminalVariant *)variantOut reason:(NSString **)reason {
    if (variantOut) *variantOut = HCGTerminalVariantNone;
    if (![text isKindOfClass:[NSString class]] || text.length == 0) {
        if (reason) *reason = @"Paste a link copied from HCG Terminal (Copy Link for HCG Nexus).";
        return nil;
    }
    if (text.length > HCGTerminalLinkMaximumLength) {
        if (reason) *reason = @"That link is too long to be an HCG Terminal saved-connection link.";
        return nil;
    }
    HCGTerminalVariant variants[2] = { HCGTerminalVariantUnleashed, HCGTerminalVariantStandard }; // longer scheme first
    for (int i = 0; i < 2; i++) {
        NSString *prefix = [[self urlSchemeForVariant:variants[i]] stringByAppendingString:@"://connection?id="];
        if (![text hasPrefix:prefix]) continue;
        NSString *identifier = [text substringFromIndex:prefix.length];
        if (!HCGIsUUIDString(identifier)) {
            if (reason) *reason = @"The link must name one saved connection (id=<UUID>) and nothing else.";
            return nil;
        }
        if (variantOut) *variantOut = variants[i];
        return [prefix stringByAppendingString:identifier];
    }
    if (reason) *reason = @"Only saved-connection links from HCG Terminal (hcgterminal://connection?id=…) are accepted.";
    return nil;
}

@end
