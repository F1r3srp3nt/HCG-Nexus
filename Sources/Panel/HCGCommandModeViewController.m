#import "HCGCommandModeViewController.h"
#import "HCGTheme.h"
#import "HCGDeviceStatusMonitor.h"
#import "HCGActionRunner.h"

#pragma mark - Views

// Root view: VoiceOver escape (two-finger Z) leaves Command Mode.
@interface HCGCommandModeRootView : UIView
@property (nonatomic, copy) void (^escapeHandler)(void);
@end

@implementation HCGCommandModeRootView
- (BOOL)accessibilityPerformEscape {
    if (self.escapeHandler) self.escapeHandler();
    return YES;
}
@end

// Static scanlines. Decoration only: drawn once per size, never animated.
@interface HCGScanlineView : UIView
@end

@implementation HCGScanlineView
- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.opaque = NO;
        self.backgroundColor = [UIColor clearColor];
        self.userInteractionEnabled = NO;
        self.isAccessibilityElement = NO;
        self.contentMode = UIViewContentModeRedraw;
    }
    return self;
}
- (void)drawRect:(CGRect)rect {
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(ctx, [[HCGTheme cyan] colorWithAlphaComponent:0.035].CGColor);
    CGFloat start = floor(CGRectGetMinY(rect) / 4.0) * 4.0;
    for (CGFloat y = start; y < CGRectGetMaxY(rect); y += 4.0) {
        CGContextFillRect(ctx, CGRectMake(CGRectGetMinX(rect), y, CGRectGetWidth(rect), 1.0));
    }
}
@end

// Icon inside a thin static ring tinted by the status colour role.
@interface HCGStatusRingView : UIView
@property (nonatomic, strong) UIColor *ringColor;
@property (nonatomic, readonly) UIImageView *imageView;
@end

@implementation HCGStatusRingView {
    CAShapeLayer *_ring;
}
- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.userInteractionEnabled = NO;
        self.isAccessibilityElement = NO;
        _ring = [CAShapeLayer layer];
        _ring.lineWidth = 1.0;
        [self.layer addSublayer:_ring];
        _imageView = [[UIImageView alloc] init];
        _imageView.contentMode = UIViewContentModeCenter;
        _imageView.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:_imageView];
        [NSLayoutConstraint activateConstraints:@[
            [_imageView.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
            [_imageView.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
            [self.widthAnchor constraintEqualToConstant:34],
            [self.heightAnchor constraintEqualToConstant:34],
        ]];
    }
    return self;
}
- (void)layoutSubviews {
    [super layoutSubviews];
    UIColor *color = self.ringColor ?: [HCGTheme secondaryText];
    _ring.frame = self.bounds;
    _ring.path = [UIBezierPath bezierPathWithOvalInRect:CGRectInset(self.bounds, 0.5, 0.5)].CGPath;
    _ring.strokeColor = [color colorWithAlphaComponent:0.55].CGColor;
    _ring.fillColor = [color colorWithAlphaComponent:0.08].CGColor;
    _imageView.tintColor = color;
}
@end

// A tappable row whose subviews never take touches themselves.
@interface HCGCommandRowControl : UIControl
@end

@implementation HCGCommandRowControl
- (void)setHighlighted:(BOOL)highlighted {
    [super setHighlighted:highlighted];
    self.alpha = highlighted ? 0.6 : 1.0;
}
@end

#pragma mark - Controller

@implementation HCGCommandModeViewController {
    HCGPanelContext *_context;
    HCGDeviceStatusMonitor *_monitor;
    HCGDeviceStatusSnapshot *_snapshot;
    UIView *_scrim;
    UIView *_card;
    UIView *_cardBackground;
    UIView *_rimView;
    UIScrollView *_scroll;
    UILayoutGuide *_contentGuide;
    NSLayoutConstraint *_guideTop, *_guideLeft, *_guideBottom, *_guideRight;
    UILabel *_commandLabel;
    UILabel *_timeLabel;
    UILabel *_dateLabel;
    UIStackView *_deviceGrid;
    UILabel *_shortcutsHeader;
    UIStackView *_shortcutGrid;
    UILabel *_shortcutsEmpty;
    UIStackView *_integrationStack;
    UILabel *_toast;
    UILabel *_footnote;
    NSArray<HCGAction *> *_shortcuts;
    NSArray<HCGIntegrationStatus *> *_integrations;
    NSDateFormatter *_timeFormatter;
    NSDateFormatter *_dateFormatter;
    NSTimer *_clockTimer;
    BOOL _updating;
}

- (instancetype)initWithContext:(HCGPanelContext *)context {
    if ((self = [super initWithNibName:nil bundle:nil])) {
        _context = context;
        _monitor = [[HCGDeviceStatusMonitor alloc] init];
        _snapshot = _monitor.snapshot;
        _shortcuts = @[];
        _integrations = @[];
        _timeFormatter = [[NSDateFormatter alloc] init];
        _timeFormatter.dateStyle = NSDateFormatterNoStyle;
        _timeFormatter.timeStyle = NSDateFormatterShortStyle;
        _dateFormatter = [[NSDateFormatter alloc] init];
        [_dateFormatter setLocalizedDateFormatFromTemplate:@"EEEEdMMMMy"];
        self.modalPresentationCapturesStatusBarAppearance = YES;
    }
    return self;
}

