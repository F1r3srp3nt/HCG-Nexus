#import "HCGOpenPGP.h"
#import "HCGDigest.h"
#if defined(__APPLE__)
#import <Security/Security.h>
#endif
#include <stdlib.h>
#include <string.h>

#pragma mark - Big numbers (verification only: public operands, no secrets)

// Little-endian 32-bit limbs.
typedef struct {
    uint32_t *d;
    int n;
} HCGBN;

static void BNFree(HCGBN *a) {
    free(a->d);
    a->d = NULL;
    a->n = 0;
}

static void BNTrim(HCGBN *a) {
    while (a->n > 0 && a->d[a->n - 1] == 0) a->n--;
}

static BOOL BNFromBytes(HCGBN *a, const uint8_t *p, size_t len) {
    int limbs = (int)((len + 3) / 4);
    a->d = (uint32_t *)calloc((size_t)(limbs > 0 ? limbs : 1), sizeof(uint32_t));
    if (!a->d) return NO;
    a->n = limbs;
    size_t i;
    for (i = 0; i < len; i++) {
        size_t bytePos = len - 1 - i; // i-th least significant byte
        a->d[i / 4] |= (uint32_t)p[bytePos] << (8 * (i % 4));
    }
    BNTrim(a);
    return YES;
}

static int BNCompare(const HCGBN *a, const HCGBN *b) {
    if (a->n != b->n) return a->n < b->n ? -1 : 1;
    int i;
    for (i = a->n - 1; i >= 0; i--) {
        if (a->d[i] != b->d[i]) return a->d[i] < b->d[i] ? -1 : 1;
    }
    return 0;
}

static int NLZ(uint32_t x) {
    int n = 0;
    if (x == 0) return 32;
    while (!(x & 0x80000000u)) { x <<= 1; n++; }
    return n;
}

// Remainder of u (m limbs) by v (n limbs, v[n-1] != 0, m >= n) into r (n limbs). Knuth D (Hacker's Delight divmnu).
static BOOL DivMod(const uint32_t *u, int m, const uint32_t *v, int n, uint32_t *r) {
    const uint64_t b = 4294967296ULL;
    if (m < n || n <= 0 || v[n - 1] == 0) return NO;
    int i, j;
    if (n == 1) {
        uint64_t k = 0;
        for (j = m - 1; j >= 0; j--) k = ((k << 32) + u[j]) % v[0];
        r[0] = (uint32_t)k;
        return YES;
    }
    int s = NLZ(v[n - 1]);
    uint32_t *vn = (uint32_t *)malloc(sizeof(uint32_t) * (size_t)n);
    uint32_t *un = (uint32_t *)malloc(sizeof(uint32_t) * (size_t)(m + 1));
    if (!vn || !un) { free(vn); free(un); return NO; }
    for (i = n - 1; i > 0; i--) vn[i] = (v[i] << s) | (uint32_t)((uint64_t)v[i - 1] >> (32 - s));
    vn[0] = v[0] << s;
    un[m] = (uint32_t)((uint64_t)u[m - 1] >> (32 - s));
    for (i = m - 1; i > 0; i--) un[i] = (u[i] << s) | (uint32_t)((uint64_t)u[i - 1] >> (32 - s));
    un[0] = u[0] << s;
    for (j = m - n; j >= 0; j--) {
        uint64_t num = ((uint64_t)un[j + n] << 32) | un[j + n - 1];
        uint64_t qhat = num / vn[n - 1];
        uint64_t rhat = num - qhat * vn[n - 1];
        while (qhat >= b || qhat * vn[n - 2] > ((rhat << 32) | un[j + n - 2])) {
            qhat--;
            rhat += vn[n - 1];
            if (rhat >= b) break;
        }
        int64_t k = 0, t;
        for (i = 0; i < n; i++) {
            uint64_t p = qhat * vn[i];
            t = (int64_t)un[i + j] - k - (int64_t)(p & 0xFFFFFFFFULL);
            un[i + j] = (uint32_t)t;
            k = (int64_t)(p >> 32) - (t >> 32);
        }
        t = (int64_t)un[j + n] - k;
        un[j + n] = (uint32_t)t;
        if (t < 0) {
            uint64_t c = 0;
            for (i = 0; i < n; i++) {
                uint64_t sum = (uint64_t)un[i + j] + vn[i] + c;
                un[i + j] = (uint32_t)sum;
                c = sum >> 32;
            }
            un[j + n] = (uint32_t)((uint64_t)un[j + n] + c);
        }
    }
    for (i = 0; i < n - 1; i++) r[i] = (un[i] >> s) | (uint32_t)((uint64_t)un[i + 1] << (32 - s));
    r[n - 1] = un[n - 1] >> s;
    free(vn);
    free(un);
    return YES;
}

// out = a * b mod m (all n limbs; a, b < m).
static BOOL MulMod(const uint32_t *a, const uint32_t *b, const uint32_t *m, int n, uint32_t *out) {
    uint32_t *prod = (uint32_t *)calloc((size_t)(2 * n), sizeof(uint32_t));
    if (!prod) return NO;
    int i, j;
    for (i = 0; i < n; i++) {
        uint64_t c = 0;
        for (j = 0; j < n; j++) {
            uint64_t t = (uint64_t)a[i] * b[j] + prod[i + j] + c;
            prod[i + j] = (uint32_t)t;
            c = t >> 32;
        }
        prod[i + n] = (uint32_t)c;
    }
    BOOL ok = DivMod(prod, 2 * n, m, n, out);
    free(prod);
    return ok;
}

// base^exp mod mod, written big-endian into out (modLen bytes). base < mod required.
static BOOL ModExp(const HCGBN *base, const HCGBN *exp, const HCGBN *mod, uint8_t *out, size_t modLen) {
    int n = mod->n;
    if (n == 0 || BNCompare(base, mod) >= 0) return NO;
    uint32_t *x = (uint32_t *)calloc((size_t)n, sizeof(uint32_t));
    uint32_t *r = (uint32_t *)calloc((size_t)n, sizeof(uint32_t));
    uint32_t *tmp = (uint32_t *)calloc((size_t)n, sizeof(uint32_t));
    if (!x || !r || !tmp) { free(x); free(r); free(tmp); return NO; }
    int i;
    for (i = 0; i < base->n; i++) x[i] = base->d[i];
    r[0] = 1;
    BOOL ok = YES;
    int bit;
    for (i = exp->n - 1; i >= 0 && ok; i--) {
        for (bit = 31; bit >= 0 && ok; bit--) {
            ok = MulMod(r, r, mod->d, n, tmp);
            memcpy(r, tmp, sizeof(uint32_t) * (size_t)n);
            if (ok && ((exp->d[i] >> bit) & 1u)) {
                ok = MulMod(r, x, mod->d, n, tmp);
                memcpy(r, tmp, sizeof(uint32_t) * (size_t)n);
            }
        }
    }
    if (ok) {
        memset(out, 0, modLen);
        size_t k;
        for (k = 0; k < modLen && k / 4 < (size_t)n; k++) {
            out[modLen - 1 - k] = (uint8_t)(r[k / 4] >> (8 * (k % 4)));
        }
    }
    free(x);
    free(r);
    free(tmp);
    return ok;
}

