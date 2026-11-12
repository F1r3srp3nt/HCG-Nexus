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

# The GNU Objective-C runtime (gobjc / libobjc-N-dev) lives in a GCC-version
# directory that clang does not necessarily search (it may pick a newer GCC).
# Use the directory that actually contains both libobjc.so and objc/objc.h.
OBJC_DIR=""
for candidate in $(find /usr/lib/gcc -name libobjc.so 2>/dev/null | sort -rV); do
    dir="$(dirname "$candidate")"
    if [ -f "$dir/include/objc/objc.h" ]; then OBJC_DIR="$dir"; break; fi
done
if [ -z "$OBJC_DIR" ]; then
    echo "GNU Objective-C runtime not found. Install it (e.g. apt-get install gobjc)." >&2
    exit 2
fi

clang \
    $(gnustep-config --objc-flags) \
    -I"$OBJC_DIR/include" -L"$OBJC_DIR" \
    -fobjc-runtime=gcc \
    -Wall -Wextra -Wno-unused-parameter -Wno-missing-field-initializers -Werror \
    -Wno-unknown-warning-option -Wno-objc-root-class \
    -I"$ROOT/Sources/Core" \
    "$ROOT"/Sources/Core/*.m \
    "$ROOT"/Tests/Host/*.m \
    -o "$OUT/hcg-host-tests" \
    $(gnustep-config --base-libs) -lm

"$OUT/hcg-host-tests"
