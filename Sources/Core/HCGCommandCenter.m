#import "HCGCommandCenter.h"
#import "HCGDigest.h"
#include <time.h>

const NSInteger HCGRoadmapStateCount = 14;
NSString *const HCGConnectionLedgerStoreKey = @"connectionLedger";
NSString *const HCGRoadmapStoreKey = @"roadmap";
NSString *const HCGLifeOSExportStoreKey = @"lifeosExported";
NSString *const HCGCommandCenterFavoritesKey = @"favoriteProducts";
const NSTimeInterval HCGConnectionFreshInterval = 15 * 60;

static const NSUInteger kLedgerLimit = 200;
static const NSUInteger kHistoryLimit = 12;

static NSString *Short(NSString *s, NSUInteger limit) {
    return s.length > limit ? [s substringToIndex:limit] : s;
}

@implementation HCGConnectionLedger

+ (NSDictionary *)entryForProduct:(NSString *)productID method:(NSString *)method success:(BOOL)success text:(NSString *)text time:(NSDate *)time {
    NSString *t = [text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (!HCGRegistryIsValidIdentifier(productID) || !HCGRegistryIsValidIdentifier(method) || !t.length || !time) return nil;
    // No links, parameters or paths in the ledger.
    if ([t rangeOfString:@"://"].location != NSNotFound || [t rangeOfString:@"?"].location != NSNotFound) t = success ? @"Read succeeded." : @"Read failed.";
    return [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithDouble:[time timeIntervalSince1970]], @"time", productID, @"product",
                                                     method, @"method", [NSNumber numberWithBool:success], @"ok", Short(t, 160), @"text", nil];
}

+ (NSArray *)entriesFromStoredValue:(id)value {
    NSMutableArray *out = [NSMutableArray array];
    if (![value isKindOfClass:[NSArray class]]) return out;
    for (id item in value) {
        if (![item isKindOfClass:[NSDictionary class]]) continue;
        id time = [item objectForKey:@"time"], ok = [item objectForKey:@"ok"];
        if (![time isKindOfClass:[NSNumber class]] || ![ok isKindOfClass:[NSNumber class]]) continue;
        NSDictionary *e = [self entryForProduct:[item objectForKey:@"product"] method:[item objectForKey:@"method"] success:[ok boolValue]
                                           text:[[item objectForKey:@"text"] isKindOfClass:[NSString class]] ? [item objectForKey:@"text"] : @""
                                           time:[NSDate dateWithTimeIntervalSince1970:[time doubleValue]]];
        if (e && out.count < kLedgerLimit) [out addObject:e];
    }
    return out;
}

+ (NSArray *)entries:(NSArray *)entries byAdding:(NSDictionary *)entry {
    NSMutableArray *out = [NSMutableArray arrayWithObject:entry];
    for (NSDictionary *e in [self entriesFromStoredValue:entries]) if (out.count < kLedgerLimit) [out addObject:e];
    return out;
}

+ (NSArray *)entries:(NSArray *)entries forProduct:(NSString *)productID {
    NSMutableArray *out = [NSMutableArray array];
    for (NSDictionary *e in entries) if ([[e objectForKey:@"product"] isEqual:productID]) [out addObject:e];
    return out;
}

@end

@implementation HCGConnectionSummary
@synthesize state = _state, title = _title, detail = _detail, lastSuccess = _lastSuccess, lastSuccessText = _lastSuccessText, lastAttempt = _lastAttempt,
            lastSuccessAccess = _lastSuccessAccess;
@end

@implementation HCGRoadmapAssessment
@synthesize state = _state, evidence = _evidence;
@end

@implementation HCGDevelopmentGap
@synthesize stableID = _stableID, productID = _productID, productName = _productName, title = _title, detail = _detail, kind = _kind, blocking = _blocking;
@end

@implementation HCGLifeOSExport
@synthesize payload = _payload, included = _included, changed = _changed, alreadyExported = _alreadyExported, fingerprints = _fingerprints;
@end

static NSString *When(NSDate *date) {
    // Stable, locale-free: "2026-11-26 10:15 UTC".
    time_t t = (time_t)[date timeIntervalSince1970];
    struct tm tm;
    gmtime_r(&t, &tm);
    return [NSString stringWithFormat:@"%04d-%02d-%02d %02d:%02d UTC", tm.tm_year + 1900, tm.tm_mon + 1, tm.tm_mday, tm.tm_hour, tm.tm_min];
}

