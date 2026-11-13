#!/usr/bin/env python3
"""Inspect a built HCGNexus.app (simulator or device build) without running it.

Checks:
  * Info.plist: bundle ID, display name, MinimumOSVersion, iPhone+iPad family,
    scene manifest, compiled app icon (CFBundleIcons) and Assets.car
  * the executable exists and is a Mach-O for the expected platform
  * no SpringBoard/private-API or preview-simulation code leaked into the app
    (LSApplicationWorkspace, SBLockScreenManager, _setSecure, overlay classes...)

Usage: scripts/inspect-app.py path/to/HCGNexus.app [--expect-min-os 14.0] [--platform iphoneos|iphonesimulator]
"""
import os
import plistlib
import struct
import sys

FORBIDDEN = [
    b"LSApplicationWorkspace", b"SBLockScreenManager", b"SBCoverSheetPresentationManager",
    b"_setSecure", b"activeInterfaceOrientation", b"_frontMostAppOrientation",
    b"HCGSpringBoardBootstrap", b"HCGSpringBoardLauncher", b"HCGSpringBoardEnvironment",
    b"HCGLockStateMonitor", b"HCGPreviewLauncher", b"HCGPreviewEnvironment",
    b"HCGOverlayController", b"HCGEdgeHandleView",
]
FAT_MAGIC = 0xCAFEBABE
MH_MAGIC_64 = 0xFEEDFACF


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    if not args:
        print(__doc__)
        return 2
    app = args[0].rstrip("/")
    expect_min = "14.0"
    platform = None
    argv = sys.argv[1:]
    if "--expect-min-os" in argv:
        expect_min = argv[argv.index("--expect-min-os") + 1]
        args = [a for a in args if a != expect_min]
    if "--platform" in argv:
        platform = argv[argv.index("--platform") + 1]
    results = []

    def check(ok, text):
        results.append(("OK" if ok else "FAIL", text))

    info_path = os.path.join(app, "Info.plist")
    check(os.path.isfile(info_path), "Info.plist present")
    info = plistlib.load(open(info_path, "rb")) if os.path.isfile(info_path) else {}
    check(info.get("CFBundleIdentifier") == "com.hakmicapitalgroup.hcgnexus.app",
          f"CFBundleIdentifier = {info.get('CFBundleIdentifier')}")
    check(info.get("CFBundleDisplayName") == "HCG Nexus", f"CFBundleDisplayName = {info.get('CFBundleDisplayName')}")
    check(info.get("MinimumOSVersion") == expect_min, f"MinimumOSVersion = {info.get('MinimumOSVersion')} (expected {expect_min})")
    check(sorted(info.get("UIDeviceFamily", [])) == [1, 2], f"UIDeviceFamily = {info.get('UIDeviceFamily')} (iPhone + iPad)")
    scene = info.get("UIApplicationSceneManifest", {}).get("UISceneConfigurations", {})
    delegate = scene.get("UIWindowSceneSessionRoleApplication", [{}])[0].get("UISceneDelegateClassName")
    check(delegate == "HCGSceneDelegate", f"scene delegate = {delegate}")
    icons = info.get("CFBundleIcons", {}).get("CFBundlePrimaryIcon", {})
    check(icons.get("CFBundleIconName") == "AppIcon" or bool(icons.get("CFBundleIconFiles")),
          f"compiled app icon: {icons.get('CFBundleIconName') or icons.get('CFBundleIconFiles')}")
    check(os.path.isfile(os.path.join(app, "Assets.car")), "Assets.car present (asset catalog compiled)")
    if platform:
        check(info.get("DTPlatformName") == platform, f"DTPlatformName = {info.get('DTPlatformName')} (expected {platform})")

    exe_name = info.get("CFBundleExecutable", "HCGNexus")
    exe = os.path.join(app, exe_name)
    data = open(exe, "rb").read() if os.path.isfile(exe) else b""
    magic = struct.unpack(">I", data[:4])[0] if len(data) >= 4 else 0
    is_macho = magic == FAT_MAGIC or (len(data) >= 4 and struct.unpack("<I", data[:4])[0] == MH_MAGIC_64)
    check(is_macho, f"executable {exe_name} is Mach-O ({len(data)} bytes)")
    leaked = [n.decode() for n in FORBIDDEN if n in data]
    check(not leaked, "no SpringBoard/private-API/preview code in the app binary" + (f": found {leaked}" if leaked else ""))
    signed = os.path.isdir(os.path.join(app, "_CodeSignature"))
    results.append(("INFO", f"code signature present: {signed}; embedded.mobileprovision: {os.path.isfile(os.path.join(app, 'embedded.mobileprovision'))}"))

    failures = 0
    for level, text in results:
        print(f"{level:4}  {text}")
        failures += level == "FAIL"
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
