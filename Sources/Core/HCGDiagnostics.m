#import "HCGDiagnostics.h"

NSString *const HCGFeatureStateOK = @"ok";
NSString *const HCGFeatureStateDisabled = @"disabled";
NSString *const HCGFeatureStateUnavailable = @"unavailable";
NSString *const HCGFeatureStateUnsupported = @"unsupported";
NSString *const HCGFeatureStateFailed = @"failed";
NSString *const HCGFeatureStateUnknown = @"unknown";

NSString *const HCGRuntimeStatusKey = @"runtimeStatus";
const NSInteger HCGRuntimeStatusSchemaVersion = 2;

NSString *const HCGStatusSchema = @"schema";
NSString *const HCGStatusVersion = @"version";
NSString *const HCGStatusBuildID = @"buildID";
NSString *const HCGStatusBuildConfig = @"buildConfig";
NSString *const HCGStatusUpdated = @"updated";
NSString *const HCGStatusState = @"state";
NSString *const HCGStatusReason = @"reason";
NSString *const HCGStatusStartedBy = @"startedBy";
NSString *const HCGStatusInjector = @"injector";
NSString *const HCGStatusDeviceModel = @"deviceModel";
NSString *const HCGStatusOSVersion = @"osVersion";
NSString *const HCGStatusOSBuild = @"osBuild";
NSString *const HCGStatusFeatures = @"features";
NSString *const HCGStatusOverlay = @"overlay";
NSString *const HCGStatusLastError = @"lastError";

NSString *const HCGFeatureEdgeHandle = @"edgeHandle";
NSString *const HCGFeatureAppLaunching = @"appLaunching";
NSString *const HCGFeatureLockDetection = @"lockDetection";
NSString *const HCGFeatureOrientation = @"orientation";

NSString *const HCGComponentRunning = @"running";
NSString *const HCGComponentRespringRequired = @"respring-required";
NSString *const HCGComponentNotLoaded = @"not-loaded";
NSString *const HCGComponentStopped = @"stopped";
NSString *const HCGComponentUnknown = @"unknown";

static NSString *HCGString(id value, NSString *fallback) {
    if ([value isKindOfClass:[NSString class]] && [value length] > 0) return value;
    if ([value isKindOfClass:[NSNumber class]]) return [value description];
    return fallback;
}

@implementation HCGDiagnostics

+ (NSDictionary *)featureWithState:(NSString *)state detail:(NSString *)detail {
    return [NSDictionary dictionaryWithObjectsAndKeys:state, @"state", (detail ?: @""), @"detail", nil];
}

+ (NSString *)springBoardStateForInstalledBuild:(NSString *)installedBuild runtime:(NSDictionary *)runtime detail:(NSString **)detail {
    NSString *result = HCGComponentUnknown;
    NSString *text = @"";
    if (![runtime isKindOfClass:[NSDictionary class]] || [runtime count] == 0) {
        result = HCGComponentNotLoaded;
        text = @"SpringBoard has not reported. After installing or updating, respring once; if it still does not report, the tweak was not loaded (check the injector).";
    } else if (![[runtime objectForKey:HCGStatusSchema] isKindOfClass:[NSNumber class]] ||
               ![[runtime objectForKey:HCGStatusBuildID] isKindOfClass:[NSString class]]) {
        result = HCGComponentRespringRequired;
        text = @"SpringBoard is running an older HCG Nexus build. Respring to load the installed one.";
    } else {
        NSString *running = [runtime objectForKey:HCGStatusBuildID];
        NSString *state = HCGString([runtime objectForKey:HCGStatusState], @"");
        if (![running isEqualToString:installedBuild]) {
            result = HCGComponentRespringRequired;
            text = [NSString stringWithFormat:@"SpringBoard is running build %@; build %@ is installed. Respring to load it.", running, installedBuild];
        } else if ([state isEqualToString:@"stopped"]) {
            result = HCGComponentStopped;
            text = [NSString stringWithFormat:@"Loaded but stopped: %@", HCGString([runtime objectForKey:HCGStatusReason], @"no reason given")];
        } else {
            result = HCGComponentRunning;
            text = [NSString stringWithFormat:@"Running build %@ in SpringBoard.", running];
        }
    }
    if (detail) *detail = text;
    return result;
}

