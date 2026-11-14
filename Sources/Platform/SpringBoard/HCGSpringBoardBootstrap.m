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
#import "HCGSystemInfo.h"
#include <os/log.h>
#include <mach-o/dyld.h>

NSString *const HCGKillSwitchPath = @"/var/mobile/Library/Preferences/com.hakmicapitalgroup.hcgnexus.killswitch";

@interface HCGSpringBoardBootstrap ()
@property (nonatomic, strong) HCGPreferencesKeyValueStore *store;
@property (nonatomic, strong, nullable) HCGNexusModel *model;
@property (nonatomic, strong, nullable) HCGSpringBoardLauncher *launcher;
@property (nonatomic, strong, nullable) HCGSpringBoardEnvironment *environment;
@property (nonatomic, strong, nullable) HCGOverlayController *overlay;
@property (nonatomic, strong, nullable) HCGLockStateMonitor *lockMonitor;
@property (nonatomic, copy) NSString *startupNote;
@property (nonatomic, copy, nullable) NSDictionary *lastError;
@property (nonatomic) BOOL enabled;
- (void)preferencesChanged;
- (void)writeRuntimeStatusForced:(BOOL)forced;
@end

static HCGSpringBoardBootstrap *gBootstrap;

static os_log_t HCGLog(void) {
    static os_log_t log;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ log = os_log_create("com.hakmicapitalgroup.hcgnexus", "springboard"); });
    return log;
}

// Status writes go through cfprefsd (IPC); keep them off SpringBoard's main thread.
static dispatch_queue_t HCGStatusQueue(void) {
    static dispatch_queue_t queue;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ queue = dispatch_queue_create("com.hakmicapitalgroup.hcgnexus.status", DISPATCH_QUEUE_SERIAL); });
    return queue;
}

static void HCGPreferencesCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef info) {
    dispatch_async(dispatch_get_main_queue(), ^{ [gBootstrap preferencesChanged]; });
}

static void HCGStatusRequestCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef info) {
    dispatch_async(dispatch_get_main_queue(), ^{ [gBootstrap writeRuntimeStatusForced:YES]; });
}

// Evidence for which injector loaded us: injector libraries present in this
// process' loaded images (not marker files on disk).
static NSString *HCGInjectorEvidence(void) {
    NSArray *needles = @[ @"ellekit", @"libsubstitute", @"substrate", @"libhooker", @"tweakloader", @"tweakinject" ];
    NSMutableOrderedSet *found = [NSMutableOrderedSet orderedSet];
    uint32_t count = _dyld_image_count();
    for (uint32_t i = 0; i < count; i++) {
        const char *path = _dyld_get_image_name(i);
        if (!path) continue;
        NSString *name = [[NSString stringWithUTF8String:path] lastPathComponent];
        NSString *lower = name.lowercaseString;
        for (NSString *needle in needles) {
            if ([lower containsString:needle]) { [found addObject:name]; break; }
        }
    }
    return found.count ? [found.array componentsJoinedByString:@", "] : @"none recognised (Nexus is loaded, so some injector is present)";
}

static NSMutableDictionary *HCGBaseStatus(NSString *state, NSString *reason, NSString *startedBy) {
    NSMutableDictionary *status = [NSMutableDictionary dictionary];
    status[HCGStatusSchema] = @(HCGRuntimeStatusSchemaVersion);
    status[HCGStatusVersion] = HCGBuildVersion();
    status[HCGStatusBuildID] = HCGBuildIdentifier();
    status[HCGStatusBuildConfig] = HCGBuildConfiguration();
    status[HCGStatusState] = state;
    if (reason.length) status[HCGStatusReason] = reason;
    status[HCGStatusStartedBy] = startedBy ?: @"unknown";
    status[HCGStatusInjector] = HCGInjectorEvidence();
    status[HCGStatusDeviceModel] = [HCGSystemInfo deviceModel];
    status[HCGStatusOSVersion] = [HCGSystemInfo osVersion];
    status[HCGStatusOSBuild] = [HCGSystemInfo osBuild];
    status[HCGStatusUpdated] = @([[NSDate date] timeIntervalSince1970]);
    return status;
}

