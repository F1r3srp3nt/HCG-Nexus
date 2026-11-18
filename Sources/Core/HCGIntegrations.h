#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class HCGSettings;

// Integration identifiers (used as HCGActionKindIntegration targets).
FOUNDATION_EXPORT NSString *const HCGIntegrationTerminal;
FOUNDATION_EXPORT NSString *const HCGIntegrationServer;
FOUNDATION_EXPORT NSString *const HCGIntegrationNews;
FOUNDATION_EXPORT NSString *const HCGIntegrationExecutableMaker;
FOUNDATION_EXPORT NSString *const HCGIntegrationSentinel;

// Bundle identifiers taken verbatim from the sibling repositories
// (see docs/INTEGRATIONS.md for file/line references). The only URL scheme is
// HCG Sentinel's navigation scheme; Terminal and News register none.
FOUNDATION_EXPORT NSString *const HCGTerminalBundleIdentifier;          // com.hakmicapitalgroup.hcgterminal
FOUNDATION_EXPORT NSString *const HCGTerminalUnleashedBundleIdentifier; // com.hakmicapitalgroup.hcgterminal.unleashed
FOUNDATION_EXPORT NSString *const HCGNewsBundleIdentifier;              // com.hakmicapitalgroup.hcgnews
FOUNDATION_EXPORT NSString *const HCGSentinelBundleIdentifier;          // com.hcg.sentinel (HCG-Sentinel project.pbxproj)
FOUNDATION_EXPORT NSString *const HCGSentinelURLScheme;                 // hcgsentinel (HCG-Sentinel Info.plist CFBundleURLTypes)

// HCG Sentinel's navigation links, exactly as Sentinel's own DeepLink.target(from:) accepts them
// (HCG-Sentinel SentinelCore/Operations/DeepLink.swift, docs/NEXUS_INTEGRATION.md):
//   hcgsentinel://open/<section>     section in -sentinelSections (case-insensitive)
//   hcgsentinel://report/<uuid>      a stored Security Lab report; Sentinel shows "Report not found" otherwise
// No query, fragment, user, password, port or extra path component. These links only navigate: Sentinel has no
// link that starts a scan, sends a request, connects to a node, changes a setting or deletes data.
@interface HCGSentinelLinks : NSObject
+ (NSArray<NSString *> *)sections;
+ (nullable NSURL *)URLForSection:(NSString *)section;
// nil when the URL is a link HCG Sentinel accepts; otherwise the reason it is refused.
+ (nullable NSString *)problemWithURLString:(NSString *)string;
@end
typedef NS_ENUM(NSInteger, HCGIntegrationState) {
    HCGIntegrationStateNotConnected = 0, // unconfigured, or no usable contract exists
    HCGIntegrationStateReady = 1,        // configured and the target app is installed
    HCGIntegrationStateAppMissing = 2,   // configured but the app is not installed
    HCGIntegrationStateUnverified = 3,   // configured; installation could not be checked
    HCGIntegrationStateUnavailableHere = 4, // configured, but this build cannot open apps by bundle ID
};

// Whether a service behind the integration can be reached. Defaults to
// Unknown (0) so a status that nobody filled in never reads as reachable.
// HCG Terminal and HCG News are app-launch integrations: Nexus opens the app
// and there is no service for Nexus to reach (NotApplicable). No integration
// publishes a phone-reachable status contract yet, so Reachable/Unreachable
// are only produced once one exists (docs/INTEGRATIONS.md).
typedef NS_ENUM(NSInteger, HCGIntegrationReachability) {
    HCGIntegrationReachabilityUnknown = 0,
    HCGIntegrationReachabilityNotApplicable = 1,
    HCGIntegrationReachabilityReachable = 2,
    HCGIntegrationReachabilityUnreachable = 3,
};

