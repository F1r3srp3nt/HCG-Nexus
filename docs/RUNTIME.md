# How the jailbreak tweak activates at runtime

This is what has to happen on the device for the edge handle to appear, and
how each step can be checked.

| # | Step | Where | How to check |
|---|---|---|---|
| 1 | The package installs `HCGNexus.dylib` and `HCGNexus.plist` (filter: SpringBoard only) under `[/var/jb]/Library/MobileSubstrate/DynamicLibraries` | `.deb` | `scripts/inspect-package.py` (file layout, filter) |
| 2 | After a **manual** respring, the injector (ElleKit on Dopamine) loads the dylib into SpringBoard | injector | Settings › HCG Nexus › Diagnostics shows *SpringBoard build* (no report means the dylib was not loaded) |
| 3 | The dylib's constructor (`%ctor` in `Tweak/Tweak.x`) runs. It returns immediately outside SpringBoard; inside it waits for `UIApplicationDidFinishLaunchingNotification` | dylib | the inspector verifies an initializer section exists in every slice, plus the bootstrap class |
| 4 | `HCGSpringBoardBootstrap` starts. It honours the kill-switch file, requires iOS 14+ and `UIWindowScene`, registers Darwin observers, and reads preferences 1 s later | SpringBoard | Diagnostics *startedBy*: `launch notification` |
| 4b | If the dylib is loaded after SpringBoard finished launching, the notification never arrives. A one-shot fallback starts it 15 s after load (idempotent) | SpringBoard | *startedBy*: `late-load fallback` |
| 5 | Nexus ships **disabled**. Turning on *Enable HCG Nexus* in Settings writes the preference and posts a Darwin notification; SpringBoard then creates the model, the overlay window and the lock monitor | Settings → SpringBoard | *Activated: Yes* |
| 6 | The overlay window must belong to a `UIWindowScene` to be displayed (iOS 13+). If SpringBoard had no connected scene at creation time, it is attached as soon as one exists | SpringBoard | *overlayWindowScene*: `attached` |
| 7 | The handle shows only while unlocked and not on the lock screen or cover sheet | lock monitor | *availability*, *lockSources* |

## Fixed in this change

* **Late load.** Startup relied only on the launch notification. A dylib
  loaded into an already-running SpringBoard would never have started. Fix:
  the delayed, idempotent fallback (4b).
* **Window scene.** A window created before SpringBoard connected its scene
  had no scene, so it could never be displayed. Fix: attach later (6), and
  report it.

## Still to confirm on the device

These cannot be observed without the phone:
* the window level (`999`) relative to apps and system UI;
* the orientation source;
* keyboard focus for panel text fields;
* the LaunchServices selectors on iOS 16.5.

After enabling, Settings › HCG Nexus › Diagnostics shows every value above.
Please share it when reporting device results.
