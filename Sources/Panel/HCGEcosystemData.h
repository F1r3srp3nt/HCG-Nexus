#import <Foundation/Foundation.h>
#import "HCGLauncher.h"

NS_ASSUME_NONNULL_BEGIN

// One read of the HCG ecosystem: a status for every registry product plus the device overview.
@interface HCGEcosystemSnapshot : NSObject
@property (nonatomic, copy) NSArray<HCGHIPProductStatus *> *statuses;      // registry order
@property (nonatomic, copy) NSArray<HCGHIPFacts *> *facts;
@property (nonatomic, copy) NSArray<NSArray<NSString *> *> *deviceRows;
@property (nonatomic) BOOL simulated;      // preview harness
@property (nonatomic) BOOL inspected;      // this host can see installed products
- (nullable HCGHIPProductStatus *)statusForProductID:(NSString *)productID;
- (nullable HCGHIPFacts *)factsForProductID:(NSString *)productID;
@end

@interface HCGEcosystemData : NSObject
// Reads facts off the main thread (file reads in SpringBoard); the completion runs on the main queue.
+ (void)loadWithLauncher:(nullable id<HCGLauncher>)launcher completion:(void (^)(HCGEcosystemSnapshot *snapshot))completion;
@end

NS_ASSUME_NONNULL_END
