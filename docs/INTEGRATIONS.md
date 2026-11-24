# HCG integration adapters

Rules:
* Use only contracts that exist in the sibling repositories.
* Never invent URL schemes, endpoints, devices or metrics.
* Unconfigured integrations show **"Not connected"**.
* HCG Connect and ERP stay the authority for authenticated ecosystem access.
* Nexus stores no HCG credentials, with one exception. In the standalone app,
  Connected Devices (HCG Device Link) keeps its own HCG Connect sign-in in the
  app's Keychain. See [`CONNECTED_DEVICES.md`](CONNECTED_DEVICES.md).

Sources inspected on 2026-11-12, at the default branches as shallow clones:
`F1r3srp3nt/HCG-Terminal`, `F1r3srp3nt/HCG-Server`, `F1r3srp3nt/HCG-News`,
`F1r3srp3nt/HCG-Executable-Maker`.

> **0.4.0~beta1:** the product layer is now the HCG Interchange Protocol (docs/INTERCHANGE.md). The HCG Terminal
> notes below about a saved-connection handoff describe 0.3.2–0.3.3 and are superseded: HCG Terminal's shipped
> contract is `<scheme>://open/<screen>`.

## What exists

| Integration | Platform | Contract usable from an iPhone | Nexus behaviour |
|---|---|---|---|
| **HCG Terminal** | SwiftUI iOS app; standard `com.hakmicapitalgroup.hcgterminal`, Unleashed `com.hakmicapitalgroup.hcgterminal.unleashed` (0.1.0) | 0.1.0 declares no URL scheme. Builds with the Nexus handoff (HCG-Terminal `docs/NEXUS-HANDOFF.md`) declare `hcgterminal` / `hcgterminal-unleashed` and `HCGNexusHandoff` = 1, with two routes: `…://open` and `…://connection?id=<UUID>` (shows that saved connection; the user taps Connect). | HCG Products shows four separate facts: **Installed** (with the version read from the app), **Launch** (SpringBoard bundle launch, or the app's own link in the standalone app), **Integration** (handoff declared by the installed build), **Session** (never shared, so never "Connected"). *Open HCG Terminal* always works when installed; *Open Saved Connection…* appears only with the handoff and accepts only a link copied from HCG Terminal. Command Mode shows *Launch available*, not *Connected*. Nothing runs a command. |
| **HCG News** | SwiftUI iOS app | Bundle ID `com.hakmicapitalgroup.hcgnews`. Its only URL use is an OAuth callback through `ASWebAuthenticationSession`, which is not a public scheme. The content API is a proposal and not deployed (`docs/HCG-NEWS-CONTENT-API-PROPOSAL.md`). | "Not connected" until switched on in settings. Then it opens the app. No headlines are shown. |
| **HCG Server** | Go agent and macOS app | Admin API on `127.0.0.1:7600`, Mac loopback only. It requires a local admin token and rejects non-loopback `Host` headers. `GET /healthz` exists (`internal/agent/admin.go:493`). The peer API uses mutual TLS with pinned fingerprints. The HCG Connect module is a stub that reports `not-configured` (`internal/hcgconnect/hcgconnect.go:54`). | Not offered as a panel integration (since 0.2.0): a phone cannot reach the loopback API, so the row could only say "Not connected". Nexus does not copy or store the admin token. **Standalone app:** Settings › Connected Devices pairs with HCG Server through **HCG Device Link** (`/peer/v1/link`, HCG Connect sign-in, owner approval). See [`CONNECTED_DEVICES.md`](CONNECTED_DEVICES.md). |
| **HCG Sentinel** | SwiftUI iOS app | Bundle ID `com.hcg.sentinel` (`HCGSentinel.xcodeproj`). URL scheme `hcgsentinel` (`HCGSentinel/Resources/Info.plist`), handled by `DeepLink.target(from:)` (`SentinelCore/Operations/DeepLink.swift`): `hcgsentinel://open/<section>` for 9 screens and `hcgsentinel://report/<uuid>`. Navigation only: no link starts a scan, sends a request, connects, changes a setting or deletes data (`docs/NEXUS_INTEGRATION.md`). `NexusStatusSnapshot` is defined but **not published**. | "Not connected" until switched on in settings. Then it opens the app, or reports "App not installed". Shortcuts may use Sentinel links; Nexus validates them with Sentinel's own rules and refuses anything else before opening. No status is shown: Sentinel does not publish it. |
| **Executable Maker** | .NET desktop app (Windows, macOS, Linux) | Build status lives only in its local SQLite database. It has no status endpoint and no URL scheme. Its website API (`/api/public/executable-maker/v1`) is documented in the repo but not deployed, and it needs HCG Connect bearer auth. | Not offered (since 0.2.0). Build status is not shown. |

## What each state is based on

| State shown | Evidence | Terminal (Standard / Unleashed) | News | Sentinel |
|---|---|---|---|---|
| Not connected | The integration is off in settings | yes | yes | yes |
| App not installed | The installation probe (LSApplicationWorkspace in SpringBoard) | yes | yes | yes |
| Ready (installed) | The installation probe | yes | yes | yes |
| Signed out / connected | Needs the app to publish its HCG Connect state | **not available**: no app publishes it | not available | not available |
| Status / activity | Needs a published status | not available | not available | **not available**: `NexusStatusSnapshot` is not written by Sentinel |

Opening an app proves only that it opened. It is never shown as a signed-in or connected state. Nexus holds no HCG
sign-in, tokens or credentials; sign-in stays in each app and HCG Connect.

## Code

* `Sources/Core/HCGIntegrations.{h,m}`: catalog and status logic. It is a pure
  function of settings plus an installation probe, and does no networking. The
  "server" status still reads "Not connected". Its detail text points
  standalone-app users to Connected Devices.
* `Sources/Platform/App/DeviceLink/`: HCG Device Link (standalone app only),
  on top of the vendored `HCGDeviceLink/` Swift client.
* `Sources/Panel/HCGActionRunner.m`: turns a status into a launch or an
  actionable error.
* Host tests: `testUnconfiguredIntegrationsAreNotConnected` and
  `testConfiguredIntegrations` in `Tests/Host/ModelTests.m`; Command Mode
  state mapping in `Tests/Host/CommandModeTests.m`.
* `Sources/Core/HCGCommandMode.{h,m}`: integration status → Command Mode
  display state (below).

## Command Mode connection states

Command Mode (`docs/FEATURES.md`) shows each offered integration with one of
six states. The mapping is `+[HCGCommandModeStatus displayForIntegrationStatus:]`
in `Sources/Core/HCGCommandMode.m`, host-tested in
`Tests/Host/CommandModeTests.m`. It only reads `HCGIntegrationStatus`; it never
probes a service.

| Display state | Produced when | Possible today? |
|---|---|---|
| **Unknown** | no status, unrecognised identifier, installation cannot be checked, or reachability / sign-in not reported | yes (e.g. no install probe) |
| **Unavailable** | no phone-reachable contract (Server, Executable Maker), app not installed, or this build cannot open apps (standalone app) | yes |
| **Off** | the integration exists but is not turned on in HCG Nexus settings | yes |
| **Disconnected** | turned on, but its service reports *unreachable* | **no** — no contract publishes reachability |
| **Signed out** | turned on and reachable, but the session is *signed out* | **no** — Nexus holds no session; HCG Connect is the authority |
| **Connected** | turned on, app installed, and reachability/sign-in either reported fine or not applicable (Terminal/News: Nexus opens the app; it shows no session or sync) | yes |

`HCGIntegrationStatus` carries the facts this needs: `recognized`,
`contractAvailable`, `configured`, `reachability` and `session`. HCG Terminal
and HCG News set reachability and session to *NotApplicable*; everything else
leaves them at their default, *Unknown*. When an HCG Connect-authorised status
contract exists, filling in those two fields is all Command Mode needs to show
*Disconnected* or *Signed out*.

## What would unlock more

* **Terminal / News:** a registered URL scheme or universal link with documented
  routes. With that, Nexus could add deep-link actions.
* **Server:** HCG Device Link now covers pairing, presence and shared reports
  in the standalone app. It needs Nexus's HCG Connect client from HCG first.
  Server status (the read-only `overview`) is still not exposed to phones.
* **Executable Maker:** a deployed, HCG Connect-authorised build-status endpoint.
