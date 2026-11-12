#import "HCGGeometry.h"
#include <math.h>

const double HCGHandleVisualWidth = 5.0;
const double HCGHandleHitWidth = 30.0;

static const double kVisualLengthPortrait = 72.0;
static const double kVisualLengthLandscape = 56.0;
static const double kHitExtraLength = 24.0;
static const double kTopReserveMin = 56.0;     // status bar + NC/CC pull zone
static const double kBottomReserveMin = 72.0;  // home indicator / app switcher
static const double kReserveFraction = 0.12;
static const double kKeyboardLimitPortrait = 0.50;  // handle stays in top half
static const double kKeyboardLimitLandscape = 0.40;
static const double kLandscapeHomeIndicatorInset = 21.0;
static const double kPanelMargin = 12.0;
static const double kPanelMaxWidth = 400.0;
static const double kPanelMaxHeight = 620.0;
static const double kWideCanvas = 700.0;

BOOL HCGOrientationIsLandscape(HCGInterfaceOrientation orientation) {
    return orientation == HCGInterfaceOrientationLandscapeLeft || orientation == HCGInterfaceOrientationLandscapeRight;
}

double HCGRotationForOrientation(HCGInterfaceOrientation orientation) {
    switch (orientation) {
        case HCGInterfaceOrientationLandscapeRight: return M_PI_2;
        case HCGInterfaceOrientationLandscapeLeft: return -M_PI_2;
        case HCGInterfaceOrientationPortraitUpsideDown: return M_PI;
        case HCGInterfaceOrientationPortrait: return 0.0;
    }
    return 0.0;
}

void HCGCanvasSizeForOrientation(double portraitWidth, double portraitHeight, HCGInterfaceOrientation orientation,
                                 double *outWidth, double *outHeight) {
    double shortSide = fmin(portraitWidth, portraitHeight);
    double longSide = fmax(portraitWidth, portraitHeight);
    if (HCGOrientationIsLandscape(orientation)) {
        if (outWidth) *outWidth = longSide;
        if (outHeight) *outHeight = shortSide;
    } else {
        if (outWidth) *outWidth = shortSide;
        if (outHeight) *outHeight = longSide;
    }
}

HCGInsets HCGSafeAreaForOrientation(HCGInsets portrait, HCGInterfaceOrientation orientation) {
    if (!HCGOrientationIsLandscape(orientation)) return portrait;
    HCGInsets result;
    // A deep top inset means a notch / Dynamic Island; UIKit reports it on both
    // landscape sides. Shallow (status-bar-only) insets disappear in landscape.
    double side = portrait.top > 24.0 ? portrait.top : 0.0;
    result.top = 0.0;
    result.left = side;
    result.right = side;
    result.bottom = portrait.bottom > 0.0 ? fmin(portrait.bottom, kLandscapeHomeIndicatorInset) : 0.0;
    return result;
}

static double Clamp(double value, double lo, double hi) {
    if (value != value) return lo;
    return fmax(lo, fmin(hi, value));
}

HCGHandleFrames HCGComputeHandleFrames(HCGHandleLayoutInput input) {
    HCGHandleFrames frames;
    double w = fmax(0.0, input.canvasWidth);
    double h = fmax(0.0, input.canvasHeight);
    double visualLength = input.landscape ? kVisualLengthLandscape : kVisualLengthPortrait;
    double hitLength = visualLength + kHitExtraLength;

    double top = input.safeArea.top + fmax(kTopReserveMin, h * kReserveFraction);
    double bottom = h - input.safeArea.bottom - fmax(kBottomReserveMin, h * kReserveFraction);
    double centerMin = top + hitLength / 2.0;
    double centerMax = bottom - hitLength / 2.0;
    if (input.keyboardSafeZone) {
        double limit = h * (input.landscape ? kKeyboardLimitLandscape : kKeyboardLimitPortrait) - hitLength / 2.0;
        centerMax = fmin(centerMax, limit);
    }
    if (centerMax < centerMin) centerMax = centerMin;
    double center = centerMin + Clamp(input.position, 0.0, 1.0) * (centerMax - centerMin);

    if (input.side == 1) { // left
        frames.visual.x = input.safeArea.left;
        frames.hit.x = 0.0;
        frames.hit.width = input.safeArea.left + HCGHandleHitWidth;
    } else {               // right
        frames.visual.x = w - input.safeArea.right - HCGHandleVisualWidth;
        frames.hit.x = w - input.safeArea.right - HCGHandleHitWidth;
        frames.hit.width = HCGHandleHitWidth + input.safeArea.right;
    }
    frames.visual.width = HCGHandleVisualWidth;
    frames.visual.height = visualLength;
    frames.visual.y = center - visualLength / 2.0;
    frames.hit.height = hitLength;
    frames.hit.y = center - hitLength / 2.0;
    frames.centerMin = centerMin;
    frames.centerMax = centerMax;
    return frames;
}

HCGRect HCGComputePanelFrame(double canvasWidth, double canvasHeight, HCGInsets safe, NSInteger side, double keyboardOverlap) {
    double availLeft = safe.left + kPanelMargin;
    double availRight = canvasWidth - safe.right - kPanelMargin;
    double availTop = safe.top + kPanelMargin;
    double bottomInset = fmax(safe.bottom, fmax(0.0, keyboardOverlap));
    double availBottom = canvasHeight - bottomInset - kPanelMargin;
    double availWidth = fmax(0.0, availRight - availLeft);
    double availHeight = fmax(0.0, availBottom - availTop);

    HCGRect frame;
    frame.width = fmin(kPanelMaxWidth, availWidth);
    frame.height = fmin(kPanelMaxHeight, availHeight);
    if (canvasWidth >= kWideCanvas) {
        frame.x = (side == 1) ? availLeft : availRight - frame.width;
    } else {
        frame.x = availLeft + (availWidth - frame.width) / 2.0;
    }
    frame.y = availTop + (availHeight - frame.height) / 2.0;
    return frame;
}

BOOL HCGRectContainsPoint(HCGRect rect, double x, double y) {
    return x >= rect.x && x < rect.x + rect.width && y >= rect.y && y < rect.y + rect.height;
}
