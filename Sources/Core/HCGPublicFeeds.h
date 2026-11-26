#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// Parsers for the anonymous, read-only HCG endpoints the registry lists (no key, login, cookie or token):
//   * HCG News news.v1 article list (hakmicapitalgroup docs/news-api/native-app-handoff.md)
//   * HCG identity discovery (hakmicapitalgroup src/routes/api/public/lifeos/v1/discovery.ts)
// Fetching lives in the platform layer and happens only when the user taps; these only validate and summarise.

@interface HCGNewsArticle : NSObject {
    NSString *_identifier;
    NSString *_title;
    NSString *_excerpt;
    NSString *_section;
    NSString *_publishedAt;
    NSString *_webURL;
    BOOL _demo;
}
@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *excerpt;
@property (nonatomic, copy, nullable) NSString *section;
@property (nonatomic, copy, nullable) NSString *publishedAt;   // ISO 8601 date part "2026-11-04"
@property (nonatomic, copy, nullable) NSString *webURL;        // canonical_web_url, only when it is an HCG https link
@property (nonatomic) BOOL demo;                               // is_demo: labelled
@end

@interface HCGPublicFeeds : NSObject
// The fixed request Nexus sends: the registry endpoint plus "?page=1&per_page=20".
+ (NSString *)newsRequestURLForEndpoint:(NSString *)endpoint;
// nil when the body is not a news.v1 list; `error` says why.
+ (nullable NSArray<HCGNewsArticle *> *)newsArticlesFromData:(nullable NSData *)data total:(nullable NSInteger *)total
                                                       error:(NSString *_Nullable *_Nullable)error;
// (title, value) rows that describe the identity service, or nil. Client identifiers are never shown.
+ (nullable NSArray<NSArray<NSString *> *> *)identityDiscoveryRowsFromData:(nullable NSData *)data error:(NSString *_Nullable *_Nullable)error;
@end

NS_ASSUME_NONNULL_END
