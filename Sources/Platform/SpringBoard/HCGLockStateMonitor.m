#import "HCGLockStateMonitor.h"
#import <UIKit/UIKit.h>
#include <notify.h>

static const char *kLockStateName = "com.apple.springboard.lockstate";
static const char *kBlankedName = "com.apple.springboard.hasBlankedScreen";

@interface NSObject (HCGSpringBoardQueries)
+ (id)sharedInstance;
- (BOOL)isUILocked;
- (BOOL)isVisible;
- (BOOL)isPresented;
@end

@implementation HCGLockStateMonitor {
    int _lockToken;
    int _blankToken;
    BOOL _lockTokenValid;
    BOOL _blankTokenValid;
    BOOL _running;
    BOOL _protectedDataUnavailable;
    NSTimer *_coverSheetPoll;
    HCGSystemSignals _signals;
}

- (instancetype)init {
    if ((self = [super init])) {
        _signals = HCGSystemSignalsUnknown();
    }
    return self;
}

- (void)dealloc {
    [self stop];
}

- (HCGSystemSignals)signals {
    return _signals;
}

- (void)start {
    if (_running) return;
    _running = YES;
    __weak typeof(self) weakSelf = self;
    notify_handler_t handler = ^(int token) { [weakSelf refresh]; };
    _lockTokenValid = notify_register_dispatch(kLockStateName, &_lockToken, dispatch_get_main_queue(), handler) == NOTIFY_STATUS_OK;
    _blankTokenValid = notify_register_dispatch(kBlankedName, &_blankToken, dispatch_get_main_queue(), handler) == NOTIFY_STATUS_OK;

    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self selector:@selector(protectedDataWillBecomeUnavailable) name:UIApplicationProtectedDataWillBecomeUnavailable object:nil];
    [nc addObserver:self selector:@selector(protectedDataDidBecomeAvailable) name:UIApplicationProtectedDataDidBecomeAvailable object:nil];
    [self refresh];
}

- (void)stop {
    if (!_running) return;
    _running = NO;
    if (_lockTokenValid) notify_cancel(_lockToken);
    if (_blankTokenValid) notify_cancel(_blankToken);
    _lockTokenValid = _blankTokenValid = NO;
    [_coverSheetPoll invalidate];
    _coverSheetPoll = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)protectedDataWillBecomeUnavailable {
    _protectedDataUnavailable = YES;
    [self refresh];
}

- (void)protectedDataDidBecomeAvailable {
    _protectedDataUnavailable = NO;
    [self refresh];
}

static HCGTriState HCGStateForToken(BOOL valid, int token) {
    if (!valid) return HCGTriStateUnknown;
    uint64_t state = 0;
    if (notify_get_state(token, &state) != NOTIFY_STATUS_OK) return HCGTriStateUnknown;
    return state != 0 ? HCGTriStateYes : HCGTriStateNo;
}

static id HCGShared(NSString *className) {
    Class cls = NSClassFromString(className);
    if (!cls || ![cls respondsToSelector:@selector(sharedInstance)]) return nil;
    return [cls sharedInstance];
}

- (HCGTriState)uiLockedState {
    id manager = HCGShared(@"SBLockScreenManager");
    if (![manager respondsToSelector:@selector(isUILocked)]) return HCGTriStateUnknown;
    return [manager isUILocked] ? HCGTriStateYes : HCGTriStateNo;
}

- (HCGTriState)coverSheetState {
    id manager = HCGShared(@"SBCoverSheetPresentationManager");
    if ([manager respondsToSelector:@selector(isVisible)]) return [manager isVisible] ? HCGTriStateYes : HCGTriStateNo;
    if ([manager respondsToSelector:@selector(isPresented)]) return [manager isPresented] ? HCGTriStateYes : HCGTriStateNo;
    return HCGTriStateUnknown;
}

- (void)refresh {
    HCGTriState lockstate = HCGStateForToken(_lockTokenValid, _lockToken);
    HCGTriState uiLocked = [self uiLockedState];

    HCGSystemSignals signals;
    // Locked if any source says so; unknown only when no source is available.
    if (lockstate == HCGTriStateYes || uiLocked == HCGTriStateYes || _protectedDataUnavailable) {
        signals.deviceLocked = HCGTriStateYes;
    } else if (lockstate == HCGTriStateNo || uiLocked == HCGTriStateNo) {
        signals.deviceLocked = HCGTriStateNo;
    } else {
        signals.deviceLocked = HCGTriStateUnknown;
    }
    signals.coverSheetVisible = [self coverSheetState];
    signals.screenBlanked = HCGStateForToken(_blankTokenValid, _blankToken);

    BOOL changed = signals.deviceLocked != _signals.deviceLocked
                || signals.coverSheetVisible != _signals.coverSheetVisible
                || signals.screenBlanked != _signals.screenBlanked;
    _signals = signals;
    [self updatePolling];
    if (changed && self.changeHandler) self.changeHandler(signals);
}

- (void)updatePolling {
    BOOL needsPoll = _running && _signals.deviceLocked == HCGTriStateNo && _signals.coverSheetVisible == HCGTriStateYes;
    if (needsPoll && !_coverSheetPoll) {
        _coverSheetPoll = [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(pollTick:) userInfo:nil repeats:YES];
        _coverSheetPoll.tolerance = 0.2;
    } else if (!needsPoll && _coverSheetPoll) {
        [_coverSheetPoll invalidate];
        _coverSheetPoll = nil;
    }
}

- (void)pollTick:(NSTimer *)timer {
    [self refresh];
}

- (NSString *)sourceSummary {
    return [NSString stringWithFormat:@"lockstate=%@ blanked=%@ SBLockScreenManager=%@ coverSheet=%@",
            _lockTokenValid ? @"ok" : @"missing",
            _blankTokenValid ? @"ok" : @"missing",
            [self uiLockedState] == HCGTriStateUnknown ? @"missing" : @"ok",
            [self coverSheetState] == HCGTriStateUnknown ? @"missing" : @"ok"];
}

@end
