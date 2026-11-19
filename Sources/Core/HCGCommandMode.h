#import <Foundation/Foundation.h>
#import "HCGIntegrations.h"
#import "HCGSettings.h"

NS_ASSUME_NONNULL_BEGIN

// Command Mode: status → display mapping (label, detail, symbol, colour role).
//
// Everything here is a pure function of values the platform layer read from
// public iOS APIs (UIDevice, NSProcessInfo, Network.framework, NSFileManager)
// or from the integrations model. Nothing is invented: a value the platform
// could not read maps to "Unavailable" (no API value) or "Unknown" (state not
// reported), never to a plausible-looking default.

// Colour roles, resolved to UIColors by the Panel layer (HCGTheme). Colour is
// never the only signal: every display also carries a distinct text label.
typedef NS_ENUM(NSInteger, HCGStatusColorRole) {
    HCGStatusColorRoleNeutral = 0,  // informational, or unknown
    HCGStatusColorRoleMuted = 1,    // off / unavailable: nothing is running
    HCGStatusColorRolePositive = 2, // connected, charging, fully charged
    HCGStatusColorRoleCaution = 3,  // needs attention: disconnected, signed out, low
    HCGStatusColorRoleCritical = 4, // very low battery or storage
};

// What the Command Mode UI shows for an HCG integration.
typedef NS_ENUM(NSInteger, HCGConnectionDisplayState) {
    HCGConnectionDisplayStateUnknown = 0,       // status missing, unrecognised or not reported
    HCGConnectionDisplayStateUnavailable = 1,   // app not installed, no integration contract, or not possible in this build
    HCGConnectionDisplayStateOff = 2,           // available but not turned on in settings
    HCGConnectionDisplayStateDisconnected = 3,  // configured, but its service is not reachable
    HCGConnectionDisplayStateSignedOut = 4,     // configured and reachable, but needs sign-in
    HCGConnectionDisplayStateConnected = 5,     // configured, reachable and (where it applies) signed in
    // An app Nexus can open but which reports no service or session (HCG Terminal, HCG News): opening it is
    // never shown as "Connected". Appended: raw values above are stable.
    HCGConnectionDisplayStateLaunchAvailable = 6,
};

typedef NS_ENUM(NSInteger, HCGBatteryChargeState) {
    HCGBatteryChargeStateUnknown = 0, // UIDeviceBatteryStateUnknown, or monitoring unavailable
    HCGBatteryChargeStateUnplugged = 1,
    HCGBatteryChargeStateCharging = 2,
    HCGBatteryChargeStateFull = 3,
};

typedef NS_ENUM(NSInteger, HCGLowPowerModeState) {
    HCGLowPowerModeStateUnknown = 0,
    HCGLowPowerModeStateOff = 1,
    HCGLowPowerModeStateOn = 2,
};

// nw_path_status_t, plus the two cases where no path has been reported.
typedef NS_ENUM(NSInteger, HCGNetworkPathStatus) {
    HCGNetworkPathStatusUnknown = 0,       // monitor started, no update received yet
    HCGNetworkPathStatusUnavailable = 1,   // path monitoring could not be started
    HCGNetworkPathStatusSatisfied = 2,
    HCGNetworkPathStatusUnsatisfied = 3,
    HCGNetworkPathStatusRequiresConnection = 4,
};

typedef NS_ENUM(NSInteger, HCGNetworkInterfaceKind) {
    HCGNetworkInterfaceKindNone = 0,  // not reported
    HCGNetworkInterfaceKindWiFi = 1,
    HCGNetworkInterfaceKindCellular = 2,
    HCGNetworkInterfaceKindWired = 3,
    HCGNetworkInterfaceKindOther = 4,
};

// One line of Command Mode status.
@interface HCGStatusDisplay : NSObject {
    NSString *_title;
    NSString *_value;
    NSString *_detail;
    NSString *_symbolName;
    HCGStatusColorRole _colorRole;
    HCGConnectionDisplayState _connectionState;
}
@property (nonatomic, copy) NSString *title;      // "Battery", "HCG Terminal"
@property (nonatomic, copy) NSString *value;      // "82%", "Connected", "Unavailable"
@property (nonatomic, copy) NSString *detail;     // one-line explanation
@property (nonatomic, copy) NSString *symbolName; // SF Symbol (iOS 13+ names)
@property (nonatomic) HCGStatusColorRole colorRole;
// Only meaningful for integration displays; Unknown otherwise.
@property (nonatomic) HCGConnectionDisplayState connectionState;
// "Battery: 82%. Charging." — for VoiceOver.
- (NSString *)accessibilityText;
@end

