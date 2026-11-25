#import <Foundation/Foundation.h>
#import "HCGPackageIndex.h"

NS_ASSUME_NONNULL_BEGIN

// HCG Interchange Protocol (HIP), version 1 — docs/INTERCHANGE.md.
//
// A small, versioned description of what each HCG product is, how Nexus recognises it, what it can do and
// how Nexus may reach it. Nexus is a viewer and navigator, not an authority:
//
//   * The registry below is compiled into Nexus. Its entries come from the products' own repositories
//     (inspected 24 Nov 2026) and say which capabilities are implemented, verified on a device or only planned.
//   * Everything a route opens is fixed text in this registry. Nexus never builds a link from data it read,
//     and every route only navigates: none can run a command, change a setting or move data.
//   * An installed product MAY declare itself (Info.plist key HCGInterchange). A declaration can only switch
//     on routes this registry already marks "needs a declaration" and can only switch capabilities OFF
//     (the HCG Device Link rule: an advertisement can cause a refusal, never an allow). It is never proof of
//     authorization and never adds a route, URL or capability Nexus does not already know.
//   * Facts (installed packages, versions, a product's own status record) are read without side effects.
//     Writes happen only through an API the product owns, after the user acts in Nexus (today: HCG Halo's
//     HaloNexusControl border switch).
//   * HCG Connect stays the only identity authority. HIP carries no account, token, password or session.
//   * Every product works without Nexus, and Nexus works without every product.

FOUNDATION_EXPORT const NSInteger HCGInterchangeProtocolVersion;   // 1
FOUNDATION_EXPORT NSString *const HCGInterchangeInfoKey;            // "HCGInterchange" (Info.plist)
FOUNDATION_EXPORT NSString *const HCGInterchangeProtocolKey;        // "protocol"      NSNumber, must be 1
FOUNDATION_EXPORT NSString *const HCGInterchangeProductKey;         // "product"       NSString, the HIP product ID
FOUNDATION_EXPORT NSString *const HCGInterchangeRoutesKey;          // "routes"        NSArray<NSString> route IDs
FOUNDATION_EXPORT NSString *const HCGInterchangeCapabilitiesKey;    // "capabilities"  NSArray<NSString> capability IDs

// HIP product identifiers.
FOUNDATION_EXPORT NSString *const HCGHIPProductNexus;
FOUNDATION_EXPORT NSString *const HCGHIPProductTerminalUnleashed;
FOUNDATION_EXPORT NSString *const HCGHIPProductTerminal;
FOUNDATION_EXPORT NSString *const HCGHIPProductSentinel;
FOUNDATION_EXPORT NSString *const HCGHIPProductHalo;
FOUNDATION_EXPORT NSString *const HCGHIPProductVortex;
FOUNDATION_EXPORT NSString *const HCGHIPProductPortal;
FOUNDATION_EXPORT NSString *const HCGHIPProductAnimationCenter;
FOUNDATION_EXPORT NSString *const HCGHIPProductRepo;
FOUNDATION_EXPORT NSString *const HCGHIPProductAgentRuntime;
FOUNDATION_EXPORT NSString *const HCGHIPProductServer;
FOUNDATION_EXPORT NSString *const HCGHIPProductConnect;
FOUNDATION_EXPORT NSString *const HCGHIPProductNews;
FOUNDATION_EXPORT NSString *const HCGHIPProductExecutableMaker;

// Requests other HCG apps may post (Darwin notifications, no payload) to bring up Nexus. Navigation only:
// Nexus opens its panel at the Ecosystem section (or that product's card) while the iPhone is unlocked and
// "Let HCG apps open Nexus" is on, at most once every 2 seconds. Nothing else happens.
FOUNDATION_EXPORT NSString *const HCGNexusOpenEcosystemDarwinNotification; // com.hakmicapitalgroup.hcgnexus/open/ecosystem
FOUNDATION_EXPORT NSString *const HCGNexusOpenProductDarwinPrefix;         // com.hakmicapitalgroup.hcgnexus/open/product/
FOUNDATION_EXPORT const NSTimeInterval HCGNexusOpenRequestMinimumInterval; // 2 s

