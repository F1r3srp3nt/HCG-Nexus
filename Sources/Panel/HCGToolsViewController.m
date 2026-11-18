#import "HCGToolsViewController.h"
#import "HCGTheme.h"
#import "HCGPanelServices.h"
#import "HCGPanelSettingsViewController.h"

@implementation HCGToolsViewController {
    NSArray<HCGToolInfo *> *_pinned;
    NSArray<HCGToolInfo *> *_others;
    BOOL _openingPage;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Tools";
    [self modelDidChange];
}

- (void)modelDidChange {
    HCGWorkspace *active = self.context.model.workspaceStore.activeWorkspace;
    NSArray<NSString *> *pinnedIds = [HCGToolCatalog validToolIdentifiers:active.toolIdentifiers];
    NSMutableArray *pinned = [NSMutableArray array], *others = [NSMutableArray array];
    for (NSString *identifier in pinnedIds) [pinned addObject:[HCGToolCatalog toolWithIdentifier:identifier]];
    for (HCGToolInfo *tool in [HCGToolCatalog allTools]) {
        if (![pinnedIds containsObject:tool.identifier]) [others addObject:tool];
    }
    _pinned = pinned;
    _others = others;
    [self.tableView reloadData];
}

- (NSArray<HCGToolInfo *> *)toolsInSection:(NSInteger)section {
    return (_pinned.count > 0 && section == 0) ? _pinned : _others;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return _pinned.count > 0 ? 2 : 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (_pinned.count > 0 && section == 0) {
        return [NSString stringWithFormat:@"Pinned for %@", self.context.model.workspaceStore.activeWorkspace.name ?: @"this workspace"];
    }
    return _pinned.count > 0 ? @"More tools" : @"Tools";
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == [self numberOfSectionsInTableView:tableView] - 1) {
        return @"Every tool works locally on this device. Pin tools per workspace under Workspaces.";
    }
    return nil;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return (NSInteger)[self toolsInSection:section].count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    HCGToolInfo *tool = [self toolsInSection:indexPath.section][(NSUInteger)indexPath.row];
    NSString *reason = [HCGToolCatalog unavailableReasonForTool:tool.identifier environment:self.context.toolEnvironment];
    UITableViewCell *cell = [self styledCellWithStyle:UITableViewCellStyleSubtitle identifier:@"tool"];
    cell.textLabel.text = tool.title;
    cell.detailTextLabel.text = reason ? [@"Unavailable here: " stringByAppendingString:reason] : tool.summary;
    cell.imageView.image = [HCGTheme symbolNamed:tool.symbolName pointSize:18];
    if (reason) {
        cell.textLabel.textColor = [HCGTheme secondaryText];
        cell.imageView.tintColor = [HCGTheme secondaryText];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.accessibilityTraits = UIAccessibilityTraitNotEnabled;
    } else {
        cell.imageView.tintColor = tool.destructive ? [HCGTheme warning] : [HCGTheme cyan];
        cell.accessibilityTraits = UIAccessibilityTraitButton;
        if ([tool.identifier isEqualToString:HCGToolAppearance]) cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    HCGToolInfo *tool = [self toolsInSection:indexPath.section][(NSUInteger)indexPath.row];
    NSString *reason = [HCGToolCatalog unavailableReasonForTool:tool.identifier environment:self.context.toolEnvironment];
    if (reason) {
        [self.context feedback:reason success:NO];
        return;
    }
    if (!tool.destructive) {
        [self runTool:tool];
        return;
    }
    UIAlertController *confirm = [UIAlertController alertControllerWithTitle:[tool.title stringByAppendingString:@"?"] message:tool.summary
                                                              preferredStyle:UIAlertControllerStyleAlert];
    confirm.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    __weak typeof(self) weakSelf = self;
    [confirm addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [confirm addAction:[UIAlertAction actionWithTitle:tool.title style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a) {
        [weakSelf runTool:tool];
    }]];
    [self presentViewController:confirm animated:YES completion:nil];
}

- (void)runTool:(HCGToolInfo *)tool {
    HCGNexusModel *model = self.context.model;
    NSString *identifier = tool.identifier;
    if ([identifier isEqualToString:HCGToolAppearance]) {
        [self.navigationController pushViewController:[[HCGPanelSettingsViewController alloc] initWithContext:self.context]
                                             animated:!UIAccessibilityIsReduceMotionEnabled()];
    } else if ([identifier isEqualToString:HCGToolCopyDiagnostics]) {
        NSString *report = HCGPanelDiagnosticsReport(self.context);
        [UIPasteboard generalPasteboard].string = report;
        BOOL copied = [[UIPasteboard generalPasteboard].string isEqualToString:report];
        [self.context feedback:copied ? @"Diagnostics copied (redacted). Paste it where you need it." : @"The clipboard did not accept the report." success:copied];
    } else if ([identifier isEqualToString:HCGToolClearRecents]) {
        [model clearRecents];
        [self.context feedback:model.recents.entries.count == 0 ? @"Recent actions cleared." : @"Recent actions could not be cleared." success:model.recents.entries.count == 0];
    } else if ([identifier isEqualToString:HCGToolResetAppearance]) {
        [model resetSettings];
        [self.context feedback:@"Appearance reset to defaults." success:YES];
    } else if ([identifier isEqualToString:HCGToolDisableNexus]) {
        HCGSettings *settings = model.settings;
        settings.enabled = NO;
        [model saveSettings:settings];
        [self.context feedback:@"HCG Nexus is off. Turn it on again in Settings › HCG Nexus." success:!model.settings.enabled];
    } else if ([identifier isEqualToString:HCGToolRepoPage]) {
        [self openRepoPage];
    } else if ([identifier isEqualToString:HCGToolImportShortcuts]) {
        NSUInteger added = [model importShortcutsFromWorkspaces];
        [self.context feedback:added ? [NSString stringWithFormat:@"Added %lu shortcuts to Apps.", (unsigned long)added]
                                     : @"Apps already has every app and link shortcut from your workspaces." success:YES];
    } else if ([identifier isEqualToString:HCGToolRestoreLayout]) {
        NSError *error = nil;
        if ([model restorePreviousLayout:&error]) {
            [self.context feedback:@"Previous layout restored. Apps is empty; Import Workspace Shortcuts brings them back." success:YES];
        } else {
            [self.context feedback:error.localizedDescription ?: @"Restore failed." success:NO];
        }
    }
    [self modelDidChange];
}

- (void)openRepoPage {
    if (_openingPage) return;
    id<HCGLauncher> launcher = self.context.model.launcher;
    NSURL *url = [NSURL URLWithString:HCGNexusRepoProductPageURLString];
    if (!launcher || ![url.scheme.lowercaseString isEqualToString:@"https"]) {
        [self.context feedback:@"Links can't be opened from here." success:NO];
        return;
    }
    _openingPage = YES;
    __weak typeof(self) weakSelf = self;
    [launcher openURL:url completion:^(NSError *error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        strongSelf->_openingPage = NO;
        if (error) {
            [strongSelf.context feedback:error.localizedDescription ?: @"The page could not be opened." success:NO];
        } else if (strongSelf.context.insideOverlay && !strongSelf.context.isPreview && strongSelf.context.closePanelImmediately) {
            strongSelf.context.closePanelImmediately();
        } else {
            [strongSelf.context feedback:@"Opened the HCG Repo page." success:YES];
        }
    }];
}

@end
