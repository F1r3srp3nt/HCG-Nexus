#import "HCGPanelContext.h"

@implementation HCGPanelContext
- (BOOL)insideOverlay {
    return self.closePanel != nil;
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
