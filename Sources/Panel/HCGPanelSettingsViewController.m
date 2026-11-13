#import "HCGPanelSettingsViewController.h"
#import "HCGWorkspaceManagerViewController.h"
#import "HCGTheme.h"

// Build route label. Theos builds pass -DHCG_PACKAGE_SCHEME="rootless" etc.;
// the Xcode project defines HCG_STANDALONE_APP=1.
#ifndef HCG_PACKAGE_SCHEME
#if defined(HCG_STANDALONE_APP) && HCG_STANDALONE_APP
#define HCG_PACKAGE_SCHEME "standalone-app"
#else
#define HCG_PACKAGE_SCHEME "unspecified"
#endif
#endif

NSString *HCGBuildDescription(void) {
    return [NSString stringWithFormat:@"%@ · package scheme: %s · built %s", HCG_NEXUS_VERSION, HCG_PACKAGE_SCHEME, __DATE__];
}

typedef NS_ENUM(NSInteger, HCGSettingsSection) {
    HCGSettingsSectionGeneral,
    HCGSettingsSectionHandle,
    HCGSettingsSectionMotion,
    HCGSettingsSectionIntegrations,
    HCGSettingsSectionWorkspaces,
    HCGSettingsSectionMaintenance,
    HCGSettingsSectionDiagnostics,
    HCGSettingsSectionAppMode,      // standalone app only: what this build can do
};

// Sections shown for a mode. The standalone app never shows the enable switch,
// handle or motion controls: there is no system-wide overlay to control.
NSArray<NSNumber *> *HCGSettingsSectionsForMode(HCGPanelMode mode) {
    if (mode == HCGPanelModeStandaloneApp) {
        return @[ @(HCGSettingsSectionAppMode), @(HCGSettingsSectionIntegrations), @(HCGSettingsSectionWorkspaces), @(HCGSettingsSectionDiagnostics) ];
    }
    return @[ @(HCGSettingsSectionGeneral), @(HCGSettingsSectionHandle), @(HCGSettingsSectionMotion), @(HCGSettingsSectionIntegrations),
              @(HCGSettingsSectionWorkspaces), @(HCGSettingsSectionMaintenance), @(HCGSettingsSectionDiagnostics) ];
}

@implementation HCGPanelSettingsViewController {
    NSArray<NSArray<NSString *> *> *_diagnostics;
    NSArray<NSNumber *> *_sections;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Settings";
    _sections = HCGSettingsSectionsForMode(self.context.mode);
    [self refreshDiagnostics];
}

- (NSArray<NSNumber *> *)visibleSectionIdentifiers {
    return _sections ?: HCGSettingsSectionsForMode(self.context.mode);
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self modelDidChange];
}

- (void)modelDidChange {
    [self refreshDiagnostics];
    [self.tableView reloadData];
}

- (HCGSettings *)settings {
    return self.context.model.settings;
}

- (void)save:(void (^)(HCGSettings *s))change {
    HCGSettings *settings = [self settings];
    change(settings);
    [self.context.model saveSettings:settings];
}

- (void)refreshDiagnostics {
    NSMutableArray *rows = [NSMutableArray array];
    [rows addObject:@[ @"Version", HCGBuildDescription() ]];
    [rows addObject:@[ @"Mode", HCGPanelModeName(self.context.mode) ]];
    [rows addObject:@[ @"Running in", self.context.environmentName ?: @"unknown" ]];
    [rows addObject:@[ @"iOS", [UIDevice currentDevice].systemVersion ?: @"?" ]];
    NSDictionary *diag = self.context.diagnosticsProvider ? self.context.diagnosticsProvider() : @{};
    NSArray *keys = @[ @"availability", @"deviceLocked", @"coverSheetVisible", @"screenBlanked", @"panelState", @"overlayWindows",
                       @"gestureRecognizers", @"installCount", @"opens", @"closes", @"forcedCloses", @"orientation", @"manualRotation",
                       @"animationsAllowed", @"launcher", @"launcherCapabilities", @"droppedEntriesOnLoad", @"dataStore" ];
    for (NSString *key in keys) {
        id value = diag[key];
        if (value) [rows addObject:@[ key, [value description] ]];
    }
    _diagnostics = rows;
}