- (void)dealloc {
    [_clockTimer invalidate];
    [_monitor stop];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (UIStatusBarStyle)preferredStatusBarStyle {
    return UIStatusBarStyleLightContent;
}

- (void)loadView {
    HCGCommandModeRootView *root = [[HCGCommandModeRootView alloc] init];
    root.backgroundColor = [UIColor clearColor];
    root.accessibilityViewIsModal = YES;
    __weak typeof(self) weakSelf = self;
    root.escapeHandler = ^{ [weakSelf closeCommandMode]; };
    self.view = root;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;

    _scrim = [[UIView alloc] initWithFrame:self.view.bounds];
    _scrim.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _scrim.isAccessibilityElement = NO;
    [_scrim addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(scrimTapped:)]];
    [self.view addSubview:_scrim];

    _contentGuide = [[UILayoutGuide alloc] init];
    [self.view addLayoutGuide:_contentGuide];
    _guideTop = [_contentGuide.topAnchor constraintEqualToAnchor:self.view.topAnchor];
    _guideLeft = [_contentGuide.leftAnchor constraintEqualToAnchor:self.view.leftAnchor];
    _guideBottom = [self.view.bottomAnchor constraintEqualToAnchor:_contentGuide.bottomAnchor];
    _guideRight = [self.view.rightAnchor constraintEqualToAnchor:_contentGuide.rightAnchor];
    [NSLayoutConstraint activateConstraints:@[ _guideTop, _guideLeft, _guideBottom, _guideRight ]];

    _card = [[UIView alloc] init];
    _card.translatesAutoresizingMaskIntoConstraints = NO;
    _card.layer.cornerRadius = 24;
    _card.layer.cornerCurve = kCACornerCurveContinuous;
    [self.view addSubview:_card];

    _scroll = [[UIScrollView alloc] init];
    _scroll.translatesAutoresizingMaskIntoConstraints = NO;
    _scroll.indicatorStyle = UIScrollViewIndicatorStyleWhite;
    _scroll.alwaysBounceVertical = NO;
    [_card addSubview:_scroll];

    UIStackView *content = [[UIStackView alloc] initWithArrangedSubviews:@[ [self buildHeader], [self buildClock] ]];
    content.axis = UILayoutConstraintAxisVertical;
    content.spacing = 16;
    content.translatesAutoresizingMaskIntoConstraints = NO;

    _deviceGrid = [self verticalStack];
    [content addArrangedSubview:[self sectionLabel:@"DEVICE"]];
    [content setCustomSpacing:8 afterView:content.arrangedSubviews.lastObject];
    [content addArrangedSubview:_deviceGrid];

    _shortcutsHeader = [self sectionLabel:@"SHORTCUTS"];
    _shortcutGrid = [self verticalStack];
    _shortcutsEmpty = [self bodyLabel:@"" style:UIFontTextStyleFootnote color:[HCGTheme secondaryText]];
    [content addArrangedSubview:_shortcutsHeader];
    [content setCustomSpacing:8 afterView:_shortcutsHeader];
    [content addArrangedSubview:_shortcutGrid];
    [content addArrangedSubview:_shortcutsEmpty];

    UILabel *integrationsHeader = [self sectionLabel:@"HCG INTEGRATIONS"];
    _integrationStack = [self verticalStack];
    [content addArrangedSubview:integrationsHeader];
    [content setCustomSpacing:8 afterView:integrationsHeader];
    [content addArrangedSubview:_integrationStack];

    _toast = [self bodyLabel:@"" style:UIFontTextStyleFootnote color:[HCGTheme primaryText]];
    _toast.textAlignment = NSTextAlignmentCenter;
    _toast.backgroundColor = [HCGTheme cyanSoft];
    _toast.layer.cornerRadius = 10;
    _toast.clipsToBounds = YES;
    _toast.hidden = YES;
    [content addArrangedSubview:_toast];

    _footnote = [self bodyLabel:[self footnoteText] style:UIFontTextStyleCaption2 color:[HCGTheme secondaryText]];
    [content addArrangedSubview:_footnote];

    [_scroll addSubview:content];

    UILayoutGuide *g = _contentGuide;
    NSLayoutConstraint *preferredWidth = [_card.widthAnchor constraintEqualToAnchor:g.widthAnchor constant:-24];
    preferredWidth.priority = UILayoutPriorityDefaultHigh;
    NSLayoutConstraint *fitHeight = [_scroll.heightAnchor constraintEqualToAnchor:_scroll.contentLayoutGuide.heightAnchor];
    fitHeight.priority = UILayoutPriorityDefaultLow; // shrink to content, scroll when taller than the screen
    [NSLayoutConstraint activateConstraints:@[
        [_card.centerXAnchor constraintEqualToAnchor:g.centerXAnchor],
        [_card.centerYAnchor constraintEqualToAnchor:g.centerYAnchor],
        [_card.widthAnchor constraintLessThanOrEqualToConstant:600],
        [_card.leadingAnchor constraintGreaterThanOrEqualToAnchor:g.leadingAnchor constant:12],
        [_card.topAnchor constraintGreaterThanOrEqualToAnchor:g.topAnchor constant:12],
        [g.bottomAnchor constraintGreaterThanOrEqualToAnchor:_card.bottomAnchor constant:12],
        preferredWidth,
        [_scroll.leadingAnchor constraintEqualToAnchor:_card.leadingAnchor],
        [_scroll.trailingAnchor constraintEqualToAnchor:_card.trailingAnchor],
        [_scroll.topAnchor constraintEqualToAnchor:_card.topAnchor],
        [_scroll.bottomAnchor constraintEqualToAnchor:_card.bottomAnchor],
        fitHeight,
        [content.leadingAnchor constraintEqualToAnchor:_scroll.contentLayoutGuide.leadingAnchor constant:18],
        [content.trailingAnchor constraintEqualToAnchor:_scroll.contentLayoutGuide.trailingAnchor constant:-18],
        [content.topAnchor constraintEqualToAnchor:_scroll.contentLayoutGuide.topAnchor constant:18],
        [content.bottomAnchor constraintEqualToAnchor:_scroll.contentLayoutGuide.bottomAnchor constant:-18],
        [content.widthAnchor constraintEqualToAnchor:_scroll.frameLayoutGuide.widthAnchor constant:-36],
    ]];

    [self applyAppearance];

    __weak typeof(self) weakSelf = self;
    _monitor.changeHandler = ^(HCGDeviceStatusSnapshot *snapshot) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        strongSelf->_snapshot = snapshot;
        [strongSelf reloadDeviceTiles];
    };

    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self selector:@selector(reloadContent) name:HCGNexusModelDidChangeNotification object:_context.model];
    [nc addObserver:self selector:@selector(reloadContent) name:UIContentSizeCategoryDidChangeNotification object:nil];
    [nc addObserver:self selector:@selector(accessibilityChanged) name:UIAccessibilityReduceTransparencyStatusDidChangeNotification object:nil];
    [nc addObserver:self selector:@selector(accessibilityChanged) name:UIAccessibilityDarkerSystemColorsStatusDidChangeNotification object:nil];
    [nc addObserver:self selector:@selector(updateClock) name:NSSystemClockDidChangeNotification object:nil];
    [nc addObserver:self selector:@selector(updateClock) name:NSSystemTimeZoneDidChangeNotification object:nil];
    [nc addObserver:self selector:@selector(updateClock) name:NSCurrentLocaleDidChangeNotification object:nil];

    [self updateContentGuide];
    [self reloadContent];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self startUpdates];
    [self reloadContent];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [self stopUpdates];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    // Accessibility text sizes switch the grids to one column.
    if (![previousTraitCollection.preferredContentSizeCategory isEqualToString:self.traitCollection.preferredContentSizeCategory]) {
        [self reloadContent];
    }
}

