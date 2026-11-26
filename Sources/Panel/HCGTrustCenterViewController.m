#import "HCGTrustCenterViewController.h"
#import "HCGTheme.h"
#import "HCGTrustFetcher.h"

#pragma mark - Shared state

// One read of every trusted repository plus this iPhone's package facts.
@interface HCGTrustSnapshot : NSObject
@property (nonatomic, copy) NSArray<HCGTrustedRepository *> *repositories;
@property (nonatomic, strong) NSMutableDictionary<NSString *, HCGRepositoryReport *> *reports;       // repository id ->
@property (nonatomic, strong) NSMutableDictionary<NSString *, HCGTrustFetchResult *> *fetches;       // repository id ->
@property (nonatomic, copy) NSDictionary *environment;                                               // trustEnvironment
@property (nonatomic, copy) NSString *deviceIOS;
- (nullable HCGCompatibilityRegistry *)compatibility;
@end

@implementation HCGTrustSnapshot
- (HCGCompatibilityRegistry *)compatibility {
    for (HCGTrustFetchResult *r in self.fetches.allValues) if (r.compatibility) return r.compatibility;
    return nil;
}
@end

static UIColor *HCGColorForAuthenticity(HCGAuthenticity a) {
    switch (a) {
        case HCGAuthenticityVerified: return [HCGTheme success];
        case HCGAuthenticityUnsigned: case HCGAuthenticityUntrusted: case HCGAuthenticityExpired: return [HCGTheme warning];
        case HCGAuthenticityInvalid: return [HCGTheme critical];
        case HCGAuthenticityUnknown: return [HCGTheme secondaryText];
    }
    return [HCGTheme secondaryText];
}

static UIColor *HCGColorForEvidence(HCGDeviceEvidence e) {
    switch (e) {
        case HCGDeviceEvidenceLaunchPassed: return [HCGTheme success];
        case HCGDeviceEvidenceInstallPassed: return [HCGTheme cyan];
        case HCGDeviceEvidenceIncompatible: case HCGDeviceEvidenceWithdrawn: return [HCGTheme critical];
        default: return [HCGTheme secondaryText];
    }
}

static UILabel *HCGTrustChip(NSString *text, UIColor *color) {
    UILabel *chip = [[UILabel alloc] init];
    chip.text = [NSString stringWithFormat:@"  %@  ", text];
    chip.font = [HCGTheme fontForTextStyle:UIFontTextStyleCaption1 weight:UIFontWeightSemibold maximumPointSize:HCGChipMaximumPointSize];
    chip.textColor = color;
    chip.backgroundColor = [color colorWithAlphaComponent:0.14];
    chip.layer.borderColor = [color colorWithAlphaComponent:0.7].CGColor;
    chip.layer.borderWidth = 1;
    chip.layer.cornerRadius = 9;
    chip.clipsToBounds = YES;
    [chip sizeToFit];
    chip.frame = CGRectMake(0, 0, CGRectGetWidth(chip.frame), MAX(20, CGRectGetHeight(chip.frame) + 4));
    return chip;
}

static UITableViewCell *HCGTextCell(HCGPanelTableViewController *vc, NSString *title, NSString *detail) {
    UITableViewCell *cell = [vc styledCellWithStyle:UITableViewCellStyleSubtitle identifier:@"text"];
    cell.textLabel.text = title;
    cell.textLabel.numberOfLines = 0;
    cell.detailTextLabel.text = detail;
    cell.detailTextLabel.numberOfLines = 0;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.accessoryView = nil;
    cell.imageView.image = nil;
    return cell;
}

