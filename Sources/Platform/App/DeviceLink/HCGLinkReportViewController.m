#import "HCGLinkReportViewController.h"
#import "HCGTheme.h"

@implementation HCGLinkReportViewController

- (instancetype)initWithContext:(HCGPanelContext *)context report:(HCGLinkOpenedReport *)report {
    if ((self = [super initWithContext:context])) {
        _report = report;
    }
    return self;
}

+ (NSString *)headerTextForReport:(HCGLinkOpenedReport *)report {
    NSString *from = report.fromName.length ? report.fromName : @"another device";
    return [NSString stringWithFormat:@"Report from %@ (remote) — data only, never executed", from];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Shared Report";
    self.tableView.allowsSelection = NO;
}

- (NSString *)receivedText {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateStyle = NSDateFormatterMediumStyle;
    formatter.timeStyle = NSDateFormatterShortStyle;
    return [formatter stringFromDate:self.report.receivedAt];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1 + (NSInteger)self.report.sections.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 0) return @"Shared report";
    return self.report.sections[(NSUInteger)section - 1].title;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section != 0) return nil;
    return @"HCG Nexus shows shared reports as plain text. Nothing in a report is opened, turned into a link, run as a command or executed.";
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) return 1;
    return MAX(1, (NSInteger)self.report.sections[(NSUInteger)section - 1].lines.count);
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        UITableViewCell *cell = [self styledCellWithStyle:UITableViewCellStyleSubtitle identifier:@"report-header"];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.textLabel.text = [HCGLinkReportViewController headerTextForReport:self.report];
        cell.textLabel.font = [HCGTheme fontForTextStyle:UIFontTextStyleHeadline weight:UIFontWeightSemibold];
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%@\nSent by %@ (%@) · received %@",
                                     self.report.title, self.report.fromName, self.report.fromApp, [self receivedText]];
        cell.imageView.image = [HCGTheme symbolNamed:@"doc.plaintext" pointSize:17];
        return cell;
    }
    // Plain UILabel text only: labels never detect or open links.
    UITableViewCell *cell = [self styledCellWithStyle:UITableViewCellStyleDefault identifier:@"report-line"];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.textLabel.font = [HCGTheme fontForTextStyle:UIFontTextStyleCallout weight:UIFontWeightRegular];
    NSArray<NSString *> *lines = self.report.sections[(NSUInteger)indexPath.section - 1].lines;
    cell.textLabel.text = lines.count ? lines[(NSUInteger)indexPath.row] : @"(empty)";
    if (!lines.count) cell.textLabel.textColor = [HCGTheme secondaryText];
    return cell;
}

@end
