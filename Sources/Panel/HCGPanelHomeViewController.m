#import "HCGPanelHomeViewController.h"
#import "HCGTheme.h"
#import "HCGWorkspaceManagerViewController.h"
#import "HCGWorkspaceDetailViewController.h"
#import "HCGPanelSettingsViewController.h"

typedef NS_ENUM(NSInteger, HCGHomeSection) {
    HCGHomeSectionShortcuts,
    HCGHomeSectionRecents,
    HCGHomeSectionIntegrations,
    HCGHomeSectionEmpty,
};

static NSString *const kCell = @"HCGHomeCell";

@interface HCGPanelHomeViewController () <UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate>
@end

@implementation HCGPanelHomeViewController {
    HCGPanelContext *_context;
    UILabel *_wordmark;
    UILabel *_subtitle;
    UILabel *_previewBadge;
    UIButton *_closeButton;
    UIScrollView *_chipScroll;
    UIStackView *_chipStack;
    UISearchTextField *_search;
    UITableView *_table;
    UIStackView *_footer;
    NSArray<NSNumber *> *_sections;
    NSArray<HCGSearchResult *> *_results;
    NSArray<HCGRecentEntry *> *_recents;
    NSArray<HCGIntegrationStatus *> *_integrations;
    UILabel *_toast;
}

