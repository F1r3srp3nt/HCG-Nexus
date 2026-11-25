#import "HCGConnectedDevicesViewController.h"
#import "HCGLinkReportViewController.h"
#import "HCGLinkDiagnosticsViewController.h"
#import "HCGTheme.h"

typedef NS_ENUM(NSInteger, HCGDevicesAction) {
    HCGDevicesActionNone = 0,
    HCGDevicesActionDismissNotice,
    HCGDevicesActionSignIn,
    HCGDevicesActionSignOut,
    HCGDevicesActionPair,
    HCGDevicesActionOpenReport,
    HCGDevicesActionRemove,
    HCGDevicesActionForget,
    HCGDevicesActionOpenService,
    HCGDevicesActionDiagnostics,
};

// One table row, built from the service snapshot.
@interface HCGDevicesRow : NSObject
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *detail;
@property (nonatomic, copy) NSString *tag;      // LOCAL / REMOTE
@property (nonatomic, copy) NSString *symbol;
@property (nonatomic) BOOL monospacedDetail;
@property (nonatomic) BOOL destructive;
@property (nonatomic) BOOL emphasised;
@property (nonatomic) BOOL caution;             // warning colour, no action (e.g. the local development label)
@property (nonatomic) HCGDevicesAction action;
@property (nonatomic, copy) NSString *payload;  // message id for reports, service id for hosted services
@end

@implementation HCGDevicesRow
+ (instancetype)rowWithTitle:(NSString *)title detail:(NSString *)detail {
    HCGDevicesRow *row = [[HCGDevicesRow alloc] init];
    row.title = title;
    row.detail = detail;
    return row;
}
@end

@interface HCGDevicesSectionModel : NSObject
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *footer;
@property (nonatomic, strong) NSMutableArray<HCGDevicesRow *> *rows;
@end

@implementation HCGDevicesSectionModel
+ (instancetype)sectionWithTitle:(NSString *)title footer:(NSString *)footer {
    HCGDevicesSectionModel *section = [[HCGDevicesSectionModel alloc] init];
    section.title = title;
    section.footer = footer;
    section.rows = [NSMutableArray array];
    return section;
}
- (HCGDevicesRow *)add:(NSString *)title detail:(NSString *)detail {
    HCGDevicesRow *row = [HCGDevicesRow rowWithTitle:title detail:detail];
    [self.rows addObject:row];
    return row;
}
@end

@implementation HCGConnectedDevicesViewController {
    NSArray<HCGDevicesSectionModel *> *_sections;
    NSDateFormatter *_dateFormatter;
    BOOL _visible;
}

- (instancetype)initWithContext:(HCGPanelContext *)context service:(id<HCGLinkServicing>)service {
    if ((self = [super initWithContext:context])) {
        _service = service;
        _dateFormatter = [[NSDateFormatter alloc] init];
        _dateFormatter.dateStyle = NSDateFormatterMediumStyle;
        _dateFormatter.timeStyle = NSDateFormatterShortStyle;
        _dateFormatter.doesRelativeDateFormatting = YES;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Connected Devices";
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self selector:@selector(appBecameActive) name:UIApplicationDidBecomeActiveNotification object:nil];
    [nc addObserver:self selector:@selector(appResignedActive) name:UIApplicationWillResignActiveNotification object:nil];
    [self rebuild];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    _visible = YES;
    // The service is shared; whichever Connected Devices screen is on screen receives its changes.
    __weak typeof(self) weakSelf = self;
    self.service.changeHandler = ^{
        [weakSelf rebuild];
    };
    [self.service screenDidAppear];
    [self rebuild];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    _visible = NO;
    [self.service screenDidDisappear];
}

// Sync only while this screen is on screen AND the app is in the foreground.
- (void)appBecameActive {
    if (_visible) [self.service screenDidAppear];
}

- (void)appResignedActive {
    if (_visible) [self.service screenDidDisappear];
}

- (void)modelDidChange {
    [self rebuild];
}

#pragma mark Formatting

- (NSString *)formatDate:(NSDate *)date {
    return date ? [_dateFormatter stringFromDate:date] : @"never";
}

- (NSString *)capabilityLine:(HCGLinkCapabilityInfo *)capability {
    NSString *line = [NSString stringWithFormat:@"%@: %@", capability.identifier, capability.state];
    if (capability.reason.length) line = [line stringByAppendingFormat:@" — %@", capability.reason];
    return line;
}

- (NSString *)deviceDetail:(HCGLinkDeviceInfo *)device {
    NSMutableArray<NSString *> *app = [NSMutableArray arrayWithObject:device.appName];
    if (device.variant.length) [app addObject:device.variant];
    if (device.appVersion.length) [app addObject:device.appVersion];
    if (device.platform.length) [app addObject:device.platform];
    NSMutableArray<NSString *> *lines = [NSMutableArray arrayWithObject:[app componentsJoinedByString:@" · "]];
    if (device.online) {
        [lines addObject:@"Online"];
    } else if (device.lastSeen) {
        [lines addObject:[NSString stringWithFormat:@"%@ · last seen %@", device.presence, [self formatDate:device.lastSeen]]];
    } else {
        [lines addObject:device.presence];
    }
    if (device.capabilities.count == 0) {
        [lines addObject:@"Advertises no capabilities"];
    }
    for (HCGLinkCapabilityInfo *capability in device.capabilities) [lines addObject:[self capabilityLine:capability]];
    return [lines componentsJoinedByString:@"\n"];
}

