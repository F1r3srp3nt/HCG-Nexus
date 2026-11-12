#import <Foundation/Foundation.h>

// Pure layout maths for the handle and panel. Uses plain doubles so it can be
// exercised by host tests without CoreGraphics/UIKit.

typedef struct {
    double x, y, width, height;
} HCGRect;

typedef struct {
    double top, left, bottom, right;
} HCGInsets;

// Raw values match UIInterfaceOrientation.
typedef NS_ENUM(NSInteger, HCGInterfaceOrientation) {
    HCGInterfaceOrientationPortrait = 1,
    HCGInterfaceOrientationPortraitUpsideDown = 2,
    HCGInterfaceOrientationLandscapeRight = 3,
    HCGInterfaceOrientationLandscapeLeft = 4,
};

typedef struct {
    double canvasWidth;
    double canvasHeight;
    HCGInsets safeArea;
    NSInteger side;          // HCGHandleSide (0 right, 1 left)
    double position;         // 0…1 inside the allowed band
    BOOL keyboardSafeZone;
    BOOL landscape;
} HCGHandleLayoutInput;

typedef struct {
    HCGRect visual;          // the thin illuminated sliver
    HCGRect hit;             // touch target (>= 44pt long, ~30pt wide)
    double centerMin;        // allowed range of the handle centre (y)
    double centerMax;
} HCGHandleFrames;

FOUNDATION_EXPORT const double HCGHandleVisualWidth;
FOUNDATION_EXPORT const double HCGHandleHitWidth;

FOUNDATION_EXPORT BOOL HCGOrientationIsLandscape(HCGInterfaceOrientation orientation);

// Rotation (radians) applied to a portrait-fixed SpringBoard canvas so its
// content appears upright for the given interface orientation.
FOUNDATION_EXPORT double HCGRotationForOrientation(HCGInterfaceOrientation orientation);

// Canvas size for a portrait screen size in the given orientation.
FOUNDATION_EXPORT void HCGCanvasSizeForOrientation(double portraitWidth, double portraitHeight,
                                                   HCGInterfaceOrientation orientation,
                                                   double *outWidth, double *outHeight);

// Approximates UIKit's landscape safe area from the portrait one on iPhone:
// notch/island depth becomes symmetric side insets and the home-indicator
// inset shrinks to 21pt. Portrait (and upside-down) are returned unchanged.
FOUNDATION_EXPORT HCGInsets HCGSafeAreaForOrientation(HCGInsets portraitInsets, HCGInterfaceOrientation orientation);

// Keeps the handle away from the status bar / Notification & Control Centre
// pull zones at the top and the home indicator at the bottom, and optionally
// above the typical keyboard area.
FOUNDATION_EXPORT HCGHandleFrames HCGComputeHandleFrames(HCGHandleLayoutInput input);

// Panel frame inside the safe area, above any keyboard overlap (in canvas points
// measured from the bottom edge).
FOUNDATION_EXPORT HCGRect HCGComputePanelFrame(double canvasWidth, double canvasHeight,
                                               HCGInsets safeArea, NSInteger side,
                                               double keyboardOverlap);

FOUNDATION_EXPORT BOOL HCGRectContainsPoint(HCGRect rect, double x, double y);
