#import "HCGAppPlatform.h"
#import "HCGConstants.h"

NSString *const HCGAppDataSuiteName = @"com.hakmicapitalgroup.hcgnexus.app.data";
const NSTimeInterval HCGAppLinkConnectedWindow = 120;

static BOOL HCGSharedLinkServiceAvailable(void) {
    Class cls = NSClassFromString(@"HCGLinkService");
    return cls && [cls conformsToProtocol:@protocol(HCGLinkServicing)];
}

static NSString *HCGAppLinkTime(NSDate *date) {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateStyle = NSDateFormatterMediumStyle;
    formatter.timeStyle = NSDateFormatterMediumStyle;
    formatter.doesRelativeDateFormatting = YES;
    return [formatter stringFromDate:date];
}

void HCGAppApplyLinkSnapshot(HCGLinkSnapshot *snapshot, HCGHIPFacts *f, NSDate *now) {
    if (!snapshot) {
        f.serviceLinkState = HCGHIPServiceLinkStateNotConnected;
        f.serviceLinkDetail = @"HCG Nexus has not contacted HCG Server since it was opened. Open Connected Devices to connect.";
        return;
    }
    HCGLinkSnapshot *s = snapshot;
    f.serviceLinkServerName = s.serverName;
    f.serviceLinkLocalDevelopment = s.localDevelopment;
    f.serviceLinkHostedServices = s.servicesLoaded ? (NSInteger)s.services.count : -1;
    NSString *lastSync = s.lastSync ? [NSString stringWithFormat:@"Last successful sync %@.", HCGAppLinkTime(s.lastSync)] : nil;
    switch (s.connectionState) {
        case HCGLinkConnectionStateNotPaired:
            f.serviceLinkState = HCGHIPServiceLinkStateNotPaired;
            f.serviceLinkDetail = s.connectionDetail.length ? s.connectionDetail : @"Pair in Connected Devices with an invitation code from HCG Server.";
            break;
        case HCGLinkConnectionStateAwaitingApproval:
            f.serviceLinkState = HCGHIPServiceLinkStateAwaitingApproval;
            f.serviceLinkDetail = nil;
            break;
        case HCGLinkConnectionStatePaired:
            f.serviceLinkState = HCGHIPServiceLinkStateNotConnected;
            f.serviceLinkDetail = @"Not contacted since HCG Nexus was opened. Open Connected Devices to connect.";
            break;
        case HCGLinkConnectionStateConnected: {
            BOOL recent = s.lastSync && [now timeIntervalSinceDate:s.lastSync] <= HCGAppLinkConnectedWindow;
            f.serviceLinkState = recent ? HCGHIPServiceLinkStateConnected : HCGHIPServiceLinkStateNotConnected;
            f.serviceLinkDetail = recent ? lastSync
                                         : [NSString stringWithFormat:@"%@ Nexus syncs only while Connected Devices is open.", lastSync ?: @"Not synced yet."];
            break;
        }
        case HCGLinkConnectionStateOffline:
            f.serviceLinkState = HCGHIPServiceLinkStateUnreachable;
            f.serviceLinkDetail = s.connectionDetail.length ? s.connectionDetail : @"HCG Server did not answer.";
            break;
        case HCGLinkConnectionStatePaused:
            f.serviceLinkState = HCGHIPServiceLinkStateNotConnected;
            f.serviceLinkDetail = s.connectionDetail;
            break;
        case HCGLinkConnectionStateEnded:
        case HCGLinkConnectionStateRemoved:
        case HCGLinkConnectionStateAuthorityChanged:
            f.serviceLinkState = HCGHIPServiceLinkStateEnded;
            f.serviceLinkDetail = s.connectionDetail;
            break;
    }
}

@implementation HCGAppDefaultsStore {
    NSUserDefaults *_defaults;
}

- (instancetype)initWithSuiteName:(NSString *)suiteName {
    if ((self = [super init])) {
        _suiteName = [suiteName copy];
        _defaults = [[NSUserDefaults alloc] initWithSuiteName:suiteName];
    }
    return self;
}

- (id)objectForKey:(NSString *)key {
    return [_defaults objectForKey:key];
}

- (void)setObject:(id)object forKey:(NSString *)key {
    if (object) [_defaults setObject:object forKey:key];
    else [_defaults removeObjectForKey:key];
}

- (void)reload {
}

- (BOOL)flush {
    // NSUserDefaults persists automatically; nothing can fail here.
    return YES;
}

