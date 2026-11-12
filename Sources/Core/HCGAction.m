#import "HCGAction.h"
#import "HCGConstants.h"
#import "HCGIntegrations.h"

static NSString *const kID = @"id";
static NSString *const kTitle = @"title";
static NSString *const kKind = @"kind";
static NSString *const kTarget = @"target";
static NSString *const kSymbol = @"symbol";

static const NSUInteger kMaxTitleLength = 48;
static const NSUInteger kMaxTargetLength = 2048;

NSString *HCGActionKindName(HCGActionKind kind) {
    switch (kind) {
        case HCGActionKindApp: return @"app";
        case HCGActionKindURL: return @"url";
        case HCGActionKindIntegration: return @"integration";
    }
    return @"unknown";
}

static BOOL HCGParseKind(NSString *name, HCGActionKind *outKind) {
    if ([name isEqualToString:@"app"]) { *outKind = HCGActionKindApp; return YES; }
    if ([name isEqualToString:@"url"]) { *outKind = HCGActionKindURL; return YES; }
    if ([name isEqualToString:@"integration"]) { *outKind = HCGActionKindIntegration; return YES; }
    return NO;
}

static NSString *HCGTrim(NSString *value) {
    return [value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

@implementation HCGAction

@synthesize identifier = _identifier;
@synthesize title = _title;
@synthesize kind = _kind;
@synthesize target = _target;
@synthesize symbolName = _symbolName;

+ (instancetype)actionWithKind:(HCGActionKind)kind title:(NSString *)title target:(NSString *)target symbol:(NSString *)symbol {
    HCGAction *action = [[self alloc] init];
    action.identifier = [[NSUUID UUID] UUIDString];
    action.kind = kind;
    action.title = HCGTrim(title);
    action.target = HCGTrim(target);
    action.symbolName = symbol;
    return action;
}

- (id)copyWithZone:(NSZone *)zone {
    HCGAction *copy = [[[self class] allocWithZone:zone] init];
    copy.identifier = self.identifier;
    copy.title = self.title;
    copy.kind = self.kind;
    copy.target = self.target;
    copy.symbolName = self.symbolName;
    return copy;
}

- (BOOL)isEqual:(id)object {
    if (![object isKindOfClass:[HCGAction class]]) return NO;
    HCGAction *other = object;
    return [other.identifier isEqualToString:self.identifier]
        && [other.title isEqualToString:self.title]
        && other.kind == self.kind
        && [other.target isEqualToString:self.target]
        && ((other.symbolName == nil && self.symbolName == nil) || [other.symbolName isEqualToString:self.symbolName]);
}

- (NSUInteger)hash {
    return [self.identifier hash];
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<HCGAction %@ %@ '%@' -> %@>", self.identifier, HCGActionKindName(self.kind), self.title, self.target];
}

+ (BOOL)isPlausibleBundleIdentifier:(NSString *)candidate {
    if (candidate.length < 3 || candidate.length > 255) return NO;
    NSCharacterSet *allowed = [NSCharacterSet characterSetWithCharactersInString:
        @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-."];
    if ([candidate rangeOfCharacterFromSet:[allowed invertedSet]].location != NSNotFound) return NO;
    if ([candidate hasPrefix:@"."] || [candidate hasSuffix:@"."]) return NO;
    if ([candidate rangeOfString:@".."].location != NSNotFound) return NO;
    return [candidate rangeOfString:@"."].location != NSNotFound;
}

+ (NSError *)validationErrorForKind:(HCGActionKind)kind title:(NSString *)rawTitle target:(NSString *)rawTarget {
    NSString *title = HCGTrim(rawTitle ?: @"");
    NSString *target = HCGTrim(rawTarget ?: @"");
    if (title.length == 0) {
        return HCGMakeError(HCGErrorInvalidName, @"The shortcut needs a name.", @"Enter a short name, for example \"Notes\".");
    }
    if (title.length > kMaxTitleLength) {
        return HCGMakeError(HCGErrorInvalidName,
                            [NSString stringWithFormat:@"Shortcut names are limited to %lu characters.", (unsigned long)kMaxTitleLength],
                            @"Shorten the name.");
    }
    if (target.length == 0 || target.length > kMaxTargetLength) {
        return HCGMakeError(HCGErrorInvalidTarget, @"The shortcut has no target.", @"Enter a bundle identifier or a link.");
    }
    switch (kind) {
        case HCGActionKindApp:
            if (![self isPlausibleBundleIdentifier:target]) {
                return HCGMakeError(HCGErrorInvalidTarget,
                                    [NSString stringWithFormat:@"\"%@\" is not a valid bundle identifier.", target],
                                    @"Use the app's bundle identifier, for example com.apple.mobilenotes.");
            }
            return nil;
        case HCGActionKindURL: {
            NSURL *url = [NSURL URLWithString:target];
            NSString *scheme = [url.scheme lowercaseString];
            if (url == nil || scheme.length == 0) {
                return HCGMakeError(HCGErrorInvalidTarget,
                                    @"The link is not a valid URL.",
                                    @"Include the scheme, for example https://example.com.");
            }
            NSArray *blocked = [NSArray arrayWithObjects:@"file", @"javascript", @"data", @"about", nil];
            if ([blocked containsObject:scheme]) {
                return HCGMakeError(HCGErrorUnsupportedAction,
                                    [NSString stringWithFormat:@"%@: links are not supported by HCG Nexus.", scheme],
                                    @"Use an https:// link or an app link instead.");
            }
            if (([scheme isEqualToString:@"http"] || [scheme isEqualToString:@"https"]) && url.host.length == 0) {
                return HCGMakeError(HCGErrorInvalidTarget, @"The web link has no host.", @"Use a full address such as https://example.com.");
            }
            return nil;
        }
        case HCGActionKindIntegration:
            if (![[HCGIntegrationCatalog allIdentifiers] containsObject:target]) {
                return HCGMakeError(HCGErrorUnsupportedAction,
                                    [NSString stringWithFormat:@"Unknown HCG integration \"%@\".", target],
                                    @"Pick Terminal, Server, News or Executable Maker.");
            }
            return nil;
    }
    return HCGMakeError(HCGErrorUnsupportedAction, @"Unsupported shortcut type.", @"Recreate the shortcut as an app or link.");
}

+ (instancetype)actionFromDictionary:(NSDictionary *)dictionary error:(NSError **)error {
    if (![dictionary isKindOfClass:[NSDictionary class]]) {
        if (error) *error = HCGMakeError(HCGErrorInvalidTarget, @"Malformed shortcut entry.", nil);
        return nil;
    }
    id identifier = [dictionary objectForKey:kID];
    id title = [dictionary objectForKey:kTitle];
    id kindName = [dictionary objectForKey:kKind];
    id target = [dictionary objectForKey:kTarget];
    id symbol = [dictionary objectForKey:kSymbol];
    HCGActionKind kind = HCGActionKindApp;
    if (![identifier isKindOfClass:[NSString class]] || [identifier length] == 0 ||
        ![title isKindOfClass:[NSString class]] || ![target isKindOfClass:[NSString class]] ||
        ![kindName isKindOfClass:[NSString class]] || !HCGParseKind(kindName, &kind) ||
        (symbol != nil && ![symbol isKindOfClass:[NSString class]])) {
        if (error) *error = HCGMakeError(HCGErrorInvalidTarget, @"Malformed shortcut entry.", nil);
        return nil;
    }
    NSError *validation = [self validationErrorForKind:kind title:title target:target];
    if (validation) {
        if (error) *error = validation;
        return nil;
    }
    HCGAction *action = [[self alloc] init];
    action.identifier = identifier;
    action.title = HCGTrim(title);
    action.kind = kind;
    action.target = HCGTrim(target);
    action.symbolName = symbol;
    return action;
}

- (NSDictionary *)dictionaryRepresentation {
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
    [dict setObject:self.identifier forKey:kID];
    [dict setObject:self.title forKey:kTitle];
    [dict setObject:HCGActionKindName(self.kind) forKey:kKind];
    [dict setObject:self.target forKey:kTarget];
    if (self.symbolName.length > 0) [dict setObject:self.symbolName forKey:kSymbol];
    return dict;
}

@end
