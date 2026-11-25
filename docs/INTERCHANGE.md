# HCG Interchange Protocol (HIP), version 1

HIP is how HCG Nexus describes, discovers and opens the other HCG products on a jailbroken iPhone. It is small on
purpose: a registry compiled into Nexus, a read-only scan, navigation-only routes, and an optional declaration a
product can ship to *narrow* what Nexus offers. Code: `Sources/Core/HCGInterchange.{h,m}` (host-tested in
`Tests/Host/EcosystemTests.m`), `Sources/Panel/HCGEcosystemScanner.m` (device facts),
`Sources/Panel/HCGProductsViewController.m` / `HCGProductDetailViewController.m` (dashboard).

## Rules

1. **Nexus is a viewer and navigator, not an authority.** HCG Connect stays the only identity system. HIP carries
   no account, token, password, SSH key or session, and Nexus passes none between apps.
2. **Read-only discovery by default.** Facts come from files and records the products already publish (below).
   Reading never writes, posts a notification, starts anything or contacts a server.
3. **Routes only navigate.** Every route target is fixed text in the registry. Nexus never builds a link from data
   it read. App links are the products' own navigation contracts, which never run commands, start sessions or
   change settings. Before opening, Nexus re-validates each link with the same exact-text rules saved shortcuts use.
4. **Writes only through product-owned APIs, after a tap in Nexus.** Today: HCG Halo's `HaloNexusControl` border
   switch, which never turns on the screen-edge light. Package changes are never offered: Nexus opens Zebra or Sileo,
   which ask first.
5. **A declaration can only narrow.** A product may declare itself (below). A declaration can switch on routes the
   registry marks *needs a declaration* and can switch capabilities **off**. It can never add a route, URL or
   capability. This is HCG Device Link's rule: *an advertisement can cause a refusal, never an allow*. It is not
   proof of authorization.
6. **Independence.** Every product works without Nexus; Nexus works without every product. A missing or old
   product shows a truthful state, never an error loop.

## Registry (inspected 24 Nov 2026)

| HIP ID | Product | Kind | Package / bundle | Links | Needs | Nexus adapter |
|---|---|---|---|---|---|---|
| `nexus` | HCG Nexus | hub | `com.hakmicapitalgroup.hcgnexus` | — | — | this dashboard |
| `terminal-unleashed` | HCG Terminal Unleashed | app | `com.hakmicapitalgroup.hcgterminal.unleashed` (same bundle) | `hcgterminal-unleashed://open/<screen>` | iOS 17.0 | detect, version + build, open, 8 screens; packages / processes / jailbreak diagnostics directly when declared, else through Unleashed Tools |
| `terminal` | HCG Terminal | app | bundle `com.hakmicapitalgroup.hcgterminal` | `hcgterminal://open/<screen>` | iOS 17.0 | detect, open, 7 screens |
| `sentinel` | HCG Sentinel | app | `com.hakmicapitalgroup.hcgsentinel`, bundle `com.hcg.sentinel` | `hcgsentinel://open/<section>` | iOS 15.0 | detect, open, Security Lab and 8 more sections |
| `halo` | HCG Halo | tweak | `com.hakmicapitalgroup.halo` | — | iOS 15.0 | status, settings (read-only), border switch (`HaloNexusControl` v1), open Settings |
| `vortex` | HCG Vortex | tweak | `com.hakmicapitalgroup.vortex` | — | iOS 15.0 | status, transition settings (read-only), open Settings |
| `portal` | HCG Portal | tweak | `com.hakmicapitalgroup.portal` | — | iOS 15.0 | status, settings (read-only), open Settings; Portal opens Nexus (below) |
| `animation-center` | HCG Animation Center | tweak | `com.hakmicapitalgroup.animationcenter` | — | iOS 15.0 | status, settings (read-only), open Settings |
| `news` | HCG News | app | bundle `com.hakmicapitalgroup.hcgnews` | — | — | detect, open |
| `repo` | HCG Repo | repository | — | — | — | installed versions, Candidate updates, package-manager links |
| `agent-runtime` | HCG Agent Runtime | service | — | — | — | **unavailable**: macOS-only, loopback-only, refuses Nexus as a task source; no iOS build |
| `server` | HCG Server | service | — | — | — | standalone app: the **real** HCG Device Link state (*Connected* only after a successful signed sync in the last 2 min; else *Not connected* / *Unreachable* with the real reason; local development labelled); other builds: **not available** |
| `connect` | HCG Connect | identity | — | — | — | **not available**: no sign-in client issued for Nexus |
| `executable-maker` | HCG Executable Maker | service | — | — | — | **not available**: desktop app, no phone interface |

Sources: HCG-Terminal `HCGTerminalKit/Sources/TerminalUI/Model/HCGEcosystem.swift` (`TerminalDeepLink`, since
`871a8ac`, in Unleashed 0.2.0~rc1 and ~rc2); HCG-Sentinel `SentinelCore/.../Operations/DeepLink.swift`;
HCG-Jailbreak-Research `HCGHalo` (`1e232ab`), `HCGVortex` (`945a701`), `HCGPortal` (`8763365`), `HCGAnimationCenter`
(`2d642bd`); Agent-Runtime `claude/brave-rubin-7vwtg1`; HCG-Server `claude/devicelink-testdevice`; HCG--Connect
`claude/hcg-connect-ios-app-8f1ua8`; HCG Repo `296ea31`.

