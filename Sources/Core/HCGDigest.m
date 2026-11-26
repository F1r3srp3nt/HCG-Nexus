#import "HCGDigest.h"
#include <string.h>
#include <stdio.h>

#define ROR32(x, n) (((x) >> (n)) | ((x) << (32 - (n))))
#define ROL32(x, n) (((x) << (n)) | ((x) >> (32 - (n))))
#define ROR64(x, n) (((x) >> (n)) | ((x) << (64 - (n))))

static const uint32_t K256[64] = {
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
};

static const uint64_t K512[80] = {
    0x428a2f98d728ae22ULL, 0x7137449123ef65cdULL, 0xb5c0fbcfec4d3b2fULL, 0xe9b5dba58189dbbcULL, 0x3956c25bf348b538ULL,
    0x59f111f1b605d019ULL, 0x923f82a4af194f9bULL, 0xab1c5ed5da6d8118ULL, 0xd807aa98a3030242ULL, 0x12835b0145706fbeULL,
    0x243185be4ee4b28cULL, 0x550c7dc3d5ffb4e2ULL, 0x72be5d74f27b896fULL, 0x80deb1fe3b1696b1ULL, 0x9bdc06a725c71235ULL,
    0xc19bf174cf692694ULL, 0xe49b69c19ef14ad2ULL, 0xefbe4786384f25e3ULL, 0x0fc19dc68b8cd5b5ULL, 0x240ca1cc77ac9c65ULL,
    0x2de92c6f592b0275ULL, 0x4a7484aa6ea6e483ULL, 0x5cb0a9dcbd41fbd4ULL, 0x76f988da831153b5ULL, 0x983e5152ee66dfabULL,
    0xa831c66d2db43210ULL, 0xb00327c898fb213fULL, 0xbf597fc7beef0ee4ULL, 0xc6e00bf33da88fc2ULL, 0xd5a79147930aa725ULL,
    0x06ca6351e003826fULL, 0x142929670a0e6e70ULL, 0x27b70a8546d22ffcULL, 0x2e1b21385c26c926ULL, 0x4d2c6dfc5ac42aedULL,
    0x53380d139d95b3dfULL, 0x650a73548baf63deULL, 0x766a0abb3c77b2a8ULL, 0x81c2c92e47edaee6ULL, 0x92722c851482353bULL,
    0xa2bfe8a14cf10364ULL, 0xa81a664bbc423001ULL, 0xc24b8b70d0f89791ULL, 0xc76c51a30654be30ULL, 0xd192e819d6ef5218ULL,
    0xd69906245565a910ULL, 0xf40e35855771202aULL, 0x106aa07032bbd1b8ULL, 0x19a4c116b8d2d0c8ULL, 0x1e376c085141ab53ULL,
    0x2748774cdf8eeb99ULL, 0x34b0bcb5e19b48a8ULL, 0x391c0cb3c5c95a63ULL, 0x4ed8aa4ae3418acbULL, 0x5b9cca4f7763e373ULL,
    0x682e6ff3d6b2b8a3ULL, 0x748f82ee5defb2fcULL, 0x78a5636f43172f60ULL, 0x84c87814a1f0ab72ULL, 0x8cc702081a6439ecULL,
    0x90befffa23631e28ULL, 0xa4506cebde82bde9ULL, 0xbef9a3f7b2c67915ULL, 0xc67178f2e372532bULL, 0xca273eceea26619cULL,
    0xd186b8c721c0c207ULL, 0xeada7dd6cde0eb1eULL, 0xf57d4f7fee6ed178ULL, 0x06f067aa72176fbaULL, 0x0a637dc5a2c898a6ULL,
    0x113f9804bef90daeULL, 0x1b710b35131c471bULL, 0x28db77f523047d84ULL, 0x32caab7b40c72493ULL, 0x3c9ebe0a15c9bebcULL,
    0x431d67c49c100d4cULL, 0x4cc5d4becb3e42b6ULL, 0x597f299cfc657e2aULL, 0x5fcb6fab3ad6faecULL, 0x6c44198c4a475817ULL,
};

static uint32_t BE32(const uint8_t *p) {
    return ((uint32_t)p[0] << 24) | ((uint32_t)p[1] << 16) | ((uint32_t)p[2] << 8) | (uint32_t)p[3];
}

static uint64_t BE64(const uint8_t *p) {
    return ((uint64_t)BE32(p) << 32) | (uint64_t)BE32(p + 4);
}

