#!/bin/sh
# HCG Nexus — collect runtime evidence after a device test (docs/DEVICE-TEST-0.6.0.md, section 16).
#
# Run ON THE PHONE (HCG Terminal Unleashed, NewTerm or SSH):
#
#   sh hcg-nexus-collect-evidence.sh              # writes the report only
#   sh hcg-nexus-collect-evidence.sh --copy-logs  # also copies the newest SpringBoard / HCG Nexus crash and
#                                                 # JetsamEvent reports next to the report
#
# Read-only for the system: it never resprings, installs, removes, kills or changes settings, and makes no network
# connection. It writes only into /var/mobile/Documents/hcg-nexus-evidence-<time>/. Crash reports contain the device
# model and iOS build; share the folder only with whoever is diagnosing the failure.

set -u
STAMP=$(date -u +%Y%m%d-%H%M%S)
OUT="/var/mobile/Documents/hcg-nexus-evidence-$STAMP"
mkdir -p "$OUT" || { echo "cannot create $OUT"; exit 1; }
REPORT="$OUT/report.txt"
COPY=0
[ "${1:-}" = "--copy-logs" ] && COPY=1

section() { printf '\n== %s ==\n' "$1" >> "$REPORT"; }
run() { printf '$ %s\n' "$*" >> "$REPORT"; "$@" >> "$REPORT" 2>&1 || printf '(exit %s)\n' "$?" >> "$REPORT"; }

printf 'HCG Nexus device evidence, %s UTC\n' "$(date -u '+%Y-%m-%d %H:%M:%S')" > "$REPORT"

section "Device and iOS"
run uname -a
command -v sw_vers >/dev/null 2>&1 && run sw_vers
command -v sysctl >/dev/null 2>&1 && run sysctl -n hw.machine kern.osversion
[ -d /var/jb ] && echo "layout: rootless (/var/jb present)" >> "$REPORT" || echo "layout: /var/jb not present" >> "$REPORT"

section "Installed packages"
if command -v dpkg-query >/dev/null 2>&1; then
    dpkg-query -W -f='${Package} ${Version} ${Status}\n' 2>/dev/null | grep -E 'hcgnexus|hakmicapitalgroup|ellekit|preferenceloader|mobilesubstrate|substitute|libhooker' >> "$REPORT"
else
    echo "dpkg-query not found" >> "$REPORT"
fi

section "HCG Nexus state"
PREFS=/var/mobile/Library/Preferences/com.hakmicapitalgroup.hcgnexus.plist
KILL=/var/mobile/Library/Preferences/com.hakmicapitalgroup.hcgnexus.killswitch
[ -e "$KILL" ] && echo "kill switch: PRESENT" >> "$REPORT" || echo "kill switch: absent" >> "$REPORT"
if [ -f "$PREFS" ]; then
    # Key names and the file size only: workspaces and shortcuts are personal and are not copied.
    ls -l "$PREFS" >> "$REPORT" 2>&1
    if command -v plutil >/dev/null 2>&1; then
        plutil -p "$PREFS" 2>/dev/null | grep -E '^  "[A-Za-z]+" =>' | sed 's/ =>.*//' >> "$REPORT"
    fi
else
    echo "preferences: not created yet" >> "$REPORT"
fi
echo "Copy Settings > HCG Nexus > Diagnostics (and the panel's own Diagnostics) into this folder as diagnostics.txt." >> "$REPORT"

section "SpringBoard now (rss KB, %cpu)"
if command -v ps >/dev/null 2>&1; then
    ps -axo pid,rss,%cpu,%mem,etime,comm 2>/dev/null | grep -E 'SpringBoard$|PID' >> "$REPORT"
else
    echo "ps not installed (adv-cmds)" >> "$REPORT"
fi

section "Crash and memory reports (newest first)"
for DIR in /var/mobile/Library/Logs/CrashReporter /var/mobile/Library/Logs/CrashReporter/Retired; do
    [ -d "$DIR" ] || continue
    ls -t "$DIR" 2>/dev/null | grep -E '^(SpringBoard|HCGNexus|JetsamEvent|Preferences)' | head -15 | while read -r f; do
        printf '%s/%s\n' "$DIR" "$f" >> "$REPORT"
    done
done

if [ "$COPY" = 1 ]; then
    for PATTERN in 'SpringBoard' 'HCGNexus' 'JetsamEvent'; do
        F=$(ls -t /var/mobile/Library/Logs/CrashReporter 2>/dev/null | grep -E "^$PATTERN" | head -1)
        [ -n "$F" ] && cp "/var/mobile/Library/Logs/CrashReporter/$F" "$OUT/" 2>/dev/null && echo "copied: $F" >> "$REPORT"
    done
fi

section "Test notes (fill in)"
echo "Step number and what was tapped:" >> "$REPORT"
echo "Local time of the failure:" >> "$REPORT"

echo "Evidence written to $OUT"
