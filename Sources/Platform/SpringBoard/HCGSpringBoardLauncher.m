#import "HCGSpringBoardLauncher.h"
#import "HCGConstants.h"
#import <UIKit/UIKit.h>

// Private LaunchServices API, declared locally and verified at runtime.
@interface NSObject (HCGLSApplicationWorkspace)
+ (id)defaultWorkspace;
- (BOOL)applicationIsInstalled:(NSString *)bundleIdentifier;
- (BOOL)openApplicationWithBundleID:(NSString *)bundleIdentifier;
@end

// SpringBoard's own launcher (private UIApplication API inside SpringBoard),
// used only as a verified fallback when LaunchServices refuses.
@interface UIApplication (HCGSpringBoardLaunch)
- (BOOL)launchApplicationWithIdentifier:(NSString *)identifier suspended:(BOOL)suspended;
@end

@implementation HCGSpringBoardLauncher {
    id _workspace;
    BOOL _canCheckInstalled;
    BOOL _canOpenApps;
    BOOL _canFallback;
}

@synthesize launcherName = _launcherName;
@synthesize simulated = _simulated;

- (instancetype)init {
    if ((self = [super init])) {
        _launcherName = @"SpringBoard (LSApplicationWorkspace)";
        _simulated = NO;
        Class workspaceClass = NSClassFromString(@"LSApplicationWorkspace");
        if (workspaceClass && [workspaceClass respondsToSelector:@selector(defaultWorkspace)]) {
            _workspace = [workspaceClass defaultWorkspace];
        }
        _canCheckInstalled = [_workspace respondsToSelector:@selector(applicationIsInstalled:)];
        _canFallback = [[UIApplication sharedApplication] respondsToSelector:@selector(launchApplicationWithIdentifier:suspended:)];
        _canOpenApps = [_workspace respondsToSelector:@selector(openApplicationWithBundleID:)] || _canFallback;
    }
    return self;
}

- (BOOL)canLaunchApplications {
    return _canOpenApps;
}

- (NSString *)capabilitySummary {
    return [NSString stringWithFormat:@"installCheck=%@ appLaunch=%@ fallback=%@ urlOpen=%@",
            _canCheckInstalled ? @"LSApplicationWorkspace applicationIsInstalled:" : @"missing",
            [_workspace respondsToSelector:@selector(openApplicationWithBundleID:)] ? @"LSApplicationWorkspace openApplicationWithBundleID:" : @"missing",
            _canFallback ? @"launchApplicationWithIdentifier:suspended:" : @"missing",
            [[UIApplication sharedApplication] respondsToSelector:@selector(openURL:options:completionHandler:)] ? @"yes" : @"missing"];
}

- (NSString *)bundleLaunchUnavailableExplanation {
    return @"This iOS version doesn't expose the LaunchServices calls HCG Nexus uses inside SpringBoard. Report your iOS and jailbreak versions (Settings › HCG Nexus › Diagnostics) so a compatible adapter can be added.";
}

- (BOOL)canLaunchApplicationsByBundleIdentifier {
    return _canOpenApps;
}

- (BOOL)canDetermineInstallation {
    return _canCheckInstalled;
}

- (BOOL)isApplicationInstalled:(NSString *)bundleIdentifier {
    if (!_canCheckInstalled) return YES;
    return [_workspace applicationIsInstalled:bundleIdentifier];
}

- (void)openApplicationWithBundleIdentifier:(NSString *)bundleIdentifier completion:(HCGLaunchCompletion)completion {
    if (!_canOpenApps) {
        completion(HCGMakeError(HCGErrorLauncherUnavailable,
                                @"This iOS version doesn't expose the app launcher HCG Nexus uses.",
                                @"Report your iOS and jailbreak versions (Settings › HCG Nexus › Diagnostics) so a compatible adapter can be added."));
        return;
    }
    id workspace = [_workspace respondsToSelector:@selector(openApplicationWithBundleID:)] ? _workspace : nil;
    BOOL canFallback = _canFallback;
    NSString *bundle = [bundleIdentifier copy];
    // LaunchServices IPC happens off the main thread; it is user-initiated and
    // never part of a SpringBoard lifecycle callback.
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        BOOL ok = workspace ? [workspace openApplicationWithBundleID:bundle] : NO;
        dispatch_async(dispatch_get_main_queue(), ^{
            BOOL launched = ok;
            // SpringBoard's own launcher must be called on the main thread.
            if (!launched && canFallback) launched = [[UIApplication sharedApplication] launchApplicationWithIdentifier:bundle suspended:NO];
            completion(launched ? nil : HCGMakeError(HCGErrorLaunchFailed,
                                               [NSString stringWithFormat:@"%@ couldn't be opened.", bundle],
                                               @"Open the app from the Home Screen once, then try again. If it is restricted by Screen Time, allow it first."));
        });
    });
}

- (void)openURL:(NSURL *)url completion:(HCGLaunchCompletion)completion {
    UIApplication *app = [UIApplication sharedApplication];
    if (![app respondsToSelector:@selector(openURL:options:completionHandler:)]) {
        completion(HCGMakeError(HCGErrorLauncherUnavailable, @"Opening links isn't available here.", nil));
        return;
    }
    NSString *scheme = url.scheme.lowercaseString ?: @"";
    [app openURL:url options:@{} completionHandler:^(BOOL success) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(success ? nil : HCGMakeError(HCGErrorNoHandlerForURL,
                                                    [NSString stringWithFormat:@"No installed app opens %@: links.", scheme],
                                                    @"Install the app that handles this link, or edit the shortcut to use an https:// address."));
        });
    }];
}

@end
