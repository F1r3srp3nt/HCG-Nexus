#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// "Use HCG Halo border" — Nexus's view of the optional HCG Halo panel border.
//
// Nexus never draws Halo's border and never edits Halo's settings itself. It reads:
//   * what is installed (HCG Halo's Settings bundle Info.plist: version, HCGHaloNexusIntegration,
//     HCGHaloNexusControl),
//   * Halo's documented preferences (domain com.hakmicapitalgroup.halo: enabled, target) and status
//     (domain com.hakmicapitalgroup.halo.status, record "status": state, nexusState, nexusDetail),
//   * its own observation: whether a decoration is attached to the panel's border host while shown,
// and switches the border only through Halo's own API (HaloNexusControl, contract HCGHaloNexusControl 1),
// which decides how to change Halo's settings without turning on Halo's screen-edge effects.

typedef NS_ENUM(NSInteger, HCGHaloBorderState) {
    HCGHaloBorderStateNotInstalled = 0, // no HCG Halo
    HCGHaloBorderStateIncompatible,     // HCG Halo cannot draw on this Nexus (too old, invalid definition, needs respring)
    HCGHaloBorderStateDisabled,         // compatible, panel border off (or Halo stopped)
    HCGHaloBorderStateReady,            // panel border on; drawn while the panel is open
    HCGHaloBorderStateActive,           // Halo's border is attached to the open panel right now
};

// HCG Halo's documented names (HCG-Jailbreak-Research HCGHalo docs/NEXUS.md and its preferences header).
FOUNDATION_EXPORT NSString *const HCGHaloSettingsDomain;      // com.hakmicapitalgroup.halo
FOUNDATION_EXPORT NSString *const HCGHaloStatusDomain;           // com.hakmicapitalgroup.halo.status
FOUNDATION_EXPORT NSString *const HCGHaloStatusRecordKey;        // "status"
FOUNDATION_EXPORT NSString *const HCGHaloKeyEnabled;             // "enabled"
FOUNDATION_EXPORT NSString *const HCGHaloKeyTarget;              // "screen" | "nexus" | "both"
FOUNDATION_EXPORT NSString *const HCGHaloStatusKeyState;         // "active" | "disabled" | "waiting" | "incompatible" | "killswitch" | "autodisabled" | "fault"
FOUNDATION_EXPORT NSString *const HCGHaloStatusKeyNexusState;    // "attached" | "waiting" | "off" | "unavailable"
FOUNDATION_EXPORT NSString *const HCGHaloStatusKeyNexusDetail;
FOUNDATION_EXPORT NSString *const HCGHaloStatusRequestNotification; // Darwin: ask SpringBoard to write Halo's status now
FOUNDATION_EXPORT NSString *const HCGHaloPrefsBundleName;        // HCGHaloPrefs.bundle
FOUNDATION_EXPORT NSString *const HCGHaloIntegrationInfoKey;     // HCGHaloNexusIntegration (Info.plist)
FOUNDATION_EXPORT NSString *const HCGHaloControlInfoKey;         // HCGHaloNexusControl (Info.plist)
FOUNDATION_EXPORT NSString *const HCGHaloControlClassName;       // HaloNexusControl
FOUNDATION_EXPORT const NSInteger HCGHaloSupportedControlVersion; // 1

// Everything Nexus knows; filled by the host (SpringBoard, Settings) and testable on its own.
@interface HCGHaloBorderFacts : NSObject {
    BOOL _haloInstalled;
    NSString *_haloVersion;
    NSInteger _integrationVersion;
    NSInteger _controlVersion;
    NSString *_definitionProblem;
    NSDictionary *_haloPreferences;
    NSDictionary *_haloStatus;
    BOOL _borderAttached;
    BOOL _panelVisible;
}
@property (nonatomic) BOOL haloInstalled;
@property (nonatomic, copy, nullable) NSString *haloVersion;
@property (nonatomic) NSInteger integrationVersion;    // 0: Halo has no Nexus border (0.1.x)
@property (nonatomic) NSInteger controlVersion;        // 0: Halo has no switch API (0.2.0~beta1)
@property (nonatomic, copy, nullable) NSString *definitionProblem; // nil: Nexus's HaloBorder.plist is installed and valid
@property (nonatomic, copy, nullable) NSDictionary *haloPreferences; // {enabled, target}
@property (nonatomic, copy, nullable) NSDictionary *haloStatus;      // Halo's status record
@property (nonatomic) BOOL borderAttached;             // Nexus's own observation (border host has a decoration)
@property (nonatomic) BOOL panelVisible;
@end

@interface HCGHaloBorderStatus : NSObject {
    HCGHaloBorderState _state;
    NSString *_detail;
    BOOL _switchOn;
    BOOL _canSwitch;
    NSString *_switchNote;
}
@property (nonatomic, readonly) HCGHaloBorderState state;
@property (nonatomic, readonly, copy) NSString *detail;     // one honest sentence
@property (nonatomic, readonly) BOOL switchOn;              // Halo's panel border is turned on in Halo's settings
@property (nonatomic, readonly) BOOL canSwitch;             // Nexus may switch it (Halo's API is present and usable)
@property (nonatomic, readonly, copy, nullable) NSString *switchNote; // why the switch is unavailable, when it is

+ (HCGHaloBorderStatus *)statusWithFacts:(HCGHaloBorderFacts *)facts;
+ (NSString *)titleForState:(HCGHaloBorderState)state;      // "Not installed", "Incompatible", "Disabled", "Ready", "Active"
// enabled && target is "nexus" or "both"; tolerant of missing or malformed values (they mean "off").
+ (BOOL)panelBorderOnInPreferences:(nullable NSDictionary *)preferences;
@end

NS_ASSUME_NONNULL_END