static void SHA1Block(HCGDigestContext *c, const uint8_t *p) {
    uint32_t w[80], a = c->h32[0], b = c->h32[1], cc = c->h32[2], d = c->h32[3], e = c->h32[4];
    int i;
    for (i = 0; i < 16; i++) w[i] = BE32(p + 4 * i);
    for (i = 16; i < 80; i++) w[i] = ROL32(w[i - 3] ^ w[i - 8] ^ w[i - 14] ^ w[i - 16], 1);
    for (i = 0; i < 80; i++) {
        uint32_t f, k;
        if (i < 20) { f = (b & cc) | (~b & d); k = 0x5a827999; }
        else if (i < 40) { f = b ^ cc ^ d; k = 0x6ed9eba1; }
        else if (i < 60) { f = (b & cc) | (b & d) | (cc & d); k = 0x8f1bbcdc; }
        else { f = b ^ cc ^ d; k = 0xca62c1d6; }
        uint32_t t = ROL32(a, 5) + f + e + k + w[i];
        e = d; d = cc; cc = ROL32(b, 30); b = a; a = t;
    }
    c->h32[0] += a; c->h32[1] += b; c->h32[2] += cc; c->h32[3] += d; c->h32[4] += e;
}

static void SHA256Block(HCGDigestContext *c, const uint8_t *p) {
    uint32_t w[64], s[8];
    int i;
    for (i = 0; i < 16; i++) w[i] = BE32(p + 4 * i);
    for (i = 16; i < 64; i++) {
        uint32_t s0 = ROR32(w[i - 15], 7) ^ ROR32(w[i - 15], 18) ^ (w[i - 15] >> 3);
        uint32_t s1 = ROR32(w[i - 2], 17) ^ ROR32(w[i - 2], 19) ^ (w[i - 2] >> 10);
        w[i] = w[i - 16] + s0 + w[i - 7] + s1;
    }
    for (i = 0; i < 8; i++) s[i] = c->h32[i];
    for (i = 0; i < 64; i++) {
        uint32_t S1 = ROR32(s[4], 6) ^ ROR32(s[4], 11) ^ ROR32(s[4], 25);
        uint32_t ch = (s[4] & s[5]) ^ (~s[4] & s[6]);
        uint32_t t1 = s[7] + S1 + ch + K256[i] + w[i];
        uint32_t S0 = ROR32(s[0], 2) ^ ROR32(s[0], 13) ^ ROR32(s[0], 22);
        uint32_t maj = (s[0] & s[1]) ^ (s[0] & s[2]) ^ (s[1] & s[2]);
        uint32_t t2 = S0 + maj;
        s[7] = s[6]; s[6] = s[5]; s[5] = s[4]; s[4] = s[3] + t1; s[3] = s[2]; s[2] = s[1]; s[1] = s[0]; s[0] = t1 + t2;
    }
    for (i = 0; i < 8; i++) c->h32[i] += s[i];
}

static void SHA512Block(HCGDigestContext *c, const uint8_t *p) {
    uint64_t w[80], s[8];
    int i;
    for (i = 0; i < 16; i++) w[i] = BE64(p + 8 * i);
    for (i = 16; i < 80; i++) {
        uint64_t s0 = ROR64(w[i - 15], 1) ^ ROR64(w[i - 15], 8) ^ (w[i - 15] >> 7);
        uint64_t s1 = ROR64(w[i - 2], 19) ^ ROR64(w[i - 2], 61) ^ (w[i - 2] >> 6);
        w[i] = w[i - 16] + s0 + w[i - 7] + s1;
    }
    for (i = 0; i < 8; i++) s[i] = c->h64[i];
    for (i = 0; i < 80; i++) {
        uint64_t S1 = ROR64(s[4], 14) ^ ROR64(s[4], 18) ^ ROR64(s[4], 41);
        uint64_t ch = (s[4] & s[5]) ^ (~s[4] & s[6]);
        uint64_t t1 = s[7] + S1 + ch + K512[i] + w[i];
        uint64_t S0 = ROR64(s[0], 28) ^ ROR64(s[0], 34) ^ ROR64(s[0], 39);
        uint64_t maj = (s[0] & s[1]) ^ (s[0] & s[2]) ^ (s[1] & s[2]);
        uint64_t t2 = S0 + maj;
        s[7] = s[6]; s[6] = s[5]; s[5] = s[4]; s[4] = s[3] + t1; s[3] = s[2]; s[2] = s[1]; s[1] = s[0]; s[0] = t1 + t2;
    }
    for (i = 0; i < 8; i++) c->h64[i] += s[i];
}

