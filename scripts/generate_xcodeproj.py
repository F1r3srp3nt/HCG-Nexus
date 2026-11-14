#!/usr/bin/env python3
"""Generate HCGNexus.xcodeproj (standalone iPhone/iPad app + unit tests).

The checked-in project is the output of this script; `--check` verifies that
it is up to date (run by scripts/check.sh). Object IDs are deterministic, so
regenerating without source changes produces an identical file.

Target boundaries are enforced here: the app target may only compile
App/, Sources/Core, Sources/Panel (minus overlay-only files) and
Sources/Platform/App. SpringBoard, preview-harness, tweak and Settings-bundle
sources can never be added to it.

Usage:
  scripts/generate_xcodeproj.py           # write HCGNexus.xcodeproj
  scripts/generate_xcodeproj.py --check   # exit 1 if the committed project is stale
  scripts/generate_xcodeproj.py --list    # print the app target's compiled sources
"""
import hashlib
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PROJECT = "HCGNexus.xcodeproj"
APP = "HCGNexus"
TESTS = "HCGNexusTests"
BUNDLE_ID = "com.hakmicapitalgroup.hcgnexus.app"
DEPLOYMENT_TARGET = "14.0"
MARKETING_VERSION = "0.2.0"

# Directories whose sources form the app target, and files deliberately left out.
APP_SOURCE_DIRS = ["App", "Sources/Core", "Sources/Panel", "Sources/Platform/App"]
APP_EXCLUDED_FILES = {
    # Overlay-only (SpringBoard window, edge handle); not used by the app.
    "Sources/Panel/HCGOverlayController.m",
    "Sources/Panel/HCGOverlayController.h",
    "Sources/Panel/HCGEdgeHandleView.m",
    "Sources/Panel/HCGEdgeHandleView.h",
}
FORBIDDEN_PREFIXES = ("Sources/Platform/SpringBoard", "Sources/Platform/Preview", "Tweak", "Prefs", "PreviewHarness")
TEST_SOURCE_DIRS = ["Tests/App"]
FRAMEWORKS = ["Foundation", "UIKit", "QuartzCore", "CoreGraphics"]


def oid(*parts):
    return hashlib.md5("/".join(("hcgnexus",) + parts).encode()).hexdigest()[:24].upper()


def q(value):
    """Quote an OpenStep plist string the way Xcode does."""
    s = str(value)
    if s and all(c.isalnum() or c in "_$/." for c in s):
        return s
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n") + '"'


def files_in(dirs, suffixes):
    out = []
    for d in dirs:
        full = os.path.join(ROOT, d)
        for name in sorted(os.listdir(full)):
            rel = f"{d}/{name}"
            if os.path.isfile(os.path.join(ROOT, rel)) and name.endswith(suffixes) and rel not in APP_EXCLUDED_FILES:
                out.append(rel)
    return out


def file_type(path):
    if path.endswith(".m"): return "sourcecode.c.objc"
    if path.endswith(".h"): return "sourcecode.c.h"
    if path.endswith(".plist"): return "text.plist.xml"
    if path.endswith(".xcassets"): return "folder.assetcatalog"
    raise ValueError(path)


def render_value(v, indent):
    pad = "\t" * indent
    if isinstance(v, dict):
        lines = ["{"]
        for k, val in v.items():
            lines.append(f"{pad}\t{q(k)} = {render_value(val, indent + 1)};")
        lines.append(pad + "}")
        return "\n".join(lines)
    if isinstance(v, list):
        if not v:
            return "(\n" + pad + ")"
        lines = ["("]
        for item in v:
            lines.append(f"{pad}\t{render_value(item, indent + 1)},")
        lines.append(pad + ")")
        return "\n".join(lines)
    return q(v)


