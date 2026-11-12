#import "HCGConstants.h"

NSString *const HCGNexusPreferencesDomain = @"com.hakmicapitalgroup.hcgnexus";
NSString *const HCGNexusSettingsChangedDarwinNotification = @"com.hakmicapitalgroup.hcgnexus/settings-changed";
NSString *const HCGNexusWorkspacesChangedDarwinNotification = @"com.hakmicapitalgroup.hcgnexus/workspaces-changed";
NSString *const HCGNexusErrorDomain = @"com.hakmicapitalgroup.hcgnexus.error";

NSError *HCGMakeError(HCGErrorCode code, NSString *message, NSString *recovery) {
    NSMutableDictionary *info = [[NSMutableDictionary alloc] init];
    [info setObject:(message ?: @"Unknown error") forKey:NSLocalizedDescriptionKey];
    if (recovery.length > 0) {
        [info setObject:recovery forKey:NSLocalizedRecoverySuggestionErrorKey];
    }
    return [NSError errorWithDomain:HCGNexusErrorDomain code:code userInfo:info];
}