// Sign-in state Nexus can observe for the integration. Defaults to Unknown
// (0). Nexus stores no HCG credentials and holds no session of its own (HCG
// Connect and ERP stay the authority), so app-launch integrations report
// NotApplicable: whether you are signed in inside the app is not visible here.
typedef NS_ENUM(NSInteger, HCGIntegrationSession) {
    HCGIntegrationSessionUnknown = 0,
    HCGIntegrationSessionNotApplicable = 1,
    HCGIntegrationSessionSignedIn = 2,
    HCGIntegrationSessionSignedOut = 3,
};

// Answers "is this app installed / can it be opened?" without launching
// anything. Implemented by the platform layer: LSApplicationWorkspace inside
// SpringBoard (jailbreak package), a simulation in the preview harness, and
// the public-API launcher of the standalone app.
@protocol HCGAppInstallationProbe <NSObject>
// NO when this build cannot open other apps by bundle identifier at all
// (the sandboxed standalone app). Shortcuts and integrations then report
// "unavailable here" instead of pretending to work.
- (BOOL)canLaunchApplicationsByBundleIdentifier;
// NO when this environment cannot determine installation state at all.
- (BOOL)canDetermineInstallation;
- (BOOL)isApplicationInstalled:(NSString *)bundleIdentifier;
@end

@interface HCGIntegrationStatus : NSObject {
    NSString *_identifier;
    NSString *_displayName;
    NSString *_symbolName;
    HCGIntegrationState _state;
    NSString *_headline;
    NSString *_detail;
    NSString *_launchBundleIdentifier;
    BOOL _recognized;
    BOOL _contractAvailable;
    BOOL _configured;
    HCGIntegrationReachability _reachability;
    HCGIntegrationSession _session;
}
@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, copy) NSString *displayName;
@property (nonatomic, copy) NSString *symbolName;
@property (nonatomic) HCGIntegrationState state;
@property (nonatomic, copy) NSString *headline;   // "Not connected", "Ready", "Needs jailbreak package", ...
@property (nonatomic, copy) NSString *detail;     // actionable explanation
@property (nonatomic, copy, nullable) NSString *launchBundleIdentifier;
// The identifier is one of +[HCGIntegrationCatalog allIdentifiers].
@property (nonatomic) BOOL recognized;
// A contract a phone can use exists (HCG Terminal, HCG News: open the app).
// NO for HCG Server and Executable Maker, whatever the settings say.
@property (nonatomic) BOOL contractAvailable;
// The user turned the integration on in HCG Nexus settings.
@property (nonatomic) BOOL configured;
@property (nonatomic) HCGIntegrationReachability reachability;
@property (nonatomic) HCGIntegrationSession session;
@property (nonatomic, readonly) BOOL canLaunch;
@end

@interface HCGIntegrationCatalog : NSObject
// Every identifier a saved shortcut may reference (kept so older workspaces
// still validate and report an accurate status).
+ (NSArray<NSString *> *)allIdentifiers;
// Integrations that can actually do something on a phone today (open their
// app): HCG Terminal and HCG News. Only these are offered in the UI, presets
// and status lists; HCG Server and Executable Maker have no phone-reachable
// interface, so offering them would show a capability that does not exist.
+ (NSArray<NSString *> *)offeredIdentifiers;
+ (nullable NSString *)displayNameForIdentifier:(NSString *)identifier;
+ (NSString *)symbolNameForIdentifier:(NSString *)identifier;
// Pure function of settings + installation probe. Performs no I/O itself
// beyond calling the probe, and never touches the network.
+ (HCGIntegrationStatus *)statusForIdentifier:(NSString *)identifier
                                     settings:(HCGSettings *)settings
                                        probe:(nullable id<HCGAppInstallationProbe>)probe;
// Statuses for -offeredIdentifiers.
+ (NSArray<HCGIntegrationStatus *> *)allStatusesWithSettings:(HCGSettings *)settings
                                                       probe:(nullable id<HCGAppInstallationProbe>)probe;
@end

NS_ASSUME_NONNULL_END
