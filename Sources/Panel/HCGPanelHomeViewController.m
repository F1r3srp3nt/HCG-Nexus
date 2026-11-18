#import "HCGPanelHomeViewController.h"
#import "HCGTheme.h"
#import "HCGBranding.h"
#import "HCGSections.h"
#import "HCGOverviewViewController.h"
#import "HCGWorkspaceManagerViewController.h"
#import "HCGToolsViewController.h"
#import "HCGProductsViewController.h"
#import "HCGDevicesInfoViewController.h"
#import "HCGAppsViewController.h"
#import "HCGAccountViewController.h"

@implementation HCGPanelHomeViewController {
    HCGPanelContext *_context;
    UIView *_brand;
    UILabel *_badge;
    UIButton *_closeButton;
    UIScrollView *_barScroll;
    UIStackView *_bar;
    UIView *_content;
    UILabel *_toast;
    NSMutableDictionary<NSNumber *, UIViewController *> *_sections;
    UIViewController *_current;
    NSInteger _selected;
    NSUInteger _toastGeneration;
    BOOL _panelVisible;
}

@synthesize selectedSection = _selected;

- (instancetype)initWithContext:(HCGPanelContext *)context {
    if ((self = [super initWithNibName:nil bundle:nil])) {
        _context = context;
        _sections = [NSMutableDictionary dictionary];
        _selected = HCGNexusSectionOverview;
        __weak typeof(self) weakSelf = self;
        context.showFeedback = ^(NSString *message, BOOL success) { [weakSelf showToast:message success:success]; };
        context.showSection = ^(NSInteger section) { [weakSelf selectSection:section]; };
    }
    return self;
}

#pragma mark View

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor clearColor]; // the host draws the glass panel behind
    self.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    self.title = @"HCG Nexus";

    UIStackView *header = [self makeHeader];
    _barScroll = [self makeSectionBar];
    _content = [[UIView alloc] init];
    _content.clipsToBounds = YES;

    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[ header, _barScroll, _content ]];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 6;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:stack];

    _toast = [[UILabel alloc] init];
    _toast.numberOfLines = 0;
    _toast.textAlignment = NSTextAlignmentCenter;
    _toast.font = [HCGTheme fontForTextStyle:UIFontTextStyleFootnote weight:UIFontWeightSemibold];
    _toast.adjustsFontForContentSizeCategory = YES;
    _toast.textColor = [HCGTheme primaryText];
    _toast.layer.cornerRadius = 12;
    _toast.layer.cornerCurve = kCACornerCurveContinuous;
    _toast.layer.borderWidth = 1;
    _toast.clipsToBounds = YES;
    _toast.alpha = 0;
    _toast.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:_toast];

    UILayoutGuide *guide = self.view.layoutMarginsGuide;
    self.view.directionalLayoutMargins = NSDirectionalEdgeInsetsMake(12, 12, 10, 12);
    self.viewRespectsSystemMinimumLayoutMargins = NO;
    [NSLayoutConstraint activateConstraints:@[
        [stack.leadingAnchor constraintEqualToAnchor:guide.leadingAnchor],
        [stack.trailingAnchor constraintEqualToAnchor:guide.trailingAnchor],
        [stack.topAnchor constraintEqualToAnchor:guide.topAnchor],
        [stack.bottomAnchor constraintEqualToAnchor:guide.bottomAnchor],
        [_toast.leadingAnchor constraintEqualToAnchor:guide.leadingAnchor constant:8],
        [_toast.trailingAnchor constraintEqualToAnchor:guide.trailingAnchor constant:-8],
        [_toast.bottomAnchor constraintEqualToAnchor:guide.bottomAnchor constant:-8],
        [_toast.heightAnchor constraintGreaterThanOrEqualToConstant:40],
    ]];
    [self showSection:_selected];
}

