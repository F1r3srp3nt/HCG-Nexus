#import "HCGEcosystemScanner.h"
#import "HCGHaloBridge.h"
#import "HCGTrustRecords.h"
#import <CoreFoundation/CoreFoundation.h>
#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <sys/sysctl.h>

static const unsigned long long kMaxListBytes = 16ull * 1024 * 1024;
static const NSTimeInterval kCacheSeconds = 4.0;

static NSString *HCGJailbreakRoot(void) {
    NSString *root = [HCGHaloBridge jailbreakRoot];
    if (root.length) return root;
    BOOL isDirectory = NO;
    if ([[NSFileManager defaultManager] fileExistsAtPath:@"/var/jb" isDirectory:&isDirectory] && isDirectory) return @"/var/jb";
    return @"";
}

static NSString *HCGReadText(NSString *path) {
    NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:NULL];
    if (!attributes || [attributes fileSize] > kMaxListBytes) return nil;
    NSData *data = [NSData dataWithContentsOfFile:path options:NSDataReadingMappedIfSafe error:NULL];
    if (!data) return nil;
    NSString *text = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    return text ?: [[NSString alloc] initWithData:data encoding:NSISOLatin1StringEncoding];
}

static id HCGCopyPreference(NSString *key, NSString *domain) {
    return CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)key, (__bridge CFStringRef)domain));
}

#pragma mark LaunchServices (private, every selector checked)

static id HCGWorkspace(void) {
    Class cls = NSClassFromString(@"LSApplicationWorkspace");
    SEL sel = NSSelectorFromString(@"defaultWorkspace");
    if (![cls respondsToSelector:sel]) return nil;
    return ((id (*)(id, SEL))objc_msgSend)(cls, sel);
}

static BOOL HCGAppInstalled(id workspace, NSString *bundle) {
    SEL sel = NSSelectorFromString(@"applicationIsInstalled:");
    if (!workspace || !bundle.length || ![workspace respondsToSelector:sel]) return NO;
    return ((BOOL (*)(id, SEL, id))objc_msgSend)(workspace, sel, bundle);
}

static id HCGProxy(NSString *bundle) {
    Class cls = NSClassFromString(@"LSApplicationProxy");
    SEL sel = NSSelectorFromString(@"applicationProxyForIdentifier:");
    if (![cls respondsToSelector:sel]) return nil;
    return ((id (*)(id, SEL, id))objc_msgSend)(cls, sel, bundle);
}

static NSString *HCGProxyString(id proxy, NSString *selectorName) {
    SEL sel = NSSelectorFromString(selectorName);
    if (![proxy respondsToSelector:sel]) return nil;
    id value = ((id (*)(id, SEL))objc_msgSend)(proxy, sel);
    return [value isKindOfClass:[NSString class]] && [value length] ? value : nil;
}

static NSDictionary *HCGAppInfo(id proxy) {
    SEL sel = NSSelectorFromString(@"bundleURL");
    if (![proxy respondsToSelector:sel]) return nil;
    id url = ((id (*)(id, SEL))objc_msgSend)(proxy, sel);
    if (![url isKindOfClass:[NSURL class]]) return nil;
    NSDictionary *info = [NSDictionary dictionaryWithContentsOfURL:[url URLByAppendingPathComponent:@"Info.plist"]];
    return [info isKindOfClass:[NSDictionary class]] ? info : nil;
}

static NSArray *HCGDeclaredSchemes(NSDictionary *info) {
    NSMutableArray *schemes = [NSMutableArray array];
    id types = [info objectForKey:@"CFBundleURLTypes"];
    for (id type in [types isKindOfClass:[NSArray class]] ? types : @[]) {
        id list = [type isKindOfClass:[NSDictionary class]] ? [type objectForKey:@"CFBundleURLSchemes"] : nil;
        for (id scheme in [list isKindOfClass:[NSArray class]] ? list : @[]) {
            if ([scheme isKindOfClass:[NSString class]]) [schemes addObject:scheme];
        }
    }
    return schemes;
}

@implementation HCGEcosystemScanner

static NSArray *gCachedFacts = nil;
static NSDate *gCachedAt = nil;
static BOOL gCachedLaunch = NO;

+ (void)invalidateCache {
    @synchronized(self) {
        gCachedFacts = nil;
        gCachedAt = nil;
    }
}

