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
