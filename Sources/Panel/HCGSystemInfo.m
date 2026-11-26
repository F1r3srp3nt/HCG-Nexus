#import "HCGSystemInfo.h"
#include <mach/mach.h>
#include <sys/resource.h>
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

+ (double)processMemoryFootprintMB {
    task_vm_info_data_t info;
    mach_msg_type_number_t count = TASK_VM_INFO_COUNT;
    if (task_info(mach_task_self(), TASK_VM_INFO, (task_info_t)&info, &count) != KERN_SUCCESS) return -1;
    return (double)info.phys_footprint / (1024.0 * 1024.0);
}

+ (double)processCPUSeconds {
    struct rusage usage;
    if (getrusage(RUSAGE_SELF, &usage) != 0) return -1;
    return (double)usage.ru_utime.tv_sec + usage.ru_utime.tv_usec / 1e6 + (double)usage.ru_stime.tv_sec + usage.ru_stime.tv_usec / 1e6;
}

@end
