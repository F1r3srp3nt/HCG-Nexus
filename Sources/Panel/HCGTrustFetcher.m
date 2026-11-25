#import "HCGTrustFetcher.h"

static const long long kMaxMetadataBytes = 8LL * 1024 * 1024;
static const long long kMaxPackageBytes = 64LL * 1024 * 1024;

@implementation HCGTrustFetchResult
@end

@interface HCGTrustFetcher () <NSURLSessionTaskDelegate>
@end

@implementation HCGTrustFetcher {
    NSURLSession *_session;
}

+ (instancetype)sharedFetcher {
    static HCGTrustFetcher *shared;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ shared = [[HCGTrustFetcher alloc] init]; });
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
        config.timeoutIntervalForResource = 120;
        config.HTTPAdditionalHeaders = @{ @"User-Agent" : [@"HCG-Nexus-TrustCenter/" stringByAppendingString:HCG_NEXUS_VERSION] };
        _session = [NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:nil];
    }
    return self;
}

// A changed location could point anywhere: never follow it.
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task willPerformHTTPRedirection:(NSHTTPURLResponse *)response
        newRequest:(NSURLRequest *)request completionHandler:(void (^)(NSURLRequest *))completionHandler {
    completionHandler(nil);
}

+ (NSString *)verifiedDownloadsDirectory {
    NSString *caches = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).firstObject ?: NSTemporaryDirectory();
    return [[caches stringByAppendingPathComponent:@"HCGNexus"] stringByAppendingPathComponent:@"VerifiedDownloads"];
}

- (void)getURL:(NSURL *)url limit:(long long)limit completion:(void (^)(NSData *data, NSString *state))completion {
    if (![[url.scheme lowercaseString] isEqualToString:@"https"]) {
        completion(nil, @"error: not https");
        return;
    }
    NSURLSessionDataTask *task = [_session dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSInteger code = [response isKindOfClass:[NSHTTPURLResponse class]] ? [(NSHTTPURLResponse *)response statusCode] : 0;
        if (error) completion(nil, [@"error: " stringByAppendingString:error.localizedDescription ?: @"failed"]);
        else if (code != 200) completion(nil, [NSString stringWithFormat:@"%ld", (long)code]);
        else if ((long long)data.length > limit) completion(nil, @"error: too large");
        else completion(data, @"200");
    }];
    [task resume];
}

- (void)fetchRepository:(HCGTrustedRepository *)repository completion:(void (^)(HCGTrustFetchResult *))completion {
    NSURL *base = [NSURL URLWithString:repository.url];
    NSArray *files = @[ @"Release", @"InRelease", @"Release.gpg", @"Packages", @"hcg-repo-archive-key.asc" ];
    NSMutableDictionary *datas = [NSMutableDictionary dictionary], *states = [NSMutableDictionary dictionary];
    dispatch_group_t group = dispatch_group_create();
    NSObject *lock = [[NSObject alloc] init];
    for (NSString *file in files) {
        NSURL *url = [NSURL URLWithString:file relativeToURL:base].absoluteURL;
        if (!url) continue;
        dispatch_group_enter(group);
        [self getURL:url limit:kMaxMetadataBytes completion:^(NSData *data, NSString *state) {
            @synchronized(lock) {
                if (data) datas[file] = data;
                states[file] = state;
            }
            dispatch_group_leave(group);
        }];
    }
    BOOL hcgRepo = [[base.host lowercaseString] isEqualToString:@"repo.hakmicapitalgroup.com"];
    if (hcgRepo) {
        NSURL *compat = [NSURL URLWithString:@"https://repo.hakmicapitalgroup.com/compatibility.json"];
        dispatch_group_enter(group);
        [self getURL:compat limit:kMaxMetadataBytes completion:^(NSData *data, NSString *state) {
            @synchronized(lock) {
                if (data) datas[@"compatibility.json"] = data;
                states[@"compatibility.json"] = state;
            }
            dispatch_group_leave(group);
        }];
    }
    dispatch_group_notify(group, dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        HCGTrustFetchResult *result = [[HCGTrustFetchResult alloc] init];
        HCGRepositoryEvidence *e = [[HCGRepositoryEvidence alloc] init];
        e.repositoryURL = repository.url;
        e.releaseData = datas[@"Release"];
        e.inRelease = datas[@"InRelease"];
        e.releaseSignature = datas[@"Release.gpg"];
        e.packages = datas[@"Packages"];
        e.packagesPath = @"Packages";
        e.publishedKey = datas[@"hcg-repo-archive-key.asc"];
        e.pinnedFingerprint = repository.pinnedFingerprint;
        e.now = [NSDate date];
        result.evidence = e;
        result.compatibility = [HCGCompatibilityRegistry registryWithData:datas[@"compatibility.json"]];
        result.fileStates = states;
        if (!e.releaseData && !e.inRelease) result.failure = [NSString stringWithFormat:@"The repository's Release file could not be read (%@).", states[@"Release"] ?: @"no answer"];
        dispatch_async(dispatch_get_main_queue(), ^{ completion(result); });
    });
}