- (void)viewSafeAreaInsetsDidChange {
    [super viewSafeAreaInsetsDidChange];
    [self updateContentGuide];
}

- (void)setHostContentInsets:(UIEdgeInsets)hostContentInsets {
    _hostContentInsets = hostContentInsets;
    [self updateContentGuide];
}

- (void)setUsesHostContentInsets:(BOOL)usesHostContentInsets {
    _usesHostContentInsets = usesHostContentInsets;
    [self updateContentGuide];
}

- (void)updateContentGuide {
    if (!self.isViewLoaded || !_guideTop) return;
    UIEdgeInsets insets = self.usesHostContentInsets ? self.hostContentInsets : self.view.safeAreaInsets;
    _guideTop.constant = insets.top;
    _guideLeft.constant = insets.left;
    _guideBottom.constant = insets.bottom;
    _guideRight.constant = insets.right;
}

- (id)accessibilityFocusElement {
    return _commandLabel;
}

#pragma mark Building blocks

- (UIStackView *)verticalStack {
    UIStackView *stack = [[UIStackView alloc] init];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 10;
    return stack;
}

- (UILabel *)bodyLabel:(NSString *)text style:(UIFontTextStyle)style color:(UIColor *)color {
    UILabel *label = [[UILabel alloc] init];
    label.text = text;
    label.numberOfLines = 0;
    label.font = [HCGTheme fontForTextStyle:style weight:UIFontWeightRegular];
    label.adjustsFontForContentSizeCategory = YES;
    label.textColor = color;
    return label;
}

- (UILabel *)sectionLabel:(NSString *)text {
    UILabel *label = [[UILabel alloc] init];
    label.attributedText = [[NSAttributedString alloc] initWithString:text attributes:@{
        NSFontAttributeName : [HCGTheme fontForTextStyle:UIFontTextStyleCaption1 weight:UIFontWeightSemibold],
        NSForegroundColorAttributeName : [HCGTheme secondaryText],
        NSKernAttributeName : @(1.6),
    }];
    label.numberOfLines = 0;
    label.adjustsFontForContentSizeCategory = YES;
    label.accessibilityTraits = UIAccessibilityTraitHeader;
    return label;
}

