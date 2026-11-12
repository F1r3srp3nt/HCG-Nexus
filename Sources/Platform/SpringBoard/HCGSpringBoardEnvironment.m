#import "HCGSpringBoardEnvironment.h"

const UIWindowLevel HCGOverlayWindowLevel = 999.0; // UIWindowLevelStatusBar (1000) - 1

@interface NSObject (HCGSpringBoardOrientation)
- (long long)activeInterfaceOrientation;
- (long long)_frontMostAppOrientation;
@end

@interface HCGOverlayWindow : UIWindow
@end

@implementation HCGOverlayWindow

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    if (self.hidden || self.alpha < 0.01) return nil;
    UIView *hit = [super hitTest:point withEvent:event];
    return hit == self ? nil : hit;
}

// Only made key explicitly, while the panel search/text fields are editing.
- (BOOL)canBecomeKeyWindow {
    return YES;
}

@end

@implementation HCGSpringBoardEnvironment {
    __weak UIWindow *_previousKeyWindow;
    BOOL _textInputActive;
}

- (NSString *)environmentName {
    return @"SpringBoard";
}

- (BOOL)isPreview {
    return NO;
}

static UIWindowScene *HCGMainWindowScene(void) {
    UIApplication *app = [UIApplication sharedApplication];
    if (![app respondsToSelector:@selector(connectedScenes)]) return nil;
    UIWindowScene *fallback = nil;
    for (UIScene *scene in app.connectedScenes) {
        if (![scene isKindOfClass:[UIWindowScene class]]) continue;
        UIWindowScene *windowScene = (UIWindowScene *)scene;
        if (windowScene.screen != [UIScreen mainScreen]) continue;
        if (windowScene.activationState == UISceneActivationStateForegroundActive) return windowScene;
        if (!fallback) fallback = windowScene;
    }
    return fallback;
}

- (void)overlayInstallContainerViewController:(UIViewController *)containerViewController {
    if (_window) return; // exactly one overlay window, ever
    UIWindowScene *scene = HCGMainWindowScene();
    HCGOverlayWindow *window = scene ? [[HCGOverlayWindow alloc] initWithWindowScene:scene]
                                     : [[HCGOverlayWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    window.frame = [UIScreen mainScreen].bounds;
    window.windowLevel = HCGOverlayWindowLevel;
    window.backgroundColor = [UIColor clearColor];
    window.opaque = NO;
    window.hidden = YES;
    window.accessibilityViewIsModal = NO;
    window.rootViewController = containerViewController;
    _window = window;
}

- (void)overlaySetContainerVisible:(BOOL)visible {
    if (!_window) return;
    if (!visible) {
        [self overlayTextInputActive:NO];
        _window.userInteractionEnabled = NO;
        _window.hidden = YES;
    } else {
        _window.userInteractionEnabled = YES;
        _window.hidden = NO; // shown without becoming key
    }
}

- (BOOL)overlayUsesManualRotation {
    return YES;
}

- (HCGInterfaceOrientation)overlayInterfaceOrientation {
    id app = [UIApplication sharedApplication];
    long long raw = 0;
    if ([app respondsToSelector:@selector(activeInterfaceOrientation)]) {
        raw = [app activeInterfaceOrientation];
    } else if ([app respondsToSelector:@selector(_frontMostAppOrientation)]) {
        raw = [app _frontMostAppOrientation];
    }
    switch (raw) {
        case UIInterfaceOrientationLandscapeLeft: return HCGInterfaceOrientationLandscapeLeft;
        case UIInterfaceOrientationLandscapeRight: return HCGInterfaceOrientationLandscapeRight;
        case UIInterfaceOrientationPortraitUpsideDown: return HCGInterfaceOrientationPortraitUpsideDown;
        default: return HCGInterfaceOrientationPortrait;
    }
}

- (NSString *)orientationSourceSummary {
    id app = [UIApplication sharedApplication];
    if ([app respondsToSelector:@selector(activeInterfaceOrientation)]) return @"activeInterfaceOrientation";
    if ([app respondsToSelector:@selector(_frontMostAppOrientation)]) return @"_frontMostAppOrientation";
    return @"unavailable (portrait only)";
}

- (void)overlayTextInputActive:(BOOL)active {
    if (!_window || active == _textInputActive) return;
    _textInputActive = active;
    if (active) {
        for (UIWindow *candidate in _window.windowScene.windows ?: @[]) {
            if (candidate.isKeyWindow && candidate != _window) _previousKeyWindow = candidate;
        }
        [_window makeKeyWindow];
    } else if (_window.isKeyWindow) {
        [_window resignKeyWindow];
        UIWindow *previous = _previousKeyWindow;
        if (previous && !previous.hidden) [previous makeKeyWindow];
        _previousKeyWindow = nil;
    }
}

- (NSUInteger)overlayWindowCount {
    NSUInteger count = 0;
    NSMutableSet *seen = [NSMutableSet set];
    for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if (![scene isKindOfClass:[UIWindowScene class]]) continue;
        for (UIWindow *window in ((UIWindowScene *)scene).windows) {
            if ([window isKindOfClass:[HCGOverlayWindow class]] && ![seen containsObject:[NSValue valueWithNonretainedObject:window]]) {
                [seen addObject:[NSValue valueWithNonretainedObject:window]];
                count++;
            }
        }
    }
    if (count == 0 && _window) count = 1; // scene-less window
    return count;
}

@end