static NSArray *HCGHCGPackages(HCGTrustSnapshot *s) {
    // Latest version of every HCG package across the checked repositories (Candidate wins ties: it is listed last).
    NSMutableDictionary *best = [NSMutableDictionary dictionary], *source = [NSMutableDictionary dictionary];
    for (HCGTrustedRepository *repo in s.repositories) {
        HCGRepositoryReport *report = s.reports[repo.identifier];
        for (NSDictionary *stanza in report.packages) {
            NSString *package = stanza[@"Package"];
            if (![package hasPrefix:@"com.hakmicapitalgroup."]) continue;
            NSDictionary *current = best[package];
            if (!current || [HCGDebianVersion compare:stanza[@"Version"] with:current[@"Version"]] != NSOrderedAscending) {
                best[package] = stanza;
                source[package] = repo;
            }
        }
    }
    NSMutableArray *out = [NSMutableArray array];
    for (NSString *package in [best.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
        [out addObject:@[ best[package], source[package] ]];
    }
    return out;
}

// The index entry for an exact installed version, and the repository that lists it.
static NSArray *HCGFindStanza(HCGTrustSnapshot *s, NSString *package, NSString *version) {
    for (HCGTrustedRepository *repo in s.repositories) {
        for (NSDictionary *stanza in s.reports[repo.identifier].packages) {
            if ([stanza[@"Package"] isEqualToString:package] && [stanza[@"Version"] isEqualToString:version]) return @[ stanza, repo ];
        }
    }
    return nil;
}

#pragma mark - Repository page

@interface HCGTrustRepositoryViewController : HCGPanelTableViewController
- (instancetype)initWithContext:(HCGPanelContext *)context repository:(HCGTrustedRepository *)repository
                         report:(HCGRepositoryReport *)report fetch:(HCGTrustFetchResult *)fetch keyring:(NSData *)keyring;
@property (nonatomic, copy) void (^onChange)(void);
@end

@implementation HCGTrustRepositoryViewController {
    HCGTrustedRepository *_repository;
    HCGRepositoryReport *_report;
    HCGTrustFetchResult *_fetch;
    HCGPGPCertificate *_keyringCertificate;
    NSArray<NSArray *> *_sections; // (title, rows, footer)
}

- (instancetype)initWithContext:(HCGPanelContext *)context repository:(HCGTrustedRepository *)repository
                         report:(HCGRepositoryReport *)report fetch:(HCGTrustFetchResult *)fetch keyring:(NSData *)keyring {
    if ((self = [super initWithContext:context])) {
        _repository = repository;
        _report = report;
        _fetch = fetch;
        _keyringCertificate = keyring.length ? [HCGPGPCertificate certificateWithData:keyring error:NULL] : nil;
        self.title = repository.name;
        [self build];
    }
    return self;
}

- (void)build {
    NSMutableArray *sections = [NSMutableArray array];
    [sections addObject:@[ @"Status", @[ @[ [HCGRepoTrust titleForAuthenticity:_report.authenticity], _report.summary ?: @"" ] ], @"" ]];
    [sections addObject:@[ @"Evidence", _report.rows ?: @[], @"" ]];
    NSMutableArray *files = [NSMutableArray array];
    for (NSString *file in [_fetch.fileStates.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
        NSString *state = _fetch.fileStates[file];
        [files addObject:@[ file, [state isEqualToString:@"200"] ? @"Published" : ([state isEqualToString:@"404"] ? @"Not published" : state) ]];
    }
    if (files.count) [sections addObject:@[ @"Files read", files, @"Read over HTTPS without cookies or credentials; redirects are refused." ]];
    NSMutableArray *warnings = [NSMutableArray array];
    for (NSString *w in _report.warnings) [warnings addObject:@[ @"Warning", w ]];
    if (warnings.count) [sections addObject:@[ @"Warnings", warnings, @"" ]];

    HCGPGPCertificate *key = _report.publishedCertificate ?: _keyringCertificate;
    NSMutableArray *keyRows = [NSMutableArray array];
    if (key) {
        HCGPGPKey *p = key.primary;
        [keyRows addObject:@[ _report.publishedCertificate ? @"Published key" : @"HCG Repo Keyring (installed)", [HCGPGPCertificate displayFingerprint:p.fingerprint] ]];
        for (NSString *uid in key.userIDs) [keyRows addObject:@[ @"User ID", uid ]];
        [keyRows addObject:@[ @"Primary", [NSString stringWithFormat:@"%@ %lu · created %@ · %@%@", p.algorithmName, (unsigned long)p.bits, [p.created description],
                                         p.expires ? [@"expires " stringByAppendingString:[p.expires description]] : @"no expiry", p.revoked ? @" · REVOKED" : @""] ]];
        for (HCGPGPKey *sub in key.subkeys) {
            [keyRows addObject:@[ [@"Subkey " stringByAppendingString:sub.keyID],
                                  [NSString stringWithFormat:@"%@ %lu · %@%@%@", sub.algorithmName, (unsigned long)sub.bits, sub.canSign ? @"signs" : @"does not sign",
                                   sub.expires ? [@" · expires " stringByAppendingString:[sub.expires description]] : @"", sub.revoked ? @" · REVOKED" : (sub.bound ? @"" : @" · not bound")] ]];
        }
        for (NSString *problem in key.problems) [keyRows addObject:@[ @"Note", problem ]];
    } else {
        [keyRows addObject:@[ @"Key", @"This repository publishes no signing key. HCG Repo is unsigned until its owner creates the production key (HCG-repo docs/SIGNING.md)." ]];
    }
    if (_repository.pinnedFingerprint) [keyRows addObject:@[ @"You pinned", [HCGPGPCertificate displayFingerprint:_repository.pinnedFingerprint] ]];
    [sections addObject:@[ @"Signing key", keyRows, @"Pinning a key means Nexus accepts this repository's index only when that key signed it. Compare the fingerprint with the one HCG publishes before you pin it." ]];
    _sections = sections;
}

- (HCGPGPCertificate *)pinCandidate {
    return _report.publishedCertificate ?: _keyringCertificate;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return (NSInteger)_sections.count + 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return section < (NSInteger)_sections.count ? _sections[section][0] : @"Trust";
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section < (NSInteger)_sections.count) {
        NSString *f = _sections[section][2];
        return f.length ? f : nil;
    }
    return @"Nothing here changes Sileo, Zebra or APT. To make Sileo or APT check signatures too, install HCG Repo Keyring from HCG Repo once it exists.";
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section < (NSInteger)_sections.count) return (NSInteger)[_sections[section][1] count];
    return 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section < (NSInteger)_sections.count) {
        NSArray *row = _sections[indexPath.section][1][indexPath.row];
        UITableViewCell *cell = HCGTextCell(self, row[0], row[1]);
        if (indexPath.section == 0) cell.accessoryView = HCGTrustChip([HCGRepoTrust titleForAuthenticity:_report.authenticity], HCGColorForAuthenticity(_report.authenticity));
        return cell;
    }
    UITableViewCell *cell = [self styledCellWithStyle:UITableViewCellStyleDefault identifier:@"action"];
    cell.accessoryView = nil;
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    if (_repository.pinnedFingerprint) {
        cell.textLabel.text = @"Remove Trust in This Key…";
        cell.textLabel.textColor = [HCGTheme critical];
    } else if ([self pinCandidate]) {
        cell.textLabel.text = @"Trust This Key…";
        cell.textLabel.textColor = [HCGTheme cyan];
    } else {
        cell.textLabel.text = @"No key to trust yet";
        cell.textLabel.textColor = [HCGTheme secondaryText];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section != (NSInteger)_sections.count) return;
    if (_repository.pinnedFingerprint) [self confirmRemoval];
    else if ([self pinCandidate]) [self confirmPin];
}

