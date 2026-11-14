// Unit tests for the standalone app (hosted in HCGNexus.app, run with
// `xcodebuild test -scheme HCGNexus -destination 'platform=iOS Simulator,...'`).
// They never open a URL for real, so the app stays in the foreground.
#import <XCTest/XCTest.h>
#import "HCGCore.h"
#import "HCGNexusModel.h"
#import "HCGActionRunner.h"
#import "HCGPanelContext.h"
#import "HCGPanelSettingsViewController.h"
#import "HCGAppPlatform.h"
#import "HCGAppRootViewController.h"
#import "HCGLinkTypes.h"
#import "HCGConnectedDevicesViewController.h"
#import "HCGLinkReportViewController.h"

@interface HCGNexusAppTests : XCTestCase
@end

@implementation HCGNexusAppTests {
    HCGAppDefaultsStore *_store;
}

- (void)setUp {
    [super setUp];
    _store = [[HCGAppDefaultsStore alloc] initWithSuiteName:@"com.hakmicapitalgroup.hcgnexus.app.tests"];
    [_store removeAllValues];
}

- (void)tearDown {
    [_store removeAllValues];
    [super tearDown];
}

- (HCGNexusModel *)makeModel {
    return [[HCGNexusModel alloc] initWithStore:_store notifier:nil launcher:[[HCGAppLauncher alloc] initWithApplication:nil]];
}

- (void)testAppDataIsSeparateFromTweakAndPreview {
    XCTAssertNotEqualObjects(HCGAppDataSuiteName, HCGNexusPreferencesDomain, @"must not share the jailbreak package's domain");
    XCTAssertNotEqualObjects(HCGAppDataSuiteName, @"com.hakmicapitalgroup.hcgnexus.preview");
    XCTAssertTrue([HCGAppDataSuiteName hasPrefix:@"com.hakmicapitalgroup.hcgnexus.app"]);
}

- (void)testLauncherReportsRealCapabilities {
    HCGAppLauncher *launcher = [[HCGAppLauncher alloc] initWithApplication:nil];
    XCTAssertFalse(launcher.simulated);
    XCTAssertFalse([launcher canLaunchApplicationsByBundleIdentifier], @"no public API opens apps by bundle ID");
    XCTAssertFalse([launcher canDetermineInstallation]);
    XCTAssertTrue([launcher bundleLaunchUnavailableExplanation].length > 0);

    XCTestExpectation *done = [self expectationWithDescription:@"bundle launch reports unavailable"];
    [launcher openApplicationWithBundleIdentifier:@"com.apple.mobilenotes" completion:^(NSError *error) {
        XCTAssertEqual(error.code, HCGErrorLauncherUnavailable);
        XCTAssertTrue(error.localizedRecoverySuggestion.length > 0);
        [done fulfill];
    }];
    [self waitForExpectationsWithTimeout:2 handler:nil];
}

- (void)testAppShortcutReportsUnavailableAndIsRecorded {
    HCGNexusModel *model = [self makeModel];
    HCGActionRunner *runner = [[HCGActionRunner alloc] initWithModel:model];
    HCGAction *notes = [HCGAction actionWithKind:HCGActionKindApp title:@"Notes" target:@"com.apple.mobilenotes" symbol:nil];
    __block NSError *result = nil;
    __block BOOL called = NO;
    [runner runAction:notes completion:^(NSError *error, NSString *summary) {
        called = YES;
        result = error;
    }];
    XCTAssertTrue(called, @"unavailable bundle launches fail immediately, without touching UIApplication");
    XCTAssertEqual(result.code, HCGErrorLauncherUnavailable);
    HCGRecentEntry *recent = model.recents.entries.firstObject;
    XCTAssertEqualObjects(recent.action.identifier, notes.identifier);
    XCTAssertFalse(recent.succeeded, @"a failed launch must not be recorded as a success");
}

- (void)testInvalidLinksAreRejectedBeforeOpening {
    HCGNexusModel *model = [self makeModel];
    HCGActionRunner *runner = [[HCGActionRunner alloc] initWithModel:model];
    HCGAction *bad = [HCGAction actionWithKind:HCGActionKindURL title:@"Local file" target:@"file:///etc/hosts" symbol:nil];
    __block NSError *result = nil;
    [runner runAction:bad completion:^(NSError *error, NSString *summary) { result = error; }];
    XCTAssertEqual(result.code, HCGErrorUnsupportedAction);
}

- (void)testConfiguredIntegrationsNeedJailbreakPackage {
    HCGNexusModel *model = [self makeModel];
    HCGSettings *settings = model.settings;
    settings.terminalVariant = HCGTerminalVariantStandard;
    settings.newsConnected = YES;
    [model saveSettings:settings];
    for (NSString *identifier in @[ HCGIntegrationTerminal, HCGIntegrationNews ]) {
        HCGIntegrationStatus *status = [model statusForIntegration:identifier];
        XCTAssertEqual(status.state, HCGIntegrationStateUnavailableHere);
        XCTAssertFalse(status.canLaunch);
    }
    XCTAssertEqualObjects([model statusForIntegration:HCGIntegrationServer].headline, @"Not connected");
}

