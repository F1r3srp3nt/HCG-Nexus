#import "HCGWorkspaceManagerViewController.h"
#import "HCGWorkspaceDetailViewController.h"
#import "HCGTheme.h"

static NSString *const kCell = @"HCGWorkspaceCell";

@implementation HCGWorkspaceManagerViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Workspaces";
    UIBarButtonItem *add = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(addTapped:)];
    add.accessibilityLabel = @"New workspace";
    self.navigationItem.rightBarButtonItems = @[ add, self.editButtonItem ];
    self.tableView.allowsSelectionDuringEditing = YES;
}

- (HCGWorkspaceStore *)store {
    return self.context.model.workspaceStore;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.tableView reloadData];
}

#pragma mark Actions

- (void)addTapped:(UIBarButtonItem *)sender {
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"New workspace"
                                                                    message:@"Presets only organise shortcuts. They don't change notifications, other apps' state or permissions."
                                                             preferredStyle:UIAlertControllerStyleActionSheet];
    sheet.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    __weak typeof(self) weakSelf = self;
    for (NSString *preset in [HCGWorkspacePresets presetIdentifiers]) {
        NSString *title = [NSString stringWithFormat:@"%@ preset", [HCGWorkspacePresets displayNameForPreset:preset]];
        [sheet addAction:[UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
            [weakSelf createWithPreset:preset];
        }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"Empty workspace…" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        [weakSelf promptForTextWithTitle:@"New workspace" message:nil placeholder:@"Name" initialValue:nil actionTitle:@"Create"
                                 handler:^BOOL(NSString *text, NSError **error) {
            return [weakSelf createNamed:text preset:HCGPresetCustom error:error];
        }];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    sheet.popoverPresentationController.barButtonItem = sender;
    [self presentViewController:sheet animated:!UIAccessibilityIsReduceMotionEnabled() completion:nil];
}

- (void)createWithPreset:(NSString *)preset {
    NSError *error = nil;
    if (![self createNamed:nil preset:preset error:&error]) HCGPresentError(self, error, nil);
}

- (BOOL)createNamed:(NSString *)name preset:(NSString *)preset error:(NSError **)error {
    HCGWorkspace *created = [self.store createWorkspaceNamed:name preset:preset error:error];
    if (!created) return NO;
    [self.context.model workspacesDidChange];
    [self.tableView reloadData];
    UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, [NSString stringWithFormat:@"Created %@", created.name]);
    return YES;
}

- (void)renameWorkspace:(HCGWorkspace *)workspace {
    __weak typeof(self) weakSelf = self;
    NSString *identifier = workspace.identifier;
    [self promptForTextWithTitle:@"Rename workspace" message:nil placeholder:@"Name" initialValue:workspace.name actionTitle:@"Rename"
                         handler:^BOOL(NSString *text, NSError **error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (![strongSelf.store renameWorkspace:identifier to:text error:error]) return NO;
        [strongSelf.context.model workspacesDidChange];
        [strongSelf.tableView reloadData];
        return YES;
    }];
}

- (void)confirmDelete:(HCGWorkspace *)workspace {
    NSString *message = [NSString stringWithFormat:@"\"%@\" and its %lu shortcuts will be removed from HCG Nexus. Apps are not affected.",
                         workspace.name, (unsigned long)workspace.actions.count];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Delete workspace?" message:message preferredStyle:UIAlertControllerStyleAlert];
    alert.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    __weak typeof(self) weakSelf = self;
    NSString *identifier = workspace.identifier;
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Delete" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a) {
        NSError *error = nil;
        if (![weakSelf.store deleteWorkspace:identifier error:&error]) {
            HCGPresentError(weakSelf, error, nil);
            return;
        }
        [weakSelf.context.model workspacesDidChange];
        [weakSelf.tableView reloadData];
    }]];
    [self presentViewController:alert animated:!UIAccessibilityIsReduceMotionEnabled() completion:nil];
}

