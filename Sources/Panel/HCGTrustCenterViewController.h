#import "HCGPanelTableViewController.h"

NS_ASSUME_NONNULL_BEGIN

// Package Trust Center (docs/TRUST-CENTER.md): repositories you trust and their keys, signature and checksum
// verification of what they publish, package metadata, Release Passports, declared and actual entitlements,
// device evidence, installed packages, security warnings and the HCG Sentinel monitoring checks.
// Read-only: it never installs, removes or changes a package, a source, Sileo, Zebra or APT. The only things it
// stores are the key fingerprints YOU pin and its own verified downloads.
@interface HCGTrustCenterViewController : HCGPanelTableViewController
@end

NS_ASSUME_NONNULL_END
