#import "HCGLinkTypes.h"

@implementation HCGLinkCapabilityInfo
- (instancetype)init {
    if ((self = [super init])) {
        _identifier = @"";
        _state = @"unavailable";
    }
    return self;
}
@end

@implementation HCGLinkDeviceInfo
- (instancetype)init {
    if ((self = [super init])) {
        _installationId = @"";
        _name = @"";
        _appName = @"";
        _appVersion = @"";
        _platform = @"";
        _presence = @"Never seen";
        _keyFingerprint = @"";
        _capabilities = @[];
    }
    return self;
}
@end

@implementation HCGLinkInboxItem
- (instancetype)init {
    if ((self = [super init])) {
        _messageId = @"";
        _title = @"";
        _fromName = @"";
        _fromApp = @"";
        _receivedAt = [NSDate date];
        _expiresAt = [NSDate date];
        _status = @"queued";
    }
    return self;
}
@end

@implementation HCGLinkReportSection
- (instancetype)init {
    if ((self = [super init])) {
        _title = @"";
        _lines = @[];
    }
    return self;
}
@end

@implementation HCGLinkOpenedReport
- (instancetype)init {
    if ((self = [super init])) {
        _messageId = @"";
        _title = @"";
        _fromName = @"";
        _fromApp = @"";
        _receivedAt = [NSDate date];
        _sections = @[];
    }
    return self;
}
@end

@implementation HCGLinkHostInfo
- (instancetype)init {
    if ((self = [super init])) {
        _name = @"";
        _platform = @"";
        _architecture = @"";
        _loadAverage = @[];
        _agentVersion = @"";
        _agentStartedAt = [NSDate date];
        _gatewayExposure = @"loopback";
        _sampledAt = [NSDate date];
    }
    return self;
}
@end

@implementation HCGLinkHostedServiceInfo
- (instancetype)init {
    if ((self = [super init])) {
        _identifier = @"";
        _name = @"";
        _version = @"";
        _runtime = @"";
        _status = @"registered";
        _health = @"unknown";
        _capabilities = @[];
    }
    return self;
}
@end

@implementation HCGLinkOpenTicketInfo
- (instancetype)init {
    if ((self = [super init])) {
        _url = [NSURL URLWithString:@"about:blank"];
        _expiresAt = [NSDate date];
        _caFingerprint = @"";
        _note = @"";
    }
    return self;
}
@end

@implementation HCGLinkDiagnosticsInfo
- (instancetype)init {
    if ((self = [super init])) {
        _generatedAt = [NSDate date];
        _serverName = @"HCG Server";
        _sections = @[];
    }
    return self;
}
@end

@implementation HCGLinkInvitationPreview
- (instancetype)init {
    if ((self = [super init])) {
        _serverName = @"";
        _serverAddress = @"";
        _serverFingerprint = @"";
        _thisDeviceFingerprint = @"";
    }
    return self;
}
@end

@implementation HCGLinkSnapshot
- (instancetype)init {
    if ((self = [super init])) {
        _accountState = HCGLinkAccountStateNotConfigured;
        _deviceName = @"";
        _appVersion = @"";
        _advertisedCapabilities = @[];
        _connectionState = HCGLinkConnectionStateNotPaired;
        _devices = @[];
        _services = @[];
        _inbox = @[];
        _approvalsNote = @"Action execution is disabled in this version of HCG Device Link, so there is nothing to approve.";
    }
    return self;
}
@end

id<HCGLinkServicing> HCGSharedLinkService(void) {
    // Looked up by name so the Objective-C screens (and scripts/compile-app-target.sh,
    // which compiles only Objective-C) do not depend on the generated Swift header.
    // The Swift class conforms to HCGLinkServicing through the bridging header,
    // so Xcode checks every method signature.
    Class cls = NSClassFromString(@"HCGLinkService");
    if (!cls || ![cls conformsToProtocol:@protocol(HCGLinkServicing)]) return nil;
    return [(Class<HCGLinkServicing>)cls sharedLinkService];
}

id<HCGLinkServicing> HCGExistingLinkService(void) {
    Class cls = NSClassFromString(@"HCGLinkService");
    if (!cls || ![cls conformsToProtocol:@protocol(HCGLinkServicing)]) return nil;
    return [(Class<HCGLinkServicing>)cls existingLinkService];
}

NSString *const HCGLinkLocalDevelopmentLabel = @"LOCAL DEVELOPMENT — not an HCG account";

NSString *HCGLinkAppDisplayName(NSString *appIdentifier) {
    if ([appIdentifier isEqualToString:@"hcg.sentinel"]) return @"HCG Sentinel";
    if ([appIdentifier isEqualToString:@"hcg.terminal"]) return @"HCG Terminal";
    if ([appIdentifier isEqualToString:@"hcg.nexus"]) return @"HCG Nexus";
    return appIdentifier;
}
