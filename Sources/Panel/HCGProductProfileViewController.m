#import "HCGProductProfileViewController.h"
#import "HCGCommandCenterViewController.h"
#import "HCGProductDetailViewController.h"
#import "HCGTrustCenterViewController.h"
#import "HCGRoadmapViewController.h"
#import "HCGDeviceClassesViewController.h"
#import "HCGTheme.h"

// A row: title, value, symbol, action ("" = none).
static NSArray *Row(NSString *title, NSString *value, NSString *symbol, NSString *action) {
    return @[ title ?: @"", value ?: @"", symbol ?: @"", action ?: @"" ];
}

static NSString *Relative(NSDate *date) {
    if (!date) return @"Never";
    NSRelativeDateTimeFormatter *f = [[NSRelativeDateTimeFormatter alloc] init];
    return [f localizedStringForDate:date relativeToDate:[NSDate date]];
}

static NSString *PlatformName(NSString *p) {
    NSDictionary *names = @{ @"ios": @"iOS", @"ios-jailbreak": @"iOS (jailbreak)", @"macos": @"macOS", @"windows": @"Windows",
                             @"linux": @"Linux", @"web": @"Web", @"android": @"Android" };
    return names[p] ?: p;
}

static NSString *RegistrationText(HCGRegistryEntry *e) {
    NSDictionary *names = @{ @"registered": @"Registered", @"proposed": @"Proposed (not applied)", @"not-registered": @"Not registered",
                             @"edition": @"An edition of", @"surface": @"Part of", @"component": @"Component", @"feature": @"Feature of HCG Nexus" };
    NSString *state = names[e.centralRegistration] ?: e.centralRegistration;
    if (e.centralProductID) return [NSString stringWithFormat:@"%@ · %@", state, e.centralProductID];
    return state;
}

static NSString *PermissionText(HCGHIPPermission p) {
    switch (p) {
        case HCGHIPPermissionNone: return @"None (view or open)";
        case HCGHIPPermissionApprovalInProduct: return @"The product asks you first";
        case HCGHIPPermissionProductOwnedSwitch: return @"A switch here calls the product's own interface";
        case HCGHIPPermissionNotOffered: return @"Not offered";
    }
    return @"—";
}

@implementation HCGProductProfileViewController {
    NSString *_entryID;
    HCGCommandCenterSnapshot *_snapshot;
    HCGCommandCenterItem *_item;
    NSArray<NSDictionary *> *_sections; // {title, footer, rows}
    NSArray<NSArray<NSString *> *> *_live;   // rows from Check now
    NSString *_liveTitle;
    BOOL _checking;
}

- (instancetype)initWithContext:(HCGPanelContext *)context entryID:(NSString *)entryID {
    if ((self = [super initWithContext:context])) _entryID = [entryID copy];
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.estimatedRowHeight = 56;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    _sections = @[];
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
    [HCGCommandCenterData loadWithModel:self.context.model completion:^(HCGCommandCenterSnapshot *snapshot) {
        typeof(self) s = weakSelf;
        if (!s) return;
        s->_snapshot = snapshot;
        [s rebuild];
    }];
}

- (void)rederive {
    _snapshot = [HCGCommandCenterData snapshotWithModel:self.context.model ecosystem:_snapshot.ecosystem];
    [self rebuild];
}

