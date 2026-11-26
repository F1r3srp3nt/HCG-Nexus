#import "HCGRepoTrust.h"
#import "HCGDigest.h"
#import "HCGPackageIndex.h"
#include <time.h>

@implementation HCGReleaseFile
@synthesize fields = _fields, sha256 = _sha256, date = _date, validUntil = _validUntil;

+ (NSDate *)dateFromRFC2822:(NSString *)text {
    if (![text isKindOfClass:[NSString class]]) return nil;
    NSArray *raw = [[text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] componentsSeparatedByString:@" "];
    NSMutableArray *parts = [NSMutableArray array];
    for (NSString *p in raw) if (p.length) [parts addObject:p];
    if (parts.count >= 1 && [[parts objectAtIndex:0] hasSuffix:@","]) [parts removeObjectAtIndex:0];
    if (parts.count < 5) return nil;
    NSArray *months = [NSArray arrayWithObjects:@"Jan", @"Feb", @"Mar", @"Apr", @"May", @"Jun", @"Jul", @"Aug", @"Sep", @"Oct", @"Nov", @"Dec", nil];
    NSUInteger month = [months indexOfObject:[parts objectAtIndex:1]];
    NSArray *hms = [[parts objectAtIndex:3] componentsSeparatedByString:@":"];
    if (month == NSNotFound || hms.count != 3) return nil;
    NSString *zone = [parts objectAtIndex:4];
    long offset = 0;
    if ([zone isEqualToString:@"GMT"] || [zone isEqualToString:@"UTC"] || [zone isEqualToString:@"Z"]) offset = 0;
    else if (zone.length == 5 && ([zone hasPrefix:@"+"] || [zone hasPrefix:@"-"])) {
        long hh = [[zone substringWithRange:NSMakeRange(1, 2)] integerValue], mm = [[zone substringWithRange:NSMakeRange(3, 2)] integerValue];
        offset = (hh * 3600 + mm * 60) * ([zone hasPrefix:@"-"] ? -1 : 1);
    } else return nil;
    struct tm t;
    memset(&t, 0, sizeof(t));
    t.tm_mday = (int)[[parts objectAtIndex:0] integerValue];
    t.tm_mon = (int)month;
    t.tm_year = (int)[[parts objectAtIndex:2] integerValue] - 1900;
    t.tm_hour = (int)[[hms objectAtIndex:0] integerValue];
    t.tm_min = (int)[[hms objectAtIndex:1] integerValue];
    t.tm_sec = (int)[[hms objectAtIndex:2] integerValue];
    if (t.tm_mday < 1 || t.tm_mday > 31 || t.tm_year < 70) return nil;
    time_t seconds = timegm(&t);
    return [NSDate dateWithTimeIntervalSince1970:(double)seconds - offset];
}

