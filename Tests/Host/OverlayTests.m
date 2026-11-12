#import "HCGTestHarness.h"
#import "HCGCore.h"
#include <stdlib.h>

#pragma mark - Geometry

static HCGInsets Insets(double t, double l, double b, double r) {
    HCGInsets i; i.top = t; i.left = l; i.bottom = b; i.right = r; return i;
}

static BOOL RectInside(HCGRect inner, double w, double h) {
    return inner.x >= -1e-9 && inner.y >= -1e-9 && inner.x + inner.width <= w + 1e-9 && inner.y + inner.height <= h + 1e-9;
}

static void testHandleStaysInsideSafeBandPortrait(void) {
    // iPhone with Dynamic Island, portrait: 393x852, insets 59/34.
    HCGHandleLayoutInput in;
    in.canvasWidth = 393; in.canvasHeight = 852; in.safeArea = Insets(59, 0, 34, 0);
    in.side = 0; in.keyboardSafeZone = NO; in.landscape = NO;
    double positions[] = {0.0, 0.25, 0.5, 1.0};
    double lastY = -1;
    int i;
    for (i = 0; i < 4; i++) {
        in.position = positions[i];
        HCGHandleFrames f = HCGComputeHandleFrames(in);
        HCG_CHECK(RectInside(f.visual, 393, 852) && RectInside(f.hit, 393, 852), "inside canvas");
        HCG_CHECK(f.hit.y >= 59 + 0.12 * 852 - 1e-6, "clear of the top pull zone (y=%.1f)", f.hit.y);
        HCG_CHECK(f.hit.y + f.hit.height <= 852 - 34 - 0.12 * 852 + 1e-6, "clear of the home indicator zone");
        HCG_CHECK(f.hit.height >= 44 && f.hit.width >= 30, "accessible touch target");
        HCG_CHECK(f.visual.y > lastY, "position is monotonic");
        HCG_CHECK_NEAR(f.visual.x + f.visual.width, 393, 1e-9);
        lastY = f.visual.y;
    }
}

static void testHandleKeyboardZoneAndLeftSide(void) {
    HCGHandleLayoutInput in;
    in.canvasWidth = 393; in.canvasHeight = 852; in.safeArea = Insets(59, 0, 34, 0);
    in.side = 1; in.position = 1.0; in.keyboardSafeZone = YES; in.landscape = NO;
    HCGHandleFrames f = HCGComputeHandleFrames(in);
    HCG_CHECK(f.hit.y + f.hit.height <= 852 * 0.5 + 1e-6, "keyboard zone keeps handle in top half");
    HCG_CHECK_NEAR(f.visual.x, 0, 1e-9);
    HCG_CHECK_NEAR(f.hit.x, 0, 1e-9);

    // Landscape with notch: insets left/right 59, bottom 21.
    in.canvasWidth = 852; in.canvasHeight = 393; in.safeArea = Insets(0, 59, 21, 59);
    in.landscape = YES; in.side = 0; in.position = 0.5;
    f = HCGComputeHandleFrames(in);
    HCG_CHECK(RectInside(f.hit, 852, 393), "landscape inside canvas");
    HCG_CHECK_NEAR(f.visual.x + f.visual.width, 852 - 59, 1e-9);
    HCG_CHECK(f.centerMax >= f.centerMin, "band never inverts");

    // Degenerate tiny canvas must not produce negative sizes.
    in.canvasWidth = 100; in.canvasHeight = 120; in.safeArea = Insets(0, 0, 0, 0);
    f = HCGComputeHandleFrames(in);
    HCG_CHECK(f.hit.height > 0 && f.centerMax >= f.centerMin, "degenerate canvas handled");
}

static void testOrientationHelpers(void) {
    double w = 0, h = 0;
    HCGCanvasSizeForOrientation(393, 852, HCGInterfaceOrientationLandscapeLeft, &w, &h);
    HCG_CHECK(w == 852 && h == 393, "landscape swaps");
    HCGCanvasSizeForOrientation(393, 852, HCGInterfaceOrientationPortrait, &w, &h);
    HCG_CHECK(w == 393 && h == 852, "portrait keeps");
    HCG_CHECK_NEAR(HCGRotationForOrientation(HCGInterfaceOrientationLandscapeRight), M_PI_2, 1e-9);
    HCG_CHECK_NEAR(HCGRotationForOrientation(HCGInterfaceOrientationLandscapeLeft), -M_PI_2, 1e-9);

    HCGInsets land = HCGSafeAreaForOrientation(Insets(59, 0, 34, 0), HCGInterfaceOrientationLandscapeRight);
    HCG_CHECK(land.left == 59 && land.right == 59 && land.top == 0 && land.bottom == 21, "notched landscape insets");
    HCGInsets homeButton = HCGSafeAreaForOrientation(Insets(20, 0, 0, 0), HCGInterfaceOrientationLandscapeLeft);
    HCG_CHECK(homeButton.left == 0 && homeButton.right == 0 && homeButton.bottom == 0, "home-button landscape insets");
}