- (void)removeAllValues {
    [_defaults removePersistentDomainForName:_suiteName];
}

@end

@implementation HCGAppLauncher {
    __weak UIApplication *_application;
}

@synthesize launcherName = _launcherName;
@synthesize simulated = _simulated;

- (instancetype)init {
    return [self initWithApplication:nil];
}

- (instancetype)initWithApplication:(UIApplication *)application {
    if ((self = [super init])) {
        _application = application;
        _launcherName = @"Standalone app (UIApplication openURL)";
        _simulated = NO;
    }
    return self;
}

- (UIApplication *)application {
    return _application ?: [UIApplication sharedApplication];
}

- (NSString *)capabilitySummary {
    return @"links=openURL appLaunchByBundleID=unavailable (iOS sandbox) installCheck=unavailable";
}

- (NSString *)bundleLaunchUnavailableExplanation {
    return @"iOS only lets ordinary apps open links, not other apps by bundle identifier. Use a link shortcut (https://, mailto:, or a URL scheme the target app documents), or install the HCG Nexus jailbreak package for system-wide app launching.";
}

- (BOOL)canLaunchApplicationsByBundleIdentifier {
    return NO;
}

- (BOOL)canDetermineInstallation {
    return NO;
}

- (BOOL)isApplicationInstalled:(NSString *)bundleIdentifier {
    return NO;
}

// Sandboxed: installation is unknowable; only whether a product's own link opens (LSApplicationQueriesSchemes
// in App/Info.plist lists hcgterminal, hcgterminal-unleashed and hcgsentinel).
- (NSArray *)ecosystemFacts {
    if (![NSThread isMainThread]) {
        // canOpenURL: belongs on the main thread; callers read facts on a background queue.
        __block NSArray *facts = nil;
        dispatch_sync(dispatch_get_main_queue(), ^{ facts = [self ecosystemFacts]; });
        return facts;
    }
    UIApplication *application = [self application];
    NSString *os = [[UIDevice currentDevice] systemVersion];
    NSMutableArray *all = [NSMutableArray array];
    for (HCGHIPProductDescriptor *d in [HCGInterchange registry]) {
        HCGHIPFacts *f = [[HCGHIPFacts alloc] init];
        f.productID = d.productID;
        f.osVersion = os;
        if (d.urlScheme.length && application) {
            NSURL *probe = [NSURL URLWithString:[d.urlScheme stringByAppendingString:@"://open/dashboard"]];
            f.canOpenScheme = probe && [application canOpenURL:probe];
        }
        // HCG Server: the real Device Link state, read without creating the service (or a device key).
        if ([d.productID isEqualToString:HCGHIPProductServer]) {
            id<HCGLinkServicing> link = HCGExistingLinkService();
            if (link || HCGSharedLinkServiceAvailable()) HCGAppApplyLinkSnapshot(link.snapshot, f, [NSDate date]);
        }
        [all addObject:f];
    }
    return all;
}

- (NSArray *)ecosystemDeviceOverview {
    UIDevice *device = [UIDevice currentDevice];
    return @[ @[ @"Device", device.model ?: @"iPhone" ], @[ @"iOS", device.systemVersion ?: @"—" ],
              @[ @"Jailbreak", @"Not visible to this app (standalone build)" ] ];
}

- (void)openApplicationWithBundleIdentifier:(NSString *)bundleIdentifier completion:(HCGLaunchCompletion)completion {
    NSError *error = HCGMakeError(HCGErrorLauncherUnavailable,
                                  [NSString stringWithFormat:@"%@ can't be opened by bundle identifier here.", bundleIdentifier],
                                  [self bundleLaunchUnavailableExplanation]);
    dispatch_async(dispatch_get_main_queue(), ^{ completion(error); });
}

- (void)openURL:(NSURL *)url completion:(HCGLaunchCompletion)completion {
    NSString *scheme = url.scheme.lowercaseString ?: @"";
    UIApplication *application = [self application];
    if (!application) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(HCGMakeError(HCGErrorLauncherUnavailable, @"Links can't be opened right now.", @"Try again from the app."));
        });
        return;
    }
    [application openURL:url options:@{} completionHandler:^(BOOL success) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(success ? nil : HCGMakeError(HCGErrorNoHandlerForURL,
                                                    [NSString stringWithFormat:@"iOS couldn't open this %@: link.", scheme],
                                                    @"No installed app handles it, or iOS declined the request. Install the app that handles this link, or edit the shortcut to use an https:// address."));
        });
    }];
}

@end