- (UIView *)buildHeader {
    _commandLabel = [[UILabel alloc] init];
    _commandLabel.attributedText = [[NSAttributedString alloc] initWithString:@"COMMAND MODE" attributes:@{
        NSFontAttributeName : [HCGTheme fontForTextStyle:UIFontTextStyleHeadline weight:UIFontWeightHeavy],
        NSForegroundColorAttributeName : [HCGTheme cyan],
        NSKernAttributeName : @(3.0),
    }];
    _commandLabel.accessibilityLabel = @"HCG Nexus Command Mode";
    _commandLabel.accessibilityTraits = UIAccessibilityTraitHeader;
    _commandLabel.adjustsFontSizeToFitWidth = YES;
    _commandLabel.minimumScaleFactor = 0.7;

    UILabel *badge = [[UILabel alloc] init];
    badge.font = [UIFont monospacedSystemFontOfSize:10 weight:UIFontWeightBold];
    badge.layer.cornerRadius = 4;
    badge.clipsToBounds = YES;
    badge.textColor = [HCGTheme obsidian];
    badge.hidden = YES;
    if (_context.mode == HCGPanelModePreview) {
        badge.text = @"  PREVIEW  ";
        badge.backgroundColor = [HCGTheme warning];
        badge.accessibilityLabel = @"Preview harness. App launches are simulated.";
        badge.hidden = NO;
    } else if (_context.mode == HCGPanelModeStandaloneApp) {
        badge.text = @"  APP MODE  ";
        badge.backgroundColor = [HCGTheme cyan];
        badge.accessibilityLabel = @"Standalone app mode.";
        badge.hidden = NO;
    }
    [badge setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];

    UIButton *close = [UIButton buttonWithType:UIButtonTypeSystem];
    [close setImage:[HCGTheme symbolNamed:@"xmark" pointSize:15] forState:UIControlStateNormal];
    close.tintColor = [HCGTheme primaryText];
    close.backgroundColor = [HCGTheme raisedSurface];
    close.layer.cornerRadius = 22;
    close.accessibilityLabel = @"Close Command Mode";
    [close addTarget:self action:@selector(closeCommandMode) forControlEvents:UIControlEventTouchUpInside];
    [close.widthAnchor constraintEqualToConstant:44].active = YES;
    [close.heightAnchor constraintEqualToConstant:44].active = YES;

    UIStackView *header = [[UIStackView alloc] initWithArrangedSubviews:@[ _commandLabel, badge, close ]];
    header.alignment = UIStackViewAlignmentCenter;
    header.spacing = 8;
    [_commandLabel setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    return header;
}

- (UIView *)buildClock {
    _timeLabel = [[UILabel alloc] init];
    UIFont *time = [UIFont monospacedDigitSystemFontOfSize:44 weight:UIFontWeightUltraLight];
    _timeLabel.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleLargeTitle] scaledFontForFont:time];
    _timeLabel.adjustsFontForContentSizeCategory = YES;
    _timeLabel.textColor = [HCGTheme primaryText];
    _timeLabel.adjustsFontSizeToFitWidth = YES;
    _timeLabel.minimumScaleFactor = 0.5;
    _dateLabel = [self bodyLabel:@"" style:UIFontTextStyleSubheadline color:[HCGTheme secondaryText]];
    UIStackView *clock = [[UIStackView alloc] initWithArrangedSubviews:@[ _timeLabel, _dateLabel ]];
    clock.axis = UILayoutConstraintAxisVertical;
    clock.spacing = 0;
    return clock;
}

- (NSString *)footnoteText {
    NSString *text = @"Device values come from iOS: battery and power state, the network path (not an internet or HCG service check) and available storage; \"Unavailable\" means iOS gave no value. Integration states reflect your HCG Nexus settings and whether the app is installed. Nexus holds no HCG session and shows no live service status.";
    if (_context.mode == HCGPanelModePreview) {
        text = [@"Preview harness: app launches and installation checks are simulated. " stringByAppendingString:text];
    }
    return text;
}

// The card: translucent obsidian over a blur (solid with Reduce
// Transparency), brushed-chrome border, a faint rim light and static
// scanlines. Nothing here moves.
- (UIView *)makeCardBackground {
    BOOL reduceTransparency = [HCGTheme reduceTransparency];
    BOOL contrast = [HCGTheme increaseContrast];
    UIView *container = [[UIView alloc] init];
    container.userInteractionEnabled = NO;
    container.layer.cornerRadius = 24;
    container.layer.cornerCurve = kCACornerCurveContinuous;
    container.clipsToBounds = YES;
    UIViewAutoresizing fill = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

    if (!reduceTransparency) {
        UIVisualEffectView *blur = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterialDark]];
        blur.frame = container.bounds;
        blur.autoresizingMask = fill;
        [container addSubview:blur];
    }
    UIView *tint = [[UIView alloc] initWithFrame:container.bounds];
    tint.autoresizingMask = fill;
    tint.backgroundColor = reduceTransparency ? [HCGTheme surface] : [[HCGTheme obsidian] colorWithAlphaComponent:contrast ? 0.86 : 0.64];
    [container addSubview:tint];

    if (!reduceTransparency && !contrast) {
        HCGScanlineView *scanlines = [[HCGScanlineView alloc] initWithFrame:container.bounds];
        scanlines.autoresizingMask = fill;
        [container addSubview:scanlines];
    }

    CAGradientLayer *rim = [CAGradientLayer layer];
    rim.colors = @[ (id)[UIColor clearColor].CGColor, (id)[[HCGTheme cyan] colorWithAlphaComponent:0.6].CGColor, (id)[UIColor clearColor].CGColor ];
    rim.startPoint = CGPointMake(0, 0.5);
    rim.endPoint = CGPointMake(1, 0.5);
    rim.frame = CGRectMake(0, 0, 2000, 1);
    UIView *rimView = [[UIView alloc] initWithFrame:CGRectMake(24, 0, 0, 1)];
    rimView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleBottomMargin;
    rimView.clipsToBounds = YES;
    [rimView.layer addSublayer:rim];
    [container addSubview:rimView];
    _rimView = rimView;

    HCGChromeBorderView *border = [[HCGChromeBorderView alloc] initWithFrame:container.bounds];
    border.autoresizingMask = fill;
    border.cornerRadius = 24;
    border.lineWidth = contrast ? 1.5 : 1.0;
    [container addSubview:border];
    return container;
}

