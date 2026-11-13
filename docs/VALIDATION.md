# Validation status — milestone 1

The four kinds of evidence are reported separately and must not be
substituted for one another. Only section 4 can show that the tweak works.

Reproduce sections 1 and 3 with
`THEOS=… HCG_ENV=rootless scripts/check.sh` (and again with `HCG_ENV=rootful`).

## Standalone app + build routes (PR #1, branch `claude/hcg-nexus-tweak-yb1ii2` @ `5671146`, 2026-11-13)

Xcode results come from the manually started **Build package run #7**:
https://github.com/F1r3srp3nt/HCG-Nexus/actions/runs/43524574351
(artifacts: `hcg-nexus-app`, `hcg-nexus-rootless-deb`, `hcg-nexus-preview-SIMULATION-rootless-deb`; kept 7 days).

Evidence is kept separate: **compile/inspection results are not device verification.**

| Check | Where | Result |
|---|---|---|
| Core host tests (+ new: sandboxed app reports configured integrations as "Needs jailbreak package") | Linux, GNUstep | **pass** — 26,930 checks, 0 failures |
| `generate_xcodeproj.py --check`; project parsed by an independent pbxproj parser (mod-pbxproj), every object reference resolves | Linux | **pass** |
| App target boundaries: 29 sources, public APIs only, single `main.m`, no SpringBoard/preview/tweak/Prefs files; Executable Maker discovery rules (one `.xcodeproj`, one application target, shared scheme `HCGNexus` archives it) | Linux, `check_app_target.py` | **pass** (and fails on a planted `LSApplicationWorkspace` reference) |
| App target compiles with `-Werror` and **links** an arm64 executable against iPhoneOS **14.5** and **16.5** SDKs (deployment target 14.0) | Linux, Theos clang 11, `compile-app-target.sh` | **pass**. Only `___isOSVersionAtLeast` (compiler-rt, supplied by Xcode) is left to the real Xcode link. Binary contains no private-API strings |
| `inspect-app.py` on that binary in a mock bundle; negative test against the preview harness binary (flags `HCGPreview*`/overlay classes) | Linux | **pass** / correctly **fails** |
| Jailbreak `.deb`, rootless and rootful: layout, filter, deps, no maintainer scripts, **initializer (`%ctor`) present in every slice**, bootstrap class present | Linux Theos build + `inspect-package.py` | **pass**; arm64e old-ABI **WARN** expected on Linux. The inspector self-test covers the initializer check |
| `build-jailbreak-deb.sh --check-only` | Linux | reads the right SDK/deployment target per layout (16.5/15.0, 14.5/14.0) and correctly refuses to build off macOS |
| **Xcode project** listed by `xcodebuild -list`: targets HCGNexus + HCGNexusTests, scheme HCGNexus | Actions run #7, Xcode 26.6 (17F113), macOS 26 runner | **pass** |
| **Simulator build** (Debug, `generic/platform=iOS Simulator`) + `inspect-app.py` (bundle ID, MinimumOSVersion 14.0, iPhone+iPad, scene delegate, AppIcon/Assets.car, no private-API code) | run #7 | **pass**, no compiler warnings |
| **Unit tests** `HCGNexusTests` on iPhone 17 Pro simulator | run #7 | **pass — 8 tests, 0 failures** |
| **Launch on simulator**: installed, launched, still running after 8 s, screenshot captured | run #7 | **pass** (screenshot in artifact `hcg-nexus-app`) |
| **Unsigned device build** (Release, iphoneos SDK 26.5) + `inspect-app.py` | run #7 | **pass** — arm64, `minos 14.0`, no compiler warnings |
| **Unsigned archive** (what Executable Maker runs before IPA export) | run #7 | **pass** — ApplicationPath `Applications/HCGNexus.app`, arm64, no team/identity (as expected unsigned) |
| SDK deployment range | run #7 | iphoneos/iphonesimulator SDK 26.5 minimum deployment target **12.0**, so the project's 14.0 is supported by this Xcode |
| **Xcode-built jailbreak `.deb`** from this branch via `build-jailbreak-deb.sh` (`--require-new-arm64e-abi`) | run #7 | **pass** — arm64e versioned ptrauth ABI (v0) for tweak and Prefs, initializer in every slice, layout/filter/deps OK; SHA-256 `25afcda65c16b5304b4f6e08a72b83036931c94c6d6c5e24d1af7ce336d80c07` |
| Standalone app on a physical iPhone/iPad | — | **not done** (needs your signing team); the unsigned device build cannot be installed |
| Jailbreak package on the iPhone 13 Pro | — | **not done** — checklist in section 4 |

