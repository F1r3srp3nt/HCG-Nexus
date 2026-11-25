#import "HCGProductsViewController.h"
#import "HCGTheme.h"
#import "HCGEcosystemData.h"
#import "HCGProductDetailViewController.h"
#import "HCGDeviceStatusMonitor.h"
#import "HCGTrustCenterViewController.h"

// HCG Ecosystem: the control centre for every HCG product on this iPhone (docs/INTERCHANGE.md).
// Everything shown is read without side effects; every action is the user's tap and only opens something.

typedef NS_ENUM(NSInteger, HCGEcosystemGroup) {
    HCGEcosystemGroupDevice = 0,
    HCGEcosystemGroupTrust,
    HCGEcosystemGroupInstalled,
    HCGEcosystemGroupAvailable,
    HCGEcosystemGroupLater,
    HCGEcosystemGroupDiagnostics,
    HCGEcosystemGroupActivity,
};

UIColor *HCGEcosystemColorForAvailability(HCGHIPAvailability availability) {
    switch (availability) {
        case HCGHIPAvailabilityReady:
        case HCGHIPAvailabilityHub: return [HCGTheme cyan];
        case HCGHIPAvailabilityAttention: return [HCGTheme warning];
        case HCGHIPAvailabilityNeedsUpdate: return [HCGTheme violet];
        case HCGHIPAvailabilityUnsupportedOS: return [HCGTheme critical];
        default: return [HCGTheme secondaryText];
    }
}

#pragma mark - Chip

@interface HCGEcosystemChip : UILabel
@end

@implementation HCGEcosystemChip
- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.font = [HCGTheme fontForTextStyle:UIFontTextStyleCaption1 weight:UIFontWeightSemibold maximumPointSize:HCGChipMaximumPointSize];
        self.textAlignment = NSTextAlignmentCenter;
        self.layer.cornerRadius = 10;
        self.layer.borderWidth = 1;
        self.clipsToBounds = YES;
        [self setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
        [self setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    }
    return self;
}
- (CGSize)intrinsicContentSize {
    CGSize size = [super intrinsicContentSize];
    return CGSizeMake(size.width + 16, MAX(20, size.height + 4));
}
- (void)setTint:(UIColor *)color {
    self.textColor = color;
    self.layer.borderColor = [color colorWithAlphaComponent:0.7].CGColor;
    self.backgroundColor = [color colorWithAlphaComponent:0.14];
}
@end

#pragma mark - Product card

@interface HCGEcosystemCardCell : UITableViewCell
- (void)configureWithStatus:(HCGHIPProductStatus *)status;
@end

@implementation HCGEcosystemCardCell {
    UIView *_card;
    UIImageView *_icon;
    UIView *_iconWell;
    UILabel *_name;
    HCGEcosystemChip *_chip;
    UILabel *_version;
    UILabel *_line;
    UILabel *_capabilities;
    UILabel *_update;
}

