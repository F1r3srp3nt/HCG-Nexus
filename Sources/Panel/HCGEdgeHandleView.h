#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

// The configurable cyan edge handle: a thin illuminated sliver inside a larger,
// invisible touch target. The view's frame is the touch target; the sliver is
// positioned by the overlay controller via `visualFrame` (in own coordinates).
@interface HCGEdgeHandleView : UIView
@property (nonatomic) CGRect visualFrame;
@property (nonatomic) CGFloat illumination;  // 0.25…1 (handle visibility setting)
@property (nonatomic) BOOL onLeftEdge;
@property (nonatomic) BOOL highlighted;
@end

NS_ASSUME_NONNULL_END