- (NSString *)connectionTitle:(HCGLinkSnapshot *)s {
    switch (s.connectionState) {
        case HCGLinkConnectionStateNotPaired: return @"Not paired";
        case HCGLinkConnectionStateAwaitingApproval: return @"Awaiting approval";
        case HCGLinkConnectionStateConnected: return @"Connected";
        case HCGLinkConnectionStateOffline: return @"Offline";
        case HCGLinkConnectionStatePaused: return @"Paused";
        case HCGLinkConnectionStateEnded: return @"Disconnected";
        case HCGLinkConnectionStateRemoved: return @"Removed by the server";
        case HCGLinkConnectionStatePaired: return @"Paired — not contacted yet";
        case HCGLinkConnectionStateAuthorityChanged: return @"Server authority changed — pair again";
    }
    return @"Unknown";
}

#pragma mark Model

- (void)rebuild {
    if (!self.isViewLoaded) return;
    NSMutableArray<HCGDevicesSectionModel *> *sections = [NSMutableArray array];
    id<HCGLinkServicing> service = self.service;
    if (!service) {
        HCGDevicesSectionModel *none = [HCGDevicesSectionModel sectionWithTitle:@"Connected devices"
                                                                         footer:@"HCG Device Link is part of the standalone HCG Nexus app built with Xcode. The jailbreak package and Settings bundle never connect to HCG Server."];
        [none add:@"Not available in this build" detail:@"This build does not include the HCG Device Link client."];
        _sections = sections;
        [sections addObject:none];
        [self.tableView reloadData];
        return;
    }
    HCGLinkSnapshot *s = service.snapshot;

    if (s.notice.length) {
        HCGDevicesSectionModel *notice = [HCGDevicesSectionModel sectionWithTitle:@"Notice" footer:nil];
        HCGDevicesRow *row = [notice add:s.notice detail:@"Tap to dismiss"];
        row.symbol = @"info.circle";
        row.action = HCGDevicesActionDismissNotice;
        [sections addObject:notice];
    }

    [sections addObject:[self accountSection:s]];
    [sections addObject:[self thisDeviceSection:s]];
    [sections addObject:[self serverSection:s]];
    if (s.pairingApproved) {
        [sections addObject:[self hostSection:s]];
        [sections addObject:[self servicesSection:s]];
        [sections addObject:[self diagnosticsSection:s]];
        [sections addObject:[self devicesSection:s]];
        [sections addObject:[self reportsSection:s]];
        [sections addObject:[self approvalsSection:s]];
    }
    if (s.serverName.length) [sections addObject:[self removeSection:s]];

    _sections = sections;
    [self.tableView reloadData];
    [self updateBusyIndicator:s.busy];
}

- (void)updateBusyIndicator:(BOOL)busy {
    if (!busy) {
        self.navigationItem.rightBarButtonItem = nil;
        return;
    }
    UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    spinner.color = [HCGTheme cyan];
    spinner.accessibilityLabel = @"Working";
    [spinner startAnimating];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:spinner];
}

- (HCGDevicesSectionModel *)accountSection:(HCGLinkSnapshot *)s {
    HCGDevicesSectionModel *section = [HCGDevicesSectionModel sectionWithTitle:@"HCG Connect account"
                                                                        footer:@"HCG Connect identifies you. HCG Server checks every request with HCG's ERP App Access, and the server's owner approves each device; Nexus never decides access itself. Signing out is local: HCG Server stops accepting a session once HCG reports it ended."];
    if (s.localDevelopment) {
        section.footer = [section.footer stringByAppendingFormat:@" The paired HCG Server is in local development pairing mode (%@): that pairing uses no HCG account and sends no HCG Connect token.", HCGLinkLocalDevelopmentLabel];
    }
    HCGDevicesRow *row;
    switch (s.accountState) {
        case HCGLinkAccountStateNotConfigured:
            row = [section add:@"Not configured" detail:s.accountDetail ?: @"HCG has not issued an HCG Connect client for HCG Nexus yet, so sign-in is not configured. Nothing is contacted."];
            row.symbol = @"person.crop.circle.badge.xmark";
            break;
        case HCGLinkAccountStateSignedOut:
            row = [section add:@"Signed out" detail:nil];
            row.symbol = @"person.crop.circle";
            row = [section add:@"Sign in with HCG Connect" detail:nil];
            row.emphasised = YES;
            row.action = HCGDevicesActionSignIn;
            break;
        case HCGLinkAccountStateSignedIn:
            row = [section add:@"Signed in" detail:s.accountEmail.length ? s.accountEmail : @"HCG account"];
            row.symbol = @"person.crop.circle.badge.checkmark";
            row = [section add:@"Sign out on this device" detail:nil];
            row.emphasised = YES;
            row.action = HCGDevicesActionSignOut;
            break;
        case HCGLinkAccountStateEnded:
            row = [section add:@"Session ended" detail:s.accountDetail];
            row.symbol = @"person.crop.circle.badge.exclamationmark";
            row = [section add:@"Sign in again" detail:nil];
            row.emphasised = YES;
            row.action = HCGDevicesActionSignIn;
            break;
    }
    return section;
}

