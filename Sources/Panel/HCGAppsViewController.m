#import "HCGAppsViewController.h"
#import "HCGTheme.h"

@interface HCGAppsViewController () <UISearchBarDelegate>
@end

@implementation HCGAppsViewController {
    UISearchBar *_search;
    UISegmentedControl *_filter;
    UIButton *_editButton;
    NSArray<HCGAction *> *_items;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Apps";
    self.tableView.tableHeaderView = [self makeHeader];
    [self modelDidChange];
}

- (UIButton *)headerButton:(NSString *)title symbol:(NSString *)symbol action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    [button setTitle:title forState:UIControlStateNormal];
    [button setImage:[HCGTheme symbolNamed:symbol pointSize:13] forState:UIControlStateNormal];
    button.titleLabel.font = [HCGTheme fontForTextStyle:UIFontTextStyleFootnote weight:UIFontWeightSemibold];
    button.titleLabel.adjustsFontForContentSizeCategory = YES;
    button.tintColor = [HCGTheme cyan];
    [HCGTheme styleCard:button cornerRadius:12];
    [button.heightAnchor constraintGreaterThanOrEqualToConstant:44].active = YES;
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (UIView *)makeHeader {
    _search = [[UISearchBar alloc] init];
    _search.searchBarStyle = UISearchBarStyleMinimal;
    _search.placeholder = @"Search apps and links";
    _search.delegate = self;
    _search.searchTextField.textColor = [HCGTheme primaryText];
    _search.searchTextField.backgroundColor = [HCGTheme glassRow];
    _search.tintColor = [HCGTheme cyan];
    _search.searchTextField.accessibilityLabel = @"Search Apps";

    _filter = [[UISegmentedControl alloc] initWithItems:@[ @"All", @"Favourites" ]];
    _filter.selectedSegmentIndex = 0;
    _filter.selectedSegmentTintColor = [HCGTheme cyanSoft];
    [_filter setTitleTextAttributes:@{ NSForegroundColorAttributeName : [HCGTheme primaryText] } forState:UIControlStateNormal];
    [_filter addTarget:self action:@selector(filterChanged) forControlEvents:UIControlEventValueChanged];
    [_filter.heightAnchor constraintGreaterThanOrEqualToConstant:36].active = YES;

    UIButton *add = [self headerButton:@"Add" symbol:@"plus" action:@selector(addTapped)];
    add.accessibilityLabel = @"Add an app or link";
    _editButton = [self headerButton:@"Reorder" symbol:@"arrow.up.arrow.down" action:@selector(toggleEditing)];
    UIStackView *buttons = [[UIStackView alloc] initWithArrangedSubviews:@[ _filter, add, _editButton ]];
    buttons.spacing = 8;
    buttons.alignment = UIStackViewAlignmentCenter;
    [_filter setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];

    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[ _search, buttons ]];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 6;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 112)];
    [header addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [stack.leadingAnchor constraintEqualToAnchor:header.layoutMarginsGuide.leadingAnchor],
        [stack.trailingAnchor constraintEqualToAnchor:header.layoutMarginsGuide.trailingAnchor],
        [stack.topAnchor constraintEqualToAnchor:header.topAnchor constant:4],
        [stack.bottomAnchor constraintEqualToAnchor:header.bottomAnchor constant:-4],
    ]];
    return header;
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    UIView *header = self.tableView.tableHeaderView;
    CGSize size = [header systemLayoutSizeFittingSize:CGSizeMake(self.tableView.bounds.size.width, UILayoutFittingCompressedSize.height)
                        withHorizontalFittingPriority:UILayoutPriorityRequired verticalFittingPriority:UILayoutPriorityFittingSizeLevel];
    if (fabs(header.frame.size.height - size.height) > 0.5 || fabs(header.frame.size.width - self.tableView.bounds.size.width) > 0.5) {
        header.frame = CGRectMake(0, 0, self.tableView.bounds.size.width, size.height);
        self.tableView.tableHeaderView = header;
    }
}

- (HCGAppLibrary *)library {
    return self.context.model.appLibrary;
}

- (BOOL)isFiltering {
    return _search.text.length > 0 || _filter.selectedSegmentIndex == 1;
}

- (void)modelDidChange {
    _items = [[self library] itemsMatchingQuery:_search.text favouritesOnly:_filter.selectedSegmentIndex == 1];
    _editButton.enabled = ![self isFiltering] && [self library].items.count > 1;
    if ([self isFiltering] && self.tableView.isEditing) [self.tableView setEditing:NO animated:NO];
    [self.tableView reloadData];
}

