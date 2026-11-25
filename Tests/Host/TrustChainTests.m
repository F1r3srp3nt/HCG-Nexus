#import "HCGTestHarness.h"
#import "HCGCore.h"
#include <unistd.h>
#include <sys/stat.h>
#include <arpa/inet.h>

NSData *HCGTrustFixture(NSString *name);
HCGPGPCertificate *HCGTrustFounderCertificate(void);

static NSDate *TrustNow(void) {
    return [NSDate dateWithTimeIntervalSince1970:1795632000]; // 2026-11-25
}

static NSString *FounderFingerprint(void) {
    return [[[NSString alloc] initWithData:HCGTrustFixture(@"founder-test.fpr") encoding:NSUTF8StringEncoding]
            stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

static HCGRepositoryEvidence *LiveCandidate(void) {
    HCGRepositoryEvidence *e = [[HCGRepositoryEvidence alloc] init];
    e.repositoryURL = @"https://repo.hakmicapitalgroup.com/repo/candidate/";
    e.releaseData = HCGTrustFixture(@"Release");
    e.packages = HCGTrustFixture(@"Packages");
    e.packagesPath = @"Packages";
    e.now = TrustNow();
    return e;
}

static HCGRepositoryEvidence *SignedCandidate(void) {
    HCGRepositoryEvidence *e = LiveCandidate();
    e.releaseSignature = HCGTrustFixture(@"Release.gpg");
    e.inRelease = HCGTrustFixture(@"InRelease");
    e.publishedKey = HCGTrustFixture(@"founder-test.asc");
    e.pinnedFingerprint = FounderFingerprint();
    return e;
}

static NSDictionary *Stanza(HCGRepositoryReport *report, NSString *package, NSString *version) {
    for (NSDictionary *s in report.packages) {
        if ([[s objectForKey:@"Package"] isEqualToString:package] && (!version || [[s objectForKey:@"Version"] isEqualToString:version])) return s;
    }
    return nil;
}

static void testReleaseParsing(void) {
    HCGReleaseFile *r = [HCGReleaseFile releaseWithData:HCGTrustFixture(@"Release")];
    HCG_CHECK(r != nil, "parses");
    HCG_CHECK_EQ_STR([r.fields objectForKey:@"Suite"], @"candidate");
    HCG_CHECK([r.sha256 objectForKey:@"Packages"] != nil && [r.sha256 objectForKey:@"Packages.xz"] != nil, "SHA256 section");
    HCG_CHECK_EQ_INT((long)[r.date timeIntervalSince1970], 1795600912); // Wed, 25 Nov 2026 10:01:52 GMT
    HCG_CHECK(r.validUntil == nil, "no Valid-Until today");
    HCG_CHECK_EQ_INT((long)[[HCGReleaseFile dateFromRFC2822:@"Thu, 01 Jan 1970 01:00:00 +0100"] timeIntervalSince1970], 0);
    HCG_CHECK([HCGReleaseFile dateFromRFC2822:@"yesterday"] == nil, "garbage date");
    HCG_CHECK([HCGReleaseFile releaseWithData:nil] == nil, "nil");
}

static void testUnsignedLiveRepository(void) {
    HCGRepositoryReport *report = [HCGRepoTrust evaluate:LiveCandidate()];
    HCG_CHECK_EQ_INT(report.authenticity, HCGAuthenticityUnsigned);
    HCG_CHECK(report.indexConsistent, "the live index is consistent");
    HCG_CHECK_EQ_INT(report.packages.count, 21);
    HCG_CHECK(report.warnings.count >= 1 && [report.summary rangeOfString:@"nothing proves"].location != NSNotFound, "says what unsigned means");

    // A changed Packages file: invalid, even unsigned.
    HCGRepositoryEvidence *e = LiveCandidate();
    NSMutableData *packages = [e.packages mutableCopy];
    ((uint8_t *)packages.mutableBytes)[100] ^= 0x20;
    e.packages = packages;
    report = [HCGRepoTrust evaluate:e];
    HCG_CHECK_EQ_INT(report.authenticity, HCGAuthenticityInvalid);
    HCG_CHECK(!report.indexConsistent, "mismatch detected");
    e = LiveCandidate();
    e.packagesPath = @"main/binary-iphoneos-arm64/Packages";
    HCG_CHECK_EQ_INT([HCGRepoTrust evaluate:e].authenticity, HCGAuthenticityInvalid); // not listed
    e = LiveCandidate();
    e.releaseData = nil;
    HCG_CHECK_EQ_INT([HCGRepoTrust evaluate:e].authenticity, HCGAuthenticityInvalid); // nothing lists Packages

    // A Valid-Until in the past is an expired (possibly replayed) index.
    NSString *text = [[NSString alloc] initWithData:HCGTrustFixture(@"Release") encoding:NSUTF8StringEncoding];
    e = LiveCandidate();
    e.releaseData = [[text stringByReplacingOccurrencesOfString:@"Architectures:" withString:@"Valid-Until: Wed, 01 Jan 2025 00:00:00 UTC\nArchitectures:"] dataUsingEncoding:NSUTF8StringEncoding];
    HCG_CHECK_EQ_INT([HCGRepoTrust evaluate:e].authenticity, HCGAuthenticityExpired);
}

static void testSignedRepository(void) {
    HCGRepositoryReport *report = [HCGRepoTrust evaluate:SignedCandidate()];
    HCG_CHECK_EQ_INT(report.authenticity, HCGAuthenticityVerified);
    HCG_CHECK(report.detachedResult.good && report.inlineResult.good, "both signatures good");
    HCG_CHECK([report.summary rangeOfString:@"not safety"].location != NSNotFound, "verified is not safe");

    HCGRepositoryEvidence *e = SignedCandidate();
    e.pinnedFingerprint = nil;
    report = [HCGRepoTrust evaluate:e];
    HCG_CHECK_EQ_INT(report.authenticity, HCGAuthenticityUntrusted); // signed, but you pinned nothing

    e = SignedCandidate();
    e.pinnedFingerprint = @"0000000000000000000000000000000000000000";
    HCG_CHECK_EQ_INT([HCGRepoTrust evaluate:e].authenticity, HCGAuthenticityUntrusted); // another key published

    e = SignedCandidate();
    e.publishedKey = HCGTrustFixture(@"other-test.asc"); // the repository swapped its key
    report = [HCGRepoTrust evaluate:e];
    HCG_CHECK_EQ_INT(report.authenticity, HCGAuthenticityUntrusted);
    HCG_CHECK(report.warnings.count > 0, "warns about the key change");

    e = SignedCandidate();
    e.inRelease = HCGTrustFixture(@"InRelease.tampered");
    HCG_CHECK_EQ_INT([HCGRepoTrust evaluate:e].authenticity, HCGAuthenticityInvalid);

    e = SignedCandidate();
    e.releaseData = HCGTrustFixture(@"Release.tampered"); // InRelease still good, Release.gpg now bad, and they differ
    HCG_CHECK_EQ_INT([HCGRepoTrust evaluate:e].authenticity, HCGAuthenticityInvalid);

    e = SignedCandidate();
    e.releaseSignature = HCGTrustFixture(@"Release.other.asc");
    e.inRelease = nil;
    HCG_CHECK_EQ_INT([HCGRepoTrust evaluate:e].authenticity, HCGAuthenticityUntrusted);

    e = SignedCandidate();
    e.releaseSignature = HCGTrustFixture(@"Release.sha1.asc");
    e.inRelease = nil;
    HCG_CHECK_EQ_INT([HCGRepoTrust evaluate:e].authenticity, HCGAuthenticityUntrusted); // weak digest

    e = SignedCandidate();
    e.now = [NSDate dateWithTimeIntervalSince1970:1795632000 + 3 * 365 * 86400.0];
    HCG_CHECK_EQ_INT([HCGRepoTrust evaluate:e].authenticity, HCGAuthenticityExpired);

    e = SignedCandidate();
    e.publishedKey = HCGTrustFixture(@"expired-test.asc");
    e.pinnedFingerprint = [[HCGPGPCertificate certificateWithData:HCGTrustFixture(@"expired-test.asc") error:NULL] primary].fingerprint;
    e.releaseSignature = HCGTrustFixture(@"Release.expired.asc");
    e.inRelease = nil;
    HCG_CHECK_EQ_INT([HCGRepoTrust evaluate:e].authenticity, HCGAuthenticityExpired);

    // Only signed text counts: with a good InRelease and no Release, the index is checked against InRelease's text.
    e = SignedCandidate();
    e.releaseData = nil;
    e.releaseSignature = nil;
    report = [HCGRepoTrust evaluate:e];
    HCG_CHECK_EQ_INT(report.authenticity, HCGAuthenticityVerified);
    HCG_CHECK(report.indexConsistent, "index checked against signed text");
}

static void testPackageAssessment(void) {
    HCGRepositoryReport *unsignedReport = [HCGRepoTrust evaluate:LiveCandidate()];
    HCGRepositoryReport *signedReport = [HCGRepoTrust evaluate:SignedCandidate()];
    HCGCompatibilityRegistry *registry = [HCGCompatibilityRegistry registryWithData:HCGTrustFixture(@"compat.json")];
    HCG_CHECK(registry != nil, "compatibility registry parses");

    NSDictionary *ac = Stanza(unsignedReport, @"com.hakmicapitalgroup.animationcenter", nil);
    NSString *sha = [ac objectForKey:@"SHA256"];
    unsigned long long size = (unsigned long long)[[ac objectForKey:@"Size"] longLongValue];
    NSDictionary *acRecord = [registry recordForPackage:@"com.hakmicapitalgroup.animationcenter" version:[ac objectForKey:@"Version"]];
    HCGPackageAssessment *a = [HCGRepoTrust assessPackage:ac repository:unsignedReport compatibility:acRecord deviceIOS:@"16.5" downloadedSHA256:sha downloadedSize:size];
    HCG_CHECK_EQ_INT(a.authenticity, HCGAuthenticityUnsigned); // a matching checksum does not make it verified
    HCG_CHECK_EQ_INT(a.checksum, HCGChecksumStateMatches);
    HCG_CHECK([a.authenticityText rangeOfString:@"not who published it"].location != NSNotFound, "explains: %s", [a.authenticityText UTF8String]);
    HCG_CHECK_EQ_INT(a.deviceEvidence, HCGDeviceEvidenceUntested);

    a = [HCGRepoTrust assessPackage:ac repository:signedReport compatibility:acRecord deviceIOS:@"16.5" downloadedSHA256:sha downloadedSize:size];
    HCG_CHECK_EQ_INT(a.authenticity, HCGAuthenticityVerified);
    HCG_CHECK([a.authenticityText rangeOfString:@"not that the package is safe"].location != NSNotFound, "verified is not safe");
    a = [HCGRepoTrust assessPackage:ac repository:signedReport compatibility:acRecord deviceIOS:@"16.5" downloadedSHA256:sha downloadedSize:size + 1];
    HCG_CHECK_EQ_INT(a.authenticity, HCGAuthenticityInvalid); // size differs
    a = [HCGRepoTrust assessPackage:ac repository:signedReport compatibility:acRecord deviceIOS:@"16.5"
                   downloadedSHA256:@"0000000000000000000000000000000000000000000000000000000000000000" downloadedSize:size];
    HCG_CHECK_EQ_INT(a.authenticity, HCGAuthenticityInvalid);
    HCG_CHECK_EQ_INT(a.checksum, HCGChecksumStateMismatch);
    a = [HCGRepoTrust assessPackage:ac repository:signedReport compatibility:nil deviceIOS:@"14.8" downloadedSHA256:nil downloadedSize:0];
    HCG_CHECK_EQ_INT(a.deviceEvidence, HCGDeviceEvidenceIncompatible); // firmware (>= 15.0)
    a = [HCGRepoTrust assessPackage:ac repository:signedReport compatibility:nil deviceIOS:@"16.5" downloadedSHA256:nil downloadedSize:0];
    HCG_CHECK_EQ_INT(a.deviceEvidence, HCGDeviceEvidenceUnknown);
    HCG_CHECK_EQ_INT(a.checksum, HCGChecksumStateNotDownloaded);

    // HCG Terminal Unleashed 0.2.0~rc1: installed, then closed at launch on the owner's iPhone 11 Pro Max.
    NSDictionary *rc1 = Stanza(unsignedReport, @"com.hakmicapitalgroup.hcgterminal.unleashed", @"0.2.0~rc1");
    HCG_CHECK(rc1 != nil, "rc1 in the index");
    NSDictionary *rc1Record = [registry recordForPackage:@"com.hakmicapitalgroup.hcgterminal.unleashed" version:@"0.2.0~rc1"];
    a = [HCGRepoTrust assessPackage:rc1 repository:unsignedReport compatibility:rc1Record deviceIOS:@"17.4" downloadedSHA256:nil downloadedSize:0];
    HCG_CHECK_EQ_INT(a.deviceEvidence, HCGDeviceEvidenceIncompatible);
    BOOL failureListed = NO;
    for (NSString *w in a.warnings) if ([w rangeOfString:@"iPhone 11 Pro Max"].location != NSNotFound) failureListed = YES;
    HCG_CHECK(failureListed, "the recorded failure is shown");
    a = [HCGRepoTrust assessPackage:rc1 repository:unsignedReport compatibility:rc1Record deviceIOS:@"16.5" downloadedSHA256:nil downloadedSize:0];
    HCG_CHECK_EQ_INT(a.deviceEvidence, HCGDeviceEvidenceIncompatible);
    HCG_CHECK([a.deviceText rangeOfString:@"16.5"].location != NSNotFound, "firmware explains: %s", [a.deviceText UTF8String]);

    HCG_CHECK([HCGRepoTrust firmwareProblemInDepends:@"firmware (>= 15.0), firmware (<< 17.0)" ios:@"17.4"] != nil, "upper bound");
    HCG_CHECK([HCGRepoTrust firmwareProblemInDepends:@"firmware (>= 15.0), firmware (<< 17.0)" ios:@"16.5"] == nil, "inside range");
    HCG_CHECK([HCGRepoTrust firmwareProblemInDepends:@"mobilesubstrate | ellekit, preferenceloader" ios:@"16.5"] == nil, "no firmware");
    HCG_CHECK([HCGRepoTrust firmwareProblemInDepends:@"firmware (>= 15.0)" ios:nil] == nil, "unknown iOS");

    NSMutableDictionary *noSHA = [ac mutableCopy];
    [noSHA removeObjectForKey:@"SHA256"];
    a = [HCGRepoTrust assessPackage:noSHA repository:signedReport compatibility:nil deviceIOS:@"16.5" downloadedSHA256:nil downloadedSize:0];
    HCG_CHECK(a.authenticity != HCGAuthenticityVerified, "no SHA-256, no verification");
    HCG_CHECK([[HCGRepoTrust titleForAuthenticity:HCGAuthenticityVerified] rangeOfString:@"afe"].location == NSNotFound, "never 'safe'");
}

static void testPassportsAndMonitor(void) {
    NSString *error = nil;
    HCGReleasePassport *p = [HCGReleasePassport passportWithData:HCGTrustFixture(@"passport-terminal-rc1.json") error:&error];
    HCG_CHECK(p != nil, "passport parses: %s", [error UTF8String]);
    HCG_CHECK_EQ_STR(p.version, @"0.2.0~rc1");
    HCG_CHECK(p.sections.count >= 7, "sections");
    NSArray *keys = [p.entitlements objectForKey:@"var/jb/Applications/HCGTerminalUnleashed.app/HCGTerminalUnleashed"];
    HCG_CHECK([keys containsObject:@"com.apple.private.security.no-sandbox"], "declared entitlement");
    BOOL sandbox = NO, incompatible = NO, launch = NO, unsignedRepo = NO;
    for (NSString *w in p.warnings) {
        if ([w rangeOfString:@"no-sandbox"].location != NSNotFound) sandbox = YES;
        if ([w rangeOfString:@"Known incompatible"].location != NSNotFound) incompatible = YES;
        if ([w rangeOfString:@"Application launch failed"].location != NSNotFound) launch = YES;
        if ([w rangeOfString:@"not signed"].location != NSNotFound) unsignedRepo = YES;
    }
    HCG_CHECK(sandbox && incompatible && launch && unsignedRepo, "warnings: sandbox %d incompatible %d launch %d unsigned %d", sandbox, incompatible, launch, unsignedRepo);
    HCGRepositoryReport *report = [HCGRepoTrust evaluate:LiveCandidate()];
    NSString *indexSHA = [Stanza(report, @"com.hakmicapitalgroup.hcgterminal.unleashed", @"0.2.0~rc1") objectForKey:@"SHA256"];
    HCG_CHECK_EQ_INT([p warningsAgainstIndexSHA256:indexSHA].count, 0); // passport and index name the same bytes
    HCG_CHECK_EQ_INT([p warningsAgainstIndexSHA256:@"1111111111111111111111111111111111111111111111111111111111111111"].count, 1);
    HCG_CHECK([HCGReleasePassport passportWithData:HCGTrustFixture(@"monitor.json") error:&error] == nil, "a monitor report is not a passport");
    HCG_CHECK([HCGReleasePassport passportWithData:[@"{\"format\":\"hcg.release-passport\",\"formatVersion\":2}" dataUsingEncoding:NSUTF8StringEncoding] error:NULL] == nil, "v2 refused");
    HCG_CHECK([HCGReleasePassport passportWithData:HCGTrustFixture(@"passport-nexus.json") error:NULL] != nil, "Nexus passport");

    HCGMonitorReport *m = [HCGMonitorReport reportWithData:HCGTrustFixture(@"monitor.json")];
    HCG_CHECK(m != nil, "monitor parses");
    HCG_CHECK_EQ_INT(m.status, HCGFindingSeverityWarning);
    HCG_CHECK_EQ_INT(m.findings.count, 14);
    HCG_CHECK_EQ_INT([[[m.findings objectAtIndex:0] objectAtIndex:1] integerValue], HCGFindingSeverityWarning); // worst first
    NSString *forged = @"{\"format\":\"hcg.repo.monitor\",\"formatVersion\":1,\"status\":\"ok\",\"checks\":[{\"id\":\"checksums.candidate\",\"status\":\"alert\",\"detail\":\"x\"}]}";
    HCG_CHECK_EQ_INT([HCGMonitorReport reportWithData:[forged dataUsingEncoding:NSUTF8StringEncoding]].status, HCGFindingSeverityAlert);
    HCG_CHECK([HCGMonitorReport reportWithData:HCGTrustFixture(@"compat.json")] == nil, "not a monitor report");
}

// A minimal signed 64-bit Mach-O with an entitlements blob.
static NSData *MachOWithEntitlements(NSString *plist, BOOL fat) {
    NSData *xml = [plist dataUsingEncoding:NSUTF8StringEncoding];
    NSMutableData *sig = [NSMutableData data];
    uint32_t blobLen = (uint32_t)(8 + xml.length), sbLen = 12 + 8 + blobLen;
    uint32_t words[5] = { htonl(0xfade0cc0), htonl(sbLen), htonl(1), htonl(5), htonl(20) };
    [sig appendBytes:words length:20];
    uint32_t blob[2] = { htonl(0xfade7171), htonl(blobLen) };
    [sig appendBytes:blob length:8];
    [sig appendData:xml];
    NSMutableData *macho = [NSMutableData data];
    uint32_t header[8] = { 0xfeedfacf, 0x0100000c, 0, 2, 1, 16, 0, 0 }; // little-endian host
    [macho appendBytes:header length:32];
    uint32_t lc[4] = { 0x1d, 16, 48, (uint32_t)sig.length };
    [macho appendBytes:lc length:16];
    [macho appendData:sig];
    if (!fat) return macho;
    NSMutableData *universal = [NSMutableData data];
    uint32_t fh[2] = { htonl(0xcafebabe), htonl(1) };
    [universal appendBytes:fh length:8];
    uint32_t arch[5] = { htonl(0x0100000c), htonl(0), htonl(64), htonl((uint32_t)macho.length), htonl(14) };
    [universal appendBytes:arch length:20];
    [universal setLength:64];
    [universal appendData:macho];
    return universal;
}

static void testEntitlements(void) {
    NSString *plist = @"<?xml version=\"1.0\" encoding=\"UTF-8\"?><!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">"
                      @"<plist version=\"1.0\"><dict><key>com.apple.private.security.no-sandbox</key><true/><key>application-identifier</key><string>x</string></dict></plist>";
    NSString *error = nil;
    NSDictionary *e = [HCGEntitlements entitlementsInMachO:MachOWithEntitlements(plist, NO) error:&error];
    HCG_CHECK([[e objectForKey:@"com.apple.private.security.no-sandbox"] boolValue], "thin: %s", [error UTF8String]);
    e = [HCGEntitlements entitlementsInMachO:MachOWithEntitlements(plist, YES) error:&error];
    HCG_CHECK(e.count == 2, "fat: %s", [error UTF8String]);
    HCG_CHECK([HCGEntitlements entitlementsInMachO:[@"#!/bin/sh" dataUsingEncoding:NSUTF8StringEncoding] error:&error] == nil && error.length, "not Mach-O");
    NSMutableData *truncated = [MachOWithEntitlements(plist, NO) mutableCopy];
    [truncated setLength:60];
    HCG_CHECK([HCGEntitlements entitlementsInMachO:truncated error:&error] == nil, "truncated");
    HCG_CHECK_EQ_INT([HCGEntitlements riskOfEntitlement:@"com.apple.private.security.no-sandbox"], HCGEntitlementRiskHigh);
    HCG_CHECK_EQ_INT([HCGEntitlements riskOfEntitlement:@"platform-application"], HCGEntitlementRiskHigh);
    HCG_CHECK_EQ_INT([HCGEntitlements riskOfEntitlement:@"com.apple.private.foo"], HCGEntitlementRiskElevated);
    HCG_CHECK_EQ_INT([HCGEntitlements riskOfEntitlement:@"application-identifier"], HCGEntitlementRiskNormal);
}

static void testTrustedRepositoriesAndArtifacts(void) {
    NSArray *repos = [HCGTrustedRepositoryList repositoriesFromStoredValue:nil];
    HCG_CHECK_EQ_INT(repos.count, 2);
    HCG_CHECK([[repos objectAtIndex:0] pinnedFingerprint] == nil && [[repos objectAtIndex:1] pinnedFingerprint] == nil, "nothing pinned by default");
    HCG_CHECK_EQ_INT([HCGTrustedRepositoryList storedValueForRepositories:repos].count, 0);
    HCGTrustedRepository *candidate = [repos objectAtIndex:1];
    candidate.pinnedFingerprint = FounderFingerprint();
    HCGTrustedRepository *custom = [[HCGTrustedRepository alloc] init];
    custom.identifier = @"custom-1";
    custom.name = @"Mirror";
    custom.url = @"https://mirror.example.com/repo/";
    NSArray *stored = [HCGTrustedRepositoryList storedValueForRepositories:[repos arrayByAddingObject:custom]];
    NSArray *back = [HCGTrustedRepositoryList repositoriesFromStoredValue:stored];
    HCG_CHECK_EQ_INT(back.count, 3);
    HCG_CHECK_EQ_STR([[back objectAtIndex:1] pinnedFingerprint], FounderFingerprint());
    HCG_CHECK([[back objectAtIndex:2] url] != nil && ![[back objectAtIndex:2] builtIn], "custom kept");
    HCG_CHECK_EQ_INT([HCGTrustedRepositoryList repositoriesFromStoredValue:@"junk"].count, 2);
    NSArray *junk = [NSArray arrayWithObject:[NSDictionary dictionaryWithObjectsAndKeys:@"custom-2", @"id", @"http://evil.example.com/", @"url", nil]];
    HCG_CHECK_EQ_INT([HCGTrustedRepositoryList repositoriesFromStoredValue:junk].count, 2); // http refused

    HCG_CHECK_EQ_STR([HCGTrustedRepositoryList normalizedRepositoryURL:@" https://Repo.Example.com/apt " reason:NULL], @"https://repo.example.com/apt/");
    NSArray *badURLs = [NSArray arrayWithObjects:@"http://repo.example.com/", @"https://user:pw@repo.example.com/", @"https://repo.example.com:8080/",
                        @"https://repo.example.com/?x=1", @"https://repo.example.com/#f", @"ftp://x", @"https://localhost/", @"", nil];
    for (NSString *u in badURLs) HCG_CHECK([HCGTrustedRepositoryList normalizedRepositoryURL:u reason:NULL] == nil, "refused %s", [u UTF8String]);
    HCG_CHECK_EQ_STR([HCGTrustedRepositoryList normalizedFingerprint:@"ac5d 9f79 03cf 8ad2 5747  b80b 3939 dc11 09be cabf"], @"AC5D9F7903CF8AD25747B80B3939DC1109BECABF");
    HCG_CHECK([HCGTrustedRepositoryList normalizedFingerprint:@"zz"] == nil, "bad fingerprint");

    // Verified artifact: the bytes handed over are the bytes verified.
    NSString *dir = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"hcg-trust-%d", (int)getpid()]];
    NSString *download = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"hcg-download-%d.part", (int)getpid()]];
    NSData *bytes = HCGTrustFixture(@"Packages");
    NSString *sha = [HCGDigest hexDigestOfData:bytes algorithm:HCGDigestAlgorithmSHA256];
    [bytes writeToFile:download atomically:NO];
    NSString *error = nil;
    HCGVerifiedArtifact *artifact = [HCGVerifiedArtifact verifyDownloadAtPath:download expectedSHA256:sha expectedSize:bytes.length intoDirectory:dir error:&error];
    HCG_CHECK(artifact != nil, "verified: %s", [error UTF8String]);
    HCG_CHECK([artifact.path hasSuffix:[sha stringByAppendingString:@".deb"]], "named by SHA-256");
    struct stat st;
    HCG_CHECK(stat([artifact.path fileSystemRepresentation], &st) == 0 && (st.st_mode & 0222) == 0, "read-only");
    HCG_CHECK([artifact stillMatches:NULL], "unchanged");
    chmod([artifact.path fileSystemRepresentation], 0644);
    NSMutableData *changed = [bytes mutableCopy];
    ((uint8_t *)changed.mutableBytes)[0] ^= 1;
    [changed writeToFile:artifact.path atomically:NO];
    NSString *reason = nil;
    HCG_CHECK(![artifact stillMatches:&reason] && reason.length, "a changed file is caught before hand-off");
    [bytes writeToFile:download atomically:NO];
    HCG_CHECK([HCGVerifiedArtifact verifyDownloadAtPath:download expectedSHA256:sha expectedSize:bytes.length + 1 intoDirectory:dir error:&error] == nil, "size mismatch refused");
    HCG_CHECK(![[NSFileManager defaultManager] fileExistsAtPath:download], "a mismatching download is deleted");
    [[NSFileManager defaultManager] removeItemAtPath:dir error:NULL];
}

void HCGRunTrustChainTests(void) {
    HCG_RUN(testReleaseParsing);
    HCG_RUN(testUnsignedLiveRepository);
    HCG_RUN(testSignedRepository);
    HCG_RUN(testPackageAssessment);
    HCG_RUN(testPassportsAndMonitor);
    HCG_RUN(testEntitlements);
    HCG_RUN(testTrustedRepositoriesAndArtifacts);
}
