#!/usr/bin/env python3
"""Validates HCG Nexus's border definition for HCG Halo (docs/HALO-BORDER.md).

    python3 scripts/check_halo_border.py [path/to/HaloBorder.plist] [--version 0.3.1~beta1]
    python3 scripts/check_halo_border.py --self-test

Schema 1 is strict: every key, type and range below is required exactly; unknown
keys are rejected. HCG Halo applies the same rules (HaloNexusDefinition.m) before
using an installed file. Standard library only; reads XML and binary plists
(Theos converts bundle plists to binary on macOS).
"""
import os
import plistlib
import re
import sys

SCHEMA = "com.hakmicapitalgroup.hcgnexus.halo-border"
MAX_BYTES = 16 * 1024
CAPABILITIES = {"live-geometry", "open-close-events", "presentation-progress", "workspace-events", "orientation", "keyboard-resize"}
REQUIRED_CAPABILITIES = {"live-geometry", "open-close-events"}
TOP_REQUIRED = {"schema", "schemaVersion", "interfaceVersion", "interfaceClass", "nexusVersion", "shape", "anchors", "capabilities"}
TOP_OPTIONAL = {"style"}


def is_int(v):
    return isinstance(v, int) and not isinstance(v, bool)


def is_num(v):
    return (isinstance(v, (int, float)) and not isinstance(v, bool)) and v == v and abs(v) != float("inf")


def validate(data, expected_version=None):
    """Returns a list of problems (empty when valid)."""
    problems = []
    if len(data) > MAX_BYTES:
        return [f"file is {len(data)} bytes (limit {MAX_BYTES})"]
    try:
        d = plistlib.loads(data)
    except Exception as e:  # noqa: BLE001 - any parse failure is a validation failure
        return [f"not a property list: {e}"]
    if not isinstance(d, dict):
        return ["top level is not a dictionary"]
    keys = set(d)
    if TOP_REQUIRED - keys:
        problems.append(f"missing keys: {sorted(TOP_REQUIRED - keys)}")
    if keys - TOP_REQUIRED - TOP_OPTIONAL:
        problems.append(f"unknown keys: {sorted(keys - TOP_REQUIRED - TOP_OPTIONAL)}")
    if d.get("schema") != SCHEMA:
        problems.append(f"schema is {d.get('schema')!r}")
    for key in ("schemaVersion", "interfaceVersion"):
        if not (is_int(d.get(key)) and d.get(key) == 1):
            problems.append(f"{key} must be the integer 1 (got {d.get(key)!r})")
    if d.get("interfaceClass") != "HCGNexusBorderInterface":
        problems.append(f"interfaceClass is {d.get('interfaceClass')!r}")
    version = d.get("nexusVersion")
    if not (isinstance(version, str) and re.fullmatch(r"[0-9][0-9A-Za-z.~+-]{0,31}", version)):
        problems.append(f"nexusVersion is {version!r}")
    elif expected_version and version != expected_version:
        problems.append(f"nexusVersion {version} != package Version {expected_version}")

    shape = d.get("shape")
    if not isinstance(shape, dict) or set(shape) != {"kind", "cornerRadius", "cornerCurve"}:
        problems.append(f"shape must have exactly kind, cornerRadius, cornerCurve (got {shape!r})")
    else:
        if shape["kind"] != "rounded-rect":
            problems.append(f"shape.kind is {shape['kind']!r}")
        if not (is_num(shape["cornerRadius"]) and 0 <= shape["cornerRadius"] <= 64):
            problems.append(f"shape.cornerRadius out of range: {shape['cornerRadius']!r}")
        if shape["cornerCurve"] not in ("continuous", "circular"):
            problems.append(f"shape.cornerCurve is {shape['cornerCurve']!r}")

    anchors = d.get("anchors")
    if not isinstance(anchors, dict) or set(anchors) != {"host", "outset", "glowMargin", "clipInterior"}:
        problems.append(f"anchors must have exactly host, outset, glowMargin, clipInterior (got {anchors!r})")
    else:
        if anchors["host"] != "panel":
            problems.append(f"anchors.host is {anchors['host']!r}")
        if not (is_num(anchors["outset"]) and 0 <= anchors["outset"] <= 12):
            problems.append(f"anchors.outset out of range: {anchors['outset']!r}")
        if not (is_num(anchors["glowMargin"]) and 8 <= anchors["glowMargin"] <= 64):
            problems.append(f"anchors.glowMargin out of range: {anchors['glowMargin']!r}")
        if not isinstance(anchors["clipInterior"], bool):
            problems.append("anchors.clipInterior must be a boolean")

    caps = d.get("capabilities")
    if not (isinstance(caps, list) and all(isinstance(c, str) for c in caps) and len(set(caps)) == len(caps or [])):
        problems.append(f"capabilities must be a list of unique strings (got {caps!r})")
    else:
        if set(caps) - CAPABILITIES:
            problems.append(f"unknown capabilities: {sorted(set(caps) - CAPABILITIES)}")
        if REQUIRED_CAPABILITIES - set(caps):
            problems.append(f"missing capabilities: {sorted(REQUIRED_CAPABILITIES - set(caps))}")

    if "style" in d:
        style = d["style"]
        if not isinstance(style, dict) or set(style) - {"defaultPreset"}:
            problems.append(f"style may only contain defaultPreset (got {style!r})")
        elif "defaultPreset" in style and not (isinstance(style["defaultPreset"], str)
                                               and re.fullmatch(r"builtin\.[a-z0-9-]{1,32}", style["defaultPreset"])):
            problems.append(f"style.defaultPreset is {style['defaultPreset']!r}")
    return problems


