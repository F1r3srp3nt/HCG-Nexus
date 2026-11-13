#import "HCGSceneDelegate.h"
#import "HCGAppDelegate.h"
#import "HCGAppRootViewController.h"

@implementation HCGSceneDelegate

- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)connectionOptions {
    if (![scene isKindOfClass:[UIWindowScene class]]) return;
    HCGNexusModel *model = [HCGAppDelegate sharedDelegate].model;
    if (!model) return;
    UIWindow *window = [[UIWindow alloc] initWithWindowScene:(UIWindowScene *)scene];
    window.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    window.rootViewController = [[HCGAppRootViewController alloc] initWithModel:model];
    self.window = window;
    [window makeKeyAndVisible];
}

- (void)sceneWillEnterForeground:(UIScene *)scene {
    // Pick up changes made in another window of this app (iPad multitasking).
    [[HCGAppDelegate sharedDelegate].model reload];
}

@end
