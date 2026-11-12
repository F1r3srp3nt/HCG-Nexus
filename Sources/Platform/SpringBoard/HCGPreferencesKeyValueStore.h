#import <Foundation/Foundation.h>
#import "HCGKeyValueStore.h"
#import "HCGLauncher.h"

NS_ASSUME_NONNULL_BEGIN

// CFPreferences-backed store for the HCG Nexus domain (as the mobile user,
// /var/mobile/Library/Preferences/com.hakmicapitalgroup.hcgnexus.plist via
// cfprefsd). Shared by SpringBoard and the Settings bundle on rootless and
// rootful layouts alike.
@interface HCGPreferencesKeyValueStore : NSObject <HCGKeyValueStore>
- (instancetype)initWithDomain:(NSString *)domain;
@end

// Darwin-notification change broadcaster (cross-process).
@interface HCGDarwinNotifier : NSObject <HCGChangeNotifier>
@end

NS_ASSUME_NONNULL_END