## 1. Source and automated checks — PASSED (Linux, 2026-11-12)

`scripts/check.sh` results:

| Check | Result |
|---|---|
| Core portability lint (no UIKit, blocks, subscripts or `__weak` in `Sources/Core`) | pass |
| No secure (lock-screen) windows, no `_setSecure` | pass |
| No automatic respring or kill in build files, no maintainer scripts | pass |
| No method hooks (`%hook`, `MSHook*`, method swizzling) | pass |
| No embedded credentials, HCG Server endpoints or tokens, or invented HCG URL schemes | pass |
| Tweak filter is SpringBoard only | pass |
| Version consistent (`control` matches `HCG_NEXUS_VERSION`); plists parse; `enabled` defaults to false | pass |
| **Core host tests: 26,920 checks, 0 failures** (includes iPhone 13 Pro geometry: 390×844 pt, safe area 47/34 portrait, 47/47/21 landscape) | pass |

The host tests run the real `Sources/Core` code, compiled with clang against
GNUstep Base using manual reference counting. They cover:

* **Settings:** starts disabled; a missing or ill-typed `enabled` value reads as
  disabled; clamping; round-trip persistence; reset keeps the enabled state and
  integrations.
* **Workspaces:** first run seeds Command, Developer, Studio and Infrastructure;
  create, rename, reorder and delete persist across reloads; case-insensitive
  duplicate names, blank names, too-long names and limits are rejected;
  deleting the active workspace selects its neighbour; deleting everything does
  not bring presets back; corrupt entries are dropped rather than crashing.
* **Shortcuts:** validation of bundle IDs and URLs (`file:` and `javascript:`
  blocked) and of integrations; add, move and remove persist.
* **Recents:** bounded to 10, de-duplicated, persisted.
* **Search:** ranking and diacritic-insensitive matching.
* **Integrations:** every unconfigured integration shows "Not connected";
  Terminal/News give Ready, App not installed or Unverified states; Server and
  Executable Maker stay Not connected whatever the settings.
* **Geometry:** the handle stays inside the safe band (clear of the top pull
  zones and the home indicator); the keyboard-safe zone; left and right sides;
  landscape insets; the panel stays inside the safe area and above the keyboard;
  degenerate sizes.
* **Panel state machine:** 20,000 random operations never start overlapping
  transitions; stale animation completions are ignored.
* **Overlay coordinator with a fake host:**
  * Disabled means nothing is installed.
  * 200 enable/disable cycles with the panel open: disabling hides the overlay
    and closes the panel immediately, and the gesture is ignored.
  * Exactly 1 install, 1 window and 3 gesture recognisers.
  * 500 rapid open/close sequences behave correctly.
  * Lock hides everything. The cover sheet hides the overlay even after Face ID
    unlock. An unknown lock state fails closed. Unlocking does not reopen the
    panel.
  * Reduce Motion disables slide animation.

Mutation checks were run by hand: removing the cover-sheet rule, or defaulting
to enabled, makes the suite fail as expected.

**Not covered here:** anything in UIKit, SpringBoard or another real iOS
runtime.

## 2. Preview harness — BUILT, NOT RUN

`PreviewHarness/` builds and packages
(`com.hakmicapitalgroup.hcgnexus.preview_0.1.0_iphoneos-arm64.deb`) with no
compiler warnings or errors. It hosts the real Panel code on a mock "current
app", with simulated lock and cover-sheet toggles. Its in-app
**Run preview self-check** covers:
* starts disabled
* 50 open/close cycles
* exactly one container and three recognisers
* disabling while open
* simulated lock and cover sheet
* workspace persistence
* "Not connected" integrations
* missing-app and unconnected-integration errors

**It has not been executed:** there is no iOS Simulator or device in this
environment. Even when it runs and passes, it is preview evidence only. It
does not exercise SpringBoard, the real window level, real lock signals or real
app launches, which are simulated.

## 3. Package compilation — PASSED (Xcode build for the iPhone 13 Pro)

