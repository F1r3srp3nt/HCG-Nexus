#import "HCGTestHarness.h"
#import "HCGCore.h"

// Regression tests for the independent review of the OpenPGP verifier (26 Nov 2026). The fixtures in
// Fixtures/trust/review were made by the reviewer with GnuPG 2.4 and small packet-rewriting scripts; each one was a
// way to get a wrong answer (or burn CPU) before the fix. See Fixtures/trust/review/README.md.

NSData *HCGTrustFixture(NSString *name);

static NSData *ReviewFixture(NSString *name) {
    return HCGTrustFixture([@"review/" stringByAppendingString:name]);
}

static NSDate *ReviewNow(void) {
    return [NSDate dateWithTimeIntervalSince1970:1795700000]; // 2026-11-26, after the review key was made
}

static NSString *const kReviewPrimary = @"6DE86F7C180F9EA182E449DA9A94D752B5FB1219";
static NSString *const kReviewSubkey = @"DB7FFB22AE4D29DF370BB9C33B345F593EF54644";

static HCGPGPStatus DetachedStatus(NSString *keyFile, NSString *signatureFile) {
    HCGPGPCertificate *cert = [HCGPGPCertificate certificateWithData:ReviewFixture(keyFile) error:NULL];
    if (!cert) return HCGPGPStatusMalformed;
    return [HCGOpenPGP verifyDetachedSignature:ReviewFixture(signatureFile) data:ReviewFixture(@"Release") certificate:cert now:ReviewNow()].status;
}

static void testBaseline(void) {
    HCG_CHECK_EQ_INT(DetachedStatus(@"key.bin", @"Release.sig"), HCGPGPStatusGood);
    HCG_CHECK_EQ_INT(DetachedStatus(@"D_rev.bin", @"Release.sig"), HCGPGPStatusKeyRevoked);
}

static void testRevocationCannotBeBypassed(void) {
    // Finding 1: the revoked subkey listed twice (once without, once with its revocation).
    HCGPGPCertificate *dup = [HCGPGPCertificate certificateWithData:ReviewFixture(@"D_dup.bin") error:NULL];
    HCG_CHECK(dup != nil, "parses");
    HCG_CHECK_EQ_INT(dup.subkeys.count, 1); // one key, however often it is listed
    HCG_CHECK_EQ_INT(DetachedStatus(@"D_dup.bin", @"Release.sig"), HCGPGPStatusKeyRevoked);
    // Finding 7: a revocation made with SHA-1 is honoured, not ignored.
    HCG_CHECK_EQ_INT(DetachedStatus(@"D_sha1rev.bin", @"Release.sig"), HCGPGPStatusKeyRevoked);

    // Finding 1 (design): the repository's key file drops the revocation. A revocation this iPhone saw before stays.
    HCGRepositoryEvidence *e = [[HCGRepositoryEvidence alloc] init];
    e.repositoryURL = @"https://repo.example.invalid/";
    e.releaseData = ReviewFixture(@"Release");
    e.releaseSignature = ReviewFixture(@"Release.sig");
    e.publishedKey = ReviewFixture(@"D_rev.bin");
    e.pinnedFingerprint = kReviewPrimary;
    e.now = ReviewNow();
    HCGRepositoryReport *first = [HCGRepoTrust evaluate:e];
    HCG_CHECK(first.authenticity != HCGAuthenticityVerified, "revoked key never verifies");
    HCG_CHECK([first.revokedFingerprints containsObject:kReviewSubkey], "the revocation is reported for remembering");

    HCGTrustedRepository *memory = [[HCGTrustedRepository alloc] init];
    memory.identifier = @"custom-review";
    memory.url = e.repositoryURL;
    HCG_CHECK([memory rememberReport:first], "remembered");
    NSArray *stored = [HCGTrustedRepositoryList storedValueForRepositories:[NSArray arrayWithObject:memory]];
    HCGTrustedRepository *restored = nil;
    for (HCGTrustedRepository *r in [HCGTrustedRepositoryList repositoriesFromStoredValue:stored]) if ([r.identifier isEqualToString:@"custom-review"]) restored = r;
    HCG_CHECK([restored.revokedFingerprints containsObject:kReviewSubkey], "the revocation survives storage");

    e.publishedKey = ReviewFixture(@"D_stripped.bin");
    e.knownRevokedFingerprints = restored.revokedFingerprints;
    HCGRepositoryReport *stripped = [HCGRepoTrust evaluate:e];
    HCG_CHECK(stripped.authenticity != HCGAuthenticityVerified, "a stripped revocation does not restore trust");
    e.knownRevokedFingerprints = nil;
    HCG_CHECK_EQ_INT([HCGRepoTrust evaluate:e].authenticity, HCGAuthenticityUnknown); // without memory: signed, but no Packages to check
}

