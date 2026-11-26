#import "HCGCommandCenterViewController.h"
#import "HCGProductProfileViewController.h"
#import "HCGRoadmapViewController.h"
#import "HCGDeviceClassesViewController.h"
#import "HCGTrustCenterViewController.h"
#import "HCGBranding.h"
#import "HCGTheme.h"

UIColor *HCGCommandCenterColorForConnection(HCGConnectionState state) {
    switch (state) {
        case HCGConnectionStateConnected: return [HCGTheme success];
        case HCGConnectionStateInstalled:
        case HCGConnectionStateReady:
        case HCGConnectionStateBuiltIn: return [HCGTheme cyan];
        case HCGConnectionStateDisconnected:
        case HCGConnectionStateFailed:
        case HCGConnectionStateSuspended: return [HCGTheme warning];
        case HCGConnectionStateNotConfigured: return [HCGTheme violet];
        case HCGConnectionStateRetired: return [HCGTheme critical];
        default: return [HCGTheme secondaryText];
    }
}

#pragma mark - Files

@interface HCGFileExchange ()
@property (nonatomic, copy) void (^completion)(NSData *, NSString *);
@end

@implementation HCGFileExchange

static HCGFileExchange *gActivePicker;

+ (BOOL)availableInContext:(HCGPanelContext *)context {
    return context.isStandaloneApp || context.mode == HCGPanelModeSettingsApp;
}

+ (void)pickJSONFrom:(UIViewController *)presenter completion:(void (^)(NSData *, NSString *))completion {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initWithDocumentTypes:@[ @"public.json", @"public.text" ]
                                                                                                    inMode:UIDocumentPickerModeImport];
#pragma clang diagnostic pop
    HCGFileExchange *delegate = [[HCGFileExchange alloc] init];
    delegate.completion = completion;
    gActivePicker = delegate; // the picker holds its delegate weakly
    picker.delegate = delegate;
    picker.allowsMultipleSelection = NO;
    [presenter presentViewController:picker animated:YES completion:nil];
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    NSURL *url = urls.firstObject;
    BOOL scoped = [url startAccessingSecurityScopedResource];
    NSNumber *size = nil;
    [url getResourceValue:&size forKey:NSURLFileSizeKey error:NULL];
    NSData *data = size.unsignedLongLongValue <= 2 * 1024 * 1024 ? [NSData dataWithContentsOfURL:url] : nil;
    if (scoped) [url stopAccessingSecurityScopedResource];
    void (^done)(NSData *, NSString *) = self.completion;
    gActivePicker = nil;
    if (done) done(data, data ? nil : @"The file could not be read (at most 2 MB).");
}

- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller {
    gActivePicker = nil;
}

+ (void)shareData:(NSData *)data fileName:(NSString *)fileName from:(UIViewController *)presenter sourceView:(UIView *)sourceView
       completion:(void (^)(BOOL))completion {
    NSString *dir = [NSTemporaryDirectory() stringByAppendingPathComponent:@"HCGNexusExport"];
    [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:NULL];
    NSString *path = [dir stringByAppendingPathComponent:fileName];
    if (![data writeToFile:path atomically:YES]) {
        completion(NO);
        return;
    }
    NSURL *fileURL = [NSURL fileURLWithPath:path];
    UIActivityViewController *share = [[UIActivityViewController alloc] initWithActivityItems:@[ fileURL ] applicationActivities:nil];
    share.completionWithItemsHandler = ^(UIActivityType type, BOOL completed, NSArray *items, NSError *error) {
        [[NSFileManager defaultManager] removeItemAtPath:path error:NULL];
        completion(completed);
    };
    share.popoverPresentationController.sourceView = sourceView ?: presenter.view;
    share.popoverPresentationController.sourceRect = (sourceView ?: presenter.view).bounds;
    [presenter presentViewController:share animated:YES completion:nil];
}

@end

#pragma mark - Command Center

typedef NS_ENUM(NSInteger, HCGCCSection) {
    HCGCCSectionDashboard = 0,
    HCGCCSectionNotices,
    HCGCCSectionFavorites,
    HCGCCSectionCategory,
    HCGCCSectionResults,
};

@implementation HCGCommandCenterViewController {
    HCGCommandCenterSnapshot *_snapshot;
    NSArray<NSArray *> *_sections; // (HCGCCSection, category ID or "")
    NSArray<HCGCommandCenterItem *> *_results;
    NSArray<NSArray<NSString *> *> *_dashboard; // (title, value, symbol, action)
    NSString *_query;
    UILabel *_subtitle;
    UISearchBar *_search;
    BOOL _loading;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Command Center";
    self.tableView.estimatedRowHeight = 64;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    self.tableView.tableHeaderView = [self makeHeader];
    _sections = @[];
}