- (void)applyAppearance {
    BOOL reduceTransparency = [HCGTheme reduceTransparency];
    double alpha = [HCGCommandModeStatus scrimAlphaReducingTransparency:reduceTransparency increaseContrast:[HCGTheme increaseContrast]];
    _scrim.backgroundColor = reduceTransparency ? [[HCGTheme obsidian] colorWithAlphaComponent:alpha] : [UIColor colorWithWhite:0 alpha:alpha];

    [_cardBackground removeFromSuperview];
    _cardBackground = [self makeCardBackground];
    _cardBackground.frame = _card.bounds;
    _cardBackground.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [_card insertSubview:_cardBackground atIndex:0];
    [self layoutRimLight];
}

- (void)layoutRimLight {
    _rimView.frame = CGRectMake(24, 0, MAX(0, CGRectGetWidth(_card.bounds) - 48), 1);
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    if (!CGRectEqualToRect(_cardBackground.frame, _card.bounds)) {
        _cardBackground.frame = _card.bounds;
        [self layoutRimLight];
    }
}

- (void)accessibilityChanged {
    [self applyAppearance];
    [self reloadContent];
}

#pragma mark Updates

- (void)startUpdates {
    if (_updating) return;
    _updating = YES;
    [_monitor start];
    [self updateClock];
    [self scheduleClockTick];
}

- (void)stopUpdates {
    if (!_updating) return;
    _updating = NO;
    [_clockTimer invalidate];
    _clockTimer = nil;
    [_monitor stop];
}

// One tick per minute boundary: the clock only changes when the minute does.
- (void)scheduleClockTick {
    [_clockTimer invalidate];
    NSTimeInterval now = [NSDate date].timeIntervalSinceReferenceDate;
    NSTimeInterval delay = 60.0 - fmod(now, 60.0) + 0.05;
    __weak typeof(self) weakSelf = self;
    _clockTimer = [NSTimer scheduledTimerWithTimeInterval:delay repeats:NO block:^(NSTimer *timer) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf || !strongSelf->_updating) return;
        [strongSelf updateClock];
        [strongSelf->_monitor refresh];
        [strongSelf scheduleClockTick];
    }];
    _clockTimer.tolerance = 0.5;
}

- (void)updateClock {
    if (!self.isViewLoaded) return;
    _timeFormatter.timeZone = [NSTimeZone localTimeZone];
    _dateFormatter.timeZone = [NSTimeZone localTimeZone];
    NSDate *now = [NSDate date];
    _timeLabel.text = [_timeFormatter stringFromDate:now];
    _dateLabel.text = [_dateFormatter stringFromDate:now];
}

#pragma mark Content

- (NSInteger)columns {
    return UIContentSizeCategoryIsAccessibilityCategory(self.traitCollection.preferredContentSizeCategory) ? 1 : 2;
}

- (void)fillGrid:(UIStackView *)grid withViews:(NSArray<UIView *> *)views {
    for (UIView *view in grid.arrangedSubviews) {
        [grid removeArrangedSubview:view];
        [view removeFromSuperview];
    }
    NSInteger columns = [self columns];
    for (NSUInteger i = 0; i < views.count; i += (NSUInteger)columns) {
        NSMutableArray *row = [NSMutableArray array];
        for (NSInteger c = 0; c < columns; c++) {
            NSUInteger index = i + (NSUInteger)c;
            if (index < views.count) {
                [row addObject:views[index]];
            } else {
                UIView *spacer = [[UIView alloc] init];
                spacer.isAccessibilityElement = NO;
                [row addObject:spacer];
            }
        }
        UIStackView *line = [[UIStackView alloc] initWithArrangedSubviews:row];
        line.axis = UILayoutConstraintAxisHorizontal;
        line.distribution = UIStackViewDistributionFillEqually;
        line.alignment = UIStackViewAlignmentFill;
        line.spacing = 10;
        [grid addArrangedSubview:line];
    }
}

