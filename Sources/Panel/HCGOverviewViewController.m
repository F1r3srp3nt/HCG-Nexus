#import "HCGOverviewViewController.h"
#import "HCGTheme.h"
#import "HCGBranding.h"
#import "HCGSections.h"
#import "HCGPanelServices.h"
#import "HCGWorkspaceDetailViewController.h"
#import "HCGPanelSettingsViewController.h"

typedef NS_ENUM(NSInteger, HCGOverviewRowGroup) {
    HCGOverviewGroupNotice,
    HCGOverviewGroupWorkspace,
    HCGOverviewGroupQuickActions,
    HCGOverviewGroupStatus,
    HCGOverviewGroupDevice,
};

@implementation HCGOverviewViewController {
    UIView *_hero;
    HCGGlowLineView *_glow;
    NSArray<NSNumber *> *_groups;
    NSArray<HCGAction *> *_quickActions;
    NSArray<NSArray<NSString *> *> *_deviceRows;
    UIScrollView *_chips;
    BOOL _visible;
    BOOL _noticeDismissed;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Overview";
    self.tableView.tableHeaderView = [self makeHero];
    [self modelDidChange];
}

#pragma mark Hero

- (UIView *)makeHero {
    UIView *container = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 128)];
    UIView *card = [[UIView alloc] init];
    [HCGTheme styleCard:card cornerRadius:16];
    card.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:card];

    UIImage *banner = [HCGBranding nexusBanner];
    NSMutableArray *constraints = [NSMutableArray arrayWithArray:@[
        [card.leadingAnchor constraintEqualToAnchor:container.layoutMarginsGuide.leadingAnchor],
        [card.trailingAnchor constraintEqualToAnchor:container.layoutMarginsGuide.trailingAnchor],
        [card.topAnchor constraintEqualToAnchor:container.topAnchor constant:6],
        [card.bottomAnchor constraintEqualToAnchor:container.bottomAnchor constant:-6],
    ]];
    if (banner) {
        // Official banner: 3:1, aspect fill, centred (sides crop on narrow panels).
        UIImageView *image = [[UIImageView alloc] initWithImage:banner];
        image.contentMode = UIViewContentModeScaleAspectFill;
        image.clipsToBounds = YES;
        image.isAccessibilityElement = YES;
        image.accessibilityLabel = @"HCG Nexus";
        image.accessibilityTraits = UIAccessibilityTraitImage | UIAccessibilityTraitHeader;
        image.translatesAutoresizingMaskIntoConstraints = NO;
        [card addSubview:image];
        [constraints addObjectsFromArray:@[
            [image.leadingAnchor constraintEqualToAnchor:card.leadingAnchor], [image.trailingAnchor constraintEqualToAnchor:card.trailingAnchor],
            [image.topAnchor constraintEqualToAnchor:card.topAnchor], [image.bottomAnchor constraintEqualToAnchor:card.bottomAnchor],
        ]];
    } else {
        // No official banner bundled: a typographic header (emblem + status), not presented as a banner.
        UIImageView *emblem = [[UIImageView alloc] initWithImage:[HCGBranding nexusEmblem]];
        emblem.contentMode = UIViewContentModeScaleAspectFit;
        emblem.layer.cornerRadius = 12;
        emblem.layer.cornerCurve = kCACornerCurveContinuous;
        emblem.clipsToBounds = YES;
        emblem.isAccessibilityElement = NO;
        emblem.hidden = emblem.image == nil;
        [emblem.widthAnchor constraintEqualToConstant:64].active = YES;
        [emblem.heightAnchor constraintEqualToConstant:64].active = YES;

        UILabel *title = [[UILabel alloc] init];
        title.attributedText = [HCGTheme wordmarkWithSize:22];
        title.adjustsFontSizeToFitWidth = YES;
        title.minimumScaleFactor = 0.7;
        title.accessibilityTraits = UIAccessibilityTraitHeader;
        title.accessibilityLabel = @"HCG Nexus";
        UILabel *subtitle = [[UILabel alloc] init];
        subtitle.font = [HCGTheme fontForTextStyle:UIFontTextStyleFootnote weight:UIFontWeightMedium];
        subtitle.adjustsFontForContentSizeCategory = YES;
        subtitle.textColor = [HCGTheme secondaryText];
        subtitle.numberOfLines = 2;
        subtitle.text = [NSString stringWithFormat:@"%@ · %@", HCGBuildVersion(), [self modeLine]];
        UIStackView *text = [[UIStackView alloc] initWithArrangedSubviews:@[ title, subtitle ]];
        text.axis = UILayoutConstraintAxisVertical;
        text.spacing = 4;
        UIStackView *row = [[UIStackView alloc] initWithArrangedSubviews:@[ emblem, text ]];
        row.alignment = UIStackViewAlignmentCenter;
        row.spacing = 14;
        row.translatesAutoresizingMaskIntoConstraints = NO;
        [card addSubview:row];
        [constraints addObjectsFromArray:@[
            [row.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],
            [row.trailingAnchor constraintLessThanOrEqualToAnchor:card.trailingAnchor constant:-16],
            [row.centerYAnchor constraintEqualToAnchor:card.centerYAnchor],
        ]];
    }
    _glow = [[HCGGlowLineView alloc] init];
    _glow.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:_glow];
    [constraints addObjectsFromArray:@[
        [_glow.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],
        [_glow.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16],
        [_glow.bottomAnchor constraintEqualToAnchor:card.bottomAnchor],
        [_glow.heightAnchor constraintEqualToConstant:1],
    ]];
    [NSLayoutConstraint activateConstraints:constraints];
    _hero = container;
    return container;
}

