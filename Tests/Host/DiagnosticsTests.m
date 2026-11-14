#import "HCGTestHarness.h"
#import "HCGCore.h"

static NSMutableDictionary *Runtime(NSString *build, NSString *state) {
    NSMutableDictionary *r = [[NSMutableDictionary alloc] init];
    [r setObject:[NSNumber numberWithInteger:HCGRuntimeStatusSchemaVersion] forKey:HCGStatusSchema];
    [r setObject:build forKey:HCGStatusBuildID];
    [r setObject:@"rootless-release" forKey:HCGStatusBuildConfig];
    [r setObject:state forKey:HCGStatusState];
    [r setObject:[NSNumber numberWithDouble:1763000000] forKey:HCGStatusUpdated];
    return r;
}

static void testComponentStates(void) {
    NSString *detail = nil;
    HCG_CHECK_EQ_STR([HCGDiagnostics springBoardStateForInstalledBuild:@"abc" runtime:nil detail:&detail], HCGComponentNotLoaded);
    HCG_CHECK([detail rangeOfString:@"respring"].location != NSNotFound, "not-loaded explains the respring");
    HCG_CHECK_EQ_STR([HCGDiagnostics springBoardStateForInstalledBuild:@"abc" runtime:Runtime(@"abc", @"active") detail:&detail], HCGComponentRunning);
    HCG_CHECK_EQ_STR([HCGDiagnostics springBoardStateForInstalledBuild:@"abc" runtime:Runtime(@"abc", @"disabled") detail:&detail], HCGComponentRunning);
    HCG_CHECK_EQ_STR([HCGDiagnostics springBoardStateForInstalledBuild:@"new" runtime:Runtime(@"old", @"active") detail:&detail], HCGComponentRespringRequired);
    HCG_CHECK([detail rangeOfString:@"old"].location != NSNotFound && [detail rangeOfString:@"new"].location != NSNotFound, "names both builds");
    NSMutableDictionary *stopped = Runtime(@"abc", @"stopped");
    [stopped setObject:@"kill switch present" forKey:HCGStatusReason];
    HCG_CHECK_EQ_STR([HCGDiagnostics springBoardStateForInstalledBuild:@"abc" runtime:stopped detail:&detail], HCGComponentStopped);
    HCG_CHECK([detail rangeOfString:@"kill switch"].location != NSNotFound, "gives the stop reason");
    // A report from a 0.1.x build (no schema/buildID) means the old dylib still runs.
    NSDictionary *legacy = [NSDictionary dictionaryWithObjectsAndKeys:@"0.1.0 · package scheme: rootless", @"version", nil];
    HCG_CHECK_EQ_STR([HCGDiagnostics springBoardStateForInstalledBuild:@"abc" runtime:legacy detail:&detail], HCGComponentRespringRequired);
}

static void testRedaction(void) {
    NSString *in = @"user someone@example.com token=abc123 password: hunter2 Authorization: Bearer eyJhbGciOi.payload.sig "
                   @"device 00008110-001A2B3C4D5E6F70 uuid 123E4567-E89B-12D3-A456-426614174000 "
                   @"key=QUJDREVGR0hJSktMTU5PUFFSU1RVVldYWVphYmNkZWZnaGlqa2xtbm9wcXJzdHV2 sha 0123456789abcdef0123456789abcdef01234567";
    NSString *out = [HCGDiagnostics redact:in];
    NSArray *leaks = [NSArray arrayWithObjects:@"someone@example.com", @"abc123", @"hunter2", @"eyJhbGciOi", @"00008110-001A2B3C4D5E6F70",
                      @"123E4567-E89B-12D3-A456-426614174000", @"QUJDREVGR0hJSktMTU5PUFFS", @"0123456789abcdef0123456789abcdef01234567", nil];
    NSUInteger i;
    for (i = 0; i < leaks.count; i++) {
        HCG_CHECK([out rangeOfString:[leaks objectAtIndex:i]].location == NSNotFound, "leaked %s in: %s", [[leaks objectAtIndex:i] UTF8String], [out UTF8String]);
    }
    // Useful identifiers must survive.
    NSString *keep = @"build f3298b92ce-dirty rootless-release iPhone14,2 iOS 16.5 (20F66) com.hakmicapitalgroup.hcgnexus";
    HCG_CHECK_EQ_STR([HCGDiagnostics redact:keep], keep);
}

static void testReportContents(void) {
    NSMutableDictionary *runtime = Runtime(@"abc1234567", @"active");
    [runtime setObject:@"libellekit.dylib" forKey:HCGStatusInjector];
    NSMutableDictionary *features = [[NSMutableDictionary alloc] init];
    [features setObject:[HCGDiagnostics featureWithState:HCGFeatureStateOK detail:@"Available"] forKey:HCGFeatureEdgeHandle];
    [features setObject:[HCGDiagnostics featureWithState:HCGFeatureStateUnsupported detail:@"LaunchServices selector missing"] forKey:HCGFeatureAppLaunching];
    [runtime setObject:features forKey:HCGStatusFeatures];
    NSDictionary *error = [NSDictionary dictionaryWithObjectsAndKeys:@"boom for someone@example.com", @"message", [NSNumber numberWithDouble:1763000100], @"time", nil];
    [runtime setObject:error forKey:HCGStatusLastError];
    NSDictionary *local = [NSDictionary dictionaryWithObjectsAndKeys:@"0.2.0", @"version", @"abc1234567", @"buildID", @"rootless-release", @"buildConfig",
                           @"iPhone14,2", @"deviceModel", @"16.5", @"osVersion", @"20F66", @"osBuild", @"/var/jb (rootless)", @"installPrefix",
                           @"Settings bundle path", @"installEvidence", @"enabled: yes", @"settingsSummary", nil];
    NSString *report = [HCGDiagnostics reportWithLocal:local runtime:runtime];
    NSArray *expected = [NSArray arrayWithObjects:@"version: 0.2.0", @"build: abc1234567 (rootless-release)", @"model: iPhone14,2",
                         @"state: running", @"edge handle: ok — Available", @"app launching: unsupported — LaunchServices selector missing",
                         @"lock detection: unknown", @"injector [evidence: images loaded in SpringBoard]: libellekit.dylib",
                         @"last SpringBoard error: boom for <redacted-email>", @"2025-11-13 02:13:20 UTC", nil];
    NSUInteger i;
    for (i = 0; i < expected.count; i++) {
        HCG_CHECK([report rangeOfString:[expected objectAtIndex:i]].location != NSNotFound, "report lacks '%s'", [[expected objectAtIndex:i] UTF8String]);
    }
    NSString *empty = [HCGDiagnostics reportWithLocal:[NSDictionary dictionary] runtime:nil];
    HCG_CHECK([empty rangeOfString:@"state: not-loaded"].location != NSNotFound, "no runtime => not-loaded");
    HCG_CHECK([empty rangeOfString:@"edge handle: unknown — no report from SpringBoard"].location != NSNotFound, "unknown, not ok");
}

void HCGRunDiagnosticsTests(void) {
    HCG_RUN(testComponentStates);
    HCG_RUN(testRedaction);
    HCG_RUN(testReportContents);
}
