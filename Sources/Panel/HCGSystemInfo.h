#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// Device facts for diagnostics. Public APIs only (sysctlbyname, UIDevice).
// Never collects the device name, serial number, UDID or anything personal.
@interface HCGSystemInfo : NSObject
+ (NSString *)deviceModel;   // hw.machine, e.g. "iPhone14,2"; "unknown" if unreadable
+ (NSString *)osVersion;     // e.g. "16.5"
+ (NSString *)osBuild;       // kern.osversion, e.g. "20F66"; "unknown" if unreadable
// Where a bundle is installed, judged from its own path (evidence, not marker
// files): "/var/jb (rootless layout)", "/ (rootful layout)" or "unknown".
+ (NSString *)installLocationForBundlePath:(NSString *)bundlePath;
// This process's own resource use (public mach and BSD APIs; no other process is read). In the SpringBoard overlay
// the process is SpringBoard. Memory: the physical footprint (what Xcode and Jetsam count), in MB, or -1. CPU: user +
// system seconds since launch, or -1.
+ (double)processMemoryFootprintMB;
+ (double)processCPUSeconds;
@end

NS_ASSUME_NONNULL_END