- (HCGDevicesSectionModel *)thisDeviceSection:(HCGLinkSnapshot *)s {
    HCGDevicesSectionModel *section = [HCGDevicesSectionModel sectionWithTitle:@"This device"
                                                                        footer:@"The device key never leaves this device. The server's owner compares its fingerprint before approving it. Capabilities are information for other devices; they never grant access."];
    HCGDevicesRow *row = [section add:s.deviceName.length ? s.deviceName : @"This device"
                               detail:[NSString stringWithFormat:@"HCG Nexus %@ (standalone app)", s.appVersion]];
    row.tag = @"LOCAL";
    row.symbol = @"iphone";
    if (s.identityProblem.length) {
        [section add:@"Device key" detail:s.identityProblem];
        return section;
    }
    if (s.installationShortId.length) [section add:@"Installation" detail:s.installationShortId].monospacedDetail = YES;
    if (s.keyStorage.length) [section add:@"Key storage" detail:s.keyStorage];
    if (s.keyFingerprint.length) [section add:@"Key fingerprint" detail:s.keyFingerprint].monospacedDetail = YES;
    NSMutableArray<NSString *> *caps = [NSMutableArray array];
    for (HCGLinkCapabilityInfo *capability in s.advertisedCapabilities) [caps addObject:[self capabilityLine:capability]];
    [section add:@"Advertises" detail:caps.count ? [caps componentsJoinedByString:@"\n"] : @"Nothing"].monospacedDetail = YES;
    return section;
}

- (HCGDevicesSectionModel *)serverSection:(HCGLinkSnapshot *)s {
    BOOL active = s.pairingPending || s.pairingApproved;
    BOOL canPair = !active && (s.connectionState == HCGLinkConnectionStateNotPaired || s.connectionState == HCGLinkConnectionStateEnded ||
                               s.connectionState == HCGLinkConnectionStateRemoved || s.connectionState == HCGLinkConnectionStateAuthorityChanged);
    NSString *footer;
    if (canPair) {
        footer = @"On the computer running HCG Server, create an invitation and enter its code here (it starts with hcg1-). Nexus first shows the server's name and key; after you request pairing, the server's owner approves this device after comparing its key fingerprint. If the invitation says the server is in local development pairing mode, no HCG account is needed and the connection is labelled LOCAL DEVELOPMENT — not an HCG account.";
    } else if (s.pairingPending) {
        footer = @"Waiting for the server's owner to approve this device. They should see this device's key fingerprint shown above; if it differs, they must reject the request.";
    } else {
        footer = @"Nexus contacts the server only while this screen is open and the app is in the foreground: a heartbeat every 20 s and the inbox every 10 s. The server's key is pinned from the invitation; a server with any other key is refused.";
    }
    HCGDevicesSectionModel *section = [HCGDevicesSectionModel sectionWithTitle:s.serverName.length ? @"HCG Server" : @"Pair device" footer:footer];

    if (s.serverName.length) {
        NSString *detail = s.connectionDetail;
        if (s.connectionState == HCGLinkConnectionStateOffline) {
            detail = [NSString stringWithFormat:@"%@ Retrying in %.0f s.", s.connectionDetail ?: @"HCG Server could not be reached.", s.retryInSeconds];
        } else if (s.connectionState == HCGLinkConnectionStateConnected) {
            detail = s.lastSync ? [NSString stringWithFormat:@"Last sync %@", [self formatDate:s.lastSync]] : @"The server answered; full sync pending.";
        } else if (s.connectionState == HCGLinkConnectionStatePaired) {
            detail = @"Approved earlier. Nexus has not reached the server since it was opened; it connects while this screen is open.";
        } else if (s.connectionState == HCGLinkConnectionStateAwaitingApproval) {
            detail = @"The server's owner has not approved this device yet.";
        }
        HCGDevicesRow *status = [section add:[self connectionTitle:s] detail:detail];
        status.symbol = s.connectionState == HCGLinkConnectionStateConnected ? @"checkmark.circle" : @"exclamationmark.circle";
        if (s.localDevelopment) {
            HCGDevicesRow *label = [section add:HCGLinkLocalDevelopmentLabel
                                         detail:@"Paired with the server owner's approval only. No HCG account is used and no HCG token is sent; access covers this one server only, never HCG services. Remote actions are always refused."];
            label.caution = YES;
            label.symbol = @"hammer";
        }
        [section add:@"Server" detail:s.serverName];
        if (s.serverAddress.length) [section add:@"Address" detail:s.serverAddress].monospacedDetail = YES;
        if (s.serverFingerprint.length) [section add:@"Server key" detail:s.serverFingerprint].monospacedDetail = YES;
        if (s.pairingPending) {
            [section add:@"This device's key (owner compares)" detail:s.keyFingerprint ?: @"unavailable"].monospacedDetail = YES;
            if (s.serverRecordedKeyFingerprint.length) {
                BOOL same = [s.serverRecordedKeyFingerprint isEqualToString:s.keyFingerprint ?: @""];
                [section add:same ? @"Key received by the server (matches)" : @"Key received by the server (DOES NOT MATCH)"
                      detail:s.serverRecordedKeyFingerprint].monospacedDetail = YES;
            }
        }
    } else if (s.connectionDetail.length) {
        HCGDevicesRow *status = [section add:[self connectionTitle:s] detail:s.connectionDetail];
        status.symbol = @"exclamationmark.circle";
    }
    if (canPair) {
        HCGDevicesRow *pair = [section add:s.connectionState == HCGLinkConnectionStateAuthorityChanged ? @"Pair again: enter a new invitation code…" : @"Enter invitation code…"
                                    detail:s.accountState == HCGLinkAccountStateSignedIn ? nil : @"Needs an HCG Connect sign-in, unless the server is in local development pairing mode."];
        pair.emphasised = YES;
        pair.symbol = @"link";
        pair.action = HCGDevicesActionPair;
    }
    return section;
}

