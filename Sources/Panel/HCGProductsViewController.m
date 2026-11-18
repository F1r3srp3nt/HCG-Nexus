#import "HCGProductsViewController.h"
#import "HCGTheme.h"
#import "HCGPanelSettingsViewController.h"

@implementation HCGProductsViewController {
    NSArray<HCGProductInfo *> *_phoneApps;
    NSArray<HCGProductInfo *> *_other;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"HCG Products";
    NSMutableArray *phone = [NSMutableArray array], *other = [NSMutableArray array];
    for (HCGProductInfo *product in [HCGProductCatalog allProducts]) [(product.hasPhoneApp ? phone : other) addObject:product];
    _phoneApps = phone;
    _other = other;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.tableView reloadData]; // re-check installation each time the section is shown
}

- (id<HCGAppInstallationProbe>)probe {
    return self.context.model.launcher;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return section == 0 ? @"iPhone apps" : @"Desktop and server";
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == 0) {
        return @"\"Installed\" only means the app is on this device. Account connection is a separate state: no HCG app shares its sign-in with Nexus today.";
    }
    return nil;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return (NSInteger)(section == 0 ? _phoneApps.count : _other.count);
}

- (HCGProductInfo *)productAt:(NSIndexPath *)indexPath {
    return (indexPath.section == 0 ? _phoneApps : _other)[(NSUInteger)indexPath.row];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    HCGProductInfo *product = [self productAt:indexPath];
    HCGProductInstallState install = [HCGProductCatalog installStateForProduct:product probe:[self probe]];
    UITableViewCell *cell = [self styledCellWithStyle:UITableViewCellStyleSubtitle identifier:@"product"];
    cell.textLabel.text = product.name;
    cell.imageView.image = [HCGTheme symbolNamed:product.symbolName pointSize:18];
    NSString *installText = [HCGProductCatalog titleForInstallState:install];
    cell.detailTextLabel.text = product.hasPhoneApp ? [NSString stringWithFormat:@"%@ · Account: not shared", installText]
                                                    : [NSString stringWithFormat:@"%@ · %@", product.platform, installText];
    cell.imageView.tintColor = install == HCGProductInstallStateInstalled ? [HCGTheme cyan] : [HCGTheme secondaryText];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator; // the whole row opens the details (44 pt+)
    cell.accessibilityHint = @"Shows status, routes and what you can do next.";
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    [self showProduct:[self productAt:indexPath]];
}

- (void)showProduct:(HCGProductInfo *)product {
    HCGProductInstallState install = [HCGProductCatalog installStateForProduct:product probe:[self probe]];
    HCGProductLaunchState launch = [HCGProductCatalog launchStateForProduct:product probe:[self probe]];
    NSMutableString *message = [NSMutableString string];
    [message appendFormat:@"Installed: %@\n", [HCGProductCatalog titleForInstallState:install]];
    [message appendFormat:@"Account: %@\n", [HCGProductCatalog accountStateTextForProduct:product]];
    if (product.integrationIdentifier) {
        HCGIntegrationStatus *status = [self.context.model statusForIntegration:product.integrationIdentifier];
        [message appendFormat:@"Panel integration: %@\n", status.state == HCGIntegrationStateNotConnected ? @"off (Settings › Integrations)" : status.headline];
    }
    [message appendFormat:@"\nRoutes: %@\n\nNext: %@", product.routesSummary, [HCGProductCatalog nextStepForProduct:product launchState:launch]];

    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:product.name message:message preferredStyle:UIAlertControllerStyleAlert];
    sheet.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    __weak typeof(self) weakSelf = self;
    if (launch == HCGProductLaunchStateAvailable || launch == HCGProductLaunchStateAttempt) {
        [sheet addAction:[UIAlertAction actionWithTitle:[@"Open " stringByAppendingString:product.name] style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
            [weakSelf openProduct:product];
        }]];
        if ([product.identifier isEqualToString:HCGProductSentinel]) {
            [sheet addAction:[UIAlertAction actionWithTitle:@"Open a Sentinel screen…" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
                [weakSelf chooseSentinelSection];
            }]];
        }
    }
    if (product.integrationIdentifier && self.context.overlayControlsOperational) {
        [sheet addAction:[UIAlertAction actionWithTitle:@"Integration Settings" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
            [weakSelf.navigationController pushViewController:[[HCGPanelSettingsViewController alloc] initWithContext:weakSelf.context]
                                                     animated:!UIAccessibilityIsReduceMotionEnabled()];
        }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"Close" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)finishLaunch:(NSError *)error name:(NSString *)name {
    if (error) {
        HCGPresentError(self, error, nil);
        return;
    }
    if (self.context.insideOverlay && !self.context.isPreview && self.context.closePanelImmediately) {
        self.context.closePanelImmediately();
    } else {
        [self.context feedback:[NSString stringWithFormat:@"Opened %@.", name] success:YES];
    }
}

- (void)openProduct:(HCGProductInfo *)product {
    id<HCGLauncher> launcher = self.context.model.launcher;
    if (!launcher || !product.bundleIdentifier) {
        [self.context feedback:@"This build can't open apps." success:NO];
        return;
    }
    __weak typeof(self) weakSelf = self;
    [launcher openApplicationWithBundleIdentifier:product.bundleIdentifier completion:^(NSError *error) {
        [weakSelf finishLaunch:error name:product.name];
    }];
}

- (void)chooseSentinelSection {
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"Open in HCG Sentinel"
                                                                   message:@"Navigation only: these links never start a scan, connect, change a setting or delete data."
                                                            preferredStyle:UIAlertControllerStyleAlert];
    sheet.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    __weak typeof(self) weakSelf = self;
    for (NSString *section in [HCGSentinelLinks sections]) {
        NSURL *url = [HCGSentinelLinks URLForSection:section];
        if (!url || [HCGSentinelLinks problemWithURLString:url.absoluteString]) continue; // validated with Sentinel's own rules
        [sheet addAction:[UIAlertAction actionWithTitle:section.capitalizedString style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
            id<HCGLauncher> launcher = weakSelf.context.model.launcher;
            if (!launcher) return;
            [launcher openURL:url completion:^(NSError *error) {
                [weakSelf finishLaunch:error name:[@"Sentinel " stringByAppendingString:section]];
            }];
        }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:sheet animated:YES completion:nil];
}

@end
