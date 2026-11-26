#import "HCGDeviceClassesViewController.h"
#import "HCGCommandCenterViewController.h"
#import "HCGTheme.h"

// One device class: its devices from the inventory, adapters, missing capabilities, instructions, roadmap.
@interface HCGDeviceClassDetailViewController : HCGPanelTableViewController
- (instancetype)initWithContext:(HCGPanelContext *)context deviceClass:(HCGRegistryDeviceClass *)deviceClass;
@end

static NSString *ClassRoadmap(HCGRegistryDeviceClass *c, NSArray<HCGInventoryDevice *> *devices) {
    NSUInteger hardware = 0, working = 0;
    for (HCGInventoryDevice *d in devices) {
        if (d.synthetic) continue; // synthetic fixtures never count as evidence
        hardware++;
        if ([d.status isEqualToString:@"connected"] || [d.status isEqualToString:@"authenticated"] || [d.status isEqualToString:@"diagnosticsAvailable"]) working++;
    }
    if (!c.adapters.count) return [HCGCommandCenter titleForRoadmapState:HCGRoadmapStateAdapterDevelopmentRequired];
    if (working) return [NSString stringWithFormat:@"%@ (reported by HCG System Tester for %lu device%@)", [HCGCommandCenter titleForRoadmapState:HCGRoadmapStateConnected], (unsigned long)working, working == 1 ? @"" : @"s"];
    if (hardware) return [NSString stringWithFormat:@"%@ (%lu detected by HCG System Tester)", [HCGCommandCenter titleForRoadmapState:HCGRoadmapStateConnectionAttempted], (unsigned long)hardware];
    return [HCGCommandCenter titleForRoadmapState:HCGRoadmapStateAdapterImplemented];
}

@implementation HCGDeviceClassesViewController {
    HCGRegistry *_registry;
    HCGDeviceInventory *_inventory;
    NSArray<HCGInventoryDevice *> *_other;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Connected Devices";
    self.tableView.estimatedRowHeight = 60;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self rebuild];
}

- (void)rebuild {
    _registry = [self.context.model ecosystemRegistry];
    _inventory = [self.context.model deviceInventory];
    _other = _inventory ? [_inventory devicesInNoClassOf:_registry.deviceClasses] : @[];
    [self.tableView reloadData];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2 + (_other.count ? 1 : 0);
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) return _inventory ? 3 : 1;
    if (section == 1) return (NSInteger)_registry.deviceClasses.count;
    return (NSInteger)_other.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return section == 0 ? @"HCG System Tester" : (section == 1 ? @"Device classes" : @"Other devices");
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == 0) {
        return @"HCG System Tester runs on your Mac and stays the hardware authority: it asks before every device and adapter. Export its inventory (Ecosystem › Export device inventory) and open the file here. Nexus only reads the file.";
    }
    if (section == 1) return @"Read-only. Nexus never controls vehicles, robots or machinery and never modifies firmware. Compatibility history stays in System Tester; it is not exported yet.";
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [self styledCellWithStyle:UITableViewCellStyleSubtitle identifier:@"d"];
    cell.textLabel.numberOfLines = 0;
    cell.detailTextLabel.numberOfLines = 0;
    cell.textLabel.textColor = [HCGTheme primaryText];
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    BOOL can = [HCGFileExchange availableInContext:self.context];
    if (indexPath.section == 0) {
        if (indexPath.row == 0 && _inventory) {
            NSUInteger synthetic = 0;
            for (HCGInventoryDevice *d in _inventory.devices) if (d.synthetic) synthetic++;
            NSDateFormatter *f = [[NSDateFormatter alloc] init];
            f.dateStyle = NSDateFormatterMediumStyle;
            f.timeStyle = NSDateFormatterShortStyle;
            cell.textLabel.text = [NSString stringWithFormat:@"%lu devices", (unsigned long)_inventory.devices.count];
            cell.detailTextLabel.text = [NSString stringWithFormat:@"Exported by HCG System Tester %@ (installation …%@) on %@%@", _inventory.appVersion, _inventory.installationSuffix,
                                         [f stringFromDate:_inventory.generatedAt], synthetic ? [NSString stringWithFormat:@" · %lu SYNTHETIC", (unsigned long)synthetic] : @""];
            cell.imageView.image = [HCGTheme symbolNamed:@"list.bullet.rectangle" pointSize:16];
            return cell;
        }
        BOOL remove = _inventory && indexPath.row == 2;
        cell.textLabel.text = remove ? @"Remove imported inventory" : (_inventory ? @"Import a newer inventory…" : @"Import device inventory…");
        cell.textLabel.textColor = remove ? [HCGTheme critical] : (can ? [HCGTheme cyan] : [HCGTheme secondaryText]);
        cell.detailTextLabel.text = remove || can ? nil : @"In the HCG Nexus app or Settings › HCG Nexus";
        cell.imageView.image = [HCGTheme symbolNamed:remove ? @"trash" : @"square.and.arrow.down" pointSize:16];
        cell.selectionStyle = remove || can ? UITableViewCellSelectionStyleDefault : UITableViewCellSelectionStyleNone;
        return cell;
    }
    if (indexPath.section == 1) {
        HCGRegistryDeviceClass *c = _registry.deviceClasses[(NSUInteger)indexPath.row];
        NSArray *devices = _inventory ? [_inventory devicesInClass:c] : @[];
        cell.textLabel.text = c.name;
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%@%@", devices.count ? [NSString stringWithFormat:@"%lu device%@ · ", (unsigned long)devices.count, devices.count == 1 ? @"" : @"s"] : @"",
                                     ClassRoadmap(c, devices)];
        cell.imageView.image = [HCGTheme symbolNamed:c.symbolName pointSize:17];
        cell.imageView.tintColor = devices.count ? [HCGTheme cyan] : [HCGTheme secondaryText];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
        return cell;
    }
    HCGInventoryDevice *d = _other[(NSUInteger)indexPath.row];
    cell.textLabel.text = d.name;
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ · %@%@", d.statusTitle, d.connectionTitle, d.synthetic ? @" · SYNTHETIC" : @""];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section == 1) {
        HCGRegistryDeviceClass *c = _registry.deviceClasses[(NSUInteger)indexPath.row];
        [self.navigationController pushViewController:[[HCGDeviceClassDetailViewController alloc] initWithContext:self.context deviceClass:c]
                                             animated:!UIAccessibilityIsReduceMotionEnabled()];
        return;
    }
    if (indexPath.section != 0) return;
    if (_inventory && indexPath.row == 0) return;
    if (_inventory && indexPath.row == 2) {
        [self.context.model removeDeviceInventory];
        [self.context feedback:@"Removed the imported device inventory." success:YES];
        [self rebuild];
        return;
    }
    if (![HCGFileExchange availableInContext:self.context]) return;
    __weak typeof(self) weakSelf = self;
    [HCGFileExchange pickJSONFrom:self completion:^(NSData *data, NSString *readError) {
        typeof(self) s = weakSelf;
        if (!s) return;
        NSString *error = readError;
        if (data && [s.context.model importDeviceInventory:data error:&error]) {
            HCGDeviceInventory *inv = [s.context.model deviceInventory];
            NSString *text = [NSString stringWithFormat:@"Imported %lu devices from HCG System Tester.", (unsigned long)inv.devices.count];
            [s.context.model recordConnectionForProduct:@"system-tester" method:@"file-import" success:YES text:text];
            [s.context.model recordEcosystemActivity:text productID:nil];
            [s.context feedback:text success:YES];
        } else {
            [s.context feedback:error ?: @"The file was refused." success:NO];
        }
        [s rebuild];
    }];
}

