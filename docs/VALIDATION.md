# Validation status

The four kinds of evidence are reported separately and must not be
substituted for one another. Only section 4 can show that the tweak works.

Reproduce sections 1 and 3 with
`THEOS=… HCG_ENV=rootless scripts/check.sh` (and again with `HCG_ENV=rootful`).

## 0.2.1~beta1 — run #13: the candidate package to install (recorded 2026-11-17)

**Status: not yet device-tested.**

| | |
|---|---|
| File | `com.hakmicapitalgroup.hcgnexus_0.2.1~beta1_iphoneos-arm64.deb` (450,270 bytes) |
| **SHA-256** | **`948465eaa30fd8cf1bc9fd98141362fe08c4e24ab0b23d788a39fa65d8ac17af`** |
| Built from | `58e2dbd81e6cca1bf3589d864403b05ebb8d966e` on branch `claude/nexus-0.2.1-beta1` (embedded build ID `58e2dbd81e`, config `rootless-release`) |
| Workflow | *Build package* run **#13**, ID 44019802883, route `jailbreak`, layout `rootless`, 2026-11-17 04:49–04:51 UTC |
| Artifact | `hcg-nexus-rootless-deb`, ID 14300601854, zip SHA-256 `d3ac321bfb14068271491ab556573a9d570b72466e8047e3d8f210cb5b2d5235`, expires 2026-11-24 |
| Distribution | HCG Repo Candidate, `https://repo.hakmicapitalgroup.com/repo/candidate/`. HCG Nexus is paid; this exact version is free there by an owner-approved exception |

**Why a new version instead of run #10's 0.2.0**
* **Packaging.** Run #10's data member is `data.tar.lzma`: legacy lzma-alone, properties `0x5d`, 64 MiB dictionary, no
  stored size. That is the same header as the HCG Vortex beta whose unpack crashed on a device with `dpkg-deb … Bus
  error: 10` (cause unconfirmed). This build is gzip (`data.tar.gz`, `control.tar.gz`). `scripts/inspect-package.py`
  now refuses lzma-alone, and it flags run #10.
* **Version.** HCG Repo already records 0.2.0 as run #9 (`19871569…`), and recorded versions are immutable there.

**Same code as run #10.** Compared with `1341669`, the only source changes are `HCG_NEXUS_VERSION` and the Settings
bundle's `CFBundleShortVersionString`. Packaging changed in `Makefile` (gzip) and `control` (Version).
Docs/tests/scripts from `be03ee0` do not affect the binaries.