- (void)savePin:(NSString *)fingerprint {
    NSMutableArray *repos = [[self.context.model trustedRepositories] mutableCopy];
    for (HCGTrustedRepository *r in repos) {
        if (![r.identifier isEqualToString:_repository.identifier]) continue;
        r.pinnedFingerprint = fingerprint;
        r.pinnedAt = fingerprint ? [NSDate date] : nil;
        r.lastReleaseDate = nil; // the replay memory belongs to the key it was verified with; revocations are kept
        if (!r.builtIn) r.expectedSuite = nil;
    }
    [self.context.model saveTrustedRepositories:repos];
    _repository.pinnedFingerprint = fingerprint;
    NSString *text = fingerprint ? [NSString stringWithFormat:@"Pinned key %@ for %@", [fingerprint substringFromIndex:24], _repository.name]
                                 : [NSString stringWithFormat:@"Removed the pinned key for %@", _repository.name];
    [self.context.model recordEcosystemActivity:text productID:HCGHIPProductRepo];
    [self build];
    [self.tableView reloadData];
    if (self.onChange) self.onChange();
}

- (void)confirmPin {
    HCGPGPCertificate *key = [self pinCandidate];
    NSString *message = [NSString stringWithFormat:@"%@\n\n%@\n\nCompare every character with the fingerprint HCG publishes (website, HCG-repo docs/SIGNING.md). After this, Nexus reports %@ as Verified only when this key signed its index.",
                         key.userIDs.firstObject ?: @"(no user ID)", [HCGPGPCertificate displayFingerprint:key.primary.fingerprint], _repository.name];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Trust This Key?" message:message preferredStyle:UIAlertControllerStyleAlert];
    alert.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    __weak typeof(self) weakSelf = self;
    NSString *fingerprint = key.primary.fingerprint;
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"I Compared It — Trust" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        [weakSelf savePin:fingerprint];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)confirmRemoval {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Remove Trust?"
                                                                   message:@"Nexus will report this repository as Untrusted until you pin a key again."
                                                            preferredStyle:UIAlertControllerStyleAlert];
    alert.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Remove" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a) { [weakSelf savePin:nil]; }]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end

#pragma mark - Package page

@interface HCGTrustPackageViewController : HCGPanelTableViewController
- (instancetype)initWithContext:(HCGPanelContext *)context stanza:(NSDictionary *)stanza repository:(HCGTrustedRepository *)repository
                       snapshot:(HCGTrustSnapshot *)snapshot;
@end

@implementation HCGTrustPackageViewController {
    NSDictionary *_stanza;
    HCGTrustedRepository *_repository;
    HCGTrustSnapshot *_snapshot;
    HCGPackageAssessment *_assessment;
    HCGReleasePassport *_passport;
    NSString *_passportState;
    HCGVerifiedArtifact *_artifact;
    NSString *_downloadSHA;
    unsigned long long _downloadSize;
    NSString *_downloadError;
    BOOL _downloading;
    NSArray<NSArray *> *_sections; // (title, rows, footer)
}

