#import "HCGWorkspacePresets.h"
#import "HCGIntegrations.h"

static HCGAction *App(NSString *title, NSString *bundle, NSString *symbol) {
    return [HCGAction actionWithKind:HCGActionKindApp title:title target:bundle symbol:symbol];
}

static HCGAction *Integration(NSString *identifier) {
    return [HCGAction actionWithKind:HCGActionKindIntegration
                               title:[HCGIntegrationCatalog displayNameForIdentifier:identifier]
                              target:identifier
                              symbol:[HCGIntegrationCatalog symbolNameForIdentifier:identifier]];
}

@implementation HCGWorkspacePresets

+ (NSArray *)presetIdentifiers {
    return [NSArray arrayWithObjects:HCGPresetCommand, HCGPresetDeveloper, HCGPresetStudio, HCGPresetInfrastructure, nil];
}

+ (NSString *)displayNameForPreset:(NSString *)preset {
    if ([preset isEqualToString:HCGPresetCommand]) return @"Command";
    if ([preset isEqualToString:HCGPresetDeveloper]) return @"Developer";
    if ([preset isEqualToString:HCGPresetStudio]) return @"Studio";
    if ([preset isEqualToString:HCGPresetInfrastructure]) return @"Infrastructure";
    return @"Custom";
}

+ (NSString *)summaryForPreset:(NSString *)preset {
    if ([preset isEqualToString:HCGPresetCommand]) return @"Daily planning, mail, notes and HCG News.";
    if ([preset isEqualToString:HCGPresetDeveloper]) return @"HCG Terminal, Executable Maker, Files and Shortcuts.";
    if ([preset isEqualToString:HCGPresetStudio]) return @"Camera, Photos, Voice Memos and Music.";
    if ([preset isEqualToString:HCGPresetInfrastructure]) return @"HCG Server, Terminal and build tooling.";
    return @"An empty workspace for your own shortcuts.";
}

+ (NSString *)symbolNameForPreset:(NSString *)preset {
    if ([preset isEqualToString:HCGPresetCommand]) return @"command";
    if ([preset isEqualToString:HCGPresetDeveloper]) return @"chevron.left.forwardslash.chevron.right";
    if ([preset isEqualToString:HCGPresetStudio]) return @"camera.aperture";
    if ([preset isEqualToString:HCGPresetInfrastructure]) return @"server.rack";
    return @"square.grid.2x2";
}

+ (NSArray *)actionsForPreset:(NSString *)preset {
    if ([preset isEqualToString:HCGPresetCommand]) {
        return [NSArray arrayWithObjects:
                App(@"Safari", @"com.apple.mobilesafari", @"safari"),
                App(@"Calendar", @"com.apple.mobilecal", @"calendar"),
                App(@"Reminders", @"com.apple.reminders", @"checklist"),
                App(@"Notes", @"com.apple.mobilenotes", @"note.text"),
                App(@"Mail", @"com.apple.mobilemail", @"envelope"),
                Integration(HCGIntegrationNews),
                App(@"Settings", @"com.apple.Preferences", @"gearshape"),
                nil];
    }
    if ([preset isEqualToString:HCGPresetDeveloper]) {
        return [NSArray arrayWithObjects:
                Integration(HCGIntegrationTerminal),
                Integration(HCGIntegrationExecutableMaker),
                App(@"Files", @"com.apple.DocumentsApp", @"folder"),
                App(@"Shortcuts", @"com.apple.shortcuts", @"square.2.layers.3d"),
                App(@"Safari", @"com.apple.mobilesafari", @"safari"),
                nil];
    }
    if ([preset isEqualToString:HCGPresetStudio]) {
        return [NSArray arrayWithObjects:
                App(@"Camera", @"com.apple.camera", @"camera"),
                App(@"Photos", @"com.apple.mobileslideshow", @"photo.on.rectangle"),
                App(@"Voice Memos", @"com.apple.VoiceMemos", @"waveform"),
                App(@"Music", @"com.apple.Music", @"music.note"),
                App(@"Notes", @"com.apple.mobilenotes", @"note.text"),
                nil];
    }
    if ([preset isEqualToString:HCGPresetInfrastructure]) {
        return [NSArray arrayWithObjects:
                Integration(HCGIntegrationServer),
                Integration(HCGIntegrationTerminal),
                Integration(HCGIntegrationExecutableMaker),
                App(@"Settings", @"com.apple.Preferences", @"gearshape"),
                nil];
    }
    return [NSArray array];
}

+ (HCGWorkspace *)workspaceForPreset:(NSString *)preset name:(NSString *)name {
    BOOL known = [[self presetIdentifiers] containsObject:preset];
    NSString *kind = known ? preset : HCGPresetCustom;
    NSString *finalName = name.length > 0 ? name : [self displayNameForPreset:kind];
    HCGWorkspace *workspace = [[HCGWorkspace alloc] initWithName:finalName preset:kind];
    [workspace replaceActions:[self actionsForPreset:kind]];
    return workspace;
}

@end
