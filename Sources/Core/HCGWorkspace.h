#import <Foundation/Foundation.h>
#import "HCGAction.h"

NS_ASSUME_NONNULL_BEGIN

// Preset kinds only describe how a workspace was seeded. They organise
// shortcuts; they do not change notification policy, app state or permissions.
FOUNDATION_EXPORT NSString *const HCGPresetCommand;
FOUNDATION_EXPORT NSString *const HCGPresetDeveloper;
FOUNDATION_EXPORT NSString *const HCGPresetStudio;
FOUNDATION_EXPORT NSString *const HCGPresetInfrastructure;
FOUNDATION_EXPORT NSString *const HCGPresetCustom;

@interface HCGWorkspace : NSObject <NSCopying> {
    NSString *_identifier;
    NSString *_name;
    NSString *_preset;
    NSMutableArray *_mutableActions;
}
@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *preset;
@property (nonatomic, readonly) NSArray<HCGAction *> *actions;

- (instancetype)initWithName:(NSString *)name preset:(NSString *)preset;

- (void)replaceActions:(NSArray<HCGAction *> *)actions;
- (void)appendAction:(HCGAction *)action;
- (void)insertAction:(HCGAction *)action atIndex:(NSUInteger)index;
- (void)removeActionAtIndex:(NSUInteger)index;
- (void)moveActionFromIndex:(NSUInteger)from toIndex:(NSUInteger)to;
- (nullable HCGAction *)actionWithIdentifier:(NSString *)identifier;
- (NSUInteger)indexOfActionWithIdentifier:(NSString *)identifier;

// Lenient decode: invalid shortcuts are dropped and counted in *droppedActions.
+ (nullable instancetype)workspaceFromDictionary:(NSDictionary *)dictionary droppedActions:(NSUInteger *_Nullable)droppedActions;
- (NSDictionary *)dictionaryRepresentation;
@end

NS_ASSUME_NONNULL_END
