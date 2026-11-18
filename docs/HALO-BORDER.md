# HCG Halo border integration (HCG Nexus 0.3.2~beta1, interface 1, schema 1, switch contract 1)

> **Version note.** HCG Nexus **0.3.1~beta1** is the combined release: the 0.3.0~beta1 redesign line, plus Command
> Mode, plus this border interface. It replaces both earlier candidates:
> - 0.2.2~beta1: the interface on the 0.2.1 code, superseded and never published;
> - 0.3.0~beta1: the redesign without the interface, run 44213585148, never published.
>
> Nexus releases from 0.3.1~beta1 onward keep the interface, so no upgrade removes it.

HCG Halo (`com.hakmicapitalgroup.halo`, a separate package) can draw its animated border around the live HCG
Nexus panel. Nexus provides **where and when**: a declarative definition file and a small runtime interface.
Halo provides **how it looks**: the renderer, colours, glow, modes, presets, animation and its settings.

- Nexus draws nothing itself, contains no Halo code and never requires Halo. Without Halo the border host is one
  empty, non-interactive view and the events are posted to nobody.
- Halo never bundles, copies or downloads this definition. It reads the file that the installed Nexus package
  put on the phone. Live geometry always comes from the running panel, never from the file.
- No login, network access, account tokens or cross-process messages. Everything happens inside SpringBoard,
  where both tweaks are loaded.

## Compatibility and install order

| HCG Nexus | HCG Halo | Result |
|---|---|---|
| 0.3.1~beta1 (and 0.2.2~beta1, unpublished), or any later build that contains interface 1 and `HaloBorder.plist` | 0.2.0~beta1 or later | Panel border available (Halo › Border Target) |
| 0.3.0~beta1, 0.2.1~beta1 or earlier, or any build without the border interface | any | Halo shows *Requires compatible HCG Nexus*; its screen-edge border works as before |
| 0.3.1~beta1 | absent, or 0.1.0~beta1 | Normal Nexus appearance; Settings › HCG Nexus › Appearance › Halo border explains what is needed |

Install order does not matter, and neither package depends on the other. Respring once after installing or
updating either package, because both are loaded only at SpringBoard launch. If Nexus is updated without a
respring, Halo sees that the installed definition (new version) differs from the running Nexus (old version).
It keeps the panel border off and asks for a respring.

## The installed resource

```
<jbroot>/Library/PreferenceBundles/HCGNexusPrefs.bundle/HaloBorder.plist
```

On a rootless jailbreak `<jbroot>` is `/var/jb`, so the path is
`/var/jb/Library/PreferenceBundles/HCGNexusPrefs.bundle/HaloBorder.plist`. The source is
`Prefs/Resources/HaloBorder.plist`, and Theos copies it into the Settings bundle. `scripts/inspect-package.py`
checks that the packaged copy is present and valid, and that its version equals the package version.

How it is located (no install prefix is assumed):

1. **In SpringBoard:** `+[HCGNexusBorderInterface borderDefinitionPath]`. It takes the path of Nexus's own
   loaded image via `dladdr`:
   - `…/Library/MobileSubstrate/DynamicLibraries/HCGNexus.dylib`;
   - `…/usr/lib/TweakInject/HCGNexus.dylib` (Dopamine may report either);
   - or the Settings bundle binary.

   It strips that suffix and appends the path above. Preview builds that carry the file in their own app
   bundle are found last.
2. **In Settings:** HCG Halo's Settings bundle looks for the sibling bundle `../HCGNexusPrefs.bundle/HaloBorder.plist`.

### Schema 1 (declarative data only; strict)

| Key | Type | Value / range |
|---|---|---|
| `schema` | string | `com.hakmicapitalgroup.hcgnexus.halo-border` |
| `schemaVersion` | integer | `1` |
| `interfaceVersion` | integer | `1` |
| `interfaceClass` | string | `HCGNexusBorderInterface` |
| `nexusVersion` | string | the package version, e.g. `0.3.1~beta1` (must equal `control`) |
| `shape` | dict | `kind` = `rounded-rect`; `cornerRadius` 0…64 pt; `cornerCurve` = `continuous` or `circular` |
| `anchors` | dict | `host` = `panel`; `outset` 0…12 pt (gap from the panel edge to the light); `glowMargin` 8…64 pt; `clipInterior` bool |
| `capabilities` | array | subset of `live-geometry`, `open-close-events`, `presentation-progress`, `workspace-events`, `orientation`, `keyboard-resize` |
| `style` | dict, optional | `defaultPreset` (a preset identifier) |

