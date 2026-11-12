#import "HCGPreferencesKeyValueStore.h"
#import "HCGConstants.h"

@implementation HCGPreferencesKeyValueStore {
    CFStringRef _domain;
}

- (instancetype)initWithDomain:(NSString *)domain {
    if ((self = [super init])) {
        _domain = (CFStringRef)CFBridgingRetain([domain copy]);
    }
    return self;
}

- (void)dealloc {
    if (_domain) CFRelease(_domain);
}

- (id)objectForKey:(NSString *)key {
    return CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)key, _domain));
}

- (void)setObject:(id)object forKey:(NSString *)key {
    CFPreferencesSetAppValue((__bridge CFStringRef)key, (__bridge CFPropertyListRef)object, _domain);
}

- (void)reload {
    CFPreferencesAppSynchronize(_domain);
}

- (BOOL)flush {
    return CFPreferencesAppSynchronize(_domain) ? YES : NO;
}

@end

@implementation HCGDarwinNotifier

static void HCGPostDarwin(NSString *name) {
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), (__bridge CFStringRef)name, NULL, NULL, true);
}

- (void)postSettingsChanged {
    HCGPostDarwin(HCGNexusSettingsChangedDarwinNotification);
}

- (void)postWorkspacesChanged {
    HCGPostDarwin(HCGNexusWorkspacesChangedDarwinNotification);
}

@end
