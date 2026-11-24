#import "HCGProductDetailViewController.h"
#import "HCGTheme.h"
#import "HCGEcosystemData.h"
#import "HCGProductsViewController.h"

typedef NS_ENUM(NSInteger, HCGDetailGroup) {
    HCGDetailGroupStatus = 0,
    HCGDetailGroupShortcuts,
    HCGDetailGroupSettings,
    HCGDetailGroupCapabilities,
    HCGDetailGroupAbout,
};

@implementation HCGProductDetailViewController {
    NSString *_productID;
    HCGHIPProductStatus *_status;
    HCGHIPFacts *_facts;
    NSArray<NSNumber *> *_groups;
    NSArray<NSArray<NSString *> *> *_statusRows;
    NSArray<NSDictionary *> *_shortcuts;   // {route, manager?, title}
    NSArray<NSArray<NSString *> *> *_aboutRows;
    BOOL _haloBusy;
}

- (instancetype)initWithContext:(HCGPanelContext *)context productID:(NSString *)productID {
    if ((self = [super initWithContext:context])) {
        _productID = [productID copy];
        self.title = [HCGInterchange descriptorForProductID:productID].name ?: @"HCG Product";
        _groups = @[];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.estimatedRowHeight = 56;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self reload];
}

- (void)modelDidChange {
    [self reload];
}

- (void)reload {
    __weak typeof(self) weakSelf = self;
    [HCGEcosystemData loadWithLauncher:self.context.model.launcher completion:^(HCGEcosystemSnapshot *snapshot) {
        typeof(self) strongSelf = weakSelf;
        if (!strongSelf) return;
        [strongSelf applyStatus:[snapshot statusForProductID:strongSelf->_productID] facts:[snapshot factsForProductID:strongSelf->_productID]];
    }];
}

- (void)applyStatus:(HCGHIPProductStatus *)status facts:(HCGHIPFacts *)facts {
    if (!status) return;
    _status = status;
    _facts = facts;
    HCGHIPProductDescriptor *d = status.descriptor;

    NSMutableArray *rows = [NSMutableArray array];
    [rows addObject:@[ @"State", status.simulated ? [status.stateTitle stringByAppendingString:@" (simulated)"] : status.stateTitle ]];
    [rows addObject:@[ @"Version", status.versionText ]];
    if (status.compatibilityText.length) [rows addObject:@[ @"Compatibility", status.compatibilityText ]];
    if (status.healthText.length) [rows addObject:@[ @"Health", status.healthText ]];
    if (status.integrationText.length) [rows addObject:@[ @"Integration", status.integrationText ]];
    if (status.updateText.length) [rows addObject:@[ @"HCG Repo", status.updateText ]];
    _statusRows = rows;

    NSMutableArray *shortcuts = [NSMutableArray array];
    for (HCGHIPRoute *route in status.routes) {
        if (route.kind == HCGHIPRouteKindPackageManager) {
            for (NSString *manager in facts.packageManagers) {
                NSString *name = [manager isEqualToString:@"zebra"] ? @"Zebra" : @"Sileo";
                [shortcuts addObject:@{ @"route" : route, @"manager" : manager, @"title" : [@"View in " stringByAppendingString:name] }];
            }
        } else {
            [shortcuts addObject:@{ @"route" : route, @"title" : route.title }];
        }
    }
    if (d.productPageURL.length && d.kind != HCGHIPProductKindRepository) {
        HCGHIPRoute *page = [[HCGHIPRoute alloc] init];
        page.identifier = @"product-page";
        page.title = @"Product Page in HCG Repo";
        page.symbolName = @"safari";
        page.kind = HCGHIPRouteKindWeb;
        page.target = d.productPageURL;
        page.requirement = HCGHIPRouteRequirementNone;
        page.detail = @"HCG Repo's page for this product.";
        [shortcuts addObject:@{ @"route" : page, @"title" : page.title }];
    }
    _shortcuts = shortcuts;

    NSMutableArray *about = [NSMutableArray array];
    [about addObject:@[ @"About", d.summary ]];
    if (d.packageIdentifier) [about addObject:@[ @"Package", d.packageIdentifier ]];
    if (d.bundleIdentifier) [about addObject:@[ @"App", d.bundleIdentifier ]];
    if (d.urlScheme) [about addObject:@[ @"Links", [d.urlScheme stringByAppendingString:@"://open/<screen> (navigation only)"] ]];
    if (d.minimumOSVersion) [about addObject:@[ @"Requires", [NSString stringWithFormat:@"iOS %@ or later", d.minimumOSVersion] ]];
    if (status.declarationNote.length) [about addObject:@[ @"Declaration", status.declarationNote ]];
    for (NSString *note in status.routeNotes) [about addObject:@[ @"Not offered", note ]];
    [about addObject:@[ @"Independence", @"Works without HCG Nexus, and Nexus works without it." ]];
    _aboutRows = about;

    NSMutableArray *groups = [NSMutableArray arrayWithObject:@(HCGDetailGroupStatus)];
    if (shortcuts.count) [groups addObject:@(HCGDetailGroupShortcuts)];
    if (status.readouts.count) [groups addObject:@(HCGDetailGroupSettings)];
    if (status.capabilities.count) [groups addObject:@(HCGDetailGroupCapabilities)];
    [groups addObject:@(HCGDetailGroupAbout)];
    _groups = groups;
    [self.tableView reloadData];
}