+ (instancetype)releaseWithData:(NSData *)data {
    NSString *text = data ? [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] : nil;
    if (!text.length) return nil;
    NSMutableDictionary *fields = [NSMutableDictionary dictionary], *sha = [NSMutableDictionary dictionary];
    NSString *section = nil;
    for (NSString *rawLine in [[text stringByReplacingOccurrencesOfString:@"\r" withString:@""] componentsSeparatedByString:@"\n"]) {
        if (rawLine.length == 0) continue;
        if ([rawLine hasPrefix:@" "] || [rawLine hasPrefix:@"\t"]) {
            if (![section isEqualToString:@"SHA256"]) continue;
            NSMutableArray *parts = [NSMutableArray array];
            for (NSString *p in [rawLine componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]) if (p.length) [parts addObject:p];
            if (parts.count == 3 && [[parts objectAtIndex:0] length] == 64) {
                [sha setObject:[NSArray arrayWithObjects:[[parts objectAtIndex:0] lowercaseString], [parts objectAtIndex:1], nil] forKey:[parts objectAtIndex:2]];
            }
            continue;
        }
        NSRange colon = [rawLine rangeOfString:@":"];
        if (colon.location == NSNotFound) { section = nil; continue; }
        NSString *key = [rawLine substringToIndex:colon.location];
        NSString *value = [[rawLine substringFromIndex:colon.location + 1] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        section = key;
        if (value.length) [fields setObject:value forKey:key];
    }
    if (!fields.count) return nil;
    HCGReleaseFile *release = [[HCGReleaseFile alloc] init];
    release.fields = fields;
    release.sha256 = sha;
    release.date = [self dateFromRFC2822:[fields objectForKey:@"Date"]];
    release.validUntil = [self dateFromRFC2822:[fields objectForKey:@"Valid-Until"]];
    return release;
}
@end

@implementation HCGRepositoryEvidence
@synthesize expectedSuite = _expectedSuite, lastReleaseDate = _lastReleaseDate, knownRevokedFingerprints = _knownRevokedFingerprints;
@synthesize repositoryURL = _repositoryURL, releaseData = _releaseData, inRelease = _inRelease, releaseSignature = _releaseSignature,
            packages = _packages, packagesPath = _packagesPath, publishedKey = _publishedKey,
            pinnedFingerprint = _pinnedFingerprint, now = _now;
@end

@implementation HCGRepositoryReport
@synthesize revokedFingerprints = _revokedFingerprints;
@synthesize authenticity = _authenticity, summary = _summary, rows = _rows, warnings = _warnings, detachedResult = _detachedResult,
            inlineResult = _inlineResult, publishedCertificate = _publishedCertificate, indexConsistent = _indexConsistent,
            releaseFile = _releaseFile, packages = _packages;
@end

@implementation HCGPackageAssessment
@synthesize package = _package, version = _version, authenticity = _authenticity, deviceEvidence = _deviceEvidence,
            checksum = _checksum, authenticityText = _authenticityText, deviceText = _deviceText, warnings = _warnings;
@end

static NSString *HCGNormalizeFingerprint(NSString *f) {
    if (![f isKindOfClass:[NSString class]]) return nil;
    NSString *s = [[[f stringByReplacingOccurrencesOfString:@" " withString:@""] stringByReplacingOccurrencesOfString:@":" withString:@""] uppercaseString];
    return s.length == 40 ? s : nil;
}

static NSArray *Row(NSString *title, NSString *value) {
    return [NSArray arrayWithObjects:title, value ?: @"—", nil];
}

// The most serious state among the supplied signature results.
static HCGAuthenticity CombineSignatures(NSArray *results) {
    BOOL invalid = NO, expired = NO, untrusted = NO;
    for (HCGPGPVerification *v in results) {
        switch (v.status) {
            case HCGPGPStatusGood: break;
            case HCGPGPStatusBad: case HCGPGPStatusMalformed: case HCGPGPStatusKeyRevoked: invalid = YES; break;
            case HCGPGPStatusKeyExpired: case HCGPGPStatusSignatureExpired: expired = YES; break;
            default: untrusted = YES; break;
        }
    }
    if (invalid) return HCGAuthenticityInvalid;
    if (expired) return HCGAuthenticityExpired;
    if (untrusted) return HCGAuthenticityUntrusted;
    return HCGAuthenticityVerified;
}

@implementation HCGRepoTrust

+ (NSString *)titleForAuthenticity:(HCGAuthenticity)a {
    switch (a) {
        case HCGAuthenticityVerified: return @"Verified";
        case HCGAuthenticityUnsigned: return @"Unsigned";
        case HCGAuthenticityUntrusted: return @"Untrusted";
        case HCGAuthenticityExpired: return @"Expired";
        case HCGAuthenticityInvalid: return @"Invalid";
        case HCGAuthenticityUnknown: return @"Not checked";
    }
    return @"Not checked";
}

+ (NSString *)titleForDeviceEvidence:(HCGDeviceEvidence)e {
    switch (e) {
        case HCGDeviceEvidenceLaunchPassed: return @"Launch passed on a device";
        case HCGDeviceEvidenceInstallPassed: return @"Installation passed on a device";
        case HCGDeviceEvidenceUntested: return @"Untested on a device";
        case HCGDeviceEvidenceIncompatible: return @"Incompatible";
        case HCGDeviceEvidenceWithdrawn: return @"Withdrawn";
        case HCGDeviceEvidenceUnknown: return @"No device data";
    }
    return @"No device data";
}

+ (NSArray *)stanzasFromText:(NSString *)text {
    NSMutableArray *out = [NSMutableArray array];
    if (![text isKindOfClass:[NSString class]]) return out;
    NSMutableDictionary *current = nil;
    NSMutableArray *order = nil;
    NSString *lastKey = nil;
    NSArray *lines = [[text stringByReplacingOccurrencesOfString:@"\r" withString:@""] componentsSeparatedByString:@"\n"];
    NSUInteger i;
    for (i = 0; i <= lines.count; i++) {
        NSString *line = i < lines.count ? [lines objectAtIndex:i] : @"";
        if ([[line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] length] == 0) {
            if (current.count) {
                [current setObject:[order copy] forKey:@"_order"];
                [out addObject:[current copy]];
            }
            current = nil;
            order = nil;
            lastKey = nil;
            continue;
        }
        if (!current) {
            current = [NSMutableDictionary dictionary];
            order = [NSMutableArray array];
        }
        unichar first = [line characterAtIndex:0];
        if ((first == ' ' || first == '\t') && lastKey) {
            NSString *more = [line substringFromIndex:1];
            if ([more isEqualToString:@"."]) more = @"";
            [current setObject:[NSString stringWithFormat:@"%@\n%@", [current objectForKey:lastKey], more] forKey:lastKey];
            continue;
        }
        NSRange colon = [line rangeOfString:@":"];
        if (colon.location == NSNotFound || colon.location == 0) continue;
        NSString *key = [line substringToIndex:colon.location];
        if ([key isEqualToString:@"_order"]) continue;
        if (![current objectForKey:key]) [order addObject:key];
        [current setObject:[[line substringFromIndex:colon.location + 1] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] forKey:key];
        lastKey = key;
    }
    return out;
}

+ (HCGRepositoryReport *)evaluate:(HCGRepositoryEvidence *)e {
    HCGRepositoryReport *report = [[HCGRepositoryReport alloc] init];
    NSDate *now = e.now ?: [NSDate date];
    NSMutableArray *rows = [NSMutableArray array], *warnings = [NSMutableArray array];
    [rows addObject:Row(@"Repository", e.repositoryURL)];

    NSString *keyError = nil;
    NSString *pinned = HCGNormalizeFingerprint(e.pinnedFingerprint);
    // With a pin, a key file whose first key is not the pinned one is rejected before any of its signatures is checked.
    HCGPGPCertificate *published = e.publishedKey.length ? [HCGPGPCertificate certificateWithData:e.publishedKey expectedFingerprint:pinned error:&keyError] : nil;
    report.publishedCertificate = published;
    // Revocations this iPhone has seen before stay in force even when the key file no longer carries them.
    NSMutableSet *revoked = [NSMutableSet set];
    for (NSString *f in e.knownRevokedFingerprints ?: [NSArray array]) {
        NSString *n = HCGNormalizeFingerprint(f);
        if (n) [revoked addObject:n];
    }
    if (published) {
        NSMutableArray *keys = [NSMutableArray arrayWithObject:published.primary];
        [keys addObjectsFromArray:published.subkeys];
        for (HCGPGPKey *k in keys) {
            if ([revoked containsObject:k.fingerprint]) k.revoked = YES;
            if (k.revoked) [revoked addObject:k.fingerprint];
        }
    }
    report.revokedFingerprints = [[revoked allObjects] sortedArrayUsingSelector:@selector(compare:)];
    [rows addObject:Row(@"Published key", published ? [HCGPGPCertificate displayFingerprint:published.primary.fingerprint]
                                               : (e.publishedKey.length ? [@"Unreadable: " stringByAppendingString:keyError ?: @""] : @"None published"))];
    [rows addObject:Row(@"Your pinned key", pinned ? [HCGPGPCertificate displayFingerprint:pinned] : @"None: you have not trusted a key for this repository")];
    HCGPGPCertificate *trusted = (published && pinned && [published.primary.fingerprint isEqualToString:pinned]) ? published : nil;

    BOOL hasDetached = e.releaseSignature.length > 0, hasInline = e.inRelease.length > 0;
    HCGAuthenticity authenticity;
    NSData *releaseData = e.releaseData;
    if (!hasDetached && !hasInline) {
        authenticity = HCGAuthenticityUnsigned;
        [rows addObject:Row(@"Signature", @"None: no Release.gpg or InRelease")];
        [warnings addObject:@"The repository is unsigned. HTTPS protects the connection, but nothing proves the index came from the repository's owner."];
    } else if (!pinned) {
        authenticity = HCGAuthenticityUntrusted;
        HCGPGPVerification *probe = published ? (hasInline ? [HCGOpenPGP verifyCleartextMessage:e.inRelease certificate:published now:now]
                                                           : [HCGOpenPGP verifyDetachedSignature:e.releaseSignature data:releaseData ?: [NSData data] certificate:published now:now]) : nil;
        [rows addObject:Row(@"Signature", probe.good ? @"Signed by the repository's published key — which you have not pinned" : @"Signed — key not pinned")];
        [warnings addObject:@"Signed, but you have not pinned this repository's key. Compare its fingerprint with the one HCG publishes before trusting it."];
        report.inlineResult = hasInline ? probe : nil;
        report.detachedResult = hasInline ? nil : probe;
    } else if (!trusted) {
        authenticity = HCGAuthenticityUntrusted;
        if (published) {
            [rows addObject:Row(@"Signature", @"Not checked: the published key is not the key you pinned")];
            [warnings addObject:[NSString stringWithFormat:@"The repository now publishes key %@, not the key you pinned. Do not trust it until HCG announces a key change.", published.primary.keyID]];
        } else {
            [rows addObject:Row(@"Signature", @"Not checked: the pinned key could not be read from the repository")];
            [warnings addObject:@"The repository's key file is missing or unreadable, so its signature cannot be checked."];
        }
    } else {
        NSMutableArray *results = [NSMutableArray array];
        if (hasDetached) {
            report.detachedResult = [HCGOpenPGP verifyDetachedSignature:e.releaseSignature data:releaseData ?: [NSData data] certificate:trusted now:now];
            [results addObject:report.detachedResult];
            [rows addObject:Row(@"Release.gpg", [NSString stringWithFormat:@"%@ — %@", [HCGOpenPGP titleForStatus:report.detachedResult.status], report.detachedResult.detail])];
        }
        if (hasInline) {
            report.inlineResult = [HCGOpenPGP verifyCleartextMessage:e.inRelease certificate:trusted now:now];
            [results addObject:report.inlineResult];
            [rows addObject:Row(@"InRelease", [NSString stringWithFormat:@"%@ — %@", [HCGOpenPGP titleForStatus:report.inlineResult.status], report.inlineResult.detail])];
        }
        authenticity = CombineSignatures(results);
        if (hasInline && report.inlineResult.good) {
            if (releaseData && ![releaseData isEqualToData:report.inlineResult.signedText]) {
                authenticity = HCGAuthenticityInvalid;
                [warnings addObject:@"InRelease and Release differ: the repository serves two different indexes."];
            }
            releaseData = report.inlineResult.signedText; // only signed text is used from here on
        }
        if (hasDetached != hasInline) [warnings addObject:hasInline ? @"Only InRelease is published (Sileo verifies Release.gpg)." : @"Only Release.gpg is published (APT prefers InRelease)."];
        if (authenticity == HCGAuthenticityVerified) {
            [rows addObject:Row(@"Signing key", [NSString stringWithFormat:@"%@ (subkey %@)", [HCGPGPCertificate displayFingerprint:trusted.primary.fingerprint],
                                                (report.inlineResult ?: report.detachedResult).signerKeyID ?: @"—"])];
        }
        if (trusted.primary.expires) {
            NSTimeInterval left = [trusted.primary.expires timeIntervalSinceDate:now];
            if (left > 0 && left < 60 * 86400) [warnings addObject:@"The repository's key expires within 60 days."];
        }
    }

    HCGReleaseFile *release = [HCGReleaseFile releaseWithData:releaseData];
    report.releaseFile = release;
    if (release.date) [rows addObject:Row(@"Release date", [release.date description])];
    if (release.validUntil) {
        [rows addObject:Row(@"Valid until", [release.validUntil description])];
        if ([release.validUntil compare:now] != NSOrderedDescending && authenticity != HCGAuthenticityInvalid) {
            authenticity = HCGAuthenticityExpired;
            [warnings addObject:@"The Release file is past its Valid-Until date: it may be a replayed old index."];
        }
    } else if ([release.fields objectForKey:@"Valid-Until"]) {
        authenticity = HCGAuthenticityInvalid;
        [rows addObject:Row(@"Valid until", @"Unreadable")];
        [warnings addObject:@"The Release file's Valid-Until date cannot be read, so its expiry cannot be checked."];
    } else if (authenticity == HCGAuthenticityVerified) {
        [warnings addObject:@"The Release file has no Valid-Until date: an old signed index could be replayed to a device that has not seen a newer one."];
    }
    // The signed index must be the one for this repository (Suite), and never older than one this iPhone already saw.
    NSString *suite = [release.fields objectForKey:@"Suite"];
    if (suite) [rows addObject:Row(@"Suite", suite)];
    if (release && e.expectedSuite.length && ![suite isEqualToString:e.expectedSuite] &&
        (authenticity == HCGAuthenticityVerified || authenticity == HCGAuthenticityExpired)) {
        authenticity = HCGAuthenticityInvalid;
        [warnings addObject:[NSString stringWithFormat:@"This address serves the '%@' index, not '%@': a signed index from another channel was substituted.",
                                                       suite ?: @"(none)", e.expectedSuite]];
    }
    if (release && e.lastReleaseDate && (authenticity == HCGAuthenticityVerified || authenticity == HCGAuthenticityExpired)) {
        if (!release.date || [release.date compare:e.lastReleaseDate] == NSOrderedAscending) {
            authenticity = HCGAuthenticityInvalid;
            [warnings addObject:@"This signed index is older than one this iPhone has already verified: it may be a replayed old index."];
        }
    }

    // Index consistency: Release names the served Packages file's SHA-256 and size.
    if (e.packages) {
        NSArray *entry = [release.sha256 objectForKey:e.packagesPath ?: @"Packages"];
        NSString *actual = [HCGDigest hexDigestOfData:e.packages algorithm:HCGDigestAlgorithmSHA256];
        report.indexConsistent = entry && [HCGDigest hexString:[entry objectAtIndex:0] equalsHexString:actual] &&
                                 [[entry objectAtIndex:1] longLongValue] == (long long)e.packages.length;
        [rows addObject:Row(@"Index", report.indexConsistent ? @"Packages matches the SHA-256 and size in Release"
                                                            : (entry ? @"MISMATCH: Packages differs from what Release lists" : @"Release does not list Packages"))];
        if (!report.indexConsistent) {
            authenticity = HCGAuthenticityInvalid;
            [warnings addObject:@"The package index does not match the Release file: do not install from this repository until it is fixed."];
        }
        report.packages = [self stanzasFromText:[[NSString alloc] initWithData:e.packages encoding:NSUTF8StringEncoding]];
    } else {
        report.packages = [NSArray array];
        if (authenticity == HCGAuthenticityVerified) authenticity = HCGAuthenticityUnknown;
    }
    if (!release && authenticity != HCGAuthenticityInvalid) {
        authenticity = HCGAuthenticityUnknown;
        [warnings addObject:@"The Release file could not be read."];
    }

    report.authenticity = authenticity;
    switch (authenticity) {
        case HCGAuthenticityVerified: report.summary = @"Verified: signed by the key you pinned, and the index matches. This proves origin, not safety."; break;
        case HCGAuthenticityUnsigned: report.summary = @"Unsigned: the index is consistent, but nothing proves who published it."; break;
        case HCGAuthenticityUntrusted: report.summary = @"Untrusted: not signed by a key you pinned."; break;
        case HCGAuthenticityExpired: report.summary = @"Expired: the key, signature or Release validity has run out."; break;
        case HCGAuthenticityInvalid: report.summary = @"Invalid: a signature or checksum does not match. Do not install from it."; break;
        case HCGAuthenticityUnknown: report.summary = @"Not checked: the repository could not be read completely."; break;
    }
    report.rows = rows;
    report.warnings = warnings;
    return report;
}

+ (NSString *)firmwareProblemInDepends:(NSString *)depends ios:(NSString *)ios {
    if (![depends isKindOfClass:[NSString class]] || ![HCGDebianVersion isValid:ios]) return nil;
    for (NSString *raw in [depends componentsSeparatedByString:@","]) {
        NSString *item = [raw stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        if (![item hasPrefix:@"firmware"] || [item rangeOfString:@"|"].location != NSNotFound) continue;
        NSRange open = [item rangeOfString:@"("], close = [item rangeOfString:@")"];
        if (open.location == NSNotFound || close.location == NSNotFound || close.location < open.location) continue;
        NSArray *parts = [[[item substringWithRange:NSMakeRange(open.location + 1, close.location - open.location - 1)]
                           stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] componentsSeparatedByString:@" "];
        if (parts.count != 2) continue;
        NSString *op = [parts objectAtIndex:0], *version = [parts objectAtIndex:1];
        NSComparisonResult c = [HCGDebianVersion compare:ios with:version];
        BOOL ok = YES;
        if ([op isEqualToString:@">="]) ok = c != NSOrderedAscending;
        else if ([op isEqualToString:@"<<"]) ok = c == NSOrderedAscending;
        else if ([op isEqualToString:@"<="]) ok = c != NSOrderedDescending;
        else if ([op isEqualToString:@">>"]) ok = c == NSOrderedDescending;
        else if ([op isEqualToString:@"="]) ok = c == NSOrderedSame;
        if (!ok) return [NSString stringWithFormat:@"Requires firmware %@ %@; this iPhone runs iOS %@.", op, version, ios];
    }
    return nil;
}

+ (HCGPackageAssessment *)assessPackage:(NSDictionary *)stanza repository:(HCGRepositoryReport *)repository
                          compatibility:(NSDictionary *)compatibility deviceIOS:(NSString *)deviceIOS
                       downloadedSHA256:(NSString *)downloadedSHA256 downloadedSize:(unsigned long long)downloadedSize {
    HCGPackageAssessment *a = [[HCGPackageAssessment alloc] init];
    a.package = [stanza objectForKey:@"Package"] ?: @"";
    a.version = [stanza objectForKey:@"Version"] ?: @"";
    NSMutableArray *warnings = [NSMutableArray array];
    NSString *indexSHA = [[stanza objectForKey:@"SHA256"] lowercaseString];
    long long indexSize = [[stanza objectForKey:@"Size"] longLongValue];
    HCGAuthenticity authenticity = repository ? repository.authenticity : HCGAuthenticityUnknown;
    if (indexSHA.length != 64) {
        [warnings addObject:@"The index gives no SHA-256 for this package, so a download cannot be checked."];
        if (authenticity == HCGAuthenticityVerified) authenticity = HCGAuthenticityUntrusted;
    }

    a.checksum = HCGChecksumStateNotDownloaded;
    if (downloadedSHA256.length) {
        BOOL match = [HCGDigest hexString:downloadedSHA256 equalsHexString:indexSHA] && (indexSize <= 0 || (unsigned long long)indexSize == downloadedSize);
        a.checksum = match ? HCGChecksumStateMatches : HCGChecksumStateMismatch;
        if (!match) {
            authenticity = HCGAuthenticityInvalid;
            [warnings addObject:@"The downloaded file does not match the index (SHA-256 or size): it was changed or corrupted. Delete it."];
        }
    }
    a.authenticity = authenticity;
    NSString *bytesNote = a.checksum == HCGChecksumStateMatches ? @"The download matches the index SHA-256 and size. "
                        : (a.checksum == HCGChecksumStateNotDownloaded ? @"Not downloaded; a download is checked against the index SHA-256 and size. " : @"");
    switch (authenticity) {
        case HCGAuthenticityVerified:
            a.authenticityText = [bytesNote stringByAppendingString:@"The index is signed by the key you pinned. That proves origin and integrity, not that the package is safe."];
            break;
        case HCGAuthenticityUnsigned:
            a.authenticityText = [bytesNote stringByAppendingString:@"The repository is unsigned, so a matching checksum only shows the file is the one the index names — not who published it."];
            break;
        case HCGAuthenticityUntrusted:
            a.authenticityText = [bytesNote stringByAppendingString:@"The index is not signed by a key you pinned."];
            break;
        case HCGAuthenticityExpired:
            a.authenticityText = [bytesNote stringByAppendingString:@"The repository's signature or key has expired."];
            break;
        case HCGAuthenticityInvalid:
            a.authenticityText = @"A signature or checksum does not match. Do not install.";
            break;
        case HCGAuthenticityUnknown:
            a.authenticityText = @"Not checked yet.";
            break;
    }

    // Device evidence: firmware requirement first, then HCG Repo's compatibility registry.
    NSString *firmware = [self firmwareProblemInDepends:[stanza objectForKey:@"Depends"] ios:deviceIOS];
    HCGDeviceEvidence evidence = HCGDeviceEvidenceUnknown;
    NSString *deviceText = @"HCG Repo does not publish device test results yet, so this version counts as untested here.";
    if ([compatibility isKindOfClass:[NSDictionary class]]) {
        NSString *status = [compatibility objectForKey:@"status"];
        if (![status isKindOfClass:[NSString class]]) status = @"";
        if ([status isEqualToString:@"Physical launch passed"]) evidence = HCGDeviceEvidenceLaunchPassed;
        else if ([status isEqualToString:@"Physical installation passed"]) evidence = HCGDeviceEvidenceInstallPassed;
        else if ([status isEqualToString:@"Known incompatible"]) evidence = HCGDeviceEvidenceIncompatible;
        else if ([status isEqualToString:@"Withdrawn"]) evidence = HCGDeviceEvidenceWithdrawn;
        else evidence = HCGDeviceEvidenceUntested;
        deviceText = [NSString stringWithFormat:@"HCG Repo: %@.", status.length ? status : @"no status"];
        id failures = [compatibility objectForKey:@"known_failures"];
        for (id failure in [failures isKindOfClass:[NSArray class]] ? failures : [NSArray array]) {
            if (![failure isKindOfClass:[NSDictionary class]]) continue;
            NSString *line = [NSString stringWithFormat:@"Known failure: %@ on %@, iOS %@, %@ (%@).",
                              [failure objectForKey:@"stage"] ?: @"failure", [failure objectForKey:@"device"] ?: @"a device",
                              [failure objectForKey:@"ios"] ?: @"?", [failure objectForKey:@"jailbreak"] ?: @"?", [failure objectForKey:@"date"] ?: @"?"];
            [warnings addObject:line];
        }
        id download = [compatibility objectForKey:@"download"];
        NSString *registrySHA = [download isKindOfClass:[NSDictionary class]] ? [download objectForKey:@"sha256"] : nil;
        if ([registrySHA isKindOfClass:[NSString class]] && indexSHA.length == 64 && ![HCGDigest hexString:registrySHA equalsHexString:indexSHA]) {
            [warnings addObject:@"HCG Repo's compatibility registry names different bytes for this version than the index."];
        }
        id label = [compatibility objectForKey:@"label"];
        if ([label isKindOfClass:[NSString class]] && [label length]) deviceText = [deviceText stringByAppendingFormat:@" %@", label];
    }
    if (firmware) {
        evidence = HCGDeviceEvidenceIncompatible;
        deviceText = firmware;
    }
    a.deviceEvidence = evidence;
    a.deviceText = deviceText;
    a.warnings = warnings;
    return a;
}

@end
