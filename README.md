# HCG Nexus

A configurable cyan edge handle that opens an HCG command panel over the
current app on a jailbroken iPhone. The panel holds searchable shortcuts,
workspaces, recent actions, HCG integration status and settings. Visually it
uses obsidian surfaces, brushed-chrome hairlines and restrained cyan light.

> **Status: milestone 1, development build.** Target confirmed:
> **iPhone 13 Pro · iOS 16.5 · Dopamine (rootless) · ElleKit · Sileo**
> (see [`docs/ENVIRONMENT.md`](docs/ENVIRONMENT.md)). The Core logic is tested and
> the code compiles and packages, but the installable arm64e package must be built
> with Xcode (GitHub Actions *Build package* workflow or a Mac), and nothing
> has run on the device yet. HCG Nexus ships **disabled**.

## Repository structure

```
Makefile, control, HCGNexus.plist   Theos tweak (filter: com.apple.springboard only)
Tweak/Tweak.x                       %ctor only; installs no hooks
Sources/
  Core/                Foundation-only and host-tested: actions, workspaces + presets,
                       store, settings, recents, search, integrations, geometry,
                       panel state machine, overlay policy, overlay coordinator
  Panel/               UIKit, independent of SpringBoard: theme, edge handle, overlay
                       controller, panel home, workspace manager/detail, shortcut
                       editor, settings, action runner, model façade
  Platform/SpringBoard/  bootstrap, CFPreferences store + Darwin notifier,
                       LaunchServices launcher, lock monitor, overlay window
  Platform/Preview/    simulated launcher, UserDefaults store, embedded environment
Prefs/                 Settings › HCG Nexus (PreferenceLoader bundle; recovery path)
PreviewHarness/        standalone app hosting the real panel; separate package
Tests/Host/            host test runner (clang + GNUstep) for Sources/Core
scripts/check.sh       lint + safety rules + host tests (+ package build/inspection)
scripts/inspect-package.py   .deb layout, maintainer-script and arm64e ABI inspection
.github/workflows/build-package.yml   manual macOS/Xcode package build (new arm64e ABI)
Assets/                supplied AppIcon.appiconset (+ how it is used)
docs/                  ENVIRONMENT, INTEGRATIONS, INSTALL-AND-RECOVERY, VALIDATION
```

## Implemented (milestone 1)

* **Edge handle.** Right or left side, adjustable position and visibility.
  The touch target is 30×96 pt around a thin sliver. It is kept clear of the
  status bar and Notification/Control Centre pull zones and of the home
  indicator, and optionally above the keyboard area.
* **Opening and closing.** Tap or swipe inward to open. Close with the close
  button, an outside tap or the VoiceOver escape gesture. A state machine
  coalesces rapid taps. Touches outside the handle pass through to the app.
* **System layout.** Safe areas are handled, and the panel moves above the
  SpringBoard keyboard while typing. In SpringBoard the canvas rotates itself
  using `activeInterfaceOrientation`, verified at runtime.
* **Lock behaviour.** The overlay hides on lock, screen off and the cover sheet,
  even after Face ID unlock on the lock screen, and fails closed when the lock
  state is unknown. The window is never "secure", so it cannot draw over the
  lock screen. Nothing bypasses authentication.
* **Workspaces.** Create (from a preset or empty), rename, reorder and delete,
  stored locally with no login required. Presets: Command, Developer, Studio and
  Infrastructure. They only organise shortcuts.
* **Shortcuts.** Apps by bundle ID, links by URL, and HCG integrations, with
  validation and search across all workspaces.
* **Launch adapter.** Uses `LSApplicationWorkspace`, verified at runtime, off
  the main thread. Missing apps, links nothing can open, unconnected
  integrations and an unavailable launcher each give an actionable error with a
  shortcut to the fix.
* **HCG integrations.**
  * Terminal and News open their apps once enabled.
  * Server and Executable Maker show "Not connected": they have no
    phone-reachable contract yet.
  * No credentials are stored and no schemes are invented.
  * See [`docs/INTEGRATIONS.md`](docs/INTEGRATIONS.md).
