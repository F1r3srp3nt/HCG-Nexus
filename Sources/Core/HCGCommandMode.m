#import "HCGCommandMode.h"
#include <math.h>

static NSString *const kUnavailable = @"Unavailable";
static NSString *const kUnknown = @"Unknown";

// Thresholds for colour roles only; the value itself is always shown.
static const double kBatteryCriticalLevel = 0.10;
static const double kBatteryCautionLevel = 0.20;
static const long long kStorageCriticalBytes = 1000LL * 1000LL * 1000LL;      // 1 GB
static const long long kStorageCautionBytes = 5LL * 1000LL * 1000LL * 1000LL; // 5 GB

static HCGStatusDisplay *HCGMakeDisplay(NSString *title, NSString *value, NSString *detail, NSString *symbol, HCGStatusColorRole role) {
    HCGStatusDisplay *display = [[HCGStatusDisplay alloc] init];
    display.title = title;
    display.value = value;
    display.detail = detail;
    display.symbolName = symbol;
    display.colorRole = role;
    display.connectionState = HCGConnectionDisplayStateUnknown;
    return display;
}

@implementation HCGStatusDisplay

@synthesize title = _title;
@synthesize value = _value;
@synthesize detail = _detail;
@synthesize symbolName = _symbolName;
@synthesize colorRole = _colorRole;
@synthesize connectionState = _connectionState;

- (NSString *)accessibilityText {
    NSString *text = [NSString stringWithFormat:@"%@: %@.", self.title ?: @"", self.value ?: kUnknown];
    if (self.detail.length > 0) text = [text stringByAppendingFormat:@" %@", self.detail];
    return text;
}

@end

@implementation HCGDeviceStatusSnapshot

@synthesize batteryLevel = _batteryLevel;
@synthesize batteryState = _batteryState;
@synthesize lowPowerMode = _lowPowerMode;
@synthesize networkStatus = _networkStatus;
@synthesize networkInterface = _networkInterface;
@synthesize networkConstrained = _networkConstrained;
@synthesize networkExpensive = _networkExpensive;
@synthesize storageAvailableBytes = _storageAvailableBytes;
@synthesize storageTotalBytes = _storageTotalBytes;

- (instancetype)init {
    if ((self = [super init])) {
        _batteryLevel = -1.0;
        _batteryState = HCGBatteryChargeStateUnknown;
        _lowPowerMode = HCGLowPowerModeStateUnknown;
        _networkStatus = HCGNetworkPathStatusUnknown;
        _networkInterface = HCGNetworkInterfaceKindNone;
        _networkConstrained = NO;
        _networkExpensive = NO;
        _storageAvailableBytes = -1;
        _storageTotalBytes = -1;
    }
    return self;
}

+ (instancetype)unavailableSnapshot {
    return [[self alloc] init];
}

- (id)copyWithZone:(NSZone *)zone {
    HCGDeviceStatusSnapshot *copy = [[[self class] allocWithZone:zone] init];
    copy.batteryLevel = self.batteryLevel;
    copy.batteryState = self.batteryState;
    copy.lowPowerMode = self.lowPowerMode;
    copy.networkStatus = self.networkStatus;
    copy.networkInterface = self.networkInterface;
    copy.networkConstrained = self.networkConstrained;
    copy.networkExpensive = self.networkExpensive;
    copy.storageAvailableBytes = self.storageAvailableBytes;
    copy.storageTotalBytes = self.storageTotalBytes;
    return copy;
}

@end

@implementation HCGCommandModeStatus

#pragma mark Device

+ (BOOL)batteryLevelIsKnown:(double)level {
    // UIDevice reports -1 when monitoring is off or the level is unknown
    // (e.g. the simulator). NaN and values above 100% are treated the same.
    return level == level && level >= 0.0 && level <= 1.0001;
}