#pragma mark Table

- (HCGDetailGroup)groupAt:(NSInteger)section {
    return (HCGDetailGroup)[_groups[(NSUInteger)section] integerValue];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return (NSInteger)_groups.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    switch ([self groupAt:section]) {
        case HCGDetailGroupStatus: return @"Status";
        case HCGDetailGroupShortcuts: return @"Open";
        case HCGDetailGroupSettings: return @"Current settings (read-only)";
        case HCGDetailGroupCapabilities: return @"Capabilities";
        case HCGDetailGroupAbout: return @"Details";
    }
    return nil;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    switch ([self groupAt:section]) {
        case HCGDetailGroupShortcuts:
            return @"Every shortcut only opens a screen. Nothing starts, runs or changes until you act inside the product.";
        case HCGDetailGroupSettings:
            return [NSString stringWithFormat:@"Read from %@'s own preferences. Change them in Settings › %@.", _status.descriptor.name, _status.descriptor.name];
        case HCGDetailGroupCapabilities:
            return @"Verified: seen working on a physical device. Available: in the shipped code. Planned: designed, not built.";
        default: return nil;
    }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch ([self groupAt:section]) {
        case HCGDetailGroupStatus: return (NSInteger)_statusRows.count;
        case HCGDetailGroupShortcuts: return (NSInteger)_shortcuts.count;
        case HCGDetailGroupSettings: return (NSInteger)_status.readouts.count;
        case HCGDetailGroupCapabilities: return (NSInteger)_status.capabilities.count;
        case HCGDetailGroupAbout: return (NSInteger)_aboutRows.count;
    }
    return 0;
}

static NSString *HCGCapabilitySymbol(HCGHIPCapabilityState state) {
    switch (state) {
        case HCGHIPCapabilityStateVerified: return @"checkmark.seal.fill";
        case HCGHIPCapabilityStateAvailable: return @"checkmark.circle";
        case HCGHIPCapabilityStatePlanned: return @"clock";
        case HCGHIPCapabilityStateDisabled: return @"pause.circle";
        case HCGHIPCapabilityStateUnavailable: return @"minus.circle";
    }
    return @"circle";
}

