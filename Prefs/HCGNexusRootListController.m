#import "HCGNexusRootListController.h"
#import <Preferences/PSSpecifier.h>
#import "HCGCore.h"
#import "HCGNexusModel.h"
#import "HCGPanelContext.h"
#import "HCGPreferencesKeyValueStore.h"
#import "HCGWorkspaceManagerViewController.h"
#import "HCGPanelSettingsViewController.h"

static NSString *const kDiagnosticsGroupID = @"diagnostics";

@implementation HCGNexusRootListController {
    HCGPreferencesKeyValueStore *_store;
    HCGNexusModel *_model;
}

- (HCGPreferencesKeyValueStore *)store {
    if (!_store) _store = [[HCGPreferencesKeyValueStore alloc] initWithDomain:HCGNexusPreferencesDomain];
    return _store;
}

- (HCGNexusModel *)model {
    // No launcher: Settings.app never launches shortcuts.
    if (!_model) _model = [[HCGNexusModel alloc] initWithStore:[self store] notifier:[[HCGDarwinNotifier alloc] init] launcher:nil];
    return _model;
}

- (NSArray *)specifiers {
    if (!_specifiers) {
        NSMutableArray *specs = [self loadSpecifiersFromPlistName:@"Root" target:self];
        [specs addObjectsFromArray:[self diagnosticsSpecifiers]];
        _specifiers = specs;
    }
    return _specifiers;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [[self store] reload];
    [self reloadSpecifiers];
}

#pragma mark Preference I/O (CFPreferences, same domain SpringBoard reads)

- (id)readPreferenceValue:(PSSpecifier *)specifier {
    NSString *key = [specifier propertyForKey:@"key"];
    if (!key) return [super readPreferenceValue:specifier];
    [[self store] reload];
    HCGSettings *settings = [HCGSettings settingsFromStore:[self store]];
    id value = [settings dictionaryRepresentation][key];
    return value ?: [specifier propertyForKey:@"default"];
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    NSString *key = [specifier propertyForKey:@"key"];
    if (!key) {
        [super setPreferenceValue:value specifier:specifier];
        return;
    }
    // Write the raw value, then normalise through HCGSettings (clamping/typing)
    // and broadcast so SpringBoard applies it immediately.
    [[self store] reload];
    [[self store] setObject:value forKey:key];
    HCGSettings *settings = [HCGSettings settingsFromStore:[self store]];
    [[self model] saveSettings:settings];
}

#pragma mark Buttons

- (void)openWorkspaces {
    HCGPanelContext *context = [[HCGPanelContext alloc] init];
    context.model = [self model];
    [context.model reload];
    context.environmentName = @"Settings";
    context.mode = HCGPanelModeSettingsApp;
    HCGWorkspaceManagerViewController *manager = [[HCGWorkspaceManagerViewController alloc] initWithContext:context];
    [self.navigationController pushViewController:manager animated:YES];
}

- (void)clearRecents {
    [[self model] reload];
    [[self model] clearRecents];
    [self reloadSpecifiers];
}

- (void)resetSettings {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Reset settings?"
                                                                   message:@"Handle position, visibility, motion and haptic preferences return to their defaults. Workspaces, recent actions, integration choices and the Enable switch are kept."
                                                            preferredStyle:UIAlertControllerStyleAlert];
    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Reset" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a) {
        [[weakSelf model] reload];
        [[weakSelf model] resetSettings];
        [weakSelf reloadSpecifiers];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark Diagnostics

- (PSSpecifier *)valueRow:(NSString *)title value:(NSString *)value {
    PSSpecifier *spec = [PSSpecifier preferenceSpecifierNamed:title target:self set:nil get:@selector(staticValue:) detail:nil cell:PSTitleValueCell edit:nil];
    [spec setProperty:value ?: @"—" forKey:@"hcgValue"];
    return spec;
}

- (id)staticValue:(PSSpecifier *)specifier {
    return [specifier propertyForKey:@"hcgValue"];
}

- (NSArray *)diagnosticsSpecifiers {
    NSMutableArray *specs = [NSMutableArray array];
    PSSpecifier *group = [PSSpecifier groupSpecifierWithName:@"Diagnostics"];
    group.identifier = kDiagnosticsGroupID;
    [specs addObject:group];
    [specs addObject:[self valueRow:@"Settings bundle" value:HCGBuildDescription()]];
    [specs addObject:[self valueRow:@"iOS" value:[UIDevice currentDevice].systemVersion]];

    [[self store] reload];
    NSDictionary *status = [[self store] objectForKey:@"runtimeStatus"];
    if (![status isKindOfClass:[NSDictionary class]]) {
        [group setProperty:@"SpringBoard has not reported yet. After installing, a respring is required before the tweak loads. Nothing here means the tweak is verified." forKey:@"footerText"];
        [specs addObject:[self valueRow:@"SpringBoard" value:@"No report"]];
        return specs;
    }
    NSDate *updated = [NSDate dateWithTimeIntervalSince1970:[status[@"updated"] doubleValue]];
    NSString *when = [NSDateFormatter localizedStringFromDate:updated dateStyle:NSDateFormatterShortStyle timeStyle:NSDateFormatterShortStyle];
    [specs addObject:[self valueRow:@"SpringBoard build" value:[status[@"version"] description]]];
    [specs addObject:[self valueRow:@"Activated" value:[status[@"activated"] boolValue] ? @"Yes" : @"No (disabled)"]];
    for (NSString *key in @[ @"startedBy", @"availability", @"overlayWindows", @"overlayWindowScene", @"gestureRecognizers", @"installCount", @"launcherCapabilities", @"lockSources", @"orientationSource" ]) {
        if (status[key]) [specs addObject:[self valueRow:key value:[status[key] description]]];
    }
    [group setProperty:[NSString stringWithFormat:@"Last reported by SpringBoard: %@.", when] forKey:@"footerText"];
    return specs;
}

@end
