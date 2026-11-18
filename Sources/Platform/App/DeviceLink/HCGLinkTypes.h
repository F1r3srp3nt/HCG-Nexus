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

// What an invitation code says, parsed locally before anything is sent.
@interface HCGLinkInvitationPreview : NSObject
@property (nonatomic, copy, nullable) NSString *problem; // non-nil: not usable, and why
@property (nonatomic, copy) NSString *serverName;
@property (nonatomic, copy) NSString *serverAddress;
@property (nonatomic, copy) NSString *serverFingerprint;     // display form, pinned for TLS
@property (nonatomic, copy) NSString *thisDeviceFingerprint; // display form, the owner compares it
@property (nonatomic, strong, nullable) NSDate *expiresAt;
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
@property (nonatomic, strong, nullable) NSDate *lastSync;
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
// Tells the server (signed with the device key), then forgets the pairing and the key.
- (void)removeThisDeviceWithCompletion:(void (^)(NSString *message))completion NS_SWIFT_NAME(removeThisDevice(completion:));
// Forgets the pairing and the key on this device only.
- (void)forgetPairingOnThisDevice;
- (void)clearNotice;
@end

// The service linked into this build (the Swift class HCGLinkService), or nil
// if the build has none. Created on first use, never at app launch.
FOUNDATION_EXPORT id<HCGLinkServicing> _Nullable HCGSharedLinkService(void);

// "hcg.terminal" -> "HCG Terminal", etc.; unknown identifiers are returned unchanged.
FOUNDATION_EXPORT NSString *HCGLinkAppDisplayName(NSString *appIdentifier);

NS_ASSUME_NONNULL_END