- (UIView *)makeHeader {
    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 128)];
    UIImageView *logo = [[UIImageView alloc] init];
    UIImage *official = [HCGBranding hcgLogo]; // the official HCG logo; never redrawn with generic typography
    logo.image = official;
    logo.contentMode = UIViewContentModeScaleAspectFit;
    logo.hidden = official == nil;
    logo.isAccessibilityElement = official != nil;
    logo.accessibilityLabel = @"HCG";
    logo.translatesAutoresizingMaskIntoConstraints = NO;
    UILabel *title = [[UILabel alloc] init];
    title.text = @"HCG Nexus";
    title.font = [HCGTheme fontForTextStyle:UIFontTextStyleTitle2 weight:UIFontWeightBold maximumPointSize:28];
    title.textColor = [HCGTheme primaryText];
    title.accessibilityTraits = UIAccessibilityTraitHeader;
    _subtitle = [[UILabel alloc] init];
    _subtitle.font = [HCGTheme fontForTextStyle:UIFontTextStyleFootnote weight:UIFontWeightMedium maximumPointSize:17];
    _subtitle.textColor = [HCGTheme secondaryText];
    _subtitle.numberOfLines = 2;
    _subtitle.text = @"Reading the HCG ecosystem registry…";
    UIStackView *text = [[UIStackView alloc] initWithArrangedSubviews:@[ title, _subtitle ]];
    text.axis = UILayoutConstraintAxisVertical;
    text.spacing = 2;
    UIStackView *top = [[UIStackView alloc] initWithArrangedSubviews:@[ logo, text ]];
    top.spacing = 12;
    top.alignment = UIStackViewAlignmentCenter;
    top.translatesAutoresizingMaskIntoConstraints = NO;
    _search = [[UISearchBar alloc] init];
    _search.placeholder = @"Search HCG products";
    _search.searchBarStyle = UISearchBarStyleMinimal;
    _search.delegate = self;
    _search.translatesAutoresizingMaskIntoConstraints = NO;
    _search.autocapitalizationType = UITextAutocapitalizationTypeNone;
    [header addSubview:top];
    [header addSubview:_search];
    [NSLayoutConstraint activateConstraints:@[
        [logo.widthAnchor constraintEqualToConstant:44],
        [logo.heightAnchor constraintEqualToConstant:44],
        [top.leadingAnchor constraintEqualToAnchor:header.leadingAnchor constant:20],
        [top.trailingAnchor constraintLessThanOrEqualToAnchor:header.trailingAnchor constant:-20],
        [top.topAnchor constraintEqualToAnchor:header.topAnchor constant:12],
        [_search.leadingAnchor constraintEqualToAnchor:header.leadingAnchor constant:10],
        [_search.trailingAnchor constraintEqualToAnchor:header.trailingAnchor constant:-10],
        [_search.bottomAnchor constraintEqualToAnchor:header.bottomAnchor constant:-4],
    ]];
    return header;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self reload];
}

- (void)modelDidChange {
    [self reload];
}

- (void)reload {
    if (_loading) return;
    _loading = YES;
    __weak typeof(self) weakSelf = self;
    [HCGCommandCenterData loadWithModel:self.context.model completion:^(HCGCommandCenterSnapshot *snapshot) {
        typeof(self) s = weakSelf;
        if (!s) return;
        s->_loading = NO;
        s->_snapshot = snapshot;
        [s rebuild];
    }];
}

