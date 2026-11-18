#import "HCGAccount.h"

NSString *const HCGAccountIntegrationKey = @"hcg.nexus";
NSString *const HCGAccountProposedRedirectURI = @"com.hakmicapitalgroup.hcgnexus.app://auth/callback";
NSString *const HCGAccountScopes = @"openid email profile";

NSString *const HCGAccountSummaryState = @"state";
NSString *const HCGAccountSummaryDisplayName = @"displayName";
NSString *const HCGAccountSummaryOrganisation = @"organisation";
NSString *const HCGAccountSummaryUpdated = @"updated";

static NSString *const kRedirectScheme = @"com.hakmicapitalgroup.hcgnexus.app";

@implementation HCGAccountConfiguration

@synthesize clientID = _clientID;
@synthesize redirectURI = _redirectURI;
@synthesize problem = _problem;

+ (BOOL)isKnownForeignClientID:(NSString *)clientID {
    // Issued to other HCG products (main-site registry, 17 Nov 2026). Prefixes where only a prefix is published.
    NSArray *foreign = [NSArray arrayWithObjects:
        @"fb9b6edf-2bfc-4b5e-a354-dbb1af697029", // HCG Executable Maker (production)
        @"af487795-ead1-4671-8b09-76301762ee2c", // HCG Store (development)
        @"94e51fe2-ba09-426d-8b41-8d36bf0dcac5", // HCG Store (production)
        @"f883ee38-3a62-431e-b5bf-4a563f59b765", // HCG AI iOS
        @"83527b77-", @"fbcbe4dc-", @"7195e34d-", @"3eb7b66b-", // HCG AI web, LifeOS beta/release, CardX
        nil];
    NSString *lower = [clientID lowercaseString];
    NSUInteger i;
    for (i = 0; i < foreign.count; i++) {
        if ([lower hasPrefix:[foreign objectAtIndex:i]]) return YES;
    }
    return NO;
}

static BOOL HCGIsUUID(NSString *value) {
    NSRegularExpression *re = [NSRegularExpression regularExpressionWithPattern:@"^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$"
                                                                        options:0 error:NULL];
    return [re numberOfMatchesInString:value options:0 range:NSMakeRange(0, value.length)] == 1;
}

+ (instancetype)configurationWithClientID:(id)clientID redirectURI:(id)redirectURI {
    HCGAccountConfiguration *config = [[self alloc] init];
    NSString *client = [clientID isKindOfClass:[NSString class]] ? [clientID stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] : @"";
    NSString *redirect = [redirectURI isKindOfClass:[NSString class]] ? [redirectURI stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] : @"";
    config->_clientID = [client copy];
    config->_redirectURI = [redirect copy];
    NSString *problem = nil;
    if (client.length == 0) {
        problem = @"HCG has not issued an HCG Connect client for HCG Nexus yet. Sign-in stays off; local features work without it.";
    } else if (!HCGIsUUID(client)) {
        problem = @"The configured HCG Connect client ID is not a valid client ID.";
    } else if ([self isKnownForeignClientID:client]) {
        problem = @"The configured client belongs to another HCG product. Nexus must use its own client.";
    } else if (redirect.length == 0) {
        problem = @"No redirect URI is configured for HCG Nexus.";
    } else {
        NSURL *url = [NSURL URLWithString:redirect];
        if (url == nil || ![[url.scheme lowercaseString] isEqualToString:kRedirectScheme] || url.query.length > 0 || url.fragment.length > 0 ||
            url.user.length > 0 || url.password.length > 0) {
            problem = [NSString stringWithFormat:@"The redirect URI must use the app's own scheme (%@://…) with no query or fragment.", kRedirectScheme];
        }
    }
    config->_problem = [problem copy];
    return config;
}

- (BOOL)isConfigured {
    return _problem == nil;
}

@end

@implementation HCGAccountRules

+ (BOOL)isPermissionGrantedWithHTTPStatus:(NSInteger)status response:(id)response {
    if (status != 200 || ![response isKindOfClass:[NSDictionary class]]) return NO;
    id allowed = [response objectForKey:@"allowed"];
    if (![allowed isKindOfClass:[NSNumber class]]) return NO;
    // A JSON boolean decodes to a boolean NSNumber (objCType c, C or B depending on the platform);
    // reject numbers such as 1 or 1.0, which are not the contract's boolean.
    const char *type = [allowed objCType];
    if (type == NULL || strlen(type) != 1 || (type[0] != 'c' && type[0] != 'C' && type[0] != 'B')) return NO;
    return [allowed boolValue];
}

