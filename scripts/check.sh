#!/usr/bin/env bash
# Source and automated checks for HCG Nexus. Safe to run anywhere: it never
# installs, uploads or touches a device.
#
#   scripts/check.sh                 # lint + Core host tests
#   HCG_ENV=rootless scripts/check.sh # + Theos package build & package inspection (needs $THEOS)
#   HCG_REQUIRE_NEW_ABI=1 ...         # treat an old-ABI arm64e slice as a failure (A12+ devices)
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
FAILED=0
pass() { printf 'PASS  %s\n' "$1"; }
fail() { printf 'FAIL  %s\n' "$1"; FAILED=1; }
check() { local name="$1"; shift; if "$@" >/dev/null 2>&1; then pass "$name"; else fail "$name"; fi; }
absent() { # name pattern paths...
    local name="$1" pattern="$2"; shift 2
    local hits
    # Ignore matches on comment lines (//, #, *).
    hits="$(grep -RnE -- "$pattern" "$@" 2>/dev/null | grep -vE '^[^:]+:[0-9]+:[[:space:]]*(//|#|\*)' || true)"
    if [ -z "$hits" ]; then pass "$name"; else fail "$name"; printf '%s\n' "$hits" | sed 's/^/      /'; fi
}

echo "== Core portability (host-testable subset) =="
absent "Core: no UIKit/CoreGraphics imports" '#import <(UIKit|CoreGraphics|QuartzCore)' Sources/Core
absent "Core: no @YES/@NO literals" '@(YES|NO)\b' Sources/Core
absent "Core: no blocks" '\^[[:space:]]*\{|\(\^|\^[[:space:]]*\([^)]*\)[[:space:]]*\{' Sources/Core
absent "Core: no __weak" '__weak' Sources/Core
absent "Core: no object subscripting" '[A-Za-z_\]\)]\[(@"|[a-z_][A-Za-z0-9_]*\])' Sources/Core

echo "== Safety rules =="
absent "No secure (lock-screen) windows" '_setSecure|setSecure:' Sources Tweak Prefs PreviewHarness
absent "No automatic respring/kill in build or package" 'INSTALL_TARGET_PROCESSES|sbreload|killall|ldrestart|uicache|reboot' Makefile Prefs/Makefile PreviewHarness/Makefile layout
check  "No maintainer scripts in layout" test ! -e layout/DEBIAN/postinst -a ! -e layout/DEBIAN/preinst -a ! -e layout/DEBIAN/prerm -a ! -e layout/DEBIAN/postrm
absent "No method hooks in the SpringBoard layer" '%hook|MSHookMessageEx|MSHookFunction|method_exchangeImplementations|method_setImplementation' Tweak Sources
absent "No embedded credentials" '(password|passwd|secret|api[_-]?key|bearer)[[:space:]]*[:=][[:space:]]*@?"[^"]+' Sources Prefs PreviewHarness Tweak
absent "No HCG Server admin endpoints or tokens" '127\.0\.0\.1|:7600|:7610|/api/v1|#token=' Sources Prefs Tweak
absent "No invented HCG URL schemes" '(hcgterminal|hcgnews|hcgserver|hcgnexus)://' Sources Prefs Tweak PreviewHarness
check  "Tweak filter targets only SpringBoard" grep -qx '{ Filter = { Bundles = ( "com.apple.springboard" ); }; }' HCGNexus.plist

echo "== Metadata =="
CONTROL_VERSION="$(sed -n 's/^Version: //p' control)"
CODE_VERSION="$(sed -n 's/^#define HCG_NEXUS_VERSION @"\(.*\)"/\1/p' Sources/Core/HCGConstants.h)"
if [ "$CONTROL_VERSION" = "$CODE_VERSION" ]; then pass "Version $CONTROL_VERSION matches control"; else fail "Version mismatch: control=$CONTROL_VERSION code=$CODE_VERSION"; fi
for plist in Prefs/Resources/*.plist Prefs/entry.plist PreviewHarness/Resources/Info.plist; do
    check "plist parses: $plist" python3 -I -c 'import plistlib,sys; plistlib.load(open(sys.argv[1],"rb"))' "$plist"
done
check "Defaults: Root.plist 'enabled' default is false" python3 -I -c '
import plistlib,sys
items=plistlib.load(open("Prefs/Resources/Root.plist","rb"))["items"]
sys.exit(0 if any(i.get("key")=="enabled" and i.get("default") is False for i in items) else 1)'

echo "== Core host tests =="
if Tests/Host/run.sh; then pass "Core host tests"; else fail "Core host tests"; fi

if [ -n "${HCG_ENV:-}" ]; then
    echo "== Theos package build ($HCG_ENV) =="
    if [ -z "${THEOS:-}" ]; then
        fail "THEOS is not set"
    else
        rm -rf packages
        if make clean >/dev/null 2>&1 && make package HCG_ENV="$HCG_ENV" FINALPACKAGE=1 >/tmp/hcg-nexus-build.log 2>&1; then
            pass "make package HCG_ENV=$HCG_ENV"
            DEB="$(ls packages/*.deb | head -n1)"
            ABI_FLAG=""
            [ "${HCG_REQUIRE_NEW_ABI:-0}" = "1" ] && ABI_FLAG="--require-new-arm64e-abi"
            if python3 -I scripts/inspect-package.py "$DEB" "$HCG_ENV" $ABI_FLAG; then pass "package inspection"; else fail "package inspection"; fi
        else
            fail "make package HCG_ENV=$HCG_ENV (see /tmp/hcg-nexus-build.log)"
            grep -E "error" /tmp/hcg-nexus-build.log | head -20
        fi
    fi
fi

echo
if [ "$FAILED" -eq 0 ]; then echo "All checks passed."; else echo "Some checks FAILED."; fi
exit "$FAILED"