static UILabel *HCGCardLabel(UIFontTextStyle style, UIFontWeight weight, UIColor *color) {
    UILabel *label = [[UILabel alloc] init];
    label.font = [HCGTheme fontForTextStyle:style weight:weight];
    label.adjustsFontForContentSizeCategory = NO;
    label.textColor = color;
    label.numberOfLines = 0;
    return label;
}

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    if ((self = [super initWithStyle:style reuseIdentifier:reuseIdentifier])) {
        self.backgroundColor = [UIColor clearColor];
        self.contentView.backgroundColor = [UIColor clearColor];
        UIView *selected = [[UIView alloc] init];
        selected.backgroundColor = [UIColor clearColor];
        self.selectedBackgroundView = selected;

        _card = [[UIView alloc] init];
        _card.translatesAutoresizingMaskIntoConstraints = NO;
        [HCGTheme styleCard:_card cornerRadius:16];
        [self.contentView addSubview:_card];

        _iconWell = [[UIView alloc] init];
        _iconWell.translatesAutoresizingMaskIntoConstraints = NO;
        _iconWell.layer.cornerRadius = 10;
        _iconWell.layer.cornerCurve = kCACornerCurveContinuous;
        _icon = [[UIImageView alloc] init];
        _icon.translatesAutoresizingMaskIntoConstraints = NO;
        _icon.contentMode = UIViewContentModeCenter;
        [_iconWell addSubview:_icon];

        _name = HCGCardLabel(UIFontTextStyleHeadline, UIFontWeightSemibold, [HCGTheme primaryText]);
        _chip = [[HCGEcosystemChip alloc] init];
        _version = HCGCardLabel(UIFontTextStyleCaption1, UIFontWeightRegular, [HCGTheme secondaryText]);
        _line = HCGCardLabel(UIFontTextStyleSubheadline, UIFontWeightRegular, [HCGTheme primaryText]);
        _capabilities = HCGCardLabel(UIFontTextStyleCaption1, UIFontWeightMedium, [HCGTheme secondaryText]);
        _update = HCGCardLabel(UIFontTextStyleCaption1, UIFontWeightSemibold, [HCGTheme violet]);

        UIStackView *top = [[UIStackView alloc] initWithArrangedSubviews:@[ _name, _chip ]];
        top.alignment = UIStackViewAlignmentCenter;
        top.spacing = 8;
        UIStackView *text = [[UIStackView alloc] initWithArrangedSubviews:@[ top, _version, _line, _capabilities, _update ]];
        text.axis = UILayoutConstraintAxisVertical;
        text.spacing = 3;
        text.translatesAutoresizingMaskIntoConstraints = NO;
        [_card addSubview:_iconWell];
        [_card addSubview:text];

        [NSLayoutConstraint activateConstraints:@[
            [_card.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:12],
            [_card.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-12],
            [_card.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:5],
            [_card.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-5],
            [_iconWell.leadingAnchor constraintEqualToAnchor:_card.leadingAnchor constant:12],
            [_iconWell.topAnchor constraintEqualToAnchor:_card.topAnchor constant:14],
            [_iconWell.widthAnchor constraintEqualToConstant:40],
            [_iconWell.heightAnchor constraintEqualToConstant:40],
            [_icon.centerXAnchor constraintEqualToAnchor:_iconWell.centerXAnchor],
            [_icon.centerYAnchor constraintEqualToAnchor:_iconWell.centerYAnchor],
            [text.leadingAnchor constraintEqualToAnchor:_iconWell.trailingAnchor constant:12],
            [text.trailingAnchor constraintEqualToAnchor:_card.trailingAnchor constant:-12],
            [text.topAnchor constraintEqualToAnchor:_card.topAnchor constant:12],
            [text.bottomAnchor constraintEqualToAnchor:_card.bottomAnchor constant:-12],
            [_card.heightAnchor constraintGreaterThanOrEqualToConstant:68],
        ]];
        self.accessibilityTraits = UIAccessibilityTraitButton;
    }
    return self;
}

