#import "HCGTestHarness.h"
#import "HCGCore.h"

// Package Trust Center: digests and OpenPGP verification against signatures made by GnuPG 2.4
// (Tests/Host/Fixtures/trust/README.md).

NSData *HCGTrustFixture(NSString *name) {
    const char *root = getenv("HCG_TEST_FIXTURES");
    NSString *dir = root ? [NSString stringWithUTF8String:root] : @"Tests/Host/Fixtures";
    NSData *data = [NSData dataWithContentsOfFile:[[dir stringByAppendingPathComponent:@"trust"] stringByAppendingPathComponent:name]];
    if (!data) fprintf(stderr, "  missing fixture %s\n", [name UTF8String]);
    return data ?: [NSData data];
}

static NSString *HexOf(NSString *text, HCGDigestAlgorithm algorithm) {
    return [HCGDigest hexDigestOfData:[text dataUsingEncoding:NSUTF8StringEncoding] algorithm:algorithm];
}

static void testDigestVectors(void) {
    // FIPS 180-4 / NIST examples.
    HCG_CHECK_EQ_STR(HexOf(@"abc", HCGDigestAlgorithmSHA1), @"a9993e364706816aba3e25717850c26c9cd0d89d");
    HCG_CHECK_EQ_STR(HexOf(@"abc", HCGDigestAlgorithmSHA256), @"ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad");
    HCG_CHECK_EQ_STR(HexOf(@"abc", HCGDigestAlgorithmSHA512),
                     @"ddaf35a193617abacc417349ae20413112e6fa4e89a97ea20a9eeee64b55d39a2192992a274fc1a836ba3c23a3feebbd454d4423643ce80e2a9ac94fa54ca49f");
    HCG_CHECK_EQ_STR(HexOf(@"", HCGDigestAlgorithmSHA256), @"e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855");
    HCG_CHECK_EQ_STR(HexOf(@"", HCGDigestAlgorithmSHA512),
                     @"cf83e1357eefb8bdf1542850d66d8007d620e4050b5715dc83f4a921d36ce9ce47d0d13c5d85f2b0ff8318d2877eec2f63b931bd47417a81a538327af927da3e");
    HCG_CHECK_EQ_STR(HexOf(@"abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq", HCGDigestAlgorithmSHA256),
                     @"248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1");
    HCG_CHECK_EQ_STR(HexOf(@"abcdefghbcdefghicdefghijdefghijkefghijklfghijklmghijklmnhijklmnoijklmnopjklmnopqklmnopqrlmnopqrsmnopqrstnopqrstu", HCGDigestAlgorithmSHA512),
                     @"8e959b75dae313da8cf4f72814fc143f8f7779c6eb9f7fa17299aeadb6889018501d289e4900f7e4331b99dec4b5433ac7d329eeb6dd26545e96e55b874be909");
    // A million 'a' in uneven chunks: exercises block boundaries and streaming.
    HCGDigestContext c;
    uint8_t chunk[997], out[64];
    memset(chunk, 'a', sizeof(chunk));
    HCGDigestInit(&c, HCGDigestAlgorithmSHA256);
    size_t left = 1000000;
    while (left) { size_t n = left < sizeof(chunk) ? left : sizeof(chunk); HCGDigestUpdate(&c, chunk, n); left -= n; }
    HCGDigestFinal(&c, out);
    HCG_CHECK_EQ_STR([HCGDigest hexStringFromData:[NSData dataWithBytes:out length:32]], @"cdc76e5c9914fb9281a1c7e284d73e67f1809a48a497200e046d39ccc7112cd0");
    HCG_CHECK([HCGDigest hexString:@"ABCDEF" equalsHexString:@"abcdef"], "case-insensitive");
    HCG_CHECK(![HCGDigest hexString:@"abcdef" equalsHexString:@"abcdee"], "differs");
    HCG_CHECK(![HCGDigest hexString:@"" equalsHexString:@""], "empty never matches");
    HCG_CHECK(![HCGDigest hexString:nil equalsHexString:@"ab"], "nil never matches");
    // The live Candidate Packages file is listed in its Release with this digest (checked again in the chain tests).
    HCG_CHECK_EQ_INT([HCGDigest hexDigestOfData:HCGTrustFixture(@"Packages") algorithm:HCGDigestAlgorithmSHA256].length, 64);
}

