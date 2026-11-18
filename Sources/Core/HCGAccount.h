#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// HCG account (central HCG identity / HCG Connect) — rules shared by every build.
//
// Three states are never merged:
//   * ownership of HCG Nexus (HCG Store; candidate demos need none),
//   * being signed in (HCG Connect session, standalone app only),
//   * permission to use a connected service (central /check, per feature).
//
// Sign-in happens only in the standalone app (ASWebAuthenticationSession, PKCE S256,
// Keychain). The tweak and Settings bundle never hold tokens; at most they read an
// HCGAccountSummary, which by construction cannot carry one.

typedef NS_ENUM(NSInteger, HCGAccountState) {
    HCGAccountStateNotConfigured = 0, // HCG has not issued Nexus's HCG Connect client: nothing is contacted
    HCGAccountStateSignedOut = 1,
    HCGAccountStateSignedIn = 2,
    HCGAccountStateSessionEnded = 3,  // expired or revoked; sign in again
    HCGAccountStateUnavailableHere = 4, // this build never signs in (jailbreak tweak, Settings bundle, preview)
};

// The registration Nexus needs (docs/HCG-CONNECT-REGISTRATION.md).
FOUNDATION_EXPORT NSString *const HCGAccountIntegrationKey;     // hcg.nexus
FOUNDATION_EXPORT NSString *const HCGAccountProposedRedirectURI; // com.hakmicapitalgroup.hcgnexus.app://auth/callback
FOUNDATION_EXPORT NSString *const HCGAccountScopes;             // openid email profile

@interface HCGAccountConfiguration : NSObject {
    NSString *_clientID;
    NSString *_redirectURI;
    NSString *_problem;
}
@property (nonatomic, copy, readonly) NSString *clientID;
@property (nonatomic, copy, readonly) NSString *redirectURI;
// nil when usable. Otherwise why sign-in must stay off (shown as "Not configured").
@property (nonatomic, copy, readonly, nullable) NSString *problem;
@property (nonatomic, readonly) BOOL isConfigured;
// Values as read from the app's Info.plist (HCGConnectClientID / HCGConnectRedirectURI).
+ (instancetype)configurationWithClientID:(nullable id)clientID redirectURI:(nullable id)redirectURI;
// A client issued to another HCG product (Store, Executable Maker, HCG AI, ...). Never reused.
+ (BOOL)isKnownForeignClientID:(NSString *)clientID;
@end

@interface HCGAccountRules : NSObject
// Central permission check (POST /check): only HTTP 200 with a JSON boolean `allowed` == true grants.
// Anything else — other status, missing or non-boolean field, string "true", transport error — denies.
+ (BOOL)isPermissionGrantedWithHTTPStatus:(NSInteger)status response:(nullable id)response;
+ (NSString *)titleForState:(HCGAccountState)state;
// The exact request for the main-site team, as plain text.
+ (NSString *)registrationRequestText;
@end

// The only account information that may cross from the standalone app to the
// tweak: no tokens, no codes, no identifiers beyond what is displayed.
FOUNDATION_EXPORT NSString *const HCGAccountSummaryState;        // NSNumber (HCGAccountState)
FOUNDATION_EXPORT NSString *const HCGAccountSummaryDisplayName;  // NSString
FOUNDATION_EXPORT NSString *const HCGAccountSummaryOrganisation; // NSString
FOUNDATION_EXPORT NSString *const HCGAccountSummaryUpdated;      // NSNumber, seconds since 1970

@interface HCGAccountSummary : NSObject
// Keeps only the four keys above with the right types and plausible values. Returns nil
// if anything looks like a credential (JWT, bearer/token/secret/code fields, long opaque strings).
+ (nullable NSDictionary *)sanitizedSummary:(nullable id)candidate;
+ (BOOL)looksLikeCredential:(NSString *)value;
@end

NS_ASSUME_NONNULL_END
