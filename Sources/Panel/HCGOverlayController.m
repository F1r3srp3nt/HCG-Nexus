#import "HCGOverlayController.h"
#import "HCGEdgeHandleView.h"
#import "HCGTheme.h"
#import "HCGPanelContext.h"
#import "HCGActionRunner.h"
#import "HCGPanelHomeViewController.h"

#pragma mark - Pass-through views

// Returns nil for touches that land on itself so they reach whatever is below
// (the frontmost app). Only real subviews (handle, dimming, panel) capture.
@interface HCGPassthroughView : UIView
@end

@implementation HCGPassthroughView
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hit = [super hitTest:point withEvent:event];
    return hit == self ? nil : hit;
}
@end

@interface HCGOverlayContainerViewController : UIViewController
@property (nonatomic, copy) void (^layoutHandler)(void);
@property (nonatomic) BOOL allowsAutorotation;
@end

@implementation HCGOverlayContainerViewController
- (void)loadView {
    HCGPassthroughView *view = [[HCGPassthroughView alloc] init];
    view.backgroundColor = [UIColor clearColor];
    self.view = view;
}
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    if (self.layoutHandler) self.layoutHandler();
}
- (void)viewSafeAreaInsetsDidChange {
    [super viewSafeAreaInsetsDidChange];
    if (self.layoutHandler) self.layoutHandler();
}
- (BOOL)shouldAutorotate {
    return self.allowsAutorotation;
}
- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return self.allowsAutorotation ? UIInterfaceOrientationMaskAll : UIInterfaceOrientationMaskPortrait;
}
@end

// Hosts the panel; supports the VoiceOver escape (two-finger Z) gesture.
@interface HCGPanelHostView : UIView
@property (nonatomic, copy) void (^escapeHandler)(void);
@end

@implementation HCGPanelHostView
- (BOOL)accessibilityPerformEscape {
    if (self.escapeHandler) self.escapeHandler();
    return YES;
}
@end

@interface HCGAccessibleHandleView : HCGEdgeHandleView
@property (nonatomic, copy) void (^activationHandler)(void);
@end

@implementation HCGAccessibleHandleView
- (BOOL)accessibilityActivate {
    if (self.activationHandler) self.activationHandler();
    return YES;
}
@end

#pragma mark - Controller

@implementation HCGOverlayController {
    __weak id<HCGOverlayEnvironment> _environment;
    HCGOverlayContainerViewController *_container;
    HCGPassthroughView *_canvas;
    UIView *_dimming;
    HCGAccessibleHandleView *_handle;
    HCGPanelHostView *_panelHost;
    UIView *_panelBackground;
    UINavigationController *_navigation;
    HCGPanelHomeViewController *_home;
    HCGPanelContext *_context;
    HCGActionRunner *_runner;
    HCGSettings *_appliedSettings;
    CGFloat _keyboardOverlap;
    BOOL _panExceededThreshold;
    UIImpactFeedbackGenerator *_haptics;
    NSUInteger _layoutPasses;
}