- (void)configureWithStatus:(HCGHIPProductStatus *)status {
    HCGHIPProductDescriptor *d = status.descriptor;
    UIColor *tint = HCGEcosystemColorForAvailability(status.availability);
    BOOL lit = status.availability == HCGHIPAvailabilityReady || status.availability == HCGHIPAvailabilityHub;
    _icon.image = [HCGTheme symbolNamed:d.symbolName pointSize:20];
    _icon.tintColor = lit ? [HCGTheme cyan] : tint;
    _iconWell.backgroundColor = lit ? [HCGTheme cyanSoft] : [[HCGTheme raisedSurface] colorWithAlphaComponent:0.8];
    _name.text = d.name;
    _chip.text = status.simulated ? [status.stateTitle stringByAppendingString:@" · sim"] : status.stateTitle;
    [_chip setTint:tint];
    _version.text = status.versionText;

    NSString *line = status.healthText;
    if (status.availability == HCGHIPAvailabilityUnsupportedOS || status.availability == HCGHIPAvailabilityNeedsUpdate ||
        status.availability == HCGHIPAvailabilityUnknown) line = status.compatibilityText;
    if (status.availability == HCGHIPAvailabilityNotAvailable || status.availability == HCGHIPAvailabilityNotInstalled) line = d.summary;
    _line.text = line;

    NSUInteger verified = 0, available = 0, planned = 0;
    for (HCGHIPResolvedCapability *c in status.capabilities) {
        if (c.state == HCGHIPCapabilityStateVerified) verified++;
        else if (c.state == HCGHIPCapabilityStateAvailable) available++;
        else if (c.state == HCGHIPCapabilityStatePlanned) planned++;
    }
    NSMutableArray *parts = [NSMutableArray array];
    if (verified) [parts addObject:[NSString stringWithFormat:@"%lu verified", (unsigned long)verified]];
    if (available) [parts addObject:[NSString stringWithFormat:@"%lu available", (unsigned long)available]];
    if (planned) [parts addObject:[NSString stringWithFormat:@"%lu planned", (unsigned long)planned]];
    NSUInteger shortcuts = 0;
    for (HCGHIPRoute *route in status.routes) if (route.kind != HCGHIPRouteKindPackageManager && route.kind != HCGHIPRouteKindWeb) shortcuts++;
    if (shortcuts) [parts addObject:[NSString stringWithFormat:@"%lu shortcut%@", (unsigned long)shortcuts, shortcuts == 1 ? @"" : @"s"]];
    _capabilities.text = parts.count ? [parts componentsJoinedByString:@" · "] : nil;
    _capabilities.hidden = parts.count == 0;
    _update.text = status.updateAvailable ? [@"Update: " stringByAppendingString:status.offeredVersion ?: @""] : nil;
    _update.hidden = !status.updateAvailable;

    // A faint cyan rim on products that are running; nothing moves.
    _card.layer.borderColor = (lit ? [[HCGTheme cyan] colorWithAlphaComponent:0.45] : [HCGTheme hairline]).CGColor;
    _card.layer.shadowColor = [HCGTheme cyan].CGColor;
    _card.layer.shadowOpacity = lit && ![HCGTheme reduceTransparency] ? 0.18f : 0;
    _card.layer.shadowRadius = 8;
    _card.layer.shadowOffset = CGSizeZero;
    _card.clipsToBounds = !(lit && ![HCGTheme reduceTransparency]);

    self.accessibilityLabel = [NSString stringWithFormat:@"%@, %@, %@", d.name, status.stateTitle, status.versionText];
    self.accessibilityValue = line;
    self.accessibilityHint = @"Shows status, shortcuts and capabilities.";
}
@end

#pragma mark - Dashboard

@implementation HCGProductsViewController {
    HCGEcosystemSnapshot *_snapshot;
    NSArray<NSNumber *> *_groups;
    NSArray<HCGHIPProductStatus *> *_installed;
    NSArray<HCGHIPProductStatus *> *_available;
    NSArray<HCGHIPProductStatus *> *_later;
    NSArray<NSArray<NSString *> *> *_diagnostics;
    NSArray<NSDictionary *> *_activity;
    HCGDeviceStatusMonitor *_monitor;
    NSArray<HCGStatusDisplay *> *_deviceDisplays;
    NSMutableSet<NSIndexPath *> *_revealed;
    UILabel *_headerSubtitle;
    HCGGlowLineView *_glow;
    BOOL _loading;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"HCG Ecosystem";
    _revealed = [NSMutableSet set];
    [self.tableView registerClass:[HCGEcosystemCardCell class] forCellReuseIdentifier:@"card"];
    self.tableView.estimatedRowHeight = 92;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.tableHeaderView = [self makeHeader];
    _groups = @[ @(HCGEcosystemGroupDevice) ];
    _monitor = [[HCGDeviceStatusMonitor alloc] init];
    __weak typeof(self) weakSelf = self;
    _monitor.changeHandler = ^(HCGDeviceStatusSnapshot *snapshot) {
        typeof(self) strongSelf = weakSelf;
        if (!strongSelf) return;
        strongSelf->_deviceDisplays = [HCGCommandModeStatus deviceDisplaysForSnapshot:snapshot];
        [strongSelf.tableView reloadData];
    };
}

