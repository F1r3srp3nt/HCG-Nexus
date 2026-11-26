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
#import "HCGLinkDiagnosticsViewController.h"
#import "HCGPanelHomeViewController.h"
#import "HCGSections.h"
#import "HCGTheme.h"
#import "HCGAppAccountProvider.h"
#import "HCGCommandModeViewController.h"

@interface HCGNexusAppTests : XCTestCase
@end

static void HCGCollectAccessibilityLabels(UIView *view, NSMutableArray<NSString *> *labels) {
    if (view.isAccessibilityElement && view.accessibilityLabel.length) [labels addObject:view.accessibilityLabel];
    for (UIView *sub in view.subviews) HCGCollectAccessibilityLabels(sub, labels);
}

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
    // Enable switch, edge handle, motion (overlay transitions) and "Use HCG Halo border" (HCG Halo is a jailbreak
    // package) belong to the overlay.
    for (NSNumber *overlayOnly in @[ @(HCGSettingsSectionGeneral), @(HCGSettingsSectionHandle), @(HCGSettingsSectionMotion),
                                     @(HCGSettingsSectionHaloBorder) ]) {
        XCTAssertFalse([app containsObject:overlayOnly], @"section %@ must not appear in the standalone app", overlayOnly);
        XCTAssertTrue([overlay containsObject:overlayOnly]);
    }
    HCGPanelContext *context = [[HCGPanelContext alloc] init];
    context.mode = HCGPanelModeStandaloneApp;
    XCTAssertFalse(context.overlayControlsOperational);
    XCTAssertTrue(context.isStandaloneApp);
}

// Every Settings row builds in every mode, with a title: a section listed for a mode but not wired
// for it (or wired to overlay-only state) fails here instead of on a device.
- (void)testSettingsBuildEveryRowInEveryMode {
    for (NSNumber *mode in @[ @(HCGPanelModeStandaloneApp), @(HCGPanelModeOverlay), @(HCGPanelModePreview) ]) {
        HCGPanelContext *context = [self appContextWithModel:[self makeModel]];
        context.mode = (HCGPanelMode)mode.integerValue;
        HCGPanelSettingsViewController *settings = [[HCGPanelSettingsViewController alloc] initWithContext:context];
        [settings loadViewIfNeeded];
        [settings beginAppearanceTransition:YES animated:NO]; // fills Diagnostics, as on screen
        [settings endAppearanceTransition];
        UITableView *table = settings.tableView;
        NSInteger sections = [settings numberOfSectionsInTableView:table];
        XCTAssertEqual(sections, (NSInteger)HCGSettingsSectionsForMode(context.mode).count, @"mode %@", mode);
        for (NSInteger section = 0; section < sections; section++) {
            XCTAssertGreaterThan([settings tableView:table titleForHeaderInSection:section].length, 0u, @"mode %@ section %ld", mode, (long)section);
            NSInteger rows = [settings tableView:table numberOfRowsInSection:section];
            XCTAssertGreaterThan(rows, 0, @"mode %@ section %ld", mode, (long)section);
            for (NSInteger row = 0; row < rows; row++) {
                UITableViewCell *cell = [settings tableView:table cellForRowAtIndexPath:[NSIndexPath indexPathForRow:row inSection:section]];
                XCTAssertNotNil(cell, @"mode %@ section %ld row %ld", mode, (long)section, (long)row);
            }
        }
    }
}

