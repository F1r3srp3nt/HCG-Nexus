#import <UIKit/UIKit.h>
@class HCGSettings;
#import "HCGCommandMode.h"

NS_ASSUME_NONNULL_BEGIN

// Obsidian surfaces, brushed-chrome hairlines, restrained cyan illumination.
// All colours adapt to Increase Contrast; surfaces adapt to Reduce Transparency.
@interface HCGTheme : NSObject
+ (UIColor *)obsidian;          // deepest background
+ (UIColor *)surface;           // panel body
+ (UIColor *)raisedSurface;     // rows, fields, chips
+ (UIColor *)separator;
+ (UIColor *)primaryText;
+ (UIColor *)secondaryText;
+ (UIColor *)cyan;              // accent / illumination
+ (UIColor *)cyanSoft;          // translucent accent fill
+ (UIColor *)violet;            // restrained secondary accent
+ (UIColor *)violetSoft;
+ (UIColor *)glassRow;          // translucent row/card fill (opaque under Reduce Transparency)
+ (UIColor *)hairline;          // fine 1 px borders on cards
+ (UIColor *)warning;
+ (UIColor *)success;
+ (UIColor *)critical;
// Command Mode colour roles (Sources/Core/HCGCommandMode.h). Neutral values
// use primary text; muted ones secondary text. Never the only signal: every
// status also has a text label.
+ (UIColor *)colorForStatusRole:(HCGStatusColorRole)role;
+ (NSArray *)chromeGradientColors; // CGColorRefs for brushed-chrome strokes

// Dynamic Type font: the style's default size, scaled once for the user's text size.
+ (UIFont *)fontForTextStyle:(UIFontTextStyle)style weight:(UIFontWeight)weight;
// The same for an explicit text size (nil = the current one); used by tests.
+ (UIFont *)fontForTextStyle:(UIFontTextStyle)style weight:(UIFontWeight)weight
    compatibleWithTraitCollection:(nullable UITraitCollection *)traits;
// The same, capped: for fixed-height chrome (section bar, header buttons, chips). Pair with
// enableLargeContentViewerForButton:title: so a long press still shows the title at full size.
+ (UIFont *)fontForTextStyle:(UIFontTextStyle)style weight:(UIFontWeight)weight maximumPointSize:(CGFloat)maximum;
+ (CGFloat)defaultPointSizeForTextStyle:(UIFontTextStyle)style;
+ (void)enableLargeContentViewerForButton:(UIButton *)button title:(NSString *)title;
+ (NSAttributedString *)wordmarkWithSize:(CGFloat)size;

+ (BOOL)increaseContrast;
+ (BOOL)reduceTransparency;

// A rounded obsidian panel background with a brushed-chrome border and a faint
// cyan rim light along the top edge.
+ (UIView *)makePanelBackgroundWithCornerRadius:(CGFloat)radius;
// Smoked glass driven by the user's panel opacity and blur. Reduce Transparency
// (read live) makes it opaque and unblurred; Increase Contrast thickens borders.
+ (UIView *)makePanelBackgroundWithCornerRadius:(CGFloat)radius settings:(nullable HCGSettings *)settings;
// A card: glass row fill, hairline border, continuous corners.
+ (void)styleCard:(UIView *)view cornerRadius:(CGFloat)radius;
// Decorative motion is allowed only when the user's Animations setting is on
// and iOS Reduce Motion is off.
+ (BOOL)decorativeMotionAllowedWithSettings:(nullable HCGSettings *)settings;
+ (void)styleTableView:(UITableView *)tableView;
+ (void)styleCell:(UITableViewCell *)cell;
+ (UIImage *_Nullable)symbolNamed:(nullable NSString *)name pointSize:(CGFloat)size;
@end

// Caps used by fixed-height chrome; exposed for tests.
FOUNDATION_EXPORT const CGFloat HCGSectionBarMaximumPointSize;
FOUNDATION_EXPORT const CGFloat HCGHeaderButtonMaximumPointSize;
FOUNDATION_EXPORT const CGFloat HCGChipMaximumPointSize;

// Applies the chrome gradient stroke to its own bounds on every layout pass.
@interface HCGChromeBorderView : UIView
@property (nonatomic) CGFloat cornerRadius;
@property (nonatomic) CGFloat lineWidth;
@end

// A 1 pt cyan→violet line. When animating, a faint highlight drifts along it
// (one pass every 6 s). Call -stopAnimating when the panel closes; it also
// stops itself when it leaves the window.
@interface HCGGlowLineView : UIView
- (void)startAnimating;
- (void)stopAnimating;
@property (nonatomic, readonly, getter=isAnimating) BOOL animating;
@end

NS_ASSUME_NONNULL_END