static void testPanelFrame(void) {
    HCGRect p = HCGComputePanelFrame(393, 852, Insets(59, 0, 34, 0), 0, 0);
    HCG_CHECK(p.width <= 400 && p.x >= 12 && p.x + p.width <= 393 - 12 + 1e-9, "fits horizontally");
    HCG_CHECK(p.y >= 59 + 12 - 1e-9 && p.y + p.height <= 852 - 34 - 12 + 1e-9, "inside safe area");
    HCGRect withKeyboard = HCGComputePanelFrame(393, 852, Insets(59, 0, 34, 0), 0, 336);
    HCG_CHECK(withKeyboard.y + withKeyboard.height <= 852 - 336 - 12 + 1e-9, "stays above keyboard");
    HCGRect wide = HCGComputePanelFrame(852, 393, Insets(0, 59, 21, 59), 1, 0);
    HCG_CHECK_NEAR(wide.x, 59 + 12, 1e-9);
    HCGRect tiny = HCGComputePanelFrame(50, 50, Insets(40, 40, 40, 40), 0, 500);
    HCG_CHECK(tiny.width >= 0 && tiny.height >= 0, "never negative");
}

void HCGRunGeometryTests(void) {
    HCG_RUN(testHandleStaysInsideSafeBandPortrait);
    HCG_RUN(testHandleKeyboardZoneAndLeftSide);
    HCG_RUN(testOrientationHelpers);
    HCG_RUN(testPanelFrame);
}

#pragma mark - State machine

static void testStateMachineBasicAndCoalescing(void) {
    HCGPanelStateMachine *sm = [[HCGPanelStateMachine alloc] init];
    HCG_CHECK_EQ_INT([sm requestOpen], HCGPanelCommandBeginOpen);
    NSUInteger g = sm.generation;
    HCG_CHECK_EQ_INT([sm requestOpen], HCGPanelCommandNone);   // double tap while opening
    HCG_CHECK_EQ_INT([sm requestClose], HCGPanelCommandNone);  // queued
    HCG_CHECK_EQ_INT([sm transitionDidFinishForGeneration:g], HCGPanelCommandBeginClose);
    NSUInteger g2 = sm.generation;
    HCG_CHECK_EQ_INT([sm transitionDidFinishForGeneration:g], HCGPanelCommandNone); // stale
    HCG_CHECK_EQ_INT([sm transitionDidFinishForGeneration:g2], HCGPanelCommandNone);
    HCG_CHECK_EQ_INT(sm.state, HCGPanelStateClosed);

    [sm requestOpen];
    NSUInteger g3 = sm.generation;
    HCG_CHECK([sm forceClose], "force close while opening");
    HCG_CHECK_EQ_INT([sm transitionDidFinishForGeneration:g3], HCGPanelCommandNone); // late completion ignored
    HCG_CHECK_EQ_INT(sm.state, HCGPanelStateClosed);
    HCG_CHECK(![sm forceClose], "already closed");
}

static void testStateMachineRandomisedInvariants(void) {
    HCGPanelStateMachine *sm = [[HCGPanelStateMachine alloc] init];
    srand(1234);
    NSUInteger inFlight = 0;  // generation of the running transition, 0 = none
    int i;
    for (i = 0; i < 20000; i++) {
        int op = rand() % 5;
        HCGPanelCommand cmd = HCGPanelCommandNone;
        if (op == 0) cmd = [sm requestOpen];
        else if (op == 1) cmd = [sm requestClose];
        else if (op == 2) cmd = [sm toggle];
        else if (op == 3) { if (inFlight) { cmd = [sm transitionDidFinishForGeneration:inFlight]; inFlight = 0; } }
        else { [sm forceClose]; inFlight = 0; }
        if (cmd != HCGPanelCommandNone) {
            HCG_CHECK(inFlight == 0, "a new transition never starts while one is in flight (step %d)", i);
            inFlight = sm.generation;
        }
        BOOL transitioning = sm.state == HCGPanelStateOpening || sm.state == HCGPanelStateClosing;
        HCG_CHECK(transitioning == (inFlight != 0), "transition state consistent (step %d)", i);
        if (HCGTestFailures > 20) return;
    }
    HCG_CHECK(sm.openTransitions >= sm.closeTransitions, "every close follows an open");
}