- (UIView *)makeHeader {
    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 86)];
    UILabel *title = [[UILabel alloc] init];
    title.text = @"HCG ECOSYSTEM";
    title.font = [HCGTheme fontForTextStyle:UIFontTextStyleTitle3 weight:UIFontWeightBold maximumPointSize:26];
    title.textColor = [HCGTheme primaryText];
    title.accessibilityTraits = UIAccessibilityTraitHeader;
    _headerSubtitle = [[UILabel alloc] init];
    _headerSubtitle.font = [HCGTheme fontForTextStyle:UIFontTextStyleFootnote weight:UIFontWeightMedium maximumPointSize:17];
    _headerSubtitle.textColor = [HCGTheme secondaryText];
    _headerSubtitle.numberOfLines = 2;
    _headerSubtitle.text = @"Reading your HCG products…";
    _glow = [[HCGGlowLineView alloc] init];
    _glow.translatesAutoresizingMaskIntoConstraints = NO;
    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[ title, _headerSubtitle ]];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 2;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [header addSubview:stack];
    [header addSubview:_glow];
    [NSLayoutConstraint activateConstraints:@[
        [stack.leadingAnchor constraintEqualToAnchor:header.leadingAnchor constant:20],
        [stack.trailingAnchor constraintEqualToAnchor:header.trailingAnchor constant:-20],
        [stack.topAnchor constraintEqualToAnchor:header.topAnchor constant:14],
        [_glow.leadingAnchor constraintEqualToAnchor:header.leadingAnchor constant:20],
        [_glow.trailingAnchor constraintEqualToAnchor:header.trailingAnchor constant:-20],
        [_glow.bottomAnchor constraintEqualToAnchor:header.bottomAnchor constant:-6],
        [_glow.heightAnchor constraintEqualToConstant:1],
    ]];
    return header;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self reloadEcosystem];
    [_monitor start];
    if ([HCGTheme decorativeMotionAllowedWithSettings:self.context.model.settings]) [_glow startAnimating];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [_monitor stop];
    [_glow stopAnimating];
}

- (void)modelDidChange {
    [self reloadEcosystem];
}

- (void)reloadEcosystem {
    if (_loading) return;
    _loading = YES;
    __weak typeof(self) weakSelf = self;
    [HCGEcosystemData loadWithLauncher:self.context.model.launcher completion:^(HCGEcosystemSnapshot *snapshot) {
        typeof(self) strongSelf = weakSelf;
        if (!strongSelf) return;
        strongSelf->_loading = NO;
        [strongSelf applySnapshot:snapshot];
    }];
}

