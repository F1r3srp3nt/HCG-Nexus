#import <Foundation/Foundation.h>
#import "HCGCore.h"

NS_ASSUME_NONNULL_BEGIN

// Reads a repository's public metadata for the Package Trust Center. Read-only and unauthenticated:
//   * https only, an ephemeral session (no cookies, no credentials, no cache), redirects refused;
//   * fixed file names under the repository URL — Release, InRelease, Release.gpg, Packages, the published key —
//     plus HCG Repo's compatibility registry (<host>/compatibility.json) when HCG Repo publishes it;
//   * size limits (8 MB metadata, 64 MB packages) and a 20 s timeout per file;
//   * a 404 is recorded as "not published", never treated as an error.
// Downloads go to a Nexus-owned folder and are kept only when their SHA-256 and size match the index
// (HCGVerifiedArtifact). Nothing is installed, and no other app's files or settings are touched.

@interface HCGTrustFetchResult : NSObject
@property (nonatomic, strong) HCGRepositoryEvidence *evidence;
@property (nonatomic, strong, nullable) HCGCompatibilityRegistry *compatibility;
@property (nonatomic, copy) NSDictionary<NSString *, NSString *> *fileStates; // file -> "200", "404", "error: …"
@property (nonatomic, copy, nullable) NSString *failure;                       // the repository could not be read
@end

@interface HCGTrustFetcher : NSObject
+ (instancetype)sharedFetcher;
// Completion on the main queue.
- (void)fetchRepository:(HCGTrustedRepository *)repository completion:(void (^)(HCGTrustFetchResult *result))completion;
// A Release Passport at <repository>/passports/<package>_<version>.json (proposed location; HCG Repo does not
// publish passports yet). Completion on the main queue with nil when not published.
- (void)fetchPassportForPackage:(NSString *)package version:(NSString *)version repository:(HCGTrustedRepository *)repository
                     completion:(void (^)(HCGReleasePassport *_Nullable passport, NSString *state))completion;
// Downloads <repository>/<Filename> and verifies it against the index entry. Completion on the main queue.
- (void)downloadPackage:(NSDictionary *)stanza repository:(HCGTrustedRepository *)repository
             completion:(void (^)(HCGVerifiedArtifact *_Nullable artifact, NSString *_Nullable sha256, unsigned long long size, NSString *_Nullable error))completion;
// Where verified downloads are kept (owner-only).
+ (NSString *)verifiedDownloadsDirectory;
@end

NS_ASSUME_NONNULL_END
