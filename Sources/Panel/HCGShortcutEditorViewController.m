#import "HCGShortcutEditorViewController.h"
#import "HCGTheme.h"

typedef NS_ENUM(NSInteger, HCGEditorRow) {
    HCGEditorRowKind,
    HCGEditorRowName,
    HCGEditorRowTarget,
};

@interface HCGShortcutEditorViewController () <UITextFieldDelegate>
@end

@implementation HCGShortcutEditorViewController {
    NSString *_workspaceIdentifier;
    UISegmentedControl *_kindControl;
    UISegmentedControl *_integrationControl;
    UITextField *_nameField;
    UITextField *_targetField;
    NSString *_errorText;
}

- (instancetype)initWithContext:(HCGPanelContext *)context workspaceIdentifier:(NSString *)identifier {
    if ((self = [super initWithContext:context])) {
        _workspaceIdentifier = [identifier copy];
    }
    return self;
}

- (UITextField *)makeField:(NSString *)placeholder label:(NSString *)label {
    UITextField *field = [[UITextField alloc] init];
    field.attributedPlaceholder = [[NSAttributedString alloc] initWithString:placeholder attributes:@{ NSForegroundColorAttributeName : [HCGTheme secondaryText] }];
    field.textColor = [HCGTheme primaryText];
    field.tintColor = [HCGTheme cyan];
    field.font = [HCGTheme fontForTextStyle:UIFontTextStyleBody weight:UIFontWeightRegular];
    field.adjustsFontForContentSizeCategory = YES;
    field.clearButtonMode = UITextFieldViewModeWhileEditing;
    field.delegate = self;
    field.accessibilityLabel = label;
    field.translatesAutoresizingMaskIntoConstraints = NO;
    return field;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"New Shortcut";
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Save" style:UIBarButtonItemStyleDone target:self action:@selector(save)];

    _kindControl = [[UISegmentedControl alloc] initWithItems:@[ @"App", @"Link", @"HCG" ]];
    _kindControl.selectedSegmentIndex = 0;
    _kindControl.selectedSegmentTintColor = [HCGTheme cyanSoft];
    [_kindControl setTitleTextAttributes:@{ NSForegroundColorAttributeName : [HCGTheme primaryText] } forState:UIControlStateNormal];
    _kindControl.accessibilityLabel = @"Shortcut type";
    [_kindControl addTarget:self action:@selector(kindChanged) forControlEvents:UIControlEventValueChanged];

    NSMutableArray *names = [NSMutableArray array];
    for (NSString *identifier in [HCGIntegrationCatalog allIdentifiers]) {
        [names addObject:[[HCGIntegrationCatalog displayNameForIdentifier:identifier] stringByReplacingOccurrencesOfString:@"HCG " withString:@""]];
    }
    _integrationControl = [[UISegmentedControl alloc] initWithItems:names];
    _integrationControl.selectedSegmentIndex = 0;
    _integrationControl.selectedSegmentTintColor = [HCGTheme cyanSoft];
    [_integrationControl setTitleTextAttributes:@{ NSForegroundColorAttributeName : [HCGTheme primaryText] } forState:UIControlStateNormal];
    _integrationControl.accessibilityLabel = @"HCG integration";
    _integrationControl.apportionsSegmentWidthsByContent = YES;

    _nameField = [self makeField:@"Name" label:@"Shortcut name"];
    _nameField.autocapitalizationType = UITextAutocapitalizationTypeWords;
    _targetField = [self makeField:@"" label:@"Target"];
    _targetField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    _targetField.autocorrectionType = UITextAutocorrectionTypeNo;
    [self kindChanged];
}

- (HCGActionKind)selectedKind {
    switch (_kindControl.selectedSegmentIndex) {
        case 1: return HCGActionKindURL;
        case 2: return HCGActionKindIntegration;
        default: return HCGActionKindApp;
    }
}

