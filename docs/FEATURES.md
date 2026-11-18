# Feature inventory — 0.2.0 (first device release candidate)

Every row says how far the feature has actually been proven. Nothing in this
project has run on a physical device yet, so **no row is "verified on
device"**. "Verified" below means verified by the named automated evidence.

Legend:

* **Verified (automated)** — implemented, and exercised by host tests, the
  package inspector, the simulator, or CI, as named.
* **Implemented, device-unverified** — code is complete and builds with
  `-Wall -Werror`, but it depends on SpringBoard/iOS behaviour that only the
  device can confirm.
* **Incomplete** — partially there; the gap is stated.
* **Removed / not offered** — deliberately not exposed because it would only
  have shown a capability that does not exist.

## Build targets

| Target | What it is | Built by | Ships to the phone? |
|---|---|---|---|
| `HCGNexus` tweak (`HCGNexus.dylib` + SpringBoard filter) | the edge handle and panel inside SpringBoard | root `Makefile` (Theos/Logos) | yes, in the `.deb` |
| `HCGNexusPrefs` (PreferenceLoader bundle) | Settings › HCG Nexus | `Prefs/Makefile`, a subproject of the root Makefile | yes, in the same `.deb` |
| `HCGNexusPreview` | simulation app for UI review — **not** the tweak | `PreviewHarness/Makefile` (separate package) | no |
| `HCGNexus.app` | standalone sandboxed app (workspaces + launching via public URLs) | `HCGNexus.xcodeproj`, scheme `HCGNexus` | separate route, needs signing |

## Jailbreak package (the release workflow)

| Feature | Status | Evidence / gap |
|---|---|---|
| Package layout, filter (SpringBoard only), dependencies, no maintainer scripts | **Verified (automated)** | `inspect-package.py`, both layouts |
| Payload ownership root:wheel, dirs/binaries 0755, data 0644, no setuid, no symlinks | **Verified (automated)** | `inspect-package.py` (mutation-tested: a world-writable file fails) |
| Tweak and Settings bundle built from the same commit + configuration | **Verified (automated)** | build marker compared by `inspect-package.py` (mutation-tested) |
| Settings bundle wired to PreferenceLoader (entry → bundle → principal class), version = package version | **Verified (automated)** | `inspect-package.py` |
| arm64e new ABI (needed on A12+, e.g. iPhone 13 Pro) | **Verified (automated)** for Xcode builds only | CI `--require-new-arm64e-abi`; Linux builds are compile checks only |
| Activation entry point (`%ctor` → bootstrap on SpringBoard launch, 15 s late-load fallback) | Implemented, device-unverified | initializer presence verified by the inspector |
| Starts **disabled**; master switch applies without respring | Implemented, device-unverified | default verified by host tests + `check.sh`; Darwin notification path needs the device |
| Kill switch file stops Nexus at next SpringBoard launch, and Settings now says so | Implemented, device-unverified | — |
| Edge handle (side, vertical position, visibility, keyboard safe zone) | Implemented, device-unverified | geometry host-tested incl. iPhone 13 Pro safe areas |
| Hidden while locked / on cover sheet; fail-closed when lock state is unreadable | Implemented, device-unverified | policy host-tested; lock signal sources need the device |
| Panel: search, workspaces, shortcuts, recents, in-panel settings, disable | Implemented, device-unverified | models host-tested; UI verified in the simulator via the preview harness |
| Workspace management (create, rename, reorder, delete, presets Command/Developer/Studio/Infrastructure) | **Verified (automated)** for data; UI device-unverified | host tests |
| App shortcuts by bundle ID | Implemented, device-unverified | LaunchServices `openApplicationWithBundleID:` off the main thread, then SpringBoard's own launcher as a verified-at-runtime fallback; Settings reports which selectors exist |
| Link (URL) shortcuts | Implemented, device-unverified | public `openURL:options:completionHandler:` |
| In-panel Settings › About › **HCG Repo** (also in the standalone app): opens the fixed product page `https://repo.hakmicapitalgroup.com/products/hcg-nexus/` in Safari through the launcher; Nexus itself makes no request | Implemented, device-unverified | URL constant host-tested (https, host, path, no query/fragment); not added to Settings › HCG Nexus, which has no launcher |
| HCG Terminal (Standard / Unleashed) and HCG News | Implemented, device-unverified | open by bundle ID; "Not connected" until turned on; "App not installed" if the app is absent |
| Rotation | Implemented, device-unverified | source reported in Status |
| Reduce Motion, VoiceOver labels, haptics toggle | Implemented, device-unverified | — |
| **Settings › HCG Nexus › Status** (installed build, SpringBoard state, per-feature state with reason) | Implemented, device-unverified | state logic host-tested (`DiagnosticsTests`) |
| **Copy Diagnostics Report** (redacted, clipboard only, never sent) | Implemented, device-unverified | report + redaction host-tested |
| Settings asks SpringBoard for a fresh report | Implemented, device-unverified | payload-free Darwin notification; it can only trigger a status write |

## Command Mode (both routes, branch `claude/nexus-command-mode`)

Opened from the **Command Mode** button (grid icon) in the panel header, next
to the close button. It is shared Panel code: the SpringBoard overlay and the
preview harness show it on the overlay canvas above the panel; the standalone
app presents it full screen. Nothing about the jailbreak package's defaults
changed (it still ships disabled), and Command Mode adds no setting, no
network request and no telemetry.

