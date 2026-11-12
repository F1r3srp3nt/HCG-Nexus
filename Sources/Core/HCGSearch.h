#import <Foundation/Foundation.h>
#import "HCGWorkspace.h"

NS_ASSUME_NONNULL_BEGIN

@interface HCGSearchResult : NSObject {
    HCGAction *_action;
    HCGWorkspace *_workspace;
    NSInteger _score;
    NSUInteger _order;
}
@property (nonatomic, strong) HCGAction *action;
@property (nonatomic, strong) HCGWorkspace *workspace;
@property (nonatomic) NSInteger score;   // lower is better
@property (nonatomic) NSUInteger order;  // original position, for stable sort
- (NSComparisonResult)compare:(HCGSearchResult *)other;
@end

@interface HCGSearch : NSObject
// Case- and diacritic-insensitive. Empty query returns the active workspace's
// shortcuts in order. Otherwise searches every workspace; ranking:
// title prefix < word prefix < title substring < target substring.
+ (NSArray<HCGSearchResult *> *)resultsForQuery:(nullable NSString *)query
                                   inWorkspaces:(NSArray<HCGWorkspace *> *)workspaces
                                activeWorkspace:(nullable HCGWorkspace *)active;
+ (NSString *)normalizedString:(NSString *)string;
@end

NS_ASSUME_NONNULL_END
