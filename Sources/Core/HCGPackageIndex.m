#import "HCGPackageIndex.h"

#pragma mark Debian version ordering (dpkg lib/dpkg/version.c)

static int HCGVersionOrder(int c) {
    if (c >= '0' && c <= '9') return 0;
    if ((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z')) return c;
    if (c == '~') return -1;
    if (c) return c + 256;
    return 0;
}

static BOOL HCGIsDigit(int c) {
    return c >= '0' && c <= '9';
}

static int HCGVerRevCmp(const char *a, const char *b) {
    while (*a || *b) {
        int firstDiff = 0;
        while ((*a && !HCGIsDigit(*a)) || (*b && !HCGIsDigit(*b))) {
            int ac = HCGVersionOrder(*a), bc = HCGVersionOrder(*b);
            if (ac != bc) return ac - bc;
            a++;
            b++;
        }
        while (*a == '0') a++;
        while (*b == '0') b++;
        while (HCGIsDigit(*a) && HCGIsDigit(*b)) {
            if (!firstDiff) firstDiff = *a - *b;
            a++;
            b++;
        }
        if (HCGIsDigit(*a)) return 1;
        if (HCGIsDigit(*b)) return -1;
        if (firstDiff) return firstDiff;
    }
    return 0;
}

// Splits [epoch:]upstream[-revision]. NO when malformed.
static BOOL HCGSplitVersion(NSString *version, long *epoch, NSString **upstream, NSString **revision) {
    if (![version isKindOfClass:[NSString class]] || version.length == 0 || version.length > 128) return NO;
    NSCharacterSet *allowed = [NSCharacterSet characterSetWithCharactersInString:
        @"0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ.+~-:"];
    if ([version rangeOfCharacterFromSet:[allowed invertedSet]].location != NSNotFound) return NO;
    NSString *rest = version;
    long e = 0;
    NSRange colon = [rest rangeOfString:@":"];
    if (colon.location != NSNotFound) {
        NSString *epochText = [rest substringToIndex:colon.location];
        if (epochText.length == 0 || epochText.length > 9) return NO;
        NSUInteger i;
        for (i = 0; i < epochText.length; i++) {
            if (!HCGIsDigit([epochText characterAtIndex:i])) return NO;
        }
        e = [epochText integerValue];
        rest = [rest substringFromIndex:colon.location + 1];
        if ([rest rangeOfString:@":"].location != NSNotFound) return NO;
    }
    NSString *rev = @"";
    NSRange dash = [rest rangeOfString:@"-" options:NSBackwardsSearch];
    if (dash.location != NSNotFound) {
        rev = [rest substringFromIndex:dash.location + 1];
        rest = [rest substringToIndex:dash.location];
        if (rev.length == 0) return NO;
    }
    if (rest.length == 0 || !HCGIsDigit([rest characterAtIndex:0])) return NO;
    if (epoch) *epoch = e;
    if (upstream) *upstream = rest;
    if (revision) *revision = rev;
    return YES;
}

@implementation HCGDebianVersion

+ (BOOL)isValid:(NSString *)version {
    return HCGSplitVersion(version, NULL, NULL, NULL);
}

+ (NSComparisonResult)compare:(NSString *)a with:(NSString *)b {
    long ea = 0, eb = 0;
    NSString *ua = nil, *ub = nil, *ra = nil, *rb = nil;
    BOOL va = HCGSplitVersion(a, &ea, &ua, &ra), vb = HCGSplitVersion(b, &eb, &ub, &rb);
    if (!va || !vb) {
        if (va == vb) return NSOrderedSame;
        return va ? NSOrderedDescending : NSOrderedAscending;
    }
    if (ea != eb) return ea < eb ? NSOrderedAscending : NSOrderedDescending;
    int r = HCGVerRevCmp([ua UTF8String], [ub UTF8String]);
    if (r == 0) r = HCGVerRevCmp([ra UTF8String], [rb UTF8String]);
    if (r == 0) return NSOrderedSame;
    return r < 0 ? NSOrderedAscending : NSOrderedDescending;
}

@end

#pragma mark Records

@implementation HCGPackageRecord
@synthesize package = _package, version = _version, status = _status, name = _name, architecture = _architecture;

- (BOOL)installed {
    return [self.status hasSuffix:@" installed"];
}
@end

@implementation HCGPackageIndex

static NSString *HCGTrim(NSString *s) {
    return [s stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
}

static void HCGFinishStanza(NSMutableDictionary *fields, NSMutableArray *out) {
    NSString *package = [fields objectForKey:@"package"];
    NSString *version = [fields objectForKey:@"version"];
    if (package.length && [HCGDebianVersion isValid:version]) {
        HCGPackageRecord *record = [[HCGPackageRecord alloc] init];
        record.package = package;
        record.version = version;
        record.status = [fields objectForKey:@"status"];
        record.name = [fields objectForKey:@"name"];
        record.architecture = [fields objectForKey:@"architecture"];
        [out addObject:record];
    }
    [fields removeAllObjects];
}

+ (NSArray *)recordsFromText:(NSString *)text {
    NSMutableArray *out = [NSMutableArray array];
    if (![text isKindOfClass:[NSString class]]) return out;
    NSMutableDictionary *fields = [NSMutableDictionary dictionary];
    NSArray *lines = [[text stringByReplacingOccurrencesOfString:@"\r" withString:@""] componentsSeparatedByString:@"\n"];
    NSUInteger i;
    for (i = 0; i < lines.count; i++) {
        NSString *line = [lines objectAtIndex:i];
        if (HCGTrim(line).length == 0) {
            HCGFinishStanza(fields, out);
            continue;
        }
        unichar first = [line characterAtIndex:0];
        if (first == ' ' || first == '\t') continue; // continuation (Description, Conffiles, ...)
        NSRange colon = [line rangeOfString:@":"];
        if (colon.location == NSNotFound || colon.location == 0) continue;
        NSString *key = [[line substringToIndex:colon.location] lowercaseString];
        if (![key isEqualToString:@"package"] && ![key isEqualToString:@"version"] && ![key isEqualToString:@"status"] &&
            ![key isEqualToString:@"name"] && ![key isEqualToString:@"architecture"]) continue;
        [fields setObject:HCGTrim([line substringFromIndex:colon.location + 1]) forKey:key];
    }
    HCGFinishStanza(fields, out);
    return out;
}

+ (NSDictionary *)installedVersionsFromStatusText:(NSString *)text packages:(NSSet *)packages {
    NSMutableDictionary *out = [NSMutableDictionary dictionary];
    NSArray *records = [self recordsFromText:text];
    NSUInteger i;
    for (i = 0; i < records.count; i++) {
        HCGPackageRecord *record = [records objectAtIndex:i];
        if (!record.installed) continue;
        if (packages && ![packages containsObject:record.package]) continue;
        [out setObject:record.version forKey:record.package];
    }
    return out;
}

+ (NSDictionary *)highestVersionsFromIndexTexts:(NSArray *)texts packages:(NSSet *)packages architectures:(NSSet *)architectures {
    NSMutableDictionary *out = [NSMutableDictionary dictionary];
    NSUInteger t;
    for (t = 0; t < texts.count; t++) {
        NSArray *records = [self recordsFromText:[texts objectAtIndex:t]];
        NSUInteger i;
        for (i = 0; i < records.count; i++) {
            HCGPackageRecord *record = [records objectAtIndex:i];
            if (packages && ![packages containsObject:record.package]) continue;
            if (architectures && record.architecture.length && ![record.architecture isEqualToString:@"all"] &&
                ![architectures containsObject:record.architecture]) continue;
            NSString *current = [out objectForKey:record.package];
            if (!current || [HCGDebianVersion compare:record.version with:current] == NSOrderedDescending) {
                [out setObject:record.version forKey:record.package];
            }
        }
    }
    return out;
}

+ (BOOL)isUpdate:(NSString *)offered over:(NSString *)installed {
    if (![HCGDebianVersion isValid:offered] || ![HCGDebianVersion isValid:installed]) return NO;
    return [HCGDebianVersion compare:offered with:installed] == NSOrderedDescending;
}

+ (BOOL)isHCGRepoListFileName:(NSString *)fileName {
    if (![fileName isKindOfClass:[NSString class]]) return NO;
    NSString *lower = [fileName lowercaseString];
    return [lower hasPrefix:@"repo.hakmicapitalgroup.com_"] && [lower hasSuffix:@"_packages"];
}

+ (NSString *)channelForListFileName:(NSString *)fileName {
    if (![self isHCGRepoListFileName:fileName]) return nil;
    NSString *lower = [fileName lowercaseString];
    if ([lower rangeOfString:@"_repo_candidate_"].location != NSNotFound) return @"candidate";
    if ([lower hasPrefix:@"repo.hakmicapitalgroup.com_repo_"]) return @"stable";
    return nil;
}

@end