static NSString *HCGPermissionText(HCGHIPPermission permission) {
    switch (permission) {
        case HCGHIPPermissionNone: return nil;
        case HCGHIPPermissionApprovalInProduct: return @"Asks you inside the product";
        case HCGHIPPermissionProductOwnedSwitch: return @"Switched through the product's own API";
        case HCGHIPPermissionNotOffered: return @"Not offered by Nexus";
    }
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSUInteger row = (NSUInteger)indexPath.row;
    switch ([self groupAt:indexPath.section]) {
        case HCGDetailGroupStatus:
        case HCGDetailGroupAbout:
        case HCGDetailGroupSettings: {
            NSArray *pair = [self groupAt:indexPath.section] == HCGDetailGroupStatus ? _statusRows[row]
                          : ([self groupAt:indexPath.section] == HCGDetailGroupAbout ? _aboutRows[row] : _status.readouts[row]);
            BOOL value1 = [self groupAt:indexPath.section] == HCGDetailGroupSettings;
            UITableViewCell *cell = [self styledCellWithStyle:value1 ? UITableViewCellStyleValue1 : UITableViewCellStyleSubtitle identifier:value1 ? @"pair" : @"text"];
            cell.textLabel.text = pair[0];
            cell.detailTextLabel.text = pair[1];
            cell.detailTextLabel.numberOfLines = 0;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            if (!value1) {
                cell.textLabel.font = [HCGTheme fontForTextStyle:UIFontTextStyleCaption1 weight:UIFontWeightSemibold];
                cell.textLabel.textColor = [HCGTheme secondaryText];
                cell.detailTextLabel.font = [HCGTheme fontForTextStyle:UIFontTextStyleBody weight:UIFontWeightRegular];
                cell.detailTextLabel.textColor = [HCGTheme primaryText];
                if ([self groupAt:indexPath.section] == HCGDetailGroupStatus && row == 0) {
                    cell.detailTextLabel.textColor = HCGEcosystemColorForAvailability(_status.availability);
                }
            }
            return cell;
        }
        case HCGDetailGroupShortcuts: {
            NSDictionary *item = _shortcuts[row];
            HCGHIPRoute *route = item[@"route"];
            UITableViewCell *cell = [self styledCellWithStyle:UITableViewCellStyleSubtitle identifier:@"route"];
            cell.textLabel.text = item[@"title"];
            cell.detailTextLabel.text = route.detail;
            cell.detailTextLabel.numberOfLines = 0;
            cell.imageView.image = [HCGTheme symbolNamed:route.symbolName pointSize:17];
            cell.imageView.tintColor = [HCGTheme cyan];
            cell.accessoryView = nil;
            cell.accessoryType = UITableViewCellAccessoryNone;
            if (route.kind == HCGHIPRouteKindNexusControl) {
                [self configureHaloSwitchCell:cell];
            } else {
                cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
                cell.accessibilityTraits = UIAccessibilityTraitButton;
            }
            return cell;
        }
        case HCGDetailGroupCapabilities: {
            HCGHIPResolvedCapability *c = _status.capabilities[row];
            UITableViewCell *cell = [self styledCellWithStyle:UITableViewCellStyleSubtitle identifier:@"capability"];
            cell.textLabel.text = c.capability.title;
            cell.textLabel.numberOfLines = 0;
            NSMutableArray *parts = [NSMutableArray arrayWithObject:[HCGInterchange titleForCapabilityState:c.state]];
            NSString *permission = HCGPermissionText(c.capability.permission);
            if (permission) [parts addObject:permission];
            if (c.reason.length) [parts addObject:c.reason];
            cell.detailTextLabel.text = [parts componentsJoinedByString:@" · "];
            cell.detailTextLabel.numberOfLines = 0;
            cell.imageView.image = [HCGTheme symbolNamed:HCGCapabilitySymbol(c.state) pointSize:16];
            cell.imageView.tintColor = c.state == HCGHIPCapabilityStateVerified || c.state == HCGHIPCapabilityStateAvailable ? [HCGTheme cyan]
                                     : (c.state == HCGHIPCapabilityStatePlanned ? [HCGTheme violet] : [HCGTheme secondaryText]);
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            return cell;
        }
    }
    return [self styledCellWithStyle:UITableViewCellStyleDefault identifier:@"x"];
}

#pragma mark HCG Halo border switch (existing integration)

- (void)configureHaloSwitchCell:(UITableViewCell *)cell {
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    if (!self.context.haloBorderStatus || !self.context.setHaloBorderEnabled) {
        cell.detailTextLabel.text = @"Available in the HCG Nexus panel and in Settings › HCG Nexus › Appearance (jailbreak package).";
        return;
    }
    HCGHaloBorderStatus *halo = self.context.haloBorderStatus();
    UISwitch *toggle = [[UISwitch alloc] init];
    toggle.onTintColor = [HCGTheme cyan];
    toggle.on = halo.switchOn;
    toggle.enabled = halo.canSwitch && !_haloBusy;
    [toggle addTarget:self action:@selector(haloSwitchChanged:) forControlEvents:UIControlEventValueChanged];
    cell.accessoryView = toggle;
    NSString *note = halo.switchNote.length ? [@" " stringByAppendingString:halo.switchNote] : @"";
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@: %@%@", [HCGHaloBorderStatus titleForState:halo.state], halo.detail, note];
    cell.accessibilityLabel = @"Use HCG Halo border";
}