#pragma mark Controls

- (UISwitch *)switchOn:(BOOL)on action:(SEL)action label:(NSString *)label {
    UISwitch *control = [[UISwitch alloc] init];
    control.on = on;
    control.onTintColor = [HCGTheme cyan];
    control.accessibilityLabel = label;
    [control addTarget:self action:action forControlEvents:UIControlEventValueChanged];
    return control;
}

- (void)enabledChanged:(UISwitch *)control {
    if (control.on) {
        [self save:^(HCGSettings *s) { s.enabled = YES; }];
        return;
    }
    if (!self.context.insideOverlay) {
        [self save:^(HCGSettings *s) { s.enabled = NO; }];
        return;
    }
    [self confirmDisableRevertingSwitch:control];
}

- (void)confirmDisableRevertingSwitch:(UISwitch *)control {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Disable HCG Nexus?"
                                                                   message:@"The panel closes and the edge handle disappears immediately. Workspaces are kept and other HCG services are not affected. Turn it back on in Settings › HCG Nexus."
                                                            preferredStyle:UIAlertControllerStyleAlert];
    alert.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:^(UIAlertAction *a) {
        [control setOn:YES animated:YES];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Disable" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a) {
        [weakSelf save:^(HCGSettings *s) { s.enabled = NO; }];
    }]];
    [self presentViewController:alert animated:!UIAccessibilityIsReduceMotionEnabled() completion:nil];
}

- (void)sideChanged:(UISegmentedControl *)control {
    [self save:^(HCGSettings *s) { s.handleSide = control.selectedSegmentIndex == 1 ? HCGHandleSideLeft : HCGHandleSideRight; }];
}

- (void)positionChanged:(UISlider *)slider {
    [self save:^(HCGSettings *s) { s.handlePosition = slider.value; }];
}

- (void)opacityChanged:(UISlider *)slider {
    [self save:^(HCGSettings *s) { s.handleOpacity = slider.value; }];
}

- (void)keyboardZoneChanged:(UISwitch *)control {
    [self save:^(HCGSettings *s) { s.keyboardSafeZone = control.on; }];
}

- (void)animationsChanged:(UISwitch *)control {
    [self save:^(HCGSettings *s) { s.animationsEnabled = control.on; }];
}

- (void)hapticsChanged:(UISwitch *)control {
    [self save:^(HCGSettings *s) { s.hapticsEnabled = control.on; }];
}

- (void)terminalChanged:(UISegmentedControl *)control {
    [self save:^(HCGSettings *s) { s.terminalVariant = (HCGTerminalVariant)control.selectedSegmentIndex; }];
}

- (void)newsChanged:(UISwitch *)control {
    [self save:^(HCGSettings *s) { s.newsConnected = control.on; }];
}

- (UISlider *)sliderWithValue:(float)value min:(float)min action:(SEL)action label:(NSString *)label {
    UISlider *slider = [[UISlider alloc] init];
    slider.minimumValue = min;
    slider.maximumValue = 1;
    slider.value = value;
    slider.continuous = NO;
    slider.minimumTrackTintColor = [HCGTheme cyan];
    slider.accessibilityLabel = label;
    [slider addTarget:self action:action forControlEvents:UIControlEventValueChanged];
    return slider;
}

- (UISegmentedControl *)segmentsWithItems:(NSArray *)items selected:(NSInteger)selected action:(SEL)action label:(NSString *)label {
    UISegmentedControl *control = [[UISegmentedControl alloc] initWithItems:items];
    control.selectedSegmentIndex = selected;
    control.selectedSegmentTintColor = [HCGTheme cyanSoft];
    [control setTitleTextAttributes:@{ NSForegroundColorAttributeName : [HCGTheme primaryText] } forState:UIControlStateNormal];
    control.accessibilityLabel = label;
    [control addTarget:self action:action forControlEvents:UIControlEventValueChanged];
    return control;
}

#pragma mark Table