- (void)applySnapshot:(HCGEcosystemSnapshot *)snapshot {
    _snapshot = snapshot;
    NSMutableArray *installed = [NSMutableArray array], *available = [NSMutableArray array], *later = [NSMutableArray array];
    NSUInteger updates = 0, attention = 0;
    for (HCGHIPProductStatus *status in snapshot.statuses) {
        if (status.descriptor.kind == HCGHIPProductKindRepository) continue; // shown in diagnostics and on every card
        if (status.availability == HCGHIPAvailabilityNotAvailable) [later addObject:status];
        else if (status.installed) [installed addObject:status];
        else [available addObject:status];
        if (status.updateAvailable) updates++;
        if (status.availability == HCGHIPAvailabilityAttention || status.availability == HCGHIPAvailabilityNeedsUpdate) attention++;
    }
    _installed = installed;
    _available = available;
    _later = later;
    _activity = [self.context.model ecosystemActivity];
    _diagnostics = [self diagnosticsRows];

    NSUInteger others = installed.count ? installed.count - 1 : 0; // HCG Nexus itself is always listed
    NSMutableArray *summary = [NSMutableArray array];
    [summary addObject:snapshot.inspected ? [NSString stringWithFormat:@"%lu HCG product%@ installed", (unsigned long)others, others == 1 ? @"" : @"s"]
                                          : @"Installed products are private to this app"];
    if (updates) [summary addObject:[NSString stringWithFormat:@"%lu update%@", (unsigned long)updates, updates == 1 ? @"" : @"s"]];
    if (attention) [summary addObject:[NSString stringWithFormat:@"%lu need%@ attention", (unsigned long)attention, attention == 1 ? @"s" : @""]];
    if (snapshot.simulated) [summary addObject:@"SIMULATED"];
    _headerSubtitle.text = [summary componentsJoinedByString:@" · "];

    NSMutableArray *groups = [NSMutableArray arrayWithObjects:@(HCGEcosystemGroupDevice), @(HCGEcosystemGroupTrust), nil];
    if (installed.count) [groups addObject:@(HCGEcosystemGroupInstalled)];
    if (available.count) [groups addObject:@(HCGEcosystemGroupAvailable)];
    if (later.count) [groups addObject:@(HCGEcosystemGroupLater)];
    [groups addObject:@(HCGEcosystemGroupDiagnostics)];
    [groups addObject:@(HCGEcosystemGroupActivity)];
    _groups = groups;
    [self.tableView reloadData];
}

- (NSArray *)diagnosticsRows {
    NSMutableArray *rows = [NSMutableArray array];
    HCGEcosystemSnapshot *s = _snapshot;
    [rows addObject:@[ @"Discovery", s.simulated ? @"Simulated (preview harness)" : (s.inspected ? @"Read-only scan in SpringBoard" : @"Sandboxed app: links only") ]];
    [rows addObject:@[ @"HCG Interchange", [NSString stringWithFormat:@"Protocol %ld · %lu products known", (long)HCGInterchangeProtocolVersion, (unsigned long)[HCGInterchange registry].count] ]];
    if (self.context.haloBorderStatus) {
        HCGHaloBorderStatus *halo = self.context.haloBorderStatus();
        [rows addObject:@[ @"HCG Halo border", [HCGHaloBorderStatus titleForState:halo.state] ]];
    }
    BOOL portal = NSClassFromString(@"HCGNexusPortalInterface") != nil && self.context.insideOverlay;
    BOOL allowed = self.context.model.settings.companionOpenAllowed;
    [rows addObject:@[ @"HCG apps can open Nexus", !self.context.insideOverlay ? @"In the jailbreak package only" : (allowed ? (portal ? @"On (Portal interface v1, app requests)" : @"On") : @"Off in settings") ]];
    NSUInteger known = 0;
    for (HCGHIPFacts *f in s.facts) if (f.offeredVersion.length) known++;
    HCGHIPFacts *repo = [s factsForProductID:HCGHIPProductRepo];
    NSString *managers = repo.packageManagers.count ? [[repo.packageManagers componentsJoinedByString:@", "] capitalizedString] : @"none found";
    if (s.inspected) {
        [rows addObject:@[ @"Package manager", managers ]];
        [rows addObject:@[ @"HCG Repo versions", known ? [NSString stringWithFormat:@"Known for %lu packages (as of the last refresh)", (unsigned long)known]
                                                      : @"No HCG Repo lists found; refresh in Zebra or Sileo" ]];
    }
    for (HCGHIPProductStatus *status in s.statuses) {
        if (status.declarationNote.length) [rows addObject:@[ status.descriptor.name, status.declarationNote ]];
    }
    return rows;
}

#pragma mark Table

- (HCGEcosystemGroup)groupAt:(NSInteger)section {
    return (HCGEcosystemGroup)[_groups[(NSUInteger)section] integerValue];
}