+ (HCGStatusDisplay *)batteryDisplayForSnapshot:(HCGDeviceStatusSnapshot *)snapshot {
    double level = snapshot ? snapshot.batteryLevel : -1.0;
    HCGBatteryChargeState state = snapshot ? snapshot.batteryState : HCGBatteryChargeStateUnknown;
    BOOL known = [self batteryLevelIsKnown:level];
    if (level > 1.0) level = 1.0;

    NSString *detail = nil;
    switch (state) {
        case HCGBatteryChargeStateUnplugged: detail = @"On battery"; break;
        case HCGBatteryChargeStateCharging: detail = @"Charging"; break;
        case HCGBatteryChargeStateFull: detail = @"Plugged in, fully charged"; break;
        default: detail = @"Charging state unavailable"; state = HCGBatteryChargeStateUnknown; break;
    }

    NSString *value = known ? [NSString stringWithFormat:@"%ld%%", (long)lround(level * 100.0)] : kUnavailable;
    HCGStatusColorRole role = HCGStatusColorRoleNeutral;
    if (state == HCGBatteryChargeStateCharging || state == HCGBatteryChargeStateFull) {
        role = HCGStatusColorRolePositive;
    } else if (known && level <= kBatteryCriticalLevel) {
        role = HCGStatusColorRoleCritical;
    } else if (known && level <= kBatteryCautionLevel) {
        role = HCGStatusColorRoleCaution;
    } else if (!known) {
        role = HCGStatusColorRoleMuted;
    }

    NSString *symbol = @"battery.100";
    if (state == HCGBatteryChargeStateCharging || state == HCGBatteryChargeStateFull) symbol = @"battery.100.bolt";
    else if (!known) symbol = @"battery.0";
    else if (level <= kBatteryCautionLevel) symbol = @"battery.25";
    if (!known && state == HCGBatteryChargeStateUnknown) detail = @"iOS reported no battery level";
    return HCGMakeDisplay(@"Battery", value, detail, symbol, role);
}

+ (HCGStatusDisplay *)lowPowerDisplayForSnapshot:(HCGDeviceStatusSnapshot *)snapshot {
    HCGLowPowerModeState state = snapshot ? snapshot.lowPowerMode : HCGLowPowerModeStateUnknown;
    if (state == HCGLowPowerModeStateOn) {
        return HCGMakeDisplay(@"Low Power Mode", @"On", @"iOS is reducing background activity", @"tortoise", HCGStatusColorRoleCaution);
    }
    if (state == HCGLowPowerModeStateOff) {
        return HCGMakeDisplay(@"Low Power Mode", @"Off", @"Normal power", @"bolt", HCGStatusColorRoleNeutral);
    }
    return HCGMakeDisplay(@"Low Power Mode", kUnavailable, @"iOS reported no power mode", @"questionmark.circle", HCGStatusColorRoleMuted);
}

+ (NSString *)interfaceName:(HCGNetworkInterfaceKind)kind {
    switch (kind) {
        case HCGNetworkInterfaceKindWiFi: return @"Wi-Fi";
        case HCGNetworkInterfaceKindCellular: return @"Cellular";
        case HCGNetworkInterfaceKindWired: return @"Wired";
        case HCGNetworkInterfaceKindOther: return @"Other network";
        default: return nil;
    }
}

+ (HCGStatusDisplay *)networkDisplayForSnapshot:(HCGDeviceStatusSnapshot *)snapshot {
    HCGNetworkPathStatus status = snapshot ? snapshot.networkStatus : HCGNetworkPathStatusUnavailable;
    switch (status) {
        case HCGNetworkPathStatusSatisfied: {
            NSString *name = [self interfaceName:snapshot.networkInterface];
            NSString *value = name ?: @"Available";
            NSString *symbol = @"network";
            if (snapshot.networkInterface == HCGNetworkInterfaceKindWiFi) symbol = @"wifi";
            if (snapshot.networkInterface == HCGNetworkInterfaceKindCellular) symbol = @"antenna.radiowaves.left.and.right";
            // A satisfied path means iOS has a usable route. It is not an
            // internet or HCG service check, and the text says so.
            NSString *detail = @"iOS reports a usable network path";
            if (snapshot.networkConstrained) detail = [detail stringByAppendingString:@" · Low Data Mode"];
            else if (snapshot.networkExpensive) detail = [detail stringByAppendingString:@" · metered"];
            return HCGMakeDisplay(@"Network", value, detail, symbol, HCGStatusColorRoleNeutral);
        }
        case HCGNetworkPathStatusUnsatisfied:
            return HCGMakeDisplay(@"Network", @"No connection", @"iOS reports no usable network path", @"wifi.slash", HCGStatusColorRoleCaution);
        case HCGNetworkPathStatusRequiresConnection:
            return HCGMakeDisplay(@"Network", @"Not connected yet", @"A connection must be established first (for example a VPN on demand)", @"wifi.exclamationmark", HCGStatusColorRoleCaution);
        case HCGNetworkPathStatusUnknown:
            return HCGMakeDisplay(@"Network", kUnknown, @"Waiting for the first network update from iOS", @"questionmark.circle", HCGStatusColorRoleNeutral);
        default:
            return HCGMakeDisplay(@"Network", kUnavailable, @"Network path monitoring is not available", @"questionmark.circle", HCGStatusColorRoleMuted);
    }
}