- (NSString *)durationText:(NSNumber *)seconds {
    long long v = MAX(0LL, seconds.longLongValue);
    if (v < 60) return [NSString stringWithFormat:@"%lld s", v];
    if (v < 3600) return [NSString stringWithFormat:@"%lld min", v / 60];
    if (v < 86400) return [NSString stringWithFormat:@"%lld h %lld min", v / 3600, (v % 3600) / 60];
    return [NSString stringWithFormat:@"%lld d %lld h", v / 86400, (v % 86400) / 3600];
}

- (NSString *)availabilityText:(HCGLinkSnapshot *)s {
    switch (s.connectionState) {
        case HCGLinkConnectionStateConnected:
            return s.lastSync ? [NSString stringWithFormat:@"Reachable · last answer %@", [self formatDate:s.lastSync]] : @"Reachable";
        case HCGLinkConnectionStateOffline:
            return [NSString stringWithFormat:@"Unreachable: %@", s.connectionDetail ?: @"no answer"];
        case HCGLinkConnectionStatePaused:
            return [NSString stringWithFormat:@"Not contacted: %@", s.connectionDetail ?: @"sync is paused"];
        default:
            return @"Not contacted yet";
    }
}

// The server's computer: only what HCG Server reported (link/services), never placeholders.
- (HCGDevicesSectionModel *)hostSection:(HCGLinkSnapshot *)s {
    NSString *footer = @"Facts HCG Server chose to share about its computer: no user names, paths or addresses.";
    if (s.localDevelopment) footer = [NSString stringWithFormat:@"%@. %@", HCGLinkLocalDevelopmentLabel, footer];
    HCGDevicesSectionModel *section = [HCGDevicesSectionModel sectionWithTitle:@"Connected host" footer:footer];
    HCGDevicesRow *availability = [section add:@"Host availability" detail:[self availabilityText:s]];
    availability.symbol = s.connectionState == HCGLinkConnectionStateConnected ? @"checkmark.circle" : @"exclamationmark.circle";
    HCGLinkHostInfo *h = s.host;
    if (!h) {
        [section add:@"Host" detail:s.servicesProblem.length ? s.servicesProblem : @"Not reported yet. It appears after the first successful sync."];
        return section;
    }
    HCGDevicesRow *row = [section add:h.name.length ? h.name : @"HCG Server's computer"
                               detail:[NSString stringWithFormat:@"%@%@ · %@", h.platform, h.osVersion.length ? [@" " stringByAppendingString:h.osVersion] : @"", h.architecture]];
    row.tag = @"REMOTE";
    row.symbol = @"desktopcomputer";
    NSMutableArray<NSString *> *cpu = [NSMutableArray array];
    if (h.cpuModel.length) [cpu addObject:h.cpuModel];
    if (h.logicalCpus > 0) [cpu addObject:[NSString stringWithFormat:@"%ld logical CPUs", (long)h.logicalCpus]];
    if (h.loadAverage.count) {
        NSMutableArray<NSString *> *loads = [NSMutableArray array];
        for (NSNumber *n in h.loadAverage) [loads addObject:[NSString stringWithFormat:@"%.2f", n.doubleValue]];
        [cpu addObject:[@"load " stringByAppendingString:[loads componentsJoinedByString:@" "]]];
    }
    if (cpu.count) [section add:@"CPU" detail:[cpu componentsJoinedByString:@" · "]];
    if (h.memoryTotalBytes) {
        NSString *total = [NSByteCountFormatter stringFromByteCount:h.memoryTotalBytes.longLongValue countStyle:NSByteCountFormatterCountStyleMemory];
        NSString *free = h.memoryAvailableBytes ? [NSByteCountFormatter stringFromByteCount:h.memoryAvailableBytes.longLongValue countStyle:NSByteCountFormatterCountStyleMemory] : nil;
        [section add:@"Memory" detail:free ? [NSString stringWithFormat:@"%@ available of %@", free, total] : total];
    }
    [section add:@"HCG Server" detail:[NSString stringWithFormat:@"Agent %@ · running since %@", h.agentVersion, [self formatDate:h.agentStartedAt]]];
    [section add:@"Gateway" detail:[h.gatewayExposure isEqualToString:@"lan"] ? @"Approved for the local network by the owner"
                                                                               : @"Reachable from the Mac only (the owner has not approved local-network access)"];
    [section add:@"Reported" detail:[self formatDate:h.sampledAt]];
    return section;
}

