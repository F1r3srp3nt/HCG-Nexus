#import "HCGHaloBorderLink.h"

NSString *const HCGHaloSettingsDomain = @"com.hakmicapitalgroup.halo";
NSString *const HCGHaloStatusDomain = @"com.hakmicapitalgroup.halo.status";
NSString *const HCGHaloStatusRecordKey = @"status";
NSString *const HCGHaloKeyEnabled = @"enabled";
NSString *const HCGHaloKeyTarget = @"target";
NSString *const HCGHaloStatusKeyState = @"state";
NSString *const HCGHaloStatusKeyNexusState = @"nexusState";
NSString *const HCGHaloStatusKeyNexusDetail = @"nexusDetail";
NSString *const HCGHaloStatusRequestNotification = @"com.hakmicapitalgroup.halo/status-request";
NSString *const HCGHaloPrefsBundleName = @"HCGHaloPrefs.bundle";
NSString *const HCGHaloIntegrationInfoKey = @"HCGHaloNexusIntegration";
NSString *const HCGHaloControlInfoKey = @"HCGHaloNexusControl";
NSString *const HCGHaloControlClassName = @"HaloNexusControl";
const NSInteger HCGHaloSupportedControlVersion = 1;

@implementation HCGHaloBorderFacts
@synthesize haloInstalled = _haloInstalled, haloVersion = _haloVersion, integrationVersion = _integrationVersion,
            controlVersion = _controlVersion, definitionProblem = _definitionProblem, haloPreferences = _haloPreferences,
            haloStatus = _haloStatus, borderAttached = _borderAttached, panelVisible = _panelVisible;
@end

@interface HCGHaloBorderStatus ()
- (instancetype)initWithState:(HCGHaloBorderState)state detail:(NSString *)detail switchOn:(BOOL)on
                    canSwitch:(BOOL)canSwitch switchNote:(NSString *)note;
@end

static NSString *HCGHaloString(NSDictionary *d, NSString *key) {
    id v = [d isKindOfClass:[NSDictionary class]] ? [d objectForKey:key] : nil;
    return [v isKindOfClass:[NSString class]] ? (NSString *)v : nil;
}

@implementation HCGHaloBorderStatus
@synthesize state = _state, detail = _detail, switchOn = _switchOn, canSwitch = _canSwitch, switchNote = _switchNote;

- (instancetype)initWithState:(HCGHaloBorderState)state detail:(NSString *)detail switchOn:(BOOL)on
                    canSwitch:(BOOL)canSwitch switchNote:(NSString *)note {
    if ((self = [super init])) {
        _state = state;
        _detail = [detail copy];
        _switchOn = on;
        _canSwitch = canSwitch;
        _switchNote = [note copy];
    }
    return self;
}

+ (NSString *)titleForState:(HCGHaloBorderState)state {
    switch (state) {
        case HCGHaloBorderStateNotInstalled: return @"Not installed";
        case HCGHaloBorderStateIncompatible: return @"Incompatible";
        case HCGHaloBorderStateDisabled: return @"Disabled";
        case HCGHaloBorderStateReady: return @"Ready";
        case HCGHaloBorderStateActive: return @"Active";
    }
    return @"Incompatible";
}

+ (BOOL)panelBorderOnInPreferences:(NSDictionary *)preferences {
    if (![preferences isKindOfClass:[NSDictionary class]]) return NO;
    id enabled = [preferences objectForKey:HCGHaloKeyEnabled];
    if (![enabled isKindOfClass:[NSNumber class]] || ![enabled boolValue]) return NO;
    NSString *target = HCGHaloString(preferences, HCGHaloKeyTarget);
    return [target isEqualToString:@"nexus"] || [target isEqualToString:@"both"];
}

+ (HCGHaloBorderStatus *)make:(HCGHaloBorderState)state detail:(NSString *)detail on:(BOOL)on
                    canSwitch:(BOOL)canSwitch note:(NSString *)note {
    return [[self alloc] initWithState:state detail:detail switchOn:on canSwitch:canSwitch switchNote:note];
}