Unknown keys, wrong types, out-of-range values, other schema or interface versions, files larger than 16 KB and
non-regular files are all rejected. Both sides apply the same rules: `scripts/check_halo_border.py` here (it has a
self-test) and `HaloNexusDefinition` in Halo. A rejected file disables only the Nexus target, and Halo shows the
reason.

## Runtime interface, version 1

`Sources/Panel/HCGNexusBorderInterface.h`. Halo finds it with `NSClassFromString(@"HCGNexusBorderInterface")`
(no link-time dependency) and checks every selector before it sends it.

| Member | Meaning |
|---|---|
| `+interfaceVersion` | `1` |
| `+activeInterface` | the live panel's interface, or nil (Nexus not enabled since the last respring) |
| `+borderDefinitionPath` | the installed resource, located as above |
| `nexusVersion` | running Nexus version (compared with the file's `nexusVersion`) |
| `borderHostView` | non-interactive view inside the panel. It has the panel's bounds, sits above the content, never clips, never hit-tests and is hidden from accessibility |
| `panelCornerRadius` | live corner radius (22 pt) |
| `panelState` | `closed`, `opening`, `open` or `closing` |
| `transitionGeneration`, `transitionDuration`, `reducedMotionTransition` | the current transition (crossfade = Reduce Motion) |
| `presentationProgress` | 0…1, read from the panel's presentation layer, so it follows reversals |

Events are posted as `HCGNexusBorderEventNotification` (`com.hakmicapitalgroup.hcgnexus.border-event`) on
the main thread, in-process only. The object is the active interface. `userInfo` holds `event`,
`generation`, `duration` (seconds) and `interfaceVersion`. Halo ignores anything that does not come from the
interface it is attached to, or that does not have exactly these types and values.

| Event | When |
|---|---|
| `installed` | the panel and its border host exist (`setActiveInterface:`) |
| `will-open` | an opening transition starts, before its animation |
| `did-open` | that opening finished (not sent for a superseded generation) |
| `will-close` | a closing transition starts; this also reverses an opening in progress |
| `did-close` | the panel is hidden (after a close, a lock or a disable) |
| `geometry` | the panel's size changed (rotation, keyboard, handle side) |
| `workspace-changed` | the active workspace changed while the panel is shown |
| `removed` | the interface is going away: detach everything |

**Command Mode** fades the panel to transparent while it is shown, so the border (inside the panel) fades with it
and returns when Command Mode closes. The panel stays *open* throughout, so no events are sent.

Because Halo's view lives inside the border host, it inherits the panel's real position, slide transform,
alpha, rotation and resizing at no cost. It disappears with the panel and cannot be orphaned. The events
add the opening trace, the close behaviour and the workspace pulse, and keep the glow sized correctly.

## Use HCG Halo border (0.3.2~beta1)

The switch sits in Settings › HCG Nexus › Appearance and in the panel's own Settings (*HCG Halo border*).
Nexus never writes HCG Halo's settings and contains none of its rendering code:

- **Switching:** Nexus calls HCG Halo's `HaloNexusControl` (`+setNexusBorderEnabled:error:`, contract
  `HCGHaloNexusControl` = 1 in `HCGHaloPrefs.bundle`'s Info.plist; HCG Halo 0.2.1~beta1 or later).
  - HCG Halo decides how its own settings change, and never turns its screen-edge light on: HCG Halo off → panel
    only; screen edge on → both; off → panel removed, screen edge untouched.
  - It is refused while HCG Halo's kill switch or launch guard is active.
  - With HCG Halo 0.2.0~beta1, which has no switch, Nexus shows the state and points to HCG Halo › Border Target.
- **States** (`HCGHaloBorderStatus`, host-tested):

| State | When |
|---|---|
| Not installed | no HCG Halo Settings bundle or dylib |
| Incompatible | HCG Halo without the Nexus border (0.1.x); Nexus's `HaloBorder.plist` missing or for another version (respring after updating); HCG Halo reports it cannot attach (`nexusState` = unavailable, with its reason); HCG Halo reports an unsupported iOS |
| Disabled | HCG Halo's panel border is off (master off or target *Screen Edge*), or HCG Halo is stopped (kill switch, launch guard, fault) |
| Ready | the panel border is on in HCG Halo; it is drawn while the panel is open |
| Active | Nexus itself sees a view attached to the open panel's border host (HCG Halo is drawing) |

- **Active comes from Nexus, not from a guess.** In the panel it is measured live. Settings › HCG Nexus reads it
  from the report SpringBoard writes (`haloBorderAttached`, `panelState`), so it shows *Ready* while the panel is
  closed.
- **Without HCG Halo**, Nexus keeps its own outline. The border host is non-interactive and empty.

## Settings entry

Settings › HCG Nexus › **Appearance › Halo border**:

- It reads HCG Halo's `Info.plist` (`HCGHaloNexusIntegration` = 1) from the sibling
  `HCGHaloPrefs.bundle`.
- It loads that bundle and pushes Halo's `HaloNexusBorderController`, the same page as in HCG Halo's
  own Settings.
- If Halo is missing, too old or incompatible, it shows an explanation instead.
- No Halo code is loaded unless this row is tapped.

## Combinations to test

| Combination | Expected |
|---|---|
| Nexus only | Normal Nexus appearance. The Appearance footer says HCG Halo 0.2.0~beta1+ is needed for a border |
| Halo only | Screen-edge border as before. Halo's Nexus target shows *Requires compatible HCG Nexus* |
| Both, target Screen Edge (default) | Nothing changes around the panel |
| Both, target Nexus Panel or Both | Border around the panel only while it is shown. Trace on open, fade on close, pulse on workspace change |
| Both, Halo disabled | Border removed at once; the panel is unaffected |
| Both, Nexus disabled | Panel and border gone; screen edge (if targeted) unaffected |
| Nexus updated without respring | Panel border off with *respring* explanation; after respring it is back |
| Nexus 0.2.1~beta1 + Halo 0.2.0~beta1 | Halo: *Requires compatible HCG Nexus*; screen edge unaffected |

**Status:**
- Build checks: `scripts/check.sh`, the schema self-test and the package inspector.
- Preview evidence: an iOS Simulator app built from this repository's real panel code and real definition,
  plus HCG Halo's real link and renderer (HCG-Jailbreak-Research, workflow *HCG Halo × Nexus preview*). It
  is preview only.
- **Device testing of every row above is still pending.**

### Device steps (manual; nothing is installed automatically)

1. Install HCG Nexus 0.3.1~beta1 and HCG Halo 0.2.0~beta1 from HCG Repo Candidate, in either order. Respring.
2. In Settings › HCG Nexus, turn on Enable. Then go to Appearance › Halo border. The page should show
   *HCG Nexus 0.3.1~beta1 · compatible*.
3. In HCG Halo, turn on Enable HCG Halo and set the Border Target to **HCG Nexus Panel**. Open and close the
   panel. Drag the handle and cancel. Switch workspaces. Rotate. Type in a panel text field (keyboard). Lock
   the phone with the panel open.
4. Turn Halo off with the panel open (the border goes at once). Then turn Nexus off (no orphaned border).
5. Copy both diagnostics reports.

Recovery is unchanged from [INSTALL-AND-RECOVERY.md](INSTALL-AND-RECOVERY.md). HCG Halo has its own kill switch:
`/var/mobile/Library/Preferences/com.hakmicapitalgroup.halo.disabled`.

## Versioning rules

- Adding an optional key or capability that older Halo versions may ignore requires a new `schemaVersion`.
  Halo's validator is strict, so today any new key is a schema change.
- Changing a member, event or `userInfo` type bumps `HCG_NEXUS_BORDER_INTERFACE_VERSION` and `interfaceVersion`
  in the file. Halo refuses versions it does not know and explains why.
