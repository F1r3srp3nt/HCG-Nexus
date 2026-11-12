#import "HCGOverlayPolicy.h"

HCGSystemSignals HCGSystemSignalsUnknown(void) {
    HCGSystemSignals signals;
    signals.deviceLocked = HCGTriStateUnknown;
    signals.coverSheetVisible = HCGTriStateUnknown;
    signals.screenBlanked = HCGTriStateUnknown;
    return signals;
}

static BOOL HCGSystemAllows(HCGSystemSignals signals) {
    if (signals.deviceLocked != HCGTriStateNo) return NO;
    if (signals.coverSheetVisible == HCGTriStateYes) return NO;
    if (signals.screenBlanked == HCGTriStateYes) return NO;
    return YES;
}

HCGOverlayDecision HCGDecideOverlay(BOOL enabled, HCGSystemSignals signals, BOOL panelPresented) {
    HCGOverlayDecision decision;
    BOOL allowed = enabled && HCGSystemAllows(signals);
    decision.overlayVisible = allowed;
    decision.panelAllowed = allowed;
    decision.mustForceClose = panelPresented && !allowed;
    return decision;
}

NSString *HCGOverlayReason(BOOL enabled, HCGSystemSignals signals) {
    if (!enabled) return @"Disabled in settings";
    if (signals.deviceLocked == HCGTriStateYes) return @"Hidden: device locked";
    if (signals.deviceLocked == HCGTriStateUnknown) return @"Hidden: lock state unknown";
    if (signals.screenBlanked == HCGTriStateYes) return @"Hidden: screen off";
    if (signals.coverSheetVisible == HCGTriStateYes) return @"Hidden: lock screen / cover sheet visible";
    if (signals.coverSheetVisible == HCGTriStateUnknown) return @"Available (cover sheet state unavailable)";
    return @"Available";
}

NSString *HCGTriStateName(HCGTriState state) {
    switch (state) {
        case HCGTriStateYes: return @"yes";
        case HCGTriStateNo: return @"no";
        case HCGTriStateUnknown: return @"unknown";
    }
    return @"unknown";
}
