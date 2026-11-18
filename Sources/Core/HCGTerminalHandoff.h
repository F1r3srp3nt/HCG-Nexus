#import <Foundation/Foundation.h>
#import "HCGSettings.h" // HCGTerminalVariant (None / Standard / Unleashed), also the user's choice in settings

NS_ASSUME_NONNULL_BEGIN

// HCG Terminal / HCG Terminal Unleashed: what Nexus can truthfully say and do.
//
// Four separate facts, never merged into one:
//   installed            the app is on the device (and its version, when readable)
//   launch available     Nexus can open it (SpringBoard bundle-ID launch, or its URL scheme)
//   integration available the installed build declares the Nexus handoff (Info.plist HCGNexusHandoff = 1
//                        and its own URL scheme), so a saved-connection link can be opened in it
//   session state       not shared: HCG Terminal never reports sessions to Nexus. Opening the app is
//                        never "Connected".
//
// Handoff contract version 1 (HCG-Terminal docs/NEXUS-HANDOFF.md):
//   standard  com.hakmicapitalgroup.hcgterminal            scheme hcgterminal
//   Unleashed com.hakmicapitalgroup.hcgterminal.unleashed  scheme hcgterminal-unleashed
//   <scheme>://open                       bring the app forward, nothing else
//   <scheme>://connection?id=<UUID>       show that saved connection; the user taps Connect
// Links are produced by HCG Terminal ("Copy Link for HCG Nexus"); Nexus only stores and opens them.
// Nothing in a link can run a command.

FOUNDATION_EXPORT NSString *const HCGTerminalHandoffInfoKey;    // HCGNexusHandoff
FOUNDATION_EXPORT const NSInteger HCGTerminalSupportedHandoffVersion; // 1
FOUNDATION_EXPORT const NSUInteger HCGTerminalLinkMaximumLength;     // 256

// What the host could read about one installed app (nil fields: unknown).
@interface HCGTerminalAppFacts : NSObject {
    HCGTerminalVariant _variant;
    BOOL _installedKnown;
    BOOL _installed;
    NSString *_version;
    NSArray *_urlSchemes;
    NSInteger _handoffVersion;
    BOOL _canLaunchByBundle;
    BOOL _canOpenScheme;
}
@property (nonatomic) HCGTerminalVariant variant;
@property (nonatomic) BOOL installedKnown;       // NO: the host cannot tell (standalone app sandbox)
@property (nonatomic) BOOL installed;
@property (nonatomic, copy, nullable) NSString *version;   // CFBundleShortVersionString
@property (nonatomic, copy, nullable) NSArray *urlSchemes; // CFBundleURLTypes schemes the app declares
@property (nonatomic) NSInteger handoffVersion;            // HCGNexusHandoff, 0 when absent
@property (nonatomic) BOOL canLaunchByBundle;              // SpringBoard bundle-ID launch exists
@property (nonatomic) BOOL canOpenScheme;                  // the host can open the variant's scheme
@end

@interface HCGTerminalStatus : NSObject {
    HCGTerminalVariant _variant;
    NSString *_installedText;
    NSString *_launchText;
    NSString *_integrationText;
    NSString *_sessionText;
    BOOL _launchAvailable;
    BOOL _integrationAvailable;
}
@property (nonatomic, readonly) HCGTerminalVariant variant;
@property (nonatomic, readonly, copy) NSString *installedText;   // "Installed · 0.1.0" / "Not installed" / "Unable to determine"
@property (nonatomic, readonly, copy) NSString *launchText;      // "Available" / "Not available: …"
@property (nonatomic, readonly, copy) NSString *integrationText; // "Saved-connection handoff available" / "Not in this version …"
@property (nonatomic, readonly, copy) NSString *sessionText;     // always "Not shared by HCG Terminal"
@property (nonatomic, readonly) BOOL launchAvailable;
@property (nonatomic, readonly) BOOL integrationAvailable;
@end

@interface HCGTerminalHandoff : NSObject
+ (NSString *)bundleIdentifierForVariant:(HCGTerminalVariant)variant;
+ (NSString *)urlSchemeForVariant:(HCGTerminalVariant)variant;
+ (NSString *)displayNameForVariant:(HCGTerminalVariant)variant;
+ (HCGTerminalVariant)variantForBundleIdentifier:(nullable NSString *)bundleIdentifier;

+ (HCGTerminalStatus *)statusWithFacts:(HCGTerminalAppFacts *)facts;

// Which installed variant Nexus should use: the only one installed, else the preferred one when both are,
// else none. `preferred` is the user's choice (HCGTerminalVariantNone = no choice).
+ (HCGTerminalVariant)variantToUseWithStandard:(HCGTerminalAppFacts *)standard unleashed:(HCGTerminalAppFacts *)unleashed
                                     preferred:(HCGTerminalVariant)preferred;

// <scheme>://open for the variant.
+ (NSURL *)openURLForVariant:(HCGTerminalVariant)variant;

// A saved-connection link exactly as HCG Terminal issues it, or nil with a reason. Accepts only
// <scheme>://connection?id=<UUID> for a known variant (no path, port, user, fragment, other or repeated
// parameters, at most 256 characters). The variant the link belongs to is returned through `variant`.
// Returns the validated text; the platform layer turns it into an NSURL (validation never depends on a
// URL parser, whose rules differ between Foundation implementations).
+ (nullable NSString *)validatedConnectionLink:(nullable NSString *)text variant:(nullable HCGTerminalVariant *)variant
                                     reason:(NSString *_Nullable *_Nullable)reason;
@end

NS_ASSUME_NONNULL_END
