#import "HCGActionRunner.h"

@implementation HCGActionRunner {
    HCGNexusModel *_model;
    NSMutableSet<NSString *> *_inFlight;
}

- (instancetype)initWithModel:(HCGNexusModel *)model {
    if ((self = [super init])) {
        _model = model;
        _inFlight = [NSMutableSet set];
    }
    return self;
}

- (void)finishAction:(HCGAction *)action error:(NSError *)error summary:(NSString *)summary completion:(HCGActionCompletion)completion {
    [_inFlight removeObject:action.identifier];
    [_model.recents recordAction:action succeeded:(error == nil) message:error.localizedDescription date:[NSDate date]];
    [_model workspacesDidChange];
    if (completion) completion(error, summary);
}

- (void)openBundle:(NSString *)bundle forAction:(HCGAction *)action displayName:(NSString *)name completion:(HCGActionCompletion)completion {
    id<HCGLauncher> launcher = _model.launcher;
    if ([launcher canDetermineInstallation] && ![launcher isApplicationInstalled:bundle]) {
        NSError *error = HCGMakeError(HCGErrorAppNotInstalled,
                                      [NSString stringWithFormat:@"%@ isn't installed.", name],
                                      [NSString stringWithFormat:@"Install the app (%@) or edit this shortcut in Workspaces.", bundle]);
        [self finishAction:action error:error summary:@"" completion:completion];
        return;
    }
    __weak typeof(self) weakSelf = self;
    [launcher openApplicationWithBundleIdentifier:bundle completion:^(NSError *error) {
        NSString *summary = launcher.simulated
            ? [NSString stringWithFormat:@"Preview: would open %@ (%@). Nothing was launched.", name, bundle]
            : [NSString stringWithFormat:@"Opened %@", name];
        [weakSelf finishAction:action error:error summary:summary completion:completion];
    }];
}

- (void)runAction:(HCGAction *)action completion:(HCGActionCompletion)completion {
    id<HCGLauncher> launcher = _model.launcher;
    if (!launcher) {
        NSError *error = HCGMakeError(HCGErrorLauncherUnavailable, @"Launching isn't available here.",
                                      @"Open shortcuts from the HCG Nexus panel instead.");
        if (completion) completion(error, @"");
        return;
    }
    if ([_inFlight containsObject:action.identifier]) return; // ignore double taps
    [_inFlight addObject:action.identifier];

    NSError *validation = [HCGAction validationErrorForKind:action.kind title:action.title target:action.target];
    if (validation) {
        [self finishAction:action error:validation summary:@"" completion:completion];
        return;
    }

    switch (action.kind) {
        case HCGActionKindApp:
            [self openBundle:action.target forAction:action displayName:action.title completion:completion];
            return;
        case HCGActionKindURL: {
            NSURL *url = [NSURL URLWithString:action.target];
            __weak typeof(self) weakSelf = self;
            [launcher openURL:url completion:^(NSError *error) {
                NSString *summary = launcher.simulated
                    ? [NSString stringWithFormat:@"Preview: would open %@", url.absoluteString]
                    : [NSString stringWithFormat:@"Opened %@", action.title];
                [weakSelf finishAction:action error:error summary:summary completion:completion];
            }];
            return;
        }
        case HCGActionKindIntegration: {
            HCGIntegrationStatus *status = [_model statusForIntegration:action.target];
            if (!status.canLaunch) {
                HCGErrorCode code = status.state == HCGIntegrationStateAppMissing ? HCGErrorAppNotInstalled : HCGErrorIntegrationNotConnected;
                NSError *error = HCGMakeError(code, [NSString stringWithFormat:@"%@: %@", status.displayName, status.headline], status.detail);
                [self finishAction:action error:error summary:@"" completion:completion];
                return;
            }
            [self openBundle:status.launchBundleIdentifier forAction:action displayName:status.displayName completion:completion];
            return;
        }
    }
    [self finishAction:action error:HCGMakeError(HCGErrorUnsupportedAction, @"This shortcut type isn't supported.", @"Delete it and add it again.")
               summary:@"" completion:completion];
}

@end
