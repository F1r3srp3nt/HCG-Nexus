#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

// ---------------------------------------------------------------------------
// HCG Device Link (hcg.devicelink/1) — STANDALONE APP ONLY.
//
// The Objective-C side of Connected Devices: plain value objects the screens
// render, and the protocol of the service that fills them. The service is
// implemented in Swift (HCGDeviceLinkService.swift) on top of the vendored
// HCGDeviceLink package; this header is also the Swift bridging header's only
// import, so Xcode checks the Swift class against this protocol.
//
// Security rules (HCG-Server docs/DEVICE-LINK.md, docs/CONNECTED_DEVICES.md):
//   * HCG Connect says who the person is; HCG Server authorizes every request
//     with ERP App Access; the server owner approves each device. Nothing here
//     decides access.
//   * Capability advertisements are information only.
//   * Shared reports are DATA: rendered as plain text, never executed, never
//     turned into links, never handed to a URL handler.
//   * Action execution is disabled; pending approvals are always empty.
// ---------------------------------------------------------------------------

#ifndef NS_SWIFT_UI_ACTOR
#define NS_SWIFT_UI_ACTOR
#endif

typedef NS_ENUM(NSInteger, HCGLinkAccountState) {
    HCGLinkAccountStateNotConfigured = 0, // HCG has not issued Nexus's HCG Connect client: nothing is contacted
    HCGLinkAccountStateSignedOut = 1,
    HCGLinkAccountStateSignedIn = 2,
    HCGLinkAccountStateEnded = 3,         // HCG ended the session; sign in again
};

typedef NS_ENUM(NSInteger, HCGLinkConnectionState) {
    HCGLinkConnectionStateNotPaired = 0,
    HCGLinkConnectionStateAwaitingApproval = 1, // pairing requested; the owner compares fingerprints and approves
    HCGLinkConnectionStateConnected = 2,
    HCGLinkConnectionStateOffline = 3,          // retrying with back-off (retryInSeconds)
    HCGLinkConnectionStatePaused = 4,           // e.g. signed out; no automatic retry
    HCGLinkConnectionStateEnded = 5,            // rejected, expired, wrong account, key mismatch...: never retried
    HCGLinkConnectionStateRemoved = 6,          // the server removed (revoked) this device
    HCGLinkConnectionStatePaired = 7,           // approved, but not contacted since the app started: NOT "connected"
    HCGLinkConnectionStateAuthorityChanged = 8, // the server switched authority mode (authority_changed): pair again
};

// One capability another installation advertises. Information, never authorization.
@interface HCGLinkCapabilityInfo : NSObject
@property (nonatomic, copy) NSString *identifier; // e.g. report.receive
@property (nonatomic, copy) NSString *state;      // available | verified | unavailable | disabled
@property (nonatomic) BOOL usable;                // available or verified
@property (nonatomic, copy, nullable) NSString *reason;
@end

// A paired installation (this one is marked isThisDevice).
@interface HCGLinkDeviceInfo : NSObject
@property (nonatomic, copy) NSString *installationId;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *appName;           // "HCG Terminal", "HCG Sentinel", "HCG Nexus" or the raw identifier
@property (nonatomic, copy) NSString *appVersion;
@property (nonatomic, copy, nullable) NSString *variant; // "Vanilla" / "Unleashed" (display only)
@property (nonatomic, copy) NSString *platform;
@property (nonatomic, copy) NSString *presence;          // "Online", "Offline", "Never seen", "Revoked"
@property (nonatomic) BOOL online;
@property (nonatomic, strong, nullable) NSDate *lastSeen;
@property (nonatomic) BOOL isThisDevice;
@property (nonatomic, copy) NSString *keyFingerprint;    // display form
@property (nonatomic, copy) NSArray<HCGLinkCapabilityInfo *> *capabilities;
@end

// Inbox header (no report content).
@interface HCGLinkInboxItem : NSObject
@property (nonatomic, copy) NSString *messageId;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *fromName;
@property (nonatomic, copy) NSString *fromApp;
@property (nonatomic, strong) NSDate *receivedAt;
@property (nonatomic, strong) NSDate *expiresAt;
@property (nonatomic, copy) NSString *status; // queued | delivered | opened
@end

// One plain-text section of an opened report (HCGDeviceLink ReportTextRenderer).
@interface HCGLinkReportSection : NSObject
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSArray<NSString *> *lines;
@end

@interface HCGLinkOpenedReport : NSObject
@property (nonatomic, copy) NSString *messageId;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *fromName;
@property (nonatomic, copy) NSString *fromApp;
@property (nonatomic, strong) NSDate *receivedAt;
@property (nonatomic, copy) NSArray<HCGLinkReportSection *> *sections;
@end