- (void)rebuild {
    HCGCommandCenterSnapshot *s = _snapshot;
    NSUInteger connected = [s countInState:HCGConnectionStateConnected], installed = [s countInState:HCGConnectionStateInstalled];
    NSUInteger planned = [s countInState:HCGConnectionStatePlanned];
    NSMutableArray *summary = [NSMutableArray arrayWithObject:[NSString stringWithFormat:@"%lu products in %lu categories", (unsigned long)s.items.count, (unsigned long)s.registry.categories.count]];
    [summary addObject:[NSString stringWithFormat:@"%lu connected", (unsigned long)connected]];
    if (s.ecosystem.simulated) [summary addObject:@"SIMULATED"];
    _subtitle.text = [summary componentsJoinedByString:@" · "];

    NSUInteger attention = [s countInState:HCGConnectionStateDisconnected] + [s countInState:HCGConnectionStateFailed];
    NSUInteger gaps = [HCGCommandCenter gapsForEntries:[s.registry visibleEntriesWithGrants:nil]].count;
    HCGDeviceInventory *inventory = [self.context.model deviceInventory];
    _dashboard = @[
        @[ @"Connections", [NSString stringWithFormat:@"%lu connected · %lu installed · %lu need attention", (unsigned long)connected, (unsigned long)installed, (unsigned long)attention], @"dot.radiowaves.left.and.right", @"" ],
        @[ @"Roadmap", [NSString stringWithFormat:@"%lu development gaps · %lu planned products", (unsigned long)gaps, (unsigned long)planned], @"map", @"roadmap" ],
        @[ @"Connected devices", inventory ? [NSString stringWithFormat:@"%lu devices from HCG System Tester", (unsigned long)inventory.devices.count] : @"Through HCG System Tester (import an inventory)", @"cable.connector", @"devices" ],
        @[ @"Service health", [self serviceHealthText], @"server.rack", @"server" ],
        @[ @"Package Trust Center", @"Authenticity, integrity and device compatibility, kept separate", @"checkmark.shield", @"trust" ],
        @[ @"Registry", [NSString stringWithFormat:@"Version %ld · %@ · verified %@", (long)s.registry.version, s.registry.source, s.registry.generatedAt], @"list.bullet.rectangle", @"registry" ],
    ];

    NSMutableArray *sections = [NSMutableArray array];
    if (_query.length) {
        NSMutableArray *entries = [NSMutableArray array];
        for (HCGCommandCenterItem *i in s.items) [entries addObject:i.entry];
        NSArray *matched = [HCGRegistry entries:entries matchingQuery:_query registry:s.registry];
        NSMutableArray *results = [NSMutableArray array];
        for (HCGRegistryEntry *e in matched) {
            HCGCommandCenterItem *i = [s itemForID:e.identifier];
            if (i) [results addObject:i];
        }
        _results = results;
        [sections addObject:@[ @(HCGCCSectionResults), @"" ]];
    } else {
        [sections addObject:@[ @(HCGCCSectionDashboard), @"" ]];
        if (s.notices.count) [sections addObject:@[ @(HCGCCSectionNotices), @"" ]];
        if ([self favorites].count) [sections addObject:@[ @(HCGCCSectionFavorites), @"" ]];
        for (HCGRegistryCategory *c in s.registry.categories) {
            if ([s itemsInCategory:c.identifier].count) [sections addObject:@[ @(HCGCCSectionCategory), c.identifier ]];
        }
    }
    _sections = sections;
    [self.tableView reloadData];
}

- (NSString *)serviceHealthText {
    HCGCommandCenterItem *server = [_snapshot itemForID:@"server"];
    if (!server) return @"—";
    if (server.hip.availability == HCGHIPAvailabilityConnected) return server.hip.integrationText;
    return [NSString stringWithFormat:@"HCG Server: %@", server.connection.title];
}

- (NSArray<HCGCommandCenterItem *> *)favorites {
    NSMutableArray *out = [NSMutableArray array];
    for (NSString *identifier in [self.context.model favoriteProductIDs]) {
        HCGCommandCenterItem *i = [_snapshot itemForID:identifier];
        if (i) [out addObject:i];
    }
    return out;
}

- (HCGCCSection)kindAt:(NSInteger)section {
    return (HCGCCSection)[_sections[(NSUInteger)section][0] integerValue];
}

- (BOOL)expanded:(NSString *)categoryID {
    return [[self.context.model expandedCategoryIDs] containsObject:categoryID];
}

- (NSArray<HCGCommandCenterItem *> *)itemsForSection:(NSInteger)section {
    switch ([self kindAt:section]) {
        case HCGCCSectionFavorites: return [self favorites];
        case HCGCCSectionResults: return _results;
        case HCGCCSectionCategory: {
            NSString *cid = _sections[(NSUInteger)section][1];
            return [self expanded:cid] ? [_snapshot itemsInCategory:cid] : @[];
        }
        default: return @[];
    }
}

#pragma mark Search

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    _query = searchText;
    [self rebuild];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
}