static HCGConnectionSummary *Summary(HCGConnectionState state, NSString *detail) {
    HCGConnectionSummary *s = [[HCGConnectionSummary alloc] init];
    s.state = state;
    s.title = [HCGCommandCenter titleForConnectionState:state];
    s.detail = detail;
    return s;
}

@implementation HCGCommandCenter

+ (NSString *)titleForConnectionState:(HCGConnectionState)state {
    switch (state) {
        case HCGConnectionStateNotSupported: return @"Not on iPhone";
        case HCGConnectionStatePlanned: return @"Planned";
        case HCGConnectionStateSuspended: return @"Suspended";
        case HCGConnectionStateRetired: return @"Retired";
        case HCGConnectionStateNotConfigured: return @"Not configured";
        case HCGConnectionStateUnableToCheck: return @"Unable to check";
        case HCGConnectionStateNotInstalled: return @"Not installed";
        case HCGConnectionStateInstalled: return @"Installed";
        case HCGConnectionStateReady: return @"Ready";
        case HCGConnectionStateConnected: return @"Connected";
        case HCGConnectionStateDisconnected: return @"Disconnected";
        case HCGConnectionStateFailed: return @"Connection failed";
        case HCGConnectionStateBuiltIn: return @"Built in";
        case HCGConnectionStateWebsite: return @"Website";
        case HCGConnectionStateReachable: return @"Public service reachable";
    }
    return @"Unknown";
}

+ (NSString *)titleForRoadmapState:(HCGRoadmapState)state {
    switch (state) {
        case HCGRoadmapStateRegistered: return @"Registered";
        case HCGRoadmapStateResearchRequired: return @"Research required";
        case HCGRoadmapStateContractAvailable: return @"Contract available";
        case HCGRoadmapStateAdapterDevelopmentRequired: return @"Adapter development required";
        case HCGRoadmapStateAdapterImplemented: return @"Adapter implemented";
        case HCGRoadmapStateConfigurationRequired: return @"Configuration required";
        case HCGRoadmapStateReadyToConnect: return @"Ready to connect";
        case HCGRoadmapStateConnectionAttempted: return @"Connection attempted";
        case HCGRoadmapStateConnected: return @"Connected";
        case HCGRoadmapStatePartiallyIntegrated: return @"Partially integrated";
        case HCGRoadmapStateValidated: return @"Validated";
        case HCGRoadmapStateDisconnected: return @"Disconnected";
        case HCGRoadmapStateBlocked: return @"Blocked";
        case HCGRoadmapStateUnsupported: return @"Unsupported";
    }
    return @"Unknown";
}

+ (NSString *)keyForRoadmapState:(HCGRoadmapState)state {
    return [[[self titleForRoadmapState:state] lowercaseString] stringByReplacingOccurrencesOfString:@" " withString:@"-"];
}

+ (HCGRoadmapState)roadmapStateForKey:(NSString *)key found:(BOOL *)found {
    NSInteger i;
    for (i = 0; i < HCGRoadmapStateCount; i++) {
        if ([[self keyForRoadmapState:(HCGRoadmapState)i] isEqualToString:key]) {
            if (found) *found = YES;
            return (HCGRoadmapState)i;
        }
    }
    if (found) *found = NO;
    return HCGRoadmapStateRegistered;
}

#pragma mark Connection