- (void)rebuild {
    _item = [_snapshot itemForID:_entryID];
    HCGRegistryEntry *e = _item.entry;
    if (!e) {
        self.title = @"Not available";
        _sections = @[ @{ @"title": @"", @"footer": @"This product is not in the registry, or it is private and needs an HCG account with access.", @"rows": @[] } ];
        [self.tableView reloadData];
        return;
    }
    self.title = e.officialName;
    HCGHIPProductStatus *hip = _item.hip;
    HCGConnectionSummary *c = _item.connection;
    NSMutableArray *sections = [NSMutableArray array];
    BOOL favorite = [[self.context.model favoriteProductIDs] containsObject:e.identifier];

    // Overview
    NSMutableArray *overview = [NSMutableArray array];
    [overview addObject:Row(@"About", e.summary, @"info.circle", @"")];
    HCGRegistryCategory *cat = [_snapshot.registry categoryWithIdentifier:e.categoryID];
    [overview addObject:Row(@"Category", cat.name ?: @"HCG Nexus", cat.symbolName ?: @"square.grid.2x2", @"")];
    NSMutableArray *platforms = [NSMutableArray array];
    for (NSString *p in e.platforms) [platforms addObject:PlatformName(p)];
    [overview addObject:Row(@"Platforms", platforms.count ? [platforms componentsJoinedByString:@", "] : @"Not decided", @"desktopcomputer", @"")];
    [overview addObject:Row(@"Development status", [e.developmentStatus stringByReplacingOccurrencesOfString:@"-" withString:@" "], @"hammer", @"")];
    if (![e.lifecycle isEqualToString:@"active"]) [overview addObject:Row(@"Lifecycle", [e.lifecycle capitalizedString], @"exclamationmark.triangle", @"")];
    [overview addObject:Row(@"Central registry", RegistrationText(e), @"building.columns", @"")];
    if (e.centralName && ![e.centralName isEqualToString:e.officialName]) [overview addObject:Row(@"Registered name", e.centralName, @"textformat", @"")];
    if (e.centralNote) [overview addObject:Row(@"Registry note", e.centralNote, @"text.bubble", @"")];
    if (!e.nameVerified) [overview addObject:Row(@"Name", @"Not verified: no official name or registry entry was found.", @"questionmark.circle", @"")];
    if (e.aliases.count) [overview addObject:Row(@"Also called", [e.aliases componentsJoinedByString:@", "], @"tag", @"")];
    if (e.distributionChannel) [overview addObject:Row(@"Distribution", [e.distributionChannel stringByReplacingOccurrencesOfString:@"-" withString:@" "], @"shippingbox", @"")];
    if (e.fromUpdate) [overview addObject:Row(@"Source", @"Added by an imported registry update: text only, nothing can be opened.", @"square.and.arrow.down", @"")];
    [overview addObject:Row(favorite ? @"Remove from Favorites" : @"Add to Favorites", @"", favorite ? @"star.fill" : @"star", @"favorite")];
    [sections addObject:@{ @"title": @"Overview", @"rows": overview }];

    // Status
    NSMutableArray *status = [NSMutableArray array];
    if (hip) {
        [status addObject:Row(@"On this iPhone", hip.stateTitle, @"iphone", @"")];
        if (hip.versionText.length) [status addObject:Row(@"Installed version", hip.versionText, @"number", @"")];
        if (hip.offeredVersion.length) [status addObject:Row(@"Latest in HCG Repo", [hip.offeredVersion stringByAppendingString:@" (from your package manager's last refresh)"], @"arrow.down.circle", @"")];
        if (hip.compatibilityText.length) [status addObject:Row(@"Compatibility", hip.compatibilityText, @"checkmark.seal", @"")];
        if (hip.healthText.length) [status addObject:Row(@"Health", hip.healthText, @"waveform.path.ecg", @"")];
    }
    [status addObject:Row(@"Connection", [NSString stringWithFormat:@"%@ — %@", c.title, c.detail], @"dot.radiowaves.left.and.right", @"")];
    [status addObject:Row(@"Last successful communication", c.lastSuccess ? [NSString stringWithFormat:@"%@ · %@", Relative(c.lastSuccess), c.lastSuccessText ?: @""] : @"Never", @"clock", @"")];
    if (c.lastAttempt && ![c.lastAttempt isEqualToDate:c.lastSuccess ?: [NSDate distantPast]]) [status addObject:Row(@"Last attempt", Relative(c.lastAttempt), @"clock.arrow.circlepath", @"")];
    [sections addObject:@{ @"title": @"Status", @"rows": status,
                           @"footer": @"Installed is not connected. A public read makes a service reachable, not connected: Connected needs a product's own interface or an authenticated exchange in the last 15 minutes." }];
    NSMutableArray *layers = [NSMutableArray array];
    NSArray *symbols = @[ @"building.columns", @"iphone", @"globe", @"lock.shield", @"checkmark.seal", @"waveform.path.ecg", @"clock.arrow.circlepath" ];
    NSArray *evidence = [HCGCommandCenter evidenceLayersForEntry:e connection:c hipStatus:hip ledger:[self.context.model connectionLedger]
                                                        registry:_snapshot.registry now:[NSDate date]];
    for (NSUInteger i = 0; i < evidence.count; i++) [layers addObject:Row(evidence[i][0], evidence[i][1], i < symbols.count ? symbols[i] : @"circle", @"")];
    NSMutableArray *progressRows = [NSMutableArray array];
    for (NSArray *step in [HCGCommandCenter integrationProgressForEntry:e connection:c hipStatus:hip]) {
        NSString *state = step[1];
        NSString *symbol = [state isEqualToString:@"done"] ? @"checkmark.circle.fill" : ([state isEqualToString:@"partial"] ? @"circle.lefthalf.filled"
                         : ([state isEqualToString:@"not needed"] ? @"minus.circle" : @"circle"));
        [progressRows addObject:Row([NSString stringWithFormat:@"%@ · %@", step[0], state], step[2], symbol, @"")];
    }
    [sections addObject:@{ @"title": @"Integration progress", @"rows": progressRows,
                           @"footer": @"Each checkpoint comes from evidence. Being registered does not mean connected; physical testing counts only from a recorded device result." }];
    [sections addObject:@{ @"title": @"Evidence", @"rows": layers,
                           @"footer": @"Each layer is separate evidence. Registration grants nothing; a public read does not authenticate; a past validation is not the current state." }];

    // Actions (only what is actually supported here)
    NSMutableArray *actions = [NSMutableArray array];
    BOOL active = [e.lifecycle isEqualToString:@"active"];
    if (active && hip && ![e.kind isEqualToString:@"hub"]) [actions addObject:Row(hip.routes.count ? @"Open and screens" : @"Integration details", hip.routes.count ? [NSString stringWithFormat:@"%lu ways to open it from here", (unsigned long)hip.routes.count] : @"What Nexus knows on this iPhone", @"arrow.up.forward.app", @"hip")];
    if (active && e.websiteURL) [actions addObject:Row(@"Open website", [[e.websiteURL substringFromIndex:8] stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"/"]], @"safari", @"web")];
    if ([e.adapter isEqualToString:@"central.registry"]) [actions addObject:Row(@"Central registry", @"Update product identities from the central HCG registry, or roll back", @"building.columns", @"registry")];
    if (active && ([e.adapter isEqualToString:@"news.v1"] || [e.adapter isEqualToString:@"connect.discovery"] || [e.adapter isEqualToString:@"store.health"] ||
                   [e.adapter isEqualToString:@"store.release"])) {
        [actions addObject:Row(_checking ? @"Checking…" : @"Check now", @"A read-only request to the registered endpoint. Sends no account, key or cookie.", @"arrow.clockwise", @"check")];
    }
    if ([e.adapter isEqualToString:@"trust-center"] || [e.identifier isEqualToString:@"repo"]) [actions addObject:Row(@"Package Trust Center", @"Signatures, checksums and device evidence", @"checkmark.shield", @"trust")];
    if ([e.adapter isEqualToString:@"system-tester.inventory"]) [actions addObject:Row(@"Connected devices", @"Import and view HCG System Tester's inventory", @"cable.connector", @"devices")];
    if ([e.adapter isEqualToString:@"lifeos.export"]) [actions addObject:Row(@"Export gaps to LifeOS", @"From the roadmap, as a file you preview in LifeOS", @"square.and.arrow.up", @"roadmap")];
    if ([e.identifier isEqualToString:@"server"] && self.context.connectedDevicesScreen) [actions addObject:Row(@"Connected Devices", @"HCG Device Link: pairing, hosted services, diagnostics", @"server.rack", @"devicelink")];
    if (actions.count) [sections addObject:@{ @"title": @"Actions", @"rows": actions }];

    if (_live.count) [sections addObject:@{ @"title": _liveTitle ?: @"Latest read", @"rows": _live }];

    // Capabilities
    NSMutableArray *caps = [NSMutableArray array];
    if (hip) {
        for (HCGHIPResolvedCapability *rc in hip.capabilities) {
            [caps addObject:Row(rc.capability.title, [NSString stringWithFormat:@"%@ — %@", [HCGInterchange titleForCapabilityState:rc.state], rc.reason], @"puzzlepiece", @"")];
        }
    } else {
        for (HCGHIPCapability *cap in e.capabilities) {
            [caps addObject:Row(cap.title, [NSString stringWithFormat:@"%@ — %@", [HCGInterchange titleForCapabilityState:cap.state], cap.note], @"puzzlepiece", @"")];
        }
    }
    if (caps.count) [sections addObject:@{ @"title": @"Capabilities", @"rows": caps }];

    // Connection methods (how to connect) and troubleshooting
    NSMutableArray *methods = [NSMutableArray array];
    for (HCGRegistryConnection *conn in e.connections) {
        HCGRegistryMethod *m = [_snapshot.registry methodWithIdentifier:conn.method];
        [methods addObject:Row(m.name ?: conn.method, [NSString stringWithFormat:@"%@ — %@", [conn.state capitalizedString], conn.detail], @"link", @"")];
    }
    if (!methods.count) [methods addObject:Row(@"None yet", @"There is no way to connect to it from this iPhone.", @"link", @"")];
    [sections addObject:@{ @"title": @"How it connects", @"rows": methods }];

    NSMutableArray *permissions = [NSMutableArray array];
    NSMutableSet *seen = [NSMutableSet set];
    NSArray *capList = hip ? hip.descriptor.capabilities : e.capabilities;
    for (HCGHIPCapability *cap in capList) {
        NSString *text = PermissionText(cap.permission);
        if ([seen containsObject:text]) continue;
        [seen addObject:text];
        [permissions addObject:Row(text, @"", @"hand.raised", @"")];
    }
    [permissions addObject:Row(@"Credentials", @"Nexus holds none for this product and passes none between apps.", @"key", @"")];
    if (e.entitlement) [permissions addObject:Row(@"Access", [NSString stringWithFormat:@"Requires the central entitlement %@", e.entitlement], @"lock", @"")];
    [sections addObject:@{ @"title": @"Permissions", @"rows": permissions }];

    NSMutableArray *trouble = [NSMutableArray array];
    for (NSString *n in hip.routeNotes) [trouble addObject:Row(@"", n, @"exclamationmark.bubble", @"")];
    if (hip.declarationNote.length) [trouble addObject:Row(@"Declaration", hip.declarationNote, @"doc.text", @"")];
    for (NSString *n in e.notes) [trouble addObject:Row(@"", n, @"text.bubble", @"")];
    if (c.state == HCGConnectionStateFailed || c.state == HCGConnectionStateDisconnected) {
        [trouble addObject:Row(@"Last problem", c.detail, @"wifi.exclamationmark", @"")];
        [trouble addObject:Row(@"", @"Check the iPhone's internet connection, then tap Check now again. Nexus never retries by itself.", @"arrow.clockwise", @"")];
    }
    if (c.state == HCGConnectionStateUnableToCheck) [trouble addObject:Row(@"", @"The App Store version of Nexus cannot see other apps. The jailbreak package (HCG Repo) can.", @"eye.slash", @"")];
    if (trouble.count) [sections addObject:@{ @"title": @"Troubleshooting", @"rows": trouble }];

    // Development requirements
    NSMutableArray *gapRows = [NSMutableArray array];
    for (HCGDevelopmentGap *g in [HCGCommandCenter gapsForEntries:@[ e ]]) {
        [gapRows addObject:Row(g.title, [NSString stringWithFormat:@"%@%@ · %@", g.blocking ? @"Blocking · " : @"", g.kind, g.detail], g.blocking ? @"exclamationmark.octagon" : @"wrench.and.screwdriver", @"")];
    }
    if (gapRows.count) [sections addObject:@{ @"title": @"Development requirements", @"rows": gapRows,
                                              @"footer": @"Each has a stable ID (nexus.<product>.<requirement>) for the LifeOS export." }];

    // Roadmap: current state, history, historical validations (separate from the current connection status)
    NSMutableArray *roadmap = [NSMutableArray array];
    [roadmap addObject:Row([HCGCommandCenter titleForRoadmapState:_item.roadmap.state], _item.roadmap.evidence, @"map", @"")];
    for (NSDictionary *h in [HCGCommandCenter roadmapHistoryForEntry:e.identifier store:[self.context.model roadmapStore]]) {
        BOOL found = NO;
        HCGRoadmapState st = [HCGCommandCenter roadmapStateForKey:h[@"state"] found:&found];
        NSDate *when = [NSDate dateWithTimeIntervalSince1970:[h[@"time"] doubleValue]];
        [roadmap addObject:Row([NSString stringWithFormat:@"%@ · %@", [HCGCommandCenter titleForRoadmapState:st], Relative(when)], h[@"evidence"] ?: @"", @"clock", @"")];
    }
    [sections addObject:@{ @"title": @"Roadmap", @"rows": roadmap, @"footer": @"Updated only from evidence. History is kept on this iPhone." }];
    if (e.validations.count) {
        NSMutableArray *v = [NSMutableArray array];
        for (HCGRegistryValidation *val in e.validations) [v addObject:Row([NSString stringWithFormat:@"%@ · %@", val.version.length ? val.version : @"Validated", val.date], [NSString stringWithFormat:@"%@ — %@", val.device, val.summary], @"checkmark.seal.fill", @"")];
        [sections addObject:@{ @"title": @"Validated on a device (history)", @"rows": v, @"footer": @"Historical evidence. It does not mean the product is connected now." }];
    }

    // Verification
    NSMutableArray *verify = [NSMutableArray array];
    [verify addObject:Row(@"Last verified", e.lastVerified, @"calendar", @"")];
    if (e.verifiedFrom.length) [verify addObject:Row(@"Source", e.verifiedFrom, @"doc.text.magnifyingglass", @"")];
    if (e.contractID || e.contractDetail) [verify addObject:Row(@"Contract", [NSString stringWithFormat:@"%@%@", e.contractID ? [e.contractID stringByAppendingString:@" — "] : @"", e.contractDetail ?: e.contractStatus], @"doc.plaintext", @"")];
    for (HCGRegistryEndpoint *ep in e.endpoints) [verify addObject:Row(@"Endpoint", [NSString stringWithFormat:@"%@ (verified: %@)", ep.detail, ep.verified], @"network", @"")];
    [sections addObject:@{ @"title": @"Where this comes from", @"rows": verify }];
    _sections = sections;
    [self.tableView reloadData];
}

