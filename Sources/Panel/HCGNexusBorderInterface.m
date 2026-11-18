#import "HCGNexusBorderInterface.h"
#import "HCGConstants.h"
#include <dlfcn.h>

NSNotificationName const HCGNexusBorderEventNotification = @"com.hakmicapitalgroup.hcgnexus.border-event";
NSString *const HCGNexusBorderEventKey = @"event";
NSString *const HCGNexusBorderGenerationKey = @"generation";
NSString *const HCGNexusBorderDurationKey = @"duration";
NSString *const HCGNexusBorderInterfaceVersionKey = @"interfaceVersion";

NSString *const HCGNexusBorderEventInstalled = @"installed";
NSString *const HCGNexusBorderEventWillOpen = @"will-open";
NSString *const HCGNexusBorderEventDidOpen = @"did-open";
NSString *const HCGNexusBorderEventWillClose = @"will-close";
NSString *const HCGNexusBorderEventDidClose = @"did-close";
NSString *const HCGNexusBorderEventGeometry = @"geometry";
NSString *const HCGNexusBorderEventWorkspaceChanged = @"workspace-changed";
NSString *const HCGNexusBorderEventRemoved = @"removed";

static NSString *const kHCGBorderDefinitionName = @"HaloBorder.plist";
static NSString *const kHCGPrefsBundleRelative = @"Library/PreferenceBundles/HCGNexusPrefs.bundle";

@implementation HCGBorderHostView

- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.userInteractionEnabled = NO;
        self.backgroundColor = [UIColor clearColor];
        self.opaque = NO;
        self.clipsToBounds = NO;
        self.isAccessibilityElement = NO;
        self.accessibilityElementsHidden = YES;
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    }
    return self;
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    return nil;
}

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    return NO;
}

@end

static __weak HCGNexusBorderInterface *gActiveInterface;

@implementation HCGNexusBorderInterface {
    __weak UIView *_hostView;
    __weak UIView *_panelView;
    CGFloat _cornerRadius;
    NSString *_state;
    NSUInteger _generation;
    NSTimeInterval _duration;
    BOOL _reducedMotion;
}

+ (NSInteger)interfaceVersion {
    return HCG_NEXUS_BORDER_INTERFACE_VERSION;
}

+ (HCGNexusBorderInterface *)activeInterface {
    return gActiveInterface;
}

+ (void)setActiveInterface:(HCGNexusBorderInterface *)interface {
    HCGNexusBorderInterface *previous = gActiveInterface;
    if (previous == interface) return;
    gActiveInterface = interface;
    if (previous) [previous noteEvent:HCGNexusBorderEventRemoved];
    if (interface) [interface noteEvent:HCGNexusBorderEventInstalled];
}

// Locates the resource from where THIS code was loaded, so no install prefix is
// assumed. The tweak loads from <jbroot>/Library/MobileSubstrate/DynamicLibraries
// (on Dopamine that directory links to <jbroot>/usr/lib/TweakInject, and dyld
// may report either path); the Settings bundle loads from
// <jbroot>/Library/PreferenceBundles/HCGNexusPrefs.bundle. Builds that carry
// the file in their own bundle (preview harness) are found last.
+ (NSString *)borderDefinitionPath {
    NSFileManager *fm = [NSFileManager defaultManager];
    Dl_info info;
    if (dladdr((const void *)&HCGNexusBorderEventNotification, &info) && info.dli_fname) {
        NSString *image = [NSString stringWithUTF8String:info.dli_fname];
        for (NSString *suffix in @[ @"/Library/MobileSubstrate/DynamicLibraries/HCGNexus.dylib",
                                    @"/usr/lib/TweakInject/HCGNexus.dylib",
                                    @"/Library/PreferenceBundles/HCGNexusPrefs.bundle/HCGNexusPrefs" ]) {
            if (![image hasSuffix:suffix]) continue;
            NSString *root = [image substringToIndex:image.length - suffix.length];
            NSString *candidate = [[root stringByAppendingPathComponent:kHCGPrefsBundleRelative]
                stringByAppendingPathComponent:kHCGBorderDefinitionName];
            if ([fm fileExistsAtPath:candidate]) return candidate;
        }
    }
    NSString *bundled = [[NSBundle mainBundle] pathForResource:@"HaloBorder" ofType:@"plist"];
    if (bundled && [fm fileExistsAtPath:bundled]) return bundled;
    return nil;
}

- (instancetype)initWithBorderHostView:(UIView *)hostView panelView:(UIView *)panelView cornerRadius:(CGFloat)cornerRadius {
    if ((self = [super init])) {
        _hostView = hostView;
        _panelView = panelView;
        _cornerRadius = cornerRadius;
        _state = @"closed";
    }
    return self;
}

- (NSString *)nexusVersion {
    return HCG_NEXUS_VERSION;
}

- (UIView *)borderHostView {
    return _hostView;
}

- (CGFloat)panelCornerRadius {
    return _cornerRadius;
}

- (NSString *)panelState {
    return _state;
}

- (NSUInteger)transitionGeneration {
    return _generation;
}

- (NSTimeInterval)transitionDuration {
    return _duration;
}

- (BOOL)reducedMotionTransition {
    return _reducedMotion;
}

- (double)presentationProgress {
    UIView *panel = _panelView;
    if (!panel || panel.hidden) return 0;
    CALayer *layer = panel.layer.presentationLayer ?: panel.layer;
    double opacity = layer.opacity;
    return opacity < 0 ? 0 : (opacity > 1 ? 1 : opacity);
}

- (void)noteTransition:(NSString *)event generation:(NSUInteger)generation duration:(NSTimeInterval)duration reducedMotion:(BOOL)reducedMotion {
    _generation = generation;
    _duration = duration;
    _reducedMotion = reducedMotion;
    if ([event isEqualToString:HCGNexusBorderEventWillOpen]) _state = @"opening";
    else if ([event isEqualToString:HCGNexusBorderEventDidOpen]) _state = @"open";
    else if ([event isEqualToString:HCGNexusBorderEventWillClose]) _state = @"closing";
    else if ([event isEqualToString:HCGNexusBorderEventDidClose]) _state = @"closed";
    [self noteEvent:event];
}

- (void)noteEvent:(NSString *)event {
    if ([event isEqualToString:HCGNexusBorderEventDidClose]) _state = @"closed";
    NSDictionary *info = @{
        HCGNexusBorderEventKey : event,
        HCGNexusBorderGenerationKey : @(_generation),
        HCGNexusBorderDurationKey : @(_duration),
        HCGNexusBorderInterfaceVersionKey : @(HCG_NEXUS_BORDER_INTERFACE_VERSION),
    };
    [[NSNotificationCenter defaultCenter] postNotificationName:HCGNexusBorderEventNotification object:self userInfo:info];
}

@end
