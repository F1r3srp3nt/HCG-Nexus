#!/usr/bin/env bash
# Build and verify the HCG Nexus jailbreak package (.deb) on a Mac.
#
#   scripts/build-jailbreak-deb.sh                  # rootless (Dopamine, palera1n rootless)
#   scripts/build-jailbreak-deb.sh --env rootful    # rootful (e.g. iOS 14.x jailbreaks)
#   scripts/build-jailbreak-deb.sh --archs arm64    # A11 or older devices only
#   scripts/build-jailbreak-deb.sh --check-only     # preflight, no build
#
# Before building it checks Theos, the SDK the Makefile asks for, Xcode's
# clang (the new arm64e ABI needs Apple clang 12+), ldid, GNU make 4+, perl,
# dpkg-deb and python3. After building it runs scripts/inspect-package.py
# with --require-new-arm64e-abi.
#
# It never installs anything, never contacts a device and never resprings.
# The verified .deb is left in --output (default: ./packages/<env>).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_NAME="rootless"
ARCHS=""
OUTPUT=""
CHECK_ONLY=0

usage() { sed -n '2,16p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; }
while [ $# -gt 0 ]; do
    case "$1" in
        --env) ENV_NAME="${2:?}"; shift 2 ;;
        --archs) ARCHS="${2:?}"; shift 2 ;;
        --output) OUTPUT="${2:?}"; shift 2 ;;
        --check-only) CHECK_ONLY=1; shift ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown option: $1" >&2; usage; exit 2 ;;
    esac
done
case "$ENV_NAME" in rootless|rootful) ;; *) echo "--env must be rootless or rootful (roothide is not set up)." >&2; exit 2 ;; esac
[ -n "$OUTPUT" ] || OUTPUT="$ROOT/packages/$ENV_NAME"

FAILED=0
ok()   { printf 'OK    %s\n' "$1"; }
bad()  { printf 'FAIL  %s\n' "$1"; FAILED=1; }
info() { printf '      %s\n' "$1"; }

echo "== Preflight ($ENV_NAME) =="
if [ "$(uname)" != "Darwin" ]; then
    bad "macOS required (found $(uname)). The arm64e slice needs Apple's clang; Linux toolchains emit the pre-iOS-14 ABI."
fi

# Theos
THEOS="${THEOS:-}"
if [ -z "$THEOS" ]; then
    for candidate in "$HOME/theos" /opt/theos; do [ -f "$candidate/makefiles/common.mk" ] && THEOS="$candidate" && break; done
fi
if [ -n "$THEOS" ] && [ -f "$THEOS/makefiles/common.mk" ]; then
    ok "Theos: $THEOS"
    case "$THEOS" in *" "*) bad "Theos path contains a space; Theos makefiles cannot handle that." ;; esac
    [ -f "$THEOS/bin/dm.pl" ] && [ -d "$THEOS/vendor/include" ] || bad "Theos checkout looks incomplete (bin/dm.pl or vendor/include missing). Run: git -C \"$THEOS\" submodule update --init --recursive"
else
    bad "Theos not found. Install: git clone --recursive https://github.com/theos/theos.git ~/theos ; export THEOS=~/theos"
fi
export THEOS

# SDK required by the Makefile for this environment (TARGET := iphone:clang:<SDK>:<deploy>)
TARGET_LINE="$(awk -v env="$ENV_NAME" '
    $0 ~ "HCG_ENV\\),"env"\\)" {found=1; next}
    found && /TARGET :=/ {print $3; exit}
    found && /^else|^endif/ {found=0}' "$ROOT/Makefile")"
SDK_VERSION="$(echo "$TARGET_LINE" | cut -d: -f3)"
DEPLOY_VERSION="$(echo "$TARGET_LINE" | cut -d: -f4)"
if [ -z "$SDK_VERSION" ]; then
    bad "Could not read TARGET for HCG_ENV=$ENV_NAME from Makefile"
elif [ -n "$THEOS" ] && [ -d "$THEOS/sdks/iPhoneOS$SDK_VERSION.sdk" ]; then
    ok "SDK: \$THEOS/sdks/iPhoneOS$SDK_VERSION.sdk (deployment target iOS $DEPLOY_VERSION)"
else
    bad "SDK iPhoneOS$SDK_VERSION.sdk missing from \$THEOS/sdks (needed for HCG_ENV=$ENV_NAME)."
    info "Install it from https://github.com/theos/sdks, e.g.:"
    info "git clone --depth 1 --filter=blob:none --sparse https://github.com/theos/sdks.git /tmp/sdks && git -C /tmp/sdks sparse-checkout set iPhoneOS$SDK_VERSION.sdk && cp -R /tmp/sdks/iPhoneOS$SDK_VERSION.sdk \"\$THEOS/sdks/\""
