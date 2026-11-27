#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// HCG UEM (Unified Endpoint Management) device status: a PROPOSED contract, hcg.uem.device-status/1 (docs/HCG-UEM.md).
// HCG UEM does not publish it yet, and Nexus has no connection to HCG UEM: this parser is prepared and tested, and
// nothing calls it with live data. When HCG UEM publishes the contract, the document must come from HCG UEM over an
// authenticated channel (HCG Connect / HCG Device Link), never from a file a user picks.
//
// Rules this code enforces:
//   * Trust tiers and their names come only from the document's own policy section (HCG UEM's authoritative policy).
//     Nothing is hard-coded: an unknown or missing tier is shown as "Not classified by HCG UEM policy".
//   * Nexus never assigns a tier, grants trust, or authorizes anything from this status. Device-specific permissions are
//     listed as HCG UEM states them; HCGUEMNexusMayAuthorize() is always NO.
//   * A jailbroken device never gains anything: its jailbreak is shown, and Nexus offers no administrative action.
//   * Suspended, revoked or expired states are shown as such and win over every other field.

FOUNDATION_EXPORT NSString *const HCGUEMDeviceStatusSchema;   // "hcg.uem.device-status/1" (proposed)
FOUNDATION_EXPORT BOOL HCGUEMNexusMayAuthorize(void);          // always NO

@interface HCGUEM : NSObject
// (title, value) rows describing the device, or nil when the document is not a valid hcg.uem.device-status/1.
+ (nullable NSArray<NSArray<NSString *> *> *)rowsFromDeviceStatus:(nullable NSData *)data error:(NSString *_Nullable *_Nullable)error;
@end

NS_ASSUME_NONNULL_END