static size_t BlockSize(HCGDigestAlgorithm a) {
    return a == HCGDigestAlgorithmSHA512 ? 128 : 64;
}

size_t HCGDigestLength(HCGDigestAlgorithm a) {
    switch (a) {
        case HCGDigestAlgorithmSHA1: return 20;
        case HCGDigestAlgorithmSHA256: return 32;
        case HCGDigestAlgorithmSHA512: return 64;
    }
    return 0;
}

static void Compress(HCGDigestContext *c, const uint8_t *p) {
    if (c->algorithm == HCGDigestAlgorithmSHA1) SHA1Block(c, p);
    else if (c->algorithm == HCGDigestAlgorithmSHA256) SHA256Block(c, p);
    else SHA512Block(c, p);
}

static void PortableInit(HCGDigestContext *c, HCGDigestAlgorithm algorithm) {
    memset(c, 0, sizeof(*c));
    c->algorithm = algorithm;
    if (algorithm == HCGDigestAlgorithmSHA1) {
        uint32_t iv[5] = { 0x67452301, 0xefcdab89, 0x98badcfe, 0x10325476, 0xc3d2e1f0 };
        memcpy(c->h32, iv, sizeof(iv));
    } else if (algorithm == HCGDigestAlgorithmSHA256) {
        uint32_t iv[8] = { 0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19 };
        memcpy(c->h32, iv, sizeof(iv));
    } else {
        uint64_t iv[8] = { 0x6a09e667f3bcc908ULL, 0xbb67ae8584caa73bULL, 0x3c6ef372fe94f82bULL, 0xa54ff53a5f1d36f1ULL,
                           0x510e527fade682d1ULL, 0x9b05688c2b3e6c1fULL, 0x1f83d9abfb41bd6bULL, 0x5be0cd19137e2179ULL };
        memcpy(c->h64, iv, sizeof(iv));
    }
}

static void PortableUpdate(HCGDigestContext *c, const void *bytes, size_t length) {
    const uint8_t *p = (const uint8_t *)bytes;
    size_t bs = BlockSize(c->algorithm);
    c->length += length;
    while (length > 0) {
        size_t take = bs - c->used;
        if (take > length) take = length;
        memcpy(c->block + c->used, p, take);
        c->used += take;
        p += take;
        length -= take;
        if (c->used == bs) {
            Compress(c, c->block);
            c->used = 0;
        }
    }
}

static void PortableFinal(HCGDigestContext *c, uint8_t *out) {
    size_t bs = BlockSize(c->algorithm), lenBytes = c->algorithm == HCGDigestAlgorithmSHA512 ? 16 : 8;
    uint64_t bits = c->length * 8;
    c->block[c->used++] = 0x80;
    if (c->used > bs - lenBytes) {
        memset(c->block + c->used, 0, bs - c->used);
        Compress(c, c->block);
        c->used = 0;
    }
    memset(c->block + c->used, 0, bs - c->used);
    int i;
    for (i = 0; i < 8; i++) c->block[bs - 1 - i] = (uint8_t)(bits >> (8 * i));
    Compress(c, c->block);
    size_t n = HCGDigestLength(c->algorithm);
    if (c->algorithm == HCGDigestAlgorithmSHA512) {
        for (i = 0; i < 8; i++) {
            int j;
            for (j = 0; j < 8; j++) out[8 * i + j] = (uint8_t)(c->h64[i] >> (56 - 8 * j));
        }
    } else {
        for (i = 0; i < (int)(n / 4); i++) {
            out[4 * i] = (uint8_t)(c->h32[i] >> 24);
            out[4 * i + 1] = (uint8_t)(c->h32[i] >> 16);
            out[4 * i + 2] = (uint8_t)(c->h32[i] >> 8);
            out[4 * i + 3] = (uint8_t)c->h32[i];
        }
    }
}

NSString *HCGDigestImplementationName(void) {
#if defined(__APPLE__)
    return @"CommonCrypto";
#else
    return @"portable";
#endif
}

NSData *HCGPortableDigest(NSData *data, HCGDigestAlgorithm algorithm) {
    HCGDigestContext c;
    uint8_t out[64];
    PortableInit(&c, algorithm);
    PortableUpdate(&c, data.bytes, data.length);
    PortableFinal(&c, out);
    return [NSData dataWithBytes:out length:HCGDigestLength(algorithm)];
}

