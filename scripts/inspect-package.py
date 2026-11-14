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
import plistlib
import re
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
EXPECTED_FILTER = {"Filter": {"Bundles": ["com.apple.springboard"]}}


def parse_filter(raw):
    """Parse a MobileSubstrate filter plist in any format Theos may emit.

    Theos on macOS converts plists to binary (plutil); on Linux it leaves the
    source format (here OpenStep text). Returns the parsed dict or None.
    """
    import plistlib
    import re
    try:
        return plistlib.loads(raw)  # binary or XML
    except Exception:
        pass
    try:
        text = raw.decode("utf-8")
    except UnicodeDecodeError:
        return None
    # Minimal OpenStep form: { Filter = { Bundles = ( "a", "b" ); }; }
    match = re.fullmatch(r'\s*\{\s*Filter\s*=\s*\{\s*Bundles\s*=\s*\(([^)]*)\)\s*;\s*\}\s*;\s*\}\s*', text)
    if not match:
        return None
    bundles = [b.strip().strip('"') for b in match.group(1).split(",") if b.strip()]
    return {"Filter": {"Bundles": bundles}}


def self_test():
    import plistlib
    ok = True
    samples = {
        "openstep": b'{ Filter = { Bundles = ( "com.apple.springboard" ); }; }\n',
        "binary": plistlib.dumps(EXPECTED_FILTER, fmt=plistlib.FMT_BINARY),
        "xml": plistlib.dumps(EXPECTED_FILTER, fmt=plistlib.FMT_XML),
    }
    for name, raw in samples.items():
        good = parse_filter(raw) == EXPECTED_FILTER
        print(f"{'OK' if good else 'FAIL':4}  filter parse ({name})")
        ok &= good
    def macho(section_flags, size):
        # Minimal thin arm64 Mach-O: header + one LC_SEGMENT_64 with one section.
        sect = b"__mod_init_func".ljust(16, b"\0") + b"__DATA".ljust(16, b"\0")
        sect += struct.pack("<QQIIIIIIII", 0, size, 0, 3, 0, 0, section_flags, 0, 0, 0)
        seg = struct.pack("<II", LC_SEGMENT_64, 72 + len(sect)) + b"__DATA".ljust(16, b"\0")
        seg += struct.pack("<QQQQiiII", 0, 0, 0, 0, 3, 3, 1, 0)
        header = struct.pack("<IiIIIIII", MH_MAGIC_64, CPU_TYPE_ARM64, 0, 6, 1, len(seg + sect), 0, 0)
        return header + seg + sect
    cases = [("initializer present", macho(S_MOD_INIT_FUNC_POINTERS, 8), True),
             ("init offsets present", macho(S_INIT_FUNC_OFFSETS, 4), True),
             ("empty initializer section", macho(S_MOD_INIT_FUNC_POINTERS, 0), False),
             ("no initializer section", macho(0x0, 8), False)]
    for name, data, expected in cases:
        good = has_initializer(data) == expected
        print(f"{'OK' if good else 'FAIL':4}  Mach-O {name}")
        ok &= good
    wider = plistlib.dumps({"Filter": {"Bundles": ["com.apple.springboard", "com.apple.UIKit"]}}, fmt=plistlib.FMT_BINARY)
    rejected = parse_filter(wider) != EXPECTED_FILTER
    print(f"{'OK' if rejected else 'FAIL':4}  wider filter is not accepted")
    ok &= rejected
    return 0 if ok else 1


LC_SEGMENT_64 = 0x19
S_MOD_INIT_FUNC_POINTERS = 0x9
S_INIT_FUNC_OFFSETS = 0x16


def has_initializer(macho):
    """True if a thin 64-bit Mach-O has a non-empty initializer section
    (__mod_init_func / __init_offsets): i.e. a constructor such as %ctor."""
    magic, _cpu, _sub, _ftype, ncmds, _size, _flags, _res = struct.unpack("<IiIIIIII", macho[:32])
    if magic != MH_MAGIC_64:
        return False
    offset = 32
    for _ in range(ncmds):
        cmd, cmdsize = struct.unpack("<II", macho[offset:offset + 8])
        if cmd == LC_SEGMENT_64:
            nsects = struct.unpack("<I", macho[offset + 64:offset + 68])[0]
            sect = offset + 72
            for _ in range(nsects):
                size = struct.unpack("<Q", macho[sect + 40:sect + 48])[0]
                flags = struct.unpack("<I", macho[sect + 64:sect + 68])[0]
                if (flags & 0xFF) in (S_MOD_INIT_FUNC_POINTERS, S_INIT_FUNC_OFFSETS) and size > 0:
                    return True
                sect += 80
        offset += cmdsize
    return False


def activation_checks(path, data):
    """The tweak dylib must be able to start itself inside SpringBoard."""
    findings = []
    slices_list = list(slices(data))
    every = bool(slices_list) and all(has_initializer(body) for _c, _s, body in slices_list)
    findings.append(("OK" if every else "FAIL",
                     f"{path}: initializer (%ctor) present in every slice" if every
                     else f"{path}: no initializer section — the tweak could never start"))
    for needle in (b"HCGSpringBoardBootstrap", b"com.apple.springboard"):
        present = needle in data
        findings.append(("OK" if present else "FAIL", f"{path}: contains {needle.decode()}"))
    return findings


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


BUILD_MARKER = re.compile(rb"HCGNexusBuild:([^:;\x00]+):([^;\x00]+);")


