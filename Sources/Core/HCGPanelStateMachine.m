#import "HCGPanelStateMachine.h"

NSString *HCGPanelStateName(HCGPanelState state) {
    switch (state) {
        case HCGPanelStateClosed: return @"closed";
        case HCGPanelStateOpening: return @"opening";
        case HCGPanelStateOpen: return @"open";
        case HCGPanelStateClosing: return @"closing";
    }
    return @"unknown";
}

@implementation HCGPanelStateMachine

@synthesize state = _state;
@synthesize generation = _generation;
@synthesize openTransitions = _openTransitions;
@synthesize closeTransitions = _closeTransitions;
@synthesize forcedCloses = _forcedCloses;

- (BOOL)isPresented {
    return _state == HCGPanelStateOpening || _state == HCGPanelStateOpen;
}

- (HCGPanelCommand)beginOpen {
    _state = HCGPanelStateOpening;
    _pendingOpen = NO;
    _pendingClose = NO;
    _generation += 1;
    _openTransitions += 1;
    return HCGPanelCommandBeginOpen;
}

- (HCGPanelCommand)beginClose {
    _state = HCGPanelStateClosing;
    _pendingOpen = NO;
    _pendingClose = NO;
    _generation += 1;
    _closeTransitions += 1;
    return HCGPanelCommandBeginClose;
}

- (HCGPanelCommand)requestOpen {
    switch (_state) {
        case HCGPanelStateClosed: return [self beginOpen];
        case HCGPanelStateOpening:
        case HCGPanelStateOpen: _pendingClose = NO; return HCGPanelCommandNone;
        case HCGPanelStateClosing: _pendingOpen = YES; return HCGPanelCommandNone;
    }
    return HCGPanelCommandNone;
}

- (HCGPanelCommand)requestClose {
    switch (_state) {
        case HCGPanelStateOpen: return [self beginClose];
        case HCGPanelStateOpening: _pendingClose = YES; return HCGPanelCommandNone;
        case HCGPanelStateClosed:
        case HCGPanelStateClosing: _pendingOpen = NO; return HCGPanelCommandNone;
    }
    return HCGPanelCommandNone;
}

- (HCGPanelCommand)toggle {
    if (_state == HCGPanelStateOpen || _state == HCGPanelStateOpening) return [self requestClose];
    return [self requestOpen];
}

- (HCGPanelCommand)transitionDidFinishForGeneration:(NSUInteger)generation {
    if (generation != _generation) return HCGPanelCommandNone;
    if (_state == HCGPanelStateOpening) {
        _state = HCGPanelStateOpen;
        if (_pendingClose) return [self beginClose];
        return HCGPanelCommandNone;
    }
    if (_state == HCGPanelStateClosing) {
        _state = HCGPanelStateClosed;
        if (_pendingOpen) return [self beginOpen];
        return HCGPanelCommandNone;
    }
    return HCGPanelCommandNone;
}

- (BOOL)forceClose {
    BOOL changed = _state != HCGPanelStateClosed;
    _state = HCGPanelStateClosed;
    _pendingOpen = NO;
    _pendingClose = NO;
    _generation += 1;
    if (changed) _forcedCloses += 1;
    return changed;
}

@end