#pragma mark Table

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return (NSInteger)_sections.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return (NSInteger)[_sections[(NSUInteger)section][@"rows"] count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    NSString *t = _sections[(NSUInteger)section][@"title"];
    return t.length ? t : nil;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    return _sections[(NSUInteger)section][@"footer"];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSArray *row = _sections[(NSUInteger)indexPath.section][@"rows"][(NSUInteger)indexPath.row];
    BOOL action = [row[3] length] > 0;
    UITableViewCell *cell = [self styledCellWithStyle:UITableViewCellStyleSubtitle identifier:action ? @"action" : @"info"];
    cell.textLabel.text = [row[0] length] ? row[0] : row[1];
    cell.textLabel.numberOfLines = 0;
    cell.detailTextLabel.text = [row[0] length] ? row[1] : nil;
    cell.detailTextLabel.numberOfLines = 0;
    cell.imageView.image = [row[2] length] ? [HCGTheme symbolNamed:row[2] pointSize:16] : nil;
    cell.imageView.tintColor = action ? [HCGTheme cyan] : [HCGTheme secondaryText];
    cell.textLabel.textColor = action ? [HCGTheme cyan] : [HCGTheme primaryText];
    cell.accessoryType = action && ![row[3] isEqualToString:@"check"] && ![row[3] isEqualToString:@"favorite"] && ![row[3] isEqualToString:@"web"]
                       ? UITableViewCellAccessoryDisclosureIndicator : UITableViewCellAccessoryNone;
    cell.selectionStyle = action ? UITableViewCellSelectionStyleDefault : UITableViewCellSelectionStyleNone;
    if (action) cell.accessibilityTraits = UIAccessibilityTraitButton;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSArray *row = _sections[(NSUInteger)indexPath.section][@"rows"][(NSUInteger)indexPath.row];
    NSString *action = row[3];
    HCGRegistryEntry *e = _item.entry;
    BOOL animated = !UIAccessibilityIsReduceMotionEnabled();
    if ([action isEqualToString:@"favorite"]) {
        [self.context.model setFavorite:![[self.context.model favoriteProductIDs] containsObject:e.identifier] forProduct:e.identifier];
        [self rebuild];
    } else if ([action isEqualToString:@"hip"]) {
        [self.navigationController pushViewController:[[HCGProductDetailViewController alloc] initWithContext:self.context productID:e.hipProductID] animated:animated];
    } else if ([action isEqualToString:@"web"]) {
        [self openWebsite];
    } else if ([action isEqualToString:@"check"]) {
        [self checkNow];
    } else if ([action isEqualToString:@"trust"]) {
        [self.navigationController pushViewController:[[HCGTrustCenterViewController alloc] initWithContext:self.context] animated:animated];
    } else if ([action isEqualToString:@"devices"]) {
        [self.navigationController pushViewController:[[HCGDeviceClassesViewController alloc] initWithContext:self.context] animated:animated];
    } else if ([action isEqualToString:@"registry"]) {
        [self.navigationController pushViewController:[[HCGRegistryInfoViewController alloc] initWithContext:self.context] animated:animated];
    } else if ([action isEqualToString:@"roadmap"]) {
        [self.navigationController pushViewController:[[HCGRoadmapViewController alloc] initWithContext:self.context] animated:animated];
    } else if ([action isEqualToString:@"devicelink"] && self.context.connectedDevicesScreen) {
        UIViewController *screen = self.context.connectedDevicesScreen(self.context);
        if (screen) [self.navigationController pushViewController:screen animated:animated];
    }
}

