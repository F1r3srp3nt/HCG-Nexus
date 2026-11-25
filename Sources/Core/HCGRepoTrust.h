#import <Foundation/Foundation.h>
#import "HCGOpenPGP.h"

NS_ASSUME_NONNULL_BEGIN

// Package Trust Center — the repository chain (docs/TRUST-CENTER.md).
//
//   pinned key ──signs──▶ Release / InRelease ──lists SHA-256──▶ Packages ──lists SHA-256──▶ .deb bytes
//
// Two separate questions, never merged into "safe":
//   * Authenticity: are these the bytes the repository's owner published? Verified needs a good signature by the key
//     YOU pinned, an unexpired Release, a consistent index, and — for a download — a matching SHA-256 and size.
//   * Device evidence: did this version install or launch on a recorded physical device? From HCG Repo's
//     compatibility registry when published, and from the package's own firmware requirement.
// A matching checksum alone proves only that the bytes are the ones the index names; on an unsigned repository the
// index itself is unauthenticated.

typedef NS_ENUM(NSInteger, HCGAuthenticity) {
    HCGAuthenticityVerified = 0,   // good signature by the pinned key, index consistent, not expired
    HCGAuthenticityUnsigned = 1,   // the repository publishes no signature
    HCGAuthenticityUntrusted = 2,  // signed, but not by a key you pinned (or a weak/unsupported signature)
    HCGAuthenticityExpired = 3,    // signing key or signature expired, or Release past Valid-Until
    HCGAuthenticityInvalid = 4,    // BAD signature, InRelease ≠ Release, index or download checksum mismatch
    HCGAuthenticityUnknown = 5,    // not checked yet, or the repository could not be read
};

typedef NS_ENUM(NSInteger, HCGDeviceEvidence) {
    HCGDeviceEvidenceLaunchPassed = 0,     // a recorded physical-device launch passed
    HCGDeviceEvidenceInstallPassed = 1,    // a recorded physical-device installation passed (launch not recorded)
    HCGDeviceEvidenceUntested = 2,         // no physical-device evidence
    HCGDeviceEvidenceIncompatible = 3,     // recorded failure, or this iOS is outside its firmware requirement
    HCGDeviceEvidenceWithdrawn = 4,
    HCGDeviceEvidenceUnknown = 5,          // HCG Repo publishes no compatibility data yet
};

typedef NS_ENUM(NSInteger, HCGChecksumState) {
    HCGChecksumStateNotDownloaded = 0,
    HCGChecksumStateMatches = 1,
    HCGChecksumStateMismatch = 2,
};

// A Debian Release file.
@interface HCGReleaseFile : NSObject {
    NSDictionary *_fields;
    NSDictionary *_sha256;
    NSDate *_date;
    NSDate *_validUntil;
}
@property (nonatomic, copy) NSDictionary<NSString *, NSString *> *fields;          // single-line fields
@property (nonatomic, copy) NSDictionary<NSString *, NSArray *> *sha256;            // path -> (hex, size)
@property (nonatomic, copy, nullable) NSDate *date;
@property (nonatomic, copy, nullable) NSDate *validUntil;
+ (nullable instancetype)releaseWithData:(nullable NSData *)data;
// RFC 2822 dates as APT writes them ("Wed, 25 Nov 2026 10:01:52 GMT").
+ (nullable NSDate *)dateFromRFC2822:(nullable NSString *)text;
@end

// Everything fetched for one repository (any part may be nil).
@interface HCGRepositoryEvidence : NSObject {
    NSString *_repositoryURL;
    NSData *_release;
    NSData *_inRelease;
    NSData *_releaseSignature;
    NSData *_packages;
    NSString *_packagesPath;
    NSData *_publishedKey;
    NSString *_pinnedFingerprint;
    NSDate *_now;
}
@property (nonatomic, copy) NSString *repositoryURL;
@property (nonatomic, copy, nullable) NSData *release;           // Release
@property (nonatomic, copy, nullable) NSData *inRelease;         // InRelease
@property (nonatomic, copy, nullable) NSData *releaseSignature;  // Release.gpg
@property (nonatomic, copy, nullable) NSData *packages;          // Packages (uncompressed)
@property (nonatomic, copy) NSString *packagesPath;              // its path in Release ("Packages")
@property (nonatomic, copy, nullable) NSData *publishedKey;      // <repo>/hcg-repo-archive-key.asc, for inspection
@property (nonatomic, copy, nullable) NSString *pinnedFingerprint; // the primary fingerprint YOU trust, or nil
@property (nonatomic, copy, nullable) NSDate *now;
@end

