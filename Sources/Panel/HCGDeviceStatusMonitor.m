#import "HCGDeviceStatusMonitor.h"
#import <UIKit/UIKit.h>
#import <Network/Network.h>

@implementation HCGDeviceStatusMonitor {
    HCGDeviceStatusSnapshot *_snapshot;
    nw_path_monitor_t _pathMonitor;
    BOOL _enabledBatteryMonitoring;
    NSUInteger _generation; // drops storage reads that finish after -stop
}

- (instancetype)init {
    if ((self = [super init])) {
        _snapshot = [HCGDeviceStatusSnapshot unavailableSnapshot];
        _snapshot.networkStatus = HCGNetworkPathStatusUnavailable; // until monitoring starts
    }
    return self;
}

- (void)dealloc {
    [self stop];
}

- (HCGDeviceStatusSnapshot *)snapshot {
    return [_snapshot copy];
}

#pragma mark Lifecycle

- (void)start {
    if (_running) return;
    _running = YES;
    _generation += 1;

    UIDevice *device = [UIDevice currentDevice];
    if (!device.batteryMonitoringEnabled) {
        device.batteryMonitoringEnabled = YES;
        _enabledBatteryMonitoring = YES;
    }
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self selector:@selector(batteryChanged:) name:UIDeviceBatteryLevelDidChangeNotification object:device];
    [nc addObserver:self selector:@selector(batteryChanged:) name:UIDeviceBatteryStateDidChangeNotification object:device];
    // Posted on an arbitrary queue.
    [nc addObserver:self selector:@selector(powerStateChanged:) name:NSProcessInfoPowerStateDidChangeNotification object:nil];

    [self startPathMonitor];
    [self refresh];
}

- (void)stop {
    if (!_running) return;
    _running = NO;
    _generation += 1;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    if (_pathMonitor) {
        nw_path_monitor_cancel(_pathMonitor);
        _pathMonitor = nil;
    }
    if (_enabledBatteryMonitoring) {
        // Only undo what this monitor did; never switch off monitoring that
        // the host process had already enabled for itself.
        [UIDevice currentDevice].batteryMonitoringEnabled = NO;
        _enabledBatteryMonitoring = NO;
    }
    _snapshot.networkStatus = HCGNetworkPathStatusUnavailable;
    _snapshot.networkInterface = HCGNetworkInterfaceKindNone;
}

- (void)refresh {
    if (!_running) return;
    [self readBattery];
    [self readPowerMode];
    [self notify];
    [self readStorage];
}

#pragma mark Readers

- (void)readBattery {
    UIDevice *device = [UIDevice currentDevice];
    float level = device.batteryLevel; // -1 when unknown (e.g. simulator)
    _snapshot.batteryLevel = level;
    switch (device.batteryState) {
        case UIDeviceBatteryStateUnplugged: _snapshot.batteryState = HCGBatteryChargeStateUnplugged; break;
        case UIDeviceBatteryStateCharging: _snapshot.batteryState = HCGBatteryChargeStateCharging; break;
        case UIDeviceBatteryStateFull: _snapshot.batteryState = HCGBatteryChargeStateFull; break;
        default: _snapshot.batteryState = HCGBatteryChargeStateUnknown; break;
    }
}

- (void)readPowerMode {
    _snapshot.lowPowerMode = [NSProcessInfo processInfo].lowPowerModeEnabled ? HCGLowPowerModeStateOn : HCGLowPowerModeStateOff;
}

