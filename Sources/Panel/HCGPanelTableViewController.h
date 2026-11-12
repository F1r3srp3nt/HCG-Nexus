#import <UIKit/UIKit.h>
#import "HCGPanelContext.h"

NS_ASSUME_NONNULL_BEGIN

// Shared styling and model-change observation for panel table screens.
@interface HCGPanelTableViewController : UITableViewController
- (instancetype)initWithContext:(HCGPanelContext *)context;
@property (nonatomic, readonly) HCGPanelContext *context;
- (void)modelDidChange; // override to refresh; default reloads the table
- (UITableViewCell *)styledCellWithStyle:(UITableViewCellStyle)style identifier:(NSString *)identifier;
// Text entry alert (rename/create). Validation errors are re-presented.
- (void)promptForTextWithTitle:(NSString *)title
                       message:(nullable NSString *)message
                   placeholder:(NSString *)placeholder
                  initialValue:(nullable NSString *)initialValue
                   actionTitle:(NSString *)actionTitle
                       handler:(BOOL (^)(NSString *text, NSError *_Nullable *_Nullable error))handler;
@end

NS_ASSUME_NONNULL_END