static const uint8_t kPrefixSHA256[] = { 0x30, 0x31, 0x30, 0x0d, 0x06, 0x09, 0x60, 0x86, 0x48, 0x01, 0x65, 0x03, 0x04, 0x02, 0x01, 0x05, 0x00, 0x04, 0x20 };
static const uint8_t kPrefixSHA512[] = { 0x30, 0x51, 0x30, 0x0d, 0x06, 0x09, 0x60, 0x86, 0x48, 0x01, 0x65, 0x03, 0x04, 0x02, 0x03, 0x05, 0x00, 0x04, 0x40 };

// RSASSA-PKCS1-v1_5 verification of `digest` (already computed) with modulus/exponent: the portable implementation,
// used where Apple's Security framework does not exist (the Linux host tests).
static BOOL PortableRSAVerify(NSData *modulus, NSData *exponent, NSData *signature, HCGDigestAlgorithm algorithm, NSData *digest) {
    const uint8_t *prefix = algorithm == HCGDigestAlgorithmSHA512 ? kPrefixSHA512 : kPrefixSHA256;
    size_t prefixLen = algorithm == HCGDigestAlgorithmSHA512 ? sizeof(kPrefixSHA512) : sizeof(kPrefixSHA256);
    // Strip leading zero bytes of the modulus for its true length.
    const uint8_t *mp = (const uint8_t *)modulus.bytes;
    size_t ml = modulus.length;
    while (ml > 0 && *mp == 0) { mp++; ml--; }
    if (ml < prefixLen + digest.length + 11 || signature.length > ml) return NO;
    HCGBN n = { NULL, 0 }, e = { NULL, 0 }, s = { NULL, 0 };
    BOOL ok = BNFromBytes(&n, mp, ml) && BNFromBytes(&e, exponent.bytes, exponent.length) &&
              BNFromBytes(&s, signature.bytes, signature.length);
    uint8_t *em = (uint8_t *)calloc(ml, 1);
    if (ok && em && e.n > 0 && ModExp(&s, &e, &n, em, ml)) {
        // 0x00 0x01 FF..FF 0x00 DigestInfo digest
        size_t padLen = ml - 3 - prefixLen - digest.length;
        uint8_t diff = (uint8_t)(em[0] ^ 0x00) | (uint8_t)(em[1] ^ 0x01);
        size_t i;
        for (i = 0; i < padLen; i++) diff |= em[2 + i] ^ 0xFF;
        diff |= em[2 + padLen];
        for (i = 0; i < prefixLen; i++) diff |= em[3 + padLen + i] ^ prefix[i];
        const uint8_t *dg = (const uint8_t *)digest.bytes;
        for (i = 0; i < digest.length; i++) diff |= em[3 + padLen + prefixLen + i] ^ dg[i];
        ok = diff == 0;
    } else {
        ok = NO;
    }
    free(em);
    BNFree(&n);
    BNFree(&e);
    BNFree(&s);
    return ok;
}

#if defined(__APPLE__)
// DER: INTEGER with a leading zero when the high bit is set (big-endian magnitude, leading zeros stripped).
static void AppendDERLength(NSMutableData *out, size_t length) {
    if (length < 128) {
        uint8_t b = (uint8_t)length;
        [out appendBytes:&b length:1];
        return;
    }
    uint8_t bytes[8];
    int n = 0;
    while (length > 0) { bytes[n++] = (uint8_t)(length & 0xFF); length >>= 8; }
    uint8_t first = (uint8_t)(0x80 | n);
    [out appendBytes:&first length:1];
    while (n > 0) [out appendBytes:&bytes[--n] length:1];
}

static NSData *DERInteger(NSData *magnitude) {
    const uint8_t *p = (const uint8_t *)magnitude.bytes;
    size_t len = magnitude.length;
    while (len > 1 && *p == 0) { p++; len--; }
    BOOL pad = len > 0 && (p[0] & 0x80);
    NSMutableData *out = [NSMutableData data];
    uint8_t tag = 0x02, zero = 0;
    [out appendBytes:&tag length:1];
    AppendDERLength(out, len + (pad ? 1 : 0));
    if (pad) [out appendBytes:&zero length:1];
    [out appendBytes:p length:len];
    return out;
}

// The same check through Apple's Security framework: an RSAPublicKey (PKCS#1) built from the OpenPGP modulus and
// exponent, and SecKeyVerifySignature with the digest already computed. The signature is left-padded to the key size.
static BOOL RSAVerify(NSData *modulus, NSData *exponent, NSData *signature, HCGDigestAlgorithm algorithm, NSData *digest) {
    const uint8_t *mp = (const uint8_t *)modulus.bytes;
    size_t ml = modulus.length;
    while (ml > 0 && *mp == 0) { mp++; ml--; }
    if (ml < 128 || signature.length == 0 || signature.length > ml || digest.length != HCGDigestLength(algorithm)) return NO;
    NSMutableData *body = [NSMutableData dataWithData:DERInteger([NSData dataWithBytes:mp length:ml])];
    [body appendData:DERInteger(exponent)];
    NSMutableData *der = [NSMutableData data];
    uint8_t seq = 0x30;
    [der appendBytes:&seq length:1];
    AppendDERLength(der, body.length);
    [der appendData:body];
    NSDictionary *attributes = @{ (__bridge id)kSecAttrKeyType : (__bridge id)kSecAttrKeyTypeRSA,
                                  (__bridge id)kSecAttrKeyClass : (__bridge id)kSecAttrKeyClassPublic,
                                  (__bridge id)kSecAttrKeySizeInBits : @(ml * 8) };
    SecKeyRef key = SecKeyCreateWithData((__bridge CFDataRef)der, (__bridge CFDictionaryRef)attributes, NULL);
    if (!key) return NO;
    NSMutableData *padded = [NSMutableData dataWithLength:ml - signature.length];
    [padded appendData:signature];
    SecKeyAlgorithm alg = algorithm == HCGDigestAlgorithmSHA512 ? kSecKeyAlgorithmRSASignatureDigestPKCS1v15SHA512
                                                                : kSecKeyAlgorithmRSASignatureDigestPKCS1v15SHA256;
    BOOL ok = SecKeyIsAlgorithmSupported(key, kSecKeyOperationTypeVerify, alg) &&
              SecKeyVerifySignature(key, alg, (__bridge CFDataRef)digest, (__bridge CFDataRef)padded, NULL);
    CFRelease(key);
    return ok;
}
#else
static BOOL RSAVerify(NSData *modulus, NSData *exponent, NSData *signature, HCGDigestAlgorithm algorithm, NSData *digest) {
    return PortableRSAVerify(modulus, exponent, signature, algorithm, digest);
}
#endif

NSString *HCGOpenPGPImplementationName(void) {
#if defined(__APPLE__)
    return @"Apple Security framework (RSA) + CommonCrypto (SHA-2)";
#else
    return @"portable C (host tests)";
#endif
}