// Writes a report for a SpringBoard where Nexus decided not to run at all, so
// Settings can say "stopped: <reason>" instead of "not loaded".
static void HCGWriteStoppedStatus(NSString *reason, NSString *startedBy) {
    NSMutableDictionary *status = HCGBaseStatus(@"stopped", reason, startedBy);
    status[HCGStatusFeatures] = @{
        HCGFeatureEdgeHandle : [HCGDiagnostics featureWithState:HCGFeatureStateUnavailable detail:reason],
    };
    dispatch_async(HCGStatusQueue(), ^{
        HCGPreferencesKeyValueStore *store = [[HCGPreferencesKeyValueStore alloc] initWithDomain:HCGNexusPreferencesDomain];
        [store setObject:status forKey:HCGRuntimeStatusKey];
        [store flush];
    });
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
            HCGWriteStoppedStatus(@"kill switch file present (/var/mobile/Library/Preferences/com.hakmicapitalgroup.hcgnexus.killswitch); delete it and respring to start Nexus", reason);
            return;
        }
        if (@available(iOS 14.0, *)) {
        } else {
            os_log(HCGLog(), "HCG Nexus: iOS older than 14 is not supported, staying inactive");
            HCGWriteStoppedStatus(@"unsupported iOS version (needs iOS 14 or later)", reason);
            return;
        }
        if (!NSClassFromString(@"UIWindowScene")) {
            os_log(HCGLog(), "HCG Nexus: UIWindowScene missing, staying inactive");
            HCGWriteStoppedStatus(@"unsupported: UIWindowScene is missing", reason);
            return;
        }
        gBootstrap = [[HCGSpringBoardBootstrap alloc] init];
        gBootstrap.startupNote = reason ?: @"unknown";
        [gBootstrap start];
    } @catch (NSException *exception) {
        os_log_error(HCGLog(), "HCG Nexus: startup failed: %{public}@", exception.reason);
        HCGWriteStoppedStatus([NSString stringWithFormat:@"startup failed: %@", exception.reason ?: exception.name], reason);
        gBootstrap = nil;
    }
}

- (void)recordError:(NSString *)message {
    os_log_error(HCGLog(), "HCG Nexus: %{public}@", message);
    self.lastError = @{ @"message" : message ?: @"unknown error", @"time" : @([[NSDate date] timeIntervalSince1970]) };
}

- (void)start {
    self.store = [[HCGPreferencesKeyValueStore alloc] initWithDomain:HCGNexusPreferencesDomain];
    CFNotificationCenterRef darwin = CFNotificationCenterGetDarwinNotifyCenter();
    CFNotificationCenterAddObserver(darwin, (__bridge const void *)self, HCGPreferencesCallback,
                                    (__bridge CFStringRef)HCGNexusSettingsChangedDarwinNotification, NULL,
                                    CFNotificationSuspensionBehaviorDeliverImmediately);
    CFNotificationCenterAddObserver(darwin, (__bridge const void *)self, HCGPreferencesCallback,
                                    (__bridge CFStringRef)HCGNexusWorkspacesChangedDarwinNotification, NULL,
                                    CFNotificationSuspensionBehaviorDeliverImmediately);
    CFNotificationCenterAddObserver(darwin, (__bridge const void *)self, HCGStatusRequestCallback,
                                    (__bridge CFStringRef)HCGNexusStatusRequestDarwinNotification, NULL,
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
        self.enabled = settings.enabled;
        if (settings.enabled && !self.overlay) [self activate];
        if (self.overlay) {
            [self.model reload]; // posts the in-process change; overlay applies settings
            [self.overlay applyModelSettings];
            if (settings.enabled) [self.lockMonitor start];
            else [self.lockMonitor stop];
        }
    } @catch (NSException *exception) {
        [self recordError:[NSString stringWithFormat:@"applying preferences failed: %@", exception.reason ?: exception.name]];
        self.enabled = NO;
        [self.overlay.coordinator updateSettings:[HCGSettings defaultSettings]]; // fail closed: disabled
    }
    [self writeRuntimeStatusForced:NO];
    // The overlay window is created lazily (first enable while unlocked);
    // report its state again once that has had a chance to happen.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self writeRuntimeStatusForced:NO];
    });
}

- (void)activate {
    self.launcher = [[HCGSpringBoardLauncher alloc] init];
    self.model = [[HCGNexusModel alloc] initWithStore:self.store notifier:[[HCGDarwinNotifier alloc] init] launcher:self.launcher];
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
    os_log(HCGLog(), "HCG Nexus: activated (%{public}@; %{public}@)", [self.launcher capabilitySummary], [self.lockMonitor sourceSummary]);
}

- (void)orientationMayHaveChanged {
    // The frontmost app finishes rotating slightly after the device does.
    [self.overlay interfaceOrientationMayHaveChanged];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.35 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self.overlay interfaceOrientationMayHaveChanged];
    });
}

#pragma mark Runtime report