+ (HCGConnectionSummary *)connectionForEntry:(HCGRegistryEntry *)entry hipStatus:(HCGHIPProductStatus *)hip ledger:(NSArray *)ledger
                                    registry:(HCGRegistry *)registry now:(NSDate *)now {
    if ([entry.lifecycle isEqualToString:@"retired"]) return Summary(HCGConnectionStateRetired, @"Retired in the registry: nothing is offered.");
    if ([entry.lifecycle isEqualToString:@"suspended"]) return Summary(HCGConnectionStateSuspended, @"Suspended in the registry: nothing is offered.");

    // Two-way reads from the ledger (navigation is never recorded as a connection).
    NSDate *lastOK = nil, *lastFail = nil, *lastAttempt = nil;
    NSString *okText = nil, *failText = nil, *okAccess = nil;
    for (NSDictionary *e in [HCGConnectionLedger entries:ledger ?: [NSArray array] forProduct:entry.identifier]) {
        HCGRegistryMethod *m = [registry methodWithIdentifier:[e objectForKey:@"method"]];
        if (!m.twoWay) continue;
        NSDate *t = [NSDate dateWithTimeIntervalSince1970:[[e objectForKey:@"time"] doubleValue]];
        if (!lastAttempt || [t compare:lastAttempt] == NSOrderedDescending) lastAttempt = t;
        if ([[e objectForKey:@"ok"] boolValue]) {
            if (!lastOK || [t compare:lastOK] == NSOrderedDescending) { lastOK = t; okText = [e objectForKey:@"text"]; okAccess = m.access; }
        } else if (!lastFail || [t compare:lastFail] == NSOrderedDescending) {
            lastFail = t;
            failText = [e objectForKey:@"text"];
        }
    }

    HCGConnectionSummary *s = nil;
    HCGHIPAvailability a = hip ? hip.availability : HCGHIPAvailabilityNotAvailable;
    if ([entry.kind isEqualToString:@"hub"] || [entry.kind isEqualToString:@"feature"]) {
        s = Summary(HCGConnectionStateBuiltIn, @"Part of HCG Nexus.");
    } else if (hip && a == HCGHIPAvailabilityConnected) {
        s = Summary(HCGConnectionStateConnected, hip.integrationText);
    } else if (hip && a == HCGHIPAvailabilityUnreachable) {
        s = Summary(lastOK ? HCGConnectionStateDisconnected : HCGConnectionStateFailed, hip.integrationText);
    } else if (hip && a == HCGHIPAvailabilityNotConnected) {
        s = Summary(HCGConnectionStateNotConfigured, hip.integrationText);
        s.title = hip.stateTitle;
    } else if (lastOK && (!lastFail || [lastFail compare:lastOK] != NSOrderedDescending) &&
               [now timeIntervalSinceDate:lastOK] <= HCGConnectionFreshInterval && [now timeIntervalSinceDate:lastOK] >= -60) {
        // A public, anonymous read shows the service is available; only local or authenticated exchanges connect.
        if ([okAccess isEqualToString:@"public"]) {
            s = Summary(HCGConnectionStateReachable, [NSString stringWithFormat:@"%@ Anonymous public read: no authenticated access.", okText ?: @"The last read succeeded."]);
        } else {
            s = Summary(HCGConnectionStateConnected, okText ?: @"The last exchange succeeded.");
            if ([okAccess isEqualToString:@"local"]) s.title = @"Connected (local interface)";
        }
    } else if (lastOK) {
        s = Summary(HCGConnectionStateDisconnected, lastFail && [lastFail compare:lastOK] == NSOrderedDescending
                        ? [NSString stringWithFormat:@"The last read failed: %@", failText ?: @"no answer."]
                        : [NSString stringWithFormat:@"Last connected %@.", When(lastOK)]);
    } else if (lastFail) {
        s = Summary(HCGConnectionStateFailed, failText ?: @"The read failed.");
    } else if (hip && (a == HCGHIPAvailabilityReady || a == HCGHIPAvailabilityOff || a == HCGHIPAvailabilityAttention || a == HCGHIPAvailabilityNeedsUpdate)) {
        s = Summary(HCGConnectionStateInstalled, [NSString stringWithFormat:@"%@. Installed is not a connection: Nexus reads its own status and opens its screens.", hip.stateTitle]);
    } else if (hip && (a == HCGHIPAvailabilityNotInstalled || a == HCGHIPAvailabilityUnsupportedOS)) {
        s = Summary(HCGConnectionStateNotInstalled, hip.compatibilityText);
    } else if (hip && a == HCGHIPAvailabilityUnknown) {
        s = Summary(HCGConnectionStateUnableToCheck, hip.routes.count ? @"This app cannot see installed products; its links can be opened." : @"This app cannot see installed products.");
    } else if (entry.adapter && ![entry.adapter isEqualToString:@"hip"]) {
        NSString *how = [entry.adapter isEqualToString:@"system-tester.inventory"] ? @"Import a device inventory file exported by HCG System Tester."
                      : [entry.adapter isEqualToString:@"lifeos.export"] ? @"Export development gaps as a LifeOS import file."
                      : @"Nexus reads it when you tap Check now; nothing is read at startup.";
        s = Summary(HCGConnectionStateReady, how);
    } else if (hip && a == HCGHIPAvailabilityNotAvailable && hip.descriptor.unavailableReason.length) {
        s = Summary(entry.isPlanned ? HCGConnectionStatePlanned : HCGConnectionStateNotSupported, hip.descriptor.unavailableReason);
    } else if (entry.isPlanned) {
        s = Summary(HCGConnectionStatePlanned, @"Planned: no integration exists yet.");
    } else {
        BOOL website = entry.websiteURL.length > 0;
        for (HCGRegistryConnection *c in entry.connections) if (![c.method isEqualToString:@"website"] && [c.state isEqualToString:@"implemented"]) website = NO;
        s = website ? Summary(HCGConnectionStateWebsite, @"A website: Nexus opens it in the browser.")
                    : Summary(HCGConnectionStateNotSupported, @"No connection method on this iPhone yet.");
    }
    s.lastSuccess = lastOK;
    s.lastSuccessAccess = okAccess;
    s.lastSuccessText = okText;
    s.lastAttempt = lastAttempt;
    return s;
}