+ (HCGStatusDisplay *)storageDisplayForSnapshot:(HCGDeviceStatusSnapshot *)snapshot {
    long long available = snapshot ? snapshot.storageAvailableBytes : -1;
    long long total = snapshot ? snapshot.storageTotalBytes : -1;
    NSString *availableText = [self formattedByteCount:available];
    if (!availableText) {
        return HCGMakeDisplay(@"Storage", kUnavailable, @"iOS reported no free-space value", @"internaldrive", HCGStatusColorRoleMuted);
    }
    NSString *totalText = total > 0 ? [self formattedByteCount:total] : nil;
    NSString *detail = totalText ? [NSString stringWithFormat:@"available of %@", totalText] : @"available · total capacity unavailable";
    HCGStatusColorRole role = HCGStatusColorRoleNeutral;
    if (available < kStorageCriticalBytes) role = HCGStatusColorRoleCritical;
    else if (available < kStorageCautionBytes) role = HCGStatusColorRoleCaution;
    return HCGMakeDisplay(@"Storage", availableText, detail, @"internaldrive", role);
}

+ (NSArray *)deviceDisplaysForSnapshot:(HCGDeviceStatusSnapshot *)snapshot {
    return [NSArray arrayWithObjects:[self batteryDisplayForSnapshot:snapshot], [self lowPowerDisplayForSnapshot:snapshot],
                                     [self networkDisplayForSnapshot:snapshot], [self storageDisplayForSnapshot:snapshot], nil];
}

+ (double)scrimAlphaReducingTransparency:(BOOL)reduceTransparency increaseContrast:(BOOL)increaseContrast {
    if (reduceTransparency) return 0.94;
    return increaseContrast ? 0.35 : 0.30;
}

+ (BOOL)animatesTransitionsWithReduceMotion:(BOOL)reduceMotion animationsEnabled:(BOOL)animationsEnabled {
    return animationsEnabled && !reduceMotion;
}

+ (NSString *)formattedByteCount:(long long)bytes {
    if (bytes < 0) return nil;
    if (bytes < 1000) return [NSString stringWithFormat:@"%lld bytes", bytes];
    NSArray *units = [NSArray arrayWithObjects:@"KB", @"MB", @"GB", @"TB", @"PB", nil];
    double value = (double)bytes;
    NSUInteger unit = 0;
    value /= 1000.0;
    while (value >= 999.95 && unit + 1 < units.count) {
        value /= 1000.0;
        unit++;
    }
    NSString *name = [units objectAtIndex:unit];
    if (value >= 100.0) return [NSString stringWithFormat:@"%.0f %@", value, name];
    return [NSString stringWithFormat:@"%.1f %@", value, name];
}

#pragma mark Integrations

