#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// Where Nexus is running. Mirrors HCGPanelMode without UIKit (Core is Foundation-only).
typedef NS_ENUM(NSInteger, HCGHost) {
    HCGHostOverlay = 0,       // jailbreak package, SpringBoard overlay
    HCGHostSettingsApp = 1,   // jailbreak package, Settings › HCG Nexus
    HCGHostStandaloneApp = 2, // sandboxed iPhone/iPad app
    HCGHostPreview = 3,       // preview harness (simulation)
};

// Tool identifiers. Every tool is a real local action; nothing here reports
// system statistics or contacts a server.
FOUNDATION_EXPORT NSString *const HCGToolAppearance;       // panel opacity, blur, handle
FOUNDATION_EXPORT NSString *const HCGToolCopyDiagnostics;  // redacted report to the clipboard
FOUNDATION_EXPORT NSString *const HCGToolClearRecents;
FOUNDATION_EXPORT NSString *const HCGToolResetAppearance;
FOUNDATION_EXPORT NSString *const HCGToolDisableNexus;     // jailbreak overlay only
FOUNDATION_EXPORT NSString *const HCGToolRepoPage;         // HCG Repo product page (needs a launcher)
FOUNDATION_EXPORT NSString *const HCGToolImportShortcuts;  // copy workspace shortcuts into Apps
FOUNDATION_EXPORT NSString *const HCGToolRestoreLayout;    // undo the layout-2 migration

// What the host can do, as plain flags.
typedef struct {
    HCGHost host;
    BOOL hasLauncher;        // can open links (overlay, app, preview)
    BOOL layoutBackupExists; // HCGLayoutMigration has a backup to restore
} HCGToolEnvironment;

@interface HCGToolInfo : NSObject {
    NSString *_identifier;
    NSString *_title;
    NSString *_summary;
    NSString *_symbolName;
    BOOL _destructive;
}
@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *summary;
@property (nonatomic, copy) NSString *symbolName;
@property (nonatomic) BOOL destructive;    // asks for confirmation first
@end

@interface HCGToolCatalog : NSObject
+ (NSArray<HCGToolInfo *> *)allTools;
+ (nullable HCGToolInfo *)toolWithIdentifier:(NSString *)identifier;
// nil when the tool works here; otherwise why it doesn't (shown instead of a dead button).
+ (nullable NSString *)unavailableReasonForTool:(NSString *)identifier environment:(HCGToolEnvironment)environment;
// Pinned by default for a workspace preset (layout migration and new workspaces).
+ (NSArray<NSString *> *)defaultToolIdentifiersForPreset:(NSString *)preset;
// Drops unknown identifiers and duplicates, keeping order.
+ (NSArray<NSString *> *)validToolIdentifiers:(nullable NSArray *)identifiers;
@end

NS_ASSUME_NONNULL_END
