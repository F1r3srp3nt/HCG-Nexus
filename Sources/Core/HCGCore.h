// HCG Nexus — Core layer umbrella header.
//
// Everything under Sources/Core is Foundation-only so it can be compiled and
// executed by the host test runner (Tests/Host) as well as on iOS.
//
// Portability rules for Core sources (enforced by scripts/check.sh):
//   * no blocks, no object subscripting, no @YES/@NO boxed literals
//   * ivars declared in the @interface and properties @synthesize'd explicitly
//   * no __weak, no UIKit/CoreGraphics types
//   * ivars only receive +1 objects (alloc/copy/mutableCopy) or go through
//     property setters, so the code is correct under ARC (iOS) and merely
//     leaks under the host runner's manual reference counting.

#import "HCGConstants.h"
#import "HCGKeyValueStore.h"
#import "HCGAction.h"
#import "HCGWorkspace.h"
#import "HCGWorkspacePresets.h"
#import "HCGWorkspaceStore.h"
#import "HCGSettings.h"
#import "HCGRecents.h"
#import "HCGSearch.h"
#import "HCGIntegrations.h"
#import "HCGGeometry.h"
#import "HCGPanelStateMachine.h"
#import "HCGOverlayPolicy.h"
#import "HCGOverlayCoordinator.h"
#import "HCGDiagnostics.h"
