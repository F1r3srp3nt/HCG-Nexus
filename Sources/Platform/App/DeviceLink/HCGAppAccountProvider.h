#import <UIKit/UIKit.h>
#import "HCGPanelContext.h"
#import "HCGLinkTypes.h"

NS_ASSUME_NONNULL_BEGIN

// STANDALONE APP ONLY. Account and Connected Devices status for the panel, read
// from the HCG Device Link service's HCG Connect session (the app's only sign-in,
// PKCE + Keychain). Exposes display values and actions only: never tokens.
// Until HCG issues Nexus's client (empty HCGConnectClientID), the state is
// "Not configured" and nothing is contacted.
@interface HCGAppAccountProvider : NSObject <HCGAccountProviding>
- (instancetype)initWithServiceProvider:(id<HCGLinkServicing> _Nullable (^)(void))serviceProvider;
// The redacted summary the tweak may read later (HCGAccountSummary rules: no credentials).
- (nullable NSDictionary *)scopedSummary;
@end

NS_ASSUME_NONNULL_END
