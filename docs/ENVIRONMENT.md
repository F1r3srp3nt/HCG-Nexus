# Target environment — needs confirmation

HCG Nexus has **not** been matched to a device yet. Nothing in this repository
claims support for any particular iPhone, iOS version or jailbreak.

## Questions for the device owner

| # | Question | Example answer | What it decides |
|---|---|---|---|
| 1 | iPhone model | iPhone 12 Pro (A14) | CPU family: A12 and newer run SpringBoard as **arm64e**; A11 and older are **arm64** only. Decides `HCG_ARCHS` and whether the arm64e ABI problem below matters. |
| 2 | Exact iOS version (Settings › General › About) | 16.5.1 (20F75) | SDK/deployment target; which SpringBoard classes and selectors to verify (`activeInterfaceOrientation`, `SBLockScreenManager isUILocked`, `SBCoverSheetPresentationManager isVisible`, `LSApplicationWorkspace openApplicationWithBundleID:`). |
| 3 | Jailbreak name and version | Dopamine 2.x / palera1n 2.x / checkra1n 0.12.x / unc0ver 8.x | Bootstrap layout and injection platform. |
| 4 | Rootless, rootful or roothide? | rootless (`/var/jb`) | `HCG_ENV` (package prefix and `Architecture:` field). |
| 5 | Injection framework | ElleKit / Substitute / Substrate / libhooker | Package `Depends:`. HCG Nexus installs **no hooks**, so it only needs a loader that honours `/Library/MobileSubstrate/DynamicLibraries/*.plist` filters. |
| 6 | Package manager | Sileo / Zebra / Cydia / apt over SSH | Install and uninstall instructions. |
| 7 | Is PreferenceLoader installed? | yes | Settings › HCG Nexus entry (`Depends: preferenceloader`). |

To answer 3–6 on the device:

```sh
ls -d /var/jb 2>/dev/null && echo rootless || echo "no /var/jb (rootful or roothide)"
ls /var/jb/usr/lib/ellekit 2>/dev/null; ls /var/jb/usr/lib/libsubstrate.dylib /usr/lib/libsubstrate.dylib 2>/dev/null
dpkg -l | grep -Ei 'ellekit|substitute|mobilesubstrate|libhooker|preferenceloader'
sw_vers 2>/dev/null || uname -a
```

## Current build defaults

These are placeholders until the answers above arrive.

| `HCG_ENV` | Theos scheme | SDK : deployment | Package prefix | Status |
|---|---|---|---|---|
| `rootless` | `rootless` | iPhoneOS16.5 : 15.0 | `/var/jb` | compiles and packages; not run on a device |
| `rootful` | default | iPhoneOS14.5 : 14.0 | `/` | compiles and packages; not run on a device |
| `roothide` | — | — | — | refused by the Makefile (needs the roothide Theos fork) |

## Known blocker: arm64e ABI with the Linux toolchain

The packages in this session were built on Linux with L1ghtmann's
clang 11 iOS toolchain. `scripts/inspect-package.py` reads the Mach-O
headers and finds that the **arm64e slices use the old, unversioned
pointer-authentication ABI**. arm64e processes on iOS 14+ (SpringBoard on A12
and newer) expect the new ABI, so that slice is not expected to load there. The arm64
slice is not affected.

Resolution depends on question 1:

* **A11 or older:** build with `HCG_ARCHS=arm64`. No arm64e slice is needed.
* **A12 or newer:** rebuild on macOS with Xcode 12 or later, or another
  toolchain that emits the new arm64e ABI. Then confirm with
  `scripts/inspect-package.py` that the warning is gone.

I could not reach the Theos documentation from this sandbox to confirm which
Linux toolchains emit the new ABI, so treat this as an open item.

## Assumptions to verify on the device

1. The overlay window level `999`
   (`HCGOverlayWindowLevel`, `Sources/Platform/SpringBoard/HCGSpringBoardEnvironment.m`)
   sits above apps and below the status bar, Notification/Control Centre,
   alerts and the lock screen.
2. `-[SpringBoard activeInterfaceOrientation]` reports the frontmost app's
   orientation, and the rotation direction in `HCGRotationForOrientation` is correct.
3. Text entry in the panel (search, rename) receives keyboard focus when the
   overlay window is made key inside SpringBoard.
4. `LSApplicationWorkspace` `applicationIsInstalled:` and
   `openApplicationWithBundleID:` behave as expected on the confirmed iOS version.
5. Lock signals: `com.apple.springboard.lockstate`,
   `SBLockScreenManager isUILocked` and `SBCoverSheetPresentationManager isVisible`
   all exist and hide the overlay at the right moments. Settings › HCG Nexus ›
   Diagnostics shows which sources were found.
