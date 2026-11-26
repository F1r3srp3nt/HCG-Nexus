#import "HCGCommandCenterData.h"

@implementation HCGCommandCenterItem
@end

@implementation HCGCommandCenterSnapshot

- (HCGCommandCenterItem *)itemForID:(NSString *)identifier {
    for (HCGCommandCenterItem *i in self.items) if ([i.entry.identifier isEqualToString:identifier]) return i;
    return nil;
}

- (NSArray *)itemsInCategory:(NSString *)categoryID {
    NSMutableArray *out = [NSMutableArray array];
    for (HCGCommandCenterItem *i in self.items) if ([i.entry.categoryID isEqualToString:categoryID]) [out addObject:i];
    return out;
}

- (NSUInteger)countInState:(HCGConnectionState)state {
    NSUInteger n = 0;
    for (HCGCommandCenterItem *i in self.items) if (i.connection.state == state) n++;
    return n;
}

@end

@implementation HCGCommandCenterData

+ (void)loadWithModel:(HCGNexusModel *)model completion:(void (^)(HCGCommandCenterSnapshot *))completion {
    [HCGEcosystemData loadWithLauncher:model.launcher completion:^(HCGEcosystemSnapshot *ecosystem) {
        completion([self snapshotWithModel:model ecosystem:ecosystem]);
    }];
}

+ (HCGCommandCenterSnapshot *)snapshotWithModel:(HCGNexusModel *)model ecosystem:(HCGEcosystemSnapshot *)ecosystem {
    HCGRegistry *registry = [model ecosystemRegistry];
    NSArray *ledger = [model connectionLedger];
    NSDate *now = [NSDate date];
    NSMutableArray *items = [NSMutableArray array];
    NSMutableDictionary *assessments = [NSMutableDictionary dictionary];
    NSMutableArray *notices = [NSMutableArray array];
    for (HCGRegistryEntry *entry in [registry visibleEntriesWithGrants:nil]) { // no HCG account in Nexus: private stays hidden
        HCGCommandCenterItem *item = [[HCGCommandCenterItem alloc] init];
        item.entry = entry;
        item.hip = entry.hipProductID ? [ecosystem statusForProductID:entry.hipProductID] : nil;
        item.connection = [HCGCommandCenter connectionForEntry:entry hipStatus:item.hip ledger:ledger registry:registry now:now];
        item.roadmap = [HCGCommandCenter roadmapForEntry:entry connection:item.connection hipStatus:item.hip];
        assessments[entry.identifier] = item.roadmap;
        [items addObject:item];
        if (item.hip.updateAvailable) [notices addObject:@[ [NSString stringWithFormat:@"%@: %@", entry.officialName, item.hip.updateText ?: @"update available"], entry.identifier ]];
        if (item.hip.availability == HCGHIPAvailabilityAttention || item.hip.availability == HCGHIPAvailabilityNeedsUpdate) {
            [notices addObject:@[ [NSString stringWithFormat:@"%@: %@", entry.officialName, item.hip.healthText ?: item.hip.stateTitle], entry.identifier ]];
        }
        if (item.connection.state == HCGConnectionStateDisconnected || item.connection.state == HCGConnectionStateFailed) {
            [notices addObject:@[ [NSString stringWithFormat:@"%@: %@", entry.officialName, item.connection.title], entry.identifier ]];
        }
        if (![entry.lifecycle isEqualToString:@"active"]) [notices addObject:@[ [NSString stringWithFormat:@"%@ is %@.", entry.officialName, entry.lifecycle], entry.identifier ]];
    }
    if (registry.problems.count) [notices addObject:@[ [NSString stringWithFormat:@"The registry ignored %lu invalid part%@.", (unsigned long)registry.problems.count, registry.problems.count == 1 ? @"" : @"s"], @"" ]];
    BOOL changed = NO;
    NSDictionary *store = [HCGCommandCenter roadmapStore:[model roadmapStore] byRecordingAssessments:assessments now:now changed:&changed];
    if (changed && !ecosystem.simulated) [model saveRoadmapStore:store];
    HCGCommandCenterSnapshot *s = [[HCGCommandCenterSnapshot alloc] init];
    s.registry = registry;
    s.items = items;
    s.ecosystem = ecosystem;
    s.notices = notices;
    return s;
}

@end

@implementation HCGPublicReader {
    NSURLSession *_session;
}

+ (instancetype)sharedReader {
    static HCGPublicReader *shared;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ shared = [[HCGPublicReader alloc] init]; });
    return shared;
}

- (instancetype)init {
    if ((self = [super init])) {
        NSURLSessionConfiguration *config = [NSURLSessionConfiguration ephemeralSessionConfiguration];
        config.HTTPCookieAcceptPolicy = NSHTTPCookieAcceptPolicyNever;
        config.HTTPShouldSetCookies = NO;
        config.URLCredentialStorage = nil;
        config.URLCache = nil;
        config.requestCachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
        config.timeoutIntervalForRequest = 20;
        config.timeoutIntervalForResource = 40;
        config.HTTPAdditionalHeaders = @{ @"User-Agent" : [@"HCG-Nexus/" stringByAppendingString:HCG_NEXUS_VERSION], @"Accept" : @"application/json" };
        _session = [NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:nil];
    }
    return self;
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task willPerformHTTPRedirection:(NSHTTPURLResponse *)response
        newRequest:(NSURLRequest *)request completionHandler:(void (^)(NSURLRequest *))completionHandler {
    completionHandler(nil); // never follow a redirect away from the registry's endpoint
}

- (void)getURLString:(NSString *)urlString completion:(void (^)(NSData *, NSString *))completion {
    NSRange q = [urlString rangeOfString:@"?"];
    NSString *base = q.location == NSNotFound ? urlString : [urlString substringToIndex:q.location];
    NSURL *url = HCGRegistryIsAllowedURL(base) ? [NSURL URLWithString:urlString] : nil;
    if (!url) {
        dispatch_async(dispatch_get_main_queue(), ^{ completion(nil, @"error: not an HCG endpoint"); });
        return;
    }
    NSURLSessionDataTask *task = [_session dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSInteger code = [response isKindOfClass:[NSHTTPURLResponse class]] ? [(NSHTTPURLResponse *)response statusCode] : 0;
        NSString *state = error ? [@"error: " stringByAppendingString:error.localizedDescription ?: @"failed"]
                        : (code != 200 ? [NSString stringWithFormat:@"HTTP %ld", (long)code] : (data.length > 1024 * 1024 ? @"error: answer too large" : @"200"));
        NSData *body = [state isEqualToString:@"200"] ? data : nil;
        dispatch_async(dispatch_get_main_queue(), ^{ completion(body, state); });
    }];
    [task resume];
}

@end
