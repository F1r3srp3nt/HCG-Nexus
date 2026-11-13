# Standalone iPhone/iPad app (HCGNexus.xcodeproj)

The standalone app is the ordinary, sandboxed way to use HCG Nexus. It is a
real Xcode project with the shared scheme **HCGNexus**. It builds an `.app`
or `.ipa`, not a jailbreak `.deb`.

## What it does — and doesn't

| Feature | Standalone app |
|---|---|
| Workspaces (create from preset or empty, rename, reorder, delete) | ✅ stored in the app's own sandbox |
| Shortcuts (add, reorder, delete), search across workspaces, recent actions | ✅ |
| Link shortcuts (`https:`, `mailto:`, `tel:`, `sms:`, an app's documented URL scheme) | ✅ opened with `UIApplication openURL:`; the real success/failure is reported |
| App shortcuts by bundle identifier | ❌ reported as **unavailable** — iOS has no public API for it |
| HCG Terminal / News integrations | status only ("Not connected" / "Needs jailbreak package") |
| System-wide edge handle and overlay | ❌ jailbreak package only. Settings show **App mode** and do not offer handle controls |

The header shows an **APP MODE** badge. Settings › App mode lists what this
build can do. Signing the app normally (personal team, paid account,
TestFlight) does **not** remove the iOS sandbox. Nothing in this project adds
private entitlements or private APIs; `scripts/check_app_target.py` and the CI
binary inspection enforce that.

**Data separation.** The app stores its data in the `NSUserDefaults` suite
`com.hakmicapitalgroup.hcgnexus.app.data`, inside its own container. It never
reads the jailbreak package's preference domain
(`com.hakmicapitalgroup.hcgnexus`) or the preview harness suite. Bundle ID:
`com.hakmicapitalgroup.hcgnexus.app`.

## Requirements

* A Mac with Xcode. The project format is Xcode 14+ (`objectVersion 56`), and
  every scheme setting is compatible with Xcode 15 and later.
* **Device deployment target: iOS 14.0** (covers iOS 14.7). The Xcode you
  build with must still support iOS 14 as a deployment target: check
  *Settings › Minimum Deployments* in the target. If your Xcode only offers
  15.0 or later, it cannot produce an iOS 14.7 build; use an older Xcode for
  that, or raise the target.
* **Simulator:** any iOS simulator runtime installed in your Xcode (14.0 or
  newer). It is independent of the device deployment target.

## Build and run in Xcode

1. `open HCGNexus.xcodeproj`
2. Select the **HCGNexus** scheme and an iPhone or iPad simulator, then press
   Run (⌘R). Simulator builds need no signing.
3. For a device: select the **HCGNexus** target › *Signing & Capabilities*:
   * tick *Automatically manage signing* and choose your **Team**;
   * if Xcode reports that the bundle ID is unavailable, change
     *Bundle Identifier* to one your team owns, for example
     `com.<you>.hcgnexus`. Data stays separate either way.
   * Connect the device, select it and Run. With a free Apple ID the app
     expires after 7 days. iOS 16+ also asks you to enable Developer Mode.
4. Tests: Product › Test (⌘U) runs `HCGNexusTests` on the selected simulator.

## Command line

```sh
# Simulator build (no signing)
xcodebuild -project HCGNexus.xcodeproj -scheme HCGNexus -configuration Debug \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath build/sim CODE_SIGNING_ALLOWED=NO build
#   -> build/sim/Build/Products/Debug-iphonesimulator/HCGNexus.app

# Unit tests on a simulator
xcodebuild -project HCGNexus.xcodeproj -scheme HCGNexus \
  -destination 'platform=iOS Simulator,name=iPhone 15' CODE_SIGNING_ALLOWED=NO test

# Unsigned device build (inspection only, cannot be installed)
xcodebuild -project HCGNexus.xcodeproj -scheme HCGNexus -configuration Release \
  -sdk iphoneos -destination 'generic/platform=iOS' -derivedDataPath build/device \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY= build
#   -> build/device/Build/Products/Release-iphoneos/HCGNexus.app
python3 scripts/inspect-app.py build/device/Build/Products/Release-iphoneos/HCGNexus.app --platform iphoneos

# Signed archive + IPA (needs your team and a matching bundle ID)
xcodebuild -project HCGNexus.xcodeproj -scheme HCGNexus -configuration Release \
  -destination 'generic/platform=iOS' -archivePath build/HCGNexus.xcarchive \
  DEVELOPMENT_TEAM=<TEAMID> -allowProvisioningUpdates archive
xcodebuild -exportArchive -archivePath build/HCGNexus.xcarchive -exportPath build/ipa \
  -exportOptionsPlist <your ExportOptions.plist> -allowProvisioningUpdates
#   -> build/ipa/HCGNexus.ipa
```

Without Xcode (Linux, or as a quick check), `scripts/compile-app-target.sh`
compiles and links the exact app-target sources against the iPhoneOS SDKs. It
is a compile check only, not an Xcode build.

## HCG Executable Maker

Import the **repository root**. Executable Maker finds `HCGNexus.xcodeproj`,
reports one *iOS application* (target **HCGNexus**, shared scheme
**HCGNexus**, bundle ID `com.hakmicapitalgroup.hcgnexus.app`, iOS 14.0), and
offers its simulator build, archive and IPA export. Choose your signing team
there for device builds; unsigned archives cannot be exported as IPA.

Executable Maker treats the IPA route and the jailbreak `.deb` route
separately. When an Xcode project is present it scores the folder as an iOS
app and does **not** offer its Theos route for that folder; Executable Maker
itself would need a change to do so. Build the jailbreak package with
`scripts/build-jailbreak-deb.sh` (see `INSTALL-AND-RECOVERY.md`). The Theos
preview harness has no Xcode project, so it is never offered as a second app.

## Changing the project

`HCGNexus.xcodeproj` is generated by `scripts/generate_xcodeproj.py`. That
script decides which files belong to the app target and refuses
SpringBoard, preview, tweak and Settings-bundle sources. After adding or
removing app files, run `python3 scripts/generate_xcodeproj.py`. `scripts/check.sh` fails if the
committed project is stale. Small edits made in Xcode (signing team, bundle
ID) are overwritten if you regenerate, so pass those on the xcodebuild command
line instead, or set them again.
