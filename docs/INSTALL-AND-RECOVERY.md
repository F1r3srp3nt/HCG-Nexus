# Build, install and recovery

Nothing here runs automatically. Building never installs. Installing never
resprings. Every device step is yours to run.

## Build

Confirmed target: iPhone 13 Pro, iOS 16.5, Dopamine (rootless), ElleKit, Sileo.

The device package must come from Apple's toolchain (see `docs/ENVIRONMENT.md`):

* **GitHub Actions:** Actions → *Build package* → *Run workflow* (layout
  `rootless`). Download the `hcg-nexus-rootless-deb` artifact (kept 7 days).
  The run fails if the arm64e slice has the old ABI.
* **Mac with Xcode 12+ and Theos:**
  ```sh
  export THEOS=~/theos
  make package FINALPACKAGE=1            # HCG_ENV defaults to rootless
  python3 scripts/inspect-package.py packages/*.deb rootless --require-new-arm64e-abi
  ```

Linux builds are fine for compile checks and the host tests, but not for this
device. This is a jailbreak `.deb`, not an IPA or TestFlight build. The
preview harness is a separate package and is not needed on the phone.

## Install on Dopamine with Sileo (manual)

1. Get `com.hakmicapitalgroup.hcgnexus_0.1.0_iphoneos-arm64.deb` onto the
   phone (AirDrop or Files) and open it with **Sileo**, then tap *Get* /
   *Install*. Sileo will also offer missing dependencies such as
   PreferenceLoader.
   Over SSH instead: `sudo apt install ./com.hakmicapitalgroup.hcgnexus_0.1.0_iphoneos-arm64.deb`.
2. **Respring when you choose:** Sileo's *Restart SpringBoard* button after
   the install, or the Respring action in the Dopamine app. The package has no
   maintainer scripts and never resprings by itself.
3. Open **Settings › HCG Nexus**. Diagnostics should show *SpringBoard build*
   and *Activated: No (disabled)*, which proves ElleKit loaded the tweak.
4. Turn on **Enable HCG Nexus**. The cyan handle appears on the right edge
   with no respring.

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
   launch. Delete the file to undo.
4. **Uninstall:** Sileo → *Installed* → **HCG Nexus** → *Remove*, or
   `sudo apt remove com.hakmicapitalgroup.hcgnexus` over SSH, then respring. Settings and workspaces stay in
   `/var/mobile/Library/Preferences/com.hakmicapitalgroup.hcgnexus.plist`.
   Delete that file only if you also want to erase workspaces.
5. **SpringBoard crash loop:** Dopamine is semi-untethered, so **rebooting**
   returns the phone to stock iOS with no tweaks loaded. Before jailbreaking
   again, turn off tweak injection in the Dopamine app's settings (if your
   Dopamine version has that option), jailbreak, then remove HCG Nexus in
   Sileo (step 4) or create the kill-switch file (step 3), and turn tweak
   injection back on. ElleKit's safe mode after a SpringBoard crash is a
   further fallback.

Uninstalling or disabling never touches other HCG apps or services.
