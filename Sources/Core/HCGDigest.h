#import <Foundation/Foundation.h>
#if defined(__APPLE__)
#include <CommonCrypto/CommonDigest.h>
#endif

NS_ASSUME_NONNULL_BEGIN

// SHA-1 (OpenPGP v4 fingerprints only; never accepted as a signature digest), SHA-256 and SHA-512. Streaming
// contexts hash files without loading them whole.
//
// On Apple platforms (the iPhone builds) every digest comes from CommonCrypto, Apple's audited implementation. The
// portable C implementation (FIPS 180-4) is used only where CommonCrypto does not exist (the Linux host tests); it is
// also exported as HCGPortableDigest so the Simulator tests can cross-check both against the same vectors.
typedef NS_ENUM(NSInteger, HCGDigestAlgorithm) {
    HCGDigestAlgorithmSHA1 = 1,
    HCGDigestAlgorithmSHA256 = 2,
    HCGDigestAlgorithmSHA512 = 3,
};

typedef struct {
    HCGDigestAlgorithm algorithm;
    uint64_t length;          // bytes hashed (SHA-512's 128-bit length never exceeds 2^64 here)
    uint32_t h32[8];
    uint64_t h64[8];
    uint8_t block[128];
    size_t used;
#if defined(__APPLE__)
    union {
        CC_SHA1_CTX sha1;
        CC_SHA256_CTX sha256;
        CC_SHA512_CTX sha512;
    } cc;
#endif
} HCGDigestContext;

// "CommonCrypto" on Apple platforms, "portable" elsewhere.
FOUNDATION_EXPORT NSString *HCGDigestImplementationName(void);
// The portable implementation, always compiled (for cross-checks).
FOUNDATION_EXPORT NSData *HCGPortableDigest(NSData *data, HCGDigestAlgorithm algorithm);

FOUNDATION_EXPORT void HCGDigestInit(HCGDigestContext *context, HCGDigestAlgorithm algorithm);
FOUNDATION_EXPORT void HCGDigestUpdate(HCGDigestContext *context, const void *bytes, size_t length);
// Writes HCGDigestLength(algorithm) bytes.
FOUNDATION_EXPORT void HCGDigestFinal(HCGDigestContext *context, uint8_t *out);
FOUNDATION_EXPORT size_t HCGDigestLength(HCGDigestAlgorithm algorithm);

@interface HCGDigest : NSObject
+ (NSData *)digestOfData:(NSData *)data algorithm:(HCGDigestAlgorithm)algorithm;
+ (NSString *)hexDigestOfData:(NSData *)data algorithm:(HCGDigestAlgorithm)algorithm;
// Streams the file; nil when it cannot be read. `size` receives the bytes read.
+ (nullable NSString *)hexDigestOfFileAtPath:(NSString *)path algorithm:(HCGDigestAlgorithm)algorithm size:(nullable unsigned long long *)size;
+ (NSString *)hexStringFromData:(NSData *)data;
// Constant-time comparison of two lowercase/uppercase hex strings of equal length.
+ (BOOL)hexString:(nullable NSString *)a equalsHexString:(nullable NSString *)b;
@end

NS_ASSUME_NONNULL_END
