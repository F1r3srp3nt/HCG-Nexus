#!/usr/bin/env python3
"""Inspect a built HCG Nexus .deb without installing it.

Checks:
  * expected files exist under the right prefix (/var/jb for rootless, / for rootful)
  * no maintainer scripts (nothing runs on install: no respring, no killall)
  * the tweak filter only targets SpringBoard
  * Mach-O slices and, for arm64e, whether the slice carries the versioned
    pointer-authentication ABI (required for arm64e processes on iOS 14+).

Usage: scripts/inspect-package.py path/to/package.deb [rootless|rootful] [--require-new-arm64e-abi]
Exit status is non-zero on hard failures. An old-ABI arm64e slice is a WARN,
or a FAIL with --require-new-arm64e-abi (required for A12+ devices on iOS 14+,
including the confirmed iPhone 13 Pro).
"""
import io
import struct
import subprocess
import sys
import tarfile
import tempfile
import os

FAT_MAGIC = 0xCAFEBABE
MH_MAGIC_64 = 0xFEEDFACF
CPU_TYPE_ARM64 = 0x0100000C
CPU_SUBTYPE_ARM64E = 2
CPU_SUBTYPE_PTRAUTH_ABI = 0x80000000


def slices(data):
    magic = struct.unpack(">I", data[:4])[0]
    if magic == FAT_MAGIC:
        count = struct.unpack(">I", data[4:8])[0]
        for i in range(count):
            cpu, sub, offset, size, _align = struct.unpack(">iIIII", data[8 + i * 20: 28 + i * 20])
            yield cpu & 0xFFFFFFFF, sub, data[offset:offset + size]
    else:
        m, cpu, sub = struct.unpack("<III", data[:12])
        if m == MH_MAGIC_64:
            yield cpu, sub, data


REQUIRE_NEW_ABI = False


def describe(path, data):
    findings = []
    for cpu, sub, _body in slices(data):
        if cpu != CPU_TYPE_ARM64:
            findings.append(("FAIL", f"{path}: unexpected CPU type {cpu:#x}"))
            continue
        base = sub & 0x00FFFFFF
        if base == CPU_SUBTYPE_ARM64E:
            if sub & CPU_SUBTYPE_PTRAUTH_ABI:
                version = (sub >> 24) & 0x3F
                findings.append(("OK", f"{path}: arm64e slice, versioned ptrauth ABI (v{version})"))
            else:
                findings.append(("FAIL" if REQUIRE_NEW_ABI else "WARN", f"{path}: arm64e slice uses the OLD (unversioned) ABI. "
                                         "Not expected to load into arm64e processes (A12+ SpringBoard) on iOS 14+. "
                                         "Rebuild with an Xcode 12+ toolchain, or build HCG_ARCHS=arm64 after confirming your device."))
        else:
            findings.append(("OK", f"{path}: arm64 slice"))
    return findings


def main():
    global REQUIRE_NEW_ABI
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    REQUIRE_NEW_ABI = "--require-new-arm64e-abi" in sys.argv[1:]
    if not args:
        print(__doc__)
        return 2
    deb = args[0]
    scheme = args[1] if len(args) > 1 else None
    prefix = {"rootless": "var/jb/", "rootful": ""}.get(scheme)
    results = []

    with tempfile.TemporaryDirectory() as tmp:
        subprocess.run(["dpkg-deb", "-R", deb, tmp], check=True)
        control_dir = os.path.join(tmp, "DEBIAN")
        scripts = [f for f in os.listdir(control_dir) if f in ("preinst", "postinst", "prerm", "postrm", "extrainst_")]
        results.append(("FAIL" if scripts else "OK", f"maintainer scripts: {scripts or 'none'}"))
        control = open(os.path.join(control_dir, "control")).read()
        arch = [l for l in control.splitlines() if l.startswith("Architecture:")]
        results.append(("OK", " ".join(arch)))

        if prefix is not None:
            expected = [
                "Library/MobileSubstrate/DynamicLibraries/HCGNexus.dylib",
                "Library/MobileSubstrate/DynamicLibraries/HCGNexus.plist",
                "Library/PreferenceBundles/HCGNexusPrefs.bundle/HCGNexusPrefs",
                "Library/PreferenceBundles/HCGNexusPrefs.bundle/Root.plist",
                "Library/PreferenceLoader/Preferences/HCGNexusPrefs.plist",
                "Library/PreferenceBundles/HCGNexusPrefs.bundle/icon.png",
                "Library/PreferenceBundles/HCGNexusPrefs.bundle/icon@2x.png",
                "Library/PreferenceBundles/HCGNexusPrefs.bundle/icon@3x.png",
            ]
            for rel in expected:
                p = os.path.join(tmp, prefix + rel)
                results.append(("OK" if os.path.exists(p) else "FAIL", f"/{prefix}{rel}"))
            if scheme == "rootless":
                stray = [d for d in os.listdir(tmp) if d not in ("DEBIAN", "var")]
                results.append(("FAIL" if stray else "OK", f"nothing outside /var/jb: {stray or 'ok'}"))

        for root, _dirs, files in os.walk(tmp):
            for name in files:
                full = os.path.join(root, name)
                rel = os.path.relpath(full, tmp)
                if name == "HCGNexus.plist":
                    text = open(full).read()
                    ok = "com.apple.springboard" in text and text.count('"') == 2
                    results.append(("OK" if ok else "FAIL", f"{rel}: filter = {text.strip()}"))
                if name in ("HCGNexus.dylib", "HCGNexusPrefs"):
                    results.extend(describe(rel, open(full, "rb").read()))

    failures = 0
    for level, text in results:
        print(f"{level:4}  {text}")
        failures += level == "FAIL"
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