- (instancetype)initWithModel:(HCGNexusModel *)model environment:(id<HCGOverlayEnvironment>)environment {
    if ((self = [super init])) {
        _model = model;
        _environment = environment;
        _coordinator = [[HCGOverlayCoordinator alloc] initWithHost:self];
        _coordinator.reduceMotion = UIAccessibilityIsReduceMotionEnabled();
        _appliedSettings = [HCGSettings defaultSettings];
        _runner = [[HCGActionRunner alloc] initWithModel:model];

        NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
        [nc addObserver:self selector:@selector(modelDidChange:) name:HCGNexusModelDidChangeNotification object:model];
        [nc addObserver:self selector:@selector(accessibilityChanged:) name:UIAccessibilityReduceMotionStatusDidChangeNotification object:nil];
        [nc addObserver:self selector:@selector(accessibilityChanged:) name:UIAccessibilityReduceTransparencyStatusDidChangeNotification object:nil];
        [nc addObserver:self selector:@selector(accessibilityChanged:) name:UIAccessibilityDarkerSystemColorsStatusDidChangeNotification object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark Public

- (void)applyModelSettings {
    [_coordinator updateSettings:_model.settings];
}

- (void)updateSystemSignals:(HCGSystemSignals)signals {
    [_coordinator updateSignals:signals];
}

- (void)interfaceOrientationMayHaveChanged {
    if (_coordinator.installed) [self layoutOverlay];
}

- (void)modelDidChange:(NSNotification *)note {
    [self applyModelSettings];
    if (_coordinator.stateMachine.isPresented) [_home reloadContent];
}

- (void)accessibilityChanged:(NSNotification *)note {
    _coordinator.reduceMotion = UIAccessibilityIsReduceMotionEnabled();
    if (!_coordinator.installed) return;
    [self rebuildPanelBackground];
    _handle.illumination = _appliedSettings.handleOpacity;
}

- (NSUInteger)installedGestureRecognizerCount {
    return _handle.gestureRecognizers.count + _dimming.gestureRecognizers.count;
}

- (BOOL)isPanelOnScreen {
    return _panelHost != nil && !_panelHost.hidden && _container.view.window != nil && !_container.view.hidden;
}

- (BOOL)isHandleOnScreen {
    return _handle != nil && !_handle.hidden && _container.view.window != nil && !_container.view.hidden;
}

- (void)simulateHandleActivation {
    [self handleActivated];
}

- (void)simulateOutsideTap {
    [_coordinator requestClose];
}

- (NSDictionary *)diagnostics {
    NSMutableDictionary *d = [[_coordinator diagnostics] mutableCopy];
    id<HCGOverlayEnvironment> env = _environment;
    d[@"environment"] = env.environmentName ?: @"unknown";
    d[@"overlayWindows"] = @([env overlayWindowCount]);
    d[@"gestureRecognizers"] = @([self installedGestureRecognizerCount]);
    d[@"orientation"] = @([env overlayInterfaceOrientation]);
    d[@"manualRotation"] = @([env overlayUsesManualRotation]);
    d[@"layoutPasses"] = @(_layoutPasses);
    d[@"launcher"] = _model.launcher.launcherName ?: @"none";
    d[@"launcherCapabilities"] = [_model.launcher capabilitySummary] ?: @"none";
    d[@"droppedEntriesOnLoad"] = @(_model.workspaceStore.droppedEntriesOnLoad);
    return d;
}

#pragma mark HCGOverlayHost

- (void)overlayInstall {
    id<HCGOverlayEnvironment> env = _environment;
    _container = [[HCGOverlayContainerViewController alloc] init];
    _container.allowsAutorotation = ![env overlayUsesManualRotation];
    __weak typeof(self) weakSelf = self;
    _container.layoutHandler = ^{ [weakSelf layoutOverlay]; };
    [_container loadViewIfNeeded];

    _canvas = [[HCGPassthroughView alloc] init];
    _canvas.backgroundColor = [UIColor clearColor];
    [_container.view addSubview:_canvas];

    _dimming = [[UIView alloc] init];
    _dimming.backgroundColor = [UIColor colorWithWhite:0 alpha:0.42];
    _dimming.hidden = YES;
    _dimming.alpha = 0;
    _dimming.isAccessibilityElement = NO;
    UITapGestureRecognizer *outside = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(outsideTapped:)];
    [_dimming addGestureRecognizer:outside];
    [_canvas addSubview:_dimming];

    _handle = [[HCGAccessibleHandleView alloc] init];
    _handle.activationHandler = ^{ [weakSelf handleActivated]; };
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTapped:)];
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePanned:)];
    pan.maximumNumberOfTouches = 1;
    [_handle addGestureRecognizer:tap];
    [_handle addGestureRecognizer:pan];
    [_canvas addSubview:_handle];

    _panelHost = [[HCGPanelHostView alloc] init];
    _panelHost.hidden = YES;
    _panelHost.accessibilityViewIsModal = YES;
    _panelHost.escapeHandler = ^{ [weakSelf.coordinator requestClose]; };
    _panelHost.layer.shadowColor = [UIColor blackColor].CGColor;
    _panelHost.layer.shadowOpacity = 0.55;
    _panelHost.layer.shadowRadius = 30;
    _panelHost.layer.shadowOffset = CGSizeMake(0, 12);
    [_canvas addSubview:_panelHost];
    [self rebuildPanelBackground];

    _context = [[HCGPanelContext alloc] init];
    _context.model = _model;
    _context.runner = _runner;
    _context.environmentName = env.environmentName;
    _context.isPreview = env.isPreview;
    _context.closePanel = ^{ [weakSelf.coordinator requestClose]; };
    _context.closePanelImmediately = ^{ [weakSelf.coordinator requestCloseImmediately]; };
    _context.diagnosticsProvider = ^NSDictionary *{ return [weakSelf diagnostics] ?: @{}; };

    _home = [[HCGPanelHomeViewController alloc] initWithContext:_context];
    _navigation = [[UINavigationController alloc] initWithRootViewController:_home];
    _navigation.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    _navigation.view.backgroundColor = [UIColor clearColor];
    _navigation.navigationBar.tintColor = [HCGTheme cyan];
    _navigation.navigationBar.titleTextAttributes = @{ NSForegroundColorAttributeName : [HCGTheme primaryText] };
    UINavigationBarAppearance *appearance = [[UINavigationBarAppearance alloc] init];
    [appearance configureWithTransparentBackground];
    appearance.titleTextAttributes = @{ NSForegroundColorAttributeName : [HCGTheme primaryText] };
    _navigation.navigationBar.standardAppearance = appearance;
    _navigation.navigationBar.scrollEdgeAppearance = appearance;
    _navigation.navigationBar.compactAppearance = appearance;
    [_container addChildViewController:_navigation];
    _navigation.view.layer.cornerRadius = 22;
    _navigation.view.layer.cornerCurve = kCACornerCurveContinuous;
    _navigation.view.clipsToBounds = YES;
    [_panelHost addSubview:_navigation.view];
    [_navigation didMoveToParentViewController:_container];

    _haptics = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];

    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self selector:@selector(keyboardWillChange:) name:UIKeyboardWillChangeFrameNotification object:nil];
    [nc addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
    [nc addObserver:self selector:@selector(textEditingBegan:) name:UITextFieldTextDidBeginEditingNotification object:nil];

    [env overlayInstallContainerViewController:_container];
    [self layoutOverlay];
}