typedef NS_ENUM(NSInteger, HCGHIPProductKind) {
    HCGHIPProductKindApp = 0,        // an app (App Store build or jailbreak package)
    HCGHIPProductKindTweak = 1,      // SpringBoard tweak + Settings bundle
    HCGHIPProductKindRepository = 2, // HCG Repo
    HCGHIPProductKindService = 3,    // runs on another computer
    HCGHIPProductKindIdentity = 4,   // HCG Connect
    HCGHIPProductKindHub = 5,        // HCG Nexus itself
};

// Capability states. The first four are HCG Device Link's advertisement states (hcg.devicelink/1).
typedef NS_ENUM(NSInteger, HCGHIPCapabilityState) {
    HCGHIPCapabilityStateAvailable = 0,   // implemented in the product's shipped code
    HCGHIPCapabilityStateVerified = 1,    // implemented and seen working on a physical device (evidence recorded)
    HCGHIPCapabilityStateUnavailable = 2, // not possible here (not installed, iOS too old, not declared, ...)
    HCGHIPCapabilityStateDisabled = 3,    // implemented, but the product is switched off
    HCGHIPCapabilityStatePlanned = 4,     // designed or documented only; not built
};

// What using a capability requires from the user.
typedef NS_ENUM(NSInteger, HCGHIPPermission) {
    HCGHIPPermissionNone = 0,              // read-only view or navigation
    HCGHIPPermissionApprovalInProduct = 1, // the product itself asks before acting (Nexus never acts for it)
    HCGHIPPermissionProductOwnedSwitch = 2,// a switch in Nexus calls an API the product owns
    HCGHIPPermissionNotOffered = 3,        // Nexus does not offer it
};

typedef NS_ENUM(NSInteger, HCGHIPRouteKind) {
    HCGHIPRouteKindOpenApp = 0,        // launch the app by bundle identifier
    HCGHIPRouteKindAppLink = 1,        // the product's own navigation link (fixed text)
    HCGHIPRouteKindSettingsApp = 2,    // open the Settings app, where the product's page is listed
    HCGHIPRouteKindPackageManager = 3, // open the package in Zebra or Sileo (viewing only)
    HCGHIPRouteKindNexusControl = 4,   // a control inside Nexus (HCG Halo border switch)
    HCGHIPRouteKindWeb = 5,            // an https page
};

typedef NS_ENUM(NSInteger, HCGHIPRouteRequirement) {
    HCGHIPRouteRequirementInstalled = 0,      // the product is installed
    HCGHIPRouteRequirementDeclaredScheme = 1, // the installed app declares the product's URL scheme
    HCGHIPRouteRequirementDeclaredRoute = 2,  // the installed product lists this route in its HCGInterchange declaration
    HCGHIPRouteRequirementNone = 3,           // always (web pages)
};

@interface HCGHIPRoute : NSObject {
    NSString *_identifier;
    NSString *_title;
    NSString *_symbolName;
    HCGHIPRouteKind _kind;
    NSString *_target;
    HCGHIPRouteRequirement _requirement;
    NSString *_detail;
    NSString *_fallbackRouteIdentifier;
}
@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *symbolName;
@property (nonatomic) HCGHIPRouteKind kind;
@property (nonatomic, copy) NSString *target;          // URL text, bundle identifier or Nexus control name (fixed)
@property (nonatomic) HCGHIPRouteRequirement requirement;
@property (nonatomic, copy) NSString *detail;          // what it opens, in words
// When this route is unavailable but another route reaches the same screen with one more tap (e.g. HCG Terminal
// 0.2.0~rc2: Jailbreak Diagnostics through Unleashed Tools).
@property (nonatomic, copy, nullable) NSString *fallbackRouteIdentifier;
@end

