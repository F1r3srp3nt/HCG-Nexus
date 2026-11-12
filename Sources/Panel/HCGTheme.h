#import <UIKit/UIKit.h>

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
+ (UIColor *)warning;
+ (UIColor *)success;
+ (NSArray *)chromeGradientColors; // CGColorRefs for brushed-chrome strokes

+ (UIFont *)fontForTextStyle:(UIFontTextStyle)style weight:(UIFontWeight)weight;
+ (NSAttributedString *)wordmarkWithSize:(CGFloat)size;

+ (BOOL)increaseContrast;
+ (BOOL)reduceTransparency;

// A rounded obsidian panel background with a brushed-chrome border and a faint
// cyan rim light along the top edge.
+ (UIView *)makePanelBackgroundWithCornerRadius:(CGFloat)radius;
+ (void)styleTableView:(UITableView *)tableView;
+ (void)styleCell:(UITableViewCell *)cell;
+ (UIImage *_Nullable)symbolNamed:(nullable NSString *)name pointSize:(CGFloat)size;
@end

// Applies the chrome gradient stroke to its own bounds on every layout pass.
@interface HCGChromeBorderView : UIView
@property (nonatomic) CGFloat cornerRadius;
@property (nonatomic) CGFloat lineWidth;
@end

NS_ASSUME_NONNULL_END
