#import "HCGPanelTableViewController.h"
#import "HCGLinkTypes.h"

NS_ASSUME_NONNULL_BEGIN

// HCG Server's read-only, redacted diagnostics (HCG Device Link link/diagnostics)
// as plain text — STANDALONE APP ONLY. Nothing here is selectable, opened,
// turned into a link or acted on.
@interface HCGLinkDiagnosticsViewController : HCGPanelTableViewController
- (instancetype)initWithContext:(HCGPanelContext *)context diagnostics:(HCGLinkDiagnosticsInfo *)diagnostics;
@property (nonatomic, readonly) HCGLinkDiagnosticsInfo *diagnostics;
+ (NSString *)headerTextForDiagnostics:(HCGLinkDiagnosticsInfo *)diagnostics;
@end

NS_ASSUME_NONNULL_END