- (void)testSettingsShowAboutSectionInEveryMode {
    // About (HCG Repo product page) and Panel glass (the app's panel uses the same glass) are in every mode.
    for (NSNumber *mode in @[ @(HCGPanelModeStandaloneApp), @(HCGPanelModeOverlay), @(HCGPanelModePreview) ]) {
        NSArray<NSNumber *> *sections = HCGSettingsSectionsForMode((HCGPanelMode)mode.integerValue);
        XCTAssertTrue([sections containsObject:@(HCGSettingsSectionAbout)], @"mode %@", mode);
        XCTAssertTrue([sections containsObject:@(HCGSettingsSectionGlass)], @"mode %@", mode);
    }
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
    XCTAssertTrue([HCGSettingsSectionsForMode(HCGPanelModeStandaloneApp) containsObject:@(HCGSettingsSectionConnectedDevices)]);
    XCTAssertFalse([HCGSettingsSectionsForMode(HCGPanelModeOverlay) containsObject:@(HCGSettingsSectionConnectedDevices)]);
    XCTAssertFalse([HCGSettingsSectionsForMode(HCGPanelModeSettingsApp) containsObject:@(HCGSettingsSectionConnectedDevices)]);
    XCTAssertFalse([HCGSettingsSectionsForMode(HCGPanelModePreview) containsObject:@(HCGSettingsSectionConnectedDevices)]);
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

static NSString *HCGTestInvitation(NSString *authMode) {
    NSMutableDictionary *payload = [@{ @"v" : @1, @"id" : @"inv-test", @"s" : @"single-use-test-value", @"hd" : @"dev-test",
                                       @"hn" : @"Studio Mac", @"ha" : @"studio.local:7610",
                                       @"fp" : [@"" stringByPaddingToLength:64 withString:@"ab" startingAtIndex:0] } mutableCopy];
    if (authMode) payload[@"am"] = authMode;
    NSData *json = [NSJSONSerialization dataWithJSONObject:payload options:0 error:nil];
    NSString *b64 = [[json base64EncodedStringWithOptions:0] stringByReplacingOccurrencesOfString:@"+" withString:@"-"];
    b64 = [[b64 stringByReplacingOccurrencesOfString:@"/" withString:@"_"] stringByReplacingOccurrencesOfString:@"=" withString:@""];
    return [@"hcg1-" stringByAppendingString:b64];
}

// Local development pairing is offered only when the invitation says so; HCG Connect pairing still needs
// Nexus's issued HCG Connect client (not issued: Info.plist keys are empty).
- (void)testLocalDevelopmentPairingOnlyWhenTheInvitationSaysSo {
    id<HCGLinkServicing> service = HCGSharedLinkService();
    XCTAssertTrue(HCGExistingLinkService() == service, @"existing service is the shared one once created");
    HCGLinkSnapshot *snapshot = service.snapshot;
    XCTAssertEqual(snapshot.accountState, HCGLinkAccountStateNotConfigured);

    HCGLinkInvitationPreview *local = [service previewInvitationCode:HCGTestInvitation(@"local-development")];
    XCTAssertTrue(local.localDevelopment);
    XCTAssertEqualObjects(local.serverName, @"Studio Mac");
    XCTAssertFalse([local.problem isEqualToString:snapshot.accountDetail], @"local development needs no HCG Connect client");
    if (local.problem) XCTAssertEqualObjects(local.problem, snapshot.identityProblem, @"only a missing device key can block it");

    HCGLinkInvitationPreview *connect = [service previewInvitationCode:HCGTestInvitation(nil)];
    XCTAssertFalse(connect.localDevelopment);
    XCTAssertNotNil(connect.problem, @"HCG Connect pairing stays unavailable until HCG issues Nexus a client");

    HCGLinkInvitationPreview *other = [service previewInvitationCode:HCGTestInvitation(@"something-else")];
    XCTAssertFalse(other.localDevelopment, @"only the exact local-development mode skips HCG Connect");
    XCTAssertNotNil(other.problem);
}

- (void)testLocalDevelopmentLabelIsTheSameEverywhere {
    XCTAssertEqualObjects(HCGLinkLocalDevelopmentLabel, @"LOCAL DEVELOPMENT — not an HCG account");
    XCTAssertEqualObjects(HCGLinkLocalDevelopmentLabel, HCGHIPLocalDevelopmentLabel);
}

// HCG Interchange: HCG Server's card reflects the real Device Link state and says Connected only after a
// successful sync, recently.
- (void)testServerFactsFollowTheRealLinkState {
    NSDate *now = [NSDate date];
    HCGHIPFacts *f = [[HCGHIPFacts alloc] init];
    HCGAppApplyLinkSnapshot(nil, f, now);
    XCTAssertEqual(f.serviceLinkState, HCGHIPServiceLinkStateNotConnected, @"service not used since launch: not connected");

    HCGLinkSnapshot *s = [[HCGLinkSnapshot alloc] init];
    f = [[HCGHIPFacts alloc] init];
    HCGAppApplyLinkSnapshot(s, f, now);
    XCTAssertEqual(f.serviceLinkState, HCGHIPServiceLinkStateNotPaired);

    s.serverName = @"Studio Mac";
    s.connectionState = HCGLinkConnectionStatePaired;
    HCGAppApplyLinkSnapshot(s, f, now);
    XCTAssertEqual(f.serviceLinkState, HCGHIPServiceLinkStateNotConnected, @"approved earlier is not connected");

    s.connectionState = HCGLinkConnectionStateConnected;
    s.lastSync = nil;
    HCGAppApplyLinkSnapshot(s, f, now);
    XCTAssertEqual(f.serviceLinkState, HCGHIPServiceLinkStateNotConnected, @"no completed sync yet");

    s.lastSync = [now dateByAddingTimeInterval:-5];
    s.localDevelopment = YES;
    s.servicesLoaded = YES;
    s.services = @[ [[HCGLinkHostedServiceInfo alloc] init] ];
    HCGAppApplyLinkSnapshot(s, f, now);
    XCTAssertEqual(f.serviceLinkState, HCGHIPServiceLinkStateConnected);
    XCTAssertTrue(f.serviceLinkLocalDevelopment);
    XCTAssertEqual(f.serviceLinkHostedServices, 1);
    XCTAssertEqualObjects(f.serviceLinkServerName, @"Studio Mac");
    HCGHIPProductStatus *status = [HCGInterchange statusForDescriptor:[HCGInterchange descriptorForProductID:HCGHIPProductServer] facts:f];
    XCTAssertEqualObjects(status.stateTitle, @"Connected");
    XCTAssertTrue([status.integrationText containsString:HCGLinkLocalDevelopmentLabel]);

    s.lastSync = [now dateByAddingTimeInterval:-(HCGAppLinkConnectedWindow + 1)];
    HCGAppApplyLinkSnapshot(s, f, now);
    XCTAssertEqual(f.serviceLinkState, HCGHIPServiceLinkStateNotConnected, @"an old sync is not a connection");

    s.connectionState = HCGLinkConnectionStateOffline;
    s.connectionDetail = @"The request timed out.";
    HCGAppApplyLinkSnapshot(s, f, now);
    XCTAssertEqual(f.serviceLinkState, HCGHIPServiceLinkStateUnreachable);
    XCTAssertEqualObjects(f.serviceLinkDetail, @"The request timed out.");

    s.connectionState = HCGLinkConnectionStateAuthorityChanged;
    s.connectionDetail = @"Studio Mac changed how it authorizes apps.";
    HCGAppApplyLinkSnapshot(s, f, now);
    XCTAssertEqual(f.serviceLinkState, HCGHIPServiceLinkStateEnded);
    XCTAssertEqualObjects(f.serviceLinkDetail, s.connectionDetail);
}

- (void)testDiagnosticsAreShownAsPlainData {
    HCGLinkDiagnosticsInfo *d = [[HCGLinkDiagnosticsInfo alloc] init];
    d.serverName = @"Studio Mac";
    d.localDevelopment = YES;
    HCGLinkReportSection *section = [[HCGLinkReportSection alloc] init];
    section.title = @"Security events (redacted by the server)";
    section.lines = @[ @"Failed authentications (24 h): 0", @"see https://example.test" ];
    d.sections = @[ section ];
    XCTAssertTrue([[HCGLinkDiagnosticsViewController headerTextForDiagnostics:d] containsString:HCGLinkLocalDevelopmentLabel]);
    d.localDevelopment = NO;
    XCTAssertFalse([[HCGLinkDiagnosticsViewController headerTextForDiagnostics:d] containsString:@"LOCAL DEVELOPMENT"]);
    HCGLinkDiagnosticsViewController *viewer = [[HCGLinkDiagnosticsViewController alloc] initWithContext:[self appContext] diagnostics:d];
    [viewer loadViewIfNeeded];
    XCTAssertFalse(viewer.tableView.allowsSelection, @"read-only");
    XCTAssertEqual([viewer numberOfSectionsInTableView:viewer.tableView], 2);
    UITableViewCell *cell = [viewer tableView:viewer.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:1 inSection:1]];
    XCTAssertEqualObjects(cell.textLabel.text, @"see https://example.test", @"verbatim plain text");
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

#pragma mark - Layout 2 (redesign)

- (HCGPanelContext *)appContextWithModel:(HCGNexusModel *)model {
    HCGPanelContext *context = [[HCGPanelContext alloc] init];
    context.mode = HCGPanelModeStandaloneApp;
    context.model = model;
    context.runner = [[HCGActionRunner alloc] initWithModel:model];
    context.environmentName = @"tests";
    return context;
}

// A system-drawn, non-interactive cell accessory (disclosure chevron, checkmark). Recent iOS draws these with a
// UIButton outside the content view; it is decoration, the row itself is the touch target. Interactive system
// accessories (detail buttons) and anything Nexus adds itself (content view, accessoryView) are still checked.
static BOOL HCGIsDecorativeCellAccessory(UIView *view) {
    UIView *ancestor = view.superview;
    while (ancestor && ![ancestor isKindOfClass:[UITableViewCell class]]) ancestor = ancestor.superview;
    if (!ancestor) return NO;
    UITableViewCell *cell = (UITableViewCell *)ancestor;
    if ([view isDescendantOfView:cell.contentView]) return NO;
    if (cell.accessoryView && [view isDescendantOfView:cell.accessoryView]) return NO;
    UITableViewCellAccessoryType type = cell.isEditing ? cell.editingAccessoryType : cell.accessoryType;
    return type == UITableViewCellAccessoryDisclosureIndicator || type == UITableViewCellAccessoryCheckmark;
}

static void HCGCollectLabels(UIView *view, NSMutableArray<UILabel *> *out) {
    if (view.hidden || view.alpha <= 0.01) return;
    if ([view isKindOfClass:[UILabel class]] && view.window && !CGRectIsEmpty(view.frame)) [out addObject:(UILabel *)view];
    for (UIView *sub in view.subviews) HCGCollectLabels(sub, out);
}

static void HCGCollectButtons(UIView *view, NSMutableArray<UIButton *> *out) {
    if ([view isKindOfClass:[UIButton class]] && !view.hidden && view.alpha > 0.01 && !HCGIsDecorativeCellAccessory(view)) {
        [out addObject:(UIButton *)view];
    }
    for (UIView *sub in view.subviews) HCGCollectButtons(sub, out);
}

// Every section loads in a phone-sized window; every visible button is labelled for VoiceOver
// and has at least a 44 pt touch target.
- (void)testEverySectionLoadsWithLabelledTouchTargets {
    HCGNexusModel *model = [self makeModel];
    HCGPanelHomeViewController *home = [[HCGPanelHomeViewController alloc] initWithContext:[self appContextWithModel:model]];
    UINavigationController *navigation = [[UINavigationController alloc] initWithRootViewController:home];
    UIWindow *window = [[UIWindow alloc] initWithFrame:CGRectMake(0, 0, 390, 844)];
    window.rootViewController = navigation;
    [window makeKeyAndVisible];
    for (NSInteger section = 0; section < HCGNexusSectionCount; section++) {
        [home selectSection:section];
        [window layoutIfNeeded];
        XCTAssertEqual(home.selectedSection, section);
        UIViewController *child = home.childViewControllers.lastObject;
        XCTAssertNotNil(child, @"section %ld has content", (long)section);
        if ([child isKindOfClass:[UITableViewController class]]) {
            UITableView *table = ((UITableViewController *)child).tableView;
            [table layoutIfNeeded];
            XCTAssertGreaterThan(table.numberOfSections, 0, @"section %ld shows rows", (long)section);
        }
        NSMutableArray<UIButton *> *buttons = [NSMutableArray array];
        HCGCollectButtons(home.view, buttons);
        for (UIButton *button in buttons) {
            if (button.window == nil || CGRectIsEmpty(button.frame)) continue;
            NSString *label = button.accessibilityLabel ?: button.currentTitle;
            XCTAssertTrue(label.length > 0, @"unlabelled button in section %ld", (long)section);
            XCTAssertGreaterThanOrEqual(button.bounds.size.height, 43.5, @"%@ in section %ld is %.1f pt tall", label, (long)section, button.bounds.size.height);
        }
    }
    window.hidden = YES;
}

- (void)testLargestAccessibilityTextSizeLaysOutEverySection {
    HCGNexusModel *model = [self makeModel];
    HCGPanelHomeViewController *home = [[HCGPanelHomeViewController alloc] initWithContext:[self appContextWithModel:model]];
    UINavigationController *navigation = [[UINavigationController alloc] initWithRootViewController:home];
    UIWindow *window = [[UIWindow alloc] initWithFrame:CGRectMake(0, 0, 375, 667)];
    window.rootViewController = navigation;
    UITraitCollection *huge = [UITraitCollection traitCollectionWithPreferredContentSizeCategory:UIContentSizeCategoryAccessibilityExtraExtraExtraLarge];
    [navigation setOverrideTraitCollection:huge forChildViewController:home];
    [window makeKeyAndVisible];
    // Nothing may be drawn larger than the system's largest style at this size (LargeTitle); before the fix,
    // double scaling drew body text at ~150 pt. Capped chrome stays within its cap.
    CGFloat largest = [UIFont preferredFontForTextStyle:UIFontTextStyleLargeTitle compatibleWithTraitCollection:huge].pointSize;
    for (NSInteger section = 0; section < HCGNexusSectionCount; section++) {
        [home selectSection:section];
        [window layoutIfNeeded];
        XCTAssertEqual(home.selectedSection, section);
        XCTAssertGreaterThan(home.view.bounds.size.height, 0);
        NSMutableArray<UILabel *> *labels = [NSMutableArray array];
        HCGCollectLabels(home.view, labels);
        for (UILabel *label in labels) {
            XCTAssertLessThanOrEqual(label.font.pointSize, largest + 0.5, @"\"%@\" in section %ld is %.0f pt",
                                     label.text, (long)section, label.font.pointSize);
        }
    }
    window.hidden = YES;
}

// Dynamic Type is applied exactly once: at every size our font stays within 20% of the system font of the same style.
- (void)testDynamicTypeScalesOnce {
    NSArray<UIContentSizeCategory> *sizes = @[ UIContentSizeCategoryExtraSmall, UIContentSizeCategoryLarge,
                                               UIContentSizeCategoryExtraExtraExtraLarge,
                                               UIContentSizeCategoryAccessibilityExtraExtraExtraLarge ];
    NSArray<UIFontTextStyle> *styles = @[ UIFontTextStyleBody, UIFontTextStyleFootnote, UIFontTextStyleSubheadline,
                                          UIFontTextStyleHeadline, UIFontTextStyleTitle3, UIFontTextStyleCaption1 ];
    for (UIContentSizeCategory size in sizes) {
        UITraitCollection *traits = [UITraitCollection traitCollectionWithPreferredContentSizeCategory:size];
        for (UIFontTextStyle style in styles) {
            CGFloat ours = [HCGTheme fontForTextStyle:style weight:UIFontWeightRegular compatibleWithTraitCollection:traits].pointSize;
            CGFloat system = [UIFont preferredFontForTextStyle:style compatibleWithTraitCollection:traits].pointSize;
            // UIFontMetrics (needed for live updates) follows Apple's scaling curve, which differs slightly from
            // the system's size table (e.g. body at the largest size: 48 vs 53 pt). Scaling twice drew ~3x.
            XCTAssertGreaterThanOrEqual(ours, system * 0.8, @"%@ at %@: %.0f vs %.0f", style, size, ours, system);
            XCTAssertLessThanOrEqual(ours, system * 1.2, @"%@ at %@: %.0f vs %.0f", style, size, ours, system);
        }
    }
    XCTAssertEqualWithAccuracy([HCGTheme defaultPointSizeForTextStyle:UIFontTextStyleBody], 17.0, 0.01);
}

// Fixed-height chrome keeps its cap at the largest size and offers the Large Content Viewer instead.
- (void)testCappedChromeAtLargestTextSize {
    HCGPanelHomeViewController *home = [[HCGPanelHomeViewController alloc] initWithContext:[self appContextWithModel:[self makeModel]]];
    UINavigationController *navigation = [[UINavigationController alloc] initWithRootViewController:home];
    UIWindow *window = [[UIWindow alloc] initWithFrame:CGRectMake(0, 0, 375, 667)];
    window.rootViewController = navigation;
    UITraitCollection *huge = [UITraitCollection traitCollectionWithPreferredContentSizeCategory:UIContentSizeCategoryAccessibilityExtraExtraExtraLarge];
    [navigation setOverrideTraitCollection:huge forChildViewController:home];
    [window makeKeyAndVisible];
    [home selectSection:0];
    [window layoutIfNeeded];
    NSMutableArray<UIButton *> *buttons = [NSMutableArray array];
    HCGCollectButtons(home.view, buttons);
    NSUInteger capped = 0;
    for (UIButton *button in buttons) {
        if (!button.showsLargeContentViewer) continue;
        capped++;
        XCTAssertLessThanOrEqual(button.titleLabel.font.pointSize, HCGChipMaximumPointSize + 0.5, @"%@", button.largeContentTitle);
        XCTAssertGreaterThan(button.largeContentTitle.length, 0u);
    }
    XCTAssertGreaterThanOrEqual(capped, (NSUInteger)HCGNexusSectionCount, @"section bar buttons use the Large Content Viewer");
    BOOL hasInteraction = NO;
    for (id<UIInteraction> interaction in home.view.interactions) {
        if ([(NSObject *)interaction isKindOfClass:[UILargeContentViewerInteraction class]]) hasInteraction = YES;
    }
    XCTAssertTrue(hasInteraction, @"the panel installs a Large Content Viewer interaction");
    window.hidden = YES;
}

- (void)testMigrationGivesTheAppAnAppsList {
    HCGNexusModel *model = [self makeModel];
    XCTAssertGreaterThan(model.appLibrary.items.count, 0u, @"preset shortcuts appear under Apps");
    XCTAssertEqual([HCGLayoutMigration layoutVersionInStore:_store], HCGCurrentLayoutVersion);
    HCGNexusModel *again = [self makeModel];
    XCTAssertEqual(again.lastMigrationOutcome, HCGLayoutMigrationAlreadyCurrent);
}

// With the shipped Info.plist (no client issued) the account is "Not configured", sign-in is
// impossible, and the Device Link service is never even constructed for it.
- (void)testAccountIsNotConfiguredWithoutAnIssuedClient {
    __block NSUInteger serviceRequests = 0;
    HCGAppAccountProvider *provider = [[HCGAppAccountProvider alloc] initWithServiceProvider:^id<HCGLinkServicing> {
        serviceRequests++;
        return nil;
    }];
    XCTAssertEqual([provider accountState], HCGAccountStateNotConfigured);
    XCTAssertFalse([provider canSignIn]);
    XCTAssertNil([provider accountDisplayName]);
    XCTAssertNil([provider organisationNames], @"organisations are never invented");
    XCTAssertTrue([provider accountDetail].length > 0);
    [provider signInFromViewController:[[UIViewController alloc] init]];
    XCTAssertEqual(serviceRequests, 0u, @"nothing is contacted without a client");
    NSDictionary *summary = [provider scopedSummary];
    XCTAssertEqualObjects(summary[HCGAccountSummaryState], @(HCGAccountStateNotConfigured));
    for (NSString *key in summary) XCTAssertFalse([key.lowercaseString containsString:@"token"]);
}

- (void)testCommandModeShowsRealStatesInAppMode {
    HCGNexusModel *model = [self makeModel];
    HCGSettings *settings = model.settings;
    settings.terminalVariant = HCGTerminalVariantStandard; // turned on; News stays off
    [model saveSettings:settings];
    HCGPanelContext *context = [[HCGPanelContext alloc] init];
    context.mode = HCGPanelModeStandaloneApp;
    context.model = model;
    context.runner = [[HCGActionRunner alloc] initWithModel:model];

    HCGCommandModeViewController *commandMode = [[HCGCommandModeViewController alloc] initWithContext:context];
    [commandMode loadViewIfNeeded];
    commandMode.view.frame = CGRectMake(0, 0, 390, 844);
    [commandMode startUpdates];
    [commandMode.view layoutIfNeeded];
    [commandMode stopUpdates];
    XCTAssertNotNil([commandMode accessibilityFocusElement]);

    // The sandboxed app cannot open apps by bundle ID: a configured
    // integration is Unavailable, an unconfigured one Off — never Connected.
    NSMutableArray<NSString *> *labels = [NSMutableArray array];
    HCGCollectAccessibilityLabels(commandMode.view, labels);
    NSString *all = [labels componentsJoinedByString:@"\n"];
    XCTAssertTrue([all containsString:@"HCG Terminal: Unavailable."], @"%@", all);
    XCTAssertTrue([all containsString:@"HCG News: Off."], @"%@", all);
    XCTAssertFalse([all containsString:@": Connected."], @"%@", all);
    XCTAssertTrue([all containsString:@"Battery: "], @"device tiles are shown");
}

@end
