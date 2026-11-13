#import "HCGSpringBoardBootstrap.h"
#import <UIKit/UIKit.h>
#import "HCGCore.h"
#import "HCGNexusModel.h"
#import "HCGOverlayController.h"
#import "HCGPreferencesKeyValueStore.h"
#import "HCGSpringBoardLauncher.h"
#import "HCGSpringBoardEnvironment.h"
#import "HCGLockStateMonitor.h"
#import "HCGPanelSettingsViewController.h"
#include <os/log.h>

NSString *const HCGKillSwitchPath = @"/var/mobile/Library/Preferences/com.hakmicapitalgroup.hcgnexus.killswitch";
static NSString *const HCGRuntimeStatusKey = @"runtimeStatus";

@interface HCGSpringBoardBootstrap ()
@property (nonatomic, strong) HCGPreferencesKeyValueStore *store;
@property (nonatomic, strong, nullable) HCGNexusModel *model;
@property (nonatomic, strong, nullable) HCGSpringBoardEnvironment *environment;
@property (nonatomic, strong, nullable) HCGOverlayController *overlay;
@property (nonatomic, strong, nullable) HCGLockStateMonitor *lockMonitor;
@property (nonatomic, copy) NSString *startupNote;
- (void)preferencesChanged;
@end

static HCGSpringBoardBootstrap *gBootstrap;
static os_log_t HCGLog(void) {
    static os_log_t log;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ log = os_log_create("com.hakmicapitalgroup.hcgnexus", "springboard"); });
    return log;
}

static void HCGDarwinCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef info) {
    dispatch_async(dispatch_get_main_queue(), ^{ [gBootstrap preferencesChanged]; });
}

@implementation HCGSpringBoardBootstrap

+ (void)startAfterLaunch {
    [self startAfterLaunchWithReason:@"launch notification"];
}

+ (void)startAfterLaunchWithReason:(NSString *)reason {
    if (gBootstrap) return;
    @try {
        if ([[NSFileManager defaultManager] fileExistsAtPath:HCGKillSwitchPath]) {
            os_log(HCGLog(), "HCG Nexus: kill switch present, staying inactive");
            return;
        }
        if (@available(iOS 14.0, *)) {
        } else {
            os_log(HCGLog(), "HCG Nexus: iOS older than 14 is not supported, staying inactive");
            return;
        }
        if (!NSClassFromString(@"UIWindowScene")) {
            os_log(HCGLog(), "HCG Nexus: UIWindowScene missing, staying inactive");
            return;
        }
        gBootstrap = [[HCGSpringBoardBootstrap alloc] init];
        gBootstrap.startupNote = reason ?: @"unknown";
        [gBootstrap start];
    } @catch (NSException *exception) {
        os_log_error(HCGLog(), "HCG Nexus: startup failed: %{public}@", exception.reason);
        gBootstrap = nil;
    }
}

- (void)start {
    self.store = [[HCGPreferencesKeyValueStore alloc] initWithDomain:HCGNexusPreferencesDomain];
    CFNotificationCenterRef darwin = CFNotificationCenterGetDarwinNotifyCenter();
    CFNotificationCenterAddObserver(darwin, (__bridge const void *)self, HCGDarwinCallback,
                                    (__bridge CFStringRef)HCGNexusSettingsChangedDarwinNotification, NULL,
                                    CFNotificationSuspensionBehaviorDeliverImmediately);
    CFNotificationCenterAddObserver(darwin, (__bridge const void *)self, HCGDarwinCallback,
                                    (__bridge CFStringRef)HCGNexusWorkspacesChangedDarwinNotification, NULL,
                                    CFNotificationSuspensionBehaviorDeliverImmediately);
    // Defer the first preference read until SpringBoard's launch work is done.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self preferencesChanged];
    });
}

