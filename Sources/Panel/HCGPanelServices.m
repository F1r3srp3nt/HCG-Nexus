#import "HCGPanelServices.h"
#import "HCGSystemInfo.h"
#import "HCGPanelSettingsViewController.h"

static NSInteger gMonitoringDepth;
static BOOL gPreviousMonitoring;

@implementation HCGDeviceFacts

+ (void)beginMonitoring {
    if (gMonitoringDepth++ == 0) {
        gPreviousMonitoring = [UIDevice currentDevice].batteryMonitoringEnabled;
        [UIDevice currentDevice].batteryMonitoringEnabled = YES;
    }
}

+ (void)endMonitoring {
    if (gMonitoringDepth <= 0) return;
    if (--gMonitoringDepth == 0) [UIDevice currentDevice].batteryMonitoringEnabled = gPreviousMonitoring;
}

+ (NSString *)battery {
    UIDevice *device = [UIDevice currentDevice];
    if (!device.batteryMonitoringEnabled || device.batteryState == UIDeviceBatteryStateUnknown || device.batteryLevel < 0) return @"Unavailable";
    NSString *state = @"";
    switch (device.batteryState) {
        case UIDeviceBatteryStateCharging: state = @" · charging"; break;
        case UIDeviceBatteryStateFull: state = @" · full"; break;
        case UIDeviceBatteryStateUnplugged: state = @" · on battery"; break;
        default: break;
    }
    return [NSString stringWithFormat:@"%ld%%%@", (long)lroundf(device.batteryLevel * 100.0f), state];
}

+ (NSString *)thermal {
    switch ([NSProcessInfo processInfo].thermalState) {
        case NSProcessInfoThermalStateNominal: return @"Normal";
        case NSProcessInfoThermalStateFair: return @"Fair";
        case NSProcessInfoThermalStateSerious: return @"Serious";
        case NSProcessInfoThermalStateCritical: return @"Critical";
    }
    return @"Unavailable";
}

+ (NSString *)storage {
    NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfFileSystemForPath:NSHomeDirectory() error:NULL];
    NSNumber *free = attributes[NSFileSystemFreeSize];
    NSNumber *size = attributes[NSFileSystemSize];
    if (![free isKindOfClass:[NSNumber class]] || ![size isKindOfClass:[NSNumber class]] || size.longLongValue <= 0) return @"Unavailable";
    NSString *freeText = [NSByteCountFormatter stringFromByteCount:free.longLongValue countStyle:NSByteCountFormatterCountStyleFile];
    NSString *sizeText = [NSByteCountFormatter stringFromByteCount:size.longLongValue countStyle:NSByteCountFormatterCountStyleFile];
    return [NSString stringWithFormat:@"%@ free of %@", freeText, sizeText];
}

+ (NSString *)uptime {
    NSDateComponentsFormatter *formatter = [[NSDateComponentsFormatter alloc] init];
    formatter.unitsStyle = NSDateComponentsFormatterUnitsStyleAbbreviated;
    formatter.allowedUnits = NSCalendarUnitDay | NSCalendarUnitHour | NSCalendarUnitMinute;
    formatter.maximumUnitCount = 2;
    return [formatter stringFromTimeInterval:[NSProcessInfo processInfo].systemUptime] ?: @"Unavailable";
}

+ (NSArray<NSArray<NSString *> *> *)rows {
    NSString *model = [HCGSystemInfo deviceModel];
    return @[
        @[ @"Model", [NSString stringWithFormat:@"%@ (%@)", [UIDevice currentDevice].model, model] ],
        @[ @"iOS", [NSString stringWithFormat:@"%@ (%@)", [HCGSystemInfo osVersion], [HCGSystemInfo osBuild]] ],
        @[ @"Battery", [self battery] ],
        @[ @"Low Power Mode", [NSProcessInfo processInfo].lowPowerModeEnabled ? @"On" : @"Off" ],
        @[ @"Thermal state", [self thermal] ],
        @[ @"Storage", [self storage] ],
        @[ @"Uptime", [self uptime] ],
    ];
}

@end

BOOL HCGIsCandidateBuild(void) {
    return [HCGBuildVersion() rangeOfString:@"~"].location != NSNotFound;
}

NSString *HCGPanelDiagnosticsReport(HCGPanelContext *context) {
    HCGNexusModel *model = context.model;
    NSUInteger failures = 0;
    for (HCGRecentEntry *entry in model.recents.entries) {
        if (!entry.succeeded) failures++;
    }
    NSMutableArray *settingsLines = [NSMutableArray array];
    NSDictionary *settings = [model.settings dictionaryRepresentation];
    for (NSString *key in [settings.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
        [settingsLines addObject:[NSString stringWithFormat:@"%@ = %@", key, settings[key]]];
    }
    NSString *bundlePath = [NSBundle bundleForClass:[HCGDeviceFacts class]].bundlePath ?: @"";
    NSDictionary *local = @{
        @"version" : HCGBuildVersion(),
        @"buildID" : HCGBuildIdentifier(),
        @"buildConfig" : HCGBuildConfiguration(),
        @"installPrefix" : [HCGSystemInfo installLocationForBundlePath:bundlePath],
        @"installEvidence" : [NSString stringWithFormat:@"%@ (%@)", HCGPanelModeName(context.mode), bundlePath.lastPathComponent ?: @""],
        @"deviceModel" : [HCGSystemInfo deviceModel],
        @"osVersion" : [HCGSystemInfo osVersion],
        @"osBuild" : [HCGSystemInfo osBuild],
        @"generated" : [HCGDiagnostics formatTimestamp:@([[NSDate date] timeIntervalSince1970])],
        @"settingsSummary" : [settingsLines componentsJoinedByString:@"\n"],
        @"workspaceCount" : [@(model.workspaceStore.workspaces.count) description],
        @"recentCount" : [@(model.recents.entries.count) description],
        @"recentFailures" : [@(failures) description],
    };
    // SpringBoard's runtime report exists only for the jailbreak package.
    id runtime = (context.mode == HCGPanelModeOverlay || context.mode == HCGPanelModeSettingsApp) ? [model.store objectForKey:HCGRuntimeStatusKey] : nil;
    NSString *report = [HCGDiagnostics reportWithLocal:local runtime:[runtime isKindOfClass:[NSDictionary class]] ? runtime : nil];
    if (context.mode == HCGPanelModePreview) report = [@"PREVIEW HARNESS (simulation, not injected into SpringBoard)\n\n" stringByAppendingString:report];
    return report;
}
