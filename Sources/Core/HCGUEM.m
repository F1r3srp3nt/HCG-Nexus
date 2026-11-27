#import "HCGUEM.h"

NSString *const HCGUEMDeviceStatusSchema = @"hcg.uem.device-status/1";

BOOL HCGUEMNexusMayAuthorize(void) {
    return NO; // HCG UEM decides; Nexus only shows its decision.
}

static NSString *Text(id value, NSUInteger limit) {
    if (![value isKindOfClass:[NSString class]]) return nil;
    NSString *s = [value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (!s.length) return nil;
    return s.length > limit ? [s substringToIndex:limit] : s;
}

static NSArray *Row(NSString *title, NSString *value) {
    return [NSArray arrayWithObjects:title, value, nil];
}

static BOOL OneOf(NSString *value, NSString *list) {
    return value.length && [[list componentsSeparatedByString:@" "] containsObject:value];
}

@implementation HCGUEM

+ (NSArray *)rowsFromDeviceStatus:(NSData *)data error:(NSString **)error {
    id json = data.length && data.length <= 256 * 1024 ? [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL] : nil;
    NSDictionary *device = [json isKindOfClass:[NSDictionary class]] ? [json objectForKey:@"device"] : nil;
    if (![[json objectForKey:@"schema"] isEqual:HCGUEMDeviceStatusSchema] || ![device isKindOfClass:[NSDictionary class]]) {
        if (error) *error = @"Not an HCG UEM device status (hcg.uem.device-status/1).";
        return nil;
    }
    NSMutableArray *rows = [NSMutableArray array];
    NSString *deviceID = Text([device objectForKey:@"hcgDeviceId"], 80);
    [rows addObject:Row(@"HCG Device ID", deviceID ?: @"Not assigned")];
    NSString *lifecycle = Text([device objectForKey:@"lifecycle"], 20);
    if (!OneOf(lifecycle, @"active suspended revoked retired")) lifecycle = @"unknown";
    BOOL blocked = [lifecycle isEqualToString:@"suspended"] || [lifecycle isEqualToString:@"revoked"] || [lifecycle isEqualToString:@"retired"];
    [rows addObject:Row(@"Lifecycle", blocked ? [NSString stringWithFormat:@"%@: no access through this device", [lifecycle capitalizedString]] : [lifecycle capitalizedString])];
    NSString *enrollment = Text([device objectForKey:@"enrollment"], 20);
    [rows addObject:Row(@"Enrollment", OneOf(enrollment, @"enrolled pending not-enrolled") ? enrollment : @"unknown")];
    id verified = [device objectForKey:@"identityVerified"];
    [rows addObject:Row(@"Verified device identity", [verified isKindOfClass:[NSNumber class]] && [verified boolValue] && !blocked ? @"Verified by HCG UEM" : @"Not verified")];
    // Tier: only a level that HCG UEM's own policy in this document defines.
    NSString *tierText = @"Not classified by HCG UEM policy";
    id level = [device objectForKey:@"tier"];
    NSDictionary *policy = [[json objectForKey:@"policy"] isKindOfClass:[NSDictionary class]] ? [json objectForKey:@"policy"] : nil;
    id tiers = [policy objectForKey:@"tiers"];
    if ([level isKindOfClass:[NSNumber class]] && [tiers isKindOfClass:[NSArray class]]) {
        for (id t in tiers) {
            if ([t isKindOfClass:[NSDictionary class]] && [[t objectForKey:@"level"] isKindOfClass:[NSNumber class]] &&
                [[t objectForKey:@"level"] integerValue] == [level integerValue] && Text([t objectForKey:@"name"], 60)) {
                tierText = [NSString stringWithFormat:@"Tier %ld: %@ (policy %@)", (long)[level integerValue], Text([t objectForKey:@"name"], 60),
                                                      Text([policy objectForKey:@"version"], 20) ?: ([[policy objectForKey:@"version"] isKindOfClass:[NSNumber class]] ? [[policy objectForKey:@"version"] description] : @"unversioned")];
            }
        }
    }
    [rows addObject:Row(@"Trust classification", blocked ? [NSString stringWithFormat:@"%@ (not in effect while %@)", tierText, lifecycle] : tierText)];
    NSString *credential = Text([device objectForKey:@"credential"], 20);
    [rows addObject:Row(@"Credential", OneOf(credential, @"valid expiring expired revoked none") ? credential : @"unknown")];
    NSDictionary *posture = [[device objectForKey:@"posture"] isKindOfClass:[NSDictionary class]] ? [device objectForKey:@"posture"] : nil;
    NSString *state = Text([posture objectForKey:@"state"], 20);
    [rows addObject:Row(@"Security posture", OneOf(state, @"compliant at-risk non-compliant unknown") ? state : @"unknown")];
    id jailbroken = [device objectForKey:@"jailbroken"];
    if ([jailbroken isKindOfClass:[NSNumber class]] && [jailbroken boolValue]) {
        [rows addObject:Row(@"Jailbreak", @"Reported by HCG UEM. It never adds privileges; Nexus offers no administrative action")];
    }
    NSMutableArray *permissions = [NSMutableArray array];
    id list = [device objectForKey:@"permissions"];
    if ([list isKindOfClass:[NSArray class]] && !blocked) for (id p in list) if (Text(p, 80) && permissions.count < 20) [permissions addObject:Text(p, 80)];
    [rows addObject:Row(@"Device-specific permissions (as HCG UEM states them)", permissions.count ? [permissions componentsJoinedByString:@", "] : @"None")];
    id history = [json objectForKey:@"history"];
    [rows addObject:Row(@"Connection history", [history isKindOfClass:[NSArray class]] ? [NSString stringWithFormat:@"%lu events", (unsigned long)[history count]] : @"Not provided")];
    id inventory = [json objectForKey:@"inventory"];
    [rows addObject:Row(@"Authorized device inventory", [inventory isKindOfClass:[NSArray class]] ? [NSString stringWithFormat:@"%lu devices", (unsigned long)[inventory count]] : @"Not provided")];
    [rows addObject:Row(@"Authorization", @"Decided by HCG UEM and HCG Connect. Nexus grants nothing")];
    return rows;
}

@end
