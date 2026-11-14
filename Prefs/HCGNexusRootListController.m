#import "HCGNexusRootListController.h"
#import <Preferences/PSSpecifier.h>
#import "HCGCore.h"
#import "HCGNexusModel.h"
#import "HCGPanelContext.h"
#import "HCGPreferencesKeyValueStore.h"
#import "HCGWorkspaceManagerViewController.h"
#import "HCGPanelSettingsViewController.h"
#import "HCGSystemInfo.h"

static NSString *const kStatusGroupID = @"status";
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
        [[self store] reload];
        // Status sits directly under the Enable switch (first group + switch).
        NSUInteger insertAt = MIN((NSUInteger)2, specs.count);
        NSArray *status = [self statusSpecifiers];
        [specs insertObjects:status atIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(insertAt, status.count)]];
        [specs addObjectsFromArray:[self diagnosticsSpecifiers]];
        _specifiers = specs;
    }
    return _specifiers;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [[self store] reload];
    [self reloadSpecifiers];
    [self requestFreshStatus];
}

// Asks SpringBoard to rewrite its report, then re-reads it. The notification
// carries no payload and can only trigger a status write.
- (void)requestFreshStatus {
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                         (__bridge CFStringRef)HCGNexusStatusRequestDarwinNotification, NULL, NULL, true);
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.6 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        typeof(self) strongSelf = weakSelf;
        if (!strongSelf || !strongSelf.view.window) return;
        [[strongSelf store] reload];
        [strongSelf reloadSpecifiers];
    });
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
    if ([key isEqualToString:@"enabled"]) [self requestFreshStatus];
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

