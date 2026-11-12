#import "HCGPreviewSelfCheck.h"
#import "HCGCore.h"
#import "HCGNexusModel.h"
#import "HCGOverlayController.h"
#import "HCGActionRunner.h"
#import "HCGPreviewPlatform.h"

@interface HCGCheckLog : NSObject
@property (nonatomic) NSMutableString *text;
@property (nonatomic) NSUInteger passes;
@property (nonatomic) NSUInteger failures;
- (void)check:(BOOL)condition name:(NSString *)name;
@end

@implementation HCGCheckLog
- (instancetype)init {
    if ((self = [super init])) _text = [NSMutableString string];
    return self;
}
- (void)check:(BOOL)condition name:(NSString *)name {
    if (condition) self.passes++; else self.failures++;
    [self.text appendFormat:@"%@  %@\n", condition ? @"PASS" : @"FAIL", name];
}
@end

static HCGSystemSignals Signals(HCGTriState locked, HCGTriState cover) {
    HCGSystemSignals s;
    s.deviceLocked = locked;
    s.coverSheetVisible = cover;
    s.screenBlanked = HCGTriStateNo;
    return s;
}

@implementation HCGPreviewSelfCheck

+ (NSString *)runInHostViewController:(UIViewController *)host passed:(BOOL *)passed {
    HCGCheckLog *log = [[HCGCheckLog alloc] init];
    [log.text appendString:@"HCG Nexus preview self-check\nScope: Panel + Core code with simulated platform. NOT a SpringBoard/device verification.\n\n"];

    UIViewController *checkHost = [[UIViewController alloc] init];
    [host addChildViewController:checkHost];
    checkHost.view.frame = host.view.bounds;
    checkHost.view.alpha = 0.01; // on-screen for window-dependent checks, effectively invisible
    checkHost.view.userInteractionEnabled = NO;
    [host.view addSubview:checkHost.view];
    [checkHost didMoveToParentViewController:host];

    HCGUserDefaultsKeyValueStore *store = [[HCGUserDefaultsKeyValueStore alloc] initWithSuiteName:@"com.hakmicapitalgroup.hcgnexus.preview.selfcheck"];
    [store removeAllValues];
    HCGPreviewLauncher *launcher = [[HCGPreviewLauncher alloc] init];
    HCGNexusModel *model = [[HCGNexusModel alloc] initWithStore:store notifier:nil launcher:launcher];
    HCGPreviewEnvironment *env = [[HCGPreviewEnvironment alloc] initWithHostViewController:checkHost];
    HCGOverlayController *overlay = [[HCGOverlayController alloc] initWithModel:model environment:env];
    overlay.coordinator.reduceMotion = NO;
    [overlay updateSystemSignals:Signals(HCGTriStateNo, HCGTriStateNo)];
    [overlay applyModelSettings];

    // 1. Starts disabled
    [log check:!model.settings.enabled name:@"Fresh install is disabled"];
    [log check:![overlay isHandleOnScreen] && overlay.coordinator.installCount == 0 name:@"Disabled: no overlay created"];

    // 2. Enable (animations off => synchronous transitions)
    HCGSettings *settings = model.settings;
    settings.enabled = YES;
    settings.animationsEnabled = NO;
    [model saveSettings:settings];
    [log check:[overlay isHandleOnScreen] name:@"Enabled: handle visible"];

    // 3. Repeated open/close
    BOOL cycleOK = YES;
    for (int i = 0; i < 50; i++) {
        [overlay simulateHandleActivation];
        if (![overlay isPanelOnScreen]) cycleOK = NO;
        [overlay simulateOutsideTap];
        if ([overlay isPanelOnScreen]) cycleOK = NO;
    }
    [log check:cycleOK name:@"50x open (handle) / close (outside tap)"];

    // 4. No duplicates after toggling
    for (int i = 0; i < 20; i++) {
        settings.enabled = (i % 2 == 1);
        [model saveSettings:settings];
    }
    [log check:overlay.coordinator.installCount == 1 && env.containerInstallCount == 1 name:@"Overlay container installed exactly once"];
    [log check:[overlay installedGestureRecognizerCount] == 3 name:@"Exactly 3 gesture recognisers (handle tap, handle pan, outside tap)"];

    // 5. Disable while open
    [overlay simulateHandleActivation];
    settings.enabled = NO;
    [model saveSettings:settings];
    [log check:![overlay isPanelOnScreen] && ![overlay isHandleOnScreen] name:@"Disable closes panel and removes handle immediately"];
    [overlay simulateHandleActivation];
    [log check:![overlay isPanelOnScreen] name:@"Disabled: activation ignored"];

    // 6. Lock / cover sheet
    settings.enabled = YES;
    [model saveSettings:settings];
    [overlay simulateHandleActivation];
    [overlay updateSystemSignals:Signals(HCGTriStateYes, HCGTriStateNo)];
    [log check:![overlay isPanelOnScreen] && ![overlay isHandleOnScreen] name:@"Simulated lock hides panel and handle"];
    [overlay updateSystemSignals:Signals(HCGTriStateNo, HCGTriStateYes)];
    [log check:![overlay isHandleOnScreen] name:@"Simulated cover sheet keeps overlay hidden"];
    [overlay updateSystemSignals:Signals(HCGTriStateNo, HCGTriStateNo)];
    [log check:[overlay isHandleOnScreen] && ![overlay isPanelOnScreen] name:@"Unlock restores handle; panel stays closed"];

    // 7. Workspace persistence
    NSError *error = nil;
    HCGWorkspaceStore *ws = model.workspaceStore;
    HCGWorkspace *created = [ws createWorkspaceNamed:@"Self Check" preset:HCGPresetStudio error:&error];
    BOOL renamed = created && [ws renameWorkspace:created.identifier to:@"Self Check 2" error:&error];
    BOOL moved = [ws moveWorkspaceFromIndex:ws.workspaces.count - 1 toIndex:0 error:&error];
    HCGWorkspaceStore *reloaded = [[HCGWorkspaceStore alloc] initWithStore:store];
    [reloaded load];
    BOOL persisted = reloaded.workspaces.count == 5 && [reloaded.workspaces.firstObject.name isEqualToString:@"Self Check 2"];
    BOOL deleted = [ws deleteWorkspace:created.identifier error:&error];
    [reloaded load];
    [log check:renamed && moved && persisted && deleted && reloaded.workspaces.count == 4 name:@"Workspace create/rename/reorder/delete persist"];

    // 8. Integrations
    NSArray<HCGIntegrationStatus *> *statuses = [model integrationStatuses];
    BOOL allNotConnected = statuses.count == 4;
    for (HCGIntegrationStatus *status in statuses) {
        if (![status.headline isEqualToString:@"Not connected"]) allNotConnected = NO;
    }
    [log check:allNotConnected name:@"Unconfigured integrations show \"Not connected\""];

    // 9. Actionable errors (synchronous paths)
    HCGActionRunner *runner = [[HCGActionRunner alloc] initWithModel:model];
    __block NSError *missing = nil;
    [runner runAction:[HCGAction actionWithKind:HCGActionKindApp title:@"Ghost" target:@"com.example.not-installed" symbol:nil]
           completion:^(NSError *e, NSString *s) { missing = e; }];
    [log check:missing.code == HCGErrorAppNotInstalled && missing.localizedRecoverySuggestion.length > 0 name:@"Missing app -> actionable error"];
    __block NSError *server = nil;
    [runner runAction:[HCGAction actionWithKind:HCGActionKindIntegration title:@"HCG Server" target:HCGIntegrationServer symbol:nil]
           completion:^(NSError *e, NSString *s) { server = e; }];
    [log check:server.code == HCGErrorIntegrationNotConnected name:@"Unconnected integration -> actionable error"];

    // 10. Geometry in the current orientation
    [overlay interfaceOrientationMayHaveChanged];
    NSDictionary *diag = [overlay diagnostics];
    [log check:[diag[@"panelState"] isEqualToString:@"closed"] name:@"Final panel state is closed"];

    [log.text appendFormat:@"\n%lu passed, %lu failed\nOrientation during run: %@ (rotate the simulator/device and run again to cover other orientations)\n",
                           (unsigned long)log.passes, (unsigned long)log.failures, diag[@"orientation"]];

    settings.enabled = NO;
    [model saveSettings:settings];
    [checkHost willMoveToParentViewController:nil];
    [checkHost.view removeFromSuperview];
    [checkHost removeFromParentViewController];
    [store removeAllValues];

    if (passed) *passed = log.failures == 0;
    NSLog(@"%@", log.text);
    return log.text;
}

@end