def build():
    app_sources = files_in(APP_SOURCE_DIRS, (".m",))
    app_headers = files_in(APP_SOURCE_DIRS, (".h",))
    for path in app_sources + app_headers:
        if path.startswith(FORBIDDEN_PREFIXES):
            raise SystemExit(f"refusing to add {path} to the standalone app target")
    test_sources = files_in(TEST_SOURCE_DIRS, (".m",)) if os.path.isdir(os.path.join(ROOT, "Tests/App")) else []

    objects = {}
    sections = {}

    def add(section, ident, body, comment=None):
        sections.setdefault(section, []).append(ident)
        objects[ident] = (body, comment)
        return ident

    # File references
    fileref = {}
    for path in app_sources + app_headers + test_sources + ["App/Info.plist", "App/Assets.xcassets"]:
        fileref[path] = add("PBXFileReference", oid("ref", path), {
            "isa": "PBXFileReference", "lastKnownFileType": file_type(path),
            "name": os.path.basename(path), "path": path, "sourceTree": "SOURCE_ROOT",
        }, os.path.basename(path))
    fw_ref = {}
    for fw in FRAMEWORKS:
        fw_ref[fw] = add("PBXFileReference", oid("fw", fw), {
            "isa": "PBXFileReference", "lastKnownFileType": "wrapper.framework", "name": f"{fw}.framework",
            "path": f"System/Library/Frameworks/{fw}.framework", "sourceTree": "SDKROOT",
        }, f"{fw}.framework")
    app_product = add("PBXFileReference", oid("product", APP), {
        "isa": "PBXFileReference", "explicitFileType": "wrapper.application", "includeInIndex": "0",
        "path": f"{APP}.app", "sourceTree": "BUILT_PRODUCTS_DIR",
    }, f"{APP}.app")
    test_product = add("PBXFileReference", oid("product", TESTS), {
        "isa": "PBXFileReference", "explicitFileType": "wrapper.cfbundle", "includeInIndex": "0",
        "path": f"{TESTS}.xctest", "sourceTree": "BUILT_PRODUCTS_DIR",
    }, f"{TESTS}.xctest")

    # Build files
    def buildfile(target, path_or_key, ref, phase_name, label):
        return add("PBXBuildFile", oid("build", target, path_or_key), {"isa": "PBXBuildFile", "fileRef": ref},
                   f"{label} in {phase_name}")

    app_src_bf = [buildfile(APP, p, fileref[p], "Sources", os.path.basename(p)) for p in app_sources]
    app_fw_bf = [buildfile(APP, "fw/" + fw, fw_ref[fw], "Frameworks", f"{fw}.framework") for fw in FRAMEWORKS]
    app_res_bf = [buildfile(APP, "App/Assets.xcassets", fileref["App/Assets.xcassets"], "Resources", "Assets.xcassets")]
    test_src_bf = [buildfile(TESTS, p, fileref[p], "Sources", os.path.basename(p)) for p in test_sources]

    # Build phases
    def phase(isa, target, files, name):
        return add(isa, oid("phase", target, isa), {
            "isa": isa, "buildActionMask": "2147483647", "files": files, "runOnlyForDeploymentPostprocessing": "0",
        }, name)

    app_sources_phase = phase("PBXSourcesBuildPhase", APP, app_src_bf, "Sources")
    app_fw_phase = phase("PBXFrameworksBuildPhase", APP, app_fw_bf, "Frameworks")
    app_res_phase = phase("PBXResourcesBuildPhase", APP, app_res_bf, "Resources")
    test_sources_phase = phase("PBXSourcesBuildPhase", TESTS, test_src_bf, "Sources")
    test_fw_phase = phase("PBXFrameworksBuildPhase", TESTS, [], "Frameworks")
    test_res_phase = phase("PBXResourcesBuildPhase", TESTS, [], "Resources")

    # Groups
    def group(key, name, children):
        return add("PBXGroup", oid("group", key), {"isa": "PBXGroup", "children": children, "name": name, "sourceTree": "<group>"}, name)

    def refs_under(prefix, paths):
        return [fileref[p] for p in paths if os.path.dirname(p) == prefix]

    all_app_files = sorted(app_sources + app_headers)
    g_app = group("App", "App", refs_under("App", all_app_files) + [fileref["App/Info.plist"], fileref["App/Assets.xcassets"]])
    g_core = group("Core", "Core", refs_under("Sources/Core", all_app_files))
    g_panel = group("Panel", "Panel", refs_under("Sources/Panel", all_app_files))
    g_platform = group("PlatformApp", "Platform (App)", refs_under("Sources/Platform/App", all_app_files))
    g_sources = group("Sources", "Shared Sources", [g_core, g_panel, g_platform])
    g_tests = group("Tests", "Tests", [fileref[p] for p in test_sources])
    g_frameworks = group("Frameworks", "Frameworks", [fw_ref[f] for f in FRAMEWORKS])
    g_products = group("Products", "Products", [app_product, test_product])
    main_group = add("PBXGroup", oid("group", "main"), {
        "isa": "PBXGroup", "children": [g_app, g_sources, g_tests, g_frameworks, g_products], "sourceTree": "<group>",
    })

    # Build configurations
    common_project = {
        "ALWAYS_SEARCH_USER_PATHS": "NO",
        "CLANG_ANALYZER_NONNULL": "YES",
        "CLANG_CXX_LANGUAGE_STANDARD": "gnu++20",
        "CLANG_ENABLE_MODULES": "YES",
        "CLANG_ENABLE_OBJC_ARC": "YES",
        "CLANG_ENABLE_OBJC_WEAK": "YES",
        "CLANG_WARN_BLOCK_CAPTURE_AUTORELEASING": "YES",
        "CLANG_WARN_BOOL_CONVERSION": "YES",
        "CLANG_WARN_COMMA": "YES",
        "CLANG_WARN_CONSTANT_CONVERSION": "YES",
        "CLANG_WARN_DIRECT_OBJC_ISA_USAGE": "YES_ERROR",
        "CLANG_WARN_EMPTY_BODY": "YES",
        "CLANG_WARN_ENUM_CONVERSION": "YES",
        "CLANG_WARN_INFINITE_RECURSION": "YES",
        "CLANG_WARN_INT_CONVERSION": "YES",
        "CLANG_WARN_OBJC_ROOT_CLASS": "YES_ERROR",
        "CLANG_WARN_STRICT_PROTOTYPES": "YES",
        "CLANG_WARN_SUSPICIOUS_MOVE": "YES",
        "CLANG_WARN_UNREACHABLE_CODE": "YES",
        "CLANG_WARN__DUPLICATE_METHOD_MATCH": "YES",
        "COPY_PHASE_STRIP": "NO",
        "ENABLE_STRICT_OBJC_MSGSEND": "YES",
        "GCC_C_LANGUAGE_STANDARD": "gnu11",
        "GCC_NO_COMMON_BLOCKS": "YES",
        "GCC_WARN_64_TO_32_BIT_CONVERSION": "YES",
        "GCC_WARN_ABOUT_RETURN_TYPE": "YES_ERROR",
        "GCC_WARN_UNDECLARED_SELECTOR": "YES",
        "GCC_WARN_UNINITIALIZED_AUTOS": "YES_AGGRESSIVE",
        "GCC_WARN_UNUSED_FUNCTION": "YES",
        "GCC_WARN_UNUSED_VARIABLE": "YES",
        "HEADER_SEARCH_PATHS": ["$(SRCROOT)/Sources/Core", "$(SRCROOT)/Sources/Panel", "$(SRCROOT)/Sources/Platform/App", "$(SRCROOT)/App"],
        "IPHONEOS_DEPLOYMENT_TARGET": DEPLOYMENT_TARGET,
        "SDKROOT": "iphoneos",
    }
    debug_project = dict(common_project, **{
        "DEBUG_INFORMATION_FORMAT": "dwarf",
        "ENABLE_TESTABILITY": "YES",
        "GCC_DYNAMIC_NO_PIC": "NO",
        "GCC_OPTIMIZATION_LEVEL": "0",
        "GCC_PREPROCESSOR_DEFINITIONS": ["DEBUG=1", "HCG_STANDALONE_APP=1", "$(inherited)"],
        "ONLY_ACTIVE_ARCH": "YES",
    })
    release_project = dict(common_project, **{
        "DEBUG_INFORMATION_FORMAT": "dwarf-with-dsym",
        "ENABLE_NS_ASSERTIONS": "NO",
        "GCC_PREPROCESSOR_DEFINITIONS": ["HCG_STANDALONE_APP=1", "$(inherited)"],
        "VALIDATE_PRODUCT": "YES",
    })
    app_settings = {
        "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
        "ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME": "AccentColor",
        "CODE_SIGN_STYLE": "Automatic",
        "CURRENT_PROJECT_VERSION": "2",
        "DEVELOPMENT_TEAM": "",
        "GENERATE_INFOPLIST_FILE": "NO",
        "INFOPLIST_FILE": "App/Info.plist",
        "IPHONEOS_DEPLOYMENT_TARGET": DEPLOYMENT_TARGET,
        "LD_RUNPATH_SEARCH_PATHS": ["$(inherited)", "@executable_path/Frameworks"],
        "MARKETING_VERSION": MARKETING_VERSION,
        "PRODUCT_BUNDLE_IDENTIFIER": BUNDLE_ID,
        "PRODUCT_NAME": "$(TARGET_NAME)",
        "SUPPORTED_PLATFORMS": "iphoneos iphonesimulator",
        "SUPPORTS_MACCATALYST": "NO",
        "SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD": "NO",
        "SUPPORTS_XR_DESIGNED_FOR_IPHONE_IPAD": "NO",
        "TARGETED_DEVICE_FAMILY": "1,2",
    }
    test_settings = {
        "BUNDLE_LOADER": "$(TEST_HOST)",
        "CODE_SIGN_STYLE": "Automatic",
        "CURRENT_PROJECT_VERSION": "2",
        "DEVELOPMENT_TEAM": "",
        "GENERATE_INFOPLIST_FILE": "YES",
        "IPHONEOS_DEPLOYMENT_TARGET": DEPLOYMENT_TARGET,
        "MARKETING_VERSION": MARKETING_VERSION,
        "PRODUCT_BUNDLE_IDENTIFIER": BUNDLE_ID + ".tests",
        "PRODUCT_NAME": "$(TARGET_NAME)",
        "SUPPORTED_PLATFORMS": "iphoneos iphonesimulator",
        "TARGETED_DEVICE_FAMILY": "1,2",
        "TEST_HOST": f"$(BUILT_PRODUCTS_DIR)/{APP}.app/{APP}",
    }

    def config_list(key, settings_by_name, label):
        ids = []
        for name, settings in settings_by_name:
            ids.append(add("XCBuildConfiguration", oid("config", key, name), {
                "isa": "XCBuildConfiguration", "buildSettings": dict(sorted(settings.items())), "name": name,
            }, name))
        return add("XCConfigurationList", oid("configlist", key), {
            "isa": "XCConfigurationList", "buildConfigurations": ids,
            "defaultConfigurationIsVisible": "0", "defaultConfigurationName": "Release",
        }, label)

    project_cl = config_list("project", [("Debug", debug_project), ("Release", release_project)], f'Build configuration list for PBXProject "{APP}"')
    app_cl = config_list(APP, [("Debug", app_settings), ("Release", app_settings)], f'Build configuration list for PBXNativeTarget "{APP}"')
    test_cl = config_list(TESTS, [("Debug", test_settings), ("Release", test_settings)], f'Build configuration list for PBXNativeTarget "{TESTS}"')

    app_target = oid("target", APP)
    test_target = oid("target", TESTS)
    project_id = oid("project")
    proxy = add("PBXContainerItemProxy", oid("proxy", TESTS), {
        "isa": "PBXContainerItemProxy", "containerPortal": project_id, "proxyType": "1",
        "remoteGlobalIDString": app_target, "remoteInfo": APP,
    }, "PBXContainerItemProxy")
    dependency = add("PBXTargetDependency", oid("dependency", TESTS), {
        "isa": "PBXTargetDependency", "target": app_target, "targetProxy": proxy,
    }, "PBXTargetDependency")

    add("PBXNativeTarget", app_target, {
        "isa": "PBXNativeTarget", "buildConfigurationList": app_cl,
        "buildPhases": [app_sources_phase, app_fw_phase, app_res_phase], "buildRules": [], "dependencies": [],
        "name": APP, "productName": APP, "productReference": app_product,
        "productType": "com.apple.product-type.application",
    }, APP)
    add("PBXNativeTarget", test_target, {
        "isa": "PBXNativeTarget", "buildConfigurationList": test_cl,
        "buildPhases": [test_sources_phase, test_fw_phase, test_res_phase], "buildRules": [], "dependencies": [dependency],
        "name": TESTS, "productName": TESTS, "productReference": test_product,
        "productType": "com.apple.product-type.bundle.unit-test",
    }, TESTS)
    add("PBXProject", project_id, {
        "isa": "PBXProject",
        "attributes": {
            "BuildIndependentTargetsInParallel": "1",
            "LastUpgradeCheck": "1500",
            "TargetAttributes": {
                app_target: {"CreatedOnToolsVersion": "15.0"},
                test_target: {"CreatedOnToolsVersion": "15.0", "TestTargetID": app_target},
            },
        },
        "buildConfigurationList": project_cl,
        "compatibilityVersion": "Xcode 14.0",
        "developmentRegion": "en",
        "hasScannedForEncodings": "0",
        "knownRegions": ["en", "Base"],
        "mainGroup": main_group,
        "productRefGroup": g_products,
        "projectDirPath": "",
        "projectRoot": "",
        "targets": [app_target, test_target],
    }, "Project object")

    lines = ["// !$*UTF8*$!", "{", "\tarchiveVersion = 1;", "\tclasses = {", "\t};", "\tobjectVersion = 56;", "\tobjects = {"]
    for section in sorted(sections):
        lines.append("")
        lines.append(f"/* Begin {section} section */")
        for ident in sorted(sections[section]):
            body, comment = objects[ident]
            rendered = render_value(body, 2)
            label = f" /* {comment} */" if comment else ""
            lines.append(f"\t\t{ident}{label} = {rendered};")
        lines.append(f"/* End {section} section */")
    lines += ["\t};", f"\trootObject = {project_id} /* Project object */;", "}", ""]
    pbxproj = "\n".join(lines)

    scheme = f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme
   LastUpgradeVersion = "1500"
   version = "1.7">
   <BuildAction
      parallelizeBuildables = "YES"
      buildImplicitDependencies = "YES">
      <BuildActionEntries>
         <BuildActionEntry
            buildForTesting = "YES"
            buildForRunning = "YES"
            buildForProfiling = "YES"
            buildForArchiving = "YES"
            buildForAnalyzing = "YES">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "{app_target}"
               BuildableName = "{APP}.app"
               BlueprintName = "{APP}"
               ReferencedContainer = "container:{PROJECT}">
            </BuildableReference>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      shouldUseLaunchSchemeArgsEnv = "YES"
      shouldAutocreateTestPlan = "YES">
      <Testables>
         <TestableReference
            skipped = "NO">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "{test_target}"
               BuildableName = "{TESTS}.xctest"
               BlueprintName = "{TESTS}"
               ReferencedContainer = "container:{PROJECT}">
            </BuildableReference>
         </TestableReference>
      </Testables>
   </TestAction>
   <LaunchAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      launchStyle = "0"
      useCustomWorkingDirectory = "NO"
      ignoresPersistentStateOnLaunch = "NO"
      debugDocumentVersioning = "YES"
      debugServiceExtension = "internal"
      allowLocationSimulation = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "{app_target}"
            BuildableName = "{APP}.app"
            BlueprintName = "{APP}"
            ReferencedContainer = "container:{PROJECT}">
         </BuildableReference>
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction
      buildConfiguration = "Release"
      shouldUseLaunchSchemeArgsEnv = "YES"
      savedToolIdentifier = ""
      useCustomWorkingDirectory = "NO"
      debugDocumentVersioning = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "{app_target}"
            BuildableName = "{APP}.app"
            BlueprintName = "{APP}"
            ReferencedContainer = "container:{PROJECT}">
         </BuildableReference>
      </BuildableProductRunnable>
   </ProfileAction>
   <AnalyzeAction
      buildConfiguration = "Debug">
   </AnalyzeAction>
   <ArchiveAction
      buildConfiguration = "Release"
      revealArchiveInOrganizer = "YES">
   </ArchiveAction>
