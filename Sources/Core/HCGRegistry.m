#import "HCGRegistry.h"

NSString *const HCGRegistrySchema = @"hcg.nexus.registry/1";

static NSString *const kAllowedHost = @"hakmicapitalgroup.com";

BOOL HCGRegistryIsAllowedURL(NSString *text) {
    if (![text isKindOfClass:[NSString class]] || text.length < 10 || text.length > 200) return NO;
    if (![text hasPrefix:@"https://"]) return NO;
    NSCharacterSet *bad = [NSCharacterSet characterSetWithCharactersInString:@"?#@ \t\r\n\\\"'<>"];
    if ([text rangeOfCharacterFromSet:bad].location != NSNotFound) return NO;
    NSString *rest = [text substringFromIndex:8];
    NSRange slash = [rest rangeOfString:@"/"];
    NSString *host = [(slash.location == NSNotFound ? rest : [rest substringToIndex:slash.location]) lowercaseString];
    if ([host rangeOfString:@":"].location != NSNotFound) return NO; // no port
    NSCharacterSet *hostChars = [NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyz0123456789.-"];
    if (!host.length || [host rangeOfCharacterFromSet:[hostChars invertedSet]].location != NSNotFound) return NO;
    if ([host isEqualToString:kAllowedHost]) return YES;
    return [host hasSuffix:[@"." stringByAppendingString:kAllowedHost]] && ![host hasPrefix:@"."] && [host rangeOfString:@".."].location == NSNotFound;
}

BOOL HCGRegistryIsValidIdentifier(NSString *text) {
    if (![text isKindOfClass:[NSString class]] || text.length < 2 || text.length > 61) return NO;
    NSCharacterSet *allowed = [NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyz0123456789.-"];
    if ([text rangeOfCharacterFromSet:[allowed invertedSet]].location != NSNotFound) return NO;
    unichar first = [text characterAtIndex:0];
    return (first >= 'a' && first <= 'z') || (first >= '0' && first <= '9');
}

static NSString *Text(id value, NSUInteger limit) {
    if (![value isKindOfClass:[NSString class]]) return nil;
    NSString *s = [value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (!s.length) return nil;
    return s.length > limit ? [s substringToIndex:limit] : s;
}

static NSArray *TextList(id value, NSUInteger count, NSUInteger limit) {
    NSMutableArray *out = [NSMutableArray array];
    if (![value isKindOfClass:[NSArray class]]) return out;
    for (id item in value) {
        NSString *s = Text(item, limit);
        if (s && out.count < count) [out addObject:s];
    }
    return out;
}

static BOOL OneOf(NSString *value, NSString *list) {
    if (!value.length) return NO;
    return [[list componentsSeparatedByString:@" "] containsObject:value];
}

static NSDictionary *Dict(id value) {
    return [value isKindOfClass:[NSDictionary class]] ? value : nil;
}

#pragma mark - Model

@implementation HCGRegistryCategory
@synthesize identifier = _identifier, name = _name, symbolName = _symbolName;
@end

@implementation HCGRegistryMethod
@synthesize identifier = _identifier, name = _name, kind = _kind, detail = _detail, twoWay = _twoWay, access = _access;
@end

@implementation HCGRegistryConnection
@synthesize method = _method, state = _state, detail = _detail;
@end

@implementation HCGRegistryRequirement
@synthesize identifier = _identifier, title = _title, detail = _detail, kind = _kind, blocking = _blocking;
@end

@implementation HCGRegistryEndpoint
@synthesize identifier = _identifier, url = _url, detail = _detail, verified = _verified;
@end

@implementation HCGRegistryValidation
@synthesize date = _date, device = _device, version = _version, summary = _summary;
@end

@implementation HCGRegistryDeviceClass
@synthesize identifier = _identifier, name = _name, symbolName = _symbolName, systemTesterCategories = _systemTesterCategories,
            examples = _examples, adapters = _adapters, missing = _missing, instructions = _instructions, safety = _safety;
@end

@implementation HCGRegistryEntry
@synthesize identifier = _identifier, officialName = _officialName, aliases = _aliases, categoryID = _categoryID, summary = _summary,
            kind = _kind, hipProductID = _hipProductID, adapter = _adapter, platforms = _platforms,
            developmentStatus = _developmentStatus, lifecycle = _lifecycle, visibility = _visibility, entitlement = _entitlement,
            nameVerified = _nameVerified, centralProductID = _centralProductID, centralRegistration = _centralRegistration,
            centralName = _centralName, centralNote = _centralNote, distributionChannel = _distributionChannel,
            repoPackage = _repoPackage, websiteURL = _websiteURL, contractID = _contractID, contractStatus = _contractStatus,
            contractDetail = _contractDetail, endpoints = _endpoints, connections = _connections, capabilities = _capabilities,
            requirements = _requirements, validations = _validations, notes = _notes, lastVerified = _lastVerified,
            verifiedFrom = _verifiedFrom, fromUpdate = _fromUpdate, securityReview = _securityReview;

- (BOOL)isPlanned {
    return [self.kind isEqualToString:@"planned"] || [self.developmentStatus isEqualToString:@"planned"] ||
           [self.developmentStatus isEqualToString:@"research"];
}

- (HCGRegistryEntry *)entryCopy {
    HCGRegistryEntry *e = [[HCGRegistryEntry alloc] init];
    e.identifier = self.identifier; e.officialName = self.officialName; e.aliases = self.aliases; e.categoryID = self.categoryID;
    e.summary = self.summary; e.kind = self.kind; e.hipProductID = self.hipProductID; e.adapter = self.adapter; e.platforms = self.platforms;
    e.developmentStatus = self.developmentStatus; e.lifecycle = self.lifecycle; e.visibility = self.visibility; e.entitlement = self.entitlement;
    e.nameVerified = self.nameVerified; e.centralProductID = self.centralProductID; e.centralRegistration = self.centralRegistration;
    e.centralName = self.centralName; e.centralNote = self.centralNote; e.distributionChannel = self.distributionChannel;
    e.repoPackage = self.repoPackage; e.websiteURL = self.websiteURL; e.contractID = self.contractID; e.contractStatus = self.contractStatus;
    e.contractDetail = self.contractDetail; e.endpoints = self.endpoints; e.connections = self.connections; e.capabilities = self.capabilities;
    e.requirements = self.requirements; e.validations = self.validations; e.notes = self.notes; e.lastVerified = self.lastVerified;
    e.verifiedFrom = self.verifiedFrom; e.fromUpdate = self.fromUpdate; e.securityReview = self.securityReview;
    return e;
}

- (HCGRegistryEndpoint *)endpointWithIdentifier:(NSString *)identifier {
    for (HCGRegistryEndpoint *e in self.endpoints) if ([e.identifier isEqualToString:identifier]) return e;
    return nil;
}

- (HCGRegistryConnection *)connectionForMethod:(NSString *)method {
    for (HCGRegistryConnection *c in self.connections) if ([c.method isEqualToString:method]) return c;
    return nil;
}
@end

#pragma mark - Parsing

static HCGHIPCapabilityState CapabilityState(NSString *s) {
    if ([s isEqualToString:@"verified"]) return HCGHIPCapabilityStateVerified;
    if ([s isEqualToString:@"available"]) return HCGHIPCapabilityStateAvailable;
    if ([s isEqualToString:@"unavailable"]) return HCGHIPCapabilityStateUnavailable;
    return HCGHIPCapabilityStatePlanned;
}

static HCGHIPPermission Permission(NSString *s) {
    if ([s isEqualToString:@"approval-in-product"]) return HCGHIPPermissionApprovalInProduct;
    if ([s isEqualToString:@"product-owned-switch"]) return HCGHIPPermissionProductOwnedSwitch;
    if ([s isEqualToString:@"not-offered"]) return HCGHIPPermissionNotOffered;
    return HCGHIPPermissionNone;
}

// One entry, or nil with `problem` set.
static HCGRegistryEntry *ParseEntry(NSDictionary *d, NSSet *categories, NSSet *methods, NSString **problem) {
    NSString *identifier = Text([d objectForKey:@"id"], 61);
    NSString *name = Text([d objectForKey:@"officialName"], 80);
    NSString *label = identifier ?: @"(no id)";
    if (!HCGRegistryIsValidIdentifier(identifier) || !name) {
        *problem = [NSString stringWithFormat:@"Entry %@: invalid id or name.", label];
        return nil;
    }
    HCGRegistryEntry *e = [[HCGRegistryEntry alloc] init];
    e.identifier = identifier;
    e.officialName = name;
    e.aliases = TextList([d objectForKey:@"aliases"], 4, 80);
    id category = [d objectForKey:@"category"];
    if ([category isKindOfClass:[NSString class]]) {
        if (![categories containsObject:category]) {
            *problem = [NSString stringWithFormat:@"Entry %@: unknown category.", label];
            return nil;
        }
        e.categoryID = category;
    } else if (category && category != [NSNull null]) {
        *problem = [NSString stringWithFormat:@"Entry %@: invalid category.", label];
        return nil;
    }
    e.summary = Text([d objectForKey:@"description"], 400) ?: @"";
    e.kind = Text([d objectForKey:@"kind"], 20) ?: @"planned";
    if (!OneOf(e.kind, @"hub app tweak service website identity repository feature planned")) {
        *problem = [NSString stringWithFormat:@"Entry %@: unknown kind.", label];
        return nil;
    }
    NSString *adapter = Text([d objectForKey:@"adapter"], 40);
    if ([adapter hasPrefix:@"hip:"]) {
        e.hipProductID = [adapter substringFromIndex:4];
        adapter = @"hip";
    }
    NSString *hip = Text([d objectForKey:@"hip"], 40);
    if (hip) e.hipProductID = hip;
    if (adapter && !OneOf(adapter, @"hip news.v1 connect.discovery system-tester.inventory lifeos.export trust-center store.health store.release central.registry")) {
        *problem = [NSString stringWithFormat:@"Entry %@: unknown adapter (ignored).", label];
        adapter = nil;
    }
    e.adapter = adapter;
    if (e.hipProductID && ![HCGInterchange descriptorForProductID:e.hipProductID]) e.hipProductID = nil;
    e.platforms = TextList([d objectForKey:@"platforms"], 8, 30);
    e.developmentStatus = Text([d objectForKey:@"developmentStatus"], 20) ?: @"research";
    if (!OneOf(e.developmentStatus, @"planned research in-development testing beta released")) e.developmentStatus = @"research";
    e.lifecycle = Text([d objectForKey:@"lifecycle"], 20) ?: @"active";
    if (!OneOf(e.lifecycle, @"active suspended retired")) e.lifecycle = @"suspended"; // unknown: offer nothing
    e.visibility = Text([d objectForKey:@"visibility"], 20) ?: @"listed";
    if (![e.visibility isEqualToString:@"listed"]) {
        // Anything but "listed" is private and needs an entitlement; without a valid one the entry is never shown.
        e.visibility = @"private";
        NSDictionary *ent = Dict([d objectForKey:@"entitlement"]);
        NSString *product = Text([ent objectForKey:@"product"], 82), *feature = Text([ent objectForKey:@"feature"], 82);
        e.entitlement = product && feature ? [NSString stringWithFormat:@"%@/%@", product, feature] : nil;
    }
    id nv = [d objectForKey:@"nameVerified"];
    e.nameVerified = ![nv isKindOfClass:[NSNumber class]] || [nv boolValue];
    NSDictionary *central = Dict([d objectForKey:@"central"]);
    e.centralProductID = Text([central objectForKey:@"productId"], 82);
    e.centralRegistration = Text([central objectForKey:@"registration"], 20) ?: @"not-registered";
    if (!OneOf(e.centralRegistration, @"registered proposed not-registered edition surface component feature")) e.centralRegistration = @"not-registered";
    e.centralName = Text([central objectForKey:@"name"], 80);
    e.centralNote = Text([central objectForKey:@"note"], 300);
    NSDictionary *distribution = Dict([d objectForKey:@"distribution"]);
    e.distributionChannel = Text([distribution objectForKey:@"channel"], 40);
    e.repoPackage = Text([distribution objectForKey:@"repoPackage"], 100);
    NSDictionary *links = Dict([d objectForKey:@"links"]);
    NSString *website = Text([links objectForKey:@"website"], 200);
    if (website && !HCGRegistryIsAllowedURL(website)) {
        *problem = [NSString stringWithFormat:@"Entry %@: website link refused (only https://*.hakmicapitalgroup.com without parameters).", label];
        website = nil;
    }
    e.websiteURL = website;
    NSDictionary *contract = Dict([d objectForKey:@"contract"]);
    e.contractID = Text([contract objectForKey:@"id"], 80);
    e.contractStatus = Text([contract objectForKey:@"status"], 20) ?: @"unknown";
    if (!OneOf(e.contractStatus, @"available planned none unknown")) e.contractStatus = @"unknown";
    e.contractDetail = Text([contract objectForKey:@"detail"], 400);

    NSMutableArray *endpoints = [NSMutableArray array];
    id list = [d objectForKey:@"endpoints"];
    if ([list isKindOfClass:[NSArray class]]) {
        for (id item in list) {
            NSDictionary *ed = Dict(item);
            NSString *eid = Text([ed objectForKey:@"id"], 60), *url = Text([ed objectForKey:@"url"], 200);
            if (!eid || !HCGRegistryIsAllowedURL(url) || ![[ed objectForKey:@"auth"] isEqual:@"none"] || ![[ed objectForKey:@"access"] isEqual:@"read"]) {
                *problem = [NSString stringWithFormat:@"Entry %@: an endpoint was refused (anonymous read-only https endpoints only).", label];
                continue;
            }
            HCGRegistryEndpoint *ep = [[HCGRegistryEndpoint alloc] init];
            ep.identifier = eid;
            ep.url = url;
            ep.detail = Text([ed objectForKey:@"detail"], 300) ?: @"";
            ep.verified = Text([ed objectForKey:@"verified"], 200) ?: @"not verified";
            if (endpoints.count < 8) [endpoints addObject:ep];
        }
    }
    e.endpoints = endpoints;

    NSMutableArray *connections = [NSMutableArray array];
    list = [d objectForKey:@"connectionMethods"];
    if ([list isKindOfClass:[NSArray class]]) {
        for (id item in list) {
            NSDictionary *cd = Dict(item);
            NSString *method = Text([cd objectForKey:@"method"], 40), *state = Text([cd objectForKey:@"state"], 20);
            if (![methods containsObject:method] || !OneOf(state, @"implemented planned unavailable")) continue;
            HCGRegistryConnection *c = [[HCGRegistryConnection alloc] init];
            c.method = method;
            c.state = state;
            c.detail = Text([cd objectForKey:@"detail"], 300) ?: @"";
            if (connections.count < 10) [connections addObject:c];
        }
    }
    e.connections = connections;

    NSMutableArray *capabilities = [NSMutableArray array];
    list = [d objectForKey:@"capabilities"];
    if ([list isKindOfClass:[NSArray class]]) {
        for (id item in list) {
            NSDictionary *cd = Dict(item);
            NSString *cid = Text([cd objectForKey:@"id"], 40), *title = Text([cd objectForKey:@"title"], 120);
            if (!cid || !title) continue;
            HCGHIPCapability *cap = [[HCGHIPCapability alloc] init];
            cap.identifier = cid;
            cap.title = title;
            cap.state = CapabilityState(Text([cd objectForKey:@"state"], 20));
            cap.permission = Permission(Text([cd objectForKey:@"permission"], 30));
            cap.note = Text([cd objectForKey:@"note"], 300) ?: @"";
            if (capabilities.count < 16) [capabilities addObject:cap];
        }
    }
    e.capabilities = capabilities;

    NSMutableArray *requirements = [NSMutableArray array];
    NSMutableSet *requirementIDs = [NSMutableSet set];
    list = [d objectForKey:@"requirements"];
    if ([list isKindOfClass:[NSArray class]]) {
        for (id item in list) {
            NSDictionary *rd = Dict(item);
            NSString *rid = Text([rd objectForKey:@"id"], 40), *title = Text([rd objectForKey:@"title"], 160);
            if (!HCGRegistryIsValidIdentifier(rid) || !title || [requirementIDs containsObject:rid]) continue;
            [requirementIDs addObject:rid];
            HCGRegistryRequirement *r = [[HCGRegistryRequirement alloc] init];
            r.identifier = rid;
            r.title = title;
            r.detail = Text([rd objectForKey:@"detail"], 400) ?: @"";
            r.kind = Text([rd objectForKey:@"kind"], 20) ?: @"development";
            if (!OneOf(r.kind, @"registration configuration contract access development research")) r.kind = @"development";
            r.blocking = [[rd objectForKey:@"blocking"] isKindOfClass:[NSNumber class]] && [[rd objectForKey:@"blocking"] boolValue];
            if (requirements.count < 12) [requirements addObject:r];
        }
    }
    e.requirements = requirements;

    NSMutableArray *validations = [NSMutableArray array];
    list = [d objectForKey:@"validations"];
    if ([list isKindOfClass:[NSArray class]]) {
        for (id item in list) {
            NSDictionary *vd = Dict(item);
            NSString *date = Text([vd objectForKey:@"date"], 10), *device = Text([vd objectForKey:@"device"], 120), *summary = Text([vd objectForKey:@"summary"], 300);
            if (!date || !device || !summary) continue;
            HCGRegistryValidation *v = [[HCGRegistryValidation alloc] init];
            v.date = date;
            v.device = device;
            v.version = Text([vd objectForKey:@"version"], 40) ?: @"";
            v.summary = summary;
            if (validations.count < 12) [validations addObject:v];
        }
    }
    e.validations = validations;
    e.notes = TextList([d objectForKey:@"notes"], 6, 300);
    e.lastVerified = Text([d objectForKey:@"lastVerified"], 10) ?: @"not verified";
    e.verifiedFrom = Text([d objectForKey:@"verifiedFrom"], 400) ?: @"";
    NSDictionary *review = Dict([d objectForKey:@"securityReview"]);
    NSString *rd = Text([review objectForKey:@"date"], 10), *rs = Text([review objectForKey:@"summary"], 300);
    if (rd && rs) e.securityReview = [NSString stringWithFormat:@"%@: %@", rd, rs];
    return e;
}

@implementation HCGRegistry
@synthesize version = _version, generatedAt = _generatedAt, source = _source, categories = _categories, methods = _methods,
            entries = _entries, deviceClasses = _deviceClasses, problems = _problems;

+ (instancetype)registryWithJSONData:(NSData *)data source:(NSString *)source error:(NSString **)error {
    if (!data.length || data.length > 1024 * 1024) {
        if (error) *error = data.length ? @"The registry file is larger than 1 MB." : @"No registry data.";
        return nil;
    }
    id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
    NSDictionary *root = Dict(json);
    if (!root) {
        if (error) *error = @"The registry file is not a JSON object.";
        return nil;
    }
    if (![[root objectForKey:@"schema"] isEqual:HCGRegistrySchema]) {
        if (error) *error = @"Not an hcg.nexus.registry/1 document.";
        return nil;
    }
    id version = [root objectForKey:@"registryVersion"];
    if (![version isKindOfClass:[NSNumber class]] || [version integerValue] < 1) {
        if (error) *error = @"The registry has no valid registryVersion.";
        return nil;
    }
    HCGRegistry *r = [[HCGRegistry alloc] init];
    r.version = [version integerValue];
    r.generatedAt = Text([root objectForKey:@"generatedAt"], 10) ?: @"unknown";
    r.source = source;
    NSMutableArray *problems = [NSMutableArray array];

    NSMutableArray *categories = [NSMutableArray array];
    NSMutableSet *categoryIDs = [NSMutableSet set];
    id list = [root objectForKey:@"categories"];
    if ([list isKindOfClass:[NSArray class]]) {
        for (id item in list) {
            NSDictionary *cd = Dict(item);
            NSString *cid = Text([cd objectForKey:@"id"], 40), *name = Text([cd objectForKey:@"name"], 60);
            if (!HCGRegistryIsValidIdentifier(cid) || !name || [categoryIDs containsObject:cid]) continue;
            HCGRegistryCategory *c = [[HCGRegistryCategory alloc] init];
            c.identifier = cid;
            c.name = name;
            c.symbolName = Text([cd objectForKey:@"symbol"], 60) ?: @"square.grid.2x2";
            [categoryIDs addObject:cid];
            [categories addObject:c];
        }
    }
    r.categories = categories;

    NSMutableArray *methods = [NSMutableArray array];
    NSMutableSet *methodIDs = [NSMutableSet set];
    list = [root objectForKey:@"connectionMethods"];
    if ([list isKindOfClass:[NSArray class]]) {
        for (id item in list) {
            NSDictionary *md = Dict(item);
            NSString *mid = Text([md objectForKey:@"id"], 40), *name = Text([md objectForKey:@"name"], 80);
            if (!HCGRegistryIsValidIdentifier(mid) || !name || [methodIDs containsObject:mid]) continue;
            HCGRegistryMethod *m = [[HCGRegistryMethod alloc] init];
            m.identifier = mid;
            m.name = name;
            m.kind = Text([md objectForKey:@"kind"], 20) ?: @"local";
            m.detail = Text([md objectForKey:@"detail"], 300) ?: @"";
            m.twoWay = [[md objectForKey:@"twoWay"] isKindOfClass:[NSNumber class]] && [[md objectForKey:@"twoWay"] boolValue];
            m.access = Text([md objectForKey:@"access"], 20) ?: @"none";
            if (!OneOf(m.access, @"public local authenticated none")) m.access = @"none";
            // Never stronger than what the method can carry: navigation proves nothing, an anonymous read is public.
            if (!m.twoWay) m.access = @"none";
            [methodIDs addObject:mid];
            [methods addObject:m];
        }
    }
    r.methods = methods;

    NSMutableArray *entries = [NSMutableArray array];
    NSMutableSet *entryIDs = [NSMutableSet set];
    list = [root objectForKey:@"products"];
    if ([list isKindOfClass:[NSArray class]]) {
        for (id item in list) {
            NSDictionary *pd = Dict(item);
            if (!pd) continue;
            NSString *problem = nil;
            HCGRegistryEntry *e = ParseEntry(pd, categoryIDs, methodIDs, &problem);
            if (problem) [problems addObject:problem];
            if (!e) continue;
            if ([entryIDs containsObject:e.identifier]) {
                [problems addObject:[NSString stringWithFormat:@"Entry %@ is listed twice; the second was ignored.", e.identifier]];
                continue;
            }
            if (entries.count >= 400) break;
            [entryIDs addObject:e.identifier];
            [entries addObject:e];
        }
    }
    r.entries = entries;

    NSMutableArray *classes = [NSMutableArray array];
    list = [root objectForKey:@"deviceClasses"];
    if ([list isKindOfClass:[NSArray class]]) {
        for (id item in list) {
            NSDictionary *dd = Dict(item);
            NSString *did = Text([dd objectForKey:@"id"], 40), *name = Text([dd objectForKey:@"name"], 60);
            if (!HCGRegistryIsValidIdentifier(did) || !name) continue;
            HCGRegistryDeviceClass *c = [[HCGRegistryDeviceClass alloc] init];
            c.identifier = did;
            c.name = name;
            c.symbolName = Text([dd objectForKey:@"symbol"], 60) ?: @"cube";
            c.systemTesterCategories = TextList([dd objectForKey:@"systemTesterCategories"], 10, 40);
            c.examples = TextList([dd objectForKey:@"examples"], 6, 60);
            c.adapters = TextList([dd objectForKey:@"adapters"], 8, 60);
            c.missing = TextList([dd objectForKey:@"missing"], 6, 300);
            c.instructions = Text([dd objectForKey:@"instructions"], 400) ?: @"";
            c.safety = Text([dd objectForKey:@"safety"], 300) ?: @"Read-only through HCG System Tester.";
            if (classes.count < 40) [classes addObject:c];
        }
    }
    r.deviceClasses = classes;
    r.problems = problems;
    if (!entries.count) {
        if (error) *error = @"The registry lists no valid products.";
        return nil;
    }
    return r;
}

+ (instancetype)builtInRegistry {
    static HCGRegistry *builtIn = nil;
    @synchronized(self) {
        if (!builtIn) {
            NSString *error = nil;
            builtIn = [self registryWithJSONData:[HCGRegistryBuiltInJSON() dataUsingEncoding:NSUTF8StringEncoding] source:@"built in" error:&error];
#if !__has_feature(objc_arc)
            [builtIn retain];
#endif
        }
    }
    return builtIn;
}

// Copies the narrowing-safe parts of `update` onto a copy of `base`.
static HCGRegistryEntry *MergedEntry(HCGRegistryEntry *base, HCGRegistryEntry *update) {
    HCGRegistryEntry *e = [[HCGRegistryEntry alloc] init];
    e.identifier = base.identifier;
    // Identity and authority never come from an imported file: the official name, central ID and registration are the
    // central registry's (or the build's), and a private entry keeps its own entitlement.
    e.officialName = base.officialName;
    e.aliases = update.aliases;
    e.categoryID = update.categoryID ?: base.categoryID;
    e.summary = update.summary.length ? update.summary : base.summary;
    e.kind = base.kind;
    e.hipProductID = base.hipProductID;
    e.adapter = base.adapter;
    e.platforms = update.platforms.count ? update.platforms : base.platforms;
    e.developmentStatus = update.developmentStatus;
    e.lifecycle = update.lifecycle;
    // Private can only stay private (with the update's entitlement if it names one); listed may become private.
    e.visibility = [base.visibility isEqualToString:@"private"] || [update.visibility isEqualToString:@"private"] ? @"private" : @"listed";
    e.entitlement = [base.visibility isEqualToString:@"private"] ? base.entitlement
                  : ([e.visibility isEqualToString:@"private"] ? update.entitlement : nil); // listed → private only narrows
    e.nameVerified = base.nameVerified;
    e.centralProductID = base.centralProductID;
    e.centralRegistration = base.centralRegistration;
    e.centralName = base.centralName;
    e.centralNote = base.centralNote;
    e.distributionChannel = update.distributionChannel ?: base.distributionChannel;
    e.repoPackage = base.repoPackage;
    // Links and endpoints: only the base's, and only those the update still lists.
    e.websiteURL = base.websiteURL && [update.websiteURL isEqualToString:base.websiteURL] ? base.websiteURL : nil;
    NSMutableArray *endpoints = [NSMutableArray array];
    for (HCGRegistryEndpoint *ep in base.endpoints) {
        HCGRegistryEndpoint *same = [update endpointWithIdentifier:ep.identifier];
        if (same && [same.url isEqualToString:ep.url]) [endpoints addObject:ep];
    }
    e.endpoints = endpoints;
    e.contractID = update.contractID ?: base.contractID;
    e.contractStatus = update.contractStatus;
    e.contractDetail = update.contractDetail ?: base.contractDetail;
    // Connection methods: the base's, kept only when the update still lists them; an update can lower their state.
    NSMutableArray *connections = [NSMutableArray array];
    for (HCGRegistryConnection *c in base.connections) {
        HCGRegistryConnection *u = [update connectionForMethod:c.method];
        if (!u) continue;
        HCGRegistryConnection *m = [[HCGRegistryConnection alloc] init];
        m.method = c.method;
        m.state = [c.state isEqualToString:@"implemented"] ? u.state : c.state;
        m.detail = u.detail.length ? u.detail : c.detail;
        [connections addObject:m];
    }
    e.connections = connections;
    // Capabilities: never added, can only be lowered.
    NSMutableArray *capabilities = [NSMutableArray array];
    for (HCGHIPCapability *c in base.capabilities) {
        HCGHIPCapability *u = nil;
        for (HCGHIPCapability *x in update.capabilities) if ([x.identifier isEqualToString:c.identifier]) u = x;
        if (!u) continue;
        if (u.state == HCGHIPCapabilityStateUnavailable || u.state == HCGHIPCapabilityStatePlanned) {
            HCGHIPCapability *lower = [[HCGHIPCapability alloc] init];
            lower.identifier = c.identifier;
            lower.title = c.title;
            lower.state = u.state;
            lower.permission = c.permission;
            lower.note = u.note;
            [capabilities addObject:lower];
        } else {
            [capabilities addObject:c];
        }
    }
    e.capabilities = capabilities;
    e.requirements = update.requirements;
    e.validations = base.validations; // evidence is never imported
    e.securityReview = base.securityReview;
    e.notes = update.notes;
    e.lastVerified = update.lastVerified;
    e.verifiedFrom = update.verifiedFrom;
    e.fromUpdate = NO;
    return e;
}

// An entry the update adds: text and status only.
static HCGRegistryEntry *TextOnlyEntry(HCGRegistryEntry *update) {
    update.hipProductID = nil;
    update.adapter = nil;
    update.websiteURL = nil;
    update.endpoints = [NSArray array];
    NSMutableArray *connections = [NSMutableArray array];
    for (HCGRegistryConnection *c in update.connections) {
        HCGRegistryConnection *m = [[HCGRegistryConnection alloc] init];
        m.method = c.method;
        m.state = [c.state isEqualToString:@"implemented"] ? @"planned" : c.state;
        m.detail = c.detail;
        [connections addObject:m];
    }
    update.connections = connections;
    NSMutableArray *capabilities = [NSMutableArray array];
    for (HCGHIPCapability *c in update.capabilities) {
        if (c.state == HCGHIPCapabilityStateAvailable || c.state == HCGHIPCapabilityStateVerified) c.state = HCGHIPCapabilityStatePlanned;
        [capabilities addObject:c];
    }
    update.capabilities = capabilities;
    update.validations = [NSArray array];
    update.securityReview = nil;
    update.fromUpdate = YES;
    // An imported entry cannot claim central registration or a verified name: only the central registry can.
    update.centralRegistration = @"not-registered";
    update.nameVerified = NO;
    if ([update.visibility isEqualToString:@"private"] && !update.entitlement) update.visibility = @"private";
    if ([update.kind isEqualToString:@"hub"]) update.kind = @"planned";
    return update;
}

- (HCGRegistry *)registryByApplyingUpdate:(HCGRegistry *)update problem:(NSString **)problem {
    if (!update || update.version <= self.version) {
        if (problem) *problem = [NSString stringWithFormat:@"The update (version %ld) is not newer than this registry (version %ld).", (long)update.version, (long)self.version];
        return self;
    }
    HCGRegistry *r = [[HCGRegistry alloc] init];
    r.version = update.version;
    r.generatedAt = update.generatedAt;
    r.source = [NSString stringWithFormat:@"%@ + update %ld (imported, unsigned: text and status only)", self.source, (long)update.version];
    NSMutableArray *categories = [NSMutableArray arrayWithArray:self.categories];
    for (HCGRegistryCategory *c in update.categories) if (![self categoryWithIdentifier:c.identifier]) [categories addObject:c];
    r.categories = categories;
    r.methods = self.methods; // connection methods are Nexus code, never imported
    NSMutableArray *entries = [NSMutableArray array];
    for (HCGRegistryEntry *base in self.entries) {
        HCGRegistryEntry *u = [update entryWithIdentifier:base.identifier];
        [entries addObject:u ? MergedEntry(base, u) : base];
    }
    for (HCGRegistryEntry *u in update.entries) {
        if (![self entryWithIdentifier:u.identifier] && entries.count < 400) [entries addObject:TextOnlyEntry(u)];
    }
    r.entries = entries;
    r.deviceClasses = self.deviceClasses;
    NSMutableArray *problems = [NSMutableArray arrayWithArray:self.problems];
    [problems addObjectsFromArray:update.problems];
    r.problems = problems;
    return r;
}

- (NSArray *)visibleEntriesWithGrants:(NSSet *)grants {
    NSMutableArray *out = [NSMutableArray array];
    for (HCGRegistryEntry *e in self.entries) {
        if ([e.visibility isEqualToString:@"listed"]) [out addObject:e];
        else if (e.entitlement && [grants containsObject:e.entitlement]) [out addObject:e];
    }
    return out;
}

- (HCGRegistryEntry *)entryWithIdentifier:(NSString *)identifier {
    if (!identifier) return nil;
    for (HCGRegistryEntry *e in self.entries) if ([e.identifier isEqualToString:identifier]) return e;
    return nil;
}

- (HCGRegistryEntry *)entryForHIPProductID:(NSString *)productID {
    if (!productID) return nil;
    for (HCGRegistryEntry *e in self.entries) if ([e.hipProductID isEqualToString:productID]) return e;
    return nil;
}

- (HCGRegistryCategory *)categoryWithIdentifier:(NSString *)identifier {
    if (!identifier) return nil;
    for (HCGRegistryCategory *c in self.categories) if ([c.identifier isEqualToString:identifier]) return c;
    return nil;
}

- (HCGRegistryMethod *)methodWithIdentifier:(NSString *)identifier {
    if (!identifier) return nil;
    for (HCGRegistryMethod *m in self.methods) if ([m.identifier isEqualToString:identifier]) return m;
    return nil;
}

+ (NSArray *)entries:(NSArray *)entries matchingQuery:(NSString *)query registry:(HCGRegistry *)registry {
    NSString *q = [[query stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] lowercaseString];
    if (!q.length) return entries;
    NSMutableArray *words = [NSMutableArray array];
    for (NSString *w in [q componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]) if (w.length) [words addObject:w];
    NSMutableArray *out = [NSMutableArray array];
    for (HCGRegistryEntry *e in entries) {
        NSMutableString *hay = [NSMutableString stringWithString:e.officialName];
        for (NSString *a in e.aliases) [hay appendFormat:@" %@", a];
        [hay appendFormat:@" %@ %@ %@", e.summary, e.centralProductID ?: @"", e.identifier];
        HCGRegistryCategory *c = [registry categoryWithIdentifier:e.categoryID];
        if (c) [hay appendFormat:@" %@", c.name];
        NSString *lower = [hay lowercaseString];
        BOOL all = YES;
        for (NSString *w in words) if ([lower rangeOfString:w].location == NSNotFound) all = NO;
        if (all) [out addObject:e];
    }
    return out;
}

@end