- (instancetype)initWithContext:(HCGPanelContext *)context {
    if ((self = [super initWithNibName:nil bundle:nil])) {
        _context = context;
        _sections = @[];
        _results = @[];
        _recents = @[];
        _integrations = @[];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor clearColor];
    self.title = @"HCG Nexus";

    _wordmark = [[UILabel alloc] init];
    _wordmark.attributedText = [HCGTheme wordmarkWithSize:20];
    _wordmark.accessibilityLabel = @"HCG Nexus";
    _wordmark.accessibilityTraits = UIAccessibilityTraitHeader;
    _wordmark.adjustsFontSizeToFitWidth = YES;
    _wordmark.minimumScaleFactor = 0.7;

    _subtitle = [[UILabel alloc] init];
    _subtitle.font = [HCGTheme fontForTextStyle:UIFontTextStyleCaption1 weight:UIFontWeightMedium];
    _subtitle.adjustsFontForContentSizeCategory = YES;
    _subtitle.textColor = [HCGTheme secondaryText];

    _previewBadge = [[UILabel alloc] init];
    _previewBadge.text = @"  PREVIEW · NOT INJECTED  ";
    _previewBadge.font = [UIFont monospacedSystemFontOfSize:10 weight:UIFontWeightBold];
    _previewBadge.textColor = [HCGTheme obsidian];
    _previewBadge.backgroundColor = [HCGTheme warning];
    _previewBadge.layer.cornerRadius = 4;
    _previewBadge.clipsToBounds = YES;
    _previewBadge.hidden = !_context.isPreview;
    _previewBadge.accessibilityLabel = @"Preview harness. Not injected into SpringBoard.";

    _closeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [_closeButton setImage:[HCGTheme symbolNamed:@"xmark" pointSize:15] forState:UIControlStateNormal];
    _closeButton.tintColor = [HCGTheme primaryText];
    _closeButton.backgroundColor = [HCGTheme raisedSurface];
    _closeButton.layer.cornerRadius = 18;
    _closeButton.accessibilityLabel = @"Close HCG Nexus";
    _closeButton.hidden = !_context.insideOverlay;
    [_closeButton addTarget:self action:@selector(closeTapped) forControlEvents:UIControlEventTouchUpInside];
    [_closeButton.widthAnchor constraintEqualToConstant:44].active = YES;
    [_closeButton.heightAnchor constraintEqualToConstant:44].active = YES;

    UIStackView *titles = [[UIStackView alloc] initWithArrangedSubviews:@[ _wordmark, _subtitle ]];
    titles.axis = UILayoutConstraintAxisVertical;
    titles.spacing = 2;
    UIStackView *header = [[UIStackView alloc] initWithArrangedSubviews:@[ titles, _previewBadge, _closeButton ]];
    header.alignment = UIStackViewAlignmentCenter;
    header.spacing = 8;
    [titles setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];

    _chipStack = [[UIStackView alloc] init];
    _chipStack.spacing = 8;
    _chipScroll = [[UIScrollView alloc] init];
    _chipScroll.showsHorizontalScrollIndicator = NO;
    _chipStack.translatesAutoresizingMaskIntoConstraints = NO;
    [_chipScroll addSubview:_chipStack];
    [NSLayoutConstraint activateConstraints:@[
        [_chipStack.leadingAnchor constraintEqualToAnchor:_chipScroll.contentLayoutGuide.leadingAnchor],
        [_chipStack.trailingAnchor constraintEqualToAnchor:_chipScroll.contentLayoutGuide.trailingAnchor],
        [_chipStack.topAnchor constraintEqualToAnchor:_chipScroll.contentLayoutGuide.topAnchor],
        [_chipStack.bottomAnchor constraintEqualToAnchor:_chipScroll.contentLayoutGuide.bottomAnchor],
        [_chipStack.heightAnchor constraintEqualToAnchor:_chipScroll.frameLayoutGuide.heightAnchor],
        [_chipScroll.heightAnchor constraintGreaterThanOrEqualToConstant:44],
    ]];

    _search = [[UISearchTextField alloc] init];
    _search.placeholder = @"Search shortcuts";
    _search.attributedPlaceholder = [[NSAttributedString alloc] initWithString:@"Search shortcuts"
                                                                    attributes:@{ NSForegroundColorAttributeName : [HCGTheme secondaryText] }];
    _search.textColor = [HCGTheme primaryText];
    _search.backgroundColor = [HCGTheme raisedSurface];
    _search.tintColor = [HCGTheme cyan];
    _search.font = [HCGTheme fontForTextStyle:UIFontTextStyleBody weight:UIFontWeightRegular];
    _search.adjustsFontForContentSizeCategory = YES;
    _search.returnKeyType = UIReturnKeySearch;
    _search.autocorrectionType = UITextAutocorrectionTypeNo;
    _search.delegate = self;
    _search.accessibilityLabel = @"Search shortcuts in all workspaces";
    [_search addTarget:self action:@selector(searchChanged) forControlEvents:UIControlEventEditingChanged];
    [_search.heightAnchor constraintGreaterThanOrEqualToConstant:40].active = YES;

    _table = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
    [HCGTheme styleTableView:_table];
    _table.dataSource = self;
    _table.delegate = self;

    UIButton *workspaces = [self footerButton:@"Workspaces" symbol:@"square.stack.3d.up" action:@selector(openWorkspaces)];
    UIButton *edit = [self footerButton:@"Shortcuts" symbol:@"slider.horizontal.3" action:@selector(editActiveWorkspace)];
    UIButton *settings = [self footerButton:@"Settings" symbol:@"gearshape" action:@selector(openSettings)];
    _footer = [[UIStackView alloc] initWithArrangedSubviews:@[ workspaces, edit, settings ]];
    _footer.distribution = UIStackViewDistributionFillEqually;
    _footer.spacing = 8;

    _toast = [[UILabel alloc] init];
    _toast.numberOfLines = 0;
    _toast.textAlignment = NSTextAlignmentCenter;
    _toast.font = [HCGTheme fontForTextStyle:UIFontTextStyleFootnote weight:UIFontWeightMedium];
    _toast.adjustsFontForContentSizeCategory = YES;
    _toast.textColor = [HCGTheme primaryText];
    _toast.backgroundColor = [HCGTheme cyanSoft];
    _toast.layer.cornerRadius = 10;
    _toast.clipsToBounds = YES;
    _toast.hidden = YES;

    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[ header, _chipScroll, _search, _toast, _table, _footer ]];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 10;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [stack setCustomSpacing:4 afterView:_table];
    [self.view addSubview:stack];
    UILayoutGuide *guide = self.view.layoutMarginsGuide;
    self.view.directionalLayoutMargins = NSDirectionalEdgeInsetsMake(14, 14, 12, 14);
    self.viewRespectsSystemMinimumLayoutMargins = NO;
    [NSLayoutConstraint activateConstraints:@[
        [stack.leadingAnchor constraintEqualToAnchor:guide.leadingAnchor],
        [stack.trailingAnchor constraintEqualToAnchor:guide.trailingAnchor],
        [stack.topAnchor constraintEqualToAnchor:guide.topAnchor],
        [stack.bottomAnchor constraintEqualToAnchor:guide.bottomAnchor],
    ]];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadContent)
                                                 name:UIContentSizeCategoryDidChangeNotification object:nil];
    [self reloadContent];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.navigationController setNavigationBarHidden:YES animated:animated];
    [self reloadContent];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.navigationController setNavigationBarHidden:NO animated:animated];
}