- (void)testWorkspacesPersistInAppStore {
    HCGNexusModel *model = [self makeModel];
    XCTAssertEqual(model.workspaceStore.workspaces.count, 4u, @"first launch seeds the four presets");
    NSError *error = nil;
    HCGWorkspace *created = [model.workspaceStore createWorkspaceNamed:@"Links" preset:HCGPresetCustom error:&error];
    XCTAssertNotNil(created, @"%@", error);
    HCGAction *link = [HCGAction actionWithKind:HCGActionKindURL title:@"Apple" target:@"https://www.apple.com" symbol:@"link"];
    XCTAssertTrue([model.workspaceStore addAction:link toWorkspace:created.identifier error:&error], @"%@", error);
    XCTAssertTrue([model.workspaceStore renameWorkspace:created.identifier to:@"Web" error:&error], @"%@", error);

    HCGNexusModel *reloaded = [self makeModel];
    HCGWorkspace *found = [reloaded.workspaceStore workspaceWithIdentifier:created.identifier];
    XCTAssertEqualObjects(found.name, @"Web");
    XCTAssertEqualObjects(found.actions.firstObject.target, @"https://www.apple.com");
    NSArray *results = [HCGSearch resultsForQuery:@"appl" inWorkspaces:reloaded.workspaceStore.workspaces activeWorkspace:nil];
    XCTAssertTrue(results.count >= 1);
}

- (void)testStandaloneSettingsHideOverlayControls {
    NSArray<NSNumber *> *app = HCGSettingsSectionsForMode(HCGPanelModeStandaloneApp);
    NSArray<NSNumber *> *overlay = HCGSettingsSectionsForMode(HCGPanelModeOverlay);
    // 0 = enable switch, 1 = edge handle, 2 = motion (overlay transitions).
    for (NSNumber *overlayOnly in @[ @0, @1, @2 ]) {
        XCTAssertFalse([app containsObject:overlayOnly], @"section %@ must not appear in the standalone app", overlayOnly);
        XCTAssertTrue([overlay containsObject:overlayOnly]);
    }
    HCGPanelContext *context = [[HCGPanelContext alloc] init];
    context.mode = HCGPanelModeStandaloneApp;
    XCTAssertFalse(context.overlayControlsOperational);
    XCTAssertTrue(context.isStandaloneApp);
}

- (void)testRootShowsAppModeBadge {
    HCGAppRootViewController *root = [[HCGAppRootViewController alloc] initWithModel:[self makeModel]];
    [root loadViewIfNeeded];
    root.view.frame = CGRectMake(0, 0, 390, 844);
    [root.view layoutIfNeeded];
    XCTAssertEqual(root.context.mode, HCGPanelModeStandaloneApp);
    __block BOOL found = NO;
    __block void (^walk)(UIView *) = ^(UIView *view) {
        if ([view isKindOfClass:[UILabel class]] && [((UILabel *)view).text containsString:@"APP MODE"]) found = YES;
        for (UIView *sub in view.subviews) walk(sub);
    };
    walk(root.view);
    walk = nil;
    XCTAssertTrue(found, @"app mode must be clearly identified");
}

#pragma mark - HCG Device Link (Connected Devices, standalone app only)

- (HCGPanelContext *)appContext {
    HCGPanelContext *context = [[HCGPanelContext alloc] init];
    context.mode = HCGPanelModeStandaloneApp;
    context.model = [self makeModel];
    return context;
}

- (void)testConnectedDevicesIsStandaloneAppOnly {
    // 8 = HCGSettingsSectionConnectedDevices.
    XCTAssertTrue([HCGSettingsSectionsForMode(HCGPanelModeStandaloneApp) containsObject:@8]);
    XCTAssertFalse([HCGSettingsSectionsForMode(HCGPanelModeOverlay) containsObject:@8]);
    XCTAssertFalse([HCGSettingsSectionsForMode(HCGPanelModeSettingsApp) containsObject:@8]);
    XCTAssertFalse([HCGSettingsSectionsForMode(HCGPanelModePreview) containsObject:@8]);
    HCGAppRootViewController *root = [[HCGAppRootViewController alloc] initWithModel:[self makeModel]];
    XCTAssertNotNil(root.context.connectedDevicesScreen, @"the app wires the Connected Devices screen");
    XCTAssertNil([self appContext].connectedDevicesScreen, @"nothing else provides it");
}