#pragma mark Table

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return (NSInteger)_sections.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch ([self kindAt:section]) {
        case HCGCCSectionDashboard: return (NSInteger)_dashboard.count;
        case HCGCCSectionNotices: return (NSInteger)MIN(_snapshot.notices.count, (NSUInteger)8);
        case HCGCCSectionResults: return MAX((NSInteger)_results.count, 1);
        default: return (NSInteger)[self itemsForSection:section].count;
    }
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    if ([self kindAt:section] != HCGCCSectionCategory) return nil;
    NSString *cid = _sections[(NSUInteger)section][1];
    HCGRegistryCategory *c = [_snapshot.registry categoryWithIdentifier:cid];
    NSUInteger count = [_snapshot itemsInCategory:cid].count;
    BOOL open = [self expanded:cid];
    UIView *header = [[UIView alloc] init];
    UIImageView *chevron = [[UIImageView alloc] initWithImage:[HCGTheme symbolNamed:open ? @"chevron.down" : @"chevron.right" pointSize:12]];
    chevron.tintColor = [HCGTheme cyan];
    chevron.contentMode = UIViewContentModeCenter;
    UIImageView *symbol = [[UIImageView alloc] initWithImage:[HCGTheme symbolNamed:c.symbolName pointSize:14]];
    symbol.tintColor = [HCGTheme cyan];
    UILabel *label = [[UILabel alloc] init];
    label.text = [NSString stringWithFormat:@"%@  ·  %lu", [c.name uppercaseString], (unsigned long)count];
    label.font = [HCGTheme fontForTextStyle:UIFontTextStyleFootnote weight:UIFontWeightSemibold maximumPointSize:18];
    label.adjustsFontForContentSizeCategory = YES;
    label.textColor = [HCGTheme secondaryText];
    label.numberOfLines = 0;
    UIStackView *row = [[UIStackView alloc] initWithArrangedSubviews:@[ chevron, symbol, label ]];
    row.spacing = 8;
    row.alignment = UIStackViewAlignmentCenter;
    row.translatesAutoresizingMaskIntoConstraints = NO;
    [header addSubview:row];
    [NSLayoutConstraint activateConstraints:@[
        [chevron.widthAnchor constraintEqualToConstant:14],
        [row.leadingAnchor constraintEqualToAnchor:header.leadingAnchor constant:20],
        [row.trailingAnchor constraintLessThanOrEqualToAnchor:header.trailingAnchor constant:-20],
        [row.topAnchor constraintEqualToAnchor:header.topAnchor constant:12],
        [row.bottomAnchor constraintEqualToAnchor:header.bottomAnchor constant:-6],
    ]];
    header.tag = section;
    header.isAccessibilityElement = YES;
    header.accessibilityLabel = [NSString stringWithFormat:@"%@, %lu products", c.name, (unsigned long)count];
    header.accessibilityHint = open ? @"Collapses the category" : @"Expands the category";
    header.accessibilityTraits = UIAccessibilityTraitHeader | UIAccessibilityTraitButton;
    [header addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(toggleCategory:)]];
    return header;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return UITableViewAutomaticDimension;
}

- (CGFloat)tableView:(UITableView *)tableView estimatedHeightForHeaderInSection:(NSInteger)section {
    return 38;
}

- (void)toggleCategory:(UITapGestureRecognizer *)tap {
    NSInteger section = tap.view.tag;
    if (section < 0 || section >= (NSInteger)_sections.count) return;
    NSString *cid = _sections[(NSUInteger)section][1];
    [self.context.model setCategory:cid expanded:![self expanded:cid]];
    [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:(NSUInteger)section] withRowAnimation:UITableViewRowAnimationAutomatic];
}

