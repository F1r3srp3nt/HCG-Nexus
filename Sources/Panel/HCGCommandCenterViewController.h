#import "HCGPanelTableViewController.h"
#import "HCGCommandCenterData.h"

NS_ASSUME_NONNULL_BEGIN

// HCG Nexus Command Center (docs/COMMAND-CENTER.md): every product in the ecosystem registry, by category, with
// search, favorites, a connection dashboard and notices. Statuses come only from evidence (HCGCommandCenter); opening
// this screen reads stored evidence and the read-only HIP scan, and starts no connection.
@interface HCGCommandCenterViewController : HCGPanelTableViewController <UISearchBarDelegate>
@end

// Colour for a connection state (shared by the Command Center screens).
FOUNDATION_EXPORT UIColor *HCGCommandCenterColorForConnection(HCGConnectionState state);

// Reading files the user picks (Files, AirDrop) and saving files: only where a normal app UI exists (standalone app,
// Settings). Never in the SpringBoard overlay.
@interface HCGFileExchange : NSObject <UIDocumentPickerDelegate>
+ (BOOL)availableInContext:(HCGPanelContext *)context;
+ (void)pickJSONFrom:(UIViewController *)presenter completion:(void (^)(NSData *_Nullable data, NSString *_Nullable error))completion;
+ (void)shareData:(NSData *)data fileName:(NSString *)fileName from:(UIViewController *)presenter sourceView:(nullable UIView *)sourceView
       completion:(void (^)(BOOL saved))completion;
@end

NS_ASSUME_NONNULL_END
