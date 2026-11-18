#import "HCGBranding.h"

#ifndef HCG_INSTALL_PREFIX
#define HCG_INSTALL_PREFIX ""
#endif

@implementation HCGBranding

+ (NSArray<NSString *> *)supportDirectories {
    NSString *suffix = @"/Library/Application Support/HCGNexus";
    NSMutableArray *dirs = [NSMutableArray array];
    NSString *prefix = @HCG_INSTALL_PREFIX;
    [dirs addObject:[prefix stringByAppendingString:suffix]];
    if (![prefix isEqualToString:@"/var/jb"]) [dirs addObject:[@"/var/jb" stringByAppendingString:suffix]];
    if (prefix.length > 0) [dirs addObject:suffix];
    return dirs;
}

+ (UIImage *)imageWithAssetName:(NSString *)assetName fileNames:(NSArray<NSString *> *)fileNames {
    static NSCache *cache;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ cache = [[NSCache alloc] init]; });
    UIImage *cached = [cache objectForKey:assetName];
    if (cached) return cached;
    UIImage *image = [UIImage imageNamed:assetName];
    for (NSString *file in fileNames) {
        if (image) break;
        image = [UIImage imageNamed:[file stringByDeletingPathExtension]];
        for (NSString *dir in [self supportDirectories]) {
            if (image) break;
            NSString *path = [dir stringByAppendingPathComponent:file];
            if ([[NSFileManager defaultManager] isReadableFileAtPath:path]) {
                image = [UIImage imageWithContentsOfFile:path];
                if (image && image.scale < 2) image = [UIImage imageWithCGImage:image.CGImage scale:3 orientation:UIImageOrientationUp];
            }
        }
    }
    if (image) [cache setObject:image forKey:assetName];
    return image;
}

+ (UIImage *)hcgLogo {
    return [self imageWithAssetName:@"HCGLogo" fileNames:@[ @"hcg-logo.png" ]];
}

+ (UIImage *)nexusEmblem {
    return [self imageWithAssetName:@"NexusEmblem" fileNames:@[ @"nexus-emblem.png" ]];
}

+ (UIImage *)nexusBanner {
    return [self imageWithAssetName:@"HCGNexusBanner" fileNames:@[ @"hcg-nexus-banner.png", @"hcg-nexus-banner.jpg" ]];
}

@end
