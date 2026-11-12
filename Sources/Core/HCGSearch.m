#import "HCGSearch.h"

@implementation HCGSearchResult

@synthesize action = _action;
@synthesize workspace = _workspace;
@synthesize score = _score;
@synthesize order = _order;

- (NSComparisonResult)compare:(HCGSearchResult *)other {
    if (self.score != other.score) return self.score < other.score ? NSOrderedAscending : NSOrderedDescending;
    if (self.order != other.order) return self.order < other.order ? NSOrderedAscending : NSOrderedDescending;
    return NSOrderedSame;
}

@end

@implementation HCGSearch

+ (NSString *)normalizedString:(NSString *)string {
    // Canonical decomposition, then drop combining marks: "Mémo" -> "memo".
    // (Portable equivalent of diacritic-insensitive folding.)
    NSString *decomposed = [string decomposedStringWithCanonicalMapping];
    NSArray *parts = [decomposed componentsSeparatedByCharactersInSet:[NSCharacterSet nonBaseCharacterSet]];
    NSString *folded = [[parts componentsJoinedByString:@""] lowercaseString];
    return [folded stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

static BOOL HasWordPrefix(NSString *haystack, NSString *needle) {
    NSCharacterSet *separators = [NSCharacterSet characterSetWithCharactersInString:@" -_./"];
    NSArray *words = [haystack componentsSeparatedByCharactersInSet:separators];
    NSUInteger i;
    for (i = 0; i < words.count; i++) {
        if ([[words objectAtIndex:i] hasPrefix:needle]) return YES;
    }
    return NO;
}

+ (NSInteger)scoreForAction:(HCGAction *)action query:(NSString *)query {
    NSString *title = [self normalizedString:action.title];
    NSString *target = [self normalizedString:action.target];
    if ([title hasPrefix:query]) return 0;
    if (HasWordPrefix(title, query)) return 1;
    if ([title rangeOfString:query].location != NSNotFound) return 2;
    if ([target rangeOfString:query].location != NSNotFound) return 3;
    return -1;
}

+ (NSArray *)resultsForQuery:(NSString *)query inWorkspaces:(NSArray *)workspaces activeWorkspace:(HCGWorkspace *)active {
    NSMutableArray *results = [[NSMutableArray alloc] init];
    NSString *needle = query ? [self normalizedString:query] : @"";
    NSUInteger order = 0;
    NSUInteger w, a;

    if (needle.length == 0) {
        if (!active) return results;
        NSArray *actions = active.actions;
        for (a = 0; a < actions.count; a++) {
            HCGSearchResult *result = [[HCGSearchResult alloc] init];
            result.action = [actions objectAtIndex:a];
            result.workspace = active;
            result.score = 0;
            result.order = order++;
            [results addObject:result];
        }
        return results;
    }

    // Active workspace first so its matches win ties.
    NSMutableArray *ordered = [[NSMutableArray alloc] init];
    if (active) [ordered addObject:active];
    for (w = 0; w < workspaces.count; w++) {
        HCGWorkspace *workspace = [workspaces objectAtIndex:w];
        if (active && [workspace.identifier isEqualToString:active.identifier]) continue;
        [ordered addObject:workspace];
    }

    for (w = 0; w < ordered.count; w++) {
        HCGWorkspace *workspace = [ordered objectAtIndex:w];
        NSArray *actions = workspace.actions;
        for (a = 0; a < actions.count; a++) {
            HCGAction *action = [actions objectAtIndex:a];
            NSInteger score = [self scoreForAction:action query:needle];
            if (score < 0) continue;
            HCGSearchResult *result = [[HCGSearchResult alloc] init];
            result.action = action;
            result.workspace = workspace;
            result.score = score;
            result.order = order++;
            [results addObject:result];
        }
    }
    return [results sortedArrayUsingSelector:@selector(compare:)];
}

@end
