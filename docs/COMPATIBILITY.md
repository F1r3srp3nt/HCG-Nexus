# Compatibility (from the project configuration)

These rows come from what the build files actually set (`Makefile`,
`scripts/generate_xcodeproj.py`). Nothing here has been verified on a physical
device yet; see `VALIDATION.md`.

## Standalone app (HCGNexus.xcodeproj)

| | Value |
|---|---|
| Device deployment target | iOS **14.0** (so iOS 14.7 is included), iPhone and iPad, arm64 |
| Simulator | any iOS simulator runtime your Xcode has installed; independent of the device target |
| Jailbreak needed | no — ordinary sandboxed app |
| Toolchain | Xcode 14+ project format. **Verified with Xcode 26.6 / iOS SDK 26.5** (CI run #7): SDK minimum deployment target 12.0, binary `minos 14.0`. Any Xcode whose iPhoneOS SDK allows 14.0 can build the iOS 14.x device app |

## Jailbreak package (Theos)

| `HCG_ENV` | Package layout | SDK : deployment target | Typical jailbreaks with this layout | Status |
|---|---|---|---|---|
| `rootless` (default) | `/var/jb`, `Architecture: iphoneos-arm64` | iPhoneOS16.5 : **15.0** | rootless jailbreaks for iOS 15 and later, e.g. Dopamine, palera1n (rootless) | **release target**; builds; Xcode-built arm64e verified for 0.1.0 (CI runs #6, #7); runtime unverified on device |
| `rootful` | `/`, `Architecture: iphoneos-arm` | iPhoneOS14.5 : **14.0** | rootful jailbreaks, e.g. on iOS 14.x (iOS 14.7 needs this layout) | builds and inspects clean (Linux); Xcode-built package not yet produced; **not supported** until verified |
| `roothide` | — | — | — | refused by the Makefile |

Rules the package itself enforces:

* **arm64e (A12 and newer)** needs the iOS 14+ arm64e ABI, which only Apple's
  clang (Xcode 12+) emits. `scripts/build-jailbreak-deb.sh` and the CI job
  reject anything else. A11 and older devices can use `--archs arm64`.
* **Injection:** the tweak installs no hooks. It needs a loader that honours
  `Library/MobileSubstrate/DynamicLibraries/*.plist` filters, such as ElleKit,
  Substitute, Substrate or libhooker (`Depends: mobilesubstrate | ellekit`), plus
  PreferenceLoader for Settings › HCG Nexus.
* The bootstrap stays inactive below iOS 14, or when `UIWindowScene` is
  missing.

Which jailbreak supports a given device and iOS version is decided by the
jailbreak, not by this project. Check your jailbreak's own support list, then
choose the matching `HCG_ENV`. Confirmed target so far: iPhone 13 Pro, iOS
16.5, Dopamine (rootless), ElleKit, Sileo.