- (HCGSettingsSection)sectionAt:(NSInteger)index {
    return (HCGSettingsSection)[self visibleSectionIdentifiers][(NSUInteger)index].integerValue;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return (NSInteger)[self visibleSectionIdentifiers].count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    switch ([self sectionAt:section]) {
        case HCGSettingsSectionGeneral: return @"HCG Nexus";
        case HCGSettingsSectionHandle: return @"Edge handle";
        case HCGSettingsSectionMotion: return @"Motion & feedback";
        case HCGSettingsSectionIntegrations: return @"HCG integrations";
        case HCGSettingsSectionWorkspaces: return @"Workspaces";
        case HCGSettingsSectionMaintenance: return @"Maintenance";
        case HCGSettingsSectionDiagnostics: return @"Diagnostics";
        case HCGSettingsSectionAppMode: return @"App mode";
    }
    return nil;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    switch ([self sectionAt:section]) {
        case HCGSettingsSectionGeneral:
            return @"When off, the panel closes, the handle disappears and Nexus stops intercepting its gesture. Workspaces are kept; nothing is uninstalled.";
        case HCGSettingsSectionHandle:
            return @"The handle stays clear of the status bar, Notification and Control Centre pull zones and the home indicator. \"Keep above keyboard\" holds it in the upper part of the screen.";
        case HCGSettingsSectionMotion:
            return @"Reduce Motion in iOS Accessibility settings always replaces sliding with a short fade.";
        case HCGSettingsSectionIntegrations:
            if (self.context.isStandaloneApp) {
                return @"In the standalone app, HCG integrations show their status only: opening another app by bundle identifier needs the jailbreak package. HCG Connect and ERP remain the authority for signed-in ecosystem access; Nexus stores no HCG credentials.";
            }
            return @"HCG Connect and ERP remain the authority for signed-in ecosystem access. Nexus stores no HCG credentials and only opens installed apps.";
        case HCGSettingsSectionAppMode:
            return @"This is the sandboxed iPhone/iPad app. It keeps its own workspaces, separate from the jailbreak package and the preview harness. Ordinary app signing does not remove the iOS sandbox, so the system-wide edge handle and bundle-ID app launching are only available through the jailbreak package.";
        case HCGSettingsSectionDiagnostics:
            if (self.context.isPreview) return @"PREVIEW: these values come from the preview harness, not from SpringBoard. They do not verify the tweak on a device.";
            return nil;
        default:
            return nil;
    }
}

- (NSArray<NSArray<NSString *> *> *)appModeRows {
    id<HCGLauncher> launcher = self.context.model.launcher;
    BOOL bundle = launcher && [launcher canLaunchApplicationsByBundleIdentifier];
    return @[
        @[ @"Mode", @"Standalone app" ],
        @[ @"System-wide edge handle", @"Not available in this app (jailbreak package only)" ],
        @[ @"Open links (https, mailto, documented app links)", launcher ? @"Available" : @"Unavailable" ],
        @[ @"Open apps by bundle identifier", bundle ? @"Available" : @"Not available in the iOS sandbox" ],
    ];
}

- (NSArray<NSString *> *)standaloneIntegrationIdentifiers {
    return [HCGIntegrationCatalog allIdentifiers];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch ([self sectionAt:section]) {
        case HCGSettingsSectionGeneral: return 1;
        case HCGSettingsSectionHandle: return 4;
        case HCGSettingsSectionMotion: return 2;
        case HCGSettingsSectionIntegrations: return self.context.isStandaloneApp ? (NSInteger)[self standaloneIntegrationIdentifiers].count : 4;
        case HCGSettingsSectionWorkspaces: return 2;
        case HCGSettingsSectionMaintenance: return 1;
        case HCGSettingsSectionDiagnostics: return (NSInteger)_diagnostics.count;
        case HCGSettingsSectionAppMode: return (NSInteger)[self appModeRows].count;
    }
    return 0;
}

