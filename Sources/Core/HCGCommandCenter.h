#import <Foundation/Foundation.h>
#import "HCGRegistry.h"

NS_ASSUME_NONNULL_BEGIN

// HCG Nexus Command Center: connection status, development roadmap and gaps for registry entries
// (docs/COMMAND-CENTER.md). Everything here is computed from evidence:
//
//   * Connection status comes from what this iPhone actually observed: the HIP scan, HCG Device Link, and the
//     connection ledger (each read Nexus made, with its outcome and time). A product is never Connected because its
//     URL, scheme or bundle identifier exists, and navigation (opening an app or a link) never counts.
//   * The roadmap state is derived from the registry (contract, adapter, requirements, historical validations) and
//     the connection status. Each state carries the evidence it was derived from. History is kept per product and
//     changes only when the derived state changes. Historical validations stay separate from the current status.
//   * Development gaps get stable IDs ("nexus.<product>.<requirement>") and can be exported as a LifeOS import file
//     (lifeos.v1). Nothing is sent: you preview and import the file in LifeOS. No XP is ever claimed.

typedef NS_ENUM(NSInteger, HCGConnectionState) {
    HCGConnectionStateNotSupported = 0,  // nothing on this iPhone to connect to
    HCGConnectionStatePlanned = 1,       // planned product or integration
    HCGConnectionStateSuspended = 2,
    HCGConnectionStateRetired = 3,
    HCGConnectionStateNotConfigured = 4, // an integration exists but needs configuration (client, pairing)
    HCGConnectionStateUnableToCheck = 5, // this host cannot see installed products (sandboxed app)
    HCGConnectionStateNotInstalled = 6,
    HCGConnectionStateInstalled = 7,     // detected on this iPhone; not a connection
    HCGConnectionStateReady = 8,         // Nexus can read it on request; no successful read recently
    HCGConnectionStateConnected = 9,     // a two-way exchange succeeded recently
    HCGConnectionStateDisconnected = 10, // connected before, not now (stale, or the last attempt failed)
    HCGConnectionStateFailed = 11,       // attempted, never succeeded
    HCGConnectionStateBuiltIn = 12,      // part of HCG Nexus (Package Trust Center)
    HCGConnectionStateWebsite = 13,      // a website only; nothing to connect to
    HCGConnectionStateReachable = 14,    // an anonymous public read succeeded recently: the service is available, but
                                         // nothing is authenticated (never shown as Connected)
};

// The 14 roadmap states, in development order.
typedef NS_ENUM(NSInteger, HCGRoadmapState) {
    HCGRoadmapStateRegistered = 0,
    HCGRoadmapStateResearchRequired = 1,
    HCGRoadmapStateContractAvailable = 2,
    HCGRoadmapStateAdapterDevelopmentRequired = 3,
    HCGRoadmapStateAdapterImplemented = 4,
    HCGRoadmapStateConfigurationRequired = 5,
    HCGRoadmapStateReadyToConnect = 6,
    HCGRoadmapStateConnectionAttempted = 7,
    HCGRoadmapStateConnected = 8,
    HCGRoadmapStatePartiallyIntegrated = 9,
    HCGRoadmapStateValidated = 10,
    HCGRoadmapStateDisconnected = 11,
    HCGRoadmapStateBlocked = 12,
    HCGRoadmapStateUnsupported = 13,
};
FOUNDATION_EXPORT const NSInteger HCGRoadmapStateCount; // 14

FOUNDATION_EXPORT NSString *const HCGConnectionLedgerStoreKey;  // "connectionLedger"
FOUNDATION_EXPORT NSString *const HCGRoadmapStoreKey;           // "roadmap"
FOUNDATION_EXPORT NSString *const HCGLifeOSExportStoreKey;      // "lifeosExported"
FOUNDATION_EXPORT NSString *const HCGCommandCenterFavoritesKey; // "favoriteProducts"
FOUNDATION_EXPORT const NSTimeInterval HCGConnectionFreshInterval; // 15 min

// The connection ledger: what Nexus read, from which product, how, when and with what outcome. Entries are
// dictionaries {time, product, method, ok, text}; text is a short sentence (no links, hosts with parameters,
// accounts or secrets). Newest first, at most 200.
@interface HCGConnectionLedger : NSObject
+ (nullable NSDictionary *)entryForProduct:(NSString *)productID method:(NSString *)method success:(BOOL)success
                                      text:(NSString *)text time:(NSDate *)time;
+ (NSArray<NSDictionary *> *)entriesFromStoredValue:(nullable id)value;
+ (NSArray<NSDictionary *> *)entries:(nullable NSArray *)entries byAdding:(NSDictionary *)entry;
+ (NSArray<NSDictionary *> *)entries:(NSArray *)entries forProduct:(NSString *)productID;
@end

@interface HCGConnectionSummary : NSObject {
    HCGConnectionState _state;
    NSString *_title;
    NSString *_detail;
    NSDate *_lastSuccess;
    NSString *_lastSuccessText;
    NSDate *_lastAttempt;
    NSString *_lastSuccessAccess;
}
@property (nonatomic) HCGConnectionState state;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *detail;
@property (nonatomic, copy, nullable) NSDate *lastSuccess;       // last successful two-way communication
@property (nonatomic, copy, nullable) NSString *lastSuccessText;
@property (nonatomic, copy, nullable) NSDate *lastAttempt;
@property (nonatomic, copy, nullable) NSString *lastSuccessAccess;  // public, local, authenticated
@end