void HCGRunStateMachineTests(void) {
    HCG_RUN(testStateMachineBasicAndCoalescing);
    HCG_RUN(testStateMachineRandomisedInvariants);
}

#pragma mark - Overlay coordinator with a fake host

@interface HCGFakeOverlayHost : NSObject <HCGOverlayHost> {
@public
    HCGOverlayCoordinator *coordinator;
    int installCalls;
    int windowsCreated;
    int gestureRecognizers;
    BOOL visible;
    BOOL panelOnScreen;
    BOOL autoComplete;
    int forceHides;
    int applyCalls;
    BOOL lastAnimated;
    NSUInteger pendingGeneration;
}
@end

@implementation HCGFakeOverlayHost
- (void)overlayInstall {
    installCalls++;
    windowsCreated++;
    gestureRecognizers += 3; // handle tap + handle pan + dimming tap
}
- (void)overlaySetVisible:(BOOL)v { visible = v; }
- (void)overlayApplySettings:(HCGSettings *)settings { (void)settings; applyCalls++; }
- (void)overlayBeginPanelTransition:(HCGPanelCommand)command generation:(NSUInteger)generation animated:(BOOL)animated {
    lastAnimated = animated;
    panelOnScreen = YES; // visible during both opening and closing animations
    pendingGeneration = generation;
    if (command == HCGPanelCommandBeginClose && !autoComplete) return;
    if (autoComplete) {
        if (command == HCGPanelCommandBeginClose) panelOnScreen = NO;
        pendingGeneration = 0;
        [coordinator panelTransitionFinished:generation];
    }
}
- (void)finishPending {
    NSUInteger g = pendingGeneration;
    pendingGeneration = 0;
    if (coordinator.stateMachine.state == HCGPanelStateClosing) panelOnScreen = NO;
    [coordinator panelTransitionFinished:g];
}
- (void)overlayForceHidePanel { forceHides++; panelOnScreen = NO; pendingGeneration = 0; }
@end

static HCGSystemSignals Unlocked(void) {
    HCGSystemSignals s; s.deviceLocked = HCGTriStateNo; s.coverSheetVisible = HCGTriStateNo; s.screenBlanked = HCGTriStateNo; return s;
}

static void testDisabledByDefaultInstallsNothing(void) {
    HCGFakeOverlayHost *host = [[HCGFakeOverlayHost alloc] init];
    HCGOverlayCoordinator *c = [[HCGOverlayCoordinator alloc] initWithHost:host];
    host->coordinator = c;
    [c updateSettings:[HCGSettings defaultSettings]];
    [c updateSignals:Unlocked()];
    HCG_CHECK_EQ_INT(host->installCalls, 0);
    HCG_CHECK(![c handleActivated], "disabled Nexus ignores activation");
    HCG_CHECK(!c.visible, "nothing visible");
}

static void testEnableDisableEnforcementAndNoDuplicates(void) {
    HCGFakeOverlayHost *host = [[HCGFakeOverlayHost alloc] init];
    host->autoComplete = YES;
    HCGOverlayCoordinator *c = [[HCGOverlayCoordinator alloc] initWithHost:host];
    host->coordinator = c;
    [c updateSignals:Unlocked()];
    HCGSettings *on = [HCGSettings defaultSettings];
    on.enabled = YES;
    HCGSettings *off = [HCGSettings defaultSettings];

    int i;
    for (i = 0; i < 200; i++) {
        [c updateSettings:on];
        HCG_CHECK(host->visible, "enabled -> visible");
        HCG_CHECK([c handleActivated], "activation accepted");
        HCG_CHECK(c.stateMachine.state == HCGPanelStateOpen && host->panelOnScreen, "panel open");
        [c updateSettings:off];
        HCG_CHECK(!host->visible, "disable hides overlay immediately (iteration %d)", i);
        HCG_CHECK(!host->panelOnScreen && c.stateMachine.state == HCGPanelStateClosed, "disable closes the panel");
        HCG_CHECK(![c handleActivated], "disabled ignores the gesture");
        if (HCGTestFailures > 20) return;
    }
    HCG_CHECK_EQ_INT(host->installCalls, 1);
    HCG_CHECK_EQ_INT(host->windowsCreated, 1);
    HCG_CHECK_EQ_INT(host->gestureRecognizers, 3);
    HCG_CHECK_EQ_INT(c.installCount, 1);
}