#pragma mark Roadmap

static HCGRoadmapAssessment *Assessment(HCGRoadmapState state, NSString *evidence) {
    HCGRoadmapAssessment *a = [[HCGRoadmapAssessment alloc] init];
    a.state = state;
    a.evidence = evidence;
    return a;
}

static HCGRegistryRequirement *Blocking(HCGRegistryEntry *entry, NSString *kinds) {
    for (HCGRegistryRequirement *r in entry.requirements) {
        if (r.blocking && [[kinds componentsSeparatedByString:@" "] containsObject:r.kind]) return r;
    }
    return nil;
}

+ (HCGRoadmapAssessment *)roadmapForEntry:(HCGRegistryEntry *)entry connection:(HCGConnectionSummary *)connection hipStatus:(HCGHIPProductStatus *)hip {
    if ([entry.lifecycle isEqualToString:@"retired"]) return Assessment(HCGRoadmapStateUnsupported, @"Retired in the registry.");
    if ([entry.lifecycle isEqualToString:@"suspended"]) return Assessment(HCGRoadmapStateBlocked, @"Suspended in the registry.");
    if (connection.state == HCGConnectionStateConnected) {
        return Assessment(HCGRoadmapStateConnected, connection.lastSuccess
                              ? [NSString stringWithFormat:@"%@ (%@).", connection.lastSuccessText ?: @"Read succeeded", When(connection.lastSuccess)]
                              : connection.detail);
    }
    if (connection.state == HCGConnectionStateReachable) {
        // Public reachability completes a public-only integration; where authenticated access is part of the product's
        // integration, it is only partial.
        HCGRegistryConnection *auth = nil;
        for (HCGRegistryConnection *c in entry.connections) if ([c.method isEqualToString:@"hcg-connect"] && ![c.state isEqualToString:@"implemented"]) auth = c;
        HCGRegistryRequirement *config = Blocking(entry, @"configuration registration");
        if (auth || config) {
            return Assessment(HCGRoadmapStatePartiallyIntegrated, [NSString stringWithFormat:@"Public service reachable (%@); authenticated access not established: %@",
                                                                  connection.lastSuccess ? When(connection.lastSuccess) : @"recently", config ? config.title : auth.detail]);
        }
        return Assessment(HCGRoadmapStateConnected, [NSString stringWithFormat:@"%@ (%@, public read).", connection.lastSuccessText ?: @"Read succeeded",
                                                     connection.lastSuccess ? When(connection.lastSuccess) : @"recently"]);
    }
    if (connection.state == HCGConnectionStateDisconnected) return Assessment(HCGRoadmapStateDisconnected, connection.detail);
    if (connection.state == HCGConnectionStateFailed) return Assessment(HCGRoadmapStateConnectionAttempted, connection.detail);

    BOOL adapter = entry.adapter != nil;
    if (adapter) {
        HCGRegistryValidation *v = entry.validations.count ? [entry.validations objectAtIndex:0] : nil;
        if (v) return Assessment(HCGRoadmapStateValidated, [NSString stringWithFormat:@"%@ on %@ (%@): %@", v.version.length ? v.version : @"Validated", v.device, v.date, v.summary]);
        BOOL installed = hip && hip.installed;
        if (installed) {
            BOOL works = NO, planned = NO;
            for (HCGHIPResolvedCapability *c in hip.capabilities) {
                if (c.state == HCGHIPCapabilityStateAvailable || c.state == HCGHIPCapabilityStateVerified) works = YES;
                if (c.state == HCGHIPCapabilityStatePlanned) planned = YES;
            }
            if (works && planned) return Assessment(HCGRoadmapStatePartiallyIntegrated, @"Installed: some capabilities work here, others are planned.");
        }
        HCGRegistryRequirement *access = Blocking(entry, @"access");
        if (access && hip && hip.availability == HCGHIPAvailabilityNotAvailable) return Assessment(HCGRoadmapStateBlocked, access.title);
        HCGRegistryRequirement *config = Blocking(entry, @"configuration registration");
        if (config && connection.state != HCGConnectionStateBuiltIn) return Assessment(HCGRoadmapStateConfigurationRequired, config.title);
        if (installed || connection.state == HCGConnectionStateReady || connection.state == HCGConnectionStateBuiltIn ||
            connection.state == HCGConnectionStateUnableToCheck || connection.state == HCGConnectionStateNotConfigured) {
            if (config) return Assessment(HCGRoadmapStateConfigurationRequired, config.title);
            return Assessment(HCGRoadmapStateReadyToConnect, connection.state == HCGConnectionStateBuiltIn ? @"Built into HCG Nexus." : connection.detail);
        }
        return Assessment(HCGRoadmapStateAdapterImplemented, connection.detail.length ? connection.detail : @"Nexus has an adapter; the product is not on this iPhone.");
    }
    HCGRegistryRequirement *research = Blocking(entry, @"research");
    if (research) return Assessment(HCGRoadmapStateResearchRequired, research.title);
    if ([entry.contractStatus isEqualToString:@"available"]) {
        HCGRegistryRequirement *access = Blocking(entry, @"access");
        if (access) return Assessment(HCGRoadmapStateContractAvailable, [NSString stringWithFormat:@"%@ exists, but: %@", entry.contractID ?: @"A contract", access.title]);
        return Assessment(HCGRoadmapStateAdapterDevelopmentRequired, [NSString stringWithFormat:@"%@ is published; Nexus has no adapter yet.", entry.contractID ?: @"A contract"]);
    }
    HCGRegistryRequirement *contract = Blocking(entry, @"contract");
    if (contract) return Assessment(HCGRoadmapStateResearchRequired, contract.title);
    if (entry.isPlanned) return Assessment(HCGRoadmapStateRegistered, @"Planned: listed in the registry, not implemented.");
    if (connection.state == HCGConnectionStateWebsite) return Assessment(HCGRoadmapStateRegistered, @"Website link only; no integration contract is published.");
    return Assessment(HCGRoadmapStateRegistered, @"Listed in the registry; no integration contract is published.");
}

