#import "HCGRoadmapViewController.h"
#import "HCGCommandCenterViewController.h"
#import "HCGProductProfileViewController.h"
#import "HCGTheme.h"

@implementation HCGRoadmapViewController {
    HCGCommandCenterSnapshot *_snapshot;
    NSArray<NSArray *> *_groups;      // (state NSNumber, items)
    NSArray<HCGDevelopmentGap *> *_gaps;
    HCGLifeOSExport *_export;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Roadmap";
    self.tableView.estimatedRowHeight = 60;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    _groups = @[];
    _gaps = @[];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    __weak typeof(self) weakSelf = self;
    [HCGCommandCenterData loadWithModel:self.context.model completion:^(HCGCommandCenterSnapshot *snapshot) {
        typeof(self) s = weakSelf;
        if (!s) return;
        s->_snapshot = snapshot;
        [s rebuild];
    }];
}

- (void)rebuild {
    NSMutableArray *groups = [NSMutableArray array];
    NSInteger state;
    for (state = HCGRoadmapStateCount - 1; state >= 0; state--) {
        NSMutableArray *items = [NSMutableArray array];
        for (HCGCommandCenterItem *i in _snapshot.items) if (i.roadmap.state == (HCGRoadmapState)state) [items addObject:i];
        if (items.count) [groups addObject:@[ @(state), items ]];
    }
    _groups = groups;
    NSMutableArray *entries = [NSMutableArray array];
    for (HCGCommandCenterItem *i in _snapshot.items) [entries addObject:i.entry];
    _gaps = [HCGCommandCenter gapsForEntries:entries];
    _export = [HCGCommandCenter lifeOSExportForGaps:_gaps exported:[self.context.model lifeOSExported] registryVersion:_snapshot.registry.version
                                          requestID:[[NSUUID UUID].UUIDString lowercaseString] now:[NSDate date]];
    [self.tableView reloadData];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2 + (NSInteger)_groups.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) return 1;
    if (section == 1) return (NSInteger)_gaps.count;
    return (NSInteger)[_groups[(NSUInteger)section - 2][1] count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 0) return @"HCG LifeOS";
    if (section == 1) {
        NSUInteger blocking = 0;
        for (HCGDevelopmentGap *g in _gaps) if (g.blocking) blocking++;
        return [NSString stringWithFormat:@"Development gaps · %lu (%lu blocking)", (unsigned long)_gaps.count, (unsigned long)blocking];
    }
    NSArray *g = _groups[(NSUInteger)section - 2];
    return [NSString stringWithFormat:@"%@ · %lu", [HCGCommandCenter titleForRoadmapState:(HCGRoadmapState)[g[0] integerValue]], (unsigned long)[g[1] count]];
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == 0) {
        return @"A lifeos.v1 import file: you preview and import it in HCG LifeOS, which checks for duplicates. Each gap has a stable ID, so exporting again adds nothing twice. No XP is ever awarded for these tasks.";
    }
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [self styledCellWithStyle:UITableViewCellStyleSubtitle identifier:@"row"];
    cell.textLabel.numberOfLines = 0;
    cell.detailTextLabel.numberOfLines = 0;
    cell.textLabel.textColor = [HCGTheme primaryText];
    if (indexPath.section == 0) {
        BOOL can = [HCGFileExchange availableInContext:self.context];
        NSUInteger tasks = _export.included.count - ([_export.included containsObject:@"nexus.ecosystem"] ? 1 : 0);
        cell.textLabel.text = _export.payload ? @"Export to HCG LifeOS" : @"Nothing new to export";
        cell.textLabel.textColor = _export.payload && can ? [HCGTheme cyan] : [HCGTheme secondaryText];
        NSMutableArray *parts = [NSMutableArray array];
        if (_export.payload) [parts addObject:[NSString stringWithFormat:@"%lu new task%@", (unsigned long)tasks, tasks == 1 ? @"" : @"s"]];
        if (_export.alreadyExported) [parts addObject:[NSString stringWithFormat:@"%lu already exported", (unsigned long)_export.alreadyExported]];
        if (_export.changed.count) [parts addObject:[NSString stringWithFormat:@"%lu changed since export (update them in LifeOS)", (unsigned long)_export.changed.count]];
        if (!can) [parts addObject:@"Export from the HCG Nexus app or Settings › HCG Nexus"];
        cell.detailTextLabel.text = [parts componentsJoinedByString:@" · "];
        cell.imageView.image = [HCGTheme symbolNamed:@"square.and.arrow.up" pointSize:16];
        cell.selectionStyle = _export.payload && can ? UITableViewCellSelectionStyleDefault : UITableViewCellSelectionStyleNone;
        cell.accessoryType = UITableViewCellAccessoryNone;
        return cell;
    }
    if (indexPath.section == 1) {
        HCGDevelopmentGap *g = _gaps[(NSUInteger)indexPath.row];
        cell.textLabel.text = [NSString stringWithFormat:@"%@: %@", g.productName, g.title];
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%@%@ · %@", g.blocking ? @"Blocking · " : @"", g.kind, g.stableID];
        cell.imageView.image = [HCGTheme symbolNamed:g.blocking ? @"exclamationmark.octagon" : @"wrench.and.screwdriver" pointSize:15];
        cell.imageView.tintColor = g.blocking ? [HCGTheme warning] : [HCGTheme secondaryText];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        return cell;
    }
    HCGCommandCenterItem *item = _groups[(NSUInteger)indexPath.section - 2][1][(NSUInteger)indexPath.row];
    cell.textLabel.text = item.entry.officialName;
    cell.detailTextLabel.text = item.roadmap.evidence;
    cell.imageView.image = [HCGTheme symbolNamed:@"map" pointSize:15];
    cell.imageView.tintColor = HCGCommandCenterColorForConnection(item.connection.state);
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    BOOL animated = !UIAccessibilityIsReduceMotionEnabled();
    if (indexPath.section == 0) {
        if (!_export.payload || ![HCGFileExchange availableInContext:self.context]) return;
        NSData *data = [NSJSONSerialization dataWithJSONObject:_export.payload options:NSJSONWritingPrettyPrinted error:NULL];
        if (!data) return;
        HCGLifeOSExport *x = _export;
        __weak typeof(self) weakSelf = self;
        [HCGFileExchange shareData:data fileName:@"hcg-nexus-lifeos-import.json" from:self sourceView:[tableView cellForRowAtIndexPath:indexPath]
                        completion:^(BOOL saved) {
            typeof(self) s = weakSelf;
            if (!s || !saved) return; // marked as exported only when the file was actually saved or shared
            [s.context.model markLifeOSExport:x];
            [s.context.model recordEcosystemActivity:[NSString stringWithFormat:@"Exported %lu development gaps for HCG LifeOS", (unsigned long)x.included.count] productID:nil];
            [s rebuild];
        }];
        return;
    }
    NSString *entryID = indexPath.section == 1 ? _gaps[(NSUInteger)indexPath.row].productID
                                               : ((HCGCommandCenterItem *)_groups[(NSUInteger)indexPath.section - 2][1][(NSUInteger)indexPath.row]).entry.identifier;
    [self.navigationController pushViewController:[[HCGProductProfileViewController alloc] initWithContext:self.context entryID:entryID] animated:animated];
}