@interface HCGRepositoryReport : NSObject {
    HCGAuthenticity _authenticity;
    NSString *_summary;
    NSArray *_rows;
    NSArray *_warnings;
    HCGPGPVerification *_detachedResult;
    HCGPGPVerification *_inlineResult;
    HCGPGPCertificate *_publishedCertificate;
    BOOL _indexConsistent;
    HCGReleaseFile *_releaseFile;
    NSArray *_packages;
}
@property (nonatomic) HCGAuthenticity authenticity;
@property (nonatomic, copy) NSString *summary;
@property (nonatomic, copy) NSArray<NSArray<NSString *> *> *rows;     // (title, value) evidence rows
@property (nonatomic, copy) NSArray<NSString *> *warnings;
@property (nonatomic, strong, nullable) HCGPGPVerification *detachedResult;
@property (nonatomic, strong, nullable) HCGPGPVerification *inlineResult;
@property (nonatomic, strong, nullable) HCGPGPCertificate *publishedCertificate; // the key the repository publishes
@property (nonatomic) BOOL indexConsistent;                            // Release lists the served Packages' SHA-256 and size
@property (nonatomic, strong, nullable) HCGReleaseFile *releaseFile;
@property (nonatomic, copy) NSArray<NSDictionary *> *packages;          // stanzas: field -> value, plus "_order"
@end

@interface HCGPackageAssessment : NSObject {
    NSString *_package;
    NSString *_version;
    HCGAuthenticity _authenticity;
    HCGDeviceEvidence _deviceEvidence;
    HCGChecksumState _checksum;
    NSString *_authenticityText;
    NSString *_deviceText;
    NSArray *_warnings;
}
@property (nonatomic, copy) NSString *package;
@property (nonatomic, copy) NSString *version;
@property (nonatomic) HCGAuthenticity authenticity;
@property (nonatomic) HCGDeviceEvidence deviceEvidence;
@property (nonatomic) HCGChecksumState checksum;
@property (nonatomic, copy) NSString *authenticityText;
@property (nonatomic, copy) NSString *deviceText;
@property (nonatomic, copy) NSArray<NSString *> *warnings;
@end

@interface HCGRepoTrust : NSObject
+ (HCGRepositoryReport *)evaluate:(HCGRepositoryEvidence *)evidence;

// Debian control stanzas with every field (multi-line values joined with "\n"); key order under "_order".
+ (NSArray<NSDictionary *> *)stanzasFromText:(nullable NSString *)text;

// `stanza`: one Packages entry. `compatibility`: this package's version record from HCG Repo's compatibility
// registry (HCGCompatibilityRegistry), or nil. `downloadedSHA256`/`downloadedSize`: a download's digest, or nil.
+ (HCGPackageAssessment *)assessPackage:(NSDictionary *)stanza
                             repository:(HCGRepositoryReport *)repository
                          compatibility:(nullable NSDictionary *)compatibility
                              deviceIOS:(nullable NSString *)deviceIOS
                       downloadedSHA256:(nullable NSString *)downloadedSHA256
                         downloadedSize:(unsigned long long)downloadedSize;

// firmware (>= 15.0), firmware (<< 17.0) from a Depends line, checked against `ios`. nil when allowed or unknown;
// otherwise why not.
+ (nullable NSString *)firmwareProblemInDepends:(nullable NSString *)depends ios:(nullable NSString *)ios;

+ (NSString *)titleForAuthenticity:(HCGAuthenticity)authenticity;
+ (NSString *)titleForDeviceEvidence:(HCGDeviceEvidence)evidence;
@end

NS_ASSUME_NONNULL_END
