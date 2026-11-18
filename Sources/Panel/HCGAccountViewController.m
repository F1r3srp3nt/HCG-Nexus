#import "HCGAccountViewController.h"
#import "HCGTheme.h"
#import "HCGPanelServices.h"

typedef NS_ENUM(NSInteger, HCGAccountSection) {
    HCGAccountSectionIdentity = 0,
    HCGAccountSectionAccess = 1,
    HCGAccountSectionLocal = 2,
};

@implementation HCGAccountViewController {
    NSArray<NSArray<NSString *> *> *_identityRows;   // [title, value]
    NSArray<NSString *> *_buttons;                   // identity actions
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Account";
    [self modelDidChange];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self modelDidChange];
}

- (id<HCGAccountProviding>)provider {
    return self.context.accountProvider;
}

- (HCGAccountState)state {
    return [self provider] ? [[self provider] accountState] : HCGAccountStateUnavailableHere;
}

- (void)modelDidChange {
    id<HCGAccountProviding> provider = [self provider];
    HCGAccountState state = [self state];
    NSMutableArray *rows = [NSMutableArray arrayWithObject:@[ @"HCG account", [HCGAccountRules titleForState:state] ]];
    NSMutableArray *buttons = [NSMutableArray array];
    if (state == HCGAccountStateSignedIn) {
        [rows addObject:@[ @"Signed in as", [provider accountDisplayName] ?: @"Name not shared by the session" ]];
        NSArray<NSString *> *organisations = [provider organisationNames];
        [rows addObject:@[ @"Organisation", organisations ? (organisations.count ? [organisations componentsJoinedByString:@", "] : @"None")
                                                          : @"Not loaded (needs HCG's /me profile endpoint)" ]];
        [buttons addObject:@"Sign Out"];
    } else if (state == HCGAccountStateSignedOut || state == HCGAccountStateSessionEnded) {
        if ([provider canSignIn]) [buttons addObject:state == HCGAccountStateSessionEnded ? @"Sign In Again" : @"Sign In with HCG"];
    } else if (state == HCGAccountStateNotConfigured) {
        [buttons addObject:@"Copy Registration Request"];
    }
    _identityRows = rows;
    _buttons = buttons;
    [self.tableView reloadData];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 3;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    switch (section) {
        case HCGAccountSectionIdentity: return @"HCG sign-in";
        case HCGAccountSectionAccess: return @"Access (three separate checks)";
        default: return @"Works without signing in";
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section != HCGAccountSectionIdentity) return nil;
    switch ([self state]) {
        case HCGAccountStateUnavailableHere:
            return @"This build never signs in and never stores HCG tokens. Sign-in uses the standalone HCG Nexus app (system browser, PKCE, Keychain).";
        case HCGAccountStateNotConfigured:
            return [[self provider] accountDetail] ?: @"HCG has not issued an HCG Connect client for HCG Nexus yet, so nothing is contacted. Copy the registration request and send it to the HCG main-site team.";
        case HCGAccountStateSessionEnded:
            return [[self provider] accountDetail] ?: @"HCG ended the session (expired or revoked). Sign in again.";
        case HCGAccountStateSignedOut:
            return @"Signing in opens HCG's sign-in page in the system browser. Tokens stay in this app's Keychain and are never shared with the tweak.";
        case HCGAccountStateSignedIn:
            return @"Signing out ends this app's session only; HCG has no global sign-out.";
    }
    return nil;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch (section) {
        case HCGAccountSectionIdentity: return (NSInteger)(_identityRows.count + _buttons.count);
        case HCGAccountSectionAccess: return 3;
        default: return 1;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == HCGAccountSectionIdentity) {
        if ((NSUInteger)indexPath.row < _identityRows.count) {
            UITableViewCell *cell = [self styledCellWithStyle:UITableViewCellStyleValue1 identifier:@"value"];
            NSArray<NSString *> *row = _identityRows[(NSUInteger)indexPath.row];
            cell.textLabel.text = row[0];
            cell.detailTextLabel.text = row[1];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            if (indexPath.row == 0) cell.imageView.image = [HCGTheme symbolNamed:@"person.crop.circle" pointSize:18];
            return cell;
        }
        NSString *title = _buttons[(NSUInteger)indexPath.row - _identityRows.count];
        UITableViewCell *cell = [self styledCellWithStyle:UITableViewCellStyleDefault identifier:@"button"];
        cell.textLabel.text = title;
        cell.textLabel.textColor = [title isEqualToString:@"Sign Out"] ? [HCGTheme warning] : [HCGTheme cyan];
        cell.accessibilityTraits = UIAccessibilityTraitButton;
        return cell;
    }
    UITableViewCell *cell = [self styledCellWithStyle:UITableViewCellStyleSubtitle identifier:@"access"];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    if (indexPath.section == HCGAccountSectionLocal) {
        cell.textLabel.text = @"Workspaces, Apps, Tools, HCG Products and appearance";
        cell.detailTextLabel.text = @"Stored on this device only. No account, no network.";
        cell.imageView.image = [HCGTheme symbolNamed:@"lock.open" pointSize:17];
        return cell;
    }
    if (indexPath.row == 0) {
        cell.textLabel.text = @"Owning HCG Nexus";
        cell.detailTextLabel.text = HCGIsCandidateBuild() ? @"Free candidate demo: no ownership check."
                                                          : @"Checked by HCG Store when its delivery is live; not checked by this build.";
        cell.imageView.image = [HCGTheme symbolNamed:@"bag" pointSize:17];
    } else if (indexPath.row == 1) {
        cell.textLabel.text = @"Signed in";
        cell.detailTextLabel.text = [HCGAccountRules titleForState:[self state]];
        cell.imageView.image = [HCGTheme symbolNamed:@"person.badge.key" pointSize:17];
    } else {
        cell.textLabel.text = @"Connected services";
        cell.detailTextLabel.text = @"Each protected operation is checked by HCG per feature. Only an explicit \"allowed\" grants access; errors and offline deny.";
        cell.imageView.image = [HCGTheme symbolNamed:@"checkmark.shield" pointSize:17];
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section != HCGAccountSectionIdentity || (NSUInteger)indexPath.row < _identityRows.count) return;
    NSString *title = _buttons[(NSUInteger)indexPath.row - _identityRows.count];
    if ([title isEqualToString:@"Copy Registration Request"]) {
        [UIPasteboard generalPasteboard].string = [HCGAccountRules registrationRequestText];
        [self.context feedback:@"Registration request copied. Send it to the HCG main-site team." success:YES];
    } else if ([title isEqualToString:@"Sign Out"]) {
        [[self provider] signOut];
        [self.context feedback:@"Signed out of HCG on this app." success:YES];
        [self modelDidChange];
    } else {
        [[self provider] signInFromViewController:self];
    }
}

@end
