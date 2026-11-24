#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// The panel's top-level sections (layout 2), in section-bar order.
typedef NS_ENUM(NSInteger, HCGNexusSection) {
    HCGNexusSectionOverview = 0,
    HCGNexusSectionWorkspaces,
    HCGNexusSectionTools,
    HCGNexusSectionProducts,
    HCGNexusSectionDevices,
    HCGNexusSectionApps,
    HCGNexusSectionAccount,
    HCGNexusSectionCount,
};

static inline NSString *HCGSectionTitle(HCGNexusSection section) {
    switch (section) {
        case HCGNexusSectionOverview: return @"Overview";
        case HCGNexusSectionWorkspaces: return @"Workspaces";
        case HCGNexusSectionTools: return @"Tools";
        case HCGNexusSectionProducts: return @"Ecosystem";
        case HCGNexusSectionDevices: return @"Devices";
        case HCGNexusSectionApps: return @"Apps";
        case HCGNexusSectionAccount: return @"Account";
        default: return @"";
    }
}

static inline NSString *HCGSectionSymbol(HCGNexusSection section) {
    switch (section) {
        case HCGNexusSectionOverview: return @"square.grid.2x2";
        case HCGNexusSectionWorkspaces: return @"square.stack.3d.up";
        case HCGNexusSectionTools: return @"wrench.and.screwdriver";
        case HCGNexusSectionProducts: return @"cube.box";
        case HCGNexusSectionDevices: return @"link";
        case HCGNexusSectionApps: return @"app.badge";
        case HCGNexusSectionAccount: return @"person.crop.circle";
        default: return @"circle";
    }
}

NS_ASSUME_NONNULL_END