- (NSString *)serviceDetail:(HCGLinkHostedServiceInfo *)v {
    NSMutableArray<NSString *> *lines = [NSMutableArray array];
    NSMutableArray<NSString *> *first = [NSMutableArray arrayWithObject:v.status];
    [first addObject:[@"health " stringByAppendingString:v.health]];
    if (v.uptimeSeconds) [first addObject:[@"up " stringByAppendingString:[self durationText:v.uptimeSeconds]]];
    if (v.restarts > 0) [first addObject:[NSString stringWithFormat:@"%ld restart%@", (long)v.restarts, v.restarts == 1 ? @"" : @"s"]];
    [lines addObject:[first componentsJoinedByString:@" · "]];
    if (v.detail.length) [lines addObject:v.detail];
    if (v.lastHealthAt) [lines addObject:[NSString stringWithFormat:@"Last health check %@", [self formatDate:v.lastHealthAt]]];
    [lines addObject:v.capabilities.count ? [@"Capabilities: " stringByAppendingString:[v.capabilities componentsJoinedByString:@", "]] : @"Capabilities: none reported"];
    if (v.openable) [lines addObject:@"Tap to open in Safari"];
    else if (v.gatewayPublished) [lines addObject:@"Published, but the gateway is reachable from the Mac only until the owner approves local-network access. Tap for details."];
    else [lines addObject:@"Not published through the gateway"];
    return [lines componentsJoinedByString:@"\n"];
}

- (HCGDevicesSectionModel *)servicesSection:(HCGLinkSnapshot *)s {
    NSString *footer = @"What HCG Server hosts, with its own lifecycle and health. Opening asks the server for a single-use link valid for 60 seconds and hands it to Safari, which verifies the gateway with the HCG Server Local CA. Nexus has no built-in browser and never skips that check.";
    if (s.localDevelopment) footer = [NSString stringWithFormat:@"%@. %@", HCGLinkLocalDevelopmentLabel, footer];
    HCGDevicesSectionModel *section = [HCGDevicesSectionModel sectionWithTitle:@"Hosted services" footer:footer];
    if (s.servicesProblem.length) [section add:@"Could not list hosted services" detail:s.servicesProblem];
    for (HCGLinkHostedServiceInfo *v in s.services) {
        NSString *title = v.version.length ? [NSString stringWithFormat:@"%@ %@", v.name, v.version] : v.name;
        HCGDevicesRow *row = [section add:title detail:[self serviceDetail:v]];
        row.symbol = [v.health isEqualToString:@"ok"] ? @"checkmark.seal" : ([v.health isEqualToString:@"failing"] ? @"xmark.octagon" : @"questionmark.circle");
        if (v.gatewayPublished) {
            row.action = HCGDevicesActionOpenService;
            row.payload = v.identifier;
        }
    }
    if (!s.servicesProblem.length && s.services.count == 0) {
        [section add:s.servicesLoaded ? @"No hosted services" : @"Not loaded yet"
              detail:s.servicesLoaded ? @"HCG Server reported no hosted services." : @"Hosted services appear after the first successful sync."];
    }
    return section;
}

- (HCGDevicesSectionModel *)diagnosticsSection:(HCGLinkSnapshot *)s {
    HCGDevicesSectionModel *section = [HCGDevicesSectionModel sectionWithTitle:@"Diagnostics"
                                                                        footer:@"Read-only. HCG Server redacts its diagnostics before sending them: no logs, addresses or credentials."];
    HCGDevicesRow *row = [section add:@"Connection diagnostics" detail:@"Server, TLS and gateway, hosted services, security events"];
    row.symbol = @"stethoscope";
    row.action = HCGDevicesActionDiagnostics;
    return section;
}

- (HCGDevicesSectionModel *)devicesSection:(HCGLinkSnapshot *)s {
    HCGDevicesSectionModel *section = [HCGDevicesSectionModel sectionWithTitle:@"Paired devices"
                                                                        footer:@"REMOTE devices are other HCG apps paired with the same server. Presence comes from the server's last-seen time. Capabilities are what each device says about itself and never grant access."];
    if (s.devicesProblem.length) [section add:@"Could not list devices" detail:s.devicesProblem];
    for (HCGLinkDeviceInfo *device in s.devices) {
        HCGDevicesRow *row = [section add:device.name.length ? device.name : @"Unnamed device" detail:[self deviceDetail:device]];
        row.tag = device.isThisDevice ? @"LOCAL" : @"REMOTE";
        row.symbol = device.online ? @"circle.fill" : @"circle";
    }
    if (s.devices.count == 0 && !s.devicesProblem.length) {
        [section add:@"No devices listed yet" detail:@"Paired devices appear after the first sync."];
    }
    return section;
}

- (HCGDevicesSectionModel *)reportsSection:(HCGLinkSnapshot *)s {
    HCGDevicesSectionModel *section = [HCGDevicesSectionModel sectionWithTitle:@"Shared reports"
                                                                        footer:@"Reports are data. Nexus shows them as plain text and never opens links, runs commands or executes anything in them. A report expires at the latest 7 days after it was shared."];
    if (s.inboxProblem.length) [section add:@"Could not read the inbox" detail:s.inboxProblem];
    for (HCGLinkInboxItem *item in s.inbox) {
        NSString *detail = [NSString stringWithFormat:@"From %@ (%@, remote) · received %@ · %@", item.fromName, item.fromApp,
                                                      [self formatDate:item.receivedAt], item.status];
        HCGDevicesRow *row = [section add:item.title.length ? item.title : @"Untitled report" detail:detail];
        row.symbol = [item.status isEqualToString:@"opened"] ? @"doc.text" : @"doc.badge.plus";
        row.action = HCGDevicesActionOpenReport;
        row.payload = item.messageId;
    }
    if (s.inbox.count == 0 && !s.inboxProblem.length) {
        [section add:@"No shared reports" detail:@"Reports that other paired devices share with this one appear here."];
    }
    return section;
}