static NSDate *Now(void) {
    return [NSDate dateWithTimeIntervalSince1970:1795632000]; // 2026-11-25
}

HCGPGPCertificate *HCGTrustFounderCertificate(void) {
    NSString *error = nil;
    HCGPGPCertificate *cert = [HCGPGPCertificate certificateWithData:HCGTrustFixture(@"founder-test.asc") error:&error];
    if (!cert) fprintf(stderr, "  founder key: %s\n", [error UTF8String]);
    return cert;
}

static void testCertificateParsing(void) {
    HCGPGPCertificate *cert = HCGTrustFounderCertificate();
    HCG_CHECK(cert != nil, "founder test key parses");
    NSString *expected = [[[NSString alloc] initWithData:HCGTrustFixture(@"founder-test.fpr") encoding:NSUTF8StringEncoding]
                          stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    HCG_CHECK_EQ_STR(cert.primary.fingerprint, expected);
    HCG_CHECK_EQ_STR(cert.primary.keyID, [expected substringFromIndex:24]);
    HCG_CHECK_EQ_INT(cert.primary.bits, 4096);
    HCG_CHECK(cert.primary.bound && cert.primary.canCertify && !cert.primary.canSign, "certify-only primary, as HCG Repo's founder key");
    HCG_CHECK(cert.primary.expires != nil, "primary expires (5 years)");
    HCG_CHECK_EQ_INT(cert.subkeys.count, 1);
    HCGPGPKey *sub = cert.subkeys.firstObject;
    HCG_CHECK(sub.bound && sub.canSign && !sub.revoked, "signing subkey with binding and back-signature");
    HCG_CHECK_EQ_INT(sub.bits, 4096);
    HCG_CHECK_EQ_STR(sub.algorithmName, @"RSA");
    HCG_CHECK(cert.userIDs.count == 1 && [cert.userIDs.firstObject rangeOfString:@"TEST ONLY"].location != NSNotFound, "user ID");
    HCG_CHECK_EQ_INT(cert.problems.count, 0);
    HCG_CHECK_EQ_STR([HCGPGPCertificate displayFingerprint:@"AC5D9F7903CF8AD25747B80B3939DC1109BECABF"], @"AC5D 9F79 03CF 8AD2 5747  B80B 3939 DC11 09BE CABF");

    // The same key in binary form.
    NSData *binary = [HCGOpenPGP dearmor:HCGTrustFixture(@"founder-test.asc")];
    HCG_CHECK(binary.length > 1000, "dearmor");
    HCG_CHECK_EQ_STR([[HCGPGPCertificate certificateWithData:binary error:NULL] primary].fingerprint, expected);

    // A damaged armor checksum, a truncated key, a tampered binding: refused or the subkey is dropped.
    NSMutableString *armor = [[[NSString alloc] initWithData:HCGTrustFixture(@"founder-test.asc") encoding:NSUTF8StringEncoding] mutableCopy];
    NSRange crc = [armor rangeOfString:@"\n=" options:NSBackwardsSearch];
    if (crc.location != NSNotFound) [armor replaceCharactersInRange:NSMakeRange(crc.location + 2, 1) withString:[[armor substringWithRange:NSMakeRange(crc.location + 2, 1)] isEqualToString:@"A"] ? @"B" : @"A"];
    HCG_CHECK([HCGPGPCertificate certificateWithData:[armor dataUsingEncoding:NSUTF8StringEncoding] error:NULL] == nil, "bad CRC-24 refused");
    HCG_CHECK([HCGPGPCertificate certificateWithData:[binary subdataWithRange:NSMakeRange(0, 40)] error:NULL] == nil, "truncated key refused");
    NSMutableData *tampered = [binary mutableCopy];
    uint8_t *bytes = (uint8_t *)tampered.mutableBytes;
    bytes[tampered.length - 30] ^= 0x01; // inside the subkey binding signature's MPI
    HCGPGPCertificate *broken = [HCGPGPCertificate certificateWithData:tampered error:NULL];
    HCG_CHECK(broken == nil || !broken.subkeys.firstObject.canSign, "tampered binding: the subkey is not used for signing");
    HCG_CHECK([HCGPGPCertificate certificateWithData:[@"hello" dataUsingEncoding:NSUTF8StringEncoding] error:NULL] == nil, "text refused");

    NSString *error = nil;
    HCGPGPCertificate *ed = [HCGPGPCertificate certificateWithData:HCGTrustFixture(@"ed25519-test.asc") error:&error];
    HCG_CHECK(ed != nil && ed.problems.count > 0 && !ed.primary.canSign, "EdDSA key parsed but not usable here");
}

static void testDetachedAndCleartextSignatures(void) {
    HCGPGPCertificate *cert = HCGTrustFounderCertificate();
    NSData *release = HCGTrustFixture(@"Release");
    HCGPGPVerification *v = [HCGOpenPGP verifyDetachedSignature:HCGTrustFixture(@"Release.gpg") data:release certificate:cert now:Now()];
    HCG_CHECK_EQ_INT(v.status, HCGPGPStatusGood);
    HCG_CHECK_EQ_STR(v.digestName, @"SHA-512");
    HCG_CHECK_EQ_STR(v.primaryFingerprint, cert.primary.fingerprint);
    HCG_CHECK_EQ_STR(v.signerFingerprint, cert.subkeys.firstObject.fingerprint);
    HCG_CHECK(v.signedAt != nil, "creation time");

    v = [HCGOpenPGP verifyDetachedSignature:HCGTrustFixture(@"Release.gpg") data:HCGTrustFixture(@"Release.tampered") certificate:cert now:Now()];
    HCG_CHECK_EQ_INT(v.status, HCGPGPStatusBad);
    v = [HCGOpenPGP verifyDetachedSignature:HCGTrustFixture(@"Release.sha256.sig") data:release certificate:cert now:Now()];
    HCG_CHECK_EQ_INT(v.status, HCGPGPStatusGood);
    HCG_CHECK_EQ_STR(v.digestName, @"SHA-256");
    v = [HCGOpenPGP verifyDetachedSignature:HCGTrustFixture(@"Release.sha1.asc") data:release certificate:cert now:Now()];
    HCG_CHECK_EQ_INT(v.status, HCGPGPStatusWeakDigest);
    v = [HCGOpenPGP verifyDetachedSignature:HCGTrustFixture(@"Release.other.asc") data:release certificate:cert now:Now()];
    HCG_CHECK_EQ_INT(v.status, HCGPGPStatusUnknownSigner);
    HCG_CHECK(v.signerKeyID.length == 16, "names the foreign key");
    v = [HCGOpenPGP verifyDetachedSignature:HCGTrustFixture(@"Release.ed25519.asc") data:release certificate:cert now:Now()];
    HCG_CHECK_EQ_INT(v.status, HCGPGPStatusUnsupported);
    v = [HCGOpenPGP verifyDetachedSignature:nil data:release certificate:cert now:Now()];
    HCG_CHECK_EQ_INT(v.status, HCGPGPStatusNoSignature);
    v = [HCGOpenPGP verifyDetachedSignature:[@"garbage" dataUsingEncoding:NSUTF8StringEncoding] data:release certificate:cert now:Now()];
    HCG_CHECK_EQ_INT(v.status, HCGPGPStatusMalformed);

    // The other key, trusted, verifies its own signature; the founder signature is then foreign.
    HCGPGPCertificate *other = [HCGPGPCertificate certificateWithData:HCGTrustFixture(@"other-test.asc") error:NULL];
    HCG_CHECK_EQ_INT([HCGOpenPGP verifyDetachedSignature:HCGTrustFixture(@"Release.other.asc") data:release certificate:other now:Now()].status, HCGPGPStatusGood);
    HCG_CHECK_EQ_INT([HCGOpenPGP verifyDetachedSignature:HCGTrustFixture(@"Release.gpg") data:release certificate:other now:Now()].status, HCGPGPStatusUnknownSigner);

    // Expired: valid in 2020, expired since 2021.
    HCGPGPCertificate *expired = [HCGPGPCertificate certificateWithData:HCGTrustFixture(@"expired-test.asc") error:NULL];
    v = [HCGOpenPGP verifyDetachedSignature:HCGTrustFixture(@"Release.expired.asc") data:release certificate:expired now:Now()];
    HCG_CHECK_EQ_INT(v.status, HCGPGPStatusKeyExpired);
    v = [HCGOpenPGP verifyDetachedSignature:HCGTrustFixture(@"Release.expired.asc") data:release certificate:expired
                                       now:[NSDate dateWithTimeIntervalSince1970:1593561600]]; // 2020-07-01
    HCG_CHECK_EQ_INT(v.status, HCGPGPStatusGood);

    // Founder key at a time after its signing subkey expires (2 years): expired, never good.
    v = [HCGOpenPGP verifyDetachedSignature:HCGTrustFixture(@"Release.gpg") data:release certificate:cert
                                       now:[NSDate dateWithTimeIntervalSince1970:1795632000 + 3 * 365 * 86400.0]];
    HCG_CHECK_EQ_INT(v.status, HCGPGPStatusKeyExpired);

    // InRelease (cleartext, text mode).
    v = [HCGOpenPGP verifyCleartextMessage:HCGTrustFixture(@"InRelease") certificate:cert now:Now()];
    HCG_CHECK_EQ_INT(v.status, HCGPGPStatusGood);
    HCG_CHECK([v.signedText isEqualToData:release], "InRelease carries exactly Release");
    HCG_CHECK([[HCGOpenPGP cleartextBodyOfMessage:HCGTrustFixture(@"InRelease")] isEqualToData:release], "body without verification");
    v = [HCGOpenPGP verifyCleartextMessage:HCGTrustFixture(@"InRelease.tampered") certificate:cert now:Now()];
    HCG_CHECK_EQ_INT(v.status, HCGPGPStatusBad);
    v = [HCGOpenPGP verifyCleartextMessage:HCGTrustFixture(@"InRelease") certificate:other now:Now()];
    HCG_CHECK_EQ_INT(v.status, HCGPGPStatusUnknownSigner);

    // Anything outside the one signed message is refused, as APT does.
    NSString *inRelease = [[NSString alloc] initWithData:HCGTrustFixture(@"InRelease") encoding:NSUTF8StringEncoding];
    NSArray *bad = [NSArray arrayWithObjects:
        [@"Origin: evil\n" stringByAppendingString:inRelease],
        [inRelease stringByAppendingString:@"Package: injected\n"],
        [inRelease stringByReplacingOccurrencesOfString:@"Hash: SHA512" withString:@"Hash: SHA512\nComment: x"],
        [inRelease stringByAppendingString:inRelease],
        @"", nil];
    for (NSString *text in bad) {
        HCGPGPVerification *r = [HCGOpenPGP verifyCleartextMessage:[text dataUsingEncoding:NSUTF8StringEncoding] certificate:cert now:Now()];
        HCG_CHECK(!r.good, "refused: %s", [[text substringToIndex:MIN((NSUInteger)24, text.length)] UTF8String]);
    }
    // Trailing whitespace on a signed line is canonicalised away (RFC 4880 §7.1), so it still verifies.
    NSString *spaced = [inRelease stringByReplacingOccurrencesOfString:@"\nSuite:" withString:@" \t\nSuite:"];
    if (![spaced isEqualToString:inRelease]) {
        HCG_CHECK([HCGOpenPGP verifyCleartextMessage:[spaced dataUsingEncoding:NSUTF8StringEncoding] certificate:cert now:Now()].good, "trailing whitespace");
    }
}

void HCGRunTrustTests(void) {
    HCG_RUN(testDigestVectors);
    HCG_RUN(testCertificateParsing);
    HCG_RUN(testDetachedAndCleartextSignatures);
}
