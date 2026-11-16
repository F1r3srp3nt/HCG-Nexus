# Build, install and recovery

Nothing here runs automatically. Building never installs. Installing never
resprings. Every device step is yours to run.

## Build the jailbreak package

Confirmed target (re-confirmed 2026-11-16): iPhone 13 Pro, iOS 16.5, Dopamine (rootless), ElleKit; installs from Terminal/SSH.
This route builds a jailbreak `.deb`. It is separate from the standalone app's
IPA route (`docs/STANDALONE-APP.md`) and does not need HCG Executable Maker or
any particular Executable Maker release.

The device package must come from Apple's toolchain, because only Apple clang
emits the iOS 14+ arm64e ABI (see `ENVIRONMENT.md`).

**On a Mac (recommended):**

```sh
# one-time setup
xcode-select -p                     # must point into Xcode.app, not CommandLineTools
brew install ldid make dpkg         # gmake (GNU make 4+), ldid, dpkg-deb
git clone --recursive https://github.com/theos/theos.git ~/theos
export THEOS=~/theos
# SDKs the Makefile asks for: 16.5 (rootless) and/or 14.5 (rootful)
git clone --depth 1 --filter=blob:none --sparse https://github.com/theos/sdks.git /tmp/sdks
git -C /tmp/sdks sparse-checkout set iPhoneOS16.5.sdk iPhoneOS14.5.sdk
cp -R /tmp/sdks/iPhoneOS16.5.sdk /tmp/sdks/iPhoneOS14.5.sdk "$THEOS/sdks/"

# build + verify (nothing is installed)
scripts/build-jailbreak-deb.sh                  # rootless → packages/rootless/com.hakmicapitalgroup.hcgnexus_0.2.0_iphoneos-arm64.deb
scripts/build-jailbreak-deb.sh --env rootful    # rootful  → packages/rootful/com.hakmicapitalgroup.hcgnexus_0.2.0_iphoneos-arm.deb
scripts/build-jailbreak-deb.sh --check-only     # preflight only
```

**Direct build (no wrapper, no Executable Maker):** the same package with
plain Theos. GNU Make 4+ is required (macOS ships 3.81; the Makefile stops
with an explanation if it is older), so use `gmake` on a Mac:

```sh
export THEOS=~/theos
gmake package FINALPACKAGE=1 HCG_ENV=rootless   # → packages/rootless/
gmake package FINALPACKAGE=1 HCG_ENV=rootful    # → packages/rootful/
python3 scripts/inspect-package.py packages/rootless/*.deb rootless --require-new-arm64e-abi
```

Each layout has its own object, staging and package directories
(`.theos/obj/<layout>`, `.theos/_<layout>`, `packages/<layout>`), so building
one never mixes files into the other. The Settings bundle is a subproject of
the root Makefile and is always built with the same layout and build ID; the
inspector proves it by comparing the build marker in both binaries. The build
ID is the git commit (`-dirty` when tracked files are modified); override it
with `HCG_BUILD_ID=…`.

The script first checks:
* Theos and the SDK the Makefile names for the chosen layout;
* Xcode is selected, and its clang is Apple clang 12 or newer;
* GNU make 4+, ldid, perl, dpkg-deb, python3;
* the `control` dependencies.

It then builds with Theos and runs `scripts/inspect-package.py --require-new-arm64e-abi`. That checks:
* the file layout, filter and dependencies;
* the arm64/arm64e slices and the new arm64e ABI;
* the tweak's initializer (its activation entry point);
* that there are no maintainer scripts.

It prints the package path and SHA-256.

**GitHub Actions (manual):** Actions → *Build package* → *Run workflow*, with
route `jailbreak` or `both` and the layout you need. Download the
`hcg-nexus-<layout>-deb` artifact (kept 7 days). The
`hcg-nexus-preview-SIMULATION-…` artifact is the preview harness, not the
tweak.

Linux builds are fine for compile checks and the host tests, but not for an
A12+ device. The preview harness is a separate package and is not needed on
the phone.

## Install from a local file with Terminal/SSH (no repository)

Confirmed setup: iPhone 13 Pro (`iPhone14,2`), iOS 16.5, Dopamine (rootless,
`/var/jb`), ElleKit. HCG Repo is suspected of crashing Sileo, so this route uses
neither Sileo nor any repository. `dpkg` installs the one local file.

Use **only** `com.hakmicapitalgroup.hcgnexus_0.2.0_iphoneos-arm64.deb`, SHA-256
`799734e7949b30bf90f2790f602e0043bac3a23e7bd43898f811f2bde3addc2e` (run #10, see
`VALIDATION.md`). Do not use the standalone app or the preview-simulation package.