// A second public read for HCG Store: HCG Nexus's own release resolution, appended to the live rows.
- (void)appendStoreRelease:(HCGRegistryEndpoint *)endpoint {
    __weak typeof(self) weakSelf = self;
    [[HCGPublicReader sharedReader] getURLString:endpoint.url completion:^(NSData *data, NSString *state) {
        typeof(self) s = weakSelf;
        if (!s) return;
        NSString *error = nil;
        NSArray *resolution = data ? [HCGPublicFeeds storeReleaseRowsFromData:data error:&error] : nil;
        NSMutableArray *rows = [NSMutableArray arrayWithArray:s->_live ?: @[]];
        if (resolution) for (NSArray *pair in resolution) [rows addObject:Row(pair[0], pair[1], @"shippingbox", @"")];
        else [rows addObject:Row(@"HCG Nexus in HCG Store", [NSString stringWithFormat:@"Not read: %@", error ?: state], @"shippingbox", @"")];
        s->_live = rows;
        [s rebuild];
    }];
}

- (void)openWebsite {
    HCGRegistryEntry *e = _item.entry;
    id<HCGLauncher> launcher = self.context.model.launcher;
    NSURL *url = HCGRegistryIsAllowedURL(e.websiteURL) ? [NSURL URLWithString:e.websiteURL] : nil;
    if (!url || !launcher) {
        [self.context feedback:@"This build can't open websites." success:NO];
        return;
    }
    NSString *activity = [NSString stringWithFormat:@"Opened %@'s website", e.officialName];
    __weak typeof(self) weakSelf = self;
    [launcher openURL:url completion:^(NSError *error) {
        typeof(self) s = weakSelf;
        if (!s) return;
        if (error) {
            HCGPresentError(s, error, nil);
            return;
        }
        [s.context.model recordEcosystemActivity:activity productID:e.hipProductID];
        // Navigation: recorded as activity and in the ledger as one-way (never counts as a connection).
        [s.context.model recordConnectionForProduct:e.identifier method:@"website" success:YES text:@"Opened the website."];
        if (s.context.insideOverlay && !s.context.isPreview && s.context.closePanelImmediately) s.context.closePanelImmediately();
        else [s.context feedback:[activity stringByAppendingString:s.context.isPreview ? @" (simulated)." : @"."] success:YES];
    }];
}

