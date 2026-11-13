#import "HCGPanelContext.h"

NSString *HCGPanelModeName(HCGPanelMode mode) {
    switch (mode) {
        case HCGPanelModeOverlay: return @"SpringBoard overlay (jailbreak package)";
        case HCGPanelModeSettingsApp: return @"Settings bundle (jailbreak package)";
        case HCGPanelModeStandaloneApp: return @"Standalone app (sandboxed)";
        case HCGPanelModePreview: return @"Preview harness (simulation, not injected)";
    }
    return @"Unknown";
}

@implementation HCGPanelContext
- (BOOL)insideOverlay {
    return self.closePanel != nil;
}
- (BOOL)overlayControlsOperational {
    return self.mode != HCGPanelModeStandaloneApp;
}
- (BOOL)isStandaloneApp {
    return self.mode == HCGPanelModeStandaloneApp;
}
@end

void HCGPresentError(UIViewController *presenter, NSError *error, UIAlertAction *extraAction) {
    if (!presenter || !error) return;
    NSString *recovery = error.localizedRecoverySuggestion;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:error.localizedDescription
                                                                   message:recovery
                                                            preferredStyle:UIAlertControllerStyleAlert];
    alert.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
    if (extraAction) [alert addAction:extraAction];
    UIViewController *top = presenter;
    while (top.presentedViewController) top = top.presentedViewController;
    [top presentViewController:alert animated:!UIAccessibilityIsReduceMotionEnabled() completion:nil];
}