- (void)testDeviceLinkServiceIsLinkedAndNotConfiguredUntilHCGIssuesAClient {
    id<HCGLinkServicing> service = HCGSharedLinkService();
    XCTAssertNotNil(service, @"the Swift HCGLinkService must be linked into the app");
    XCTAssertTrue([(NSObject *)service conformsToProtocol:@protocol(HCGLinkServicing)]);
    XCTAssertTrue(service == HCGSharedLinkService(), @"one shared service");
    HCGLinkSnapshot *snapshot = service.snapshot;
    // Info.plist HCGConnectClientID / HCGConnectRedirectURI are empty: nothing is contacted.
    XCTAssertEqual(snapshot.accountState, HCGLinkAccountStateNotConfigured);
    XCTAssertTrue(snapshot.accountDetail.length > 0);
    XCTAssertEqual(snapshot.connectionState, HCGLinkConnectionStateNotPaired);
    XCTAssertEqual(snapshot.approvalsCount, 0);
    XCTAssertFalse(snapshot.executionEnabled);
    NSMutableArray<NSString *> *advertised = [NSMutableArray array];
    for (HCGLinkCapabilityInfo *capability in snapshot.advertisedCapabilities) {
        [advertised addObject:capability.identifier];
        XCTAssertEqualObjects(capability.state, @"available");
    }
    XCTAssertEqualObjects(advertised, (@[ @"report.receive", @"report.view" ]), @"Nexus only receives and views reports");
    XCTAssertNotNil([service previewInvitationCode:@"https://example.test/not-an-invitation"].problem);
}

- (void)testSharedReportIsShownAsPlainData {
    HCGLinkOpenedReport *report = [[HCGLinkOpenedReport alloc] init];
    report.title = @"Exposure Check — 1 finding";
    report.fromName = @"Ana's iPhone";
    report.fromApp = @"HCG Sentinel";
    HCGLinkReportSection *section = [[HCGLinkReportSection alloc] init];
    section.title = @"Finding 1: <b>Open admin panel</b>";
    section.lines = @[ @"Location: https://example.test/admin", @"Evidence: $(rm -rf ~) [link](https://example.test)" ];
    report.sections = @[ section ];
    XCTAssertEqualObjects([HCGLinkReportViewController headerTextForReport:report],
                          @"Report from Ana's iPhone (remote) — data only, never executed");

    HCGLinkReportViewController *viewer = [[HCGLinkReportViewController alloc] initWithContext:[self appContext] report:report];
    [viewer loadViewIfNeeded];
    XCTAssertFalse(viewer.tableView.allowsSelection, @"nothing in a report can be tapped");
    XCTAssertEqual([viewer numberOfSectionsInTableView:viewer.tableView], 2);
    XCTAssertEqualObjects([viewer tableView:viewer.tableView titleForHeaderInSection:1], section.title, @"shown verbatim, not as HTML");
    for (NSInteger row = 0; row < 2; row++) {
        UITableViewCell *cell = [viewer tableView:viewer.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:row inSection:1]];
        XCTAssertEqualObjects(cell.textLabel.text, section.lines[(NSUInteger)row], @"verbatim plain text");
        NSAttributedString *text = cell.textLabel.attributedText;
        __block BOOL linked = NO;
        [text enumerateAttribute:NSLinkAttributeName inRange:NSMakeRange(0, text.length) options:0
                      usingBlock:^(id value, NSRange range, BOOL *stop) { if (value) linked = YES; }];
        XCTAssertFalse(linked, @"no string becomes a link");
    }
    UITableViewCell *header = [viewer tableView:viewer.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]];
    XCTAssertTrue([header.textLabel.text containsString:@"data only, never executed"]);
}

- (void)testConnectedDevicesWithoutServiceSaysSo {
    HCGConnectedDevicesViewController *screen = [[HCGConnectedDevicesViewController alloc] initWithContext:[self appContext] service:nil];
    [screen loadViewIfNeeded];
    XCTAssertEqual([screen numberOfSectionsInTableView:screen.tableView], 1);
    UITableViewCell *cell = [screen tableView:screen.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]];
    XCTAssertEqualObjects(cell.textLabel.text, @"Not available in this build");
}

- (void)testConnectedDevicesScreenShowsLocalDeviceAndAccount {
    id<HCGLinkServicing> service = HCGSharedLinkService();
    XCTAssertNotNil(service);
    HCGConnectedDevicesViewController *screen = [[HCGConnectedDevicesViewController alloc] initWithContext:[self appContext] service:service];
    [screen loadViewIfNeeded];
    NSMutableArray<NSString *> *headers = [NSMutableArray array];
    for (NSInteger i = 0; i < [screen numberOfSectionsInTableView:screen.tableView]; i++) {
        [headers addObject:[screen tableView:screen.tableView titleForHeaderInSection:i] ?: @""];
    }
    XCTAssertTrue([headers containsObject:@"HCG Connect account"]);
    XCTAssertTrue([headers containsObject:@"This device"]);
    XCTAssertTrue([headers containsObject:@"Pair device"]);
    NSInteger local = (NSInteger)[headers indexOfObject:@"This device"];
    UITableViewCell *cell = [screen tableView:screen.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:local]];
    XCTAssertTrue([cell.accessibilityLabel containsString:@"this device"], @"the local device is labelled LOCAL");
}

@end