@end

@implementation HCGRegistryInfoViewController {
    HCGRegistry *_registry;
    HCGCentralSnapshot *_central;
    HCGCentralSnapshot *_previous;
    NSUInteger _matched;
    BOOL _fetching;
}

typedef NS_ENUM(NSInteger, HCGRegistrySection) { HCGRegistrySectionInfo = 0, HCGRegistrySectionCentral, HCGRegistrySectionUpdates, HCGRegistrySectionProblems };

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Registry";
    self.tableView.estimatedRowHeight = 52;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self reload];
}

- (void)reload {
    _registry = [self.context.model ecosystemRegistry];
    _central = [self.context.model centralSnapshot];
    _previous = [self.context.model previousCentralSnapshot];
    _matched = 0;
    if (_central) [[HCGRegistry builtInRegistry] registryByApplyingCentralSnapshot:_central matched:&_matched];
    [self.tableView reloadData];
}

static NSString *ShortDate(NSDate *d) {
    NSDateFormatter *f = [[NSDateFormatter alloc] init];
    f.dateStyle = NSDateFormatterMediumStyle;
    f.timeStyle = NSDateFormatterShortStyle;
    return [f stringFromDate:d];
}

- (NSArray<NSArray<NSString *> *> *)centralRows {
    NSMutableArray *rows = [NSMutableArray array];
    [rows addObject:@[ @"Source", @"beta.hakmicapitalgroup.com · public product catalogue", @"" ]];
    if (_central) {
        [rows addObject:@[ @"Snapshot", [NSString stringWithFormat:@"%@ · %lu products · fetched %@", _central.version, (unsigned long)_central.products.count, ShortDate(_central.fetchedAt)], @"" ]];
        [rows addObject:@[ @"Applied", [NSString stringWithFormat:@"Names and release status of %lu Nexus products", (unsigned long)_matched], @"" ]];
    } else {
        [rows addObject:@[ @"Snapshot", @"None: using the built-in registry (works offline)", @"" ]];
    }
    [rows addObject:@[ _fetching ? @"Updating…" : @"Update from central registry", @"A read-only request; sends no account, key or cookie", @"fetch" ]];
    if (_previous) [rows addObject:@[ @"Restore previous snapshot", [NSString stringWithFormat:@"%@ · fetched %@", _previous.version, ShortDate(_previous.fetchedAt)], @"revert" ]];
    if (_central) [rows addObject:@[ @"Use built-in registry only", @"Forget the central snapshots on this iPhone", @"clear" ]];
    return rows;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return _registry.problems.count ? 4 : 3;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch (section) {
        case HCGRegistrySectionInfo: return 4;
        case HCGRegistrySectionCentral: return (NSInteger)[self centralRows].count;
        case HCGRegistrySectionUpdates: return [self.context.model hasRegistryUpdate] ? 2 : 1;
        default: return (NSInteger)MIN(_registry.problems.count, (NSUInteger)20);
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    switch (section) {
        case HCGRegistrySectionInfo: return @"HCG ecosystem registry";
        case HCGRegistrySectionCentral: return @"Central registry";
        case HCGRegistrySectionUpdates: return @"Imported updates";
        default: return @"Ignored parts";
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == HCGRegistrySectionCentral) {
        return @"The central HCG registry is the authority for product names, IDs and release status. It only updates products Nexus already lists, and never adds links, connections or permissions: being registered grants nothing. The current and previous snapshots are kept for rollback.";
    }
    if (section == HCGRegistrySectionUpdates) {
        return @"An imported update (hcg.nexus.registry/1, higher version) can change descriptions and status, or suspend and retire products. It can never change a product's name, central ID or registration, add a link, endpoint or connection, grant access, or add validation history.";
    }
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [self styledCellWithStyle:UITableViewCellStyleSubtitle identifier:@"r"];
    cell.detailTextLabel.numberOfLines = 0;
    cell.textLabel.numberOfLines = 0;
    cell.textLabel.textColor = [HCGTheme primaryText];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    if (indexPath.section == HCGRegistrySectionInfo) {
        NSArray *rows = @[ @[ @"Version", [NSString stringWithFormat:@"%ld", (long)_registry.version] ], @[ @"Source", _registry.source ],
                           @[ @"Verified", _registry.generatedAt ],
                           @[ @"Contents", [NSString stringWithFormat:@"%lu products, %lu categories, %lu device classes", (unsigned long)_registry.entries.count,
                                            (unsigned long)_registry.categories.count, (unsigned long)_registry.deviceClasses.count] ] ];
        cell.textLabel.text = rows[(NSUInteger)indexPath.row][0];
        cell.detailTextLabel.text = rows[(NSUInteger)indexPath.row][1];
        return cell;
    }
    if (indexPath.section == HCGRegistrySectionCentral) {
        NSArray *row = [self centralRows][(NSUInteger)indexPath.row];
        cell.textLabel.text = row[0];
        cell.detailTextLabel.text = row[1];
        if ([row[2] length]) {
            cell.textLabel.textColor = [row[2] isEqualToString:@"clear"] ? [HCGTheme critical] : [HCGTheme cyan];
            cell.selectionStyle = UITableViewCellSelectionStyleDefault;
        }
        return cell;
    }
    if (indexPath.section == HCGRegistrySectionUpdates) {
        BOOL can = [HCGFileExchange availableInContext:self.context];
        if (indexPath.row == 0) {
            cell.textLabel.text = @"Import registry update…";
            cell.detailTextLabel.text = can ? nil : @"In the HCG Nexus app or Settings";
            cell.textLabel.textColor = can ? [HCGTheme cyan] : [HCGTheme secondaryText];
            cell.selectionStyle = can ? UITableViewCellSelectionStyleDefault : UITableViewCellSelectionStyleNone;
        } else {
            cell.textLabel.text = @"Remove imported update";
            cell.detailTextLabel.text = nil;
            cell.textLabel.textColor = [HCGTheme critical];
            cell.selectionStyle = UITableViewCellSelectionStyleDefault;
        }
        return cell;
    }
    cell.textLabel.text = _registry.problems[(NSUInteger)indexPath.row];
    cell.detailTextLabel.text = nil;
    return cell;
}

- (void)fetchCentral {
    if (_fetching) return;
    if (self.context.isPreview) {
        [self.context feedback:@"The preview harness does not make network requests." success:NO];
        return;
    }
    _fetching = YES;
    [self.tableView reloadData];
    __weak typeof(self) weakSelf = self;
    [[HCGPublicReader sharedReader] getURLString:HCGCentralRegistryURL completion:^(NSData *data, NSString *state) {
        typeof(self) s = weakSelf;
        if (!s) return;
        s->_fetching = NO;
        NSString *error = nil;
        HCGCentralSnapshot *snap = data ? [HCGCentralSnapshot snapshotWithData:data fetchedAt:[NSDate date] error:&error] : nil;
        if (snap) {
            [s.context.model saveCentralSnapshot:snap];
            NSString *text = [NSString stringWithFormat:@"Read the central registry (%lu products, version %@).", (unsigned long)snap.products.count, snap.version];
            [s.context.model recordConnectionForProduct:@"central-app-access" method:@"https-api" success:YES text:text];
            [s.context feedback:text success:YES];
        } else {
            NSString *why = [NSString stringWithFormat:@"Central registry not updated: %@", error ?: state];
            [s.context.model recordConnectionForProduct:@"central-app-access" method:@"https-api" success:NO text:why];
            [s.context feedback:[why stringByAppendingString:@" The last snapshot stays in use."] success:NO];
        }
        [s reload];
    }];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section == HCGRegistrySectionCentral) {
        NSString *action = [self centralRows][(NSUInteger)indexPath.row][2];
        if ([action isEqualToString:@"fetch"]) [self fetchCentral];
        else if ([action isEqualToString:@"revert"]) {
            BOOL ok = [self.context.model revertCentralSnapshot];
            [self.context feedback:ok ? @"Restored the previous central snapshot." : @"No previous snapshot." success:ok];
            [self reload];
        } else if ([action isEqualToString:@"clear"]) {
            [self.context.model clearCentralSnapshots];
            [self.context feedback:@"Using the built-in registry only." success:YES];
            [self reload];
        }
        return;
    }
    if (indexPath.section != HCGRegistrySectionUpdates) return;
    if (indexPath.row == 1) {
        [self.context.model removeRegistryUpdate];
        [self.context feedback:@"Removed the imported registry update." success:YES];
        [self reload];
        return;
    }
    if (![HCGFileExchange availableInContext:self.context]) return;
    __weak typeof(self) weakSelf = self;
    [HCGFileExchange pickJSONFrom:self completion:^(NSData *data, NSString *readError) {
        typeof(self) s = weakSelf;
        if (!s) return;
        NSString *error = readError;
        if (data && [s.context.model importRegistryUpdate:data error:&error]) {
            [s.context feedback:@"Imported the registry update (text and status only)." success:YES];
            [s.context.model recordEcosystemActivity:@"Imported an ecosystem registry update" productID:nil];
        } else {
            [s.context feedback:error ?: @"The registry update was refused." success:NO];
        }
        [s reload];
    }];
}

@end
