# Device checklist — HCG Nexus 0.2.0 (run #10)

**Setup (confirmed by the owner, 2026-11-16):** iPhone 13 Pro (`iPhone14,2`),
iOS 16.5, Dopamine (rootless, `/var/jb`), ElleKit. Install from Terminal/SSH,
because HCG Repo is suspected of crashing Sileo.

**Package:** only `com.hakmicapitalgroup.hcgnexus_0.2.0_iphoneos-arm64.deb`,
SHA-256 `799734e7949b30bf90f2790f602e0043bac3a23e7bd43898f811f2bde3addc2e`
(build `13416698ea`). Not the standalone app, not the preview-simulation package.

Runtime behaviour is **unverified** until this list has been run. Every step is
manual; nothing here installs or resprings by itself. Keep the recovery steps
below at hand before starting.

This build does **not** have the *About › HCG Repo* row (added to `main` later)
or Connected Devices (standalone app branch only). Their absence is expected.

| # | Do | Expect | If not |
|---|---|---|---|
| 0 | Before installing: `dpkg-query -W ellekit preferenceloader`, and note whether Sileo opens | Both packages listed with versions | Install the missing one from Dopamine's default sources first (not HCG Repo) |
| 1 | `sh hcg-nexus-install-local.sh` in the folder holding the `.deb` | Every line `OK`, ending "All checks passed. Nothing was changed." | Do not install; send the output |
| 2 | `sudo sh hcg-nexus-install-local.sh --install`. Do **not** respring yet. Open Settings › HCG Nexus | dpkg finishes; Settings shows *Installed 0.2.0 (13416698ea)* and *SpringBoard: Not loaded* | No Settings entry → PreferenceLoader issue; send `dpkg -s com.hakmicapitalgroup.hcgnexus` |
| 3 | Respring (Dopamine app › Respring). Open Settings › HCG Nexus | *SpringBoard: Running*; Edge handle *Off*; Diagnostics › Injector lists ElleKit; Device `iPhone14,2 · iOS 16.5` | *Not loaded* → tweak injection off or ElleKit not loading; *Stopped* → reason in the footer |
| 4 | Turn on **Enable HCG Nexus** | Within ~2 s the cyan handle appears on the right edge; Status › Edge handle *Working*; no respring | Footer names the failing feature and why |
| 5 | Tap the handle; open a workspace; run an app shortcut (e.g. Files) | Panel opens; the app opens; Recents records it | Status › App launching gives the reason |
| 6 | Lock the phone; then, unlocked, pull down Notification Centre | Handle hidden on the lock screen and cover sheet; back after unlock/dismiss | Status › Lock detection |
| 7 | Rotate inside an app that supports landscape | Handle stays on the chosen edge, clear of system gesture areas | Status › Rotation |
| 8 | In Settings › HCG Nexus change handle side, position and visibility | Applies immediately; values survive leaving and reopening Settings | — |
| 9 | Turn **Enable** off | Handle disappears immediately; touches pass through | Recovery step 2 |
| 10 | **Copy Diagnostics Report**, paste it into Notes | Build `13416698ea (rootless-release)`, `iPhone14,2`, iOS 16.5, feature states; no e-mail, names or identifiers | Send the report anyway |
| 11 | Recovery test: `touch /var/mobile/Library/Preferences/com.hakmicapitalgroup.hcgnexus.killswitch`, respring, open Settings › HCG Nexus | *SpringBoard: Stopped — kill switch file present…*; no handle even with Enable on | — |
| 12 | `rm /var/mobile/Library/Preferences/com.hakmicapitalgroup.hcgnexus.killswitch`, respring | *Running* again; handle back if Enable is on | — |
| 13 | Optional: `sudo dpkg -r com.hakmicapitalgroup.hcgnexus`, respring | Handle gone; Settings entry gone | Recovery below |

Report back with the pasted diagnostics report, a pass or fail for each row, and the
output of step 1.

## Recovery (least to most invasive)

1. **Settings › HCG Nexus › Enable → off.** Immediate; workspaces kept.
2. **Kill switch** (if Settings can't be used):
   `touch /var/mobile/Library/Preferences/com.hakmicapitalgroup.hcgnexus.killswitch`,
   then respring. Delete the file and respring to undo.
3. **Uninstall without any repository:** `sudo dpkg -r com.hakmicapitalgroup.hcgnexus`,
   then respring. Settings and workspaces remain in
   `/var/mobile/Library/Preferences/com.hakmicapitalgroup.hcgnexus.plist`; delete it
   only to erase them.
4. **SpringBoard crash loop:** reboot. Dopamine is semi-untethered, so the phone
   starts without tweaks. If your Dopamine version has a tweak-injection switch,
   turn it off, then jailbreak, run step 3 (or 2), and turn injection back on.
   ElleKit's safe mode is a further fallback.

Nothing in these steps contacts HCG Repo or any other source, or touches other
HCG apps or services.
