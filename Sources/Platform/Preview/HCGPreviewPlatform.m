#import "HCGPreviewPlatform.h"
#import "HCGConstants.h"

@implementation HCGUserDefaultsKeyValueStore {
    NSUserDefaults *_defaults;
    NSString *_suiteName;
}

- (instancetype)initWithSuiteName:(NSString *)suiteName {
    if ((self = [super init])) {
        _suiteName = [suiteName copy];
        _defaults = [[NSUserDefaults alloc] initWithSuiteName:suiteName];
    }
    return self;
}

- (id)objectForKey:(NSString *)key { return [_defaults objectForKey:key]; }

- (void)setObject:(id)object forKey:(NSString *)key {
    if (object) [_defaults setObject:object forKey:key];
    else [_defaults removeObjectForKey:key];
}

- (void)reload {}

- (BOOL)flush { return YES; }

- (void)removeAllValues {
    [_defaults removePersistentDomainForName:_suiteName];
}

@end

@implementation HCGPreviewLauncher {
    NSMutableArray<NSString *> *_log;
}

@synthesize launcherName = _launcherName;
@synthesize simulated = _simulated;

+ (NSSet<NSString *> *)defaultInstalledApps {
    // Stock Apple apps are treated as installed; HCG apps are not, so the
    // preview shows both the happy path and the "App not installed" path.
    return [NSSet setWithArray:@[ @"com.apple.mobilesafari", @"com.apple.mobilecal", @"com.apple.reminders", @"com.apple.mobilenotes",
                                  @"com.apple.mobilemail", @"com.apple.Preferences", @"com.apple.DocumentsApp", @"com.apple.shortcuts",
                                  @"com.apple.camera", @"com.apple.mobileslideshow", @"com.apple.Music" ]];
}

- (instancetype)init {
    if ((self = [super init])) {
        _launcherName = @"Preview (simulated launches)";
        _simulated = YES;
        _simulatedInstalledApps = [HCGPreviewLauncher defaultInstalledApps];
        _log = [NSMutableArray array];
    }
    return self;
}

- (NSArray<NSString *> *)launchLog { return [_log copy]; }

- (NSString *)capabilitySummary {
    return @"simulated: no app is ever launched; installation state is simulated";
}

- (NSString *)bundleLaunchUnavailableExplanation {
    return @"Preview simulation: app launches are simulated.";
}

// Simulated: the harness pretends app launches work so the UI paths can be
// exercised; every such launch is labelled as simulated.
- (BOOL)canLaunchApplicationsByBundleIdentifier { return YES; }

- (BOOL)canDetermineInstallation { return YES; }

- (BOOL)isApplicationInstalled:(NSString *)bundleIdentifier {
    return [self.simulatedInstalledApps containsObject:bundleIdentifier];
}

- (void)openApplicationWithBundleIdentifier:(NSString *)bundleIdentifier completion:(HCGLaunchCompletion)completion {
    [_log addObject:[@"app:" stringByAppendingString:bundleIdentifier]];
    dispatch_async(dispatch_get_main_queue(), ^{ completion(nil); });
}

- (void)openURL:(NSURL *)url completion:(HCGLaunchCompletion)completion {
    [_log addObject:[@"url:" stringByAppendingString:url.absoluteString ?: @""]];
    BOOL fail = self.simulateURLFailure;
    NSString *scheme = url.scheme.lowercaseString ?: @"";
    dispatch_async(dispatch_get_main_queue(), ^{
        completion(fail ? HCGMakeError(HCGErrorNoHandlerForURL,
                                       [NSString stringWithFormat:@"No installed app opens %@: links.", scheme],
                                       @"Install the app that handles this link, or edit the shortcut to use an https:// address.") : nil);
    });
}

@end

@implementation HCGPreviewEnvironment {
    __weak UIViewController *_host;
    UIViewController *_container;
}

- (instancetype)initWithHostViewController:(UIViewController *)host {
    if ((self = [super init])) {
        _host = host;
    }
    return self;
}

- (NSString *)environmentName { return @"Preview harness (not injected)"; }

- (BOOL)isPreview { return YES; }

- (void)overlayInstallContainerViewController:(UIViewController *)containerViewController {
    UIViewController *host = _host;
    if (_container || !host) return;
    _container = containerViewController;
    _containerInstallCount += 1;
    [host addChildViewController:containerViewController];
    containerViewController.view.frame = host.view.bounds;
    containerViewController.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    containerViewController.view.hidden = YES;
    [host.view addSubview:containerViewController.view];
    [containerViewController didMoveToParentViewController:host];
}

- (void)overlaySetContainerVisible:(BOOL)visible {
    _container.view.hidden = !visible;
    _container.view.userInteractionEnabled = visible;
    if (visible) [_container.view.superview bringSubviewToFront:_container.view];
}

- (BOOL)overlayUsesManualRotation { return NO; }

- (HCGInterfaceOrientation)overlayInterfaceOrientation {
    UIWindowScene *scene = _host.view.window.windowScene;
    switch (scene ? scene.interfaceOrientation : UIInterfaceOrientationPortrait) {
        case UIInterfaceOrientationLandscapeLeft: return HCGInterfaceOrientationLandscapeLeft;
        case UIInterfaceOrientationLandscapeRight: return HCGInterfaceOrientationLandscapeRight;
        case UIInterfaceOrientationPortraitUpsideDown: return HCGInterfaceOrientationPortraitUpsideDown;
        default: return HCGInterfaceOrientationPortrait;
    }
}

- (void)overlayTextInputActive:(BOOL)active {}

- (NSUInteger)overlayWindowCount {
    return 0; // embedded view, no separate window
}

@end