def archive_checks(deb, scheme):
    """Ownership, permissions and entry types of the installed payload."""
    results = []
    tar_bytes = subprocess.run(["dpkg-deb", "--fsys-tarfile", deb], check=True, capture_output=True).stdout
    owners, bad_modes, odd_types = set(), [], []
    with tarfile.open(fileobj=io.BytesIO(tar_bytes)) as tar:
        for m in tar.getmembers():
            name = m.name.lstrip("./") or "/"
            owners.add((m.uid, m.gid))
            if not (m.isdir() or m.isfile()):
                odd_types.append(name)
                continue
            mode = m.mode & 0o7777
            if mode & 0o7000:
                bad_modes.append(f"{name} {oct(mode)} (setuid/setgid/sticky)")
            elif mode & 0o022:
                bad_modes.append(f"{name} {oct(mode)} (group/world-writable)")
            elif m.isdir() and mode != 0o755:
                bad_modes.append(f"{name} {oct(mode)} (directory should be 0755)")
            elif m.isfile():
                executable = os.path.basename(name) in ("HCGNexus.dylib", "HCGNexusPrefs")
                want = 0o755 if executable else 0o644
                if mode != want:
                    bad_modes.append(f"{name} {oct(mode)} (expected {oct(want)})")
    results.append(("OK" if owners == {(0, 0)} else "FAIL", f"payload owned by root (uid/gid 0): {sorted(owners)}"))
    results.append(("FAIL" if bad_modes else "OK", f"payload permissions: {bad_modes or 'dirs 0755, binaries 0755, data 0644'}"))
    results.append(("FAIL" if odd_types else "OK", f"only regular files and directories: {odd_types or 'ok'}"))
    return results


def consistency_checks(tmp, prefix, scheme):
    """Settings bundle wiring and same-build proof for tweak + Settings."""
    results = []
    bundle = os.path.join(tmp, prefix + "Library/PreferenceBundles/HCGNexusPrefs.bundle")
    entry = os.path.join(tmp, prefix + "Library/PreferenceLoader/Preferences/HCGNexusPrefs.plist")
    try:
        info = plistlib.load(open(os.path.join(bundle, "Info.plist"), "rb"))
        ent = plistlib.load(open(entry, "rb")).get("entry", {})
        wired = (info.get("CFBundleExecutable") == "HCGNexusPrefs" and ent.get("bundle") == "HCGNexusPrefs"
                 and info.get("NSPrincipalClass") == ent.get("detail") == "HCGNexusRootListController")
        results.append(("OK" if wired else "FAIL", f"PreferenceLoader entry -> bundle {ent.get('bundle')} / {ent.get('detail')}; "
                        f"Info.plist executable {info.get('CFBundleExecutable')} principal {info.get('NSPrincipalClass')}"))
        version = info.get("CFBundleShortVersionString")
    except Exception as exc:  # noqa: BLE001 - report, don't crash
        results.append(("FAIL", f"Settings bundle plists unreadable: {exc}"))
        version = None
    markers = {}
    for rel in ("Library/MobileSubstrate/DynamicLibraries/HCGNexus.dylib", "Library/PreferenceBundles/HCGNexusPrefs.bundle/HCGNexusPrefs"):
        path = os.path.join(tmp, prefix + rel)
        if os.path.exists(path):
            found = set(BUILD_MARKER.findall(open(path, "rb").read()))
            markers[os.path.basename(rel)] = found
    values = set().union(*markers.values()) if markers else set()
    if len(markers) == 2 and len(values) == 1 and all(markers.values()):
        build_id, config = (v.decode() for v in next(iter(values)))
        results.append(("OK", f"tweak and Settings bundle share build {build_id} ({config})"))
        if scheme:
            results.append(("OK" if config.startswith(scheme + "-") else "FAIL", f"build config {config} matches package scheme {scheme}"))
    else:
        results.append(("FAIL", f"build markers differ or are missing: { {k: sorted(v) for k, v in markers.items()} }"))
    return results, version


def main():
    global REQUIRE_NEW_ABI
    if "--self-test" in sys.argv[1:]:
        return self_test()
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
            checks, bundle_version = consistency_checks(tmp, prefix, scheme)
            results.extend(checks)
            pkg_version = next((l.split(":", 1)[1].strip() for l in control.splitlines() if l.startswith("Version:")), None)
            results.append(("OK" if bundle_version == pkg_version else "FAIL",
                            f"Settings bundle version {bundle_version} == package Version {pkg_version}"))
            if scheme == "rootless":
                stray = [d for d in os.listdir(tmp) if d not in ("DEBIAN", "var")]
                results.append(("FAIL" if stray else "OK", f"nothing outside /var/jb: {stray or 'ok'}"))

        for root, _dirs, files in os.walk(tmp):
            for name in files:
                full = os.path.join(root, name)
                rel = os.path.relpath(full, tmp)
                if name == "HCGNexus.plist":
                    parsed = parse_filter(open(full, "rb").read())
                    ok = parsed == EXPECTED_FILTER
                    results.append(("OK" if ok else "FAIL", f"{rel}: filter = {parsed}"))
                if name in ("HCGNexus.dylib", "HCGNexusPrefs"):
                    data = open(full, "rb").read()
                    results.extend(describe(rel, data))
                    if name == "HCGNexus.dylib":
                        results.extend(activation_checks(rel, data))

    results.extend(archive_checks(deb, scheme))

    failures = 0
    for level, text in results:
        print(f"{level:4}  {text}")
        failures += level == "FAIL"
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