- (void)filterChanged {
    [self modelDidChange];
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    [self modelDidChange];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
}

- (void)toggleEditing {
    if ([self isFiltering]) return;
    [self.tableView setEditing:!self.tableView.isEditing animated:!UIAccessibilityIsReduceMotionEnabled()];
    [_editButton setTitle:self.tableView.isEditing ? @"Done" : @"Reorder" forState:UIControlStateNormal];
    if (!self.tableView.isEditing) [self modelDidChange];
}

#pragma mark Adding

- (void)addTapped {
    UIAlertController *choice = [UIAlertController alertControllerWithTitle:@"Add to Apps" message:nil preferredStyle:UIAlertControllerStyleAlert];
    choice.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    __weak typeof(self) weakSelf = self;
    [choice addAction:[UIAlertAction actionWithTitle:@"App (bundle identifier)" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        [weakSelf promptForKind:HCGActionKindApp title:nil target:nil];
    }]];
    [choice addAction:[UIAlertAction actionWithTitle:@"Link (URL)" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        [weakSelf promptForKind:HCGActionKindURL title:nil target:nil];
    }]];
    [choice addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:choice animated:YES completion:nil];
}

- (void)promptForKind:(HCGActionKind)kind title:(NSString *)initialTitle target:(NSString *)initialTarget {
    BOOL app = kind == HCGActionKindApp;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:app ? @"Add App" : @"Add Link"
                                                                   message:app ? @"Enter the app's bundle identifier, for example com.apple.DocumentsApp." : @"Enter a link such as https://… or mailto:…"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    alert.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.placeholder = @"Title";
        field.text = initialTitle;
        field.autocapitalizationType = UITextAutocapitalizationTypeWords;
    }];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.placeholder = app ? @"Bundle identifier" : @"https://";
        field.text = initialTarget;
        field.autocapitalizationType = UITextAutocapitalizationTypeNone;
        field.autocorrectionType = UITextAutocorrectionTypeNo;
        field.keyboardType = app ? UIKeyboardTypeASCIICapable : UIKeyboardTypeURL;
    }];
    __weak typeof(self) weakSelf = self;
    __weak UIAlertController *weakAlert = alert;
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Add" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        NSString *title = [weakAlert.textFields[0].text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] ?: @"";
        NSString *target = [weakAlert.textFields[1].text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] ?: @"";
        HCGAction *action = [HCGAction actionWithKind:kind title:title target:target symbol:app ? @"app" : @"link"];
        NSError *error = nil;
        HCGAction *added = [[weakSelf library] addItem:action error:&error];
        if (!added) {
            // Re-present with the values kept, after showing why.
            UIAlertAction *retry = [UIAlertAction actionWithTitle:@"Edit" style:UIAlertActionStyleDefault handler:^(UIAlertAction *r) {
                [weakSelf promptForKind:kind title:title target:target];
            }];
            HCGPresentError(weakSelf, error, retry);
            return;
        }
        [weakSelf.context.model appsDidChange];
        [weakSelf.context feedback:[NSString stringWithFormat:@"Added %@.", added.title] success:YES];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark Table

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (self.context.model.launcher && ![self.context.model.launcher canLaunchApplicationsByBundleIdentifier]) {
        return @"In the standalone app, links open; apps by bundle identifier need the jailbreak package. Swipe a row for more.";
    }
    return @"Tap to open. Star for Favourites. Swipe to add to the active workspace or delete.";
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return MAX(1, (NSInteger)_items.count);
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [self styledCellWithStyle:UITableViewCellStyleSubtitle identifier:@"app"];
    if (_items.count == 0) {
        BOOL empty = [self library].items.count == 0;
        cell.textLabel.text = empty ? @"No apps yet" : @"Nothing matches";
        cell.detailTextLabel.text = empty ? @"Add an app or link, or use Tools › Import Workspace Shortcuts." : @"Try another search or show All.";
        cell.imageView.image = [HCGTheme symbolNamed:empty ? @"plus.square.dashed" : @"magnifyingglass" pointSize:18];
        cell.selectionStyle = empty ? UITableViewCellSelectionStyleDefault : UITableViewCellSelectionStyleNone;
        return cell;
    }
    HCGAction *item = _items[(NSUInteger)indexPath.row];
    BOOL favourite = [[self library] isFavourite:item.identifier];
    cell.textLabel.text = item.title;
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ · %@", item.kind == HCGActionKindApp ? @"App" : @"Link", item.target];
    cell.imageView.image = [HCGTheme symbolNamed:item.symbolName pointSize:18];
    UIButton *star = [UIButton buttonWithType:UIButtonTypeSystem];
    [star setImage:[HCGTheme symbolNamed:favourite ? @"star.fill" : @"star" pointSize:16] forState:UIControlStateNormal];
    star.tintColor = favourite ? [HCGTheme violet] : [HCGTheme secondaryText];
    star.frame = CGRectMake(0, 0, 44, 44);
    star.accessibilityLabel = favourite ? [NSString stringWithFormat:@"Remove %@ from Favourites", item.title]
                                        : [NSString stringWithFormat:@"Add %@ to Favourites", item.title];
    star.tag = indexPath.row;
    [star addTarget:self action:@selector(starTapped:) forControlEvents:UIControlEventTouchUpInside];
    cell.accessoryView = star;
    cell.accessibilityHint = @"Opens this shortcut.";
    return cell;
}

