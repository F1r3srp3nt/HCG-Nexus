#import "HCGToolCatalog.h"
#import "HCGWorkspace.h"

NSString *const HCGToolAppearance = @"tool.appearance";
NSString *const HCGToolCopyDiagnostics = @"tool.diagnostics.copy";
NSString *const HCGToolClearRecents = @"tool.recents.clear";
NSString *const HCGToolResetAppearance = @"tool.appearance.reset";
NSString *const HCGToolDisableNexus = @"tool.nexus.disable";
NSString *const HCGToolRepoPage = @"tool.repo.page";
NSString *const HCGToolImportShortcuts = @"tool.apps.import";
NSString *const HCGToolRestoreLayout = @"tool.layout.restore";

@implementation HCGToolInfo
@synthesize identifier = _identifier;
@synthesize title = _title;
@synthesize summary = _summary;
@synthesize symbolName = _symbolName;
@synthesize destructive = _destructive;
@end

static HCGToolInfo *HCGTool(NSString *identifier, NSString *title, NSString *summary, NSString *symbol, BOOL destructive) {
    HCGToolInfo *tool = [[HCGToolInfo alloc] init];
    tool.identifier = identifier;
    tool.title = title;
    tool.summary = summary;
    tool.symbolName = symbol;
    tool.destructive = destructive;
    return tool;
}

@implementation HCGToolCatalog

+ (NSArray *)allTools {
    return [NSArray arrayWithObjects:
        HCGTool(HCGToolAppearance, @"Appearance", @"Panel opacity and blur, edge handle, motion and haptics.", @"paintbrush", NO),
        HCGTool(HCGToolCopyDiagnostics, @"Copy Diagnostics", @"Copies a redacted report (build, device model, iOS, feature states) to the clipboard. Nothing is sent.", @"doc.on.clipboard", NO),
        HCGTool(HCGToolClearRecents, @"Clear Recent Actions", @"Forgets the recent-actions list. Shortcuts are kept.", @"clock.arrow.circlepath", YES),
        HCGTool(HCGToolResetAppearance, @"Reset Appearance", @"Restores panel and handle defaults. Workspaces, Apps and the enabled state are kept.", @"arrow.counterclockwise", YES),
        HCGTool(HCGToolDisableNexus, @"Turn Off HCG Nexus", @"Hides the edge handle until you turn Nexus on again in Settings › HCG Nexus.", @"power", YES),
        HCGTool(HCGToolRepoPage, @"HCG Repo Product Page", @"Opens the HCG Nexus page on HCG Repo in Safari.", @"safari", NO),
        HCGTool(HCGToolImportShortcuts, @"Import Workspace Shortcuts", @"Adds app and link shortcuts from your workspaces to Apps. Existing entries are kept.", @"square.and.arrow.down", NO),
        HCGTool(HCGToolRestoreLayout, @"Restore Previous Layout", @"Puts your workspaces back exactly as they were before this version's layout update and empties Apps.", @"arrow.uturn.backward", YES),
        nil];
}

+ (HCGToolInfo *)toolWithIdentifier:(NSString *)identifier {
    NSArray *tools = [self allTools];
    NSUInteger i;
    for (i = 0; i < tools.count; i++) {
        if ([[[tools objectAtIndex:i] identifier] isEqualToString:identifier]) return [tools objectAtIndex:i];
    }
    return nil;
}

+ (NSString *)unavailableReasonForTool:(NSString *)identifier environment:(HCGToolEnvironment)env {
    if (![self toolWithIdentifier:identifier]) return @"Unknown tool.";
    if ([identifier isEqualToString:HCGToolDisableNexus]) {
        if (env.host == HCGHostStandaloneApp) return @"The standalone app has no system-wide edge handle to turn off.";
        if (env.host == HCGHostPreview) return @"Preview harness: there is no SpringBoard handle to turn off.";
        return nil;
    }
    if ([identifier isEqualToString:HCGToolRepoPage]) {
        return env.hasLauncher ? nil : @"Links can't be opened from here. Open the page from the panel or the app.";
    }
    if ([identifier isEqualToString:HCGToolRestoreLayout]) {
        return env.layoutBackupExists ? nil : @"There is no earlier layout to restore on this device.";
    }
    return nil;
}

+ (NSArray *)defaultToolIdentifiersForPreset:(NSString *)preset {
    if ([preset isEqualToString:HCGPresetCommand]) {
        return [NSArray arrayWithObjects:HCGToolAppearance, HCGToolCopyDiagnostics, HCGToolClearRecents, nil];
    }
    if ([preset isEqualToString:HCGPresetDeveloper]) {
        return [NSArray arrayWithObjects:HCGToolCopyDiagnostics, HCGToolRepoPage, HCGToolAppearance, nil];
    }
    if ([preset isEqualToString:HCGPresetStudio]) {
        return [NSArray arrayWithObjects:HCGToolAppearance, HCGToolClearRecents, nil];
    }
    if ([preset isEqualToString:HCGPresetInfrastructure]) {
        return [NSArray arrayWithObjects:HCGToolCopyDiagnostics, HCGToolAppearance, nil];
    }
    return [NSArray arrayWithObjects:HCGToolAppearance, nil];
}

+ (NSArray *)validToolIdentifiers:(NSArray *)identifiers {
    NSMutableArray *out = [[NSMutableArray alloc] init];
    if (![identifiers isKindOfClass:[NSArray class]]) return out;
    NSUInteger i;
    for (i = 0; i < identifiers.count; i++) {
        id identifier = [identifiers objectAtIndex:i];
        if ([identifier isKindOfClass:[NSString class]] && [self toolWithIdentifier:identifier] && ![out containsObject:identifier]) {
            [out addObject:identifier];
        }
    }
    return out;
}

@end