- (NSArray<HCGHIPProductStatus *> *)productsInGroup:(HCGEcosystemGroup)group {
    if (group == HCGEcosystemGroupInstalled) return _installed;
    if (group == HCGEcosystemGroupAvailable) return _available;
    if (group == HCGEcosystemGroupLater) return _later;
    return @[];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return (NSInteger)_groups.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    switch ([self groupAt:section]) {
        case HCGEcosystemGroupDevice: return @"This iPhone";
        case HCGEcosystemGroupTrust: return @"Security";
        case HCGEcosystemGroupInstalled: return @"Installed";
        case HCGEcosystemGroupAvailable: return @"Not installed";
        case HCGEcosystemGroupLater: return @"Not on this iPhone yet";
        case HCGEcosystemGroupDiagnostics: return @"Integration diagnostics";
        case HCGEcosystemGroupActivity: return @"Activity";
    }
    return nil;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    switch ([self groupAt:section]) {
        case HCGEcosystemGroupInstalled:
            return @"Read-only: Nexus reads each product's own status and settings and opens its screens. It never runs commands, changes another product's settings (except the HCG Halo border switch, through HCG Halo) or installs packages.";
        case HCGEcosystemGroupLater:
            return @"Adapters are prepared; nothing is connected. HCG Connect stays the only sign-in authority, and no credentials pass between apps.";
        case HCGEcosystemGroupActivity:
            return _activity.count ? @"What Nexus opened or switched, kept on this iPhone only." : @"Nothing yet. Opening a product or a screen from here is listed.";
        default: return nil;
    }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch ([self groupAt:section]) {
        case HCGEcosystemGroupDevice: return (NSInteger)(_snapshot.deviceRows.count + _deviceDisplays.count);
        case HCGEcosystemGroupTrust: return 1;
        case HCGEcosystemGroupDiagnostics: return (NSInteger)_diagnostics.count;
        case HCGEcosystemGroupActivity: return (NSInteger)MIN(_activity.count, (NSUInteger)12) + (_activity.count ? 1 : 0);
        default: return (NSInteger)[self productsInGroup:[self groupAt:section]].count;
    }
}

- (UITableViewCell *)valueCellTitle:(NSString *)title value:(NSString *)value symbol:(NSString *)symbol {
    UITableViewCell *cell = [self styledCellWithStyle:UITableViewCellStyleValue1 identifier:@"value"];
    cell.textLabel.text = title;
    cell.detailTextLabel.text = value;
    cell.detailTextLabel.numberOfLines = 0;
    cell.imageView.image = symbol ? [HCGTheme symbolNamed:symbol pointSize:16] : nil;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.accessoryType = UITableViewCellAccessoryNone;
    return cell;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    HCGEcosystemGroup group = [self groupAt:indexPath.section];
    NSUInteger row = (NSUInteger)indexPath.row;
    switch (group) {
        case HCGEcosystemGroupDevice: {
            if (row < _snapshot.deviceRows.count) {
                NSArray *pair = _snapshot.deviceRows[row];
                return [self valueCellTitle:pair[0] value:pair[1] symbol:row == 0 ? @"iphone" : (row == 1 ? @"gear" : @"lock.open")];
            }
            HCGStatusDisplay *display = _deviceDisplays[row - _snapshot.deviceRows.count];
            UITableViewCell *cell = [self valueCellTitle:display.title value:display.value symbol:display.symbolName];
            cell.imageView.tintColor = [HCGTheme colorForStatusRole:display.colorRole];
            return cell;
        }
        case HCGEcosystemGroupTrust: {
            UITableViewCell *cell = [self styledCellWithStyle:UITableViewCellStyleSubtitle identifier:@"trust"];
            cell.textLabel.text = @"Package Trust Center";
            cell.detailTextLabel.text = @"Repository signatures, checksums, Release Passports, entitlements and installed packages. Read-only.";
            cell.detailTextLabel.numberOfLines = 0;
            cell.imageView.image = [HCGTheme symbolNamed:@"checkmark.shield" pointSize:18];
            cell.imageView.tintColor = [HCGTheme cyan];
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            cell.selectionStyle = UITableViewCellSelectionStyleDefault;
            return cell;
        }
        case HCGEcosystemGroupDiagnostics: {
            NSArray *pair = _diagnostics[row];
            UITableViewCell *cell = [self styledCellWithStyle:UITableViewCellStyleSubtitle identifier:@"diag"];
            cell.textLabel.text = pair[0];
            cell.detailTextLabel.text = pair[1];
            cell.detailTextLabel.numberOfLines = 0;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            return cell;
        }
        case HCGEcosystemGroupActivity: {
            if (row == MIN(_activity.count, (NSUInteger)12)) {
                UITableViewCell *cell = [self styledCellWithStyle:UITableViewCellStyleDefault identifier:@"clear"];
                cell.textLabel.text = @"Clear Activity";
                cell.textLabel.textColor = [HCGTheme cyan];
                return cell;
            }
            NSDictionary *entry = _activity[row];
            UITableViewCell *cell = [self styledCellWithStyle:UITableViewCellStyleSubtitle identifier:@"activity"];
            cell.textLabel.text = entry[@"text"];
            cell.textLabel.numberOfLines = 0;
            NSDate *time = [NSDate dateWithTimeIntervalSince1970:[entry[@"time"] doubleValue]];
            NSRelativeDateTimeFormatter *formatter = [[NSRelativeDateTimeFormatter alloc] init];
            cell.detailTextLabel.text = [formatter localizedStringForDate:time relativeToDate:[NSDate date]];
            HCGHIPProductDescriptor *d = [HCGInterchange descriptorForProductID:entry[@"product"]];
            cell.imageView.image = [HCGTheme symbolNamed:d.symbolName ?: @"clock" pointSize:15];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            return cell;
        }
        default: {
            HCGEcosystemCardCell *cell = [tableView dequeueReusableCellWithIdentifier:@"card" forIndexPath:indexPath];
            [cell configureWithStatus:[self productsInGroup:group][row]];
            return cell;
        }
    }
}