| Package | Result |
|---|---|
| `com.hakmicapitalgroup.hcgnexus_0.1.0_iphoneos-arm64.deb` (rootless, iPhoneOS16.5 SDK, deployment 15.0) | builds with `-Wall -Werror`; files under `/var/jb`; no maintainer scripts; filter is SpringBoard only; Settings icons present; no CydiaSubstrate linkage |
| `com.hakmicapitalgroup.hcgnexus_0.1.0_iphoneos-arm.deb` (rootful, iPhoneOS14.5 SDK, deployment 14.0) | same checks pass |

**Not installable on the confirmed iPhone 13 Pro:** the Linux-built arm64e
slices use the old pointer-authentication ABI (measured: CPU subtype `0x2`
with both available Linux toolchains). With
`HCG_REQUIRE_NEW_ABI=1 scripts/check.sh`, or
`inspect-package.py --require-new-arm64e-abi`, this is a hard failure.
The device package must come from the **Build package** workflow (macOS runner,
Xcode) or a Mac.

**Xcode build — GitHub Actions *Build package* run #4**
(https://github.com/F1r3srp3nt/HCG-Nexus/actions/runs/43163310346, commit
`726f314`, `macos-latest`, iPhoneOS16.5 SDK, rootless):

| Step | Result |
|---|---|
| Lint, safety rules, host tests (ubuntu-24.04) | pass |
| `gmake package FINALPACKAGE=1 HCG_ENV=rootless` | pass → `com.hakmicapitalgroup.hcgnexus_0.1.0_iphoneos-arm64.deb` |
| `inspect-package.py --require-new-arm64e-abi` | pass: no maintainer scripts; every file under `/var/jb`; filter `{'Filter': {'Bundles': ['com.apple.springboard']}}`; `HCGNexus.dylib` and `HCGNexusPrefs` each have an arm64 slice and an **arm64e slice with the versioned ptrauth ABI (v0)** |
| Preview harness package | pass (separate `.deb`) |
| Artifact | `hcg-nexus-rootless-deb`, ID 13918394573, 555,614 bytes, sha256 `70a53c8c…cdcf2a` (zip), expires 2026-11-19 |

Earlier runs, for the record: #1 failed to link the host tests on the
runner (fixed by locating libobjc explicitly). #2's `macos-14` job was
cancelled before a runner was assigned (switched to `macos-latest`). #3 built
the package, but the inspector crashed on the binary filter plist that Theos
emits on macOS (parser fixed).

I could not download the artifact into this sandbox: its network policy blocks
GitHub's artifact storage host. The ABI result above is the CI inspector's
output.

## 4. Physical-device verification — NOT DONE

Target: iPhone 13 Pro, iOS 16.5, Dopamine rootless, ElleKit, Sileo. Nothing
has been observed on it yet. Checklist for the first session:

- [ ] Settings › HCG Nexus appears with the icon. Diagnostics shows SpringBoard
      build / Activated: No.
- [ ] After a fresh install, no handle is visible and touches behave normally.
- [ ] Enable: the handle appears without a respring. Side, position and
      visibility changes apply live.
- [ ] Tap and swipe-inward open the panel. The close button, outside tap and
      VoiceOver escape (two-finger Z) close it.
- [ ] Rotate an app to landscape: the handle and panel stay upright, inside the
      safe area and clear of system gestures.
- [ ] Back-swipe in apps still works away from the handle. Notification and
      Control Centre pulls and the home indicator are unaffected.
- [ ] Search field and rename receive keyboard input; the panel stays above
      the keyboard.
- [ ] Lock: the handle and panel vanish before the lock screen appears. On the
      lock screen, including after Face ID and before swiping up, nothing from
      Nexus is visible.
- [ ] With Notification Centre pulled down while unlocked, the handle is
      covered or hidden.
- [ ] Launch an installed app shortcut, a missing-app shortcut (actionable
      error), an https link, and an unknown-scheme link (actionable error).
- [ ] Disable from the panel and from Settings: the overlay is removed and
      input is normal immediately.
- [ ] Diagnostics shows overlayWindows = 1 and gestureRecognizers = 3 after
      many open/close and enable/disable cycles.
- [ ] Reduce Motion: fade instead of slide. Bold Text, larger text and Increase
      Contrast render legibly.
- [ ] Kill switch file stops activation after a respring. Uninstall leaves
      SpringBoard normal.