// The server's computer, as HCG Server reports it (approved, non-sensitive facts only).
@interface HCGLinkHostInfo : NSObject
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *platform;
@property (nonatomic, copy, nullable) NSString *osVersion;
@property (nonatomic, copy) NSString *architecture;
@property (nonatomic, copy, nullable) NSString *cpuModel;
@property (nonatomic) NSInteger logicalCpus;
@property (nonatomic, strong, nullable) NSNumber *memoryTotalBytes;
@property (nonatomic, strong, nullable) NSNumber *memoryAvailableBytes;
@property (nonatomic, copy) NSArray<NSNumber *> *loadAverage;
@property (nonatomic, copy) NSString *agentVersion;
@property (nonatomic, strong) NSDate *agentStartedAt;
@property (nonatomic, copy) NSString *gatewayExposure; // loopback (the Mac only) | lan (approved for the local network)
@property (nonatomic, strong) NSDate *sampledAt;
@end

// One service HCG Server hosts (for example HCG System Tester). Real data from
// the server only; Nexus never shows a placeholder service.
@interface HCGLinkHostedServiceInfo : NSObject
@property (nonatomic, copy) NSString *identifier;      // e.g. system-tester
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *version;
@property (nonatomic, copy) NSString *runtime;
@property (nonatomic, copy) NSString *status;          // registered | starting | running | unhealthy | stopping | stopped | crashed | failed
@property (nonatomic, copy) NSString *health;          // ok | failing | unknown
@property (nonatomic, copy, nullable) NSString *detail;
@property (nonatomic, strong, nullable) NSNumber *uptimeSeconds;
@property (nonatomic) NSInteger restarts;
@property (nonatomic, strong, nullable) NSDate *lastHealthAt;
@property (nonatomic, copy) NSArray<NSString *> *capabilities;
@property (nonatomic) BOOL gatewayPublished;
@property (nonatomic) BOOL openable;                   // published and the gateway is approved for the local network
@end

// A single-use, 60-second link into one hosted service. Opened in the system
// browser only (Safari verifies the gateway with the HCG Server Local CA).
@interface HCGLinkOpenTicketInfo : NSObject
@property (nonatomic, strong) NSURL *url;
@property (nonatomic, strong) NSDate *expiresAt;
@property (nonatomic, copy) NSString *caFingerprint; // SHA-256, display form (pairs, as iOS shows it)
@property (nonatomic, copy) NSString *note;
@end

// Read-only, redacted server diagnostics as plain-text sections.
@interface HCGLinkDiagnosticsInfo : NSObject
@property (nonatomic, strong) NSDate *generatedAt;
@property (nonatomic, copy) NSString *serverName;
@property (nonatomic) BOOL localDevelopment;
@property (nonatomic, copy) NSArray<HCGLinkReportSection *> *sections;
@end

// What an invitation code says, parsed locally before anything is sent.
@interface HCGLinkInvitationPreview : NSObject
@property (nonatomic, copy, nullable) NSString *problem; // non-nil: not usable, and why
@property (nonatomic, copy) NSString *serverName;
@property (nonatomic, copy) NSString *serverAddress;
@property (nonatomic, copy) NSString *serverFingerprint;     // display form, pinned for TLS
@property (nonatomic, copy) NSString *thisDeviceFingerprint; // display form, the owner compares it
@property (nonatomic, strong, nullable) NSDate *expiresAt;
@property (nonatomic) BOOL localDevelopment; // the server is in local development pairing mode (no HCG account)
@end

// Everything the Connected Devices screen shows, as one immutable snapshot.
@interface HCGLinkSnapshot : NSObject
// HCG Connect account
@property (nonatomic) HCGLinkAccountState accountState;
@property (nonatomic, copy, nullable) NSString *accountDetail; // why not configured / why it ended
@property (nonatomic, copy, nullable) NSString *accountEmail;
// This device (LOCAL)
@property (nonatomic, copy) NSString *deviceName;
@property (nonatomic, copy) NSString *appVersion;
@property (nonatomic, copy, nullable) NSString *identityProblem;
@property (nonatomic, copy, nullable) NSString *installationShortId;
@property (nonatomic, copy, nullable) NSString *keyFingerprint; // display form
@property (nonatomic, copy, nullable) NSString *keyStorage;     // "Secure Enclave" / "Keychain (software)"
@property (nonatomic, copy) NSArray<HCGLinkCapabilityInfo *> *advertisedCapabilities;
// Connection to HCG Server
@property (nonatomic) HCGLinkConnectionState connectionState;
@property (nonatomic, copy, nullable) NSString *connectionDetail;
@property (nonatomic) NSTimeInterval retryInSeconds;
@property (nonatomic) BOOL pairingPending;  // a pairing request is waiting for the owner
@property (nonatomic) BOOL pairingApproved; // paired and approved (devices, reports and approvals apply)
@property (nonatomic, copy, nullable) NSString *serverName;
@property (nonatomic, copy, nullable) NSString *serverAddress;
@property (nonatomic, copy, nullable) NSString *serverFingerprint;            // display form
@property (nonatomic, copy, nullable) NSString *serverRecordedKeyFingerprint; // what the server says it received
@property (nonatomic, strong, nullable) NSDate *lastSync; // last fully successful sync round (a real server answer)
// Local development pairing (owner approval only, no HCG account; this one server only).
// Every screen showing such a connection shows HCGLinkLocalDevelopmentLabel.
@property (nonatomic) BOOL localDevelopment;
// Hosted services (HCG Server as a development host). Real server data only.
@property (nonatomic, strong, nullable) HCGLinkHostInfo *host;
@property (nonatomic, copy) NSArray<HCGLinkHostedServiceInfo *> *services;
@property (nonatomic) BOOL servicesLoaded;           // the server answered link/services at least once
@property (nonatomic, copy, nullable) NSString *servicesProblem;
// Paired devices, shared reports, approvals
@property (nonatomic, copy) NSArray<HCGLinkDeviceInfo *> *devices;
@property (nonatomic, copy, nullable) NSString *devicesProblem;
@property (nonatomic, copy) NSArray<HCGLinkInboxItem *> *inbox;
@property (nonatomic, copy, nullable) NSString *inboxProblem;
@property (nonatomic) NSInteger approvalsCount;
@property (nonatomic) BOOL executionEnabled;
@property (nonatomic, copy) NSString *approvalsNote;
@property (nonatomic, copy, nullable) NSString *approvalsProblem;
// UI
@property (nonatomic) BOOL busy;
@property (nonatomic, copy, nullable) NSString *notice; // one-shot message for the person
@end

