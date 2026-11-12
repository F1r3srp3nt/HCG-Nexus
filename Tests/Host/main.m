#import "HCGTestHarness.h"

int HCGTestFailures = 0;
int HCGTestChecks = 0;
const char *HCGCurrentTest = "";

int main(int argc, const char *argv[]) {
    (void)argc; (void)argv;
    // One pool for the whole run: Core code is written for ARC and is compiled
    // here with manual reference counting, so it leaks rather than over-releases.
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    fprintf(stdout, "HCG Nexus host tests (Core layer)\n");
    HCGRunSettingsTests();
    HCGRunActionTests();
    HCGRunWorkspaceStoreTests();
    HCGRunRecentsTests();
    HCGRunSearchTests();
    HCGRunIntegrationTests();
    HCGRunGeometryTests();
    HCGRunStateMachineTests();
    HCGRunOverlayTests();
    fprintf(stdout, "%d checks, %d failures\n", HCGTestChecks, HCGTestFailures);
    [pool release];
    return HCGTestFailures == 0 ? 0 : 1;
}
