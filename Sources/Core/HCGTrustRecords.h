#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// Package Trust Center records (docs/TRUST-CENTER.md): HCG Repo's Release Passport and compatibility registry,
// HCG Sentinel's repository-monitor results, Mach-O entitlements, the repositories you trust, and downloaded
// artifacts. All read-only; nothing here installs, publishes or contacts a server.

#pragma mark Release Passport (hcg.release-passport v1, HCG-repo docs/RELEASE_PASSPORT.md)

@interface HCGReleasePassport : NSObject {
    NSDictionary *_json;
    NSString *_package;
    NSString *_version;
    NSArray *_sections;
    NSArray *_warnings;
    NSDictionary *_entitlements;
}
@property (nonatomic, copy) NSDictionary *json;
@property (nonatomic, copy) NSString *package;
@property (nonatomic, copy) NSString *version;
// (section title, rows) where rows are (title, value) pairs, in display order.
@property (nonatomic, copy) NSArray<NSArray *> *sections;
@property (nonatomic, copy) NSArray<NSString *> *warnings;
@property (nonatomic, copy) NSDictionary<NSString *, NSArray<NSString *> *> *entitlements; // binary path -> keys
// nil when the data is not a version-1 passport; `error` explains.
+ (nullable instancetype)passportWithData:(nullable NSData *)data error:(NSString *_Nullable *_Nullable)error;
// Warnings that also need the index's SHA-256 for this version (the passport names other bytes, etc.).
- (NSArray<NSString *> *)warningsAgainstIndexSHA256:(nullable NSString *)sha256;
@end

#pragma mark Compatibility registry (hcg.repo.compatibility v1)

@interface HCGCompatibilityRegistry : NSObject {
    NSDictionary *_versions;
}
// nil unless format "hcg.repo.compatibility", version 1.
+ (nullable instancetype)registryWithData:(nullable NSData *)data;
// One version record (status, levels, known_failures, requirements, download, label), or nil.
- (nullable NSDictionary *)recordForPackage:(NSString *)package version:(NSString *)version;
@end

#pragma mark HCG Sentinel ↔ HCG Repo monitor (hcg.repo.monitor v1, HCG-repo docs/SENTINEL_MONITORING.md)

typedef NS_ENUM(NSInteger, HCGFindingSeverity) {
    HCGFindingSeverityOK = 0,
    HCGFindingSeverityUnknown = 1,
    HCGFindingSeverityWarning = 2,
    HCGFindingSeverityAlert = 3,
};

@interface HCGMonitorReport : NSObject {
    HCGFindingSeverity _status;
    NSString *_checkedAt;
    NSString *_target;
    NSArray *_findings;
}
@property (nonatomic) HCGFindingSeverity status;
@property (nonatomic, copy) NSString *checkedAt;
@property (nonatomic, copy) NSString *target;
@property (nonatomic, copy) NSArray<NSArray *> *findings; // (id, NSNumber severity, detail), worst first
+ (nullable instancetype)reportWithData:(nullable NSData *)data;
+ (HCGFindingSeverity)severityFromString:(nullable NSString *)status;
+ (NSString *)titleForSeverity:(HCGFindingSeverity)severity;
@end

#pragma mark Entitlements

typedef NS_ENUM(NSInteger, HCGEntitlementRisk) {
    HCGEntitlementRiskNormal = 0,
    HCGEntitlementRiskElevated = 1,   // private Apple entitlements
    HCGEntitlementRiskHigh = 2,       // runs outside the sandbox, as a platform binary, or can control other processes
};

@interface HCGEntitlements : NSObject
// The entitlements plist embedded in a Mach-O's code signature (thin or fat; the first slice that has one), or nil.
// `error` says why none was found ("not a Mach-O", "not signed", "no entitlements").
+ (nullable NSDictionary *)entitlementsInMachO:(NSData *)data error:(NSString *_Nullable *_Nullable)error;
+ (HCGEntitlementRisk)riskOfEntitlement:(NSString *)key;
// What it lets the program do, in words.
+ (NSString *)explanationOfEntitlement:(NSString *)key;
@end

#pragma mark Trusted repositories

@interface HCGTrustedRepository : NSObject {
    NSString *_identifier;
    NSString *_name;
    NSString *_url;
    NSString *_pinnedFingerprint;
    NSDate *_pinnedAt;
    BOOL _builtIn;
}
@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *url;                         // https, ends with "/"
@property (nonatomic, copy, nullable) NSString *pinnedFingerprint; // 40 hex; nil until YOU pin a key
@property (nonatomic, copy, nullable) NSDate *pinnedAt;
@property (nonatomic) BOOL builtIn;                                // HCG Repo Stable / Candidate: cannot be removed
@end

FOUNDATION_EXPORT NSString *const HCGTrustedRepositoriesStoreKey; // "trustedRepositories"

@interface HCGTrustedRepositoryList : NSObject
// HCG Repo Stable and Candidate (never pinned by default), then valid stored entries.
+ (NSArray<HCGTrustedRepository *> *)repositoriesFromStoredValue:(nullable id)value;
+ (NSArray *)storedValueForRepositories:(NSArray<HCGTrustedRepository *> *)repositories;
// A normalised https URL ending in "/", or nil with a reason (no credentials, query, fragment or non-https).
+ (nullable NSString *)normalizedRepositoryURL:(nullable NSString *)text reason:(NSString *_Nullable *_Nullable)reason;
+ (nullable NSString *)normalizedFingerprint:(nullable NSString *)text;
@end

#pragma mark Verified downloads

// A downloaded .deb whose bytes matched the index. For a future installer hand-off: call -stillMatches: immediately
// before handing over the path. The file is made read-only after verification and is named by its SHA-256, so the
// path handed over names the verified bytes; -stillMatches: re-hashes them to prove nothing changed in between.
@interface HCGVerifiedArtifact : NSObject {
    NSString *_path;
    NSString *_sha256;
    unsigned long long _size;
    NSDate *_verifiedAt;
}
@property (nonatomic, copy, readonly) NSString *path;
@property (nonatomic, copy, readonly) NSString *sha256;
@property (nonatomic, readonly) unsigned long long size;
@property (nonatomic, copy, readonly) NSDate *verifiedAt;
// Hashes the file; on a match moves it to <directory>/<sha256>.deb, read-only. nil on mismatch (the file is
// deleted) or error; `error` explains.
+ (nullable instancetype)verifyDownloadAtPath:(NSString *)path expectedSHA256:(NSString *)sha256 expectedSize:(unsigned long long)size
                                  intoDirectory:(NSString *)directory error:(NSString *_Nullable *_Nullable)error;
- (BOOL)stillMatches:(NSString *_Nullable *_Nullable)reason;
// Creates the directory with owner-only permissions (0700) if needed.
+ (BOOL)prepareDirectory:(NSString *)directory;
@end

NS_ASSUME_NONNULL_END
