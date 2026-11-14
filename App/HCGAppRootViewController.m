#import "HCGAppRootViewController.h"
#import "HCGActionRunner.h"
#import "HCGPanelHomeViewController.h"
#import "HCGAppPlatform.h"
#import "HCGTheme.h"
#import "HCGConnectedDevicesViewController.h"

@implementation HCGAppRootViewController {
    HCGNexusModel *_model;
    UINavigationController *_navigation;
    UIView *_panelBackground;
    UIView *_panel;
}

- (instancetype)initWithModel:(HCGNexusModel *)model {
    if ((self = [super initWithNibName:nil bundle:nil])) {
        _model = model;
        _context = [[HCGPanelContext alloc] init];
        _context.mode = HCGPanelModeStandaloneApp;
        _context.model = model;
        _context.runner = [[HCGActionRunner alloc] initWithModel:model];
        _context.environmentName = @"HCG Nexus app (sandboxed)";
        _context.isPreview = NO;
        __weak typeof(self) weakSelf = self;
        _context.diagnosticsProvider = ^NSDictionary *{
            return [weakSelf diagnostics] ?: @{};
        };
        // HCG Device Link (standalone app only). The service is created when the
        // screen is first opened, never at launch.
        _context.connectedDevicesScreen = ^UIViewController *(HCGPanelContext *context) {
            return [[HCGConnectedDevicesViewController alloc] initWithContext:context service:HCGSharedLinkService()];
        };
    }
    return self;
}

- (NSDictionary *)diagnostics {
    id<HCGLauncher> launcher = _model.launcher;
    NSMutableDictionary *d = [NSMutableDictionary dictionary];
    d[@"launcher"] = launcher.launcherName ?: @"none";
    d[@"launcherCapabilities"] = [launcher capabilitySummary] ?: @"none";
    d[@"droppedEntriesOnLoad"] = @(_model.workspaceStore.droppedEntriesOnLoad);
    id<HCGKeyValueStore> store = _model.store;
    if ([store isKindOfClass:[HCGAppDefaultsStore class]]) {
        d[@"dataStore"] = [NSString stringWithFormat:@"app sandbox · %@", ((HCGAppDefaultsStore *)store).suiteName];
    }
    return d;
}

- (UIStatusBarStyle)preferredStatusBarStyle {
    return UIStatusBarStyleLightContent;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    self.view.backgroundColor = [HCGTheme obsidian];

    // Faint cyan illumination behind the panel.
    CAGradientLayer *glow = [CAGradientLayer layer];
    glow.type = kCAGradientLayerRadial;
    glow.colors = @[ (id)[[HCGTheme cyan] colorWithAlphaComponent:0.12].CGColor, (id)[UIColor clearColor].CGColor ];
    glow.startPoint = CGPointMake(0.5, 0.0);
    glow.endPoint = CGPointMake(1.1, 0.9);
    glow.frame = CGRectMake(0, 0, 4000, 4000);
    [self.view.layer addSublayer:glow];

    _panel = [[UIView alloc] init];
    _panel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:_panel];
    [self rebuildPanelBackground];

    HCGPanelHomeViewController *home = [[HCGPanelHomeViewController alloc] initWithContext:_context];
    _navigation = [[UINavigationController alloc] initWithRootViewController:home];
    _navigation.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    _navigation.view.backgroundColor = [UIColor clearColor];
    _navigation.navigationBar.tintColor = [HCGTheme cyan];
    UINavigationBarAppearance *appearance = [[UINavigationBarAppearance alloc] init];
    [appearance configureWithTransparentBackground];
    appearance.titleTextAttributes = @{ NSForegroundColorAttributeName : [HCGTheme primaryText] };
    _navigation.navigationBar.standardAppearance = appearance;
    _navigation.navigationBar.scrollEdgeAppearance = appearance;
    _navigation.navigationBar.compactAppearance = appearance;
    [self addChildViewController:_navigation];
    _navigation.view.translatesAutoresizingMaskIntoConstraints = NO;
    _navigation.view.layer.cornerRadius = 22;
    _navigation.view.layer.cornerCurve = kCACornerCurveContinuous;
    _navigation.view.clipsToBounds = YES;
    [_panel addSubview:_navigation.view];
    [_navigation didMoveToParentViewController:self];

    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    NSLayoutConstraint *preferredWidth = [_panel.widthAnchor constraintEqualToConstant:720];
    preferredWidth.priority = UILayoutPriorityDefaultHigh;
    [NSLayoutConstraint activateConstraints:@[
        [_panel.centerXAnchor constraintEqualToAnchor:safe.centerXAnchor],
        [_panel.leadingAnchor constraintGreaterThanOrEqualToAnchor:safe.leadingAnchor constant:10],
        [_panel.trailingAnchor constraintLessThanOrEqualToAnchor:safe.trailingAnchor constant:-10],
        preferredWidth,
        [_panel.topAnchor constraintEqualToAnchor:safe.topAnchor constant:8],
        [_panel.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor constant:-8],
        [_navigation.view.leadingAnchor constraintEqualToAnchor:_panel.leadingAnchor],
        [_navigation.view.trailingAnchor constraintEqualToAnchor:_panel.trailingAnchor],
        [_navigation.view.topAnchor constraintEqualToAnchor:_panel.topAnchor],
        [_navigation.view.bottomAnchor constraintEqualToAnchor:_panel.bottomAnchor],
    ]];

    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self selector:@selector(modelDidChange) name:HCGNexusModelDidChangeNotification object:_model];
    [nc addObserver:self selector:@selector(accessibilityChanged) name:UIAccessibilityReduceTransparencyStatusDidChangeNotification object:nil];
    [nc addObserver:self selector:@selector(accessibilityChanged) name:UIAccessibilityDarkerSystemColorsStatusDidChangeNotification object:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)modelDidChange {
    UIViewController *root = _navigation.viewControllers.firstObject;
    if ([root isKindOfClass:[HCGPanelHomeViewController class]]) [(HCGPanelHomeViewController *)root reloadContent];
}

- (void)accessibilityChanged {
    [self rebuildPanelBackground];
}

- (void)rebuildPanelBackground {
    [_panelBackground removeFromSuperview];
    _panelBackground = [HCGTheme makePanelBackgroundWithCornerRadius:22];
    _panelBackground.frame = _panel.bounds;
    _panelBackground.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [_panel insertSubview:_panelBackground atIndex:0];
}

@end
