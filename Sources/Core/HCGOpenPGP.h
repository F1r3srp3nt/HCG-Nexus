#import <Foundation/Foundation.h>
#import "HCGDigest.h"

NS_ASSUME_NONNULL_BEGIN

// A read-only OpenPGP (RFC 4880) verifier for APT repository metadata, matching HCG Repo's signing
// (HCG-repo docs/SIGNING.md): an RSA primary key with an RSA signing subkey, Release.gpg (detached, binary mode) and
// InRelease (cleartext, text mode), SHA-512 digests.
//
// Scope, deliberately narrow:
//   * v4 keys and signatures; RSA (algorithms 1 and 3) only. EdDSA, ECDSA, DSA and v5/v6 packets are reported as
//     Unsupported, never as good.
//   * Digests: SHA-256 and SHA-512. SHA-1 and MD5 are refused as weak; others are unsupported.
//   * A subkey is used only with a valid binding signature from the primary key and, for signing subkeys, a valid
//     back-signature (primary key binding) from the subkey itself. Revocations from the primary are honoured.
//   * Expiry is checked at the signature's creation time and now (a signature from an expired key reports Expired).
//   * Verification only: no private key, no encryption, no key generation, nothing written.
// The RSA arithmetic and digests are portable C (HCGDigest, an internal big-number routine), host-tested against
// signatures made by GnuPG (Tests/Host/Fixtures/trust).

typedef NS_ENUM(NSInteger, HCGPGPStatus) {
    HCGPGPStatusGood = 0,            // valid signature by the given certificate, key valid now
    HCGPGPStatusBad = 1,             // the signature does not match the data
    HCGPGPStatusUnknownSigner = 2,   // signed by a key that is not in the given certificate
    HCGPGPStatusWeakDigest = 3,      // SHA-1 / MD5
    HCGPGPStatusUnsupported = 4,     // algorithm, packet version or digest this verifier does not handle
    HCGPGPStatusKeyExpired = 5,      // the signing key or its primary key has expired (now or at signing time)
    HCGPGPStatusSignatureExpired = 6,
    HCGPGPStatusKeyRevoked = 7,
    HCGPGPStatusMalformed = 8,       // not parseable, or data outside the signed message
    HCGPGPStatusNoSignature = 9,     // no signature was supplied
};

@interface HCGPGPKey : NSObject {
    NSString *_fingerprint;
    NSString *_keyID;
    NSInteger _algorithm;
    NSUInteger _bits;
    NSDate *_created;
    NSDate *_expires;
    BOOL _canSign;
    BOOL _canCertify;
    BOOL _isSubkey;
    BOOL _revoked;
    BOOL _bound;
    NSData *_packetBody;
    NSData *_modulus;
    NSData *_exponent;
}
@property (nonatomic, copy) NSString *fingerprint;   // 40 uppercase hex digits (v4: SHA-1 of the key packet)
@property (nonatomic, copy) NSString *keyID;         // last 16 hex digits
@property (nonatomic) NSInteger algorithm;           // RFC 4880 public-key algorithm id
@property (nonatomic) NSUInteger bits;               // RSA modulus size; 0 for other algorithms
@property (nonatomic, copy) NSDate *created;
@property (nonatomic, copy, nullable) NSDate *expires;
@property (nonatomic) BOOL canSign;
@property (nonatomic) BOOL canCertify;
@property (nonatomic) BOOL isSubkey;
@property (nonatomic) BOOL revoked;
@property (nonatomic) BOOL bound;                    // primary: has a valid self-signature; subkey: valid binding (+ back-signature when signing)
@property (nonatomic, copy) NSData *packetBody;
@property (nonatomic, copy, nullable) NSData *modulus;
@property (nonatomic, copy, nullable) NSData *exponent;
@property (nonatomic, readonly) NSString *algorithmName;   // "RSA", "EdDSA", ...
@end

// A public key with its subkeys, as exported by `gpg --export` (armored or binary).
@interface HCGPGPCertificate : NSObject {
    HCGPGPKey *_primary;
    NSArray *_subkeys;
    NSArray *_userIDs;
    NSArray *_problems;
}
@property (nonatomic, strong) HCGPGPKey *primary;
@property (nonatomic, copy) NSArray<HCGPGPKey *> *subkeys;
@property (nonatomic, copy) NSArray<NSString *> *userIDs;
@property (nonatomic, copy) NSArray<NSString *> *problems;  // ignored or invalid parts, in words
// nil when the data holds no usable primary key; `error` explains.
+ (nullable instancetype)certificateWithData:(NSData *)data error:(NSString *_Nullable *_Nullable)error;
// "AC5D 9F79 03CF 8AD2 5747  B80B 3939 DC11 09BE CABF" (GnuPG's display grouping).
+ (NSString *)displayFingerprint:(NSString *)fingerprint;
@end

@interface HCGPGPVerification : NSObject {
    HCGPGPStatus _status;
    NSString *_detail;
    NSString *_signerFingerprint;
    NSString *_signerKeyID;
    NSString *_primaryFingerprint;
    NSString *_digestName;
    NSDate *_signedAt;
    NSData *_signedText;
}
@property (nonatomic) HCGPGPStatus status;
@property (nonatomic, copy) NSString *detail;
@property (nonatomic, copy, nullable) NSString *signerFingerprint;   // the (sub)key that signed
@property (nonatomic, copy, nullable) NSString *signerKeyID;         // from the signature, also for unknown signers
@property (nonatomic, copy, nullable) NSString *primaryFingerprint;  // the certificate the signer belongs to
@property (nonatomic, copy, nullable) NSString *digestName;          // "SHA-512"
@property (nonatomic, copy, nullable) NSDate *signedAt;
@property (nonatomic, copy, nullable) NSData *signedText;            // InRelease: the message, LF line endings
@property (nonatomic, readonly) BOOL good;
@end

// Which code performs the RSA and digest operations: Apple's Security framework and CommonCrypto on Apple platforms;
// the portable C implementation only where those do not exist (Linux host tests).
FOUNDATION_EXPORT NSString *HCGOpenPGPImplementationName(void);
// The portable RSASSA-PKCS1-v1_5 check, always compiled, for cross-checks against the platform implementation.
FOUNDATION_EXPORT BOOL HCGPortableRSAVerify(NSData *modulus, NSData *exponent, NSData *signature, HCGDigestAlgorithm algorithm, NSData *digest);

@interface HCGOpenPGP : NSObject
// Release.gpg against Release (binary-mode, or text-mode with canonical line endings). `now` lets tests fix time.
+ (HCGPGPVerification *)verifyDetachedSignature:(nullable NSData *)signature data:(NSData *)data
                                    certificate:(HCGPGPCertificate *)certificate now:(NSDate *)now;
// InRelease. Only a file that is exactly one signed message is accepted (nothing before or after it).
+ (HCGPGPVerification *)verifyCleartextMessage:(nullable NSData *)message certificate:(HCGPGPCertificate *)certificate now:(NSDate *)now;
// The text of a cleartext message without verifying it (for showing what an untrusted InRelease says), or nil.
+ (nullable NSData *)cleartextBodyOfMessage:(nullable NSData *)message;
// Armor → binary (checks the CRC-24 when present). Binary input is returned unchanged.
+ (nullable NSData *)dearmor:(NSData *)data;
+ (NSString *)titleForStatus:(HCGPGPStatus)status;
@end

NS_ASSUME_NONNULL_END
