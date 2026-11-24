#import "HCGTerminalHandoff.h"
#import "HCGIntegrations.h"
#import "HCGInterchange.h"

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
    if (variant == HCGTerminalVariantUnleashed) return @"HCG Terminal Unleashed";
    return @"HCG Terminal";
}

+ (HCGTerminalVariant)variantForBundleIdentifier:(NSString *)bundleIdentifier {
    if ([bundleIdentifier isEqualToString:HCGTerminalBundleIdentifier]) return HCGTerminalVariantStandard;
    if ([bundleIdentifier isEqualToString:HCGTerminalUnleashedBundleIdentifier]) return HCGTerminalVariantUnleashed;
    return HCGTerminalVariantNone;
}

+ (NSString *)productIDForVariant:(HCGTerminalVariant)variant {
    if (variant == HCGTerminalVariantStandard) return HCGHIPProductTerminal;
    if (variant == HCGTerminalVariantUnleashed) return HCGHIPProductTerminalUnleashed;
    return nil;
}

+ (NSURL *)openURLForVariant:(HCGTerminalVariant)variant {
    NSString *scheme = [self urlSchemeForVariant:variant];
    if (!scheme.length) return nil;
    return [NSURL URLWithString:[scheme stringByAppendingString:@"://open/dashboard"]];
}

+ (BOOL)isTerminalLinkText:(NSString *)text {
    if (![text isKindOfClass:[NSString class]]) return NO;
    NSString *lower = [text lowercaseString];
    return [lower hasPrefix:@"hcgterminal://"] || [lower hasPrefix:@"hcgterminal-unleashed://"];
}

+ (NSString *)problemWithLinkText:(NSString *)text {
    if (![self isTerminalLinkText:text]) return @"Not an HCG Terminal link.";
    if (text.length > 96) return @"That link is too long to be an HCG Terminal link.";
    if ([HCGInterchange isRegistryLink:text]) return nil;
    return @"HCG Terminal links only open one of its screens: <scheme>://open/<screen>, for example hcgterminal-unleashed://open/tools. Nothing else is accepted.";
}

@end