@interface HCGHIPCapability : NSObject {
    NSString *_identifier;
    NSString *_title;
    HCGHIPCapabilityState _state;
    HCGHIPPermission _permission;
    NSString *_note;
}
@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, copy) NSString *title;
@property (nonatomic) HCGHIPCapabilityState state;   // as built (Available / Verified / Planned / Unavailable)
@property (nonatomic) HCGHIPPermission permission;
@property (nonatomic, copy) NSString *note;          // evidence for Verified, the reason otherwise
@end

typedef NS_ENUM(NSInteger, HCGHIPReadoutKind) {
    HCGHIPReadoutKindBool = 0,
    HCGHIPReadoutKindText = 1,
    HCGHIPReadoutKindPercent = 2,    // 0…1 shown as %
    HCGHIPReadoutKindNumber = 3,
    HCGHIPReadoutKindColours = 4,    // array of "#RRGGBB"
    HCGHIPReadoutKindCount = 5,      // array, shown as its count
};

// One preference value Nexus may show (read-only) from the product's own preference domain.
@interface HCGHIPReadout : NSObject {
    NSString *_key;
    NSString *_title;
    HCGHIPReadoutKind _kind;
    id _defaultValue;
}
@property (nonatomic, copy) NSString *key;
@property (nonatomic, copy) NSString *title;
@property (nonatomic) HCGHIPReadoutKind kind;
@property (nonatomic, strong, nullable) id defaultValue; // the product's own default, used when unset
@end

@interface HCGHIPProductDescriptor : NSObject {
    NSString *_productID;
    NSString *_name;
    NSString *_symbolName;
    HCGHIPProductKind _kind;
    NSString *_packageIdentifier;
    NSString *_bundleIdentifier;
    NSString *_urlScheme;
    NSString *_settingsBundleName;
    NSString *_minimumOSVersion;
    NSString *_integrationMinimumVersion;
    NSString *_summary;
    NSString *_unavailableReason;
    NSString *_preferenceDomain;
    NSString *_enabledKey;
    BOOL _enabledByDefault;
    NSString *_statusDomain;
    NSString *_statusRecordKey;
    NSString *_productPageURL;
    NSArray *_routes;
    NSArray *_capabilities;
    NSArray *_readouts;
}
@property (nonatomic, copy) NSString *productID;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *symbolName;
@property (nonatomic) HCGHIPProductKind kind;
@property (nonatomic, copy, nullable) NSString *packageIdentifier;  // HCG Repo package
@property (nonatomic, copy, nullable) NSString *bundleIdentifier;   // app bundle
@property (nonatomic, copy, nullable) NSString *urlScheme;          // its own navigation scheme
@property (nonatomic, copy, nullable) NSString *settingsBundleName; // "HCGHaloPrefs.bundle"
@property (nonatomic, copy, nullable) NSString *minimumOSVersion;   // its package's firmware requirement
@property (nonatomic, copy, nullable) NSString *integrationMinimumVersion; // oldest package version Nexus's adapter supports
@property (nonatomic, copy) NSString *summary;
// Set for products with nothing on this phone to talk to (services, unissued clients): shown instead of states.
@property (nonatomic, copy, nullable) NSString *unavailableReason;
@property (nonatomic, copy, nullable) NSString *preferenceDomain;
@property (nonatomic, copy, nullable) NSString *enabledKey;
@property (nonatomic) BOOL enabledByDefault;
@property (nonatomic, copy, nullable) NSString *statusDomain;
@property (nonatomic, copy, nullable) NSString *statusRecordKey;    // nil: the status fields are top-level keys
@property (nonatomic, copy, nullable) NSString *productPageURL;
@property (nonatomic, copy) NSArray<HCGHIPRoute *> *routes;
@property (nonatomic, copy) NSArray<HCGHIPCapability *> *capabilities;
@property (nonatomic, copy) NSArray<HCGHIPReadout *> *readouts;
- (nullable HCGHIPRoute *)routeWithIdentifier:(NSString *)identifier;
@end

