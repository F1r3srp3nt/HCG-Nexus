#!/usr/bin/env bash
# Builds and runs the Core-layer host tests with clang + GNUstep Base.
# Requires: clang, gnustep-config (Debian/Ubuntu: libgnustep-base-dev).
#
# These tests execute the real Sources/Core code (compiled with manual
# reference counting against the GNU runtime). They do NOT exercise UIKit,
# SpringBoard or any jailbreak runtime — see docs/VALIDATION.md.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT="${HCG_TEST_BUILD_DIR:-$ROOT/.build/host-tests}"
mkdir -p "$OUT"

if ! command -v gnustep-config >/dev/null 2>&1; then
    echo "gnustep-config not found. Install GNUstep Base (e.g. apt-get install libgnustep-base-dev)." >&2
    exit 2
fi

GCC_OBJC_INCLUDE="$(dirname "$(dirname "$(find /usr/lib/gcc -path '*/include/objc/objc.h' 2>/dev/null | head -n1)")")"

clang \
    $(gnustep-config --objc-flags) \
    ${GCC_OBJC_INCLUDE:+-I"$GCC_OBJC_INCLUDE"} \
    -fobjc-runtime=gcc \
    -Wall -Wextra -Wno-unused-parameter -Wno-missing-field-initializers -Werror \
    -Wno-unknown-warning-option -Wno-objc-root-class \
    -I"$ROOT/Sources/Core" \
    "$ROOT"/Sources/Core/*.m \
    "$ROOT"/Tests/Host/*.m \
    -o "$OUT/hcg-host-tests" \
    $(gnustep-config --base-libs) -lm

"$OUT/hcg-host-tests"