## Capability states

`available` (in the shipped code), `verified` (seen working on a physical device, with evidence), `unavailable`
(not here: not installed, iOS too old, not declared), `disabled` (switched off in the product) are HCG Device
Link's advertisement states. HIP adds `planned` (designed or documented only). Only four capabilities are
`verified` today: HCG Terminal Unleashed 0.2.0~rc2's local rootless shell, installed-package information, file
browsing and jailbreak diagnostics, which the owner saw on an iPhone 11 Pro Max (iOS 17.4, Dopamine).

Permissions: `none` (view or navigate), `approval in product` (the product asks; Nexus never acts for it),
`product-owned switch` (a Nexus switch calls the product's API), `not offered`.

## Facts Nexus reads (jailbreak package; SpringBoard)

| Fact | Source |
|---|---|
| Installed HCG packages and versions | `<jbroot>/var/lib/dpkg/status` |
| Versions HCG Repo offers | HCG Repo package lists your package manager already downloaded: `<jbroot>/var/lib/apt/lists/repo.hakmicapitalgroup.com_*_Packages`, Zebra's `lists` folder. As of that manager's last refresh; Nexus never refreshes. |
| Apps, versions, builds, URL schemes, declaration | LaunchServices (`LSApplicationProxy`), each app's `Info.plist` |
| Tweak Settings page installed | `<jbroot>/Library/PreferenceBundles/<bundle>/Info.plist` |
| Tweak settings shown read-only | the registry's readout keys in the product's own preference domain |
| Tweak health | the product's own status record (`com.hakmicapitalgroup.<product>.status`) |
| Package manager | Zebra (`xyz.willy.Zebra`), Sileo (`org.coolstar.SileoStore`, `org.coolstar.SileoNightly`) |

The standalone app cannot see installed products (iOS sandbox). It shows *Unable to check* and offers a product's
links only when `canOpenURL` succeeds for its scheme. The preview harness uses a labelled simulation.

## Declaring a product (optional)

An app's `Info.plist`, or a tweak's Settings-bundle `Info.plist`, may contain:

```xml
<key>HCGInterchange</key>
<dict>
    <key>protocol</key><integer>1</integer>
    <key>product</key><string>terminal-unleashed</string>
    <key>routes</key>
    <array>
        <string>jailbreak-diagnostics</string>
        <string>packages</string>
        <string>processes</string>
    </array>
    <!-- optional: listing capabilities switches every unlisted one off -->
</dict>
```

Nexus ignores the whole declaration if `protocol` is not 1 or `product` is not the declaring product's HIP ID. It
ignores and reports unknown routes. Listed capabilities can only make unlisted ones unavailable.

## Opening Nexus from other HCG products

Navigation only. Nexus opens its panel at the HCG Ecosystem dashboard, or at one product's page. It does this only
while the iPhone is unlocked (waiting up to 3 s), while *Enable HCG Nexus* and *Let HCG Apps Open Nexus* are on,
and at most once every 2 s. Each opening is recorded in the dashboard's activity list.

* **HCG apps (another process):** post a Darwin notification with no payload:
  `com.hakmicapitalgroup.hcgnexus/open/ecosystem`, or
  `com.hakmicapitalgroup.hcgnexus/open/product/<HIP ID>` (for example `…/open/product/terminal-unleashed`).
  `CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), name, NULL, NULL, true)` is
  public API and works from a sandboxed app. The name is the whole request, and nothing in it can carry data.
* **HCG Portal (in SpringBoard):** `HCGNexusPortalInterface` version 1, exactly as HCG Portal already calls it
  (`+interfaceVersion`, `+activeInterface`, `-canOpenPanel`, `-openPanelFromSource:completion:`; the completion is
  called once on the main thread). `Sources/Panel/HCGNexusPortalInterface.h`.

## Not done (truthfully)

* HCG Terminal 0.2.0~rc2 has no direct link to Jailbreak Diagnostics, Installed Packages or Processes. Nexus opens
  Unleashed Tools, one tap away, and says so. The HCG-Terminal branch `claude/nexus-interchange` adds the three
  routes and the declaration above, plus an *Open HCG Nexus* button that uses the Darwin request. That change is not
  in an installable Terminal build yet.
* No tweak defines a Settings deep link. Nexus opens the Settings app rather than guessing `prefs:root=`, the same
  choice HCG Portal made.
* HCG Sentinel publishes no status snapshot, so Nexus shows no Sentinel activity. HCG Sentinel has no
  "device health" screen; Nexus's own device overview covers battery, storage and network.
* Agent Runtime and Connect sign-in are prepared adapters only. HCG Server is live in the standalone app only: its
  card in *Your computers* takes its state from Connected Devices (`HCGAppApplyLinkSnapshot`,
  `HCGHIPFacts.serviceLinkState`). It never reads the server itself and never creates a device key; until Connected
  Devices has been opened it says *Not connected*.
* None of this has been tried on a phone yet: `DEVICE-CHECKLIST.md` rows 24–31.