BOOL HCGPortableRSAVerify(NSData *modulus, NSData *exponent, NSData *signature, HCGDigestAlgorithm algorithm, NSData *digest) {
    return PortableRSAVerify(modulus, exponent, signature, algorithm, digest);
}

#pragma mark - Model

@implementation HCGPGPKey
@synthesize fingerprint = _fingerprint, keyID = _keyID, algorithm = _algorithm, bits = _bits, created = _created,
            expires = _expires, canSign = _canSign, canCertify = _canCertify, isSubkey = _isSubkey, revoked = _revoked,
            bound = _bound, packetBody = _packetBody, modulus = _modulus, exponent = _exponent;

- (NSString *)algorithmName {
    switch (self.algorithm) {
        case 1: case 2: case 3: return @"RSA";
        case 16: return @"ElGamal";
        case 17: return @"DSA";
        case 18: return @"ECDH";
        case 19: return @"ECDSA";
        case 22: return @"EdDSA";
        case 25: return @"X25519";
        case 27: return @"Ed25519";
    }
    return [NSString stringWithFormat:@"algorithm %ld", (long)self.algorithm];
}
@end

@implementation HCGPGPVerification
@synthesize status = _status, detail = _detail, signerFingerprint = _signerFingerprint, signerKeyID = _signerKeyID,
            primaryFingerprint = _primaryFingerprint, digestName = _digestName, signedAt = _signedAt, signedText = _signedText;

- (BOOL)good {
    return self.status == HCGPGPStatusGood;
}
@end

#pragma mark - Packets

typedef struct {
    int tag;
    const uint8_t *body;
    size_t length;
} HCGPacket;

// Reads the packet at *offset; NO at the end or on malformed input.
static BOOL NextPacket(const uint8_t *p, size_t len, size_t *offset, HCGPacket *out) {
    size_t o = *offset;
    if (o >= len) return NO;
    uint8_t h = p[o++];
    if (!(h & 0x80)) return NO;
    size_t bodyLen = 0;
    if (h & 0x40) {
        out->tag = h & 0x3F;
        if (o >= len) return NO;
        uint8_t l1 = p[o++];
        if (l1 < 192) bodyLen = l1;
        else if (l1 < 224) {
            if (o >= len) return NO;
            bodyLen = ((size_t)(l1 - 192) << 8) + p[o++] + 192;
        } else if (l1 == 255) {
            if (o + 4 > len) return NO;
            bodyLen = ((size_t)p[o] << 24) | ((size_t)p[o + 1] << 16) | ((size_t)p[o + 2] << 8) | p[o + 3];
            o += 4;
        } else {
            return NO; // partial body lengths: never used for keys or signatures
        }
    } else {
        out->tag = (h >> 2) & 0x0F;
        int lt = h & 3;
        if (lt == 3) return NO;
        size_t n = lt == 0 ? 1 : (lt == 1 ? 2 : 4), i;
        if (o + n > len) return NO;
        for (i = 0; i < n; i++) bodyLen = (bodyLen << 8) | p[o + i];
        o += n;
    }
    if (bodyLen > len - o) return NO;
    out->body = p + o;
    out->length = bodyLen;
    *offset = o + bodyLen;
    return YES;
}

static uint32_t Be32(const uint8_t *p) {
    return ((uint32_t)p[0] << 24) | ((uint32_t)p[1] << 16) | ((uint32_t)p[2] << 8) | p[3];
}

// MPI at *o: returns its bytes (leading zeros stripped by the encoding) or nil.
static NSData *ReadMPI(const uint8_t *p, size_t len, size_t *o, NSUInteger *bitsOut) {
    if (*o + 2 > len) return nil;
    NSUInteger bits = ((NSUInteger)p[*o] << 8) | p[*o + 1];
    size_t bytes = (bits + 7) / 8;
    *o += 2;
    if (bytes > len - *o || bytes == 0) return nil;
    NSData *d = [NSData dataWithBytes:p + *o length:bytes];
    *o += bytes;
    if (bitsOut) *bitsOut = bits;
    return d;
}

static NSString *Hex(const uint8_t *p, size_t n) {
    NSMutableString *s = [NSMutableString string];
    size_t i;
    for (i = 0; i < n; i++) [s appendFormat:@"%02X", p[i]];
    return s;
}

// Limits that keep an attacker-supplied key file cheap to read (independent review, 26 Nov 2026): every RSA operation
// is bounded by the modulus and exponent sizes, and the number of signatures and subkeys checked is capped.
static const NSUInteger kMinRSABits = 2048;
static const NSUInteger kMaxRSABits = 8192;
static const size_t kMaxExponentBytes = 4;
static const NSUInteger kMaxCertificateBytes = 1024 * 1024;
static const NSUInteger kMaxCertificateSignatures = 128;
static const NSUInteger kMaxSubkeys = 32;

static HCGPGPKey *ParseKey(HCGPacket packet, BOOL subkey, NSString **problem) {
    if (packet.length < 6 || packet.body[0] != 4) return nil; // v4 only
    if (packet.length > 0xFFFF) { if (problem) *problem = @"The key packet is too large."; return nil; }
    HCGPGPKey *key = [[HCGPGPKey alloc] init];
    key.isSubkey = subkey;
    key.created = [NSDate dateWithTimeIntervalSince1970:Be32(packet.body + 1)];
    key.algorithm = packet.body[5];
    key.packetBody = [NSData dataWithBytes:packet.body length:packet.length];
    // Fingerprint: SHA-1(0x99, 2-byte length, body).
    HCGDigestContext c;
    uint8_t header[3] = { 0x99, (uint8_t)(packet.length >> 8), (uint8_t)packet.length };
    uint8_t fp[20];
    HCGDigestInit(&c, HCGDigestAlgorithmSHA1);
    HCGDigestUpdate(&c, header, 3);
    HCGDigestUpdate(&c, packet.body, packet.length);
    HCGDigestFinal(&c, fp);
    key.fingerprint = Hex(fp, 20);
    key.keyID = Hex(fp + 12, 8);
    if (key.algorithm == 1 || key.algorithm == 2 || key.algorithm == 3) {
        size_t o = 6;
        NSUInteger bits = 0;
        key.modulus = ReadMPI(packet.body, packet.length, &o, &bits);
        key.exponent = ReadMPI(packet.body, packet.length, &o, NULL);
        key.bits = bits;
        if (!key.modulus || !key.exponent) return nil;
        if (bits < kMinRSABits || bits > kMaxRSABits) {
            if (problem) *problem = [NSString stringWithFormat:@"RSA keys of %lu bits are not accepted (2048 to 8192 bits are).", (unsigned long)bits];
            return nil;
        }
        const uint8_t *ex = (const uint8_t *)key.exponent.bytes;
        if (key.exponent.length > kMaxExponentBytes || !(ex[key.exponent.length - 1] & 1) || (key.exponent.length == 1 && ex[0] < 3)) {
            if (problem) *problem = @"The RSA public exponent is not accepted (it must be odd, at least 3 and at most 32 bits).";
            return nil;
        }
    }
    return key;
}

#pragma mark - Signatures

