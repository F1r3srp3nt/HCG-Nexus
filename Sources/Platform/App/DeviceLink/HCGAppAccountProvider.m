#import "HCGAppAccountProvider.h"

@implementation HCGAppAccountProvider {
    id<HCGLinkServicing> _Nullable (^_serviceProvider)(void);
    HCGAccountConfiguration *_configuration;
}

- (instancetype)initWithServiceProvider:(id<HCGLinkServicing> _Nullable (^)(void))serviceProvider {
    if ((self = [super init])) {
        _serviceProvider = [serviceProvider copy];
        NSBundle *bundle = [NSBundle mainBundle];
        _configuration = [HCGAccountConfiguration configurationWithClientID:[bundle objectForInfoDictionaryKey:@"HCGConnectClientID"]
                                                                redirectURI:[bundle objectForInfoDictionaryKey:@"HCGConnectRedirectURI"]];
    }
    return self;
}

// The service is created lazily (first use), never at launch, and only when a client is configured:
// with no client there is nothing to sign in to, so nothing is constructed or contacted.
- (id<HCGLinkServicing>)service {
    if (!_configuration.isConfigured || !_serviceProvider) return nil;
    return _serviceProvider();
}

- (HCGAccountState)accountState {
    if (!_configuration.isConfigured) return HCGAccountStateNotConfigured;
    id<HCGLinkServicing> service = [self service];
    if (!service) return HCGAccountStateNotConfigured;
    switch (service.snapshot.accountState) {
        case HCGLinkAccountStateNotConfigured: return HCGAccountStateNotConfigured;
        case HCGLinkAccountStateSignedOut: return HCGAccountStateSignedOut;
        case HCGLinkAccountStateSignedIn: return HCGAccountStateSignedIn;
        case HCGLinkAccountStateEnded: return HCGAccountStateSessionEnded;
    }
    return HCGAccountStateNotConfigured;
}

- (NSString *)accountDisplayName {
    if ([self accountState] != HCGAccountStateSignedIn) return nil;
    return [self service].snapshot.accountEmail;
}

- (NSString *)accountDetail {
    if (!_configuration.isConfigured) return _configuration.problem;
    return [self service].snapshot.accountDetail;
}

// The HCG /me profile (organisations) is not fetched by this build; nil means "not loaded",
// never an empty list pretending the user has none.
- (NSArray<NSString *> *)organisationNames {
    return nil;
}

- (NSString *)connectionSummary {
    if (!_configuration.isConfigured) return @"Needs HCG sign-in (not configured)";
    id<HCGLinkServicing> service = [self service];
    if (!service) return @"Unavailable in this build";
    HCGLinkSnapshot *snapshot = service.snapshot;
    switch (snapshot.connectionState) {
        case HCGLinkConnectionStateNotPaired: return @"Not paired";
        case HCGLinkConnectionStateAwaitingApproval: return @"Awaiting owner approval";
        case HCGLinkConnectionStateConnected: return [NSString stringWithFormat:@"Connected · %lu devices", (unsigned long)snapshot.devices.count];
        case HCGLinkConnectionStateOffline: return @"Offline · retrying";
        case HCGLinkConnectionStatePaused: return @"Paused";
        case HCGLinkConnectionStateEnded: return @"Pairing ended";
        case HCGLinkConnectionStateRemoved: return @"Removed by the server";
    }
    return @"Unknown";
}

- (BOOL)canSignIn {
    HCGAccountState state = [self accountState];
    return _configuration.isConfigured && (state == HCGAccountStateSignedOut || state == HCGAccountStateSessionEnded);
}

- (void)signInFromViewController:(UIViewController *)presenter {
    if (![self canSignIn]) return;
    [[self service] signInPresentingFromWindow:presenter.view.window];
}

- (void)signOut {
    [[self service] signOut];
}

- (NSDictionary *)scopedSummary {
    NSMutableDictionary *summary = [NSMutableDictionary dictionary];
    summary[HCGAccountSummaryState] = @([self accountState]);
    NSString *name = [self accountDisplayName];
    if (name) summary[HCGAccountSummaryDisplayName] = name;
    summary[HCGAccountSummaryUpdated] = @([[NSDate date] timeIntervalSince1970]);
    return [HCGAccountSummary sanitizedSummary:summary];
}

@end
