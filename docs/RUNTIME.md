# How the jailbreak tweak activates at runtime

This is what has to happen on the device for the edge handle to appear, and
how each step can be checked.

| # | Step | Where | How to check |
|---|---|---|---|
| 1 | The package installs `HCGNexus.dylib` and `HCGNexus.plist` (filter: SpringBoard only) under `[/var/jb]/Library/MobileSubstrate/DynamicLibraries` | `.deb` | `scripts/inspect-package.py` (file layout, filter) |
| 2 | After a **manual** respring, the injector (ElleKit on Dopamine) loads the dylib into SpringBoard | injector | Settings › HCG Nexus › Status: *SpringBoard: Running* (same build as installed). Diagnostics › *Injector* lists the injector libraries found in SpringBoard's loaded images |
| 3 | The dylib's constructor (`%ctor` in `Tweak/Tweak.x`) runs. It returns immediately outside SpringBoard; inside it waits for `UIApplicationDidFinishLaunchingNotification` | dylib | the inspector verifies an initializer section exists in every slice, plus the bootstrap class |
| 4 | `HCGSpringBoardBootstrap` starts. It honours the kill-switch file, requires iOS 14+ and `UIWindowScene`, registers Darwin observers, and reads preferences 1 s later. When it refuses to start it still writes a report, so Settings shows *Stopped* with the reason | SpringBoard | Diagnostics *Started by*: `launch notification` |
| 4b | If the dylib is loaded after SpringBoard finished launching, the notification never arrives. A one-shot fallback starts it 15 s after load (idempotent) | SpringBoard | *startedBy*: `late-load fallback` |
| 5 | Nexus ships **disabled**. Turning on *Enable HCG Nexus* in Settings writes the preference and posts a Darwin notification; SpringBoard then creates the model, the overlay window and the lock monitor | Settings → SpringBoard | Status › *Edge handle: Working* |
| 6 | The overlay window must belong to a `UIWindowScene` to be displayed (iOS 13+). If SpringBoard had no connected scene at creation time, it is attached as soon as one exists | SpringBoard | Diagnostics *overlayWindowScene*; Edge handle *Failed* if it has none |
| 7 | The handle shows only while unlocked and not on the lock screen or cover sheet | lock monitor | Status › *Lock detection*; Diagnostics *availability* |

## Runtime report (schema 2)

SpringBoard writes one dictionary, `runtimeStatus`, into
`com.hakmicapitalgroup.hcgnexus`. Writes run on a private serial queue (never
SpringBoard's main thread) and are skipped when nothing changed. Settings
posts the payload-free `com.hakmicapitalgroup.hcgnexus/status-request` Darwin
notification when it appears; the only thing SpringBoard does in response is
rewrite this report. There is no other channel between Settings and
SpringBoard.

| Key | Meaning |
|---|---|
| `schema`, `version`, `buildID`, `buildConfig` | which build is running; Settings compares `buildID` with its own to decide *Running* vs *Respring required* |
| `state`, `reason` | `active`, `disabled` (switch off) or `stopped` (kill switch, unsupported iOS, startup exception) |
| `startedBy`, `injector` | launch path, and injector images found in SpringBoard (evidence, not marker files) |
| `deviceModel`, `osVersion`, `osBuild` | `hw.machine`, iOS version, `kern.osversion` |
| `features` | `edgeHandle`, `appLaunching`, `lockDetection`, `orientation`, each `{state, detail}` with state `ok`, `disabled`, `unavailable`, `unsupported`, `failed` or `unknown` |
| `overlay` | window, scene, level, frame, panel state and counters |
| `lastError` | last caught exception while applying settings (Nexus fails closed: disabled) |

**Copy Diagnostics Report** in Settings combines this with the Settings
bundle's own facts, redacts e-mail addresses, tokens, UUIDs/UDIDs and long
secrets, and puts the text on the clipboard. Nothing is sent anywhere.

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