- (UITableViewCell *)controlCell:(NSString *)title control:(UIView *)control stacked:(BOOL)stacked {
    UITableViewCell *cell = [self styledCellWithStyle:UITableViewCellStyleDefault identifier:stacked ? @"stacked" : @"control"];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    for (UIView *sub in cell.contentView.subviews) {
        if (sub.tag == 77) [sub removeFromSuperview];
    }
    if (!stacked) {
        cell.textLabel.text = title;
        cell.accessoryView = control;
        return cell;
    }
    cell.textLabel.text = nil;
    UILabel *label = [[UILabel alloc] init];
    label.text = title;
    label.textColor = [HCGTheme primaryText];
    label.font = [HCGTheme fontForTextStyle:UIFontTextStyleBody weight:UIFontWeightMedium];
    label.adjustsFontForContentSizeCategory = YES;
    label.isAccessibilityElement = NO;
    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[ label, control ]];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 8;
    stack.tag = 77;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [cell.contentView addSubview:stack];
    UILayoutGuide *margins = cell.contentView.layoutMarginsGuide;
    [NSLayoutConstraint activateConstraints:@[
        [stack.leadingAnchor constraintEqualToAnchor:margins.leadingAnchor],
        [stack.trailingAnchor constraintEqualToAnchor:margins.trailingAnchor],
        [stack.topAnchor constraintEqualToAnchor:margins.topAnchor],
        [stack.bottomAnchor constraintEqualToAnchor:margins.bottomAnchor],
    ]];
    return cell;
}

- (UITableViewCell *)statusCellForIntegration:(NSString *)identifier {
    HCGIntegrationStatus *status = [self.context.model statusForIntegration:identifier];
    UITableViewCell *cell = [self styledCellWithStyle:UITableViewCellStyleSubtitle identifier:@"status"];
    cell.textLabel.text = status.displayName;
    cell.detailTextLabel.text = status.headline;
    cell.imageView.image = [HCGTheme symbolNamed:status.symbolName pointSize:17];
    cell.imageView.tintColor = [HCGTheme secondaryText];
    cell.accessoryType = UITableViewCellAccessoryDetailButton;
    return cell;
}

