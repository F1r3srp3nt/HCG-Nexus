#import "HCGEdgeHandleView.h"
#import "HCGTheme.h"

@implementation HCGEdgeHandleView {
    UIView *_sliver;
    CAGradientLayer *_core;
}

- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.backgroundColor = [UIColor clearColor];
        self.isAccessibilityElement = YES;
        self.accessibilityLabel = @"HCG Nexus";
        self.accessibilityHint = @"Opens the HCG command panel.";
        self.accessibilityTraits = UIAccessibilityTraitButton;
        _illumination = 0.7;

        _sliver = [[UIView alloc] init];
        _sliver.userInteractionEnabled = NO;
        _sliver.layer.cornerRadius = 2.5;
        _sliver.layer.cornerCurve = kCACornerCurveContinuous;
        _sliver.clipsToBounds = NO;
        _sliver.layer.shadowColor = [HCGTheme cyan].CGColor;
        _sliver.layer.shadowOffset = CGSizeZero;

        _core = [CAGradientLayer layer];
        _core.cornerRadius = 2.5;
        _core.startPoint = CGPointMake(0.5, 0);
        _core.endPoint = CGPointMake(0.5, 1);
        [_sliver.layer addSublayer:_core];
        [self addSubview:_sliver];
        [self applyAppearance];
    }
    return self;
}

- (void)applyAppearance {
    CGFloat level = MAX(0.25, MIN(1.0, self.illumination));
    UIColor *cyan = [HCGTheme cyan];
    // Brushed chrome cap fading into restrained cyan.
    _core.colors = @[
        (id)[[UIColor colorWithWhite:0.86 alpha:1] colorWithAlphaComponent:level].CGColor,
        (id)[cyan colorWithAlphaComponent:level].CGColor,
        (id)[cyan colorWithAlphaComponent:level * 0.85].CGColor,
        (id)[[UIColor colorWithWhite:0.62 alpha:1] colorWithAlphaComponent:level].CGColor,
    ];
    _sliver.layer.shadowOpacity = (float)(self.highlighted ? 0.9 : 0.45 * level);
    _sliver.layer.shadowRadius = self.highlighted ? 10 : 6;
}

- (void)setIllumination:(CGFloat)illumination {
    _illumination = illumination;
    [self applyAppearance];
}

- (void)setHighlighted:(BOOL)highlighted {
    _highlighted = highlighted;
    [self applyAppearance];
}

- (void)setVisualFrame:(CGRect)visualFrame {
    _visualFrame = visualFrame;
    [self setNeedsLayout];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    _sliver.frame = self.visualFrame;
    _core.frame = _sliver.bounds;
    [CATransaction commit];
}

- (void)tintColorDidChange {
    [super tintColorDidChange];
    [self applyAppearance];
}

@end