- (NSString *)modeLine {
    switch (self.context.mode) {
        case HCGPanelModeOverlay: return HCGIsCandidateBuild() ? @"Jailbreak tweak · free candidate demo" : @"Jailbreak tweak";
        case HCGPanelModeStandaloneApp: return @"Standalone app";
        case HCGPanelModePreview: return @"Preview harness (simulation)";
        case HCGPanelModeSettingsApp: return @"Settings";
    }
    return @"";
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    // Hero height follows the banner's 3:1 ratio, clamped for small and wide panels.
    CGFloat width = self.tableView.bounds.size.width;
    CGFloat height = [HCGBranding nexusBanner] ? MIN(150, MAX(96, (width - 32) / 3.0 + 12)) : 108;
    if (fabs(_hero.frame.size.height - height) > 0.5 || fabs(_hero.frame.size.width - width) > 0.5) {
        _hero.frame = CGRectMake(0, 0, width, height);
        self.tableView.tableHeaderView = _hero;
    }
}

#pragma mark Lifecycle

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self panelDidAppear];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [self panelDidDisappear];
}

- (void)panelDidAppear {
    if (_visible) return;
    _visible = YES;
    [HCGDeviceFacts beginMonitoring];
    [self modelDidChange];
    if ([HCGTheme decorativeMotionAllowedWithSettings:self.context.model.settings]) [_glow startAnimating];
}

- (void)panelDidDisappear {
    if (!_visible) return;
    _visible = NO;
    [_glow stopAnimating];
    [HCGDeviceFacts endMonitoring];
}

#pragma mark Content

- (void)modelDidChange {
    HCGNexusModel *model = self.context.model;
    HCGWorkspace *active = model.workspaceStore.activeWorkspace;
    NSMutableArray *quick = [NSMutableArray array];
    for (NSString *identifier in active.quickActionIdentifiers) {
        HCGAction *item = [model.appLibrary itemWithIdentifier:identifier];
        if (item) [quick addObject:item];
    }
    _quickActions = quick;
    _deviceRows = [HCGDeviceFacts rows];
    NSMutableArray *groups = [NSMutableArray array];
    if (model.lastMigrationOutcome == HCGLayoutMigrationMigrated && !_noticeDismissed) [groups addObject:@(HCGOverviewGroupNotice)];
    [groups addObjectsFromArray:@[ @(HCGOverviewGroupWorkspace), @(HCGOverviewGroupQuickActions), @(HCGOverviewGroupStatus), @(HCGOverviewGroupDevice) ]];
    _groups = groups;
    [self.tableView reloadData];
}