- (void)readStorage {
    NSUInteger generation = _generation;
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        long long available = -1, total = -1;
        NSURL *home = [NSURL fileURLWithPath:NSHomeDirectory() isDirectory:YES];
        NSDictionary *values = [home resourceValuesForKeys:@[ NSURLVolumeAvailableCapacityForImportantUsageKey, NSURLVolumeTotalCapacityKey ] error:NULL];
        NSNumber *important = values[NSURLVolumeAvailableCapacityForImportantUsageKey];
        NSNumber *capacity = values[NSURLVolumeTotalCapacityKey];
        if ([important isKindOfClass:[NSNumber class]] && important.longLongValue > 0) available = important.longLongValue;
        if ([capacity isKindOfClass:[NSNumber class]] && capacity.longLongValue > 0) total = capacity.longLongValue;
        if (available < 0 || total < 0) {
            NSDictionary *fs = [[NSFileManager defaultManager] attributesOfFileSystemForPath:NSHomeDirectory() error:NULL];
            NSNumber *free = fs[NSFileSystemFreeSize];
            NSNumber *size = fs[NSFileSystemSize];
            if (available < 0 && [free isKindOfClass:[NSNumber class]]) available = free.longLongValue;
            if (total < 0 && [size isKindOfClass:[NSNumber class]] && size.longLongValue > 0) total = size.longLongValue;
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf || !strongSelf->_running || strongSelf->_generation != generation) return;
            strongSelf->_snapshot.storageAvailableBytes = available;
            strongSelf->_snapshot.storageTotalBytes = total;
            [strongSelf notify];
        });
    });
}

- (void)startPathMonitor {
    nw_path_monitor_t monitor = nw_path_monitor_create();
    if (!monitor) {
        _snapshot.networkStatus = HCGNetworkPathStatusUnavailable;
        return;
    }
    _snapshot.networkStatus = HCGNetworkPathStatusUnknown; // until the first update
    _snapshot.networkInterface = HCGNetworkInterfaceKindNone;
    NSUInteger generation = _generation;
    __weak typeof(self) weakSelf = self;
    nw_path_monitor_set_queue(monitor, dispatch_get_main_queue());
    nw_path_monitor_set_update_handler(monitor, ^(nw_path_t path) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf || !strongSelf->_running || strongSelf->_generation != generation) return;
        [strongSelf applyPath:path];
    });
    _pathMonitor = monitor;
    nw_path_monitor_start(monitor);
}

- (void)applyPath:(nw_path_t)path {
    HCGNetworkPathStatus status = HCGNetworkPathStatusUnknown;
    switch (nw_path_get_status(path)) {
        case nw_path_status_satisfied: status = HCGNetworkPathStatusSatisfied; break;
        case nw_path_status_unsatisfied: status = HCGNetworkPathStatusUnsatisfied; break;
        case nw_path_status_satisfiable: status = HCGNetworkPathStatusRequiresConnection; break;
        default: status = HCGNetworkPathStatusUnknown; break; // nw_path_status_invalid
    }
    HCGNetworkInterfaceKind kind = HCGNetworkInterfaceKindNone;
    if (status == HCGNetworkPathStatusSatisfied) {
        if (nw_path_uses_interface_type(path, nw_interface_type_wifi)) kind = HCGNetworkInterfaceKindWiFi;
        else if (nw_path_uses_interface_type(path, nw_interface_type_cellular)) kind = HCGNetworkInterfaceKindCellular;
        else if (nw_path_uses_interface_type(path, nw_interface_type_wired)) kind = HCGNetworkInterfaceKindWired;
        else if (nw_path_uses_interface_type(path, nw_interface_type_other)) kind = HCGNetworkInterfaceKindOther;
    }
    _snapshot.networkStatus = status;
    _snapshot.networkInterface = kind;
    _snapshot.networkExpensive = nw_path_is_expensive(path);
    _snapshot.networkConstrained = nw_path_is_constrained(path);
    [self notify];
}

#pragma mark Notifications

- (void)batteryChanged:(NSNotification *)note {
    if (!_running) return;
    [self readBattery];
    [self notify];
}

- (void)powerStateChanged:(NSNotification *)note {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!self->_running) return;
        [self readPowerMode];
        [self notify];
    });
}

- (void)notify {
    if (self.changeHandler) self.changeHandler([_snapshot copy]);
}

@end
