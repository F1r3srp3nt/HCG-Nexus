#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// ---------------------------------------------------------------------------
// Runtime status + diagnostics shared by the SpringBoard tweak (writer) and
// Settings › HCG Nexus (reader). Foundation-only and host-tested.
//
// Feature states are deliberately distinct:
//   ok          — working, with the evidence in `detail`
//   disabled    — the user turned it off
//   unavailable — supported, but not usable right now (e.g. lock state
//                 unreadable, so Nexus stays hidden: fail-closed)
//   unsupported — this iOS/jailbreak lacks what the feature needs
//   failed      — tried and failed (error in `detail`)
//   unknown     — no evidence either way (e.g. no report from SpringBoard)
// ---------------------------------------------------------------------------

FOUNDATION_EXPORT NSString *const HCGFeatureStateOK;
FOUNDATION_EXPORT NSString *const HCGFeatureStateDisabled;
FOUNDATION_EXPORT NSString *const HCGFeatureStateUnavailable;
FOUNDATION_EXPORT NSString *const HCGFeatureStateUnsupported;
FOUNDATION_EXPORT NSString *const HCGFeatureStateFailed;
FOUNDATION_EXPORT NSString *const HCGFeatureStateUnknown;

// Preference key (in HCGNexusPreferencesDomain) holding the SpringBoard report.
FOUNDATION_EXPORT NSString *const HCGRuntimeStatusKey;
FOUNDATION_EXPORT const NSInteger HCGRuntimeStatusSchemaVersion;

// Report dictionary keys (plist types only).
FOUNDATION_EXPORT NSString *const HCGStatusSchema;        // NSNumber
FOUNDATION_EXPORT NSString *const HCGStatusVersion;       // e.g. "0.2.0"
FOUNDATION_EXPORT NSString *const HCGStatusBuildID;       // git commit (+ "-dirty")
FOUNDATION_EXPORT NSString *const HCGStatusBuildConfig;   // e.g. "rootless-release"
FOUNDATION_EXPORT NSString *const HCGStatusUpdated;       // NSNumber, seconds since 1970
FOUNDATION_EXPORT NSString *const HCGStatusState;         // "active" | "disabled" | "stopped"
FOUNDATION_EXPORT NSString *const HCGStatusReason;        // why stopped/disabled
FOUNDATION_EXPORT NSString *const HCGStatusStartedBy;
FOUNDATION_EXPORT NSString *const HCGStatusInjector;      // evidence: injector images loaded in SpringBoard
FOUNDATION_EXPORT NSString *const HCGStatusDeviceModel;   // hw.machine, e.g. iPhone14,2
FOUNDATION_EXPORT NSString *const HCGStatusOSVersion;
FOUNDATION_EXPORT NSString *const HCGStatusOSBuild;
FOUNDATION_EXPORT NSString *const HCGStatusFeatures;      // { name: { state, detail } }
FOUNDATION_EXPORT NSString *const HCGStatusOverlay;       // { key: string }
FOUNDATION_EXPORT NSString *const HCGStatusLastError;     // { message, time }

// Feature names inside HCGStatusFeatures.
FOUNDATION_EXPORT NSString *const HCGFeatureEdgeHandle;
FOUNDATION_EXPORT NSString *const HCGFeatureAppLaunching;
FOUNDATION_EXPORT NSString *const HCGFeatureLockDetection;
FOUNDATION_EXPORT NSString *const HCGFeatureOrientation;

// SpringBoard component state as seen from Settings.
FOUNDATION_EXPORT NSString *const HCGComponentRunning;           // same build as installed
FOUNDATION_EXPORT NSString *const HCGComponentRespringRequired;   // SpringBoard runs another build
FOUNDATION_EXPORT NSString *const HCGComponentNotLoaded;          // no report at all
FOUNDATION_EXPORT NSString *const HCGComponentStopped;            // loaded but stopped (kill switch, unsupported iOS)
FOUNDATION_EXPORT NSString *const HCGComponentUnknown;            // malformed/old report

@interface HCGDiagnostics : NSObject

+ (NSDictionary *)featureWithState:(NSString *)state detail:(NSString *)detail;

// Compares the build the Settings bundle was compiled from with the build the
// SpringBoard tweak reports. *detail receives a one-line explanation with the
// action to take (e.g. "Respring to load build abc").
+ (NSString *)springBoardStateForInstalledBuild:(NSString *)installedBuild
                                        runtime:(nullable NSDictionary *)runtime
                                         detail:(NSString *_Nullable *_Nullable)detail;

// Removes e-mail addresses, credential-looking assignments, bearer tokens,
// UUIDs/UDIDs and long hex/base64 secrets.
+ (NSString *)redact:(NSString *)text;

// Full plain-text report. `local` holds facts gathered by Settings (keys:
// version, buildID, buildConfig, installPrefix, installEvidence, deviceModel,
// osVersion, osBuild, generated, settingsSummary, workspaceCount,
// recentCount, recentFailures). Output is always redacted.
+ (NSString *)reportWithLocal:(NSDictionary *)local runtime:(nullable NSDictionary *)runtime;

+ (NSString *)formatTimestamp:(nullable id)secondsSince1970;
@end

NS_ASSUME_NONNULL_END