- (HCGOverviewRowGroup)groupAt:(NSInteger)section {
    return (HCGOverviewRowGroup)_groups[(NSUInteger)section].integerValue;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return (NSInteger)_groups.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    switch ([self groupAt:section]) {
        case HCGOverviewGroupNotice: return nil;
        case HCGOverviewGroupWorkspace: return @"Active workspace";
        case HCGOverviewGroupQuickActions: return @"Quick actions";
        case HCGOverviewGroupStatus: return @"Account & connections";
        case HCGOverviewGroupDevice: return @"This device";
    }
    return nil;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if ([self groupAt:section] == HCGOverviewGroupDevice) return @"Read on this device with public iOS APIs. Nothing is estimated or sent anywhere.";
    return nil;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch ([self groupAt:section]) {
        case HCGOverviewGroupNotice: return 1;
        case HCGOverviewGroupWorkspace: return 2;
        case HCGOverviewGroupQuickActions: return MAX(1, (NSInteger)_quickActions.count);
        case HCGOverviewGroupStatus: return 3;
        case HCGOverviewGroupDevice: return (NSInteger)_deviceRows.count;
    }
    return 0;
}

- (UITableViewCell *)chipCell {
    UITableViewCell *cell = [self styledCellWithStyle:UITableViewCellStyleDefault identifier:@"chips"];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    [_chips removeFromSuperview];
    _chips = [[UIScrollView alloc] init];
    _chips.showsHorizontalScrollIndicator = NO;
    _chips.translatesAutoresizingMaskIntoConstraints = NO;
    UIStackView *stack = [[UIStackView alloc] init];
    stack.spacing = 8;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [_chips addSubview:stack];
    [cell.contentView addSubview:_chips];
    UILayoutGuide *margins = cell.contentView.layoutMarginsGuide;
    [NSLayoutConstraint activateConstraints:@[
        [_chips.leadingAnchor constraintEqualToAnchor:cell.contentView.leadingAnchor constant:12],
        [_chips.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor constant:-12],
        [_chips.topAnchor constraintEqualToAnchor:margins.topAnchor],
        [_chips.bottomAnchor constraintEqualToAnchor:margins.bottomAnchor],
        [_chips.heightAnchor constraintGreaterThanOrEqualToConstant:44],
        [stack.leadingAnchor constraintEqualToAnchor:_chips.contentLayoutGuide.leadingAnchor],
        [stack.trailingAnchor constraintEqualToAnchor:_chips.contentLayoutGuide.trailingAnchor],
        [stack.topAnchor constraintEqualToAnchor:_chips.contentLayoutGuide.topAnchor],
        [stack.bottomAnchor constraintEqualToAnchor:_chips.contentLayoutGuide.bottomAnchor],
        [stack.heightAnchor constraintEqualToAnchor:_chips.frameLayoutGuide.heightAnchor],
    ]];
    HCGWorkspaceStore *store = self.context.model.workspaceStore;
    NSArray<HCGWorkspace *> *workspaces = store.workspaces;
    for (NSUInteger i = 0; i < workspaces.count; i++) {
        HCGWorkspace *workspace = workspaces[i];
        BOOL selected = [workspace.identifier isEqualToString:store.activeWorkspace.identifier];
        UIButton *chip = [UIButton buttonWithType:UIButtonTypeSystem];
        [chip setTitle:workspace.name forState:UIControlStateNormal];
        [chip setImage:[HCGTheme symbolNamed:[HCGWorkspacePresets symbolNameForPreset:workspace.preset] pointSize:12] forState:UIControlStateNormal];
        chip.titleLabel.font = [HCGTheme fontForTextStyle:UIFontTextStyleSubheadline weight:selected ? UIFontWeightSemibold : UIFontWeightRegular];
        chip.titleLabel.adjustsFontForContentSizeCategory = YES;
        chip.tintColor = selected ? [HCGTheme cyan] : [HCGTheme secondaryText];
        chip.backgroundColor = selected ? [HCGTheme cyanSoft] : [UIColor clearColor];
        chip.layer.cornerRadius = 15;
        chip.layer.cornerCurve = kCACornerCurveContinuous;
        chip.layer.borderWidth = 1;
        chip.layer.borderColor = (selected ? [HCGTheme cyan] : [HCGTheme hairline]).CGColor;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        chip.contentEdgeInsets = UIEdgeInsetsMake(8, 12, 8, 18);
        chip.titleEdgeInsets = UIEdgeInsetsMake(0, 6, 0, -6);
#pragma clang diagnostic pop
        [chip.heightAnchor constraintGreaterThanOrEqualToConstant:44].active = YES;
        chip.tag = (NSInteger)i;
        chip.accessibilityLabel = [NSString stringWithFormat:@"%@ workspace", workspace.name];
        chip.accessibilityTraits = UIAccessibilityTraitButton | (selected ? UIAccessibilityTraitSelected : 0);
        chip.accessibilityHint = selected ? @"Active." : @"Switches to this workspace.";
        [chip addTarget:self action:@selector(chipTapped:) forControlEvents:UIControlEventTouchUpInside];
        [stack addArrangedSubview:chip];
    }
    return cell;
}

