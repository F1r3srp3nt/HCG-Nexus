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
@end

NS_ASSUME_NONNULL_END
