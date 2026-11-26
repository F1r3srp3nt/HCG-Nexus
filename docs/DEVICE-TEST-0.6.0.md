# HCG Nexus 0.6.0~beta1 — physical device test

**Package under test:** `com.hakmicapitalgroup.hcgnexus` **0.6.0~beta1**, from HCG Repo Candidate.

| | |
|---|---|
| SHA-256 | `587b2fbd7548b0c9e84d888503ffbfd07ff687d2b679ee241e476b858e33e713` |
| Size | 2,076,696 bytes |
| Built by | HCG-Nexus *Build package* run #35, commit `1540d61` |

**Devices:**

- **A:** iPhone 13 Pro, iOS 16.5, Dopamine (rootless)
- **B:** iPhone 11 Pro Max, iOS 17.4, Dopamine (rootless)

Each device needs ElleKit, PreferenceLoader, and Zebra or Sileo.

Everything here is read-only for your phone, except installing and removing the package and the switches you flip
yourself. Nexus never resprings, installs or connects by itself. Fill in the results table at the end and send it back
with the diagnostics text from step 4.4.

**Time:** about 45 minutes per device (plus an overnight idle check for section 13, optional).

---

## 0. Before you start (rollback ready)

0.1. Note what is installed now: Zebra › Packages › HCG Nexus (version), or `dpkg -l | grep hcgnexus` in HCG Terminal
     Unleashed. Write it in the table.

0.2. Back up Nexus's settings and workspaces (optional, for exact rollback):
     `cp /var/mobile/Library/Preferences/com.hakmicapitalgroup.hcgnexus.plist /var/mobile/Documents/hcgnexus-backup.plist`

0.3. Know the kill switch (section 15). You can create it from Filza or HCG Terminal Unleashed even if SpringBoard
     misbehaves.

0.4. Charge above 50 %, and turn off Low Power Mode (it throttles the CPU and changes the measurements).

## 1. Installation

1.1. Zebra/Sileo › Sources › refresh **HCG Repo Candidate** (`https://repo.hakmicapitalgroup.com/repo/candidate/`).
     Expected: no source errors.

1.2. Search *HCG Nexus*. Expected: version **0.6.0~beta1** offered as the newest. 0.5.0, 0.4.0 and older betas are
     listed as older versions.

1.3. Install 0.6.0~beta1. Expected:
     - The package manager shows the dependencies `mobilesubstrate | ellekit`, `preferenceloader` and
       `firmware (>= 15.0)`.
     - No install-script output (the package has none).
     - The phone does **not** respring by itself.

1.4. Verify the exact file, in HCG Terminal Unleashed:
     `dpkg -s com.hakmicapitalgroup.hcgnexus | grep -E '^(Version|Status)'`
     Expected: `Version: 0.6.0~beta1`, `Status: install ok installed`.

