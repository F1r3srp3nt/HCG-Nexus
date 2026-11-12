#import "HCGOverlayCoordinator.h"

@implementation HCGOverlayCoordinator

@synthesize signals = _signals;
@synthesize stateMachine = _stateMachine;
@synthesize installed = _installed;
@synthesize visible = _visible;
@synthesize installCount = _installCount;
@synthesize rejectedActivations = _rejectedActivations;
@synthesize reduceMotion = _reduceMotion;

- (instancetype)initWithHost:(id<HCGOverlayHost>)host {
    if ((self = [super init])) {
        _host = host;
        _settings = [[HCGSettings alloc] init]; // disabled by default
        _signals = HCGSystemSignalsUnknown();
        _stateMachine = [[HCGPanelStateMachine alloc] init];
    }
    return self;
}

- (HCGSettings *)settings {
    return [_settings copy];
}

- (BOOL)animationsAllowed {
    return _settings.animationsEnabled && !_reduceMotion;
}

- (void)dispatch:(HCGPanelCommand)command {
    if (command == HCGPanelCommandNone) return;
    [_host overlayBeginPanelTransition:command generation:_stateMachine.generation animated:self.animationsAllowed];
}

- (void)reevaluate {
    HCGOverlayDecision decision = HCGDecideOverlay(_settings.enabled, _signals, _stateMachine.isPresented);
    if (decision.mustForceClose || (!decision.panelAllowed && _stateMachine.state != HCGPanelStateClosed)) {
        [_stateMachine forceClose];
        if (_installed) [_host overlayForceHidePanel];
    }
    if (decision.overlayVisible && !_installed) {
        _installed = YES;
        _installCount += 1;
        [_host overlayInstall];
        [_host overlayApplySettings:[_settings copy]];
    }
    if (_installed) {
        [_host overlaySetVisible:decision.overlayVisible];
    }
    _visible = _installed && decision.overlayVisible;
}

- (void)updateSettings:(HCGSettings *)settings {
    _settings = [settings copy];
    if (_installed) [_host overlayApplySettings:[_settings copy]];
    [self reevaluate];
}

- (void)updateSignals:(HCGSystemSignals)signals {
    _signals = signals;
    [self reevaluate];
}

- (BOOL)handleActivated {
    HCGOverlayDecision decision = HCGDecideOverlay(_settings.enabled, _signals, _stateMachine.isPresented);
    if (!decision.panelAllowed || !_installed) {
        _rejectedActivations += 1;
        return NO;
    }
    [self dispatch:[_stateMachine toggle]];
    return YES;
}

- (void)requestClose {
    [self dispatch:[_stateMachine requestClose]];
}

- (void)requestCloseImmediately {
    if ([_stateMachine forceClose] && _installed) [_host overlayForceHidePanel];
}

- (void)panelTransitionFinished:(NSUInteger)generation {
    [self dispatch:[_stateMachine transitionDidFinishForGeneration:generation]];
}

- (NSDictionary *)diagnostics {
    NSMutableDictionary *d = [[NSMutableDictionary alloc] init];
    [d setObject:[NSNumber numberWithBool:_settings.enabled] forKey:@"enabled"];
    [d setObject:HCGOverlayReason(_settings.enabled, _signals) forKey:@"availability"];
    [d setObject:HCGTriStateName(_signals.deviceLocked) forKey:@"deviceLocked"];
    [d setObject:HCGTriStateName(_signals.coverSheetVisible) forKey:@"coverSheetVisible"];
    [d setObject:HCGTriStateName(_signals.screenBlanked) forKey:@"screenBlanked"];
    [d setObject:HCGPanelStateName(_stateMachine.state) forKey:@"panelState"];
    [d setObject:[NSNumber numberWithBool:_installed] forKey:@"installed"];
    [d setObject:[NSNumber numberWithBool:_visible] forKey:@"visible"];
    [d setObject:[NSNumber numberWithUnsignedInteger:_installCount] forKey:@"installCount"];
    [d setObject:[NSNumber numberWithUnsignedInteger:_stateMachine.openTransitions] forKey:@"opens"];
    [d setObject:[NSNumber numberWithUnsignedInteger:_stateMachine.closeTransitions] forKey:@"closes"];
    [d setObject:[NSNumber numberWithUnsignedInteger:_stateMachine.forcedCloses] forKey:@"forcedCloses"];
    [d setObject:[NSNumber numberWithBool:self.animationsAllowed] forKey:@"animationsAllowed"];
    return d;
}

@end