+ (NSDictionary *)roadmapStore:(NSDictionary *)store byRecordingAssessments:(NSDictionary *)assessments now:(NSDate *)now changed:(BOOL *)changed {
    NSMutableDictionary *out = [NSMutableDictionary dictionary];
    BOOL any = NO;
    NSDictionary *old = [store isKindOfClass:[NSDictionary class]] ? store : [NSDictionary dictionary];
    for (NSString *key in old) {
        NSDictionary *v = [old objectForKey:key];
        if ([key isKindOfClass:[NSString class]] && HCGRegistryIsValidIdentifier(key) && [v isKindOfClass:[NSDictionary class]]) [out setObject:v forKey:key];
    }
    NSNumber *time = [NSNumber numberWithDouble:[now timeIntervalSince1970]];
    for (NSString *entryID in assessments) {
        HCGRoadmapAssessment *a = [assessments objectForKey:entryID];
        NSString *stateKey = [self keyForRoadmapState:a.state];
        NSDictionary *current = [out objectForKey:entryID];
        if ([[current objectForKey:@"state"] isEqual:stateKey]) continue; // unchanged: no new history
        NSMutableArray *history = [NSMutableArray array];
        NSDictionary *record = [NSDictionary dictionaryWithObjectsAndKeys:stateKey, @"state", Short(a.evidence ?: @"", 300), @"evidence", time, @"time", nil];
        [history addObject:record];
        id oldHistory = [current objectForKey:@"history"];
        if ([oldHistory isKindOfClass:[NSArray class]]) {
            for (id h in oldHistory) if ([h isKindOfClass:[NSDictionary class]] && history.count < kHistoryLimit) [history addObject:h];
        }
        [out setObject:[NSDictionary dictionaryWithObjectsAndKeys:stateKey, @"state", Short(a.evidence ?: @"", 300), @"evidence", time, @"since", history, @"history", nil]
                forKey:entryID];
        any = YES;
    }
    if (changed) *changed = any;
    return out;
}

