#import "HCGEcosystemData.h"

@implementation HCGEcosystemSnapshot

- (HCGHIPProductStatus *)statusForProductID:(NSString *)productID {
    for (HCGHIPProductStatus *status in self.statuses) {
        if ([status.descriptor.productID isEqualToString:productID]) return status;
    }
    return nil;
}

- (HCGHIPFacts *)factsForProductID:(NSString *)productID {
    for (HCGHIPFacts *facts in self.facts) {
        if ([facts.productID isEqualToString:productID]) return facts;
    }
    return nil;
}

@end

@implementation HCGEcosystemData

+ (void)loadWithLauncher:(id<HCGLauncher>)launcher completion:(void (^)(HCGEcosystemSnapshot *))completion {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSArray *facts = [launcher respondsToSelector:@selector(ecosystemFacts)] ? [launcher ecosystemFacts] : @[];
        NSArray *rows = [launcher respondsToSelector:@selector(ecosystemDeviceOverview)] ? [launcher ecosystemDeviceOverview] : @[];
        HCGEcosystemSnapshot *snapshot = [[HCGEcosystemSnapshot alloc] init];
        snapshot.facts = facts;
        snapshot.deviceRows = rows;
        NSMutableArray *statuses = [NSMutableArray array];
        for (HCGHIPProductDescriptor *d in [HCGInterchange registry]) {
            HCGHIPFacts *match = nil;
            for (HCGHIPFacts *f in facts) {
                if ([f.productID isEqualToString:d.productID]) match = f;
            }
            if (match.simulated) snapshot.simulated = YES;
            if (match.hostCanInspect) snapshot.inspected = YES;
            [statuses addObject:[HCGInterchange statusForDescriptor:d facts:match]];
        }
        snapshot.statuses = statuses;
        dispatch_async(dispatch_get_main_queue(), ^{ completion(snapshot); });
    });
}

@end