- (instancetype)initWithContext:(HCGPanelContext *)context stanza:(NSDictionary *)stanza repository:(HCGTrustedRepository *)repository
                       snapshot:(HCGTrustSnapshot *)snapshot {
    if ((self = [super initWithContext:context])) {
        _stanza = stanza;
        _repository = repository;
        _snapshot = snapshot;
        _passportState = @"Checking…";
        self.title = stanza[@"Name"] ?: stanza[@"Package"];
        [self build];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.estimatedRowHeight = 56;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    __weak typeof(self) weakSelf = self;
    [[HCGTrustFetcher sharedFetcher] fetchPassportForPackage:_stanza[@"Package"] version:_stanza[@"Version"] repository:_repository
                                                  completion:^(HCGReleasePassport *passport, NSString *state) {
        typeof(self) s = weakSelf;
        if (!s) return;
        s->_passport = passport;
        s->_passportState = passport ? @"Published" : ([state isEqualToString:@"404"] ? @"HCG Repo does not publish Release Passports yet (they are derived records today)." : state);
        [s build];
        [s.tableView reloadData];
    }];
}

- (void)build {
    HCGRepositoryReport *report = _snapshot.reports[_repository.identifier];
    NSDictionary *record = [[_snapshot compatibility] recordForPackage:_stanza[@"Package"] version:_stanza[@"Version"]];
    _assessment = [HCGRepoTrust assessPackage:_stanza repository:report compatibility:record deviceIOS:_snapshot.deviceIOS
                             downloadedSHA256:_downloadSHA downloadedSize:_downloadSize];
    NSMutableArray *sections = [NSMutableArray array];
    [sections addObject:@[ @"Authenticity", @[ @[ [HCGRepoTrust titleForAuthenticity:_assessment.authenticity], _assessment.authenticityText ] ],
                           @"Verified means: the bytes are the ones the repository's pinned key signed for. It is not a safety review." ]];
    [sections addObject:@[ @"This iPhone", @[ @[ [HCGRepoTrust titleForDeviceEvidence:_assessment.deviceEvidence],
                                                [NSString stringWithFormat:@"%@ This iPhone: iOS %@.", _assessment.deviceText, _snapshot.deviceIOS ?: @"?"] ] ], @"" ]];
    NSMutableArray *warnings = [NSMutableArray array];
    for (NSString *w in _assessment.warnings) [warnings addObject:@[ @"Warning", w ]];
    for (NSString *w in _passport.warnings) [warnings addObject:@[ @"Release Passport", w ]];
    for (NSString *w in [_passport warningsAgainstIndexSHA256:_stanza[@"SHA256"]]) [warnings addObject:@[ @"Release Passport", w ]];
    if (warnings.count) [sections addObject:@[ @"Warnings", warnings, @"" ]];

    NSMutableArray *download = [NSMutableArray array];
    if (_artifact) {
        [download addObject:@[ @"Verified download", [NSString stringWithFormat:@"SHA-256 %@\n%llu bytes · kept read-only in Nexus's own folder. Nothing was installed.", _artifact.sha256, _artifact.size] ]];
    } else if (_downloadError) {
        [download addObject:@[ @"Download refused", _downloadError ]];
    }
    [download addObject:@[ _downloading ? @"Downloading…" : (_artifact ? @"Download and Verify Again" : @"Download and Verify"),
                           [NSString stringWithFormat:@"Checks the file against SHA-256 %@ and %@ bytes from the index. Installs nothing.",
                            _stanza[@"SHA256"] ?: @"(none)", _stanza[@"Size"] ?: @"?"] ]];
    [sections addObject:@[ @"Downloaded package", download, @"A future installer integration must hand over exactly these verified bytes and re-check them first; installing will always ask you." ]];

    NSMutableArray *meta = [NSMutableArray array];
    for (NSString *key in _stanza[@"_order"] ?: @[]) {
        NSString *value = _stanza[key];
        if ([key isEqualToString:@"Description"] && value.length > 400) value = [[value substringToIndex:399] stringByAppendingString:@"…"];
        [meta addObject:@[ key, value ?: @"" ]];
    }
    [sections addObject:@[ @"Package metadata", meta, [@"From " stringByAppendingString:_repository.url] ]];

    if (record) {
        NSMutableArray *levels = [NSMutableArray array];
        NSDictionary *l = record[@"levels"];
        for (NSString *k in @[ @"static_inspection", @"maintainer_script_review", @"script_free_lifecycle", @"device_installation", @"application_launch", @"runtime_verification" ]) {
            [levels addObject:@[ [[k stringByReplacingOccurrencesOfString:@"_" withString:@" "] capitalizedString], [l isKindOfClass:[NSDictionary class]] ? (l[k] ?: @"—") : @"—" ]];
        }
        [sections addObject:@[ @"HCG Repo compatibility", levels, record[@"label"] ?: @"" ]];
    }

    NSMutableArray *passport = [NSMutableArray array];
    if (_passport) {
        for (NSArray *section in _passport.sections) for (NSArray *row in section[1]) [passport addObject:@[ [NSString stringWithFormat:@"%@ · %@", section[0], row[0]], row[1] ]];
    } else {
        [passport addObject:@[ @"Release Passport", _passportState ]];
    }
    [sections addObject:@[ @"Release Passport", passport, @"" ]];

    NSMutableArray *ents = [NSMutableArray array];
    for (NSString *binary in _passport.entitlements) {
        for (NSString *k in _passport.entitlements[binary]) {
            [ents addObject:@[ [NSString stringWithFormat:@"Declared · %@", k], [HCGEntitlements explanationOfEntitlement:k] ]];
        }
    }
    HCGHIPProductDescriptor *d = nil;
    for (HCGHIPProductDescriptor *candidate in [HCGInterchange registry]) if ([candidate.packageIdentifier isEqualToString:_stanza[@"Package"]]) d = candidate;
    NSDictionary *actual = d.bundleIdentifier ? _snapshot.environment[@"entitlements"][d.bundleIdentifier] : nil;
    if ([actual isKindOfClass:[NSDictionary class]]) {
        if (actual[@"_unavailable"]) [ents addObject:@[ @"Installed app", actual[@"_unavailable"] ]];
        for (NSString *k in [[actual allKeys] sortedArrayUsingSelector:@selector(compare:)]) {
            if ([k hasPrefix:@"_"]) continue;
            HCGEntitlementRisk risk = [HCGEntitlements riskOfEntitlement:k];
            [ents addObject:@[ [NSString stringWithFormat:@"Installed app · %@%@", k, risk == HCGEntitlementRiskHigh ? @" (high)" : (risk == HCGEntitlementRiskElevated ? @" (elevated)" : @"")],
                               [HCGEntitlements explanationOfEntitlement:k] ]];
        }
    }
    if (!ents.count) [ents addObject:@[ @"Entitlements", d.bundleIdentifier ? @"Not installed here, and no Release Passport published." : @"A tweak: entitlements apply to apps and tools; none declared." ]];
    [sections addObject:@[ @"Entitlements", ents, @"Declared: what the Release Passport records. Installed app: read from the app on this iPhone." ]];
    _sections = sections;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return (NSInteger)_sections.count; }
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section { return _sections[section][0]; }
- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    NSString *f = _sections[section][2];
    return f.length ? f : nil;
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return (NSInteger)[_sections[section][1] count]; }

