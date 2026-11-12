#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, HCGTriState) {
    HCGTriStateUnknown = -1,
    HCGTriStateNo = 0,
    HCGTriStateYes = 1,
};

// Signals gathered by the platform layer (SpringBoard lock monitor or the
// preview harness' simulated controls).
typedef struct {
    HCGTriState deviceLocked;       // com.apple.springboard.lockstate / SBLockScreenManager
    HCGTriState coverSheetVisible;  // lock screen / Notification Centre cover sheet
    HCGTriState screenBlanked;      // display off
} HCGSystemSignals;

typedef struct {
    BOOL overlayVisible;   // window + handle shown and hit-testable
    BOOL panelAllowed;     // panel may be opened
    BOOL mustForceClose;   // an open panel must close immediately (no animation)
} HCGOverlayDecision;

FOUNDATION_EXPORT HCGSystemSignals HCGSystemSignalsUnknown(void);

// Fail-closed policy:
//   * disabled                       -> hidden, never intercepts touches
//   * locked or lock state unknown   -> hidden
//   * cover sheet visible / screen off -> hidden
// An unknown cover-sheet state does not block (reported as degraded in
// diagnostics) because the lock-state signal remains authoritative.
FOUNDATION_EXPORT HCGOverlayDecision HCGDecideOverlay(BOOL enabled, HCGSystemSignals signals, BOOL panelPresented);

// Human-readable reason for diagnostics.
FOUNDATION_EXPORT NSString *HCGOverlayReason(BOOL enabled, HCGSystemSignals signals);
FOUNDATION_EXPORT NSString *HCGTriStateName(HCGTriState state);
