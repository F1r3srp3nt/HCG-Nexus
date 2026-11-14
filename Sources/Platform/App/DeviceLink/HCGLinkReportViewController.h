#import "HCGPanelTableViewController.h"
#import "HCGLinkTypes.h"

NS_ASSUME_NONNULL_BEGIN

// Shows a report shared by another paired device. A report is DATA: every
// field is rendered as plain text in labels (no links, no data detectors, no
// Markdown or HTML), nothing is opened, copied into a command or executed.
@interface HCGLinkReportViewController : HCGPanelTableViewController
- (instancetype)initWithContext:(HCGPanelContext *)context report:(HCGLinkOpenedReport *)report;
@property (nonatomic, readonly) HCGLinkOpenedReport *report;
// "Report from <device> (remote) — data only, never executed"
+ (NSString *)headerTextForReport:(HCGLinkOpenedReport *)report;
@end

NS_ASSUME_NONNULL_END
