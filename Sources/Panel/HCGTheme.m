#import "HCGTheme.h"
#import "HCGSettings.h"

static UIColor *RGB(CGFloat r, CGFloat g, CGFloat b, CGFloat a) {
    return [UIColor colorWithRed:r / 255.0 green:g / 255.0 blue:b / 255.0 alpha:a];
}

const CGFloat HCGSectionBarMaximumPointSize = 20;   // the bar is 52 pt tall
const CGFloat HCGHeaderButtonMaximumPointSize = 22; // Add / Reorder / New Workspace / Edit
const CGFloat HCGChipMaximumPointSize = 26;         // workspace chips (they grow to fit)

@implementation HCGTheme

+ (BOOL)increaseContrast {
    return UIAccessibilityDarkerSystemColorsEnabled();
}

+ (BOOL)reduceTransparency {
    return UIAccessibilityIsReduceTransparencyEnabled();
}

+ (UIColor *)obsidian { return RGB(7, 9, 12, 1); }
+ (UIColor *)surface { return RGB(14, 17, 22, [self reduceTransparency] ? 1.0 : 0.92); }
+ (UIColor *)raisedSurface { return [self increaseContrast] ? RGB(34, 40, 50, 1) : RGB(23, 28, 36, 1); }
+ (UIColor *)separator { return [self increaseContrast] ? RGB(120, 132, 146, 1) : RGB(56, 64, 76, 1); }
+ (UIColor *)primaryText { return RGB(236, 241, 246, 1); }
+ (UIColor *)secondaryText { return [self increaseContrast] ? RGB(200, 210, 220, 1) : RGB(150, 163, 176, 1); }
+ (UIColor *)cyan { return [self increaseContrast] ? RGB(120, 240, 255, 1) : RGB(52, 222, 242, 1); }
+ (UIColor *)cyanSoft { return RGB(52, 222, 242, [self increaseContrast] ? 0.30 : 0.16); }
+ (UIColor *)violet { return [self increaseContrast] ? RGB(196, 176, 255, 1) : RGB(150, 128, 255, 1); }
+ (UIColor *)violetSoft { return RGB(150, 128, 255, [self increaseContrast] ? 0.30 : 0.14); }
+ (UIColor *)glassRow {
    if ([self reduceTransparency]) return [self raisedSurface];
    return [self increaseContrast] ? RGB(34, 40, 50, 0.86) : RGB(26, 32, 42, 0.58);
}
+ (UIColor *)hairline { return [self increaseContrast] ? RGB(150, 162, 176, 1) : RGB(255, 255, 255, 0.10); }
+ (UIColor *)warning { return RGB(255, 184, 77, 1); }
+ (UIColor *)success { return RGB(98, 224, 160, 1); }
+ (UIColor *)critical { return [self increaseContrast] ? RGB(255, 140, 140, 1) : RGB(255, 107, 107, 1); }

+ (UIColor *)colorForStatusRole:(HCGStatusColorRole)role {
    switch (role) {
        case HCGStatusColorRolePositive: return [self success];
        case HCGStatusColorRoleCaution: return [self warning];
        case HCGStatusColorRoleCritical: return [self critical];
        case HCGStatusColorRoleMuted: return [self secondaryText];
        default: return [self primaryText];
    }
}

+ (NSArray *)chromeGradientColors {
    CGFloat boost = [self increaseContrast] ? 1.15 : 1.0;
    return @[
        (id)RGB(MIN(255, 118 * boost), MIN(255, 128 * boost), MIN(255, 140 * boost), 1).CGColor,
        (id)RGB(MIN(255, 222 * boost), MIN(255, 228 * boost), MIN(255, 236 * boost), 1).CGColor,
        (id)RGB(MIN(255, 92 * boost), MIN(255, 100 * boost), MIN(255, 112 * boost), 1).CGColor,
        (id)RGB(MIN(255, 176 * boost), MIN(255, 184 * boost), MIN(255, 194 * boost), 1).CGColor,
    ];
}

