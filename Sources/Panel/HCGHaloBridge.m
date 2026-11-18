#import "HCGHaloBridge.h"
#import "HCGConstants.h"
#import "HCGNexusBorderInterface.h"
#import <CoreFoundation/CoreFoundation.h>
#import <dlfcn.h>
#import <objc/message.h>

static NSString *const kHaloDylibRelative = @"Library/MobileSubstrate/DynamicLibraries/HCGHalo.dylib";
static NSString *const kHaloDylibRelativeTweakInject = @"usr/lib/TweakInject/HCGHalo.dylib";
static NSString *const kPreferenceBundlesRelative = @"Library/PreferenceBundles";

@implementation HCGHaloBridge

+ (NSString *)jailbreakRoot {
    Dl_info info;
    if (!dladdr((const void *)&HCGNexusBorderEventNotification, &info) || !info.dli_fname) return nil;
    NSString *image = [NSString stringWithUTF8String:info.dli_fname];
    for (NSString *suffix in @[ @"/Library/MobileSubstrate/DynamicLibraries/HCGNexus.dylib",
                                @"/usr/lib/TweakInject/HCGNexus.dylib",
                                @"/Library/PreferenceBundles/HCGNexusPrefs.bundle/HCGNexusPrefs" ]) {
        if ([image hasSuffix:suffix]) return [image substringToIndex:image.length - suffix.length];
    }
    return nil;
}

+ (NSString *)haloPrefsBundlePathInRoot:(NSString *)root {
    return [[root stringByAppendingPathComponent:kPreferenceBundlesRelative] stringByAppendingPathComponent:HCGHaloPrefsBundleName];
}

static id HCGCopyPreference(NSString *key, NSString *domain) {
    return CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)key, (__bridge CFStringRef)domain));
}

static NSInteger HCGIntegerValue(id value) {
    return [value isKindOfClass:[NSNumber class]] ? [value integerValue] : 0;
}

+ (NSString *)definitionProblem {
    NSString *path = [HCGNexusBorderInterface borderDefinitionPath];
    if (!path) return @"HaloBorder.plist is missing from HCG Nexus's Settings bundle";
    NSDictionary *d = [NSDictionary dictionaryWithContentsOfFile:path];
    if (![d isKindOfClass:[NSDictionary class]]) return @"HaloBorder.plist cannot be read";
    if (HCGIntegerValue(d[@"interfaceVersion"]) != HCG_NEXUS_BORDER_INTERFACE_VERSION) return @"HaloBorder.plist has another interface version";
    if (![d[@"nexusVersion"] isEqual:HCG_NEXUS_VERSION]) return @"HaloBorder.plist belongs to another HCG Nexus version; respring after updating";
    return nil;
}

+ (HCGHaloBorderFacts *)factsWithBorderAttached:(BOOL)attached panelVisible:(BOOL)visible {
    HCGHaloBorderFacts *facts = [[HCGHaloBorderFacts alloc] init];
    facts.borderAttached = attached;
    facts.panelVisible = visible;
    NSString *root = [self jailbreakRoot];
    if (!root) return facts; // not the jailbreak package: Halo does not apply

    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *bundle = [self haloPrefsBundlePathInRoot:root];
    NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:[bundle stringByAppendingPathComponent:@"Info.plist"]];
    BOOL dylib = [fm fileExistsAtPath:[root stringByAppendingPathComponent:kHaloDylibRelative]] ||
                 [fm fileExistsAtPath:[root stringByAppendingPathComponent:kHaloDylibRelativeTweakInject]];
    facts.haloInstalled = [info isKindOfClass:[NSDictionary class]] || dylib;
    if (!facts.haloInstalled) return facts;
    if ([info isKindOfClass:[NSDictionary class]]) {
        id version = info[@"CFBundleShortVersionString"];
        if ([version isKindOfClass:[NSString class]]) facts.haloVersion = version;
        facts.integrationVersion = HCGIntegerValue(info[HCGHaloIntegrationInfoKey]);
        facts.controlVersion = HCGIntegerValue(info[HCGHaloControlInfoKey]);
    }
    facts.definitionProblem = [self definitionProblem];

    CFPreferencesAppSynchronize((__bridge CFStringRef)HCGHaloSettingsDomain);
    NSMutableDictionary *prefs = [NSMutableDictionary dictionary];
    id enabled = HCGCopyPreference(HCGHaloKeyEnabled, HCGHaloSettingsDomain);
    id target = HCGCopyPreference(HCGHaloKeyTarget, HCGHaloSettingsDomain);
    if (enabled) prefs[HCGHaloKeyEnabled] = enabled;
    if (target) prefs[HCGHaloKeyTarget] = target;
    facts.haloPreferences = prefs;

    CFPreferencesAppSynchronize((__bridge CFStringRef)HCGHaloStatusDomain);
    id status = HCGCopyPreference(HCGHaloStatusRecordKey, HCGHaloStatusDomain);
    if ([status isKindOfClass:[NSDictionary class]]) facts.haloStatus = status;
    return facts;
}

