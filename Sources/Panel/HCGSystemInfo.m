#import "HCGSystemInfo.h"
#import <UIKit/UIKit.h>
#include <sys/sysctl.h>

static NSString *HCGSysctlString(const char *name) {
    size_t size = 0;
    if (sysctlbyname(name, NULL, &size, NULL, 0) != 0 || size == 0 || size > 256) return nil;
    char buffer[257] = {0};
    if (sysctlbyname(name, buffer, &size, NULL, 0) != 0) return nil;
    NSString *value = [NSString stringWithUTF8String:buffer];
    return value.length ? value : nil;
}

@implementation HCGSystemInfo

+ (NSString *)deviceModel {
    return HCGSysctlString("hw.machine") ?: @"unknown";
}

+ (NSString *)osVersion {
    return [UIDevice currentDevice].systemVersion ?: @"unknown";
}

+ (NSString *)osBuild {
    return HCGSysctlString("kern.osversion") ?: @"unknown";
}

+ (NSString *)installLocationForBundlePath:(NSString *)bundlePath {
    NSString *resolved = [bundlePath stringByResolvingSymlinksInPath] ?: bundlePath;
    if ([bundlePath hasPrefix:@"/var/jb/"] || [resolved hasPrefix:@"/var/jb/"] ||
        [resolved rangeOfString:@"/procursus/"].location != NSNotFound) {
        return @"/var/jb (rootless layout)";
    }
    if ([resolved hasPrefix:@"/Library/"] || [bundlePath hasPrefix:@"/Library/"]) return @"/ (rootful layout)";
    return @"unknown";
}

@end
