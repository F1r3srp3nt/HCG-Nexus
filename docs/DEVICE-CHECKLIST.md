# Device checklist — HCG Nexus 0.3.0~beta1 via HCG Repo Candidate

**Setup (owner-confirmed):** iPhone 13 Pro (`iPhone14,2`), iOS 16.5, Dopamine (rootless), ElleKit, Zebra.
**Package:** `com.hakmicapitalgroup.hcgnexus_0.3.0~beta1_iphoneos-arm64.deb`. Its SHA-256 is recorded in
`VALIDATION.md` (0.3.0~beta1). It is a free public demo in `https://repo.hakmicapitalgroup.com/repo/candidate/`.
**Status: not yet device-tested.** The simulator screenshots show the standalone app, not SpringBoard.
The 0.2.1~beta1 checklist is in git history (`claude/nexus-0.2.1-beta1`).

Upgrading from 0.2.x keeps every workspace and shortcut. The first launch copies app and link shortcuts into
Apps. Tools › Restore Previous Layout undoes that.

| # | Do | Expect |
|---|---|---|
| 1 | Zebra: refresh HCG Repo Candidate, install/upgrade **HCG Nexus 0.3.0~beta1**, respring | Install log clean (`data.tar.gz`); Settings › HCG Nexus › Status: *Installed 0.3.0~beta1*, *SpringBoard: Running* |
| 2 | Enable, open the panel | Smoked-glass panel; chrome **HCG** logo + NEXUS in the header; section bar; Overview opens first |
| 3 | Overview | Emblem header (no banner yet); workspace chips switch with one tap; quick actions run; device rows show `iPhone14,2`, iOS 16.5, battery %, Low Power, thermal, storage, uptime |
| 4 | Settings › HCG Nexus › Panel glass: opacity min/max, blur Off/Light/Standard/Strong | The panel changes at once; text stays readable at every setting; with blur off the panel never goes below ~60 % |
| 5 | iOS Settings › Accessibility: Reduce Transparency on | The panel turns opaque and unblurred; glass controls are disabled with a note |
| 6 | Reduce Motion on (or Animations off), open/close the panel | No glow sweep on the Overview, fade instead of slide; with both off, the glow line moves slowly while open and stops when closed |
| 7 | Workspaces: create, rename, reorder, delete; open one; pick quick actions and tools | Saved immediately; survive a respring |
| 8 | Apps: search, favourite, reorder, add an app (bundle ID) and a link, swipe *To Workspace*, delete | Each succeeds with a confirmation toast; invalid input explains why |
| 9 | Tools: Copy Diagnostics (paste it), Clear Recent Actions, HCG Repo page, Import, Restore Previous Layout, Turn Off | Toast for each; Restore brings the 0.2 layout back; Turn Off hides the handle |
| 10 | HCG Products | Each app shows Installed / Not installed correctly; *Open* launches installed ones; Sentinel screens open; Server / Executable Maker explain the next step; account always "not shared" |
| 11 | Devices and Account in the tweak | "Not part of the jailbreak package" and "Sign-in is in the standalone app" — no data, no sign-in |
| 12 | Respring with the panel open; lock while open | Panel closes; handle hidden on lock screen |

Report back with: a pass or fail for each row, the pasted diagnostics report, and screenshots of rows 2, 3, 4 and 10.

## Recovery

1. Settings › HCG Nexus › Enable off (immediate).
2. Kill switch: create `/var/mobile/Library/Preferences/com.hakmicapitalgroup.hcgnexus.killswitch` (Filza or `touch`),
   then respring.
3. Uninstall: Zebra › HCG Nexus › Remove (or `sudo dpkg -r com.hakmicapitalgroup.hcgnexus`), then respring.
4. Crash loop: reboot (Dopamine starts without tweaks), then step 3.
5. Layout only: Tools › Restore Previous Layout returns the 0.2 workspaces exactly as they were stored.