- (void)chipTapped:(UIButton *)chip {
    NSArray<HCGWorkspace *> *workspaces = self.context.model.workspaceStore.workspaces;
    if (chip.tag < 0 || (NSUInteger)chip.tag >= workspaces.count) return;
    HCGWorkspace *workspace = workspaces[(NSUInteger)chip.tag];
    NSError *error = nil;
    if (![self.context.model.workspaceStore setActiveWorkspace:workspace.identifier error:&error]) {
        HCGPresentError(self, error, nil);
        return;
    }
    [self.context.model workspacesDidChange];
    [self.context feedback:[NSString stringWithFormat:@"Switched to %@", workspace.name] success:YES];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    HCGNexusModel *model = self.context.model;
    switch ([self groupAt:indexPath.section]) {
        case HCGOverviewGroupNotice: {
            UITableViewCell *cell = [self styledCellWithStyle:UITableViewCellStyleSubtitle identifier:@"notice"];
            cell.textLabel.text = model.lastMigrationImported > 0
                ? [NSString stringWithFormat:@"%lu shortcuts are now also in Apps", (unsigned long)model.lastMigrationImported]
                : @"Nexus has a new layout";
            cell.detailTextLabel.text = @"Your workspaces kept every shortcut. Tools › Restore Previous Layout undoes this. Tap to dismiss.";
            cell.imageView.image = [HCGTheme symbolNamed:@"sparkles" pointSize:17];
            cell.imageView.tintColor = [HCGTheme violet];
            return cell;
        }
        case HCGOverviewGroupWorkspace: {
            if (indexPath.row == 0) return [self chipCell];
            UITableViewCell *cell = [self styledCellWithStyle:UITableViewCellStyleSubtitle identifier:@"ws"];
            HCGWorkspace *active = model.workspaceStore.activeWorkspace;
            cell.textLabel.text = active ? [NSString stringWithFormat:@"Edit %@", active.name] : @"Create a workspace";
            cell.detailTextLabel.text = active ? [NSString stringWithFormat:@"%lu shortcuts · %lu quick actions · %lu tools", (unsigned long)active.actions.count,
                                                  (unsigned long)active.quickActionIdentifiers.count, (unsigned long)active.toolIdentifiers.count]
                                               : @"Workspaces group your shortcuts, quick actions and tools.";
            cell.imageView.image = [HCGTheme symbolNamed:@"slider.horizontal.3" pointSize:17];
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            return cell;
        }
        case HCGOverviewGroupQuickActions: {
            UITableViewCell *cell = [self styledCellWithStyle:UITableViewCellStyleSubtitle identifier:@"quick"];
            if (_quickActions.count == 0) {
                cell.textLabel.text = @"Choose quick actions";
                cell.detailTextLabel.text = model.appLibrary.items.count ? @"Pick up to four apps or links for this workspace." : @"Add apps or links under Apps first.";
                cell.imageView.image = [HCGTheme symbolNamed:@"plus.circle" pointSize:18];
                return cell;
            }
            HCGAction *action = _quickActions[(NSUInteger)indexPath.row];
            cell.textLabel.text = action.title;
            BOOL bundleLaunch = action.kind == HCGActionKindApp && model.launcher && ![model.launcher canLaunchApplicationsByBundleIdentifier];
            cell.detailTextLabel.text = bundleLaunch ? @"App · needs the jailbreak package" : action.target;
            cell.imageView.image = [HCGTheme symbolNamed:action.symbolName pointSize:18];
            cell.accessibilityHint = @"Opens this shortcut.";
            return cell;
        }
        case HCGOverviewGroupStatus: {
            UITableViewCell *cell = [self styledCellWithStyle:UITableViewCellStyleValue1 identifier:@"status"];
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            id<HCGAccountProviding> account = self.context.accountProvider;
            if (indexPath.row == 0) {
                cell.textLabel.text = @"HCG account";
                cell.detailTextLabel.text = account ? [HCGAccountRules titleForState:[account accountState]] : @"In the standalone app";
                cell.imageView.image = [HCGTheme symbolNamed:@"person.crop.circle" pointSize:17];
            } else if (indexPath.row == 1) {
                cell.textLabel.text = @"Connected Devices";
                cell.detailTextLabel.text = account ? [account connectionSummary] : @"In the standalone app";
                cell.imageView.image = [HCGTheme symbolNamed:@"link" pointSize:17];
            } else {
                cell.textLabel.text = @"HCG Products";
                cell.detailTextLabel.text = [self productsSummary];
                cell.imageView.image = [HCGTheme symbolNamed:@"cube.box" pointSize:17];
            }
            return cell;
        }
        case HCGOverviewGroupDevice: {
            UITableViewCell *cell = [self styledCellWithStyle:UITableViewCellStyleValue1 identifier:@"device"];
            NSArray<NSString *> *row = _deviceRows[(NSUInteger)indexPath.row];
            cell.textLabel.text = row[0];
            cell.detailTextLabel.text = row[1];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            return cell;
        }
    }
    return [self styledCellWithStyle:UITableViewCellStyleDefault identifier:@"x"];
}