- (NSString *)integrationIdentifierForRow:(NSInteger)row {
    if (self.context.isStandaloneApp) {
        NSArray *ids = [self standaloneIntegrationIdentifiers];
        return row >= 0 && (NSUInteger)row < ids.count ? ids[(NSUInteger)row] : nil;
    }
    if (row == 2) return HCGIntegrationServer;
    if (row == 3) return HCGIntegrationExecutableMaker;
    return nil; // rows 0-1 are controls
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    HCGSettings *s = [self settings];
    switch ([self sectionAt:indexPath.section]) {
        case HCGSettingsSectionGeneral:
            return [self controlCell:@"Enable HCG Nexus" control:[self switchOn:s.enabled action:@selector(enabledChanged:) label:@"Enable HCG Nexus"] stacked:NO];
        case HCGSettingsSectionHandle:
            switch (indexPath.row) {
                case 0: return [self controlCell:@"Side" control:[self segmentsWithItems:@[ @"Right", @"Left" ] selected:s.handleSide == HCGHandleSideLeft ? 1 : 0 action:@selector(sideChanged:) label:@"Handle side"] stacked:YES];
                case 1: return [self controlCell:@"Vertical position" control:[self sliderWithValue:(float)s.handlePosition min:0 action:@selector(positionChanged:) label:@"Handle vertical position"] stacked:YES];
                case 2: return [self controlCell:@"Visibility" control:[self sliderWithValue:(float)s.handleOpacity min:(float)[HCGSettings minimumHandleOpacity] action:@selector(opacityChanged:) label:@"Handle visibility"] stacked:YES];
                default: return [self controlCell:@"Keep above keyboard" control:[self switchOn:s.keyboardSafeZone action:@selector(keyboardZoneChanged:) label:@"Keep handle above keyboard area"] stacked:NO];
            }
        case HCGSettingsSectionMotion:
            if (indexPath.row == 0) return [self controlCell:@"Animations" control:[self switchOn:s.animationsEnabled action:@selector(animationsChanged:) label:@"Animations"] stacked:NO];
            return [self controlCell:@"Haptics" control:[self switchOn:s.hapticsEnabled action:@selector(hapticsChanged:) label:@"Haptics"] stacked:NO];
        case HCGSettingsSectionIntegrations: {
            if (!self.context.isStandaloneApp && indexPath.row == 0) {
                return [self controlCell:@"HCG Terminal" control:[self segmentsWithItems:@[ @"Off", @"Standard", @"Unleashed" ] selected:s.terminalVariant action:@selector(terminalChanged:) label:@"HCG Terminal app variant"] stacked:YES];
            }
            if (!self.context.isStandaloneApp && indexPath.row == 1) {
                return [self controlCell:@"HCG News" control:[self switchOn:s.newsConnected action:@selector(newsChanged:) label:@"Open HCG News from the panel"] stacked:NO];
            }
            return [self statusCellForIntegration:[self integrationIdentifierForRow:indexPath.row]];
        }
        case HCGSettingsSectionWorkspaces: {
            UITableViewCell *cell = [self styledCellWithStyle:UITableViewCellStyleValue1 identifier:@"value"];
            if (indexPath.row == 0) {
                cell.textLabel.text = @"Manage workspaces";
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%lu", (unsigned long)self.context.model.workspaceStore.workspaces.count];
                cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            } else {
                cell.textLabel.text = @"Clear recent actions";
                cell.textLabel.textColor = [HCGTheme cyan];
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%lu", (unsigned long)self.context.model.recents.entries.count];
            }
            return cell;
        }
        case HCGSettingsSectionMaintenance: {
            UITableViewCell *cell = [self styledCellWithStyle:UITableViewCellStyleDefault identifier:@"button"];
            cell.textLabel.text = @"Reset settings";
            cell.textLabel.textColor = [HCGTheme warning];
            cell.accessibilityHint = @"Restores handle, motion and haptic defaults. Keeps workspaces and the enabled state.";
            return cell;
        }
        case HCGSettingsSectionAppMode: {
            NSArray<NSString *> *row = [self appModeRows][(NSUInteger)indexPath.row];
            UITableViewCell *cell = [self styledCellWithStyle:UITableViewCellStyleSubtitle identifier:@"appmode"];
            cell.textLabel.text = row[0];
            cell.detailTextLabel.text = row[1];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            return cell;
        }
        case HCGSettingsSectionDiagnostics: {
            UITableViewCell *cell = [self styledCellWithStyle:UITableViewCellStyleSubtitle identifier:@"diag"];
            NSArray<NSString *> *row = _diagnostics[(NSUInteger)indexPath.row];
            cell.textLabel.text = row[0];
            cell.textLabel.font = [UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightSemibold];
            cell.detailTextLabel.text = row[1];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            return cell;
        }
    }
    return [self styledCellWithStyle:UITableViewCellStyleDefault identifier:@"empty"];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    switch ([self sectionAt:indexPath.section]) {
        case HCGSettingsSectionWorkspaces:
            if (indexPath.row == 0) {
                [self.navigationController pushViewController:[[HCGWorkspaceManagerViewController alloc] initWithContext:self.context]
                                                     animated:!UIAccessibilityIsReduceMotionEnabled()];
            } else {
                [self.context.model clearRecents];
            }
            break;
        case HCGSettingsSectionMaintenance:
            [self confirmReset];
            break;
        case HCGSettingsSectionIntegrations:
            if ([self integrationIdentifierForRow:indexPath.row]) [self tableView:tableView accessoryButtonTappedForRowWithIndexPath:indexPath];
            break;
        default:
            break;
    }
}

- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath {
    if ([self sectionAt:indexPath.section] != HCGSettingsSectionIntegrations) return;
    NSString *identifier = [self integrationIdentifierForRow:indexPath.row];
    if (!identifier) return;
    HCGIntegrationStatus *status = [self.context.model statusForIntegration:identifier];
    HCGPresentError(self, HCGMakeError(HCGErrorIntegrationNotConnected, [NSString stringWithFormat:@"%@: %@", status.displayName, status.headline], status.detail), nil);
}

- (void)confirmReset {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Reset settings?"
                                                                   message:@"Handle position, visibility, motion and haptic preferences return to their defaults. Workspaces, recent actions, integration choices and the enabled state are kept."
                                                            preferredStyle:UIAlertControllerStyleAlert];
    alert.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Reset" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a) {
        [weakSelf.context.model resetSettings];
    }]];
    [self presentViewController:alert animated:!UIAccessibilityIsReduceMotionEnabled() completion:nil];
}

@end
