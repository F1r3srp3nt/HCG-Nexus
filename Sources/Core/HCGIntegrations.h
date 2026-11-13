#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class HCGSettings;

// Integration identifiers (used as HCGActionKindIntegration targets).
FOUNDATION_EXPORT NSString *const HCGIntegrationTerminal;
FOUNDATION_EXPORT NSString *const HCGIntegrationServer;
FOUNDATION_EXPORT NSString *const HCGIntegrationNews;
FOUNDATION_EXPORT NSString *const HCGIntegrationExecutableMaker;

// Bundle identifiers taken verbatim from the sibling repositories
// (see docs/INTEGRATIONS.md for file/line references). No URL schemes are
// listed because none of the inspected apps registers one.
FOUNDATION_EXPORT NSString *const HCGTerminalBundleIdentifier;          // com.hakmicapitalgroup.hcgterminal
FOUNDATION_EXPORT NSString *const HCGTerminalUnleashedBundleIdentifier; // com.hakmicapitalgroup.hcgterminal.unleashed
FOUNDATION_EXPORT NSString *const HCGNewsBundleIdentifier;              // com.hakmicapitalgroup.hcgnews

typedef NS_ENUM(NSInteger, HCGIntegrationState) {
    HCGIntegrationStateNotConnected = 0, // unconfigured, or no usable contract exists
    HCGIntegrationStateReady = 1,        // configured and the target app is installed
    HCGIntegrationStateAppMissing = 2,   // configured but the app is not installed
    HCGIntegrationStateUnverified = 3,   // configured; installation could not be checked
    HCGIntegrationStateUnavailableHere = 4, // configured, but this build cannot open apps by bundle ID
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
}
@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, copy) NSString *displayName;
@property (nonatomic, copy) NSString *symbolName;
@property (nonatomic) HCGIntegrationState state;
@property (nonatomic, copy) NSString *headline;   // "Not connected", "Ready", "Needs jailbreak package", ...
@property (nonatomic, copy) NSString *detail;     // actionable explanation
@property (nonatomic, copy, nullable) NSString *launchBundleIdentifier;
@property (nonatomic, readonly) BOOL canLaunch;
@end

@interface HCGIntegrationCatalog : NSObject
+ (NSArray<NSString *> *)allIdentifiers;
+ (nullable NSString *)displayNameForIdentifier:(NSString *)identifier;
+ (NSString *)symbolNameForIdentifier:(NSString *)identifier;
// Pure function of settings + installation probe. Performs no I/O itself
// beyond calling the probe, and never touches the network.
+ (HCGIntegrationStatus *)statusForIdentifier:(NSString *)identifier
                                     settings:(HCGSettings *)settings
                                        probe:(nullable id<HCGAppInstallationProbe>)probe;
+ (NSArray<HCGIntegrationStatus *> *)allStatusesWithSettings:(HCGSettings *)settings
                                                       probe:(nullable id<HCGAppInstallationProbe>)probe;
@end

NS_ASSUME_NONNULL_END