- (UIButton *)footerButton:(NSString *)title symbol:(NSString *)symbol action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    [button setTitle:title forState:UIControlStateNormal];
    [button setImage:[HCGTheme symbolNamed:symbol pointSize:13] forState:UIControlStateNormal];
    button.titleLabel.font = [HCGTheme fontForTextStyle:UIFontTextStyleFootnote weight:UIFontWeightSemibold];
    button.titleLabel.adjustsFontForContentSizeCategory = YES;
    button.titleLabel.adjustsFontSizeToFitWidth = YES;
    button.titleLabel.minimumScaleFactor = 0.7;
    button.tintColor = [HCGTheme cyan];
    button.backgroundColor = [HCGTheme raisedSurface];
    button.layer.cornerRadius = 12;
    button.layer.borderWidth = 1;
    button.layer.borderColor = [HCGTheme separator].CGColor;
    [button.heightAnchor constraintGreaterThanOrEqualToConstant:44].active = YES;
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

#pragma mark Content

- (id)accessibilityFocusElement {
    return _wordmark;
}

- (void)resetTransientState {
    _search.text = @"";
    _toast.hidden = YES;
    [_table setContentOffset:CGPointZero animated:NO];
}

- (void)reloadContent {
    if (!self.isViewLoaded) return;
    HCGNexusModel *model = _context.model;
    HCGWorkspace *active = model.workspaceStore.activeWorkspace;
    _subtitle.text = active ? [NSString stringWithFormat:@"%@ workspace", active.name] : @"No workspace";
    [self rebuildChipsWithActive:active];

    _results = [HCGSearch resultsForQuery:_search.text inWorkspaces:model.workspaceStore.workspaces activeWorkspace:active];
    BOOL searching = _search.text.length > 0;
    _recents = searching ? @[] : model.recents.entries;
    _integrations = searching ? @[] : [model integrationStatuses];

    NSMutableArray *sections = [NSMutableArray array];
    if (model.workspaceStore.workspaces.count == 0 || (_results.count == 0 && !searching)) {
        [sections addObject:@(HCGHomeSectionEmpty)];
    }
    if (_results.count > 0 || searching) [sections addObject:@(HCGHomeSectionShortcuts)];
    if (_recents.count > 0) [sections addObject:@(HCGHomeSectionRecents)];
    if (_integrations.count > 0) [sections addObject:@(HCGHomeSectionIntegrations)];
    _sections = sections;
    [_table reloadData];
}