- (NSDictionary *)featureReport {
    NSMutableDictionary *features = [NSMutableDictionary dictionary];
    NSDictionary *diag = self.overlay ? [self.overlay diagnostics] : @{};

    // Edge handle
    NSDictionary *handle;
    if (!self.enabled) {
        handle = [HCGDiagnostics featureWithState:HCGFeatureStateDisabled detail:@"Enable HCG Nexus is off in Settings"];
    } else if (!self.overlay) {
        handle = [HCGDiagnostics featureWithState:HCGFeatureStateUnknown detail:@"enabled, but SpringBoard has not applied it yet"];
    } else if (self.environment.window && !self.environment.windowHasScene) {
        handle = [HCGDiagnostics featureWithState:HCGFeatureStateFailed detail:@"overlay window has no UIWindowScene, so iOS cannot display it"];
    } else if (self.lockMonitor.signals.deviceLocked == HCGTriStateUnknown) {
        handle = [HCGDiagnostics featureWithState:HCGFeatureStateUnavailable detail:@"lock state cannot be read on this iOS; Nexus stays hidden (fail-closed)"];
    } else {
        handle = [HCGDiagnostics featureWithState:HCGFeatureStateOK detail:[diag[@"availability"] description] ?: @"available"];
    }
    features[HCGFeatureEdgeHandle] = handle;

    // App launching
    HCGSpringBoardLauncher *launcher = self.launcher ?: [[HCGSpringBoardLauncher alloc] init];
    features[HCGFeatureAppLaunching] = [launcher canLaunchApplicationsByBundleIdentifier]
        ? [HCGDiagnostics featureWithState:HCGFeatureStateOK detail:[launcher capabilitySummary]]
        : [HCGDiagnostics featureWithState:HCGFeatureStateUnsupported detail:[@"no launch API on this iOS: " stringByAppendingString:[launcher capabilitySummary]]];

    // Lock detection (only measured while active)
    if (self.lockMonitor) {
        BOOL any = self.lockMonitor.signals.deviceLocked != HCGTriStateUnknown;
        features[HCGFeatureLockDetection] = [HCGDiagnostics featureWithState:any ? HCGFeatureStateOK : HCGFeatureStateUnsupported
                                                                      detail:[self.lockMonitor sourceSummary]];
    } else {
        features[HCGFeatureLockDetection] = [HCGDiagnostics featureWithState:self.enabled ? HCGFeatureStateUnknown : HCGFeatureStateDisabled
                                                                      detail:@"measured once Nexus is enabled"];
    }

    // Orientation
    NSString *orientationSource = self.environment ? [self.environment orientationSourceSummary] : nil;
    if (!orientationSource) {
        features[HCGFeatureOrientation] = [HCGDiagnostics featureWithState:self.enabled ? HCGFeatureStateUnknown : HCGFeatureStateDisabled
                                                                    detail:@"measured once Nexus is enabled"];
    } else {
        BOOL available = ![orientationSource hasPrefix:@"unavailable"];
        features[HCGFeatureOrientation] = [HCGDiagnostics featureWithState:available ? HCGFeatureStateOK : HCGFeatureStateUnsupported
                                                                    detail:orientationSource];
    }
    return features;
}

- (NSDictionary *)overlayReport {
    if (!self.overlay) return @{ @"overlay" : self.enabled ? @"not created yet" : @"not created (disabled)" };
    NSMutableDictionary *overlay = [NSMutableDictionary dictionary];
    NSDictionary *diag = [self.overlay diagnostics];
    for (NSString *key in @[ @"availability", @"deviceLocked", @"coverSheetVisible", @"screenBlanked", @"panelState", @"visible", @"installCount", @"overlayWindows", @"gestureRecognizers", @"opens", @"closes", @"forcedCloses" ]) {
        if (diag[key]) overlay[key] = [diag[key] description];
    }
    [overlay addEntriesFromDictionary:[self.environment windowDiagnostics]];
    return overlay;
}

- (void)writeRuntimeStatusForced:(BOOL)forced {
    NSMutableDictionary *status = HCGBaseStatus(self.enabled ? @"active" : @"disabled",
                                                self.enabled ? nil : @"Enable HCG Nexus is off in Settings", self.startupNote);
    status[HCGStatusFeatures] = [self featureReport];
    status[HCGStatusOverlay] = [self overlayReport];
    if (self.lastError) status[HCGStatusLastError] = self.lastError;
    HCGPreferencesKeyValueStore *store = self.store;
    dispatch_async(HCGStatusQueue(), ^{
        if (!forced) {
            NSDictionary *previous = [store objectForKey:HCGRuntimeStatusKey];
            NSMutableDictionary *a = [previous isKindOfClass:[NSDictionary class]] ? [previous mutableCopy] : nil;
            NSMutableDictionary *b = [status mutableCopy];
            [a removeObjectForKey:HCGStatusUpdated];
            [b removeObjectForKey:HCGStatusUpdated];
            if ([a isEqualToDictionary:b]) return; // unchanged: avoid redundant writes
        }
        [store setObject:status forKey:HCGRuntimeStatusKey];
        [store flush];
    });
}

@end