+ (NSArray *)roadmapHistoryForEntry:(NSString *)entryID store:(NSDictionary *)store {
    NSDictionary *current = [store isKindOfClass:[NSDictionary class]] ? [store objectForKey:entryID] : nil;
    id history = [current isKindOfClass:[NSDictionary class]] ? [current objectForKey:@"history"] : nil;
    NSMutableArray *out = [NSMutableArray array];
    if (![history isKindOfClass:[NSArray class]]) return out;
    for (id h in history) {
        if (![h isKindOfClass:[NSDictionary class]]) continue;
        BOOL found = NO;
        [self roadmapStateForKey:[h objectForKey:@"state"] found:&found];
        if (found && [[h objectForKey:@"time"] isKindOfClass:[NSNumber class]]) [out addObject:h];
    }
    return out;
}

#pragma mark Gaps and LifeOS

+ (NSArray *)gapsForEntries:(NSArray *)entries {
    NSMutableArray *out = [NSMutableArray array];
    for (HCGRegistryEntry *e in entries) {
        if (![e.lifecycle isEqualToString:@"active"]) continue;
        NSMutableArray *requirements = [NSMutableArray arrayWithArray:e.requirements];
        NSMutableSet *ids = [NSMutableSet set];
        for (HCGRegistryRequirement *r in requirements) [ids addObject:r.identifier];
        BOOL counts = !e.isPlanned && ![e.kind isEqualToString:@"feature"];
        if (counts && [e.centralRegistration isEqualToString:@"not-registered"] && ![ids containsObject:@"register-central"]) {
            HCGRegistryRequirement *r = [[HCGRegistryRequirement alloc] init];
            r.identifier = @"register-central";
            r.title = [NSString stringWithFormat:@"Register %@ in the central product registry", e.officialName];
            r.detail = @"No central product ID exists, so access cannot be checked centrally (ERP › App Access).";
            r.kind = @"registration";
            [requirements addObject:r];
        }
        for (HCGRegistryRequirement *r in requirements) {
            HCGDevelopmentGap *g = [[HCGDevelopmentGap alloc] init];
            g.stableID = [NSString stringWithFormat:@"nexus.%@.%@", e.identifier, r.identifier];
            g.productID = e.identifier;
            g.productName = e.officialName;
            g.title = r.title;
            g.detail = r.detail;
            g.kind = r.kind;
            g.blocking = r.blocking;
            if (g.stableID.length <= 120) [out addObject:g];
        }
    }
    return out;
}

static NSString *Fingerprint(NSString *title, NSString *notes) {
    NSData *d = [[NSString stringWithFormat:@"%@\n%@", title, notes] dataUsingEncoding:NSUTF8StringEncoding];
    return [[HCGDigest hexDigestOfData:d algorithm:HCGDigestAlgorithmSHA256] substringToIndex:16];
}

static NSString *const kProjectID = @"nexus.ecosystem";

