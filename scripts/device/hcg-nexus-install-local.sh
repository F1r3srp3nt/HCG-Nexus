# HCG Nexus — verified local install of ONE specific package, no repository.
#
# Run ON THE PHONE (NewTerm or SSH), from the folder holding the .deb:
#
#   sh hcg-nexus-install-local.sh            # checks only; changes nothing
#   sudo sh hcg-nexus-install-local.sh --install
#
# It accepts exactly one file:
#   com.hakmicapitalgroup.hcgnexus_0.2.0_iphoneos-arm64.deb
#   SHA-256 799734e7949b30bf90f2790f602e0043bac3a23e7bd43898f811f2bde3addc2e
#   (Build package run #10, commit 13416698ea72f814e9960c09ff17115c3f00cb4c)
#
# Before installing it checks, and refuses on any mismatch:
#   * the file name and SHA-256 above, and the package's own control fields;
#   * the device: iPhone14,2 (iPhone 13 Pro), iOS 16.5, rootless /var/jb,
#     dpkg architecture iphoneos-arm64;
#   * dependencies already installed: ElleKit (or mobilesubstrate) and
#     PreferenceLoader. Nothing is downloaded.
# It then runs `dpkg -i` on the local file only. It never contacts a
# repository, never edits sources, and never resprings or reboots.
#
# Plain POSIX sh; does not depend on bash.
set -u

EXPECTED_FILE="com.hakmicapitalgroup.hcgnexus_0.2.0_iphoneos-arm64.deb"
EXPECTED_SHA256="799734e7949b30bf90f2790f602e0043bac3a23e7bd43898f811f2bde3addc2e"
EXPECTED_PACKAGE="com.hakmicapitalgroup.hcgnexus"
EXPECTED_VERSION="0.2.0"
EXPECTED_ARCH="iphoneos-arm64"
EXPECTED_MODEL="iPhone14,2"
EXPECTED_MODEL_NAME="iPhone 13 Pro"
EXPECTED_IOS="16.5"
PREFIX="/var/jb"

# Test hooks (used by scripts/test-install-local.sh on a computer only).
if [ "${HCG_TEST_MODE:-0}" = "1" ]; then
    PREFIX="${HCG_TEST_PREFIX:?}"
fi

MODE="check"
for arg in "$@"; do
    case "$arg" in
        --install) MODE="install" ;;
        -h|--help) sed -n '2,24p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "Unknown option: $arg (use --install or --help)"; exit 2 ;;
    esac
done

FAILED=0
ok()   { printf 'OK    %s\n' "$1"; }
bad()  { printf 'FAIL  %s\n' "$1"; FAILED=1; }
note() { printf '      %s\n' "$1"; }

device_model() {
    if [ "${HCG_TEST_MODE:-0}" = "1" ]; then echo "${HCG_TEST_MODEL:-}"; return; fi
    m="$(sysctl -n hw.machine 2>/dev/null)"
    [ -n "$m" ] && { echo "$m"; return; }
    uname -m 2>/dev/null
}
ios_version() {
    if [ "${HCG_TEST_MODE:-0}" = "1" ]; then echo "${HCG_TEST_IOS:-}"; return; fi
    v="$(sysctl -n kern.osproductversion 2>/dev/null)"
    [ -n "$v" ] && { echo "$v"; return; }
    if command -v sw_vers >/dev/null 2>&1; then sw_vers -productVersion 2>/dev/null && return; fi
    sed -n '/<key>ProductVersion<\/key>/{n;s/.*<string>\(.*\)<\/string>.*/\1/p;}' /System/Library/CoreServices/SystemVersion.plist 2>/dev/null
}
dpkg_arch() {
    if [ "${HCG_TEST_MODE:-0}" = "1" ]; then echo "${HCG_TEST_ARCH:-}"; return; fi
    dpkg --print-architecture 2>/dev/null
}
installed() { # package -> version if installed, else empty
    dpkg-query -W -f='${Status}|${Version}\n' "$1" 2>/dev/null | sed -n 's/^install ok installed|//p'
}
sha256_of() {
    if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | cut -d' ' -f1
    elif command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | cut -d' ' -f1
    elif command -v openssl >/dev/null 2>&1; then openssl dgst -sha256 "$1" | sed 's/.*= //'
    else echo ""; fi
}

echo "== Package file =="
DEB="./$EXPECTED_FILE"
if [ ! -f "$DEB" ]; then
    bad "$EXPECTED_FILE not found in $(pwd). Put this script next to the .deb and run it from that folder."
