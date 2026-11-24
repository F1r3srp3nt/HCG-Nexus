# Validation status

The four kinds of evidence are reported separately and must not be
substituted for one another. Only section 4 can show that the tweak works.

Reproduce sections 1 and 3 with
`THEOS=… HCG_ENV=rootless scripts/check.sh` (and again with `HCG_ENV=rootful`).

## 0.4.0~beta1 — HCG Ecosystem dashboard and HCG Interchange Protocol (recorded 2026-11-24)

**Status: built and verified; not imported or published** (needs the owner's approval of the exact SHA-256 below). Not device-tested: `DEVICE-CHECKLIST.md` rows 24–31.

What changed (docs/INTERCHANGE.md):
* **HCG Interchange Protocol v1**: a registry of 14 HCG products with package and bundle IDs, links, iOS
  requirements, capabilities (verified / available / planned / unavailable) and permissions; a read-only scan
  (dpkg status, HCG Repo package lists, LaunchServices, each tweak's own status and preferences); declarations that
  can only narrow.
* **HCG Terminal**: Nexus now uses HCG Terminal's real `TerminalDeepLink` contract (`<scheme>://open/<screen>`).
  It shows the installed version and build, compatibility (iOS 17 for Unleashed) and verified capabilities. It
  opens 8 screens, and packages, processes and jailbreak diagnostics through Unleashed Tools until a Terminal build
  declares direct links. The never-shipped saved-connection handoff of 0.3.2 is retired.
* **Ecosystem dashboard** (the panel's *Ecosystem* section, formerly *HCG Products*): device overview, product
  cards with state, version, compatibility, capabilities and updates; per-product pages with shortcuts, read-only
  current settings, capabilities and identifiers; integration diagnostics; activity history. Cards rise in once,
  except with Reduce Motion or Animations off.
* **Opening Nexus**: `HCGNexusPortalInterface` v1 (the interface HCG Portal already calls) and Darwin requests
  `com.hakmicapitalgroup.hcgnexus/open/…` from HCG apps; unlocked only, rate-limited, *Let HCG Apps Open Nexus*
  (Settings › HCG Nexus, default on).
* HCG Halo: the existing border switch is unchanged and now also on HCG Halo's page; Halo's colours, animation,
  brightness and speed are shown read-only.

| | |
|---|---|
| File | `com.hakmicapitalgroup.hcgnexus_0.4.0~beta1_iphoneos-arm64.deb` (1,387,236 bytes) |
| **SHA-256** | **`86a0ed3cbd09a162a4d3165141748ec4a2ee5715950507dab2114a3735fa43ff`** |
| Built from | `72f7de826c94…` on `claude/hcg-nexus-tweak-yb1ii2` (build ID `72f7de826c`, `rootless-release`) |
| Workflow | *Build package* run **#32**, ID 45467080416, route `both`, layout `rootless`: https://github.com/F1r3srp3nt/HCG-Nexus/actions/runs/45467080416 |
| Artifact | `hcg-nexus-rootless-deb`, ID 14956744051, zip SHA-256 `9ac56c324709ae0c31c76840903c14596642f724476c39df00af4b6ae9c6845c`, expires 2026-12-01 |
| Depends | `mobilesubstrate \| ellekit, preferenceloader` (no firmware change: still installs on the iPhone 13 Pro, iOS 16.5) |
| HCG Repo request | HCG-repo `claude/candidate-nexus-0.4.0`, `pending-imports/hcg-nexus-0.4.0-beta1-rootless.toml` (held until approved) |

**Simulator / CI (no device):** run #32, all 4 jobs green: lint + 28,200 Core host checks (HIP registry invariants,
Debian version ordering, dpkg/Packages parsing, Terminal Unleashed rc2 on iOS 17.4 and 16.5, declarations that try
to add routes or capabilities, tweak states, prepared adapters claiming nothing, open requests, activity log); HCG
Device Link and HCGConnectVerify (Linux and macOS); app XCTests on the Simulator; launch screenshot and screenshots of
every section (the Ecosystem dashboard in the sandboxed app); unsigned device build and archive; Theos jailbreak
package and preview harness. Local: `scripts/check.sh` with the Theos toolchain, rootless and rootful; app target
against iPhoneOS 14.5 and 16.5.
Re-checked here on the downloaded `.deb`: `inspect-package.py --require-new-arm64e-abi` 16/16 OK; control
`Version: 0.4.0~beta1`; `HaloBorder.plist` `nexusVersion` 0.4.0~beta1, interface 1; the tweak contains
`HCGNexusPortalInterface`, `HCGEcosystemScanner`, the open requests and the new setting.

**Phone:** not tested (pending, rows 24–31). HCG Terminal's direct links (HCG-Terminal `claude/nexus-interchange`)
are not in an installable Terminal build; with 0.2.0~rc2 Nexus uses Unleashed Tools for those three screens.

## 0.3.3~beta1 — Command Mode keeps the configured panel glass (recorded 2026-11-19)

**Status: published 2026-11-21 in HCG Repo Candidate** (owner approval 21 Nov 2026; HCG-repo PR #17, `ade4a55`). The
live `.deb` matches the SHA-256 below. Not device-tested: `DEVICE-CHECKLIST.md` row 23.

Finding on 0.3.2~beta1 (and every earlier build with Command Mode): the Command Mode card ignored *Panel glass*. It
always used an ultra-thin blur and a fixed 0.64 tint (0.86 with Increase Contrast), so with blur *Off*, *Strong* or a
custom opacity it did not match the panel.

Change: the card takes blur and opacity from the same settings, by the panel's rules
(`HCGCommandModeStatus +cardBlurForSettings:reduceTransparency:` / `+cardTintAlphaForSettings:…`):
* configured blur (Off / Light / Standard / Strong → same materials as the panel) and opacity are kept;
* with blur Off the panel's readability floor (0.6) applies;
* Increase Contrast raises the tint to at least 0.86 and never lowers a higher one;
* **Reduce Transparency overrides the setting**: no blur, opaque surface (unchanged behaviour);
* a settings change rebuilds the card's glass live, only when what it uses changed.

Nothing else changes from 0.3.2~beta1.

| | |
|---|---|
| File | `com.hakmicapitalgroup.hcgnexus_0.3.3~beta1_iphoneos-arm64.deb` (1,199,034 bytes) |
| **SHA-256** | **`e42efb6da782fba82d48ee678495dfdb5df4cc0c501da9383102b3e2d25e9c6f`** |
| Built from | `a58ff705d685…` on `claude/nexus-0.3.3-command-glass` |
| Workflow | *Build package* run **#30**, ID 44569229745, route `both`, layout `rootless`: https://github.com/F1r3srp3nt/HCG-Nexus/actions/runs/44569229745 |
| Artifact | `hcg-nexus-rootless-deb`, ID 14553841955, zip SHA-256 `4610089e2529d22be0033fafeb9334ae728d43e1cbdcbc86bc45668a39d6c24f`, expires 2026-11-26 |
| HCG Repo request | HCG-repo `imports/hcg-nexus-0.3.3-beta1-rootless.toml` (merged in PR #17, published) |

Compatibility with HCG Halo and HCG Terminal is the same as 0.3.2~beta1 (tables below, read *0.3.3~beta1* for *0.3.2~beta1*).

**Simulator / CI (no device):** run #30, all 4 jobs green: lint + 27,833 Core host checks (13 new, for the card's
glass), HCG Device Link and HCGConnectVerify (Linux and macOS), app XCTests on the simulator, section screenshots
(standard, largest text, increased contrast), unsigned device build and archive, Theos jailbreak build. Re-checked
here on the downloaded `.deb`: package inspector all OK (arm64 + arm64e with the versioned ptrauth ABI, `%ctor`,
SpringBoard filter, root:wheel, permissions); control `Version: 0.3.3~beta1`; `HaloBorder.plist` `nexusVersion`
0.3.3~beta1, interface 1; the tweak contains the new card-glass code.

**Phone:** not tested (pending, row 23).

## 0.3.2~beta1 — run #29: HCG Halo border switch + HCG Terminal states (recorded 2026-11-18)

**Status: published 2026-11-19 in HCG Repo Candidate** (HCG-repo PR #12, `cecfcf0`; *Publish* run 44467733378), together
with HCG Halo 0.3.1~beta1. The live `.deb` matches the SHA-256 below. Not yet device-tested: `DEVICE-CHECKLIST.md` rows
17–22, HCG Halo rows N18–N23.

| | |
|---|---|
| File | `com.hakmicapitalgroup.hcgnexus_0.3.2~beta1_iphoneos-arm64.deb` (1,197,154 bytes) |
| **SHA-256** | **`e5e5f0f46b2023470d9d76070d7d666339735e9c31b4aa19b5eae3684a38ad56`** |
| Built from | `cd81084a48b5…` on `claude/nexus-0.3.2-integrations` (build ID `cd81084a48`, `rootless-release`) |
| Workflow | *Build package* run **#29**, ID 44389550508, route `both`, layout `rootless`: https://github.com/F1r3srp3nt/HCG-Nexus/actions/runs/44389550508 |
| Artifact | `hcg-nexus-rootless-deb`, ID 14467701677, zip SHA-256 `9137184b05e2af663ae59b2f23bba89a929ab46c05e09921015e6e6ae269cb92`, expires 2026-11-25 |
| HCG Repo request | HCG-repo `imports/hcg-nexus-0.3.2-beta1-rootless.toml` (merged in PR #12, published) |

### Compatibility

| HCG Nexus | HCG Halo | Panel border | *Use HCG Halo border* in Nexus |
|---|---|---|---|
| **0.3.2~beta1** | **0.3.1~beta1** | yes | **switches it** (HCG Halo's `HaloNexusControl`, never the screen edge); states Not installed / Incompatible / Disabled / Ready / Active |
| 0.3.2~beta1 | 0.3.0~beta1 or 0.2.0~beta1 | yes (set in HCG Halo › Border Target) | shows the true state; switch disabled ("switched in HCG Halo › Border Target") |
| 0.3.2~beta1 | 0.1.0~beta1 | no | Incompatible |
| 0.3.2~beta1 | none | no; Nexus keeps its own outline | Not installed |
| 0.3.1~beta1 / 0.2.2~beta1 | 0.3.1~beta1 | yes (set in HCG Halo) | no switch in those Nexus builds |

| HCG Nexus 0.3.2~beta1 with | Installed | Launch | Integration (saved-connection handoff) | Session |
|---|---|---|---|---|
| HCG Terminal 0.1.0 (standard or Unleashed) | yes, with version | Open HCG Terminal | not available ("no Nexus handoff yet") | not shared |
| HCG Terminal **0.1.1** (HCG-Terminal `d591d49`, `HCGNexusHandoff` = 1) | yes, with version | Open HCG Terminal | *Open Saved Connection…* (`hcgterminal://connection?id=…`; the user taps Connect in Terminal) | not shared |
| none | Not installed | — | — | — |

HCG Terminal 0.1.1 is not an HCG Repo package: standard Terminal is distributed as an app, and HCG Terminal Unleashed's
`.deb` requires iOS 17 (HCG-repo listing). Its CI (HCG-Terminal Apple builds run 44389174073, all 5 jobs green) builds and
tests both variants but uploads no installable package.

### Evidence

**Simulator / CI (no device):**
* Nexus run #29: lint + 27,820 Core host checks (HCG Halo states incl. missing/incompatible companions, disabled and
  stopped HCG Halo, panel open/close; HCG Terminal states and link validation; mutation-checked), HCGConnectVerify 21/21
  (Linux and macOS), 22/22 app XCTests, Xcode jailbreak build `--require-new-arm64e-abi`.
* Re-checked here on the downloaded `.deb`: inspector all OK, no warnings; tweak and Settings bundle contain the HCG Halo
  bridge, the `HaloNexusControl` call and the HCG Terminal handoff; `HaloBorder.plist` accepted by HCG Halo's validator.
* HCG Halo × Nexus preview run 44388729789 (HCG Halo `1e232ab` + this Nexus `cd81084`), iOS Simulator, real Settings
  bundles, 0 failures:
  - Nexus alone: *Not installed*, switch disabled.
  - HCG Halo off: *Disabled*; switch on gives panel only (`enabled`, target `nexus`) and *Ready*; switch off turns HCG
    Halo off again.
  - Screen edge on: on gives `both`, off gives `screen` (screen edge untouched); *Show Halo on* never written.
  - Launch guard: switch refused with the reason, nothing written, *Disabled*.
  - Fault: *Disabled*, never *Ready*.
  - The panel preview (attach, open/close/reverse, Command Mode) and the surfaces preview also passed.
* HCG Terminal run 44389174073: handoff route and model suites pass on macOS and the iOS Simulator; both builds declare
  their own scheme and `HCGNexusHandoff=1`; Simulator `openurl` shows each scheme registered to the right app (iOS's
  confirmation prompt is not tapped, so in-app handling there is covered by the unit tests only).

**Phone (owner, iPhone 13 Pro, iOS 16.5, Dopamine), 18 Nov 2026, on 0.3.1~beta1 (before this build):**
* The redesigned 0.3.1~beta1 panel runs (Overview, banner, workspace chips, Command Mode button).
* HCG Halo draws its screen-edge light; the panel has only Nexus's own outline. Cause: HCG Halo's Border Target was
  *Screen Edge* (its default), and 0.3.1~beta1 had no switch or status in Nexus. 0.3.2~beta1 + HCG Halo 0.3.1~beta1
  address that; **not yet tried on the phone.**

## 0.3.1~beta1 — run #24: the combined candidate (recorded 2026-11-18)

**One combined Nexus candidate** (owner decision): the redesign, Command Mode and the HCG Halo border interface.
**Status: not yet device-tested.** Checklist: `DEVICE-CHECKLIST.md` (rows 1–16).

| | |
|---|---|
| File | `com.hakmicapitalgroup.hcgnexus_0.3.1~beta1_iphoneos-arm64.deb` (1,143,570 bytes) |
| **SHA-256** | **`b6750cf12d7ab4ebcf5542cef0496945211d8226152a4c45e57e40adaf6741c3`** |
| Built from | `82412dd5d52086eb20b45170a203853654af8d6b` on `claude/nexus-combined-0.3.1` (embedded build `82412dd5d5`, `rootless-release`) |
| Workflow | *Build package* run **#24**, ID 44225979728, route `both`, layout `rootless`: https://github.com/F1r3srp3nt/HCG-Nexus/actions/runs/44225979728 |
| Artifact | `hcg-nexus-rootless-deb`, ID 14393735142, zip SHA-256 `83dee9f040b61db7b5ad59ea067bc40cecfbf30f6f71cb8999a0d594fe318de2`, expires 2026-11-25 |
| Works with | HCG Halo 0.2.0~beta1 or later (border interface 1); either package works alone |
| Distribution | HCG Repo Candidate, free public demo by a per-version exception; experimental; production access unchanged |

**CI (all four jobs green on this commit):**
* Lint + Core host tests: 27,674 checks, 0 failures (`scripts/check.sh`; also rootless and rootful locally).
* HCG Device Link client tests (vendored copy unchanged, `VENDORED.sha256`).
* HCG Connect token verification (`HCGConnectVerify`): 21/21 on Linux (swift-crypto) and 21/21 on macOS (CryptoKit).
* Standalone app: 22/22 XCTests (sections, Settings rows in every mode, 44 pt labelled targets, Dynamic Type scaled
  once, capped chrome with the Large Content Viewer, migration, account not configured, Connected Devices boundary);
  launch check; screenshots of all seven sections, the largest text size and increased contrast
  (`docs/screenshots/0.3.1-beta1/`); unsigned device build and archive.
* Jailbreak package, `build-jailbreak-deb.sh --require-new-arm64e-abi`: passed.

**Checked again here on the downloaded bytes (zip digest matched GitHub's):**
* `scripts/inspect-package.py … rootless --require-new-arm64e-abi`: every check OK, no warnings. Includes gzip
  members, root:wheel, arm64/arm64e (new ABI), shared build ID, Settings bundle 0.3.1 = package base version,
  nothing outside `/var/jb`, branding (`hcg-logo.png` `424dbe64…3a07`, `nexus-emblem.png` `8e8582be…a86af`,
  `hcg-nexus-banner.jpg` `1cb7c600…5a3b`).
* `HaloBorder.plist` is installed at `/var/jb/Library/PreferenceBundles/HCGNexusPrefs.bundle/` and is **accepted by HCG
  Halo 0.2.0~beta1's own validator** (`HaloNexusDefinition.m` from HCG-Jailbreak-Research `778c21a`, compiled on Linux
  with GNUstep; only subscripts, one file read and property synthesis adapted for the older runtime): Nexus
  0.3.1~beta1, corner radius 22 (continuous), outset 2, glow margin 36, six capabilities. The same build rejects an
  older `nexusVersion`, a wrong schema, an integer for a boolean, a float interface version, an unknown key and
  interface version 2.
* `HCGNexus.dylib` exports `HCGNexusBorderInterface` (`+activeInterface`, `+interfaceVersion`, `borderHostView`,
  `presentationProgress`, `+borderDefinitionPath`) and posts `com.hakmicapitalgroup.hcgnexus.border-event`.
* The HCG Halo session ran Halo's panel preview against this code: 17/17 (attach via the installed definition,
  open/close/reversal, Halo or Nexus off, 30 cycles, Command Mode).

**Still needs the device:** everything in `DEVICE-CHECKLIST.md`; in particular SpringBoard loading on iOS 16.5,
panel glass and blur, Halo drawing on the live panel, Command Mode, and recovery.

## 0.3.0~beta1 — run #15: not shipped (superseded by the combined 0.3.1~beta1) (recorded 2026-11-18)

**Status: not yet device-tested.** Checklist: `DEVICE-CHECKLIST.md`.

| | |
|---|---|
| File | `com.hakmicapitalgroup.hcgnexus_0.3.0~beta1_iphoneos-arm64.deb` |
| **SHA-256** | **`e4a92c2b3680b965052769cd641cce6ebe28aa0371a0e3e3c72a29f46c5ca341`** |
| Built from | `77b0f3adb1d75ceb0c4c088fa8e9d0ab33573b57` on branch `claude/hcg-nexus-tweak-yb1ii2` (embedded build ID `77b0f3adb1`, config `rootless-release`) |
| Workflow | *Build package* run **#15**, ID 44213585148, route `both`, layout `rootless`, 2026-11-18 01:09 UTC: https://github.com/F1r3srp3nt/HCG-Nexus/actions/runs/44213585148 |
| Artifact | `hcg-nexus-rootless-deb`, ID 14386843705, zip SHA-256 `f156dc38fd04aea061dd4d38e66f71a5e2931983d8f1b78089126b22aaf585f6`, expires 2026-11-25 |
| Distribution | HCG Repo Candidate, `https://repo.hakmicapitalgroup.com/repo/candidate/`: free public demo by a per-version exception. Production access is unchanged |

**Jailbreak package (CI, `build-jailbreak-deb.sh --require-new-arm64e-abi`): passed.**
* arm64 + arm64e slices with the versioned ptrauth ABI in the tweak and the Settings bundle; `%ctor` in every slice;
  SpringBoard-only filter.
* `ar` members `debian-binary`, `control.tar.gz`, `data.tar.gz` (gzip); root:wheel; dirs/binaries 0755, data 0644;
  regular files only; nothing outside `/var/jb`; no doubled `var/jb/var/jb` prefix.
* Branding installed at `/var/jb/Library/Application Support/HCGNexus/` (`hcg-logo.png`, `nexus-emblem.png`).
* Tweak and Settings bundle share build `77b0f3adb1`; Settings bundle 0.3.0 = package base version.
* `Depends: mobilesubstrate | ellekit, preferenceloader`; no maintainer scripts.

**Host and Linux checks (CI lint job and locally):** `scripts/check.sh` passed, Core host tests 27,188 checks /
0 failures (rootless and rootful), HCG Device Link client tests passed. App target compiled and linked against the
iPhoneOS 14.5 and 16.5 SDKs on Linux.

**Run #14 (`6d89605`) is not a candidate.** Its package verified, but 2 app tests failed: an inserted settings section
shifted the About section's identifier, and HCG Products used a 25.7 pt unlabelled detail button. Both were fixed in
`77b0f3a`, which also changes code in the tweak, so only run #15 is offered.

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
## Command Mode (branch `claude/nexus-command-mode`, 2026-11-18)

Linux container only (Ubuntu clang 18.1.3 + GNUstep). **No Theos toolchain,
no Xcode run, no simulator and no device run** for this change. Version stays
0.2.0: nothing in the docs requires a bump for an unreleased feature branch,
and `control`/`HCG_NEXUS_VERSION` must move together when it is released.

| Check | Result |
|---|---|
| `scripts/check.sh` (lint, Core portability, safety rules, plists, Xcode project matches generator, app-target boundaries, host tests) | **pass** — "All checks passed."; app-target compile/link step **SKIP** (no `$THEOS`) |
| Core host tests (new `Tests/Host/CommandModeTests.m`: every Command Mode display state, nil/unrecognised/out-of-range data, battery/power/network/storage, presentation policy, no implied-activity wording) | **pass** — 27,456 checks, 0 failures (26,970 before this change) |
| Mutation checks by hand: an unreported sign-in state mapped to Connected; "off" mapped to Disconnected | suite **fails** as expected (2 and 3 failures) |
| `generate_xcodeproj.py --check` after regenerating (3 new app sources, Network.framework linked) | **pass** — 34 app sources |
| `check_app_target.py` | **pass** — 34 sources, public APIs only |
| Syntax check with host clang against public iPhoneOS SDK headers (`theos/sdks`, fetched into a scratch directory, not installed): tweak sources (Core + Panel + SpringBoard) for 16.5/iOS 15.0 and 14.5/iOS 14.0 with `-Wall -Werror`; app target for both SDKs with the flags of `compile-app-target.sh`; preview harness sources | **pass** — 0 diagnostics in every set. This is not a Theos or Xcode build: no Logos (`Tweak.x`), no Settings bundle (private Preferences headers), no packaging |
| App target linked with `ld64.lld` against the 14.5 and 16.5 SDK stubs (compiler-rt `___isOSVersionAtLeast` / `___isPlatformVersionAtLeast` left to Xcode, as in `compile-app-target.sh`) | **pass** — `nw_path_*` resolve from Network.framework; no private-API strings |
| `Tests/App/HCGNexusAppTests.m` › `testCommandModeShowsRealStatesInAppMode` | **not run** (needs Xcode); syntax-checked only, against a stub XCTest header |
| Command Mode on the simulator, in the preview harness, or on the iPhone 13 Pro | **not done** — see `DEVICE-CHECKLIST.md` row 4b |

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