1. **Copy two files to the phone**, into the same folder (for example
   `/var/mobile/Documents/hcg-nexus/`), with AirDrop and the Files app or `scp`:
   the `.deb` and `scripts/device/hcg-nexus-install-local.sh`.
2. **Check (changes nothing):**
   ```sh
   cd /var/mobile/Documents/hcg-nexus
   sh hcg-nexus-install-local.sh
   ```
   The script checks the file name, the SHA-256, the package's control fields,
   and that every file goes under `/var/jb`. It checks the device: `iPhone14,2`,
   iOS 16.5, `/var/jb` present, dpkg architecture `iphoneos-arm64`. It checks
   that ElleKit and PreferenceLoader are already installed. Any mismatch stops it
   with the reason, and it never downloads anything.
3. **Install:** `sudo sh hcg-nexus-install-local.sh --install`. This runs
   `dpkg -i` on the local file only. It does not respring.
   Without the script, the equivalent manual steps are:
   ```sh
   sha256sum com.hakmicapitalgroup.hcgnexus_0.2.0_iphoneos-arm64.deb   # must print 799734e7…dc2e
   dpkg-query -W ellekit preferenceloader                             # both must be listed
   sudo dpkg -i ./com.hakmicapitalgroup.hcgnexus_0.2.0_iphoneos-arm64.deb
   ```
4. **Respring when you choose:** Dopamine app › *Respring*, or
   `sudo killall -9 SpringBoard`.
5. Continue with `DEVICE-CHECKLIST.md`.

## Install on Dopamine with Sileo (only if Sileo works without HCG Repo)

1. Get `com.hakmicapitalgroup.hcgnexus_0.2.0_iphoneos-arm64.deb` onto the
   phone (AirDrop or Files) and open it with **Sileo**, then tap *Get* /
   *Install*. Sileo will also offer missing dependencies such as
   PreferenceLoader.
   Over SSH instead: `sudo apt install ./com.hakmicapitalgroup.hcgnexus_0.2.0_iphoneos-arm64.deb`.
2. **Respring when you choose:** Sileo's *Restart SpringBoard* button after
   the install, or the Respring action in the Dopamine app. The package has no
   maintainer scripts and never resprings by itself.
3. Open **Settings › HCG Nexus**. The **Status** section under the Enable
   switch shows the installed version and build, and *SpringBoard: Running*
   once the respring has loaded that same build. *Respring required* means
   SpringBoard still runs an older build; *Not loaded* means the injector did
   not load the tweak; *Stopped* gives the reason (kill switch, unsupported
   iOS, startup error).
4. Turn on **Enable HCG Nexus**. The cyan handle appears on the right edge
   with no respring, and Status › Edge handle reads *Working*. Settings
   changes always apply immediately; a respring is only needed after
   installing or updating the package.

Run `DEVICE-CHECKLIST.md` for the full first-run check.

`make install THEOS_DEVICE_IP=…` also works if you run it; the Makefile never
sets `INSTALL_TARGET_PROCESSES`, so nothing is killed.

## Disable or recover (least to most invasive)

1. **Settings › HCG Nexus › Enable HCG Nexus → off.** Takes effect
   immediately: the panel closes, the handle disappears and touches pass
   straight through. Workspaces are kept.
2. **From the panel:** Settings › Enable HCG Nexus → off, then confirm.
3. **Kill switch** (if Settings can't be opened):
   `touch /var/mobile/Library/Preferences/com.hakmicapitalgroup.hcgnexus.killswitch`,
   then respring. Nexus will not create anything at the next SpringBoard
   launch, and Settings › HCG Nexus shows *SpringBoard: Stopped* with the
   reason. Delete the file and respring to undo.
4. **Uninstall:** over Terminal/SSH, `sudo dpkg -r com.hakmicapitalgroup.hcgnexus`
   (no repository involved), or Sileo → *Installed* → **HCG Nexus** → *Remove*.
   Then respring. Settings and workspaces stay in
   `/var/mobile/Library/Preferences/com.hakmicapitalgroup.hcgnexus.plist`.
   Delete that file only if you also want to erase workspaces.
5. **SpringBoard crash loop:** Dopamine is semi-untethered, so **rebooting**
   returns the phone to stock iOS with no tweaks loaded. Before jailbreaking
   again, turn off tweak injection in the Dopamine app's settings (if your
   Dopamine version has that option), jailbreak, then remove HCG Nexus with
   `sudo dpkg -r com.hakmicapitalgroup.hcgnexus` (step 4; Sileo is not needed)
   or create the kill-switch file (step 3), and turn tweak injection back on. ElleKit's safe mode after a SpringBoard crash is a
   further fallback.

Uninstalling or disabling never touches other HCG apps or services.
