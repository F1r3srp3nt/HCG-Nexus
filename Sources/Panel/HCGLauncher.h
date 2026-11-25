#import <Foundation/Foundation.h>
#import "HCGIntegrations.h"
#import "HCGTerminalHandoff.h"
#import "HCGInterchange.h"

NS_ASSUME_NONNULL_BEGIN

typedef void (^HCGLaunchCompletion)(NSError *_Nullable error);

// Adapter that actually opens apps and links. Implementations:
//   * HCGSpringBoardLauncher (Sources/Platform/SpringBoard) — on device, inside
//     SpringBoard, via LSApplicationWorkspace / UIApplication. Every private
//     class and selector is verified with respondsToSelector: first.
//   * HCGPreviewLauncher (Sources/Platform/Preview) — preview harness; app
//     launches are SIMULATED and reported as such.
//   * HCGAppLauncher (Sources/Platform/App) — standalone iOS app; opens links
//     with UIApplication and reports bundle-ID launching as unavailable.
@protocol HCGLauncher <HCGAppInstallationProbe>
@property (nonatomic, readonly) NSString *launcherName;
@property (nonatomic, readonly) BOOL simulated;
// One-line capability summary for diagnostics.
- (NSString *)capabilitySummary;
// Actionable explanation shown when -canLaunchApplicationsByBundleIdentifier
// is NO (e.g. "iOS only lets ordinary apps open links...").
- (NSString *)bundleLaunchUnavailableExplanation;
// Completion is always delivered on the main queue.
- (void)openApplicationWithBundleIdentifier:(NSString *)bundleIdentifier completion:(HCGLaunchCompletion)completion;
- (void)openURL:(NSURL *)url completion:(HCGLaunchCompletion)completion;
@optional
// HCG Interchange facts for every registry product (HCGInterchange.h), read without side effects: the full set
// in SpringBoard (HCGEcosystemScanner), only "does its link open" in the sandboxed app, a labelled simulation in
// the preview harness. May be slow (file reads): call off the main thread.
- (NSArray<HCGHIPFacts *> *)ecosystemFacts;
// (title, value) rows for the dashboard's device overview, read from the device.
- (NSArray<NSArray<NSString *> *> *)ecosystemDeviceOverview;
// Package Trust Center facts (HCGEcosystemScanner +trustEnvironment keys); jailbreak package only. Slow: off the main thread.
- (NSDictionary *)trustEnvironment;
@end

// Broadcasts persisted changes to other processes (Darwin notifications on
// device; no-op in the preview harness).
@protocol HCGChangeNotifier <NSObject>
- (void)postSettingsChanged;
- (void)postWorkspacesChanged;
@end

NS_ASSUME_NONNULL_END