// How a service product (HCG Server) is reached from this iPhone, reported by the platform layer from the
// app's real HCG Device Link state. NotReported (the default) means this build has no Device Link client
// (jailbreak package, Settings bundle, preview harness): the registry's unavailableReason is shown instead.
typedef NS_ENUM(NSInteger, HCGHIPServiceLinkState) {
    HCGHIPServiceLinkStateNotReported = 0,
    HCGHIPServiceLinkStateNotPaired = 1,        // no pairing on this device
    HCGHIPServiceLinkStateAwaitingApproval = 2, // pairing requested; the owner has not approved it yet
    HCGHIPServiceLinkStateNotConnected = 3,     // paired, but no recent successful request (detail says why)
    HCGHIPServiceLinkStateConnected = 4,        // ONLY after a signed request to the server succeeded recently
    HCGHIPServiceLinkStateUnreachable = 5,      // the last request failed (detail: the real reason)
    HCGHIPServiceLinkStateEnded = 6,            // rejected, removed, authority changed...: pair again (detail says why)
};

// What the host could read about one product, without side effects. Filled by the platform layer
// (HCGEcosystemScanner in SpringBoard and Settings; a reduced set in the standalone app; a simulation in the
// preview harness).
@interface HCGHIPFacts : NSObject {
    NSString *_productID;
    BOOL _hostCanInspect;
    BOOL _hostCanLaunchApps;
    NSString *_packageVersion;
    BOOL _appInstalled;
    NSString *_appVersion;
    NSString *_appBuild;
    NSArray *_declaredSchemes;
    id _declaration;
    BOOL _settingsBundlePresent;
    BOOL _canOpenScheme;
    NSString *_osVersion;
    NSString *_offeredVersion;
    NSDictionary *_preferences;
    NSDictionary *_statusRecord;
    NSArray *_packageManagers;
    BOOL _simulated;
    HCGHIPServiceLinkState _serviceLinkState;
    NSString *_serviceLinkDetail;
    NSString *_serviceLinkServerName;
    BOOL _serviceLinkLocalDevelopment;
    NSInteger _serviceLinkHostedServices;
}
@property (nonatomic, copy) NSString *productID;
@property (nonatomic) BOOL hostCanInspect;           // NO in the sandboxed app: installation is private there
@property (nonatomic) BOOL hostCanLaunchApps;        // bundle-ID launch and opening Settings
@property (nonatomic, copy, nullable) NSString *packageVersion;  // dpkg, nil when not installed
@property (nonatomic) BOOL appInstalled;
@property (nonatomic, copy, nullable) NSString *appVersion;      // CFBundleShortVersionString
@property (nonatomic, copy, nullable) NSString *appBuild;        // CFBundleVersion
@property (nonatomic, copy, nullable) NSArray *declaredSchemes;  // CFBundleURLTypes
@property (nonatomic, strong, nullable) id declaration;          // raw Info.plist HCGInterchange value (unvalidated)
@property (nonatomic) BOOL settingsBundlePresent;
@property (nonatomic) BOOL canOpenScheme;                        // sandboxed app: canOpenURL for its scheme
@property (nonatomic, copy, nullable) NSString *osVersion;
@property (nonatomic, copy, nullable) NSString *offeredVersion;  // highest HCG Repo version in local package lists
@property (nonatomic, copy, nullable) NSDictionary *preferences; // only the registry's readout keys
@property (nonatomic, copy, nullable) NSDictionary *statusRecord;// the product's own status record
@property (nonatomic, copy, nullable) NSArray<NSString *> *packageManagers; // "zebra", "sileo" (installed)
@property (nonatomic) BOOL simulated;                            // preview harness
// Service products only (HCG Server through HCG Device Link, standalone app). Never inferred: the platform layer
// reports Connected only when a real request succeeded.
@property (nonatomic) HCGHIPServiceLinkState serviceLinkState;
@property (nonatomic, copy, nullable) NSString *serviceLinkDetail;     // the real reason / last contact, in words
@property (nonatomic, copy, nullable) NSString *serviceLinkServerName; // the paired server's name
@property (nonatomic) BOOL serviceLinkLocalDevelopment;                // paired for local development (no HCG account)
@property (nonatomic) NSInteger serviceLinkHostedServices;             // services the server reported; -1 not known
@property (nonatomic, readonly) BOOL installed;
@end

