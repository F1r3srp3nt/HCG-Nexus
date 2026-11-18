#import <Foundation/Foundation.h>
#import "HCGCommandMode.h"

NS_ASSUME_NONNULL_BEGIN

// Reads real device status for Command Mode through PUBLIC APIs only:
//   * battery level and charging state — UIDevice (batteryMonitoringEnabled)
//   * Low Power Mode — NSProcessInfo.lowPowerModeEnabled
//   * network path — Network.framework nw_path_monitor (no request is made;
//     it only reports whether iOS has a usable route and over which interface)
//   * available storage — NSURL volume resource values (NSFileManager fallback)
// Nothing is sent anywhere and nothing is polled in the background: the
// monitor runs only between -start and -stop (while Command Mode is on
// screen). Values iOS does not provide stay "unavailable" in the snapshot.
@interface HCGDeviceStatusMonitor : NSObject
// Called on the main queue whenever a value changes (also once after -start).
@property (nonatomic, copy, nullable) void (^changeHandler)(HCGDeviceStatusSnapshot *snapshot);
@property (nonatomic, readonly) HCGDeviceStatusSnapshot *snapshot; // copy
@property (nonatomic, readonly, getter=isRunning) BOOL running;
// Main thread only. Idempotent.
- (void)start;
// Main thread only. Idempotent. Restores UIDevice battery monitoring if this
// monitor was the one that turned it on.
- (void)stop;
// Re-reads battery, power mode and storage (network updates arrive by itself).
- (void)refresh;
@end

NS_ASSUME_NONNULL_END
