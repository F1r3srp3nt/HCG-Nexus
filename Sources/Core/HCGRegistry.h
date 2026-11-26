#import <Foundation/Foundation.h>
#import "HCGInterchange.h"

NS_ASSUME_NONNULL_BEGIN

// HCG Nexus ecosystem registry, schema hcg.nexus.registry/1 (docs/COMMAND-CENTER.md).
//
// The registry is data, not code: Resources/Registry/hcg-ecosystem-registry.json, embedded in the build by
// scripts/embed_registry.py. Each entry records where its facts were verified (central HCG product registry, the
// product's repository) and when. Rules:
//
//   * Links and endpoints are only https://hakmicapitalgroup.com or its subdomains, without query, fragment, user or
//     port. They are the only links and endpoints Nexus opens or reads, and every endpoint is anonymous and read-only.
//   * Registration in the registry never authorizes anything. A private entry is shown only when the account holds
//     its entitlement (product/feature); Nexus has no account today, so private entries stay hidden.
//   * An imported registry update (same schema, higher registryVersion, from Files) can add entries and change text,
//     lifecycle and status. It can only NARROW what Nexus may do: it never adds a link, endpoint, adapter, connection
//     method or capability to an entry, and entries it adds carry none of them. Validation history is never imported.
//   * Lifecycle: active, suspended (shown, nothing offered), retired (shown as retired, nothing offered).

FOUNDATION_EXPORT NSString *const HCGRegistrySchema;                 // "hcg.nexus.registry/1"
FOUNDATION_EXPORT NSString *HCGRegistryBuiltInJSON(void);            // generated (HCGRegistryData.m)

// https, host hakmicapitalgroup.com or a subdomain, no query/fragment/user/port/whitespace, at most 200 characters.
FOUNDATION_EXPORT BOOL HCGRegistryIsAllowedURL(NSString *_Nullable text);
// Lower-case letters, digits, '.' and '-', 2-61 characters, starting with a letter or digit.
FOUNDATION_EXPORT BOOL HCGRegistryIsValidIdentifier(NSString *_Nullable text);

@interface HCGRegistryCategory : NSObject {
    NSString *_identifier;
    NSString *_name;
    NSString *_symbolName;
}
@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *symbolName;
@end

@interface HCGRegistryMethod : NSObject {
    NSString *_identifier;
    NSString *_name;
    NSString *_kind;
    NSString *_detail;
    BOOL _twoWay;
}
@property (nonatomic, copy) NSString *identifier;   // local-app, url-scheme, local-ipc, hcg-server, https-api, ...
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *kind;         // local, remote, device, identity, web
@property (nonatomic, copy) NSString *detail;
@property (nonatomic) BOOL twoWay;                  // NO: navigation only, never counts as a connection
@end

@interface HCGRegistryConnection : NSObject {
    NSString *_method;
    NSString *_state;
    NSString *_detail;
}
@property (nonatomic, copy) NSString *method;
@property (nonatomic, copy) NSString *state;        // implemented, planned, unavailable
@property (nonatomic, copy) NSString *detail;
@end

@interface HCGRegistryRequirement : NSObject {
    NSString *_identifier;
    NSString *_title;
    NSString *_detail;
    NSString *_kind;
    BOOL _blocking;
}
@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *detail;
@property (nonatomic, copy) NSString *kind;         // registration, configuration, contract, access, development, research
@property (nonatomic) BOOL blocking;
@end

@interface HCGRegistryEndpoint : NSObject {
    NSString *_identifier;
    NSString *_url;
    NSString *_detail;
    NSString *_verified;
}
@property (nonatomic, copy) NSString *identifier;   // "news.articles"
@property (nonatomic, copy) NSString *url;          // allowed URL, no query
@property (nonatomic, copy) NSString *detail;
@property (nonatomic, copy) NSString *verified;     // how and when it was verified
@end