+ (NSString *)titleForState:(HCGAccountState)state {
    switch (state) {
        case HCGAccountStateNotConfigured: return @"Not configured";
        case HCGAccountStateSignedOut: return @"Signed out";
        case HCGAccountStateSignedIn: return @"Signed in";
        case HCGAccountStateSessionEnded: return @"Session ended";
        case HCGAccountStateUnavailableHere: return @"Sign-in is in the standalone app";
    }
    return @"Not configured";
}

+ (NSString *)registrationRequestText {
    return [NSString stringWithFormat:
        @"HCG Connect client request — HCG Nexus (iOS)\n"
        @"Product: HCG Nexus\n"
        @"Integration key: %@\n"
        @"Platform: iOS (standalone iPhone/iPad app, bundle com.hakmicapitalgroup.hcgnexus.app)\n"
        @"Environment: production (a separate development client only if HCG requires one)\n"
        @"Consent name: HCG Nexus\n"
        @"Client type: public, token_endpoint_auth_method none (no secret)\n"
        @"Grants: authorization_code, refresh_token\n"
        @"PKCE: S256 only\n"
        @"Scopes: %@\n"
        @"Access token audience: authenticated\n"
        @"Redirect URI (exact): %@\n"
        @"Allowed origins: none\n"
        @"Logout URLs: none\n"
        @"Status: configured_untested until a device sign-in passes\n"
        @"Please send back the client ID only.",
        HCGAccountIntegrationKey, HCGAccountScopes, HCGAccountProposedRedirectURI];
}

@end

@implementation HCGAccountSummary

+ (BOOL)looksLikeCredential:(NSString *)value {
    if (![value isKindOfClass:[NSString class]]) return NO;
    if (value.length > 120) return YES;
    NSString *lower = [value lowercaseString];
    if ([lower hasPrefix:@"bearer "] || [lower hasPrefix:@"ey"]) return YES; // bearer header, base64url JSON (JWT)
    NSRegularExpression *jwt = [NSRegularExpression regularExpressionWithPattern:@"^[A-Za-z0-9_-]{8,}\\.[A-Za-z0-9_-]{8,}\\.[A-Za-z0-9_-]{8,}$" options:0 error:NULL];
    if ([jwt numberOfMatchesInString:value options:0 range:NSMakeRange(0, value.length)] > 0) return YES;
    NSRegularExpression *opaque = [NSRegularExpression regularExpressionWithPattern:@"[A-Za-z0-9+/_=-]{40,}" options:0 error:NULL];
    return [opaque numberOfMatchesInString:value options:0 range:NSMakeRange(0, value.length)] > 0;
}

+ (NSDictionary *)sanitizedSummary:(id)candidate {
    if (![candidate isKindOfClass:[NSDictionary class]]) return nil;
    NSArray *keys = [candidate allKeys];
    NSUInteger i;
    for (i = 0; i < keys.count; i++) {
        id key = [keys objectAtIndex:i];
        NSString *lowerKey = [key isKindOfClass:[NSString class]] ? [key lowercaseString] : @"";
        if ([lowerKey rangeOfString:@"token"].location != NSNotFound || [lowerKey rangeOfString:@"secret"].location != NSNotFound ||
            [lowerKey rangeOfString:@"code"].location != NSNotFound || [lowerKey rangeOfString:@"password"].location != NSNotFound ||
            [lowerKey rangeOfString:@"cookie"].location != NSNotFound || [lowerKey rangeOfString:@"auth"].location != NSNotFound) {
            return nil; // a credential-bearing summary is refused outright, not trimmed
        }
        id value = [candidate objectForKey:key];
        if ([value isKindOfClass:[NSString class]] && [self looksLikeCredential:value]) return nil;
    }
    NSMutableDictionary *out = [[NSMutableDictionary alloc] init];
    id state = [candidate objectForKey:HCGAccountSummaryState];
    if (![state isKindOfClass:[NSNumber class]] || [state integerValue] < HCGAccountStateNotConfigured ||
        [state integerValue] > HCGAccountStateUnavailableHere) return nil;
    [out setObject:state forKey:HCGAccountSummaryState];
    id name = [candidate objectForKey:HCGAccountSummaryDisplayName];
    if ([name isKindOfClass:[NSString class]] && [name length] > 0 && [name length] <= 80) [out setObject:name forKey:HCGAccountSummaryDisplayName];
    id organisation = [candidate objectForKey:HCGAccountSummaryOrganisation];
    if ([organisation isKindOfClass:[NSString class]] && [organisation length] > 0 && [organisation length] <= 80) {
        [out setObject:organisation forKey:HCGAccountSummaryOrganisation];
    }
    id updated = [candidate objectForKey:HCGAccountSummaryUpdated];
    if ([updated isKindOfClass:[NSNumber class]]) [out setObject:updated forKey:HCGAccountSummaryUpdated];
    return out;
}

@end