- (HCGDevicesSectionModel *)approvalsSection:(HCGLinkSnapshot *)s {
    HCGDevicesSectionModel *section = [HCGDevicesSectionModel sectionWithTitle:@"Pending approvals" footer:nil];
    if (s.approvalsProblem.length) [section add:@"Could not read approvals" detail:s.approvalsProblem];
    NSString *title = s.approvalsCount == 0 ? @"None" : [NSString stringWithFormat:@"%ld pending", (long)s.approvalsCount];
    [section add:title detail:s.approvalsNote];
    [section add:@"Remote actions" detail:@"Disabled. HCG Nexus never runs anything another device sends, and the server's action registry is empty in this version."];
    return section;
}

- (HCGDevicesSectionModel *)removeSection:(HCGLinkSnapshot *)s {
    HCGDevicesSectionModel *section = [HCGDevicesSectionModel sectionWithTitle:@"Remove this device"
                                                                        footer:@"Removing tells the server (signed with this device's key) and deletes the key on this device. To connect again you need a new invitation and the owner's approval."];
    if (s.pairingPending || s.pairingApproved) {
        HCGDevicesRow *remove = [section add:@"Disconnect and remove this device" detail:nil];
        remove.destructive = YES;
        remove.action = HCGDevicesActionRemove;
    }
    HCGDevicesRow *forget = [section add:@"Forget pairing on this device only" detail:@"The server keeps listing this device until its owner revokes it."];
    forget.destructive = YES;
    forget.action = HCGDevicesActionForget;
    return section;
}

#pragma mark Table

- (HCGDevicesRow *)rowAt:(NSIndexPath *)indexPath {
    return _sections[(NSUInteger)indexPath.section].rows[(NSUInteger)indexPath.row];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return (NSInteger)_sections.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return (NSInteger)_sections[(NSUInteger)section].rows.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return _sections[(NSUInteger)section].title;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    return _sections[(NSUInteger)section].footer;
}

- (UILabel *)tagLabel:(NSString *)text {
    UILabel *label = [[UILabel alloc] init];
    label.text = [NSString stringWithFormat:@" %@ ", text];
    label.font = [HCGTheme fontForTextStyle:UIFontTextStyleCaption2 weight:UIFontWeightBold];
    label.adjustsFontForContentSizeCategory = YES;
    BOOL local = [text isEqualToString:@"LOCAL"];
    label.textColor = local ? [HCGTheme success] : [HCGTheme cyan];
    label.backgroundColor = [HCGTheme cyanSoft];
    label.layer.cornerRadius = 6;
    label.layer.masksToBounds = YES;
    label.textAlignment = NSTextAlignmentCenter;
    label.isAccessibilityElement = NO;
    [label sizeToFit];
    CGRect frame = label.frame;
    frame.size.width += 8;
    frame.size.height += 6;
    label.frame = frame;
    return label;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    HCGDevicesRow *row = [self rowAt:indexPath];
    UITableViewCell *cell = [self styledCellWithStyle:UITableViewCellStyleSubtitle identifier:@"device-link"];
    cell.textLabel.text = row.title;
    cell.detailTextLabel.text = row.detail;
    UIFont *detailFont = row.monospacedDetail
        ? [[UIFontMetrics metricsForTextStyle:UIFontTextStyleFootnote] scaledFontForFont:[UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightRegular]]
        : [HCGTheme fontForTextStyle:UIFontTextStyleFootnote weight:UIFontWeightRegular];
    cell.detailTextLabel.font = detailFont;
    cell.textLabel.font = [HCGTheme fontForTextStyle:UIFontTextStyleBody weight:row.emphasised || row.destructive || row.caution ? UIFontWeightSemibold : UIFontWeightMedium];
    cell.textLabel.numberOfLines = 0;
    if (row.destructive || row.caution) cell.textLabel.textColor = [HCGTheme warning];
    else if (row.emphasised) cell.textLabel.textColor = [HCGTheme cyan];
    if (row.symbol.length) {
        cell.imageView.image = [HCGTheme symbolNamed:row.symbol pointSize:17];
        cell.imageView.tintColor = row.destructive || row.caution ? [HCGTheme warning] : [HCGTheme cyan];
    }
    if (row.tag.length) cell.accessoryView = [self tagLabel:row.tag];
    else if (row.action == HCGDevicesActionOpenReport || row.action == HCGDevicesActionDiagnostics) cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    cell.selectionStyle = row.action == HCGDevicesActionNone ? UITableViewCellSelectionStyleNone : UITableViewCellSelectionStyleDefault;

    NSMutableArray<NSString *> *spoken = [NSMutableArray arrayWithObject:row.title];
    if (row.tag.length) [spoken addObject:[row.tag isEqualToString:@"LOCAL"] ? @"this device" : @"remote device"];
    cell.accessibilityLabel = [spoken componentsJoinedByString:@", "];
    cell.accessibilityValue = row.detail;
    cell.accessibilityTraits = row.action == HCGDevicesActionNone ? UIAccessibilityTraitStaticText : UIAccessibilityTraitButton;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    HCGDevicesRow *row = [self rowAt:indexPath];
    switch (row.action) {
        case HCGDevicesActionNone:
            break;
        case HCGDevicesActionDismissNotice:
            [self.service clearNotice];
            break;
        case HCGDevicesActionSignIn:
            [self.service signInPresentingFromWindow:self.view.window];
            break;
        case HCGDevicesActionSignOut:
            [self confirmSignOut];
            break;
        case HCGDevicesActionPair:
            [self promptForInvitationWithText:nil];
            break;
        case HCGDevicesActionOpenReport:
            if (row.payload) [self openReport:row.payload];
            break;
        case HCGDevicesActionRemove:
            [self confirmRemove];
            break;
        case HCGDevicesActionForget:
            [self confirmForget];
            break;
        case HCGDevicesActionOpenService:
            if (row.payload) [self openService:row.payload name:row.title];
            break;
        case HCGDevicesActionDiagnostics:
            [self openDiagnostics];
            break;
    }
}