void HCGDigestInit(HCGDigestContext *c, HCGDigestAlgorithm algorithm) {
#if defined(__APPLE__)
    memset(c, 0, sizeof(*c));
    c->algorithm = algorithm;
    if (algorithm == HCGDigestAlgorithmSHA1) CC_SHA1_Init(&c->cc.sha1);
    else if (algorithm == HCGDigestAlgorithmSHA256) CC_SHA256_Init(&c->cc.sha256);
    else CC_SHA512_Init(&c->cc.sha512);
#else
    PortableInit(c, algorithm);
#endif
}

void HCGDigestUpdate(HCGDigestContext *c, const void *bytes, size_t length) {
#if defined(__APPLE__)
    const uint8_t *p = (const uint8_t *)bytes;
    while (length > 0) { // CC_LONG is 32-bit
        CC_LONG n = length > 0x40000000 ? 0x40000000 : (CC_LONG)length;
        if (c->algorithm == HCGDigestAlgorithmSHA1) CC_SHA1_Update(&c->cc.sha1, p, n);
        else if (c->algorithm == HCGDigestAlgorithmSHA256) CC_SHA256_Update(&c->cc.sha256, p, n);
        else CC_SHA512_Update(&c->cc.sha512, p, n);
        p += n;
        length -= n;
    }
#else
    PortableUpdate(c, bytes, length);
#endif
}

void HCGDigestFinal(HCGDigestContext *c, uint8_t *out) {
#if defined(__APPLE__)
    if (c->algorithm == HCGDigestAlgorithmSHA1) CC_SHA1_Final(out, &c->cc.sha1);
    else if (c->algorithm == HCGDigestAlgorithmSHA256) CC_SHA256_Final(out, &c->cc.sha256);
    else CC_SHA512_Final(out, &c->cc.sha512);
#else
    PortableFinal(c, out);
#endif
}

@implementation HCGDigest

+ (NSData *)digestOfData:(NSData *)data algorithm:(HCGDigestAlgorithm)algorithm {
    HCGDigestContext c;
    uint8_t out[64];
    HCGDigestInit(&c, algorithm);
    HCGDigestUpdate(&c, data.bytes, data.length);
    HCGDigestFinal(&c, out);
    return [NSData dataWithBytes:out length:HCGDigestLength(algorithm)];
}

+ (NSString *)hexStringFromData:(NSData *)data {
    const uint8_t *p = (const uint8_t *)data.bytes;
    NSMutableString *s = [NSMutableString stringWithCapacity:data.length * 2];
    NSUInteger i;
    for (i = 0; i < data.length; i++) [s appendFormat:@"%02x", p[i]];
    return s;
}

+ (NSString *)hexDigestOfData:(NSData *)data algorithm:(HCGDigestAlgorithm)algorithm {
    return [self hexStringFromData:[self digestOfData:data algorithm:algorithm]];
}

+ (NSString *)hexDigestOfFileAtPath:(NSString *)path algorithm:(HCGDigestAlgorithm)algorithm size:(unsigned long long *)size {
    FILE *f = fopen([path fileSystemRepresentation], "rb");
    if (!f) return nil;
    HCGDigestContext c;
    HCGDigestInit(&c, algorithm);
    uint8_t buffer[65536];
    size_t n;
    unsigned long long total = 0;
    while ((n = fread(buffer, 1, sizeof(buffer), f)) > 0) {
        HCGDigestUpdate(&c, buffer, n);
        total += n;
    }
    BOOL failed = ferror(f) != 0;
    fclose(f);
    if (failed) return nil;
    uint8_t out[64];
    HCGDigestFinal(&c, out);
    if (size) *size = total;
    return [self hexStringFromData:[NSData dataWithBytes:out length:HCGDigestLength(algorithm)]];
}

+ (BOOL)hexString:(NSString *)a equalsHexString:(NSString *)b {
    if (![a isKindOfClass:[NSString class]] || ![b isKindOfClass:[NSString class]] || a.length != b.length || a.length == 0) return NO;
    NSString *la = [a lowercaseString], *lb = [b lowercaseString];
    unichar diff = 0;
    NSUInteger i;
    for (i = 0; i < la.length; i++) diff |= [la characterAtIndex:i] ^ [lb characterAtIndex:i];
    return diff == 0;
}

@end