typedef struct {
    int version;
    int type;
    int pubAlgorithm;
    int hashAlgorithm;
    const uint8_t *hashedStart;   // from the version byte
    size_t hashedLength;          // version .. end of hashed subpackets
    uint8_t left16[2];
    const uint8_t *mpi;           // RSA signature value (into the packet), with its length
    size_t mpiLength;
    uint32_t created;
    BOOL hasCreated;
    uint32_t sigExpires;          // seconds after creation, 0 = never
    uint32_t keyExpires;          // seconds after key creation, 0 = never (self-signatures)
    BOOL hasKeyExpires;
    int keyFlags;                 // -1 when absent
    uint8_t issuerFingerprint[20];
    BOOL hasIssuerFingerprint;
    uint8_t issuerKeyID[8];
    BOOL hasIssuerKeyID;
    BOOL unknownCritical;
    const uint8_t *embedded;      // embedded signature (primary key binding) body
    size_t embeddedLength;
} HCGSig;

static BOOL ParseSubpackets(const uint8_t *p, size_t len, BOOL hashed, HCGSig *sig) {
    size_t o = 0;
    while (o < len) {
        size_t sl;
        uint8_t l1 = p[o++];
        if (l1 < 192) sl = l1;
        else if (l1 < 255) {
            if (o >= len) return NO;
            sl = ((size_t)(l1 - 192) << 8) + p[o++] + 192;
        } else {
            if (o + 4 > len) return NO;
            sl = Be32(p + o);
            o += 4;
        }
        if (sl == 0 || sl > len - o) return NO;
        int type = p[o] & 0x7F;
        BOOL critical = (p[o] & 0x80) != 0;
        const uint8_t *d = p + o + 1;
        size_t dl = sl - 1;
        switch (type) {
            case 2: if (hashed && dl == 4) { sig->created = Be32(d); sig->hasCreated = YES; } break;
            case 3: if (hashed && dl == 4) sig->sigExpires = Be32(d); break;
            case 9: if (hashed && dl == 4) { sig->keyExpires = Be32(d); sig->hasKeyExpires = YES; } break;
            case 16: if (dl == 8) { memcpy(sig->issuerKeyID, d, 8); sig->hasIssuerKeyID = YES; } break;
            case 27: if (hashed && dl >= 1) sig->keyFlags = d[0]; break;
            case 32: sig->embedded = d; sig->embeddedLength = dl; break;
            case 33: if (dl == 21 && d[0] == 4) { memcpy(sig->issuerFingerprint, d + 1, 20); sig->hasIssuerFingerprint = YES; } break;
            case 11: case 21: case 22: case 23: case 25: case 30:
                break; // preferences and features: informational, safe to honour by ignoring
            case 4: case 5: case 6: case 7: case 12: case 20: case 24: case 26: case 28: case 29: case 31: case 34: case 35: case 37: case 39:
                // Known but not implemented (trust, regular expressions, revocation keys, notations, policy URLs, ...):
                // when the signer marked one critical, the signature must not be accepted.
                if (critical && hashed) sig->unknownCritical = YES;
                break;
            default:
                if (critical && hashed) sig->unknownCritical = YES;
                break;
        }
        o += sl;
    }
    return YES;
}

static BOOL ParseSignature(const uint8_t *p, size_t len, HCGSig *sig) {
    memset(sig, 0, sizeof(*sig));
    sig->keyFlags = -1;
    if (len < 1) return NO;
    sig->version = p[0];
    if (sig->version != 4) return YES; // reported as unsupported by the caller
    if (len < 6) return NO;
    sig->type = p[1];
    sig->pubAlgorithm = p[2];
    sig->hashAlgorithm = p[3];
    size_t hashedLen = ((size_t)p[4] << 8) | p[5];
    if (6 + hashedLen + 2 > len) return NO;
    if (!ParseSubpackets(p + 6, hashedLen, YES, sig)) return NO;
    sig->hashedStart = p;
    sig->hashedLength = 6 + hashedLen;
    size_t o = 6 + hashedLen;
    size_t unhashedLen = ((size_t)p[o] << 8) | p[o + 1];
    o += 2;
    if (o + unhashedLen + 2 > len) return NO;
    if (!ParseSubpackets(p + o, unhashedLen, NO, sig)) return NO;
    o += unhashedLen;
    sig->left16[0] = p[o];
    sig->left16[1] = p[o + 1];
    o += 2;
    if (sig->pubAlgorithm == 1 || sig->pubAlgorithm == 3) {
        if (o + 2 > len) return NO;
        size_t bytes = ((((size_t)p[o] << 8) | p[o + 1]) + 7) / 8;
        o += 2;
        if (bytes == 0 || bytes > len - o) return NO;
        sig->mpi = p + o;
        sig->mpiLength = bytes;
    }
    return YES;
}

static HCGDigestAlgorithm DigestFor(int hashAlgorithm, BOOL *weak) {
    *weak = NO;
    if (hashAlgorithm == 8) return HCGDigestAlgorithmSHA256;
    if (hashAlgorithm == 10) return HCGDigestAlgorithmSHA512;
    if (hashAlgorithm == 1 || hashAlgorithm == 2 || hashAlgorithm == 3) *weak = YES;
    return (HCGDigestAlgorithm)0;
}

static NSString *DigestName(int hashAlgorithm) {
    switch (hashAlgorithm) {
        case 1: return @"MD5";
        case 2: return @"SHA-1";
        case 3: return @"RIPEMD-160";
        case 8: return @"SHA-256";
        case 9: return @"SHA-384";
        case 10: return @"SHA-512";
        case 11: return @"SHA-224";
    }
    return [NSString stringWithFormat:@"hash %d", hashAlgorithm];
}

static void HashKeyPacket(HCGDigestContext *c, NSData *body) {
    uint8_t header[3] = { 0x99, (uint8_t)(body.length >> 8), (uint8_t)body.length };
    HCGDigestUpdate(c, header, 3);
    HCGDigestUpdate(c, body.bytes, body.length);
}

static void HashTrailer(HCGDigestContext *c, const HCGSig *sig) {
    HCGDigestUpdate(c, sig->hashedStart, sig->hashedLength);
    uint8_t trailer[6] = { 0x04, 0xFF, (uint8_t)(sig->hashedLength >> 24), (uint8_t)(sig->hashedLength >> 16),
                           (uint8_t)(sig->hashedLength >> 8), (uint8_t)sig->hashedLength };
    HCGDigestUpdate(c, trailer, 6);
}

// Finishes the digest and checks the RSA signature made by `key`.
static BOOL CheckSignature(HCGDigestContext *c, HCGDigestAlgorithm algorithm, const HCGSig *sig, HCGPGPKey *key) {
    HashTrailer(c, sig);
    uint8_t out[64];
    HCGDigestFinal(c, out);
    if (out[0] != sig->left16[0] || out[1] != sig->left16[1]) return NO;
    if (!(key.algorithm == 1 || key.algorithm == 3) || !key.modulus || !sig->mpi) return NO;
    return RSAVerify(key.modulus, key.exponent, [NSData dataWithBytes:sig->mpi length:sig->mpiLength], algorithm,
                     [NSData dataWithBytes:out length:HCGDigestLength(algorithm)]);
}