@interface HCGRoadmapAssessment : NSObject {
    HCGRoadmapState _state;
    NSString *_evidence;
}
@property (nonatomic) HCGRoadmapState state;
@property (nonatomic, copy) NSString *evidence;
@end

@interface HCGDevelopmentGap : NSObject {
    NSString *_stableID;
    NSString *_productID;
    NSString *_productName;
    NSString *_title;
    NSString *_detail;
    NSString *_kind;
    BOOL _blocking;
}
@property (nonatomic, copy) NSString *stableID;    // "nexus.<product>.<requirement>" (LifeOS stable ID rules)
@property (nonatomic, copy) NSString *productID;
@property (nonatomic, copy) NSString *productName;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *detail;
@property (nonatomic, copy) NSString *kind;
@property (nonatomic) BOOL blocking;
@end

@interface HCGLifeOSExport : NSObject {
    NSDictionary *_payload;
    NSArray *_included;
    NSArray *_changed;
    NSUInteger _alreadyExported;
    NSDictionary *_fingerprints;
}
@property (nonatomic, copy, nullable) NSDictionary *payload;          // lifeos.v1 import request; nil: nothing new
@property (nonatomic, copy) NSArray<NSString *> *included;            // stable IDs in the payload (tasks and project)
@property (nonatomic, copy) NSArray<NSString *> *changed;             // exported before with different text: update in LifeOS
@property (nonatomic) NSUInteger alreadyExported;                     // unchanged, skipped
@property (nonatomic, copy) NSDictionary<NSString *, NSString *> *fingerprints; // stable ID -> fingerprint, for marking
@end

@interface HCGCommandCenter : NSObject
+ (HCGConnectionSummary *)connectionForEntry:(HCGRegistryEntry *)entry
                                   hipStatus:(nullable HCGHIPProductStatus *)hip
                                      ledger:(nullable NSArray<NSDictionary *> *)ledger
                                    registry:(HCGRegistry *)registry
                                         now:(NSDate *)now;
+ (HCGRoadmapAssessment *)roadmapForEntry:(HCGRegistryEntry *)entry
                               connection:(HCGConnectionSummary *)connection
                                hipStatus:(nullable HCGHIPProductStatus *)hip;
+ (NSString *)titleForConnectionState:(HCGConnectionState)state;
// Integration progress, nine checkpoints, each from evidence (dimension, state, evidence): state is "done",
// "partial", "pending" or "not needed". Central registration, Authentication, API contract, Adapter implementation,
// Configuration, Successful communication, Capability validation, Physical testing, Security review. Being registered
// never makes a product connected; physical testing comes only from recorded device results.
+ (NSArray<NSArray<NSString *> *> *)integrationProgressForEntry:(HCGRegistryEntry *)entry
                                                     connection:(HCGConnectionSummary *)connection
                                                      hipStatus:(nullable HCGHIPProductStatus *)hip;
// The seven evidence layers, kept apart (title, value): Registered product, Installed application, Available service,
// Authenticated connection, Verified capability, Current connection health, Historical validation. A public read only
// ever fills "Available service"; "Authenticated connection" needs a signed or bearer-authorized exchange.
+ (NSArray<NSArray<NSString *> *> *)evidenceLayersForEntry:(HCGRegistryEntry *)entry
                                                connection:(HCGConnectionSummary *)connection
                                                 hipStatus:(nullable HCGHIPProductStatus *)hip
                                                    ledger:(nullable NSArray<NSDictionary *> *)ledger
                                                  registry:(HCGRegistry *)registry
                                                       now:(NSDate *)now;
+ (NSString *)titleForRoadmapState:(HCGRoadmapState)state;
+ (NSString *)keyForRoadmapState:(HCGRoadmapState)state;            // "adapter-implemented"
+ (HCGRoadmapState)roadmapStateForKey:(nullable NSString *)key found:(nullable BOOL *)found;

// Persistent roadmap: {entryID: {state, evidence, since, history: [{state, evidence, time}]}}. Returns the new store
// and whether anything changed. History grows only when a derived state changes (at most 12 per product).
+ (NSDictionary *)roadmapStore:(nullable NSDictionary *)store
           byRecordingAssessments:(NSDictionary<NSString *, HCGRoadmapAssessment *> *)assessments
                             now:(NSDate *)now
                         changed:(nullable BOOL *)changed;
+ (NSArray<NSDictionary *> *)roadmapHistoryForEntry:(NSString *)entryID store:(nullable NSDictionary *)store;

// Development gaps for the visible entries: the registry's requirements plus missing central registration or contract.
+ (NSArray<HCGDevelopmentGap *> *)gapsForEntries:(NSArray<HCGRegistryEntry *> *)entries;

// A lifeos.v1 import request for gaps not exported before (by stable ID and fingerprint). `exported` is the stored
// {stableID: fingerprint} map. `requestID` must be a UUID.
+ (HCGLifeOSExport *)lifeOSExportForGaps:(NSArray<HCGDevelopmentGap *> *)gaps
                                exported:(nullable NSDictionary *)exported
                         registryVersion:(NSInteger)registryVersion
                               requestID:(NSString *)requestID
                                     now:(NSDate *)now;
// The stored map after the user saved the export file.
+ (NSDictionary *)exportedStore:(nullable NSDictionary *)exported byMarking:(HCGLifeOSExport *)export_;

// Favorites: valid registry IDs, unique, at most 40.
+ (NSArray<NSString *> *)favoritesFromStoredValue:(nullable id)value;
@end

NS_ASSUME_NONNULL_END
