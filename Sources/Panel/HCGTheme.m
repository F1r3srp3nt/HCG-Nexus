#import "HCGTheme.h"

static UIColor *RGB(CGFloat r, CGFloat g, CGFloat b, CGFloat a) {
    return [UIColor colorWithRed:r / 255.0 green:g / 255.0 blue:b / 255.0 alpha:a];
}

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
+ (UIColor *)warning { return RGB(255, 184, 77, 1); }
+ (UIColor *)success { return RGB(98, 224, 160, 1); }

+ (NSArray *)chromeGradientColors {
    CGFloat boost = [self increaseContrast] ? 1.15 : 1.0;
    return @[
        (id)RGB(MIN(255, 118 * boost), MIN(255, 128 * boost), MIN(255, 140 * boost), 1).CGColor,
        (id)RGB(MIN(255, 222 * boost), MIN(255, 228 * boost), MIN(255, 236 * boost), 1).CGColor,
        (id)RGB(MIN(255, 92 * boost), MIN(255, 100 * boost), MIN(255, 112 * boost), 1).CGColor,
        (id)RGB(MIN(255, 176 * boost), MIN(255, 184 * boost), MIN(255, 194 * boost), 1).CGColor,
    ];
}

+ (UIFont *)fontForTextStyle:(UIFontTextStyle)style weight:(UIFontWeight)weight {
    UIFontDescriptor *base = [UIFontDescriptor preferredFontDescriptorWithTextStyle:style];
    UIFont *font = [UIFont systemFontOfSize:base.pointSize weight:weight];
    return [[UIFontMetrics metricsForTextStyle:style] scaledFontForFont:font];
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
    UIView *container = [[UIView alloc] init];
    container.userInteractionEnabled = NO;
    container.layer.cornerRadius = radius;
    container.layer.cornerCurve = kCACornerCurveContinuous;
    container.clipsToBounds = YES;

    if (![self reduceTransparency]) {
        UIVisualEffectView *blur = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterialDark]];
        blur.frame = container.bounds;
        blur.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [container addSubview:blur];
    }
    UIView *tint = [[UIView alloc] initWithFrame:container.bounds];
    tint.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    tint.backgroundColor = [self surface];
    [container addSubview:tint];

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
    cell.backgroundColor = [self raisedSurface];
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