#pragma mark Table

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return MAX(1, (NSInteger)self.store.workspaces.count);
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    return @"Tap a workspace to edit its shortcuts. Use Edit to reorder or delete. Workspaces are stored locally and work without signing in.";
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [self styledCellWithStyle:UITableViewCellStyleSubtitle identifier:kCell];
    NSArray<HCGWorkspace *> *workspaces = self.store.workspaces;
    if (workspaces.count == 0) {
        cell.textLabel.text = @"No workspaces";
        cell.detailTextLabel.text = @"Tap + to create one from a preset.";
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        return cell;
    }
    HCGWorkspace *workspace = workspaces[(NSUInteger)indexPath.row];
    BOOL active = [workspace.identifier isEqualToString:self.store.activeWorkspace.identifier];
    cell.textLabel.text = workspace.name;
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ · %lu shortcuts%@",
                                 [HCGWorkspacePresets displayNameForPreset:workspace.preset],
                                 (unsigned long)workspace.actions.count, active ? @" · Active" : @""];
    cell.imageView.image = [HCGTheme symbolNamed:[HCGWorkspacePresets symbolNameForPreset:workspace.preset] pointSize:18];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    cell.showsReorderControl = YES;

    __weak typeof(self) weakSelf = self;
    NSMutableArray *custom = [NSMutableArray array];
    [custom addObject:[[UIAccessibilityCustomAction alloc] initWithName:@"Rename" actionHandler:^BOOL(UIAccessibilityCustomAction *a) {
        [weakSelf renameWorkspace:workspace];
        return YES;
    }]];
    [custom addObject:[[UIAccessibilityCustomAction alloc] initWithName:@"Delete" actionHandler:^BOOL(UIAccessibilityCustomAction *a) {
        [weakSelf confirmDelete:workspace];
        return YES;
    }]];
    cell.accessibilityCustomActions = custom;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSArray<HCGWorkspace *> *workspaces = self.store.workspaces;
    if (workspaces.count == 0) return;
    HCGWorkspace *workspace = workspaces[(NSUInteger)indexPath.row];
    if (tableView.isEditing) {
        [self renameWorkspace:workspace];
        return;
    }
    [self.navigationController pushViewController:[[HCGWorkspaceDetailViewController alloc] initWithContext:self.context workspaceIdentifier:workspace.identifier]
                                         animated:!UIAccessibilityIsReduceMotionEnabled()];
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return self.store.workspaces.count > 0;
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    return self.store.workspaces.count > 1;
}

- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)from toIndexPath:(NSIndexPath *)to {
    NSError *error = nil;
    if (![self.store moveWorkspaceFromIndex:(NSUInteger)from.row toIndex:(NSUInteger)to.row error:&error]) {
        HCGPresentError(self, error, nil);
        [tableView reloadData];
        return;
    }
    [self.context.model workspacesDidChange];
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSArray<HCGWorkspace *> *workspaces = self.store.workspaces;
    if (workspaces.count == 0) return nil;
    HCGWorkspace *workspace = workspaces[(NSUInteger)indexPath.row];
    __weak typeof(self) weakSelf = self;
    UIContextualAction *del = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive title:@"Delete"
                                                                    handler:^(UIContextualAction *a, UIView *v, void (^done)(BOOL)) {
        [weakSelf confirmDelete:workspace];
        done(NO);
    }];
    UIContextualAction *rename = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal title:@"Rename"
                                                                       handler:^(UIContextualAction *a, UIView *v, void (^done)(BOOL)) {
        [weakSelf renameWorkspace:workspace];
        done(YES);
    }];
    rename.backgroundColor = [UIColor colorWithRed:0.12 green:0.45 blue:0.52 alpha:1];
    return [UISwipeActionsConfiguration configurationWithActions:@[ del, rename ]];
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)style forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (style == UITableViewCellEditingStyleDelete && self.store.workspaces.count > 0) {
        [self confirmDelete:self.store.workspaces[(NSUInteger)indexPath.row]];
    }
}

- (void)setEditing:(BOOL)editing animated:(BOOL)animated {
    [super setEditing:editing animated:animated];
    if (!editing) [self.tableView reloadData];
}

@end