+ (HCGHaloBorderStatus *)statusWithBorderAttached:(BOOL)attached panelVisible:(BOOL)visible {
    return [HCGHaloBorderStatus statusWithFacts:[self factsWithBorderAttached:attached panelVisible:visible]];
}

// HaloNexusControl lives in HCG Halo's SpringBoard dylib and in its Settings bundle. In Settings the bundle
// may need loading (as for Halo's border page); SpringBoard never loads a Settings bundle.
+ (Class)controlClass {
    Class cls = NSClassFromString(HCGHaloControlClassName);
    if (cls) return cls;
    if (!NSClassFromString(@"PSListController")) return Nil; // not the Settings app
    NSString *root = [self jailbreakRoot];
    if (!root) return Nil;
    NSBundle *bundle = [NSBundle bundleWithPath:[self haloPrefsBundlePathInRoot:root]];
    if (![bundle isLoaded] && ![bundle loadAndReturnError:NULL]) return Nil;
    return NSClassFromString(HCGHaloControlClassName);
}

+ (BOOL)setPanelBorderEnabled:(BOOL)enabled error:(NSString **)error {
    HCGHaloBorderFacts *facts = [self factsWithBorderAttached:NO panelVisible:NO];
    if (!facts.haloInstalled) {
        if (error) *error = @"HCG Halo is not installed.";
        return NO;
    }
    Class cls = [self controlClass];
    SEL versionSel = NSSelectorFromString(@"controlVersion");
    SEL setSel = NSSelectorFromString(@"setNexusBorderEnabled:error:");
    if (!cls || ![cls respondsToSelector:versionSel] || ![cls respondsToSelector:setSel]) {
        if (error) *error = @"This HCG Halo has no switch for the Nexus border. Use HCG Halo › Border Target, or update HCG Halo.";
        return NO;
    }
    NSInteger version = ((NSInteger (*)(id, SEL))objc_msgSend)(cls, versionSel);
    if (version != HCGHaloSupportedControlVersion) {
        if (error) *error = [NSString stringWithFormat:@"HCG Halo's switch interface is version %ld; this HCG Nexus understands version %ld.",
                                                       (long)version, (long)HCGHaloSupportedControlVersion];
        return NO;
    }
    NSString *reason = nil;
    BOOL ok = ((BOOL (*)(id, SEL, BOOL, NSString *__autoreleasing *))objc_msgSend)(cls, setSel, enabled, &reason);
    if (!ok && error) *error = [reason isKindOfClass:[NSString class]] && reason.length ? reason : @"HCG Halo refused the change.";
    [self requestHaloStatus];
    return ok;
}

+ (void)requestHaloStatus {
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                         (__bridge CFStringRef)HCGHaloStatusRequestNotification, NULL, NULL, true);
}

@end
