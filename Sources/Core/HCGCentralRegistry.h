#import <Foundation/Foundation.h>
#import "HCGRegistry.h"

NS_ASSUME_NONNULL_BEGIN

// The central HCG product registry as HCG Nexus consumes it (docs/CENTRAL-REGISTRY.md).
//
// Source: the main HCG platform's public catalogue, GET https://beta.hakmicapitalgroup.com/api/public/pricing/v1/catalog
// (anonymous, HTTPS to the platform's own host; verified live 26 Nov 2026: api_version "1", 31 products). It is the
// authority for product IDENTITY: registered name, central product ID and release status. Nexus keeps its own
// registry only for what the platform does not publish (categories, adapters, connection methods, requirements).
//
// Rules:
//   * A snapshot only updates entries Nexus already lists by central product ID. It never adds a product, link,
//     endpoint, adapter, capability or permission, and never changes visibility or entitlements: being in the central
//     catalogue grants nothing.
//   * Version validation: api_version "1", at least 5 products with valid IDs, at most 256 KB. The version is the
//     SHA-256 of the identity fields, so an unchanged catalogue keeps its version.
//   * Caching and rollback: the current and the previous valid snapshot are kept; either can be restored, or the
//     built-in registry used alone. Offline, the last valid snapshot (or the built-in registry) is used.
//   * The source URL is fixed in code. A registry file can never name another authority.

FOUNDATION_EXPORT NSString *const HCGCentralRegistryURL;            // the catalogue route above
FOUNDATION_EXPORT NSString *const HCGCentralSnapshotStoreKey;       // "centralSnapshot"
FOUNDATION_EXPORT NSString *const HCGCentralSnapshotPreviousKey;    // "centralSnapshotPrevious"

@interface HCGCentralProduct : NSObject {
    NSString *_productID;
    NSString *_name;
    NSString *_status;
    NSString *_releaseStatus;
}
@property (nonatomic, copy) NSString *productID;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *status;          // central lifecycle_status
@property (nonatomic, copy) NSString *releaseStatus;   // planned, in_development, internal_testing, testflight, published, archived
@end

@interface HCGCentralSnapshot : NSObject {
    NSString *_version;
    NSDate *_fetchedAt;
    NSDictionary *_products;
    NSString *_body;
}
@property (nonatomic, copy) NSString *version;                                   // 16 hex digits
@property (nonatomic, copy) NSDate *fetchedAt;
@property (nonatomic, copy) NSDictionary<NSString *, HCGCentralProduct *> *products; // by product ID
@property (nonatomic, copy) NSString *body;                                      // the validated JSON, for the cache
// nil when the data is not a valid catalogue; `error` says why.
+ (nullable instancetype)snapshotWithData:(nullable NSData *)data fetchedAt:(NSDate *)fetchedAt error:(NSString *_Nullable *_Nullable)error;
// Stored form {version, fetchedAt, body} and back (re-validated on load).
- (NSDictionary *)storedValue;
+ (nullable instancetype)snapshotFromStoredValue:(nullable id)value;
@end

@interface HCGRegistry (Central)
// Entries whose central product ID is in the snapshot take its name and release status, and are marked registered
// (verified live). Entries the built-in registry calls registered but the catalogue does not list get a problem.
// `matched` receives how many entries matched.
- (HCGRegistry *)registryByApplyingCentralSnapshot:(nullable HCGCentralSnapshot *)snapshot matched:(nullable NSUInteger *)matched;
@end

NS_ASSUME_NONNULL_END
