#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// Debian package versions and package lists, read-only.
//
// HCG products are distributed as .deb packages through HCG Repo. Nexus reads, never writes:
//   * the dpkg status file (<jbroot>/var/lib/dpkg/status) for what is installed, and
//   * package lists the user's package manager already downloaded (apt lists, Zebra's lists) for which
//     versions HCG Repo offers, as of that manager's last refresh.
// Nothing here installs, removes, refreshes or contacts a server.

@interface HCGDebianVersion : NSObject
// dpkg's ordering ([epoch:]upstream[-revision], with "~" sorting before everything, so 0.2.0~rc2 < 0.2.0).
// An invalid version sorts before every valid one.
+ (NSComparisonResult)compare:(nullable NSString *)a with:(nullable NSString *)b;
+ (BOOL)isValid:(nullable NSString *)version;
@end

@interface HCGPackageRecord : NSObject {
    NSString *_package;
    NSString *_version;
    NSString *_status;
    NSString *_name;
    NSString *_architecture;
}
@property (nonatomic, copy) NSString *package;
@property (nonatomic, copy) NSString *version;
@property (nonatomic, copy, nullable) NSString *status;        // dpkg status file only ("install ok installed")
@property (nonatomic, copy, nullable) NSString *name;
@property (nonatomic, copy, nullable) NSString *architecture;
@property (nonatomic, readonly) BOOL installed;                 // status ends in " installed" (status file)
@end

@interface HCGPackageIndex : NSObject
// Every stanza with a Package and a valid Version, in file order. Continuation lines are ignored.
+ (NSArray<HCGPackageRecord *> *)recordsFromText:(nullable NSString *)text;
// package -> version for packages dpkg reports as installed, limited to `packages` (nil: all).
+ (NSDictionary<NSString *, NSString *> *)installedVersionsFromStatusText:(nullable NSString *)text
                                                                 packages:(nullable NSSet<NSString *> *)packages;
// package -> highest version offered across the given package lists (Packages files), limited to `packages`
// (nil: all) and to `architectures` (nil: any; "all" always matches).
+ (NSDictionary<NSString *, NSString *> *)highestVersionsFromIndexTexts:(NSArray<NSString *> *)texts
                                                               packages:(nullable NSSet<NSString *> *)packages
                                                          architectures:(nullable NSSet<NSString *> *)architectures;
// YES when `offered` is a newer version than `installed` (both valid).
+ (BOOL)isUpdate:(nullable NSString *)offered over:(nullable NSString *)installed;
// A package-list file name that belongs to HCG Repo (apt's and Zebra's naming:
// "repo.hakmicapitalgroup.com_repo_candidate_Packages", "repo.hakmicapitalgroup.com_repo_candidate_._Packages").
+ (BOOL)isHCGRepoListFileName:(NSString *)fileName;
// "candidate", "stable" or nil, from such a file name.
+ (nullable NSString *)channelForListFileName:(NSString *)fileName;
@end

NS_ASSUME_NONNULL_END
