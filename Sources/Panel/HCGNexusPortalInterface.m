#import "HCGNexusPortalInterface.h"

static HCGNexusPortalInterface *gActive = nil;

@implementation HCGNexusPortalInterface {
    BOOL (^_canOpen)(void);
    void (^_open)(NSString *, HCGNexusPortalOpenCompletion);
}

+ (NSInteger)interfaceVersion {
    return HCG_NEXUS_PORTAL_INTERFACE_VERSION;
}

+ (instancetype)activeInterface {
    return gActive;
}

+ (void)setActiveInterface:(HCGNexusPortalInterface *)interface {
    gActive = interface;
}

- (instancetype)initWithCanOpen:(BOOL (^)(void))canOpen open:(void (^)(NSString *, HCGNexusPortalOpenCompletion))open {
    if ((self = [super init])) {
        _canOpen = [canOpen copy];
        _open = [open copy];
    }
    return self;
}

- (BOOL)canOpenPanel {
    return _canOpen ? _canOpen() : NO;
}

- (void)openPanelFromSource:(NSString *)source completion:(HCGNexusPortalOpenCompletion)completion {
    // Exactly once, on the main thread, whatever happens below.
    __block BOOL answered = NO;
    HCGNexusPortalOpenCompletion once = ^(BOOL opened, NSString *reason) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (answered) return;
            answered = YES;
            if (completion) completion(opened, reason);
        });
    };
    NSString *fixed = [source isKindOfClass:[NSString class]] && source.length <= 32 ? source : @"unknown";
    void (^run)(void) = ^{
        if (!self->_open) {
            once(NO, @"HCG Nexus is not ready.");
            return;
        }
        @try {
            self->_open(fixed, once);
        } @catch (NSException *exception) {
            once(NO, @"HCG Nexus could not open its panel.");
        }
    };
    if ([NSThread isMainThread]) run();
    else dispatch_async(dispatch_get_main_queue(), run);
}

@end