// The base size must be the style's size at the DEFAULT text size ("Large"). UIFontMetrics then scales it once
// for the user's setting. Starting from preferredFontDescriptorWithTextStyle: (already scaled for the current
// setting) scaled it twice: at the largest accessibility size body text was drawn at ~150 pt instead of 53 pt.
+ (CGFloat)defaultPointSizeForTextStyle:(UIFontTextStyle)style {
    UITraitCollection *standard = [UITraitCollection traitCollectionWithPreferredContentSizeCategory:UIContentSizeCategoryLarge];
    return [UIFontDescriptor preferredFontDescriptorWithTextStyle:style compatibleWithTraitCollection:standard].pointSize;
}

+ (UIFont *)fontForTextStyle:(UIFontTextStyle)style weight:(UIFontWeight)weight {
    return [self fontForTextStyle:style weight:weight compatibleWithTraitCollection:nil];
}

+ (UIFont *)fontForTextStyle:(UIFontTextStyle)style weight:(UIFontWeight)weight compatibleWithTraitCollection:(UITraitCollection *)traits {
    UIFont *font = [UIFont systemFontOfSize:[self defaultPointSizeForTextStyle:style] weight:weight];
    UIFontMetrics *metrics = [UIFontMetrics metricsForTextStyle:style];
    return traits ? [metrics scaledFontForFont:font compatibleWithTraitCollection:traits] : [metrics scaledFontForFont:font];
}

+ (UIFont *)fontForTextStyle:(UIFontTextStyle)style weight:(UIFontWeight)weight maximumPointSize:(CGFloat)maximum {
    UIFont *font = [UIFont systemFontOfSize:[self defaultPointSizeForTextStyle:style] weight:weight];
    return [[UIFontMetrics metricsForTextStyle:style] scaledFontForFont:font maximumPointSize:maximum];
}

+ (void)enableLargeContentViewerForButton:(UIButton *)button title:(NSString *)title {
    button.showsLargeContentViewer = YES;
    button.largeContentTitle = title;
    button.scalesLargeContentImage = YES;
}

+ (NSAttributedString *)wordmarkWithSize:(CGFloat)size {
    NSMutableAttributedString *mark = [[NSMutableAttributedString alloc] init];
    [mark appendAttributedString:[[NSAttributedString alloc] initWithString:@"HCG " attributes:@{
        NSFontAttributeName : [UIFont systemFontOfSize:size weight:UIFontWeightHeavy],
        NSForegroundColorAttributeName : [self cyan],
        NSKernAttributeName : @(1.5),
    }]];
    [mark appendAttributedString:[[NSAttributedString alloc] initWithString:@"NEXUS" attributes:@{
        NSFontAttributeName : [UIFont systemFontOfSize:size weight:UIFontWeightLight],
        NSForegroundColorAttributeName : [self primaryText],
        NSKernAttributeName : @(4.0),
    }]];
    return mark;
}

+ (UIView *)makePanelBackgroundWithCornerRadius:(CGFloat)radius {
    return [self makePanelBackgroundWithCornerRadius:radius settings:nil];
}

+ (BOOL)decorativeMotionAllowedWithSettings:(HCGSettings *)settings {
    if (UIAccessibilityIsReduceMotionEnabled()) return NO;
    return settings == nil || settings.animationsEnabled;
}

+ (void)styleCard:(UIView *)view cornerRadius:(CGFloat)radius {
    view.backgroundColor = [self glassRow];
    view.layer.cornerRadius = radius;
    view.layer.cornerCurve = kCACornerCurveContinuous;
    view.layer.borderWidth = [self increaseContrast] ? 1.0 : 0.5;
    view.layer.borderColor = [self hairline].CGColor;
    view.clipsToBounds = YES;
}

