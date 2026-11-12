# Build, install and recovery

Nothing here runs automatically. Building never installs. Installing never
resprings. Every device step is yours to run.

## Build (macOS or Linux with Theos)

```sh
export THEOS=~/theos                     # your Theos checkout
make package HCG_ENV=rootless FINALPACKAGE=1    # or HCG_ENV=rootful
python3 scripts/inspect-package.py packages/*.deb rootless
```

Optional: `HCG_ARCHS=arm64` for A11 or older devices. On A12 and newer, the
arm64e slice must use the new ABI; see `docs/ENVIRONMENT.md`.

This is a jailbreak `.deb`, not an IPA or TestFlight build.

The preview harness is a separate package and is never needed on the device:

```sh
make -C PreviewHarness package HCG_ENV=rootless FINALPACKAGE=1
```

## Install (manual)

1. Copy `packages/com.hakmicapitalgroup.hcgnexus_0.1.0_<arch>.deb` to the phone,
   for example with AirDrop, Filza or `scp`.
2. Install it with your package manager by opening the `.deb` in Sileo or Zebra,
   or over SSH:
   * rootless: `sudo apt install ./com.hakmicapitalgroup.hcgnexus_0.1.0_iphoneos-arm64.deb`
   * rootful: `apt install ./com.hakmicapitalgroup.hcgnexus_0.1.0_iphoneos-arm.deb`
3. **Respring when you choose.** Use the package manager's prompt, or run
   `sbreload` / `killall SpringBoard` yourself. The package has no maintainer
   scripts and never resprings by itself.
4. Open **Settings › HCG Nexus**. Diagnostics should show *SpringBoard build*
   and *Activated: No (disabled)*, which proves the tweak loaded.
5. Turn on **Enable HCG Nexus**. The cyan handle appears on the right edge. No
   respring is needed.

`make install THEOS_DEVICE_IP=…` also works, but only when you run it. The
Makefile does not set `INSTALL_TARGET_PROCESSES`, so it kills nothing.

## Disable or recover (least to most invasive)

1. **Settings › HCG Nexus › Enable HCG Nexus → off.** Takes effect
   immediately: the panel closes, the handle disappears and touches pass
   straight through. Workspaces are kept.
2. **From the panel:** Settings › Enable HCG Nexus → off, then confirm.
3. **Kill switch** (if Settings can't be opened):
   `touch /var/mobile/Library/Preferences/com.hakmicapitalgroup.hcgnexus.killswitch`,
   then respring. Nexus will not create anything at the next SpringBoard
   launch. Delete the file to undo.
4. **Uninstall:** remove **HCG Nexus** in Sileo, Zebra or Cydia, or run
   `sudo apt remove com.hakmicapitalgroup.hcgnexus` (no `sudo` on rootful),
   then respring. Settings and workspaces stay in
   `/var/mobile/Library/Preferences/com.hakmicapitalgroup.hcgnexus.plist`.
   Delete that file only if you also want to erase workspaces.
5. **SpringBoard crash loop:** use your jailbreak's safe mode or its
   tweak-injection toggle, if it has one. On semi-untethered jailbreaks, a
   reboot returns to stock iOS. Then uninstall as in step 4.

Uninstalling or disabling never touches other HCG apps or services.
