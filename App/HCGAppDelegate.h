#import <UIKit/UIKit.h>
#import "HCGNexusModel.h"

NS_ASSUME_NONNULL_BEGIN

// Standalone app delegate. Owns the single shared model so every scene (iPad
// windows included) shows the same workspaces.
@interface HCGAppDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, readonly) HCGNexusModel *model;
+ (nullable instancetype)sharedDelegate;
@end

NS_ASSUME_NONNULL_END