+ (NSArray *)packageManagersWithWorkspace:(id)workspace {
    NSMutableArray *managers = [NSMutableArray array];
    if (HCGAppInstalled(workspace, @"xyz.willy.Zebra")) [managers addObject:@"zebra"];
    if (HCGAppInstalled(workspace, @"org.coolstar.SileoStore") || HCGAppInstalled(workspace, @"org.coolstar.SileoNightly")) [managers addObject:@"sileo"];
    return managers;
}

+ (NSArray *)hcgRepoListTextsWithRoot:(NSString *)root {
    NSMutableArray *texts = [NSMutableArray array];
    NSArray *folders = @[ [root stringByAppendingPathComponent:@"var/lib/apt/lists"],
                          @"/var/mobile/Library/Application Support/xyz.willy.Zebra/lists" ];
    NSFileManager *fm = [NSFileManager defaultManager];
    for (NSString *folder in folders) {
        for (NSString *name in [fm contentsOfDirectoryAtPath:folder error:NULL] ?: @[]) {
            if (![HCGPackageIndex isHCGRepoListFileName:name]) continue;
            NSString *text = HCGReadText([folder stringByAppendingPathComponent:name]);
            if (text.length) [texts addObject:text];
        }
    }
    return texts;
}

+ (NSArray *)factsCanLaunchApps:(BOOL)canLaunchApps {
    @synchronized(self) {
        if (gCachedFacts && gCachedLaunch == canLaunchApps && gCachedAt && -[gCachedAt timeIntervalSinceNow] < kCacheSeconds) return gCachedFacts;
    }
    NSString *root = HCGJailbreakRoot();
    NSSet *packages = [HCGInterchange packageIdentifiers];
    NSDictionary *installed = [HCGPackageIndex installedVersionsFromStatusText:HCGReadText([root stringByAppendingPathComponent:@"var/lib/dpkg/status"])
                                                                      packages:packages];
    NSDictionary *offered = [HCGPackageIndex highestVersionsFromIndexTexts:[self hcgRepoListTextsWithRoot:root]
                                                                  packages:packages
                                                             architectures:[NSSet setWithObject:root.length ? @"iphoneos-arm64" : @"iphoneos-arm"]];
    id workspace = HCGWorkspace();
    NSArray *managers = [self packageManagersWithWorkspace:workspace];
    NSString *os = [[UIDevice currentDevice] systemVersion];
    NSString *bundles = [root stringByAppendingPathComponent:@"Library/PreferenceBundles"];
    NSFileManager *fm = [NSFileManager defaultManager];

    NSMutableArray *all = [NSMutableArray array];
    for (HCGHIPProductDescriptor *d in [HCGInterchange registry]) {
        HCGHIPFacts *f = [[HCGHIPFacts alloc] init];
        f.productID = d.productID;
        f.hostCanInspect = YES;
        f.hostCanLaunchApps = canLaunchApps;
        f.osVersion = os;
        f.packageManagers = managers;
        if (d.packageIdentifier) {
            f.packageVersion = [installed objectForKey:d.packageIdentifier];
            f.offeredVersion = [offered objectForKey:d.packageIdentifier];
        }
        if (d.bundleIdentifier.length && HCGAppInstalled(workspace, d.bundleIdentifier)) {
            f.appInstalled = YES;
            id proxy = HCGProxy(d.bundleIdentifier);
            NSDictionary *info = HCGAppInfo(proxy);
            f.appVersion = HCGProxyString(proxy, @"shortVersionString") ?: [info objectForKey:@"CFBundleShortVersionString"];
            f.appBuild = HCGProxyString(proxy, @"bundleVersion") ?: [info objectForKey:@"CFBundleVersion"];
            f.declaredSchemes = HCGDeclaredSchemes(info);
            f.declaration = [info objectForKey:HCGInterchangeInfoKey];
        }
        if (d.settingsBundleName.length) {
            NSString *infoPath = [[bundles stringByAppendingPathComponent:d.settingsBundleName] stringByAppendingPathComponent:@"Info.plist"];
            f.settingsBundlePresent = [fm fileExistsAtPath:infoPath];
            if (f.settingsBundlePresent && !f.declaration) {
                NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:infoPath];
                f.declaration = [info isKindOfClass:[NSDictionary class]] ? [info objectForKey:HCGInterchangeInfoKey] : nil;
            }
        }
        if (d.preferenceDomain.length && f.installed) {
            CFPreferencesAppSynchronize((__bridge CFStringRef)d.preferenceDomain);
            NSMutableDictionary *prefs = [NSMutableDictionary dictionary];
            NSMutableArray *keys = [NSMutableArray array];
            for (HCGHIPReadout *readout in d.readouts) [keys addObject:readout.key];
            if (d.enabledKey) [keys addObject:d.enabledKey];
            for (NSString *key in keys) {
                id value = HCGCopyPreference(key, d.preferenceDomain);
                if (value) [prefs setObject:value forKey:key];
            }
            f.preferences = prefs;
        }
        if (d.statusDomain.length && f.installed) {
            CFPreferencesAppSynchronize((__bridge CFStringRef)d.statusDomain);
            NSMutableDictionary *record = [NSMutableDictionary dictionary];
            NSArray *keys = d.statusRecordKey.length ? @[ d.statusRecordKey ] : @[ @"state", @"detail" ];
            for (NSString *key in keys) {
                id value = HCGCopyPreference(key, d.statusDomain);
                if (value) [record setObject:value forKey:key];
            }
            f.statusRecord = record;
        }
        [all addObject:f];
    }
    @synchronized(self) {
        gCachedFacts = [all copy];
        gCachedAt = [NSDate date];
        gCachedLaunch = canLaunchApps;
    }
    return all;
}

