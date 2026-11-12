# Target environment

## Confirmed (2026-11-12, by the device owner)

| Item | Value | Consequence for the build |
|---|---|---|
| Device | iPhone 13 Pro (A15) | SpringBoard runs as **arm64e**: the package needs an arm64e slice with the **new (iOS 14+) ABI** |
| iOS | 16.5 | iPhoneOS16.5 SDK; deployment target 15.0 (covers 16.5) |
| Jailbreak | Dopamine | rootless bootstrap under `/var/jb` → `HCG_ENV=rootless` (now the Makefile default), `Architecture: iphoneos-arm64` |
| Injection | ElleKit | HCG Nexus installs no hooks; ElleKit only needs to load `/var/jb/Library/MobileSubstrate/DynamicLibraries/HCGNexus.dylib` per its SpringBoard filter. `Depends: mobilesubstrate \| ellekit` |
| Package manager | Sileo | install / uninstall steps in `INSTALL-AND-RECOVERY.md` |

Still worth confirming on the phone: that **PreferenceLoader** is installed
(`Depends: preferenceloader`; Sileo will offer it if missing).

## arm64e ABI — how the device package must be built

Measured in this repository's build environment (Linux):

* L1ghtmann iOSToolchain (clang 11): arm64e objects have CPU subtype `0x2` —
  the old, unversioned ABI. It has `-fptrauth-*` flags but no ABI-version flag.
* kabiroberai swift-toolchain-linux 5.8 (Apple open-source clang 13): also `0x2`.

Neither can produce a package for the iPhone 13 Pro. Apple's clang in
Xcode 12 or later emits the versioned ABI. Build the device package either:

* with the **Build package** GitHub Actions workflow (manual trigger, macOS
  runner, Xcode toolchain). It fails unless
  `scripts/inspect-package.py --require-new-arm64e-abi` passes and uploads the
  `.deb` as a 7-day workflow artifact; or
* on a Mac: `make package FINALPACKAGE=1` then
  `python3 scripts/inspect-package.py packages/*.deb rootless --require-new-arm64e-abi`.

Do not install a package whose inspection reports an old-ABI arm64e slice.

## Other layouts

`HCG_ENV=rootful` (iPhoneOS14.5 SDK, deployment 14.0) still builds for other
devices; `roothide` is refused by the Makefile.

## Assumptions to verify on the iPhone 13 Pro (iOS 16.5)

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