- (UIStackView *)makeHeader {
    UIImage *logo = [HCGBranding hcgLogo];
    UIView *mark;
    if (logo) {
        // Official chrome HCG logo, sized to the header (no wasted space), then the product name.
        UIImageView *logoView = [[UIImageView alloc] initWithImage:logo];
        logoView.contentMode = UIViewContentModeScaleAspectFit;
        logoView.isAccessibilityElement = NO;
        CGFloat ratio = logo.size.height > 0 ? logo.size.width / logo.size.height : 2.2;
        [logoView.heightAnchor constraintEqualToConstant:30].active = YES;
        [logoView.widthAnchor constraintEqualToConstant:30 * ratio].active = YES;
        UILabel *nexus = [[UILabel alloc] init];
        nexus.attributedText = [[NSAttributedString alloc] initWithString:@"NEXUS" attributes:@{
            NSFontAttributeName : [UIFont systemFontOfSize:17 weight:UIFontWeightLight],
            NSForegroundColorAttributeName : [HCGTheme primaryText],
            NSKernAttributeName : @(4.0),
        }];
        nexus.isAccessibilityElement = NO;
        UIStackView *row = [[UIStackView alloc] initWithArrangedSubviews:@[ logoView, nexus ]];
        row.alignment = UIStackViewAlignmentCenter;
        row.spacing = 8;
        mark = row;
    } else {
        UILabel *wordmark = [[UILabel alloc] init];
        wordmark.attributedText = [HCGTheme wordmarkWithSize:20];
        wordmark.isAccessibilityElement = NO;
        mark = wordmark;
    }
    mark.isAccessibilityElement = YES;
    mark.accessibilityLabel = @"HCG Nexus";
    mark.accessibilityTraits = UIAccessibilityTraitHeader;
    _brand = mark;

    _badge = [[UILabel alloc] init];
    _badge.font = [UIFont monospacedSystemFontOfSize:10 weight:UIFontWeightBold];
    _badge.layer.cornerRadius = 5;
    _badge.clipsToBounds = YES;
    _badge.textColor = [HCGTheme obsidian];
    _badge.hidden = YES;
    if (_context.mode == HCGPanelModePreview) {
        _badge.text = @"  PREVIEW · NOT INJECTED  ";
        _badge.backgroundColor = [HCGTheme warning];
        _badge.accessibilityLabel = @"Preview harness. Not injected into SpringBoard.";
        _badge.hidden = NO;
    } else if (_context.mode == HCGPanelModeStandaloneApp) {
        _badge.text = @"  APP MODE  ";
        _badge.backgroundColor = [HCGTheme cyan];
        _badge.accessibilityLabel = @"Standalone app mode. The system-wide edge handle needs the jailbreak package.";
        _badge.hidden = NO;
    }
    [_badge setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];

    _closeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [_closeButton setImage:[HCGTheme symbolNamed:@"xmark" pointSize:14] forState:UIControlStateNormal];
    _closeButton.tintColor = [HCGTheme primaryText];
    [HCGTheme styleCard:_closeButton cornerRadius:22];
    _closeButton.accessibilityLabel = @"Close HCG Nexus";
    _closeButton.hidden = !_context.insideOverlay;
    [_closeButton addTarget:self action:@selector(closeTapped) forControlEvents:UIControlEventTouchUpInside];
    [_closeButton.widthAnchor constraintEqualToConstant:44].active = YES;
    [_closeButton.heightAnchor constraintEqualToConstant:44].active = YES;

    UIView *spacer = [[UIView alloc] init];
    [spacer setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    UIStackView *header = [[UIStackView alloc] initWithArrangedSubviews:@[ mark, spacer, _badge, _closeButton ]];
    header.alignment = UIStackViewAlignmentCenter;
    header.spacing = 8;
    [header.heightAnchor constraintGreaterThanOrEqualToConstant:44].active = YES;
    return header;
}

- (UIScrollView *)makeSectionBar {
    UIScrollView *scroll = [[UIScrollView alloc] init];
    scroll.showsHorizontalScrollIndicator = NO;
    _bar = [[UIStackView alloc] init];
    _bar.spacing = 4;
    _bar.translatesAutoresizingMaskIntoConstraints = NO;
    _bar.accessibilityContainerType = UIAccessibilityContainerTypeSemanticGroup;
    _bar.accessibilityLabel = @"Sections";
    [scroll addSubview:_bar];
    [NSLayoutConstraint activateConstraints:@[
        [_bar.leadingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.leadingAnchor],
        [_bar.trailingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.trailingAnchor],
        [_bar.topAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.topAnchor],
        [_bar.bottomAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.bottomAnchor],
        [_bar.heightAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.heightAnchor],
        [scroll.heightAnchor constraintEqualToConstant:52],
    ]];
    for (NSInteger section = 0; section < HCGNexusSectionCount; section++) {
        UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
        [button setTitle:HCGSectionTitle((HCGNexusSection)section) forState:UIControlStateNormal];
        [button setImage:[HCGTheme symbolNamed:HCGSectionSymbol((HCGNexusSection)section) pointSize:13] forState:UIControlStateNormal];
        button.titleLabel.font = [HCGTheme fontForTextStyle:UIFontTextStyleFootnote weight:UIFontWeightSemibold];
        button.titleLabel.adjustsFontForContentSizeCategory = YES;
        button.layer.cornerRadius = 12;
        button.layer.cornerCurve = kCACornerCurveContinuous;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        button.contentEdgeInsets = UIEdgeInsetsMake(8, 10, 8, 14);
        button.titleEdgeInsets = UIEdgeInsetsMake(0, 4, 0, -4);
#pragma clang diagnostic pop
        [button.heightAnchor constraintGreaterThanOrEqualToConstant:44].active = YES;
        button.tag = section;
        [button addTarget:self action:@selector(sectionTapped:) forControlEvents:UIControlEventTouchUpInside];
        [_bar addArrangedSubview:button];
    }
    return scroll;
}

- (void)styleSectionBar {
    for (UIButton *button in _bar.arrangedSubviews) {
        BOOL selected = button.tag == _selected;
        button.tintColor = selected ? [HCGTheme cyan] : [HCGTheme secondaryText];
        button.backgroundColor = selected ? [HCGTheme cyanSoft] : [UIColor clearColor];
        button.layer.borderWidth = selected ? 1 : 0;
        button.layer.borderColor = [HCGTheme cyan].CGColor;
        button.accessibilityTraits = UIAccessibilityTraitButton | (selected ? UIAccessibilityTraitSelected : 0);
        if (selected) [_barScroll scrollRectToVisible:CGRectInset(button.frame, -24, 0) animated:!UIAccessibilityIsReduceMotionEnabled()];
    }
}

#pragma mark Sections

- (UIViewController *)makeSection:(NSInteger)section {
    switch (section) {
        case HCGNexusSectionOverview: return [[HCGOverviewViewController alloc] initWithContext:_context];
        case HCGNexusSectionWorkspaces: return [[HCGWorkspaceManagerViewController alloc] initWithContext:_context];
        case HCGNexusSectionTools: return [[HCGToolsViewController alloc] initWithContext:_context];
        case HCGNexusSectionProducts: return [[HCGProductsViewController alloc] initWithContext:_context];
        case HCGNexusSectionDevices: {
            UIViewController *real = _context.connectedDevicesScreen ? _context.connectedDevicesScreen(_context) : nil;
            return real ?: [[HCGDevicesInfoViewController alloc] initWithContext:_context];
        }
        case HCGNexusSectionApps: return [[HCGAppsViewController alloc] initWithContext:_context];
        case HCGNexusSectionAccount: return [[HCGAccountViewController alloc] initWithContext:_context];
    }
    return [[HCGOverviewViewController alloc] initWithContext:_context];
}

- (void)sectionTapped:(UIButton *)button {
    [self selectSection:button.tag];
}

- (void)selectSection:(NSInteger)section {
    if (section < 0 || section >= HCGNexusSectionCount) return;
    if (self.navigationController.topViewController != self) [self.navigationController popToViewController:self animated:NO];
    _selected = section;
    if (self.isViewLoaded) [self showSection:section];
}

- (void)showSection:(NSInteger)section {
    UIViewController *next = _sections[@(section)];
    if (!next) {
        next = [self makeSection:section];
        _sections[@(section)] = next;
    }
    if (next != _current) {
        if ([_current isKindOfClass:[HCGOverviewViewController class]]) [(HCGOverviewViewController *)_current panelDidDisappear];
        [_current willMoveToParentViewController:nil];
        [_current.view removeFromSuperview];
        [_current removeFromParentViewController];
        [self addChildViewController:next];
        next.view.frame = _content.bounds;
        next.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        next.view.backgroundColor = [UIColor clearColor];
        if ([next isKindOfClass:[UITableViewController class]]) ((UITableViewController *)next).tableView.backgroundColor = [UIColor clearColor];
        [_content addSubview:next.view];
        [next didMoveToParentViewController:self];
        _current = next;
        if (_panelVisible && [next isKindOfClass:[HCGOverviewViewController class]]) [(HCGOverviewViewController *)next panelDidAppear];
    }
    [self styleSectionBar];
    UIAccessibilityPostNotification(UIAccessibilityLayoutChangedNotification, nil);
}

#pragma mark Lifecycle

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.navigationController setNavigationBarHidden:YES animated:animated];
    [self reloadContent];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.navigationController setNavigationBarHidden:NO animated:animated];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (!_context.insideOverlay) [self panelDidAppear]; // the app and Settings have no open/close events
}