- (void)overlaySetVisible:(BOOL)visible {
    [_environment overlaySetContainerVisible:visible];
    _handle.hidden = !visible;
    _handle.accessibilityElementsHidden = !visible;
    if (!visible) {
        _handle.highlighted = NO;
        [self endTextInput];
    } else {
        [self layoutOverlay];
    }
}

- (void)overlayApplySettings:(HCGSettings *)settings {
    _appliedSettings = [settings copy];
    _handle.illumination = settings.handleOpacity;
    _handle.onLeftEdge = settings.handleSide == HCGHandleSideLeft;
    [self layoutOverlay];
}

- (void)overlayBeginPanelTransition:(HCGPanelCommand)command generation:(NSUInteger)generation animated:(BOOL)animated {
    BOOL opening = command == HCGPanelCommandBeginOpen;
    BOOL crossfade = !animated && _appliedSettings.animationsEnabled && _coordinator.reduceMotion;
    NSTimeInterval duration = animated ? 0.34 : (crossfade ? 0.18 : 0.0);
    CGFloat direction = _appliedSettings.handleSide == HCGHandleSideLeft ? -1.0 : 1.0;
    CGAffineTransform offscreen = animated
        ? CGAffineTransformScale(CGAffineTransformMakeTranslation(direction * 48.0, 0), 0.97, 0.97)
        : CGAffineTransformIdentity;
    __weak typeof(self) weakSelf = self;

    if (opening) {
        [_home reloadContent];
        [self layoutOverlay];
        _dimming.hidden = NO;
        _panelHost.hidden = NO;
        _panelHost.transform = offscreen;
        _panelHost.alpha = duration > 0 ? 0 : 1;
        _dimming.alpha = duration > 0 ? 0 : 1;
        if (_appliedSettings.hapticsEnabled) [_haptics impactOccurred];
        void (^changes)(void) = ^{
            self->_panelHost.transform = CGAffineTransformIdentity;
            self->_panelHost.alpha = 1;
            self->_dimming.alpha = 1;
        };
        void (^done)(BOOL) = ^(BOOL finished) {
            UIAccessibilityPostNotification(UIAccessibilityScreenChangedNotification, [weakSelf panelAccessibilityFocus]);
            [weakSelf.coordinator panelTransitionFinished:generation];
        };
        if (duration > 0) {
            [UIView animateWithDuration:duration delay:0 usingSpringWithDamping:(animated ? 0.86 : 1.0) initialSpringVelocity:0
                                options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                             animations:changes completion:done];
        } else {
            changes();
            done(YES);
        }
        return;
    }

    [self endTextInput];
    void (^changes)(void) = ^{
        self->_panelHost.transform = offscreen;
        self->_panelHost.alpha = 0;
        self->_dimming.alpha = 0;
    };
    void (^done)(BOOL) = ^(BOOL finished) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        if (generation == strongSelf->_coordinator.stateMachine.generation) [strongSelf finishClosing];
        [strongSelf.coordinator panelTransitionFinished:generation];
    };
    if (duration > 0) {
        [UIView animateWithDuration:duration delay:0 options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveEaseIn
                         animations:changes completion:done];
    } else {
        changes();
        done(YES);
    }
}

