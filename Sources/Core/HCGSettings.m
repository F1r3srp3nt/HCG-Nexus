#import "HCGSettings.h"

NSString *const HCGSettingEnabled = @"enabled";
NSString *const HCGSettingHandleSide = @"handleSide";
NSString *const HCGSettingHandlePosition = @"handlePosition";
NSString *const HCGSettingHandleOpacity = @"handleOpacity";
NSString *const HCGSettingKeyboardSafeZone = @"keyboardSafeZone";
NSString *const HCGSettingAnimations = @"animationsEnabled";
NSString *const HCGSettingHaptics = @"hapticsEnabled";
NSString *const HCGSettingTerminalVariant = @"terminalVariant";
NSString *const HCGSettingNewsConnected = @"newsConnected";

static const double kDefaultPosition = 0.35;
static const double kDefaultOpacity = 0.7;
static const double kMinOpacity = 0.25;

static double HCGClamp(double value, double lo, double hi) {
    if (value != value) return lo; // NaN
    if (value < lo) return lo;
    if (value > hi) return hi;
    return value;
}

static BOOL HCGReadBool(id<HCGKeyValueStore> store, NSString *key, BOOL fallback) {
    id value = [store objectForKey:key];
    if ([value isKindOfClass:[NSNumber class]]) return [value boolValue];
    return fallback;
}

static double HCGReadDouble(id<HCGKeyValueStore> store, NSString *key, double fallback) {
    id value = [store objectForKey:key];
    if ([value isKindOfClass:[NSNumber class]]) return [value doubleValue];
    return fallback;
}

static NSInteger HCGReadInteger(id<HCGKeyValueStore> store, NSString *key, NSInteger fallback) {
    id value = [store objectForKey:key];
    if ([value isKindOfClass:[NSNumber class]]) return [value integerValue];
    return fallback;
}

@implementation HCGSettings

@synthesize enabled = _enabled;
@synthesize handleSide = _handleSide;
@synthesize handlePosition = _handlePosition;
@synthesize handleOpacity = _handleOpacity;
@synthesize keyboardSafeZone = _keyboardSafeZone;
@synthesize animationsEnabled = _animationsEnabled;
@synthesize hapticsEnabled = _hapticsEnabled;
@synthesize terminalVariant = _terminalVariant;
@synthesize newsConnected = _newsConnected;

+ (double)minimumHandleOpacity {
    return kMinOpacity;
}

- (instancetype)init {
    if ((self = [super init])) {
        _enabled = NO;
        _terminalVariant = HCGTerminalVariantNone;
        _newsConnected = NO;
        [self resetPreservingEnabledAndIntegrations];
    }
    return self;
}

+ (instancetype)defaultSettings {
    return [[self alloc] init];
}

- (void)resetPreservingEnabledAndIntegrations {
    _handleSide = HCGHandleSideRight;
    _handlePosition = kDefaultPosition;
    _handleOpacity = kDefaultOpacity;
    _keyboardSafeZone = YES;
    _animationsEnabled = YES;
    _hapticsEnabled = YES;
}

- (void)setHandleSide:(HCGHandleSide)handleSide {
    _handleSide = (handleSide == HCGHandleSideLeft) ? HCGHandleSideLeft : HCGHandleSideRight;
}

- (void)setHandlePosition:(double)handlePosition {
    _handlePosition = HCGClamp(handlePosition, 0.0, 1.0);
}

- (void)setHandleOpacity:(double)handleOpacity {
    _handleOpacity = HCGClamp(handleOpacity, kMinOpacity, 1.0);
}

- (void)setTerminalVariant:(HCGTerminalVariant)terminalVariant {
    if (terminalVariant != HCGTerminalVariantStandard && terminalVariant != HCGTerminalVariantUnleashed) {
        terminalVariant = HCGTerminalVariantNone;
    }
    _terminalVariant = terminalVariant;
}

- (id)copyWithZone:(NSZone *)zone {
    HCGSettings *copy = [[[self class] allocWithZone:zone] init];
    copy.enabled = self.enabled;
    copy.handleSide = self.handleSide;
    copy.handlePosition = self.handlePosition;
    copy.handleOpacity = self.handleOpacity;
    copy.keyboardSafeZone = self.keyboardSafeZone;
    copy.animationsEnabled = self.animationsEnabled;
    copy.hapticsEnabled = self.hapticsEnabled;
    copy.terminalVariant = self.terminalVariant;
    copy.newsConnected = self.newsConnected;
    return copy;
}

- (BOOL)isEqual:(id)object {
    if (![object isKindOfClass:[HCGSettings class]]) return NO;
    return [[self dictionaryRepresentation] isEqual:[object dictionaryRepresentation]];
}

- (NSUInteger)hash {
    return (NSUInteger)self.enabled ^ ((NSUInteger)self.handleSide << 1);
}

+ (instancetype)settingsFromStore:(id<HCGKeyValueStore>)store {
    HCGSettings *settings = [[self alloc] init];
    settings.enabled = HCGReadBool(store, HCGSettingEnabled, NO);
    settings.handleSide = (HCGHandleSide)HCGReadInteger(store, HCGSettingHandleSide, HCGHandleSideRight);
    settings.handlePosition = HCGReadDouble(store, HCGSettingHandlePosition, kDefaultPosition);
    settings.handleOpacity = HCGReadDouble(store, HCGSettingHandleOpacity, kDefaultOpacity);
    settings.keyboardSafeZone = HCGReadBool(store, HCGSettingKeyboardSafeZone, YES);
    settings.animationsEnabled = HCGReadBool(store, HCGSettingAnimations, YES);
    settings.hapticsEnabled = HCGReadBool(store, HCGSettingHaptics, YES);
    settings.terminalVariant = (HCGTerminalVariant)HCGReadInteger(store, HCGSettingTerminalVariant, HCGTerminalVariantNone);
    settings.newsConnected = HCGReadBool(store, HCGSettingNewsConnected, NO);
    return settings;
}

- (NSDictionary *)dictionaryRepresentation {
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
    [dict setObject:[NSNumber numberWithBool:self.enabled] forKey:HCGSettingEnabled];
    [dict setObject:[NSNumber numberWithInteger:self.handleSide] forKey:HCGSettingHandleSide];
    [dict setObject:[NSNumber numberWithDouble:self.handlePosition] forKey:HCGSettingHandlePosition];
    [dict setObject:[NSNumber numberWithDouble:self.handleOpacity] forKey:HCGSettingHandleOpacity];
    [dict setObject:[NSNumber numberWithBool:self.keyboardSafeZone] forKey:HCGSettingKeyboardSafeZone];
    [dict setObject:[NSNumber numberWithBool:self.animationsEnabled] forKey:HCGSettingAnimations];
    [dict setObject:[NSNumber numberWithBool:self.hapticsEnabled] forKey:HCGSettingHaptics];
    [dict setObject:[NSNumber numberWithInteger:self.terminalVariant] forKey:HCGSettingTerminalVariant];
    [dict setObject:[NSNumber numberWithBool:self.newsConnected] forKey:HCGSettingNewsConnected];
    return dict;
}

- (void)writeToStore:(id<HCGKeyValueStore>)store {
    NSDictionary *dict = [self dictionaryRepresentation];
    NSArray *keys = [dict allKeys];
    NSUInteger i;
    for (i = 0; i < keys.count; i++) {
        NSString *key = [keys objectAtIndex:i];
        [store setObject:[dict objectForKey:key] forKey:key];
    }
    [store flush];
}

@end
