#import "HCGAppPlatform.h"
#import "HCGConstants.h"

NSString *const HCGAppDataSuiteName = @"com.hakmicapitalgroup.hcgnexus.app.data";

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