- (void)reloadContent {
    if (!self.isViewLoaded) return;
    [self updateClock];
    [self reloadDeviceTiles];

    HCGNexusModel *model = _context.model;
    HCGWorkspace *active = model.workspaceStore.activeWorkspace;
    _shortcuts = active.actions ?: @[];
    NSString *header = active ? [NSString stringWithFormat:@"SHORTCUTS · %@", active.name.uppercaseString] : @"SHORTCUTS";
    _shortcutsHeader.attributedText = [[NSAttributedString alloc] initWithString:header attributes:@{
        NSFontAttributeName : [HCGTheme fontForTextStyle:UIFontTextStyleCaption1 weight:UIFontWeightSemibold],
        NSForegroundColorAttributeName : [HCGTheme secondaryText],
        NSKernAttributeName : @(1.6),
    }];
    NSMutableArray *buttons = [NSMutableArray array];
    for (NSUInteger i = 0; i < _shortcuts.count; i++) [buttons addObject:[self shortcutButtonAtIndex:i]];
    [self fillGrid:_shortcutGrid withViews:buttons];
    _shortcutGrid.hidden = buttons.count == 0;
    _shortcutsEmpty.hidden = buttons.count > 0;
    _shortcutsEmpty.text = active ? @"This workspace has no shortcuts. Add them under Shortcuts in the panel."
                                  : @"No workspace yet. Create one under Workspaces in the panel.";

    _integrations = [model integrationStatuses];
    for (UIView *view in _integrationStack.arrangedSubviews) {
        [_integrationStack removeArrangedSubview:view];
        [view removeFromSuperview];
    }
    for (NSUInteger i = 0; i < _integrations.count; i++) [_integrationStack addArrangedSubview:[self integrationRowAtIndex:i]];
}

- (void)reloadDeviceTiles {
    if (!self.isViewLoaded) return;
    NSArray<HCGStatusDisplay *> *displays = [HCGCommandModeStatus deviceDisplaysForSnapshot:_snapshot];
    NSMutableArray *tiles = [NSMutableArray array];
    for (HCGStatusDisplay *display in displays) [tiles addObject:[self tileForDisplay:display]];
    [self fillGrid:_deviceGrid withViews:tiles];
}

- (UIView *)surfaceViewWithCornerRadius:(CGFloat)radius {
    UIView *view = [[UIView alloc] init];
    view.backgroundColor = [HCGTheme reduceTransparency] ? [HCGTheme raisedSurface] : [[HCGTheme raisedSurface] colorWithAlphaComponent:0.62];
    view.layer.cornerRadius = radius;
    view.layer.cornerCurve = kCACornerCurveContinuous;
    view.layer.borderWidth = 1;
    view.layer.borderColor = [HCGTheme separator].CGColor;
    return view;
}

- (UIView *)tileForDisplay:(HCGStatusDisplay *)display {
    UIColor *roleColor = [HCGTheme colorForStatusRole:display.colorRole];
    UIView *tile = [self surfaceViewWithCornerRadius:14];
    tile.isAccessibilityElement = YES;
    tile.accessibilityLabel = [display accessibilityText];

    HCGStatusRingView *ring = [[HCGStatusRingView alloc] init];
    ring.ringColor = display.colorRole == HCGStatusColorRoleNeutral ? [HCGTheme cyan] : roleColor;
    ring.imageView.image = [HCGTheme symbolNamed:display.symbolName pointSize:15];

    UILabel *title = [[UILabel alloc] init];
    title.attributedText = [[NSAttributedString alloc] initWithString:display.title.uppercaseString attributes:@{
        NSFontAttributeName : [HCGTheme fontForTextStyle:UIFontTextStyleCaption2 weight:UIFontWeightSemibold],
        NSForegroundColorAttributeName : [HCGTheme secondaryText],
        NSKernAttributeName : @(1.0),
    }];
    title.numberOfLines = 0;
    title.adjustsFontForContentSizeCategory = YES;
    UILabel *value = [[UILabel alloc] init];
    value.text = display.value;
    value.font = [HCGTheme fontForTextStyle:UIFontTextStyleTitle3 weight:UIFontWeightSemibold];
    value.adjustsFontForContentSizeCategory = YES;
    value.textColor = roleColor;
    value.numberOfLines = 0;
    UILabel *detail = [self bodyLabel:display.detail style:UIFontTextStyleCaption1 color:[HCGTheme secondaryText]];

    UIStackView *texts = [[UIStackView alloc] initWithArrangedSubviews:@[ title, value, detail ]];
    texts.axis = UILayoutConstraintAxisVertical;
    texts.spacing = 2;
    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[ ring, texts ]];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.alignment = UIStackViewAlignmentLeading;
    stack.spacing = 8;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.userInteractionEnabled = NO;
    [tile addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [stack.leadingAnchor constraintEqualToAnchor:tile.leadingAnchor constant:12],
        [stack.trailingAnchor constraintEqualToAnchor:tile.trailingAnchor constant:-12],
        [stack.topAnchor constraintEqualToAnchor:tile.topAnchor constant:12],
        [stack.bottomAnchor constraintLessThanOrEqualToAnchor:tile.bottomAnchor constant:-12],
    ]];
    return tile;
}