- (void)overlayForceHidePanel {
    [_panelHost.layer removeAllAnimations];
    [_dimming.layer removeAllAnimations];
    [self endTextInput];
    [self finishClosing];
}

- (void)finishClosing {
    if (_navigation.presentedViewController) [_navigation dismissViewControllerAnimated:NO completion:nil];
    _panelHost.hidden = YES;
    _panelHost.alpha = 0;
    _panelHost.transform = CGAffineTransformIdentity;
    _dimming.hidden = YES;
    _dimming.alpha = 0;
    [_navigation popToRootViewControllerAnimated:NO];
    [_home resetTransientState];
    if (!_handle.hidden) UIAccessibilityPostNotification(UIAccessibilityScreenChangedNotification, _handle);
}

- (id)panelAccessibilityFocus {
    return [_home accessibilityFocusElement] ?: _panelHost;
}

#pragma mark Gestures

- (void)handleActivated {
    if (self.beforeActivation) self.beforeActivation();
    [_coordinator handleActivated];
}

- (void)handleTapped:(UITapGestureRecognizer *)recognizer {
    if (recognizer.state == UIGestureRecognizerStateEnded) [self handleActivated];
}

- (void)handlePanned:(UIPanGestureRecognizer *)recognizer {
    CGPoint translation = [recognizer translationInView:_canvas];
    CGFloat inward = _appliedSettings.handleSide == HCGHandleSideLeft ? translation.x : -translation.x;
    switch (recognizer.state) {
        case UIGestureRecognizerStateBegan:
            _panExceededThreshold = NO;
            _handle.highlighted = YES;
            break;
        case UIGestureRecognizerStateChanged:
            if (!_panExceededThreshold && inward > 28.0) {
                _panExceededThreshold = YES;
                if (!_coordinator.stateMachine.isPresented) [self handleActivated];
            }
            break;
        default:
            _handle.highlighted = NO;
            break;
    }
}

- (void)outsideTapped:(UITapGestureRecognizer *)recognizer {
    if (recognizer.state == UIGestureRecognizerStateEnded) [_coordinator requestClose];
}

#pragma mark Layout

- (void)rebuildPanelBackground {
    [_panelBackground removeFromSuperview];
    _panelBackground = [HCGTheme makePanelBackgroundWithCornerRadius:22];
    _panelBackground.frame = _panelHost.bounds;
    _panelBackground.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [_panelHost insertSubview:_panelBackground atIndex:0];
}