#pragma mark Actions

- (void)present:(UIAlertController *)alert {
    alert.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    [self presentViewController:alert animated:!UIAccessibilityIsReduceMotionEnabled() completion:nil];
}

- (void)showMessage:(NSString *)message title:(NSString *)title {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
    [self present:alert];
}

- (void)confirmSignOut {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Sign out of HCG Connect?"
                                                                   message:@"Nexus stops syncing with HCG Server until you sign in again. The pairing and this device's key are kept."
                                                            preferredStyle:UIAlertControllerStyleAlert];
    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Sign Out" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a) {
        [weakSelf.service signOut];
    }]];
    [self present:alert];
}

- (void)promptForInvitationWithText:(NSString *)text {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Pair with HCG Server"
                                                                   message:@"Paste the invitation code from HCG Server on your computer. It starts with hcg1- and works once."
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.placeholder = @"hcg1-…";
        field.text = text;
        field.autocapitalizationType = UITextAutocapitalizationTypeNone;
        field.autocorrectionType = UITextAutocorrectionTypeNo;
        field.spellCheckingType = UITextSpellCheckingTypeNo;
        field.smartQuotesType = UITextSmartQuotesTypeNo;
        field.smartDashesType = UITextSmartDashesTypeNo;
        field.smartInsertDeleteType = UITextSmartInsertDeleteTypeNo;
        field.keyboardType = UIKeyboardTypeASCIICapable;
        field.clearButtonMode = UITextFieldViewModeWhileEditing;
        field.font = [UIFont monospacedSystemFontOfSize:14 weight:UIFontWeightRegular];
        field.accessibilityLabel = @"Invitation code";
    }];
    __weak typeof(self) weakSelf = self;
    __weak UIAlertController *weakAlert = alert;
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Continue" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        [weakSelf reviewInvitation:weakAlert.textFields.firstObject.text ?: @""];
    }]];
    [self present:alert];
}

// Shows what the code says (parsed on this device; nothing is sent yet) so the
// person can compare the server's key and this device's key before pairing.
- (void)reviewInvitation:(NSString *)code {
    HCGLinkInvitationPreview *preview = [self.service previewInvitationCode:code];
    __weak typeof(self) weakSelf = self;
    if (preview.problem) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Invitation not usable" message:preview.problem
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
        [alert addAction:[UIAlertAction actionWithTitle:@"Try Again" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
            [weakSelf promptForInvitationWithText:code];
        }]];
        [self present:alert];
        return;
    }
    NSMutableString *message = [NSMutableString string];
    if (preview.localDevelopment) {
        [message appendFormat:@"%@\n\nThis server is in local development pairing mode: its owner approves this device, no HCG account is used and no HCG token is sent. Access covers this one server only, never HCG services, and remote actions are always refused.\n\n", HCGLinkLocalDevelopmentLabel];
    }
    [message appendFormat:@"Server: %@\nAddress: %@\n\nServer key:\n%@\n\nThis device's key:\n%@", preview.serverName, preview.serverAddress,
                          preview.serverFingerprint, preview.thisDeviceFingerprint];
    if (preview.expiresAt) [message appendFormat:@"\n\nThe invitation expires %@.", [self formatDate:preview.expiresAt]];
    [message appendString:@"\n\nCheck that the server key matches HCG Server on your computer. Its owner approves this device after comparing this device's key."];
    UIAlertController *confirm = [UIAlertController alertControllerWithTitle:preview.localDevelopment ? @"Request local development pairing?" : @"Request pairing?"
                                                                     message:message
                                                              preferredStyle:UIAlertControllerStyleAlert];
    [confirm addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [confirm addAction:[UIAlertAction actionWithTitle:@"Request Pairing" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        [weakSelf.service pairWithInvitationCode:code completion:^(NSString *problem) {
            if (problem) [weakSelf showMessage:problem title:@"Pairing not requested"];
        }];
    }]];
    [self present:confirm];
}

