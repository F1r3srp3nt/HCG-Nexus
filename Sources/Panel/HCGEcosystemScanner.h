#import <Foundation/Foundation.h>
#import "HCGInterchange.h"

NS_ASSUME_NONNULL_BEGIN

// Read-only discovery of HCG products on a jailbroken iPhone (SpringBoard and the Settings bundle; never the
// sandboxed standalone app). It reads, and only reads:
//   * <jbroot>/var/lib/dpkg/status                         installed HCG packages and versions
//   * HCG Repo package lists your package manager already downloaded (<jbroot>/var/lib/apt/lists,
//     Zebra's lists folder)                                 versions HCG Repo offers, as of that refresh
//   * LaunchServices (LSApplicationProxy)                  apps, their versions, URL schemes, HCGInterchange
//   * <jbroot>/Library/PreferenceBundles/<bundle>          whether a tweak's Settings page is installed
//   * each tweak's own preference and status domains        the registry's readout keys and the status record
// It writes nothing, posts nothing, starts nothing and contacts no server.
@interface HCGEcosystemScanner : NSObject
// One HCGHIPFacts per registry product. Safe off the main thread. Results are cached for a few seconds.
+ (NSArray<HCGHIPFacts *> *)factsCanLaunchApps:(BOOL)canLaunchApps;
// Device overview lines: (title, value) pairs such as ("iPhone", "iPhone 13 Pro"), ("iOS", "16.5"),
// ("Jailbreak", "Rootless (/var/jb) · Dopamine"). Only facts read from the device; nothing guessed.
+ (NSArray<NSArray<NSString *> *> *)deviceOverview;
+ (void)invalidateCache;

// Package Trust Center facts, read-only (keys below). Never writes, never changes Sileo's or Zebra's sources.
//   installed       NSArray<HCGPackageRecord> every package dpkg reports installed
//   trustedYes      NSArray<NSString> APT source entries marked trusted=yes (they skip signature checks)
//   keyring         NSData  <jbroot>/etc/apt/trusted.gpg.d/hcg-repo.gpg (HCG Repo Keyring), when installed
//   entitlements    NSDictionary bundle ID -> entitlements of installed HCG apps' executables
//   packageManagers NSArray "zebra", "sileo"
+ (NSDictionary *)trustEnvironment;
@end

NS_ASSUME_NONNULL_END
