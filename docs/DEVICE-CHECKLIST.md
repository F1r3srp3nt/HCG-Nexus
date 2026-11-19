# Device checklist — HCG Nexus 0.3.2~beta1 (with HCG Halo 0.3.1~beta1) via HCG Repo Candidate

**Setup (owner-confirmed):** iPhone 13 Pro (`iPhone14,2`), iOS 16.5, Dopamine (rootless), ElleKit, Zebra.
**Package:** `com.hakmicapitalgroup.hcgnexus_0.3.2~beta1_iphoneos-arm64.deb`. Its SHA-256 is recorded in
`VALIDATION.md` (0.3.2~beta1). It is a free public demo in `https://repo.hakmicapitalgroup.com/repo/candidate/`.
**Status: not yet device-tested.** The simulator screenshots show the standalone app, not SpringBoard.
The 0.2.1~beta1 checklist is in git history (`claude/nexus-0.2.1-beta1`).

Upgrading from 0.2.x keeps every workspace and shortcut. The first launch copies app and link shortcuts into
Apps. Tools › Restore Previous Layout undoes that.

| # | Do | Expect |
|---|---|---|
| 1 | Zebra: refresh HCG Repo Candidate, install/upgrade **HCG Nexus 0.3.1~beta1**, respring | Install log clean (`data.tar.gz`); Settings › HCG Nexus › Status: *Installed 0.3.1~beta1*, *SpringBoard: Running* |
| 2 | Enable, open the panel | Smoked-glass panel; chrome **HCG** logo + NEXUS in the header; section bar; Overview opens first |
| 3 | Overview | Official HCG Nexus banner shown whole (star and lettering not cropped); workspace chips switch with one tap; quick actions run; device rows show `iPhone14,2`, iOS 16.5, battery %, Low Power, thermal, storage, uptime |
| 4 | Settings › HCG Nexus › Panel glass: opacity min/max, blur Off/Light/Standard/Strong | The panel changes at once; text stays readable at every setting; with blur off the panel never goes below ~60 % |
| 5 | iOS Settings › Accessibility: Reduce Transparency on | The panel turns opaque and unblurred; glass controls are disabled with a note |
| 6 | Reduce Motion on (or Animations off), open/close the panel | No glow sweep on the Overview, fade instead of slide; with both off, the glow line moves slowly while open and stops when closed |
| 7 | Workspaces: create, rename, reorder, delete; open one; pick quick actions and tools | Saved immediately; survive a respring |
| 8 | Apps: search, favourite, reorder, add an app (bundle ID) and a link, swipe *To Workspace*, delete | Each succeeds with a confirmation toast; invalid input explains why |
| 9 | Tools: Copy Diagnostics (paste it), Clear Recent Actions, HCG Repo page, Import, Restore Previous Layout, Turn Off | Toast for each; Restore brings the 0.2 layout back; Turn Off hides the handle |
| 10 | HCG Products | Each app shows Installed / Not installed correctly; *Open* launches installed ones; Sentinel screens open; Server / Executable Maker explain the next step; account always "not shared" |
| 11 | Devices and Account in the tweak | "Not part of the jailbreak package" and "Sign-in is in the standalone app" — no data, no sign-in |
| 12 | Respring with the panel open; lock while open | Panel closes; handle hidden on lock screen |

| 13 | In the open panel, tap the grid button (**Command Mode**); then rotate, lock, and reopen | Status tiles: battery %, charging, Low Power, network, storage, thermal. Integration states never claim *Connected* without proof. Lock or close removes it; the panel returns when it is dismissed |
| 14 | With **HCG Halo 0.2.0~beta1** installed (either order, one respring): Settings › HCG Nexus › Appearance › **Halo border** | Opens HCG Halo's *Nexus Panel Border* page: *HCG Nexus 0.3.1~beta1 · compatible*; the preview shows the panel outline |
| 15 | HCG Halo › Border Target **HCG Nexus Panel**, Enable HCG Halo on; open, drag-cancel and close the panel; switch workspace; open Command Mode | Light trace on open, border follows the panel, fades with it on close and while Command Mode is shown; one soft pulse on workspace change; no orphaned border; all panel controls respond |
| 16 | Turn HCG Halo off with the panel open; then remove HCG Halo and respring | Border gone at once; Nexus looks and works as usual; Appearance › Halo border explains HCG Halo is not installed |
| 17 | 0.3.2: Settings › HCG Nexus › Appearance with HCG Halo **0.3.1~beta1**, HCG Halo off | *Use HCG Halo border* off, Status **Disabled**. Turn it on: Status **Ready**; HCG Halo › Border Target becomes *HCG Nexus Panel*; the screen edge stays dark |
| 18 | Open the panel; in the panel's Settings › *HCG Halo border* | Border drawn around the panel; Status **Active**. Close the panel: border gone; Settings › HCG Nexus shows **Ready** |
| 19 | HCG Halo screen edge on (Target *Screen Edge*), then turn *Use HCG Halo border* on and off | On: Target *Both*, screen edge unchanged. Off: Target back to *Screen Edge*, screen edge unchanged |
| 20 | Remove HCG Halo (respring); then install HCG Halo 0.3.0~beta1 only | Status **Not installed**, switch disabled, panel keeps Nexus's outline. With 0.3.0 (no switch API): switch disabled with "switched in HCG Halo › Border Target" |
| 21 | HCG Products › HCG Terminal (and Unleashed, if installed) | Installed shows the real version (e.g. *Installed · 0.1.0*); Launch *Available*; Integration names the version and says it has no handoff yet; Session *Not shared*. *Open HCG Terminal* opens it; the toast says *Opened*, never *Connected*. Command Mode shows *Launch available* |
| 22 | Only with an HCG Terminal build that has the Nexus handoff: Copy Link for HCG Nexus on a saved connection; HCG Products › *Open Saved Connection…*, paste | HCG Terminal opens that connection's screen and waits for you to tap Connect; no session starts and nothing runs by itself. A link with any extra parameter is refused in Nexus |
| 23 | 0.3.3~beta1: Settings › HCG Nexus › Panel glass: blur **Off** with opacity 0.4, then **Strong** with 1.0; open Command Mode after each (and change it while Command Mode is open). Then turn on Accessibility › Reduce Transparency | The Command Mode card matches the panel each time (blur Off: no blur, tint at the 0.6 floor; Strong: thick blur, opaque); a change shows without reopening. With Reduce Transparency: no blur, opaque card, whatever the setting |

Report back with: a pass or fail for each row, the pasted diagnostics report, and screenshots of rows 2, 3, 4 and 10.

## Recovery

1. Settings › HCG Nexus › Enable off (immediate).
2. Kill switch: create `/var/mobile/Library/Preferences/com.hakmicapitalgroup.hcgnexus.killswitch` (Filza or `touch`),
   then respring.
3. Uninstall: Zebra › HCG Nexus › Remove (or `sudo dpkg -r com.hakmicapitalgroup.hcgnexus`), then respring.
4. Crash loop: reboot (Dopamine starts without tweaks), then step 3.
5. Layout only: Tools › Restore Previous Layout returns the 0.2 workspaces exactly as they were stored.
