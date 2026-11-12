#import "HCGPanelTableViewController.h"
#import "HCGTheme.h"

@implementation HCGPanelTableViewController

- (instancetype)initWithContext:(HCGPanelContext *)context {
    if ((self = [super initWithStyle:UITableViewStyleInsetGrouped])) {
        _context = context;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    [HCGTheme styleTableView:self.tableView];
    // Inside the overlay the panel background shows through; in Settings.app
    // give the screen its own obsidian backdrop.
    self.tableView.backgroundColor = self.context.insideOverlay ? [UIColor clearColor] : [HCGTheme obsidian];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(modelChangedNotification:)
                                                 name:HCGNexusModelDidChangeNotification object:self.context.model];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)modelChangedNotification:(NSNotification *)note {
    if (self.isViewLoaded && !self.tableView.isEditing) [self modelDidChange];
}

- (void)modelDidChange {
    [self.tableView reloadData];
}

- (UITableViewCell *)styledCellWithStyle:(UITableViewCellStyle)style identifier:(NSString *)identifier {
    UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:identifier];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:style reuseIdentifier:identifier];
    [HCGTheme styleCell:cell];
    cell.accessoryView = nil;
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    cell.imageView.image = nil;
    cell.imageView.tintColor = [HCGTheme cyan];
    cell.textLabel.textColor = [HCGTheme primaryText];
    cell.detailTextLabel.textColor = [HCGTheme secondaryText];
    cell.accessibilityHint = nil;
    return cell;
}

- (void)tableView:(UITableView *)tableView willDisplayHeaderView:(UIView *)view forSection:(NSInteger)section {
    if ([view isKindOfClass:[UITableViewHeaderFooterView class]]) {
        UITableViewHeaderFooterView *header = (UITableViewHeaderFooterView *)view;
        header.textLabel.textColor = [HCGTheme secondaryText];
    }
}

- (void)tableView:(UITableView *)tableView willDisplayFooterView:(UIView *)view forSection:(NSInteger)section {
    if ([view isKindOfClass:[UITableViewHeaderFooterView class]]) {
        UITableViewHeaderFooterView *footer = (UITableViewHeaderFooterView *)view;
        footer.textLabel.textColor = [HCGTheme secondaryText];
    }
}

- (void)promptForTextWithTitle:(NSString *)title message:(NSString *)message placeholder:(NSString *)placeholder
                  initialValue:(NSString *)initialValue actionTitle:(NSString *)actionTitle
                       handler:(BOOL (^)(NSString *, NSError **))handler {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    alert.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.placeholder = placeholder;
        field.text = initialValue;
        field.autocapitalizationType = UITextAutocapitalizationTypeWords;
        field.clearButtonMode = UITextFieldViewModeWhileEditing;
        field.returnKeyType = UIReturnKeyDone;
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    __weak typeof(self) weakSelf = self;
    __weak UIAlertController *weakAlert = alert;
    [alert addAction:[UIAlertAction actionWithTitle:actionTitle style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *text = weakAlert.textFields.firstObject.text ?: @"";
        NSError *error = nil;
        if (!handler(text, &error) && error) {
            HCGPresentError(weakSelf, error, [UIAlertAction actionWithTitle:@"Try Again" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
                [weakSelf promptForTextWithTitle:title message:message placeholder:placeholder initialValue:text actionTitle:actionTitle handler:handler];
            }]);
        }
    }]];
    [self presentViewController:alert animated:!UIAccessibilityIsReduceMotionEnabled() completion:nil];
}

@end