typedef NS_ENUM(NSInteger, HCGHIPAvailability) {
    HCGHIPAvailabilityReady = 0,          // installed, compatible, running normally (or no runtime status)
    HCGHIPAvailabilityOff = 1,            // installed, switched off in its own settings
    HCGHIPAvailabilityAttention = 2,      // installed; its status reports a fault, kill switch, launch guard, ...
    HCGHIPAvailabilityNeedsUpdate = 3,    // installed, older than Nexus's adapter supports
    HCGHIPAvailabilityNotInstalled = 4,
    HCGHIPAvailabilityUnsupportedOS = 5,  // not installed and this iOS is older than it requires
    HCGHIPAvailabilityUnknown = 6,        // this host cannot see installed products (sandboxed app)
    HCGHIPAvailabilityNotAvailable = 7,   // nothing on this phone to connect to (service, identity, planned)
    HCGHIPAvailabilityHub = 8,            // HCG Nexus itself
    HCGHIPAvailabilityConnected = 9,      // a service this iPhone reached: the last signed request succeeded
    HCGHIPAvailabilityNotConnected = 10,  // a service this build can reach, but no current connection (not paired, ...)
    HCGHIPAvailabilityUnreachable = 11,   // a service this iPhone is paired with, but the last request failed
};

// "LOCAL DEVELOPMENT — not an HCG account": shown wherever a local-development connection appears.
FOUNDATION_EXPORT NSString *const HCGHIPLocalDevelopmentLabel;

@interface HCGHIPResolvedCapability : NSObject {
    HCGHIPCapability *_capability;
    HCGHIPCapabilityState _state;
    NSString *_reason;
}
@property (nonatomic, strong) HCGHIPCapability *capability;
@property (nonatomic) HCGHIPCapabilityState state;   // after applying this device's facts
@property (nonatomic, copy) NSString *reason;
@end

@interface HCGHIPProductStatus : NSObject {
    HCGHIPProductDescriptor *_descriptor;
    HCGHIPAvailability _availability;
    NSString *_stateTitle;
    NSString *_versionText;
    NSString *_compatibilityText;
    NSString *_healthText;
    NSString *_integrationText;
    NSString *_updateText;
    NSString *_offeredVersion;
    BOOL _updateAvailable;
    NSArray *_routes;
    NSArray *_routeNotes;
    NSArray *_capabilities;
    NSArray *_readouts;
    NSString *_declarationNote;
    BOOL _simulated;
}
@property (nonatomic, strong) HCGHIPProductDescriptor *descriptor;
@property (nonatomic) HCGHIPAvailability availability;
@property (nonatomic, copy) NSString *stateTitle;         // chip: "Ready", "Off", "Needs update", ...
@property (nonatomic, copy) NSString *versionText;        // "0.2.0~rc2 · app 0.2.0 (2)"
@property (nonatomic, copy) NSString *compatibilityText;
@property (nonatomic, copy) NSString *healthText;
@property (nonatomic, copy) NSString *integrationText;    // "Connected" only for a service reached through Device Link
@property (nonatomic, copy, nullable) NSString *updateText;
@property (nonatomic, copy, nullable) NSString *offeredVersion;
@property (nonatomic) BOOL updateAvailable;
@property (nonatomic, copy) NSArray<HCGHIPRoute *> *routes;      // usable now, in registry order
@property (nonatomic, copy) NSArray<NSString *> *routeNotes;     // why other routes are not offered
@property (nonatomic, copy) NSArray<HCGHIPResolvedCapability *> *capabilities;
@property (nonatomic, copy) NSArray<NSArray<NSString *> *> *readouts; // (title, value) pairs
@property (nonatomic, copy, nullable) NSString *declarationNote;
@property (nonatomic) BOOL simulated;
@property (nonatomic, readonly) BOOL installed;
@end