+ (UIView *)makePanelBackgroundWithCornerRadius:(CGFloat)radius settings:(HCGSettings *)settings {
    HCGSettings *s = settings ?: [HCGSettings defaultSettings];
    BOOL reduce = [self reduceTransparency];
    HCGPanelBlur blur = [s effectivePanelBlurWithReduceTransparency:reduce];
    CGFloat tintAlpha = (CGFloat)[s effectivePanelOpacityWithReduceTransparency:reduce];
    UIView *container = [[UIView alloc] init];
    container.userInteractionEnabled = NO;
    container.layer.cornerRadius = radius;
    container.layer.cornerCurve = kCACornerCurveContinuous;
    container.clipsToBounds = YES;

    if (blur != HCGPanelBlurOff) {
        UIBlurEffectStyle style = blur == HCGPanelBlurLight ? UIBlurEffectStyleSystemUltraThinMaterialDark
                                : (blur == HCGPanelBlurStrong ? UIBlurEffectStyleSystemThickMaterialDark : UIBlurEffectStyleSystemThinMaterialDark);
        UIVisualEffectView *effect = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:style]];
        effect.frame = container.bounds;
        effect.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [container addSubview:effect];
    }
    // Smoked tint: obsidian with a faint violet cast toward the bottom.
    UIView *tint = [[UIView alloc] initWithFrame:container.bounds];
    tint.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    tint.backgroundColor = RGB(10, 13, 18, tintAlpha);
    [container addSubview:tint];
    if (!reduce) {
        CAGradientLayer *cast = [CAGradientLayer layer];
        cast.colors = @[ (id)[UIColor clearColor].CGColor, (id)RGB(90, 70, 190, 0.10).CGColor ];
        cast.startPoint = CGPointMake(0.5, 0.35);
        cast.endPoint = CGPointMake(0.5, 1.0);
        cast.frame = CGRectMake(0, 0, 2000, 2000);
        UIView *castView = [[UIView alloc] initWithFrame:container.bounds];
        castView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        castView.clipsToBounds = YES;
        [castView.layer addSublayer:cast];
        [container addSubview:castView];
    }

    // Faint cyan rim light along the top edge.
    CAGradientLayer *rim = [CAGradientLayer layer];
    rim.colors = @[ (id)[UIColor clearColor].CGColor, (id)[[self cyan] colorWithAlphaComponent:0.55].CGColor, (id)[UIColor clearColor].CGColor ];
    rim.startPoint = CGPointMake(0, 0.5);
    rim.endPoint = CGPointMake(1, 0.5);
    UIView *rimView = [[UIView alloc] init];
    rimView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleBottomMargin;
    rimView.frame = CGRectMake(radius, 0, MAX(0, container.bounds.size.width - 2 * radius), 1);
    [rimView.layer addSublayer:rim];
    rim.frame = CGRectMake(0, 0, 2000, 1);
    rimView.clipsToBounds = YES;
    [container addSubview:rimView];

    HCGChromeBorderView *border = [[HCGChromeBorderView alloc] initWithFrame:container.bounds];
    border.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    border.cornerRadius = radius;
    border.lineWidth = [self increaseContrast] ? 1.5 : 1.0;
    [container addSubview:border];
    return container;
}

+ (void)styleTableView:(UITableView *)tableView {
    tableView.backgroundColor = [UIColor clearColor];
    tableView.separatorColor = [self separator];
    tableView.indicatorStyle = UIScrollViewIndicatorStyleWhite;
    tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
#if defined(__IPHONE_15_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_15_0
    if (@available(iOS 15.0, *)) tableView.sectionHeaderTopPadding = 8;
#endif
    tableView.estimatedRowHeight = 56;
    tableView.rowHeight = UITableViewAutomaticDimension;
}

+ (void)styleCell:(UITableViewCell *)cell {
    cell.backgroundColor = [self glassRow];
    cell.textLabel.textColor = [self primaryText];
    cell.textLabel.font = [self fontForTextStyle:UIFontTextStyleBody weight:UIFontWeightMedium];
    cell.textLabel.adjustsFontForContentSizeCategory = YES;
    cell.textLabel.numberOfLines = 0;
    cell.detailTextLabel.textColor = [self secondaryText];
    cell.detailTextLabel.font = [self fontForTextStyle:UIFontTextStyleFootnote weight:UIFontWeightRegular];
    cell.detailTextLabel.adjustsFontForContentSizeCategory = YES;
    cell.detailTextLabel.numberOfLines = 0;
    cell.tintColor = [self cyan];
    UIView *selected = [[UIView alloc] init];
    selected.backgroundColor = [self cyanSoft];
    cell.selectedBackgroundView = selected;
}

+ (UIImage *)symbolNamed:(NSString *)name pointSize:(CGFloat)size {
    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:size weight:UIImageSymbolWeightMedium];
    UIImage *image = name.length ? [UIImage systemImageNamed:name withConfiguration:config] : nil;
    if (!image) image = [UIImage systemImageNamed:@"app.dashed" withConfiguration:config];
    return image;
}

