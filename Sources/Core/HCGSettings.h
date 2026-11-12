#import <Foundation/Foundation.h>
#import "HCGKeyValueStore.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, HCGHandleSide) {
    HCGHandleSideRight = 0,
    HCGHandleSideLeft = 1,
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
FOUNDATION_EXPORT NSString *const HCGSettingTerminalVariant;
FOUNDATION_EXPORT NSString *const HCGSettingNewsConnected;

// Value object. All setters clamp to valid ranges.
@interface HCGSettings : NSObject <NSCopying> {
    BOOL _enabled;
    HCGHandleSide _handleSide;
    double _handlePosition;
    double _handleOpacity;
    BOOL _keyboardSafeZone;
    BOOL _animationsEnabled;
    BOOL _hapticsEnabled;
    HCGTerminalVariant _terminalVariant;
    BOOL _newsConnected;
}
// Defaults to NO: HCG Nexus starts disabled after installation.
@property (nonatomic) BOOL enabled;
@property (nonatomic) HCGHandleSide handleSide;
@property (nonatomic) double handlePosition;  // 0 (top of allowed band) … 1 (bottom)
@property (nonatomic) double handleOpacity;   // 0.25 … 1.0
@property (nonatomic) BOOL keyboardSafeZone;  // keep handle above typical keyboard area
@property (nonatomic) BOOL animationsEnabled; // Reduce Motion always overrides
@property (nonatomic) BOOL hapticsEnabled;
@property (nonatomic) HCGTerminalVariant terminalVariant;
@property (nonatomic) BOOL newsConnected;

+ (instancetype)defaultSettings;
+ (double)minimumHandleOpacity;

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
