#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, HCGPanelState) {
    HCGPanelStateClosed = 0,
    HCGPanelStateOpening = 1,
    HCGPanelStateOpen = 2,
    HCGPanelStateClosing = 3,
};

typedef NS_ENUM(NSInteger, HCGPanelCommand) {
    HCGPanelCommandNone = 0,
    HCGPanelCommandBeginOpen = 1,
    HCGPanelCommandBeginClose = 2,
};

FOUNDATION_EXPORT NSString *HCGPanelStateName(HCGPanelState state);

// Serialises open/close requests so rapid taps, outside taps and lock events
// can never stack animations or leave the panel half-visible. Each Begin*
// command carries a generation; completions from older generations (e.g. an
// animation that finished after a forced close) are ignored.
@interface HCGPanelStateMachine : NSObject {
    HCGPanelState _state;
    BOOL _pendingOpen;
    BOOL _pendingClose;
    NSUInteger _generation;
    NSUInteger _openTransitions;
    NSUInteger _closeTransitions;
    NSUInteger _forcedCloses;
}
@property (nonatomic, readonly) HCGPanelState state;
@property (nonatomic, readonly) NSUInteger generation;
@property (nonatomic, readonly) NSUInteger openTransitions;
@property (nonatomic, readonly) NSUInteger closeTransitions;
@property (nonatomic, readonly) NSUInteger forcedCloses;
@property (nonatomic, readonly) BOOL isPresented; // Opening or Open

- (HCGPanelCommand)requestOpen;
- (HCGPanelCommand)requestClose;
- (HCGPanelCommand)toggle;
- (HCGPanelCommand)transitionDidFinishForGeneration:(NSUInteger)generation;
// Immediate close with no animation (lock, disable). Returns YES if the panel
// was not already closed.
- (BOOL)forceClose;
@end

NS_ASSUME_NONNULL_END
