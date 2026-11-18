#import "HCGDevicesInfoViewController.h"
#import "HCGTheme.h"

@implementation HCGDevicesInfoViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Connected Devices";
}

// [title, where it lives, what it does]. Capabilities of HCG Device Link (docs/CONNECTED_DEVICES.md).
- (NSArray<NSArray<NSString *> *> *)capabilities {
    return @[
        @[ @"Pair with your HCG Server", @"Standalone app", @"Invitation code, HCG Connect sign-in and owner approval with key fingerprints." ],
        @[ @"Paired devices and presence", @"Standalone app", @"Your other HCG installations, their versions and advertised capabilities (information only)." ],
        @[ @"Shared reports", @"Standalone app", @"Receive and read reports other devices share, as plain text. Never executed or opened as links." ],
        @[ @"Remote actions", @"Not available", @"Disabled by design: no device can run commands on another." ],
    ];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return section == 0 ? @"In this build" : @"HCG Device Link capabilities";
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == 1) return @"Device Link signs in with HCG Connect and keeps keys in the app's Keychain, which is why it lives in the standalone app and not in SpringBoard.";
    return nil;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return section == 0 ? 1 : (NSInteger)[self capabilities].count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [self styledCellWithStyle:UITableViewCellStyleSubtitle identifier:@"devices"];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    if (indexPath.section == 0) {
        cell.textLabel.text = self.context.isPreview ? @"Not part of the preview harness" : @"Not part of the jailbreak package";
        cell.detailTextLabel.text = @"Connected Devices (HCG Device Link) runs in the standalone HCG Nexus app. This build never connects to HCG Server and shows no device data.";
        cell.imageView.image = [HCGTheme symbolNamed:@"info.circle" pointSize:18];
        return cell;
    }
    NSArray<NSString *> *row = [self capabilities][(NSUInteger)indexPath.row];
    cell.textLabel.text = row[0];
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ · %@", row[1], row[2]];
    BOOL available = ![row[1] isEqualToString:@"Not available"];
    cell.imageView.image = [HCGTheme symbolNamed:available ? @"iphone" : @"nosign" pointSize:17];
    cell.imageView.tintColor = available ? [HCGTheme violet] : [HCGTheme secondaryText];
    return cell;
}

@end