* **Settings.** Available in the panel and in the Settings app:
  * enable switch
  * handle side, position, visibility and keyboard zone
  * animations and haptics
  * integrations
  * workspace management
  * clear recents
  * reset (keeps the enabled state and workspaces)
  * diagnostics and version
* **Disabled means off.** When disabled, the panel closes, the window is hidden
  and nothing intercepts touches. Workspaces are kept. While disabled since
  launch, SpringBoard only reads preferences and listens for two Darwin
  notifications: no window, panel or lock monitor is created.
* **Accessibility.** Dynamic Type, VoiceOver labels and hints, a modal panel,
  custom actions for rename/delete, Reduce Motion (fade instead of slide),
  Reduce Transparency (solid surfaces) and Increase Contrast.
* **Recovery.** Settings entry, kill-switch file, package-manager uninstall.
  No automatic respring anywhere.

## Build, install, recover

See [`docs/INSTALL-AND-RECOVERY.md`](docs/INSTALL-AND-RECOVERY.md). Short version:

```sh
scripts/check.sh                                  # lint + host tests
THEOS=~/theos HCG_ENV=rootless HCG_REQUIRE_NEW_ABI=1 scripts/check.sh   # + build & strict inspect (Mac)
make package FINALPACKAGE=1                       # rootless by default (Xcode toolchain for the device)
```

Install the `.deb` with your package manager, respring yourself, then enable it
in **Settings › HCG Nexus**. To disable, turn that switch off. To remove it,
uninstall **HCG Nexus** in the package manager.

## Known limitations

* **arm64e ABI.** Packages built on Linux have an old-ABI arm64e slice and must
  not be installed on the iPhone 13 Pro. Use the Xcode-built package from the
  *Build package* workflow or a Mac.
* **Unverified SpringBoard assumptions:**
  * window level `999`
  * orientation source and rotation direction
  * keyboard focus for text fields inside SpringBoard
  * `LSApplicationWorkspace` selectors
  * cover-sheet selectors
* **Keyboard in other apps.** SpringBoard cannot see another app's keyboard
  frame, so "Keep above keyboard" uses a fixed upper zone instead.
* **Notification Centre.** If Notification Centre is pulled down while unlocked,
  it is detected when the handle is next touched, not immediately (no hook is
  installed for it).
* **Preview harness.** Never executed here (no Simulator), and its launches are
  simulated.
* **Integrations.** No live status, metrics or deep links, because no contracts
  exist for them yet.
* **Concurrent edits.** Settings.app and the panel editing workspaces at the
  same moment resolve as last writer wins.

## Prioritised TODO

1. ~~Confirm the environment~~ — done: iPhone 13 Pro, iOS 16.5, Dopamine
   rootless, ElleKit, Sileo. Build defaults updated.
2. **Run the *Build package* workflow** (or build on a Mac) to produce the
   new-ABI arm64e rootless `.deb`, which must pass `--require-new-arm64e-abi`.
3. **Run the device checklist** in [`docs/VALIDATION.md`](docs/VALIDATION.md).
   Adjust the window level, orientation mapping and text-input focus based on
   what is observed.
4. **Run the preview harness** on Simulator or device, then add an XcodeGen or
   Xcode project that uses `Assets/AppIcon.appiconset`.
5. **Add a cover-sheet presentation hook** for the confirmed iOS version,
   selector-verified, so the handle hides as soon as Notification Centre is
   pulled down.
6. **Add Terminal/News deep links** once those apps publish URL schemes.
7. **Add read-only HCG Server and Executable Maker status** via HCG
   Connect-authorised endpoints once they exist. Fetch on demand, off the main
   thread, with timeouts.
8. **Polish the shortcut editor:** an installed-app picker instead of typing
   bundle IDs, plus icon choice.
9. **Add localisation**, plus UI tests in the preview harness.
