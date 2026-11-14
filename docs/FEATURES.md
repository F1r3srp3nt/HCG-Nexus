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
| HCG Terminal (Standard / Unleashed) and HCG News | Implemented, device-unverified | open by bundle ID; "Not connected" until turned on; "App not installed" if the app is absent |
| Rotation | Implemented, device-unverified | source reported in Status |
| Reduce Motion, VoiceOver labels, haptics toggle | Implemented, device-unverified | — |
| **Settings › HCG Nexus › Status** (installed build, SpringBoard state, per-feature state with reason) | Implemented, device-unverified | state logic host-tested (`DiagnosticsTests`) |
| **Copy Diagnostics Report** (redacted, clipboard only, never sent) | Implemented, device-unverified | report + redaction host-tested |
| Settings asks SpringBoard for a fresh report | Implemented, device-unverified | payload-free Darwin notification; it can only trigger a status write |

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
