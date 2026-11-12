#import "HCGNexusModel.h"

NSNotificationName const HCGNexusModelDidChangeNotification = @"HCGNexusModelDidChangeNotification";

@implementation HCGNexusModel {
    id<HCGChangeNotifier> _notifier;
    HCGSettings *_settings;
}

- (instancetype)initWithStore:(id<HCGKeyValueStore>)store notifier:(id<HCGChangeNotifier>)notifier launcher:(id<HCGLauncher>)launcher {
    if ((self = [super init])) {
        _store = store;
        _notifier = notifier;
        _launcher = launcher;
        _workspaceStore = [[HCGWorkspaceStore alloc] initWithStore:store];
        _recents = [[HCGRecents alloc] initWithStore:store];
        _settings = [HCGSettings defaultSettings];
        [self reloadWithoutNotifying];
    }
    return self;
}

- (HCGSettings *)settings {
    return [_settings copy];
}

- (void)reloadWithoutNotifying {
    [_store reload];
    _settings = [HCGSettings settingsFromStore:_store];
    [_workspaceStore load];
    [_recents load];
}

- (void)notifyLocal {
    if ([NSThread isMainThread]) {
        [[NSNotificationCenter defaultCenter] postNotificationName:HCGNexusModelDidChangeNotification object:self];
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:HCGNexusModelDidChangeNotification object:self];
        });
    }
}

- (void)reload {
    [self reloadWithoutNotifying];
    // A first-run seed writes the presets; let other processes know.
    if (_workspaceStore.seededOnLoad) [_notifier postWorkspacesChanged];
    [self notifyLocal];
}

- (void)saveSettings:(HCGSettings *)settings {
    _settings = [settings copy];
    [_settings writeToStore:_store];
    [_notifier postSettingsChanged];
    [self notifyLocal];
}

- (void)resetSettings {
    HCGSettings *settings = [_settings copy];
    [settings resetPreservingEnabledAndIntegrations];
    [self saveSettings:settings];
}

- (void)workspacesDidChange {
    [_notifier postWorkspacesChanged];
    [self notifyLocal];
}

- (void)clearRecents {
    [_recents clear];
    [_notifier postWorkspacesChanged];
    [self notifyLocal];
}

- (NSArray<HCGIntegrationStatus *> *)integrationStatuses {
    return [HCGIntegrationCatalog allStatusesWithSettings:_settings probe:_launcher];
}

- (HCGIntegrationStatus *)statusForIntegration:(NSString *)identifier {
    return [HCGIntegrationCatalog statusForIdentifier:identifier settings:_settings probe:_launcher];
}

@end