@interface HCGRegistryValidation : NSObject {
    NSString *_date;
    NSString *_device;
    NSString *_version;
    NSString *_summary;
}
@property (nonatomic, copy) NSString *date;
@property (nonatomic, copy) NSString *device;
@property (nonatomic, copy) NSString *version;
@property (nonatomic, copy) NSString *summary;
@end

@interface HCGRegistryEntry : NSObject {
    NSString *_identifier;
    NSString *_officialName;
    NSArray *_aliases;
    NSString *_categoryID;
    NSString *_summary;
    NSString *_kind;
    NSString *_hipProductID;
    NSString *_adapter;
    NSArray *_platforms;
    NSString *_developmentStatus;
    NSString *_lifecycle;
    NSString *_visibility;
    NSString *_entitlement;
    BOOL _nameVerified;
    NSString *_centralProductID;
    NSString *_centralRegistration;
    NSString *_centralName;
    NSString *_centralNote;
    NSString *_distributionChannel;
    NSString *_repoPackage;
    NSString *_websiteURL;
    NSString *_contractID;
    NSString *_contractStatus;
    NSString *_contractDetail;
    NSArray *_endpoints;
    NSArray *_connections;
    NSArray *_capabilities;
    NSArray *_requirements;
    NSArray *_validations;
    NSArray *_notes;
    NSString *_lastVerified;
    NSString *_verifiedFrom;
    BOOL _fromUpdate;
}
@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, copy) NSString *officialName;
@property (nonatomic, copy) NSArray<NSString *> *aliases;
@property (nonatomic, copy, nullable) NSString *categoryID;          // nil: HCG Nexus itself
@property (nonatomic, copy) NSString *summary;
@property (nonatomic, copy) NSString *kind;                          // hub, app, tweak, service, website, identity, repository, feature, planned
@property (nonatomic, copy, nullable) NSString *hipProductID;        // HCG Interchange adapter on this iPhone
@property (nonatomic, copy, nullable) NSString *adapter;             // "hip", "news.v1", "connect.discovery", "system-tester.inventory", "lifeos.export", "trust-center"
@property (nonatomic, copy) NSArray<NSString *> *platforms;
@property (nonatomic, copy) NSString *developmentStatus;             // planned, research, in-development, testing, beta, released
@property (nonatomic, copy) NSString *lifecycle;                     // active, suspended, retired
@property (nonatomic, copy) NSString *visibility;                    // listed, private
@property (nonatomic, copy, nullable) NSString *entitlement;         // "product_id/feature_key" (private entries)
@property (nonatomic) BOOL nameVerified;                             // NO: no official name was found
@property (nonatomic, copy, nullable) NSString *centralProductID;
@property (nonatomic, copy) NSString *centralRegistration;           // registered, proposed, not-registered, edition, surface, component, feature
@property (nonatomic, copy, nullable) NSString *centralName;
@property (nonatomic, copy, nullable) NSString *centralNote;
@property (nonatomic, copy, nullable) NSString *distributionChannel;
@property (nonatomic, copy, nullable) NSString *repoPackage;
@property (nonatomic, copy, nullable) NSString *websiteURL;
@property (nonatomic, copy, nullable) NSString *contractID;
@property (nonatomic, copy) NSString *contractStatus;                // available, planned, none, unknown
@property (nonatomic, copy, nullable) NSString *contractDetail;
@property (nonatomic, copy) NSArray<HCGRegistryEndpoint *> *endpoints;
@property (nonatomic, copy) NSArray<HCGRegistryConnection *> *connections;
@property (nonatomic, copy) NSArray<HCGHIPCapability *> *capabilities;   // for entries without a HIP adapter
@property (nonatomic, copy) NSArray<HCGRegistryRequirement *> *requirements;
@property (nonatomic, copy) NSArray<HCGRegistryValidation *> *validations;
@property (nonatomic, copy) NSArray<NSString *> *notes;
@property (nonatomic, copy) NSString *lastVerified;                  // YYYY-MM-DD
@property (nonatomic, copy) NSString *verifiedFrom;
@property (nonatomic) BOOL fromUpdate;                               // added by an imported update (text only)
@property (nonatomic, readonly) BOOL isPlanned;                      // kind planned or status planned/research
- (nullable HCGRegistryEndpoint *)endpointWithIdentifier:(NSString *)identifier;
- (nullable HCGRegistryConnection *)connectionForMethod:(NSString *)method;
@end