- (void)rebuildChipsWithActive:(HCGWorkspace *)active {
    for (UIView *view in _chipStack.arrangedSubviews) {
        [_chipStack removeArrangedSubview:view];
        [view removeFromSuperview];
    }
    NSArray<HCGWorkspace *> *workspaces = _context.model.workspaceStore.workspaces;
    for (NSUInteger i = 0; i < workspaces.count; i++) {
        HCGWorkspace *workspace = workspaces[i];
        BOOL selected = [workspace.identifier isEqualToString:active.identifier];
        UIButton *chip = [UIButton buttonWithType:UIButtonTypeSystem];
        [chip setTitle:workspace.name forState:UIControlStateNormal];
        [chip setImage:[HCGTheme symbolNamed:[HCGWorkspacePresets symbolNameForPreset:workspace.preset] pointSize:12] forState:UIControlStateNormal];
        chip.titleLabel.font = [HCGTheme fontForTextStyle:UIFontTextStyleSubheadline weight:selected ? UIFontWeightSemibold : UIFontWeightRegular];
        chip.titleLabel.adjustsFontForContentSizeCategory = YES;
        chip.tintColor = selected ? [HCGTheme cyan] : [HCGTheme secondaryText];
        chip.backgroundColor = selected ? [HCGTheme cyanSoft] : [HCGTheme raisedSurface];
        chip.layer.cornerRadius = 14;
        chip.layer.borderWidth = 1;
        chip.layer.borderColor = (selected ? [HCGTheme cyan] : [HCGTheme separator]).CGColor;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        // Still honoured when no UIButtonConfiguration is set; needed for iOS 14.
        chip.contentEdgeInsets = UIEdgeInsetsMake(8, 12, 8, 18);
        chip.titleEdgeInsets = UIEdgeInsetsMake(0, 6, 0, -6);
#pragma clang diagnostic pop
        chip.tag = (NSInteger)i;
        chip.accessibilityLabel = [NSString stringWithFormat:@"%@ workspace", workspace.name];
        chip.accessibilityTraits = UIAccessibilityTraitButton | (selected ? UIAccessibilityTraitSelected : 0);
        [chip addTarget:self action:@selector(chipTapped:) forControlEvents:UIControlEventTouchUpInside];
        [_chipStack addArrangedSubview:chip];
    }
}

- (void)chipTapped:(UIButton *)chip {
    NSArray<HCGWorkspace *> *workspaces = _context.model.workspaceStore.workspaces;
    if (chip.tag < 0 || (NSUInteger)chip.tag >= workspaces.count) return;
    NSError *error = nil;
    if (![_context.model.workspaceStore setActiveWorkspace:workspaces[chip.tag].identifier error:&error]) {
        HCGPresentError(self, error, nil);
        return;
    }
    [_context.model workspacesDidChange];
    [self reloadContent];
}

- (void)searchChanged {
    [self reloadContent];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}

- (void)showToast:(NSString *)message {
    _toast.text = [NSString stringWithFormat:@"  %@  ", message];
    _toast.hidden = NO;
    UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, message);
}

#pragma mark Navigation

- (void)closeTapped {
    if (_context.closePanel) _context.closePanel();
}

- (void)openWorkspaces {
    [self.navigationController pushViewController:[[HCGWorkspaceManagerViewController alloc] initWithContext:_context]
                                         animated:!UIAccessibilityIsReduceMotionEnabled()];
}

- (void)editActiveWorkspace {
    HCGWorkspace *active = _context.model.workspaceStore.activeWorkspace;
    if (!active) {
        [self openWorkspaces];
        return;
    }
    [self.navigationController pushViewController:[[HCGWorkspaceDetailViewController alloc] initWithContext:_context workspaceIdentifier:active.identifier]
                                         animated:!UIAccessibilityIsReduceMotionEnabled()];
}

- (void)openSettings {
    [self.navigationController pushViewController:[[HCGPanelSettingsViewController alloc] initWithContext:_context]
                                         animated:!UIAccessibilityIsReduceMotionEnabled()];
}

#pragma mark Running actions

- (void)runAction:(HCGAction *)action {
    __weak typeof(self) weakSelf = self;
    [_context.runner runAction:action completion:^(NSError *error, NSString *summary) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        [strongSelf reloadContent];
        if (error) {
            [strongSelf presentActionError:error];
            return;
        }
        if (strongSelf->_context.isPreview) {
            [strongSelf showToast:summary];
        } else if (strongSelf->_context.closePanelImmediately) {
            strongSelf->_context.closePanelImmediately();
        }
    }];
}