- (void)checkNow {
    if (_checking) return;
    HCGRegistryEntry *e = _item.entry;
    BOOL news = [e.adapter isEqualToString:@"news.v1"], store = [e.adapter isEqualToString:@"store.health"], release = [e.adapter isEqualToString:@"store.release"];
    HCGRegistryEndpoint *ep = [e endpointWithIdentifier:news ? @"news.articles" : (store ? @"store.health" : (release ? @"store.release" : @"identity.discovery"))];
    HCGRegistryEndpoint *releaseEndpoint = store ? [e endpointWithIdentifier:@"store.release"] : nil;
    if (!ep) {
        [self.context feedback:@"The registry lists no endpoint for this product." success:NO];
        return;
    }
    if (self.context.isPreview) {
        [self.context feedback:@"The preview harness does not make network requests." success:NO];
        return;
    }
    _checking = YES;
    [self rebuild];
    NSString *url = news ? [HCGPublicFeeds newsRequestURLForEndpoint:ep.url] : ep.url;
    __weak typeof(self) weakSelf = self;
    [[HCGPublicReader sharedReader] getURLString:url completion:^(NSData *data, NSString *state) {
        typeof(self) s = weakSelf;
        if (!s) return;
        s->_checking = NO;
        NSString *error = nil;
        NSMutableArray *rows = [NSMutableArray array];
        NSString *ledgerText = nil;
        if (news) {
            NSInteger total = 0;
            NSArray *articles = data ? [HCGPublicFeeds newsArticlesFromData:data total:&total error:&error] : nil;
            for (HCGNewsArticle *a in articles) {
                NSString *meta = [@[ a.section ?: @"", a.publishedAt ?: @"", a.demo ? @"DEMO" : @"" ] componentsJoinedByString:@" "];
                [rows addObject:Row(a.title, [NSString stringWithFormat:@"%@%@", [meta stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]],
                                                                          a.excerpt.length ? [@" — " stringByAppendingString:a.excerpt] : @""], @"newspaper", @"")];
            }
            if (articles) {
                ledgerText = [NSString stringWithFormat:@"Read %lu published article%@ (%ld in total).", (unsigned long)articles.count, articles.count == 1 ? @"" : @"s", (long)total];
                if (!articles.count) [rows addObject:Row(@"", @"No published articles.", @"newspaper", @"")];
            }
            s->_liveTitle = @"Latest approved articles";
        } else if (store) {
            NSArray *health = data ? [HCGPublicFeeds storeHealthRowsFromData:data error:&error] : nil;
            for (NSArray *pair in health) [rows addObject:Row(pair[0], pair[1], @"shippingbox", @"")];
            if (health) ledgerText = @"Read the HCG Store's public health.";
            s->_liveTitle = @"HCG Store (public)";
            if (health && releaseEndpoint) [s appendStoreRelease:releaseEndpoint];
        } else if (release) {
            NSArray *resolution = data ? [HCGPublicFeeds storeReleaseRowsFromData:data error:&error] : nil;
            for (NSArray *pair in resolution) [rows addObject:Row(pair[0], pair[1], @"shippingbox", @"")];
            if (resolution) ledgerText = @"Read its public HCG Store release resolution.";
            s->_liveTitle = @"HCG Store release (public)";
        } else {
            NSArray *discovery = data ? [HCGPublicFeeds identityDiscoveryRowsFromData:data error:&error] : nil;
            for (NSArray *pair in discovery) [rows addObject:Row(pair[0], pair[1], @"person.badge.key", @"")];
            if (discovery) ledgerText = @"Read the public identity discovery.";
            s->_liveTitle = @"Central sign-in service";
        }
        if (ledgerText) {
            [s.context.model recordConnectionForProduct:e.identifier method:@"https-api" success:YES text:ledgerText];
            s->_live = rows;
            [s.context feedback:ledgerText success:YES];
        } else {
            NSString *why = [NSString stringWithFormat:@"No answer: %@", error ?: state];
            [s.context.model recordConnectionForProduct:e.identifier method:@"https-api" success:NO text:why];
            s->_live = @[ Row(@"Check failed", why, @"wifi.exclamationmark", @"") ];
            [s.context feedback:why success:NO];
        }
        [s rederive];
    }];
}

@end