// Device facts read by the platform layer. Every field defaults to "not read".
@interface HCGDeviceStatusSnapshot : NSObject <NSCopying> {
    double _batteryLevel;
    HCGBatteryChargeState _batteryState;
    HCGLowPowerModeState _lowPowerMode;
    HCGNetworkPathStatus _networkStatus;
    HCGNetworkInterfaceKind _networkInterface;
    BOOL _networkConstrained;
    BOOL _networkExpensive;
    long long _storageAvailableBytes;
    long long _storageTotalBytes;
}
@property (nonatomic) double batteryLevel;                  // 0…1; negative = unavailable (UIDevice reports -1)
@property (nonatomic) HCGBatteryChargeState batteryState;
@property (nonatomic) HCGLowPowerModeState lowPowerMode;
@property (nonatomic) HCGNetworkPathStatus networkStatus;
@property (nonatomic) HCGNetworkInterfaceKind networkInterface;
@property (nonatomic) BOOL networkConstrained;              // Low Data Mode
@property (nonatomic) BOOL networkExpensive;                // cellular or personal hotspot
@property (nonatomic) long long storageAvailableBytes;      // negative = unavailable
@property (nonatomic) long long storageTotalBytes;          // negative = unavailable
+ (instancetype)unavailableSnapshot;
@end

@interface HCGCommandModeStatus : NSObject

+ (HCGStatusDisplay *)batteryDisplayForSnapshot:(nullable HCGDeviceStatusSnapshot *)snapshot;
+ (HCGStatusDisplay *)lowPowerDisplayForSnapshot:(nullable HCGDeviceStatusSnapshot *)snapshot;
+ (HCGStatusDisplay *)networkDisplayForSnapshot:(nullable HCGDeviceStatusSnapshot *)snapshot;
+ (HCGStatusDisplay *)storageDisplayForSnapshot:(nullable HCGDeviceStatusSnapshot *)snapshot;
// Battery, Low Power Mode, Network, Storage — in display order.
+ (NSArray<HCGStatusDisplay *> *)deviceDisplaysForSnapshot:(nullable HCGDeviceStatusSnapshot *)snapshot;

// Precedence: missing/unrecognised → Unknown; no contract → Unavailable;
// not turned on → Off; this build cannot open it / app missing → Unavailable;
// installation unchecked → Unknown; unreachable → Disconnected; reachability
// not reported → Unknown; signed out → Signed out; sign-in not reported →
// Unknown; otherwise Connected. Out-of-range enum values map to Unknown.
+ (HCGConnectionDisplayState)connectionStateForIntegrationStatus:(nullable HCGIntegrationStatus *)status;
+ (HCGStatusDisplay *)displayForIntegrationStatus:(nullable HCGIntegrationStatus *)status;

+ (NSString *)labelForConnectionState:(HCGConnectionDisplayState)state;
+ (HCGStatusColorRole)colorRoleForConnectionState:(HCGConnectionDisplayState)state;
+ (NSString *)symbolNameForConnectionState:(HCGConnectionDisplayState)state;

// Presentation policy. The scrim dims what is behind Command Mode (the app or
// Home Screen wallpaper) by a restrained 30% (35% with Increase Contrast).
// With Reduce Transparency it becomes a nearly opaque obsidian surface.
+ (double)scrimAlphaReducingTransparency:(BOOL)reduceTransparency increaseContrast:(BOOL)increaseContrast;
// Command Mode's card uses the panel glass the user chose (HCG Nexus › Panel glass), by the same rules as the
// panel: Reduce Transparency makes it opaque and unblurred; with blur off it never goes below the panel's
// readability floor; Increase Contrast raises the tint to at least 0.86. nil settings mean the defaults.
+ (double)cardTintAlphaForSettings:(nullable HCGSettings *)settings reduceTransparency:(BOOL)reduceTransparency
                  increaseContrast:(BOOL)increaseContrast;
+ (HCGPanelBlur)cardBlurForSettings:(nullable HCGSettings *)settings reduceTransparency:(BOOL)reduceTransparency;
// Opening and closing are animated only when the user allows animations in
// HCG Nexus settings and Reduce Motion is off; otherwise they are instant.
+ (BOOL)animatesTransitionsWithReduceMotion:(BOOL)reduceMotion animationsEnabled:(BOOL)animationsEnabled;

// Decimal (base-1000) units as iOS Settings uses: "512 MB", "64.2 GB".
// Negative input returns nil.
+ (nullable NSString *)formattedByteCount:(long long)bytes;
@end

NS_ASSUME_NONNULL_END