- (void)kindChanged {
    HCGActionKind kind = [self selectedKind];
    _targetField.keyboardType = kind == HCGActionKindURL ? UIKeyboardTypeURL : UIKeyboardTypeASCIICapable;
    NSString *placeholder = kind == HCGActionKindURL ? @"https://example.com" : @"com.apple.mobilenotes";
    _targetField.attributedPlaceholder = [[NSAttributedString alloc] initWithString:placeholder attributes:@{ NSForegroundColorAttributeName : [HCGTheme secondaryText] }];
    _targetField.accessibilityLabel = kind == HCGActionKindURL ? @"Link URL" : @"App bundle identifier";
    _errorText = nil;
    [self.tableView reloadData];
}

- (void)save {
    HCGActionKind kind = [self selectedKind];
    NSString *target = _targetField.text ?: @"";
    NSString *title = _nameField.text ?: @"";
    NSString *symbol = kind == HCGActionKindURL ? @"link" : @"app";
    if (kind == HCGActionKindIntegration) {
        NSArray *identifiers = [HCGIntegrationCatalog allIdentifiers];
        NSInteger index = MAX(0, _integrationControl.selectedSegmentIndex);
        target = identifiers[(NSUInteger)index];
        symbol = [HCGIntegrationCatalog symbolNameForIdentifier:target];
        if (title.length == 0) title = [HCGIntegrationCatalog displayNameForIdentifier:target];
    }
    HCGAction *action = [HCGAction actionWithKind:kind title:title target:target symbol:symbol];
    NSError *error = nil;
    if (![self.context.model.workspaceStore addAction:action toWorkspace:_workspaceIdentifier error:&error]) {
        _errorText = [NSString stringWithFormat:@"%@ %@", error.localizedDescription ?: @"", error.localizedRecoverySuggestion ?: @""];
        [self.tableView reloadData];
        UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, _errorText);
        return;
    }
    [self.context.model workspacesDidChange];
    [self.view endEditing:YES];
    [self.navigationController popViewControllerAnimated:!UIAccessibilityIsReduceMotionEnabled()];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    if (textField == _nameField && [self selectedKind] != HCGActionKindIntegration) {
        [_targetField becomeFirstResponder];
    } else {
        [self save];
    }
    return YES;
}

#pragma mark Table

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 3;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (_errorText.length) return _errorText;
    switch ([self selectedKind]) {
        case HCGActionKindApp: return @"Enter the app's bundle identifier. If the app isn't installed, Nexus tells you when you open the shortcut.";
        case HCGActionKindURL: return @"https links open in the default browser. Other schemes need an installed app that handles them.";
        case HCGActionKindIntegration: return @"HCG integrations show \"Not connected\" until they are set up in HCG Nexus settings.";
    }
    return nil;
}

- (void)tableView:(UITableView *)tableView willDisplayFooterView:(UIView *)view forSection:(NSInteger)section {
    [super tableView:tableView willDisplayFooterView:view forSection:section];
    if (_errorText.length && [view isKindOfClass:[UITableViewHeaderFooterView class]]) {
        ((UITableViewHeaderFooterView *)view).textLabel.textColor = [HCGTheme warning];
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [self styledCellWithStyle:UITableViewCellStyleDefault identifier:[NSString stringWithFormat:@"row%ld", (long)indexPath.row]];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    UIView *content = nil;
    switch ((HCGEditorRow)indexPath.row) {
        case HCGEditorRowKind: content = _kindControl; break;
        case HCGEditorRowName: content = _nameField; break;
        case HCGEditorRowTarget: content = [self selectedKind] == HCGActionKindIntegration ? _integrationControl : _targetField; break;
    }
    for (UIView *sub in cell.contentView.subviews) {
        if (sub != content) [sub removeFromSuperview];
    }
    if (content.superview != cell.contentView) {
        [content removeFromSuperview];
        content.translatesAutoresizingMaskIntoConstraints = NO;
        [cell.contentView addSubview:content];
        UILayoutGuide *margins = cell.contentView.layoutMarginsGuide;
        [NSLayoutConstraint activateConstraints:@[
            [content.leadingAnchor constraintEqualToAnchor:margins.leadingAnchor],
            [content.trailingAnchor constraintEqualToAnchor:margins.trailingAnchor],
            [content.topAnchor constraintEqualToAnchor:margins.topAnchor],
            [content.bottomAnchor constraintEqualToAnchor:margins.bottomAnchor],
            [content.heightAnchor constraintGreaterThanOrEqualToConstant:36],
        ]];
    }
    return cell;
}

@end