+ (HCGHaloBorderStatus *)statusWithFacts:(HCGHaloBorderFacts *)facts {
    if (!facts.haloInstalled) {
        return [self make:HCGHaloBorderStateNotInstalled
                   detail:@"HCG Halo is not installed. Nexus keeps its own outline."
                       on:NO canSwitch:NO note:@"Install HCG Halo 0.3.1~beta1 or later to use its border."];
    }
    NSString *version = facts.haloVersion.length ? facts.haloVersion : @"(unknown version)";
    if (facts.integrationVersion < 1) {
        return [self make:HCGHaloBorderStateIncompatible
                   detail:[NSString stringWithFormat:@"HCG Halo %@ has no HCG Nexus panel border; it needs 0.2.0~beta1 or later.", version]
                       on:NO canSwitch:NO note:@"Update HCG Halo."];
    }
    if (facts.definitionProblem.length) {
        return [self make:HCGHaloBorderStateIncompatible
                   detail:[@"Nexus's border definition cannot be used: " stringByAppendingString:facts.definitionProblem]
                       on:NO canSwitch:NO note:@"Reinstall HCG Nexus."];
    }

    BOOL on = [self panelBorderOnInPreferences:facts.haloPreferences];
    BOOL canSwitch = facts.controlVersion == HCGHaloSupportedControlVersion;
    NSString *note = nil;
    if (facts.controlVersion == 0) {
        note = [NSString stringWithFormat:@"HCG Halo %@ can only be switched in its own settings (Border Target). HCG Halo 0.3.1~beta1 adds this switch.", version];
    } else if (!canSwitch) {
        note = [NSString stringWithFormat:@"HCG Halo %@ uses a newer switch interface (version %ld) than this Nexus understands.", version, (long)facts.controlVersion];
    }

    NSDictionary *status = facts.haloStatus;
    NSString *engine = HCGHaloString(status, HCGHaloStatusKeyState);
    NSString *nexusState = HCGHaloString(status, HCGHaloStatusKeyNexusState);
    NSString *nexusDetail = HCGHaloString(status, HCGHaloStatusKeyNexusDetail);

    // Halo itself stopped: whatever its settings say, nothing is drawn.
    if ([engine isEqualToString:@"kill-switch"]) {
        return [self make:HCGHaloBorderStateDisabled detail:@"HCG Halo is stopped by its kill switch." on:on canSwitch:NO
                     note:@"Remove HCG Halo's kill switch file, then respring."];
    }
    if ([engine isEqualToString:@"auto-disabled"]) {
        return [self make:HCGHaloBorderStateDisabled detail:@"HCG Halo turned itself off after repeated SpringBoard restarts." on:on
                canSwitch:NO note:@"Turn HCG Halo back on in its own settings."];
    }
    if ([engine isEqualToString:@"fault"]) {
        return [self make:HCGHaloBorderStateDisabled detail:@"HCG Halo stopped after an error and removed its border." on:on
                canSwitch:NO note:@"See HCG Halo's status page; a respring restarts it."];
    }
    if ([engine isEqualToString:@"incompatible"]) {
        return [self make:HCGHaloBorderStateIncompatible detail:@"HCG Halo reports this iOS version is not supported." on:on
                canSwitch:NO note:nil];
    }

    if (!on) {
        return [self make:HCGHaloBorderStateDisabled
                   detail:@"The HCG Halo panel border is off. Nexus shows its own outline."
                       on:NO canSwitch:canSwitch note:note];
    }
    // Halo has the border on but cannot attach (e.g. definition rejected, Nexus updated without a respring).
    if ([nexusState isEqualToString:@"unavailable"]) {
        NSString *why = nexusDetail.length ? nexusDetail : @"HCG Halo cannot attach to this Nexus.";
        return [self make:HCGHaloBorderStateIncompatible detail:why on:YES canSwitch:canSwitch note:note];
    }
    if (facts.borderAttached && facts.panelVisible) {
        return [self make:HCGHaloBorderStateActive detail:@"HCG Halo is drawing its border around this panel."
                       on:YES canSwitch:canSwitch note:note];
    }
    return [self make:HCGHaloBorderStateReady
               detail:@"On. HCG Halo draws its border while the panel is open."
                   on:YES canSwitch:canSwitch note:note];
}

@end