- (void)presentActionError:(NSError *)error {
    __weak typeof(self) weakSelf = self;
    UIAlertAction *extra = nil;
    if (error.code == HCGErrorIntegrationNotConnected) {
        extra = [UIAlertAction actionWithTitle:@"Integration Settings" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
            [weakSelf openSettings];
        }];
    } else if (error.code == HCGErrorAppNotInstalled || error.code == HCGErrorNoHandlerForURL || error.code == HCGErrorInvalidTarget) {
        extra = [UIAlertAction actionWithTitle:@"Edit Shortcuts" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
            [weakSelf editActiveWorkspace];
        }];
    }
    HCGPresentError(self, error, extra);
}

#pragma mark Table

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return (NSInteger)_sections.count;
}

- (HCGHomeSection)sectionAt:(NSInteger)index {
    return (HCGHomeSection)_sections[(NSUInteger)index].integerValue;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    switch ([self sectionAt:section]) {
        case HCGHomeSectionShortcuts: return _search.text.length ? @"Results" : @"Shortcuts";
        case HCGHomeSectionRecents: return @"Recent";
        case HCGHomeSectionIntegrations: return @"HCG Integrations";
        case HCGHomeSectionEmpty: return nil;
    }
    return nil;
}

- (void)tableView:(UITableView *)tableView willDisplayHeaderView:(UIView *)view forSection:(NSInteger)section {
    if ([view isKindOfClass:[UITableViewHeaderFooterView class]]) {
        UITableViewHeaderFooterView *header = (UITableViewHeaderFooterView *)view;
        header.textLabel.textColor = [HCGTheme secondaryText];
        header.textLabel.font = [HCGTheme fontForTextStyle:UIFontTextStyleCaption1 weight:UIFontWeightSemibold];
    }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch ([self sectionAt:section]) {
        case HCGHomeSectionShortcuts: return MAX(1, (NSInteger)_results.count);
        case HCGHomeSectionRecents: return (NSInteger)_recents.count;
        case HCGHomeSectionIntegrations: return (NSInteger)_integrations.count;
        case HCGHomeSectionEmpty: return 1;
    }
    return 0;
}