else
    ok "found $EXPECTED_FILE"
    SUM="$(sha256_of "$DEB")"
    if [ -z "$SUM" ]; then bad "no SHA-256 tool (sha256sum, shasum or openssl) found"
    elif [ "$SUM" = "$EXPECTED_SHA256" ]; then ok "SHA-256 $SUM"
    else bad "SHA-256 is $SUM, expected $EXPECTED_SHA256 — wrong or damaged file; do not install it"; fi
    if command -v dpkg-deb >/dev/null 2>&1; then
        P="$(dpkg-deb -f "$DEB" Package 2>/dev/null)"; V="$(dpkg-deb -f "$DEB" Version 2>/dev/null)"; A="$(dpkg-deb -f "$DEB" Architecture 2>/dev/null)"
        if [ "$P|$V|$A" = "$EXPECTED_PACKAGE|$EXPECTED_VERSION|$EXPECTED_ARCH" ]; then ok "control: $P $V $A"
        else bad "control fields are '$P $V $A', expected '$EXPECTED_PACKAGE $EXPECTED_VERSION $EXPECTED_ARCH'"; fi
        if dpkg-deb -c "$DEB" 2>/dev/null | awk '{print $6}' | grep -Eqv '^\.?/?$|^(\./)?var/?$|^(\./)?var/jb(/.*)?$'; then
            bad "package contains files outside /var/jb"
        else ok "all files install under /var/jb"; fi
    else
        bad "dpkg-deb not found (is this the jailbroken phone?)"
    fi
fi

echo "== Device =="
MODEL="$(device_model)"; IOS="$(ios_version)"; ARCH="$(dpkg_arch)"
[ "$MODEL" = "$EXPECTED_MODEL" ] && ok "model $MODEL ($EXPECTED_MODEL_NAME)" || bad "model is '${MODEL:-unknown}', expected $EXPECTED_MODEL ($EXPECTED_MODEL_NAME)"
[ "$IOS" = "$EXPECTED_IOS" ] && ok "iOS $IOS" || bad "iOS is '${IOS:-unknown}', expected $EXPECTED_IOS"
[ -d "$PREFIX" ] && ok "rootless prefix $PREFIX exists" || bad "$PREFIX missing: this is not a rootless jailbreak (Dopamine)"
[ "$ARCH" = "$EXPECTED_ARCH" ] && ok "dpkg architecture $ARCH" || bad "dpkg architecture is '${ARCH:-unknown}', expected $EXPECTED_ARCH"

echo "== Dependencies (must already be installed; nothing is downloaded) =="
EK="$(installed ellekit)"; MS="$(installed mobilesubstrate)"; PL="$(installed preferenceloader)"
if [ -n "$EK" ]; then ok "ElleKit $EK"
elif [ -n "$MS" ]; then ok "mobilesubstrate $MS (ElleKit not installed as 'ellekit')"
else bad "neither ellekit nor mobilesubstrate is installed — install ElleKit from Dopamine's default sources first"; fi
[ -n "$PL" ] && ok "PreferenceLoader $PL" || bad "preferenceloader is not installed — install it from your default sources first (Settings › HCG Nexus needs it)"

echo "== Current state =="
CUR="$(installed "$EXPECTED_PACKAGE")"
[ -n "$CUR" ] && note "HCG Nexus $CUR is installed now; dpkg will replace it with $EXPECTED_VERSION" || note "HCG Nexus is not installed"
if grep -rqs 'hakmicapitalgroup' "$PREFIX/etc/apt/sources.list.d" "$PREFIX/etc/apt/sources.list" 2>/dev/null; then
    note "an HCG source is still listed in $PREFIX/etc/apt — not needed for this install and not touched by it"
fi

echo
if [ "$FAILED" -ne 0 ]; then
    echo "Checks FAILED. Nothing was installed."
    exit 1
fi
if [ "$MODE" = "check" ]; then
    echo "All checks passed. Nothing was changed."
    echo "To install:  sudo sh $(basename "$0") --install"
    exit 0
fi
if [ "$(id -u)" != "0" ]; then
    echo "Installing needs root: sudo sh $(basename "$0") --install"
    exit 1
fi
echo "== Install (local file only) =="
echo "dpkg -i $DEB"
if dpkg -i "$DEB"; then
    echo
    echo "Installed: $(installed "$EXPECTED_PACKAGE")"
    echo "Nexus is OFF until you enable it. Nothing was resprung."
    echo "Next: respring when you choose (Dopamine app › Respring), then open Settings › HCG Nexus."
    exit 0
fi
echo "dpkg reported an error. Nothing else was changed; see the output above."
exit 1