fi

# Xcode clang (new arm64e ABI)
if command -v xcode-select >/dev/null 2>&1; then
    DEV_DIR="$(xcode-select -p 2>/dev/null || true)"
    case "$DEV_DIR" in
        *CommandLineTools*|"") bad "Xcode is not selected (xcode-select -p: ${DEV_DIR:-none}). Run: sudo xcode-select -s /Applications/Xcode.app" ;;
        *) ok "Xcode: $DEV_DIR ($(xcodebuild -version 2>/dev/null | head -1))" ;;
    esac
    CLANG_VERSION="$(xcrun --sdk iphoneos clang --version 2>/dev/null | head -1 || true)"
    CLANG_MAJOR="$(echo "$CLANG_VERSION" | sed -n 's/.*clang version \([0-9][0-9]*\).*/\1/p')"
    if [ -n "$CLANG_MAJOR" ] && [ "$CLANG_MAJOR" -ge 12 ] && echo "$CLANG_VERSION" | grep -q "Apple"; then
        ok "Compiler: $CLANG_VERSION (emits the iOS 14+ arm64e ABI)"
    else
        bad "Apple clang 12 or newer required for arm64e (found: ${CLANG_VERSION:-none})."
    fi
fi

# GNU make 4+
MAKE_BIN=""
for candidate in gmake make; do
    if command -v "$candidate" >/dev/null 2>&1; then
        major="$("$candidate" --version 2>/dev/null | sed -n '1s/.*Make \([0-9][0-9]*\).*/\1/p')"
        if [ -n "$major" ] && [ "$major" -ge 4 ]; then MAKE_BIN="$candidate"; break; fi
    fi
done
[ -n "$MAKE_BIN" ] && ok "GNU make: $($MAKE_BIN --version | head -1) ($MAKE_BIN)" || bad "GNU make 4+ not found (macOS ships 3.81). Install: brew install make (provides gmake)"

# Signing & packaging tools
if command -v ldid >/dev/null 2>&1; then ok "ldid: $(command -v ldid)"; else bad "ldid not found (Theos signs with it). Install: brew install ldid"; fi
command -v perl >/dev/null 2>&1 && ok "perl: $(perl -e 'print $^V')" || bad "perl not found"
command -v dpkg-deb >/dev/null 2>&1 && ok "dpkg-deb: $(command -v dpkg-deb)" || bad "dpkg-deb not found (needed to verify the package). Install: brew install dpkg"
command -v python3 >/dev/null 2>&1 && ok "python3: $(python3 --version 2>&1)" || bad "python3 not found"

# Package metadata
grep -q '^Depends:.*preferenceloader' "$ROOT/control" && ok "control: $(grep '^Depends:' "$ROOT/control")" || bad "control has no Depends on preferenceloader"

if [ "$FAILED" -ne 0 ]; then
    echo; echo "Preflight failed; nothing was built."; exit 1
fi
[ "$CHECK_ONLY" -eq 1 ] && { echo; echo "Preflight passed (--check-only: not building)."; exit 0; }

echo; echo "== Build =="
mkdir -p "$OUTPUT"
find "$OUTPUT" -maxdepth 1 -name 'com.hakmicapitalgroup.hcgnexus_*.deb' -delete
cd "$ROOT"
"$MAKE_BIN" clean "HCG_ENV=$ENV_NAME" >/dev/null
MAKE_ARGS=(package FINALPACKAGE=1 "HCG_ENV=$ENV_NAME" "THEOS_PACKAGE_DIR=$OUTPUT")
[ -n "$ARCHS" ] && MAKE_ARGS+=("HCG_ARCHS=$ARCHS")
echo "$MAKE_BIN ${MAKE_ARGS[*]}"
"$MAKE_BIN" "${MAKE_ARGS[@]}"

DEB="$(ls "$OUTPUT"/com.hakmicapitalgroup.hcgnexus_*.deb 2>/dev/null | head -n1)"
[ -n "$DEB" ] || { echo "FAIL  make succeeded but no .deb was written to $OUTPUT"; exit 1; }

echo; echo "== Verify =="
python3 -I "$ROOT/scripts/inspect-package.py" "$DEB" "$ENV_NAME" --require-new-arm64e-abi
dpkg-deb -f "$DEB" Package Version Architecture Depends

echo
echo "Verified package: $DEB"
echo "SHA-256: $(shasum -a 256 "$DEB" | cut -d' ' -f1)"
echo "Nothing was installed. To install, copy it to the device and open it with your package manager (see docs/INSTALL-AND-RECOVERY.md)."