- (NSString *)subtitleForAction:(HCGAction *)action {
    switch (action.kind) {
        case HCGActionKindApp: return action.target;
        case HCGActionKindURL: return action.target;
        case HCGActionKindIntegration: {
            HCGIntegrationStatus *status = [_context.model statusForIntegration:action.target];
            return [NSString stringWithFormat:@"HCG integration · %@", status.headline];
        }
    }
    return @"";
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kCell];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:kCell];
    [HCGTheme styleCell:cell];
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.imageView.tintColor = [HCGTheme cyan];
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;

    switch ([self sectionAt:indexPath.section]) {
        case HCGHomeSectionShortcuts: {
            if (_results.count == 0) {
                cell.textLabel.text = @"No matching shortcuts";
                cell.detailTextLabel.text = @"Try another name, or add one under Shortcuts.";
                cell.imageView.image = [HCGTheme symbolNamed:@"magnifyingglass" pointSize:17];
                cell.selectionStyle = UITableViewCellSelectionStyleNone;
                break;
            }
            HCGSearchResult *result = _results[(NSUInteger)indexPath.row];
            cell.textLabel.text = result.action.title;
            NSString *detail = [self subtitleForAction:result.action];
            if (_search.text.length) detail = [NSString stringWithFormat:@"%@ · %@", result.workspace.name, detail];
            cell.detailTextLabel.text = detail;
            cell.imageView.image = [HCGTheme symbolNamed:result.action.symbolName pointSize:18];
            cell.accessibilityHint = @"Opens this shortcut.";
            break;
        }
        case HCGHomeSectionRecents: {
            HCGRecentEntry *entry = _recents[(NSUInteger)indexPath.row];
            NSRelativeDateTimeFormatter *formatter = [[NSRelativeDateTimeFormatter alloc] init];
            NSString *when = [formatter localizedStringForDate:entry.date relativeToDate:[NSDate date]];
            cell.textLabel.text = entry.action.title;
            cell.detailTextLabel.text = entry.succeeded ? when : [NSString stringWithFormat:@"%@ · %@", when, entry.message ?: @"Failed"];
            cell.imageView.image = [HCGTheme symbolNamed:entry.succeeded ? @"clock.arrow.circlepath" : @"exclamationmark.triangle" pointSize:17];
            cell.imageView.tintColor = entry.succeeded ? [HCGTheme secondaryText] : [HCGTheme warning];
            cell.accessibilityHint = @"Runs this action again.";
            break;
        }
        case HCGHomeSectionIntegrations: {
            HCGIntegrationStatus *status = _integrations[(NSUInteger)indexPath.row];
            cell.textLabel.text = status.displayName;
            cell.detailTextLabel.text = status.headline;
            cell.imageView.image = [HCGTheme symbolNamed:status.symbolName pointSize:17];
            BOOL ready = status.state == HCGIntegrationStateReady || status.state == HCGIntegrationStateUnverified;
            cell.detailTextLabel.textColor = ready ? [HCGTheme success] : [HCGTheme secondaryText];
            cell.imageView.tintColor = ready ? [HCGTheme cyan] : [HCGTheme secondaryText];
            cell.accessoryType = UITableViewCellAccessoryDetailButton;
            cell.accessibilityHint = status.canLaunch ? @"Opens the app." : @"Shows connection details.";
            break;
        }
        case HCGHomeSectionEmpty: {
            BOOL none = _context.model.workspaceStore.workspaces.count == 0;
            cell.textLabel.text = none ? @"No workspaces yet" : @"This workspace is empty";
            cell.detailTextLabel.text = none ? @"Create one from a preset under Workspaces." : @"Add app or link shortcuts under Shortcuts.";
            cell.imageView.image = [HCGTheme symbolNamed:@"plus.square.dashed" pointSize:18];
            break;
        }
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    switch ([self sectionAt:indexPath.section]) {
        case HCGHomeSectionShortcuts:
            if (_results.count > 0) [self runAction:_results[(NSUInteger)indexPath.row].action];
            break;
        case HCGHomeSectionRecents:
            [self runAction:_recents[(NSUInteger)indexPath.row].action];
            break;
        case HCGHomeSectionIntegrations: {
            HCGIntegrationStatus *status = _integrations[(NSUInteger)indexPath.row];
            if (status.canLaunch) {
                HCGAction *action = [HCGAction actionWithKind:HCGActionKindIntegration title:status.displayName target:status.identifier symbol:status.symbolName];
                action.identifier = [@"integration." stringByAppendingString:status.identifier];
                [self runAction:action];
            } else {
                [self showIntegrationDetail:status];
            }
            break;
        }
        case HCGHomeSectionEmpty:
            if (_context.model.workspaceStore.workspaces.count == 0) [self openWorkspaces];
            else [self editActiveWorkspace];
            break;
    }
}

- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath {
    if ([self sectionAt:indexPath.section] == HCGHomeSectionIntegrations) {
        [self showIntegrationDetail:_integrations[(NSUInteger)indexPath.row]];
    }
}

- (void)showIntegrationDetail:(HCGIntegrationStatus *)status {
    NSError *info = HCGMakeError(HCGErrorIntegrationNotConnected, [NSString stringWithFormat:@"%@: %@", status.displayName, status.headline], status.detail);
    __weak typeof(self) weakSelf = self;
    UIAlertAction *settings = [UIAlertAction actionWithTitle:@"Integration Settings" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        [weakSelf openSettings];
    }];
    HCGPresentError(self, info, settings);
}

@end