// A self-signature / binding signature over keys (and optionally a user ID) by `signer`.
static BOOL CheckKeySignature(const HCGSig *sig, HCGPGPKey *primary, HCGPGPKey *subkey, NSData *userID, HCGPGPKey *signer) {
    if (sig->version != 4 || !(sig->pubAlgorithm == 1 || sig->pubAlgorithm == 3) || sig->unknownCritical || !sig->hasCreated) return NO;
    BOOL weak = NO;
    HCGDigestAlgorithm algorithm = DigestFor(sig->hashAlgorithm, &weak);
    if (!algorithm) return NO;
    if (sig->sigExpires && (double)sig->created + (double)sig->sigExpires <= [[NSDate date] timeIntervalSince1970]) return NO; // expired certification
    HCGDigestContext c;
    HCGDigestInit(&c, algorithm);
    HashKeyPacket(&c, primary.packetBody);
    if (subkey) HashKeyPacket(&c, subkey.packetBody);
    if (userID) {
        uint8_t header[5] = { 0xB4, (uint8_t)(userID.length >> 24), (uint8_t)(userID.length >> 16), (uint8_t)(userID.length >> 8), (uint8_t)userID.length };
        HCGDigestUpdate(&c, header, 5);
        HCGDigestUpdate(&c, userID.bytes, userID.length);
    }
    return CheckSignature(&c, algorithm, sig, signer);
}

#pragma mark - Armor

static const int kB64Invalid = -1;

static int B64Value(unichar ch) {
    if (ch >= 'A' && ch <= 'Z') return ch - 'A';
    if (ch >= 'a' && ch <= 'z') return ch - 'a' + 26;
    if (ch >= '0' && ch <= '9') return ch - '0' + 52;
    if (ch == '+') return 62;
    if (ch == '/') return 63;
    return kB64Invalid;
}

static NSData *Base64Decode(NSString *text) {
    NSMutableData *out = [NSMutableData data];
    uint32_t acc = 0;
    int bits = 0;
    NSUInteger i;
    for (i = 0; i < text.length; i++) {
        unichar ch = [text characterAtIndex:i];
        if (ch == ' ' || ch == '\t' || ch == '\r' || ch == '\n') continue;
        if (ch == '=') {
            // Padding ends the data: only more padding (and whitespace) may follow.
            NSUInteger j;
            for (j = i + 1; j < text.length; j++) {
                unichar c2 = [text characterAtIndex:j];
                if (c2 != '=' && c2 != ' ' && c2 != '\t' && c2 != '\r' && c2 != '\n') return nil;
            }
            break;
        }
        int v = B64Value(ch);
        if (v == kB64Invalid) return nil;
        acc = (acc << 6) | (uint32_t)v;
        bits += 6;
        if (bits >= 8) {
            bits -= 8;
            uint8_t byte = (uint8_t)(acc >> bits);
            [out appendBytes:&byte length:1];
        }
    }
    return out;
}

static uint32_t CRC24(const uint8_t *p, size_t len) {
    uint32_t crc = 0xB704CE;
    size_t i;
    int b;
    for (i = 0; i < len; i++) {
        crc ^= (uint32_t)p[i] << 16;
        for (b = 0; b < 8; b++) {
            crc <<= 1;
            if (crc & 0x1000000) crc ^= 0x1864CFB;
        }
    }
    return crc & 0xFFFFFF;
}

static NSArray *Lines(NSString *text) {
    return [[text stringByReplacingOccurrencesOfString:@"\r\n" withString:@"\n"] componentsSeparatedByString:@"\n"];
}

