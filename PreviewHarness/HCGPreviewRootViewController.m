#import "HCGPreviewRootViewController.h"
#import "HCGCore.h"
#import "HCGNexusModel.h"
#import "HCGOverlayController.h"
#import "HCGPreviewPlatform.h"
#import "HCGPreviewSelfCheck.h"
#import "HCGTheme.h"

@implementation HCGPreviewRootViewController {
    HCGUserDefaultsKeyValueStore *_store;
    HCGPreviewLauncher *_launcher;
    HCGNexusModel *_model;
    HCGPreviewEnvironment *_environment;
    HCGOverlayController *_overlay;
    UISwitch *_enabledSwitch;
    UISwitch *_lockSwitch;
    UISwitch *_coverSwitch;
    UIButton *_passThroughButton;
    NSUInteger _passThroughTaps;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    [self buildMockApp];

    _store = [[HCGUserDefaultsKeyValueStore alloc] initWithSuiteName:@"com.hakmicapitalgroup.hcgnexus.preview"];
    _launcher = [[HCGPreviewLauncher alloc] init];
    _model = [[HCGNexusModel alloc] initWithStore:_store notifier:nil launcher:_launcher];
    _environment = [[HCGPreviewEnvironment alloc] initWithHostViewController:self];
    _overlay = [[HCGOverlayController alloc] initWithModel:_model environment:_environment];
    [self applySimulatedSignals];
    [_overlay applyModelSettings];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(modelChanged) name:HCGNexusModelDidChangeNotification object:_model];
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    [coordinator animateAlongsideTransition:nil completion:^(id<UIViewControllerTransitionCoordinatorContext> context) {
        [self->_overlay interfaceOrientationMayHaveChanged];
    }];
}

- (void)modelChanged {
    _enabledSwitch.on = _model.settings.enabled;
}

#pragma mark Mock app

- (UILabel *)label:(NSString *)text style:(UIFontTextStyle)style color:(UIColor *)color {
    UILabel *label = [[UILabel alloc] init];
    label.text = text;
    label.numberOfLines = 0;
    label.font = [UIFont preferredFontForTextStyle:style];
    label.adjustsFontForContentSizeCategory = YES;
    label.textColor = color;
    return label;
}

- (UIStackView *)switchRow:(NSString *)title control:(UISwitch *__strong *)control action:(SEL)action {
    UISwitch *toggle = [[UISwitch alloc] init];
    toggle.accessibilityLabel = title;
    [toggle addTarget:self action:action forControlEvents:UIControlEventValueChanged];
    *control = toggle;
    UIStackView *row = [[UIStackView alloc] initWithArrangedSubviews:@[ [self label:title style:UIFontTextStyleSubheadline color:[UIColor labelColor]], toggle ]];
    row.alignment = UIStackViewAlignmentCenter;
    return row;
}

- (void)buildMockApp {
    UILabel *banner = [self label:@"PREVIEW HARNESS · UI only · not injected into SpringBoard. Passing here does not verify the tweak on a device."
                            style:UIFontTextStyleFootnote color:[UIColor blackColor]];
    banner.backgroundColor = [HCGTheme warning];
    banner.textAlignment = NSTextAlignmentCenter;
    banner.accessibilityTraits = UIAccessibilityTraitHeader;

    UILabel *title = [self label:@"Mock current app" style:UIFontTextStyleLargeTitle color:[UIColor labelColor]];
    UILabel *body = [self label:@"The HCG Nexus handle sits on the screen edge above this content. With the panel closed, taps here must reach this app."
                          style:UIFontTextStyleBody color:[UIColor secondaryLabelColor]];
    _passThroughButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [_passThroughButton setTitle:@"Pass-through tap test: 0" forState:UIControlStateNormal];
    _passThroughButton.titleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
    [_passThroughButton addTarget:self action:@selector(passThroughTapped) forControlEvents:UIControlEventTouchUpInside];

    UITextField *field = [[UITextField alloc] init];
    field.borderStyle = UITextBorderStyleRoundedRect;
    field.placeholder = @"Mock app text field (keyboard test)";

    UIStackView *enabledRow = [self switchRow:@"HCG Nexus enabled" control:&_enabledSwitch action:@selector(enabledChanged)];
    UIStackView *lockRow = [self switchRow:@"Simulate device locked" control:&_lockSwitch action:@selector(applySimulatedSignals)];
    UIStackView *coverRow = [self switchRow:@"Simulate cover sheet visible" control:&_coverSwitch action:@selector(applySimulatedSignals)];

    UIButton *check = [UIButton buttonWithType:UIButtonTypeSystem];
    [check setTitle:@"Run preview self-check" forState:UIControlStateNormal];
    [check addTarget:self action:@selector(runSelfCheck) forControlEvents:UIControlEventTouchUpInside];
    UIButton *reset = [UIButton buttonWithType:UIButtonTypeSystem];
    [reset setTitle:@"Reset preview data" forState:UIControlStateNormal];
    [reset setTitleColor:[UIColor systemRedColor] forState:UIControlStateNormal];
    [reset addTarget:self action:@selector(resetPreviewData) forControlEvents:UIControlEventTouchUpInside];

    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[ banner, title, body, _passThroughButton, field, enabledRow, lockRow, coverRow, check, reset ]];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 14;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    UIScrollView *scroll = [[UIScrollView alloc] init];
    scroll.translatesAutoresizingMaskIntoConstraints = NO;
    scroll.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    [scroll addSubview:stack];
    [self.view addSubview:scroll];
    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [scroll.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [scroll.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [scroll.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [scroll.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [stack.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:24],
        [stack.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-24],
        [stack.topAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.topAnchor constant:16],
        [stack.bottomAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.bottomAnchor constant:-16],
    ]];
}

- (void)passThroughTapped {
    _passThroughTaps += 1;
    [_passThroughButton setTitle:[NSString stringWithFormat:@"Pass-through tap test: %lu", (unsigned long)_passThroughTaps] forState:UIControlStateNormal];
}

#pragma mark Controls

- (void)enabledChanged {
    HCGSettings *settings = _model.settings;
    settings.enabled = _enabledSwitch.on;
    [_model saveSettings:settings];
}

- (void)applySimulatedSignals {
    HCGSystemSignals signals;
    signals.deviceLocked = _lockSwitch.on ? HCGTriStateYes : HCGTriStateNo;
    signals.coverSheetVisible = _coverSwitch.on ? HCGTriStateYes : HCGTriStateNo;
    signals.screenBlanked = HCGTriStateNo;
    [_overlay updateSystemSignals:signals];
}

- (void)runSelfCheck {
    BOOL passed = NO;
    NSString *report = [HCGPreviewSelfCheck runInHostViewController:self passed:&passed];
    UIViewController *sheet = [[UIViewController alloc] init];
    UITextView *text = [[UITextView alloc] init];
    text.editable = NO;
    text.font = [UIFont monospacedSystemFontOfSize:13 weight:UIFontWeightRegular];
    text.text = report;
    sheet.view = text;
    sheet.title = passed ? @"Preview self-check passed" : @"Preview self-check FAILED";
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:sheet];
    sheet.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(dismissSheet)];
    [self presentViewController:nav animated:YES completion:nil];
}

- (void)dismissSheet {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)resetPreviewData {
    [_store removeAllValues];
    [_model reload];
    [_overlay applyModelSettings];
}

@end