1.5. Optional (proves the exact bytes):
     `sha256sum /var/jb/var/cache/apt/archives/com.hakmicapitalgroup.hcgnexus_0.6.0~beta1_iphoneos-arm64.deb`
     (or Zebra's download folder). Expected: `587b2fbd…e713`.

## 2. SpringBoard stability

2.1. Respring once (the package manager's button, or Dopamine's Respring). Expected: SpringBoard returns within about
     10 s; no Safe Mode banner.

2.2. Before enabling Nexus: use the phone normally for 1 minute (Home screen, Control Center, an app, Lock/unlock).
     Expected: no change from before (Nexus is off after installation).

2.3. Settings › HCG Nexus › **Enable HCG Nexus** → on. Expected: the cyan edge handle appears on the right edge without
     a respring.

2.4. Open and close the panel 20 times (tap the handle; close with the X, a swipe, and a tap outside). Expected: no
     freeze, no respring, and the handle stays in place.

2.5. Rotate (in an app that supports landscape), open the panel, then rotate back. Expected: the panel stays on screen
     and readable; no respring.

2.6. Lock the phone with the panel open, then unlock. Expected: the panel is closed or still usable; there is no
     handle on the Lock Screen.

## 3. Settings integration

3.1. Settings › HCG Nexus. Expected:
     - *Status*: *Installed 0.6.0~beta1*, *SpringBoard: Running*.
     - The Appearance, Panel glass and Diagnostics sections open.

3.2. Change Panel glass opacity, then open the panel. Expected: the change is visible without a respring.

3.3. Settings › HCG Nexus › Command Center (Ecosystem section) opens there too (the same screens as in the panel).

## 4. Diagnostics (record these)

4.1. Settings › HCG Nexus › Diagnostics. Expected: every row has a value (version, build `1540d61c7a`, environment
     rootless).

4.2. Note *Build* and *Environment* in the table.

4.3. Note any row that says *Error*, *Stopped* or *Unknown*.

4.4. Long-press or tap *Copy diagnostics* (if offered), paste the text into Notes, and send it back.

## 5. Standalone application launch

The standalone app (bundle `com.hakmicapitalgroup.hcgnexus.app`) is **not** part of the jailbreak package. It needs its
own signed install. Skip this section if you have no way to sign it, and write *not installed* in the table.

- **Option A (both devices):** Xcode on a Mac, `HCGNexus.xcodeproj`, your signing team, run on the device
  (docs/STANDALONE-APP.md).
- **Option B (device A only, if you already use TrollStore on iOS 16.5):** install the IPA exported from Xcode or HCG
  Executable Maker. The CI artifact `HCGNexus-unsigned-device-NOT-INSTALLABLE.app.zip` is for inspection and is not a
  supported install.

5.1. Launch HCG Nexus from the Home screen. Expected: it opens to Overview within 3 s; *APP MODE* in the header.

5.2. HCG Ecosystem › This iPhone. Expected: *Jailbreak: Not visible to this app (standalone build)*. That is correct:
     the sandboxed app cannot see installed products.

5.3. Force-quit and relaunch 3 times. Expected: no crash.

## 6. Command Center navigation

6.1. Panel › **HCG Ecosystem** › **Command Center** › **All HCG products**. Expected:
     - the official HCG logo;
     - *HCG Nexus*;
     - "41 products in 13 categories · N connected".

6.2. Dashboard rows:
     - **Connections**, **Roadmap**, **Connected devices**, **Service health**, **Package Trust Center** and **Registry**
       are present.
     - Each row with an arrow opens its screen; Back returns.

6.3. Open five different product profiles (for example HCG Terminal Unleashed, HCG News, HCG Connect, HCG Build Host,
     HCG Vanguard). Expected:
     - each shows Overview, Status, How it connects, Permissions, Roadmap and *Where this comes from*;
     - nothing claims *Connected* before step 6.4.

6.4. **HCG News › Check now.** Expected:
     - *Latest approved articles* lists real headlines (13 were published on 26 Nov);
     - the status becomes *Connected* with *Last successful communication: now*.

     Without internet: *Check failed* with the reason, and the status becomes *Connection failed*.

6.5. **HCG Connect › Check now.** Expected:
     - the sign-in issuer is shown, with *PKCE: S256 supported*;
     - *HCG Nexus client: Not issued: Nexus cannot sign in*;
     - no sign-in button.

6.6. **HCG Trading.** Expected:
     - *Research required*;
     - no website link (its domain does not answer yet).

6.7. Wait 16 minutes, then reopen HCG News. Expected: *Disconnected* (*Last connected …*). Evidence expires; it is not
     kept as *Connected*.

## 7. Product search

7.1. Type `terminal`. Expected: exactly HCG Terminal and HCG Terminal Unleashed.

7.2. Type `simulator`. Expected: HCG Trading Lab (its website name is the Trading Simulator).

7.3. Type `security vanguard`. Expected: only HCG Vanguard (every word must match).

7.4. Type `zzzz`. Expected: *No HCG product matches.*

7.5. Clear the search. Expected: the dashboard and categories come back.

## 8. Favorites

8.1. Open HCG Halo › **Add to Favorites**, then go Back. Expected: a *Favorites* section with HCG Halo.

8.2. Close the panel, respring, and reopen Command Center. Expected: HCG Halo is still in Favorites.

8.3. HCG Halo › **Remove from Favorites**. Expected: the Favorites section disappears.

## 9. Expandable categories

9.1. Tap the header **AI · 2**. Expected: it expands to HCG AI and HCG Agent Runtime; the chevron points down.

9.2. Expand three more categories, close the panel, then reopen. Expected: the same categories are still expanded.

9.3. Turn on VoiceOver and focus a category header. Expected: it reads "<category>, N products", with the expand or
     collapse hint.

## 10. Roadmap persistence

10.1. Command Center › **Roadmap**. Expected: products grouped by state (for example *Validated · 1* for HCG Terminal
      Unleashed, *Configuration required* for HCG Connect), each with an evidence sentence.

10.2. Open HCG News's profile › Roadmap. Expected: after step 6.4 the history shows *Connected* above
      *Ready to connect*, with times.

10.3. Respring, then reopen HCG News › Roadmap. Expected: the same history (it persists).

10.4. **Export to HCG LifeOS** (Settings › HCG Nexus › Command Center › Roadmap; it is not offered in the panel
      overlay). Expected:
      - a share sheet with `hcg-nexus-lifeos-import.json`;
      - after you save it, the row says *Nothing new to export* and *N already exported*.

## 11. Package Trust Center

11.1. HCG Ecosystem › Command Center › Package Trust Center. Expected: HCG Repo and HCG Repo Candidate are shown as
      **Unsigned** (HCG Repo has no signing key yet), with the index *Packages matches the SHA-256 and size in Release*.

11.2. Open HCG Nexus in the package list. Expected:
      - the authenticity, checksum and device-evidence rows are separate;
      - nothing says "safe".

11.3. *Trust This Key…*. Expected: *No key to trust yet*; nothing is stored.

11.4. Then Command Center › HCG Package Repository. Expected: *Last successful communication* is the Trust Center read.

## 12. Existing integrations (must be unchanged from 0.5.0)

12.1. **HCG Terminal / Terminal Unleashed:**
      - the product page shows the installed version and build;
      - *Open and screens* opens HCG Terminal Unleashed on Packages, Processes and Jailbreak Diagnostics (directly, or
        through Unleashed Tools with a one-tap note);
      - Nexus never runs a command.

12.2. **HCG Server** (standalone app only, if installed):
      - Settings › Connected Devices shows the real state (*Not paired*, or the paired server with *LOCAL DEVELOPMENT —
        not an HCG account* when applicable);
      - in Command Center, HCG Server is *Connected* only right after a successful signed sync.

      In the jailbreak package: *Not available* with the reason.

12.3. **HCG Halo** (if installed): the panel border switch still works. Afterwards, HCG Halo's profile shows *Last
      successful communication* "HCG Halo accepted a border change".

## 13. Memory and CPU consumption

In HCG Terminal Unleashed's shell:

```
ps -axo pid,rss,%cpu,%mem,comm | grep -E 'SpringBoard$'
```

`rss` is resident memory in KB. If `ps` is missing, install `adv-cmds` from your bootstrap's repository, or skip to
13.5.

13.1. **Baseline:** Nexus disabled (Settings switch off), wait 30 s, then record `rss` and `%cpu`.

13.2. **Enabled, panel closed:** turn Nexus on, wait 30 s, then record. Expected: `rss` within about +15 MB of the
      baseline, and `%cpu` back near the baseline (under 2 %) when idle.

13.3. **Panel open on Command Center**, idle 30 s, then record. Expected: `%cpu` settles under 5 % (with Reduce Motion
      on, under 2 %).

13.4. **After step 2.4** (20 opens) and a minute idle, record. Expected: `rss` no more than about 10 MB above 13.3. A
      steady climb on every open is a leak: record the values for each opening.

13.5. **Overnight (optional):** Settings › Battery after 24 h of normal use. Expected: SpringBoard's share is not
      noticeably higher than before installing.

## 14. Respring and reboot behavior

14.1. **Respring with Nexus enabled.** Expected: the handle reappears without opening Settings; favorites, expanded
      categories and roadmap history are kept.

14.2. **Reboot** (Dopamine is semi-untethered):
      - Expected: the phone boots to stock iOS, with no handle and no Nexus code running.
      - Re-jailbreak with Dopamine. Expected: after the userspace reboot, the handle is back and the settings are kept.

14.3. **Kill switch test:**
      - `touch /var/mobile/Library/Preferences/com.hakmicapitalgroup.hcgnexus.killswitch`, then respring.
        Expected: no handle; Settings › HCG Nexus shows *SpringBoard: Stopped* with the reason.
      - `rm` the file, then respring. Expected: the handle is back.

## 15. Rollback path (documented, use if anything fails)

From least to most invasive (docs/INSTALL-AND-RECOVERY.md):

1. **Turn it off:** Settings › HCG Nexus › Enable HCG Nexus → off. The effect is immediate, and workspaces are kept.
2. **Kill switch:** `touch /var/mobile/Library/Preferences/com.hakmicapitalgroup.hcgnexus.killswitch`, then respring.
   Nexus creates nothing at the next SpringBoard launch.
3. **Downgrade to an earlier approved beta:** Zebra › HCG Nexus › *Versions* (Sileo: the package's version list), or
   `sudo apt install com.hakmicapitalgroup.hcgnexus=0.3.3~beta1`. Then respring.
   - 0.5.0~beta1 and 0.4.0~beta1 are also on Candidate. 0.3.3~beta1 is the last version without the Ecosystem and
     Trust Center code.
   - Older versions ignore the preference keys 0.6.0 added (`roadmap`, `connectionLedger`, `favoriteProducts`,
     `expandedCategories`, `registryUpdate`, `systemTesterInventory`, `lifeosExported`), so settings and workspaces
     carry over.
4. **Restore your settings exactly:** `cp /var/mobile/Documents/hcgnexus-backup.plist
   /var/mobile/Library/Preferences/com.hakmicapitalgroup.hcgnexus.plist`, then respring.
5. **Uninstall:** Zebra › HCG Nexus › *Remove*, or `sudo dpkg -r com.hakmicapitalgroup.hcgnexus`, then respring.
   Settings stay in the plist above; delete it only to erase everything.
6. **SpringBoard crash loop:**
   - Reboot (the phone starts without tweaks).
   - Before re-jailbreaking, turn off tweak injection in Dopamine's settings if your version has it.
   - Re-jailbreak, then use step 2 or 5, and turn tweak injection back on.
   - ElleKit's safe mode is a further fallback.

None of these touch other HCG products, Sileo, Zebra or APT sources.

## Results (fill in and send back)

| # | Device A (13 Pro, 16.5) | Device B (11 Pro Max, 17.4) | Notes |
|---|---|---|---|
| 0.1 Installed before | | | |
| 1 Installation (1.1–1.5) | pass / fail | pass / fail | |
| 2 SpringBoard stability | | | |
| 3 Settings integration | | | |
| 4 Diagnostics (build, environment) | | | |
| 5 Standalone app (or *not installed*) | | | |
| 6 Command Center navigation (6.1–6.7) | | | |
| 7 Product search | | | |
| 8 Favorites | | | |
| 9 Expandable categories | | | |
| 10 Roadmap persistence | | | |
| 11 Package Trust Center | | | |
| 12.1 HCG Terminal | | | |
| 12.2 HCG Server | | | |
| 12.3 HCG Halo | | | |
| 13 SpringBoard rss / %cpu: baseline · enabled · panel open · after 20 opens | | | |
| 14 Respring / reboot / kill switch | | | |
| Rollback used? (which step) | | | |

Add screenshots of 6.1, 6.4, 10.1 and 11.1. A device result is recorded in HCG Repo only from this report; nothing is
marked tested before it.