// Cards rise in once, staggered; never with Reduce Motion or Animations off.
- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (![cell isKindOfClass:[HCGEcosystemCardCell class]] || [_revealed containsObject:indexPath]) return;
    [_revealed addObject:indexPath];
    if (![HCGTheme decorativeMotionAllowedWithSettings:self.context.model.settings]) return;
    cell.alpha = 0;
    cell.transform = CGAffineTransformMakeTranslation(0, 14);
    [UIView animateWithDuration:0.38 delay:0.04 * MIN(indexPath.row, 8) usingSpringWithDamping:0.86 initialSpringVelocity:0
                        options:UIViewAnimationOptionAllowUserInteraction animations:^{
        cell.alpha = 1;
        cell.transform = CGAffineTransformIdentity;
    } completion:nil];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    HCGEcosystemGroup group = [self groupAt:indexPath.section];
    if (group == HCGEcosystemGroupTrust) {
        [self.navigationController pushViewController:[[HCGTrustCenterViewController alloc] initWithContext:self.context]
                                             animated:!UIAccessibilityIsReduceMotionEnabled()];
        return;
    }
    if (group == HCGEcosystemGroupActivity) {
        if ((NSUInteger)indexPath.row == MIN(_activity.count, (NSUInteger)12)) {
            [self.context.model clearEcosystemActivity];
            _activity = @[];
            [tableView reloadData];
        }
        return;
    }
    NSArray *products = [self productsInGroup:group];
    if ((NSUInteger)indexPath.row >= products.count) return;
    HCGHIPProductStatus *status = products[(NSUInteger)indexPath.row];
    [self showProductWithID:status.descriptor.productID];
}

- (void)showProductWithID:(NSString *)productID {
    if (![HCGInterchange descriptorForProductID:productID]) return;
    HCGProductDetailViewController *detail = [[HCGProductDetailViewController alloc] initWithContext:self.context productID:productID];
    [self.navigationController pushViewController:detail animated:!UIAccessibilityIsReduceMotionEnabled()];
}

@end
