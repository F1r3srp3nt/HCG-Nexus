#import <Foundation/Foundation.h>
#import "HCGKeyValueStore.h"
#import "HCGAction.h"

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString *const HCGStoreKeyRecents;
FOUNDATION_EXPORT const NSUInteger HCGMaxRecents;

@interface HCGRecentEntry : NSObject {
    HCGAction *_action;
    NSDate *_date;
    BOOL _succeeded;
    NSString *_message;
}
@property (nonatomic, copy) HCGAction *action;
@property (nonatomic, copy) NSDate *date;
@property (nonatomic) BOOL succeeded;
@property (nonatomic, copy, nullable) NSString *message; // error summary when !succeeded
@end

// Bounded most-recent-first list. Re-running an action moves it to the front.
@interface HCGRecents : NSObject {
    id<HCGKeyValueStore> _backingStore;
    NSMutableArray *_entries;
}
@property (nonatomic, readonly) NSArray<HCGRecentEntry *> *entries;
- (instancetype)initWithStore:(id<HCGKeyValueStore>)store;
- (void)load;
- (void)recordAction:(HCGAction *)action succeeded:(BOOL)succeeded message:(nullable NSString *)message date:(NSDate *)date;
- (void)clear;
@end

NS_ASSUME_NONNULL_END