static NSString *HCGMachine(void) {
    size_t size = 0;
    if (sysctlbyname("hw.machine", NULL, &size, NULL, 0) != 0 || size == 0 || size > 64) return nil;
    char buffer[64] = { 0 };
    if (sysctlbyname("hw.machine", buffer, &size, NULL, 0) != 0) return nil;
    return [NSString stringWithUTF8String:buffer];
}

static NSString *HCGModelName(NSString *machine) {
    NSDictionary *names = @{ @"iPhone12,1" : @"iPhone 11", @"iPhone12,3" : @"iPhone 11 Pro", @"iPhone12,5" : @"iPhone 11 Pro Max",
                             @"iPhone13,1" : @"iPhone 12 mini", @"iPhone13,2" : @"iPhone 12", @"iPhone13,3" : @"iPhone 12 Pro",
                             @"iPhone13,4" : @"iPhone 12 Pro Max", @"iPhone14,4" : @"iPhone 13 mini", @"iPhone14,5" : @"iPhone 13",
                             @"iPhone14,2" : @"iPhone 13 Pro", @"iPhone14,3" : @"iPhone 13 Pro Max", @"iPhone14,6" : @"iPhone SE (3rd generation)",
                             @"iPhone14,7" : @"iPhone 14", @"iPhone14,8" : @"iPhone 14 Plus", @"iPhone15,2" : @"iPhone 14 Pro",
                             @"iPhone15,3" : @"iPhone 14 Pro Max" };
    NSString *name = machine ? names[machine] : nil;
    if (name) return [NSString stringWithFormat:@"%@ (%@)", name, machine];
    return machine ?: [[UIDevice currentDevice] model];
}

+ (NSArray *)deviceOverview {
    NSMutableArray *rows = [NSMutableArray array];
    [rows addObject:@[ @"Device", HCGModelName(HCGMachine()) ]];
    [rows addObject:@[ @"iOS", [[UIDevice currentDevice] systemVersion] ?: @"—" ]];
    NSString *root = HCGJailbreakRoot();
    NSFileManager *fm = [NSFileManager defaultManager];
    NSMutableArray *jb = [NSMutableArray array];
    if (root.length) {
        [jb addObject:[NSString stringWithFormat:@"Rootless (%@)", root]];
        if ([fm fileExistsAtPath:[root stringByAppendingPathComponent:@".installed_dopamine"]]) [jb addObject:@"Dopamine"];
        if ([fm fileExistsAtPath:[root stringByAppendingPathComponent:@"usr/lib/libellekit.dylib"]]) [jb addObject:@"ElleKit"];
    } else {
        [jb addObject:@"Rootful layout"];
    }
    [rows addObject:@[ @"Jailbreak", [jb componentsJoinedByString:@" · "] ]];
    return rows;
}