- (void)layoutOverlay {
    if (!_container.isViewLoaded || !_canvas) return;
    id<HCGOverlayEnvironment> env = _environment;
    _layoutPasses += 1;
    UIView *root = _container.view;
    CGRect bounds = root.bounds;
    if (CGRectIsEmpty(bounds)) return;

    HCGInterfaceOrientation orientation = [env overlayInterfaceOrientation];
    BOOL containerIsLandscape = bounds.size.width > bounds.size.height;
    BOOL wantsLandscape = HCGOrientationIsLandscape(orientation);
    BOOL rotate = [env overlayUsesManualRotation] &&
                  (wantsLandscape != containerIsLandscape || orientation == HCGInterfaceOrientationPortraitUpsideDown);

    UIEdgeInsets raw = root.safeAreaInsets;
    HCGInsets insets = { raw.top, raw.left, raw.bottom, raw.right };
    double width = bounds.size.width, height = bounds.size.height;
    double angle = 0;
    if (rotate) {
        HCGCanvasSizeForOrientation(bounds.size.width, bounds.size.height, orientation, &width, &height);
        insets = HCGSafeAreaForOrientation(insets, orientation);
        angle = HCGRotationForOrientation(orientation);
    }

    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    _canvas.transform = CGAffineTransformIdentity;
    _canvas.bounds = CGRectMake(0, 0, width, height);
    _canvas.center = CGPointMake(CGRectGetMidX(bounds), CGRectGetMidY(bounds));
    _canvas.transform = CGAffineTransformMakeRotation(angle);
    _dimming.frame = _canvas.bounds;

    HCGHandleLayoutInput input;
    input.canvasWidth = width;
    input.canvasHeight = height;
    input.safeArea = insets;
    input.side = _appliedSettings.handleSide;
    input.position = _appliedSettings.handlePosition;
    input.keyboardSafeZone = _appliedSettings.keyboardSafeZone;
    input.landscape = width > height;
    HCGHandleFrames frames = HCGComputeHandleFrames(input);
    _handle.frame = CGRectMake(frames.hit.x, frames.hit.y, frames.hit.width, frames.hit.height);
    _handle.visualFrame = CGRectMake(frames.visual.x - frames.hit.x, frames.visual.y - frames.hit.y, frames.visual.width, frames.visual.height);

    if (!_coordinator.stateMachine.isPresented || _panelHost.hidden || CGAffineTransformIsIdentity(_panelHost.transform)) {
        CGAffineTransform saved = _panelHost.transform;
        _panelHost.transform = CGAffineTransformIdentity;
        HCGRect panel = HCGComputePanelFrame(width, height, insets, _appliedSettings.handleSide, _keyboardOverlap);
        _panelHost.frame = CGRectMake(panel.x, panel.y, panel.width, panel.height);
        _panelHost.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:_panelHost.bounds cornerRadius:22].CGPath;
        _navigation.view.frame = _panelHost.bounds;
        _panelBackground.frame = _panelHost.bounds;
        _panelHost.transform = saved;
    }
    [CATransaction commit];
}

#pragma mark Keyboard & text input

- (void)textEditingBegan:(NSNotification *)note {
    UIView *field = note.object;
    if ([field isKindOfClass:[UIView class]] && [field isDescendantOfView:_panelHost]) {
        [_environment overlayTextInputActive:YES];
    }
}

- (void)endTextInput {
    if ([_panelHost endEditing:YES] || _keyboardOverlap > 0) {
        _keyboardOverlap = 0;
    }
    [_environment overlayTextInputActive:NO];
}

- (void)keyboardWillChange:(NSNotification *)note {
    if (!_canvas || _panelHost.hidden) return;
    CGRect end = [note.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGRect inCanvas = [_canvas convertRect:end fromCoordinateSpace:[UIScreen mainScreen].coordinateSpace];
    CGFloat overlap = 0;
    if (CGRectIntersectsRect(inCanvas, _canvas.bounds)) {
        overlap = MAX(0, CGRectGetMaxY(_canvas.bounds) - CGRectGetMinY(inCanvas));
    }
    [self setKeyboardOverlap:overlap notification:note];
}

- (void)keyboardWillHide:(NSNotification *)note {
    if (!_canvas) return;
    [self setKeyboardOverlap:0 notification:note];
}

- (void)setKeyboardOverlap:(CGFloat)overlap notification:(NSNotification *)note {
    if (fabs(overlap - _keyboardOverlap) < 0.5) return;
    _keyboardOverlap = overlap;
    NSTimeInterval duration = [note.userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    if (_coordinator.reduceMotion) duration = 0;
    [UIView animateWithDuration:duration animations:^{ [self layoutOverlay]; }];
}

@end