- (void)copyDiagnostics {
    NSString *report = [HCGDiagnostics reportWithLocal:[self localFacts] runtime:[self runtimeStatus]];
    [UIPasteboard generalPasteboard].string = report;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Diagnostics copied"
                                                                   message:@"The report is on the clipboard. E-mail addresses, tokens and device identifiers are removed; review it before sharing."
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark Status + diagnostics

- (nullable NSDictionary *)runtimeStatus {
    NSDictionary *status = [[self store] objectForKey:HCGRuntimeStatusKey];
    return [status isKindOfClass:[NSDictionary class]] ? status : nil;
}

- (NSDictionary *)localFacts {
    HCGNexusModel *model = [self model];
    [model reload];
    NSUInteger failures = 0;
    for (HCGRecentEntry *entry in model.recents.entries) {
        if (!entry.succeeded) failures++;
    }
    NSString *bundlePath = [NSBundle bundleForClass:[self class]].bundlePath ?: @"";
    NSMutableArray *settingsLines = [NSMutableArray array];
    NSDictionary *settings = [model.settings dictionaryRepresentation];
    for (NSString *key in [settings.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
        [settingsLines addObject:[NSString stringWithFormat:@"%@ = %@", key, settings[key]]];
    }
    return @{
        @"version" : HCGBuildVersion(),
        @"buildID" : HCGBuildIdentifier(),
        @"buildConfig" : HCGBuildConfiguration(),
        @"installPrefix" : [HCGSystemInfo installLocationForBundlePath:bundlePath],
        @"installEvidence" : [@"Settings bundle path " stringByAppendingString:bundlePath],
        @"deviceModel" : [HCGSystemInfo deviceModel],
        @"osVersion" : [HCGSystemInfo osVersion],
        @"osBuild" : [HCGSystemInfo osBuild],
        @"generated" : [HCGDiagnostics formatTimestamp:@([[NSDate date] timeIntervalSince1970])],
        @"settingsSummary" : [settingsLines componentsJoinedByString:@"\n"],
        @"workspaceCount" : [@(model.workspaceStore.workspaces.count) description],
        @"recentCount" : [@(model.recents.entries.count) description],
        @"recentFailures" : [@(failures) description],
    };
}

- (PSSpecifier *)valueRow:(NSString *)title value:(NSString *)value {
    PSSpecifier *spec = [PSSpecifier preferenceSpecifierNamed:title target:self set:nil get:@selector(staticValue:) detail:nil cell:PSTitleValueCell edit:nil];
    [spec setProperty:value ?: @"—" forKey:@"hcgValue"];
    return spec;
}

- (id)staticValue:(PSSpecifier *)specifier {
    return [specifier propertyForKey:@"hcgValue"];
}

static NSString *HCGStateTitle(NSString *state) {
    if ([state isEqualToString:HCGFeatureStateOK]) return @"Working";
    if ([state isEqualToString:HCGFeatureStateDisabled]) return @"Off";
    if ([state isEqualToString:HCGFeatureStateUnavailable]) return @"Unavailable";
    if ([state isEqualToString:HCGFeatureStateUnsupported]) return @"Not supported";
    if ([state isEqualToString:HCGFeatureStateFailed]) return @"Failed";
    return @"Unknown";
}

static NSString *HCGComponentTitle(NSString *component) {
    if ([component isEqualToString:HCGComponentRunning]) return @"Running";
    if ([component isEqualToString:HCGComponentRespringRequired]) return @"Respring required";
    if ([component isEqualToString:HCGComponentNotLoaded]) return @"Not loaded";
    if ([component isEqualToString:HCGComponentStopped]) return @"Stopped";
    return @"Unknown";
}

- (NSArray *)statusSpecifiers {
    NSMutableArray *specs = [NSMutableArray array];
    PSSpecifier *group = [PSSpecifier groupSpecifierWithName:@"Status"];
    group.identifier = kStatusGroupID;
    [specs addObject:group];

    [specs addObject:[self valueRow:@"Installed" value:[NSString stringWithFormat:@"%@ (%@)", HCGBuildVersion(), HCGBuildIdentifier()]]];
    NSDictionary *runtime = [self runtimeStatus];
    NSString *detail = nil;
    NSString *component = [HCGDiagnostics springBoardStateForInstalledBuild:HCGBuildIdentifier() runtime:runtime detail:&detail];
    [specs addObject:[self valueRow:@"SpringBoard" value:HCGComponentTitle(component)]];

    NSMutableString *footer = [NSMutableString stringWithString:detail ?: @""];
    if ([component isEqualToString:HCGComponentRunning]) {
        NSDictionary *features = runtime[HCGStatusFeatures];
        NSArray *rows = @[ @[ HCGFeatureEdgeHandle, @"Edge handle" ], @[ HCGFeatureAppLaunching, @"App launching" ],
                           @[ HCGFeatureLockDetection, @"Lock detection" ], @[ HCGFeatureOrientation, @"Rotation" ] ];
        for (NSArray *row in rows) {
            NSDictionary *feature = [features isKindOfClass:[NSDictionary class]] ? features[row[0]] : nil;
            NSString *state = [feature isKindOfClass:[NSDictionary class]] ? [feature[@"state"] description] : HCGFeatureStateUnknown;
            [specs addObject:[self valueRow:row[1] value:HCGStateTitle(state)]];
            if (![state isEqualToString:HCGFeatureStateOK] && ![state isEqualToString:HCGFeatureStateDisabled]) {
                NSString *why = [feature isKindOfClass:[NSDictionary class]] ? [feature[@"detail"] description] : @"no report";
                [footer appendFormat:@"\n%@: %@", row[1], why ?: @"no detail"];
            }
        }
        NSDictionary *error = runtime[HCGStatusLastError];
        if ([error isKindOfClass:[NSDictionary class]]) [footer appendFormat:@"\nLast error: %@", error[@"message"]];
        [footer appendFormat:@"\nReported %@.", [HCGDiagnostics formatTimestamp:runtime[HCGStatusUpdated]]];
    }
    [footer appendString:@"\n\nSettings changes apply immediately. A respring is needed only after installing or updating the package."];
    [group setProperty:footer forKey:@"footerText"];
    return specs;
}

- (NSArray *)diagnosticsSpecifiers {
    NSMutableArray *specs = [NSMutableArray array];
    PSSpecifier *group = [PSSpecifier groupSpecifierWithName:@"Diagnostics"];
    group.identifier = kDiagnosticsGroupID;
    [specs addObject:group];
    [specs addObject:[self valueRow:@"Build" value:HCGBuildDescription()]];
    [specs addObject:[self valueRow:@"Device" value:[NSString stringWithFormat:@"%@ · iOS %@ (%@)", [HCGSystemInfo deviceModel], [HCGSystemInfo osVersion], [HCGSystemInfo osBuild]]]];
    NSString *bundlePath = [NSBundle bundleForClass:[self class]].bundlePath ?: @"";
    [specs addObject:[self valueRow:@"Install location" value:[HCGSystemInfo installLocationForBundlePath:bundlePath]]];

    NSDictionary *runtime = [self runtimeStatus];
    if (runtime) {
        [specs addObject:[self valueRow:@"Injector" value:[runtime[HCGStatusInjector] description]]];
        [specs addObject:[self valueRow:@"Started by" value:[runtime[HCGStatusStartedBy] description]]];
        NSDictionary *overlay = runtime[HCGStatusOverlay];
        if ([overlay isKindOfClass:[NSDictionary class]]) {
            for (NSString *key in [overlay.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
                [specs addObject:[self valueRow:key value:[overlay[key] description]]];
            }
        }
    }

    PSSpecifier *copy = [PSSpecifier preferenceSpecifierNamed:@"Copy Diagnostics Report" target:self set:nil get:nil detail:nil cell:PSButtonCell edit:nil];
    copy.buttonAction = @selector(copyDiagnostics);
    [specs addObject:copy];
    [group setProperty:@"The report contains build, device model, iOS version, feature states and settings. It never includes your name, e-mail, device identifiers or HCG credentials, and nothing is sent anywhere: it is only copied to the clipboard." forKey:@"footerText"];
    return specs;
}

@end
