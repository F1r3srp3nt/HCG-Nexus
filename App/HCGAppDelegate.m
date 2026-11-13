#import "HCGAppDelegate.h"
#import "HCGAppPlatform.h"

@implementation HCGAppDelegate

+ (instancetype)sharedDelegate {
    id delegate = [UIApplication sharedApplication].delegate;
    return [delegate isKindOfClass:[HCGAppDelegate class]] ? delegate : nil;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // App data lives in this app's sandbox under its own suite; it never reads
    // or writes the jailbreak package's preference domain.
    HCGAppDefaultsStore *store = [[HCGAppDefaultsStore alloc] initWithSuiteName:HCGAppDataSuiteName];
    HCGAppLauncher *launcher = [[HCGAppLauncher alloc] initWithApplication:application];
    _model = [[HCGNexusModel alloc] initWithStore:store notifier:nil launcher:launcher];
    return YES;
}

- (UISceneConfiguration *)application:(UIApplication *)application
configurationForConnectingSceneSession:(UISceneSession *)connectingSceneSession
                              options:(UISceneConnectionOptions *)options {
    UISceneConfiguration *configuration = [[UISceneConfiguration alloc] initWithName:@"Default Configuration"
                                                                         sessionRole:connectingSceneSession.role];
    configuration.delegateClass = NSClassFromString(@"HCGSceneDelegate");
    return configuration;
}

@end