| Feature | Status | Evidence / gap |
|---|---|---|
| State mapping (device values and integration connection states → label, detail, symbol, colour role) in `Sources/Core/HCGCommandMode.{h,m}` | **Verified (automated)** | host tests `Tests/Host/CommandModeTests.m`: every display state, missing/`nil`/out-of-range input, battery/power/network/storage edge cases, no "online"/"syncing"/"live" wording; mutation-checked (treating an unreported sign-in state as Connected, or "off" as Disconnected, fails the suite) |
| Integration states **Unknown / Unavailable / Off / Disconnected / Signed out / Connected**, each with its own text label and symbol (never colour alone) | **Verified (automated)** for the mapping; UI device-unverified | the integrations model gained `recognized`, `contractAvailable`, `configured`, `reachability` and `session` (`Sources/Core/HCGIntegrations.h`). Reachability and session default to *Unknown*, so nothing reads as connected by accident |
| What each shipped integration can actually show | — | HCG Terminal / HCG News: *Off* until turned on; then *Connected* (Nexus can open the app; no session or sync status is claimed), *Unavailable* (app not installed, or the sandboxed app cannot open apps), or *Unknown* (installation cannot be checked). HCG Server / Executable Maker would map to *Unavailable* (no phone-reachable contract) but stay unlisted, as before. **No shipped integration can produce *Disconnected* or *Signed out* today**: no HCG contract publishes reachability or sign-in state to a phone. Those states are mapped and tested so a future contract cannot be misreported |
| Device status: battery level + charging state (`UIDevice`, battery monitoring on only while visible and restored afterwards), Low Power Mode (`NSProcessInfo`), network path and interface (`Network.framework` `nw_path_monitor`, no request made), available storage (`NSURLVolumeAvailableCapacityForImportantUsageKey`, `NSFileManager` fallback), time and date | Implemented, device-unverified | public APIs only (`check_app_target.py` passes); values iOS does not give show **Unavailable** (e.g. the simulator's battery). The network tile says it is a route check, not an internet or HCG service check |
| Shortcuts of the active workspace, launched through the existing `HCGActionRunner` (same errors, recents and closing behaviour as the home screen) | Implemented, device-unverified | reuses `HCGWorkspaceStore`; no second store |
| Scrim dims what is behind by 30% (35% with Increase Contrast); nearly opaque obsidian with Reduce Transparency; instant open/close with Reduce Motion or animations off | **Verified (automated)** for the policy values; rendering device-unverified | `testPresentationPolicy`. In the overlay the Command Mode scrim replaces the panel's 42% dimming while it is shown, so the app is dimmed once, not twice |
| Decoration (static scanlines, status rings, rim light) never animates and implies no activity | Implemented | no animation besides the optional 0.2 s fade on open/close; scanlines are hidden with Reduce Transparency / Increase Contrast |
| Closed by every panel close path (lock, cover sheet, disable, launched shortcut) | Implemented, device-unverified | `finishClosing`, `overlaySetVisible:NO` and the close transition all remove it first |
| VoiceOver: modal view, header focus on open, two-finger-Z escape back to the panel, one combined label per tile/row; Dynamic Type switches the grids to one column at accessibility sizes | Implemented, device-unverified | — |
| Standalone app XCTest `testCommandModeShowsRealStatesInAppMode` | written, **not run** (needs Xcode) | syntax-checked on Linux against the iPhoneOS 16.5 SDK headers with a stub XCTest header only |

## Removed / not offered

| Item | Why |
|---|---|
| HCG Server and HCG Executable Maker panel integrations | HCG Server's admin API is reachable only on the host Mac's loopback interface with a local admin token (Nexus will not store it), and Executable Maker publishes no build-status interface a phone can read. The rows could only ever display "Not connected", so they were removed from presets, the shortcut editor and Settings. Shortcuts saved by 0.1.0 that reference them still load, and running one explains why it is unavailable |
| `roothide` builds | not implemented; the Makefile refuses `HCG_ENV=roothide` |

## Layouts

| Layout | Status |
|---|---|
| rootless (`/var/jb`, iOS 15+) — Dopamine, palera1n rootless | **release target**; builds and inspects clean; device-unverified |
| rootful (`/`, iOS 14) | builds and inspects clean on Linux; no Xcode-built package yet; device-unverified |
| roothide | unsupported |

## Ranked blockers to calling this "verified on device"

1. **No device run yet.** Everything marked device-unverified depends on the
   checklist in `DEVICE-CHECKLIST.md` being run on the iPhone 13 Pro
   (iOS 16.5, Dopamine, ElleKit).
2. **Device package must be built by Xcode.** The Linux toolchain emits the
   old arm64e ABI, which an A12+ SpringBoard will not load. Use
   `scripts/build-jailbreak-deb.sh` on a Mac or the manual *Build package*
   workflow.
3. **SpringBoard window level 999** relative to iOS 16.5 system UI is a
   reasoned choice, not an observation.
4. **Lock-state sources and the LaunchServices selectors on iOS 16.5** are
   checked at runtime and reported in Status, but have not been observed.
5. **Writing the runtime report from SpringBoard into
   `/var/mobile/Library/Preferences`** relies on cfprefsd accepting
   SpringBoard's write for this domain. If Status stays "Not loaded" after a
   respring while the handle works, this is the cause.