</Scheme>
'''
    workspace = '''<?xml version="1.0" encoding="UTF-8"?>
<Workspace
   version = "1.0">
   <FileRef
      location = "self:">
   </FileRef>
</Workspace>
'''
    return {
        f"{PROJECT}/project.pbxproj": pbxproj,
        f"{PROJECT}/xcshareddata/xcschemes/{APP}.xcscheme": scheme,
        f"{PROJECT}/project.xcworkspace/contents.xcworkspacedata": workspace,
    }, app_sources


def main():
    outputs, app_sources = build()
    if "--list" in sys.argv:
        print("\n".join(app_sources))
        return 0
    if "--check" in sys.argv:
        stale = [p for p, text in outputs.items()
                 if not os.path.exists(os.path.join(ROOT, p)) or open(os.path.join(ROOT, p)).read() != text]
        if stale:
            print("HCGNexus.xcodeproj is out of date; run scripts/generate_xcodeproj.py:\n  " + "\n  ".join(stale))
            return 1
        print(f"HCGNexus.xcodeproj is up to date ({len(app_sources)} app sources)")
        return 0
    for path, text in outputs.items():
        full = os.path.join(ROOT, path)
        os.makedirs(os.path.dirname(full), exist_ok=True)
        with open(full, "w") as f:
            f.write(text)
        print("wrote", path)
    return 0


if __name__ == "__main__":
    sys.exit(main())
