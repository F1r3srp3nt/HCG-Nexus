#!/usr/bin/env python3
"""Regression checks for the standalone app target (no Xcode needed).

1. Sources compiled into the app use public APIs only: no SpringBoard classes,
   LaunchServices-private calls, secure windows, Darwin lock-state reads or the
   jailbreak package's CFPreferences domain. Swift is used only for HCG Device
   Link (Sources/Platform/App/DeviceLink), and the vendored HCGDeviceLink
   package is linked into the app target only.
2. HCGNexus.xcodeproj is discoverable by HCG Executable Maker as an iOS app:
   exactly one .xcodeproj, an application target, a committed shared scheme
   that archives that target, a valid scheme name, iPhoneOS SDK, deployment
   target set, and no .xcodeproj inside the Theos preview harness.
"""
import glob
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FORBIDDEN = [
    "LSApplicationWorkspace", "SBLockScreenManager", "SBCoverSheetPresentationManager", "_setSecure",
    "notify_register", "notify_get_state", "CFPreferencesCopyAppValue", "CFPreferencesSetAppValue",
    "activeInterfaceOrientation", "_frontMostAppOrientation", "HCGPreferencesKeyValueStore",
    "HCGSpringBoard", "HCGLockStateMonitor", "HCGPreview", "HCGOverlayController", "HCGEdgeHandleView",
]
failures = 0


def report(ok, text):
    global failures
    print(f"{'PASS' if ok else 'FAIL'}  {text}")
    failures += not ok


sources = subprocess.run([sys.executable, "-I", os.path.join(ROOT, "scripts/generate_xcodeproj.py"), "--list"],
                         capture_output=True, text=True, check=True).stdout.split()
swift_sources = subprocess.run([sys.executable, "-I", os.path.join(ROOT, "scripts/generate_xcodeproj.py"), "--list-swift"],
                               capture_output=True, text=True, check=True).stdout.split()
headers = [s[:-2] + ".h" for s in sources if os.path.exists(os.path.join(ROOT, s[:-2] + ".h"))]
hits = []
for rel in sources + headers + swift_sources:
    for n, line in enumerate(open(os.path.join(ROOT, rel), encoding="utf-8"), 1):
        code = line.split("//", 1)[0]
        for word in FORBIDDEN:
            if word in code:
                hits.append(f"{rel}:{n}: {word}")
report(not hits, f"app target ({len(sources)} Objective-C + {len(swift_sources)} Swift sources) uses public APIs only" + ("".join("\n      " + h for h in hits)))
report(all(s.startswith("Sources/Platform/App/DeviceLink/") for s in swift_sources),
       f"Swift only for HCG Device Link (Sources/Platform/App/DeviceLink): {swift_sources}")
report(not any(s.startswith(("Sources/Platform/SpringBoard", "Sources/Platform/Preview", "Tweak", "Prefs", "PreviewHarness")) for s in sources),
       "no SpringBoard/preview/tweak/Settings-bundle files in the app target")
mains = [s for s in sources if os.path.basename(s) == "main.m"]
report(mains == ["App/main.m"], f"single entry point in the app target: {mains}")

projects = [p for p in glob.glob(os.path.join(ROOT, "**/*.xcodeproj"), recursive=True)
            if "/.theos/" not in p and "/build/" not in p]
report([os.path.relpath(p, ROOT) for p in projects] == ["HCGNexus.xcodeproj"],
       f"exactly one Xcode project: {[os.path.relpath(p, ROOT) for p in projects]}")
pbx = open(os.path.join(ROOT, "HCGNexus.xcodeproj/project.pbxproj")).read()
app_targets = re.findall(r'productType = "com\.apple\.product-type\.application"', pbx)
report(len(app_targets) == 1, f"one iOS application target ({len(app_targets)})")
report(pbx.count("packageProductDependencies = (") == 1 and "relativePath = HCGDeviceLink;" in pbx
       and pbx.count("isa = XCSwiftPackageProductDependency;") == 1,
       "vendored HCGDeviceLink package linked into the app target only")
report("SDKROOT = iphoneos;" in pbx and "IPHONEOS_DEPLOYMENT_TARGET = 14.0;" in pbx, "SDKROOT iphoneos, IPHONEOS_DEPLOYMENT_TARGET 14.0")
report('SUPPORTED_PLATFORMS = "iphoneos iphonesimulator";' in pbx, "supports device and simulator")
scheme_path = os.path.join(ROOT, "HCGNexus.xcodeproj/xcshareddata/xcschemes/HCGNexus.xcscheme")
scheme = open(scheme_path).read() if os.path.exists(scheme_path) else ""
archives = re.search(r'buildForArchiving = "YES"[^<]*>\s*<BuildableReference[^>]*BlueprintName = "HCGNexus"', scheme)
report(bool(archives), "shared scheme HCGNexus archives the HCGNexus app target (Executable Maker reads this)")
report(re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9 _.\-]{0,127}", "HCGNexus") is not None, "scheme name accepted by Executable Maker")
report(not glob.glob(os.path.join(ROOT, "PreviewHarness/**/*.xcodeproj"), recursive=True), "preview harness has no Xcode project (stays a Theos simulation)")
sys.exit(1 if failures else 0)