static void testOversizedKeysAreCheap(void) {
    // Finding 2: each of these took 2.5 s to ~20 min before. Now they are refused before any RSA work.
    NSArray *files = [NSArray arrayWithObjects:@"dos_8192_8192.bin", @"dos_16384_16384.bin", @"dos_max.bin", nil];
    for (NSString *f in files) {
        NSDate *start = [NSDate date];
        NSString *error = nil;
        HCGPGPCertificate *cert = [HCGPGPCertificate certificateWithData:ReviewFixture(f) error:&error];
        NSTimeInterval took = -[start timeIntervalSinceNow];
        HCG_CHECK(cert == nil, "%s is refused", [f UTF8String]);
        HCG_CHECK(took < 0.5, "%s took %.2f s", [f UTF8String], took);
        HCG_CHECK(error.length > 0, "with a reason");
    }
    // With a pin, a different key is rejected without checking any of its signatures.
    HCGPGPCertificate *other = [HCGPGPCertificate certificateWithData:ReviewFixture(@"key.bin") expectedFingerprint:@"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA" error:NULL];
    HCG_CHECK(other != nil && !other.primary.bound && other.subkeys.count == 0, "not the pinned key: nothing checked");
    HCGPGPCertificate *pinned = [HCGPGPCertificate certificateWithData:ReviewFixture(@"key.bin") expectedFingerprint:kReviewPrimary error:NULL];
    HCG_CHECK(pinned.primary.bound && pinned.subkeys.count == 1, "the pinned key is read fully");
}

static void testStrictness(void) {
    // Finding 5: critical notation / policy URL.
    HCG_CHECK_EQ_INT(DetachedStatus(@"key.bin", @"B_critnot.sig"), HCGPGPStatusUnsupported);
    HCG_CHECK_EQ_INT(DetachedStatus(@"key.bin", @"B_critpol.sig"), HCGPGPStatusUnsupported);
    // Finding 9: data after a good signature.
    HCG_CHECK_EQ_INT(DetachedStatus(@"key.bin", @"A_trailing.sig"), HCGPGPStatusMalformed);
    HCG_CHECK_EQ_INT(DetachedStatus(@"key.bin", @"A_litpkt.sig"), HCGPGPStatusMalformed);
    // Finding 6: a binary-mode (0x00) signature inside a cleartext message.
    HCGPGPCertificate *cert = [HCGPGPCertificate certificateWithData:ReviewFixture(@"key.bin") error:NULL];
    HCG_CHECK_EQ_INT([HCGOpenPGP verifyCleartextMessage:ReviewFixture(@"F_binary_in_clear.txt") certificate:cert now:ReviewNow()].status, HCGPGPStatusMalformed);
    HCG_CHECK_EQ_INT([HCGOpenPGP verifyCleartextMessage:ReviewFixture(@"InRelease") certificate:cert now:ReviewNow()].status, HCGPGPStatusGood);
    // Armor: data after base64 padding, and headers without the blank line.
    NSString *armored = [[NSString alloc] initWithData:HCGTrustFixture(@"Release.sha256.sig") encoding:NSUTF8StringEncoding];
    if ([armored hasPrefix:@"-----BEGIN"]) {
        NSString *noBlank = [armored stringByReplacingOccurrencesOfString:@"-----\n\n" withString:@"-----\n"];
        HCG_CHECK([HCGOpenPGP dearmor:[noBlank dataUsingEncoding:NSUTF8StringEncoding]] == nil, "armor headers must end with a blank line");
    }
    NSString *bad = @"-----BEGIN PGP SIGNATURE-----\n\nAAAA=AAAA\n-----END PGP SIGNATURE-----\n";
    HCG_CHECK([HCGOpenPGP dearmor:[bad dataUsingEncoding:NSUTF8StringEncoding]] == nil, "nothing after base64 padding");
}