+ (HCGLifeOSExport *)lifeOSExportForGaps:(NSArray *)gaps exported:(NSDictionary *)exported registryVersion:(NSInteger)registryVersion
                               requestID:(NSString *)requestID now:(NSDate *)now {
    NSDictionary *done = [exported isKindOfClass:[NSDictionary class]] ? exported : [NSDictionary dictionary];
    NSMutableArray *operations = [NSMutableArray array], *included = [NSMutableArray array], *changed = [NSMutableArray array];
    NSMutableDictionary *fingerprints = [NSMutableDictionary dictionary];
    NSUInteger skipped = 0;
    NSMutableSet *seen = [NSMutableSet set];
    NSString *date = [When(now) substringToIndex:10];
    for (HCGDevelopmentGap *g in gaps) {
        if ([seen containsObject:g.stableID]) continue; // never twice in one file (LifeOS: duplicate_id)
        [seen addObject:g.stableID];
        NSString *title = Short([NSString stringWithFormat:@"%@: %@", g.productName, g.title], 300);
        NSString *notes = Short(g.detail ?: @"", 20000);
        NSString *fp = Fingerprint(title, notes);
        NSString *previous = [done objectForKey:g.stableID];
        if (previous) {
            if ([previous isEqual:fp]) skipped++;
            else [changed addObject:g.stableID];
            continue; // already in LifeOS: a new add would conflict; update it there
        }
        NSDictionary *source = [NSDictionary dictionaryWithObjectsAndKeys:@"hcg-nexus", @"app", [NSNumber numberWithInteger:registryVersion], @"registryVersion",
                                                                          g.productID, @"product", g.kind, @"kind", date, @"exported", nil];
        NSDictionary *fields = [NSDictionary dictionaryWithObjectsAndKeys:
            title, @"title", notes, @"notes",
            [NSString stringWithFormat:@"Development gap in the HCG ecosystem, exported by HCG Nexus (registry version %ld). Stable ID %@.", (long)registryVersion, g.stableID], @"description",
            g.blocking ? @"Stuck" : @"Later", @"status", g.blocking ? @"high" : @"medium", @"priority",
            kProjectID, @"project_id", [NSNull null], @"parent_id", [NSNull null], @"due_date", [NSNull null], @"start_date",
            [NSArray array], @"dependencies", [NSNull null], @"progress", source, @"source", nil];
        [operations addObject:[NSDictionary dictionaryWithObjectsAndKeys:@"task", @"kind", g.stableID, @"id", [NSNumber numberWithInt:0], @"expected_revision",
                                                                         [NSNumber numberWithBool:NO], @"deleted", fields, @"fields", nil]];
        [included addObject:g.stableID];
        [fingerprints setObject:fp forKey:g.stableID];
        if (operations.count >= 1999) break;
    }
    HCGLifeOSExport *x = [[HCGLifeOSExport alloc] init];
    x.changed = changed;
    x.alreadyExported = skipped;
    if (operations.count && ![done objectForKey:kProjectID]) {
        NSDictionary *project = [NSDictionary dictionaryWithObjectsAndKeys:@"HCG ecosystem integration (from HCG Nexus)", @"title",
                                                                          @"Development gaps HCG Nexus found in the HCG ecosystem registry.", @"notes", nil];
        [operations insertObject:[NSDictionary dictionaryWithObjectsAndKeys:@"project", @"kind", kProjectID, @"id", [NSNumber numberWithInt:0], @"expected_revision",
                                                                            [NSNumber numberWithBool:NO], @"deleted", project, @"fields", nil] atIndex:0];
        [included insertObject:kProjectID atIndex:0];
        [fingerprints setObject:@"project" forKey:kProjectID];
    }
    x.included = included;
    x.fingerprints = fingerprints;
    if (operations.count) {
        x.payload = [NSDictionary dictionaryWithObjectsAndKeys:@"lifeos.v1", @"version", requestID, @"request_id", operations, @"operations", nil];
    }
    return x;
}

+ (NSDictionary *)exportedStore:(NSDictionary *)exported byMarking:(HCGLifeOSExport *)export_ {
    NSMutableDictionary *out = [NSMutableDictionary dictionary];
    if ([exported isKindOfClass:[NSDictionary class]]) {
        for (id key in exported) {
            id v = [exported objectForKey:key];
            if ([key isKindOfClass:[NSString class]] && [v isKindOfClass:[NSString class]]) [out setObject:v forKey:key];
        }
    }
    [out addEntriesFromDictionary:export_.fingerprints];
    return out;
}

#pragma mark Evidence layers

static NSArray *Layer(NSString *title, NSString *value) {
    return [NSArray arrayWithObjects:title, value, nil];
}

