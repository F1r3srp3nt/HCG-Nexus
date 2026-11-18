// Swift bridging header for the HCGNexus app target (standalone app only).
// Exposes the Objective-C side of HCG Device Link to HCGDeviceLinkService.swift.
// Swift in this app exists only for Device Link. HCGAccount.h adds the shared
// client-configuration guard (a client issued to another HCG product is refused).
#import "HCGLinkTypes.h"
#import "HCGAccount.h"
