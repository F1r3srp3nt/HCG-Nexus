# HCG Nexus icon assets

`AppIcon.appiconset/` is the supplied icon pack, kept unchanged so an Xcode
project for the preview harness can use it directly
(`ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon`).

Theos builds on Linux cannot compile asset catalogs (no `actool`), so the
builds use copies derived from this set:

| Destination | Files | Source |
|---|---|---|
| Preview harness app (`PreviewHarness/Resources`) | `AppIcon{20,29,40,60}x…@2x/@3x.png`, iPad `76`/`83.5` | copied verbatim, referenced by `CFBundleIcons` in its `Info.plist` |
| Settings › HCG Nexus row (`Prefs/Resources`) | `icon.png`, `icon@2x.png`, `icon@3x.png` (29 pt) | resized from `Icon-1024.png` with rounded corners, because Settings does not mask PreferenceLoader icons on every iOS version |

The 1024 px marketing image is not shipped inside any package.
