#import <Foundation/Foundation.h>

// Keep in sync with `Version:` in /control (scripts/check.sh verifies this).
#define HCG_NEXUS_VERSION @"0.1.0"

// CFPreferences domain shared by SpringBoard (reader) and the Settings bundle.
FOUNDATION_EXPORT NSString *const HCGNexusPreferencesDomain;

// Darwin notification posted by any writer after settings change.
FOUNDATION_EXPORT NSString *const HCGNexusSettingsChangedDarwinNotification;
// Darwin notification posted after workspaces/recents change.
FOUNDATION_EXPORT NSString *const HCGNexusWorkspacesChangedDarwinNotification;

// Error domain for user-facing validation and launch errors.
FOUNDATION_EXPORT NSString *const HCGNexusErrorDomain;

typedef NS_ENUM(NSInteger, HCGErrorCode) {
    HCGErrorInvalidName = 1,
    HCGErrorDuplicateName = 2,
    HCGErrorLimitReached = 3,
    HCGErrorNotFound = 4,
    HCGErrorInvalidTarget = 5,
    HCGErrorAppNotInstalled = 10,
    HCGErrorNoHandlerForURL = 11,
    HCGErrorUnsupportedAction = 12,
    HCGErrorIntegrationNotConnected = 13,
    HCGErrorLauncherUnavailable = 14,
    HCGErrorSystemLocked = 15,
    HCGErrorLaunchFailed = 16,
};

// Builds an NSError whose localizedDescription is the message and whose
// NSLocalizedRecoverySuggestionErrorKey carries the actionable next step.
FOUNDATION_EXPORT NSError *HCGMakeError(HCGErrorCode code, NSString *message, NSString *recovery);