- (BOOL)isDownloadRow:(NSIndexPath *)indexPath {
    NSArray *rows = _sections[indexPath.section][1];
    return [_sections[indexPath.section][0] isEqualToString:@"Downloaded package"] && indexPath.row == (NSInteger)rows.count - 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSArray *row = _sections[indexPath.section][1][indexPath.row];
    UITableViewCell *cell = HCGTextCell(self, row[0], row[1]);
    NSString *title = _sections[indexPath.section][0];
    if ([title isEqualToString:@"Authenticity"]) cell.accessoryView = HCGTrustChip([HCGRepoTrust titleForAuthenticity:_assessment.authenticity], HCGColorForAuthenticity(_assessment.authenticity));
    if ([title isEqualToString:@"This iPhone"]) cell.accessoryView = HCGTrustChip(_assessment.deviceEvidence == HCGDeviceEvidenceIncompatible ? @"Incompatible" : (_assessment.deviceEvidence == HCGDeviceEvidenceUntested || _assessment.deviceEvidence == HCGDeviceEvidenceUnknown ? @"Untested" : @"Tested"), HCGColorForEvidence(_assessment.deviceEvidence));
    if ([self isDownloadRow:indexPath]) {
        cell.textLabel.textColor = _downloading ? [HCGTheme secondaryText] : [HCGTheme cyan];
        cell.selectionStyle = _downloading ? UITableViewCellSelectionStyleNone : UITableViewCellSelectionStyleDefault;
        cell.accessibilityTraits = UIAccessibilityTraitButton;
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (![self isDownloadRow:indexPath] || _downloading) return;
    _downloading = YES;
    _downloadError = nil;
    [self build];
    [tableView reloadData];
    __weak typeof(self) weakSelf = self;
    [[HCGTrustFetcher sharedFetcher] downloadPackage:_stanza repository:_repository completion:^(HCGVerifiedArtifact *artifact, NSString *sha, unsigned long long size, NSString *error) {
        typeof(self) s = weakSelf;
        if (!s) return;
        s->_downloading = NO;
        s->_artifact = artifact;
        s->_downloadSHA = sha;
        s->_downloadSize = size;
        s->_downloadError = artifact ? nil : (error ?: @"The download failed.");
        NSString *name = s->_stanza[@"Name"] ?: s->_stanza[@"Package"];
        [s.context.model recordEcosystemActivity:artifact ? [NSString stringWithFormat:@"Downloaded and verified %@ %@ (not installed)", name, s->_stanza[@"Version"]]
                                                          : [NSString stringWithFormat:@"Download of %@ %@ refused: checksum did not match or download failed", name, s->_stanza[@"Version"]]
                                       productID:HCGHIPProductRepo];
        [s build];
        [s.tableView reloadData];
    }];
}

@end

#pragma mark - Trust Center

typedef NS_ENUM(NSInteger, HCGTrustGroup) {
    HCGTrustGroupRepositories = 0,
    HCGTrustGroupPackages,
    HCGTrustGroupInstalled,
    HCGTrustGroupWarnings,
    HCGTrustGroupSentinel,
};

@implementation HCGTrustCenterViewController {
    HCGTrustSnapshot *_snapshot;
    NSArray *_packages;            // (stanza, repository)
    NSArray *_installedHCG;        // (HCGPackageRecord, index match or nil)
    NSArray<NSString *> *_warnings;
    NSArray<NSArray *> *_sentinel; // (title, detail, NSNumber severity)
    NSUInteger _installedCount;
    NSInteger _pending;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Package Trust Center";
    self.tableView.estimatedRowHeight = 60;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    UILabel *header = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 320, 64)];
    header.numberOfLines = 0;
    header.font = [HCGTheme fontForTextStyle:UIFontTextStyleFootnote weight:UIFontWeightMedium maximumPointSize:17];
    header.textColor = [HCGTheme secondaryText];
    header.text = @"   Read-only. Checks what HCG Repo publishes against keys you trust;\n   installs, removes and changes nothing.";
    self.tableView.tableHeaderView = header;
    [self reload];
}

