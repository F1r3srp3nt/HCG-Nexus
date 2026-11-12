#import "HCGWorkspaceDetailViewController.h"
#import "HCGShortcutEditorViewController.h"
#import "HCGTheme.h"

typedef NS_ENUM(NSInteger, HCGDetailSection) {
    HCGDetailSectionShortcuts = 0,
    HCGDetailSectionWorkspace = 1,
};

static NSString *const kCell = @"HCGDetailCell";

@implementation HCGWorkspaceDetailViewController {
    NSString *_identifier;
}

- (instancetype)initWithContext:(HCGPanelContext *)context workspaceIdentifier:(NSString *)identifier {
    if ((self = [super initWithContext:context])) {
        _identifier = [identifier copy];
    }
    return self;
}

- (HCGWorkspaceStore *)store {
    return self.context.model.workspaceStore;
}

- (HCGWorkspace *)workspace {
    return [self.store workspaceWithIdentifier:_identifier];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    UIBarButtonItem *add = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(addShortcut)];
    add.accessibilityLabel = @"Add shortcut";
    self.navigationItem.rightBarButtonItems = @[ add, self.editButtonItem ];
    [self modelDidChange];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self modelDidChange];
}

- (void)modelDidChange {
    HCGWorkspace *workspace = [self workspace];
    if (!workspace) {
        [self.navigationController popViewControllerAnimated:NO];
        return;
    }
    self.title = workspace.name;
    [self.tableView reloadData];
}

- (void)addShortcut {
    HCGShortcutEditorViewController *editor = [[HCGShortcutEditorViewController alloc] initWithContext:self.context workspaceIdentifier:_identifier];
    [self.navigationController pushViewController:editor animated:!UIAccessibilityIsReduceMotionEnabled()];
}

- (void)removeActionAtIndex:(NSUInteger)index {
    HCGWorkspace *workspace = [self workspace];
    if (index >= workspace.actions.count) return;
    NSError *error = nil;
    if (![self.store removeAction:workspace.actions[index].identifier fromWorkspace:_identifier error:&error]) {
        HCGPresentError(self, error, nil);
    } else {
        [self.context.model workspacesDidChange];
    }
    [self.tableView reloadData];
}

#pragma mark Table

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return section == HCGDetailSectionShortcuts ? @"Shortcuts" : @"Workspace";
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == HCGDetailSectionShortcuts) {
        return @"Shortcuts open apps by bundle identifier, links by URL, or HCG integrations. Use Edit to reorder or delete.";
    }
    return nil;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == HCGDetailSectionShortcuts) return MAX(1, (NSInteger)[self workspace].actions.count);
    return 2; // rename, make active
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [self styledCellWithStyle:UITableViewCellStyleSubtitle identifier:kCell];
    HCGWorkspace *workspace = [self workspace];
    if (indexPath.section == HCGDetailSectionShortcuts) {
        if (workspace.actions.count == 0) {
            cell.textLabel.text = @"Add a shortcut";
            cell.detailTextLabel.text = @"An app, a link, or an HCG integration.";
            cell.imageView.image = [HCGTheme symbolNamed:@"plus.circle" pointSize:18];
            return cell;
        }
        HCGAction *action = workspace.actions[(NSUInteger)indexPath.row];
        cell.textLabel.text = action.title;
        NSString *kind = action.kind == HCGActionKindApp ? @"App" : (action.kind == HCGActionKindURL ? @"Link" : @"HCG");
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ · %@", kind, action.target];
        cell.imageView.image = [HCGTheme symbolNamed:action.symbolName pointSize:18];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        __weak typeof(self) weakSelf = self;
        NSUInteger index = (NSUInteger)indexPath.row;
        cell.accessibilityCustomActions = @[ [[UIAccessibilityCustomAction alloc] initWithName:@"Delete" actionHandler:^BOOL(UIAccessibilityCustomAction *a) {
            [weakSelf removeActionAtIndex:index];
            return YES;
        }] ];
        return cell;
    }
    BOOL active = [workspace.identifier isEqualToString:self.store.activeWorkspace.identifier];
    if (indexPath.row == 0) {
        cell.textLabel.text = @"Rename";
        cell.imageView.image = [HCGTheme symbolNamed:@"pencil" pointSize:17];
    } else {
        cell.textLabel.text = active ? @"Active workspace" : @"Make active";
        cell.imageView.image = [HCGTheme symbolNamed:active ? @"checkmark.circle.fill" : @"circle" pointSize:17];
        cell.selectionStyle = active ? UITableViewCellSelectionStyleNone : UITableViewCellSelectionStyleDefault;
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    HCGWorkspace *workspace = [self workspace];
    if (indexPath.section == HCGDetailSectionShortcuts) {
        if (workspace.actions.count == 0) [self addShortcut];
        return;
    }
    if (indexPath.row == 0) {
        __weak typeof(self) weakSelf = self;
        NSString *identifier = _identifier;
        [self promptForTextWithTitle:@"Rename workspace" message:nil placeholder:@"Name" initialValue:workspace.name actionTitle:@"Rename"
                             handler:^BOOL(NSString *text, NSError **error) {
            if (![weakSelf.context.model.workspaceStore renameWorkspace:identifier to:text error:error]) return NO;
            [weakSelf.context.model workspacesDidChange];
            [weakSelf modelDidChange];
            return YES;
        }];
    } else {
        NSError *error = nil;
        if (![self.store setActiveWorkspace:_identifier error:&error]) HCGPresentError(self, error, nil);
        [self.context.model workspacesDidChange];
        [tableView reloadData];
    }
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return indexPath.section == HCGDetailSectionShortcuts && [self workspace].actions.count > 0;
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    return indexPath.section == HCGDetailSectionShortcuts && [self workspace].actions.count > 1;
}

- (NSIndexPath *)tableView:(UITableView *)tableView targetIndexPathForMoveFromRowAtIndexPath:(NSIndexPath *)source toProposedIndexPath:(NSIndexPath *)proposed {
    if (proposed.section != HCGDetailSectionShortcuts) {
        NSInteger last = MAX(0, (NSInteger)[self workspace].actions.count - 1);
        return [NSIndexPath indexPathForRow:last inSection:HCGDetailSectionShortcuts];
    }
    return proposed;
}

- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)from toIndexPath:(NSIndexPath *)to {
    NSError *error = nil;
    if (![self.store moveActionInWorkspace:_identifier fromIndex:(NSUInteger)from.row toIndex:(NSUInteger)to.row error:&error]) {
        HCGPresentError(self, error, nil);
        [tableView reloadData];
        return;
    }
    [self.context.model workspacesDidChange];
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)style forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (style == UITableViewCellEditingStyleDelete) [self removeActionAtIndex:(NSUInteger)indexPath.row];
}

- (void)setEditing:(BOOL)editing animated:(BOOL)animated {
    [super setEditing:editing animated:animated];
    if (!editing) [self.tableView reloadData];
}

@end
