#import <UIKit/UIKit.h>
#import "HCGNexusModel.h"
#import "HCGActionRunner.h"

NS_ASSUME_NONNULL_BEGIN

// Everything a panel screen needs, passed down the navigation stack.
@interface HCGPanelContext : NSObject
@property (nonatomic, strong) HCGNexusModel *model;
@property (nonatomic, strong, nullable) HCGActionRunner *runner;      // nil in Settings.app
@property (nonatomic, copy) NSString *environmentName;               // "SpringBoard", "Preview harness", "Settings"
@property (nonatomic) BOOL isPreview;
@property (nonatomic, copy, nullable) void (^closePanel)(void);       // animated close
@property (nonatomic, copy, nullable) void (^closePanelImmediately)(void);
@property (nonatomic, copy, nullable) NSDictionary *_Nonnull (^diagnosticsProvider)(void);
@property (nonatomic, readonly) BOOL insideOverlay;                  // closePanel != nil
@end

// Presents an error with its recovery suggestion as an accessible alert.
FOUNDATION_EXPORT void HCGPresentError(UIViewController *presenter, NSError *error, UIAlertAction *_Nullable extraAction);

NS_ASSUME_NONNULL_END