+ (NSArray *)evidenceLayersForEntry:(HCGRegistryEntry *)entry connection:(HCGConnectionSummary *)connection hipStatus:(HCGHIPProductStatus *)hip
                             ledger:(NSArray *)ledger registry:(HCGRegistry *)registry now:(NSDate *)now {
    NSMutableArray *rows = [NSMutableArray array];
    // 1. Registered product: the central registry's own state (registration in Nexus's file is not central).
    NSString *reg = [entry.centralRegistration isEqualToString:@"registered"]
                  ? [NSString stringWithFormat:@"Registered centrally as %@", entry.centralProductID ?: @"—"]
                  : ([entry.centralRegistration isEqualToString:@"proposed"] ? @"Proposed only: not in the central registry"
                  : ([entry.centralRegistration isEqualToString:@"not-registered"] ? @"Not in the central registry"
                  : [NSString stringWithFormat:@"%@ of %@", [entry.centralRegistration capitalizedString], entry.centralProductID ?: @"HCG Nexus"]));
    [rows addObject:Layer(@"Registered product", reg)];
    // 2. Installed application.
    NSString *installed = @"Not applicable (nothing installs on this iPhone)";
    if (hip) {
        if (hip.installed) installed = [NSString stringWithFormat:@"Installed%@", hip.versionText.length ? [@" · " stringByAppendingString:hip.versionText] : @""];
        else if (hip.availability == HCGHIPAvailabilityUnknown) installed = @"Unable to check (sandboxed app)";
        else if (hip.availability == HCGHIPAvailabilityNotAvailable || hip.availability == HCGHIPAvailabilityHub) installed = hip.availability == HCGHIPAvailabilityHub ? @"This app" : @"Not applicable";
        else installed = @"Not installed";
    }
    [rows addObject:Layer(@"Installed application", installed)];
    // 3. Available service (public reads) and 4. Authenticated connection, from the ledger by access class.
    NSDate *lastPublic = nil, *lastAuth = nil, *lastLocal = nil;
    for (NSDictionary *e in [HCGConnectionLedger entries:ledger ?: [NSArray array] forProduct:entry.identifier]) {
        if (![[e objectForKey:@"ok"] boolValue]) continue;
        HCGRegistryMethod *m = [registry methodWithIdentifier:[e objectForKey:@"method"]];
        NSDate *t = [NSDate dateWithTimeIntervalSince1970:[[e objectForKey:@"time"] doubleValue]];
        if ([m.access isEqualToString:@"public"] && (!lastPublic || [t compare:lastPublic] == NSOrderedDescending)) lastPublic = t;
        if ([m.access isEqualToString:@"authenticated"] && (!lastAuth || [t compare:lastAuth] == NSOrderedDescending)) lastAuth = t;
        if ([m.access isEqualToString:@"local"] && (!lastLocal || [t compare:lastLocal] == NSOrderedDescending)) lastLocal = t;
    }
    BOOL hasPublicEndpoint = entry.endpoints.count > 0;
    [rows addObject:Layer(@"Available service", lastPublic ? [NSString stringWithFormat:@"Public read succeeded %@", When(lastPublic)]
                                              : (hasPublicEndpoint ? @"A public endpoint is registered; not read yet" : @"No public service registered"))];
    NSString *auth = @"None: Nexus holds no HCG account or token";
    if (hip.availability == HCGHIPAvailabilityConnected) auth = [NSString stringWithFormat:@"Signed HCG Device Link exchange · %@", hip.integrationText];
    else if (lastAuth) auth = [NSString stringWithFormat:@"Authenticated exchange %@", When(lastAuth)];
    else if (lastLocal) auth = [NSString stringWithFormat:@"Not authenticated · its local interface answered %@", When(lastLocal)];
    [rows addObject:Layer(@"Authenticated connection", auth)];
    // 5. Verified capability: only capabilities with device evidence.
    NSMutableArray *verified = [NSMutableArray array];
    NSArray *caps = hip ? hip.descriptor.capabilities : entry.capabilities;
    for (HCGHIPCapability *c in caps) if (c.state == HCGHIPCapabilityStateVerified) [verified addObject:c.title];
    [rows addObject:Layer(@"Verified capability", verified.count ? [verified componentsJoinedByString:@", "] : @"None verified on a device")];
    // 6. Current connection health.
    [rows addObject:Layer(@"Current connection health", [NSString stringWithFormat:@"%@ — %@", connection.title, connection.detail])];
    // 7. Historical validation (never the current state).
    HCGRegistryValidation *v = entry.validations.count ? [entry.validations objectAtIndex:0] : nil;
    [rows addObject:Layer(@"Historical validation", v ? [NSString stringWithFormat:@"%@ on %@ (%@)", v.version.length ? v.version : @"Validated", v.device, v.date]
                                                     : @"No device validation recorded")];
    return rows;
}

+ (NSArray *)favoritesFromStoredValue:(id)value {
    NSMutableArray *out = [NSMutableArray array];
    if (![value isKindOfClass:[NSArray class]]) return out;
    for (id item in value) {
        if (HCGRegistryIsValidIdentifier(item) && ![out containsObject:item] && out.count < 40) [out addObject:item];
    }
    return out;
}

@end
