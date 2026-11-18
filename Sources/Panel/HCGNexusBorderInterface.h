#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

// HCG Nexus border interface, version 1 — see docs/HALO-BORDER.md.
//
// A small, in-process interface that lets HCG Halo (a separate package) draw
// its animated border around the live Nexus panel. Nexus itself draws nothing
// here and never depends on Halo: with no observer this costs one empty view
// and a few NSNotificationCenter posts that nobody receives.
//
// Contract (stable within a version):
//   * The class name, +interfaceVersion and the properties below.
//   * HCGNexusBorderEventNotification: posted in-process on the main thread,
//     object = the active interface, userInfo with the keys below. It is never
//     sent across processes and carries no user data.
//   * The installed declarative resource (+borderDefinitionPath) describes the
//     shape, styling anchors and capabilities. The LIVE geometry is always the
//     bounds of borderHostView, never a value from the file.
//
// borderHostView is a dedicated, non-interactive view inside the panel. It has
// the panel's bounds, sits above the panel content, never clips and returns nil
// from hit-testing, so anything added to it follows the panel's real position,
// transform, alpha, resizing and rotation, and can never capture a touch.

#define HCG_NEXUS_BORDER_INTERFACE_VERSION 1

FOUNDATION_EXPORT NSNotificationName const HCGNexusBorderEventNotification;  // "com.hakmicapitalgroup.hcgnexus.border-event"

// userInfo keys
FOUNDATION_EXPORT NSString *const HCGNexusBorderEventKey;           // NSString, one of the events below
FOUNDATION_EXPORT NSString *const HCGNexusBorderGenerationKey;      // NSNumber (unsigned), transition generation
FOUNDATION_EXPORT NSString *const HCGNexusBorderDurationKey;        // NSNumber (seconds), 0 when not animated
FOUNDATION_EXPORT NSString *const HCGNexusBorderInterfaceVersionKey; // NSNumber, HCG_NEXUS_BORDER_INTERFACE_VERSION

// Events
FOUNDATION_EXPORT NSString *const HCGNexusBorderEventInstalled;        // the panel and borderHostView now exist
FOUNDATION_EXPORT NSString *const HCGNexusBorderEventWillOpen;         // opening transition starts (may be reversed)
FOUNDATION_EXPORT NSString *const HCGNexusBorderEventDidOpen;          // opening finished for this generation
FOUNDATION_EXPORT NSString *const HCGNexusBorderEventWillClose;        // closing transition starts (also reverses an opening)
FOUNDATION_EXPORT NSString *const HCGNexusBorderEventDidClose;         // panel hidden (after a close, a lock or a disable)
FOUNDATION_EXPORT NSString *const HCGNexusBorderEventGeometry;         // panel bounds changed (rotation, keyboard, handle side)
FOUNDATION_EXPORT NSString *const HCGNexusBorderEventWorkspaceChanged; // the active workspace changed while the panel is shown
FOUNDATION_EXPORT NSString *const HCGNexusBorderEventRemoved;          // the interface is going away; detach everything

@interface HCGNexusBorderInterface : NSObject

+ (NSInteger)interfaceVersion;

// The live panel's interface, or nil when Nexus has not built its panel (for
// example while Enable HCG Nexus is off since the last respring).
+ (nullable HCGNexusBorderInterface *)activeInterface;

// The installed border-definition resource, located from Nexus's own loaded
// image (the Settings bundle of the same package), or nil if it is missing.
+ (nullable NSString *)borderDefinitionPath;

@property (nonatomic, readonly, copy) NSString *nexusVersion;
@property (nonatomic, readonly, weak, nullable) UIView *borderHostView;
@property (nonatomic, readonly) CGFloat panelCornerRadius;
// "closed", "opening", "open" or "closing".
@property (nonatomic, readonly, copy) NSString *panelState;
@property (nonatomic, readonly) NSUInteger transitionGeneration;
@property (nonatomic, readonly) NSTimeInterval transitionDuration;
// 0…1: how far the panel is presented right now, read from its presentation
// layer, so it follows the real animation including reversals.
@property (nonatomic, readonly) double presentationProgress;
// YES while Nexus replaces sliding with a crossfade (Reduce Motion).
@property (nonatomic, readonly) BOOL reducedMotionTransition;

#pragma mark Nexus-internal (HCGOverlayController only)
- (instancetype)initWithBorderHostView:(UIView *)hostView panelView:(UIView *)panelView cornerRadius:(CGFloat)cornerRadius;
+ (void)setActiveInterface:(nullable HCGNexusBorderInterface *)interface;
- (void)noteTransition:(NSString *)event generation:(NSUInteger)generation duration:(NSTimeInterval)duration reducedMotion:(BOOL)reducedMotion;
- (void)noteEvent:(NSString *)event;
@end

// The view Nexus places inside its panel for decorations. Never interactive.
@interface HCGBorderHostView : UIView
@end

NS_ASSUME_NONNULL_END