- (void)haloSwitchChanged:(UISwitch *)toggle {
    if (!self.context.setHaloBorderEnabled) return;
    BOOL wanted = toggle.on;
    NSString *error = nil;
    _haloBusy = YES;
    BOOL ok = self.context.setHaloBorderEnabled(wanted, &error);
    _haloBusy = NO;
    if (!ok) {
        toggle.on = !wanted;
        [self.context feedback:error ?: @"HCG Halo refused the change." success:NO];
    } else {
        [self.context.model recordEcosystemActivity:wanted ? @"Turned on the HCG Halo border (through HCG Halo)" : @"Turned off the HCG Halo border (through HCG Halo)"
                                          productID:HCGHIPProductHalo];
        [self.context feedback:wanted ? @"HCG Halo border on." : @"HCG Halo border off." success:YES];
    }
    // HCG Halo answers its status request asynchronously.
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.6 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ [weakSelf reload]; });
}

#pragma mark Opening

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if ([self groupAt:indexPath.section] != HCGDetailGroupShortcuts) return;
    NSDictionary *item = _shortcuts[(NSUInteger)indexPath.row];
    HCGHIPRoute *route = item[@"route"];
    if (route.kind == HCGHIPRouteKindNexusControl) return;
    [self openRoute:route manager:item[@"manager"] title:item[@"title"]];
}

// Only registry targets, re-validated right before opening (the same exact-text rules saved shortcuts use).
- (NSURL *)validatedURLForRoute:(HCGHIPRoute *)route manager:(NSString *)manager reason:(NSString **)reason {
    NSString *text = nil;
    switch (route.kind) {
        case HCGHIPRouteKindAppLink:
            text = route.target;
            if ([HCGTerminalHandoff isTerminalLinkText:text]) {
                NSString *problem = [HCGTerminalHandoff problemWithLinkText:text];
                if (problem) { if (reason) *reason = problem; return nil; }
            } else if ([[text lowercaseString] hasPrefix:@"hcgsentinel://"]) {
                NSString *problem = [HCGSentinelLinks problemWithURLString:text];
                if (problem) { if (reason) *reason = problem; return nil; }
            } else if (![HCGInterchange isRegistryLink:text]) {
                if (reason) *reason = @"Not a link HCG Nexus knows.";
                return nil;
            }
            break;
        case HCGHIPRouteKindWeb:
            text = route.target;
            if (![text hasPrefix:@"https://repo.hakmicapitalgroup.com/"]) { if (reason) *reason = @"Only HCG Repo pages."; return nil; }
            break;
        case HCGHIPRouteKindPackageManager:
            text = [HCGInterchange packageManagerLinkForManager:manager packageIdentifier:_status.descriptor.packageIdentifier];
            break;
        default:
            break;
    }
    NSURL *url = text ? [NSURL URLWithString:text] : nil;
    if (!url && reason) *reason = @"This shortcut can't be opened.";
    return url;
}

- (void)openRoute:(HCGHIPRoute *)route manager:(NSString *)manager title:(NSString *)title {
    id<HCGLauncher> launcher = self.context.model.launcher;
    if (!launcher) {
        [self.context feedback:@"This build can't open other apps." success:NO];
        return;
    }
    HCGHIPProductDescriptor *d = _status.descriptor;
    NSString *activity = [route.identifier isEqualToString:@"open-app"] ? [@"Opened " stringByAppendingString:d.name]
                                                                       : [NSString stringWithFormat:@"Opened %@ › %@", d.name, title];
    __weak typeof(self) weakSelf = self;
    HCGLaunchCompletion done = ^(NSError *error) {
        typeof(self) strongSelf = weakSelf;
        if (!strongSelf) return;
        if (error) {
            HCGPresentError(strongSelf, error, nil);
            return;
        }
        [strongSelf.context.model recordEcosystemActivity:activity productID:d.productID];
        if (strongSelf.context.insideOverlay && !strongSelf.context.isPreview && strongSelf.context.closePanelImmediately) {
            strongSelf.context.closePanelImmediately();
        } else {
            [strongSelf.context feedback:strongSelf.context.isPreview ? [activity stringByAppendingString:@" (simulated)."] : [activity stringByAppendingString:@"."] success:YES];
        }
    };
    if (route.kind == HCGHIPRouteKindOpenApp || route.kind == HCGHIPRouteKindSettingsApp) {
        [launcher openApplicationWithBundleIdentifier:route.target completion:done];
        return;
    }
    NSString *reason = nil;
    NSURL *url = [self validatedURLForRoute:route manager:manager reason:&reason];
    if (!url) {
        [self.context feedback:reason ?: @"This shortcut can't be opened." success:NO];
        return;
    }
    [launcher openURL:url completion:done];
}

@end