- (UIButton *)shortcutButtonAtIndex:(NSUInteger)index {
    HCGAction *action = _shortcuts[index];
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    NSMutableAttributedString *title = [[NSMutableAttributedString alloc] initWithString:action.title ?: @"" attributes:@{
        NSFontAttributeName : [HCGTheme fontForTextStyle:UIFontTextStyleSubheadline weight:UIFontWeightSemibold],
        NSForegroundColorAttributeName : [HCGTheme primaryText],
    }];
    NSString *caption = [self captionForAction:action];
    if (caption.length) {
        [title appendAttributedString:[[NSAttributedString alloc] initWithString:[@"\n" stringByAppendingString:caption] attributes:@{
            NSFontAttributeName : [HCGTheme fontForTextStyle:UIFontTextStyleCaption2 weight:UIFontWeightRegular],
            NSForegroundColorAttributeName : [HCGTheme secondaryText],
        }]];
    }
    [button setAttributedTitle:title forState:UIControlStateNormal];
    [button setImage:[HCGTheme symbolNamed:action.symbolName pointSize:15] forState:UIControlStateNormal];
    button.titleLabel.numberOfLines = 0;
    button.titleLabel.adjustsFontForContentSizeCategory = YES;
    button.titleLabel.lineBreakMode = NSLineBreakByWordWrapping;
    button.tintColor = [HCGTheme cyan];
    button.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeading;
    button.backgroundColor = [HCGTheme reduceTransparency] ? [HCGTheme raisedSurface] : [[HCGTheme raisedSurface] colorWithAlphaComponent:0.62];
    button.layer.cornerRadius = 12;
    button.layer.cornerCurve = kCACornerCurveContinuous;
    button.layer.borderWidth = 1;
    button.layer.borderColor = [HCGTheme separator].CGColor;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    // Still honoured when no UIButtonConfiguration is set; needed for iOS 14.
    button.contentEdgeInsets = UIEdgeInsetsMake(10, 12, 10, 18);
    button.titleEdgeInsets = UIEdgeInsetsMake(0, 8, 0, -8);
#pragma clang diagnostic pop
    [button.heightAnchor constraintGreaterThanOrEqualToConstant:48].active = YES;
    button.tag = (NSInteger)index;
    button.accessibilityLabel = caption.length ? [NSString stringWithFormat:@"%@, %@", action.title, caption] : action.title;
    button.accessibilityHint = @"Opens this shortcut.";
    button.enabled = _context.runner != nil;
    [button addTarget:self action:@selector(shortcutTapped:) forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (NSString *)captionForAction:(HCGAction *)action {
    switch (action.kind) {
        case HCGActionKindApp:
            if (_context.model.launcher && ![_context.model.launcher canLaunchApplicationsByBundleIdentifier]) return @"Needs jailbreak package";
            return @"App";
        case HCGActionKindURL: return @"Link";
        case HCGActionKindIntegration: {
            HCGIntegrationStatus *status = [_context.model statusForIntegration:action.target];
            return [NSString stringWithFormat:@"HCG · %@", [HCGCommandModeStatus displayForIntegrationStatus:status].value];
        }
    }
    return @"";
}

- (UIView *)integrationRowAtIndex:(NSUInteger)index {
    HCGIntegrationStatus *status = _integrations[index];
    HCGStatusDisplay *display = [HCGCommandModeStatus displayForIntegrationStatus:status];
    UIColor *roleColor = [HCGTheme colorForStatusRole:display.colorRole];

    HCGCommandRowControl *row = [[HCGCommandRowControl alloc] init];
    row.backgroundColor = [HCGTheme reduceTransparency] ? [HCGTheme raisedSurface] : [[HCGTheme raisedSurface] colorWithAlphaComponent:0.62];
    row.layer.cornerRadius = 14;
    row.layer.cornerCurve = kCACornerCurveContinuous;
    row.layer.borderWidth = 1;
    row.layer.borderColor = [HCGTheme separator].CGColor;
    row.tag = (NSInteger)index;
    row.isAccessibilityElement = YES;
    row.accessibilityTraits = UIAccessibilityTraitButton;
    row.accessibilityLabel = [display accessibilityText];
    row.accessibilityHint = status.canLaunch ? @"Opens the app." : @"Shows details.";
    [row addTarget:self action:@selector(integrationTapped:) forControlEvents:UIControlEventTouchUpInside];

    HCGStatusRingView *ring = [[HCGStatusRingView alloc] init];
    ring.ringColor = display.colorRole == HCGStatusColorRoleNeutral ? [HCGTheme secondaryText] : roleColor;
    ring.imageView.image = [HCGTheme symbolNamed:status.symbolName pointSize:15];

    UILabel *name = [[UILabel alloc] init];
    name.text = display.title;
    name.font = [HCGTheme fontForTextStyle:UIFontTextStyleSubheadline weight:UIFontWeightSemibold];
    name.adjustsFontForContentSizeCategory = YES;
    name.textColor = [HCGTheme primaryText];
    name.numberOfLines = 0;
    UILabel *detail = [self bodyLabel:display.detail style:UIFontTextStyleCaption1 color:[HCGTheme secondaryText]];
    UIStackView *texts = [[UIStackView alloc] initWithArrangedSubviews:@[ name, detail ]];
    texts.axis = UILayoutConstraintAxisVertical;
    texts.spacing = 2;

    // State pill: symbol + text, so the state never depends on colour alone.
    UIImageView *stateIcon = [[UIImageView alloc] initWithImage:[HCGTheme symbolNamed:display.symbolName pointSize:11]];
    stateIcon.tintColor = roleColor;
    UILabel *stateLabel = [[UILabel alloc] init];
    stateLabel.text = display.value;
    stateLabel.font = [HCGTheme fontForTextStyle:UIFontTextStyleCaption1 weight:UIFontWeightSemibold];
    stateLabel.adjustsFontForContentSizeCategory = YES;
    stateLabel.textColor = roleColor;
    UIStackView *pill = [[UIStackView alloc] initWithArrangedSubviews:@[ stateIcon, stateLabel ]];
    pill.spacing = 4;
    pill.alignment = UIStackViewAlignmentCenter;
    pill.layoutMarginsRelativeArrangement = YES;
    pill.directionalLayoutMargins = NSDirectionalEdgeInsetsMake(4, 8, 4, 8);
    UIView *pillBackground = [[UIView alloc] init];
    pillBackground.backgroundColor = [roleColor colorWithAlphaComponent:0.12];
    pillBackground.layer.cornerRadius = 8;
    pillBackground.translatesAutoresizingMaskIntoConstraints = NO;
    [pill insertSubview:pillBackground atIndex:0];
    [NSLayoutConstraint activateConstraints:@[
        [pillBackground.leadingAnchor constraintEqualToAnchor:pill.leadingAnchor],
        [pillBackground.trailingAnchor constraintEqualToAnchor:pill.trailingAnchor],
        [pillBackground.topAnchor constraintEqualToAnchor:pill.topAnchor],
        [pillBackground.bottomAnchor constraintEqualToAnchor:pill.bottomAnchor],
    ]];
    [pill setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [pill setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];

    UIStackView *line = [[UIStackView alloc] initWithArrangedSubviews:@[ ring, texts, pill ]];
    line.alignment = UIStackViewAlignmentCenter;
    line.spacing = 10;
    if ([self columns] == 1) {
        line.axis = UILayoutConstraintAxisVertical;
        line.alignment = UIStackViewAlignmentLeading;
    }
    line.translatesAutoresizingMaskIntoConstraints = NO;
    line.userInteractionEnabled = NO;
    [row addSubview:line];
    [NSLayoutConstraint activateConstraints:@[
        [line.leadingAnchor constraintEqualToAnchor:row.leadingAnchor constant:12],
        [line.trailingAnchor constraintEqualToAnchor:row.trailingAnchor constant:-12],
        [line.topAnchor constraintEqualToAnchor:row.topAnchor constant:10],
        [line.bottomAnchor constraintEqualToAnchor:row.bottomAnchor constant:-10],
        [row.heightAnchor constraintGreaterThanOrEqualToConstant:56],
    ]];
    return row;
}

#pragma mark Actions

- (BOOL)animatesTransitions {
    return [HCGCommandModeStatus animatesTransitionsWithReduceMotion:UIAccessibilityIsReduceMotionEnabled()
                                                   animationsEnabled:_context.model.settings.animationsEnabled];
}

- (void)scrimTapped:(UITapGestureRecognizer *)recognizer {
    if (recognizer.state == UIGestureRecognizerStateEnded) [self closeCommandMode];
}

- (void)closeCommandMode {
    if (self.dismissHandler) {
        self.dismissHandler();
        return;
    }
    if (self.presentingViewController) {
        [self.presentingViewController dismissViewControllerAnimated:[self animatesTransitions] completion:nil];
    }
}

- (void)shortcutTapped:(UIButton *)button {
    if (button.tag < 0 || (NSUInteger)button.tag >= _shortcuts.count) return;
    [self runAction:_shortcuts[(NSUInteger)button.tag]];
}

- (void)integrationTapped:(HCGCommandRowControl *)row {
    if (row.tag < 0 || (NSUInteger)row.tag >= _integrations.count) return;
    HCGIntegrationStatus *status = _integrations[(NSUInteger)row.tag];
    if (status.canLaunch && _context.runner) {
        HCGAction *action = [HCGAction actionWithKind:HCGActionKindIntegration title:status.displayName target:status.identifier symbol:status.symbolName];
        action.identifier = [@"integration." stringByAppendingString:status.identifier];
        [self runAction:action];
        return;
    }
    HCGStatusDisplay *display = [HCGCommandModeStatus displayForIntegrationStatus:status];
    NSString *message = status.detail.length ? status.detail : display.detail;
    HCGPresentError(self, HCGMakeError(HCGErrorIntegrationNotConnected, [NSString stringWithFormat:@"%@: %@", display.title, display.value], message), nil);
}

- (void)runAction:(HCGAction *)action {
    if (!_context.runner) return;
    __weak typeof(self) weakSelf = self;
    [_context.runner runAction:action completion:^(NSError *error, NSString *summary) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        if (error) {
            HCGPresentError(strongSelf, error, nil);
            return;
        }
        HCGPanelContext *context = strongSelf->_context;
        if (context.isPreview || context.isStandaloneApp) {
            [strongSelf showToast:summary];
        } else if (context.closePanelImmediately) {
            context.closePanelImmediately(); // overlay: get out of the opened app's way (also removes Command Mode)
        }
    }];
}

- (void)showToast:(NSString *)message {
    _toast.text = [NSString stringWithFormat:@"  %@  ", message];
    _toast.hidden = NO;
    UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, message);
}

@end
