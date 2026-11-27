#import "HCGPublicFeeds.h"
#import "HCGRegistry.h"

static NSString *Text(id value, NSUInteger limit) {
    if (![value isKindOfClass:[NSString class]]) return nil;
    NSString *s = [value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (!s.length) return nil;
    return s.length > limit ? [[s substringToIndex:limit] stringByAppendingString:@"…"] : s;
}

@implementation HCGNewsArticle
@synthesize identifier = _identifier, title = _title, excerpt = _excerpt, section = _section, publishedAt = _publishedAt, webURL = _webURL, demo = _demo;
@end

@implementation HCGPublicFeeds

+ (NSString *)newsRequestURLForEndpoint:(NSString *)endpoint {
    return [endpoint stringByAppendingString:@"?page=1&per_page=20"];
}

+ (NSArray *)newsArticlesFromData:(NSData *)data total:(NSInteger *)total error:(NSString **)error {
    id json = data.length && data.length <= 2 * 1024 * 1024 ? [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL] : nil;
    if (![json isKindOfClass:[NSDictionary class]]) {
        if (error) *error = @"The answer was not JSON.";
        return nil;
    }
    id apiError = [json objectForKey:@"error"];
    if ([apiError isKindOfClass:[NSDictionary class]]) {
        if (error) *error = [NSString stringWithFormat:@"HCG News answered: %@", Text([apiError objectForKey:@"code"], 40) ?: @"error"];
        return nil;
    }
    id articles = [json objectForKey:@"articles"];
    if (![[json objectForKey:@"api_version"] isEqual:@"news.v1"] || ![articles isKindOfClass:[NSArray class]]) {
        if (error) *error = @"Not a news.v1 article list.";
        return nil;
    }
    if (total) *total = [[json objectForKey:@"total"] isKindOfClass:[NSNumber class]] ? [[json objectForKey:@"total"] integerValue] : (NSInteger)[articles count];
    NSMutableArray *out = [NSMutableArray array];
    for (id a in articles) {
        if (![a isKindOfClass:[NSDictionary class]] || out.count >= 50) continue;
        NSString *identifier = Text([a objectForKey:@"id"], 64), *title = Text([a objectForKey:@"title"], 200);
        if (!identifier || !title) continue;
        HCGNewsArticle *n = [[HCGNewsArticle alloc] init];
        n.identifier = identifier;
        n.title = title;
        n.excerpt = Text([a objectForKey:@"excerpt"], 280) ?: @"";
        id section = [a objectForKey:@"section"];
        n.section = [section isKindOfClass:[NSDictionary class]] ? Text([section objectForKey:@"name"], 60) : nil;
        NSString *published = Text([a objectForKey:@"published_at"], 40);
        n.publishedAt = published.length >= 10 ? [published substringToIndex:10] : nil;
        NSString *web = Text([a objectForKey:@"canonical_web_url"], 200);
        n.webURL = HCGRegistryIsAllowedURL(web) ? web : nil;
        n.demo = [[a objectForKey:@"is_demo"] isKindOfClass:[NSNumber class]] && [[a objectForKey:@"is_demo"] boolValue];
        [out addObject:n];
    }
    return out;
}

+ (NSArray *)storeReleaseRowsFromData:(NSData *)data error:(NSString **)error {
    id json = data.length && data.length <= 512 * 1024 ? [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL] : nil;
    NSDictionary *product = [json isKindOfClass:[NSDictionary class]] ? [json objectForKey:@"product"] : nil;
    id releases = [json isKindOfClass:[NSDictionary class]] ? [json objectForKey:@"releases"] : nil, options = [json isKindOfClass:[NSDictionary class]] ? [json objectForKey:@"options"] : nil;
    if (![[json objectForKey:@"format"] isEqual:@"hcg.store.release-resolution/1"] || ![product isKindOfClass:[NSDictionary class]] ||
        ![releases isKindOfClass:[NSArray class]] || ![options isKindOfClass:[NSArray class]]) {
        if (error) *error = @"Not an HCG Store release resolution (hcg.store.release-resolution/1).";
        return nil;
    }
    NSMutableArray *rows = [NSMutableArray array];
    [rows addObject:[NSArray arrayWithObjects:@"In HCG Store", [NSString stringWithFormat:@"%@ · %@", Text([product objectForKey:@"name"], 80) ?: @"—",
                                                                Text([product objectForKey:@"developmentStatus"], 40) ?: @"status not stated"], nil]];
    if (![releases count]) [rows addObject:[NSArray arrayWithObjects:@"Published releases", @"None published in HCG Store yet", nil]];
    for (id r in releases) {
        if (![r isKindOfClass:[NSDictionary class]] || rows.count > 12) continue;
        NSString *version = Text([r objectForKey:@"version"], 60);
        if (!version) continue;
        [rows addObject:[NSArray arrayWithObjects:[NSString stringWithFormat:@"Current release %@", version],
                         [NSString stringWithFormat:@"%@ channel%@%@", Text([r objectForKey:@"channel"], 30) ?: @"—",
                          Text([r objectForKey:@"releaseDate"], 10) ? [@" · " stringByAppendingString:Text([r objectForKey:@"releaseDate"], 10)] : @"",
                          [[r objectForKey:@"source"] isEqual:@"hcg-store-publication"] ? @" · published through HCG Store" : @" · from the Store catalogue"], nil]];
    }
    for (id o in options) {
        if (![o isKindOfClass:[NSDictionary class]] || rows.count > 20) continue;
        NSDictionary *access = [o objectForKey:@"access"];
        NSString *kind = [access isKindOfClass:[NSDictionary class]] ? Text([access objectForKey:@"kind"], 40) : nil;
        NSString *accessText = [kind isEqualToString:@"free-testing"] ? [NSString stringWithFormat:@"temporary free testing until %@", Text([access objectForKey:@"freeUntil"], 10) ?: @"—"]
                             : [kind isEqualToString:@"free-with-account"] ? @"free with an HCG account"
                             : [kind isEqualToString:@"licence-required"] ? @"licence required"
                             : @"not available yet";
        NSString *sha = Text([o objectForKey:@"sha256"], 64);
        [rows addObject:[NSArray arrayWithObjects:[NSString stringWithFormat:@"%@ · %@", Text([o objectForKey:@"platform"], 30) ?: @"—", Text([o objectForKey:@"fileName"], 120) ?: @"file"],
                         [NSString stringWithFormat:@"%@%@ · signing %@", accessText, sha.length == 64 ? [NSString stringWithFormat:@" · SHA-256 %@…", [sha substringToIndex:12]] : @"",
                          Text([o objectForKey:@"signing"], 30) ?: @"not reported"], nil]];
    }
    [rows addObject:[NSArray arrayWithObjects:@"Drafts, approvals, superseded and disabled versions", @"Only in the Store publishing API: needs HCG Connect and a Store permission (not offered to Nexus)", nil]];
    return rows;
}

+ (NSArray *)storeHealthRowsFromData:(NSData *)data error:(NSString **)error {
    id json = data.length && data.length <= 64 * 1024 ? [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL] : nil;
    NSString *status = [json isKindOfClass:[NSDictionary class]] ? Text([json objectForKey:@"status"], 40) : nil;
    if (!status) {
        if (error) *error = @"Not the HCG Store health answer.";
        return nil;
    }
    NSMutableArray *rows = [NSMutableArray array];
    NSArray *fields = [NSArray arrayWithObjects:@"status", @"Status", @"mode", @"Mode", @"hcgConnect", @"HCG Connect", @"entitlementAuthority", @"Entitlement authority",
                                                @"payments", @"Payments", @"protectedDownloads", @"Protected downloads", nil];
    NSUInteger i;
    for (i = 0; i + 1 < fields.count; i += 2) {
        NSString *v = Text([json objectForKey:[fields objectAtIndex:i]], 60);
        if (v) [rows addObject:[NSArray arrayWithObjects:[fields objectAtIndex:i + 1], v, nil]];
    }
    [rows addObject:[NSArray arrayWithObjects:@"Release management", @"Needs HCG Connect and Store permissions (not offered to Nexus)", nil]];
    return rows;
}

+ (NSArray *)identityDiscoveryRowsFromData:(NSData *)data error:(NSString **)error {
    id json = data.length && data.length <= 256 * 1024 ? [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL] : nil;
    NSDictionary *oauth = [json isKindOfClass:[NSDictionary class]] ? [json objectForKey:@"oauth"] : nil;
    NSString *issuer = [oauth isKindOfClass:[NSDictionary class]] ? Text([oauth objectForKey:@"issuer"], 200) : nil;
    if (!issuer || ![issuer hasPrefix:@"https://"]) {
        if (error) *error = @"Not an HCG identity discovery document.";
        return nil;
    }
    NSMutableArray *rows = [NSMutableArray array];
    [rows addObject:[NSArray arrayWithObjects:@"Contract", Text([json objectForKey:@"version"], 40) ?: @"—", nil]];
    NSString *host = [[issuer substringFromIndex:8] componentsSeparatedByString:@"/"].firstObject;
    [rows addObject:[NSArray arrayWithObjects:@"Sign-in issuer", host.length ? host : @"—", nil]];
    id methods = [oauth objectForKey:@"code_challenge_methods_supported"];
    if ([methods isKindOfClass:[NSArray class]] && [methods containsObject:@"S256"]) [rows addObject:[NSArray arrayWithObjects:@"PKCE", @"S256 supported", nil]];
    id scopes = [oauth objectForKey:@"scopes_supported"];
    if ([scopes isKindOfClass:[NSArray class]]) {
        NSMutableArray *names = [NSMutableArray array];
        for (id s in scopes) if ([s isKindOfClass:[NSString class]] && names.count < 8) [names addObject:s];
        [rows addObject:[NSArray arrayWithObjects:@"Scopes", [names componentsJoinedByString:@" "], nil]];
    }
    id revocation = [oauth objectForKey:@"revocation_endpoint"];
    [rows addObject:[NSArray arrayWithObjects:@"Revocation endpoint", [revocation isKindOfClass:[NSString class]] ? @"Advertised" : @"Not advertised", nil]];
    [rows addObject:[NSArray arrayWithObjects:@"HCG Nexus client", @"Not issued: Nexus cannot sign in", nil]];
    return rows;
}

@end