static HCGRepositoryEvidence *SignedReviewRepo(void) {
    HCGRepositoryEvidence *e = [[HCGRepositoryEvidence alloc] init];
    e.repositoryURL = @"https://repo.hakmicapitalgroup.com/repo/";
    e.inRelease = ReviewFixture(@"InRelease");
    e.publishedKey = ReviewFixture(@"key.bin");
    e.pinnedFingerprint = kReviewPrimary;
    e.packages = nil;
    e.now = ReviewNow();
    return e;
}

static void testReplayAndChannelSwap(void) {
    // Finding 3: the Candidate index ("Suite: candidate") served at the Stable address.
    HCGRepositoryEvidence *e = SignedReviewRepo();
    e.expectedSuite = @"stable";
    HCGRepositoryReport *swapped = [HCGRepoTrust evaluate:e];
    HCG_CHECK_EQ_INT(swapped.authenticity, HCGAuthenticityInvalid);
    e.expectedSuite = @"candidate";
    HCG_CHECK([HCGRepoTrust evaluate:e].authenticity != HCGAuthenticityInvalid, "its own suite is fine");
    // An index older than one already verified.
    e.lastReleaseDate = [NSDate dateWithTimeIntervalSince1970:1795700000];
    HCG_CHECK_EQ_INT([HCGRepoTrust evaluate:e].authenticity, HCGAuthenticityInvalid);
    e.lastReleaseDate = [NSDate dateWithTimeIntervalSince1970:1795600912]; // the same Date is not a replay
    HCG_CHECK([HCGRepoTrust evaluate:e].authenticity != HCGAuthenticityInvalid, "same date accepted");
    // Built-in repositories carry their suite.
    NSArray *repos = [HCGTrustedRepositoryList repositoriesFromStoredValue:nil];
    HCG_CHECK_EQ_STR([[repos objectAtIndex:0] expectedSuite], @"stable");
    HCG_CHECK_EQ_STR([[repos objectAtIndex:1] expectedSuite], @"candidate");
}

static void testUnreadableValidUntil(void) {
    // Finding 4: a Valid-Until that cannot be parsed is not silently ignored.
    NSString *release = [[NSString alloc] initWithData:HCGTrustFixture(@"Release") encoding:NSUTF8StringEncoding];
    NSString *withBad = [release stringByReplacingOccurrencesOfString:@"Architectures:" withString:@"Valid-Until: Wed, 02 Dec 2026 10:00 UT\nArchitectures:"];
    HCGRepositoryEvidence *e = [[HCGRepositoryEvidence alloc] init];
    e.repositoryURL = @"https://repo.hakmicapitalgroup.com/repo/candidate/";
    e.releaseData = [withBad dataUsingEncoding:NSUTF8StringEncoding];
    e.now = ReviewNow();
    HCGRepositoryReport *r = [HCGRepoTrust evaluate:e];
    HCG_CHECK_EQ_INT(r.authenticity, HCGAuthenticityInvalid);
}

void HCGRunTrustReviewTests(void) {
    HCGCurrentTest = "trust-review";
    testBaseline();
    testRevocationCannotBeBypassed();
    testOversizedKeysAreCheap();
    testStrictness();
    testReplayAndChannelSwap();
    testUnreadableValidUntil();
}