- (void)preferencesChanged {
    @try {
        [self.store reload];
        HCGSettings *settings = [HCGSettings settingsFromStore:self.store];
        if (settings.enabled && !self.overlay) [self activate];
        if (self.overlay) {
            [self.model reload]; // posts the in-process change; overlay applies settings
            [self.overlay applyModelSettings];
            if (settings.enabled) [self.lockMonitor start];
            else [self.lockMonitor stop];
        }
        [self writeRuntimeStatusWithEnabled:settings.enabled];
    } @catch (NSException *exception) {
        os_log_error(HCGLog(), "HCG Nexus: failed to apply preferences: %{public}@", exception.reason);
        [self.overlay.coordinator updateSettings:[HCGSettings defaultSettings]]; // fail closed: disabled
    }
}

- (void)activate {
    HCGSpringBoardLauncher *launcher = [[HCGSpringBoardLauncher alloc] init];
    self.model = [[HCGNexusModel alloc] initWithStore:self.store notifier:[[HCGDarwinNotifier alloc] init] launcher:launcher];
    self.environment = [[HCGSpringBoardEnvironment alloc] init];
    self.overlay = [[HCGOverlayController alloc] initWithModel:self.model environment:self.environment];
    self.lockMonitor = [[HCGLockStateMonitor alloc] init];

    __weak typeof(self) weakSelf = self;
    self.lockMonitor.changeHandler = ^(HCGSystemSignals signals) {
        [weakSelf.overlay updateSystemSignals:signals];
    };
    // Pulling down the cover sheet on an unlocked phone posts no lock-state
    // change, so re-read the (cheap) state right before honouring a tap.
    self.overlay.beforeActivation = ^{
        [weakSelf.lockMonitor refresh];
    };
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(orientationMayHaveChanged)
                                                 name:UIDeviceOrientationDidChangeNotification object:nil];
    [self.lockMonitor start];
    [self.overlay updateSystemSignals:self.lockMonitor.signals];
    os_log(HCGLog(), "HCG Nexus: activated (%{public}@; %{public}@)", [launcher capabilitySummary], [self.lockMonitor sourceSummary]);
}

- (void)orientationMayHaveChanged {
    // The frontmost app finishes rotating slightly after the device does.
    [self.overlay interfaceOrientationMayHaveChanged];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.35 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self.overlay interfaceOrientationMayHaveChanged];
    });
}

- (void)writeRuntimeStatusWithEnabled:(BOOL)enabled {
    NSMutableDictionary *status = [NSMutableDictionary dictionary];
    status[@"version"] = HCGBuildDescription();
    status[@"loadedInSpringBoard"] = @YES;
    status[@"startedBy"] = self.startupNote ?: @"unknown";
    status[@"enabled"] = @(enabled);
    status[@"activated"] = @(self.overlay != nil);
    status[@"updated"] = @([[NSDate date] timeIntervalSince1970]);
    if (self.overlay) {
        NSDictionary *diag = [self.overlay diagnostics];
        for (NSString *key in @[ @"availability", @"overlayWindows", @"gestureRecognizers", @"installCount", @"launcherCapabilities", @"panelState" ]) {
            id value = diag[key];
            if (value) status[key] = [value description];
        }
        status[@"lockSources"] = [self.lockMonitor sourceSummary];
        status[@"orientationSource"] = [self.environment orientationSourceSummary];
        status[@"overlayWindowScene"] = self.environment.window ? (self.environment.windowHasScene ? @"attached" : @"MISSING (window cannot display)") : @"not created yet";
    }
    NSDictionary *previous = [self.store objectForKey:HCGRuntimeStatusKey];
    NSMutableDictionary *comparablePrevious = [previous isKindOfClass:[NSDictionary class]] ? [previous mutableCopy] : nil;
    [comparablePrevious removeObjectForKey:@"updated"];
    NSMutableDictionary *comparable = [status mutableCopy];
    [comparable removeObjectForKey:@"updated"];
    if ([comparablePrevious isEqualToDictionary:comparable]) return; // avoid redundant writes
    [self.store setObject:status forKey:HCGRuntimeStatusKey];
    [self.store flush];
}

@end