+ (NSString *)replace:(NSString *)pattern in:(NSString *)text with:(NSString *)template options:(NSRegularExpressionOptions)options {
    NSError *error = nil;
    NSRegularExpression *re = [NSRegularExpression regularExpressionWithPattern:pattern options:options error:&error];
    if (!re) return text;
    return [re stringByReplacingMatchesInString:text options:0 range:NSMakeRange(0, text.length) withTemplate:template];
}

+ (NSString *)redact:(NSString *)text {
    if (text.length == 0) return @"";
    NSString *out = text;
    out = [self replace:@"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}" in:out with:@"<redacted-email>" options:0];
    out = [self replace:@"(bearer)\\s+[A-Za-z0-9._~+/=-]+" in:out with:@"$1 <redacted>" options:NSRegularExpressionCaseInsensitive];
    out = [self replace:@"((?:password|passwd|secret|token|api[_-]?key|authorization)[\"']?\\s*[:=]\\s*)[\"']?[^\\s\"',;]+"
                     in:out with:@"$1<redacted>" options:NSRegularExpressionCaseInsensitive];
    out = [self replace:@"[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}" in:out with:@"<redacted-uuid>" options:0];
    out = [self replace:@"\\b[0-9A-Fa-f]{8}-[0-9A-Fa-f]{16}\\b" in:out with:@"<redacted-udid>" options:0];
    out = [self replace:@"\\b[0-9A-Fa-f]{40}\\b" in:out with:@"<redacted-hex>" options:0];
    out = [self replace:@"\\b[A-Za-z0-9+/_-]{48,}={0,2}" in:out with:@"<redacted-secret>" options:0];
    return out;
}

+ (NSString *)formatTimestamp:(id)seconds {
    if (![seconds isKindOfClass:[NSNumber class]]) return @"unknown";
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy-MM-dd HH:mm:ss 'UTC'"];
    [formatter setTimeZone:[NSTimeZone timeZoneWithName:@"UTC"]];
    return [formatter stringFromDate:[NSDate dateWithTimeIntervalSince1970:[seconds doubleValue]]];
}

+ (void)appendFeatures:(NSDictionary *)features to:(NSMutableString *)out {
    NSArray *order = [NSArray arrayWithObjects:HCGFeatureEdgeHandle, HCGFeatureAppLaunching, HCGFeatureLockDetection, HCGFeatureOrientation, nil];
    NSArray *labels = [NSArray arrayWithObjects:@"edge handle", @"app launching", @"lock detection", @"orientation", nil];
    NSUInteger i;
    for (i = 0; i < order.count; i++) {
        NSDictionary *feature = [features isKindOfClass:[NSDictionary class]] ? [features objectForKey:[order objectAtIndex:i]] : nil;
        NSString *state = HCGFeatureStateUnknown;
        NSString *detail = @"no report from SpringBoard";
        if ([feature isKindOfClass:[NSDictionary class]]) {
            state = HCGString([feature objectForKey:@"state"], HCGFeatureStateUnknown);
            detail = HCGString([feature objectForKey:@"detail"], @"");
        }
        [out appendFormat:@"%@: %@%@%@\n", [labels objectAtIndex:i], state, detail.length ? @" — " : @"", detail];
    }
}

+ (void)appendDictionary:(NSDictionary *)dict to:(NSMutableString *)out {
    if (![dict isKindOfClass:[NSDictionary class]] || dict.count == 0) {
        [out appendString:@"(none reported)\n"];
        return;
    }
    NSArray *keys = [[dict allKeys] sortedArrayUsingSelector:@selector(compare:)];
    NSUInteger i;
    for (i = 0; i < keys.count; i++) {
        NSString *key = [keys objectAtIndex:i];
        [out appendFormat:@"%@: %@\n", key, HCGString([dict objectForKey:key], @"?")];
    }
}