static void testRepeatedOpenCloseWithAnimations(void) {
    HCGFakeOverlayHost *host = [[HCGFakeOverlayHost alloc] init];
    HCGOverlayCoordinator *c = [[HCGOverlayCoordinator alloc] initWithHost:host];
    host->coordinator = c;
    HCGSettings *on = [HCGSettings defaultSettings];
    on.enabled = YES;
    [c updateSettings:on];
    [c updateSignals:Unlocked()];
    int i;
    for (i = 0; i < 500; i++) {
        [c handleActivated];          // begin open
        [c handleActivated];          // rapid second tap: queued close
        [c requestClose];             // outside tap: no extra transition
        [host finishPending];         // open finished -> begins queued close
        HCG_CHECK(c.stateMachine.state == HCGPanelStateClosing, "queued close started");
        [host finishPending];
        HCG_CHECK(c.stateMachine.state == HCGPanelStateClosed && !host->panelOnScreen, "closed cleanly (iteration %d)", i);
        if (HCGTestFailures > 20) return;
    }
    HCG_CHECK_EQ_INT(c.stateMachine.openTransitions, 500);
    HCG_CHECK_EQ_INT(c.stateMachine.closeTransitions, 500);
    HCG_CHECK_EQ_INT(host->installCalls, 1);
}

static void testLockHidesAndUnlockRestoresHandleOnly(void) {
    HCGFakeOverlayHost *host = [[HCGFakeOverlayHost alloc] init];
    host->autoComplete = YES;
    HCGOverlayCoordinator *c = [[HCGOverlayCoordinator alloc] initWithHost:host];
    host->coordinator = c;
    HCGSettings *on = [HCGSettings defaultSettings];
    on.enabled = YES;
    [c updateSettings:on];
    [c updateSignals:Unlocked()];
    [c handleActivated];
    HCG_CHECK(host->panelOnScreen, "open before lock");

    HCGSystemSignals locked = Unlocked();
    locked.deviceLocked = HCGTriStateYes;
    [c updateSignals:locked];
    HCG_CHECK(!host->visible && !host->panelOnScreen, "lock hides overlay and panel");
    HCG_CHECK_EQ_INT(host->forceHides, 1);
    HCG_CHECK(![c handleActivated], "cannot open while locked");

    HCGSystemSignals authenticatedOnCoverSheet = Unlocked();
    authenticatedOnCoverSheet.coverSheetVisible = HCGTriStateYes;
    [c updateSignals:authenticatedOnCoverSheet];
    HCG_CHECK(!host->visible, "hidden while the lock-screen cover sheet is up even after Face ID");

    HCGSystemSignals unknown = HCGSystemSignalsUnknown();
    [c updateSignals:unknown];
    HCG_CHECK(!host->visible, "unknown lock state fails closed");

    [c updateSignals:Unlocked()];
    HCG_CHECK(host->visible, "unlocked shows handle");
    HCG_CHECK(!host->panelOnScreen && c.stateMachine.state == HCGPanelStateClosed, "panel does not reopen by itself");
    HCG_CHECK_EQ_INT(host->installCalls, 1);
}

static void testReduceMotionDisablesAnimation(void) {
    HCGFakeOverlayHost *host = [[HCGFakeOverlayHost alloc] init];
    host->autoComplete = YES;
    HCGOverlayCoordinator *c = [[HCGOverlayCoordinator alloc] initWithHost:host];
    host->coordinator = c;
    HCGSettings *on = [HCGSettings defaultSettings];
    on.enabled = YES;
    [c updateSettings:on];
    [c updateSignals:Unlocked()];
    [c handleActivated];
    HCG_CHECK(host->lastAnimated, "animated by default");
    [c requestClose];
    c.reduceMotion = YES;
    [c handleActivated];
    HCG_CHECK(!host->lastAnimated, "Reduce Motion wins over the animation setting");
    NSDictionary *diag = [c diagnostics];
    HCG_CHECK_EQ_STR([diag objectForKey:@"availability"], @"Available");
}

void HCGRunOverlayTests(void) {
    HCG_RUN(testDisabledByDefaultInstallsNothing);
    HCG_RUN(testEnableDisableEnforcementAndNoDuplicates);
    HCG_RUN(testRepeatedOpenCloseWithAnimations);
    HCG_RUN(testLockHidesAndUnlockRestoresHandleOnly);
    HCG_RUN(testReduceMotionDisablesAnimation);
}