@interface HCGRegistryDeviceClass : NSObject {
    NSString *_identifier;
    NSString *_name;
    NSString *_symbolName;
    NSArray *_systemTesterCategories;
    NSArray *_examples;
    NSArray *_adapters;
    NSArray *_missing;
    NSString *_instructions;
    NSString *_safety;
}
@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *symbolName;
@property (nonatomic, copy) NSArray<NSString *> *systemTesterCategories; // HCG System Tester DeviceCategory raw values
@property (nonatomic, copy) NSArray<NSString *> *examples;
@property (nonatomic, copy) NSArray<NSString *> *adapters;               // System Tester adapters that exist today
@property (nonatomic, copy) NSArray<NSString *> *missing;
@property (nonatomic, copy) NSString *instructions;
@property (nonatomic, copy) NSString *safety;
@end

@interface HCGRegistry : NSObject {
    NSInteger _version;
    NSString *_generatedAt;
    NSString *_source;
    NSArray *_categories;
    NSArray *_methods;
    NSArray *_entries;
    NSArray *_deviceClasses;
    NSArray *_problems;
}
@property (nonatomic) NSInteger version;
@property (nonatomic, copy) NSString *generatedAt;
@property (nonatomic, copy) NSString *source;                        // "built in", "built in + update 3 (imported)"
@property (nonatomic, copy) NSArray<HCGRegistryCategory *> *categories;
@property (nonatomic, copy) NSArray<HCGRegistryMethod *> *methods;
@property (nonatomic, copy) NSArray<HCGRegistryEntry *> *entries;    // every entry, private ones included
@property (nonatomic, copy) NSArray<HCGRegistryDeviceClass *> *deviceClasses;
@property (nonatomic, copy) NSArray<NSString *> *problems;           // ignored parts, in words

// nil when the data is not a usable hcg.nexus.registry/1 document; `error` says why. Invalid entries are dropped
// with a problem, not the whole registry.
+ (nullable instancetype)registryWithJSONData:(nullable NSData *)data source:(NSString *)source error:(NSString *_Nullable *_Nullable)error;
// The registry compiled into this build (never nil: a broken build fails the host tests).
+ (instancetype)builtInRegistry;
// The registry with an imported update applied under the narrowing rules above. A lower or equal registryVersion is
// refused (`problem`), and self is returned unchanged.
- (HCGRegistry *)registryByApplyingUpdate:(HCGRegistry *)update problem:(NSString *_Nullable *_Nullable)problem;

// Entries an account with these grants ("product_id/feature_key") may see. Pass nil when nobody is signed in.
- (NSArray<HCGRegistryEntry *> *)visibleEntriesWithGrants:(nullable NSSet<NSString *> *)grants;
- (nullable HCGRegistryEntry *)entryWithIdentifier:(nullable NSString *)identifier;
- (nullable HCGRegistryEntry *)entryForHIPProductID:(nullable NSString *)productID;
- (nullable HCGRegistryCategory *)categoryWithIdentifier:(nullable NSString *)identifier;
- (nullable HCGRegistryMethod *)methodWithIdentifier:(nullable NSString *)identifier;
// Case-insensitive match on name, aliases, description, category, central ID; every word must match.
+ (NSArray<HCGRegistryEntry *> *)entries:(NSArray<HCGRegistryEntry *> *)entries matchingQuery:(nullable NSString *)query
                                registry:(HCGRegistry *)registry;
@end

NS_ASSUME_NONNULL_END