+ (HCGConnectionDisplayState)connectionStateForIntegrationStatus:(HCGIntegrationStatus *)status detail:(NSString **)detailOut {
    NSString *detail = nil;
    HCGConnectionDisplayState state = HCGConnectionDisplayStateUnknown;

    if (status == nil) {
        detail = @"No status was reported for this integration.";
    } else if (!status.recognized) {
        detail = @"HCG Nexus does not recognise this integration.";
    } else if (!status.contractAvailable) {
        state = HCGConnectionDisplayStateUnavailable;
        detail = @"No interface a phone can reach exists for this integration yet.";
    } else if (!status.configured) {
        state = HCGConnectionDisplayStateOff;
        detail = @"Turned off. Turn it on in HCG Nexus settings to open it from Nexus.";
    } else {
        switch (status.state) {
            case HCGIntegrationStateUnavailableHere:
                state = HCGConnectionDisplayStateUnavailable;
                detail = @"This build cannot open other apps; that needs the HCG Nexus jailbreak package.";
                break;
            case HCGIntegrationStateAppMissing:
                state = HCGConnectionDisplayStateUnavailable;
                detail = @"The app is not installed on this device.";
                break;
            case HCGIntegrationStateUnverified:
                detail = @"Turned on, but whether the app is installed cannot be checked here.";
                break;
            case HCGIntegrationStateReady:
                switch (status.reachability) {
                    case HCGIntegrationReachabilityUnreachable:
                        state = HCGConnectionDisplayStateDisconnected;
                        detail = @"Turned on, but its service cannot be reached.";
                        break;
                    case HCGIntegrationReachabilityReachable:
                    case HCGIntegrationReachabilityNotApplicable:
                        switch (status.session) {
                            case HCGIntegrationSessionSignedOut:
                                state = HCGConnectionDisplayStateSignedOut;
                                detail = @"Reachable, but you need to sign in.";
                                break;
                            case HCGIntegrationSessionSignedIn:
                                state = HCGConnectionDisplayStateConnected;
                                detail = @"Reachable and signed in.";
                                break;
                            case HCGIntegrationSessionNotApplicable:
                                state = HCGConnectionDisplayStateConnected;
                                detail = status.reachability == HCGIntegrationReachabilityNotApplicable
                                    ? @"Nexus can open the app. No session or sync status is visible to Nexus."
                                    : @"Reachable. No sign-in is needed.";
                                break;
                            default:
                                detail = @"Turned on; sign-in state was not reported.";
                                break;
                        }
                        break;
                    default:
                        detail = @"Turned on; reachability was not reported.";
                        break;
                }
                break;
            default:
                // NotConnected while configured, or an out-of-range value.
                detail = @"Turned on, but no usable status was reported.";
                break;
        }
    }
    if (detailOut) *detailOut = detail;
    return state;
}

+ (HCGConnectionDisplayState)connectionStateForIntegrationStatus:(HCGIntegrationStatus *)status {
    return [self connectionStateForIntegrationStatus:status detail:NULL];
}

+ (HCGStatusDisplay *)displayForIntegrationStatus:(HCGIntegrationStatus *)status {
    NSString *detail = nil;
    HCGConnectionDisplayState state = [self connectionStateForIntegrationStatus:status detail:&detail];
    NSString *title = status.displayName.length > 0 ? status.displayName : @"Integration";
    HCGStatusDisplay *display = HCGMakeDisplay(title, [self labelForConnectionState:state], detail ?: @"",
                                               [self symbolNameForConnectionState:state], [self colorRoleForConnectionState:state]);
    display.connectionState = state;
    return display;
}

+ (NSString *)labelForConnectionState:(HCGConnectionDisplayState)state {
    switch (state) {
        case HCGConnectionDisplayStateUnavailable: return kUnavailable;
        case HCGConnectionDisplayStateOff: return @"Off";
        case HCGConnectionDisplayStateDisconnected: return @"Disconnected";
        case HCGConnectionDisplayStateSignedOut: return @"Signed out";
        case HCGConnectionDisplayStateConnected: return @"Connected";
        default: return kUnknown;
    }
}

+ (HCGStatusColorRole)colorRoleForConnectionState:(HCGConnectionDisplayState)state {
    switch (state) {
        case HCGConnectionDisplayStateConnected: return HCGStatusColorRolePositive;
        case HCGConnectionDisplayStateDisconnected:
        case HCGConnectionDisplayStateSignedOut: return HCGStatusColorRoleCaution;
        case HCGConnectionDisplayStateUnavailable:
        case HCGConnectionDisplayStateOff: return HCGStatusColorRoleMuted;
        default: return HCGStatusColorRoleNeutral;
    }
}

+ (NSString *)symbolNameForConnectionState:(HCGConnectionDisplayState)state {
    switch (state) {
        case HCGConnectionDisplayStateUnavailable: return @"nosign";
        case HCGConnectionDisplayStateOff: return @"slash.circle";
        case HCGConnectionDisplayStateDisconnected: return @"exclamationmark.triangle";
        case HCGConnectionDisplayStateSignedOut: return @"person.crop.circle.badge.exclamationmark";
        case HCGConnectionDisplayStateConnected: return @"checkmark.circle";
        default: return @"questionmark.circle";
    }
}

@end
