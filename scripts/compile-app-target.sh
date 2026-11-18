#!/usr/bin/env bash
# Compile-and-link check for the standalone app target WITHOUT Xcode.
#
# Compiles exactly the sources that scripts/generate_xcodeproj.py puts in the
# HCGNexus app target (Objective-C, ARC, HCG_STANDALONE_APP=1) for
# arm64-apple-ios<deployment target> and links an executable against the given
# iPhoneOS SDK. This proves the sources compile and every symbol resolves from
# public SDK frameworks; it is NOT a substitute for an Xcode build (no asset
# catalog, Info.plist processing, signing or simulator run). The Swift side of
# HCG Device Link (Sources/Platform/App/DeviceLink/*.swift and the vendored
# HCGDeviceLink package) is NOT compiled here: the Objective-C screens reach it
# only through HCGLinkTypes.h and NSClassFromString, so they compile and link on
# their own. Only the Xcode build (CI "app" job) compiles the Swift.
#
#   scripts/compile-app-target.sh [SDK path ...]
#
# Defaults to $THEOS/sdks/iPhoneOS*.sdk with $THEOS/toolchain/linux/iphone/bin/clang
# on Linux, or xcrun's clang/SDK on macOS.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
DEPLOYMENT_TARGET="$(sed -n 's/^DEPLOYMENT_TARGET = "\(.*\)"/\1/p' scripts/generate_xcodeproj.py)"
OUT="${HCG_APP_CHECK_DIR:-$ROOT/.build/app-target-check}"
mkdir -p "$OUT"

# `@available` checks call ___isOSVersionAtLeast from clang's compiler-rt,
# which Xcode links automatically. The Linux Theos toolchain ships no iOS
# compiler-rt, so only that one symbol is allowed to stay undefined there.
EXTRA_LDFLAGS=()
if [ "$(uname)" = "Darwin" ]; then
    CLANG="$(xcrun --sdk iphoneos -f clang)"
    SDKS=("${@:-$(xcrun --sdk iphoneos --show-sdk-path)}")
else
    : "${THEOS:?set THEOS (Linux) to use the Theos iOS toolchain}"
    CLANG="$THEOS/toolchain/linux/iphone/bin/clang"
    if [ "$#" -gt 0 ]; then SDKS=("$@"); else SDKS=("$THEOS"/sdks/iPhoneOS*.sdk); fi
    EXTRA_LDFLAGS=(-Wl,-U,___isOSVersionAtLeast)
fi

mapfile -t SOURCES < <(python3 -I scripts/generate_xcodeproj.py --list)
echo "App target: ${#SOURCES[@]} sources, deployment target iOS $DEPLOYMENT_TARGET"

status=0
for SDK in "${SDKS[@]}"; do
    name="$(basename "$SDK" .sdk)"
    exe="$OUT/HCGNexus-$name"
    if "$CLANG" -target "arm64-apple-ios$DEPLOYMENT_TARGET" -isysroot "$SDK" \
        -fobjc-arc -fobjc-weak -Wall -Werror -Wno-deprecated-declarations -Wno-unknown-warning-option \
        -DHCG_STANDALONE_APP=1 \
        -ISources/Core -ISources/Panel -ISources/Platform/App -ISources/Platform/App/DeviceLink -IApp \
        "${SOURCES[@]}" \
        -framework Foundation -framework UIKit -framework QuartzCore -framework CoreGraphics "${EXTRA_LDFLAGS[@]}" \
        -o "$exe" 2> "$OUT/$name.log"; then
        echo "PASS  compiled and linked against $name ($(stat -c%s "$exe" 2>/dev/null || stat -f%z "$exe") bytes)"
    else
        echo "FAIL  $name — see $OUT/$name.log"; head -40 "$OUT/$name.log"; status=1
    fi
done
exit $status
