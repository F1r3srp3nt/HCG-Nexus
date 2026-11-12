#import <Foundation/Foundation.h>
#import "HCGNexusModel.h"

NS_ASSUME_NONNULL_BEGIN

typedef void (^HCGActionCompletion)(NSError *_Nullable error, NSString *summary);

// Resolves a shortcut to a concrete launch through the configured launcher and
// turns every failure into an actionable error (missing app, no handler for a
// link, unconnected integration, unavailable launcher). Records Recents.
@interface HCGActionRunner : NSObject
- (instancetype)initWithModel:(HCGNexusModel *)model;
- (void)runAction:(HCGAction *)action completion:(HCGActionCompletion)completion;
@end

NS_ASSUME_NONNULL_END
