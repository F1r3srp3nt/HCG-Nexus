#import <Foundation/Foundation.h>
#import "HCGNexusModel.h"
#import "HCGEcosystemData.h"

NS_ASSUME_NONNULL_BEGIN

// One registry product as the Command Center shows it: the entry, this iPhone's HIP status (when Nexus has an
// adapter), the evidence-based connection status and the roadmap state.
@interface HCGCommandCenterItem : NSObject
@property (nonatomic, strong) HCGRegistryEntry *entry;
@property (nonatomic, strong, nullable) HCGHIPProductStatus *hip;
@property (nonatomic, strong) HCGConnectionSummary *connection;
@property (nonatomic, strong) HCGRoadmapAssessment *roadmap;
@end

@interface HCGCommandCenterSnapshot : NSObject
@property (nonatomic, strong) HCGRegistry *registry;
@property (nonatomic, copy) NSArray<HCGCommandCenterItem *> *items;    // visible entries, registry order
@property (nonatomic, strong, nullable) HCGEcosystemSnapshot *ecosystem;
@property (nonatomic, copy) NSArray<NSArray<NSString *> *> *notices;   // (text, entry ID or "") needing attention
- (nullable HCGCommandCenterItem *)itemForID:(NSString *)identifier;
- (NSArray<HCGCommandCenterItem *> *)itemsInCategory:(NSString *)categoryID;
- (NSUInteger)countInState:(HCGConnectionState)state;
@end

@interface HCGCommandCenterData : NSObject
// Reads the HIP facts off the main thread (HCGEcosystemData), then derives everything on the main queue and records
// roadmap changes. Nothing connects or starts: only stored evidence and the read-only scan are used.
+ (void)loadWithModel:(HCGNexusModel *)model completion:(void (^)(HCGCommandCenterSnapshot *snapshot))completion;
// Re-derives from an existing ecosystem scan (after a read changed the ledger).
+ (HCGCommandCenterSnapshot *)snapshotWithModel:(HCGNexusModel *)model ecosystem:(nullable HCGEcosystemSnapshot *)ecosystem;
@end

// GET of a registry endpoint: https on hakmicapitalgroup.com only, no cookies, credentials or cache, no redirects,
// at most 1 MB, 20 s. `state` is "200", an HTTP status or "error: …".
@interface HCGPublicReader : NSObject <NSURLSessionTaskDelegate>
+ (instancetype)sharedReader;
- (void)getURLString:(NSString *)urlString completion:(void (^)(NSData *_Nullable data, NSString *state))completion;
@end

NS_ASSUME_NONNULL_END