- (NSString *)productsSummary {
    id<HCGAppInstallationProbe> probe = self.context.model.launcher;
    NSUInteger phoneApps = 0, installed = 0, unknown = 0;
    for (HCGProductInfo *product in [HCGProductCatalog allProducts]) {
        if (!product.hasPhoneApp) continue;
        phoneApps++;
        HCGProductInstallState state = [HCGProductCatalog installStateForProduct:product probe:probe];
        if (state == HCGProductInstallStateInstalled) installed++;
        if (state == HCGProductInstallStateUnknown) unknown++;
    }
    if (unknown == phoneApps) return @"Installation unknown here";
    return [NSString stringWithFormat:@"%lu of %lu apps installed", (unsigned long)installed, (unsigned long)phoneApps];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    HCGNexusModel *model = self.context.model;
    switch ([self groupAt:indexPath.section]) {
        case HCGOverviewGroupNotice:
            _noticeDismissed = YES;
            [self modelDidChange];
            break;
        case HCGOverviewGroupWorkspace: {
            if (indexPath.row == 0) break;
            HCGWorkspace *active = model.workspaceStore.activeWorkspace;
            if (!active) {
                if (self.context.showSection) self.context.showSection(HCGNexusSectionWorkspaces);
                break;
            }
            [self.navigationController pushViewController:[[HCGWorkspaceDetailViewController alloc] initWithContext:self.context workspaceIdentifier:active.identifier]
                                                 animated:!UIAccessibilityIsReduceMotionEnabled()];
            break;
        }
        case HCGOverviewGroupQuickActions:
            if (_quickActions.count == 0) {
                HCGWorkspace *active = model.workspaceStore.activeWorkspace;
                if (model.appLibrary.items.count == 0 || !active) {
                    if (self.context.showSection) self.context.showSection(model.appLibrary.items.count == 0 ? HCGNexusSectionApps : HCGNexusSectionWorkspaces);
                } else {
                    [self.navigationController pushViewController:[[HCGWorkspaceDetailViewController alloc] initWithContext:self.context workspaceIdentifier:active.identifier]
                                                         animated:!UIAccessibilityIsReduceMotionEnabled()];
                }
            } else {
                [self runAction:_quickActions[(NSUInteger)indexPath.row]];
            }
            break;
        case HCGOverviewGroupStatus:
            if (self.context.showSection) {
                self.context.showSection(indexPath.row == 0 ? HCGNexusSectionAccount : (indexPath.row == 1 ? HCGNexusSectionDevices : HCGNexusSectionProducts));
            }
            break;
        case HCGOverviewGroupDevice:
            break;
    }
}

- (void)runAction:(HCGAction *)action {
    if (!self.context.runner) {
        [self.context feedback:@"Shortcuts can't be opened from here." success:NO];
        return;
    }
    __weak typeof(self) weakSelf = self;
    [self.context.runner runAction:action completion:^(NSError *error, NSString *summary) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        if (error) {
            HCGPresentError(strongSelf, error, nil);
            return;
        }
        if (strongSelf.context.insideOverlay && !strongSelf.context.isPreview && strongSelf.context.closePanelImmediately) {
            strongSelf.context.closePanelImmediately();
        } else {
            [strongSelf.context feedback:summary success:YES];
        }
    }];
}

@end
