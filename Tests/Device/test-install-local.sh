#!/usr/bin/env bash
# Exercises scripts/device/hcg-nexus-install-local.sh on a computer, against
# the real run #10 .deb, with a simulated device (HCG_TEST_MODE) and stub
# dpkg-query/dpkg. Nothing is installed on this machine.
#
#   Tests/Device/test-install-local.sh <run10.deb> [<other.deb>]
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$ROOT/scripts/device/hcg-nexus-install-local.sh"
GOOD="${1:?path to com.hakmicapitalgroup.hcgnexus_0.2.0_iphoneos-arm64.deb (run #10)}"
OTHER="${2:-}"
NAME="com.hakmicapitalgroup.hcgnexus_0.2.0_iphoneos-arm64.deb"
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
FAILED=0

setup() { # $1 = deb to place, $2 = installed packages ("ellekit preferenceloader")
    rm -rf "$WORK/case"; mkdir -p "$WORK/case/bin" "$WORK/case/jb/etc/apt"
    cp "$1" "$WORK/case/$NAME"
    printf '%s\n' $2 > "$WORK/case/installed"
    cat > "$WORK/case/bin/dpkg-query" <<'EOF'
#!/bin/sh
pkg="$(eval echo \${$#})"
if grep -qx "$pkg" "$HCG_CASE/installed"; then echo "install ok installed|1.0"; fi
EOF
    cat > "$WORK/case/bin/dpkg" <<'EOF'
#!/bin/sh
echo "$*" >> "$HCG_CASE/dpkg.log"; exit 0
EOF
    chmod +x "$WORK/case/bin/"*
}
run() { # env assignments..., then args
    (cd "$WORK/case" && env PATH="$WORK/case/bin:$PATH" HCG_CASE="$WORK/case" HCG_TEST_MODE=1 \
        HCG_TEST_PREFIX="$WORK/case/jb" HCG_TEST_MODEL=iPhone14,2 HCG_TEST_IOS=16.5 HCG_TEST_ARCH=iphoneos-arm64 \
        "$@")
}
expect() { # name, expected exit, actual exit, output, must-contain
    if [ "$3" -eq "$2" ] && grep -q -- "$5" <<<"$4"; then echo "PASS  $1"; else
        echo "FAIL  $1 (exit $3, wanted $2; missing '$5')"; echo "$4" | sed 's/^/      /'; FAILED=1; fi
}

setup "$GOOD" "ellekit preferenceloader"
out="$(run sh "$SCRIPT" 2>&1)"; rc=$?
expect "check mode passes and changes nothing" 0 $rc "$out" "Nothing was changed"
[ ! -f "$WORK/case/dpkg.log" ] && echo "PASS  check mode did not call dpkg -i" || { echo "FAIL  check mode called dpkg"; FAILED=1; }

out="$(run sh "$SCRIPT" --install 2>&1)"; rc=$?
expect "install mode runs dpkg -i on the local file" 0 $rc "$out" "Nothing was resprung"
grep -qx -- "-i ./$NAME" "$WORK/case/dpkg.log" && echo "PASS  dpkg called exactly as: dpkg -i ./$NAME" || { echo "FAIL  dpkg args: $(cat "$WORK/case/dpkg.log")"; FAILED=1; }

out="$(run env HCG_TEST_MODEL=iPhone15,2 sh "$SCRIPT" --install 2>&1)"; rc=$?
expect "refuses another model" 1 $rc "$out" "expected iPhone14,2"

out="$(run env HCG_TEST_IOS=16.6 sh "$SCRIPT" 2>&1)"; rc=$?
expect "refuses another iOS version" 1 $rc "$out" "expected 16.5"

out="$(run env HCG_TEST_ARCH=iphoneos-arm sh "$SCRIPT" 2>&1)"; rc=$?
expect "refuses rootful dpkg architecture" 1 $rc "$out" "expected iphoneos-arm64"

rm -rf "$WORK/case/jb"; out="$(run sh "$SCRIPT" 2>&1)"; rc=$?
expect "refuses without /var/jb" 1 $rc "$out" "not a rootless jailbreak"

setup "$GOOD" "ellekit"
out="$(run sh "$SCRIPT" --install 2>&1)"; rc=$?
expect "refuses without PreferenceLoader (nothing downloaded)" 1 $rc "$out" "preferenceloader is not installed"
[ ! -f "$WORK/case/dpkg.log" ] && echo "PASS  refused install did not call dpkg" || { echo "FAIL  dpkg called after refusal"; FAILED=1; }

setup "$GOOD" "preferenceloader"
out="$(run sh "$SCRIPT" 2>&1)"; rc=$?
expect "refuses without ElleKit/mobilesubstrate" 1 $rc "$out" "neither ellekit nor mobilesubstrate"

setup "$GOOD" "ellekit preferenceloader"
printf 'x' >> "$WORK/case/$NAME"
out="$(run sh "$SCRIPT" --install 2>&1)"; rc=$?
expect "refuses a modified file (SHA-256)" 1 $rc "$out" "wrong or damaged file"

if [ -n "$OTHER" ]; then
    setup "$OTHER" "ellekit preferenceloader"
    out="$(run sh "$SCRIPT" 2>&1)"; rc=$?
    expect "refuses a different build with the same file name" 1 $rc "$out" "wrong or damaged file"
fi

setup "$GOOD" "ellekit preferenceloader"; rm "$WORK/case/$NAME"
out="$(run sh "$SCRIPT" 2>&1)"; rc=$?
expect "refuses when the .deb is missing" 1 $rc "$out" "not found"

echo
[ "$FAILED" -eq 0 ] && echo "All install-helper tests passed." || echo "Some install-helper tests FAILED."
exit "$FAILED"