static NSString *HCGSafeComponent(NSString *s) {
    NSCharacterSet *allowed = [NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.+~-"];
    return s.length && s.length < 128 && [s rangeOfCharacterFromSet:[allowed invertedSet]].location == NSNotFound ? s : nil;
}

- (void)fetchPassportForPackage:(NSString *)package version:(NSString *)version repository:(HCGTrustedRepository *)repository
                     completion:(void (^)(HCGReleasePassport *, NSString *))completion {
    NSString *p = HCGSafeComponent(package), *v = HCGSafeComponent(version);
    NSURL *url = p && v ? [NSURL URLWithString:[NSString stringWithFormat:@"passports/%@_%@.json", p,
                                               [v stringByReplacingOccurrencesOfString:@"~" withString:@"%7E"]] relativeToURL:[NSURL URLWithString:repository.url]].absoluteURL : nil;
    if (!url) {
        completion(nil, @"invalid name");
        return;
    }
    [self getURL:url limit:kMaxMetadataBytes completion:^(NSData *data, NSString *state) {
        NSString *error = nil;
        HCGReleasePassport *passport = data ? [HCGReleasePassport passportWithData:data error:&error] : nil;
        dispatch_async(dispatch_get_main_queue(), ^{ completion(passport, passport ? @"200" : (error ?: state)); });
    }];
}

- (void)downloadPackage:(NSDictionary *)stanza repository:(HCGTrustedRepository *)repository
             completion:(void (^)(HCGVerifiedArtifact *, NSString *, unsigned long long, NSString *))completion {
    void (^finish)(HCGVerifiedArtifact *, NSString *, unsigned long long, NSString *) = ^(HCGVerifiedArtifact *a, NSString *sha, unsigned long long size, NSString *error) {
        dispatch_async(dispatch_get_main_queue(), ^{ completion(a, sha, size, error); });
    };
    NSString *filename = stanza[@"Filename"], *sha256 = [stanza[@"SHA256"] lowercaseString];
    long long expectedSize = [stanza[@"Size"] longLongValue];
    if (![filename isKindOfClass:[NSString class]] || [filename hasPrefix:@"/"] || [filename rangeOfString:@".."].location != NSNotFound ||
        [filename rangeOfString:@"://"].location != NSNotFound || ![filename hasSuffix:@".deb"]) {
        finish(nil, nil, 0, @"The index gives no usable file name for this package.");
        return;
    }
    if (sha256.length != 64) {
        finish(nil, nil, 0, @"The index gives no SHA-256 for this package, so a download could not be verified.");
        return;
    }
    if (expectedSize <= 0 || expectedSize > kMaxPackageBytes) {
        finish(nil, nil, 0, @"The package is larger than the Trust Center downloads (64 MB).");
        return;
    }
    NSURL *url = [NSURL URLWithString:[filename stringByReplacingOccurrencesOfString:@"~" withString:@"%7E"] relativeToURL:[NSURL URLWithString:repository.url]].absoluteURL;
    if (![[url.scheme lowercaseString] isEqualToString:@"https"]) {
        finish(nil, nil, 0, @"Only https downloads are verified.");
        return;
    }
    NSURLSessionDownloadTask *task = [_session downloadTaskWithURL:url completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error) {
        NSInteger code = [response isKindOfClass:[NSHTTPURLResponse class]] ? [(NSHTTPURLResponse *)response statusCode] : 0;
        if (error || code != 200 || !location) {
            finish(nil, nil, 0, error ? error.localizedDescription : [NSString stringWithFormat:@"The repository answered HTTP %ld.", (long)code]);
            return;
        }
        NSString *dir = [HCGTrustFetcher verifiedDownloadsDirectory];
        if (![HCGVerifiedArtifact prepareDirectory:dir]) {
            finish(nil, nil, 0, @"The verified-downloads folder cannot be created.");
            return;
        }
        // Move out of the session's temporary file first (it is deleted when this block returns).
        NSString *partial = [dir stringByAppendingPathComponent:[[NSUUID UUID].UUIDString stringByAppendingPathExtension:@"part"]];
        if (![[NSFileManager defaultManager] moveItemAtPath:location.path toPath:partial error:NULL]) {
            finish(nil, nil, 0, @"The download could not be stored.");
            return;
        }
        unsigned long long size = 0;
        NSString *actual = [HCGDigest hexDigestOfFileAtPath:partial algorithm:HCGDigestAlgorithmSHA256 size:&size];
        NSString *why = nil;
        HCGVerifiedArtifact *artifact = [HCGVerifiedArtifact verifyDownloadAtPath:partial expectedSHA256:sha256 expectedSize:(unsigned long long)expectedSize
                                                                    intoDirectory:dir error:&why];
        finish(artifact, actual, size, why);
    }];
    [task resume];
}

@end
