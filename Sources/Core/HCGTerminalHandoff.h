#import <Foundation/Foundation.h>
#import "HCGSettings.h" // HCGTerminalVariant (None / Standard / Unleashed), also the user's choice in settings

NS_ASSUME_NONNULL_BEGIN

// HCG Terminal / HCG Terminal Unleashed: names and links.
//
// The link contract is HCG Terminal's own TerminalDeepLink (HCG-Terminal
// HCGTerminalKit/Sources/TerminalUI/Model/HCGEcosystem.swift, since commit 871a8ac, shipped in Unleashed
// 0.2.0~rc1 and ~rc2):
//   standard  com.hakmicapitalgroup.hcgterminal            scheme hcgterminal
//   Unleashed com.hakmicapitalgroup.hcgterminal.unleashed  scheme hcgterminal-unleashed
//   <scheme>://open/<destination>   exactly one path component, no query: navigation only. A link never starts
//                                   a session, runs a command, changes a setting or passes text to a terminal.
// A build that declares its scheme in CFBundleURLTypes accepts these links (the scheme and the link handler
// arrived in the same commit). Destinations and their availability live in the HCG Interchange registry
// (HCGInterchange.m); the routes packages, processes and jailbreak-diagnostics are used only when the installed
// build declares them (Info.plist HCGInterchange), otherwise Nexus opens Unleashed Tools, one tap away.
//
// Installed, launchable and "has Nexus links" are separate facts (HCGHIPProductStatus). Opening the app is never
// "Connected": HCG Terminal shares no session with Nexus and keeps its own credentials.

@interface HCGTerminalHandoff : NSObject
+ (NSString *)bundleIdentifierForVariant:(HCGTerminalVariant)variant;
+ (NSString *)urlSchemeForVariant:(HCGTerminalVariant)variant;
+ (NSString *)displayNameForVariant:(HCGTerminalVariant)variant;
+ (HCGTerminalVariant)variantForBundleIdentifier:(nullable NSString *)bundleIdentifier;
// The HIP product identifier of the variant (HCGHIPProductTerminal / HCGHIPProductTerminalUnleashed).
+ (nullable NSString *)productIDForVariant:(HCGTerminalVariant)variant;

// <scheme>://open/dashboard for the variant (brings the app forward on its dashboard).
+ (nullable NSURL *)openURLForVariant:(HCGTerminalVariant)variant;

// nil when `text` is exactly one of the HCG Terminal links in the HCG Interchange registry; otherwise why it is
// refused. Matched as exact text, so nothing that could carry a command gets through.
+ (nullable NSString *)problemWithLinkText:(nullable NSString *)text;
// YES when the text starts with an HCG Terminal scheme (any letter case).
+ (BOOL)isTerminalLinkText:(nullable NSString *)text;
@end

NS_ASSUME_NONNULL_END