@end

@implementation HCGDeviceClassDetailViewController {
    HCGRegistryDeviceClass *_class;
    NSArray<NSArray *> *_sections; // (title, rows of (title, detail))
}

- (instancetype)initWithContext:(HCGPanelContext *)context deviceClass:(HCGRegistryDeviceClass *)deviceClass {
    if ((self = [super initWithContext:context])) _class = deviceClass;
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = _class.name;
    self.tableView.estimatedRowHeight = 52;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    HCGDeviceInventory *inventory = [self.context.model deviceInventory];
    NSArray *devices = inventory ? [inventory devicesInClass:_class] : @[];
    NSMutableArray *sections = [NSMutableArray array];
    NSMutableArray *deviceRows = [NSMutableArray array];
    for (HCGInventoryDevice *d in devices) {
        NSMutableArray *bits = [NSMutableArray arrayWithObjects:d.statusTitle, d.connectionTitle, nil];
        if (d.model) [bits addObject:d.model];
        if (d.osVersion) [bits addObject:d.osVersion];
        if (d.synthetic) [bits addObject:@"SYNTHETIC"];
        [deviceRows addObject:@[ d.name, [bits componentsJoinedByString:@" · "] ]];
    }
    if (!deviceRows.count) [deviceRows addObject:@[ inventory ? @"None in the imported inventory" : @"No inventory imported", @"Discovery runs in HCG System Tester on your Mac." ]];
    [sections addObject:@[ @"Devices (from HCG System Tester)", deviceRows ]];
    [sections addObject:@[ @"Roadmap", @[ @[ ClassRoadmap(_class, devices), @"From HCG System Tester's adapters and the imported inventory. Synthetic devices never count." ] ] ]];
    NSMutableArray *adapters = [NSMutableArray array];
    for (NSString *a in _class.adapters) [adapters addObject:@[ a, @"Implemented in HCG System Tester" ]];
    if (!adapters.count) [adapters addObject:@[ @"No adapter yet", @"HCG System Tester has no adapter for this class." ]];
    [sections addObject:@[ @"Required adapters", adapters ]];
    NSMutableArray *missing = [NSMutableArray array];
    for (NSString *m in _class.missing) [missing addObject:@[ m, @"" ]];
    [missing addObject:@[ @"Compatibility history", @"Kept in HCG System Tester; not exported yet." ]];
    [sections addObject:@[ @"Missing capabilities", missing ]];
    [sections addObject:@[ @"How to connect", @[ @[ _class.instructions, _class.examples.count ? [@"Examples: " stringByAppendingString:[_class.examples componentsJoinedByString:@", "]] : @"" ] ] ]];
    [sections addObject:@[ @"Safety", @[ @[ _class.safety, @"" ] ] ]];
    _sections = sections;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return (NSInteger)_sections.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return (NSInteger)[_sections[(NSUInteger)section][1] count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return _sections[(NSUInteger)section][0];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSArray *row = _sections[(NSUInteger)indexPath.section][1][(NSUInteger)indexPath.row];
    UITableViewCell *cell = [self styledCellWithStyle:UITableViewCellStyleSubtitle identifier:@"c"];
    cell.textLabel.text = row[0];
    cell.textLabel.numberOfLines = 0;
    cell.detailTextLabel.text = [row[1] length] ? row[1] : nil;
    cell.detailTextLabel.numberOfLines = 0;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    return cell;
}

@end
