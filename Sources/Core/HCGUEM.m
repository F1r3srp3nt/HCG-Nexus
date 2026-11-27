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

+ (NSArray *)rowsFromUEMSelfStatus:(NSData *)data catalog:(NSData *)catalog error:(NSString **)error {
    id json = data.length && data.length <= 512 * 1024 ? [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL] : nil;
    NSDictionary *summary = [json isKindOfClass:[NSDictionary class]] ? [json objectForKey:@"summary"] : nil;
    if (![summary isKindOfClass:[NSDictionary class]] || !Text([summary objectForKey:@"deviceId"], 40)) {
        if (error) *error = @"Not an HCG UEM device status (summary.deviceId missing).";
        return nil;
    }
    NSMutableArray *rows = [NSMutableArray array];
    NSString *deviceID = Text([summary objectForKey:@"deviceId"], 40);
    // HCG Device IDs: a 3-4 letter prefix, "_" and 26 base32 characters (HCG UEM internal/ids).
    NSRange us = [deviceID rangeOfString:@"_"];
    BOOL validID = us.location >= 3 && us.location <= 4 && deviceID.length == us.location + 27;
    [rows addObject:Row(@"HCG Device ID", validID ? deviceID : @"Invalid device ID: status not shown")];
    if (!validID) return rows;
    NSString *state = Text([summary objectForKey:@"state"], 40);
    NSString *states = @"unregistered enrollment_requested pending_verification pending_approval enrolled active suspended quarantined credential_rotation_required retired revoked";
    if (!OneOf(state, states)) state = @"unknown";
    BOOL blocked = !OneOf(state, @"active enrolled");
    [rows addObject:Row(@"Lifecycle", [state stringByReplacingOccurrencesOfString:@"_" withString:@" "])];
    // Classification: the key from HCG UEM; its name only from HCG UEM's catalogue.
    NSString *key = Text([summary objectForKey:@"classification"], 40);
    NSString *classification = key ? [NSString stringWithFormat:@"%@ (name from HCG UEM's catalogue not available)", key] : @"Not classified by HCG UEM";
    id cat = catalog.length ? [NSJSONSerialization JSONObjectWithData:catalog options:0 error:NULL] : nil;
    id classes = [cat isKindOfClass:[NSDictionary class]] ? [cat objectForKey:@"classifications"] : nil;
    if (key && [classes isKindOfClass:[NSArray class]]) {
        for (id c in classes) {
            if ([c isKindOfClass:[NSDictionary class]] && [[c objectForKey:@"key"] isEqual:key] && Text([c objectForKey:@"name"], 60)) {
                id rev = [cat objectForKey:@"revision"];
                classification = [NSString stringWithFormat:@"%@ (catalogue revision %@)", Text([c objectForKey:@"name"], 60), rev ? [rev description] : @"—"];
            }
        }
    }
    id unmet = [json objectForKey:@"classificationUnmet"];
    if ([unmet isKindOfClass:[NSArray class]] && [unmet count]) classification = [classification stringByAppendingFormat:@"; %lu requirement%@ unmet", (unsigned long)[unmet count], [unmet count] == 1 ? @"" : @"s"];
    [rows addObject:Row(@"Trust classification", blocked ? [NSString stringWithFormat:@"%@ (not in effect while %@)", classification, state] : classification)];
    NSString *assurance = Text([summary objectForKey:@"keyAssurance"], 40);
    [rows addObject:Row(@"Verified device identity", OneOf(assurance, @"hardware_attested hardware_admin_confirmed") && !blocked ? [@"Key assurance: " stringByAppendingString:assurance] :
                                                    [NSString stringWithFormat:@"Not verified (key assurance %@)", OneOf(assurance, @"software hardware_claimed hardware_admin_confirmed hardware_attested") ? assurance : @"unknown"])];
    NSUInteger active = 0, revoked = 0;
    id creds = [json objectForKey:@"credentials"];
    if ([creds isKindOfClass:[NSArray class]]) for (id c in creds) {
        NSString *st = [c isKindOfClass:[NSDictionary class]] ? Text([c objectForKey:@"status"], 20) : nil;
        if ([st isEqualToString:@"active"]) active++;
        if ([st isEqualToString:@"revoked"] || [st isEqualToString:@"expired"]) revoked++;
    }
    [rows addObject:Row(@"Credentials", [NSString stringWithFormat:@"%lu active, %lu revoked or expired", (unsigned long)active, (unsigned long)revoked])];
    NSString *compliance = Text([summary objectForKey:@"compliance"], 20);
    [rows addObject:Row(@"Security posture", OneOf(compliance, @"compliant noncompliant stale unknown") ? compliance : @"unknown")];
    NSString *connectivity = Text([summary objectForKey:@"connectivity"], 20);
    [rows addObject:Row(@"Connectivity", OneOf(connectivity, @"never_seen online offline") ? [connectivity stringByReplacingOccurrencesOfString:@"_" withString:@" "] : @"unknown")];
    id jailbroken = [summary objectForKey:@"jailbroken"];
    if ([jailbroken isKindOfClass:[NSNumber class]] && [jailbroken boolValue]) {
        [rows addObject:Row(@"Jailbreak", @"Reported by HCG UEM (development or research only). It never adds privileges; Nexus offers no administrative action")];
    }
    id history = [json objectForKey:@"history"];
    [rows addObject:Row(@"Lifecycle history", [history isKindOfClass:[NSArray class]] ? [NSString stringWithFormat:@"%lu transitions", (unsigned long)[history count]] : @"Not provided")];
    [rows addObject:Row(@"Authorization", @"Decided by HCG UEM and HCG Connect. Nexus grants nothing")];
    return rows;
}

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