// The Device Link service. Called on the main thread only; every completion
// and changeHandler call is delivered on the main thread.
NS_SWIFT_UI_ACTOR
@protocol HCGLinkServicing <NSObject>
+ (id<HCGLinkServicing>)sharedLinkService NS_SWIFT_NAME(sharedLinkService());
// The service if something already created it, else nil (never creates it: no Keychain key is made).
+ (nullable id<HCGLinkServicing>)existingLinkService NS_SWIFT_NAME(existingLinkService());
@property (nonatomic, readonly) HCGLinkSnapshot *snapshot;
@property (nonatomic, copy, nullable) void (^changeHandler)(void);
// Foreground sync runs only between these two calls (the screen is visible
// and the app is active): heartbeat every 20 s, inbox every 10 s.
- (void)screenDidAppear;
- (void)screenDidDisappear;
- (void)signInPresentingFromWindow:(nullable UIWindow *)window NS_SWIFT_NAME(signIn(presentingFrom:));
- (void)signOut;
- (HCGLinkInvitationPreview *)previewInvitationCode:(NSString *)code NS_SWIFT_NAME(previewInvitation(code:));
- (void)pairWithInvitationCode:(NSString *)code
                    completion:(void (^)(NSString *_Nullable problem))completion NS_SWIFT_NAME(pair(invitationCode:completion:));
// Fetches a shared report (data only) and acknowledges it as opened.
- (void)openReportWithMessageId:(NSString *)messageId
                     completion:(void (^)(HCGLinkOpenedReport *_Nullable report, NSString *_Nullable problem))completion
    NS_SWIFT_NAME(openReport(messageId:completion:));
// Asks the server for a single-use 60-second link to one hosted service (never
// opened here: the screen opens it in the system browser). `problemCode` is the
// server's error code, e.g. gateway_local_only.
- (void)openServiceWithIdentifier:(NSString *)serviceId
                       completion:(void (^)(HCGLinkOpenTicketInfo *_Nullable ticket, NSString *_Nullable problem,
                                            NSString *_Nullable problemCode))completion NS_SWIFT_NAME(openService(identifier:completion:));
// Read-only, redacted server diagnostics.
- (void)loadDiagnosticsWithCompletion:(void (^)(HCGLinkDiagnosticsInfo *_Nullable diagnostics, NSString *_Nullable problem))completion
    NS_SWIFT_NAME(loadDiagnostics(completion:));
// Tells the server (signed with the device key), then forgets the pairing and the key.
- (void)removeThisDeviceWithCompletion:(void (^)(NSString *message))completion NS_SWIFT_NAME(removeThisDevice(completion:));
// Forgets the pairing and the key on this device only.
- (void)forgetPairingOnThisDevice;
- (void)clearNotice;
@end

// The service linked into this build (the Swift class HCGLinkService), or nil
// if the build has none. Created on first use, never at app launch.
FOUNDATION_EXPORT id<HCGLinkServicing> _Nullable HCGSharedLinkService(void);

// HCGSharedLinkService() without creating it (nil until Connected Devices or the account screen used it).
FOUNDATION_EXPORT id<HCGLinkServicing> _Nullable HCGExistingLinkService(void);

// "LOCAL DEVELOPMENT — not an HCG account": shown wherever a local-development connection appears.
FOUNDATION_EXPORT NSString *const HCGLinkLocalDevelopmentLabel;

// "hcg.terminal" -> "HCG Terminal", etc.; unknown identifiers are returned unchanged.
FOUNDATION_EXPORT NSString *HCGLinkAppDisplayName(NSString *appIdentifier);

NS_ASSUME_NONNULL_END
