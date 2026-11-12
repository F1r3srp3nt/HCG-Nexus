#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, HCGActionKind) {
    HCGActionKindApp = 0,          // target = bundle identifier
    HCGActionKindURL = 1,          // target = absolute URL with a scheme
    HCGActionKindIntegration = 2,  // target = HCG integration identifier
};

FOUNDATION_EXPORT NSString *HCGActionKindName(HCGActionKind kind);

// A user-configured shortcut. Plist-serialisable via -dictionaryRepresentation.
@interface HCGAction : NSObject <NSCopying> {
    NSString *_identifier;
    NSString *_title;
    HCGActionKind _kind;
    NSString *_target;
    NSString *_symbolName;
}
@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, copy) NSString *title;
@property (nonatomic) HCGActionKind kind;
@property (nonatomic, copy) NSString *target;
// SF Symbol name used by the UI. Optional; the UI falls back per kind.
@property (nonatomic, copy, nullable) NSString *symbolName;

+ (instancetype)actionWithKind:(HCGActionKind)kind
                         title:(NSString *)title
                        target:(NSString *)target
                        symbol:(nullable NSString *)symbol;

// Returns nil (and sets *error) when the dictionary is malformed or invalid.
+ (nullable instancetype)actionFromDictionary:(NSDictionary *)dictionary error:(NSError *_Nullable *_Nullable)error;
- (NSDictionary *)dictionaryRepresentation;

// Validates title and target for the given kind. Returns nil when valid,
// otherwise an error with an actionable message.
+ (nullable NSError *)validationErrorForKind:(HCGActionKind)kind
                                       title:(NSString *)title
                                      target:(NSString *)target;

+ (BOOL)isPlausibleBundleIdentifier:(NSString *)candidate;
@end

NS_ASSUME_NONNULL_END
