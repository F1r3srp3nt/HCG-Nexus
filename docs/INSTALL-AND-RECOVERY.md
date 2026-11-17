# Build, install and recovery

Nothing here runs automatically. Building never installs. Installing never
resprings. Every device step is yours to run.

## Build the jailbreak package

Confirmed target (re-confirmed 2026-11-16): iPhone 13 Pro, iOS 16.5, Dopamine (rootless), ElleKit; installs from HCG Repo Candidate with Zebra.
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

## Install from HCG Repo Candidate with Zebra (the testing route)

Package: **HCG Nexus 0.2.1~beta1**, `com.hakmicapitalgroup.hcgnexus_0.2.1~beta1_iphoneos-arm64.deb`,
SHA-256 `948465eaa30fd8cf1bc9fd98141362fe08c4e24ab0b23d788a39fa65d8ac17af` (run #13, see `VALIDATION.md`).
It is the 0.2.0 code with gzip packaging. HCG Nexus is a paid product; this one beta is free in the candidate
channel. Not yet device-tested.

1. In Zebra, add the source `https://repo.hakmicapitalgroup.com/repo/candidate/` (*HCG Repo Candidate*) and refresh.
   Refreshing this source is expected and fine.
2. Open **HCG Nexus**, check the version reads **0.2.1~beta1**, and install it. Zebra installs PreferenceLoader or an
   injector from your other sources only if they are missing.
3. **Respring when you choose** (Zebra's restart button or Dopamine app › *Respring*). The package has no
   maintainer scripts and never resprings by itself.
4. Open **Settings › HCG Nexus**. The **Status** section shows the installed version and build, and
   *SpringBoard: Running* once the respring has loaded that build. *Not loaded* means the injector did not load the
   tweak; *Stopped* gives the reason.
5. Turn on **Enable HCG Nexus**. The cyan handle appears on the right edge with no respring. Settings changes apply
   immediately; a respring is only needed after installing or updating the package.

Run `DEVICE-CHECKLIST.md` for the full first-run check.

## Optional: install a local file with Terminal/SSH

SSH or NewTerm is optional, for diagnosis and recovery. `scripts/device/hcg-nexus-install-local.sh` verifies and
installs one specific local file with `dpkg -i`, no repository involved. As shipped, it pins run #10's 0.2.0 file
(`799734e7…dc2e`), which is **not** offered for installation because of its lzma packaging; adjust `EXPECTED_*`
before using it for another build. For the candidate build, the manual equivalent is:

```sh
sha256sum com.hakmicapitalgroup.hcgnexus_0.2.1~beta1_iphoneos-arm64.deb   # must print 948465ea…8ac17af
dpkg-query -W ellekit preferenceloader                                  # both must be listed
sudo dpkg -i ./com.hakmicapitalgroup.hcgnexus_0.2.1~beta1_iphoneos-arm64.deb
```

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
4. **Uninstall:** Zebra › *Packages* › **HCG Nexus** › *Remove*, or over Terminal/SSH
   `sudo dpkg -r com.hakmicapitalgroup.hcgnexus`.
   Then respring. Settings and workspaces stay in
   `/var/mobile/Library/Preferences/com.hakmicapitalgroup.hcgnexus.plist`.
   Delete that file only if you also want to erase workspaces.
5. **SpringBoard crash loop:** Dopamine is semi-untethered, so **rebooting**
   returns the phone to stock iOS with no tweaks loaded. Before jailbreaking
   again, turn off tweak injection in the Dopamine app's settings (if your
   Dopamine version has that option), jailbreak, then remove HCG Nexus in Zebra or with
   `sudo dpkg -r com.hakmicapitalgroup.hcgnexus` (step 4)
   or create the kill-switch file (step 3), and turn tweak injection back on. ElleKit's safe mode after a SpringBoard crash is a
   further fallback.

Uninstalling or disabling never touches other HCG apps or services.