**Checks on this exact file (downloaded through the GitHub API; zip digest matched GitHub's record):**
* CI: lint + 26,960 host checks passed. `build-jailbreak-deb.sh --require-new-arm64e-abi` passed.
* This repository's `scripts/inspect-package.py … rootless --require-new-arm64e-abi` passed:
  - arm64 and arm64e slices (versioned ptrauth ABI v0) in both binaries;
  - the initializer is present;
  - shared build `58e2dbd81e`;
  - root:wheel ownership, 0755/0644 permissions;
  - `ar` members `debian-binary`, `control.tar.gz`, `data.tar.gz` (gzip magic checked);
  - Settings bundle version 0.2.1 matches the package's base version.
* HCG Repo `hcgrepo inspect`: passed. Its one warning, `firmware-undeclared`, notes the binaries need iOS 15.0+ and
  the package declares no firmware range.
* HCG Repo trial import, build and offline verification of both sources passed:
  - the stable index is unchanged and still empty;
  - the candidate index lists this file with this SHA-256;
  - 0.2.0 appears nowhere in the output.

## 0.2.0 — run #10: verified, not offered for installation (recorded 2026-11-16)

> Superseded for device testing by 0.2.1~beta1 above, because of its lzma packaging.

This is the only package to use for the device test:

| | |
|---|---|
| File | `com.hakmicapitalgroup.hcgnexus_0.2.0_iphoneos-arm64.deb` (236,034 bytes) |
| **SHA-256** | **`799734e7949b30bf90f2790f602e0043bac3a23e7bd43898f811f2bde3addc2e`** |
| Built from | `main` @ `13416698ea72f814e9960c09ff17115c3f00cb4c` (clean tree; embedded build ID `13416698ea`, config `rootless-release`) |
| Workflow | *Build package* run **#10**, ID 43557670545, manual dispatch on `main`, route `both`, layout `rootless`, 2026-11-14 04:38–05:08 UTC: https://github.com/F1r3srp3nt/HCG-Nexus/actions/runs/43557670545 |
| Toolchain | macOS runner, Xcode clang, Theos (latest at build time), iPhoneOS16.5 SDK, deployment target 15.0 |
| Artifact | `hcg-nexus-rootless-deb`, ID **14099414356**, zip SHA-256 `dd84f6bc3dcde26e6d92204b6f162e7f6cd1aab2c61d49dbcc962e8f51a18e54`, GitHub expiry **2026-11-21 05:07 UTC** |
| Other artifacts of run #10 (not for the phone) | `hcg-nexus-app` (standalone app, ID 14099492161); `hcg-nexus-preview-SIMULATION-rootless-deb` (preview simulation, ID 14099364406) |

Checks on this exact file:

* **CI (run #10), all three jobs passed.**
  - Lint + 26,960 host checks passed.
  - Standalone app job passed: simulator build, unit tests, simulator launch, unsigned device build and archive.
  - Jailbreak job passed. `scripts/build-jailbreak-deb.sh --require-new-arm64e-abi` confirmed:
    - tweak and Prefs have arm64 slices and arm64e slices with the versioned ptrauth ABI (v0);
    - the initializer is present in every slice;
    - tweak and Settings share build `13416698ea`;
    - payload installs as root:wheel, dirs/binaries 0755, data 0644;
    - everything is under `/var/jb`, with no maintainer scripts;
    - the filter is SpringBoard only;
    - PreferenceLoader wiring is correct and the version is 0.2.0.
* **Independent re-check (2026-11-16).**
  - The artifact was downloaded again through the GitHub API. The zip digest matched GitHub's recorded digest, and the `.deb` SHA-256 matched the CI log.
  - `scripts/inspect-package.py … rootless --require-new-arm64e-abi` passed on the downloaded file.
* **Install helper.** `Tests/Device/test-install-local.sh` passes 14/14 against this file. It covers: accepted; wrong model, iOS or architecture refused; no `/var/jb` refused; missing dependencies refused with no download; modified file refused; run #9's file refused.

### Run #9 and run #10 are not byte-identical: what differs

| | Run #9 | Run #10 |
|---|---|---|
| Commit | `907b1df` (branch) | `1341669` (main) |
| `.deb` SHA-256 | `19871569…616a5` | `799734e7…dc2e` |

* **Source.** The only change between the two commits is `docs/VALIDATION.md` (3 lines). No source, resource, Makefile or package metadata changed.
* **Package.** Everything is byte-identical except the two Mach-O binaries:
  - `control`, `Root.plist`, `Info.plist`, the PreferenceLoader entry, the filter plist and the icons are identical;
  - the archive itself differs only in timestamps and lzma output size.
* **Binaries.** In each binary (`HCGNexus.dylib`, `HCGNexusPrefs`) and each slice (arm64, arm64e), 190–192 bytes differ, all in three places:
  1. the embedded build ID: `907b1df330` → `13416698ea`, 2 occurrences per slice (same length, so no layout shift);
  2. `LC_UUID`: derived from the content, so it changes when the build ID changes;
  3. the ad-hoc code signature (`ldid`): it hashes the pages that changed.
* **Proof.** With those three normalised, every slice of both binaries is byte-for-byte identical, with equal sizes and signature offsets.
* **Conclusion.** Executable code and data are identical, so runtime behaviour is the same. The only visible difference is the build ID shown in Settings › HCG Nexus and in the diagnostics report.

### What this package contains, compared with newer work

The run #10 package is exactly 0.2.0 as described in `docs/FEATURES.md` at `1341669`. It does **not** contain:

| Change | Where it lives | Affects the jailbreak package? |
|---|---|---|
| In-panel Settings › About › **HCG Repo** row (opens `https://repo.hakmicapitalgroup.com/products/hcg-nexus/` in Safari) | `main` after the build: `60c3b77`, merged as `3136149` (PR #2) | **Yes** (overlay panel and standalone app) — **not in the run #10 .deb** |
| **Connected Devices / HCG Device Link** (pairing with HCG Server through HCG Connect, paired devices, shared reports; Swift package `HCGDeviceLink`) | branch `claude/lucid-mendel-egzyd6` only (`bc40ad3`, `24ec523`; based on `1341669`, not merged) | No: standalone app only. `Sources/Platform/App/` is compiled only into the Xcode app target; the tweak and Prefs Makefiles include only `Sources/Core`, `Sources/Panel` and `Sources/Platform/SpringBoard`. The shared panel code gains a section the overlay never shows. One Core string (the detail text for a legacy HCG Server shortcut) changes wording |

`claude/lucid-mendel-egzyd6` and `main` both edit `Sources/Panel/HCGPanelSettingsViewController.m`. A test merge (`git merge-tree origin/main origin/claude/lucid-mendel-egzyd6`, 2026-11-16) conflicts in that file only. The conflicts are in the section enum and the section lists, which both sides extend.

## 0.2.0 — first device release candidate (branch `claude/hcg-nexus-tweak-yb1ii2`, 2026-11-14)

Linux only (Theos clang 11 + GNUstep). **No device run and no Xcode run for
0.2.0 yet**; device steps are in `DEVICE-CHECKLIST.md`.

| Check | Result |
|---|---|
| Core host tests (new: diagnostics component states, redaction, report contents; only working integrations offered) | **pass** — 26,960 checks, 0 failures; new tests mutation-checked |
| `HCG_ENV=rootless scripts/check.sh` and `HCG_ENV=rootful scripts/check.sh` (lint, plists, Xcode project regenerated and matching, app target compiles/links against iPhoneOS 14.5 and 16.5, package build, inspection) | **pass** for both |
| Tweak + Settings bundle compile with `-Wall -Werror` (both layouts); preview harness builds | **pass** (only the expected Linux arm64e old-ABI linker warnings) |
| Both layouts build into separate `packages/<layout>/`, `.theos/obj/<layout>`, `.theos/_<layout>` | **pass** |
| Settings bundle and tweak carry the same build ID and config (`<commit>-dirty`, `rootless-release` / `rootful-release`); before this change the Settings bundle of a plain `make package` had an empty layout name | **pass** (inspector; a patched build ID is rejected) |
| Payload ownership root:wheel and permissions 0755/0644 | **pass** (inspector; a planted 0666 file is rejected) |
| PreferenceLoader entry → bundle → principal class; bundle version == package version (0.2.0) | **pass** |
| Runtime report written off the main thread, also when Nexus refuses to start; Settings Status/Copy Diagnostics | compiles; **device-unverified** |
| **Xcode-built rootless package, run #9** on `907b1df` (https://github.com/F1r3srp3nt/HCG-Nexus/actions/runs/43553119233), `build-jailbreak-deb.sh --require-new-arm64e-abi` | **pass** — `com.hakmicapitalgroup.hcgnexus_0.2.0_iphoneos-arm64.deb`, **SHA-256 `1987156996c2e76fb005bb66590aff76b77c474c4387ede6e015f19a081616a5`**; tweak and Prefs arm64e versioned ptrauth ABI (v0) + arm64; initializer in every slice; tweak and Settings share build `907b1df330` (`rootless-release`); installs as root:wheel, 0755/0644; PreferenceLoader wiring and version 0.2.0 OK. Artifact `hcg-nexus-rootless-deb` (ID 14097301893, kept until 2026-11-21) |
| Standalone app, run #9 (Xcode, simulator build, unit tests, simulator launch, unsigned device build, unsigned archive) | **pass**; artifact `hcg-nexus-app` (ID 14097342812) |
| Run #8 on `5e30159` | Xcode build was correct (arm64e versioned ABI, shared build ID) but failed the new ownership check: on a Mac, Theos' `dm.pl` writes owner names root/wheel with the builder's numeric IDs (501/20), which dpkg installs as root:wheel. The check was corrected in `907b1df` to judge ownership as dpkg does (self-tested). The app job's artifact upload hit a GitHub service timeout |

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