- (BOOL)accessibilityPerformEscape {
    if (_query.length) {
        _search.text = @"";
        _query = nil;
        [self rebuild];
        return YES;
    }
    return NO;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    switch ([self kindAt:section]) {
        case HCGCCSectionDashboard: return @"Dashboard";
        case HCGCCSectionNotices: return @"Notifications";
        case HCGCCSectionFavorites: return @"Favorites";
        case HCGCCSectionResults: return [NSString stringWithFormat:@"Results for “%@”", _query];
        default: return nil;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if ([self kindAt:section] == HCGCCSectionDashboard) {
        return @"Connected appears only after a real two-way exchange succeeded (a read of the product's API, its own interface on this iPhone, or HCG Device Link). An app or link that exists is never reported as connected.";
    }
    if (section == (NSInteger)_sections.count - 1 && !_query.length) {
        return @"Names, identifiers, links and endpoints come from the central HCG product registry and the products' own repositories; each product page says where and when. Registration never grants access.";
    }
    return nil;
}

- (UITableViewCell *)productCell:(HCGCommandCenterItem *)item {
    UITableViewCell *cell = [self styledCellWithStyle:UITableViewCellStyleSubtitle identifier:@"product"];
    HCGRegistryEntry *e = item.entry;
    cell.textLabel.text = e.officialName;
    cell.textLabel.numberOfLines = 0;
    NSString *state = item.connection.title;
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ · %@", state, [HCGCommandCenter titleForRoadmapState:item.roadmap.state]];
    cell.detailTextLabel.numberOfLines = 0;
    cell.detailTextLabel.textColor = HCGCommandCenterColorForConnection(item.connection.state);
    HCGHIPProductDescriptor *d = e.hipProductID ? [HCGInterchange descriptorForProductID:e.hipProductID] : nil;
    HCGRegistryCategory *c = [_snapshot.registry categoryWithIdentifier:e.categoryID];
    cell.imageView.image = [HCGTheme symbolNamed:d.symbolName ?: (c.symbolName ?: @"app") pointSize:18];
    cell.imageView.tintColor = HCGCommandCenterColorForConnection(item.connection.state);
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    cell.accessibilityLabel = [NSString stringWithFormat:@"%@, %@, %@", e.officialName, state, [HCGCommandCenter titleForRoadmapState:item.roadmap.state]];
    return cell;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSUInteger row = (NSUInteger)indexPath.row;
    switch ([self kindAt:indexPath.section]) {
        case HCGCCSectionDashboard: {
            NSArray *d = _dashboard[row];
            UITableViewCell *cell = [self styledCellWithStyle:UITableViewCellStyleSubtitle identifier:@"dash"];
            cell.textLabel.text = d[0];
            cell.detailTextLabel.text = d[1];
            cell.detailTextLabel.numberOfLines = 0;
            cell.imageView.image = [HCGTheme symbolNamed:d[2] pointSize:17];
            cell.imageView.tintColor = [HCGTheme cyan];
            BOOL action = [d[3] length] > 0;
            cell.accessoryType = action ? UITableViewCellAccessoryDisclosureIndicator : UITableViewCellAccessoryNone;
            cell.selectionStyle = action ? UITableViewCellSelectionStyleDefault : UITableViewCellSelectionStyleNone;
            return cell;
        }
        case HCGCCSectionNotices: {
            NSArray *n = _snapshot.notices[row];
            UITableViewCell *cell = [self styledCellWithStyle:UITableViewCellStyleDefault identifier:@"notice"];
            cell.textLabel.text = n[0];
            cell.textLabel.numberOfLines = 0;
            cell.imageView.image = [HCGTheme symbolNamed:@"bell.badge" pointSize:15];
            cell.imageView.tintColor = [HCGTheme warning];
            BOOL action = [n[1] length] > 0;
            cell.accessoryType = action ? UITableViewCellAccessoryDisclosureIndicator : UITableViewCellAccessoryNone;
            return cell;
        }
        case HCGCCSectionResults:
            if (!_results.count) {
                UITableViewCell *cell = [self styledCellWithStyle:UITableViewCellStyleDefault identifier:@"none"];
                cell.textLabel.text = @"No HCG product matches.";
                cell.textLabel.textColor = [HCGTheme secondaryText];
                cell.selectionStyle = UITableViewCellSelectionStyleNone;
                return cell;
            }
            return [self productCell:_results[row]];
        default:
            return [self productCell:[self itemsForSection:indexPath.section][row]];
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSUInteger row = (NSUInteger)indexPath.row;
    BOOL animated = !UIAccessibilityIsReduceMotionEnabled();
    switch ([self kindAt:indexPath.section]) {
        case HCGCCSectionDashboard: {
            NSString *action = _dashboard[row][3];
            UIViewController *next = nil;
            if ([action isEqualToString:@"roadmap"]) next = [[HCGRoadmapViewController alloc] initWithContext:self.context];
            else if ([action isEqualToString:@"devices"]) next = [[HCGDeviceClassesViewController alloc] initWithContext:self.context];
            else if ([action isEqualToString:@"trust"]) next = [[HCGTrustCenterViewController alloc] initWithContext:self.context];
            else if ([action isEqualToString:@"server"]) next = [[HCGProductProfileViewController alloc] initWithContext:self.context entryID:@"server"];
            else if ([action isEqualToString:@"registry"]) next = [[HCGRegistryInfoViewController alloc] initWithContext:self.context];
            if (next) [self.navigationController pushViewController:next animated:animated];
            return;
        }
        case HCGCCSectionNotices: {
            NSString *identifier = _snapshot.notices[row][1];
            if (identifier.length) [self.navigationController pushViewController:[[HCGProductProfileViewController alloc] initWithContext:self.context entryID:identifier] animated:animated];
            return;
        }
        default: {
            NSArray *items = [self kindAt:indexPath.section] == HCGCCSectionResults ? _results : [self itemsForSection:indexPath.section];
            if (row >= items.count) return;
            HCGCommandCenterItem *item = items[row];
            [self.navigationController pushViewController:[[HCGProductProfileViewController alloc] initWithContext:self.context entryID:item.entry.identifier] animated:animated];
        }
    }
}

@end
