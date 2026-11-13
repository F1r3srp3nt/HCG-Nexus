# HCG Nexus icon assets

The supplied icon pack is the standalone app's real icon set, unchanged:
`App/Assets.xcassets/AppIcon.appiconset/` (18 slots, 13 opaque RGB PNGs,
1024 px marketing image included). The Xcode project compiles it with
`ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon`; `AccentColor` (cyan) and
`LaunchBackground` (obsidian) sit in the same catalog.

Theos builds cannot compile asset catalogs on Linux (no `actool`), so the
jailbreak-side builds use copies derived from that set:

| Destination | Files | Source |
|---|---|---|
| Standalone app (`HCGNexus.xcodeproj`) | `App/Assets.xcassets/AppIcon.appiconset` | the icon pack itself |
| Preview harness app (`PreviewHarness/Resources`) | `AppIcon{20,29,40,60}x…@2x/@3x.png`, iPad `76`/`83.5` | copied verbatim, referenced by `CFBundleIcons` in its `Info.plist` |
| Settings › HCG Nexus row (`Prefs/Resources`) | `icon.png`, `icon@2x.png`, `icon@3x.png` (29 pt) | resized from `Icon-1024.png` with rounded corners, because Settings does not mask PreferenceLoader icons on every iOS version |

No jailbreak package ships the 1024 px marketing image.
