#import "HCGTrustRecords.h"
#import "HCGRepoTrust.h"
#import "HCGDigest.h"
#include <string.h>

static id HCGJSON(NSData *data) {
    if (![data isKindOfClass:[NSData class]] || data.length == 0 || data.length > 4 * 1024 * 1024) return nil;
    return [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
}

static NSString *HCGText(id value) {
    if ([value isKindOfClass:[NSString class]]) return [value length] ? value : nil;
    if ([value isKindOfClass:[NSNumber class]]) return [value stringValue];
    return nil;
}

static NSDictionary *HCGDict(id d, NSString *key) {
    id v = [d isKindOfClass:[NSDictionary class]] ? [d objectForKey:key] : nil;
    return [v isKindOfClass:[NSDictionary class]] ? v : nil;
}

static NSArray *HCGList(id d, NSString *key) {
    id v = [d isKindOfClass:[NSDictionary class]] ? [d objectForKey:key] : nil;
    return [v isKindOfClass:[NSArray class]] ? v : [NSArray array];
}

static NSArray *HCGPair(NSString *title, NSString *value) {
    return [NSArray arrayWithObjects:title, value ?: @"—", nil];
}

static NSString *HCGShort(NSString *s, NSUInteger max) {
    if (s.length <= max) return s;
    return [[s substringToIndex:max - 1] stringByAppendingString:@"…"];
}

#pragma mark - Entitlements

@implementation HCGEntitlements

+ (HCGEntitlementRisk)riskOfEntitlement:(NSString *)key {
    NSArray *high = [NSArray arrayWithObjects:@"com.apple.private.security.no-sandbox", @"platform-application", @"task_for_pid-allow",
                     @"com.apple.system-task-ports", @"com.apple.private.skip-library-validation", @"run-unsigned-code",
                     @"com.apple.private.security.disk-device-access", @"com.apple.rootless.install", @"com.apple.private.persona-mgmt",
                     @"com.apple.private.security.storage.AppDataContainers", nil];
    if ([high containsObject:key]) return HCGEntitlementRiskHigh;
    if ([key hasPrefix:@"com.apple.private."] || [key hasPrefix:@"com.apple.rootless."] || [key isEqualToString:@"get-task-allow"] ||
        [key isEqualToString:@"dynamic-codesigning"]) return HCGEntitlementRiskElevated;
    return HCGEntitlementRiskNormal;
}

+ (NSString *)explanationOfEntitlement:(NSString *)key {
    if ([key isEqualToString:@"com.apple.private.security.no-sandbox"]) return @"Runs outside the app sandbox: can read and write anywhere the user can.";
    if ([key isEqualToString:@"platform-application"]) return @"Treated as a platform (Apple) binary.";
    if ([key isEqualToString:@"task_for_pid-allow"] || [key isEqualToString:@"com.apple.system-task-ports"]) return @"Can inspect and control other processes.";
    if ([key isEqualToString:@"com.apple.private.skip-library-validation"]) return @"Can load libraries not signed with its own team.";
    if ([key isEqualToString:@"run-unsigned-code"] || [key isEqualToString:@"dynamic-codesigning"]) return @"Can run code that is not signed.";
    if ([key isEqualToString:@"get-task-allow"]) return @"Debuggable: other processes may attach to it.";
    if ([key hasPrefix:@"com.apple.private."]) return @"A private Apple entitlement (only effective on a jailbroken device).";
    if ([key hasPrefix:@"com.apple.security.application-groups"]) return @"Shares data with apps in the same group.";
    if ([key hasPrefix:@"keychain-access-groups"]) return @"Keychain access group.";
    return @"Standard entitlement.";
}

static uint32_t RBE(const uint8_t *p) { return ((uint32_t)p[0] << 24) | ((uint32_t)p[1] << 16) | ((uint32_t)p[2] << 8) | p[3]; }
static uint32_t RLE(const uint8_t *p) { return ((uint32_t)p[3] << 24) | ((uint32_t)p[2] << 16) | ((uint32_t)p[1] << 8) | p[0]; }

static NSDictionary *EntitlementsInSlice(const uint8_t *p, size_t len, NSString **error) {
    if (len < 28) { *error = @"Not a Mach-O file."; return nil; }
    uint32_t magic = RLE(p);
    size_t header;
    if (magic == 0xfeedfacf) header = 32;
    else if (magic == 0xfeedface) header = 28;
    else { *error = @"Not a Mach-O file."; return nil; }
    uint32_t ncmds = RLE(p + 16), sizeofcmds = RLE(p + 20);
    if (header + (size_t)sizeofcmds > len) { *error = @"Truncated Mach-O."; return nil; }
    size_t o = header, end = header + sizeofcmds;
    uint32_t i;
    for (i = 0; i < ncmds && o + 8 <= end; i++) {
        uint32_t cmd = RLE(p + o), cmdsize = RLE(p + o + 4);
        if (cmdsize < 8 || o + cmdsize > end) { *error = @"Malformed load commands."; return nil; }
        if (cmd == 0x1d && cmdsize >= 16) { // LC_CODE_SIGNATURE
            uint32_t off = RLE(p + o + 8), size = RLE(p + o + 12);
            if ((size_t)off + size > len || size < 12) { *error = @"Code signature outside the file."; return nil; }
            const uint8_t *sb = p + off;
            if (RBE(sb) != 0xfade0cc0) { *error = @"Unrecognised code signature."; return nil; }
            uint32_t count = RBE(sb + 8), j;
            if (12 + (size_t)count * 8 > size) { *error = @"Malformed code signature."; return nil; }
            for (j = 0; j < count; j++) {
                uint32_t type = RBE(sb + 12 + 8 * j), boff = RBE(sb + 16 + 8 * j);
                if (type != 5) continue; // CSSLOT_ENTITLEMENTS
                if ((size_t)boff + 8 > size) { *error = @"Malformed entitlements blob."; return nil; }
                const uint8_t *blob = sb + boff;
                uint32_t blen = RBE(blob + 4);
                if (RBE(blob) != 0xfade7171 || blen < 8 || (size_t)boff + blen > size) { *error = @"Malformed entitlements blob."; return nil; }
                NSData *xml = [NSData dataWithBytes:blob + 8 length:blen - 8];
                id plist = [NSPropertyListSerialization propertyListWithData:xml options:0 format:NULL error:NULL];
                if (![plist isKindOfClass:[NSDictionary class]]) { *error = @"Entitlements are not a dictionary."; return nil; }
                return plist;
            }
            *error = @"Signed, with no entitlements.";
            return nil;
        }
        o += cmdsize;
    }
    *error = @"Not code-signed.";
    return nil;
}

+ (NSDictionary *)entitlementsInMachO:(NSData *)data error:(NSString **)error {
    NSString *why = @"Not a Mach-O file.";
    const uint8_t *p = (const uint8_t *)data.bytes;
    size_t len = data.length;
    NSDictionary *result = nil;
    if (len >= 8 && (RBE(p) == 0xcafebabe || RBE(p) == 0xcafebabf)) {
        BOOL fat64 = RBE(p) == 0xcafebabf;
        uint32_t n = RBE(p + 4), i;
        size_t entry = fat64 ? 32 : 20;
        if (n > 32 || 8 + (size_t)n * entry > len) why = @"Malformed universal binary.";
        for (i = 0; i < n && !result && 8 + (size_t)n * entry <= len; i++) {
            const uint8_t *a = p + 8 + entry * i;
            unsigned long long off = fat64 ? (((unsigned long long)RBE(a + 8) << 32) | RBE(a + 12)) : RBE(a + 8);
            unsigned long long size = fat64 ? (((unsigned long long)RBE(a + 16) << 32) | RBE(a + 20)) : RBE(a + 12);
            if (off + size > len) { why = @"Malformed universal binary."; continue; }
            result = EntitlementsInSlice(p + off, (size_t)size, &why);
        }
    } else if (len >= 4) {
        result = EntitlementsInSlice(p, len, &why);
    }
    if (!result && error) *error = why;
    return result;
}

@end

#pragma mark - Release Passport

@implementation HCGReleasePassport
@synthesize json = _json, package = _package, version = _version, sections = _sections, warnings = _warnings, entitlements = _entitlements;

+ (instancetype)passportWithData:(NSData *)data error:(NSString **)error {
    id json = HCGJSON(data);
    if (![json isKindOfClass:[NSDictionary class]] || ![[json objectForKey:@"format"] isEqual:@"hcg.release-passport"] ||
        ![[json objectForKey:@"formatVersion"] isKindOfClass:[NSNumber class]] || [[json objectForKey:@"formatVersion"] integerValue] != 1) {
        if (error) *error = @"Not an HCG Release Passport (format hcg.release-passport, version 1).";
        return nil;
    }
    NSString *package = HCGText([json objectForKey:@"package"]), *version = HCGText([json objectForKey:@"version"]);
    NSDictionary *artifact = HCGDict(json, @"artifact");
    if (!package || !version || !HCGText([artifact objectForKey:@"sha256"])) {
        if (error) *error = @"The passport has no package, version or artifact checksum.";
        return nil;
    }
    HCGReleasePassport *p = [[HCGReleasePassport alloc] init];
    p.json = json;
    p.package = package;
    p.version = version;
    NSMutableArray *sections = [NSMutableArray array], *warnings = [NSMutableArray array];

    NSDictionary *product = HCGDict(json, @"product"), *distribution = HCGDict(json, @"distribution"), *publication = HCGDict(json, @"publication");
    [sections addObject:[NSArray arrayWithObjects:@"Release", [NSArray arrayWithObjects:
        HCGPair(@"Product", HCGText([product objectForKey:@"name"]) ?: HCGText([product objectForKey:@"key"])),
        HCGPair(@"Package", package), HCGPair(@"Version", version),
        HCGPair(@"Edition", HCGText([json objectForKey:@"edition"])),
        HCGPair(@"Platform", [NSString stringWithFormat:@"%@ · %@", HCGText([json objectForKey:@"platform"]) ?: @"?", HCGText([json objectForKey:@"architecture"]) ?: @"?"]),
        HCGPair(@"Channel", [NSString stringWithFormat:@"%@ · %@", HCGText([distribution objectForKey:@"channel"]) ?: @"?", HCGText([distribution objectForKey:@"access"]) ?: @"?"]),
        HCGPair(@"Publication", HCGText([publication objectForKey:@"record_status"])),
        HCGPair(@"Compatibility", HCGText([json objectForKey:@"compatibility_status"])), nil], nil]];
    [sections addObject:[NSArray arrayWithObjects:@"Artifact", [NSArray arrayWithObjects:
        HCGPair(@"File", HCGText([artifact objectForKey:@"filename"])), HCGPair(@"SHA-256", HCGText([artifact objectForKey:@"sha256"])),
        HCGPair(@"Size", HCGText([artifact objectForKey:@"size"]) ? [NSString stringWithFormat:@"%@ bytes", HCGText([artifact objectForKey:@"size"])] : nil), nil], nil]];
    NSDictionary *source = HCGDict(json, @"source"), *build = HCGDict(json, @"build");
    NSString *commit = HCGText([source objectForKey:@"commit"]);
    [sections addObject:[NSArray arrayWithObjects:@"Source and build", [NSArray arrayWithObjects:
        HCGPair(@"Repository", HCGText([source objectForKey:@"repository"])), HCGPair(@"Commit", commit ? HCGShort(commit, 13) : nil),
        HCGPair(@"Build", HCGText([build objectForKey:@"provider"])), HCGPair(@"Run", HCGText([build objectForKey:@"run_id"])),
        HCGPair(@"Built", HCGText([build objectForKey:@"built_at"])), nil], nil]];

    NSMutableArray *levels = [NSMutableArray array];
    NSDictionary *levelDict = HCGDict(HCGDict(json, @"validation"), @"levels");
    NSArray *levelOrder = [NSArray arrayWithObjects:@"static_inspection", @"maintainer_script_review", @"script_free_lifecycle",
                           @"device_installation", @"application_launch", @"runtime_verification", nil];
    NSArray *levelTitles = [NSArray arrayWithObjects:@"Static inspection", @"Maintainer scripts", @"Script-free lifecycle",
                            @"Device installation", @"Application launch", @"Runtime verification", nil];
    NSUInteger i;
    for (i = 0; i < levelOrder.count; i++) {
        NSDictionary *level = HCGDict(levelDict, [levelOrder objectAtIndex:i]);
        NSString *state = HCGText([level objectForKey:@"state"]) ?: @"not-recorded";
        [levels addObject:HCGPair([levelTitles objectAtIndex:i], state)];
        if ([state isEqualToString:@"failed"]) [warnings addObject:[NSString stringWithFormat:@"%@ failed.", [levelTitles objectAtIndex:i]]];
    }
    [sections addObject:[NSArray arrayWithObjects:@"Validation", levels, nil]];

    NSMutableArray *devices = [NSMutableArray array];
    for (id ev in HCGList(json, @"device_evidence")) {
        if (![ev isKindOfClass:[NSDictionary class]]) continue;
        NSString *title = [NSString stringWithFormat:@"%@ · iOS %@", HCGText([ev objectForKey:@"device"]) ?: @"?", HCGText([ev objectForKey:@"ios"]) ?: @"?"];
        NSString *value = [NSString stringWithFormat:@"%@ %@ · %@ · %@", HCGText([ev objectForKey:@"stage"]) ?: @"?", HCGText([ev objectForKey:@"result"]) ?: @"?",
                           HCGText([ev objectForKey:@"jailbreak"]) ?: @"?", HCGText([ev objectForKey:@"date"]) ?: @"?"];
        [devices addObject:HCGPair(title, value)];
        if ([[ev objectForKey:@"result"] isEqual:@"fail"]) [warnings addObject:[NSString stringWithFormat:@"Recorded device failure: %@ (%@).", value, title]];
    }
    if (!devices.count) [devices addObject:HCGPair(@"Physical devices", @"No device evidence recorded")];
    [sections addObject:[NSArray arrayWithObjects:@"Device evidence", devices, nil]];

    NSDictionary *repoSigning = HCGDict(json, @"repository_signing"), *codeSigning = HCGDict(json, @"code_signing");
    BOOL repoConfigured = [[repoSigning objectForKey:@"configured"] isKindOfClass:[NSNumber class]] && [[repoSigning objectForKey:@"configured"] boolValue];
    id allSigned = [codeSigning objectForKey:@"all_signed"];
    [sections addObject:[NSArray arrayWithObjects:@"Signing", [NSArray arrayWithObjects:
        HCGPair(@"Repository", HCGText([repoSigning objectForKey:@"status"])),
        HCGPair(@"Repository key", HCGText([repoSigning objectForKey:@"fingerprint"]) ?: @"None"),
        HCGPair(@"Code (Mach-O)", [NSString stringWithFormat:@"%@ binaries, %@", HCGText([codeSigning objectForKey:@"binaries"]) ?: @"?",
                                    [allSigned isKindOfClass:[NSNumber class]] ? ([allSigned boolValue] ? @"all signed" : @"NOT all signed") : @"signing unknown"]),
        HCGPair(@"Code signing method", HCGText([codeSigning objectForKey:@"method_claimed"]) ?: @"not stated"), nil], nil]];
    if (!repoConfigured) [warnings addObject:@"The channel serving this release is not signed (no repository signing key yet)."];
    if ([allSigned isKindOfClass:[NSNumber class]] && ![allSigned boolValue]) [warnings addObject:@"Not every binary in the package is code-signed."];

    NSMutableDictionary *entitlements = [NSMutableDictionary dictionary];
    NSMutableArray *entRows = [NSMutableArray array];
    NSDictionary *entDict = HCGDict(codeSigning, @"entitlements");
    for (NSString *binary in [[entDict allKeys] sortedArrayUsingSelector:@selector(compare:)]) {
        id keys = [entDict objectForKey:binary];
        NSMutableArray *list = [NSMutableArray array];
        for (id k in [keys isKindOfClass:[NSArray class]] ? keys : [NSArray array]) if ([k isKindOfClass:[NSString class]]) [list addObject:k];
        [entitlements setObject:list forKey:binary];
        [entRows addObject:HCGPair([binary lastPathComponent], list.count ? [list componentsJoinedByString:@", "] : @"none")];
        for (NSString *k in list) {
            if ([HCGEntitlements riskOfEntitlement:k] == HCGEntitlementRiskHigh) {
                [warnings addObject:[NSString stringWithFormat:@"%@ declares %@: %@", [binary lastPathComponent], k, [HCGEntitlements explanationOfEntitlement:k]]];
            }
        }
    }
    if (!entRows.count) [entRows addObject:HCGPair(@"Entitlements", @"None declared")];
    [sections addObject:[NSArray arrayWithObjects:@"Declared entitlements", entRows, nil]];
    p.entitlements = entitlements;

    NSMutableArray *approvals = [NSMutableArray array];
    for (id ap in HCGList(json, @"approvals")) {
        if (![ap isKindOfClass:[NSDictionary class]]) continue;
        [approvals addObject:HCGPair(HCGText([ap objectForKey:@"kind"]) ?: @"approval", HCGShort(HCGText([ap objectForKey:@"record"]) ?: @"", 240))];
    }
    if (approvals.count) [sections addObject:[NSArray arrayWithObjects:@"Approvals", approvals, nil]];

    if ([[publication objectForKey:@"record_status"] isEqual:@"withdrawn"]) [warnings addObject:@"This release has been withdrawn."];
    if ([[json objectForKey:@"compatibility_status"] isEqual:@"Known incompatible"]) [warnings addObject:@"HCG Repo records this version as Known incompatible."];
    p.sections = sections;
    p.warnings = warnings;
    return p;
}

- (NSArray *)warningsAgainstIndexSHA256:(NSString *)sha256 {
    NSString *own = HCGText([HCGDict(self.json, @"artifact") objectForKey:@"sha256"]);
    if (sha256.length == 64 && own && ![HCGDigest hexString:own equalsHexString:sha256]) {
        return [NSArray arrayWithObject:@"The passport names different bytes (SHA-256) than the repository index."];
    }
    return [NSArray array];
}

@end

#pragma mark - Compatibility registry

@implementation HCGCompatibilityRegistry

+ (instancetype)registryWithData:(NSData *)data {
    id json = HCGJSON(data);
    if (![json isKindOfClass:[NSDictionary class]] || ![[json objectForKey:@"format"] isEqual:@"hcg.repo.compatibility"] ||
        [[json objectForKey:@"formatVersion"] integerValue] != 1) return nil;
    NSMutableDictionary *versions = [NSMutableDictionary dictionary];
    for (id package in HCGList(json, @"packages")) {
        NSString *name = HCGText([package isKindOfClass:[NSDictionary class]] ? [package objectForKey:@"package"] : nil);
        if (!name) continue;
        for (id v in HCGList(package, @"versions")) {
            NSString *version = HCGText([v isKindOfClass:[NSDictionary class]] ? [v objectForKey:@"version"] : nil);
            if (version) [versions setObject:v forKey:[NSString stringWithFormat:@"%@ %@", name, version]];
        }
    }
    HCGCompatibilityRegistry *r = [[HCGCompatibilityRegistry alloc] init];
    r->_versions = [versions copy];
    return r;
}

- (NSDictionary *)recordForPackage:(NSString *)package version:(NSString *)version {
    return [_versions objectForKey:[NSString stringWithFormat:@"%@ %@", package, version]];
}

@end

#pragma mark - Monitor

@implementation HCGMonitorReport
@synthesize status = _status, checkedAt = _checkedAt, target = _target, findings = _findings;

+ (HCGFindingSeverity)severityFromString:(NSString *)status {
    if ([status isEqual:@"ok"]) return HCGFindingSeverityOK;
    if ([status isEqual:@"warning"]) return HCGFindingSeverityWarning;
    if ([status isEqual:@"alert"]) return HCGFindingSeverityAlert;
    return HCGFindingSeverityUnknown;
}

+ (NSString *)titleForSeverity:(HCGFindingSeverity)s {
    switch (s) {
        case HCGFindingSeverityOK: return @"OK";
        case HCGFindingSeverityUnknown: return @"Unknown";
        case HCGFindingSeverityWarning: return @"Warning";
        case HCGFindingSeverityAlert: return @"Alert";
    }
    return @"Unknown";
}

static NSInteger HCGCompareFindings(id a, id b, void *context) {
    NSInteger sa = [[a objectAtIndex:1] integerValue], sb = [[b objectAtIndex:1] integerValue];
    if (sa != sb) return sa > sb ? NSOrderedAscending : NSOrderedDescending;
    return [[a objectAtIndex:0] compare:[b objectAtIndex:0]];
}

+ (instancetype)reportWithData:(NSData *)data {
    id json = HCGJSON(data);
    if (![json isKindOfClass:[NSDictionary class]] || ![[json objectForKey:@"format"] isEqual:@"hcg.repo.monitor"] ||
        [[json objectForKey:@"formatVersion"] integerValue] != 1) return nil;
    HCGMonitorReport *r = [[HCGMonitorReport alloc] init];
    r.status = [self severityFromString:[json objectForKey:@"status"]];
    r.checkedAt = HCGText([json objectForKey:@"checked_at"]) ?: @"";
    r.target = HCGText([json objectForKey:@"target"]) ?: @"";
    NSMutableArray *findings = [NSMutableArray array];
    HCGFindingSeverity worst = HCGFindingSeverityOK;
    for (id check in HCGList(json, @"checks")) {
        NSString *identifier = HCGText([check isKindOfClass:[NSDictionary class]] ? [check objectForKey:@"id"] : nil);
        if (!identifier) continue;
        HCGFindingSeverity s = [self severityFromString:[check objectForKey:@"status"]];
        if (s > worst) worst = s;
        [findings addObject:[NSArray arrayWithObjects:identifier, [NSNumber numberWithInteger:s], HCGShort(HCGText([check objectForKey:@"detail"]) ?: @"", 200), nil]];
    }
    // The overall status can never claim better than its worst check.
    if (worst > r.status) r.status = worst;
    r.findings = [findings sortedArrayUsingFunction:HCGCompareFindings context:NULL];
    return r;
}

@end

#pragma mark - Trusted repositories

NSString *const HCGTrustedRepositoriesStoreKey = @"trustedRepositories";

@implementation HCGTrustedRepository
@synthesize identifier = _identifier, name = _name, url = _url, pinnedFingerprint = _pinnedFingerprint, pinnedAt = _pinnedAt, builtIn = _builtIn;
@synthesize expectedSuite = _expectedSuite, lastReleaseDate = _lastReleaseDate, revokedFingerprints = _revokedFingerprints;

- (BOOL)rememberReport:(HCGRepositoryReport *)report {
    BOOL changed = NO;
    NSMutableSet *revoked = [NSMutableSet setWithArray:self.revokedFingerprints ?: [NSArray array]];
    NSUInteger before = revoked.count;
    [revoked addObjectsFromArray:report.revokedFingerprints ?: [NSArray array]];
    if (revoked.count != before) {
        self.revokedFingerprints = [[revoked allObjects] sortedArrayUsingSelector:@selector(compare:)];
        changed = YES;
    }
    if (report.authenticity != HCGAuthenticityVerified) return changed;
    NSString *suite = [report.releaseFile.fields objectForKey:@"Suite"];
    if (!self.expectedSuite.length && suite.length && suite.length <= 40) {
        self.expectedSuite = suite;
        changed = YES;
    }
    NSDate *date = report.releaseFile.date;
    if (date && (!self.lastReleaseDate || [date compare:self.lastReleaseDate] == NSOrderedDescending)) {
        self.lastReleaseDate = date;
        changed = YES;
    }
    return changed;
}
@end

@implementation HCGTrustedRepositoryList

+ (NSString *)normalizedFingerprint:(NSString *)text {
    if (![text isKindOfClass:[NSString class]]) return nil;
    NSString *s = [[[text stringByReplacingOccurrencesOfString:@" " withString:@""] stringByReplacingOccurrencesOfString:@":" withString:@""] uppercaseString];
    if (s.length != 40) return nil;
    NSCharacterSet *hex = [NSCharacterSet characterSetWithCharactersInString:@"0123456789ABCDEF"];
    return [s rangeOfCharacterFromSet:[hex invertedSet]].location == NSNotFound ? s : nil;
}

+ (NSString *)normalizedRepositoryURL:(NSString *)text reason:(NSString **)reason {
    NSString *s = [text isKindOfClass:[NSString class]] ? [text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] : nil;
    NSString *why = nil;
    if (!s.length || s.length > 200) why = @"Enter the repository's address (at most 200 characters).";
    else if (![[s lowercaseString] hasPrefix:@"https://"]) why = @"Only https:// repositories can be checked.";
    else if ([s rangeOfCharacterFromSet:[NSCharacterSet whitespaceCharacterSet]].location != NSNotFound ||
             [s rangeOfString:@"?"].location != NSNotFound || [s rangeOfString:@"#"].location != NSNotFound) why = @"The address may not contain spaces, ? or #.";
    else {
        NSString *rest = [s substringFromIndex:8];
        NSRange slash = [rest rangeOfString:@"/"];
        NSString *host = slash.location == NSNotFound ? rest : [rest substringToIndex:slash.location];
        NSCharacterSet *allowed = [NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.-"];
        if (!host.length || [host rangeOfCharacterFromSet:[allowed invertedSet]].location != NSNotFound || [host hasPrefix:@"."] || [host rangeOfString:@"."].location == NSNotFound) {
            why = @"The address needs a plain host name (no user, password or port).";
        }
    }
    if (why) {
        if (reason) *reason = why;
        return nil;
    }
    NSString *scheme = @"https://", *rest = [s substringFromIndex:8];
    NSRange slash = [rest rangeOfString:@"/"];
    NSString *host = [(slash.location == NSNotFound ? rest : [rest substringToIndex:slash.location]) lowercaseString];
    NSString *path = slash.location == NSNotFound ? @"/" : [rest substringFromIndex:slash.location];
    if (![path hasSuffix:@"/"]) path = [path stringByAppendingString:@"/"];
    return [NSString stringWithFormat:@"%@%@%@", scheme, host, path];
}

static HCGTrustedRepository *HCGBuiltIn(NSString *identifier, NSString *name, NSString *url) {
    HCGTrustedRepository *r = [[HCGTrustedRepository alloc] init];
    r.identifier = identifier;
    r.name = name;
    r.url = url;
    r.builtIn = YES;
    // HCG Repo's channels (HCG-repo config/repo.toml: suite "stable"; the Candidate channel uses suite "candidate").
    r.expectedSuite = [identifier isEqualToString:@"hcg-repo-candidate"] ? @"candidate" : @"stable";
    return r;
}

+ (NSArray *)repositoriesFromStoredValue:(id)value {
    NSMutableArray *out = [NSMutableArray arrayWithObjects:
        HCGBuiltIn(@"hcg-repo-stable", @"HCG Repo", @"https://repo.hakmicapitalgroup.com/repo/"),
        HCGBuiltIn(@"hcg-repo-candidate", @"HCG Repo Candidate", @"https://repo.hakmicapitalgroup.com/repo/candidate/"), nil];
    NSArray *stored = [value isKindOfClass:[NSArray class]] ? value : [NSArray array];
    NSUInteger i;
    for (i = 0; i < stored.count && out.count < 12; i++) {
        id d = [stored objectAtIndex:i];
        if (![d isKindOfClass:[NSDictionary class]]) continue;
        NSString *identifier = HCGText([d objectForKey:@"id"]);
        NSString *fingerprint = [self normalizedFingerprint:[d objectForKey:@"fingerprint"]];
        id pinnedAt = [d objectForKey:@"pinnedAt"];
        HCGTrustedRepository *existing = nil;
        for (HCGTrustedRepository *r in out) if ([r.identifier isEqualToString:identifier]) existing = r;
        if (!existing) {
            NSString *url = [self normalizedRepositoryURL:[d objectForKey:@"url"] reason:NULL];
            NSString *name = HCGText([d objectForKey:@"name"]);
            if (!identifier || ![identifier hasPrefix:@"custom-"] || !url) continue;
            existing = [[HCGTrustedRepository alloc] init];
            existing.identifier = identifier;
            existing.url = url;
            existing.name = name ? HCGShort(name, 40) : url;
            [out addObject:existing];
        }
        existing.pinnedFingerprint = fingerprint;
        existing.pinnedAt = fingerprint && [pinnedAt isKindOfClass:[NSNumber class]] ? [NSDate dateWithTimeIntervalSince1970:[pinnedAt doubleValue]] : nil;
        id suite = [d objectForKey:@"suite"], last = [d objectForKey:@"lastReleaseDate"], revokedList = [d objectForKey:@"revoked"];
        if (!existing.builtIn && [suite isKindOfClass:[NSString class]] && [suite length] <= 40) existing.expectedSuite = suite;
        if ([last isKindOfClass:[NSNumber class]]) existing.lastReleaseDate = [NSDate dateWithTimeIntervalSince1970:[last doubleValue]];
        if ([revokedList isKindOfClass:[NSArray class]]) {
            NSMutableArray *fps = [NSMutableArray array];
            for (id f in revokedList) {
                NSString *n = [self normalizedFingerprint:f];
                if (n && fps.count < 64) [fps addObject:n];
            }
            existing.revokedFingerprints = fps;
        }
    }
    return out;
}

+ (NSArray *)storedValueForRepositories:(NSArray *)repositories {
    NSMutableArray *out = [NSMutableArray array];
    for (HCGTrustedRepository *r in repositories) {
        if (r.builtIn && !r.pinnedFingerprint && !r.lastReleaseDate && !r.revokedFingerprints.count) continue; // nothing to remember
        NSMutableDictionary *d = [NSMutableDictionary dictionary];
        [d setObject:r.identifier forKey:@"id"];
        if (!r.builtIn) {
            [d setObject:r.url forKey:@"url"];
            [d setObject:r.name ?: r.url forKey:@"name"];
        }
        if (r.pinnedFingerprint) {
            [d setObject:r.pinnedFingerprint forKey:@"fingerprint"];
            [d setObject:[NSNumber numberWithDouble:[(r.pinnedAt ?: [NSDate date]) timeIntervalSince1970]] forKey:@"pinnedAt"];
        }
        if (!r.builtIn && r.expectedSuite) [d setObject:r.expectedSuite forKey:@"suite"];
        if (r.lastReleaseDate) [d setObject:[NSNumber numberWithDouble:[r.lastReleaseDate timeIntervalSince1970]] forKey:@"lastReleaseDate"];
        if (r.revokedFingerprints.count) [d setObject:r.revokedFingerprints forKey:@"revoked"];
        [out addObject:d];
    }
    return out;
}

@end

#pragma mark - Verified artifacts

@implementation HCGVerifiedArtifact
@synthesize path = _path, sha256 = _sha256, size = _size, verifiedAt = _verifiedAt;

+ (BOOL)prepareDirectory:(NSString *)directory {
    NSFileManager *fm = [NSFileManager defaultManager];
    BOOL isDirectory = NO;
    if (![fm fileExistsAtPath:directory isDirectory:&isDirectory]) {
        NSDictionary *attributes = [NSDictionary dictionaryWithObject:[NSNumber numberWithShort:0700] forKey:NSFilePosixPermissions];
        return [fm createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:attributes error:NULL];
    }
    return isDirectory;
}

+ (instancetype)verifyDownloadAtPath:(NSString *)path expectedSHA256:(NSString *)sha256 expectedSize:(unsigned long long)size
                       intoDirectory:(NSString *)directory error:(NSString **)error {
    NSFileManager *fm = [NSFileManager defaultManager];
    unsigned long long actualSize = 0;
    NSString *actual = [HCGDigest hexDigestOfFileAtPath:path algorithm:HCGDigestAlgorithmSHA256 size:&actualSize];
    if (!actual) {
        if (error) *error = @"The download cannot be read.";
        return nil;
    }
    if (sha256.length != 64 || ![HCGDigest hexString:actual equalsHexString:sha256] || (size > 0 && actualSize != size)) {
        [fm removeItemAtPath:path error:NULL];
        if (error) *error = [NSString stringWithFormat:@"The download does not match the index: SHA-256 %@ (%llu bytes), expected %@ (%llu bytes). It was deleted.",
                             actual, actualSize, sha256 ?: @"(none)", size];
        return nil;
    }
    if (![self prepareDirectory:directory]) {
        if (error) *error = @"The verified-downloads folder cannot be created.";
        return nil;
    }
    NSString *final = [directory stringByAppendingPathComponent:[[actual lowercaseString] stringByAppendingPathExtension:@"deb"]];
    if (![final isEqualToString:path]) {
        [fm removeItemAtPath:final error:NULL];
        if (![fm moveItemAtPath:path toPath:final error:NULL]) {
            if (error) *error = @"The verified download cannot be stored.";
            return nil;
        }
    }
    [fm setAttributes:[NSDictionary dictionaryWithObject:[NSNumber numberWithShort:0444] forKey:NSFilePosixPermissions] ofItemAtPath:final error:NULL];
    HCGVerifiedArtifact *artifact = [[HCGVerifiedArtifact alloc] init];
    artifact->_path = [final copy];
    artifact->_sha256 = [[actual lowercaseString] copy];
    artifact->_size = actualSize;
    artifact->_verifiedAt = [[NSDate date] copy];
    return artifact;
}

- (BOOL)stillMatches:(NSString **)reason {
    unsigned long long size = 0;
    NSString *now = [HCGDigest hexDigestOfFileAtPath:self.path algorithm:HCGDigestAlgorithmSHA256 size:&size];
    if (!now) {
        if (reason) *reason = @"The verified file is gone.";
        return NO;
    }
    if (![HCGDigest hexString:now equalsHexString:self.sha256] || size != self.size) {
        if (reason) *reason = @"The verified file changed after verification. Do not install it.";
        return NO;
    }
    return YES;
}

@end
