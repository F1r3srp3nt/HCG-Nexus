#import <Foundation/Foundation.h>
#import "HCGKeyValueStore.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, HCGHandleSide) {
    HCGHandleSideRight = 0,
    HCGHandleSideLeft = 1,
};

// Background blur behind the panel. Discrete levels map to real system
// materials (no simulated partial blur). Reduce Transparency always wins: the
// panel is then opaque and unblurred whatever is stored here.
typedef NS_ENUM(NSInteger, HCGPanelBlur) {
    HCGPanelBlurOff = 0,
    HCGPanelBlurLight = 1,
    HCGPanelBlurStandard = 2,
    HCGPanelBlurStrong = 3,
};

typedef NS_ENUM(NSInteger, HCGTerminalVariant) {
    HCGTerminalVariantNone = 0,
    HCGTerminalVariantStandard = 1,
    HCGTerminalVariantUnleashed = 2,
};

// Preference keys (CFPreferences domain HCGNexusPreferencesDomain).
FOUNDATION_EXPORT NSString *const HCGSettingEnabled;
FOUNDATION_EXPORT NSString *const HCGSettingHandleSide;
FOUNDATION_EXPORT NSString *const HCGSettingHandlePosition;
FOUNDATION_EXPORT NSString *const HCGSettingHandleOpacity;
FOUNDATION_EXPORT NSString *const HCGSettingKeyboardSafeZone;
FOUNDATION_EXPORT NSString *const HCGSettingAnimations;
FOUNDATION_EXPORT NSString *const HCGSettingHaptics;
FOUNDATION_EXPORT NSString *const HCGSettingCompanionOpen; // "companionOpenAllowed"
FOUNDATION_EXPORT NSString *const HCGSettingTerminalVariant;
FOUNDATION_EXPORT NSString *const HCGSettingNewsConnected;
FOUNDATION_EXPORT NSString *const HCGSettingSentinelConnected;
FOUNDATION_EXPORT NSString *const HCGSettingPanelOpacity;
FOUNDATION_EXPORT NSString *const HCGSettingPanelBlur;

// Value object. All setters clamp to valid ranges.
@interface HCGSettings : NSObject <NSCopying> {
    BOOL _enabled;
    HCGHandleSide _handleSide;
    double _handlePosition;
    double _handleOpacity;
    BOOL _keyboardSafeZone;
    BOOL _animationsEnabled;
    BOOL _hapticsEnabled;
    BOOL _companionOpenAllowed;
    HCGTerminalVariant _terminalVariant;
    BOOL _newsConnected;
    BOOL _sentinelConnected;
    double _panelOpacity;
    HCGPanelBlur _panelBlur;
}
// Defaults to NO: HCG Nexus starts disabled after installation.
@property (nonatomic) BOOL enabled;
@property (nonatomic) HCGHandleSide handleSide;
@property (nonatomic) double handlePosition;  // 0 (top of allowed band) … 1 (bottom)
@property (nonatomic) double handleOpacity;   // 0.25 … 1.0
@property (nonatomic) BOOL keyboardSafeZone;  // keep handle above typical keyboard area
@property (nonatomic) BOOL animationsEnabled; // Reduce Motion always overrides
@property (nonatomic) BOOL hapticsEnabled;
// HCG apps and tweaks (HCG Terminal, HCG Portal) may open the panel at the Ecosystem dashboard. Navigation
// only, unlocked only, rate-limited. Default on.
@property (nonatomic) BOOL companionOpenAllowed;
@property (nonatomic) HCGTerminalVariant terminalVariant;
@property (nonatomic) BOOL newsConnected;
@property (nonatomic) BOOL sentinelConnected;
// Smoked-glass tint over the blur, 0.35 (most transparent) … 1.0 (opaque).
@property (nonatomic) double panelOpacity;
@property (nonatomic) HCGPanelBlur panelBlur;

+ (instancetype)defaultSettings;
+ (double)minimumHandleOpacity;
+ (double)minimumPanelOpacity;
// The tint actually drawn: with blur off, never below 0.6 so text stays
// readable over a busy wallpaper; Reduce Transparency forces 1.0.
- (double)effectivePanelOpacityWithReduceTransparency:(BOOL)reduceTransparency;
- (HCGPanelBlur)effectivePanelBlurWithReduceTransparency:(BOOL)reduceTransparency;

// Strict, typed, clamped read of a stored dictionary. Unknown keys are ignored
// and wrongly typed values fall back to defaults.
+ (instancetype)settingsFromStore:(id<HCGKeyValueStore>)store;
- (void)writeToStore:(id<HCGKeyValueStore>)store;

// Restores appearance/behaviour defaults. Keeps `enabled` and never touches
// workspaces, recents or integration choices.
- (void)resetPreservingEnabledAndIntegrations;

- (NSDictionary *)dictionaryRepresentation;
@end

NS_ASSUME_NONNULL_END