- (void)starTapped:(UIButton *)star {
    if (star.tag < 0 || (NSUInteger)star.tag >= _items.count) return;
    HCGAction *item = _items[(NSUInteger)star.tag];
    BOOL favourite = ![[self library] isFavourite:item.identifier];
    NSError *error = nil;
    if (![[self library] setFavourite:favourite forItem:item.identifier error:&error]) {
        HCGPresentError(self, error, nil);
        return;
    }
    [self.context.model appsDidChange];
    UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, favourite ? @"Added to Favourites" : @"Removed from Favourites");
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (_items.count == 0) {
        if ([self library].items.count == 0) [self addTapped];
        return;
    }
    HCGAction *item = _items[(NSUInteger)indexPath.row];
    if (!self.context.runner) {
        [self.context feedback:@"Shortcuts can't be opened from here." success:NO];
        return;
    }
    __weak typeof(self) weakSelf = self;
    [self.context.runner runAction:item completion:^(NSError *error, NSString *summary) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        if (error) {
            HCGPresentError(strongSelf, error, nil);
        } else if (strongSelf.context.insideOverlay && !strongSelf.context.isPreview && strongSelf.context.closePanelImmediately) {
            strongSelf.context.closePanelImmediately();
        } else {
            [strongSelf.context feedback:summary success:YES];
        }
    }];
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (_items.count == 0) return nil;
    HCGAction *item = _items[(NSUInteger)indexPath.row];
    __weak typeof(self) weakSelf = self;
    UIContextualAction *remove = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive title:@"Delete"
                                                                       handler:^(UIContextualAction *a, UIView *v, void (^done)(BOOL)) {
        NSError *error = nil;
        BOOL ok = [[weakSelf library] removeItemWithIdentifier:item.identifier error:&error];
        if (ok) {
            [weakSelf.context.model appsDidChange];
            [weakSelf.context feedback:[NSString stringWithFormat:@"Deleted %@. Workspaces keep their own copies.", item.title] success:YES];
        } else {
            HCGPresentError(weakSelf, error, nil);
        }
        done(ok);
    }];
    UIContextualAction *addToWorkspace = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal title:@"To Workspace"
                                                                               handler:^(UIContextualAction *a, UIView *v, void (^done)(BOOL)) {
        HCGWorkspace *active = weakSelf.context.model.workspaceStore.activeWorkspace;
        if (!active) {
            [weakSelf.context feedback:@"Create a workspace first." success:NO];
            done(NO);
            return;
        }
        NSError *error = nil;
        BOOL ok = [weakSelf.context.model.workspaceStore addAction:[item copy] toWorkspace:active.identifier error:&error];
        if (ok) {
            [weakSelf.context.model workspacesDidChange];
            [weakSelf.context feedback:[NSString stringWithFormat:@"Added %@ to %@.", item.title, active.name] success:YES];
        } else {
            HCGPresentError(weakSelf, error, nil);
        }
        done(ok);
    }];
    addToWorkspace.backgroundColor = [HCGTheme violet];
    return [UISwipeActionsConfiguration configurationWithActions:@[ remove, addToWorkspace ]];
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    return ![self isFiltering] && _items.count > 1;
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
    return UITableViewCellEditingStyleNone;
}

- (BOOL)tableView:(UITableView *)tableView shouldIndentWhileEditingRowAtIndexPath:(NSIndexPath *)indexPath {
    return NO;
}

- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)from toIndexPath:(NSIndexPath *)to {
    NSError *error = nil;
    if (![[self library] moveItemFromIndex:(NSUInteger)from.row toIndex:(NSUInteger)to.row error:&error]) {
        HCGPresentError(self, error, nil);
        [self modelDidChange];
        return;
    }
    _items = [[self library] itemsMatchingQuery:nil favouritesOnly:NO];
    [self.context.model appsDidChange];
}

@end