+ (NSDictionary *)trustEnvironment {
    NSString *root = HCGJailbreakRoot();
    NSMutableDictionary *env = [NSMutableDictionary dictionary];
    NSArray *records = [HCGPackageIndex recordsFromText:HCGReadText([root stringByAppendingPathComponent:@"var/lib/dpkg/status"])];
    NSMutableArray *installed = [NSMutableArray array];
    for (HCGPackageRecord *r in records) if (r.installed) [installed addObject:r];
    env[@"installed"] = installed;

    NSMutableArray *trustedYes = [NSMutableArray array];
    NSString *sourcesDir = [root stringByAppendingPathComponent:@"etc/apt/sources.list.d"];
    NSFileManager *fm = [NSFileManager defaultManager];
    NSMutableArray *sourceFiles = [NSMutableArray array];
    for (NSString *name in [fm contentsOfDirectoryAtPath:sourcesDir error:NULL] ?: @[]) [sourceFiles addObject:[sourcesDir stringByAppendingPathComponent:name]];
    [sourceFiles addObject:[root stringByAppendingPathComponent:@"etc/apt/sources.list"]];
    for (NSString *path in sourceFiles) {
        NSString *text = HCGReadText(path);
        if (!text.length) continue;
        if ([path hasSuffix:@".sources"]) {
            for (NSString *stanza in [text componentsSeparatedByString:@"\n\n"]) {
                NSString *lower = [stanza lowercaseString];
                if ([lower rangeOfString:@"trusted: yes"].location == NSNotFound) continue;
                NSRange uris = [lower rangeOfString:@"uris:"];
                NSString *uri = uris.location != NSNotFound ? [[[stanza substringFromIndex:uris.location + 5] componentsSeparatedByString:@"\n"].firstObject
                                                               stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] : @"(no URIs)";
                [trustedYes addObject:[NSString stringWithFormat:@"%@ (%@)", uri, path.lastPathComponent]];
            }
        } else {
            for (NSString *line in [text componentsSeparatedByString:@"\n"]) {
                NSString *t = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
                if ([t hasPrefix:@"#"] || [[t lowercaseString] rangeOfString:@"trusted=yes"].location == NSNotFound) continue;
                [trustedYes addObject:[NSString stringWithFormat:@"%@ (%@)", t, path.lastPathComponent]];
            }
        }
    }
    env[@"trustedYes"] = trustedYes;

    NSData *keyring = [NSData dataWithContentsOfFile:[root stringByAppendingPathComponent:@"etc/apt/trusted.gpg.d/hcg-repo.gpg"]];
    if (keyring.length) env[@"keyring"] = keyring;

    id workspace = HCGWorkspace();
    env[@"packageManagers"] = [self packageManagersWithWorkspace:workspace];
    NSMutableDictionary *entitlements = [NSMutableDictionary dictionary];
    for (HCGHIPProductDescriptor *d in [HCGInterchange registry]) {
        if (!d.bundleIdentifier.length || !HCGAppInstalled(workspace, d.bundleIdentifier)) continue;
        id proxy = HCGProxy(d.bundleIdentifier);
        SEL urlSel = NSSelectorFromString(@"bundleURL");
        NSURL *bundleURL = [proxy respondsToSelector:urlSel] ? ((id (*)(id, SEL))objc_msgSend)(proxy, urlSel) : nil;
        NSDictionary *info = HCGAppInfo(proxy);
        NSString *exe = [info objectForKey:@"CFBundleExecutable"];
        if (![bundleURL isKindOfClass:[NSURL class]] || ![exe isKindOfClass:[NSString class]] || [exe rangeOfString:@"/"].location != NSNotFound) continue;
        NSString *path = [bundleURL.path stringByAppendingPathComponent:exe];
        NSDictionary *attributes = [fm attributesOfItemAtPath:path error:NULL];
        if (!attributes || [attributes fileSize] > 96ull * 1024 * 1024) continue;
        NSData *binary = [NSData dataWithContentsOfFile:path options:NSDataReadingMappedIfSafe error:NULL];
        NSString *why = nil;
        NSDictionary *ents = binary ? [HCGEntitlements entitlementsInMachO:binary error:&why] : nil;
        entitlements[d.bundleIdentifier] = ents ?: @{ @"_unavailable" : why ?: @"unreadable" };
    }
    env[@"entitlements"] = entitlements;
    return env;
}

@end