+ (NSString *)reportWithLocal:(NSDictionary *)local runtime:(NSDictionary *)runtime {
    NSMutableString *out = [[NSMutableString alloc] init];
    [out appendString:@"HCG Nexus diagnostics (personal data and secrets redacted)\n"];
    [out appendFormat:@"generated: %@\n\n", HCGString([local objectForKey:@"generated"], @"unknown")];

    [out appendString:@"== Installed package (Settings bundle) ==\n"];
    [out appendFormat:@"version: %@\n", HCGString([local objectForKey:@"version"], @"unknown")];
    [out appendFormat:@"build: %@ (%@)\n", HCGString([local objectForKey:@"buildID"], @"unknown"), HCGString([local objectForKey:@"buildConfig"], @"unknown")];
    [out appendFormat:@"install location: %@ [evidence: %@]\n\n", HCGString([local objectForKey:@"installPrefix"], @"unknown"),
                      HCGString([local objectForKey:@"installEvidence"], @"none")];

    [out appendString:@"== Device ==\n"];
    [out appendFormat:@"model: %@\n", HCGString([local objectForKey:@"deviceModel"], @"unknown")];
    [out appendFormat:@"iOS: %@ (%@)\n\n", HCGString([local objectForKey:@"osVersion"], @"unknown"), HCGString([local objectForKey:@"osBuild"], @"unknown")];

    NSString *detail = nil;
    NSString *component = [self springBoardStateForInstalledBuild:HCGString([local objectForKey:@"buildID"], @"unknown") runtime:runtime detail:&detail];
    [out appendString:@"== SpringBoard component ==\n"];
    [out appendFormat:@"state: %@ — %@\n", component, detail];
    if ([runtime isKindOfClass:[NSDictionary class]] && runtime.count > 0) {
        [out appendFormat:@"reported: %@\n", [self formatTimestamp:[runtime objectForKey:HCGStatusUpdated]]];
        [out appendFormat:@"running build: %@ (%@), version %@\n", HCGString([runtime objectForKey:HCGStatusBuildID], @"unknown"),
                          HCGString([runtime objectForKey:HCGStatusBuildConfig], @"unknown"), HCGString([runtime objectForKey:HCGStatusVersion], @"unknown")];
        [out appendFormat:@"nexus state: %@%@%@\n", HCGString([runtime objectForKey:HCGStatusState], @"unknown"),
                          [runtime objectForKey:HCGStatusReason] ? @" — " : @"", HCGString([runtime objectForKey:HCGStatusReason], @"")];
        [out appendFormat:@"started by: %@\n", HCGString([runtime objectForKey:HCGStatusStartedBy], @"unknown")];
        [out appendFormat:@"injector [evidence: images loaded in SpringBoard]: %@\n", HCGString([runtime objectForKey:HCGStatusInjector], @"unknown")];
    }
    [out appendString:@"\n== Features ==\n"];
    [self appendFeatures:[runtime isKindOfClass:[NSDictionary class]] ? [runtime objectForKey:HCGStatusFeatures] : nil to:out];

    [out appendString:@"\n== Overlay ==\n"];
    [self appendDictionary:[runtime isKindOfClass:[NSDictionary class]] ? [runtime objectForKey:HCGStatusOverlay] : nil to:out];

    [out appendString:@"\n== Settings ==\n"];
    [out appendFormat:@"%@\n", HCGString([local objectForKey:@"settingsSummary"], @"unknown")];
    [out appendFormat:@"workspaces: %@, recent actions: %@ (%@ failed)\n",
                      HCGString([local objectForKey:@"workspaceCount"], @"?"), HCGString([local objectForKey:@"recentCount"], @"?"),
                      HCGString([local objectForKey:@"recentFailures"], @"?")];

    [out appendString:@"\n== Errors ==\n"];
    NSDictionary *error = [runtime isKindOfClass:[NSDictionary class]] ? [runtime objectForKey:HCGStatusLastError] : nil;
    if ([error isKindOfClass:[NSDictionary class]]) {
        [out appendFormat:@"last SpringBoard error: %@ (%@)\n", HCGString([error objectForKey:@"message"], @"?"),
                          [self formatTimestamp:[error objectForKey:@"time"]]];
    } else {
        [out appendString:@"last SpringBoard error: none reported\n"];
    }
    return [self redact:out];
}

@end