- (void)panelDidAppear {
    _panelVisible = YES;
    if ([_current isKindOfClass:[HCGOverviewViewController class]]) [(HCGOverviewViewController *)_current panelDidAppear];
}

- (void)panelDidDisappear {
    _panelVisible = NO;
    if ([_current isKindOfClass:[HCGOverviewViewController class]]) [(HCGOverviewViewController *)_current panelDidDisappear];
}

- (void)reloadContent {
    if (!self.isViewLoaded) return;
    if ([_current respondsToSelector:@selector(modelDidChange)]) [(id)_current modelDidChange];
}

- (void)resetTransientState {
    [self panelDidDisappear];
    _toast.alpha = 0;
    [self.view endEditing:YES];
}

- (id)accessibilityFocusElement {
    return _brand;
}

- (void)closeTapped {
    if (_context.closePanel) _context.closePanel();
}

#pragma mark Feedback

- (void)showToast:(NSString *)message success:(BOOL)success {
    if (!self.isViewLoaded || message.length == 0) return;
    _toast.text = [NSString stringWithFormat:@"  %@  ", message];
    _toast.backgroundColor = [HCGTheme reduceTransparency] ? [HCGTheme raisedSurface] : [[HCGTheme obsidian] colorWithAlphaComponent:0.92];
    _toast.layer.borderColor = (success ? [HCGTheme cyan] : [HCGTheme warning]).CGColor;
    [self.view bringSubviewToFront:_toast];
    NSUInteger generation = ++_toastGeneration;
    BOOL motion = [HCGTheme decorativeMotionAllowedWithSettings:_context.model.settings];
    [UIView animateWithDuration:motion ? 0.2 : 0 animations:^{ self->_toast.alpha = 1; }];
    UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, message);
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf || generation != strongSelf->_toastGeneration) return;
        [UIView animateWithDuration:motion ? 0.25 : 0 animations:^{ strongSelf->_toast.alpha = 0; }];
    });
}

@end