- (void)openReport:(NSString *)messageId {
    __weak typeof(self) weakSelf = self;
    [self updateBusyIndicator:YES];
    [self.service openReportWithMessageId:messageId completion:^(HCGLinkOpenedReport *report, NSString *problem) {
        HCGConnectedDevicesViewController *strongSelf = weakSelf;
        if (!strongSelf) return;
        [strongSelf updateBusyIndicator:strongSelf.service.snapshot.busy];
        if (!report) {
            [strongSelf showMessage:problem ?: @"The report could not be opened." title:@"Report not opened"];
            return;
        }
        HCGLinkReportViewController *viewer = [[HCGLinkReportViewController alloc] initWithContext:strongSelf.context report:report];
        [strongSelf.navigationController pushViewController:viewer animated:!UIAccessibilityIsReduceMotionEnabled()];
    }];
}

// Hosted services open in the system browser only, after the person has seen the gateway CA's SHA-256.
- (void)openService:(NSString *)serviceId name:(NSString *)name {
    __weak typeof(self) weakSelf = self;
    [self updateBusyIndicator:YES];
    [self.service openServiceWithIdentifier:serviceId completion:^(HCGLinkOpenTicketInfo *ticket, NSString *problem, NSString *code) {
        HCGConnectedDevicesViewController *strongSelf = weakSelf;
        if (!strongSelf) return;
        [strongSelf updateBusyIndicator:strongSelf.service.snapshot.busy];
        if (!ticket) {
            NSString *title = [code isEqualToString:@"gateway_local_only"] ? [NSString stringWithFormat:@"%@ is reachable on the Mac only", name] : @"Not opened";
            [strongSelf showMessage:problem ?: @"HCG Server did not provide a link." title:title];
            return;
        }
        [strongSelf confirmOpenTicket:ticket name:name];
    }];
}

- (void)confirmOpenTicket:(HCGLinkOpenTicketInfo *)ticket name:(NSString *)name {
    NSDateFormatter *time = [[NSDateFormatter alloc] init];
    time.dateStyle = NSDateFormatterNoStyle;
    time.timeStyle = NSDateFormatterMediumStyle;
    NSMutableString *message = [NSMutableString string];
    if (self.service.snapshot.localDevelopment) [message appendFormat:@"%@\n\n", HCGLinkLocalDevelopmentLabel];
    [message appendFormat:@"Safari checks the gateway with the HCG Server Local CA. Its SHA-256 must match Settings › General › About › Certificate Trust Settings › HCG Server Local CA and HCG Server on your Mac:\n\n%@", ticket.caFingerprint];
    if (ticket.note.length) [message appendFormat:@"\n\n%@", ticket.note];
    [message appendFormat:@"\n\nThe link works once, until %@.", [time stringFromDate:ticket.expiresAt]];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:[NSString stringWithFormat:@"Open %@ in Safari?", name] message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Open in Safari" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        if ([ticket.expiresAt timeIntervalSinceNow] <= 0) {
            [weakSelf showMessage:@"The single-use link expired (it is valid for 60 seconds). Tap the service again for a new one." title:@"Link expired"];
            return;
        }
        // The system browser, never an in-app web view: Safari does its own certificate validation.
        [[UIApplication sharedApplication] openURL:ticket.url options:@{} completionHandler:^(BOOL opened) {
            if (!opened) [weakSelf showMessage:@"iOS did not open the link in Safari." title:@"Not opened"];
        }];
    }]];
    [self present:alert];
}

- (void)openDiagnostics {
    __weak typeof(self) weakSelf = self;
    [self updateBusyIndicator:YES];
    [self.service loadDiagnosticsWithCompletion:^(HCGLinkDiagnosticsInfo *diagnostics, NSString *problem) {
        HCGConnectedDevicesViewController *strongSelf = weakSelf;
        if (!strongSelf) return;
        [strongSelf updateBusyIndicator:strongSelf.service.snapshot.busy];
        if (!diagnostics) {
            [strongSelf showMessage:problem ?: @"HCG Server did not return diagnostics." title:@"Diagnostics not loaded"];
            return;
        }
        HCGLinkDiagnosticsViewController *viewer = [[HCGLinkDiagnosticsViewController alloc] initWithContext:strongSelf.context diagnostics:diagnostics];
        [strongSelf.navigationController pushViewController:viewer animated:!UIAccessibilityIsReduceMotionEnabled()];
    }];
}

- (void)confirmRemove {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Remove this device from the server?"
                                                                   message:@"The server stops accepting this device at once and this device's key is deleted. To connect again you need a new invitation and the owner's approval."
                                                            preferredStyle:UIAlertControllerStyleAlert];
    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Remove" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a) {
        [weakSelf.service removeThisDeviceWithCompletion:^(NSString *message) {
            [weakSelf showMessage:message title:@"Remove this device"];
        }];
    }]];
    [self present:alert];
}

- (void)confirmForget {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Forget the pairing on this device?"
                                                                   message:@"The server is not told. Nexus forgets the server and deletes this device's key; ask the server's owner to revoke the old entry."
                                                            preferredStyle:UIAlertControllerStyleAlert];
    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Forget" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a) {
        [weakSelf.service forgetPairingOnThisDevice];
    }]];
    [self present:alert];
}

@end