- (void)modelDidChange {
}

- (void)reload {
    _snapshot = [[HCGTrustSnapshot alloc] init];
    _snapshot.repositories = [self.context.model trustedRepositories];
    _snapshot.reports = [NSMutableDictionary dictionary];
    _snapshot.fetches = [NSMutableDictionary dictionary];
    _snapshot.deviceIOS = [[UIDevice currentDevice] systemVersion];
    _snapshot.environment = @{};
    _pending = (NSInteger)_snapshot.repositories.count + 1;
    __weak typeof(self) weakSelf = self;
    id<HCGLauncher> launcher = self.context.model.launcher;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSDictionary *env = [launcher respondsToSelector:@selector(trustEnvironment)] ? [launcher trustEnvironment] : @{};
        dispatch_async(dispatch_get_main_queue(), ^{
            typeof(self) s = weakSelf;
            if (!s) return;
            s->_snapshot.environment = env ?: @{};
            [s finishOne];
        });
    });
    for (HCGTrustedRepository *repo in _snapshot.repositories) {
        HCGTrustSnapshot *snapshot = _snapshot;
        [[HCGTrustFetcher sharedFetcher] fetchRepository:repo completion:^(HCGTrustFetchResult *result) {
            dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
                HCGRepositoryReport *report = [HCGRepoTrust evaluate:result.evidence];
                if (result.failure) {
                    report.authenticity = HCGAuthenticityUnknown;
                    report.summary = result.failure;
                }
                dispatch_async(dispatch_get_main_queue(), ^{
                    typeof(self) s = weakSelf;
                    if (!s || s->_snapshot != snapshot) return;
                    snapshot.fetches[repo.identifier] = result;
                    snapshot.reports[repo.identifier] = report;
                    // A real read of HCG Repo's public files is two-way communication evidence for HCG Repo (Command Center).
                    if (repo.builtIn) {
                        [s.context.model recordConnectionForProduct:@"repo" method:@"https-api" success:!result.failure
                                                               text:result.failure ? @"Package Trust Center could not read HCG Repo." : [NSString stringWithFormat:@"Package Trust Center read %@ (%@).", repo.name, [HCGRepoTrust titleForAuthenticity:report.authenticity]]];
                    }
                    // Anti-replay and revocation memory: remembered only from this repository's own evaluation.
                    if (!result.failure) {
                        NSArray *stored = [s.context.model trustedRepositories];
                        for (HCGTrustedRepository *r in stored) {
                            if ([r.identifier isEqualToString:repo.identifier] && [r rememberReport:report]) {
                                [s.context.model saveTrustedRepositories:stored];
                                break;
                            }
                        }
                    }
                    [s finishOne];
                });
            });
        }];
    }
    [self.tableView reloadData];
}

- (void)finishOne {
    _pending--;
    [self derive];
    [self.tableView reloadData];
}