def self_test():
    good_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "Prefs", "Resources", "HaloBorder.plist")
    good = plistlib.load(open(good_path, "rb"))
    cases = [("source file", good, True)]

    def variant(label, mutate):
        d = plistlib.loads(plistlib.dumps(good))
        mutate(d)
        cases.append((label, d, False))

    variant("wrong schema", lambda d: d.update(schema="x"))
    variant("schema version 2", lambda d: d.update(schemaVersion=2))
    variant("boolean version", lambda d: d.update(schemaVersion=True))
    variant("unknown key", lambda d: d.update(script="rm -rf /"))
    variant("other class", lambda d: d.update(interfaceClass="NSFileManager"))
    variant("huge radius", lambda d: d["shape"].update(cornerRadius=500))
    variant("negative outset", lambda d: d["anchors"].update(outset=-1))
    variant("unknown capability", lambda d: d["capabilities"].append("run-code"))
    variant("missing capability", lambda d: d["capabilities"].remove("live-geometry"))
    variant("duplicate capability", lambda d: d["capabilities"].append("orientation"))
    variant("missing shape", lambda d: d.pop("shape"))
    variant("bad preset", lambda d: d["style"].update(defaultPreset="../x"))
    failures = 0
    for label, d, ok in cases:
        for fmt in (plistlib.FMT_XML, plistlib.FMT_BINARY):
            got = not validate(plistlib.dumps(d, fmt=fmt))
            if got != ok:
                failures += 1
                print(f"FAIL  self-test {label} ({fmt}): expected {'valid' if ok else 'invalid'}")
    if validate(b"not a plist") == [] or validate(b"x" * (MAX_BYTES + 1)) == []:
        failures += 1
        print("FAIL  self-test: garbage or oversize accepted")
    print(f"{'OK' if not failures else 'FAIL'}  check_halo_border self-test: {len(cases) * 2 + 2} cases")
    return 1 if failures else 0


def main(argv):
    if "--self-test" in argv:
        return self_test()
    expected = None
    if "--version" in argv:
        expected = argv[argv.index("--version") + 1]
        argv = [a for i, a in enumerate(argv) if a != "--version" and (i == 0 or argv[i - 1] != "--version")]
    path = argv[0] if argv else os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "Prefs", "Resources", "HaloBorder.plist")
    problems = validate(open(path, "rb").read(), expected)
    for p in problems:
        print(f"FAIL  {p}")
    print(f"{'OK' if not problems else 'FAIL'}  {path}: HCG Halo border definition (schema 1)")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