@end

@implementation HCGChromeBorderView {
    CAGradientLayer *_gradient;
    CAShapeLayer *_mask;
}

- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.userInteractionEnabled = NO;
        self.backgroundColor = [UIColor clearColor];
        _lineWidth = 1.0;
        _gradient = [CAGradientLayer layer];
        _gradient.colors = [HCGTheme chromeGradientColors];
        _gradient.startPoint = CGPointMake(0, 0);
        _gradient.endPoint = CGPointMake(1, 1);
        _mask = [CAShapeLayer layer];
        _mask.fillColor = [UIColor clearColor].CGColor;
        _mask.strokeColor = [UIColor blackColor].CGColor;
        _gradient.mask = _mask;
        [self.layer addSublayer:_gradient];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    _gradient.frame = self.bounds;
    _gradient.colors = [HCGTheme chromeGradientColors];
    CGRect inset = CGRectInset(self.bounds, self.lineWidth / 2.0, self.lineWidth / 2.0);
    _mask.lineWidth = self.lineWidth;
    _mask.path = [UIBezierPath bezierPathWithRoundedRect:inset cornerRadius:MAX(0, self.cornerRadius - self.lineWidth / 2.0)].CGPath;
}

@end

@implementation HCGGlowLineView {
    CAGradientLayer *_line;
    CAGradientLayer *_highlight;
    BOOL _animating;
}

- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.userInteractionEnabled = NO;
        self.isAccessibilityElement = NO;
        _line = [CAGradientLayer layer];
        _line.colors = @[ (id)[[HCGTheme cyan] colorWithAlphaComponent:0.0].CGColor, (id)[[HCGTheme cyan] colorWithAlphaComponent:0.75].CGColor,
                          (id)[[HCGTheme violet] colorWithAlphaComponent:0.65].CGColor, (id)[[HCGTheme violet] colorWithAlphaComponent:0.0].CGColor ];
        _line.startPoint = CGPointMake(0, 0.5);
        _line.endPoint = CGPointMake(1, 0.5);
        [self.layer addSublayer:_line];
        _highlight = [CAGradientLayer layer];
        _highlight.colors = @[ (id)[UIColor colorWithWhite:1 alpha:0].CGColor, (id)[UIColor colorWithWhite:1 alpha:0.85].CGColor,
                               (id)[UIColor colorWithWhite:1 alpha:0].CGColor ];
        _highlight.startPoint = CGPointMake(0, 0.5);
        _highlight.endPoint = CGPointMake(1, 0.5);
        _highlight.opacity = 0;
        [self.layer addSublayer:_highlight];
    }
    return self;
}

- (CGSize)intrinsicContentSize {
    return CGSizeMake(UIViewNoIntrinsicMetric, 1);
}

- (void)layoutSubviews {
    [super layoutSubviews];
    _line.frame = self.bounds;
    _highlight.frame = CGRectMake(-80, 0, 80, self.bounds.size.height);
}

- (BOOL)isAnimating {
    return _animating;
}

- (void)startAnimating {
    if (_animating || !self.window || ![HCGTheme decorativeMotionAllowedWithSettings:nil]) return;
    _animating = YES;
    CABasicAnimation *drift = [CABasicAnimation animationWithKeyPath:@"position.x"];
    drift.fromValue = @(-40.0);
    drift.toValue = @(self.bounds.size.width + 40.0);
    drift.duration = 2.4;
    CAAnimationGroup *cycle = [CAAnimationGroup animation];
    CABasicAnimation *fade = [CABasicAnimation animationWithKeyPath:@"opacity"];
    fade.fromValue = @(0.9);
    fade.toValue = @(0.9);
    fade.duration = 2.4;
    cycle.animations = @[ drift, fade ];
    cycle.duration = 6.0;           // 2.4 s drift, then 3.6 s rest
    cycle.repeatCount = HUGE_VALF;
    [_highlight addAnimation:cycle forKey:@"hcg.glow"];
}

- (void)stopAnimating {
    _animating = NO;
    [_highlight removeAnimationForKey:@"hcg.glow"];
}

- (void)didMoveToWindow {
    [super didMoveToWindow];
    if (!self.window) [self stopAnimating];
}

@end