- (void)derive {
    _packages = HCGHCGPackages(_snapshot);
    NSMutableArray *warnings = [NSMutableArray array], *installed = [NSMutableArray array], *sentinel = [NSMutableArray array];
    for (HCGTrustedRepository *repo in _snapshot.repositories) {
        HCGRepositoryReport *report = _snapshot.reports[repo.identifier];
        for (NSString *w in report.warnings) [warnings addObject:[NSString stringWithFormat:@"%@: %@", repo.name, w]];
        HCGTrustFetchResult *fetch = _snapshot.fetches[repo.identifier];
        if (!report) continue;
        BOOL available = [fetch.fileStates[@"Release"] isEqualToString:@"200"] && [fetch.fileStates[@"Packages"] isEqualToString:@"200"];
        [sentinel addObject:@[ [NSString stringWithFormat:@"availability · %@", repo.name], available ? @"Release and Packages: HTTP 200" : @"Release or Packages unavailable",
                               @(available ? HCGFindingSeverityOK : HCGFindingSeverityAlert) ]];
        [sentinel addObject:@[ [NSString stringWithFormat:@"index · %@", repo.name], report.indexConsistent ? @"Release lists the served Packages" : @"Release does not match Packages",
                               @(report.indexConsistent ? HCGFindingSeverityOK : HCGFindingSeverityAlert) ]];
        HCGFindingSeverity sig = report.authenticity == HCGAuthenticityVerified ? HCGFindingSeverityOK
                               : (report.authenticity == HCGAuthenticityInvalid ? HCGFindingSeverityAlert : HCGFindingSeverityWarning);
        [sentinel addObject:@[ [NSString stringWithFormat:@"signature · %@", repo.name], [HCGRepoTrust titleForAuthenticity:report.authenticity], @(sig) ]];
    }
    NSArray *records = _snapshot.environment[@"installed"];
    _installedCount = [records isKindOfClass:[NSArray class]] ? records.count : 0;
    for (HCGPackageRecord *record in [records isKindOfClass:[NSArray class]] ? records : @[]) {
        if (![record.package hasPrefix:@"com.hakmicapitalgroup."]) continue;
        NSArray *match = HCGFindStanza(_snapshot, record.package, record.version);
        [installed addObject:@[ record, match ?: [NSNull null] ]];
        if (!match && _pending == 0) {
            [warnings addObject:[NSString stringWithFormat:@"%@ %@ is installed but not in any checked index: an older version, or from another source.", record.package, record.version]];
        } else if (match) {
            NSDictionary *rec = [[_snapshot compatibility] recordForPackage:record.package version:record.version];
            if ([rec[@"status"] isEqual:@"Known incompatible"]) [warnings addObject:[NSString stringWithFormat:@"Installed %@ %@ is recorded as Known incompatible by HCG Repo.", record.package, record.version]];
        }
    }
    _installedHCG = installed;
    for (NSString *source in _snapshot.environment[@"trustedYes"] ?: @[]) {
        [warnings addObject:[NSString stringWithFormat:@"APT source marked trusted=yes (signatures are not checked): %@. Nexus does not change it.", source]];
    }
    NSDictionary *ents = _snapshot.environment[@"entitlements"];
    for (NSString *bundle in [ents isKindOfClass:[NSDictionary class]] ? ents : @{}) {
        for (NSString *k in ents[bundle]) {
            if ([k hasPrefix:@"_"] || [HCGEntitlements riskOfEntitlement:k] != HCGEntitlementRiskHigh) continue;
            HCGHIPProductDescriptor *d = [HCGInterchange descriptorForBundleIdentifier:bundle];
            [warnings addObject:[NSString stringWithFormat:@"%@ has %@: %@", d.name ?: bundle, k, [HCGEntitlements explanationOfEntitlement:k]]];
        }
    }
    if ([_snapshot.environment[@"packageManagers"] containsObject:@"zebra"]) {
        [warnings addObject:@"Zebra does not check repository signatures (HCG-repo docs/SIGNING.md); Sileo and APT do once HCG Repo Keyring is installed."];
    }
    _warnings = warnings;
    _sentinel = sentinel;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 5;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    switch ((HCGTrustGroup)section) {
        case HCGTrustGroupRepositories: return @"Repositories";
        case HCGTrustGroupPackages: return @"HCG packages";
        case HCGTrustGroupInstalled: return @"Installed on this iPhone";
        case HCGTrustGroupWarnings: return @"Security warnings";
        case HCGTrustGroupSentinel: return @"HCG Sentinel checks";
    }
    return nil;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    switch ((HCGTrustGroup)section) {
        case HCGTrustGroupRepositories: return _pending > 0 ? @"Reading…" : @"Verified needs a good signature by a key you pinned. Unsigned means nothing proves who published the index.";
        case HCGTrustGroupPackages: return @"Two separate answers per package: authenticity (who published these bytes) and device evidence (did it work on a real iPhone). Neither means \"safe\".";
        case HCGTrustGroupInstalled: return _installedCount ? [NSString stringWithFormat:@"%lu packages installed in total (dpkg).", (unsigned long)_installedCount] : @"Installed packages are visible to the jailbreak package only.";
        case HCGTrustGroupSentinel: return @"HCG Sentinel publishes no repository findings to Nexus yet. Nexus runs the same public checks itself (hcg.repo.monitor v1); it never retries, fixes or publishes anything.";
        default: return nil;
    }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch ((HCGTrustGroup)section) {
        case HCGTrustGroupRepositories: return (NSInteger)_snapshot.repositories.count;
        case HCGTrustGroupPackages: return (NSInteger)MAX(_packages.count, (NSUInteger)1);
        case HCGTrustGroupInstalled: return (NSInteger)MAX(_installedHCG.count, (NSUInteger)1);
        case HCGTrustGroupWarnings: return (NSInteger)MAX(_warnings.count, (NSUInteger)1);
        case HCGTrustGroupSentinel: return (NSInteger)MAX(_sentinel.count, (NSUInteger)1);
    }
    return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSUInteger row = (NSUInteger)indexPath.row;
    switch ((HCGTrustGroup)indexPath.section) {
        case HCGTrustGroupRepositories: {
            HCGTrustedRepository *repo = _snapshot.repositories[row];
            HCGRepositoryReport *report = _snapshot.reports[repo.identifier];
            UITableViewCell *cell = HCGTextCell(self, repo.name, report ? report.summary : @"Reading…");
            HCGAuthenticity a = report ? report.authenticity : HCGAuthenticityUnknown;
            cell.accessoryView = HCGTrustChip(report ? [HCGRepoTrust titleForAuthenticity:a] : @"…", HCGColorForAuthenticity(a));
            cell.selectionStyle = report ? UITableViewCellSelectionStyleDefault : UITableViewCellSelectionStyleNone;
            cell.imageView.image = [HCGTheme symbolNamed:repo.pinnedFingerprint ? @"key.fill" : @"key" pointSize:16];
            return cell;
        }
        case HCGTrustGroupPackages: {
            if (!_packages.count) return HCGTextCell(self, _pending > 0 ? @"Reading…" : @"No HCG packages", nil);
            NSDictionary *stanza = _packages[row][0];
            HCGTrustedRepository *repo = _packages[row][1];
            HCGPackageAssessment *a = [HCGRepoTrust assessPackage:stanza repository:_snapshot.reports[repo.identifier]
                                                    compatibility:[[_snapshot compatibility] recordForPackage:stanza[@"Package"] version:stanza[@"Version"]]
                                                        deviceIOS:_snapshot.deviceIOS downloadedSHA256:nil downloadedSize:0];
            UITableViewCell *cell = HCGTextCell(self, [NSString stringWithFormat:@"%@ %@", stanza[@"Name"] ?: stanza[@"Package"], stanza[@"Version"]],
                                                [NSString stringWithFormat:@"%@ · %@ · %@", [HCGRepoTrust titleForAuthenticity:a.authenticity],
                                                 [HCGRepoTrust titleForDeviceEvidence:a.deviceEvidence], repo.name]);
            cell.accessoryView = HCGTrustChip([HCGRepoTrust titleForAuthenticity:a.authenticity], HCGColorForAuthenticity(a.authenticity));
            cell.selectionStyle = UITableViewCellSelectionStyleDefault;
            return cell;
        }
        case HCGTrustGroupInstalled: {
            if (!_installedHCG.count) return HCGTextCell(self, _installedCount ? @"No HCG packages installed" : @"Not visible here", nil);
            HCGPackageRecord *record = _installedHCG[row][0];
            id match = _installedHCG[row][1];
            UITableViewCell *cell = HCGTextCell(self, [NSString stringWithFormat:@"%@ %@", record.package, record.version],
                                                match != [NSNull null] ? [NSString stringWithFormat:@"In the %@ index (SHA-256 %@…)", [(HCGTrustedRepository *)match[1] name], [(NSString *)match[0][@"SHA256"] substringToIndex:12]]
                                                                       : @"Not in any checked index");
            cell.selectionStyle = match != [NSNull null] ? UITableViewCellSelectionStyleDefault : UITableViewCellSelectionStyleNone;
            return cell;
        }
        case HCGTrustGroupWarnings: {
            if (!_warnings.count) return HCGTextCell(self, _pending > 0 ? @"Reading…" : @"No warnings", nil);
            UITableViewCell *cell = HCGTextCell(self, _warnings[row], nil);
            cell.imageView.image = [HCGTheme symbolNamed:@"exclamationmark.triangle" pointSize:15];
            cell.imageView.tintColor = [HCGTheme warning];
            return cell;
        }
        case HCGTrustGroupSentinel: {
            if (!_sentinel.count) return HCGTextCell(self, @"Reading…", nil);
            NSArray *f = _sentinel[row];
            HCGFindingSeverity s = (HCGFindingSeverity)[f[2] integerValue];
            UITableViewCell *cell = HCGTextCell(self, f[0], f[1]);
            cell.accessoryView = HCGTrustChip([HCGMonitorReport titleForSeverity:s], s == HCGFindingSeverityOK ? [HCGTheme success] : (s == HCGFindingSeverityAlert ? [HCGTheme critical] : [HCGTheme warning]));
            return cell;
        }
    }
    return HCGTextCell(self, @"", nil);
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSUInteger row = (NSUInteger)indexPath.row;
    UIViewController *next = nil;
    if (indexPath.section == HCGTrustGroupRepositories && row < _snapshot.repositories.count) {
        HCGTrustedRepository *repo = _snapshot.repositories[row];
        HCGRepositoryReport *report = _snapshot.reports[repo.identifier];
        if (!report) return;
        HCGTrustRepositoryViewController *vc = [[HCGTrustRepositoryViewController alloc] initWithContext:self.context repository:repo report:report
                                                                                                   fetch:_snapshot.fetches[repo.identifier] keyring:_snapshot.environment[@"keyring"]];
        __weak typeof(self) weakSelf = self;
        vc.onChange = ^{ [weakSelf reload]; };
        next = vc;
    } else if (indexPath.section == HCGTrustGroupPackages && row < _packages.count) {
        next = [[HCGTrustPackageViewController alloc] initWithContext:self.context stanza:_packages[row][0] repository:_packages[row][1] snapshot:_snapshot];
    } else if (indexPath.section == HCGTrustGroupInstalled && row < _installedHCG.count && _installedHCG[row][1] != [NSNull null]) {
        NSArray *match = _installedHCG[row][1];
        next = [[HCGTrustPackageViewController alloc] initWithContext:self.context stanza:match[0] repository:match[1] snapshot:_snapshot];
    }
    if (next) [self.navigationController pushViewController:next animated:!UIAccessibilityIsReduceMotionEnabled()];
}

@end
