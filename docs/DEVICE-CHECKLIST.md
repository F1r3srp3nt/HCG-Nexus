# Device checklist — 0.2.0 on iPhone 13 Pro (iOS 16.5, Dopamine, ElleKit, Sileo)

Runtime behaviour is **unverified** until this list has been run. Every step
is manual; nothing here installs or resprings by itself. Keep the recovery
steps in `INSTALL-AND-RECOVERY.md` at hand.

Use only an **Xcode-built** rootless package (`scripts/build-jailbreak-deb.sh`
on a Mac, or the manual *Build package* workflow). Before installing, note its
SHA-256 and confirm the inspector printed `arm64e … versioned ABI`.

| # | Do | Expect | If not |
|---|---|---|---|
| 1 | Install the `.deb` in Sileo. Do **not** respring yet. Open Settings › HCG Nexus | Status: *Installed 0.2.0 (<build>)*, *SpringBoard: Not loaded* (or *Respring required* when upgrading) | Settings entry missing → PreferenceLoader not installed |
| 2 | Respring (Sileo's button or the Dopamine app). Open Settings › HCG Nexus again | *SpringBoard: Running*; Edge handle *Off*; Diagnostics › Injector names ElleKit; Started by *launch notification* | *Not loaded* → tweak not injected (check ElleKit/tweak injection); *Stopped* → reason shown in the footer |
| 3 | Turn on **Enable HCG Nexus** | Within ~2 s the cyan handle appears on the right edge; Status › Edge handle *Working*. No respring | Footer shows the failing feature and reason |
| 4 | Tap the handle; open a workspace; run an app shortcut (e.g. Files) | Panel opens; the app opens; Recents records it | App launching row explains which launcher is missing |
| 5 | Lock the phone; pull down the cover sheet while unlocked | Handle hidden on the lock screen and cover sheet; returns after unlock/dismiss | Lock detection row |
| 6 | Rotate inside an app that supports landscape | Handle stays on the chosen edge, clear of system gesture areas | Rotation row |
| 7 | Change handle side / position / visibility in Settings | Applies immediately | — |
| 8 | Turn **Enable** off | Handle disappears immediately; touches pass through | Use the kill switch (recovery step 3) |
| 9 | Tap **Copy Diagnostics Report** and paste it into a note | Report lists build, device `iPhone14,2`, iOS 16.5, feature states; no e-mail, names or identifiers | Share the report with the result |
| 10 | Uninstall in Sileo, respring | Handle gone; Settings entry gone | Recovery section |

Report back: the pasted diagnostics report plus pass/fail for each row.
