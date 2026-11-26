#import "HCGCentralRegistry.h"
#import "HCGDigest.h"

NSString *const HCGCentralRegistryURL = @"https://beta.hakmicapitalgroup.com/api/public/pricing/v1/catalog";
NSString *const HCGCentralSnapshotStoreKey = @"centralSnapshot";
NSString *const HCGCentralSnapshotPreviousKey = @"centralSnapshotPrevious";

static NSString *Text(id value, NSUInteger limit) {
    if (![value isKindOfClass:[NSString class]]) return nil;
    NSString *s = [value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (!s.length || s.length > limit) return nil;
    return s;
}

static BOOL ValidProductID(NSString *s) {
    if (s.length < 3 || s.length > 81) return NO;
    NSCharacterSet *ok = [NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyz0123456789._-"];
    unichar c = [s characterAtIndex:0];
    return [s rangeOfCharacterFromSet:[ok invertedSet]].location == NSNotFound && ((c >= 'a' && c <= 'z') || (c >= '0' && c <= '9'));
}

@implementation HCGCentralProduct
@synthesize productID = _productID, name = _name, status = _status, releaseStatus = _releaseStatus;
@end

@implementation HCGCentralSnapshot
@synthesize version = _version, fetchedAt = _fetchedAt, products = _products, body = _body;

+ (instancetype)snapshotWithData:(NSData *)data fetchedAt:(NSDate *)fetchedAt error:(NSString **)error {
    if (!data.length || data.length > 256 * 1024) {
        if (error) *error = data.length ? @"The central catalogue is larger than 256 KB." : @"No answer from the central registry.";
        return nil;
    }
    id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
    id list = [json isKindOfClass:[NSDictionary class]] ? [json objectForKey:@"products"] : nil;
    if (![[json objectForKey:@"api_version"] isEqual:@"1"] || ![list isKindOfClass:[NSArray class]]) {
        if (error) *error = @"Not the central catalogue (api_version 1 with products).";
        return nil;
    }
    NSMutableDictionary *products = [NSMutableDictionary dictionary];
    NSMutableArray *identity = [NSMutableArray array];
    for (id item in list) {
        if (![item isKindOfClass:[NSDictionary class]]) continue;
        NSString *pid = Text([item objectForKey:@"product_id"], 81), *name = Text([item objectForKey:@"name"], 120);
        if (!ValidProductID(pid) || !name || [products objectForKey:pid]) continue;
        HCGCentralProduct *p = [[HCGCentralProduct alloc] init];
        p.productID = pid;
        p.name = name;
        p.status = Text([item objectForKey:@"status"], 40) ?: @"unknown";
        p.releaseStatus = Text([item objectForKey:@"release_status"], 40) ?: @"unknown";
        [products setObject:p forKey:pid];
        [identity addObject:[NSString stringWithFormat:@"%@\t%@\t%@\t%@", pid, name, p.status, p.releaseStatus]];
        if (products.count >= 500) break;
    }
    if (products.count < 5) {
        if (error) *error = @"The central catalogue lists fewer than 5 valid products; it was not used.";
        return nil;
    }
    [identity sortUsingSelector:@selector(compare:)];
    NSData *canonical = [[identity componentsJoinedByString:@"\n"] dataUsingEncoding:NSUTF8StringEncoding];
    HCGCentralSnapshot *s = [[HCGCentralSnapshot alloc] init];
    s.version = [[HCGDigest hexDigestOfData:canonical algorithm:HCGDigestAlgorithmSHA256] substringToIndex:16];
    s.fetchedAt = fetchedAt;
    s.products = products;
    s.body = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] ?: @"";
    return s;
}

- (NSDictionary *)storedValue {
    return [NSDictionary dictionaryWithObjectsAndKeys:self.version, @"version", [NSNumber numberWithDouble:[self.fetchedAt timeIntervalSince1970]], @"fetchedAt",
                                                      self.body, @"body", nil];
}

+ (instancetype)snapshotFromStoredValue:(id)value {
    if (![value isKindOfClass:[NSDictionary class]]) return nil;
    id body = [value objectForKey:@"body"], fetched = [value objectForKey:@"fetchedAt"];
    if (![body isKindOfClass:[NSString class]] || ![fetched isKindOfClass:[NSNumber class]]) return nil;
    return [self snapshotWithData:[body dataUsingEncoding:NSUTF8StringEncoding] fetchedAt:[NSDate dateWithTimeIntervalSince1970:[fetched doubleValue]] error:NULL];
}
@end

static NSString *DevelopmentStatusFor(NSString *releaseStatus) {
    if ([releaseStatus isEqualToString:@"planned"]) return @"planned";
    if ([releaseStatus isEqualToString:@"in_development"]) return @"in-development";
    if ([releaseStatus isEqualToString:@"internal_testing"]) return @"testing";
    if ([releaseStatus isEqualToString:@"testflight"]) return @"beta";
    if ([releaseStatus isEqualToString:@"published"]) return @"released";
    return nil;
}

@implementation HCGRegistry (Central)

- (HCGRegistry *)registryByApplyingCentralSnapshot:(HCGCentralSnapshot *)snapshot matched:(NSUInteger *)matched {
    if (matched) *matched = 0;
    if (!snapshot) return self;
    NSUInteger n = 0;
    NSMutableArray *entries = [NSMutableArray array], *problems = [NSMutableArray arrayWithArray:self.problems];
    for (HCGRegistryEntry *original in self.entries) {
        HCGRegistryEntry *e = [original entryCopy];
        HCGCentralProduct *p = e.centralProductID ? [snapshot.products objectForKey:e.centralProductID] : nil;
        BOOL own = [e.centralRegistration isEqualToString:@"registered"] || [e.centralRegistration isEqualToString:@"proposed"] ||
                   [e.centralRegistration isEqualToString:@"not-registered"];
        if (!p || !own) {
            if (!p && [e.centralRegistration isEqualToString:@"registered"]) {
                [problems addObject:[NSString stringWithFormat:@"%@: %@ is not in the live central catalogue (it may be retired or deprecated).", e.officialName, e.centralProductID]];
            }
            [entries addObject:e];
            continue;
        }
        n++;
        // Identity from the central registry; everything that grants or connects stays as built in.
        e.officialName = p.name;
        e.centralName = p.name;
        e.centralRegistration = @"registered";
        e.nameVerified = YES;
        NSString *dev = DevelopmentStatusFor(p.releaseStatus);
        if (dev) e.developmentStatus = dev;
        if ([p.releaseStatus isEqualToString:@"archived"]) e.lifecycle = @"retired";
        e.centralNote = [NSString stringWithFormat:@"Central registry (live): release status %@, lifecycle %@.", p.releaseStatus, p.status];
        [entries addObject:e];
    }
    HCGRegistry *r = [[HCGRegistry alloc] init];
    r.version = self.version;
    r.generatedAt = self.generatedAt;
    r.source = [NSString stringWithFormat:@"%@ + central registry %@", self.source, snapshot.version];
    r.categories = self.categories;
    r.methods = self.methods;
    r.entries = entries;
    r.deviceClasses = self.deviceClasses;
    r.problems = problems;
    if (matched) *matched = n;
    return r;
}

@end
