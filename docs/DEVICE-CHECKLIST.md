# Device checklist — HCG Nexus 0.2.1~beta1 (run #13) via HCG Repo Candidate

**Setup (owner-confirmed):** iPhone 13 Pro (`iPhone14,2`), iOS 16.5, Dopamine (rootless, `/var/jb`), ElleKit, Zebra.

**Package:** `com.hakmicapitalgroup.hcgnexus_0.2.1~beta1_iphoneos-arm64.deb`, SHA-256
`948465eaa30fd8cf1bc9fd98141362fe08c4e24ab0b23d788a39fa65d8ac17af`, build `58e2dbd81e`. This is the 0.2.0 code with
gzip packaging. It is not the standalone app and not the preview simulation.

**Status: not yet device-tested.** Every step is manual. Keep the recovery steps below at hand before step 2.

This build has no *About › HCG Repo* row, and no Connected Devices: that feature belongs to the standalone app,
not to this tweak.

| # | Do | Expect | If not |
|---|---|---|---|
| 1 | Zebra: add `https://repo.hakmicapitalgroup.com/repo/candidate/`, refresh, open **HCG Nexus** | Source *HCG Repo Candidate*; HCG Nexus **0.2.1~beta1**, about 450 KB, depends on ElleKit/mobilesubstrate and PreferenceLoader | Screenshot the source and package pages |
| 2 | Install. Do **not** respring yet | Install log ends without errors; it unpacks `data.tar.gz` (no `Bus error`) | Screenshot the full install log |
| 3 | Settings › HCG Nexus (before respring) | *Installed 0.2.1~beta1 (58e2dbd81e)*, *SpringBoard: Not loaded* | No Settings entry → PreferenceLoader issue |
| 4 | Respring (Zebra or Dopamine app). Settings › HCG Nexus | *SpringBoard: Running*; Edge handle *Off*; Diagnostics › Injector lists ElleKit; Device `iPhone14,2 · iOS 16.5` | *Not loaded* → injection; *Stopped* → reason in footer |
| 5 | Turn on **Enable HCG Nexus** | Cyan handle on the right edge within ~2 s; Status › Edge handle *Working*; no respring | Footer names the failing feature |
| 6 | Tap the handle; open a workspace; run an app shortcut (e.g. Files) | Panel opens; app opens; Recents records it | Status › App launching |
| 7 | Lock the phone; then, unlocked, pull down Notification Centre | Handle hidden on lock screen and cover sheet; back afterwards | Status › Lock detection |
| 8 | Rotate inside a landscape-capable app; change side/position/visibility in Settings | Handle stays clear of system edges; changes apply at once and persist | Status › Rotation |
| 9 | Turn **Enable** off | Handle disappears immediately; touches pass through | Recovery 2 |
| 10 | **Copy Diagnostics Report**, paste into Notes | Build `58e2dbd81e (rootless-release)`, `iPhone14,2`, iOS 16.5, feature states; no personal data | Send it anyway |
| 11 | Optional uninstall: Zebra › remove HCG Nexus, respring | Handle and Settings entry gone | Recovery below |

Report back with: the pass/fail result of each row, the pasted diagnostics report, and screenshots for any failure.

## Recovery (least to most invasive)

1. **Settings › HCG Nexus › Enable → off.** Takes effect immediately; workspaces are kept.
2. **Kill switch** (if Settings can't be used): create
   `/var/mobile/Library/Preferences/com.hakmicapitalgroup.hcgnexus.killswitch`, with Filza (new empty file) or in a
   terminal (`touch …`), then respring. Delete the file and respring to undo.
3. **Uninstall:** Zebra › *Packages* › HCG Nexus › *Remove*, or `sudo dpkg -r com.hakmicapitalgroup.hcgnexus`, then
   respring.
4. **SpringBoard crash loop:** reboot. Dopamine is semi-untethered, so the phone starts without tweaks. If your
   Dopamine has a tweak-injection switch, turn it off, jailbreak, run step 3 (or 2), and turn injection back on.
   ElleKit's safe mode is a further fallback.

SSH (or NewTerm) is optional, for diagnosis and for steps 2–3.