// Decodes the first armor block of `kind` ("PUBLIC KEY BLOCK", "SIGNATURE") in lines[start..]; nil if malformed.
static NSData *DecodeArmorLines(NSArray *lines, NSUInteger start, NSString *kind, NSUInteger *endLine) {
    NSString *begin = [NSString stringWithFormat:@"-----BEGIN PGP %@-----", kind];
    NSString *end = [NSString stringWithFormat:@"-----END PGP %@-----", kind];
    NSUInteger i = start;
    while (i < lines.count && ![[[lines objectAtIndex:i] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] isEqualToString:begin]) i++;
    if (i >= lines.count) return nil;
    i++;
    // Armor headers until the first blank line (a header line contains ": ").
    while (i < lines.count && [[lines objectAtIndex:i] rangeOfString:@": "].location != NSNotFound) i++;
    if (i >= lines.count || [[[lines objectAtIndex:i] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] length] != 0) return nil;
    i++; // the blank line that ends the armor headers (RFC 4880 6.2)
    NSMutableString *body = [NSMutableString string];
    NSString *checksum = nil;
    for (; i < lines.count; i++) {
        NSString *line = [[lines objectAtIndex:i] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        if ([line isEqualToString:end]) break;
        if ([line hasPrefix:@"="] && line.length == 5) { checksum = [line substringFromIndex:1]; continue; }
        [body appendString:line];
    }
    if (i >= lines.count) return nil;
    if (endLine) *endLine = i;
    NSData *data = Base64Decode(body);
    if (!data.length) return nil;
    if (checksum) {
        NSData *crc = Base64Decode(checksum);
        if (crc.length != 3) return nil;
        const uint8_t *c = (const uint8_t *)crc.bytes;
        uint32_t expected = ((uint32_t)c[0] << 16) | ((uint32_t)c[1] << 8) | c[2];
        if (CRC24(data.bytes, data.length) != expected) return nil;
    }
    return data;
}

#pragma mark - Certificate

@implementation HCGPGPCertificate
@synthesize primary = _primary, subkeys = _subkeys, userIDs = _userIDs, problems = _problems;

+ (NSString *)displayFingerprint:(NSString *)fingerprint {
    NSString *f = [fingerprint uppercaseString];
    if (f.length != 40) return f;
    NSMutableString *s = [NSMutableString string];
    NSUInteger i;
    for (i = 0; i < 10; i++) {
        if (i == 5) [s appendString:@"  "];
        else if (i > 0) [s appendString:@" "];
        [s appendString:[f substringWithRange:NSMakeRange(i * 4, 4)]];
    }
    return s;
}

static NSDate *ExpiryFrom(HCGPGPKey *key, const HCGSig *sig) {
    if (!sig->hasKeyExpires || sig->keyExpires == 0) return nil;
    return [key.created dateByAddingTimeInterval:sig->keyExpires];
}

+ (instancetype)certificateWithData:(NSData *)data error:(NSString **)error {
    return [self certificateWithData:data expectedFingerprint:nil error:error];
}

// A revocation the verifier cannot check (SHA-1, SHA-384, ...) that names the primary key as its issuer. Honoured:
// a revocation can only take trust away, so failing closed is the safe reading.
static BOOL IsUncheckableRevocationFromPrimary(const HCGSig *sig, HCGPGPKey *primary) {
    BOOL weak = NO;
    if (sig->version != 4 || DigestFor(sig->hashAlgorithm, &weak)) return NO;
    if (sig->hasIssuerFingerprint) return [Hex(sig->issuerFingerprint, 20) isEqualToString:primary.fingerprint];
    return sig->hasIssuerKeyID && [Hex(sig->issuerKeyID, 8) isEqualToString:primary.keyID];
}

+ (instancetype)certificateWithData:(NSData *)data expectedFingerprint:(NSString *)expected error:(NSString **)error {
    if (data.length > kMaxCertificateBytes) {
        if (error) *error = @"The key file is too large (over 1 MB).";
        return nil;
    }
    NSData *binary = [HCGOpenPGP dearmor:data];
    if (!binary.length) {
        if (error) *error = @"Not an OpenPGP public key.";
        return nil;
    }
    const uint8_t *p = (const uint8_t *)binary.bytes;
    size_t len = binary.length, offset = 0;
    HCGPacket packet;
    HCGPGPKey *primary = nil, *currentSubkey = nil;
    NSData *currentUserID = nil;
    NSMutableArray *subkeys = [NSMutableArray array], *userIDs = [NSMutableArray array], *problems = [NSMutableArray array];
    uint32_t bestSelfSig = 0, bestDirectSig = 0;
    BOOL primaryHasSelfSig = NO, directExpiry = NO, capped = NO;
    NSDate *directExpires = nil;
    NSUInteger signatures = 0;
    NSMutableDictionary *bindingTimes = [NSMutableDictionary dictionary];
    while (NextPacket(p, len, &offset, &packet)) {
        if (packet.tag == 6) {
            if (primary) break; // only the first key in the file
            NSString *problem = nil;
            primary = ParseKey(packet, NO, &problem);
            if (!primary) {
                if (error) *error = problem ?: @"The primary key is not a v4 key this verifier understands.";
                return nil;
            }
            // The pin is compared before any signature is checked, so a key that is not the pinned one costs nothing.
            if (expected.length && ![primary.fingerprint isEqualToString:[expected uppercaseString]]) {
                HCGPGPCertificate *other = [[HCGPGPCertificate alloc] init];
                other.primary = primary;
                other.subkeys = [NSArray array];
                other.userIDs = [NSArray array];
                other.problems = [NSArray arrayWithObject:@"Not the pinned key: its signatures were not checked."];
                return other;
            }
        } else if (!primary) {
            continue;
        } else if (packet.tag == 13) {
            currentUserID = [NSData dataWithBytes:packet.body length:packet.length];
            currentSubkey = nil;
            NSString *uid = [[NSString alloc] initWithData:currentUserID encoding:NSUTF8StringEncoding];
            if (uid.length) [userIDs addObject:uid];
        } else if (packet.tag == 17) {
            currentUserID = nil; // user attribute: not used
            currentSubkey = nil;
        } else if (packet.tag == 14) {
            currentUserID = nil;
            NSString *problem = nil;
            HCGPGPKey *parsed = ParseKey(packet, YES, &problem);
            currentSubkey = nil;
            if (!parsed) {
                [problems addObject:problem ? [@"A subkey was ignored: " stringByAppendingString:problem] : @"A subkey that is not a v4 key was ignored."];
                continue;
            }
            // The same subkey listed twice is one key: its signatures (and any revocation) all apply to it.
            for (HCGPGPKey *known in subkeys) if ([known.fingerprint isEqualToString:parsed.fingerprint]) currentSubkey = known;
            if (!currentSubkey) {
                if (subkeys.count >= kMaxSubkeys) { capped = YES; continue; }
                currentSubkey = parsed;
                [subkeys addObject:parsed];
            }
        } else if (packet.tag == 2) {
            if (++signatures > kMaxCertificateSignatures) { capped = YES; break; }
            HCGSig sig;
            if (!ParseSignature(packet.body, packet.length, &sig) || sig.version != 4) continue;
            if (sig.type == 0x20) {
                // A key revocation of the primary, wherever it appears in the file.
                if (CheckKeySignature(&sig, primary, nil, nil, primary)) primary.revoked = YES;
                else if (IsUncheckableRevocationFromPrimary(&sig, primary)) {
                    primary.revoked = YES;
                    [problems addObject:@"A revocation of the key made with a digest this verifier cannot check was honoured."];
                }
            } else if (sig.type == 0x1F && !currentSubkey && !currentUserID) {
                // Direct-key signature: its expiry applies to the primary key.
                if (CheckKeySignature(&sig, primary, nil, nil, primary) && sig.created >= bestDirectSig) {
                    bestDirectSig = sig.created;
                    directExpiry = sig.hasKeyExpires && sig.keyExpires;
                    directExpires = ExpiryFrom(primary, &sig);
                }
            } else if (sig.type >= 0x10 && sig.type <= 0x13 && currentUserID && !currentSubkey) {
                if (CheckKeySignature(&sig, primary, nil, currentUserID, primary) && sig.created >= bestSelfSig) {
                    bestSelfSig = sig.created;
                    primaryHasSelfSig = YES;
                    primary.expires = ExpiryFrom(primary, &sig);
                    int flags = sig.keyFlags;
                    primary.canCertify = flags < 0 || (flags & 0x01);
                    primary.canSign = flags < 0 || (flags & 0x02);
                }
            } else if (sig.type == 0x18 && currentSubkey) {
                if (!CheckKeySignature(&sig, primary, currentSubkey, nil, primary)) continue;
                NSNumber *previous = [bindingTimes objectForKey:currentSubkey.fingerprint];
                if (previous && [previous unsignedIntValue] > sig.created) continue;
                [bindingTimes setObject:[NSNumber numberWithUnsignedInt:sig.created] forKey:currentSubkey.fingerprint];
                int flags = sig.keyFlags;
                BOOL sign = flags >= 0 && (flags & 0x02);
                BOOL backSigOK = NO;
                if (sign && sig.embedded) {
                    HCGSig back;
                    if (ParseSignature(sig.embedded, sig.embeddedLength, &back) && back.version == 4 && back.type == 0x19) {
                        backSigOK = CheckKeySignature(&back, primary, currentSubkey, nil, currentSubkey);
                    }
                }
                currentSubkey.canSign = sign && backSigOK;
                currentSubkey.bound = YES;
                currentSubkey.expires = ExpiryFrom(currentSubkey, &sig);
                if (sign && !backSigOK) [problems addObject:[NSString stringWithFormat:@"Signing subkey %@ has no valid back-signature and is not used.", currentSubkey.keyID]];
            } else if (sig.type == 0x28 && currentSubkey) {
                if (CheckKeySignature(&sig, primary, currentSubkey, nil, primary)) currentSubkey.revoked = YES;
                else if (IsUncheckableRevocationFromPrimary(&sig, primary)) {
                    currentSubkey.revoked = YES;
                    [problems addObject:[NSString stringWithFormat:@"A revocation of subkey %@ made with a digest this verifier cannot check was honoured.", currentSubkey.keyID]];
                }
            }
        }
    }
    if (capped) [problems addObject:@"The key file holds more signatures or subkeys than are checked; the rest were ignored."];
    if (directExpiry && directExpires && (!primary.expires || [directExpires compare:primary.expires] == NSOrderedAscending)) primary.expires = directExpires;
    if (!primary) {
        if (error) *error = @"No public key found.";
        return nil;
    }
    if (!primaryHasSelfSig) {
        if (primary.algorithm == 1 || primary.algorithm == 3) {
            if (error) *error = @"The primary key has no valid self-signature.";
            return nil;
        }
        [problems addObject:[NSString stringWithFormat:@"%@ keys are not supported by this verifier.", primary.algorithmName]];
    }
    primary.bound = primaryHasSelfSig;
    for (HCGPGPKey *subkey in subkeys) {
        if (!subkey.bound) [problems addObject:[NSString stringWithFormat:@"Subkey %@ has no valid binding signature and is not used.", subkey.keyID]];
    }
    HCGPGPCertificate *certificate = [[HCGPGPCertificate alloc] init];
    certificate.primary = primary;
    certificate.subkeys = subkeys;
    certificate.userIDs = userIDs;
    certificate.problems = problems;
    return certificate;
}

@end

#pragma mark - Verification

@implementation HCGOpenPGP

+ (NSString *)titleForStatus:(HCGPGPStatus)status {
    switch (status) {
        case HCGPGPStatusGood: return @"Good signature";
        case HCGPGPStatusBad: return @"BAD signature";
        case HCGPGPStatusUnknownSigner: return @"Signed by an untrusted key";
        case HCGPGPStatusWeakDigest: return @"Weak digest (refused)";
        case HCGPGPStatusUnsupported: return @"Unsupported signature";
        case HCGPGPStatusKeyExpired: return @"Signing key expired";
        case HCGPGPStatusSignatureExpired: return @"Signature expired";
        case HCGPGPStatusKeyRevoked: return @"Signing key revoked";
        case HCGPGPStatusMalformed: return @"Malformed signature";
        case HCGPGPStatusNoSignature: return @"No signature";
    }
    return @"Unknown";
}

+ (NSData *)dearmor:(NSData *)data {
    if (data.length == 0) return nil;
    const uint8_t *p = (const uint8_t *)data.bytes;
    if (p[0] & 0x80) return data; // binary packets
    NSString *text = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (!text) return nil;
    NSArray *lines = Lines(text);
    NSData *key = DecodeArmorLines(lines, 0, @"PUBLIC KEY BLOCK", NULL);
    return key ?: DecodeArmorLines(lines, 0, @"SIGNATURE", NULL);
}

static HCGPGPVerification *Result(HCGPGPStatus status, NSString *detail) {
    HCGPGPVerification *v = [[HCGPGPVerification alloc] init];
    v.status = status;
    v.detail = detail;
    return v;
}

// Canonical text for type 0x01: CRLF line endings, trailing spaces and tabs removed from each line.
static NSData *CanonicalText(NSData *data) {
    NSString *text = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (!text) return data;
    NSArray *lines = Lines(text);
    NSMutableArray *out = [NSMutableArray array];
    NSCharacterSet *ws = [NSCharacterSet characterSetWithCharactersInString:@" \t"];
    for (NSString *line in lines) {
        NSUInteger end = line.length;
        while (end > 0 && [ws characterIsMember:[line characterAtIndex:end - 1]]) end--;
        [out addObject:[line substringToIndex:end]];
    }
    return [[out componentsJoinedByString:@"\r\n"] dataUsingEncoding:NSUTF8StringEncoding];
}

static HCGPGPKey *FindSigner(HCGPGPCertificate *cert, const HCGSig *sig) {
    NSMutableArray *keys = [NSMutableArray arrayWithObject:cert.primary];
    [keys addObjectsFromArray:cert.subkeys];
    for (HCGPGPKey *key in keys) {
        if (sig->hasIssuerFingerprint && [key.fingerprint isEqualToString:Hex(sig->issuerFingerprint, 20)]) return key;
        if (!sig->hasIssuerFingerprint && sig->hasIssuerKeyID && [key.keyID isEqualToString:Hex(sig->issuerKeyID, 8)]) return key;
    }
    return nil;
}

static HCGPGPVerification *VerifyOne(const HCGSig *sig, NSData *data, HCGPGPCertificate *cert, NSDate *now, BOOL cleartext) {
    if (sig->version != 4) return Result(HCGPGPStatusUnsupported, [NSString stringWithFormat:@"Version %d signatures are not supported.", sig->version]);
    if (sig->type != 0x00 && sig->type != 0x01) return Result(HCGPGPStatusMalformed, @"Not a signature over a document.");
    if (cleartext && sig->type != 0x01) return Result(HCGPGPStatusMalformed, @"A signed message (InRelease) must carry a text-mode signature.");
    HCGPGPVerification *result = nil;
    NSString *issuer = sig->hasIssuerFingerprint ? Hex(sig->issuerFingerprint + 12, 8) : (sig->hasIssuerKeyID ? Hex(sig->issuerKeyID, 8) : nil);
    BOOL weak = NO;
    HCGDigestAlgorithm algorithm = DigestFor(sig->hashAlgorithm, &weak);
    if (weak) result = Result(HCGPGPStatusWeakDigest, [NSString stringWithFormat:@"Made with %@, which is refused.", DigestName(sig->hashAlgorithm)]);
    else if (!(sig->pubAlgorithm == 1 || sig->pubAlgorithm == 3)) result = Result(HCGPGPStatusUnsupported, @"Only RSA signatures are supported.");
    else if (!algorithm) result = Result(HCGPGPStatusUnsupported, [NSString stringWithFormat:@"%@ is not supported (SHA-256 and SHA-512 are).", DigestName(sig->hashAlgorithm)]);
    else if (sig->unknownCritical) result = Result(HCGPGPStatusUnsupported, @"The signature has a critical field this verifier does not understand.");
    else if (!sig->hasCreated) result = Result(HCGPGPStatusMalformed, @"The signature has no creation time.");
    if (result) {
        result.signerKeyID = issuer;
        result.digestName = DigestName(sig->hashAlgorithm);
        return result;
    }
    HCGPGPKey *signer = FindSigner(cert, sig);
    if (!signer) {
        result = Result(HCGPGPStatusUnknownSigner, [NSString stringWithFormat:@"Signed by key %@, which is not part of the trusted key.", issuer ?: @"(not named)"]);
        result.signerKeyID = issuer;
        result.digestName = DigestName(sig->hashAlgorithm);
        return result;
    }
    if (!signer.bound || !signer.canSign) {
        result = Result(HCGPGPStatusUnknownSigner, [NSString stringWithFormat:@"Key %@ is not certified for signing by the trusted key.", signer.keyID]);
        result.signerKeyID = signer.keyID;
        return result;
    }
    HCGDigestContext c;
    HCGDigestInit(&c, algorithm);
    NSData *hashed = sig->type == 0x01 ? CanonicalText(data) : data;
    HCGDigestUpdate(&c, hashed.bytes, hashed.length);
    BOOL ok = CheckSignature(&c, algorithm, sig, signer);
    NSDate *signedAt = [NSDate dateWithTimeIntervalSince1970:sig->created];
    if (!ok) result = Result(HCGPGPStatusBad, @"The signature does not match: the data was changed or the signature is not for it.");
    else if (signer.revoked || cert.primary.revoked) result = Result(HCGPGPStatusKeyRevoked, @"The signing key has been revoked.");
    else if ([signedAt compare:signer.created] == NSOrderedAscending) result = Result(HCGPGPStatusMalformed, @"The signature is older than its key.");
    else if ((signer.expires && [signer.expires compare:now] != NSOrderedDescending) ||
             (cert.primary.expires && [cert.primary.expires compare:now] != NSOrderedDescending)) {
        NSDate *when = signer.expires ?: cert.primary.expires;
        result = Result(HCGPGPStatusKeyExpired, [NSString stringWithFormat:@"The signing key expired on %@.", [when description]]);
    } else if ((signer.expires && [signer.expires compare:signedAt] != NSOrderedDescending)) {
        result = Result(HCGPGPStatusKeyExpired, @"The key had already expired when it signed.");
    } else if (sig->sigExpires && [[signedAt dateByAddingTimeInterval:sig->sigExpires] compare:now] != NSOrderedDescending) {
        result = Result(HCGPGPStatusSignatureExpired, @"The signature has expired.");
    } else {
        result = Result(HCGPGPStatusGood, [NSString stringWithFormat:@"Good %@ signature by %@.", DigestName(sig->hashAlgorithm), signer.isSubkey ? @"the trusted key's signing subkey" : @"the trusted key"]);
    }
    result.signerFingerprint = signer.fingerprint;
    result.signerKeyID = signer.keyID;
    result.primaryFingerprint = cert.primary.fingerprint;
    result.digestName = DigestName(sig->hashAlgorithm);
    result.signedAt = signedAt;
    return result;
}

// Every signature packet in `signature`; the best result wins (a good one, else the most specific failure).
static HCGPGPVerification *VerifyPackets(NSData *signature, NSData *data, HCGPGPCertificate *cert, NSDate *now, BOOL cleartext) {
    NSData *binary = [HCGOpenPGP dearmor:signature];
    if (!binary.length) return Result(HCGPGPStatusMalformed, @"The signature file is not OpenPGP data.");
    const uint8_t *p = (const uint8_t *)binary.bytes;
    size_t len = binary.length, offset = 0;
    HCGPacket packet;
    HCGPGPVerification *best = nil, *good = nil;
    NSUInteger count = 0;
    // Every packet is read before any result is returned: anything that is not a signature, more than 16 signatures,
    // or bytes after the last packet make the whole file malformed, even when one signature is good.
    while (NextPacket(p, len, &offset, &packet)) {
        if (packet.tag != 2) return Result(HCGPGPStatusMalformed, @"The signature file holds something other than signatures.");
        if (++count > 16) return Result(HCGPGPStatusMalformed, @"The signature file holds more than 16 signatures.");
        if (good) continue;
        HCGSig sig;
        HCGPGPVerification *one = ParseSignature(packet.body, packet.length, &sig) ? VerifyOne(&sig, data, cert, now, cleartext)
                                                                                  : Result(HCGPGPStatusMalformed, @"The signature cannot be read.");
        if (one.good) good = one;
        else if (!best || best.status == HCGPGPStatusUnknownSigner || best.status == HCGPGPStatusMalformed) best = one;
    }
    if (offset != len) return Result(HCGPGPStatusMalformed, @"The signature file has trailing data.");
    return good ?: (best ?: Result(HCGPGPStatusNoSignature, @"No signature found."));
}

+ (HCGPGPVerification *)verifyDetachedSignature:(NSData *)signature data:(NSData *)data certificate:(HCGPGPCertificate *)certificate now:(NSDate *)now {
    if (signature.length == 0) return Result(HCGPGPStatusNoSignature, @"No signature was supplied.");
    if (!certificate) return Result(HCGPGPStatusUnknownSigner, @"No trusted key.");
    return VerifyPackets(signature, data ?: [NSData data], certificate, now ?: [NSDate date], NO);
}

// Splits an InRelease file into its message text and signature armor; nil if anything is outside them.
static BOOL SplitCleartext(NSData *message, NSData **textOut, NSData **signatureOut) {
    NSString *text = [[NSString alloc] initWithData:message encoding:NSUTF8StringEncoding];
    if (!text) return NO;
    NSArray *lines = Lines(text);
    NSUInteger i = 0;
    if (lines.count < 4 || ![[lines objectAtIndex:0] isEqualToString:@"-----BEGIN PGP SIGNED MESSAGE-----"]) return NO;
    i = 1;
    while (i < lines.count && [[lines objectAtIndex:i] length] > 0) {
        if (![[lines objectAtIndex:i] hasPrefix:@"Hash: "]) return NO; // only Hash headers
        i++;
    }
    if (i >= lines.count) return NO;
    i++; // blank line
    NSMutableArray *body = [NSMutableArray array];
    NSUInteger signatureLine = NSNotFound;
    for (; i < lines.count; i++) {
        NSString *line = [lines objectAtIndex:i];
        if ([line isEqualToString:@"-----BEGIN PGP SIGNATURE-----"]) { signatureLine = i; break; }
        if ([line hasPrefix:@"-----BEGIN PGP"]) return NO; // a second message
        if ([line hasPrefix:@"- "]) line = [line substringFromIndex:2];
        else if ([line hasPrefix:@"-"]) return NO; // not dash-escaped
        [body addObject:line];
    }
    if (signatureLine == NSNotFound) return NO;
    NSUInteger end = 0;
    NSData *sig = DecodeArmorLines(lines, signatureLine, @"SIGNATURE", &end);
    if (!sig) return NO;
    for (i = end + 1; i < lines.count; i++) {
        if ([[[lines objectAtIndex:i] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] length]) return NO;
    }
    if (textOut) *textOut = [[body componentsJoinedByString:@"\n"] dataUsingEncoding:NSUTF8StringEncoding];
    if (signatureOut) *signatureOut = sig;
    return YES;
}

+ (NSData *)cleartextBodyOfMessage:(NSData *)message {
    NSData *text = nil;
    if (!message.length || !SplitCleartext(message, &text, NULL)) return nil;
    NSMutableData *withNewline = [text mutableCopy];
    [withNewline appendBytes:"\n" length:1];
    return withNewline;
}

+ (HCGPGPVerification *)verifyCleartextMessage:(NSData *)message certificate:(HCGPGPCertificate *)certificate now:(NSDate *)now {
    if (message.length == 0) return Result(HCGPGPStatusNoSignature, @"No signed message was supplied.");
    NSData *text = nil, *signature = nil;
    if (!SplitCleartext(message, &text, &signature)) return Result(HCGPGPStatusMalformed, @"Not exactly one signed message (text outside the signature, or malformed).");
    if (!certificate) return Result(HCGPGPStatusUnknownSigner, @"No trusted key.");
    HCGPGPVerification *result = VerifyPackets(signature, text, certificate, now ?: [NSDate date], YES);
    NSMutableData *withNewline = [text mutableCopy];
    [withNewline appendBytes:"\n" length:1];
    result.signedText = withNewline;
    return result;
}

@end