@interface HCGInterchange : NSObject
+ (NSArray<HCGHIPProductDescriptor *> *)registry;
+ (nullable HCGHIPProductDescriptor *)descriptorForProductID:(nullable NSString *)productID;
+ (nullable HCGHIPProductDescriptor *)descriptorForBundleIdentifier:(nullable NSString *)bundleIdentifier;
// Every HCG package identifier in the registry (for reading dpkg status and package lists).
+ (NSSet<NSString *> *)packageIdentifiers;

// Route identifiers a declaration may switch on: only registry routes marked DeclaredRoute, only for the
// declaring product, only with protocol 1. `problem` explains anything ignored or refused.
+ (NSSet<NSString *> *)declaredRouteIdentifiersFromDeclaration:(nullable id)declaration
                                                    descriptor:(HCGHIPProductDescriptor *)descriptor
                                                       problem:(NSString *_Nullable *_Nullable)problem;
// Capability identifiers the declaration lists, or nil when it lists none (then nothing is switched off).
+ (nullable NSSet<NSString *> *)declaredCapabilityIdentifiersFromDeclaration:(nullable id)declaration
                                                                  descriptor:(HCGHIPProductDescriptor *)descriptor;

+ (HCGHIPProductStatus *)statusForDescriptor:(HCGHIPProductDescriptor *)descriptor facts:(nullable HCGHIPFacts *)facts;

// Every link target any registry route may open (exact text). Used to accept saved shortcuts.
+ (BOOL)isRegistryLink:(nullable NSString *)urlText;

// The Darwin name that opens Nexus at a product's card, or nil for an unknown product.
+ (nullable NSString *)openProductDarwinNotificationForProductID:(nullable NSString *)productID;
// The product a Darwin name asks for (nil: the Ecosystem overview, or not a Nexus open request).
+ (nullable NSString *)productIDForOpenDarwinNotification:(nullable NSString *)name;

+ (NSString *)titleForAvailability:(HCGHIPAvailability)availability;
+ (NSString *)titleForCapabilityState:(HCGHIPCapabilityState)state;
// "zbra://packages/<id>" / "sileo://package/<id>" for a registry package, else nil.
+ (nullable NSString *)packageManagerLinkForManager:(NSString *)manager packageIdentifier:(NSString *)packageIdentifier;
@end

// The ecosystem activity history: what Nexus did (opened a product or screen, switched the HCG Halo border,
// an HCG app asked to open Nexus). Short sentences only; never URLs with parameters, names of hosts, file
// paths, accounts or secrets. Kept in Nexus's own preferences, newest first.
FOUNDATION_EXPORT NSString *const HCGEcosystemActivityStoreKey; // "ecosystemActivity"
FOUNDATION_EXPORT const NSUInteger HCGEcosystemActivityLimit;   // 40

@interface HCGEcosystemActivity : NSObject
// A sanitised entry dictionary {time, product, text}, or nil when the text is empty.
+ (nullable NSDictionary *)entryWithText:(NSString *)text productID:(nullable NSString *)productID time:(NSDate *)time;
// Valid entries from a stored value (anything malformed is dropped), newest first, at most the limit.
+ (NSArray<NSDictionary *> *)entriesFromStoredValue:(nullable id)value;
+ (NSArray<NSDictionary *> *)entries:(nullable NSArray *)entries byAdding:(NSDictionary *)entry;
@end

NS_ASSUME_NONNULL_END
